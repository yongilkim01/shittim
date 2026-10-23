#!/usr/bin/env python3
"""Read-only MPRIS/Shittim comparison. Output contains no titles, URLs or artwork."""
import asyncio
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def unwrap(value):
    if hasattr(value, 'value'):
        return unwrap(value.value)
    if isinstance(value, dict):
        return {key: unwrap(item) for key, item in value.items()}
    if isinstance(value, list):
        return [unwrap(item) for item in value]
    return value


def clean_text(value):
    return re.sub(r'[\x00-\x1f\x7f]', ' ', value)[:2048] if isinstance(value, str) else ''


def compare(remote, shell):
    output = {'sessionBus': True, 'shittim': shell is not None, 'players': [], 'issues': []}
    if not remote:
        output['issues'].append('MprisNotRegistered')
    indexed = {player['name']: player for player in shell.get('players', [])} if shell else {}
    for name, properties in remote.items():
        metadata = properties.get('Metadata', {})
        if not isinstance(metadata, dict):
            metadata = {}
        title = metadata.get('xesam:title', '')
        artist = metadata.get('xesam:artist', [])
        artist = ', '.join(item for item in artist if isinstance(item, str)) if isinstance(artist, list) else ''
        native = indexed.get(name)
        record = {'player': name, 'metadataPresent': bool(title or artist), 'artworkProvided': bool(metadata.get('mpris:artUrl')),
                  'state': properties.get('PlaybackStatus') if properties.get('PlaybackStatus') in ('Playing', 'Paused', 'Stopped') else 'Unknown', 'detectedByShittim': native is not None,
                  'canControl': properties.get('CanControl', False), 'canSeek': properties.get('CanSeek', False),
                  'canNext': properties.get('CanGoNext', False), 'canPrevious': properties.get('CanGoPrevious', False)}
        issues = []
        if not record['metadataPresent']:
            issues.append('MetadataMissing')
        if not native:
            issues.append('ShittimNotDetected' if shell else 'ShittimIPCUnavailable')
        else:
            record['titleSynced'] = clean_text(native.get('title')) == clean_text(title)
            record['artistSynced'] = clean_text(native.get('artist')) == clean_text(artist)
            if not record['titleSynced'] or not record['artistSynced']:
                issues.append('MetadataSyncMismatch')
        if shell and shell.get('selected') == name:
            record['selected'] = True
            record['uiTitleSynced'] = not title or shell.get('title') == clean_text(title)
            record['uiArtistSynced'] = shell.get('artist') == clean_text(artist)
            if not record['uiTitleSynced'] or not record['uiArtistSynced']:
                issues.append('UIDisplayMismatch')
            record['playbackSynced'] = shell.get('playing') == (properties.get('PlaybackStatus') == 'Playing')
            record['artworkState'] = shell.get('artworkState') if shell.get('opened') else 'panelClosed'
            if record['artworkProvided'] and not shell.get('artAllowed'):
                issues.append('ArtworkRejected')
            if shell.get('opened') and shell.get('artworkState') == 'error':
                issues.append('ArtworkLoadFailed')
            if not record['playbackSynced']:
                issues.append('PlaybackSyncMismatch')
        record['issues'] = issues
        output['players'].append(record)
    return output


async def shell_snapshot():
    process = await asyncio.create_subprocess_exec('quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'),
        'call', 'media', 'diagnostics', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    try:
        output, _ = await asyncio.wait_for(process.communicate(), 5)
    except asyncio.TimeoutError:
        process.kill(); await process.wait(); raise
    return json.loads(output) if process.returncode == 0 else None


async def collect():
    from dbus_next import Message, MessageType
    from dbus_next.aio import MessageBus
    bus = await MessageBus().connect()
    try:
        reply = await asyncio.wait_for(bus.call(Message(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus',
            interface='org.freedesktop.DBus', member='ListNames')), 5)
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError('ListNamesFailed')
        remote = {}
        failures = 0
        for name in reply.body[0]:
            if not name.startswith('org.mpris.MediaPlayer2.'):
                continue
            try:
                properties = await asyncio.wait_for(bus.call(Message(destination=name, path='/org/mpris/MediaPlayer2',
                    interface='org.freedesktop.DBus.Properties', member='GetAll', signature='s', body=['org.mpris.MediaPlayer2.Player'])), 3)
                if properties.message_type != MessageType.ERROR:
                    remote[name] = unwrap(properties.body[0])
                else:
                    failures += 1
            except (OSError, asyncio.TimeoutError):
                failures += 1
        try:
            shell = await shell_snapshot()
        except (OSError, ValueError, asyncio.TimeoutError):
            shell = None
        result = compare(remote, shell)
        result['unavailablePlayers'] = failures
        return result
    finally:
        bus.disconnect()


if __name__ == '__main__':
    try:
        print(json.dumps(asyncio.run(collect()), ensure_ascii=False, indent=2))
    except Exception as error:
        print(json.dumps({'sessionBus': False, 'error': type(error).__name__}))
        sys.exit(1)
