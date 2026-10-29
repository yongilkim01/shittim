"""Desktop setup in temporary homes, mocked commands, and redacted MPRIS data."""
import configparser
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, script):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / script)
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


TOOL = load('desktop_tool', 'desktop-tool.py')
MEDIA = load('media_diagnostic', 'diagnose-media.py')


class DesktopSetup(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name); self.root = self.base / 'repo with spaces'; self.home = self.base / 'home'
        self.root.mkdir(); self.home.mkdir()
        self.env = patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                              XDG_STATE_HOME=str(self.home / '.local/state'), HYPRLAND_INSTANCE_SIGNATURE='')
        self.env.start(); self.addCleanup(self.env.stop)
        for relative in ['config/hyprland-portals.conf', 'config/templates/shittim-lock.conf.in']:
            path = self.root / relative; path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, path)
        self.config = TOOL.files.Config(self.root, self.home)
        self.desktop = TOOL.Desktop(self.config)

    def write(self, relative, text):
        path = self.config.config / relative; path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8'); return path

    def test_mime_merge_keeps_unrelated_values_and_is_idempotent(self):
        old = '[Default Applications]\ntext/plain=custom.desktop;\ntext/html=old.desktop;\n[Added Associations]\ntext/plain=custom.desktop;\n'
        new = TOOL.mime_text(old, {'text/html': 'google-chrome.desktop'})
        parser = configparser.ConfigParser(); parser.read_string(new)
        self.assertEqual(parser['Default Applications']['text/plain'], 'custom.desktop;')
        self.assertEqual(parser['Added Associations']['text/plain'], 'custom.desktop;')
        self.assertEqual(new, TOOL.mime_text(new, {'text/html': 'google-chrome.desktop'}))

    def test_setup_backups_links_defaults_and_repeat(self):
        original = '[Default Applications]\ntext/plain=mine.desktop;\ntext/html=old.desktop;\n'
        mime = self.write('mimeapps.list', original)
        self.write('hypr/shittim-base.lua', 'local mainMod = "SUPER"\nlocal fileManager = "dolphin"\nhl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))\n')
        with patch.object(self.desktop, 'installed', return_value=set(TOOL.APPLICATIONS)), patch.object(TOOL.subprocess, 'run'):
            try:
                self.desktop.setup()
            except OSError:
                if os.name == 'nt': self.skipTest('Windows 심볼릭 링크 권한 없음')
                raise
            self.assertEqual(next(self.config.backups.rglob('mimeapps.list')).read_text(), original)
            self.assertIn('google-chrome.desktop', mime.read_text())
            self.assertIn('text/plain=mine.desktop;', mime.read_text())
            lock = (self.config.config / 'hypr/shittim-lock.conf').read_text(encoding='utf-8')
            self.assertIn('path = ' + str(self.root) + '/assets/wallpapers/shittim-city.png', lock)
            self.assertIn("/usr/bin/bash '" + str(self.root) + "'/scripts/lock-status.sh", lock)
            self.assertNotIn('@ROOT', lock)
            before = sorted(str(path) for path in self.config.backups.rglob('*'))
            self.desktop.setup()
            self.assertEqual(before, sorted(str(path) for path in self.config.backups.rglob('*')))
            self.assertFalse((self.config.config / 'systemd/user/shittim-clipboard.service').exists())

    def test_missing_chrome_never_creates_fake_default(self):
        self.config.dry = True
        with patch.object(self.desktop, 'installed', return_value={'org.shittim.Files.desktop'}):
            # Actual branch, with link/write isolated; no root commands.
            self.config.dry = False
            with patch.object(self.config, 'link'), patch.object(TOOL.subprocess, 'run'):
                self.desktop.setup()
        data = json.loads(self.desktop.manifest.read_text())
        self.assertEqual(data['defaults'], {'inode/directory': 'org.shittim.Files.desktop'})
        self.assertNotIn('google-chrome', (self.config.config / 'mimeapps.list').read_text())

    def test_static_custom_binding_preserved_and_known_dolphin_replaced(self):
        self.write('hypr/shittim-base.lua', 'local mainMod="SUPER"\nlocal fileManager="dolphin"\n'
            'hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("my-browser"))\n'
            'hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))\n')
        bindings, conflicts = self.desktop.bindings()
        self.assertNotIn('SUPER + B', bindings); self.assertIn('SUPER + B', conflicts)
        self.assertIn('SUPER + E', bindings)
        bindings, conflicts = self.desktop.bindings(True)
        self.assertEqual(conflicts, []); self.assertIn('SUPER + B', bindings)

    def test_included_lua_is_not_executed_or_blindly_overridden(self):
        self.write('hypr/shittim-base.lua', 'dofile("custom.lua")\n')
        bindings, conflicts = self.desktop.bindings()
        self.assertEqual(bindings, {}); self.assertEqual(len(conflicts), len(TOOL.KEYS))

    def test_live_binds_reject_custom_and_keep_repeated_managed_commands(self):
        bindings = [{'modmask': 64, 'key': 'B', 'dispatcher': 'exec', 'arg': 'custom-browser'},
                    {'modmask': 64, 'key': 'E', 'dispatcher': 'exec', 'arg': 'dolphin'},
                    {'modmask': 64, 'key': 'L', 'dispatcher': 'function: 0x1234', 'arg': '17',
                     'description': TOOL.binding_marker('SUPER + L', self.desktop.commands()['SUPER + L'])}]
        with patch.dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE='test'), patch.object(TOOL.subprocess, 'run', return_value=Mock(stdout=json.dumps(bindings))):
            allowed, conflicts = self.desktop.bindings()
        self.assertEqual(conflicts, ['SUPER + B'])
        self.assertIn('SUPER + L', allowed); self.assertIn('SUPER + E', allowed)

    def test_lua_reference_is_not_mistaken_for_an_exec_command(self):
        self.write('hypr/shittim-base.lua', 'local mainMod="SUPER"\nlocal fileManager="dolphin"\n'
            'hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))\n')
        bindings = [{'modmask': 64, 'key': 'E', 'dispatcher': 'function: 0x1234', 'arg': '23', 'description': ''},
                    {'modmask': 64, 'key': 'B', 'dispatcher': 'function: 0x5678', 'arg': '24', 'description': ''}]
        with patch.dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE='test'), patch.object(TOOL.subprocess, 'run', return_value=Mock(stdout=json.dumps(bindings))):
            allowed, conflicts = self.desktop.bindings()
        self.assertIn('SUPER + E', allowed); self.assertIn('SUPER + B', conflicts)

    def test_hyprland_057_dispatcher_object_is_migrated_like_a_lua_reference(self):
        self.write('hypr/shittim-base.lua', 'local mainMod="SUPER"\nlocal fileManager="dolphin"\n'
            'hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))\n')
        bindings = [{'modmask': 64, 'key': 'E', 'dispatcher': 'HL.Dispatcher(exec_cmd)', 'arg': '23', 'description': ''},
                    {'modmask': 64, 'key': 'B', 'dispatcher': 'HL.Dispatcher(exec_cmd)', 'arg': '24', 'description': ''}]
        with patch.dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE='test'), patch.object(TOOL.subprocess, 'run', return_value=Mock(stdout=json.dumps(bindings))):
            allowed, conflicts = self.desktop.bindings()
        self.assertIn('SUPER + E', allowed); self.assertIn('SUPER + B', conflicts)

    def test_dry_run_creates_no_config_or_state(self):
        self.config.dry = True
        self.desktop.setup()
        self.assertFalse(self.config.config.exists()); self.assertFalse(self.config.state.exists())

    def test_verify_without_setup_reports_missing_manifest_and_recovery(self):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/desktop-tool.py'), 'verify'],
                                capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 1)
        self.assertIn(str(self.desktop.manifest), result.stderr)
        self.assertIn('bash scripts/setup-desktop.sh', result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertFalse(self.config.config.exists()); self.assertFalse(self.config.state.exists())

    def test_missing_executable_reports_its_name_without_command_output(self):
        environment = dict(os.environ, PATH='', PYTHONUTF8='1')
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/desktop-tool.py'), 'launch', 'files'],
                                env=environment, capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(result.returncode, 1)
        self.assertIn('xdg-open', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def test_clipboard_service_is_opt_in_and_uses_watch_action(self):
        with patch.object(TOOL.subprocess, 'run') as run:
            self.desktop.clipboard(True)
            text = (self.config.config / 'systemd/user/shittim-clipboard.service').read_text()
            self.assertIn('clipboard.sh" watch\n', text)
            self.assertIn('WantedBy=shittim.service', text)
            self.assertIn('PartOf=shittim.service', text)
            self.assertEqual(run.call_args.args[0], ['systemctl', '--user', 'enable', '--now', 'shittim-clipboard.service'])

    @unittest.skipUnless(shutil.which('lua'), 'Linux Lua에서 실제 생성 구문 실행 검사')
    def test_generated_lua_executes_with_quoted_repository_path(self):
        commands = self.desktop.commands()
        lua = self.desktop.lua(commands)
        check = 'local result={}\nhl={unbind=function(key) result[key]=nil end,bind=function(key,command) result[key]=command end,dsp={exec_cmd=function(command) return command end}}\n'
        check += lua + '\nassert(result["SUPER + B"] == ' + json.dumps(commands['SUPER + B']) + ')\n'
        subprocess.run(['lua', '-'], input=check, text=True, check=True, capture_output=True, timeout=5)

    def test_generated_desktop_file_is_excluded_from_capture(self):
        self.assertFalse(TOOL.files.allowed(Path('hypr/shittim-desktop.lua')))
        self.assertFalse(TOOL.files.allowed(Path('hypr/shittim-lock.conf')))

    @unittest.skipIf(os.name == 'nt', '실제 Linux 설정 링크 검사')
    def test_live_verify_checks_actual_binding_and_default_mime(self):
        with patch.object(self.desktop, 'installed', return_value=set(TOOL.APPLICATIONS)), patch.object(TOOL.subprocess, 'run'):
            self.desktop.setup()
        expected = {mime: app for app, values in TOOL.APPLICATIONS.items() for mime in values}
        bindings = []
        for key, command in self.desktop.commands().items():
            bindings.append({'modmask': (64 if 'SUPER' in key else 0) | (1 if 'SHIFT' in key else 0),
                             'key': key.split('+')[-1].strip(), 'dispatcher': 'function: 0x1234', 'arg': '15',
                             'description': TOOL.binding_marker(key, command)})
        def run(arguments, **_kwargs):
            if arguments[0] == 'xdg-mime': return Mock(returncode=0, stdout=expected[arguments[-1]] + '\n')
            return Mock(returncode=0, stdout=json.dumps(bindings))
        with patch.object(self.desktop, 'installed', return_value=set(TOOL.APPLICATIONS)), patch.object(TOOL.subprocess, 'run', side_effect=run):
            self.desktop.verify(live=True)
            bindings[0]['description'] = 'custom changed after setup'
            with self.assertRaisesRegex(ValueError, '단축키 불일치'):
                self.desktop.verify(live=True)


class MediaDiagnostics(unittest.TestCase):
    def data(self):
        name = 'org.mpris.MediaPlayer2.fixture'
        remote = {name: {'PlaybackStatus': 'Playing', 'CanControl': True, 'CanSeek': False,
                        'Metadata': {'xesam:title': 'PRIVATE TITLE', 'xesam:artist': ['PRIVATE ARTIST'], 'mpris:artUrl': 'https://private.test/secret?token=private'}}}
        shell = {'selected': name, 'opened': True, 'artworkState': 'ready', 'artAllowed': True, 'playing': True,
                 'title': 'PRIVATE TITLE', 'artist': 'PRIVATE ARTIST', 'players': [{'name': name, 'title': 'PRIVATE TITLE', 'artist': 'PRIVATE ARTIST'}]}
        return remote, shell

    def test_healthy_comparison_is_redacted(self):
        remote, shell = self.data(); report = MEDIA.compare(remote, shell)
        self.assertEqual(report['players'][0]['issues'], [])
        self.assertTrue(report['players'][0]['titleSynced'])
        for private in ['PRIVATE TITLE', 'PRIVATE ARTIST', 'private.test', 'token=']:
            self.assertNotIn(private, json.dumps(report))

    def test_missing_player_metadata_ui_and_artwork_failures_are_distinct(self):
        self.assertEqual(MEDIA.compare({}, None)['issues'], ['MprisNotRegistered'])
        remote, shell = self.data(); shell['players'] = []
        self.assertIn('ShittimNotDetected', MEDIA.compare(remote, shell)['players'][0]['issues'])
        remote, shell = self.data(); shell['title'] = 'stale'; shell['artworkState'] = 'error'; shell['playing'] = False
        issues = MEDIA.compare(remote, shell)['players'][0]['issues']
        self.assertIn('UIDisplayMismatch', issues); self.assertIn('ArtworkLoadFailed', issues); self.assertIn('PlaybackSyncMismatch', issues)
        remote, shell = self.data(); next(iter(remote.values()))['Metadata'] = {}
        self.assertIn('MetadataMissing', MEDIA.compare(remote, shell)['players'][0]['issues'])


if __name__ == '__main__':
    unittest.main()
