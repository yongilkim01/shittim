#!/usr/bin/env python3
"""Applies power.json for the current power source: runs hypridle with a generated file and handles the lid.

Read-only towards the system configuration: logind.conf and PAM are never written. The lid is only taken over
(through a logind handle-lid-switch inhibitor) when the user picked something other than the system setting.
Writes its applied state to $XDG_RUNTIME_DIR/shittim/power-status.json for the shell.
"""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
INTERNAL = ('eDP', 'LVDS', 'DSI')


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


policy = module('shittim_power_policy', 'power-policy.py')


def run(args, timeout=5):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ''


def power_source(sysfs=Path('/sys/class/power_supply')):
    """('battery'|'ac', has_battery). Machines without a system battery always use the AC policy."""
    batteries, online = False, False
    try:
        entries = list(sysfs.iterdir())
    except OSError:
        return 'ac', False
    for entry in entries:
        try:
            kind = (entry / 'type').read_text().strip()
            if kind == 'Battery':
                scope = (entry / 'scope').read_text().strip() if (entry / 'scope').exists() else 'System'
                batteries = batteries or scope == 'System'
            elif kind in ('Mains', 'USB', 'USB_C', 'USB_PD') and (entry / 'online').read_text().strip() == '1':
                online = True
        except OSError:
            continue
    return ('ac' if online or not batteries else 'battery'), batteries


def lid_state(acpi=Path('/proc/acpi/button/lid')):
    """'open' | 'closed' | '' (no lid). Falls back to logind when ACPI does not expose the switch."""
    try:
        for entry in sorted(acpi.iterdir()):
            text = (entry / 'state').read_text()
            if 'closed' in text:
                return 'closed'
            if 'open' in text:
                return 'open'
    except OSError:
        pass
    code, output = run(['busctl', '--system', 'get-property', 'org.freedesktop.login1', '/org/freedesktop/login1',
                        'org.freedesktop.login1.Manager', 'LidClosed'])
    if code == 0 and output.split()[:1] == ['b']:
        return 'closed' if output.split()[1] == 'true' else 'open'
    return ''


def logind_lid():
    values = {}
    for key, name in (('battery', 'HandleLidSwitch'), ('ac', 'HandleLidSwitchExternalPower'), ('docked', 'HandleLidSwitchDocked')):
        code, output = run(['busctl', '--system', 'get-property', 'org.freedesktop.login1', '/org/freedesktop/login1',
                            'org.freedesktop.login1.Manager', name])
        parts = output.split(None, 1)
        values[key] = parts[1].strip().strip('"') if code == 0 and len(parts) == 2 and parts[0] == 's' else ''
    return values


def docked():
    code, output = run(['hyprctl', '-j', 'monitors'])
    try:
        monitors = json.loads(output) if code == 0 else []
    except ValueError:
        return False
    return any(not str(item.get('name', '')).startswith(INTERNAL) for item in monitors if isinstance(item, dict))


def write_atomic(path, text):
    path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.shittim-', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(text)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


