#!/usr/bin/env python3
"""Power and lock preferences: validation, the single writer of shittim/power.json, and the hypridle file they generate.

Never runs commands. The shell changes one value at a time through `set`, so every write passes the same validation.
"""
import json
import os
from pathlib import Path
import shlex
import sys
import tempfile

SOURCES = ('battery', 'ac')
# Minutes; 0 turns the step off. Fixed choices keep a broken file from locking every few seconds.
CHOICES = {
    'lock': (0, 1, 2, 3, 5, 10, 15, 30),
    'screenOff': (0, 1, 2, 3, 5, 10, 15, 30, 60),
    'suspend': (0, 10, 15, 20, 30, 45, 60, 120),
}
LID = ('system', 'suspend', 'screen-off', 'ignore')
MARKER = '# Managed by Shittim: idle policy generated from shittim/power.json.'


def paths(root=None):
    root = Path(root or Path(__file__).resolve().parents[1])
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    return root / 'config/power.json', config / 'shittim/power.json'


def validate(data):
    """Returns a normalized copy or raises ValueError. Unknown keys are dropped."""
    if not isinstance(data, dict) or data.get('version') != 1:
        raise ValueError('PowerConfigVersion')
    result = {'version': 1}
    for source in SOURCES:
        policy = data.get(source)
        if not isinstance(policy, dict):
            raise ValueError('PowerConfigInvalid')
        normalized = {}
        for key, choices in CHOICES.items():
            value = policy.get(key)
            if isinstance(value, bool) or not isinstance(value, int) or value not in choices:
                raise ValueError('PowerConfigInvalid')
            normalized[key] = value
        if policy.get('lid') not in LID:
            raise ValueError('PowerConfigInvalid')
        normalized['lid'] = policy['lid']
        result[source] = normalized
    return result


def read_settings(root=None):
    """Personal file if present, else repository defaults. A broken personal file falls back with an error code."""
    default, personal = paths(root)
    defaults = validate(json.loads(default.read_text(encoding='utf-8')))
    if not personal.exists():
        return defaults, ''
    try:
        if personal.stat().st_size > 16384:
            raise ValueError('PowerConfigInvalid')
        return validate(json.loads(personal.read_text(encoding='utf-8'))), ''
    except (OSError, ValueError, TypeError):
        return defaults, 'PowerConfigInvalid'


def hypridle_text(policy, root):
    action = '/usr/bin/bash ' + shlex.quote(str(Path(root) / 'scripts/power-action.sh'))
    lines = [MARKER, '# Regenerated when settings or the power source change; edit power.json instead.',
             'general {',
             '    lock_cmd = /usr/bin/bash ' + shlex.quote(str(Path(root) / 'scripts/lock-screen.sh')),
             '    before_sleep_cmd = loginctl lock-session',
             '    after_sleep_cmd = ' + action + ' screen-on',
             # lock_cmd is a wrapper script, so hypridle's automatic mode would not wait; 3 waits for the lock.
             '    inhibit_sleep = 3',
             '}']
    if policy['lock']:
        lines += ['listener {', '    timeout = ' + str(policy['lock'] * 60), '    on-timeout = loginctl lock-session', '}']
    if policy['screenOff']:
        lines += ['listener {', '    timeout = ' + str(policy['screenOff'] * 60),
                  '    on-timeout = ' + action + ' screen-off', '    on-resume = ' + action + ' screen-on', '}']
    if policy['suspend']:
        lines += ['listener {', '    timeout = ' + str(policy['suspend'] * 60), '    on-timeout = ' + action + ' suspend', '}']
    return '\n'.join(lines) + '\n'


def update(source, key, value, root=None):
    """Changes one value and writes the personal file atomically. A broken file is kept as power.json.invalid."""
    settings, error = read_settings(root)
    if source not in SOURCES or key not in tuple(CHOICES) + ('lid',):
        raise ValueError('InvalidRequest')
    changed = json.loads(json.dumps(settings))
    changed[source][key] = value if key == 'lid' else int(value) if str(value).isdigit() else value
    changed = validate(changed)
    personal = paths(root)[1]
    personal.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    if error and personal.exists():
        os.replace(personal, personal.with_name('power.json.invalid'))
    fd, name = tempfile.mkstemp(prefix='.shittim-', dir=str(personal.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(json.dumps(changed, ensure_ascii=False, indent=2) + '\n')
        os.replace(name, personal)
    finally:
        if os.path.exists(name):
            os.unlink(name)
    return changed


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ['set'] and len(argv) == 4:
        try:
            update(*argv[1:])
        except (OSError, ValueError, TypeError) as error:
            print(str(error) if isinstance(error, ValueError) else 'PowerConfigWriteFailed', file=sys.stderr)
            return 1
        return 0
    if argv:
        print('사용법: power-policy.py [set battery|ac lock|screenOff|suspend|lid 값]', file=sys.stderr)
        return 2
    settings, error = read_settings()
    print(json.dumps({'settings': settings, 'error': error}, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
