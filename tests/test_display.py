"""Display layout tests with a fake Hyprland; nothing here touches a real monitor, hyprctl or systemd."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('display_config', ROOT / 'scripts/display-config.py')
DISPLAY = importlib.util.module_from_spec(spec)
spec.loader.exec_module(DISPLAY)

RULE = re.compile(r'hl\.monitor\(\{ output = "([^"]+)", mode = "(\d+)x(\d+)@([\d.]+)", position = "(-?\d+)x(-?\d+)", '
                  r'scale = "([\d.]+)", transform = (\d) \}\)')


def raw(name, x=0, width=1920, height=1080, refresh=60.0, scale=1.0, description=None, modes=None):
    """Shaped like one entry of `hyprctl -j monitors all` (debug/HyprCtl.cpp getMonitorData)."""
    return {'id': 0 if name.startswith('eDP') else 1, 'name': name, 'description': description if description is not None else name + ' Panel SN1',
            'make': 'Make', 'model': 'Model', 'serial': 'SN1', 'width': width, 'height': height, 'refreshRate': refresh,
            'x': x, 'y': 0, 'scale': scale, 'transform': 0, 'focused': name.startswith('eDP'), 'dpmsStatus': True, 'vrr': False,
            'disabled': False, 'mirrorOf': 'none',
            'availableModes': modes or ['1920x1080@60.00Hz', '1920x1080@144.00Hz', '1280x720@60.00Hz', '2560x1440@59.95Hz']}


class FakeHyprland:
    def __init__(self, monitors, fail=(), drop_after=None):
        self.raw = monitors
        self.fail = set(fail)
        self.evals = []
        self.reloads = 0
        self.calls = 0
        self.drop_after = drop_after

    def monitors(self):
        self.calls += 1
        if 'monitors' in self.fail:
            raise DISPLAY.HyprlandError('HyprctlFailed')
        if self.drop_after is not None and self.calls > self.drop_after:
            self.raw = self.raw[:1]
        return [DISPLAY.normalize(item) for item in self.raw]

    def eval(self, code):
        self.evals.append(code)
        if 'eval' in self.fail or ('restore' in self.fail and len(self.evals) > 1):
            raise DISPLAY.HyprlandError('HyprlandRejected: error')
        if 'ignore' in self.fail:
            return
        for name, width, height, refresh, x, y, scale, transform in RULE.findall(code):
            for item in self.raw:
                if item['name'] == name:
                    # hyprctl prints refresh with five and scale with two decimals.
                    item.update(width=int(width), height=int(height), refreshRate=float(refresh), x=int(x), y=int(y),
                                scale=round(float(scale), 2), transform=int(transform))

    def reload(self):
        self.reloads += 1
        if 'reload' in self.fail:
            raise DISPLAY.HyprlandError('HyprctlFailed')


class Clock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


def plan_for(monitors, **changes):
    items = []
    for monitor in monitors:
        item = {key: monitor[key] for key in ('name', 'width', 'height', 'refresh', 'scale', 'transform', 'x', 'y')}
        item.update(changes.get(monitor['name'], {}))
        items.append(item)
    return {'monitors': items, 'primary': changes.get('primary', '')}


class Workspace(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.files = DISPLAY.Files(runtime=base / 'run', config=base / 'config')
        which = patch.object(DISPLAY.shutil, 'which', return_value=None); which.start(); self.addCleanup(which.stop)


class State(unittest.TestCase):
    def test_normalize_reads_real_hyprctl_shape_without_serial(self):
        monitor = DISPLAY.normalize(raw('eDP-1', scale=1.25))
        self.assertTrue(monitor['internal'])
        self.assertEqual(monitor['scale'], 1.25)
        self.assertNotIn('serial', monitor)
        self.assertIn({'width': 2560, 'height': 1440, 'refresh': 59.95, 'text': '2560x1440@59.95'}, monitor['modes'])

    def test_two_decimal_scale_is_recovered_as_hyprlands_n_over_120(self):
        # 2880x1800 at 1.6 (192/120) is clean; hyprctl would print 1.60, and 1.33 on 2560x1600 is not clean at all.
        self.assertEqual(DISPLAY.exact_scale(2880, 1800, 1.6), 192 / 120)
        self.assertTrue(DISPLAY.clean(1920, 1080, 1.25))
        self.assertFalse(DISPLAY.clean(1920, 1080, 1.75))

    def test_logical_size_follows_scale_and_rotation(self):
        item = {'width': 1920, 'height': 1080, 'scale': 1.5, 'transform': 1, 'x': 0, 'y': 0}
        self.assertEqual(DISPLAY.logical(item), (720, 1280))


class Validation(unittest.TestCase):
    def setUp(self):
        self.monitors = [DISPLAY.normalize(raw('eDP-1')), DISPLAY.normalize(raw('HDMI-A-1', x=1920))]

    def check(self, code, **changes):
        with self.assertRaisesRegex(ValueError, code):
            DISPLAY.validate(plan_for(self.monitors, **changes), self.monitors)

    def test_valid_change_is_normalized_with_the_mode_text_hyprland_reported(self):
        layout = DISPLAY.validate(plan_for(self.monitors, **{'HDMI-A-1': {'width': 2560, 'height': 1440, 'refresh': 59.95}}), self.monitors)
        self.assertEqual(layout['monitors'][0]['mode'], '2560x1440@59.95')

    def test_rejects_modes_scales_rotations_and_positions_the_screen_does_not_support(self):
        self.check('UnsupportedMode', **{'eDP-1': {'width': 3840, 'height': 2160}})
        self.check('UnsupportedMode', **{'eDP-1': {'refresh': 120.0}})
        self.check('InvalidScale', **{'eDP-1': {'scale': 1.75}})
        self.check('InvalidScale', **{'eDP-1': {'scale': 8}})
        self.check('InvalidTransform', **{'eDP-1': {'transform': 5}})
        self.check('InvalidPlan', **{'eDP-1': {'x': '0'}})
        self.check('InvalidPosition', **{'eDP-1': {'x': 99999, 'y': 0}})

    def test_rejects_overlapping_or_detached_screens(self):
        self.check('MonitorsOverlap', **{'HDMI-A-1': {'x': 1000}})
        self.check('MonitorsSeparated', **{'HDMI-A-1': {'x': 2000}})
        # Corners alone do not let the pointer cross.
        self.check('MonitorsSeparated', **{'HDMI-A-1': {'x': 1920, 'y': 1080}})

    def test_rejects_unknown_missing_or_disabled_monitors(self):
        plan = plan_for(self.monitors)
        plan['monitors'].append(dict(plan['monitors'][0], name='DP-9'))
        with self.assertRaisesRegex(ValueError, 'MonitorNotConnected'):
            DISPLAY.validate(plan, self.monitors)
        with self.assertRaisesRegex(ValueError, 'MonitorSetChanged'):
            DISPLAY.validate({'monitors': plan['monitors'][:1]}, self.monitors)
        with self.assertRaisesRegex(ValueError, 'InvalidPrimary'):
            DISPLAY.validate(dict(plan_for(self.monitors), primary='DP-9'), self.monitors)
        self.assertEqual(DISPLAY.validate(dict(plan_for(self.monitors), primary='DP-9'), self.monitors, 'DP-9')['primary'], 'DP-9')
        with self.assertRaisesRegex(ValueError, 'InvalidPlan'):
            DISPLAY.validate('nope', self.monitors)

    def test_rotation_changes_the_footprint_used_for_overlap(self):
        self.check('MonitorsOverlap', **{'eDP-1': {'transform': 1, 'x': 1000}})
        DISPLAY.validate(plan_for(self.monitors, **{'eDP-1': {'transform': 1, 'x': 840}}), self.monitors)


class Lua(unittest.TestCase):
    def test_rule_always_names_every_field_and_escapes_strings(self):
        rule = DISPLAY.monitor_rule('desc:Odd "Name"', {'mode': '1920x1080@60.00', 'x': -1920, 'y': 0, 'scale': 1.25, 'transform': 1})
        self.assertEqual(rule, 'hl.monitor({ output = "desc:Odd \\"Name\\"", mode = "1920x1080@60.00", position = "-1920x0", '
                               'scale = "1.25", transform = 1 })')
        with self.assertRaisesRegex(ValueError, 'InvalidName'):
            DISPLAY.lua_string('bad\nname')

    def test_saved_file_is_valid_lua_with_primary_rules(self):
        text = DISPLAY.lua_text({'monitors': {'desc:Make Model SN1': {'mode': '1920x1080@60.00', 'width': 1920, 'height': 1080, 'refresh': 60.0,
                                                                     'scale': 1.0, 'transform': 0, 'x': 0, 'y': 0}}, 'primary': 'HDMI-A-1'})
        self.assertIn('default_monitor = "HDMI-A-1"', text)
        self.assertIn('hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })', text)
        if DISPLAY.shutil.which('luac'):
            with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False) as handle:
                handle.write(text)
            self.addCleanup(Path(handle.name).unlink)
            subprocess.run(['luac', '-p', handle.name], check=True)


class GuardFlow(Workspace):
    def transaction(self, hyprland, **changes):
        monitors = hyprland.monitors()
        after = DISPLAY.validate(plan_for(monitors, **changes), monitors)
        return {'id': 'abc', 'before': DISPLAY.snapshot(monitors), 'after': after, 'monitors': monitors}

    def guard(self, hyprland):
        clock = Clock()
        return DISPLAY.Guard(hyprland, self.files, clock=clock, sleep=clock.sleep), clock

    def test_no_answer_restores_the_snapshot_after_the_timeout(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        guard, clock = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'reverted')
        self.assertGreaterEqual(clock.now, DISPLAY.TIMEOUT)
        self.assertEqual(hyprland.monitors()[0]['scale'], 1.0)
        self.assertEqual(self.files.status()['reason'], 'timeout')
        self.assertFalse(self.files.saved_path.exists())

    def test_keep_saves_only_after_the_answer(self):
        hyprland = FakeHyprland([raw('eDP-1'), raw('HDMI-A-1', x=1920)])
        transaction = self.transaction(hyprland, **{'HDMI-A-1': {'width': 1280, 'height': 720}}, primary='HDMI-A-1')
        self.files.decide('abc', 'keep')
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(transaction), 'kept')
        saved = json.loads(self.files.saved_path.read_text())
        self.assertEqual(saved['primary'], 'HDMI-A-1')
        self.assertEqual(saved['monitors']['desc:HDMI-A-1 Panel SN1']['mode'], '1280x720@60.00')
        self.assertIn('output = "desc:eDP-1 Panel SN1"', self.files.lua_path.read_text())
        self.assertFalse(self.files.status()['linked'])

    def test_answer_for_another_change_is_ignored(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        self.files.decide('other', 'keep')
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'reverted')

    def test_revert_and_stop_restore_immediately(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        self.files.decide('abc', 'revert')
        guard, clock = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'reverted')
        self.assertLess(clock.now, 1)
        self.files.decision_path.unlink()
        hyprland = FakeHyprland([raw('eDP-1')])
        guard, _ = self.guard(hyprland)
        guard.stop()
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'reverted')
        self.assertEqual(self.files.status()['reason'], 'stopped')

    def test_rejected_or_unapplied_change_is_rolled_back_as_failed(self):
        hyprland = FakeHyprland([raw('eDP-1')], fail={'ignore'})
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'failed')
        self.assertEqual(self.files.status()['reason'], 'ApplyMismatch')

    def test_unplugged_screen_ends_the_wait_with_the_old_layout(self):
        hyprland = FakeHyprland([raw('eDP-1'), raw('HDMI-A-1', x=1920)])
        transaction = self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}, 'HDMI-A-1': {'x': 1536}})
        hyprland.drop_after = hyprland.calls + 3
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(transaction), 'reverted')
        self.assertEqual(self.files.status()['reason'], 'disconnected')
        self.assertEqual(hyprland.monitors()[0]['scale'], 1.0)

    def test_failed_restore_falls_back_to_reload_and_reports_total_failure(self):
        hyprland = FakeHyprland([raw('eDP-1')], fail={'restore'})
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'reverted')
        self.assertEqual((hyprland.reloads, self.files.status()['method']), (1, 'reload'))
        hyprland = FakeHyprland([raw('eDP-1')], fail={'restore', 'reload'})
        guard, _ = self.guard(hyprland)
        self.assertEqual(guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}})), 'restore-failed')

    def test_unexpected_error_still_restores(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        guard, _ = self.guard(hyprland)
        with patch.object(self.files, 'decision', side_effect=RuntimeError('boom')):
            with self.assertRaises(RuntimeError):
                guard.run(self.transaction(hyprland, **{'eDP-1': {'scale': 1.25}}))
        self.assertEqual(self.files.status()['state'], 'reverted')
        self.assertEqual(hyprland.monitors()[0]['scale'], 1.0)


class Start(Workspace):
    def test_change_is_recorded_before_the_guard_starts_and_nothing_is_applied_here(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        launched = []
        result = DISPLAY.start(plan_for(hyprland.monitors(), **{'eDP-1': {'scale': 1.25}}), hyprland, self.files,
                               launch=launched.append, running=lambda: False)
        self.assertEqual(result['state'], 'starting')
        self.assertEqual(launched, [result['id']])
        self.assertEqual(hyprland.evals, [])
        stored = json.loads(self.files.transaction.read_text())
        self.assertEqual(stored['before']['monitors'][0]['scale'], 1.0)

    def test_without_a_guard_nothing_changes(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        with patch.dict(DISPLAY.os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'GuardUnavailable'):
                DISPLAY.start(plan_for(hyprland.monitors(), **{'eDP-1': {'scale': 1.25}}), hyprland, self.files, running=lambda: False)
        self.assertEqual(hyprland.evals, [])

    def test_second_change_waits_for_the_first(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        with self.assertRaisesRegex(ValueError, 'ChangeRunning'):
            DISPLAY.start(plan_for(hyprland.monitors(), **{'eDP-1': {'scale': 1.25}}), hyprland, self.files, launch=lambda _: None, running=lambda: True)

    def test_primary_only_is_saved_without_touching_screens(self):
        hyprland = FakeHyprland([raw('eDP-1'), raw('HDMI-A-1', x=1920)])
        result = DISPLAY.start(plan_for(hyprland.monitors(), primary='HDMI-A-1'), hyprland, self.files, launch=self.fail, running=lambda: False)
        self.assertEqual(result['state'], 'kept')
        saved = json.loads(self.files.saved_path.read_text())
        self.assertEqual((saved['primary'], saved['monitors']), ('HDMI-A-1', {}))
        self.assertEqual(DISPLAY.start(plan_for(hyprland.monitors(), primary='HDMI-A-1'), hyprland, self.files)['state'], 'unchanged')

    def test_answers_go_to_the_running_change_only(self):
        with self.assertRaisesRegex(ValueError, 'NoChange'):
            DISPLAY.answer(self.files, 'keep')
        self.files.report('abc', 'waiting')
        DISPLAY.answer(self.files, 'keep')
        self.assertEqual(self.files.decision('abc'), 'keep')

    def test_restore_command_works_without_the_guard(self):
        hyprland = FakeHyprland([raw('eDP-1')])
        monitors = hyprland.monitors()
        DISPLAY.write_atomic(self.files.transaction, json.dumps({'id': 'abc', 'before': DISPLAY.snapshot(monitors)}))
        hyprland.eval(DISPLAY.rules_code([dict(DISPLAY.snapshot(monitors)['monitors'][0], scale=1.25)]))
        self.assertEqual(DISPLAY.restore_now(hyprland, self.files)['state'], 'reverted')
        self.assertEqual(hyprland.monitors()[0]['scale'], 1.0)
        self.assertEqual(self.files.decision('abc'), 'revert')

    def test_saved_layout_keeps_other_monitors_and_drops_broken_entries(self):
        DISPLAY.write_atomic(self.files.saved_path, json.dumps({'version': 1, 'primary': '', 'monitors': {
            'DP-3': {'mode': '1920x1080@60.00', 'width': 1920, 'height': 1080, 'refresh': 60.0, 'scale': 1, 'transform': 0, 'x': 0, 'y': 0},
            'bad': {'mode': 'x'}}}))
        hyprland = FakeHyprland([raw('eDP-1')])
        monitors = hyprland.monitors()
        self.files.persist(DISPLAY.snapshot(monitors), monitors)
        self.assertEqual(sorted(self.files.saved()['monitors']), ['DP-3', 'desc:eDP-1 Panel SN1'])


class ManagedConfig(unittest.TestCase):
    def test_hyprland_lua_loads_the_saved_layout_last(self):
        tool = importlib.util.spec_from_file_location('config_tool_display', ROOT / 'scripts/config-tool.py')
        module = importlib.util.module_from_spec(tool)
        tool.loader.exec_module(module)
        text = module.Config(dry=True).lua()
        self.assertIn('shittim-monitors.lua', text)
        self.assertGreater(text.index('shittim-monitors.lua'), text.index('shittim-titlebars.lua'))
        self.assertFalse(module.allowed(Path('hypr/shittim-monitors.lua')))


if __name__ == '__main__':
    unittest.main()
