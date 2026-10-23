"""Deterministic /proc and sysfs fixtures; optional real Linux read-only smoke test."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('dashboard_service', ROOT / 'scripts/dashboard-service.py')
DASH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DASH)


class DashboardTelemetry(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.proc, self.sys = self.base / 'proc', self.base / 'sys'
        self.proc.mkdir(); self.sys.mkdir()
        self.now = 100
        self.runner = Mock()
        self.stat = Mock(return_value=SimpleNamespace(f_blocks=1000, f_frsize=1024, f_bfree=400, f_bavail=350))
        self.collector = DASH.Collector(self.proc, self.sys, clock=lambda: self.now, statvfs=self.stat, runner=self.runner, isdir=lambda path: True)

    def file(self, root, name, value):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf-8')
        return path

    def test_cpu_deltas_guest_exclusion_and_reset(self):
        first = DASH.cpu_counters('cpu 100 20 30 400 50 10 5 5 80 10\n')
        second = DASH.cpu_counters('cpu 130 20 40 440 60 10 5 5 90 20\n')
        self.assertEqual(first, (620, 450))
        self.assertEqual(DASH.cpu_usage(first, second), 44.4)
        self.assertIsNone(DASH.cpu_usage(None, first))
        self.assertIsNone(DASH.cpu_usage(second, first))
        self.assertIsNone(DASH.cpu_usage(first, first))
        self.assertIsNone(DASH.cpu_counters('bad data'))
        self.assertIsNone(DASH.cpu_usage((100, 50), (110, 49)))

    def test_memory_uses_available_and_missing_is_not_zero(self):
        memory = DASH.memory_info('MemTotal: 1000 kB\nMemAvailable: 350 kB\nMemFree: 10 kB\n')
        self.assertEqual(memory, {'used': 650 * 1024, 'total': 1000 * 1024, 'percent': 65})
        self.assertIsNone(DASH.memory_info('MemTotal: 1000 kB')['percent'])
        self.assertIsNone(DASH.memory_info('MemTotal: 1 kB\nMemAvailable: 2 kB')['percent'])

    def test_local_mounts_escaping_remote_filter_and_reserved_blocks(self):
        mountinfo = '1 0 8:1 / / rw - ext4 /dev/sda1 rw\n'
        mountinfo += '2 0 8:2 / /media/한글\\040disk rw - ext4 /dev/sda2 rw\n'
        mountinfo += '3 0 0:2 / /network rw - nfs host:/data rw\n4 0 0:3 / /proc rw - proc proc rw\n'
        self.file(self.proc, 'self/mountinfo', mountinfo)
        disks = self.collector.disks()
        self.assertEqual([disk['mount'] for disk in disks], ['/', '/media/한글 disk'])
        self.assertEqual(disks[0]['used'], 600 * 1024)
        self.assertEqual(disks[0]['total'], 1000 * 1024)
        self.assertEqual(disks[0]['percent'], 63.2)
        self.stat.side_effect = PermissionError()
        self.assertEqual(self.collector.disks(), [])
        self.collector.isdir = lambda path: False
        self.stat.reset_mock()
        self.assertEqual(self.collector.disks(), [])
        self.stat.assert_not_called()

    def net(self, wifi=(1000, 500), ethernet=(5000, 2000)):
        self.file(self.proc, 'net/dev', 'header\nheader\n' + '\n'.join(
            name + ': ' + ' '.join(map(str, [values[0]] + [0] * 7 + [values[1]] + [0] * 7))
            for name, values in [('lo', (100, 100)), ('p2p-dev-test', (100, 100)), ('wifi-test', wifi), ('eth-test', ethernet)]))
        for name, index in [('wifi-test', '2'), ('eth-test', '3')]:
            self.file(self.sys, 'class/net/' + name + '/operstate', 'up')
            self.file(self.sys, 'class/net/' + name + '/ifindex', index)
        self.file(self.proc, 'net/route', 'header\nwifi-test 00000000 01000000 0003 0 0 600 00000000\neth-test 00000000 01000000 0003 0 0 100 00000000\n')

    def test_network_per_interface_monotonic_deltas_routes_and_reset(self):
        self.net()
        first = self.collector.network()
        self.assertEqual(first['interface'], 'eth-test'); self.assertIsNone(first['down'])
        self.now += 2; self.net(wifi=(3000, 2500), ethernet=(9000, 3000))
        second = self.collector.network()
        self.assertEqual(second['down'], 2000); self.assertEqual(second['up'], 500)
        self.assertEqual(len(second['interfaces']), 2)
        self.now += 1; self.net(ethernet=(10, 10))
        self.assertIsNone(self.collector.network()['down'])
        self.now += 1; self.file(self.sys, 'class/net/eth-test/ifindex', '99')
        self.assertIsNone(self.collector.network()['down'])
        self.file(self.sys, 'class/net/eth-test/operstate', 'down')
        self.assertEqual(self.collector.network()['interface'], 'wifi-test')

    def test_ipv6_default_and_disconnected(self):
        self.net(); self.file(self.proc, 'net/route', '')
        self.file(self.proc, 'net/ipv6_route', '0' * 32 + ' 00 ' + '0' * 32 + ' 00 ' + '0' * 32 + ' 00000100 00000000 00000000 00000001 wifi-test\n')
        self.assertEqual(self.collector.network()['interface'], 'wifi-test')
        self.file(self.sys, 'class/net/wifi-test/operstate', 'down')
        self.file(self.sys, 'class/net/eth-test/operstate', 'down')
        missing = self.collector.network()
        self.assertEqual(missing['interface'], ''); self.assertIsNone(missing['up'])

    def test_temperature_real_sensor_priority_and_faults(self):
        self.file(self.sys, 'class/hwmon/hwmon0/name', 'coretemp')
        self.file(self.sys, 'class/hwmon/hwmon0/temp1_label', 'Package id 0')
        self.file(self.sys, 'class/hwmon/hwmon0/temp1_input', '42000')
        self.file(self.sys, 'class/hwmon/hwmon0/temp1_crit', '100000')
        self.file(self.sys, 'class/hwmon/hwmon1/name', 'nvme')
        self.file(self.sys, 'class/hwmon/hwmon1/temp1_input', '70000')
        temperature = self.collector.temperature()
        self.assertEqual(temperature['value'], 42); self.assertEqual(temperature['critical'], 100)
        self.assertIn('Package', temperature['label'])
        self.file(self.sys, 'class/hwmon/hwmon0/temp1_fault', '1')
        self.assertEqual(self.collector.temperature()['value'], 70)
        self.file(self.sys, 'class/hwmon/hwmon1/temp1_input', 'garbage')
        self.assertIsNone(self.collector.temperature()['value'])

    def test_gpu_sysfs_and_unsupported_are_not_fabricated(self):
        self.file(self.sys, 'class/drm/card0/device/uevent', 'DRIVER=i915\n')
        self.file(self.sys, 'class/drm/card0/device/vendor', '0x8086')
        unsupported = self.collector.gpu()
        self.assertIsNone(unsupported['percent']); self.assertIn('i915', unsupported['name'])
        self.now += 3
        self.file(self.sys, 'class/drm/card1/device/uevent', 'DRIVER=amdgpu\n')
        self.file(self.sys, 'class/drm/card1/device/gpu_busy_percent', '37')
        self.assertEqual(self.collector.gpu()['percent'], 37)
        self.runner.assert_not_called()

    def test_nvidia_read_only_query_timeout_and_cache(self):
        self.file(self.sys, 'class/drm/card0/device/vendor', '0x10de')
        self.runner.return_value = SimpleNamespace(returncode=0, stdout='45, Test GPU\n')
        with patch.object(DASH.shutil, 'which', return_value='/usr/bin/nvidia-smi'):
            self.assertEqual(self.collector.gpu()['percent'], 45)
            self.collector.gpu(); self.assertEqual(self.runner.call_count, 1)
            args, kwargs = self.runner.call_args
            self.assertEqual(args[0], ['nvidia-smi', '--query-gpu=utilization.gpu,name', '--format=csv,noheader,nounits'])
            self.assertNotIn('shell', kwargs); self.assertLess(kwargs['timeout'], 1)
            self.now += 3; self.runner.side_effect = subprocess.TimeoutExpired('nvidia-smi', 0.8)
            self.assertIsNone(self.collector.gpu()['percent'])

    def test_missing_hardware_serializes_nulls(self):
        sample = self.collector.sample()
        encoded = json.dumps(sample, allow_nan=False)
        self.assertIsNone(sample['cpu']['percent']); self.assertIsNone(sample['gpu']['percent'])
        self.assertIsNone(sample['temperature']['value']); self.assertEqual(sample['storage'], [])
        self.assertIn('null', encoded)

    @unittest.skipUnless(sys.platform == 'linux', 'requires actual Linux /proc')
    def test_live_read_only_collector_and_process_shutdown(self):
        response = subprocess.run([sys.executable, str(ROOT / 'scripts/dashboard-service.py'), '--once'], capture_output=True, text=True, timeout=8)
        self.assertEqual(response.returncode, 0, response.stderr)
        sample = json.loads(response.stdout)
        self.assertEqual(sample['event'], 'sample'); self.assertGreater(sample['memory']['total'], 0)
        self.assertIsNotNone(sample['cpu']['percent'])
        self.assertTrue(0 <= sample['cpu']['percent'] <= 100)
        process = subprocess.Popen([sys.executable, '-u', str(ROOT / 'scripts/dashboard-service.py')], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            first = json.loads(process.stdout.readline())
            second = json.loads(process.stdout.readline())
            self.assertGreater(second['time'], first['time'])
        finally:
            process.terminate(); process.communicate(timeout=3)


if __name__ == '__main__':
    unittest.main()
