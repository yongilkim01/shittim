#!/usr/bin/env python3
"""Network settings JSON pipe over the NetworkManager D-Bus API.

Reads devices, IP configuration and saved profiles (NetworkManager never hands out secrets through GetSettings) and
changes profiles on request. A change to a profile that is in use runs under a NetworkManager checkpoint, so
NetworkManager itself rolls the devices and the profile back when nobody confirms in time, even when this process
or the shell is gone. Passwords pass through memory only: they are never printed, logged or written by this script.
Diagnostics run only when asked and say which hosts they contact.
"""
import asyncio
import ipaddress
import json
import logging
import os
from pathlib import Path
import random
import re
import signal
import socket
import struct
import sys
import time
from urllib.parse import urlparse

NM = 'org.freedesktop.NetworkManager'
NM_PATH = '/org/freedesktop/NetworkManager'
SETTINGS_PATH = NM_PATH + '/Settings'
PROPERTIES = 'org.freedesktop.DBus.Properties'
DEVICE_TYPES = {1: 'wired', 2: 'wifi'}
VETH = 20
PROFILE_TYPES = {'802-3-ethernet': 'wired', '802-11-wireless': 'wifi'}
CONNECTIVITY = {0: 'unknown', 1: 'none', 2: 'portal', 3: 'limited', 4: 'full'}
# Seconds the user has to confirm a change before NetworkManager restores the previous state.
CONFIRM_SECONDS = 30
# Generous first timeout: it also covers the time a polkit password prompt may take before the change is applied.
AUTH_SECONDS = 120
FALLBACK_TARGET = 'ping.archlinux.org'
STATE_FILE = 'network-checkpoint'


class NetworkError(Exception):
    pass


def text_ssid(raw):
    data = bytes(raw or b'')
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        return data.decode('latin-1')


def band(frequency):
    if not isinstance(frequency, int) or frequency <= 0:
        return ''
    if frequency < 3000:
        return '2.4GHz'
    if frequency < 5925:
        return '5GHz'
    return '6GHz'


def security(flags, wpa, rsn):
    """Access point security from NM80211ApFlags / NM80211ApSecurityFlags."""
    if rsn & 0x200 or wpa & 0x200:
        return 'wpa-eap'
    if rsn & 0x400:
        return 'sae'
    if rsn & 0x800 or rsn & 0x1000:
        return 'owe'
    if rsn & 0x100:
        return 'wpa2-psk'
    if wpa & 0x100:
        return 'wpa-psk'
    if flags & 0x1:
        return 'wep'
    return 'open'


def ipv4_to_dbus(address):
    return struct.unpack('=I', socket.inet_aton(address))[0]


def ipv4_from_dbus(value):
    return socket.inet_ntoa(struct.pack('=I', value))


def ipv6_from_bytes(raw):
    data = bytes(raw)
    return str(ipaddress.IPv6Address(data)) if len(data) == 16 else ''


def address_list(values, family):
    """Comma or whitespace separated DNS servers of one family, at most four, no duplicates."""
    if not isinstance(values, list) or len(values) > 4:
        raise NetworkError('InvalidDns')
    result = []
    for value in values:
        try:
            address = ipaddress.ip_address(str(value).strip())
        except ValueError:
            raise NetworkError('InvalidDns')
        if address.version != family or address.is_unspecified or address.is_multicast:
            raise NetworkError('InvalidDns')
        if str(address) not in result:
            result.append(str(address))
    return result


