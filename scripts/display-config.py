#!/usr/bin/env python3
"""Display layout: reads Hyprland monitors, validates a requested layout, applies it under a guard that restores the
previous layout unless the user keeps it, and is the single writer of the saved layout.

  list            connected monitors, the saved primary display and whether saving is wired into hyprland.lua
  apply [PLAN]    plan JSON as the argument or on stdin. Validates it, records the rollback snapshot and starts `guard` as its own
                  systemd user unit, so the rollback does not depend on Quickshell or the settings window
  keep | revert   answers the running change
  restore         puts the snapshot of the last change back now; works from a TTY without the guard
  reset           removes the saved layout and reloads Hyprland's own monitor rules
  guard ID        internal: applies, waits for an answer, then saves or restores

Nothing is written to Hyprland's own files. Kept layouts go to shittim/display.json and the generated
hypr/shittim-monitors.lua, which the managed hyprland.lua loads after the original settings.
"""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

TIMEOUT = 15
SETTLE = 5
UNIT = 'shittim-display-guard'
MARKER = '-- Managed by Shittim: monitor layout kept in the display settings. Change it there (shittim/display.json).'
MODE = re.compile(r'^(\d+)x(\d+)@(\d+(?:\.\d+)?)Hz$')
INTERNAL = ('eDP', 'LVDS', 'DSI')
LIMIT = 32768


class HyprlandError(Exception):
    pass


