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
ROOT = Path(__file__).resolve().parents[1]


def desktop_focus(method='focusStatus', runner=subprocess.run):
    try:
        result = runner(['quickshell', 'ipc', '--path', str(ROOT/'shell/shell.qml'), 'call', 'desktop', method],
                        check=True, capture_output=True, text=True, timeout=2)
        value = json.loads(result.stdout)
        if not isinstance(value, dict) or value.get('protocol') != 1:
            raise ValueError('UnsupportedTrace')
        return value
    except (OSError, ValueError, subprocess.SubprocessError):
        return {'protocol': 0}


def snapshot(api, focus=None):
    clients = api.query('clients')
    active = api.query('activewindow')
    result = dict(time=time.monotonic(), active=active.get('address'), cursor=api.query('cursorpos'),
        windows=[{**{key: client.get(key) for key in ('address', 'class', 'mapped', 'floating', 'monitor', 'at', 'size', 'fullscreen', 'fullscreenClient')},
            'workspace': client.get('workspace', {}).get('id'),
            'hidden': bool(WINDOWS.HIDDEN.fullmatch(client.get('workspace', {}).get('name', ''))),
            'tags': [tag for tag in client.get('tags', []) if tag == WINDOWS.MAXIMIZED or WINDOWS.RESTORE.fullmatch(tag)]}
            for client in clients],
        monitors=[{key: monitor.get(key) for key in ('id', 'x', 'y', 'width', 'height', 'scale', 'transform', 'reserved', 'focused')}
            for monitor in api.query('monitors')])
    if focus is not None: result['desktopFocus'] = focus()
    return result


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
        started = desktop_focus('startInputTrace') if args.watch else desktop_focus()
        tracing = started.get('protocol') == 1
        if args.watch:
            print(f'{args.watch}초 동안 Kitty → 바탕화면 → 같은 Kitty를 클릭하고 입력을 확인하세요. 입력 내용은 기록하지 않습니다.', flush=True)
            if not tracing:
                print('[Shittim:주의] 실행 중인 Shittim이 포커스 진단에 응답하지 않습니다. git pull 후 systemctl --user restart shittim.service 하고 다시 검사하세요.', flush=True)
        try:
            samples = [snapshot(api, desktop_focus)]
            until = time.monotonic() + args.watch
            while time.monotonic() < until:
                time.sleep(min(0.5, max(0, until-time.monotonic())))
                samples.append(snapshot(api, desktop_focus))
        finally:
            if tracing and args.watch: stopped = desktop_focus('stopInputTrace')
        if tracing and args.watch: samples[-1]['desktopFocus'] = stopped
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
        if not problems: print('설정·최대화 복원 기록·작업 영역 정적 검사 통과. 클릭 포커스 정상 동작을 판정한 결과는 아닙니다.')
        return int(bool(problems))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('[Shittim:오류] 창 상태를 읽지 못했습니다: ' + type(error).__name__, file=sys.stderr)
        return 1


if __name__ == '__main__': sys.exit(main())
