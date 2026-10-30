"""Network settings adapter: input validation, settings written for NetworkManager, diagnosis parsing, no secrets out."""
import asyncio
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('network_service', ROOT / 'scripts/network-service.py')
SERVICE = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(SERVICE)


class Variant:
    """Stand-in for dbus_next.Variant: keeps the signature so tests can check what goes on the bus."""
    def __init__(self, signature, value):
        self.signature, self.value = signature, value

    def __repr__(self):
        return 'V({!r}, {!r})'.format(self.signature, self.value)


class Validation(unittest.TestCase):
    def test_manual_ipv4(self):
        result = SERVICE.validate_family({'method': 'manual', 'address': ' 192.168.0.50 ', 'prefix': 24, 'gateway': '192.168.0.1',
                                          'dns': ['1.1.1.1', '1.1.1.1', '9.9.9.9']}, 4)
        self.assertEqual(result, {'method': 'manual', 'address': '192.168.0.50', 'prefix': 24, 'gateway': '192.168.0.1',
                                  'dns': ['1.1.1.1', '9.9.9.9'], 'autoDns': False})

    def test_rejections_name_the_field(self):
        cases = [({'method': 'manual', 'address': '192.168.0.300', 'prefix': 24}, 'InvalidAddress'),
                 ({'method': 'manual', 'address': '192.168.0.0', 'prefix': 24}, 'InvalidAddress'),
                 ({'method': 'manual', 'address': '127.0.0.5', 'prefix': 8}, 'InvalidAddress'),
                 ({'method': 'manual', 'address': '192.168.0.5', 'prefix': 33}, 'InvalidPrefix'),
                 ({'method': 'manual', 'address': '192.168.0.5', 'prefix': True}, 'InvalidPrefix'),
                 ({'method': 'manual', 'address': '192.168.0.5', 'prefix': 24, 'gateway': '10.0.0.1'}, 'GatewayOutsideNetwork'),
                 ({'method': 'manual', 'address': '192.168.0.5', 'prefix': 24, 'gateway': '192.168.0.5'}, 'InvalidGateway'),
                 ({'method': 'manual', 'address': '192.168.0.5', 'prefix': 24, 'gateway': 'fd00::1'}, 'InvalidGateway'),
                 ({'method': 'auto', 'dns': ['1.1.1.1', 'nope']}, 'InvalidDns'),
                 ({'method': 'auto', 'dns': ['fd00::1']}, 'InvalidDns'),
                 ({'method': 'auto', 'dns': ['1.1.1.1'] * 5}, 'InvalidDns'),
                 ({'method': 'shared'}, 'InvalidMethod'),
                 ({'method': 'auto; rm -rf /'}, 'InvalidMethod'),
                 ('auto', 'InvalidSettings')]
        for settings, code in cases:
            with self.subTest(settings=settings):
                with self.assertRaises(SERVICE.NetworkError) as raised:
                    SERVICE.validate_family(settings, 4)
                self.assertEqual(str(raised.exception), code)

    def test_ipv6_and_disabled(self):
        self.assertEqual(SERVICE.validate_family({'method': 'manual', 'address': 'FD00::10', 'prefix': 64, 'gateway': 'fd00::1', 'dns': ['fd00::53']}, 6),
                         {'method': 'manual', 'address': 'fd00::10', 'prefix': 64, 'gateway': 'fd00::1', 'dns': ['fd00::53'], 'autoDns': False})
        self.assertEqual(SERVICE.validate_family({'method': 'ignore', 'dns': ['junk']}, 6)['dns'], [])
        self.assertEqual(SERVICE.validate_family({'method': 'disabled'}, 6)['method'], 'disabled')
        with self.assertRaises(SERVICE.NetworkError):
            SERVICE.validate_family({'method': 'ignore'}, 4)
        auto = SERVICE.validate_family({'method': 'auto', 'dns': ['1.1.1.1'], 'autoDns': False}, 4)
        self.assertEqual((auto['dns'], auto['autoDns']), (['1.1.1.1'], False))

    def test_proxy(self):
        self.assertEqual(SERVICE.validate_proxy({'method': 'auto', 'pacUrl': 'http://wpad.lan/wpad.dat'}), {'method': 'auto', 'pacUrl': 'http://wpad.lan/wpad.dat'})
        self.assertEqual(SERVICE.validate_proxy({'method': 'none', 'pacUrl': 'http://x/y'}), {'method': 'none', 'pacUrl': ''})
        self.assertIsNone(SERVICE.validate_proxy(None))
        for bad in ({'method': 'manual'}, {'method': 'auto', 'pacUrl': 'javascript:alert(1)'}, {'method': 'auto', 'pacUrl': 'http://'}):
            with self.assertRaises(SERVICE.NetworkError):
                SERVICE.validate_proxy(bad)