class Hyprland:
    """The only place that talks to Hyprland. Rules go through `hyprctl eval` because the session uses the Lua config."""

    def __init__(self, runner=subprocess.run):
        self.runner = runner

    def command(self, *args):
        # From a TTY there is no instance signature; -i 0 selects the running Hyprland.
        base = ['hyprctl'] + ([] if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') else ['-i', '0'])
        try:
            result = self.runner(base + list(args), capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            raise HyprlandError('HyprctlFailed')
        if result.returncode != 0:
            raise HyprlandError('HyprctlFailed')
        return result.stdout

    def monitors(self):
        try:
            data = json.loads(self.command('-j', 'monitors', 'all'))
        except ValueError:
            raise HyprlandError('HyprctlFailed')
        return [normalize(item) for item in data if isinstance(item, dict) and item.get('name')]

    def eval(self, code):
        output = self.command('eval', code).strip()
        if output != 'ok':
            raise HyprlandError('HyprlandRejected: ' + output.splitlines()[0][:200] if output else 'HyprlandRejected')

    def reload(self):
        self.command('reload')


# ---- monitor state -------------------------------------------------------------------------------------------------

def clean(width, height, scale):
    """Hyprland's own check (helpers/Monitor.cpp): at n/120 the logical size must be whole pixels."""
    step = round(scale * 120)
    if step <= 0:
        return False
    value = step / 120
    return (width / value).is_integer() and (height / value).is_integer()


def exact_scale(width, height, reported):
    """hyprctl prints the scale with two decimals; recover the clean n/120 value Hyprland actually uses."""
    centre = round(reported * 120)
    found = [step / 120 for step in range(centre - 2, centre + 3) if step > 0 and clean(width, height, step / 120)
             and abs(step / 120 - reported) <= 0.005 + 1e-9]
    return min(found, key=lambda value: abs(value - reported)) if found else reported


def normalize(raw):
    modes, seen = [], set()
    for text in raw.get('availableModes') or []:
        match = MODE.match(str(text))
        if not match:
            continue
        width, height, refresh = int(match.group(1)), int(match.group(2)), match.group(3)
        if (width, height, refresh) in seen:
            continue
        seen.add((width, height, refresh))
        modes.append({'width': width, 'height': height, 'refresh': float(refresh), 'text': '{}x{}@{}'.format(width, height, refresh)})
    width, height = int(raw.get('width') or 0), int(raw.get('height') or 0)
    name = str(raw['name'])
    return {
        'name': name, 'id': int(raw.get('id', -1)),
        'description': str(raw.get('description') or ''), 'make': str(raw.get('make') or ''), 'model': str(raw.get('model') or ''),
        'internal': name.startswith(INTERNAL),
        'width': width, 'height': height, 'refresh': round(float(raw.get('refreshRate') or 0), 3),
        'x': int(raw.get('x') or 0), 'y': int(raw.get('y') or 0),
        'scale': exact_scale(width, height, float(raw.get('scale') or 1)), 'transform': int(raw.get('transform') or 0),
        'disabled': bool(raw.get('disabled')), 'mirrored': str(raw.get('mirrorOf') or 'none') not in ('none', ''),
        'focused': bool(raw.get('focused')), 'modes': modes,
    }


def editable(monitors):
    return {monitor['name']: monitor for monitor in monitors if not monitor['disabled'] and not monitor['mirrored']}


def current_mode(monitor):
    same = [mode for mode in monitor['modes'] if mode['width'] == monitor['width'] and mode['height'] == monitor['height']]
    if same:
        best = min(same, key=lambda mode: abs(mode['refresh'] - monitor['refresh']))
        if abs(best['refresh'] - monitor['refresh']) < 0.02:
            return best
    return {'width': monitor['width'], 'height': monitor['height'], 'refresh': monitor['refresh'],
            'text': '{}x{}@{:.3f}'.format(monitor['width'], monitor['height'], monitor['refresh'])}


def logical(item):
    width, height = round(item['width'] / item['scale']), round(item['height'] / item['scale'])
    return (height, width) if item['transform'] % 2 else (width, height)


def rect(item):
    width, height = logical(item)
    return item['x'], item['y'], item['x'] + width, item['y'] + height


def overlap(a, b):
    return min(a[2], b[2]) > max(a[0], b[0]) and min(a[3], b[3]) > max(a[1], b[1])


def touching(a, b):
    side = (a[2] == b[0] or b[2] == a[0]) and min(a[3], b[3]) > max(a[1], b[1])
    stacked = (a[3] == b[1] or b[3] == a[1]) and min(a[2], b[2]) > max(a[0], b[0])
    return side or stacked


def check_layout(items):
    rects = [rect(item) for item in items]
    for index, first in enumerate(rects):
        for second in rects[index + 1:]:
            if overlap(first, second):
                raise ValueError('MonitorsOverlap')
    # Every screen must share an edge with the rest; across a gap the pointer cannot move between them.
    reached, queue = {0}, [0]
    while queue and rects:
        current = queue.pop()
        for index, other in enumerate(rects):
            if index not in reached and touching(rects[current], other):
                reached.add(index)
                queue.append(index)
    if rects and len(reached) != len(rects):
        raise ValueError('MonitorsSeparated')


def validate(plan, monitors, saved_primary=''):
    """Returns the normalized layout for every editable monitor or raises ValueError with an error code."""
    if not isinstance(plan, dict) or not isinstance(plan.get('monitors'), list):
        raise ValueError('InvalidPlan')
    active = editable(monitors)
    result = {}
    for item in plan['monitors']:
        if not isinstance(item, dict) or not isinstance(item.get('name'), str):
            raise ValueError('InvalidPlan')
        name = item['name']
        if name not in active:
            raise ValueError('MonitorNotConnected')
        if name in result:
            raise ValueError('InvalidPlan')
        monitor = active[name]
        try:
            values = {key: item[key] for key in ('width', 'height', 'x', 'y', 'transform')}
            if any(isinstance(value, bool) or not isinstance(value, int) for value in values.values()):
                raise TypeError
            refresh, scale = float(item['refresh']), float(item['scale'])
        except (KeyError, TypeError, ValueError):
            raise ValueError('InvalidPlan')
        modes = monitor['modes'] + [current_mode(monitor)]
        mode = next((mode for mode in modes if mode['width'] == values['width'] and mode['height'] == values['height']
                     and abs(mode['refresh'] - refresh) < 0.006), None)
        if mode is None:
            raise ValueError('UnsupportedMode')
        if not 0.5 <= scale <= 4 or not clean(mode['width'], mode['height'], scale):
            raise ValueError('InvalidScale')
        # Only the four rotations are offered; a flipped transform set elsewhere is kept as it is.
        if values['transform'] not in (0, 1, 2, 3) and values['transform'] != monitor['transform']:
            raise ValueError('InvalidTransform')
        if abs(values['x']) > LIMIT or abs(values['y']) > LIMIT:
            raise ValueError('InvalidPosition')
        result[name] = {'name': name, 'mode': mode['text'], 'width': mode['width'], 'height': mode['height'], 'refresh': mode['refresh'],
                        'scale': round(scale * 120) / 120, 'transform': values['transform'], 'x': values['x'], 'y': values['y']}
    if set(result) != set(active):
        raise ValueError('MonitorSetChanged')
    items = [result[name] for name in sorted(result)]
    check_layout(items)
    primary = plan.get('primary', '')
    if not isinstance(primary, str) or (primary and primary not in active and primary != saved_primary):
        raise ValueError('InvalidPrimary')
    return {'monitors': items, 'primary': primary}


def snapshot(monitors, primary=''):
    items = []
    for monitor in sorted(editable(monitors).values(), key=lambda item: item['name']):
        mode = current_mode(monitor)
        items.append({'name': monitor['name'], 'mode': mode['text'], 'width': monitor['width'], 'height': monitor['height'],
                      'refresh': mode['refresh'], 'scale': monitor['scale'], 'transform': monitor['transform'],
                      'x': monitor['x'], 'y': monitor['y']})
    return {'monitors': items, 'primary': primary}


def matches(monitors, items):
    state = {monitor['name']: monitor for monitor in monitors}
    for item in items:
        monitor = state.get(item['name'])
        if (monitor is None or monitor['width'] != item['width'] or monitor['height'] != item['height']
                or abs(monitor['refresh'] - item['refresh']) > 0.05 or abs(monitor['scale'] - item['scale']) > 0.006
                or monitor['transform'] != item['transform'] or monitor['x'] != item['x'] or monitor['y'] != item['y']):
            return False
    return True


def same_layout(first, second):
    keys = ('name', 'width', 'height', 'refresh', 'scale', 'transform', 'x', 'y')
    shape = lambda layout: [tuple(round(item[key], 4) if isinstance(item[key], float) else item[key] for key in keys) for item in layout['monitors']]
    return shape(first) == shape(second)


# ---- Lua -------------------------------------------------------------------------------------------------------------

def lua_string(text):
    if any(ord(character) < 32 for character in text):
        raise ValueError('InvalidName')
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def scale_text(scale):
    return ('%.6f' % scale).rstrip('0').rstrip('.')


def monitor_rule(output, item):
    # transform is always written: a rule without it resets the rotation.
    return 'hl.monitor({{ output = {}, mode = {}, position = {}, scale = {}, transform = {} }})'.format(
        lua_string(output), lua_string(item['mode']), lua_string('{}x{}'.format(item['x'], item['y'])),
        lua_string(scale_text(item['scale'])), int(item['transform']))


def rules_code(items):
    return ' '.join(monitor_rule(item['name'], item) for item in items)


# ---- files -----------------------------------------------------------------------------------------------------------

def write_atomic(path, text, mode=0o600):
    path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.shittim-', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(text)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default=None):
    try:
        if path.stat().st_size > 262144:
            return default
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError, UnicodeError):
        return default


class Files:
    def __init__(self, runtime=None, config=None):
        self.runtime = Path(runtime or os.environ.get('XDG_RUNTIME_DIR') or '/nonexistent') / 'shittim'
        self.config = Path(config or os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
        self.transaction = self.runtime / 'display-transaction.json'
        self.status_path = self.runtime / 'display-status.json'
        self.decision_path = self.runtime / 'display-decision'
        self.saved_path = self.config / 'shittim/display.json'
        self.lua_path = self.config / 'hypr/shittim-monitors.lua'
        self.hyprland = self.config / 'hypr/hyprland.lua'

    def status(self):
        return read_json(self.status_path, {}) or {}

    def report(self, transaction, state, **fields):
        data = {'id': transaction, 'state': state, 'time': time.time()}
        data.update(fields)
        write_atomic(self.status_path, json.dumps(data, ensure_ascii=False) + '\n')

    def decision(self, transaction):
        data = read_json(self.decision_path, {}) or {}
        return data.get('decision') if data.get('id') == transaction else None

    def decide(self, transaction, decision):
        write_atomic(self.decision_path, json.dumps({'id': transaction, 'decision': decision}) + '\n')

    def saved(self):
        data = read_json(self.saved_path, {})
        if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('monitors'), dict):
            return {'version': 1, 'monitors': {}, 'primary': ''}
        primary = data.get('primary') if isinstance(data.get('primary'), str) else ''
        return {'version': 1, 'monitors': {key: value for key, value in data['monitors'].items() if valid_saved(key, value)}, 'primary': primary}

    def linked(self):
        try:
            return 'shittim-monitors.lua' in self.hyprland.read_text(encoding='utf-8')
        except (OSError, UnicodeError):
            return False

    def persist(self, layout, monitors, screens=True):
        """Merges the kept layout into display.json (other monitors' saved entries stay) and regenerates the Lua file."""
        saved = self.saved()
        for item in layout['monitors'] if screens else []:
            key = saved_key(item['name'], monitors)
            saved['monitors'] = {name: value for name, value in saved['monitors'].items() if name not in (key, item['name'])}
            saved['monitors'][key] = {field: item[field] for field in ('mode', 'width', 'height', 'refresh', 'scale', 'transform', 'x', 'y')}
        saved['primary'] = layout['primary']
        text = lua_text(saved)
        write_atomic(self.saved_path, json.dumps(saved, ensure_ascii=False, indent=2) + '\n')
        write_atomic(self.lua_path, text, 0o644)
        if shutil.which('luac'):
            subprocess.run(['luac', '-p', str(self.lua_path)], check=True, capture_output=True, timeout=5)

    def reset(self):
        for path in (self.saved_path, self.lua_path):
            if path.exists():
                path.unlink()


def valid_saved(key, value):
    try:
        return (isinstance(key, str) and isinstance(value, dict) and MODE.match(str(value['mode']) + 'Hz') is not None
                and all(isinstance(value[field], int) and not isinstance(value[field], bool) for field in ('width', 'height', 'transform', 'x', 'y'))
                and 0.5 <= float(value['scale']) <= 4 and 0 <= value['transform'] <= 7 and lua_string(key))
    except (KeyError, TypeError, ValueError):
        return False


def saved_key(name, monitors):
    """A unique description follows the screen to another port; identical screens fall back to the port name."""
    monitor = next((item for item in monitors if item['name'] == name), None)
    description = monitor['description'] if monitor else ''
    if description and sum(1 for item in monitors if item['description'] == description) == 1:
        return 'desc:' + description
    return name


def lua_text(saved):
    lines = [MARKER]
    for key in sorted(saved['monitors']):
        lines.append(monitor_rule(key, saved['monitors'][key]))
    if saved['primary']:
        primary = lua_string(saved['primary'])
        # Hyprland has no primary output; these are the two things it does start from (cursor:default_monitor and
        # the default workspace of a monitor).
        lines.append('hl.config({{ cursor = {{ default_monitor = {} }} }})'.format(primary))
        lines.append('hl.workspace_rule({{ workspace = "1", monitor = {}, default = true }})'.format(primary))
    return '\n'.join(lines) + '\n'


# ---- change and rollback -----------------------------------------------------------------------------------------------

class Guard:
    def __init__(self, hyprland, files, clock=time.monotonic, sleep=time.sleep, timeout=TIMEOUT, settle=SETTLE):
        self.hyprland, self.files, self.clock, self.sleep = hyprland, files, clock, sleep
        self.timeout, self.settle = timeout, settle
        self.stopping = False

    def stop(self, *_):
        self.stopping = True

    def settled(self, items):
        end = self.clock() + self.settle
        while True:
            try:
                if matches(self.hyprland.monitors(), items):
                    return True
            except HyprlandError:
                pass
            if self.clock() >= end:
                return False
            self.sleep(0.2)

    def run(self, transaction):
        tid = transaction['id']
        try:
            self.files.report(tid, 'applying')
            try:
                self.hyprland.eval(rules_code(transaction['after']['monitors']))
                if not self.settled(transaction['after']['monitors']):
                    raise HyprlandError('ApplyMismatch')
            except (HyprlandError, ValueError) as error:
                return self.restore(transaction, 'failed', str(error))
            deadline = self.clock() + self.timeout
            self.files.report(tid, 'waiting', deadline=time.time() + self.timeout, timeout=self.timeout)
            names = {item['name'] for item in transaction['after']['monitors']}
            checked = self.clock()
            while True:
                decision = self.files.decision(tid)
                if decision == 'keep':
                    return self.keep(transaction)
                if decision == 'revert':
                    return self.restore(transaction, 'reverted', 'user')
                if self.stopping:
                    return self.restore(transaction, 'reverted', 'stopped')
                if self.clock() >= deadline:
                    return self.restore(transaction, 'reverted', 'timeout')
                if self.clock() - checked >= 1:
                    checked = self.clock()
                    try:
                        if not names <= {monitor['name'] for monitor in self.hyprland.monitors()}:
                            return self.restore(transaction, 'reverted', 'disconnected')
                    except HyprlandError:
                        pass
                self.sleep(0.1)
        except BaseException:
            # Any surprise ends in the old layout, never in an unconfirmed one.
            self.restore(transaction, 'reverted', 'error')
            raise

    def keep(self, transaction):
        try:
            self.files.persist(transaction['after'], transaction.get('monitors') or self.hyprland.monitors())
        except (OSError, ValueError, HyprlandError, subprocess.SubprocessError):
            self.files.report(transaction['id'], 'kept', error='SaveFailed', linked=self.files.linked())
            return 'kept'
        self.files.report(transaction['id'], 'kept', linked=self.files.linked())
        return 'kept'

    def restore(self, transaction, state, reason):
        try:
            connected = {monitor['name'] for monitor in self.hyprland.monitors()}
            items = [item for item in transaction['before']['monitors'] if item['name'] in connected]
            self.hyprland.eval(rules_code(items))
            if not self.settled(items):
                raise HyprlandError('RestoreMismatch')
            self.files.report(transaction['id'], state, reason=reason)
            return state
        except (HyprlandError, ValueError) as error:
            # Last resort: Hyprland's own configuration, which is what a fresh login would use.
            try:
                self.hyprland.reload()
                self.files.report(transaction['id'], state, reason=reason, error=str(error), method='reload')
                return state
            except HyprlandError:
                self.files.report(transaction['id'], 'restore-failed', reason=reason, error=str(error))
                return 'restore-failed'


def guard_running():
    result = subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT], capture_output=True, timeout=5)
    return result.returncode == 0


