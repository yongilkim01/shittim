#!/usr/bin/env python3
"""Desktop catalogue and explicit file operations; JSON over private standard I/O."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile


SPEC = importlib.util.spec_from_file_location('shittim_file_ops', Path(__file__).with_name('file-operations.py'))
ops = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(ops)
component, local_uri = ops.component, ops.local_uri


class Layout:
    def __init__(self, path):
        self.path = Path(path)
        root=Path(__file__).resolve().parents[1]
        if not self.path.is_absolute() or self.path.resolve().is_relative_to(root): raise ValueError('StateMustBeOutsideRepository')

    def read(self):
        if not self.path.exists(): return {}
        if self.path.stat().st_size > 1024 * 1024: raise ValueError('LayoutInvalid')
        data = json.loads(self.path.read_text(encoding='utf-8'))
        if not isinstance(data, dict): raise ValueError('LayoutInvalid')
        return data

    def move(self, screen, positions):
        if not isinstance(screen, str) or not 0 < len(screen) <= 256 or not isinstance(positions, dict) or len(positions) > 4096:
            raise ValueError('LayoutInvalid')
        cleaned = {}
        for key, value in positions.items():
            if not isinstance(key, str) or len(key) > 16384 or not isinstance(value, list) or len(value) != 2 or not all(isinstance(v, (int, float)) and 0 <= v <= 100000 for v in value):
                raise ValueError('LayoutInvalid')
            cleaned[key] = value
        data = self.read(); data[screen] = cleaned
        if len(data) > 32: raise ValueError('LayoutInvalid')
        encoded = json.dumps(data, ensure_ascii=False)
        if len(encoded.encode('utf-8')) > 1024 * 1024: raise ValueError('LayoutInvalid')
        self.path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=self.path.parent, delete=False) as stream:
            temporary = Path(stream.name)
            try:
                stream.write(encoded + '\n'); stream.flush(); os.fsync(stream.fileno())
                temporary.chmod(0o600); os.replace(temporary, self.path)
            finally: temporary.unlink(missing_ok=True)
        return data


class Desktop:
    def __init__(self, gio, glib, emit):
        self.gio, self.glib, self.emit = gio, glib, emit
        self.operations = ops.FileOperations(gio, glib)
        self.home = Path.home()
        directory = glib.get_user_special_dir(glib.UserDirectory.DIRECTORY_DESKTOP)
        self.directory = Path(directory) if directory else None
        self.enabled = self.directory is not None and self.directory != self.home
        self.projects = next((path for path in (self.home / 'projects', self.home / 'Projects') if path.is_dir()), self.home / 'projects')
        self.layout = Layout(Path(os.environ.get('XDG_STATE_HOME') or self.home / '.local/state') / 'shittim/desktop-layout.json')
        self.entries = {}; self.busy = False

    def refresh(self):
        entries = [{'id':'home','name':'Home','uri':self.home.as_uri(),'directory':True,'special':True,'icons':['user-home']},
            {'id':'trash','name':'Trash','uri':'trash:///','directory':True,'special':True,'icons':['user-trash']},
            {'id':'projects','name':'Projects','uri':self.projects.as_uri(),'directory':True,'special':True,'icons':['folder-projects']}]
        if self.enabled and self.directory.is_dir():
            folder = self.gio.File.new_for_path(str(self.directory))
            iterator = folder.enumerate_children('standard::name,standard::display-name,standard::type,standard::icon,standard::is-hidden', self.gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
            try:
                for info in iterator:
                    if info.get_is_hidden(): continue
                    child = folder.get_child(info.get_name()); uri = child.get_uri()
                    entries.append(dict(id=uri,name=info.get_display_name(),uri=uri,
                        directory=info.get_file_type() == self.gio.FileType.DIRECTORY,special=False,**self.operations.icon(info.get_icon())))
                    if len(entries) >= 4096: break
            finally: iterator.close(None)
        self.entries = {entry['id']: entry for entry in entries}
        try: positions = self.layout.read()
        except (OSError, ValueError): positions = {}; self.emit({'event':'error','error':'LayoutInvalid'})
        self.emit({'event':'desktop','entries':entries,'positions':positions,'directory':str(self.directory or ''),'enabled':self.enabled})

    def transfer(self, uris, destination, move=False):
        return ops.FileOperations(self.gio, self.glib).transfer(uris, destination, move)

    def operation(self, message):
        return self.operations.operation(message, self.entries, self.directory, self.enabled, self.projects)



def serve(gio, glib, emit):
    import threading
    desktop = Desktop(gio, glib, emit); loop = glib.MainLoop(); pending = bytearray(); source = 0; monitors = []
    def refresh():
        nonlocal source
        source = 0
        try: desktop.refresh()
        except Exception: emit({'event':'error','error':'DesktopReadFailed'})
        return False
    def changed(*_args):
        nonlocal source
        if not source: source = glib.timeout_add(150, refresh)
    if desktop.enabled:
        desktop.directory.mkdir(exist_ok=True)
        monitor = gio.File.new_for_path(str(desktop.directory)).monitor_directory(gio.FileMonitorFlags.NONE,None)
        monitor.connect('changed',changed); monitors.append(monitor)
    def finish(error, request):
        desktop.busy = False
        emit({'event':'result','id':request,'ok':not error,'error':error})
        emit({'event':'busy','value':False}); changed(); return False
    def work(message):
        error = ''
        try: desktop.operation(message)
        except ValueError as exception: error = str(exception)
        except Exception: error = 'FileOperationFailed'
        glib.idle_add(finish,error,message.get('id'))
    def handle(message):
        if not isinstance(message,dict): raise ValueError('InvalidRequest')
        if message.get('action') == 'refresh': changed()
        elif message.get('action') == 'positions':
            positions = desktop.layout.move(message.get('screen'),message.get('positions'))
            emit({'event':'positions','positions':positions})
            emit({'event':'result','id':message.get('id'),'ok':True})
        elif desktop.busy: emit({'event':'result','id':message.get('id'),'ok':False,'error':'FileOperationBusy'})
        else:
            desktop.busy=True; emit({'event':'busy','value':True})
            threading.Thread(target=work,args=(message,),daemon=True).start()
    def read(_source,condition):
        try:
            while True:
                try: chunk=os.read(sys.stdin.fileno(),4096)
                except BlockingIOError: break
                if not chunk: loop.quit(); return False
                pending.extend(chunk)
                if len(pending)>1024*1024: loop.quit(); return False
                while b'\n' in pending:
                    line,_,tail=pending.partition(b'\n'); pending[:]=tail
                    message={}
                    try: message=json.loads(line);handle(message)
                    except Exception: emit({'event':'result','id':message.get('id') if isinstance(message,dict) else None,'ok':False,'error':'InvalidRequest'})
        except OSError: loop.quit(); return False
        if condition & (glib.IO_HUP|glib.IO_ERR): loop.quit(); return False
        return True
    os.set_blocking(sys.stdin.fileno(),False)
    glib.io_add_watch(sys.stdin,glib.IO_IN|glib.IO_HUP|glib.IO_ERR,read)
    for sig in (signal.SIGTERM,signal.SIGINT): glib.unix_signal_add(glib.PRIORITY_DEFAULT,sig,lambda:(loop.quit(),False)[1])
    refresh(); loop.run()


def main():
    from gi.repository import Gio, GLib
    if sys.argv[1:]: return 2
    with os.fdopen(os.dup(sys.stdout.fileno()),'w',encoding='utf-8',buffering=1) as protocol:
        with open(os.devnull,'w') as sink: os.dup2(sink.fileno(),1); os.dup2(sink.fileno(),2)
        serve(Gio,GLib,lambda message: print(json.dumps(message,ensure_ascii=False),file=protocol,flush=True))
    return 0


if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError,ImportError): sys.exit(1)
