"""Dock preferences use isolated config paths, never a user's applications."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('dock_settings', ROOT / 'scripts/dock-settings.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class DockSettings(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.default = self.base / 'default.json'
        self.user = self.base / 'personal.json'
        self.default.write_text(json.dumps({'favorites': ['kitty.desktop', 'kitty.desktop', '앱.desktop']}), encoding='utf-8')
        self.mock = patch.object(TOOL, 'paths', return_value=(self.default, self.user))
        self.mock.start(); self.addCleanup(self.mock.stop)

    def test_default_order_deduplication_and_unicode(self):
        data = TOOL.read_settings()
        self.assertEqual(data['favorites'], ['kitty.desktop', '앱.desktop'])
        self.assertEqual(data['error'], '')

    def test_personal_replaces_default_and_can_be_empty(self):
        self.user.write_text('{"favorites": []}', encoding='utf-8')
        self.assertEqual(TOOL.read_settings()['favorites'], [])
        self.assertEqual(TOOL.read_settings()['error'], '')
        self.user.write_text('{"favorites": ["my.desktop"], "windowClasses": {"my.desktop": ["Exact Class"]}}')
        self.assertEqual(TOOL.read_settings()['windowClasses'], {'my.desktop': ['Exact Class']})

    def test_invalid_personal_never_falls_back_or_executes(self):
        for data in [None, [], {'favorites': 'kitty.desktop'}, {'favorites': ['/tmp/app.desktop']},
                     {'favorites': ['x.desktop\n']}, {'favorites': ['x.desktop'], 'windowClasses': {'x.desktop': 'x'}},
                     {'favorites': [], 'windowClasses': {'/tmp/unlisted.desktop': ['class']}}, {'favorites': ['x.desktop'] * 65}]:
            self.user.write_text(json.dumps(data), encoding='utf-8')
            self.assertEqual(TOOL.read_settings()['error'], 'DockConfigInvalid', repr(data))
        self.user.write_bytes(b'not json')
        self.assertEqual(TOOL.read_settings()['favorites'], [])
        self.user.write_bytes(b' ' * 65537)
        self.assertEqual(TOOL.read_settings()['error'], 'DockConfigInvalid')

    def test_repository_default_is_valid(self):
        self.mock.stop()
        with patch.dict('os.environ', {'XDG_CONFIG_HOME': str(self.base / 'config')}):
            self.assertEqual(TOOL.read_settings()['error'], '')


if __name__ == '__main__':
    unittest.main()
