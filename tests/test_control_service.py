"""Control protocol and authentication tests; no real hardware or system bus."""
import asyncio
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import AsyncMock, Mock, patch

SPEC = importlib.util.spec_from_file_location('control_service', Path(__file__).resolve().parents[1] / 'scripts/control-service.py')
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)
DEVICE = '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF'


class Backlight(unittest.TestCase):
    def test_no_hardware_and_broken_sysfs(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            self.assertEqual(TOOL.brightness_devices(base), [])
            device = base / 'panel0'
            device.mkdir()
            (device / 'max_brightness').write_text('1000')
            (device / 'brightness').write_text('450')
            self.assertEqual(TOOL.brightness_devices(base), [{'name': 'panel0', 'value': 0.45, 'maximum': 1000}])
            (device / 'max_brightness').write_text('0')
            self.assertEqual(TOOL.brightness_devices(base), [])

    def test_brightness_is_bounded_and_never_runs_a_shell(self):
        devices = [{'name': 'panel0', 'value': 0.5}]
        self.assertEqual(TOOL.brightness_command('panel0', 3, devices),
                         ['brightnessctl', '--class=backlight', '--device=panel0', '--quiet', 'set', '100%'])
        self.assertEqual(TOOL.brightness_command('panel0', -1, devices)[-1], '1%')
        for name, value in [('panel0; touch injected', 0.5), ('panel0', float('nan')), ('panel0', '50%')]:
            with self.assertRaises(TOOL.ControlError):
                TOOL.brightness_command(name, value, devices)

    def test_only_real_bluez_device_paths_are_accepted(self):
        self.assertTrue(TOOL.valid_device(DEVICE))
        for value in [None, '/org/bluez', DEVICE + '; command', '../../device', '/org/bluez/hci0/dev_AA']:
            self.assertFalse(TOOL.valid_device(value))


class Protocol(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.events = []
        self.bridge = TOOL.Bridge(self.events.append)

    async def test_invalid_requests_do_not_echo_arbitrary_input(self):
        await self.bridge.handle({'id': 1, 'action': 'private-input-not-for-output'})
        self.assertEqual(self.events, [{'event': 'result', 'id': 1, 'ok': False, 'error': 'InvalidAction'}])

    async def test_pair_uses_own_agent_and_clears_prompts(self):
        self.bridge.register_agent = AsyncMock()
        self.bridge.bluez = AsyncMock()
        await self.bridge.handle({'id': 1, 'action': 'pair', 'device': DEVICE})
        self.bridge.register_agent.assert_awaited_once()
        self.bridge.bluez.assert_awaited_once_with(DEVICE, 'Pair', timeout=90)
        self.assertIsNone(self.bridge.pairing)
        self.assertIn({'event': 'result', 'id': 1, 'ok': True}, self.events)

    async def test_pair_failure_restores_state_and_reports_safe_code(self):
        self.bridge.register_agent = AsyncMock()
        self.bridge.bluez = AsyncMock(side_effect=TOOL.ControlError('AuthenticationFailed'))
        await self.bridge.handle({'id': 2, 'action': 'pair', 'device': DEVICE})
        self.assertIsNone(self.bridge.pairing)
        self.assertEqual(self.events[-1]['error'], 'AuthenticationFailed')

    async def test_denied_brightness_is_disabled_until_refresh(self):
        process = Mock()
        process.returncode = 1
        process.communicate = AsyncMock(return_value=(b'', b'Permission denied'))
        with patch.object(TOOL, 'brightness_devices', return_value=[{'name': 'panel0', 'value': 0.5}]), \
                patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)) as spawn:
            await self.bridge.handle({'id': 3, 'action': 'brightness', 'device': 'panel0', 'value': 0.8})
        self.assertIn('panel0', self.bridge.blocked_backlights)
        self.assertEqual(self.events[-2]['error'], 'BrightnessPermissionDenied')
        self.assertFalse(self.events[-1]['backlights'][0]['writable'])
        self.assertNotIn('shell', spawn.call_args.kwargs)

    async def test_failed_cli_uses_owned_active_local_session_without_privilege_changes(self):
        process = Mock(returncode=1)
        process.communicate = AsyncMock(return_value=(b'', b'Failed to set brightness: No session'))
        device = {'name': 'panel0', 'value': 0.32, 'maximum': 937}
        active = '/org/freedesktop/login1/session/_37'
        self.bridge.bus = object()
        self.bridge.call = AsyncMock(side_effect=[[
            [('other', 2000, 'other-user', 'seat0', '/other'),
             ('ours', 1000, 'local-user', 'seat0', active)]
        ], [{'Active': Mock(value=True), 'Remote': Mock(value=False)}], []])
        with patch.object(TOOL.os, 'getuid', return_value=1000, create=True), \
                patch.dict(TOOL.os.environ, {'XDG_SEAT': 'seat0'}), \
                patch.object(TOOL, 'brightness_devices', return_value=[device]), \
                patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)) as spawn:
            await self.bridge.set_brightness('panel0', 0.7)
        self.assertEqual(self.bridge.call.await_count, 3)
        self.assertEqual(self.bridge.call.call_args.args,
            ('org.freedesktop.login1', active, 'org.freedesktop.login1.Session',
             'SetBrightness', 'ssu', ['backlight', 'panel0', 656]))
        self.assertEqual(spawn.call_args.args[0], 'brightnessctl')
        self.assertFalse(self.bridge.blocked_backlights)

    async def test_inactive_remote_and_ambiguous_sessions_cannot_control_brightness(self):
        session = '/org/freedesktop/login1/session/_37'
        properties = lambda active, remote: [{'Active': Mock(value=active), 'Remote': Mock(value=remote)}]
        for records, replies in [
                ([('ours', 1000, 'u', 'seat0', session)], [properties(False, False)]),
                ([('ours', 1000, 'u', 'seat0', session)], [properties(True, True)]),
                ([('ours', 1000, 'u', 'seat0', session), ('ours2', 1000, 'u', 'seat1', session + '1')],
                 [properties(True, False), properties(True, False)])]:
            with self.subTest(records=records, replies=replies), \
                    patch.object(TOOL.os, 'getuid', return_value=1000, create=True), \
                    patch.dict(TOOL.os.environ, {'XDG_SEAT': ''}):
                self.bridge.call = AsyncMock(side_effect=[[records]] + replies)
                with self.assertRaisesRegex(TOOL.ControlError, 'BrightnessSessionUnavailable'):
                    await self.bridge.logind_brightness({'name': 'panel0', 'maximum': 1000}, 50)
                self.assertFalse(any(call.args[3] == 'SetBrightness' for call in self.bridge.call.call_args_list))

    async def test_successful_cli_does_not_need_a_login_session(self):
        process = Mock(returncode=0)
        process.communicate = AsyncMock(return_value=(b'', b''))
        self.bridge.logind_brightness = AsyncMock()
        with patch.object(TOOL, 'brightness_devices', return_value=[{'name': 'panel0'}]), \
                patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)):
            await self.bridge.set_brightness('panel0', 0.6)
        self.bridge.logind_brightness.assert_not_awaited()

    async def test_command_error_is_not_misreported_as_permission_denied_or_logged(self):
        process = Mock(returncode=1)
        process.communicate = AsyncMock(return_value=(b'', b'device error private-marker'))
        self.bridge.snapshot = AsyncMock()
        with patch.object(TOOL, 'brightness_devices', return_value=[{'name': 'panel0'}]), \
                patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)):
            await self.bridge.handle({'id': 7, 'action': 'brightness', 'device': 'panel0', 'value': 0.6})
        self.assertEqual(self.events[-1]['error'], 'BrightnessCommandFailed')
        self.assertFalse(self.bridge.blocked_backlights)
        self.assertNotIn('private-marker', repr(self.events))
        self.bridge.snapshot.assert_awaited_once()

    async def test_timed_out_brightness_process_is_killed_and_reaped(self):
        process = Mock()
        process.communicate = AsyncMock(side_effect=asyncio.TimeoutError)
        process.wait = AsyncMock(return_value=-9)
        with patch.object(TOOL, 'brightness_devices', return_value=[{'name': 'panel0'}]), \
                patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)):
            with self.assertRaisesRegex(TOOL.ControlError, 'BrightnessTimeout'):
                await self.bridge.set_brightness('panel0', 0.6)
        process.kill.assert_called_once()
        process.wait.assert_awaited_once()

    async def test_profile_without_daemon_returns_error_not_success(self):
        try:
            import dbus_next  # noqa: F401
        except ImportError:
            self.skipTest('dbus-next가 있는 Linux 검사 환경에서 실행')
        await self.bridge.handle({'id': 4, 'action': 'profile', 'profile': 'balanced'})
        self.assertFalse(self.events[-1]['ok'])
        self.assertEqual(self.events[-1]['error'], 'BusUnavailable')

    async def test_screenshot_uses_generated_picture_path_and_argument_list(self):
        with tempfile.TemporaryDirectory() as directory:
            process = Mock()
            process.wait = AsyncMock(return_value=0)
            with patch.object(TOOL.Path, 'home', return_value=Path(directory)), \
                    patch.object(TOOL.os, 'umask'), patch.object(TOOL.shutil, 'which', return_value=None), \
                    patch.object(TOOL.asyncio, 'sleep', new=AsyncMock()), \
                    patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=process)) as spawn:
                self.assertEqual(await TOOL.screenshot(), 0)
            arguments = spawn.call_args.args
            self.assertEqual(arguments[0], 'grim')
            self.assertEqual(Path(arguments[1]).parent, Path(directory) / 'Pictures/Screenshots')

    async def test_region_cancel_and_untrusted_geometry_do_not_capture(self):
        for returncode, geometry in [(1, b''), (0, b'0,0 1x1; evil')]:
            selector = Mock(returncode=returncode)
            selector.communicate = AsyncMock(return_value=(geometry, b''))
            with patch.object(TOOL.os, 'umask'), patch.object(TOOL.asyncio, 'sleep', new=AsyncMock()), \
                    patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(return_value=selector)) as spawn:
                self.assertEqual(await TOOL.screenshot('region'), 0 if returncode else 1)
                self.assertEqual(spawn.call_count, 1)

    async def test_region_capture_and_copy_use_separate_argument_lists(self):
        with tempfile.TemporaryDirectory() as directory:
            selector = Mock(returncode=0); selector.communicate = AsyncMock(return_value=(b'-20,10 100x200\n', b''))
            process = Mock(); process.wait = AsyncMock(return_value=0)
            async def capture(*args, **kwargs):
                if args[0] == 'slurp': return selector
                if args[0] == 'grim': Path(args[-1]).write_bytes(b'fixture image')
                return process
            with patch.object(TOOL.Path, 'home', return_value=Path(directory)), patch.object(TOOL.os, 'umask'), \
                    patch.object(TOOL.shutil, 'which', side_effect=lambda name: '/usr/bin/wl-copy' if name == 'wl-copy' else None), \
                    patch.object(TOOL.asyncio, 'sleep', new=AsyncMock()), \
                    patch.object(TOOL.asyncio, 'create_subprocess_exec', new=AsyncMock(side_effect=capture)) as spawn:
                self.assertEqual(await TOOL.screenshot('region'), 0)
                self.assertEqual(spawn.call_args_list[1].args[:3], ('grim', '-g', '-20,10 100x200'))
                self.assertEqual(spawn.call_args_list[2].args, ('wl-copy', '--type', 'image/png'))
            self.assertNotIn('shell', spawn.call_args.kwargs)

    async def test_agent_signatures_and_explicit_user_confirmation(self):
        try:
            from dbus_next import DBusError
            from dbus_next.service import ServiceInterface
        except ImportError:
            self.skipTest('dbus-next가 있는 Linux 검사 환경에서 실행')
        self.bridge.bus = Mock()
        self.bridge.call = AsyncMock(return_value=[])
        await self.bridge.register_agent()
        methods = {method.name: method for method in ServiceInterface._get_methods(self.bridge.agent)}
        self.assertEqual(methods['RequestConfirmation'].in_signature, 'ou')
        self.assertEqual(methods['RequestPasskey'].out_signature, 'u')
        self.bridge.pairing = DEVICE
        request = asyncio.create_task(methods['RequestConfirmation'].fn(self.bridge.agent, DEVICE, 123456))
        await asyncio.sleep(0)
        prompt = self.events[-1]
        self.assertEqual(prompt['code'], '123456')
        self.assertFalse(request.done())
        await self.bridge.handle({'action': 'reply', 'request': prompt['request'], 'accept': True})
        await request
        with self.assertRaises(DBusError):
            await self.bridge.request('/org/bluez/hci0/dev_00_00_00_00_00_00', 'authorize')


if __name__ == '__main__':
    unittest.main()
