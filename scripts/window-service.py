#!/usr/bin/env python3
"""Explicit Hyprland window actions. No shell evaluation or persistent window data."""
import argparse
import json
import math
import re
import subprocess
import sys


ADDRESS = re.compile(r'(?:0x)?([0-9a-fA-F]{1,16})\Z')
HIDDEN = re.compile(r'special:shittim-hidden-(\d+)-([0-3])-([0-3])-([0-9a-f]+)\Z')


def address(value):
    match = ADDRESS.fullmatch(value)
    if not match:
        raise ValueError('InvalidWindow')
    return '0x' + match[1].lower().lstrip('0') if int(match[1], 16) else '0x0'


class Windows:
    def __init__(self, runner=subprocess.run):
        self.runner = runner

    def query(self, name):
        result = self.runner(['hyprctl', '-j', name], capture_output=True, text=True, timeout=4, check=True)
        return json.loads(result.stdout)

    def dispatch(self, expression):
        result = self.runner(['hyprctl', 'dispatch', expression], capture_output=True, text=True, timeout=4, check=True)
        if result.stdout.strip().lower() != 'ok':
            raise ValueError('DispatcherFailed')

    def action(self, operation, target='active', zone=None, monitor_id=None):
        clients = self.query('clients')
        if target == 'active':
            target = self.query('activewindow').get('address', '')
        target = address(target)
        client = next((item for item in clients if address(item['address']) == target and item.get('mapped', True)), None)
        if client is None:
            raise ValueError('WindowClosed')
        selector = 'window=' + json.dumps('address:' + target)
        workspace = client.get('workspace', {})
        hidden = HIDDEN.fullmatch(workspace.get('name', ''))
        if hidden and hidden[4] != target[2:]:
            hidden = None
        def send(name, fields=''):
            self.dispatch('hl.dsp.' + name + '({' + (fields + ',' if fields else '') + selector + '})')
        if operation == 'activate':
            if hidden:
                destination = int(hidden[1])
                workspaces = self.query('workspaces')
                if not any(item.get('id') == destination for item in workspaces):
                    monitors = self.query('monitors')
                    monitor = next((item for item in monitors if item.get('focused')), None)
                    if not monitor:
                        raise ValueError('MonitorUnavailable')
                    destination = int(monitor['activeWorkspace']['id'])
                if destination <= 0:
                    raise ValueError('WorkspaceUnavailable')
                send('window.move', 'workspace=' + json.dumps(str(destination)) + ',follow=false')
                if int(hidden[2]) or int(hidden[3]):
                    send('window.fullscreen_state', f'internal={hidden[2]},client={hidden[3]},action="set"')
                client = next((item for item in self.query('clients') if address(item['address']) == target), None)
                if client is None: raise ValueError('WindowClosed')
            if client.get('floating') and not client.get('fullscreen') and not client.get('fullscreenClient'):
                monitors = self.query('monitors')
                if monitors and not visible(client, monitors):
                    monitor = next((item for item in monitors if item.get('id') == client.get('monitor')), None)
                    monitor = monitor or next((item for item in monitors if item.get('focused')), monitors[0])
                    x, y, width, height = fitted(client, monitor)
                    send('window.resize', f'x={width},y={height},relative=false')
                    send('window.move', f'x={x},y={y},relative=false')
            send('focus')
            send('window.alter_zorder', 'mode="top"')
        elif operation == 'hide':
            if hidden:
                return
            origin = workspace.get('id', 0)
            if not isinstance(origin, int) or origin <= 0 or client.get('pinned') or client.get('grouped'):
                raise ValueError('CannotHideSpecialOrGroupedWindow')
            internal, external = int(client.get('fullscreen', 0)), int(client.get('fullscreenClient', 0))
            if internal not in range(4) or external not in range(4):
                raise ValueError('InvalidFullscreenState')
            destination = f'special:shittim-hidden-{origin}-{internal}-{external}-{target[2:]}'
            if internal or external:
                send('window.fullscreen_state', 'internal=0,client=0,action="set"')
            try:
                send('window.move', 'workspace=' + json.dumps(destination) + ',follow=false')
            except (ValueError, subprocess.SubprocessError):
                if internal or external:
                    send('window.fullscreen_state', f'internal={internal},client={external},action="set"')
                raise
        elif operation == 'close':
            send('window.close')
        elif hidden:
            raise ValueError('RestoreWindowFirst')
        elif operation in ('maximize', 'fullscreen'):
            send('window.fullscreen', 'mode="' + ('maximized' if operation == 'maximize' else 'fullscreen') + '",action="toggle"')
        elif operation == 'tile':
            send('window.float', 'action="toggle"')
        elif operation == 'fit':
            if not client.get('floating') or client.get('fullscreen') or client.get('fullscreenClient'):
                raise ValueError('RequiresNormalFloatingWindow')
            monitors = self.query('monitors')
            monitor = next((item for item in monitors if item.get('id') == client.get('monitor')), None)
            if not monitor:
                raise ValueError('MonitorUnavailable')
            x, y, width, height = fitted(client, monitor)
            send('window.resize', f'x={width},y={height},relative=false')
            send('window.move', f'x={x},y={y},relative=false')
        elif operation == 'snap':
            if not client.get('floating') or client.get('pinned') or client.get('grouped') or client.get('fullscreen') == 2 or client.get('fullscreenClient') == 2:
                raise ValueError('RequiresNormalFloatingWindow')
            monitor = next((item for item in self.query('monitors') if item['id'] == monitor_id),None)
            if monitor is None: raise ValueError('MonitorUnavailable')
            x,y,width,height = snapped(monitor,zone)
            if zone == 'top':
                send('window.fullscreen','mode="maximized",action="set"')
                return
            if client.get('fullscreen') or client.get('fullscreenClient'): send('window.fullscreen_state','internal=0,client=0,action="set"')
            send('window.resize',f'x={width},y={height},relative=false')
            send('window.move',f'x={x},y={y},relative=false')
        else:
            raise ValueError('InvalidAction')


