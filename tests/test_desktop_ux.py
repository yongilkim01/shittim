"""Desktop UX installation preserves unrelated settings and backs up changes."""
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from xml.sax.saxutils import escape
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('desktop_ux', ROOT / 'scripts/desktop-ux.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)


class DesktopUX(unittest.TestCase):
    def test_configerrors_ignores_blank_lines_and_reports_actual_errors(self):
        script = (ROOT / 'scripts/verify-desktop-ux.sh').read_text(encoding='utf-8')
        line = next(line for line in script.splitlines() if 'hyprctl -j configerrors |' in line)
        code = shlex.split(line.split('|', 1)[1])[-1]
        for errors, expected in [([], 0), ([''], 0), (['', '  ', '\n'], 0),
                                 (['', 'bad rule', '  '], 1)]:
            with self.subTest(errors=errors):
                result = subprocess.run([sys.executable, '-c', code], input=json.dumps(errors),
                                        capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertIn('Hyprland 설정 오류: ' + str(expected), result.stdout)
                if expected: self.assertIn('bad rule', result.stdout)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name); self.home = self.base / 'home'; self.home.mkdir()
        self.env = patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                              XDG_DATA_HOME=str(self.base / 'external data'), XDG_STATE_HOME=str(self.home / '.local/state'))
        self.env.start(); self.addCleanup(self.env.stop)
        self.config = TOOL.files.Config(ROOT, self.home)
        self.ux = TOOL.UX(self.config)

    def test_ini_and_css_merge_preserve_unrelated_preferences_and_update_once(self):
        text = '[Settings]\ngtk-cursor-theme-name=mine\ngtk-font-name=old\n'
        merged = TOOL.ini(text, TOOL.GTK)
        self.assertIn('gtk-cursor-theme-name=mine', merged)
        self.assertEqual(merged, TOOL.ini(merged, TOOL.GTK))
        old = 'button { padding: 7px; }\n'
        styled = TOOL.css(old, 'window { color: cyan; }')
        self.assertIn(old.strip(), styled)
        self.assertEqual(styled, TOOL.css(styled, 'window { color: cyan; }'))
        replaced = TOOL.css(styled, 'window { color: white; }')
        self.assertNotIn('cyan', replaced); self.assertIn(old.strip(), replaced)
        with self.assertRaises(ValueError): TOOL.css(TOOL.CSS_BEGIN, '')
        with self.assertRaises(ValueError): TOOL.css(TOOL.CSS_END + TOOL.CSS_BEGIN, '')

    @unittest.skipIf(os.name == 'nt', 'Linux 심볼릭 링크와 Lua 검사')
    def test_setup_links_external_xdg_data_backups_and_repeats_without_drift(self):
        gtk = self.config.config / 'gtk-3.0'; gtk.mkdir(parents=True)
        (gtk / 'gtk.css').write_text('button { padding: 7px; }\n')
        entry = self.config.config / 'hypr/hyprland.lua'; entry.parent.mkdir()
        entry.write_text(self.config.lua())
        with patch.object(self.ux, 'gsettings', return_value=[]):
            self.ux.setup()
            before = list(self.config.backups.rglob('*'))
            self.ux.setup(); self.ux.verify()
        self.assertEqual(before, list(self.config.backups.rglob('*')))
        self.assertTrue((self.config.data / 'icons/Shittim-HUD/index.theme').is_symlink())
        self.assertIn('button { padding: 7px; }', (gtk / 'gtk.css').read_text())
        self.assertTrue(any(path.name == 'gtk.css' for path in self.config.backups.rglob('*')))
        (gtk / 'settings.ini').write_text('[Settings]\ngtk-theme-name=other\n')
        with self.assertRaisesRegex(ValueError, 'GTK 설정 불일치'): self.ux.verify()

    def test_dry_run_writes_no_user_state(self):
        self.config.dry = True
        with patch.object(self.ux, 'gsettings', side_effect=AssertionError('dry run must not use GSettings')):
            self.ux.setup(); self.ux.verify()
        self.assertFalse(self.config.config.exists()); self.assertFalse(self.config.data.exists()); self.assertFalse(self.config.state.exists())

    def test_generated_policy_is_excluded_from_config_capture(self):
        self.assertFalse(TOOL.files.allowed(Path('hypr/shittim-windows.lua')))

    @unittest.skipUnless(shutil.which('lua'), '실제 Lua 인터프리터 검사')
    def test_lua_policy_uses_static_rule_and_expected_mouse_bindings(self):
        text = '''local rules,binds,options={},{},{}
hl={window_rule=function(v) table.insert(rules,v) end, config=function(v) options=v end,
env=function() end, unbind=function() end,
bind=function(key,fn,opts) binds[key]=opts or {} end,
dsp={window={drag=function() end,resize=function() end,close=function() end,float=function() end,fullscreen=function() end},exec_cmd=function() end}}
'''
        text += self.ux.lua()
        text += '''
assert(#rules==1 and rules[1].float==true and rules[1].match.float==false)
assert(rules[1].match.fullscreen==false and rules[1].match.fullscreen_state_client==0)
assert(options.general.resize_on_border and options.general.snap.enabled)
assert(binds['SUPER + mouse:272'].mouse and binds['SUPER + mouse:273'].mouse)
assert(binds['ALT + Alt_L'].release and binds['ALT + Alt_R'].release)
'''
        subprocess.run(['lua', '-'], input=text, text=True, check=True, capture_output=True, timeout=5)

    @unittest.skipUnless(sys.platform == 'linux' and shutil.which('glib-compile-schemas'), '실제 GSettings 메모리 백엔드 검사')
    def test_gsettings_changes_are_backed_up_idempotent_and_restorable(self):
        schemas = self.base / 'schemas'; schemas.mkdir()
        text = '<schemalist>'
        for schema, values in TOOL.SETTINGS.items():
            text += '<schema id="' + schema + '" path="/' + schema.replace('.', '/') + '/">'
            for key, value in values.items():
                kind = 'b' if isinstance(value, bool) else 's'
                default = 'false' if kind == 'b' else "'original'"
                text += '<key name="' + key + '" type="' + kind + '"><default>' + escape(default) + '</default></key>'
            text += '</schema>'
        (schemas / 'fixture.gschema.xml').write_text(text + '</schemalist>')
        subprocess.run(['glib-compile-schemas', str(schemas)], check=True, capture_output=True, timeout=5)
        environment = dict(os.environ, GSETTINGS_SCHEMA_DIR=str(schemas), GSETTINGS_BACKEND='memory')
        code = ('import importlib.util; s=importlib.util.spec_from_file_location("ux",' + repr(str(ROOT / 'scripts/desktop-ux.py')) + '); '
                'm=importlib.util.module_from_spec(s); s.loader.exec_module(m); from gi.repository import Gio; '
                'settings=Gio.Settings.new("org.gnome.desktop.interface"); settings.set_string("font-name","Before font 11"); '
                'ux=m.UX(); records=ux.gsettings(); backup=ux.files.backups/"desktop-gsettings.json"; before=backup.read_bytes(); '
                'assert settings.get_string("font-name")=="Hack Nerd Font Mono 10"; '
                'ux.gsettings(); assert backup.read_bytes()==before; '
                'ux.restore_settings(backup); assert settings.get_string("font-name")=="Before font 11"; '
                'assert settings.get_user_value("gtk-theme") is None')
        result = subprocess.run([sys.executable, '-c', code], env=environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__': unittest.main()
