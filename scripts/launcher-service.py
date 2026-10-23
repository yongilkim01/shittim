#!/usr/bin/env python3
"""Event-driven GIO application catalogue and launch protocol for Shittim."""
import json
import os
import signal
import sys
import importlib.util
from pathlib import Path

_dock_spec = importlib.util.spec_from_file_location('dock_settings', Path(__file__).with_name('dock-settings.py'))
dock_settings = importlib.util.module_from_spec(_dock_spec)
_dock_spec.loader.exec_module(dock_settings)


def load_gio():
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio, GLib
    desktop = getattr(Gio, 'DesktopAppInfo', None)
    if desktop is None:
        gi.require_version('GioUnix', '2.0')
        from gi.repository import GioUnix
        desktop = GioUnix.DesktopAppInfo
    return Gio, GLib, desktop


class Catalogue:
    def __init__(self, gio, desktop, emit):
        self.gio = gio
        self.desktop = desktop
        self.emit = emit
        self.applications = {}

    def refresh(self):
        entries = []
        applications = {}
        for app in self.gio.AppInfo.get_all():
            if not isinstance(app, self.desktop) or not app.should_show() or app.get_is_hidden():
                continue
            app_id = app.get_id()
            if not app_id or app_id in applications:
                continue
            icon = app.get_icon()
            icons, icon_file = [], ''
            if isinstance(icon, self.gio.ThemedIcon):
                icons = list(icon.get_names())
            elif isinstance(icon, self.gio.FileIcon):
                icon_file = icon.get_file().get_uri()
            applications[app_id] = app
            entries.append({'id': app_id, 'name': app.get_display_name() or app.get_name() or app_id,
                'genericName': app.get_generic_name() or '', 'keywords': list(app.get_keywords() or []),
                'icons': icons, 'iconFile': icon_file,
                'startupWMClass': getattr(app, 'get_startup_wm_class', lambda: '')() or ''})
        self.applications = applications
        entries.sort(key=lambda item: (item['name'].casefold(), item['id']))
        self.emit({'event': 'catalogue', 'applications': entries})

    def handle(self, message):
        request = message.get('request') if isinstance(message, dict) else None
        if not isinstance(message, dict):
            self.emit({'event': 'error', 'error': 'InvalidRequest'})
            return
        action = message.get('action')
        if action == 'refresh':
            self.refresh()
            return
        if action != 'launch' or not isinstance(message.get('id'), str):
            self.emit({'event': 'error', 'error': 'InvalidRequest'})
            return
        # Only catalogue IDs are accepted. No command text or path is executed here.
        app_id = message['id']
        try:
            app = self.desktop.new(app_id) if app_id in self.applications else None
            if app is None or not app.should_show() or app.get_is_hidden():
                self.emit({'event': 'launched', 'request': request, 'ok': False, 'error': 'ApplicationMissing'})
                self.refresh()
                return
            app.launch_uris_async([], self.gio.AppLaunchContext(), None, self.launched, request)
        except Exception:
            # GError text may contain arbitrary Exec arguments; never log or forward it.
            self.emit({'event': 'launched', 'request': request, 'ok': False, 'error': 'LaunchFailed'})
            return

    def launched(self, app, result, request):
        try:
            if not app.launch_uris_finish(result):
                raise RuntimeError()
        except Exception:
            self.emit({'event': 'launched', 'request': request, 'ok': False, 'error': 'LaunchFailed'})
            return
        self.emit({'event': 'launched', 'request': request, 'ok': True})


def serve(gio, glib, desktop, emit):
    catalogue = Catalogue(gio, desktop, emit)
    loop = glib.MainLoop()
    pending = bytearray()
    refresh_source = 0
    config_monitors = []

    def watch_config():
        for monitor in config_monitors:
            monitor.cancel()
        config_monitors.clear()
        # Watch the nearest existing directory, including atomic file replacements
        # and creation of a previously absent ~/.config/shittim directory.
        directories = set()
        for path in dock_settings.paths():
            directory = path.parent
            while not directory.exists() and directory != directory.parent:
                directory = directory.parent
            directories.add(str(directory))
        for directory in directories:
            try:
                monitor = gio.File.new_for_path(directory).monitor_directory(gio.FileMonitorFlags.NONE, None)
                monitor.connect('changed', lambda *_args: changed(None))
                config_monitors.append(monitor)
            except Exception:
                pass  # F5 / IPC reload remains available on unsupported filesystems.

    def refresh():
        nonlocal refresh_source
        refresh_source = 0
        try:
            watch_config()
            catalogue.refresh()
            emit(dock_settings.read_settings())
        except Exception:
            emit({'event': 'error', 'error': 'CatalogueFailed'})
        return False

    def changed(_monitor):
        nonlocal refresh_source
        if not refresh_source:
            refresh_source = glib.timeout_add(120, refresh)

    def read(_source, condition):
        try:
            while True:
                try:
                    chunk = os.read(sys.stdin.fileno(), 4096)
                except BlockingIOError:
                    break
                if not chunk:
                    loop.quit()
                    return False
                pending.extend(chunk)
                if len(pending) > 16384:
                    emit({'event': 'error', 'error': 'InvalidRequest'})
                    loop.quit()
                    return False
                while b'\n' in pending:
                    line, _, tail = pending.partition(b'\n')
                    pending[:] = tail
                    try:
                        message = json.loads(line)
                        catalogue.handle(message)
                        if isinstance(message, dict) and message.get('action') == 'refresh':
                            watch_config()
                            emit(dock_settings.read_settings())
                    except (ValueError, UnicodeError):
                        emit({'event': 'error', 'error': 'InvalidRequest'})
                    except Exception:
                        emit({'event': 'error', 'error': 'CatalogueFailed'})
        except OSError:
            loop.quit()
            return False
        if condition & (glib.IO_HUP | glib.IO_ERR):
            loop.quit()
            return False
        return True

    monitor = gio.AppInfoMonitor.get()
    monitor.connect('changed', changed)
    os.set_blocking(sys.stdin.fileno(), False)
    glib.io_add_watch(sys.stdin, glib.IO_IN | glib.IO_HUP | glib.IO_ERR, read)
    for name in (signal.SIGTERM, signal.SIGINT):
        glib.unix_signal_add(glib.PRIORITY_DEFAULT, name, lambda: (loop.quit(), False)[1])
    refresh()
    loop.run()


def main():
    try:
        gio, glib, desktop = load_gio()
    except (ImportError, ValueError):
        print(json.dumps({'event': 'error', 'error': 'GioUnavailable'}), flush=True)
        return 1
    if sys.argv[1:] == ['--check']:
        catalogue = Catalogue(gio, desktop, lambda message: print(json.dumps({
            'applications': len(message['applications']), 'gio': True}), flush=True))
        catalogue.refresh()
        return 0
    if sys.argv[1:]:
        return 2
    # Keep IPC on a non-inheritable descriptor. Launched apps must not write into
    # the JSON stream or inherit raw output into the shell journal.
    with os.fdopen(os.dup(sys.stdout.fileno()), 'w', encoding='utf-8', buffering=1) as protocol:
        with open(os.devnull, 'w') as sink:
            os.dup2(sink.fileno(), 1)
            os.dup2(sink.fileno(), 2)
        def emit(value):
            print(json.dumps(value, ensure_ascii=False), file=protocol, flush=True)
        serve(gio, glib, desktop, emit)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (BrokenPipeError, OSError):
        sys.exit(1)
