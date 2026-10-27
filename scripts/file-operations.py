#!/usr/bin/env python3
"""Shared GIO mutations with explicit catalogue/location context, no UI inheritance."""
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit, unquote


def component(value):
    if not isinstance(value, str) or value in ('', '.', '..') or len(value.encode('utf-8')) > 255 or any(c in value for c in ('/', '\\', '\x00')):
        raise ValueError('InvalidName')
    return value


def local_uri(value):
    if not isinstance(value, str) or len(value) > 16384:
        raise ValueError('InvalidURI')
    parsed = urlsplit(value)
    if parsed.scheme != 'file' or parsed.netloc not in ('', 'localhost') or parsed.query or parsed.fragment or '\x00' in unquote(parsed.path) or not parsed.path.startswith('/'):
        raise ValueError('LocalFilesOnly')
    return value


class FileOperations:
    def __init__(self, gio, glib):
        self.gio, self.glib = gio, glib

    def icon(self, icon):
        if isinstance(icon, self.gio.ThemedIcon): return {'icons': list(icon.get_names()), 'iconFile': ''}
        if isinstance(icon, self.gio.FileIcon): return {'icons': [], 'iconFile': icon.get_file().get_uri()}
        return {'icons': ['text-x-generic'], 'iconFile': ''}

    def selected(self, entries, ids, editable=False):
        if not isinstance(ids, list) or not 0 < len(ids) <= 256 or not all(isinstance(key, str) and key in entries for key in ids):
            raise ValueError('SelectionChanged')
        entries = [entries[key] for key in dict.fromkeys(ids)]
        if editable and any(entry['special'] for entry in entries): raise ValueError('ProtectedShortcut')
        return entries

    def transfer(self, uris, destination, move=False):
        if not isinstance(uris, list) or not 0 < len(uris) <= 256: raise ValueError('InvalidURI')
        sources = [local_uri(uri) for uri in uris]
        # Nemo owns recursive operations, conflict dialogs, progress, and I/O errors.
        connection = self.gio.bus_get_sync(self.gio.BusType.SESSION, None)
        connection.call_sync('org.Nemo','/org/Nemo','org.Nemo.FileOperations','MoveURIs' if move else 'CopyURIs',
            self.glib.Variant('(ass)', (sources, local_uri(destination))), None, self.gio.DBusCallFlags.NONE, 10000, None)

    def operation(self, message, entries, directory, enabled, projects=None):
        action = message.get('action')
        if action == 'open':
            for entry in self.selected(entries, message.get('ids')):
                if entry['id'] == 'projects' and projects is not None: projects.mkdir(exist_ok=True)
                if entry['directory']:
                    subprocess.Popen([sys.executable,str(Path(__file__).with_name('files-client.py')),entry['uri']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)
                elif entry['uri'].endswith('.desktop'):
                    subprocess.Popen(['nemo','--no-desktop',entry['uri']], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)
                else: self.gio.AppInfo.launch_default_for_uri(entry['uri'], None)
        elif action == 'trash':
            for entry in self.selected(entries, message.get('ids'), True): self.gio.File.new_for_uri(entry['uri']).trash(None)
        elif action == 'rename':
            selection = self.selected(entries, message.get('ids'), True)
            if len(selection) != 1: raise ValueError('SelectOneFile')
            self.gio.File.new_for_uri(selection[0]['uri']).set_display_name(component(message.get('name')), None)
        elif action in ('copy','cut'):
            selection = self.selected(entries, message.get('ids'), True)
            uris = [local_uri(entry['uri']) for entry in selection]
            subprocess.run(['wl-copy','--type','x-special/gnome-copied-files'], input=('cut' if action == 'cut' else 'copy') + '\n' + '\n'.join(uris), text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        elif action in ('paste','drop'):
            if not enabled or not directory.is_dir(): raise ValueError('DesktopDirectoryUnavailable')
            destination = directory.as_uri()
            if message.get('target'):
                entry = self.selected(entries, [message['target']])[0]
                if not entry['directory']: raise ValueError('NotDirectory')
                destination = entry['uri']
            if action == 'paste':
                result = subprocess.run(['wl-paste','--no-newline','--type','x-special/gnome-copied-files'], capture_output=True, text=True, check=True, timeout=5)
                if len(result.stdout) > 1024 * 1024: raise ValueError('InvalidURI')
                lines = result.stdout.splitlines()
                if not lines or lines[0] not in ('cut','copy'): raise ValueError('ClipboardHasNoFiles')
                self.transfer(lines[1:], destination, lines[0] == 'cut')
                if lines[0] == 'cut': subprocess.run(['wl-copy','--clear'], check=True, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else: self.transfer(message.get('uris'), destination, False)
        elif action == 'folder':
            if not enabled or not directory.is_dir(): raise ValueError('DesktopDirectoryUnavailable')
            self.gio.File.new_for_path(str(directory / component(message.get('name')))).make_directory(None)
        elif action == 'open-desktop':
            if not enabled: raise ValueError('DesktopDirectoryUnavailable')
            directory.mkdir(exist_ok=True)
            subprocess.Popen([sys.executable,str(Path(__file__).with_name('files-client.py')),str(directory)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)
        else: raise ValueError('InvalidRequest')
