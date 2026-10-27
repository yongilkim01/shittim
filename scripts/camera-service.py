#!/usr/bin/env python3
"""Camera presence/use observer for Shittim; read-only, never opens a camera for capture.

Protocol (stdout, one JSON object per line, only when the state changes):
  {"event": "state", "watch": "inotify"|"poll", "cameras": [{"node", "name", "users", "error"}]}

Presence comes from /sys/class/video4linux, capture capability from VIDIOC_QUERYCAP
(only when a node appears). "In use" means a process visible to this user holds the
device node open (/proc/<pid>/fd). inotify open/close events on /dev/videoN trigger the
re-scan, so there is no steady polling while inotify is available.
"""
import argparse
import ctypes
import errno
import fcntl
import json
import os
from pathlib import Path
import re
import select
import struct
import sys
import time

SYSFS = Path('/sys/class/video4linux')
DEV = Path('/dev')
PROC = Path('/proc')
NODE = re.compile(r'^video\d+$')
VIDIOC_QUERYCAP = 0x80685600  # _IOR('V', 0, struct v4l2_capability) with sizeof == 104
CAP_VIDEO_CAPTURE = 0x00000001
CAP_VIDEO_CAPTURE_MPLANE = 0x00001000
CAP_DEVICE_CAPS = 0x80000000
IN_ATTRIB, IN_CLOSE_WRITE, IN_CLOSE_NOWRITE, IN_OPEN = 0x4, 0x8, 0x10, 0x20
IN_CREATE, IN_DELETE, IN_IGNORED = 0x100, 0x200, 0x8000
IN_NONBLOCK, IN_CLOEXEC = 0o4000, 0o2000000
DEVICE_MASK = IN_OPEN | IN_CLOSE_WRITE | IN_CLOSE_NOWRITE | IN_ATTRIB
EVENT = struct.Struct('iIII')
SETTLE = 0.3
POLL_INTERVAL = 5.0


def capture_capable(caps):
    """Return True for VIDEO_CAPTURE nodes; metadata-only nodes of the same webcam are skipped."""
    capabilities, device_caps = caps
    effective = device_caps if capabilities & CAP_DEVICE_CAPS else capabilities
    return bool(effective & (CAP_VIDEO_CAPTURE | CAP_VIDEO_CAPTURE_MPLANE))


def query_caps(path):
    """(capabilities, device_caps) or an error code string. Opening for QUERYCAP does not start streaming."""
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    except OSError as error:
        return 'permission' if error.errno in (errno.EACCES, errno.EPERM) else 'unavailable'
    try:
        buffer = bytearray(104)
        fcntl.ioctl(descriptor, VIDIOC_QUERYCAP, buffer, True)
        return struct.unpack_from('II', buffer, 84)
    except OSError:
        return 'unavailable'
    finally:
        os.close(descriptor)


def read_name(sysfs, node):
    try:
        return (sysfs / node / 'name').read_text(encoding='utf-8', errors='replace').strip() or node
    except OSError:
        return node


def device_users(nodes, proc=PROC, own_pid=None):
    """Map node name -> sorted process names holding /dev/<node>. Unreadable processes are skipped."""
    own_pid = os.getpid() if own_pid is None else own_pid
    targets = {str(DEV / node): node for node in nodes}
    users = {node: set() for node in nodes}
    if not targets:
        return {}
    try:
        entries = list(proc.iterdir())
    except OSError:
        return {node: [] for node in nodes}
    for entry in entries:
        if not entry.name.isdigit() or int(entry.name) == own_pid:
            continue
        try:
            links = list((entry / 'fd').iterdir())
        except OSError:
            continue
        held = set()
        for link in links:
            try:
                target = os.readlink(link)
            except OSError:
                continue
            if target in targets:
                held.add(targets[target])
        if held:
            try:
                name = (entry / 'comm').read_text(encoding='utf-8', errors='replace').strip() or entry.name
            except OSError:
                name = entry.name
            for node in held:
                users[node].add(name)
    return {node: sorted(names) for node, names in users.items()}


