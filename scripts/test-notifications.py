#!/usr/bin/env python3
"""Live-session notification protocol checks; removes only its own test notifications."""
import asyncio
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


async def ipc(action, *args):
    process = await asyncio.create_subprocess_exec('quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'),
        'call', 'notifications', action, *map(str, args), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    output, _ = await asyncio.wait_for(process.communicate(), 5)
    if process.returncode != 0:
        raise RuntimeError('NotificationIPCUnavailable')
    return json.loads(output) if output.strip() else None


async def main():
    from dbus_next import Message, MessageType, Variant
    from dbus_next.aio import MessageBus
    bus = await MessageBus().connect()
    ids = set()
    before = await ipc('status')
    assert before['ownership'] == 'owned', 'Shittim does not own the notification service'

    async def call(member, signature='', body=None):
        reply = await asyncio.wait_for(bus.call(Message(destination='org.freedesktop.Notifications', path='/org/freedesktop/Notifications',
            interface='org.freedesktop.Notifications', member=member, signature=signature, body=body or [])), 5)
        assert reply.message_type != MessageType.ERROR, 'Notification protocol error'
        return reply.body

    async def notify(replaces, title, hints=None):
        reply = await call('Notify', 'susssasa{sv}i', ['Shittim verification', replaces, 'dialog-information', title,
            '실제 D-Bus 알림 검증 · 이 알림만 자동 제거됩니다.', [], hints or {}, 0])
        ids.add(reply[0])
        return reply[0]

    try:
        capabilities = (await call('GetCapabilities'))[0]
        assert all(value in capabilities for value in ['actions', 'body', 'persistence'])
        first = await notify(0, 'Shittim notification test', {'category': Variant('s', 'system')})
        await asyncio.sleep(0.25)
        assert await ipc('contains', first), 'Notification was not recorded'
        assert await notify(first, 'Shittim replacement test') == first, 'Replacement changed the notification ID'
        await asyncio.sleep(0.25)
        assert await ipc('contains', first), 'Replaced notification missing'
        await call('CloseNotification', 'u', [first])
        await asyncio.sleep(0.25)
        assert not await ipc('contains', first), 'Client-closed notification retained'
        await ipc('dndOn')
        assert (await ipc('status'))['dnd']
        second = await notify(0, 'Shittim DND test')
        await asyncio.sleep(0.25)
        assert await ipc('contains', second), 'DND dropped notification history'
        print('PASS: native D-Bus receive, replacement, client close, shared DND/history')
    finally:
        for identity in ids:
            await call('CloseNotification', 'u', [identity])
        await ipc('dndOn' if before['dnd'] else 'dndOff')
        bus.disconnect()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as error:
        # Test payloads are fixed; never dump user notification data or D-Bus replies.
        print('FAIL: notification protocol verification (' + type(error).__name__ + ')', file=sys.stderr)
        sys.exit(1)