def spawn(transaction):
    if not shutil.which('systemd-run') or not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        raise ValueError('GuardUnavailable')
    environment = ['--setenv=' + name + '=' + os.environ[name]
                   for name in ('HYPRLAND_INSTANCE_SIGNATURE', 'XDG_RUNTIME_DIR', 'XDG_CONFIG_HOME') if os.environ.get(name)]
    # A unit of its own: stopping shittim.service or Quickshell does not take the rollback down with it.
    command = ['systemd-run', '--user', '--quiet', '--collect', '--unit=' + UNIT, '--description=Shittim display change guard',
               '--property=RuntimeMaxSec=120'] + environment + [sys.executable or '/usr/bin/python3', str(Path(__file__).resolve()), 'guard', transaction]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        raise ValueError('GuardUnavailable')
    if result.returncode != 0:
        raise ValueError('GuardUnavailable')


def start(plan, hyprland, files, launch=spawn, running=guard_running):
    monitors = hyprland.monitors()
    saved = files.saved()
    after = validate(plan, monitors, saved['primary'])
    before = snapshot(monitors, saved['primary'])
    if same_layout(before, after):
        if after['primary'] == before['primary']:
            return {'state': 'unchanged'}
        # Only the primary display changed: nothing on screen moves, so it is saved without the confirmation step.
        files.persist(after, monitors, screens=False)
        return {'state': 'kept', 'linked': files.linked()}
    if running():
        raise ValueError('ChangeRunning')
    transaction = uuid.uuid4().hex[:12]
    write_atomic(files.transaction, json.dumps({'id': transaction, 'before': before, 'after': after, 'monitors': monitors,
                                                'time': time.time()}, ensure_ascii=False) + '\n')
    files.report(transaction, 'starting')
    launch(transaction)
    return {'state': 'starting', 'id': transaction}


