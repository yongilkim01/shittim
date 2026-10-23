#!/usr/bin/env python3
"""Observe notification bus ownership without activating or replacing a server.

Never read notification payloads or stop another daemon.
"""
import argparse
import asyncio
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
NAME = 'org.freedesktop.Notifications'
DAEMONS = re.compile(r'\b(?:mako|dunst|swaync|xfce4-notifyd|notification-daemon)\b')


def shittim_process(pid):
    try:
        args = Path('/proc/{}/cmdline'.format(pid)).read_bytes().decode().strip('\0').split('\0')
        if Path(args[0]).name not in ('quickshell', 'qs'):
            return False
        for index, arg in enumerate(args[:-1]):
            if arg in ('--path', '-p') and Path(args[index + 1]).resolve() == ROOT / 'shell/shell.qml':
                return True
    except (OSError, UnicodeError, ValueError):
        pass
    return False


def audit(system_dirs=None):
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share')
    directories = [data] + [Path(path) for path in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if path]
    activators = []
    autostarts = []
    # Inspection only: do not evaluate captured Lua, Exec fields, or arbitrary shell profiles.
    for directory in directories:
        for path in (directory / 'dbus-1/services').glob('*.service'):
            try:
                if path.stat().st_size <= 65536 and re.search(r'^Name\s*=\s*org\.freedesktop\.Notifications\s*$', path.read_text(), re.M):
                    activators.append(str(path))
            except (OSError, UnicodeError):
                continue
    candidates = list((config / 'hypr').glob('*.lua')) + list((config / 'hypr').glob('*.conf'))
    candidates += list((config / 'autostart').glob('*.desktop'))
    for directory in os.environ.get('XDG_CONFIG_DIRS', '/etc/xdg').split(':'):
        if directory:
            candidates += list((Path(directory) / 'autostart').glob('*.desktop'))
    if system_dirs is None:
        system_dirs = ['/etc/systemd/user', '/usr/lib/systemd/user']
    for directory in [config / 'systemd/user'] + [Path(path) for path in system_dirs]:
        candidates += list(directory.glob('*.wants/*.service'))
    for path in candidates:
        try:
            if path.stat().st_size <= 1024 * 1024 and DAEMONS.search(path.read_text()):
                autostarts.append(str(path))
        except (OSError, UnicodeError):
            continue
    return {'activationFiles': sorted(set(activators)), 'autostartCandidates': sorted(set(autostarts))}


async def observe(watch=False):
    from dbus_next import Message, MessageType
    from dbus_next.aio import MessageBus
    bus = await MessageBus().connect()
    lock = asyncio.Lock()

    async def call(member, signature, body):
        return await asyncio.wait_for(bus.call(Message(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus',
            interface='org.freedesktop.DBus', member=member, signature=signature, body=body)), 5)

    async def report():
        async with lock:
            owner = await call('GetNameOwner', 's', [NAME])
            if owner.message_type == MessageType.ERROR:
                result = {'state': 'missing' if owner.error_name == 'org.freedesktop.DBus.Error.NameHasNoOwner' else 'error', 'pid': 0}
            else:
                process = await call('GetConnectionUnixProcessID', 's', [owner.body[0]])
                if process.message_type == MessageType.ERROR:
                    result = {'state': 'missing', 'pid': 0}
                else:
                    pid = int(process.body[0])
                    own = pid == os.getppid() if watch else shittim_process(pid)
                    result = {'state': 'owned' if own else 'conflict', 'pid': pid}
            print(json.dumps(result), flush=True)
            return result['state'] == 'owned'

    async def changed():
        try:
            await report()
        except (OSError, asyncio.TimeoutError):
            print(json.dumps({'state': 'error', 'pid': 0}), flush=True)

    def handler(message):
        if message.message_type == MessageType.SIGNAL and message.sender == 'org.freedesktop.DBus' and message.interface == 'org.freedesktop.DBus' and message.member == 'NameOwnerChanged' and len(message.body) == 3 and message.body[0] == NAME:
            asyncio.create_task(changed())

    try:
        if watch:
            bus.add_message_handler(handler)
            reply = await call('AddMatch', 's', ["type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='" + NAME + "'"])
            if reply.message_type == MessageType.ERROR:
                raise RuntimeError('MatchFailed')
        result = await report()
        if watch:
            await bus.wait_for_disconnect()
            return False
        return result
    finally:
        bus.disconnect()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--watch', action='store_true')
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--audit', action='store_true')
    args = parser.parse_args()
    if args.audit:
        print(json.dumps(audit(), ensure_ascii=False))
        return 0
    try:
        return 0 if asyncio.run(observe(args.watch)) else 1
    except Exception:
        # No raw D-Bus errors, environment values, or application payloads in the journal.
        print(json.dumps({'state': 'error', 'pid': 0}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
