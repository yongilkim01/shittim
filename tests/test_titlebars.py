"""Optional titlebars: verified pins, quoted commands, guarded Lua and safe backups."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('titlebars', ROOT / 'scripts/titlebar-tool.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)


class Titlebars(unittest.TestCase):
    def test_only_confirmed_running_commits_choose_a_plugin_revision(self):
        for commit, expected in TOOL.COMPATIBLE.items():
            self.assertEqual(TOOL.revision({'commit': commit}), expected)
        for version in ({}, {'commit': 'unknown', 'tag': 'v0.55.0'}, {'commit': 'x; touch /tmp/unsafe'}):
            with self.assertRaisesRegex(ValueError, '호환성'): TOOL.revision(version)

    def test_generated_source_is_not_captured(self):
        self.assertFalse(TOOL.files.allowed(Path('hypr/shittim-titlebars.lua')))

    @unittest.skipUnless(shutil.which('lua'), '실제 Lua 인터프리터 검사')
    def test_lua_is_safe_without_plugin_and_binds_three_actual_actions_when_loaded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo with 'quote'"; (root / 'config').mkdir(parents=True)
            (root / 'config/titlebars.lua').write_text((ROOT / 'config/titlebars.lua').read_text(encoding='utf-8'), encoding='utf-8')
            class Config: pass
            config = Config(); config.root = root
            source = TOOL.source(config)
            self.assertNotIn('__HIDE__', source)
            code = '''local buttons,events,environment,options={},{},{},nil
hl={plugin={},on=function(event,callback) events[event]=callback end,
exec_cmd=function(command) assert(command=='hyprpm reload') end,
env=function(k,v) environment[k]=v end,
config=function(v) options=v end}
local setup=assert(load([==[SOURCE]==]))
setup()
assert(options==nil and #buttons==0 and events['hyprland.start'])
events['hyprland.start']()
hl.plugin.hyprbars={add_button=function(button) table.insert(buttons,button) end}
setup()
assert(#buttons==3 and buttons[1].icon=='X' and buttons[2].icon=='□' and buttons[3].icon=='−')
assert(buttons[1].action:match(' close$') and buttons[2].action:match(' maximize$') and buttons[3].action:match(' hide$'))
assert(options.plugin.hyprbars.bar_part_of_window and options.plugin.hyprbars.bar_height==28)
assert(options.plugin.hyprbars.on_double_click==buttons[2].action)
assert(environment.GTK_CSD=='0')
'''.replace('SOURCE', source)
            subprocess.run(['lua', '-'], input=code, text=True, capture_output=True, check=True, timeout=5)
            # Shell quoting must recover the real repository path, including apostrophes.
            import shlex
            command = shlex.join(['/usr/bin/bash', str(root / 'scripts/windows.sh'), 'hide'])
            self.assertEqual(shlex.split(command)[1], str(root / 'scripts/windows.sh'))

    def test_setup_backup_is_idempotent_and_dry_run_writes_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'), XDG_STATE_HOME=str(home / '.local/state')):
                config = TOOL.files.Config(ROOT, home)
                target = config.config / 'hypr/shittim-titlebars.lua'
                config.dry = True; config.write(target, TOOL.source(config)); self.assertFalse(target.exists())
                config.dry = False; target.parent.mkdir(parents=True); target.write_text('previous settings')
                config.write(target, TOOL.source(config)); before = list(config.backups.rglob('*'))
                config.write(target, TOOL.source(config)); self.assertEqual(before, list(config.backups.rglob('*')))
                self.assertTrue(any(path.is_file() and path.read_text()=='previous settings' for path in before))
                config.backup(target); self.assertFalse(target.exists())

    def test_verify_reports_unloaded_plugin_and_real_config_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            with patch.dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'), XDG_STATE_HOME=str(home / '.local/state')):
                config = TOOL.files.Config(ROOT, home)
                config.write(config.config / 'hypr/shittim-titlebars.lua', TOOL.source(config))
                with patch.object(TOOL.files, 'Config', return_value=config), patch.object(TOOL.sys, 'argv', ['titlebar-tool.py', 'verify']):
                    with patch.object(TOOL.subprocess, 'run', return_value=Mock(stdout='[]')):
                        with self.assertRaisesRegex(ValueError, '로드되지'): TOOL.main()
                    for errors in (['bad plugin option'], ['', '  ']):
                        responses = [Mock(stdout='[{"name":"hyprbars"}]'), Mock(stdout=json.dumps(errors))]
                        with patch.object(TOOL.subprocess, 'run', side_effect=responses):
                            if errors[0]:
                                with self.assertRaisesRegex(ValueError, 'bad plugin option'): TOOL.main()
                            else: TOOL.main()


if __name__ == '__main__': unittest.main()
