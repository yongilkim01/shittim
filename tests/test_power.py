"""Lock, idle and lid policy tests; no real hypridle, hyprlock, logind, suspend or screen changes."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


POLICY = load('power_policy', 'scripts/power-policy.py')
IDLE = load('idle_service', 'scripts/idle-service.py')
DESKTOP = load('desktop_tool_power', 'scripts/desktop-tool.py')
GUIDE = load('test_power_guide', 'scripts/test-power.py')


class Settings(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / 'config'
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=str(self.config)); self.env.start(); self.addCleanup(self.env.stop)
        self.personal = self.config / 'shittim/power.json'

    def test_defaults_keep_suspend_off_and_lid_on_system(self):
        settings, error = POLICY.read_settings(ROOT)
        self.assertEqual(error, '')
        for source in POLICY.SOURCES:
            self.assertEqual(settings[source]['suspend'], 0)
            self.assertEqual(settings[source]['lid'], 'system')
            self.assertEqual(settings[source]['lock'], 5)

    def test_rejects_values_outside_choices(self):
        base = json.loads((ROOT / 'config/power.json').read_text())
        for key, value in (('lock', 7), ('lock', True), ('screenOff', '10'), ('suspend', -1), ('lid', 'poweroff')):
            data = json.loads(json.dumps(base)); data['ac'][key] = value
            with self.assertRaises(ValueError, msg=(key, value)):
                POLICY.validate(data)
        with self.assertRaises(ValueError):
            POLICY.validate(dict(base, version=2))

    def test_update_writes_one_value_and_keeps_the_rest(self):
        changed = POLICY.update('battery', 'suspend', '30', ROOT)
        self.assertEqual(changed['battery']['suspend'], 30)
        saved = json.loads(self.personal.read_text())
        self.assertEqual(saved, changed)
        self.assertEqual(saved['ac'], POLICY.read_settings(ROOT)[0]['ac'])
        POLICY.update('ac', 'lid', 'ignore', ROOT)
        self.assertEqual(POLICY.read_settings(ROOT)[0]['ac']['lid'], 'ignore')
        self.assertEqual(POLICY.read_settings(ROOT)[0]['battery']['suspend'], 30)

    def test_update_refuses_invalid_and_keeps_file(self):
        POLICY.update('ac', 'lock', '10', ROOT)
        before = self.personal.read_text()
        for args in (('ac', 'lock', '7'), ('desk', 'lock', '5'), ('ac', 'password', '5'), ('ac', 'lid', 'reboot')):
            with self.assertRaises(ValueError):
                POLICY.update(*args, root=ROOT)
        self.assertEqual(self.personal.read_text(), before)
        self.assertEqual(POLICY.main(['set', 'ac', 'lock', '7']), 1)

    def test_broken_personal_file_falls_back_and_is_preserved_on_next_save(self):
        self.personal.parent.mkdir(parents=True); self.personal.write_text('{broken')
        settings, error = POLICY.read_settings(ROOT)
        self.assertEqual(error, 'PowerConfigInvalid')
        self.assertEqual(settings, POLICY.read_settings(ROOT)[0])
        POLICY.update('ac', 'lock', '10', ROOT)
        self.assertEqual((self.personal.parent / 'power.json.invalid').read_text(), '{broken')
        self.assertEqual(POLICY.read_settings(ROOT)[1], '')


class Hypridle(unittest.TestCase):
    def policy(self, **values):
        return dict({'lock': 5, 'screenOff': 10, 'suspend': 0, 'lid': 'system'}, **values)

    def test_generated_file_waits_for_lock_before_sleep(self):
        text = POLICY.hypridle_text(self.policy(), Path('/repo with space'))
        self.assertTrue(text.startswith(POLICY.MARKER))
        self.assertIn("lock_cmd = /usr/bin/bash '/repo with space/scripts/lock-screen.sh'", text)
        self.assertIn('before_sleep_cmd = loginctl lock-session', text)
        # Our lock_cmd is a wrapper, so hypridle's auto mode would not wait; 3 must be explicit.
        self.assertIn('inhibit_sleep = 3', text)
        self.assertNotIn('#', text.split('\n', 2)[2])

    def test_listeners_follow_settings_in_seconds(self):
        text = POLICY.hypridle_text(self.policy(lock=5, screenOff=10, suspend=30), Path('/r'))
        self.assertEqual(text.count('listener {'), 3)
        self.assertIn('timeout = 300\n    on-timeout = loginctl lock-session', text)
        self.assertIn("timeout = 600\n    on-timeout = /usr/bin/bash /r/scripts/power-action.sh screen-off\n    on-resume = /usr/bin/bash /r/scripts/power-action.sh screen-on", text)
        self.assertIn('timeout = 1800\n    on-timeout = /usr/bin/bash /r/scripts/power-action.sh suspend', text)

    def test_disabled_steps_have_no_listener(self):
        text = POLICY.hypridle_text(self.policy(lock=0, screenOff=0, suspend=0), Path('/r'))
        self.assertNotIn('listener', text)
        self.assertIn('before_sleep_cmd', text)


class PowerSource(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.sys = Path(self.temp.name)

    def supply(self, name, **files):
        path = self.sys / name; path.mkdir()
        for key, value in files.items():
            (path / key).write_text(value + '\n')

    def test_battery_without_mains_is_battery(self):
        self.supply('BAT0', type='Battery', scope='System')
        self.supply('ADP1', type='Mains', online='0')
        self.assertEqual(IDLE.power_source(self.sys), ('battery', True))

    def test_online_mains_or_usb_c_is_ac(self):
        self.supply('BAT0', type='Battery')
        self.supply('ucsi', type='USB', online='1')
        self.assertEqual(IDLE.power_source(self.sys), ('ac', True))

    def test_desktop_and_peripheral_batteries_use_ac(self):
        self.supply('hidpp_battery_0', type='Battery', scope='Device')
        self.assertEqual(IDLE.power_source(self.sys), ('ac', False))
        self.assertEqual(IDLE.power_source(self.sys / 'missing'), ('ac', False))

    def test_lid_reads_acpi_state(self):
        lid = self.sys / 'LID0'; lid.mkdir(); (lid / 'state').write_text('state:      closed\n')
        self.assertEqual(IDLE.lid_state(self.sys), 'closed')
        (lid / 'state').write_text('state:      open\n')
        self.assertEqual(IDLE.lid_state(self.sys), 'open')


class Supervisor(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=str(base / 'config')); self.env.start(); self.addCleanup(self.env.stop)
        self.state = {'source': ('battery', True), 'lid': 'open', 'docked': False, 'external': False}
        self.actions = []
        probe = {'source': lambda: self.state['source'], 'lid': lambda: self.state['lid'], 'docked': lambda: self.state['docked'],
                 'logind': lambda: {'battery': 'suspend', 'ac': 'suspend', 'docked': 'ignore'},
                 'external': lambda: self.state['external'], 'action': lambda *args: self.actions.append(args)}
        self.supervisor = IDLE.Supervisor(ROOT, base / 'run', probe)
        self.addCleanup(self.supervisor.stop)
        self.started = []
        def ensure(child, args):
            if child.args != args:  # like Child.ensure: a running child with the same arguments is kept
                self.started.append((child.name, args)); child.args = args
            return True
        patcher = patch.object(IDLE.Child, 'ensure', autospec=True, side_effect=ensure); patcher.start(); self.addCleanup(patcher.stop)
        running = patch.object(IDLE.Child, 'running', autospec=True, side_effect=lambda child: child.args is not None)
        running.start(); self.addCleanup(running.stop)
        stop = patch.object(IDLE.Child, 'stop', autospec=True, side_effect=lambda child: setattr(child, 'args', None))
        stop.start(); self.addCleanup(stop.stop)

    def test_tick_writes_config_for_current_source_and_status(self):
        status = self.supervisor.tick()
        self.assertEqual(status['source'], 'battery')
        self.assertEqual(status['idle'], 'running')
        self.assertEqual(status['applied'], POLICY.read_settings(ROOT)[0]['battery'])
        self.assertIn('timeout = 600', self.supervisor.config.read_text())
        self.assertEqual(json.loads(self.supervisor.status_path.read_text())['lid']['system']['battery'], 'suspend')
        self.state['source'] = ('ac', True)
        self.supervisor.tick()
        self.assertIn('timeout = 900', self.supervisor.config.read_text())
        self.assertEqual([name for name, _ in self.started].count('hypridle'), 2)

    def test_unchanged_policy_does_not_restart_hypridle(self):
        self.supervisor.tick(); self.supervisor.tick(); self.supervisor.tick()
        self.assertEqual([name for name, _ in self.started].count('hypridle'), 1)

    def test_external_hypridle_is_left_alone(self):
        self.state['external'] = True
        self.assertEqual(self.supervisor.tick()['idle'], 'external')
        self.assertFalse(self.supervisor.config.exists())
        self.assertEqual(self.started, [])

    def test_system_lid_policy_takes_no_inhibitor(self):
        self.state['lid'] = 'closed'
        status = self.supervisor.tick()
        self.assertFalse(status['lid']['inhibited'])
        self.assertNotIn('lid-inhibitor', [name for name, _ in self.started])
        self.assertEqual(self.actions, [])

    def test_lid_close_suspends_only_on_transition_and_not_docked(self):
        POLICY.update('battery', 'lid', 'suspend', ROOT)
        status = self.supervisor.tick()
        self.assertTrue(status['lid']['inhibited'])
        args = dict(self.started)['lid-inhibitor']
        self.assertIn('--what=handle-lid-switch', args); self.assertIn('--mode=block', args)
        self.state['lid'] = 'closed'; self.supervisor.tick(); self.supervisor.tick()
        self.assertEqual(self.actions, [('suspend',)])
        self.state['lid'] = 'open'; self.supervisor.tick()
        self.state['docked'] = True; self.state['lid'] = 'closed'; self.supervisor.tick()
        self.assertEqual(self.actions, [('suspend',)])

    def test_lid_screen_off_locks_first_and_restores_on_open(self):
        POLICY.update('battery', 'lid', 'screen-off', ROOT)
        self.supervisor.tick()
        self.state['lid'] = 'closed'; self.supervisor.tick()
        self.state['lid'] = 'open'; self.supervisor.tick()
        self.assertEqual(self.actions, [('lock',), ('screen-off',), ('screen-on',)])

    def test_refused_lid_inhibitor_reports_and_does_not_act(self):
        POLICY.update('battery', 'lid', 'suspend', ROOT)
        with patch.object(self.supervisor.lid_guard, 'ensure', return_value=False):
            self.state['lid'] = 'closed'
            status = self.supervisor.tick()
        self.assertEqual(status['lid']['error'], 'LidInhibitFailed')
        self.assertEqual(self.actions, [])


class Child(unittest.TestCase):
    def test_restart_budget_stops_spinning(self):
        child = IDLE.Child('test')
        with patch.object(IDLE.subprocess, 'Popen', side_effect=OSError):
            results = [child.ensure(['missing-binary']) for _ in range(5)]
        self.assertEqual(results, [False] * 5)
        self.assertEqual(len(child.starts), 3)


class LockScreen(unittest.TestCase):
    def test_template_uses_repository_assets_and_status_script(self):
        text = DESKTOP.lock_text(ROOT)
        self.assertTrue(text.startswith('# Managed by Shittim'))
        self.assertNotIn('@ROOT', text)
        self.assertIn('path = ' + str(ROOT) + '/assets/wallpapers/shittim-city.png', text)
        template = (ROOT / 'config/templates/shittim-lock.conf.in').read_text()
        widgets = []
        for block in template.split('\n}\n'):
            path = re.search(r'path = @ROOT@/(\S+)', block)
            if path:
                size = re.search(r'\n    size = (\d+)', block)
                widgets.append((block.strip().split(' ', 1)[0].split('\n')[-1], path[1], size[1] if size else ''))
        self.assertEqual([kind for kind, _, _ in widgets], ['background', 'image', 'image'])
        for kind, asset, size in widgets:
            self.assertTrue((ROOT / asset).is_file(), asset)
            if kind == 'image':
                # hyprlock minifies with GL_LINEAR and no mipmaps; a source much larger than 2x breaks thin lines.
                width, height = struct.unpack('>II', (ROOT / asset).read_bytes()[16:24])
                self.assertLessEqual(min(width, height), int(size) * 2, asset)

    def test_template_never_handles_secrets_and_keeps_pam_with_hyprlock(self):
        template = (ROOT / 'config/templates/shittim-lock.conf.in').read_text()
        self.assertIn('input-field', template)
        self.assertNotIn('pam', template.split('\n', 3)[3].lower())
        for line in template.splitlines():
            if not line.lstrip().startswith('#'):
                self.assertNotIn('#', line, line)

    def test_repository_path_with_hash_is_refused(self):
        with self.assertRaises(ValueError):
            DESKTOP.lock_text(Path('/tmp/a#b'))


class Guide(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=str(base / 'config'), XDG_RUNTIME_DIR=str(base / 'run'), XDG_STATE_HOME=str(base / 'state'))
        self.env.start(); self.addCleanup(self.env.stop)
        self.personal = base / 'config/shittim/power.json'

    def test_settings_restore_puts_back_the_exact_file_or_removes_it(self):
        settings = GUIDE.Settings()
        settings.set('ac', lock=1, screenOff=2)
        self.assertEqual(json.loads(self.personal.read_text())['ac']['lock'], 1)
        settings.restore()
        self.assertFalse(self.personal.exists())
        POLICY.update('battery', 'lock', '10', ROOT)
        original = self.personal.read_bytes()
        settings = GUIDE.Settings()
        settings.set('battery', lock=1, suspend=0)
        settings.restore()
        self.assertEqual(self.personal.read_bytes(), original)

    def test_resume_without_lock_is_a_failure(self):
        tester = GUIDE.Tester(ask=lambda prompt: '', out=lambda text: None)
        clock = iter([0, 100, 100])
        with patch.object(GUIDE, 'slept_seconds', side_effect=lambda: next(clock)),              patch.object(GUIDE, 'locked', return_value=False):
            tester.suspend()
        name, outcome, detail = tester.results[-1]
        self.assertEqual(outcome, 'FAIL')
        self.assertIn('보안', detail)

    def test_interrupted_run_restores_settings_and_keep_awake(self):
        tester = GUIDE.Tester(ask=lambda prompt: '', out=lambda text: None)
        calls = []
        def boom(source):
            tester.settings.set('ac', lock=1); tester.keep_awake_on = True
            raise KeyboardInterrupt
        with patch.object(tester, 'check_service', return_value={'source': 'ac', 'hasBattery': False}),              patch.object(tester, 'manual_lock'), patch.object(tester, 'control_center_lock'), patch.object(tester, 'screen_wake'),              patch.object(tester, 'auto_lock_and_screen_off', side_effect=boom),              patch.object(tester, 'ipc', side_effect=lambda function: calls.append(function) or (0, '')):
            with self.assertRaises(KeyboardInterrupt):
                tester.run(False)
        self.assertFalse(self.personal.exists())
        self.assertEqual(calls, ['toggleKeepAwake'])

    def screen_wake(self, wakes):
        """Runs the screen wake step with a fake Hyprland; wakes(options) says whether the screen came back on its own."""
        tester = GUIDE.Tester(ask=lambda prompt: '', out=lambda text: None)
        options = {'key_press_enables_dpms': True, 'mouse_move_enables_dpms': True}
        state = {'on': True}
        history, actions = [], []
        def set_wake(values):
            options.update(values); history.append(dict(options)); return True
        def action(name):
            actions.append(name)
            state['on'] = name == 'screen-on' or wakes(options)
        with patch.object(GUIDE, 'wake_option', side_effect=lambda key: options[key]), \
             patch.object(GUIDE, 'set_wake', side_effect=set_wake), patch.object(GUIDE, 'power_action', side_effect=action), \
             patch.object(GUIDE, 'screens_on', side_effect=lambda: [state['on']]), patch.object(GUIDE.time, 'sleep'), \
             patch.object(GUIDE, 'input_devices', return_value={'keyboards': ['fcitx-virtual'], 'mice': [], 'touch': [], 'tablets': []}):
            tester.screen_wake()
        self.assertTrue(all(any(values.values()) for values in history))
        self.assertEqual(history[-1], {'key_press_enables_dpms': True, 'mouse_move_enables_dpms': True})
        self.assertEqual(actions[-1], 'screen-on')
        self.assertTrue(state['on'])
        return tester.results[-1]

    def test_screen_wake_names_the_input_side_and_always_restores(self):
        self.assertEqual(self.screen_wake(lambda options: False)[1], 'PASS')
        name, outcome, detail = self.screen_wake(lambda options: options['key_press_enables_dpms'])
        self.assertEqual(outcome, 'FAIL')
        self.assertIn('키보드 쪽', detail)
        self.assertIn('fcitx-virtual', detail)
        self.assertIn('마우스·터치패드', self.screen_wake(lambda options: options['mouse_move_enables_dpms'])[2])

    def test_requires_hyprland_session(self):
        with patch.dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=''):
            self.assertEqual(GUIDE.main([]), 1)
        self.assertEqual(GUIDE.main(['--reboot']), 2)


@unittest.skipUnless(shutil.which('bash') and os.name != 'nt', 'Linux Bash 필요')
class Scripts(unittest.TestCase):
    def run_script(self, *args, env=None):
        return subprocess.run(['bash', str(ROOT / 'scripts/power-action.sh'), *args], capture_output=True, text=True,
                              env=dict(os.environ, **(env or {})), timeout=10)

    def test_power_action_requires_hyprland_and_known_action(self):
        result = self.run_script('suspend', env={'HYPRLAND_INSTANCE_SIGNATURE': ''})
        self.assertNotEqual(result.returncode, 0)
        result = self.run_script('reboot', '--dry-run', env={'HYPRLAND_INSTANCE_SIGNATURE': 'test'})
        self.assertNotEqual(result.returncode, 0)

    def test_suspend_dry_run_plans_only(self):
        result = self.run_script('suspend', '--dry-run', env={'HYPRLAND_INSTANCE_SIGNATURE': 'test'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('systemctl suspend', result.stdout)

    def test_suspend_refuses_when_lock_never_engages(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        bin_dir = Path(temp.name)
        log = bin_dir / 'calls'
        for name, body in (('hyprctl', 'echo \'{"locked": false}\''), ('systemctl', 'echo systemctl "$@" >> ' + str(log)),
                           ('setsid', 'exit 0'), ('notify-send', 'exit 0'), ('sleep', 'exit 0')):
            path = bin_dir / name; path.write_text('#!/bin/sh\n' + body + '\n'); path.chmod(0o755)
        result = self.run_script('suspend', env={'HYPRLAND_INSTANCE_SIGNATURE': 'test', 'PATH': str(bin_dir) + ':' + os.environ['PATH']})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(log.exists())

    def test_suspend_runs_after_lock_confirmed(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        bin_dir = Path(temp.name)
        log = bin_dir / 'calls'
        for name, body in (('hyprctl', 'echo \'{"locked": true}\''), ('systemctl', 'echo systemctl "$@" >> ' + str(log))):
            path = bin_dir / name; path.write_text('#!/bin/sh\n' + body + '\n'); path.chmod(0o755)
        result = self.run_script('suspend', env={'HYPRLAND_INSTANCE_SIGNATURE': 'test', 'PATH': str(bin_dir) + ':' + os.environ['PATH']})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_text(), 'systemctl suspend\n')

    def test_lock_status_line_reads_sysfs_only(self):
        result = subprocess.run(['bash', str(ROOT / 'scripts/lock-status.sh')], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.splitlines()), 1)


if __name__ == '__main__':
    unittest.main()