class Settings(unittest.TestCase):
    def test_manual_family_replaces_deprecated_keys(self):
        # GetSettings returns the old 'addresses'/'routes' next to 'address-data'; NetworkManager ignores
        # 'address-data' and 'gateway' if 'addresses' is sent, so both must go.
        section = {'addresses': Variant('aau', [[1, 24, 0]]), 'routes': Variant('aau', []), 'route-data': Variant('aa{sv}', []),
                   'method': Variant('s', 'auto'), 'dns': Variant('au', [1])}
        values = SERVICE.validate_family({'method': 'manual', 'address': '10.77.0.50', 'prefix': 24, 'gateway': '10.77.0.1', 'dns': ['10.77.0.1', '9.9.9.9']}, 4)
        SERVICE.apply_family(section, values, 4, Variant)
        self.assertNotIn('addresses', section); self.assertNotIn('routes', section); self.assertIn('route-data', section)
        self.assertEqual(section['method'].value, 'manual')
        self.assertEqual(section['address-data'].signature, 'aa{sv}')
        self.assertEqual(section['address-data'].value[0]['address'].value, '10.77.0.50')
        self.assertEqual(section['address-data'].value[0]['prefix'].signature, 'u')
        self.assertEqual(section['gateway'].value, '10.77.0.1')
        self.assertEqual([SERVICE.ipv4_from_dbus(item) for item in section['dns'].value], ['10.77.0.1', '9.9.9.9'])
        self.assertTrue(section['ignore-auto-dns'].value)

    def test_auto_family_keeps_dhcp_and_extra_dns(self):
        section = {'address-data': Variant('aa{sv}', [{}]), 'gateway': Variant('s', '10.0.0.1'), 'method': Variant('s', 'manual')}
        SERVICE.apply_family(section, SERVICE.validate_family({'method': 'auto'}, 6), 6, Variant)
        self.assertEqual(section['method'].value, 'auto'); self.assertNotIn('address-data', section); self.assertNotIn('gateway', section)
        self.assertNotIn('dns', section); self.assertFalse(section['ignore-auto-dns'].value)
        SERVICE.apply_family(section, SERVICE.validate_family({'method': 'auto', 'dns': ['fd00::53']}, 6), 6, Variant)
        self.assertEqual(section['dns'].signature, 'aay'); self.assertEqual(len(section['dns'].value[0]), 16)

    def test_profile_reads_wire_format_without_secrets(self):
        settings = {
            'connection': {'id': Variant('s', 'SHITTIM_HOME'), 'uuid': Variant('s', 'c38186c4-4498-3bc4-8836-bd2fee63e3a8'), 'type': Variant('s', '802-11-wireless'),
                           'autoconnect-priority': Variant('i', 5), 'timestamp': Variant('t', 1793326600)},
            '802-11-wireless': {'ssid': Variant('ay', 'SHITTIM_HOME'.encode()), 'hidden': Variant('b', True)},
            '802-11-wireless-security': {'key-mgmt': Variant('s', 'sae')},
            'ipv4': {'method': Variant('s', 'manual'), 'address-data': Variant('aa{sv}', [{'address': Variant('s', '10.0.0.5'), 'prefix': Variant('u', 24)}]),
                     'gateway': Variant('s', '10.0.0.1'), 'dns': Variant('au', [struct.unpack('=I', bytes([1, 1, 1, 1]))[0]]), 'ignore-auto-dns': Variant('b', True)},
            'ipv6': {'method': Variant('s', 'auto'), 'dns': Variant('aay', [bytes(15) + b'\x01'])},
            'proxy': {'method': Variant('i', 1), 'pac-url': Variant('s', 'http://wpad/wpad.dat')}}
        profile = SERVICE.Bridge.profile('/org/freedesktop/NetworkManager/Settings/3', settings)
        self.assertEqual(profile['ssid'], 'SHITTIM_HOME'); self.assertTrue(profile['hidden']); self.assertEqual(profile['keyMgmt'], 'sae')
        self.assertTrue(profile['autoconnect']); self.assertEqual(profile['priority'], 5); self.assertTrue(profile['shared'])
        self.assertEqual(profile['ipv4'], {'method': 'manual', 'addresses': [{'address': '10.0.0.5', 'prefix': 24}], 'gateway': '10.0.0.1', 'dns': ['1.1.1.1'], 'autoDns': False})
        self.assertEqual(profile['ipv6']['dns'], ['::1']); self.assertEqual(profile['proxy'], {'method': 'auto', 'pacUrl': 'http://wpad/wpad.dat'})
        self.assertIsNone(SERVICE.Bridge.profile('/x', {'connection': {'type': Variant('s', 'vpn')}}))

    def test_access_point_wording(self):
        self.assertEqual([SERVICE.band(f) for f in (2437, 5180, 5955, 0)], ['2.4GHz', '5GHz', '6GHz', ''])
        self.assertEqual(SERVICE.security(0, 0, 0), 'open'); self.assertEqual(SERVICE.security(1, 0, 0), 'wep')
        self.assertEqual(SERVICE.security(1, 0x100, 0), 'wpa-psk'); self.assertEqual(SERVICE.security(1, 0, 0x100), 'wpa2-psk')
        self.assertEqual(SERVICE.security(1, 0, 0x500), 'sae'); self.assertEqual(SERVICE.security(1, 0, 0x200), 'wpa-eap')
        self.assertEqual(SERVICE.text_ssid('싯딤'.encode('utf-8')), '싯딤'); self.assertEqual(SERVICE.text_ssid(b'\xff'), 'ÿ')


