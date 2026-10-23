#!/usr/bin/env python3
"""Check the running shell's dashboard and stop sampling again when initially closed."""
import asyncio
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


async def ipc(action):
    process = await asyncio.create_subprocess_exec('quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'),
        'call', 'dashboard', action, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    try:
        output, _ = await asyncio.wait_for(process.communicate(), 4)
    except asyncio.TimeoutError:
        process.kill(); await process.wait()
        raise RuntimeError('DashboardIPCTimeout')
    if process.returncode:
        raise RuntimeError('DashboardIPCUnavailable')
    return json.loads(output) if output.strip() else None


async def wait_for(predicate):
    for _ in range(32):
        state = await ipc('status')
        if predicate(state):
            return
        await asyncio.sleep(0.25)
    raise RuntimeError('DashboardStateTimeout')


async def main():
    before = await ipc('status')
    if before['opened'] and before['page'] != 'system':
        print('현재 상세 화면을 유지했습니다. System 메뉴에서 실제 측정을 확인하세요.')
        return
    try:
        if not before['opened']:
            await ipc('show')
        await wait_for(lambda state: state['opened'] and state['measuring'] and state['process'] and state['pid'] > 0 and state['ready'] and state['samples'] >= 2)
        print('PASS: 실행 중인 Shittim 대시보드에서 실제 측정 응답 수신')
    finally:
        if not before['opened']:
            await ipc('hide')
            await wait_for(lambda state: not state['opened'] and not state['measuring'] and not state['process'] and state['pid'] == 0)
            print('PASS: 대시보드 닫힘 후 측정 프로세스 종료')


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except Exception as error:
        print('FAIL: 대시보드 검사 (' + type(error).__name__ + ')', file=sys.stderr)
        sys.exit(1)
