"""Diagnostic privacy and scoped publishing; never inspect the real home."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('diagnose', Path(__file__).resolve().parents[1] / 'scripts/diagnose.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class Diagnostics(unittest.TestCase):
    def test_report_generation_keeps_failures_and_does_not_execute_profiles(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            profile = home / '.bash_profile'
            profile.write_text('exec start-hyprland\nexport API_KEY=do-not-upload # shittim\n', encoding='utf-8')
            (home / 'shittim-start.log').write_text('Failed to start session\npassword=do-not-upload\n', encoding='utf-8')
            env = {'XDG_CONFIG_HOME': str(home / '.config'), 'XDG_RUNTIME_DIR': str(home / 'run'), 'ZDOTDIR': ''}
            with patch.object(TOOL.Path, 'home', return_value=home), patch.dict(os.environ, env), \
                    patch.object(TOOL, 'command', return_value='[종료 코드 1] missing fixture service'), \
                    patch.object(TOOL.os, 'getuid', return_value=1000, create=True):
                report = TOOL.collect()
            self.assertIn('exec start-hyprland', report)
            self.assertIn('Failed to start session', report)
            self.assertIn('missing fixture service', report)
            self.assertNotIn('do-not-upload', report)
            self.assertNotIn(str(home), report)
            self.assertFalse((home / '.config').exists())
            self.assertIn('do-not-upload', profile.read_text())

    def test_scrub_removes_credentials_and_host_identifiers(self):
        raw = ('password=do-not-upload\nexport API_KEY=do-not-upload\n'
               'https://name:do-not-upload@example.org\n'
               'value=' + 'a' * 48 + '\n/home/test/.config/hypr/hyprland.lua\n'
               'test-host 192.168.1.2 aa:bb:cc:dd:ee:ff\n'
               '\x1b[31mERROR: Failed to open session\x1b[0m')
        with patch.object(TOOL.socket, 'gethostname', return_value='test-host'):
            result = TOOL.scrub(raw, '/home/test')
        for value in ('do-not-upload', 'a' * 48, '/home/test', 'test-host', '192.168.1.2', 'aa:bb:cc:dd:ee:ff', '\x1b'):
            self.assertNotIn(value, result)
        self.assertIn('ERROR: Failed to open session', result)
        self.assertIn('$HOME/.config/hypr/hyprland.lua', result)

    def test_profiles_are_read_without_execution_and_filtered(self):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory) / '.bash_profile'
            profile.write_text('echo unrelated-private-note\n'
                               'if [ "$(tty)" = /dev/tty1 ]; then\n'
                               ' exec start-hyprland\nfi\n'
                               'export API_KEY=do-not-upload # shittim\n', encoding='utf-8')
            result = TOOL.scrub(TOOL.profile_excerpt(profile))
            self.assertIn('exec start-hyprland', result)
            self.assertIn('/dev/tty1', result)
            self.assertNotIn('unrelated-private-note', result)
            self.assertNotIn('do-not-upload', result)
            self.assertEqual(profile.read_text().count('do-not-upload'), 1)

    def test_shell_status_and_layers_survive_scrub(self):
        status = '[종료 코드 0]\n  WARN: locale\n{"fingerprint":"' + 'a' * 64 + '","owner":"control","screens":["eDP-1"]}\n'
        layers = '[종료 코드 0]\n{"eDP-1":{"levels":{"0":[{"namespace":"shittim-surface"}],"2":[{"namespace":"shittim-bar"}]}}}'
        with patch.object(TOOL, 'command', side_effect=[status, layers]):
            report = TOOL.scrub(TOOL.shell_status() + '\n' + TOOL.layers())
        self.assertIn('"owner": "control"', report)
        self.assertNotIn('a' * 64, report)
        self.assertIn('eDP-1: shittim-bar, shittim-surface', report)

    def test_failed_and_missing_commands_do_not_abort_collection(self):
        with patch.object(TOOL.subprocess, 'run', return_value=subprocess.CompletedProcess([], 7, 'failure details')):
            self.assertIn('7', TOOL.command(['example']))
        with patch.object(TOOL.subprocess, 'run', side_effect=FileNotFoundError('missing')):
            self.assertIn('실행 불가', TOOL.command(['example']))
        with patch.object(TOOL.subprocess, 'run', side_effect=subprocess.TimeoutExpired('example', 1)):
            self.assertIn('시간 제한', TOOL.command(['example']))

    def test_existing_staged_changes_block_publish(self):
        with patch.object(TOOL, 'git', side_effect=['main', 'other-file.txt']) as git:
            with self.assertRaises(ValueError):
                TOOL.publish()
        self.assertFalse(any(call.args[0] in ('add', 'commit', 'push') for call in git.call_args_list))

    def test_unpublished_other_commits_block_publish(self):
        replies = ['main', '', 'https://github.com/yongilkim01/shittim.git', '', '', 'shell/shell.qml']
        with patch.object(TOOL, 'git', side_effect=replies) as git:
            with self.assertRaises(ValueError):
                TOOL.publish()
        self.assertFalse(any(call.args[0] in ('add', 'commit') for call in git.call_args_list))

    def test_publish_scopes_commit_and_push_to_report(self):
        replies = ['main', '', 'https://github.com/yongilkim01/shittim.git', '', '', '', '', 'diagnostics/latest.txt', '', 'abc1234']
        with patch.object(TOOL, 'git', side_effect=replies) as git, patch.object(TOOL.subprocess, 'run') as run:
            TOOL.publish()
        calls = [call.args for call in git.call_args_list]
        self.assertIn(('add', '--', 'diagnostics/latest.txt'), calls)
        self.assertIn(('commit', '-m', 'chore: collect laptop login diagnostics', '--', 'diagnostics/latest.txt'), calls)
        self.assertEqual(run.call_args.args[0], ['git', 'push', 'origin', 'HEAD:refs/heads/main'])


if __name__ == '__main__':
    unittest.main()
