#!/usr/bin/env python3
"""Explicit Hyprland window actions. No shell evaluation or persistent window data."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


ADDRESS = re.compile(r'(?:0x)?([0-9a-fA-F]{1,16})\Z')
HIDDEN = re.compile(r'special:shittim-hidden-(\d+)-([0-3])-([0-3])-([0-9a-f]+)\Z')
MAXIMIZED = 'shittim-maximized'
RESTORE = re.compile(r'shittim-restore_(-?\d+)_(-?\d+)_(\d+)_(\d+)_([01])\Z')


def restore_geometry(client):
    for tag in client.get('tags', []):
        match = RESTORE.fullmatch(tag)
        if match:
            x, y, width, height, floating = map(int, match.groups())
            if abs(x) <= 100000 and abs(y) <= 100000 and 0 < width <= 100000 and 0 < height <= 100000:
                return tag, dict(at=[x, y], size=[width, height]), bool(floating)
    return None


def address(value):
    match = ADDRESS.fullmatch(value)
    if not match:
        raise ValueError('InvalidWindow')
    return '0x' + match[1].lower().lstrip('0') if int(match[1], 16) else '0x0'


class Windows:
    def __init__(self, runner=subprocess.run):
        self.runner = runner

    def query(self, name, *args):
        result = self.runner(['hyprctl', '-j', name, *args], capture_output=True, text=True, timeout=4, check=True)
        return json.loads(result.stdout)

    def monitor(self, client):
        monitors = self.query('monitors')
        monitor = next((item for item in monitors if item.get('id') == client.get('monitor')), None)
        monitor = monitor or next((item for item in monitors if item.get('focused')), None)
        if monitor is None: raise ValueError('MonitorUnavailable')
        return monitor

    def maximize_area(self, client, monitor):
        x, y, width, height = work_area(monitor)
        # Native titlebars are outside the client rectangle. Files draws its own.
        if client.get('class') != 'org.shittim.Files':
            decorations = self.query('decorations', 'address:' + address(client['address']))
            if any(item.get('decorationName') == 'Hyprbar' for item in decorations):
                decorated = self.query('getprop', 'address:' + address(client['address']), 'decorate').get('decorate')
                if decorated:
                    bar = self.query('getoption', 'plugin:hyprbars:bar_height').get('int', 0)
                    if not isinstance(bar, int) or not 0 <= bar <= 256: raise ValueError('InvalidDecoration')
                    y += bar; height = max(1, height - bar)
        return x, y, width, height

    def dispatch(self, expression):
        result = self.runner(['hyprctl', 'dispatch', expression], capture_output=True, text=True, timeout=4, check=True)
        if result.stdout.strip().lower() != 'ok':
            raise ValueError('DispatcherFailed')

    def observe(self, target):
        client=next((item for item in self.query('clients') if address(item['address'])==target),None)
        if client is None: return {'address':target,'closed':True}
        return dict(address=target,closed=False,at=client['at'],size=client['size'],monitor=client.get('monitor'),
            floating=bool(client.get('floating')),hidden=bool(HIDDEN.fullmatch(client.get('workspace',{}).get('name',''))),
            maximized=MAXIMIZED in client.get('tags',[]) or client.get('fullscreen')==1,
            fullscreen=bool(int(client.get('fullscreen',0)) & 2),
            active=address(self.query('activewindow').get('address') or '0')==target)

    def execute(self, operation, target, zone=None, monitor_id=None):
        target=address(self.query('activewindow').get('address','0')) if target=='active' else address(target)
        before=self.observe(target)
        self.expected_geometry=None
        result=self.action(operation,target,zone,monitor_id) or {}
        deadline=time.monotonic()+2
        while True:
            state=self.observe(target)
            expected=not state['closed']
            if operation=='close':
                # A save dialog can legitimately delay closing; never kill the application.
                return dict(result,state=state,verified=state['closed'],accepted=True)
            if operation=='hide': expected=state.get('hidden',False)
            elif operation=='activate': expected=state.get('active',False) and not state.get('hidden',False)
            elif operation in ('maximize','restore'): expected=state.get('maximized')==(result.get('mode')=='maximized')
            elif operation=='fullscreen': expected=state.get('fullscreen')!=before.get('fullscreen')
            elif operation=='tile': expected=not state.get('maximized') and state.get('floating')!=before.get('floating')
            if expected and self.expected_geometry is not None and state.get('floating'):
                actual=state.get('at',[])+state.get('size',[])
                expected=len(actual)==4 and all(abs(a-b)<=2 for a,b in zip(actual,self.expected_geometry))
            if expected:return dict(result,state=state,verified=True,accepted=True)
            if time.monotonic()>=deadline:
                error=ValueError('OutcomeUnknown');error.state=state;raise error
            time.sleep(0.05)

    def changed(self, target):
        self.dispatch('hl.dsp.event(' + json.dumps('shittim-window-state,' + address(target)) + ')')

    def reflow(self):
        count = 0
        for client in self.query('clients'):
            if MAXIMIZED not in client.get('tags', []) or not client.get('mapped', True) or HIDDEN.fullmatch(client.get('workspace', {}).get('name', '')):
                continue
            if int(client.get('fullscreen', 0)) & 2: continue
            self.execute('fit', client['address']); self.changed(client['address']); count += 1
        return {'adjusted': count}

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
        def geometry(box):
            self.expected_geometry=tuple(box)
            x, y, width, height = box
            send('window.resize', f'x={width},y={height},relative=false')
            send('window.move', f'x={x},y={y},relative=false')
        def tag(value):
            send('window.tag', 'tag=' + json.dumps(value))
        def forget_maximize():
            tag('-' + MAXIMIZED)
            for value in client.get('tags', []):
                if RESTORE.fullmatch(value): tag('-' + value)
        def maximize(restore=False, destination=None):
            if int(client.get('fullscreen', 0)) & 2 or int(client.get('fullscreenClient', 0)) & 2:
                raise ValueError('ExitFullscreenBeforeMaximize')
            if client.get('pinned') or client.get('grouped'):
                raise ValueError('CannotMaximizePinnedOrGroupedWindow')
            if MAXIMIZED in client.get('tags', []):
                record = restore_geometry(client)
                if record is None: raise ValueError('InvalidRestoreGeometry')
                _, original, floating = record
                geometry(fit_area(original, self.maximize_area(client, self.monitor(client))))
                if not floating: send('window.float', 'action="unset"')
                forget_maximize()
                return {'mode': 'normal'}
            if client.get('fullscreen') or client.get('fullscreenClient'):
                # Restore windows maximized by an older Shittim before migration.
                send('window.fullscreen_state', 'internal=0,client=0,action="set"')
                return {'mode': 'normal'}
            if restore: return {'mode': 'normal'}
            original = [int(value) for value in client['at'] + client['size']]
            state = 'shittim-restore_' + '_'.join(map(str, original + [int(bool(client.get('floating')))]))
            if not RESTORE.fullmatch(state) or not restore_geometry({'tags': [state]}): raise ValueError('InvalidRestoreGeometry')
            box = self.maximize_area(client, destination or self.monitor(client))
            if not client.get('floating'): send('window.float', 'action="set"')
            for value in client.get('tags', []):
                if RESTORE.fullmatch(value): tag('-' + value)
            tag('+' + state)
            try:
                geometry(box)
                tag('+' + MAXIMIZED)
            except (ValueError, subprocess.SubprocessError):
                geometry(tuple(original)); tag('-' + state)
                if not client.get('floating'): send('window.float', 'action="unset"')
                raise
            return {'mode': 'maximized'}
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
            if MAXIMIZED in client.get('tags', []) and not int(client.get('fullscreen', 0)) & 2:
                geometry(self.maximize_area(client, self.monitor(client)))
            if MAXIMIZED not in client.get('tags', []) and client.get('floating') and not client.get('fullscreen') and not client.get('fullscreenClient'):
                monitors = self.query('monitors')
                if monitors and not visible(client, monitors):
                    monitor = next((item for item in monitors if item.get('id') == client.get('monitor')), None)
                    monitor = monitor or next((item for item in monitors if item.get('focused')), monitors[0])
                    x, y, width, height = fit_area(client, self.maximize_area(client, monitor))
                    geometry((x,y,width,height))
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
        elif operation in ('maximize', 'restore'):
            result = maximize(operation == 'restore')
            send('focus'); send('window.alter_zorder', 'mode="top"')
            return result
        elif operation == 'fullscreen':
            send('window.fullscreen', 'mode="fullscreen",action="toggle"')
        elif operation == 'tile':
            if MAXIMIZED in client.get('tags', []):
                maximize(True)
                send('window.float', 'action="unset"')
            else: send('window.float', 'action="toggle"')
        elif operation == 'fit':
            if int(client.get('fullscreen',0)) & 2 or int(client.get('fullscreenClient',0)) & 2:
                raise ValueError('ExitFullscreenBeforeFit')
            if MAXIMIZED in client.get('tags', []):
                geometry(self.maximize_area(client, self.monitor(client)))
                return {'mode':'maximized'}
            if client.get('fullscreen') or client.get('fullscreenClient'):
                send('window.fullscreen', 'mode="maximized",action="unset"')
                send('window.fullscreen', 'mode="maximized",action="set"')
                return {'mode':'maximized'}
            if not client.get('floating'):
                return {'mode':'tiled'}
            monitors = self.query('monitors')
            monitor = next((item for item in monitors if item.get('id') == client.get('monitor')), None)
            if not monitor:
                raise ValueError('MonitorUnavailable')
            x, y, width, height = fit_area(client, self.maximize_area(client, monitor))
            geometry((x,y,width,height))
        elif operation == 'snap':
            if not client.get('floating') or client.get('pinned') or client.get('grouped') or int(client.get('fullscreen', 0)) & 2 or int(client.get('fullscreenClient', 0)) & 2:
                raise ValueError('RequiresNormalFloatingWindow')
            monitor = next((item for item in self.query('monitors') if item['id'] == monitor_id),None)
            if monitor is None: raise ValueError('MonitorUnavailable')
            x,y,width,height = snapped(monitor,zone)
            bar = self.maximize_area(client, monitor)[1] - work_area(monitor)[1]
            y += bar; height = max(1, height - bar)
            if zone == 'top':
                if MAXIMIZED not in client.get('tags', []): maximize(destination=monitor)
                else: geometry(self.maximize_area(client, monitor))
                return
            if client.get('fullscreen') or client.get('fullscreenClient'): send('window.fullscreen_state','internal=0,client=0,action="set"')
            geometry((x,y,width,height))
            if MAXIMIZED in client.get('tags', []): forget_maximize()
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
    return fit_area(client, work_area(monitor))


def fit_area(client, area):
    x0, y0, max_w, max_h = area
    w, h = min(max_w, max(1, int(client['size'][0]))), min(max_h, max(1, int(client['size'][1])))
    return min(max(int(client['at'][0]), x0), x0 + max_w - w), min(max(int(client['at'][1]), y0), y0 + max_h - h), w, h


def snapped(monitor,zone):
    if zone not in ('left','right','top-left','top-right','bottom-left','bottom-right','top'):
        raise ValueError('InvalidSnapZone')
    x,y,w,h = work_area(monitor)
    if zone == 'top': return x,y,w,h
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
    parser.add_argument('action', choices=['activate', 'hide', 'close', 'maximize', 'restore', 'fullscreen', 'tile', 'fit','snap','snap-preview','reflow'])
    parser.add_argument('address', nargs='?', default='active')
    parser.add_argument('zone',nargs='?')
    parser.add_argument('monitor',nargs='?',type=int)
    parser.add_argument('--request',default=None)
    args = parser.parse_args()
    request=args.request or uuid.uuid4().hex
    if not re.fullmatch(r'[A-Za-z0-9-]{1,80}',request):parser.error('InvalidRequest')
    def reply(ok, **values):
        print(json.dumps(dict(version=1,request=request,operation=args.action,target=args.address,
            ok=ok,status='success' if ok else 'failure',retryable=False,**values)))
    try:
        if args.action == 'snap-preview':
            monitor = next((item for item in Windows().query('monitors') if item['id']==args.monitor),None)
            if monitor is None: raise ValueError('MonitorUnavailable')
            reply(True,geometry=snapped(monitor,args.zone),monitor=monitor,verified=True); return 0
        # Serialize titlebar, Files, Dock and keyboard commands against the same state.
        import fcntl
        runtime = Path(os.environ['XDG_RUNTIME_DIR'])
        if runtime.stat().st_uid != os.getuid(): raise ValueError('InvalidRuntimeDirectory')
        with (runtime / 'shittim-window-actions.lock').open('a') as lock:
            os.chmod(lock.name, 0o600)
            deadline=time.monotonic()+15
            while True:
                try:fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB);break
                except BlockingIOError:
                    if time.monotonic()>=deadline:raise ValueError('RequestTimeout')
                    time.sleep(0.05)
            windows = Windows()
            if args.action == 'reflow': result=windows.reflow()
            else:
                result=windows.execute(args.action, args.address,args.zone,args.monitor)
                # Refresh state in both the main shell and the separate Files process.
                if args.action != 'close':
                    current = windows.query('activewindow').get('address') if args.address == 'active' else args.address
                    if current: windows.changed(current)
        reply(True,**(result or {}))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        code = str(error) if isinstance(error, ValueError) and re.fullmatch(r'[A-Za-z]+', str(error)) else type(error).__name__
        if code=='ExitFullscreenBeforeFit': print('전체 화면을 먼저 해제한 뒤 다시 맞추세요. 최대화는 그대로 사용할 수 있습니다.',file=sys.stderr)
        reply(False,error=code,code=code,state=getattr(error,'state',None),verified=False,accepted=code=='OutcomeUnknown')
        return 1


if __name__ == '__main__':
    sys.exit(main())
