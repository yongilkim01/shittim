#!/usr/bin/env python3
"""Read-only live MPRIS discovery and Shittim IPC. Does not control user playback."""
import asyncio
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


async def main():
    from dbus_next import Message, MessageType
    from dbus_next.aio import MessageBus
    bus = await MessageBus().connect()
    try:
        reply = await asyncio.wait_for(bus.call(Message(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus',
            interface='org.freedesktop.DBus', member='ListNames')), 5)
        assert reply.message_type != MessageType.ERROR, 'DBusUnavailable'
        count = sum(name.startswith('org.mpris.MediaPlayer2.') for name in reply.body[0])
        process = await asyncio.create_subprocess_exec('quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'),
            'call', 'media', 'status', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            output, _ = await asyncio.wait_for(process.communicate(), 5)
        except asyncio.TimeoutError:
            process.kill(); await process.wait(); raise
        assert process.returncode == 0, 'MediaIPCUnavailable'
        state = json.loads(output)
        assert 'players' in state and 'favorites' in state, 'InvalidMediaState'
        assert not count or state['players'] > 0, 'MprisPlayersNotDetected'
        print('PASS: Shittim media IPC; MPRIS services={}, detected players={}, installed favorites={}'.format(count, state['players'], state['favorites']))
        if not count:
            print('미디어가 없는 상태입니다. MPRIS 지원 앱에서 재생한 뒤 다시 검사하세요.')
    finally:
        bus.disconnect()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as error:
        print('FAIL: media verification (' + type(error).__name__ + ')', file=sys.stderr)
        sys.exit(1)