def validate_family(settings, family):
    """Normalise one IP family from the settings page; raises NetworkError with a field-specific code."""
    if not isinstance(settings, dict):
        raise NetworkError('InvalidSettings')
    methods = ('auto', 'manual', 'disabled') if family == 4 else ('auto', 'dhcp', 'manual', 'ignore', 'disabled')
    method = settings.get('method')
    if method not in methods:
        raise NetworkError('InvalidMethod')
    result = {'method': method, 'address': '', 'prefix': 0, 'gateway': '', 'dns': [], 'autoDns': True}
    if method in ('disabled', 'ignore'):
        return result
    result['dns'] = address_list(settings.get('dns', []), family)
    result['autoDns'] = settings.get('autoDns', True) is True or not result['dns']
    if method != 'manual':
        return result
    prefix = settings.get('prefix')
    if not isinstance(prefix, int) or isinstance(prefix, bool) or not 1 <= prefix <= (32 if family == 4 else 128):
        raise NetworkError('InvalidPrefix')
    try:
        interface = ipaddress.ip_interface('{}/{}'.format(str(settings.get('address', '')).strip(), prefix))
    except ValueError:
        raise NetworkError('InvalidAddress')
    address = interface.ip
    if address.version != family or address.is_unspecified or address.is_multicast or address.is_loopback:
        raise NetworkError('InvalidAddress')
    if family == 4 and prefix < 31 and address in (interface.network.network_address, interface.network.broadcast_address):
        raise NetworkError('InvalidAddress')
    gateway = str(settings.get('gateway', '')).strip()
    if gateway:
        try:
            gateway_address = ipaddress.ip_address(gateway)
        except ValueError:
            raise NetworkError('InvalidGateway')
        if gateway_address.version != family or gateway_address == address or gateway_address.is_unspecified:
            raise NetworkError('InvalidGateway')
        if family == 4 and gateway_address not in interface.network:
            raise NetworkError('GatewayOutsideNetwork')
    result.update(address=str(address), prefix=prefix, gateway=gateway and str(ipaddress.ip_address(gateway)))
    result['autoDns'] = False
    return result


def validate_proxy(settings):
    if settings is None:
        return None
    if not isinstance(settings, dict) or settings.get('method') not in ('none', 'auto'):
        raise NetworkError('InvalidProxy')
    url = str(settings.get('pacUrl', '')).strip()
    if url:
        parsed = urlparse(url)
        if parsed.scheme not in ('http', 'https', 'file') or (parsed.scheme != 'file' and not parsed.netloc) or len(url) > 2048:
            raise NetworkError('InvalidProxy')
    return {'method': settings['method'], 'pacUrl': url if settings['method'] == 'auto' else ''}


def apply_family(section, values, family, variant):
    """Write a validated family into a GetSettings section, dropping deprecated keys that override the new ones."""
    for key in ('addresses', 'routes', 'address-data', 'gateway', 'dns', 'dns-data'):
        section.pop(key, None)
    section['method'] = variant('s', values['method'])
    if values['method'] == 'manual':
        section['address-data'] = variant('aa{sv}', [{'address': variant('s', values['address']), 'prefix': variant('u', values['prefix'])}])
        if values['gateway']:
            section['gateway'] = variant('s', values['gateway'])
    if values['dns']:
        if family == 4:
            section['dns'] = variant('au', [ipv4_to_dbus(item) for item in values['dns']])
        else:
            section['dns'] = variant('aay', [ipaddress.IPv6Address(item).packed for item in values['dns']])
    if values['method'] not in ('disabled', 'ignore'):
        section['ignore-auto-dns'] = variant('b', not values['autoDns'])


def ping_summary(output):
    """Packet loss and average round trip from iputils ping output (C locale)."""
    sent = re.search(r'(\d+) packets transmitted, (\d+) (?:packets )?received', output)
    rtt = re.search(r'= [0-9.]+/([0-9.]+)/', output)
    if not sent or int(sent.group(1)) == 0:
        return None
    transmitted, received = int(sent.group(1)), int(sent.group(2))
    return {'sent': transmitted, 'received': received, 'loss': round(100 * (transmitted - received) / transmitted),
            'latency': round(float(rtt.group(1)), 1) if rtt and received else None}


def quality(connectivity, internet):
    """Connection quality from a finished diagnosis. Only a full connection with a measured round trip can be good."""
    if connectivity != 'full':
        return 'poor' if connectivity in ('none', 'limited', 'portal') else 'unknown'
    if not internet or internet.get('latency') is None:
        return 'unknown'
    if internet['loss'] == 0 and internet['latency'] < 50:
        return 'good'
    if internet['loss'] <= 10 and internet['latency'] < 150:
        return 'fair'
    return 'poor'


def dns_query(name, identifier=None):
    identifier = random.randrange(65536) if identifier is None else identifier
    labels = b''.join(bytes([len(part)]) + part.encode('ascii') for part in name.rstrip('.').split('.'))
    return struct.pack('>HHHHHH', identifier, 0x0100, 1, 0, 0, 0) + labels + b'\x00' + struct.pack('>HH', 1, 1), identifier


def dns_answered(packet, identifier):
    if len(packet) < 12:
        return False
    reply, flags, _, answers = struct.unpack('>HHHH', packet[:8])
    return reply == identifier and flags & 0x8000 and flags & 0x000f == 0 and answers > 0


