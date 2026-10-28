#!/usr/bin/env python3
"""Watch shell panel state across a suspend: runtime status latency, panel ownership history and mapped layers.

Run it, suspend and wake, then use the bar. Only changes are logged, with wall-clock time, to
~/.local/state/shittim/panel-watch-<time>.txt (diagnose.sh includes the latest one). Read-only: it never
changes settings, opens panels or sends input.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SLOW = 0.5


def run(args, timeout=5):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ''


def shell_status():
    started = time.monotonic()
    code, output = run(['quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'), 'call', 'runtime', 'status'])
    elapsed = time.monotonic() - started
    line = next((item for item in output.splitlines() if item.startswith('{')), '')
    try:
        return json.loads(line) if code == 0 else None, elapsed
    except ValueError:
        return None, elapsed


def shell_layers():
    code, output = run(['hyprctl', '-j', 'layers'])
    try:
        data = json.loads(output) if code == 0 else {}
    except ValueError:
        return None
    return sorted({item.get('namespace', '') for monitor in data.values() for level in monitor.get('levels', {}).values()
                   for item in level if str(item.get('namespace', '')).startswith('shittim')})


def slept_seconds():
    return time.clock_gettime(time.CLOCK_BOOTTIME) - time.monotonic()


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    duration = int(argv[0]) if argv and argv[0].isdigit() else 300
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        print('[Shittim:오류] Hyprland 세션의 터미널에서 실행하세요.', file=sys.stderr)
        return 1
    log = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'shittim' / time.strftime('panel-watch-%Y%m%d-%H%M%S.txt')
    log.parent.mkdir(parents=True, exist_ok=True)
    print(f'패널 상태 기록 시작 ({duration}초). 절전했다가 깨운 뒤 TopBar 를 눌러 보세요. Ctrl+C 로 끝낼 수 있습니다.')
    print('기록: ' + str(log))
    last = {'owner': None, 'layers': None, 'history': 0, 'slept': slept_seconds(), 'ok': None}
    end = time.monotonic() + duration
    with log.open('w', encoding='utf-8') as out:
        def write(text):
            line = time.strftime('%H:%M:%S') + f'.{int(time.time() * 1000) % 1000:03d} ' + text
            out.write(line + '\n')
            out.flush()
            print(line)
        try:
            while time.monotonic() < end:
                slept = slept_seconds()
                if slept - last['slept'] > 1:
                    write(f'절전 복귀 감지 (절전 {slept - last["slept"]:.0f}초)')
                last['slept'] = slept
                status, elapsed = shell_status()
                if (status is not None) != last['ok']:
                    write('Shittim 응답 ' + ('정상' if status is not None else '없음'))
                    last['ok'] = status is not None
                if elapsed > SLOW:
                    write(f'Shittim 응답 느림 {elapsed:.2f}초')
                if status is not None:
                    if status.get('owner') != last['owner']:
                        write(f'패널 소유: {last["owner"]!r} → {status.get("owner")!r} · 화면 {status.get("screens")} · control {status.get("control")}')
                        last['owner'] = status.get('owner')
                    history = status.get('history') or []
                    new = [item for item in history if item.get('time', 0) > last['history']]
                    for item in new:
                        write(f'  기록: {item.get("name")} {item.get("event")}')
                    if history:
                        last['history'] = max(item.get('time', 0) for item in history)
                layers = shell_layers()
                if layers != last['layers']:
                    write('Shittim 레이어: ' + (', '.join(layers) if layers else '없음' if layers is not None else 'hyprctl 실패'))
                    last['layers'] = layers
                time.sleep(0.25)
        except KeyboardInterrupt:
            pass
        write('기록 끝')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
