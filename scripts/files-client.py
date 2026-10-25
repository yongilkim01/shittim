#!/usr/bin/env python3
"""Open a location in the single Shittim Files instance, using argument arrays."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT / 'shell/files.qml'


def uri(value):
    if not value: return ''
    if any(ord(c) < 32 for c in value): raise ValueError('올바르지 않은 경로입니다.')
    parsed = urlsplit(value)
    if parsed.scheme:
        if parsed.scheme not in ('file','trash','network','smb','sftp','mtp','gphoto2') or parsed.username or parsed.password:
            raise ValueError('지원하지 않는 위치입니다.')
        return value
    return Path(value).expanduser().absolute().as_uri()


def call(method, *args):
    return subprocess.run(['quickshell','ipc','--path',str(ENTRY),'call','files',method,*args],
                          capture_output=True, text=True, timeout=5)


def open_locations(locations, new_tab=False):
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if not runtime or not Path(runtime).is_dir() or Path(runtime).stat().st_uid != os.getuid():
        raise ValueError('사용자 그래픽 세션의 XDG_RUNTIME_DIR이 필요합니다.')
    with (Path(runtime) / 'shittim-files-launch.lock').open('a') as lock:
        os.chmod(lock.name,0o600); fcntl.flock(lock,fcntl.LOCK_EX)
        if call('ping').returncode:
            subprocess.run(['quickshell','--daemonize','--path',str(ENTRY)], check=True, stdout=subprocess.DEVNULL)
        for _ in range(50):
            if call('ping').returncode == 0: break
            time.sleep(0.1)
        else: raise ValueError('Shittim Files를 시작하지 못했습니다.')
        for index, value in enumerate(locations or ['']):
            payload=json.dumps({'uri':uri(value),'newTab':new_tab or index>0},ensure_ascii=False)
            result=call('open',payload)
            if result.returncode or result.stdout.strip() != 'requested':
                raise ValueError('Shittim Files에 위치를 전달하지 못했습니다.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--new-tab',action='store_true')
    parser.add_argument('locations',nargs='*')
    args=parser.parse_args()
    if len(args.locations)>16: parser.error('한 번에 16개 위치까지 열 수 있습니다.')
    try: open_locations(args.locations,args.new_tab)
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print('[Shittim:오류] '+(str(error) if isinstance(error,ValueError) else '파일 관리자 실행에 실패했습니다.'),file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__': sys.exit(main())
