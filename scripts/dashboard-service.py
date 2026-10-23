#!/usr/bin/env python3
"""Read-only Linux dashboard telemetry. No elevated privileges or persistent files."""
import argparse
import asyncio
import csv
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def read(path):
    try:
        return path.read_text(encoding='utf-8').strip()
    except (OSError, UnicodeError):
        return ''


def number(value, minimum=None, maximum=None):
    try:
        result = float(value)
        if not math.isfinite(result) or minimum is not None and result < minimum or maximum is not None and result > maximum:
            return None
        return result
    except (TypeError, ValueError):
        return None


def label(value, limit=160):
    return re.sub(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]', '', str(value))[:limit]


def cpu_counters(text):
    try:
        line = text.splitlines()[0].split()
        if line[0] != 'cpu' or len(line) < 6:
            return None
        values = [int(item) for item in line[1:9]]
        if any(value < 0 for value in values):
            return None
        # guest/guest_nice are already included in user/nice; do not count twice.
        return sum(values), values[3] + values[4]
    except (ValueError, IndexError):
        return None


def cpu_usage(previous, current):
    if previous is None or current is None:
        return None
    total, idle = current[0] - previous[0], current[1] - previous[1]
    if total <= 0 or idle < 0 or idle > total:
        return None
    return round(100 * (total - idle) / total, 1)


def memory_info(text):
    values = {}
    for line in text.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[2] == 'kB' and fields[1].isdigit():
            values[fields[0].rstrip(':')] = int(fields[1]) * 1024
    total, available = values.get('MemTotal'), values.get('MemAvailable')
    if not total or available is None or available < 0 or available > total:
        return {'used': None, 'total': None, 'percent': None}
    used = total - available
    return {'used': used, 'total': total, 'percent': round(100 * used / total, 1)}


def mount_unescape(value):
    return re.sub(r'\\(040|011|012|134)', lambda match: chr(int(match[1], 8)), value)


def local_mounts(text):
    supported = {'ext2', 'ext3', 'ext4', 'btrfs', 'xfs', 'f2fs', 'vfat', 'exfat', 'ntfs', 'ntfs3', 'fuseblk', 'zfs', 'bcachefs', 'jfs', 'reiserfs', 'hfsplus', 'overlay'}
    mounts = {}
    for line in text.splitlines():
        before, separator, after = line.partition(' - ')
        left, right = before.split(), after.split()
        if not separator or len(left) < 6 or len(right) < 2 or right[0] not in supported:
            continue
        mount, device = mount_unescape(left[4]), mount_unescape(right[1])
        if not mount.startswith('/') or right[0] == 'overlay' and mount != '/':
            continue
        mounts[mount] = {'mount': mount, 'device': device, 'filesystem': right[0]}
    return sorted(mounts.values(), key=lambda item: (item['mount'] != '/', item['mount']))[:64]


