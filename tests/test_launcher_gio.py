"""Real GIO tests in isolated XDG dirs; launch only temporary test programs."""
import importlib.util
import json
import os
import selectors
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
try:
    SPEC = importlib.util.spec_from_file_location('launcher_gio', ROOT / 'scripts/launcher-service.py')
    TOOL = importlib.util.module_from_spec(SPEC)
    SPEC.loader.exec_module(TOOL)
    TOOL.load_gio()
    AVAILABLE = sys.platform == 'linux'
except (ImportError, ValueError):
    AVAILABLE = False


@unittest.skipUnless(AVAILABLE, 'Linux + python-gobject에서 실제 GIO 검사를 실행')
class GioIntegration(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='shittim-launcher-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.user = self.base / 'user data/applications'
        self.system = self.base / 'system data/applications'
        self.user.mkdir(parents=True); self.system.mkdir(parents=True)
        self.environment = dict(os.environ, XDG_DATA_HOME=str(self.user.parent), XDG_DATA_DIRS=str(self.system.parent),
                                XDG_CONFIG_HOME=str(self.base / 'config'), XDG_CACHE_HOME=str(self.base / 'cache'),
                                XDG_CURRENT_DESKTOP='Hyprland', LANG='C.UTF-8')

    def desktop(self, directory, name, fields):
        path = directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/true\n' + fields, encoding='utf-8')
        return path

    def run_code(self, code):
        return subprocess.run([sys.executable, '-c', code], env=self.environment, check=True,
                              capture_output=True, text=True, timeout=10).stdout

    def test_xdg_precedence_hidden_nodisplay_tryexec_and_desktop_visibility(self):
        self.desktop(self.system, 'duplicate.desktop', 'Name=System\n')
        self.desktop(self.user, 'duplicate.desktop', 'Name=User Override\nGenericName=Generic\nKeywords=one;two;\n')
        self.desktop(self.system, 'masked.desktop', '')
        self.desktop(self.user, 'masked.desktop', 'Hidden=true\n')
        self.desktop(self.user, 'nodisplay.desktop', 'NoDisplay=true\n')
        self.desktop(self.user, 'other.desktop', 'OnlyShowIn=KDE;\n')
        self.desktop(self.user, 'not-hypr.desktop', 'NotShowIn=Hyprland;\n')
        self.desktop(self.user, 'missing.desktop', 'TryExec=shittim-nonexistent-executable\n')
        self.desktop(self.user / 'nested', 'name.desktop', 'Name=Nested\n')
        code = ('import importlib.util,json; s=importlib.util.spec_from_file_location("launcher",' + repr(str(ROOT / 'scripts/launcher-service.py')) + '); '
                'm=importlib.util.module_from_spec(s); s.loader.exec_module(m); g,l,d=m.load_gio(); m.Catalogue(g,d,lambda x: print(json.dumps(x))).refresh()')
        apps = json.loads(self.run_code(code))['applications']
        self.assertEqual({app['id'] for app in apps}, {'duplicate.desktop', 'nested-name.desktop'})
        self.assertEqual(next(app for app in apps if app['id'] == 'duplicate.desktop')['name'], 'User Override')

    def test_exec_arguments_field_codes_working_directory_and_terminal(self):
        working = self.base / 'work dir'; working.mkdir()
        output = self.base / 'launched.json'
        recorder = self.base / 'record.py'
        recorder.write_text('import json,os,sys\nfrom pathlib import Path\nPath(sys.argv[1]).write_text(json.dumps({"args":sys.argv[2:],"cwd":os.getcwd()}))\n')
        terminal = self.base / 'bin'; terminal.mkdir()
        shim = terminal / 'xdg-terminal-exec'
        shim.write_text('#!/bin/sh\nprintf terminal > "$SHITTIM_TERMINAL_MARKER"\nexec "$@"\n')
        shim.chmod(0o755)
        self.environment.update(PATH=str(terminal) + os.pathsep + os.environ['PATH'], SHITTIM_TERMINAL_MARKER=str(self.base / 'terminal-called'))
        for is_terminal in [False, True]:
            with self.subTest(terminal=is_terminal):
                output.unlink(missing_ok=True)
                app = self.desktop(self.user, 'launch.desktop', 'Name=한글 앱\nIcon=fixture-icon\nPath=' + str(working) + '\n'
                    'Terminal=' + str(is_terminal).lower() + '\nExec="' + sys.executable + '" "' + str(recorder) + '" "' + str(output) + '" "two words" %c %k %i %f %F %u %U %%\n')
                code = ('import importlib.util; s=importlib.util.spec_from_file_location("launcher",' + repr(str(ROOT / 'scripts/launcher-service.py')) + '); '
                        'm=importlib.util.module_from_spec(s); s.loader.exec_module(m); g,l,d=m.load_gio(); '
                        'a=d.new("launch.desktop"); assert a.launch([],g.AppLaunchContext())')
                self.run_code(code)
                deadline = time.monotonic() + 5
                while not output.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(output.exists())
                data = json.loads(output.read_text())
                self.assertEqual(data['cwd'], str(working))
                self.assertEqual(data['args'], ['two words', '한글 앱', str(app), '--icon', 'fixture-icon', '%'])
        self.assertTrue((self.base / 'terminal-called').exists())

    def test_shared_catalogue_startup_class_and_live_personal_dock_preferences(self):
        self.desktop(self.user, 'dock.desktop', 'Name=Dock Fixture\nStartupWMClass=ExactFixtureClass\n')
        process = subprocess.Popen([sys.executable, str(ROOT / 'scripts/launcher-service.py')], env=self.environment,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        def cleanup():
            if process.poll() is None:
                process.stdin.close()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=3)
            process.stdout.close(); process.stderr.close()
        self.addCleanup(cleanup)
        selector = selectors.DefaultSelector(); selector.register(process.stdout, selectors.EVENT_READ)
        self.addCleanup(selector.close)
        pending = bytearray()
        def receive(predicate):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                while b'\n' in pending:
                    line, _, tail = pending.partition(b'\n'); pending[:] = tail
                    message = json.loads(line)
                    if predicate(message):
                        return message
                if selector.select(0.1):
                    pending.extend(os.read(process.stdout.fileno(), 65536))
            self.fail('shared dock service response timed out')
        catalogue = receive(lambda message: message.get('event') == 'catalogue')
        app = next(app for app in catalogue['applications'] if app['id'] == 'dock.desktop')
        self.assertEqual(app['startupWMClass'], 'ExactFixtureClass')
        receive(lambda message: message.get('event') == 'dock')
        personal = Path(self.environment['XDG_CONFIG_HOME']) / 'shittim/dock.json'
        personal.parent.mkdir(parents=True)
        personal.write_text('{"favorites":["dock.desktop"],"windowClasses":{"dock.desktop":["ExactFixtureClass"]}}')
        dock = receive(lambda message: message.get('event') == 'dock' and message.get('favorites') == ['dock.desktop'])
        self.assertEqual(dock['windowClasses'], {'dock.desktop': ['ExactFixtureClass']})
        replacement = personal.with_suffix('.new')
        replacement.write_text('{"favorites":[]}'); replacement.replace(personal)
        receive(lambda message: message.get('event') == 'dock' and message.get('favorites') == [] and not message.get('error'))
        personal.write_text('invalid config')
        receive(lambda message: message.get('error') == 'DockConfigInvalid')
        personal.unlink()
        process.stdin.write(b'{"action":"refresh"}\n')
        receive(lambda message: message.get('event') == 'dock' and not message.get('error') and 'kitty.desktop' in message.get('favorites', []))

    def test_desktop_defaults_are_resolved_by_real_gio(self):
        for name in ['google-chrome.desktop', 'org.shittim.Files.desktop', 'swayimg.desktop', 'vlc.desktop', 'org.pwmt.zathura.desktop']:
            self.desktop(self.user, name, 'Name=Desktop association fixture\n')
        self.environment['HOME'] = str(self.base / 'home'); Path(self.environment['HOME']).mkdir()
        self.environment['XDG_STATE_HOME'] = str(self.base / 'state')
        code = ('import importlib.util; from pathlib import Path; s=importlib.util.spec_from_file_location("desktop",'
                + repr(str(ROOT / 'scripts/desktop-tool.py')) + '); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); '
                'd=m.Desktop(); d.setup(); g,l,a=m.module("launcher","launcher-service.py").load_gio(); '
                'expected={"inode/directory":"org.shittim.Files.desktop","x-scheme-handler/https":"google-chrome.desktop",'
                '"image/webp":"swayimg.desktop","application/pdf":"org.pwmt.zathura.desktop","audio/flac":"vlc.desktop"}; '
                '[(lambda app: (app is not None and app.get_id()==value) or (_ for _ in ()).throw(AssertionError(key)))'
                '(g.AppInfo.get_default_for_type(key,False)) for key,value in expected.items()]')
        self.run_code(code)

    def test_desktop_setup_with_missing_and_hidden_apps_uses_only_installed_entries(self):
        self.desktop(self.user, 'org.shittim.Files.desktop', 'Name=Installed file manager\n')
        self.desktop(self.user, 'vlc.desktop', 'Hidden=true\n')
        self.desktop(self.user, 'swayimg.desktop', 'TryExec=shittim-nonexistent-image-viewer\n')
        self.environment['HOME'] = str(self.base / 'home'); Path(self.environment['HOME']).mkdir()
        self.environment['XDG_STATE_HOME'] = str(self.base / 'state')
        code = ('import importlib.util,json; s=importlib.util.spec_from_file_location("desktop",'
                + repr(str(ROOT / 'scripts/desktop-tool.py')) + '); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); '
                'd=m.Desktop(); assert d.installed()=={"org.shittim.Files.desktop"}; d.setup(); '
                'data=json.loads(d.manifest.read_text()); assert data["defaults"]=={"inode/directory":"org.shittim.Files.desktop"}')
        self.run_code(code)

    def test_nodisplay_viewer_is_a_mime_default_but_stays_out_of_launcher(self):
        self.desktop(self.user, 'swayimg.desktop', 'NoDisplay=true\nMimeType=image/png;image/webp;\n')
        self.environment['HOME'] = str(self.base / 'home'); Path(self.environment['HOME']).mkdir()
        self.environment['XDG_STATE_HOME'] = str(self.base / 'state')
        code = ('import importlib.util,json; s=importlib.util.spec_from_file_location("desktop",'
                + repr(str(ROOT / 'scripts/desktop-tool.py')) + '); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); '
                'd=m.Desktop(); assert d.installed()=={"swayimg.desktop"}; d.setup(); '
                'data=json.loads(d.manifest.read_text()); assert data["defaults"]["image/png"]=="swayimg.desktop"; '
                'launcher=m.module("launcher","launcher-service.py"); g,l,a=launcher.load_gio(); '
                'assert g.AppInfo.get_default_for_type("image/png",False).get_id()=="swayimg.desktop"; '
                'messages=[]; launcher.Catalogue(g,a,messages.append).refresh(); '
                'assert not any(app["id"]=="swayimg.desktop" for app in messages[0]["applications"])')
        self.run_code(code)

    def test_service_watches_app_changes_and_keeps_child_output_out_of_protocol(self):
        output = self.base / 'child-finished'
        recorder = self.base / 'noisy.py'
        recorder.write_text('from pathlib import Path\nprint("not-json-from-child", flush=True)\nPath(' + repr(str(output)) + ').touch()\n')
        self.desktop(self.user, 'noisy.desktop', 'Exec="' + sys.executable + '" "' + str(recorder) + '"\n')
        process = subprocess.Popen([sys.executable, str(ROOT / 'scripts/launcher-service.py')], env=self.environment,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        def cleanup():
            if process.poll() is None:
                process.stdin.close()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=3)
            process.stdout.close(); process.stderr.close()
        self.addCleanup(cleanup)
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        self.addCleanup(selector.close)
        pending = bytearray()
        def receive(predicate):
            deadline = time.monotonic() + 8
            while time.monotonic() < deadline:
                while b'\n' in pending:
                    line, _, tail = pending.partition(b'\n'); pending[:] = tail
                    message = json.loads(line)
                    if predicate(message): return message
                if selector.select(0.1):
                    chunk = os.read(process.stdout.fileno(), 65536)
                    if not chunk: self.fail('launcher service exited before response')
                    pending.extend(chunk)
            self.fail('launcher service response timed out')
        is_catalogue = lambda message: message.get('event') == 'catalogue'
        receive(is_catalogue)
        self.desktop(self.user, 'added.desktop', 'Name=Added\n')
        receive(lambda message: is_catalogue(message) and any(app['id'] == 'added.desktop' for app in message['applications']))
        process.stdin.write(b'{"action":"launch","id":"noisy.desktop","request":1}\n')
        launched = receive(lambda message: message.get('event') == 'launched')
        self.assertTrue(launched['ok'])
        deadline = time.monotonic() + 5
        while not output.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(output.exists())
        process.stdin.write(b'{"action":"refresh"}\n{"action":"refresh"}\n')
        receive(is_catalogue); receive(is_catalogue)
        executable = self.base / 'removed-app'
        executable.write_text('#!/bin/sh\nexit 0\n'); executable.chmod(0o755)
        self.desktop(self.user, 'removed.desktop', 'Exec=' + str(executable) + '\n')
        receive(lambda message: is_catalogue(message) and any(app['id'] == 'removed.desktop' for app in message['applications']))
        executable.unlink()
        process.stdin.write(b'{"action":"launch","id":"removed.desktop","request":2}\n')
        failed = receive(lambda message: message.get('event') == 'launched' and message.get('request') == 2)
        self.assertFalse(failed['ok'])
        self.assertIn(failed['error'], ['ApplicationMissing', 'LaunchFailed'])


if __name__ == '__main__':
    unittest.main()