class Diagnosis(unittest.TestCase):
    def test_ping_summary(self):
        output = ('PING 10.77.0.1 (10.77.0.1) 56(84) bytes of data.\n\n--- 10.77.0.1 ping statistics ---\n'
                  '4 packets transmitted, 3 received, 25% packet loss, time 905ms\nrtt min/avg/max/mdev = 0.047/0.061/0.078/0.012 ms\n')
        self.assertEqual(SERVICE.ping_summary(output), {'sent': 4, 'received': 3, 'loss': 25, 'latency': 0.1})
        self.assertEqual(SERVICE.ping_summary('5 packets transmitted, 0 received, +5 errors, 100% packet loss'), {'sent': 5, 'received': 0, 'loss': 100, 'latency': None})
        self.assertIsNone(SERVICE.ping_summary('ping: socket: Operation not permitted'))

    def test_quality_needs_a_measurement(self):
        self.assertEqual(SERVICE.quality('full', {'loss': 0, 'latency': 12}), 'good')
        self.assertEqual(SERVICE.quality('full', {'loss': 5, 'latency': 80}), 'fair')
        self.assertEqual(SERVICE.quality('full', {'loss': 20, 'latency': 20}), 'poor')
        self.assertEqual(SERVICE.quality('full', None), 'unknown')
        self.assertEqual(SERVICE.quality('limited', {'loss': 0, 'latency': 1}), 'poor')
        self.assertEqual(SERVICE.quality('unknown', {'loss': 0, 'latency': 1}), 'unknown')

    def test_dns_packet(self):
        query, identifier = SERVICE.dns_query('ping.archlinux.org', 0x1234)
        self.assertEqual(query[:12], bytes.fromhex('123401000001000000000000'))
        self.assertEqual(query[12:], b'\x04ping\x09archlinux\x03org\x00\x00\x01\x00\x01')
        self.assertTrue(SERVICE.dns_answered(bytes.fromhex('123481800001000100000000'), 0x1234))
        self.assertFalse(SERVICE.dns_answered(bytes.fromhex('123481830001000000000000'), 0x1234))
        self.assertFalse(SERVICE.dns_answered(bytes.fromhex('999981800001000100000000'), 0x1234))


