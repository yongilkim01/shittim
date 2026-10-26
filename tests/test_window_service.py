"""Window controls use validated selectors and real geometry arithmetic, no shell."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('window_service', ROOT / 'scripts/window-service.py')
TOOL = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(TOOL)


class WindowActions(unittest.TestCase):
    def setUp(self):
        self.client = {'address': '0xabc', 'mapped': True, 'workspace': {'id': 3, 'name': '3'},
                       'floating': True, 'fullscreen': 0, 'fullscreenClient': 0, 'monitor': 0,
                       'at': [-100, 900], 'size': [2000, 1200], 'grouped': []}
        self.monitor = {'id': 0, 'x': 0, 'y': 0, 'width': 1920, 'height': 1080, 'scale': 1,
                        'transform': 0, 'reserved': [0, 40, 0, 0], 'focused': True, 'activeWorkspace': {'id': 1}}
        self.workspaces = [{'id': 3}]
        self.commands = []
        def run(args, **kwargs):
            self.assertNotIn('shell', kwargs)
            if args[1] == '-j':
                values = {'clients': [self.client], 'activewindow': self.client, 'monitors': [self.monitor], 'workspaces': self.workspaces, 'decorations': []}
                return Mock(stdout=json.dumps(values[args[2]]))
            self.commands.append(args)
            return Mock(stdout='ok\n')
        self.windows = TOOL.Windows(run)

    def test_address_validation_and_graceful_close(self):
        self.windows.action('close', 'abc')
        self.assertEqual(self.commands, [['hyprctl', 'dispatch', 'hl.dsp.window.close({window="address:0xabc"})']])
        for value in ['abc);os.execute("bad")', '0x', '0xabc\n', 'class:kitty']:
            with self.assertRaises(ValueError): self.windows.action('close', value)

    def test_hide_records_origin_and_fullscreen_in_compositor_state(self):
        self.client.update(fullscreen=2, fullscreenClient=2)
        self.windows.action('hide', 'abc')
        self.assertIn('internal=0,client=0', self.commands[0][2])
        self.assertIn('workspace="special:shittim-hidden-3-2-2-abc",follow=false', self.commands[1][2])
        self.assertEqual(len(self.commands), 2)

    def test_restore_survives_shell_restart_without_private_state_files(self):
        self.client['workspace'] = {'id': -99, 'name': 'special:shittim-hidden-3-1-1-abc'}
        self.windows.action('activate', 'abc')
        self.assertIn('workspace="3",follow=false', self.commands[0][2])
        self.assertIn('internal=1,client=1', self.commands[1][2])
        self.assertIn('hl.dsp.focus(', self.commands[2][2])
        self.assertIn('alter_zorder', self.commands[3][2])

    def test_missing_original_workspace_uses_focused_monitor(self):
        self.workspaces = []
        self.client['workspace'] = {'id': -99, 'name': 'special:shittim-hidden-3-0-0-abc'}
        self.windows.action('activate', 'abc')
        self.assertIn('workspace="1",follow=false', self.commands[0][2])

    def test_special_grouped_and_pinned_windows_are_not_hidden(self):
        self.client['pinned'] = True
        with self.assertRaisesRegex(ValueError, 'CannotHide'): self.windows.action('hide', 'abc')
        self.client['pinned'] = False; self.client['grouped'] = ['0xabc', '0xdef']
        with self.assertRaisesRegex(ValueError, 'CannotHide'): self.windows.action('hide', 'abc')
        self.client['grouped'] = []; self.client['workspace']['id'] = -99
        with self.assertRaisesRegex(ValueError, 'CannotHide'): self.windows.action('hide', 'abc')
        self.assertEqual(self.commands, [])

    def test_fit_respects_reserved_bar_scale_rotation_and_negative_output_position(self):
        self.assertEqual(TOOL.fitted(self.client, self.monitor), (8, 48, 1904, 1024))
        self.monitor.update(x=-1080, width=1920, height=1080, scale=1.5, transform=1)
        x, y, width, height = TOOL.fitted(self.client, self.monitor)
        self.assertGreaterEqual(x, -1072); self.assertGreaterEqual(y, 48)
        self.assertLessEqual(x + width, -1080 + 720 - 8)
        self.assertLessEqual(y + height, 1280 - 8)
        self.monitor['scale'] = 0
        with self.assertRaises(ValueError): TOOL.fitted(self.client, self.monitor)

    def test_fullscreen_maximize_and_tiling_are_distinct(self):
        self.windows.action('maximize', 'abc'); self.windows.action('fullscreen', 'abc'); self.windows.action('tile', 'abc')
        self.assertTrue(any('shittim-maximized' in command[2] for command in self.commands))
        self.assertFalse(any('mode="maximized"' in command[2] for command in self.commands))
        self.assertIn('mode="fullscreen"', self.commands[-2][2])
        self.assertIn('window.float({action="toggle"', self.commands[-1][2])
        self.client['fullscreen'] = 2
        with self.assertRaisesRegex(ValueError, 'ExitFullscreenBeforeFit'): self.windows.action('fit', 'abc')

    def test_fit_reapplies_maximized_area_and_preserves_tiling(self):
        self.client['fullscreen']=1
        self.assertEqual(self.windows.action('fit','abc'),{'mode':'maximized'})
        self.assertIn('mode="maximized",action="unset"',self.commands[0][2])
        self.assertIn('mode="maximized",action="set"',self.commands[1][2])
        self.commands=[]; self.client.update(fullscreen=0,floating=False)
        self.assertEqual(self.windows.action('fit','abc'),{'mode':'tiled'})
        self.assertEqual(self.commands,[])
        self.client['fullscreenClient']=2
        with self.assertRaisesRegex(ValueError,'ExitFullscreenBeforeFit'): self.windows.action('fit','abc')

    def test_failed_dispatch_is_reported(self):
        self.windows.runner = lambda *_args, **_kwargs: Mock(stdout='[bad]')
        with self.assertRaisesRegex(ValueError, 'DispatcherFailed'): self.windows.dispatch('hl.dsp.focus({})')

    def test_half_quarter_snap_geometry_and_safe_dispatch(self):
        self.monitor['reserved']=[0,40,0,78]
        left=TOOL.snapped(self.monitor,'left'); right=TOOL.snapped(self.monitor,'right')
        self.assertEqual(left,(8,48,952,946)); self.assertEqual(right,(960,48,952,946))
        self.assertEqual(TOOL.snapped(self.monitor,'top-left'),(8,48,952,473))
        self.assertEqual(TOOL.snapped(self.monitor,'bottom-right'),(960,521,952,473))
        self.windows.action('snap','abc','left',0)
        self.assertIn('x=952,y=946,relative=false',self.commands[0][2])
        self.assertIn('x=8,y=48,relative=false',self.commands[1][2])
        with self.assertRaises(ValueError): self.windows.action('snap','abc','bad',0)
        self.client['fullscreen']=2
        with self.assertRaises(ValueError): self.windows.action('snap','abc','left',0)

    def test_dock_reservation_is_shared_by_fit_and_snap_without_double_subtraction(self):
        self.monitor['reserved']=[0,40,0,78]
        self.assertEqual(TOOL.work_area(self.monitor),(8,48,1904,946))
        self.assertEqual(TOOL.fitted(self.client,self.monitor),(8,48,1904,946))
        self.assertEqual(TOOL.snapped(self.monitor,'left')[3],946)
        self.assertEqual(TOOL.snapped(self.monitor,'top'),TOOL.work_area(self.monitor))
        self.windows.action('fit','abc')
        self.assertIn('x=1904,y=946,relative=false',self.commands[0][2])
        self.monitor['reserved']=[0,40,0,0]
        self.assertEqual(TOOL.snapped(self.monitor,'left')[3],1024)

    def test_activation_recovers_offscreen_window_but_leaves_fullscreen_untouched(self):
        self.client['at'] = [-5000, -5000]
        self.windows.action('activate', 'abc')
        self.assertIn('window.resize', self.commands[0][2]); self.assertIn('window.move', self.commands[1][2])
        self.assertIn('hl.dsp.focus', self.commands[2][2])
        self.commands = []; self.client['fullscreen'] = 2
        self.windows.action('activate', 'abc')
        self.assertEqual(len(self.commands), 2)
        self.assertIn('hl.dsp.focus', self.commands[0][2])


if __name__ == '__main__': unittest.main()
