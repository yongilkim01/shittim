"""Read-only conflict discovery and isolated session-bus ownership checks."""
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('notification_owner', ROOT / 'scripts/notification-owner.py')
OWNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(OWNER)


class NotificationOwner(unittest.TestCase):
    def test_audit_reports_paths_without_payloads_or_mutations(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            config, data = base / 'config', base / 'data'
            lua = config / 'hypr/hyprland.lua'
            lua.parent.mkdir(parents=True)
            lua.write_text('hl.exec_cmd("mako")\nlocal private_value = "DO_NOT_PRINT"\n')
            activation = data / 'dbus-1/services/org.test.service'
            activation.parent.mkdir(parents=True)
            activation.write_text('[D-BUS Service]\nName=org.freedesktop.Notifications\nExec=DO_NOT_EXECUTE\n')
            before = {path: path.read_bytes() for path in (lua, activation)}
            with patch.dict(os.environ, {'XDG_CONFIG_HOME': str(config), 'XDG_CONFIG_DIRS': str(base / 'empty'), 'XDG_DATA_HOME': str(data), 'XDG_DATA_DIRS': str(base / 'empty')}):
                result = OWNER.audit(system_dirs=[])
            self.assertEqual(result['activationFiles'], [str(activation)])
            self.assertEqual(result['autostartCandidates'], [str(lua)])
            self.assertNotIn('DO_NOT_PRINT', json.dumps(result))
            self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_non_shittim_process_does_not_count_as_owner(self):
        self.assertFalse(OWNER.shittim_process(os.getpid()))
        self.assertFalse(OWNER.shittim_process(-1))

    @unittest.skipUnless(sys.platform == 'linux' and shutil.which('dbus-run-session'), 'requires isolated Linux session bus')
    def test_bus_missing_conflict_and_recovery_events(self):
        result = subprocess.run(['dbus-run-session', '--', sys.executable, str(Path(__file__).resolve()), '--bus-scenario'],
            capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


async def bus_scenario():
    from dbus_next.aio import MessageBus
    bus = await MessageBus().connect()
    child = await asyncio.create_subprocess_exec(sys.executable, str(ROOT / 'scripts/notification-owner.py'), '--watch',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)

    async def state():
        return json.loads(await asyncio.wait_for(child.stdout.readline(), 5))

    try:
        assert (await state())['state'] == 'missing'
        await bus.request_name(OWNER.NAME)
        owned = await state()
        assert owned['state'] == 'owned' and owned['pid'] == os.getpid()
        check = await asyncio.create_subprocess_exec(sys.executable, str(ROOT / 'scripts/notification-owner.py'), '--check', stdout=asyncio.subprocess.PIPE)
        output, _ = await asyncio.wait_for(check.communicate(), 5)
        assert check.returncode == 1 and json.loads(output)['state'] == 'conflict'
        await bus.release_name(OWNER.NAME)
        assert (await state())['state'] == 'missing'
        await bus.request_name(OWNER.NAME)
        assert (await state())['state'] == 'owned'
    finally:
        child.terminate()
        await child.communicate()
        bus.disconnect()


if __name__ == '__main__':
    if '--bus-scenario' in sys.argv:
        asyncio.run(bus_scenario())
    else:
        unittest.main()