class Requests(unittest.TestCase):
    def run_bridge(self, message):
        events = []
        bridge = SERVICE.Bridge(events.append)
        bridge.variant = Variant

        async def publish(force=False):
            pass
        bridge.publish = publish
        asyncio.run(bridge.handle(message))
        return bridge, events

    def test_bad_requests_never_reach_the_bus(self):
        for message, code in (({'id': 1, 'action': 'apply', 'uuid': 'c38186c4-4498-3bc4-8836-bd2fee63e3a8', 'ipv4': {'method': 'manual', 'address': 'x', 'prefix': 24}, 'ipv6': {'method': 'auto'}}, 'InvalidAddress'),
                              ({'id': 2, 'action': 'delete', 'uuid': '../../etc/passwd'}, 'InvalidConnection'),
                              ({'id': 3, 'action': 'reboot'}, 'InvalidAction'),
                              ({'id': 4, 'action': 'connect-hidden', 'ssid': 'Lab', 'security': 'wpa-psk', 'password': 'short', 'device': 'wlan0'}, 'InvalidPassword'),
                              ({'id': 5, 'action': 'autoconnect', 'uuid': 'c38186c4-4498-3bc4-8836-bd2fee63e3a8', 'enabled': 'yes'}, 'InvalidSettings')):
            with self.subTest(code=code):
                bridge, events = self.run_bridge(dict(message))
                self.assertEqual(events, [{'event': 'result', 'id': message['id'], 'ok': False, 'error': code}])

    def test_uuid_and_interface_are_checked_before_lookup(self):
        bridge = SERVICE.Bridge(lambda value: None)
        with self.assertRaises(SERVICE.NetworkError) as raised:
            asyncio.run(bridge.connection_path('../../etc/passwd'))
        self.assertEqual(str(raised.exception), 'InvalidConnection')
        with self.assertRaises(SERVICE.NetworkError) as raised:
            asyncio.run(bridge.device_path('wlan0; reboot'))
        self.assertEqual(str(raised.exception), 'InvalidDevice')

    def test_password_is_dropped_and_never_echoed(self):
        message = {'id': 9, 'action': 'connect-hidden', 'ssid': 'Lab', 'security': 'wpa-psk', 'password': 'correct horse battery', 'device': 'wlan0'}
        bridge, events = self.run_bridge(message)
        self.assertEqual(message, {})
        self.assertNotIn('correct horse', json.dumps(events))

    def test_checkpoint_memory_holds_no_secret_and_survives_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            bridge = SERVICE.Bridge(lambda value: None)
            bridge.state_dir = Path(directory) / 'shittim'
            bridge.checkpoint = {'path': '/org/freedesktop/NetworkManager/Checkpoint/7', 'name': 'SHITTIM_HOME', 'uuid': 'u'}
            bridge.remember_checkpoint(bridge.checkpoint['path'])
            stored = json.loads((bridge.state_dir / SERVICE.STATE_FILE).read_text())
            self.assertEqual(set(stored), {'path', 'name', 'uuid'})
            again = SERVICE.Bridge(lambda value: None)
            again.state_dir = bridge.state_dir
            again.restore_checkpoint()
            self.assertEqual(again.checkpoint['path'], '/org/freedesktop/NetworkManager/Checkpoint/7')
            bridge.remember_checkpoint('')
            self.assertFalse((bridge.state_dir / SERVICE.STATE_FILE).exists())
            (bridge.state_dir / SERVICE.STATE_FILE).write_text(json.dumps({'path': '/etc/passwd'}))
            third = SERVICE.Bridge(lambda value: None)
            third.state_dir = bridge.state_dir
            third.restore_checkpoint()
            self.assertIsNone(third.checkpoint)


if __name__ == '__main__':
    unittest.main()