class Cameras:
    def __init__(self, sysfs=SYSFS, dev=DEV, proc=PROC, query=query_caps):
        self.sysfs, self.dev, self.proc, self.query = sysfs, dev, proc, query
        self.caps = {}

    def nodes(self):
        try:
            return sorted((entry.name for entry in self.sysfs.iterdir() if NODE.match(entry.name)), key=lambda name: int(name[5:]))
        except OSError:
            return []

    def refresh_caps(self, node):
        # Queried once per appearance/ACL change; the query's own open must not retrigger a scan loop.
        if node not in self.caps:
            self.caps[node] = self.query(str(self.dev / node))

    def snapshot(self):
        present = self.nodes()
        for node in list(self.caps):
            if node not in present:
                del self.caps[node]
        cameras = []
        for node in present:
            self.refresh_caps(node)
            caps = self.caps[node]
            if isinstance(caps, str):
                cameras.append({'node': node, 'name': read_name(self.sysfs, node), 'error': caps})
            elif capture_capable(caps):
                cameras.append({'node': node, 'name': read_name(self.sysfs, node), 'error': ''})
        holders = device_users([camera['node'] for camera in cameras], self.proc)
        for camera in cameras:
            camera['users'] = holders.get(camera['node'], [])
        return cameras


class Inotify:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.add = libc.inotify_add_watch
        self.add.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
        self.fd = libc.inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), 'inotify_init1')
        self.watches = {}

    def watch(self, path, mask):
        if path in self.watches.values():
            return
        descriptor = self.add(self.fd, os.fsencode(path), mask)
        if descriptor >= 0:
            self.watches[descriptor] = path

    def read(self):
        """Return (path, mask, name) events; drops watches the kernel removed."""
        try:
            data = os.read(self.fd, 65536)
        except BlockingIOError:
            return []
        events, offset = [], 0
        while offset + EVENT.size <= len(data):
            descriptor, mask, _cookie, length = EVENT.unpack_from(data, offset)
            name = data[offset + EVENT.size:offset + EVENT.size + length].split(b'\0', 1)[0].decode(errors='replace')
            offset += EVENT.size + length
            path = self.watches.get(descriptor)
            if mask & IN_IGNORED:
                self.watches.pop(descriptor, None)
            if path is not None:
                events.append((path, mask, name))
        return events


def emit(state):
    sys.stdout.write(json.dumps(state, ensure_ascii=False, sort_keys=True) + '\n')
    sys.stdout.flush()


def run(cameras):
    try:
        notify = Inotify()
        notify.watch(str(DEV), IN_CREATE | IN_DELETE)
    except (OSError, AttributeError):
        notify = None
    last, due = None, 0.0
    while True:
        if notify is not None:
            for node in cameras.nodes():
                notify.watch(str(DEV / node), DEVICE_MASK)
        state = {'event': 'state', 'watch': 'inotify' if notify else 'poll', 'cameras': cameras.snapshot()}
        if state != last:
            emit(state)
            last = state
        due = 0.0
        while not due:
            # Quickshell stops the helper with the shell; an orphaned helper exits on the next wake-up.
            ready, _, _ = select.select([notify.fd] if notify else [], [], [], 30.0 if notify else POLL_INTERVAL)
            if os.getppid() == 1:
                return 0
            if notify is None:
                due = time.monotonic()
                continue
            for path, mask, name in notify.read() if notify.fd in ready else []:
                if path == str(DEV) and not NODE.match(name):
                    continue
                if path == str(DEV) and mask & IN_CREATE:
                    # udev applies the seat ACL after the node appears; ATTRIB re-queries it.
                    cameras.caps.pop(name, None)
                if mask & IN_ATTRIB:
                    cameras.caps.pop(Path(path).name, None)
                due = time.monotonic()
        # Coalesce the open/close burst of device enumeration before reporting "in use".
        time.sleep(SETTLE)
        if notify is not None:
            notify.read()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='현재 상태를 한 번 출력하고 종료')
    options = parser.parse_args(argv)
    cameras = Cameras()
    if options.check:
        emit({'event': 'state', 'watch': 'none', 'cameras': cameras.snapshot()})
        return 0
    return run(cameras)


if __name__ == '__main__':
    sys.exit(main())