class Bridge:
    def __init__(self, emit):
        self.emit = emit
        self.bus = None
        self.variant = None
        self.connections = None
        self.dirty = True
        self.last_state = None
        self.pending_snapshot = None
        self.checkpoint = None
        self.diagnosing = False
        self.state_dir = Path(os.environ.get('XDG_RUNTIME_DIR') or '/tmp') / 'shittim'

    async def call(self, path, interface, member, signature='', body=None, timeout=8, interactive=False):
        if self.bus is None:
            raise NetworkError('BusUnavailable')
        from dbus_next import Message, MessageFlag, MessageType
        message = Message(destination=NM, path=path, interface=interface, member=member, signature=signature, body=body or [],
                          flags=MessageFlag.ALLOW_INTERACTIVE_AUTHORIZATION if interactive else MessageFlag.NONE)
        try:
            reply = await asyncio.wait_for(self.bus.call(message), timeout)
        except asyncio.TimeoutError:
            raise NetworkError('Timeout')
        if reply is None or reply.message_type == MessageType.ERROR:
            # Daemon error text can quote settings; only the error name leaves this process.
            raise NetworkError(reply.error_name.rsplit('.', 1)[-1] if reply else 'NoReply')
        return reply.body

    async def properties(self, path, interface):
        result = await self.call(path, PROPERTIES, 'GetAll', 's', [interface], timeout=4)
        return {key: value.value for key, value in result[0].items()}

    async def setup(self):
        try:
            from dbus_next import BusType, Variant
            from dbus_next.aio import MessageBus
            self.variant = Variant
            self.bus = await asyncio.wait_for(MessageBus(bus_type=BusType.SYSTEM).connect(), 5)
            await self.bus.call(self.dbus_match())
            self.bus.add_message_handler(self.on_message)
        except Exception:
            self.bus = None
            self.emit({'event': 'notice', 'error': 'DBusDependencyUnavailable'})
        self.restore_checkpoint()
        self.emit({'event': 'ready'})

    def dbus_match(self):
        from dbus_next import Message
        return Message(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus', interface='org.freedesktop.DBus',
                       member='AddMatch', signature='s', body=["type='signal',sender='{}'".format(NM)])

    def on_message(self, message):
        from dbus_next import MessageType
        if message.message_type != MessageType.SIGNAL or not message.interface:
            return
        if 'Settings' in message.interface:
            self.dirty = True
        # NetworkManager announces changes in bursts (scans, activation steps); one snapshot per burst.
        if self.pending_snapshot is None:
            self.pending_snapshot = asyncio.get_running_loop().call_later(0.4, self.flush)

    def flush(self):
        self.pending_snapshot = None
        asyncio.ensure_future(self.publish())

    # Checkpoints survive this process; remember ours so a restarted shell can still offer keep/restore.
    def restore_checkpoint(self):
        try:
            value = json.loads((self.state_dir / STATE_FILE).read_text())
            if re.fullmatch(r'/org/freedesktop/NetworkManager/Checkpoint/[0-9]+', value.get('path', '')):
                self.checkpoint = {'path': value['path'], 'name': str(value.get('name', ''))[:128], 'uuid': str(value.get('uuid', ''))[:36]}
        except (OSError, ValueError, AttributeError):
            pass

    def remember_checkpoint(self, path):
        """Only the checkpoint path and the profile name/uuid; nothing secret."""
        try:
            self.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            target = self.state_dir / STATE_FILE
            if path:
                target.write_text(json.dumps({'path': path, 'name': self.checkpoint['name'], 'uuid': self.checkpoint['uuid']}, ensure_ascii=False))
            else:
                target.unlink(missing_ok=True)
        except OSError:
            pass

    async def ip_config(self, path, family):
        if not path or path == '/':
            return {'addresses': [], 'gateway': '', 'dns': []}
        values = await self.properties(path, NM + ('.IP4Config' if family == 4 else '.IP6Config'))
        addresses = [{'address': item['address'].value, 'prefix': item['prefix'].value} for item in values.get('AddressData', [])
                     if 'address' in item and 'prefix' in item]
        if family == 4:
            dns = [item['address'].value for item in values.get('NameserverData', []) if 'address' in item]
        else:
            dns = [ipv6_from_bytes(item) for item in values.get('Nameservers', [])]
        return {'addresses': addresses, 'gateway': values.get('Gateway', ''), 'dns': [item for item in dns if item]}

    async def access_point(self, path):
        values = await self.properties(path, NM + '.AccessPoint')
        return {'ssid': text_ssid(values.get('Ssid')), 'bssid': values.get('HwAddress', ''), 'strength': values.get('Strength', 0),
                'frequency': values.get('Frequency', 0), 'band': band(values.get('Frequency', 0)),
                'security': security(values.get('Flags', 0), values.get('WpaFlags', 0), values.get('RsnFlags', 0))}

    async def device(self, path):
        values = await self.properties(path, NM + '.Device')
        kind = DEVICE_TYPES.get(values.get('DeviceType'))
        # A veth link counts as wired only when NetworkManager manages it (container veths are left unmanaged).
        if values.get('DeviceType') == VETH and values.get('Managed', False):
            kind = 'wired'
        name = values.get('Interface', '')
        if kind is None or name == 'lo' or name.startswith('p2p-dev-'):
            return None
        item = {'path': path, 'interface': name, 'type': kind, 'state': values.get('State', 0),
                'reason': (values.get('StateReason') or [0, 0])[1], 'managed': values.get('Managed', False),
                'autoconnect': values.get('Autoconnect', False), 'hwAddress': values.get('HwAddress', ''),
                'driver': values.get('Driver', ''), 'connection': None, 'dhcp4': False, 'dhcp6': False}
        item['ip4'] = await self.ip_config(values.get('Ip4Config'), 4)
        item['ip6'] = await self.ip_config(values.get('Ip6Config'), 6)
        item['dhcp4'] = values.get('Dhcp4Config', '/') != '/'
        item['dhcp6'] = values.get('Dhcp6Config', '/') != '/'
        active = values.get('ActiveConnection', '/')
        if active and active != '/':
            try:
                connection = await self.properties(active, NM + '.Connection.Active')
                item['connection'] = {'uuid': connection.get('Uuid', ''), 'name': connection.get('Id', ''), 'state': connection.get('State', 0)}
            except NetworkError:
                pass
        if kind == 'wired':
            wired = await self.properties(path, NM + '.Device.Wired')
            item.update(speed=wired.get('Speed', 0), carrier=wired.get('Carrier', False), permHwAddress=wired.get('PermHwAddress', ''))
        else:
            wireless = await self.properties(path, NM + '.Device.Wireless')
            item.update(bitrate=wireless.get('Bitrate', 0), permHwAddress=wireless.get('PermHwAddress', ''), accessPoint=None, accessPoints=[])
            current = wireless.get('ActiveAccessPoint', '/')
            for ap in wireless.get('AccessPoints', [])[:96]:
                try:
                    data = await self.access_point(ap)
                except NetworkError:
                    continue
                item['accessPoints'].append(data)
                if ap == current:
                    item['accessPoint'] = data
        return item

    async def profiles(self):
        if not self.dirty and self.connections is not None:
            return self.connections
        self.dirty = False
        result = []
        paths = (await self.call(SETTINGS_PATH, NM + '.Settings', 'ListConnections'))[0]
        for path in paths:
            try:
                settings = (await self.call(path, NM + '.Settings.Connection', 'GetSettings'))[0]
            except NetworkError:
                continue
            profile = self.profile(path, settings)
            if profile:
                result.append(profile)
        result.sort(key=lambda item: (item['type'], -item['priority'], item['name'].lower()))
        self.connections = result
        return result

    @staticmethod
    def profile(path, settings):
        def value(section, key, default=None):
            item = settings.get(section, {}).get(key)
            return default if item is None else item.value
        kind = PROFILE_TYPES.get(value('connection', 'type'))
        if kind is None:
            return None
        def family(name):
            data = [{'address': item['address'].value, 'prefix': item['prefix'].value} for item in value(name, 'address-data', [])
                    if 'address' in item and 'prefix' in item]
            raw = value(name, 'dns', [])
            dns = [ipv4_from_dbus(item) if name == 'ipv4' else ipv6_from_bytes(item) for item in raw]
            return {'method': value(name, 'method', 'auto'), 'addresses': data, 'gateway': value(name, 'gateway', ''),
                    'dns': [item for item in dns if item], 'autoDns': not value(name, 'ignore-auto-dns', False)}
        proxy_method = value('proxy', 'method', 0)
        return {'path': path, 'uuid': value('connection', 'uuid', ''), 'name': value('connection', 'id', ''), 'type': kind,
                'interface': value('connection', 'interface-name', ''), 'autoconnect': value('connection', 'autoconnect', True),
                'priority': value('connection', 'autoconnect-priority', 0), 'timestamp': value('connection', 'timestamp', 0),
                'shared': not value('connection', 'permissions', []),
                'ssid': text_ssid(value('802-11-wireless', 'ssid', b'')) if kind == 'wifi' else '',
                'hidden': value('802-11-wireless', 'hidden', False) is True,
                'keyMgmt': value('802-11-wireless-security', 'key-mgmt', 'none' if kind == 'wifi' else ''),
                'eap': '802-1x' in settings,
                'ipv4': family('ipv4'), 'ipv6': family('ipv6'),
                'proxy': {'method': 'auto' if proxy_method == 1 else 'none', 'pacUrl': value('proxy', 'pac-url', '')}}

    async def checkpoint_state(self, checkpoints):
        if not self.checkpoint:
            return None
        if self.checkpoint['path'] not in checkpoints:
            # Destroyed or rolled back (by us, by the timeout, or by another tool).
            self.checkpoint = None
            self.remember_checkpoint('')
            return None
        try:
            values = await self.properties(self.checkpoint['path'], NM + '.Checkpoint')
        except NetworkError:
            return None
        now = time.clock_gettime(time.CLOCK_BOOTTIME) * 1000
        remaining = (values.get('Created', 0) + values.get('RollbackTimeout', 0) * 1000 - now) / 1000
        return {'name': self.checkpoint['name'], 'uuid': self.checkpoint['uuid'], 'remaining': max(0, int(remaining + 0.5)),
                'applying': self.checkpoint.get('applying', False)}

    async def snapshot(self):
        state = {'event': 'state', 'available': False, 'version': '', 'connectivity': 'unknown', 'devices': [],
                 'connections': [], 'permissions': {}, 'checkpoint': None, 'checkTarget': ''}
        if self.bus is None:
            return state
        try:
            manager = await self.properties(NM_PATH, NM)
        except NetworkError:
            return state
        state.update(available=True, version=manager.get('Version', ''), connectivity=CONNECTIVITY.get(manager.get('Connectivity', 0), 'unknown'),
                     networking=manager.get('NetworkingEnabled', False), wireless=manager.get('WirelessEnabled', False))
        uri = manager.get('ConnectivityCheckUri', '') if manager.get('ConnectivityCheckEnabled', False) else ''
        state['checkTarget'] = urlparse(uri).hostname or ''
        for path in manager.get('Devices', []):
            try:
                item = await self.device(path)
            except NetworkError:
                continue
            if item:
                state['devices'].append(item)
        state['devices'].sort(key=lambda item: (item['type'] != 'wifi', item['interface']))
        try:
            state['connections'] = await self.profiles()
        except NetworkError:
            self.dirty = True
        try:
            permissions = (await self.call(NM_PATH, NM, 'GetPermissions', timeout=4))[0]
            # 'yes', 'auth' (a polkit password prompt will appear) or 'no', keyed like 'settings.modify.system'.
            state['permissions'] = {key.split('NetworkManager.', 1)[-1]: value for key, value in permissions.items()}
        except NetworkError:
            pass
        state['checkpoint'] = await self.checkpoint_state(manager.get('Checkpoints', []))
        return state

    async def publish(self, force=False):
        state = await self.snapshot()
        encoded = json.dumps(state, ensure_ascii=False, sort_keys=True)
        if force or encoded != self.last_state:
            self.last_state = encoded
            self.emit(state)

    async def connection_path(self, uuid):
        if not isinstance(uuid, str) or not re.fullmatch(r'[0-9a-fA-F-]{36}', uuid):
            raise NetworkError('InvalidConnection')
        return (await self.call(SETTINGS_PATH, NM + '.Settings', 'GetConnectionByUuid', 's', [uuid]))[0]

    async def device_path(self, interface):
        if not isinstance(interface, str) or not re.fullmatch(r'[A-Za-z0-9_.:@-]{1,15}', interface):
            raise NetworkError('InvalidDevice')
        return (await self.call(NM_PATH, NM, 'GetDeviceByIpIface', 's', [interface]))[0]

    async def active_devices(self, uuid):
        """Devices on which this profile is active right now."""
        manager = await self.properties(NM_PATH, NM)
        devices = []
        for path in manager.get('ActiveConnections', []):
            try:
                active = await self.properties(path, NM + '.Connection.Active')
            except NetworkError:
                continue
            if active.get('Uuid') == uuid:
                devices.extend(active.get('Devices', []))
        return devices

    async def update(self, path, settings):
        await self.call(path, NM + '.Settings.Connection', 'Update2', 'a{sa{sv}}ua{sv}', [settings, 0x1, {}], timeout=AUTH_SECONDS, interactive=True)
        self.dirty = True

    async def settings(self, path):
        return (await self.call(path, NM + '.Settings.Connection', 'GetSettings'))[0]

    async def apply(self, message):
        if self.checkpoint:
            raise NetworkError('ConfirmPending')
        ipv4 = validate_family(message.get('ipv4'), 4)
        ipv6 = validate_family(message.get('ipv6'), 6)
        proxy = validate_proxy(message.get('proxy'))
        path = await self.connection_path(message.get('uuid'))
        settings = await self.settings(path)
        for name in ('ipv4', 'ipv6'):
            settings.setdefault(name, {})
        apply_family(settings['ipv4'], ipv4, 4, self.variant)
        apply_family(settings['ipv6'], ipv6, 6, self.variant)
        if proxy is not None:
            settings['proxy'] = {'method': self.variant('i', 1 if proxy['method'] == 'auto' else 0)}
            if proxy['pacUrl']:
                settings['proxy']['pac-url'] = self.variant('s', proxy['pacUrl'])
        name = settings['connection']['id'].value
        devices = await self.active_devices(message['uuid'])
        if not devices:
            # Not in use: saving cannot cut a connection, so there is nothing to confirm.
            await self.update(path, settings)
            return {'applied': 'saved'}
        checkpoint = (await self.call(NM_PATH, NM, 'CheckpointCreate', 'aouu', [devices, AUTH_SECONDS, 0], timeout=AUTH_SECONDS, interactive=True))[0]
        self.checkpoint = {'path': checkpoint, 'name': name, 'uuid': message['uuid'], 'applying': True}
        self.remember_checkpoint(checkpoint)
        try:
            await self.update(path, settings)
            for device in devices:
                try:
                    await self.call(device, NM + '.Device', 'Reapply', 'a{sa{sv}}tu', [{}, 0, 0], timeout=20, interactive=True)
                except NetworkError:
                    # Some changes cannot be reapplied in place; activating the profile again applies them.
                    await self.call(NM_PATH, NM, 'ActivateConnection', 'ooo', [path, device, '/'], timeout=20, interactive=True)
        except NetworkError:
            await self.rollback()
            raise
        await self.call(NM_PATH, NM, 'CheckpointAdjustRollbackTimeout', 'ou', [checkpoint, CONFIRM_SECONDS], timeout=8)
        self.checkpoint['applying'] = False
        return {'applied': 'checkpoint'}

    async def rollback(self):
        if not self.checkpoint:
            return
        path = self.checkpoint['path']
        try:
            await self.call(NM_PATH, NM, 'CheckpointRollback', 'o', [path], timeout=30, interactive=True)
        finally:
            self.checkpoint = None
            self.remember_checkpoint('')
            self.dirty = True

    async def keep(self):
        if not self.checkpoint or self.checkpoint.get('applying'):
            raise NetworkError('NothingToConfirm')
        path = self.checkpoint['path']
        await self.call(NM_PATH, NM, 'CheckpointDestroy', 'o', [path], timeout=AUTH_SECONDS, interactive=True)
        self.checkpoint = None
        self.remember_checkpoint('')

    async def autoconnect(self, message):
        enabled = message.get('enabled')
        priority = message.get('priority')
        if not isinstance(enabled, bool) or (priority is not None and (not isinstance(priority, int) or isinstance(priority, bool) or not -999 <= priority <= 999)):
            raise NetworkError('InvalidSettings')
        path = await self.connection_path(message.get('uuid'))
        settings = await self.settings(path)
        settings['connection']['autoconnect'] = self.variant('b', enabled)
        if priority is not None:
            settings['connection']['autoconnect-priority'] = self.variant('i', priority)
        await self.update(path, settings)

    async def connect_hidden(self, message):
        ssid = message.get('ssid')
        method = message.get('security')
        password = message.get('password', '')
        if not isinstance(ssid, str) or not 1 <= len(ssid.encode('utf-8')) <= 32 or method not in ('none', 'wpa-psk', 'sae'):
            raise NetworkError('InvalidSettings')
        if method != 'none' and (not isinstance(password, str) or not (8 <= len(password) <= 63 or re.fullmatch(r'[0-9A-Fa-f]{64}', password))):
            raise NetworkError('InvalidPassword')
        device = await self.device_path(message.get('device'))
        V = self.variant
        settings = {'connection': {'id': V('s', ssid), 'type': V('s', '802-11-wireless')},
                    '802-11-wireless': {'ssid': V('ay', ssid.encode('utf-8')), 'hidden': V('b', True), 'mode': V('s', 'infrastructure')}}
        if method != 'none':
            settings['802-11-wireless-security'] = {'key-mgmt': V('s', method), 'psk': V('s', password)}
        password = None
        await self.call(NM_PATH, NM, 'AddAndActivateConnection', 'a{sa{sv}}oo', [settings, device, '/'], timeout=AUTH_SECONDS, interactive=True)
        self.dirty = True

    async def run(self, *command, timeout=15):
        try:
            process = await asyncio.create_subprocess_exec(*command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                                                           env=dict(os.environ, LC_ALL='C'))
        except FileNotFoundError:
            return None
        try:
            output, _ = await asyncio.wait_for(process.communicate(), timeout)
        except asyncio.TimeoutError:
            process.kill()
            await process.wait()
            return None
        return output.decode('utf-8', 'replace')

    async def ping(self, target, interface=None, count=4):
        command = ['ping', '-n', '-c', str(count), '-i', '0.3', '-W', '1']
        if interface:
            command += ['-I', interface]
        output = await self.run(*command, '--', target, timeout=count + 4)
        return ping_summary(output) if output is not None else None

    async def resolve(self, server, name, interface=None):
        """One A query straight to a DNS server the device uses: is that server answering?"""
        loop = asyncio.get_running_loop()
        family = socket.AF_INET6 if ':' in server else socket.AF_INET
        address = (server, 53)
        if family == socket.AF_INET6 and ipaddress.IPv6Address(server).is_link_local:
            # A link-local server (often the router itself) is only reachable through the device it was learnt on.
            try:
                address = (server, 53, 0, socket.if_nametoindex(interface or ''))
            except OSError:
                return {'server': server, 'ok': False, 'latency': None}
        with socket.socket(family, socket.SOCK_DGRAM) as sock:
            sock.setblocking(False)
            query, identifier = dns_query(name)
            started = time.monotonic()
            try:
                await loop.sock_connect(sock, address)
                await loop.sock_sendall(sock, query)
                while True:
                    packet = await asyncio.wait_for(loop.sock_recv(sock, 1500), 2)
                    if packet[:2] == query[:2]:
                        break
            except (OSError, asyncio.TimeoutError):
                return {'server': server, 'ok': False, 'latency': None}
            return {'server': server, 'ok': bool(dns_answered(packet, identifier)), 'latency': round((time.monotonic() - started) * 1000, 1)}

    async def diagnose(self, message):
        if self.diagnosing:
            raise NetworkError('DiagnosisRunning')
        state = await self.snapshot()
        interface = message.get('device')
        device = next((item for item in state['devices'] if item['interface'] == interface), None)
        if device is None:
            raise NetworkError('InvalidDevice')
        self.diagnosing = True
        target = state['checkTarget'] or FALLBACK_TARGET
        report = {'event': 'diagnosis', 'device': interface, 'target': target, 'running': True, 'steps': {}}
        try:
            self.emit(report)
            gateway = device['ip4']['gateway'] or device['ip6']['gateway']
            report['steps']['gateway'] = {'target': gateway, 'result': await self.ping(gateway, interface) if gateway else None}
            self.emit(report)
            servers = (device['ip4']['dns'] + device['ip6']['dns'])[:2]
            try:
                ipaddress.ip_address(target)
                literal = True
            except ValueError:
                literal = False
            # A check address given as a number needs no name lookup, so there is nothing to ask the DNS servers.
            report['steps']['dns'] = {'target': target, 'skipped': literal,
                                      'servers': [] if literal else [await self.resolve(server, target, interface) for server in servers]}
            self.emit(report)
            connectivity = state['connectivity']
            try:
                connectivity = CONNECTIVITY.get((await self.call(NM_PATH, NM, 'CheckConnectivity', timeout=30))[0], 'unknown')
            except NetworkError:
                pass
            internet = await self.ping(target, None, 5)
            report['steps']['internet'] = {'target': target, 'connectivity': connectivity, 'result': internet}
            report['quality'] = quality(connectivity, internet)
        finally:
            report['running'] = False
            self.diagnosing = False
            self.emit(report)

    async def handle(self, message):
        key = message.get('id')
        action = message.get('action')
        result = {}
        try:
            if action == 'refresh':
                self.dirty = True
            elif action == 'activate':
                path = await self.connection_path(message.get('uuid'))
                device = await self.device_path(message.get('device')) if message.get('device') else '/'
                await self.call(NM_PATH, NM, 'ActivateConnection', 'ooo', [path, device, '/'], timeout=AUTH_SECONDS, interactive=True)
            elif action == 'disconnect':
                await self.call(await self.device_path(message.get('device')), NM + '.Device', 'Disconnect', timeout=AUTH_SECONDS, interactive=True)
            elif action == 'autoconnect':
                await self.autoconnect(message)
            elif action == 'delete':
                path = await self.connection_path(message.get('uuid'))
                await self.call(path, NM + '.Settings.Connection', 'Delete', timeout=AUTH_SECONDS, interactive=True)
                self.dirty = True
            elif action == 'apply':
                result = await self.apply(message)
            elif action == 'keep':
                await self.keep()
            elif action == 'revert':
                if not self.checkpoint:
                    raise NetworkError('NothingToConfirm')
                await self.rollback()
            elif action == 'connect-hidden':
                await self.connect_hidden(message)
            elif action == 'diagnose':
                await self.diagnose(message)
            else:
                raise NetworkError('InvalidAction')
            self.emit(dict({'event': 'result', 'id': key, 'ok': True}, **result))
        except asyncio.CancelledError:
            raise
        except Exception as error:
            code = str(error) if isinstance(error, NetworkError) else type(error).__name__
            self.emit({'event': 'result', 'id': key, 'ok': False, 'error': code})
        finally:
            message.clear()
        await self.publish()

    async def tick(self):
        """While a change waits for confirmation the countdown has to move; otherwise NetworkManager signals drive updates."""
        if self.checkpoint:
            await self.publish()

    async def shutdown(self):
        if self.pending_snapshot is not None:
            self.pending_snapshot.cancel()
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
    await bridge.publish(force=True)
    reader = asyncio.StreamReader(limit=16384)
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
                if not isinstance(message, dict) or len(tasks) >= 8:
                    raise ValueError()
            except (ValueError, UnicodeError):
                emit({'event': 'notice', 'error': 'InvalidRequest'})
                continue
            finally:
                line = None
            task = asyncio.create_task(bridge.handle(message))
            tasks.add(task)
            task.add_done_callback(tasks.discard)

    async def ticks():
        while not stop.is_set():
            await asyncio.sleep(1)
            await bridge.tick()

    workers = [asyncio.create_task(inputs()), asyncio.create_task(ticks())]
    try:
        await stop.wait()
    finally:
        for task in workers + list(tasks):
            task.cancel()
        await bridge.shutdown()
        await asyncio.gather(*workers, *tasks, return_exceptions=True)
        transport.close()


async def check():
    """One snapshot for scripts/verify-network.sh: names and states only, no addresses or profile contents."""
    bridge = Bridge(lambda value: None)
    await bridge.setup()
    state = await bridge.snapshot()
    await bridge.shutdown()
    print(json.dumps({'available': state['available'], 'version': state['version'], 'connectivity': state['connectivity'],
                      'checkTarget': state['checkTarget'], 'profiles': len(state['connections']),
                      'devices': [{'interface': item['interface'], 'type': item['type'], 'state': item['state'],
                                   'connected': item['connection'] is not None} for item in state['devices']],
                      'permissions': {key: value for key, value in state['permissions'].items()
                                      if key in ('network-control', 'settings.modify.system', 'checkpoint-rollback', 'enable-disable-wifi')}},
                     ensure_ascii=False))
    return 0 if state['available'] else 1


if __name__ == '__main__':
    logging.disable(logging.CRITICAL)
    try:
        if sys.argv[1:] == ['--check']:
            sys.exit(asyncio.run(check()))
        if sys.argv[1:]:
            sys.exit(2)
        asyncio.run(main())
    except (OSError, ValueError, BrokenPipeError):
        sys.exit(1)