def answer(files, decision):
    status = files.status()
    if status.get('state') not in ('applying', 'waiting'):
        raise ValueError('NoChange')
    files.decide(status['id'], decision)
    return {'id': status['id'], 'decision': decision}


def restore_now(hyprland, files):
    transaction = read_json(files.transaction)
    if not isinstance(transaction, dict) or 'before' not in transaction:
        raise ValueError('NoSnapshot')
    files.decide(transaction['id'], 'revert')
    state = Guard(hyprland, files).restore(transaction, 'reverted', 'restore')
    return {'state': state}


def listing(hyprland, files):
    saved = files.saved()
    return {'monitors': hyprland.monitors(), 'primary': saved['primary'], 'linked': files.linked(),
            'guard': bool(shutil.which('systemd-run'))}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    hyprland, files = Hyprland(), Files()
    try:
        if argv == ['list']:
            result = listing(hyprland, files)
        elif argv[:1] == ['apply'] and len(argv) <= 2:
            try:
                plan = json.loads(argv[1] if len(argv) == 2 else sys.stdin.read(65536))
            except ValueError:
                raise ValueError('InvalidPlan')
            result = start(plan, hyprland, files)
        elif argv in (['keep'], ['revert']):
            result = answer(files, argv[0])
        elif argv == ['restore']:
            result = restore_now(hyprland, files)
        elif argv == ['reset']:
            files.reset()
            hyprland.reload()
            result = {'state': 'reset'}
        elif len(argv) == 2 and argv[0] == 'guard':
            transaction = read_json(files.transaction)
            if not isinstance(transaction, dict) or transaction.get('id') != argv[1]:
                raise ValueError('NoSnapshot')
            guard = Guard(hyprland, files)
            for number in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
                signal.signal(number, guard.stop)
            result = {'state': guard.run(transaction)}
        else:
            print('사용법: display-config.py list|apply|keep|revert|restore|reset', file=sys.stderr)
            return 2
    except (ValueError, HyprlandError, OSError, subprocess.SubprocessError) as error:
        print(str(error) if isinstance(error, (ValueError, HyprlandError)) else 'DisplayCommandFailed', file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
