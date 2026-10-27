"""Meeting device helper and diagnostic tests; no real camera, PipeWire, D-Bus or Chrome."""
import importlib.util
import io
import json
import os
import subprocess
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CAMERA = load('camera_service', 'scripts/camera-service.py')
CHECK = load('meeting_check', 'scripts/meeting-check.py')


class FakeSystem:
    """sysfs/proc trees in a temporary directory; /proc fd links point at /dev/videoN strings."""
    def __init__(self, base):
        self.sysfs, self.proc = base / 'sys', base / 'proc'
        self.sysfs.mkdir()
        self.proc.mkdir()

    def camera(self, node, name):
        (self.sysfs / node).mkdir()
        (self.sysfs / node / 'name').write_text(name + '\n')

    def process(self, pid, comm, targets):
        directory = self.proc / str(pid)
        (directory / 'fd').mkdir(parents=True)
        (directory / 'comm').write_text(comm + '\n')
        for index, target in enumerate(targets):
            os.symlink(target, directory / 'fd' / str(index))


@unittest.skipIf(os.name == 'nt', 'symlink-based /proc fixture needs POSIX')
class CameraService(unittest.TestCase):
    def test_capture_and_metadata_nodes(self):
        self.assertTrue(CAMERA.capture_capable((CAMERA.CAP_DEVICE_CAPS | 0x1, 0x1)))
        # Second node of a UVC webcam: metadata only, even though the device as a whole can capture.
        self.assertFalse(CAMERA.capture_capable((CAMERA.CAP_DEVICE_CAPS | 0x1, 0x00800000)))
        self.assertTrue(CAMERA.capture_capable((CAMERA.CAP_VIDEO_CAPTURE_MPLANE, 0)))

    def test_snapshot_reports_presence_users_and_permission(self):
        with tempfile.TemporaryDirectory() as directory:
            system = FakeSystem(Path(directory))
            system.camera('video0', 'Integrated Camera')
            system.camera('video1', 'Integrated Camera')
            system.camera('video2', 'USB Camera')
            system.process(100, 'chrome', ['/dev/video0', '/dev/null'])
            system.process(101, 'chrome', ['/dev/video0'])
            system.process(os.getpid(), 'self', ['/dev/video2'])
            caps = {'/dev/video0': (CAMERA.CAP_DEVICE_CAPS | 1, 1), '/dev/video1': (CAMERA.CAP_DEVICE_CAPS | 1, 0x00800000),
                    '/dev/video2': 'permission'}
            queries = []
            cameras = CAMERA.Cameras(system.sysfs, Path('/dev'), system.proc, lambda path: queries.append(path) or caps[path])
            self.assertEqual(cameras.snapshot(), [
                {'node': 'video0', 'name': 'Integrated Camera', 'error': '', 'users': ['chrome']},
                {'node': 'video2', 'name': 'USB Camera', 'error': 'permission', 'users': []}])
            cameras.snapshot()
            # Capabilities are cached: the query's own open must not cause a re-scan loop.
            self.assertEqual(len(queries), 3)

    def test_no_cameras(self):
        with tempfile.TemporaryDirectory() as directory:
            system = FakeSystem(Path(directory))
            self.assertEqual(CAMERA.Cameras(system.sysfs, Path('/dev'), system.proc, lambda path: 'unavailable').snapshot(), [])
            self.assertEqual(CAMERA.Cameras(Path(directory) / 'missing', Path('/dev'), system.proc).snapshot(), [])

    def test_removed_camera_drops_cached_caps(self):
        with tempfile.TemporaryDirectory() as directory:
            system = FakeSystem(Path(directory))
            system.camera('video0', 'USB Camera')
            cameras = CAMERA.Cameras(system.sysfs, Path('/dev'), system.proc, lambda path: (1, 0))
            self.assertEqual(len(cameras.snapshot()), 1)
            (system.sysfs / 'video0' / 'name').unlink()
            (system.sysfs / 'video0').rmdir()
            self.assertEqual(cameras.snapshot(), [])
            self.assertEqual(cameras.caps, {})


