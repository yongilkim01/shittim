"""Launch protocol tests; mock metadata only, never run a user's applications."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock

SPEC = importlib.util.spec_from_file_location('launcher_service', Path(__file__).resolve().parents[1] / 'scripts/launcher-service.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class Desktop:
    records = {}

    def __init__(self, app_id, name, visible=True):
        self.app_id, self.name, self.visible = app_id, name, visible
        self.launch_uris_finish = Mock(return_value=True)
        self.launch_uris_async = Mock(side_effect=lambda uris, context, cancel, callback, request: callback(self, None, request))

    def get_id(self): return self.app_id
    def get_display_name(self): return self.name
    def get_name(self): return self.name
    def should_show(self): return self.visible
    def get_is_hidden(self): return False
    def get_icon(self): return None
    def get_generic_name(self): return '편집기'
    def get_keywords(self): return ['개발', 'text']

    @classmethod
    def new(cls, app_id): return cls.records.get(app_id)


class Protocol(unittest.TestCase):
    def setUp(self):
        self.events = []
        self.app = Desktop('sample.desktop', '앱 공백 <&>')
        Desktop.records = {self.app.app_id: self.app}
        self.gio = Mock()
        self.gio.ThemedIcon = type('ThemedIcon', (), {})
        self.gio.FileIcon = type('FileIcon', (), {})
        self.gio.AppInfo.get_all.return_value = [self.app, self.app, Desktop('hidden', 'Hidden', False)]
        self.catalogue = TOOL.Catalogue(self.gio, Desktop, self.events.append)
        self.catalogue.refresh()

    def test_catalogue_deduplicates_and_preserves_metadata(self):
        apps = self.events[-1]['applications']
        self.assertEqual(len(apps), 1)
        self.assertEqual(apps[0]['name'], '앱 공백 <&>')
        self.assertEqual(apps[0]['keywords'], ['개발', 'text'])

    def test_launch_passes_no_shell_command_to_gio(self):
        self.catalogue.handle({'action': 'launch', 'id': self.app.app_id, 'request': 7})
        call = self.app.launch_uris_async.call_args.args
        self.assertEqual(call[:3], ([], self.gio.AppLaunchContext.return_value, None))
        self.assertTrue(callable(call[3]))
        self.assertEqual(call[4], 7)
        self.assertEqual(self.events[-1], {'event': 'launched', 'request': 7, 'ok': True})

    def test_new_window_uses_desktop_action_when_provided(self):
        self.app.list_actions=Mock(return_value=['new-window']); self.app.launch_action=Mock()
        self.catalogue.handle({'action':'new-window','id':self.app.app_id,'request':9})
        self.app.launch_action.assert_called_once_with('new-window',self.gio.AppLaunchContext.return_value)
        self.app.launch_uris_async.assert_not_called()
        self.assertEqual(self.events[-1],{'event':'launched','request':9,'ok':True})

    def test_unknown_id_and_disappeared_entry_never_launch(self):
        for app_id in ['sh -c anything', '/tmp/unregistered.desktop', 'sample.desktop']:
            Desktop.records.clear()
            self.catalogue.handle({'action': 'launch', 'id': app_id, 'request': 8})
            self.app.launch_uris_async.assert_not_called()
            self.assertTrue(any(event.get('error') == 'ApplicationMissing' for event in self.events))

    def test_hidden_after_indexing_is_rechecked(self):
        self.app.visible = False
        self.catalogue.handle({'action': 'launch', 'id': self.app.app_id, 'request': 9})
        self.app.launch_uris_async.assert_not_called()

    def test_error_does_not_expose_exec_arguments(self):
        self.app.launch_uris_finish.side_effect = RuntimeError('private-exec-value')
        self.catalogue.handle({'action': 'launch', 'id': self.app.app_id, 'request': 10})
        self.assertEqual(self.events[-1]['error'], 'LaunchFailed')
        self.assertNotIn('private-exec-value', repr(self.events))

    def test_invalid_messages_are_rejected(self):
        for message in [None, [], 'command', {'action': 'run', 'command': 'text'}, {'action': 'launch', 'id': []}]:
            self.catalogue.handle(message)
            self.assertEqual(self.events[-1]['error'], 'InvalidRequest')


if __name__ == '__main__':
    unittest.main()
