#!/usr/bin/env python3
"""Session-only GIO directory browser. File mutations compose shared GIO operations."""
import importlib.util
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
from urllib.parse import urlsplit

SPEC = importlib.util.spec_from_file_location('shittim_desktop_ops', Path(__file__).with_name('file-operations.py'))
ops = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(ops)
ATTRIBUTES = 'standard::name,standard::display-name,standard::type,standard::icon,standard::size,standard::is-hidden,time::modified,access::can-write,access::can-trash,trash::orig-path'


def location(value, home):
    if value in (None, ''): return home.as_uri()
    if not isinstance(value, str) or len(value) > 16384 or any(ord(c) < 32 for c in value):
        raise ValueError('InvalidURI')
    if value.startswith('/'): return Path(value).as_uri()
    parsed = urlsplit(value)
    if parsed.scheme == 'file': return ops.local_uri(value)
    if parsed.scheme not in ('trash', 'network', 'smb', 'sftp', 'mtp', 'gphoto2') or parsed.username or parsed.password:
        raise ValueError('UnsupportedLocation')
    return value


class Files:
    def __init__(self, gio, glib, emit):
        self.gio, self.glib, self.emit = gio, glib, emit
        self.home = Path.home()
        self.projects = next((path for path in (self.home / 'projects', self.home / 'Projects') if path.is_dir()), self.home / 'projects')
        self.operations = ops.FileOperations(gio, glib)
        self.tabs = {}
        self.volume_monitor = gio.VolumeMonitor.get()

    def places(self):
        rows = [dict(name='Home', uri=self.home.as_uri(), icon='home', group='places')]
        for label, enum, icon in [('Desktop','DIRECTORY_DESKTOP','desktop'), ('Documents','DIRECTORY_DOCUMENTS','document'),
                ('Downloads','DIRECTORY_DOWNLOAD','download'), ('Pictures','DIRECTORY_PICTURES','image'),
                ('Music','DIRECTORY_MUSIC','music'), ('Videos','DIRECTORY_VIDEOS','video')]:
            value = self.glib.get_user_special_dir(getattr(self.glib.UserDirectory, enum))
            if value and Path(value) != self.home and Path(value).is_dir():
                rows.append(dict(name=label, uri=Path(value).as_uri(), icon=icon, group='places'))
        schemes = self.gio.Vfs.get_default().get_supported_uri_schemes()
        if 'trash' in schemes: rows.append(dict(name='Trash', uri='trash:///', icon='trash', group='places'))
        rows.append(dict(name='File System', uri='file:///', icon='drive', group='Devices'))
        known = {row['uri'] for row in rows}
        for mount in self.volume_monitor.get_mounts():
            uri = mount.get_root().get_uri()
            if uri not in known:
                rows.append(dict(name=mount.get_name(), uri=uri, icon='drive', group='Devices')); known.add(uri)
        if 'network' in schemes: rows.append(dict(name='Network', uri='network:///', icon='network', group='Network'))
        return rows

    def close_tab(self, tab):
        previous = self.tabs.pop(tab, None)
        if previous and previous.get('monitor'): previous['monitor'].cancel()

    def browse(self, message):
        tab = message['tab']
        if tab not in self.tabs and len(self.tabs) >= 16: raise ValueError('TooManyTabs')
        uri = location(message.get('uri'), self.home)
        folder = self.gio.File.new_for_uri(uri)
        info = folder.query_info('standard::display-name,standard::type,access::can-write', self.gio.FileQueryInfoFlags.NONE, None)
        if info.get_file_type() != self.gio.FileType.DIRECTORY: raise ValueError('NotDirectory')
        children, truncated = [], False
        folder_icons = {'desktop':'user-desktop','document':'folder-documents','download':'folder-download',
                        'image':'folder-pictures','music':'folder-music','video':'folder-videos'}
        special_icons = {place['uri']:folder_icons[place['icon']] for place in self.places() if place['icon'] in folder_icons}
        if self.projects.is_dir(): special_icons[self.projects.as_uri()]='folder-projects'
        iterator = folder.enumerate_children(ATTRIBUTES, self.gio.FileQueryInfoFlags.NONE, None)
        try:
            for child in iterator:
                name = child.get_name()
                item = folder.get_child(name)
                original = child.get_attribute_byte_string('trash::orig-path') or ''
                icon = self.operations.icon(child.get_icon())
                if item.get_uri() in special_icons: icon={'icons':[special_icons[item.get_uri()]],'iconFile':''}
                children.append(dict(id=item.get_uri(), uri=item.get_uri(), name=child.get_display_name(),
                    directory=child.get_file_type() == self.gio.FileType.DIRECTORY, hidden=child.get_is_hidden(),
                    special=False, size=child.get_size(), modified=child.get_attribute_uint64('time::modified'),
                    canTrash=child.get_attribute_boolean('access::can-trash'), original=original,
                    **icon))
                if len(children) >= 20000: truncated = True; break
        finally: iterator.close(None)
        children.sort(key=lambda entry: (not entry['directory'], self.glib.utf8_collate_key_for_filename(entry['name'], -1)))
        crumbs, ancestor = [], folder
        for _ in range(128):
            parent = ancestor.get_parent()
            name = 'Home' if ancestor.get_uri() == self.home.as_uri() else ancestor.get_basename() or ('Trash' if uri.startswith('trash:') else '/')
            crumbs.insert(0, dict(name=name, uri=ancestor.get_uri()))
            if parent is None or ancestor.get_uri() == self.home.as_uri(): break
            ancestor = parent
        self.close_tab(tab)
        state = dict(uri=folder.get_uri(), entries={item['id']:item for item in children}, monitor=None)
        self.tabs[tab] = state
        try:
            monitor = folder.monitor_directory(self.gio.FileMonitorFlags.NONE, None)
            monitor.connect('changed', lambda *_: self.emit(dict(event='changed', tab=tab)))
            state['monitor'] = monitor
        except self.glib.Error: pass
        parent = folder.get_parent()
        self.emit(dict(event='listing', tab=tab, request=message['request'], uri=state['uri'],
            name='Home' if state['uri'] == self.home.as_uri() else info.get_display_name() or folder.get_basename() or '/',
            entries=children, breadcrumbs=crumbs, parent=parent.get_uri() if parent else '', truncated=truncated,
            writable=state['uri'].startswith('file:') and info.get_attribute_boolean('access::can-write')))

    def handle(self, message):
        action, tab = message.get('action'), message.get('tab')
        if action == 'close-tab': self.close_tab(tab); return
        if action == 'browse': self.browse(message); return
        state = self.tabs.get(tab)
        if state is None: raise ValueError('LocationChanged')
        directory = Path(self.gio.File.new_for_uri(state['uri']).get_path() or '/')
        enabled = state['uri'].startswith('file:')
        if action == 'open':
            for entry in self.operations.selected(state['entries'], message.get('ids')):
                if entry['directory']: raise ValueError('NotFile')
                if entry['uri'].lower().endswith('.desktop'):
                    subprocess.Popen(['nemo','--no-desktop',entry['uri']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else: self.gio.AppInfo.launch_default_for_uri(entry['uri'], None)
        elif action == 'restore':
            for entry in self.operations.selected(state['entries'], message.get('ids')):
                if not state['uri'].startswith('trash:') or not entry.get('original') or not entry['original'].startswith('/'):
                    raise ValueError('RestoreUnavailable')
                source = self.gio.File.new_for_uri(entry['uri'])
                source.move(self.gio.File.new_for_path(entry['original']), self.gio.FileCopyFlags.NONE, None, None, None)
        elif action == 'nemo':
            subprocess.Popen(['nemo','--no-desktop',state['uri']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif action in ('copy','cut','paste','drop','folder','rename','trash'):
            if not enabled: raise ValueError('ReadOnlyLocation')
            self.operations.operation(message, state['entries'], directory, enabled)
        else: raise ValueError('InvalidRequest')
        self.emit(dict(event='done', tab=tab, request=message['request'], action=action))
        if action in ('paste','drop','folder','rename','trash','restore'): self.emit(dict(event='changed', tab=tab))


def serve(gio, glib, emit):
    browser = Files(gio, glib, emit)
    loop = glib.MainLoop(); pending = bytearray(); work = queue.Queue(maxsize=32)
    latest = {}; running = True
    def worker():
        while running:
            message = work.get()
            if message is None: break
            if message.get('action') == 'browse' and latest.get(message['tab']) != message['request']: continue
            try: browser.handle(message)
            except Exception as exception:
                code = str(exception) if isinstance(exception, ValueError) else 'FileOperationFailed'
                if isinstance(exception, glib.Error):
                    for value, label in ((gio.IOErrorEnum.PERMISSION_DENIED,'PermissionDenied'),(gio.IOErrorEnum.NOT_FOUND,'NotFound'),(gio.IOErrorEnum.EXISTS,'AlreadyExists')):
                        if exception.matches(gio.io_error_quark(), value): code=label; break
                emit(dict(event='error', tab=message['tab'], request=message['request'], error=code))
    thread = threading.Thread(target=worker, daemon=True); thread.start()
    def read(_source, condition):
        try:
            while True:
                try: chunk = os.read(sys.stdin.fileno(), 4096)
                except BlockingIOError: break
                if not chunk: loop.quit(); return False
                pending.extend(chunk)
                if len(pending) > 1024*1024: loop.quit(); return False
                while b'\n' in pending:
                    line, _, tail = pending.partition(b'\n'); pending[:] = tail
                    message = {}
                    try:
                        message = json.loads(line)
                        if not isinstance(message,dict) or not isinstance(message.get('tab'),int) or not 0 <= message['tab'] <= 1000000 or not isinstance(message.get('request'),int):
                            raise ValueError('InvalidRequest')
                        if message.get('action') == 'browse': latest[message['tab']]=message['request']
                        work.put_nowait(message)
                    except (ValueError, queue.Full) as exception:
                        valid = isinstance(message,dict) and isinstance(message.get('tab'),int) and isinstance(message.get('request'),int)
                        emit(dict(event='error',error='Busy' if isinstance(exception,queue.Full) else 'InvalidRequest',
                                  tab=message['tab'] if valid else -1,request=message['request'] if valid else -1))
        except OSError: loop.quit(); return False
        if condition & (glib.IO_HUP|glib.IO_ERR): loop.quit(); return False
        return True
    os.set_blocking(sys.stdin.fileno(), False)
    glib.io_add_watch(sys.stdin, glib.IO_IN|glib.IO_HUP|glib.IO_ERR, read)
    for sig in (signal.SIGTERM,signal.SIGINT): glib.unix_signal_add(glib.PRIORITY_DEFAULT,sig,lambda:(loop.quit(),False)[1])
    emit(dict(event='ready',home=browser.home.as_uri(),places=browser.places()))
    for event in ('mount-added','mount-removed','mount-changed'):
        browser.volume_monitor.connect(event,lambda *_: emit(dict(event='places',places=browser.places())))
    loop.run(); running=False


def main():
    from gi.repository import Gio, GLib
    lock = threading.Lock()
    with os.fdopen(os.dup(sys.stdout.fileno()),'w',encoding='utf-8',buffering=1) as protocol:
        with open(os.devnull,'w') as sink: os.dup2(sink.fileno(),1); os.dup2(sink.fileno(),2)
        def emit(message):
            with lock: print(json.dumps(message,ensure_ascii=False), file=protocol, flush=True)
        serve(Gio,GLib,emit)
    return 0


if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError,ImportError): sys.exit(1)