class PortalConfig(unittest.TestCase):
    def run_check(self, function, *args):
        report = CHECK.Report()
        output = io.StringIO()
        with redirect_stdout(output):
            function(report, *args)
        return report, output.getvalue()

    def test_repository_portal_file_selects_hyprland_for_capture(self):
        preferences = CHECK.portal_preferences((ROOT / 'config/hyprland-portals.conf').read_text(encoding='utf-8'))
        self.assertEqual(preferences['org.freedesktop.impl.portal.ScreenCast'], 'hyprland')
        self.assertEqual(preferences['org.freedesktop.impl.portal.Screenshot'], 'hyprland')
        self.assertEqual(preferences['org.freedesktop.impl.portal.FileChooser'], 'gtk')

    def test_installed_portal_file_states(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            report, output = self.run_check(CHECK.check_portal_config, home)
            self.assertEqual(report.failures, 1)
            self.assertIn('setup-desktop.sh', output)
            target = home / 'xdg-desktop-portal/hyprland-portals.conf'
            target.parent.mkdir()
            target.write_text((ROOT / 'config/hyprland-portals.conf').read_text(encoding='utf-8'), encoding='utf-8')
            report, _ = self.run_check(CHECK.check_portal_config, home)
            self.assertEqual((report.failures, report.warnings), (0, 0))
            target.write_text('[preferred]\ndefault=gtk\n', encoding='utf-8')
            report, _ = self.run_check(CHECK.check_portal_config, home)
            self.assertEqual(report.failures, 1)
            target.write_text('[preferred]\ndefault=hyprland;gtk\n', encoding='utf-8')
            report, _ = self.run_check(CHECK.check_portal_config, home)
            self.assertEqual((report.failures, report.warnings), (0, 1))

    def test_source_types(self):
        self.assertEqual(CHECK.parse_busctl_uint('u 7\n'), 7)
        self.assertIsNone(CHECK.parse_busctl_uint('Failed to get property'))
        self.assertEqual(CHECK.source_type_names(3), ['모니터', '창'])


class ChromeAndDevices(unittest.TestCase):
    def test_chrome_flags(self):
        self.assertEqual(CHECK.chrome_flag_findings('# comment\n\n--enable-smooth-scrolling\n'), [])
        levels = [level for level, _ in CHECK.chrome_flag_findings(
            '--use-fake-ui-for-media-stream\n--ozone-platform=x11\n--disable-features=WebRTCPipeWireCapturer\n'
            '--enable-features=WebRTCPipeWireCapturer\n--auto-select-desktop-capture-source="Entire screen"\n')]
        self.assertEqual(levels, ['실패', '주의', '실패', '정보', '실패'])

    def test_chrome_windows_from_hyprctl(self):
        clients = json.dumps([{'class': 'google-chrome', 'title': 'Meet', 'xwayland': False},
                              {'class': 'kitty', 'title': 'shell', 'xwayland': False},
                              {'class': 'Google-chrome', 'title': 'old', 'xwayland': True}])
        self.assertEqual(CHECK.chrome_windows(clients), [('Meet', False), ('old', True)])
        self.assertIsNone(CHECK.chrome_windows(None))
        self.assertIsNone(CHECK.chrome_windows('not json'))

    def test_audio_devices_skip_monitors(self):
        sources = json.dumps([{'name': 'alsa_output.monitor', 'description': 'Monitor of Speakers', 'monitor_of_sink': 'alsa_output'},
                              {'name': 'alsa_input', 'description': 'Built-in Microphone', 'monitor_of_sink': 'n/a'},
                              {'name': 'bluez_input', 'description': 'Headset'}])
        self.assertEqual(CHECK.audio_devices(sources, 'sources'), ['Built-in Microphone', 'Headset'])
        self.assertEqual(CHECK.audio_devices('[]', 'sinks'), [])
        self.assertIsNone(CHECK.audio_devices('', 'sinks'))

    def test_screencast_nodes_from_pw_dump(self):
        dump = json.dumps([
            {'type': 'PipeWire:Interface:Node', 'info': {'props': {'node.name': 'xdg-desktop-portal-hyprland', 'media.name': 'xdph-streaming-Ab12', 'media.class': 'Video/Source'}}},
            {'type': 'PipeWire:Interface:Node', 'info': {'props': {'node.name': 'v4l2_input.usb', 'media.class': 'Video/Source'}}},
            {'type': 'PipeWire:Interface:Port', 'info': {'props': {'node.name': 'xdph-streaming-port'}}}])
        self.assertEqual(CHECK.screencast_nodes(dump), ['xdph-streaming-Ab12'])
        self.assertEqual(CHECK.screencast_nodes('[]'), [])

    def test_missing_camera_is_not_an_install_failure(self):
        report = CHECK.Report()
        with patch.object(CHECK, 'run', return_value=(0, json.dumps({'event': 'state', 'cameras': []}))), redirect_stdout(io.StringIO()) as output:
            CHECK.check_cameras(report)
        self.assertEqual(report.failures, 0)
        self.assertIn('[장치 없음] 카메라 장치 없음', output.getvalue())

    def test_commands_never_use_a_shell(self):
        with patch.object(CHECK.subprocess, 'run') as runner:
            runner.return_value.returncode, runner.return_value.stdout = 0, ''
            CHECK.run(['pacman', '-Q', '--', 'pipewire'])
        self.assertNotIn('shell', runner.call_args.kwargs)
        self.assertIsInstance(runner.call_args.args[0], list)


DESKTOP = load('desktop_tool_meeting', 'scripts/desktop-tool.py')


class PickerConfig(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name); self.root = base / 'repo with spaces'; self.home = base / 'home'
        self.root.mkdir(); self.home.mkdir()
        self.env = patch.dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                              XDG_STATE_HOME=str(self.home / '.local/state'), HYPRLAND_INSTANCE_SIGNATURE='')
        self.env.start(); self.addCleanup(self.env.stop)
        for relative in ['config/hyprland-portals.conf', 'dotfiles/hypr/shittim-lock.conf']:
            path = self.root / relative; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text((ROOT / relative).read_text(encoding='utf-8'), encoding='utf-8')
        self.desktop = DESKTOP.Desktop(DESKTOP.files.Config(self.root, self.home))
        self.xdph = self.home / '.config/hypr/xdph.conf'

    def setup_desktop(self):
        with patch.object(self.desktop, 'installed', return_value=set(DESKTOP.APPLICATIONS)), patch.object(DESKTOP.subprocess, 'run'), \
                redirect_stdout(io.StringIO()) as output:
            try:
                self.desktop.setup()
            except OSError:
                if os.name == 'nt': self.skipTest('Windows 심볼릭 링크 권한 없음')
                raise
        return output.getvalue()

    def test_managed_xdph_config_points_to_wrapper_and_allows_tokens(self):
        self.setup_desktop()
        settings = CHECK.xdph_settings(self.xdph.read_text(encoding='utf-8'))
        self.assertEqual(settings['custom_picker_binary'], str(self.root.resolve() / 'scripts/share-picker.sh'))
        self.assertEqual(settings['allow_token_by_default'], 'true')
        first = self.xdph.read_text(encoding='utf-8')
        self.setup_desktop()
        self.assertEqual(first, self.xdph.read_text(encoding='utf-8'))

    def test_user_xdph_config_is_never_overwritten(self):
        self.xdph.parent.mkdir(parents=True)
        self.xdph.write_text('screencopy {\n    max_fps = 30\n}\n', encoding='utf-8')
        output = self.setup_desktop()
        self.assertEqual(self.xdph.read_text(encoding='utf-8'), 'screencopy {\n    max_fps = 30\n}\n')
        self.assertIn('기존 사용자 xdph.conf 유지', output)

    def test_check_picker_reports_default_picker_and_token(self):
        report = CHECK.Report()
        with redirect_stdout(io.StringIO()) as output:
            CHECK.check_picker(report, self.home / '.config')
        self.assertEqual(report.failures, 0)
        self.assertEqual(report.warnings, 2)
        self.assertIn('기본 선택 창', output.getvalue())

    def test_xdph_settings_ignore_other_sections_and_comments(self):
        text = '# c\ngeneral {\n    custom_picker_binary = /wrong\n}\nscreencopy {\n    allow_token_by_default = true # yes\n}\n'
        self.assertEqual(CHECK.xdph_settings(text), {'allow_token_by_default': 'true'})


