#!/usr/bin/env python3
"""Private nested Hyprland test: real click/key delivery, panel handoff and window lifecycle."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
from types import SimpleNamespace
import shlex
import subprocess
import tempfile
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
# Protocol from the same released upstream used to review the Lua/headless APIs.
PROTOCOL='https://raw.githubusercontent.com/hyprwm/Hyprland/af923e30d1d24f1f4a4f5cb8308065173c1d9539/protocols/wlr-virtual-pointer-unstable-v1.xml'


def wait_for(callback, label, seconds=15):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        try:
            result=callback()
            if result:return result
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):pass
        time.sleep(.05)
    raise RuntimeError('Timed out: '+label)


def run(native=False):
    parent_display=os.environ.get('WAYLAND_DISPLAY','')
    if not parent_display:raise SystemExit('Run from a working Wayland session; this test never starts a DRM/TTY session.')
    parent_socket=Path(parent_display) if parent_display.startswith('/') else Path(os.environ['XDG_RUNTIME_DIR'])/parent_display
    if not parent_socket.is_socket():raise SystemExit('Parent Wayland socket is unavailable')
    processes=[];logs=[]
    # HOME, state, compositor sockets and D-Bus are all private; no user's settings/services are changed.
    with tempfile.TemporaryDirectory(prefix='shittim-session-') as temporary:
        base=Path(temporary);runtime=base/'runtime';runtime.mkdir(mode=0o700)
        env=dict(os.environ,HOME=str(base),XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(base/'config'),
                 XDG_STATE_HOME=str(base/'state'),XDG_DATA_HOME=str(base/'data'),SHITTIM_TEST_SESSION='1',
                 QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software',
                 LIBSEAT_BACKEND='seatd',SEATD_SOCK=str(base/'no-seat.sock'),HYPRLAND_NO_SD_VARS='1',HYPRLAND_NO_SD_NOTIFY='1')
        for key in ('WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','HYPRLAND_CMD','QT_QPA_PLATFORMTHEME'):env.pop(key,None)
        # No real seat can open. The compositor can only render into this parent window.
        env['WAYLAND_DISPLAY']=str(parent_socket)
        def command(*args,check=True,timeout=45):
            return subprocess.run([str(a) for a in args],env=env,check=check,capture_output=True,text=True,timeout=timeout).stdout.strip()
        def spawn(name,*args):
            stream=(base/(name+'.log')).open('w');logs.append(stream)
            process=subprocess.Popen([str(a) for a in args],env=env,stdout=stream,stderr=stream);processes.append(process);return process
        def query(name):return json.loads(command('hyprctl','-j',name))
        def ipc(path,target,method):return json.loads(command('quickshell','ipc','--path',path,'call',target,method))
        def window_action(action,address):
            result=json.loads(command('python3',ROOT/'scripts/window-service.py',action,address))
            if not result['ok'] or not result.get('verified'):raise AssertionError(result)
            return result['state']
        try:
            spec=importlib.util.spec_from_file_location('shittim_session_ux',ROOT/'scripts/desktop-ux.py')
            ux=importlib.util.module_from_spec(spec);spec.loader.exec_module(ux)
            # Render Lua only; an installer Config would read the parent process's XDG overrides.
            config=SimpleNamespace(root=ROOT,config=base/'config')
            compositor_config=base/'hyprland.lua'
            compositor_config.write_text((ROOT/'tests/session/hyprland.lua').read_text()+ '\n'+ux.UX(config).lua())
            compositor=spawn('compositor','Hyprland','--config',compositor_config)
            lock=wait_for(lambda:next(runtime.glob('hypr/*/hyprland.lock'),None),'compositor socket')
            content=wait_for(lambda:lock.read_text().splitlines() if lock.stat().st_size else None,'compositor lock')
            if int(content[0])!=compositor.pid:raise AssertionError('Unexpected compositor PID; input test refused')
            env['HYPRLAND_INSTANCE_SIGNATURE']=lock.parent.name;env['WAYLAND_DISPLAY']=content[1]
            monitors=wait_for(lambda:query('monitors'),'headless output')
            if command('hyprctl','configerrors').strip():raise AssertionError('Isolated Lua config rejected')
            protocol=base/'pointer.xml'
            # Download is limited to a public, pinned protocol; never executed.
            with urllib.request.urlopen(PROTOCOL,timeout=30) as response:protocol.write_bytes(response.read())
            command('wayland-scanner','client-header',protocol,base/'virtual-pointer.h')
            command('wayland-scanner','private-code',protocol,base/'virtual-pointer.c')
            flags=shlex.split(command('pkg-config','--cflags','--libs','wayland-client'))
            command('cc',ROOT/'tests/session/pointer.c',base/'virtual-pointer.c','-I'+str(base),'-o',base/'pointer',*flags)
            monitor=monitors[0];width=int(monitor['width']/monitor['scale']);height=int(monitor['height']/monitor['scale'])
            def click(x,y):command(base/'pointer',str(int(x)),str(int(y)),str(width),str(height))
            def client(pid):return next((w for w in query('clients') if w.get('pid')==pid),None)
            shell_path=ROOT/'shell/shell.qml';probe_path=ROOT/'shell/test-probe.qml'
            shell=spawn('shell','quickshell','--no-duplicate','--path',shell_path)
            wait_for(lambda:ipc(shell_path,'runtime','status').get('fingerprint'),'real shell imports')
            probe=spawn('probe','quickshell','--path',probe_path)
            target=wait_for(lambda:client(probe.pid),'Wayland probe')
            address=target['address']
            command('hyprctl','dispatch','hl.dsp.window.resize({window="address:'+address+'",x=420,y=260,relative=false})')
            command('hyprctl','dispatch','hl.dsp.window.move({window="address:'+address+'",x=250,y=180,relative=false})')
            wait_for(lambda:ipc(probe_path,'probe','status') is not None,'probe IPC')
            # The assertion observes text editing, not only Hyprland's activewindow.
            for cycle in range(8):
                click(width-25,height/2)
                target=client(probe.pid);click(target['at'][0]+80,target['at'][1]+80)
                command('wtype','a')
                wait_for(lambda:ipc(probe_path,'probe','status')['keys']==cycle+1,'desktop -> click -> keyboard delivery')
            for target_name in ('launcher','dashboard','windows','notifications'):
                command('quickshell','ipc','--path',shell_path,'call',target_name,'show')
                wait_for(lambda:ipc(shell_path,'runtime','status')['owner']!='','panel input ownership')
            click(width-90,20)
            wait_for(lambda:ipc(shell_path,'runtime','status')['owner']=='control','Control Center bar action')
            command('wtype','-k','Escape')
            wait_for(lambda:ipc(shell_path,'runtime','status')['owner']=='','Escape release')
            files=spawn('files','quickshell','--path',ROOT/'shell/files.qml')
            file_window=wait_for(lambda:client(files.pid),'Files native window')
            wait_for(lambda:ipc(ROOT/'shell/files.qml','files','status')['ready'],'Files service ready')
            for _ in range(4):
                window_action('maximize',address)
                window_action('maximize',file_window['address'])
                if 'shittim-maximized' not in next(w for w in query('clients') if w['address']==address).get('tags',[]):
                    raise AssertionError('Maximizing Files restored another window')
                window_action('restore',file_window['address'])
                window_action('restore',address)
            window_action('hide',address);window_action('activate',address)
            # Observe actual files window button hits as well as controller calls.
            for _ in range(3):
                window_action('activate',file_window['address']);target=client(files.pid)
                click(target['at'][0]+target['size'][0]-46,target['at'][1]+20)
                wait_for(lambda:ipc(ROOT/'shell/files.qml','files','status')['maximized'] and not ipc(ROOT/'shell/files.qml','files','status')['windowBusy'],'Files button maximize')
                target=client(files.pid);click(target['at'][0]+target['size'][0]-46,target['at'][1]+20)
                wait_for(lambda:not ipc(ROOT/'shell/files.qml','files','status')['maximized'] and not ipc(ROOT/'shell/files.qml','files','status')['windowBusy'],'Files button restore')
            if native:
                command('python3',ROOT/'scripts/titlebar-tool.py','build',timeout=900)
                command('python3',ROOT/'scripts/titlebar-tool.py','setup')
                with compositor_config.open('a') as stream:stream.write('\ndofile('+json.dumps(str(config.config/'hypr/shittim-titlebars.lua'))+')\n')
                command('python3',ROOT/'scripts/titlebar-tool.py','load')
                command('python3',ROOT/'scripts/titlebar-tool.py','verify')
                window_action('activate',address);window_action('fit',address)
                tokens=json.loads((ROOT/'config/design-tokens.json').read_text())
                slot=tokens['windowButtonSize']['value'];gap=tokens['titlebarButtonGap']['value'];padding=tokens['titlebarPadding']['value'];bar=tokens['titlebarHeight']['value']
                def native_button(index):
                    current=client(probe.pid)
                    click(current['at'][0]+current['size'][0]-padding-slot/2-index*(slot+gap),current['at'][1]-bar/2)
                native_button(1)
                wait_for(lambda:'shittim-maximized' in client(probe.pid).get('tags',[]),'native maximize button')
                time.sleep(.15);native_button(1)
                wait_for(lambda:'shittim-maximized' not in client(probe.pid).get('tags',[]),'native restore button')
                time.sleep(.15);native_button(2)
                wait_for(lambda:client(probe.pid)['workspace']['name'].startswith('special:shittim-hidden-'),'native minimize button')
                window_action('activate',address);time.sleep(.15);native_button(0)
                wait_for(lambda:client(probe.pid) is None,'native close button')
            if shell.poll() is not None or files.poll() is not None:raise AssertionError('Shell or Files exited')
            print(json.dumps(dict(ok=True,checks=['real-imports','pointer-keyboard-8-cycles','panel-handoff','escape','independent-maximize','Files-button-restore','hide-activate'],nativeBuiltAndLoaded=native)))
        except Exception:
            for stream in logs:stream.flush()
            for name in ('compositor','shell','files','probe'):
                path=base/(name+'.log')
                if path.is_file():print('--- '+name+' ---\n'+path.read_text(errors='replace')[-12000:])
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None:process.terminate()
            for process in reversed(processes):
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
            for stream in logs:stream.close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--native',action='store_true')
    run(parser.parse_args().native)
