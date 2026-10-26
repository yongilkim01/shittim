#!/usr/bin/env python3
"""Read-only window diagnostics; no titles, file names, input text, or automatic upload."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

SPEC = importlib.util.spec_from_file_location('window_actions', Path(__file__).with_name('window-service.py'))
WINDOWS = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(WINDOWS)


def snapshot(api):
    clients = api.query('clients')
    active = api.query('activewindow')
    return dict(time=time.monotonic(), active=active.get('address'), cursor=api.query('cursorpos'),
        windows=[{**{key: client.get(key) for key in ('address', 'class', 'mapped', 'floating', 'monitor', 'at', 'size', 'fullscreen', 'fullscreenClient')},
            'workspace': client.get('workspace', {}).get('id'),
            'hidden': bool(WINDOWS.HIDDEN.fullmatch(client.get('workspace', {}).get('name', ''))),
            'tags': [tag for tag in client.get('tags', []) if tag == WINDOWS.MAXIMIZED or WINDOWS.RESTORE.fullmatch(tag)]}
            for client in clients],
        monitors=[{key: monitor.get(key) for key in ('id', 'x', 'y', 'width', 'height', 'scale', 'transform', 'reserved', 'focused')}
            for monitor in api.query('monitors')])


def inspect(state, settings):
    problems = []
    if settings.get('input:follow_mouse') != 2 or settings.get('input:float_switch_override_focus') != 0:
        problems.append('클릭 포커스 설정이 최신 Shittim 정책과 다릅니다. setup-desktop-ux.sh 실행 후 hyprctl reload 하세요.')
    for client in state['windows']:
        if not client.get('mapped') or client['hidden'] or WINDOWS.MAXIMIZED not in client['tags']: continue
        if int(client.get('fullscreen', 0)) & 2: continue
        if not WINDOWS.restore_geometry(client): problems.append('최대화 창의 복원 위치 기록이 없습니다: ' + client['address'])
        monitor = next((m for m in state['monitors'] if m['id'] == client['monitor']), None)
        if monitor:
            x, y, width, height = WINDOWS.work_area(monitor)
            cx, cy = client['at']; cw, ch = client['size']
            if cx < x-2 or cy < y-2 or cx+cw > x+width+2 or cy+ch > y+height+2:
                problems.append('최대화 창이 작업 영역을 벗어났습니다: ' + client['address'])
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--watch', type=int, default=0, metavar='SECONDS')
    args = parser.parse_args()
    if not 0 <= args.watch <= 30: parser.error('--watch는 0~30초입니다.')
    try:
        api = WINDOWS.Windows()
        settings = {key: api.query('getoption', key).get('int') for key in ('input:follow_mouse', 'input:float_switch_override_focus')}
        if args.watch: print(f'{args.watch}초 동안 창을 마우스로 클릭하고 입력·최대화·복원을 확인하세요. 입력 내용은 기록하지 않습니다.', flush=True)
        samples = [snapshot(api)]
        until = time.monotonic() + args.watch
        while time.monotonic() < until:
            time.sleep(min(0.5, max(0, until-time.monotonic())))
            samples.append(snapshot(api))
        problems = inspect(samples[-1], settings)
        destination = Path(os.environ.get('XDG_STATE_HOME') or Path.home()/'.local/state')/'shittim'
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination, delete=False) as temporary:
            json.dump(dict(settings=settings, samples=samples, problems=problems), temporary, ensure_ascii=False, indent=2)
            name = temporary.name
        os.chmod(name, 0o600)
        path = destination/'window-check.json'; os.replace(name, path)
        print('검사 결과: ' + str(path))
        for problem in problems: print('[Shittim:오류] ' + problem)
        if not problems: print('포커스 정책·최대화 복원 기록·작업 영역 검사 통과. 실제 클릭 후 입력 결과는 화면에서 확인하세요.')
        return int(bool(problems))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('[Shittim:오류] 창 상태를 읽지 못했습니다: ' + type(error).__name__, file=sys.stderr)
        return 1


if __name__ == '__main__': sys.exit(main())
