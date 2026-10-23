#!/usr/bin/env python3
"""Control Center JSON pipe. No shell evaluation, credential files, or input logging."""
import asyncio
from datetime import datetime
import json
import logging
import math
import os
from pathlib import Path
import re
import shutil
import signal
import sys


class ControlError(Exception):
    pass


def brightness_devices(base=Path('/sys/class/backlight')):
    devices = []
    for path in sorted(base.glob('*')):
        try:
            maximum = int((path / 'max_brightness').read_text())
            current = int((path / 'brightness').read_text())
            if maximum > 0:
                devices.append({'name': path.name, 'value': max(0, min(1, current / maximum)), 'maximum': maximum})
        except (OSError, ValueError):
            continue
    return devices


def brightness_command(name, fraction, devices):
    if name not in [device['name'] for device in devices] or not isinstance(fraction, (int, float)) or not math.isfinite(fraction):
        raise ControlError('InvalidBrightness')
    return ['brightnessctl', '--class=backlight', '--device=' + name, '--quiet', 'set',
            '{}%'.format(max(1, min(100, round(fraction * 100))))]


def valid_device(path):
    return isinstance(path, str) and re.fullmatch(r'/org/bluez/hci[0-9]+/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}', path) is not None


class Bridge:
    def __init__(self, emit):
        self.emit = emit
        self.bus = None
        self.agent = None
        self.pairing = None
        self.pending = {}
        self.sequence = 0
        self.blocked_backlights = set()
        self.last_cpu = None
        self.last_state = None

    async def call(self, destination, path, interface, member, signature='', body=None, timeout=8):
        if self.bus is None:
            raise ControlError('BusUnavailable')
        from dbus_next import Message, MessageType
        reply = await asyncio.wait_for(self.bus.call(Message(destination=destination, path=path,
            interface=interface, member=member, signature=signature, body=body or [])), timeout)
        if reply is None or reply.message_type == MessageType.ERROR:
            # Do not propagate arbitrary daemon error text to stdout or journal.
            raise ControlError(reply.error_name.rsplit('.', 1)[-1] if reply else 'NoReply')
        return reply.body

    async def bluez(self, path, member, timeout=12):
        if not valid_device(path):
            raise ControlError('InvalidDevice')
        return await self.call('org.bluez', path, 'org.bluez.Device1', member, timeout=timeout)

    async def logind_brightness(self, device, percent):
        sessions = await self.call('org.freedesktop.login1', '/org/freedesktop/login1',
                                   'org.freedesktop.login1.Manager', 'ListSessions', timeout=2)
        candidates = []
        for _, uid, _, seat, path in sessions[0]:
            if uid != os.getuid() or not seat or (os.environ.get('XDG_SEAT') and seat != os.environ['XDG_SEAT']):
                continue
            result = await self.call('org.freedesktop.login1', path,
                'org.freedesktop.DBus.Properties', 'GetAll', 's', ['org.freedesktop.login1.Session'], timeout=2)
            properties = result[0]
            if properties['Active'].value and not properties['Remote'].value:
                candidates.append(path)
        if len(candidates) != 1:
            raise ControlError('BrightnessSessionUnavailable')
        maximum = device['maximum']
        level = max(1, min(maximum, (maximum * percent + 50) // 100))
        await self.call('org.freedesktop.login1', candidates[0], 'org.freedesktop.login1.Session',
                        'SetBrightness', 'ssu', ['backlight', device['name'], level], timeout=4)

    async def set_brightness(self, name, fraction):
        devices = brightness_devices()
        args = brightness_command(name, fraction, devices)
        device = next(item for item in devices if item['name'] == name)
        code = 'BrightnessToolUnavailable'
        try:
            process = await asyncio.create_subprocess_exec(*args, stdout=asyncio.subprocess.DEVNULL,
                                                           stderr=asyncio.subprocess.PIPE, env=dict(os.environ, LC_ALL='C'))
            try:
                _, stderr = await asyncio.wait_for(process.communicate(), 4)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()
                raise ControlError('BrightnessTimeout')
            if process.returncode == 0:
                return
            # Classify known errors without forwarding command output to QML or logs.
            code = 'BrightnessPermissionDenied' if any(text in stderr.lower() for text in (
                b'permission denied', b'operation not permitted', b'root privileges')) else 'BrightnessCommandFailed'
        except FileNotFoundError:
            pass
        if self.bus is not None:
            try:
                await self.logind_brightness(device, int(args[-1][:-1]))
                return
            except ControlError as error:
                reason = str(error)
                if reason in ('AccessDenied', 'NotYourDevice'):
                    code = 'BrightnessPermissionDenied'
                elif reason == 'BrightnessSessionUnavailable':
                    code = reason
                else:
                    code = 'BrightnessLogindFailed'
            except asyncio.TimeoutError:
                code = 'BrightnessTimeout'
        if code == 'BrightnessPermissionDenied':
            self.blocked_backlights.add(name)
        raise ControlError(code)

    async def setup(self):
        try:
            from dbus_next import BusType
            from dbus_next.aio import MessageBus
            self.bus = await asyncio.wait_for(MessageBus(bus_type=BusType.SYSTEM).connect(), 5)
        except Exception:
            self.emit({'event': 'notice', 'error': 'DBusDependencyUnavailable'})
        self.emit({'event': 'ready'})

    async def request(self, device, kind, **fields):
        from dbus_next import DBusError
        if device != self.pairing or self.pending:
            raise DBusError('org.bluez.Error.Rejected', 'No active pairing request')
        self.sequence += 1
        key = self.sequence
        future = asyncio.get_running_loop().create_future()
        self.pending[key] = future
        self.emit(dict(event='prompt', request=key, device=device, kind=kind, **fields))
        try:
            response = await asyncio.wait_for(future, 60)
            if not response.get('accept'):
                raise DBusError('org.bluez.Error.Rejected', 'Rejected by user')
            return response.get('value', '')
        except asyncio.TimeoutError:
            raise DBusError('org.bluez.Error.Canceled', 'Prompt timed out')
        finally:
            self.pending.pop(key, None)
            self.emit({'event': 'prompt-clear', 'request': key})

    async def register_agent(self):
        if self.agent is not None:
            return
        from dbus_next import DBusError
        from dbus_next.service import ServiceInterface, method
        bridge = self

        class PairingAgent(ServiceInterface):
            def __init__(self):
                super().__init__('org.bluez.Agent1')

            @method()
            def Release(self):
                bridge.cancel_prompts()

            @method()
            async def RequestPinCode(self, device: 'o') -> 's':
                value = await bridge.request(device, 'pin')
                if not isinstance(value, str) or not 1 <= len(value) <= 16:
                    raise DBusError('org.bluez.Error.Rejected', 'Invalid PIN')
                return value

            @method()
            async def RequestPasskey(self, device: 'o') -> 'u':
                value = await bridge.request(device, 'passkey')
                if not isinstance(value, str) or not re.fullmatch(r'[0-9]{1,6}', value):
                    raise DBusError('org.bluez.Error.Rejected', 'Invalid passkey')
                return int(value)

            @method()
            async def RequestConfirmation(self, device: 'o', passkey: 'u'):
                await bridge.request(device, 'confirm', code='{:06d}'.format(passkey))

            @method()
            async def RequestAuthorization(self, device: 'o'):
                await bridge.request(device, 'authorize')

            @method()
            async def AuthorizeService(self, device: 'o', uuid: 's'):
                await bridge.request(device, 'authorize', service=uuid)

            @method()
            def DisplayPinCode(self, device: 'o', pincode: 's'):
                if device == bridge.pairing:
                    bridge.emit({'event': 'prompt', 'kind': 'display', 'device': device, 'code': pincode})

            @method()
            def DisplayPasskey(self, device: 'o', passkey: 'u', entered: 'q'):
                if device == bridge.pairing:
                    bridge.emit({'event': 'prompt', 'kind': 'display', 'device': device,
                                 'code': '{:06d}'.format(passkey), 'entered': entered})

            @method()
            def Cancel(self):
                bridge.cancel_prompts()

        agent = PairingAgent()
        self.bus.export('/org/shittim/ControlAgent', agent)
        try:
            await self.call('org.bluez', '/org/bluez', 'org.bluez.AgentManager1', 'RegisterAgent',
                            'os', ['/org/shittim/ControlAgent', 'KeyboardDisplay'])
        except Exception:
            self.bus.unexport('/org/shittim/ControlAgent')
            raise
        # Pair() is sent over this same bus connection, so our application agent
        # handles it without taking over the system's default agent.
        self.agent = agent

    def cancel_prompts(self):
        for future in self.pending.values():
            if not future.done():
                future.set_result({'accept': False})
        self.emit({'event': 'prompt-clear'})

    async def handle(self, message):
        key = message.get('id')
        action = message.get('action')
        try:
            if action == 'reply':
                future = self.pending.get(message.get('request'))
                if future and not future.done():
                    future.set_result({'accept': message.get('accept') is True, 'value': message.get('value', '')})
                return
            if action == 'refresh':
                self.blocked_backlights.clear()
            elif action == 'brightness':
                await self.set_brightness(message.get('device'), message.get('value'))
            elif action in ('pair', 'connect', 'disconnect', 'cancel-pair'):
                path = message.get('device')
                if not valid_device(path):
                    raise ControlError('InvalidDevice')
                if action == 'pair':
                    if self.pairing is not None:
                        raise ControlError('PairingBusy')
                    await self.register_agent()
                    self.pairing = path
                    try:
                        await self.bluez(path, 'Pair', timeout=90)
                    finally:
                        self.pairing = None
                        self.cancel_prompts()
                else:
                    await self.bluez(path, {'connect': 'Connect', 'disconnect': 'Disconnect', 'cancel-pair': 'CancelPairing'}[action])
            elif action == 'profile':
                profile = message.get('profile')
                if profile not in ('power-saver', 'balanced', 'performance'):
                    raise ControlError('InvalidProfile')
                from dbus_next import Variant
                await self.call('org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles',
                    'org.freedesktop.DBus.Properties', 'Set', 'ssv',
                    ['org.freedesktop.UPower.PowerProfiles', 'ActiveProfile', Variant('s', profile)])
            else:
                raise ControlError('InvalidAction')
            self.emit({'event': 'result', 'id': key, 'ok': True})
            if action in ('brightness', 'profile', 'refresh'):
                await self.snapshot()
        except asyncio.CancelledError:
            raise
        except Exception as error:
            code = str(error) if isinstance(error, ControlError) else type(error).__name__
            self.emit({'event': 'result', 'id': key, 'ok': False, 'error': code})
            if action == 'brightness':
                await self.snapshot()

    async def snapshot(self):
        devices = brightness_devices()
        for device in devices:
            device['writable'] = (shutil.which('brightnessctl') is not None or self.bus is not None) and device['name'] not in self.blocked_backlights
        state = {'event': 'state', 'backlights': devices, 'profiles': [], 'profile': '', 'bluetooth': False,
                 'screenshotAvailable': shutil.which('grim') is not None}
        if self.bus:
            try:
                result = await self.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                    'org.freedesktop.DBus', 'NameHasOwner', 's', ['org.bluez'], timeout=2)
                state['bluetooth'] = bool(result[0])
            except Exception:
                pass
            try:
                result = await self.call('org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles',
                    'org.freedesktop.DBus.Properties', 'GetAll', 's', ['org.freedesktop.UPower.PowerProfiles'], timeout=2)
                state['profiles'] = [item['Profile'].value for item in result[0]['Profiles'].value]
                state['profile'] = result[0]['ActiveProfile'].value
            except Exception:
                pass
        try:
            values = [int(value) for value in Path('/proc/stat').read_text().splitlines()[0].split()[1:9]]
            cpu = (sum(values), values[3] + values[4])
            if self.last_cpu and cpu[0] > self.last_cpu[0]:
                state['cpu'] = round(100 * (1 - (cpu[1] - self.last_cpu[1]) / (cpu[0] - self.last_cpu[0])))
            self.last_cpu = cpu
            memory = {line.split(':')[0]: int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines()}
            state['memory'] = round(100 * (1 - memory['MemAvailable'] / memory['MemTotal']))
            state['uptime'] = int(float(Path('/proc/uptime').read_text().split()[0]))
        except (OSError, ValueError, KeyError, IndexError):
            pass
        self.emit(state)

    async def shutdown(self):
        self.cancel_prompts()
        if self.pairing and self.bus:
            try:
                await self.bluez(self.pairing, 'CancelPairing', timeout=1)
            except Exception:
                pass
        if self.bus:
            self.bus.disconnect()


async def main():
    def emit(value):
        print(json.dumps(value, ensure_ascii=False), flush=True)

    bridge = Bridge(emit)
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for name in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(name, stop.set)
    await bridge.setup()
    reader = asyncio.StreamReader(limit=8192)
    protocol = asyncio.StreamReaderProtocol(reader)
    transport, _ = await loop.connect_read_pipe(lambda: protocol, sys.stdin)
    tasks = set()

    async def inputs():
        while not stop.is_set():
            line = await reader.readline()
            if not line:
                stop.set()
                return
            try:
                message = json.loads(line)
                if not isinstance(message, dict) or len(tasks) >= 16:
                    raise ValueError()
            except (ValueError, UnicodeError):
                emit({'event': 'notice', 'error': 'InvalidRequest'})
                continue
            task = asyncio.create_task(bridge.handle(message))
            tasks.add(task)
            task.add_done_callback(tasks.discard)

    async def poll():
        while not stop.is_set():
            await bridge.snapshot()
            await asyncio.sleep(2)

    workers = [asyncio.create_task(inputs()), asyncio.create_task(poll())]
    try:
        await stop.wait()
    finally:
        for task in workers + list(tasks):
            task.cancel()
        await bridge.shutdown()
        await asyncio.gather(*workers, *tasks, return_exceptions=True)
        transport.close()


async def screenshot(mode='all'):
    os.umask(0o077)
    # Give the compositor time to unmap the Control Center before capture.
    await asyncio.sleep(0.3)
    geometry = None
    if mode == 'region':
        selector = await asyncio.create_subprocess_exec('slurp', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            output, _ = await asyncio.wait_for(selector.communicate(), 120)
        except asyncio.TimeoutError:
            selector.kill(); await selector.wait(); return 1
        if selector.returncode != 0:
            return 0  # Escape cancels without a file or clipboard change.
        geometry = output.decode().strip()
        if not re.fullmatch(r'-?\d+,-?\d+ [1-9]\d*x[1-9]\d*', geometry):
            return 1
    pictures = Path.home() / 'Pictures'
    if shutil.which('xdg-user-dir'):
        process = await asyncio.create_subprocess_exec('xdg-user-dir', 'PICTURES', stdout=asyncio.subprocess.PIPE,
                                                       stderr=asyncio.subprocess.DEVNULL)
        output, _ = await asyncio.wait_for(process.communicate(), 3)
        candidate = Path(output.decode().strip())
        if candidate.is_absolute():
            pictures = candidate
    directory = pictures / 'Screenshots'
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / ('shittim-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.png')
    command = ['grim'] + (['-g', geometry] if geometry else []) + [str(destination)]
    process = await asyncio.create_subprocess_exec(*command, stdout=asyncio.subprocess.DEVNULL,
                                                   stderr=asyncio.subprocess.DEVNULL)
    try:
        result = await asyncio.wait_for(process.wait(), 10)
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        return 1
    if result == 0 and shutil.which('wl-copy'):
        with destination.open('rb') as image:
            copy = await asyncio.create_subprocess_exec('wl-copy', '--type', 'image/png', stdin=image,
                stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
            try:
                if await asyncio.wait_for(copy.wait(), 5) != 0:
                    return 2
            except asyncio.TimeoutError:
                copy.kill(); await copy.wait(); return 2
    return result


if __name__ == '__main__':
    logging.disable(logging.CRITICAL)
    try:
        if sys.argv[1:] == ['--screenshot']:
            sys.exit(asyncio.run(screenshot()))
        elif sys.argv[1:] == ['--screenshot-region']:
            sys.exit(asyncio.run(screenshot('region')))
        elif not sys.argv[1:]:
            asyncio.run(main())
        else:
            sys.exit(2)
    except (OSError, ValueError, BrokenPipeError, asyncio.TimeoutError):
        sys.exit(1)