class Collector:
    def __init__(self, proc=Path('/proc'), sysfs=Path('/sys'), clock=time.monotonic, statvfs=os.statvfs, runner=subprocess.run, isdir=os.path.isdir):
        self.proc, self.sysfs, self.clock, self.statvfs, self.runner = Path(proc), Path(sysfs), clock, statvfs, runner
        self.isdir = isdir
        self.previous_cpu = None
        self.previous_net = {}
        self.storage = []
        self.storage_ready = False
        self.gpu_cache = None
        self.gpu_time = -math.inf
        cpu = read(self.proc / 'cpuinfo')
        self.cpu_name = next((label(line.split(':', 1)[1].strip()) for line in cpu.splitlines()
            if ':' in line and line.split(':', 1)[0].strip() in ('model name', 'Hardware', 'Processor')), '')

    def disks(self):
        result = []
        for item in local_mounts(read(self.proc / 'self/mountinfo')):
            try:
                if not self.isdir(item['mount']):
                    continue
                info = self.statvfs(item['mount'])
                total = info.f_blocks * info.f_frsize
                free = info.f_bfree * info.f_frsize
                available = info.f_bavail * info.f_frsize
                if total <= 0 or not 0 <= free <= total:
                    continue
                used = total - free
                # df-style utilization excludes blocks reserved for privileged users.
                denominator = used + max(0, available)
                result.append(dict(item, mount=label(item['mount'], 512), device=label(item['device'], 256),
                    used=used, total=total, percent=round(100 * used / denominator, 1) if denominator > 0 else 0))
            except (OSError, ValueError, OverflowError):
                continue
        return result

    def network(self):
        now = self.clock()
        current, interfaces = {}, []
        for line in read(self.proc / 'net/dev').splitlines()[2:]:
            name, separator, tail = line.rpartition(':')
            name = name.strip()
            if not separator or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,64}', name) or name == 'lo' or name.startswith('p2p-dev-'):
                continue
            fields = tail.split()
            try:
                rx, tx = int(fields[0]), int(fields[8])
                if rx < 0 or tx < 0:
                    continue
            except (ValueError, IndexError):
                continue
            device = self.sysfs / 'class/net' / name
            index = read(device / 'ifindex')
            previous = self.previous_net.get(name)
            down = up = None
            if previous and index and previous[0] == index and now > previous[3] and rx >= previous[1] and tx >= previous[2]:
                down, up = (rx - previous[1]) / (now - previous[3]), (tx - previous[2]) / (now - previous[3])
            current[name] = (index, rx, tx, now)
            interfaces.append({'name': name, 'down': down, 'up': up, 'state': read(device / 'operstate'),
                'physical': (device / 'device').exists()})
        self.previous_net = current
        routes = []
        for line in read(self.proc / 'net/route').splitlines()[1:]:
            fields = line.split()
            try:
                if len(fields) >= 8 and fields[1] == '00000000' and fields[7] == '00000000' and int(fields[3], 16) & 1 and not int(fields[3], 16) & 0x200:
                    routes.append((0, int(fields[6]), fields[0]))
            except ValueError:
                continue
        for line in read(self.proc / 'net/ipv6_route').splitlines():
            fields = line.split()
            try:
                if len(fields) == 10 and fields[0] == '0' * 32 and fields[1] == '00' and int(fields[8], 16) & 1 and not int(fields[8], 16) & 0x200:
                    routes.append((1, int(fields[5], 16), fields[9]))
            except ValueError:
                continue
        candidates = {item['name']: item for item in interfaces if item['state'] in ('up', 'unknown')}
        selected = next((candidates[name] for _, _, name in sorted(routes) if name in candidates), None)
        if selected is None:
            selected = next((item for item in interfaces if item['state'] == 'up' and item['physical']), None)
        return {'interface': selected['name'] if selected else '', 'down': selected['down'] if selected else None,
            'up': selected['up'] if selected else None, 'interfaces': interfaces}

    def temperature(self):
        sensors = []
        for hwmon in sorted((self.sysfs / 'class/hwmon').glob('hwmon*')):
            chip = read(hwmon / 'name')
            for path in sorted(hwmon.glob('temp*_input')):
                stem = path.name.removesuffix('_input')
                if read(hwmon / (stem + '_fault')) == '1' or read(hwmon / (stem + '_enable')) == '0':
                    continue
                raw = number(read(path), -40000, 150000)
                if raw is None:
                    continue
                caption = read(hwmon / (stem + '_label')) or chip or hwmon.name
                critical = number(read(hwmon / (stem + '_crit')), 1000, 200000)
                priority = 0 if chip in ('coretemp', 'k10temp', 'zenpower', 'cpu_thermal', 'soc_thermal') else 2
                if re.search(r'package|tctl|tdie|cpu', caption, re.I):
                    priority = 0
                sensors.append((priority, {'value': raw / 1000, 'label': label(chip + ' · ' + caption) if chip != caption else label(caption),
                    'critical': critical / 1000 if critical else None}))
        for zone in sorted((self.sysfs / 'class/thermal').glob('thermal_zone*')):
            raw = number(read(zone / 'temp'), -40000, 150000)
            if raw is not None:
                name = read(zone / 'type') or zone.name
                critical = next((number(read(path.with_name(path.name.replace('_type', '_temp'))), 1000, 200000)
                    for path in zone.glob('trip_point_*_type') if read(path) == 'critical'), None)
                sensors.append((1 if re.search(r'cpu|pkg|soc', name, re.I) else 3,
                    {'value': raw / 1000, 'label': label(name), 'critical': critical / 1000 if critical else None}))
        return min(sensors, key=lambda item: (item[0], -item[1]['value']))[1] if sensors else {'value': None, 'label': '', 'critical': None}

    def gpu(self):
        now = self.clock()
        if self.gpu_cache is not None and now - self.gpu_time < 2:
            return self.gpu_cache
        devices = []
        for card in sorted((self.sysfs / 'class/drm').glob('card*')):
            if not re.fullmatch(r'card\d+', card.name):
                continue
            path = card / 'device'
            if not path.exists():
                continue
            driver = next((line.partition('=')[2] for line in read(path / 'uevent').splitlines() if line.startswith('DRIVER=')), '')
            name = read(path / 'product_name') or ((driver or read(path / 'vendor') or 'GPU') + ' · ' + card.name)
            devices.append({'name': label(name), 'percent': number(read(path / 'gpu_busy_percent'), 0, 100),
                'vendor': read(path / 'vendor'), 'primary': read(path / 'boot_vga') == '1'})
        if any(item['vendor'] == '0x10de' for item in devices) and shutil.which('nvidia-smi'):
            try:
                response = self.runner(['nvidia-smi', '--query-gpu=utilization.gpu,name', '--format=csv,noheader,nounits'],
                    capture_output=True, text=True, timeout=0.8, check=False, env=dict(os.environ, LC_ALL='C'))
                if response.returncode == 0:
                    for fields in csv.reader(response.stdout.splitlines()):
                        if len(fields) == 2:
                            devices.append({'name': label(fields[1].strip()), 'percent': number(fields[0].strip(), 0, 100), 'vendor': '0x10de', 'primary': False})
            except (OSError, subprocess.TimeoutExpired):
                pass
        devices.sort(key=lambda item: (item['percent'] is None, not item['primary'], item['name']))
        self.gpu_cache = devices[0] if devices else {'name': '', 'percent': None}
        self.gpu_time = now
        return self.gpu_cache

    def sample(self, include_storage=True):
        current = cpu_counters(read(self.proc / 'stat'))
        usage = cpu_usage(self.previous_cpu, current)
        self.previous_cpu = current
        if include_storage:
            self.storage = self.disks()
            self.storage_ready = True
        gpu, temperature, network = self.gpu(), self.temperature(), self.network()
        return {'event': 'sample', 'time': int(self.clock() * 1000), 'cpu': {'name': self.cpu_name, 'percent': usage},
            'memory': memory_info(read(self.proc / 'meminfo')), 'gpu': gpu, 'temperature': temperature,
            'storage': self.storage, 'storageReady': self.storage_ready, 'network': network}


async def stream():
    collector = Collector()
    storage = None
    next_storage = 0
    while True:
        now = time.monotonic()
        if storage is not None and storage.done():
            try:
                collector.storage = storage.result()
            except OSError:
                collector.storage = []
            collector.storage_ready = True
            storage = None
        if storage is None and now >= next_storage:
            # Slow/unresponsive filesystems never block the CPU/network sampler.
            storage = asyncio.create_task(asyncio.to_thread(collector.disks))
            next_storage = now + 15
        print(json.dumps(collector.sample(False), ensure_ascii=False, allow_nan=False), flush=True)
        await asyncio.sleep(max(0.1, 1 - (time.monotonic() - now)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--once', action='store_true', help='print one real sample after a counter interval')
    args = parser.parse_args()
    if sys.platform != 'linux':
        print(json.dumps({'event': 'error', 'error': 'LinuxRequired'}), flush=True)
        return 1
    if args.once:
        collector = Collector()
        collector.sample(True)
        time.sleep(0.25)
        print(json.dumps(collector.sample(False), ensure_ascii=False, allow_nan=False), flush=True)
    else:
        asyncio.run(stream())
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (BrokenPipeError, KeyboardInterrupt):
        pass
