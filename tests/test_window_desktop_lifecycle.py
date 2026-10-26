"""Stateful compositor fixture: independent maximize, restore, hide, and failure recovery."""
import importlib.util
import json
from pathlib import Path
import re
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('desktop_windows', ROOT/'scripts/window-service.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)
SPEC = importlib.util.spec_from_file_location('window_diagnostics', ROOT/'scripts/window-diagnostics.py')
DIAGNOSTICS = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(DIAGNOSTICS)


class DesktopLifecycle(unittest.TestCase):
    def setUp(self):
        self.monitor = dict(id=0, x=0, y=0, width=1920, height=1080, scale=1, transform=0,
                            reserved=[0, 40, 0, 72], focused=True, activeWorkspace={'id': 1})
        self.clients = []
        for index, name in enumerate(('kitty', 'org.shittim.Files', 'google-chrome')):
            self.clients.append(dict(address='0x'+str(index+1), **{'class': name}, mapped=True,
                floating=True, fullscreen=0, fullscreenClient=0, monitor=0, grouped=[],
                at=[180+index*40, 120], size=[700, 500], workspace={'id': 1, 'name': '1'}, tags=[]))
        self.commands = []; self.focused = self.clients[0]; self.fail_resize = False
        self.windows = TOOL.Windows(self.run_command)

    def run_command(self, args, **kwargs):
        self.assertNotIn('shell', kwargs)
        if args[1] == '-j':
            name = args[2]
            values = {'clients': self.clients, 'monitors': [self.monitor], 'activewindow': self.focused,
                'workspaces': [{'id': 1}], 'decorations': [{'decorationName': 'Hyprbar'}],
                'getprop': {'decorate': True}, 'getoption': {'int': 24}, 'cursorpos': {'x': 100, 'y': 100}}
            return Mock(stdout=json.dumps(values[name]))
        expression = args[2]; self.commands.append(expression)
        target = re.search(r'window="address:(0x[0-9a-f]+)"', expression)
        if target is None: return Mock(stdout='ok')
        client = next(item for item in self.clients if item['address'] == target[1])
        if 'window.resize(' in expression:
            if self.fail_resize:
                self.fail_resize = False
                return Mock(stdout='resize rejected')
            values = re.search(r'x=(-?\d+),y=(-?\d+)', expression)
            client['size'] = list(map(int, values.groups()))
        elif 'window.move(' in expression:
            values = re.search(r'x=(-?\d+),y=(-?\d+)', expression)
            if values: client['at'] = list(map(int, values.groups()))
            else:
                workspace = re.search(r'workspace="([^"]+)"', expression)[1]
                client['workspace'] = {'id': -99 if workspace.startswith('special:') else int(workspace), 'name': workspace}
        elif 'window.tag(' in expression:
            value = re.search(r'tag="([^"]+)"', expression)[1]
            if value.startswith('+') and value[1:] not in client['tags']: client['tags'].append(value[1:])
            elif value.startswith('-'): client['tags'] = [tag for tag in client['tags'] if tag != value[1:]]
        elif 'window.fullscreen_state(' in expression:
            client['fullscreen'], client['fullscreenClient'] = map(int, re.search(r'internal=(\d),client=(\d)', expression).groups())
        elif 'window.fullscreen(' in expression:
            # Native Hyprland fullscreen/maximize permits one owner per workspace.
            if not client['fullscreen']:
                for other in self.clients: other['fullscreen'] = 0
                client['fullscreen'] = 2 if '"fullscreen"' in expression else 1
            else: client['fullscreen'] = 0
        elif 'window.float(' in expression:
            client['floating'] = not client['floating'] if 'toggle' in expression else '"set"' in expression
        elif 'hl.dsp.focus(' in expression: self.focused = client
        elif 'window.close(' in expression: client['mapped'] = False
        return Mock(stdout='ok')

    def test_two_maximized_windows_keep_independent_geometry_and_restore(self):
        originals = [(client['at'][:], client['size'][:]) for client in self.clients]
        for client in self.clients: self.windows.action('maximize', client['address'])
        for client in self.clients:
            self.assertIn(TOOL.MAXIMIZED, client['tags'])
            self.assertEqual(client['fullscreen'], 0)
            self.assertEqual(client['at'][1], 48 if client['class'] == 'org.shittim.Files' else 72)
            self.assertEqual(client['at'][1]+client['size'][1], 1000)
        for index, client in enumerate(self.clients):
            self.windows.action('maximize', client['address'])
            self.assertEqual((client['at'], client['size']), originals[index])
            self.assertFalse(client['tags']); self.assertTrue(client['mapped'])
            for other in self.clients[index+1:]: self.assertIn(TOOL.MAXIMIZED, other['tags'])
        self.assertFalse(any('window.fullscreen' in cmd or 'window.close' in cmd or 'workspace=' in cmd for cmd in self.commands))

    def test_repeated_files_maximize_restore_never_hides_or_closes(self):
        client = self.clients[1]; original = (client['at'][:], client['size'][:])
        for _ in range(20):
            self.windows.action('maximize', client['address'])
            self.assertIn(TOOL.MAXIMIZED, client['tags'])
            self.windows.action('maximize', client['address'])
            self.assertEqual((client['at'], client['size']), original)
            self.assertTrue(client['mapped']); self.assertEqual(client['workspace']['id'], 1)

    def test_hide_restore_and_reflow_survive_new_controller_instance(self):
        client = self.clients[1]
        self.windows.action('maximize', client['address'])
        record = TOOL.restore_geometry(client)
        self.windows.action('hide', client['address'])
        self.assertTrue(client['workspace']['name'].startswith('special:shittim-hidden-'))
        self.monitor['reserved'][3] = 100
        replacement = TOOL.Windows(self.run_command)
        replacement.action('activate', client['address'])
        self.assertEqual(client['workspace']['id'], 1)
        self.assertEqual(client['at'][1]+client['size'][1], 972)
        self.assertEqual(TOOL.restore_geometry(client), record)
        replacement.action('restore', client['address']); self.assertFalse(client['tags'])

    def test_fullscreen_is_distinct_and_keeps_managed_restore_record(self):
        client = self.clients[0]
        self.windows.action('maximize', client['address'])
        record = TOOL.restore_geometry(client)
        self.windows.action('fullscreen', client['address'])
        self.assertEqual(client['fullscreen'], 2)
        self.assertEqual(self.windows.reflow()['adjusted'], 0)
        with self.assertRaisesRegex(ValueError, 'ExitFullscreen'): self.windows.action('maximize', client['address'])
        self.windows.action('fullscreen', client['address'])
        self.assertEqual(TOOL.restore_geometry(client), record)
        self.windows.action('restore', client['address']); self.assertFalse(client['tags'])

    def test_failed_geometry_change_rolls_back_without_touching_other_windows(self):
        client = self.clients[1]; original = (client['at'][:], client['size'][:])
        self.fail_resize = True
        with self.assertRaisesRegex(ValueError, 'DispatcherFailed'): self.windows.action('maximize', client['address'])
        self.assertEqual((client['at'], client['size']), original)
        self.assertFalse(client['tags']); self.assertTrue(client['mapped'])
        self.assertTrue(all('address:0x2' in cmd for cmd in self.commands))

    def test_work_area_reflow_changes_maximized_windows_only(self):
        for client in self.clients[:2]: self.windows.action('maximize', client['address'])
        other = (self.clients[2]['at'][:], self.clients[2]['size'][:])
        self.monitor.update(width=1600, height=900, scale=1.25, x=-1280)
        self.assertEqual(self.windows.reflow()['adjusted'], 2)
        for client in self.clients[:2]:
            self.assertGreaterEqual(client['at'][0], -1272)
            self.assertLessEqual(client['at'][0]+client['size'][0], -8)
            self.assertLessEqual(client['at'][1]+client['size'][1], 640)
        self.assertEqual((self.clients[2]['at'], self.clients[2]['size']), other)

    def test_invalid_restore_state_is_reported_without_hiding_window(self):
        client = self.clients[1]; client['tags'] = [TOOL.MAXIMIZED, 'shittim-restore_0_0_0_0_1']
        with self.assertRaisesRegex(ValueError, 'InvalidRestore'): self.windows.action('restore', client['address'])
        self.assertEqual(self.commands, []); self.assertTrue(client['mapped'])

    def test_native_titlebar_is_included_in_snap_and_recovered_normal_geometry(self):
        kitty, files = self.clients[:2]
        self.windows.action('snap', kitty['address'], 'left', 0)
        self.windows.action('snap', files['address'], 'right', 0)
        self.assertEqual(kitty['at'][1], 72); self.assertEqual(files['at'][1], 48)
        for client in (kitty, files): self.assertEqual(client['at'][1]+client['size'][1], 1000)
        kitty.update(at=[-5000, -5000])
        self.windows.action('activate', kitty['address'])
        self.assertGreaterEqual(kitty['at'][1], 72)

    def test_maximized_tiled_window_can_return_to_tiling(self):
        client = self.clients[0]; client['floating'] = False
        self.windows.action('maximize', client['address'])
        self.windows.action('tile', client['address'])
        self.assertFalse(client['floating']); self.assertFalse(client['tags'])

    def test_pinned_and_grouped_windows_are_not_silently_rearranged(self):
        for values in ({'pinned': True}, {'pinned': False, 'grouped': ['0x1', '0x3']}):
            self.clients[0].update(values)
            with self.assertRaisesRegex(ValueError, 'CannotMaximize'): self.windows.action('maximize', '1')
        self.assertEqual(self.commands, [])

    def test_diagnostics_omit_titles_locations_and_unrelated_tags(self):
        self.clients[0].update(title='private document title', initialTitle='private path', tags=['unrelated private tag'])
        report = DIAGNOSTICS.snapshot(self.windows)
        self.assertNotIn('private', json.dumps(report))
        self.assertEqual(report['active'], self.clients[0]['address'])
        self.assertEqual(DIAGNOSTICS.inspect(report, {'input:follow_mouse': 2, 'input:float_switch_override_focus': 0}), [])

    def test_diagnostics_detect_stale_focus_policy_and_clipped_bottom_edge(self):
        client = self.clients[1]; self.windows.action('maximize', client['address'])
        client['size'][1] += 20
        errors = DIAGNOSTICS.inspect(DIAGNOSTICS.snapshot(self.windows), {'input:follow_mouse': 0})
        self.assertEqual(len(errors), 2)
        self.assertTrue(any(client['address'] in error for error in errors))


if __name__ == '__main__': unittest.main()