def work_area(monitor):
    """Monitor work area in logical coordinates, including rotated/scaled outputs."""
    scale = float(monitor.get('scale', 1))
    if not math.isfinite(scale) or scale <= 0:
        raise ValueError('InvalidMonitor')
    width, height = float(monitor['width']), float(monitor['height'])
    if int(monitor.get('transform', 0)) % 2:
        width, height = height, width
    left, top, right, bottom = monitor.get('reserved', [0, 0, 0, 0])
    x0, y0 = int(monitor['x'] + left + 8), int(monitor['y'] + top + 8)
    max_w, max_h = max(1, int(width / scale - left - right - 16)), max(1, int(height / scale - top - bottom - 16))
    return x0, y0, max_w, max_h


def visible(client, monitors):
    x, y = client['at']; width, height = client['size']
    for monitor in monitors:
        x0, y0, mw, mh = work_area(monitor)
        if min(x + width, x0 + mw) - max(x, x0) >= min(32, width) and min(y + height, y0 + mh) - max(y, y0) >= min(24, height):
            return True
    return False


def fitted(client, monitor):
    x0, y0, max_w, max_h = work_area(monitor)
    w, h = min(max_w, max(1, int(client['size'][0]))), min(max_h, max(1, int(client['size'][1])))
    return min(max(int(client['at'][0]), x0), x0 + max_w - w), min(max(int(client['at'][1]), y0), y0 + max_h - h), w, h


def snapped(monitor,zone):
    if zone not in ('left','right','top-left','top-right','bottom-left','bottom-right','top'):
        raise ValueError('InvalidSnapZone')
    x,y,w,h = work_area(monitor)
    if zone == 'top': return x,y,w,h
    # Leave room for the floating Dock, without changing exclusive zones globally.
    h=max(1,h-78)
    left=zone in ('left','top-left','bottom-left')
    half=w//2
    if not left: x+=half
    w=half if left else w-half
    if zone not in ('left','right'):
        half=h//2
        if zone.startswith('bottom'): y+=half; h-=half
        else: h=half
    return x,y,max(1,w),max(1,h)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['activate', 'hide', 'close', 'maximize', 'fullscreen', 'tile', 'fit','snap','snap-preview'])
    parser.add_argument('address', nargs='?', default='active')
    parser.add_argument('zone',nargs='?')
    parser.add_argument('monitor',nargs='?',type=int)
    args = parser.parse_args()
    try:
        if args.action == 'snap-preview':
            monitor = next((item for item in Windows().query('monitors') if item['id']==args.monitor),None)
            if monitor is None: raise ValueError('MonitorUnavailable')
            print(json.dumps({'ok':True,'geometry':snapped(monitor,args.zone),'monitor':monitor})); return 0
        Windows().action(args.action, args.address,args.zone,args.monitor)
        print(json.dumps({'ok': True}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        code = str(error) if isinstance(error, ValueError) and re.fullmatch(r'[A-Za-z]+', str(error)) else type(error).__name__
        print(json.dumps({'ok': False, 'error': code}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
