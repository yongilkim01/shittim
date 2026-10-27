"""Meeting device helper and diagnostic tests; no real camera, PipeWire, D-Bus or Chrome."""
import importlib.util
import io
import json
import os
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
            {'type': 'PipeWire:Interface:Node', 'info': {'props': {'node.name': 'xdph-streaming-Ab12', 'media.class': 'Video/Source'}}},
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


if __name__ == '__main__':
    unittest.main()
