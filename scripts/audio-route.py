#!/usr/bin/env python3
"""Per-application output routing for the audio settings page.

  move STREAM TARGET   send playback stream STREAM (PipeWire id) to the output whose object.serial is TARGET,
                       or back to the default output when TARGET is "default"

WirePlumber moves a stream when its `target.object` entry in the "default" metadata changes; this sets that entry the
way pipewire-pulse does for pavucontrol (the sink's object.serial, type Spa:Id) and removes it for "default". Both ids
are checked against `pw-dump` first, so only a real Stream/Output/Audio node and a real Audio/Sink are ever touched.
WirePlumber keeps the choice in its own restore-stream state; nothing is written here.
"""
import json
import re
import subprocess
import sys

TIMEOUT = 5
NUMBER = re.compile(r'^[0-9]{1,10}$')


class RouteError(Exception):
    pass


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=TIMEOUT)
    except FileNotFoundError:
        raise RouteError('ToolMissing')
    except subprocess.TimeoutExpired:
        raise RouteError('Timeout')


def nodes(runner=run):
    result = runner(['pw-dump'])
    if result.returncode != 0:
        raise RouteError('PipeWireUnavailable')
    try:
        data = json.loads(result.stdout)
    except ValueError:
        raise RouteError('PipeWireUnavailable')
    found = []
    for item in data if isinstance(data, list) else []:
        if isinstance(item, dict) and item.get('type') == 'PipeWire:Interface:Node':
            props = (item.get('info') or {}).get('props') or {}
            found.append({'id': item.get('id'), 'class': str(props.get('media.class', '')), 'serial': str(props.get('object.serial', ''))})
    return found


def move(stream, target, runner=run):
    if not NUMBER.match(stream) or not (target == 'default' or NUMBER.match(target)):
        raise RouteError('InvalidArguments')
    known = nodes(runner)
    if not any(node['id'] == int(stream) and node['class'].startswith('Stream/Output/Audio') for node in known):
        raise RouteError('StreamNotFound')
    if target != 'default' and not any(node['serial'] == target and node['class'] == 'Audio/Sink' for node in known):
        raise RouteError('TargetNotFound')
    args = (['pw-metadata', '-n', 'default', '-d', stream, 'target.object'] if target == 'default'
            else ['pw-metadata', '-n', 'default', stream, 'target.object', target, 'Spa:Id'])
    if runner(args).returncode != 0:
        raise RouteError('MetadataFailed')
    return {'state': 'moved', 'stream': int(stream), 'target': target}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 3 or argv[0] != 'move':
        print('사용법: audio-route.py move STREAM TARGET|default', file=sys.stderr)
        return 2
    try:
        print(json.dumps(move(argv[1], argv[2])), flush=True)
        return 0
    except RouteError as error:
        print(str(error), file=sys.stderr, flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