@unittest.skipIf(os.name == 'nt', 'bash wrapper needs POSIX')
class PickerWrapper(unittest.TestCase):
    """share-picker.sh with fake quickshell/hyprland-share-picker on PATH."""
    def run_wrapper(self, quickshell_body, *args):
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory) / 'bin'; bin_dir.mkdir()
            for name, body in (('quickshell', quickshell_body), ('hyprland-share-picker', 'echo "[SELECTION]/screen:FALLBACK $*"')):
                path = bin_dir / name
                path.write_text('#!/usr/bin/env bash\n' + body + '\n'); path.chmod(0o755)
            environment = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ.get('PATH', ''), XDG_RUNTIME_DIR=directory)
            result = subprocess.run(['bash', str(ROOT / 'scripts/share-picker.sh'), *args], capture_output=True, text=True, env=environment, timeout=20)
            leftovers = list(Path(directory).glob('shittim-share-picker.*'))
        return result, leftovers

    def test_selection_is_printed_once_with_newline(self):
        result, leftovers = self.run_wrapper('[[ $SHITTIM_PICKER_ALLOW_TOKEN == 1 ]] && printf "[SELECTION]r/screen:eDP-1\\n" > "$SHITTIM_PICKER_OUTPUT"; echo noise', '--allow-token')
        self.assertEqual((result.returncode, result.stdout), (0, '[SELECTION]r/screen:eDP-1\n'))
        self.assertEqual(leftovers, [])

    def test_cancel_prints_nothing_and_fails(self):
        result, leftovers = self.run_wrapper('printf "[CANCEL]\\n" > "$SHITTIM_PICKER_OUTPUT"')
        self.assertEqual((result.returncode, result.stdout), (1, ''))
        self.assertEqual(leftovers, [])

    def test_crashed_hud_picker_falls_back_to_official_picker(self):
        result, leftovers = self.run_wrapper('exit 3', '--allow-token')
        self.assertEqual(result.stdout, '[SELECTION]/screen:FALLBACK --allow-token\n')
        self.assertEqual(leftovers, [])


if __name__ == '__main__':
    unittest.main()