class Child:
    """One supervised helper process. Restarts are limited so a broken setup cannot spin."""
    def __init__(self, name):
        self.name, self.process, self.args, self.starts = name, None, None, []

    def running(self):
        return self.process is not None and self.process.poll() is None

    def ensure(self, args):
        if self.running() and self.args == args:
            return True
        self.stop()
        now = time.monotonic()
        self.starts = [moment for moment in self.starts if now - moment < 60]
        if len(self.starts) >= 3:
            return False
        self.starts.append(now)
        try:
            self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            self.process = None
            return False
        self.args = args
        return True

    def stop(self):
        if self.running():
            self.process.terminate()
            try:
                self.process.wait(3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        self.process, self.args = None, None


class Supervisor:
    def __init__(self, root=ROOT, runtime=None, probe=None):
        runtime = Path(runtime or os.environ.get('XDG_RUNTIME_DIR') or '/run/user/' + str(os.getuid())) / 'shittim'
        self.root, self.config, self.status_path = Path(root), runtime / 'hypridle.conf', runtime / 'power-status.json'
        self.idle, self.lid_guard = Child('hypridle'), Child('lid-inhibitor')
        self.probe = probe or {'source': power_source, 'lid': lid_state, 'docked': docked, 'logind': logind_lid,
                               'external': self.external_hypridle, 'action': self.action}
        self.system_lid = self.probe['logind']()
        self.last_lid, self.lid_screen_off, self.written = '', False, None

    def external_hypridle(self):
        code, output = run(['pgrep', '-u', str(os.getuid()), '-x', 'hypridle'])
        mine = self.idle.process.pid if self.idle.running() else None
        return code == 0 and any(int(pid) != mine for pid in output.split() if pid.isdigit())

    def action(self, *args):
        subprocess.Popen(['/usr/bin/bash', str(self.root / 'scripts/power-action.sh'), *args],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def apply_idle(self, current):
        text = policy.hypridle_text(current, self.root)
        if not self.idle.running() and self.probe['external']():
            return 'external'
        if self.written != text:
            write_atomic(self.config, text)
            self.written = text
            self.idle.stop()
        return 'running' if self.idle.ensure(['hypridle', '--config', str(self.config)]) else 'failed'

    def apply_lid(self, current):
        wanted = current['lid']
        state = self.probe['lid']()
        result = {'policy': wanted, 'system': self.system_lid, 'present': bool(state), 'inhibited': False, 'error': ''}
        if not state or wanted == 'system':
            self.lid_guard.stop()
            self.last_lid = state
            return result
        args = ['systemd-inhibit', '--what=handle-lid-switch', '--who=Shittim', '--why=덮개 동작을 Shittim 설정으로 처리', '--mode=block', 'sleep', 'infinity']
        starting = not self.lid_guard.running()
        if self.lid_guard.ensure(args) and starting:
            time.sleep(0.2)  # systemd-inhibit exits at once when logind refuses the lock
        result['inhibited'] = self.lid_guard.running()
        if not result['inhibited']:
            # logind keeps handling the lid with its own setting; report instead of acting twice.
            result['error'] = 'LidInhibitFailed'
            self.last_lid = state
            return result
        if state != self.last_lid:
            if state == 'closed' and not self.probe['docked']():
                if wanted == 'suspend':
                    self.probe['action']('suspend')
                elif wanted == 'screen-off':
                    self.probe['action']('lock')
                    self.probe['action']('screen-off')
                    self.lid_screen_off = True
            elif state == 'open' and self.lid_screen_off:
                self.probe['action']('screen-on')
                self.lid_screen_off = False
        self.last_lid = state
        return result

    def tick(self):
        settings, error = policy.read_settings(self.root)
        source, has_battery = self.probe['source']()
        current = settings[source]
        status = {'version': 1, 'time': int(time.time()), 'source': source, 'hasBattery': has_battery,
                  'settingsError': error, 'applied': current, 'idle': self.apply_idle(current),
                  'lid': self.apply_lid(current)}
        write_atomic(self.status_path, json.dumps(status, ensure_ascii=False) + '\n')
        return status

    def stop(self):
        self.idle.stop()
        self.lid_guard.stop()
        for path in (self.status_path, self.config):
            try:
                path.unlink()
            except OSError:
                pass


def main():
    if '--check' in sys.argv[1:]:
        settings, error = policy.read_settings()
        source, has_battery = power_source()
        print(json.dumps({'source': source, 'hasBattery': has_battery, 'lid': lid_state(), 'settingsError': error,
                          'logind': logind_lid(), 'hypridle': policy.hypridle_text(settings[source], ROOT)}, ensure_ascii=False))
        return 0
    supervisor = Supervisor()
    stopping = []
    signal.signal(signal.SIGTERM, lambda *_: stopping.append(True))
    signal.signal(signal.SIGINT, lambda *_: stopping.append(True))
    try:
        while not stopping:
            supervisor.tick()
            for _ in range(10):
                if stopping:
                    break
                time.sleep(0.2)
    finally:
        supervisor.stop()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
