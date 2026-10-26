#!/usr/bin/env python3
"""Export an existing window check using a strict schema; publish only on --publish."""
import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORT = Path('diagnostics/windows-latest.json')
SPEC = importlib.util.spec_from_file_location('login_diagnostics', ROOT/'scripts/diagnose.py')
DIAG = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(DIAG)
ADDRESS = re.compile(r'0x[0-9a-fA-F]{1,16}\Z')
RESTORE = re.compile(r'shittim-restore_(-?\d{1,6})_(-?\d{1,6})_(\d{1,6})_(\d{1,6})_[01]\Z')
FOCUS_FLAGS = ('requested', 'grabbed', 'windowActive', 'viewFocused')
FOCUS_EVENTS = {'start', 'request', 'grab', 'keyboard', 'view', 'grab-cleared', 'active-window', 'desktop-press'}


def clean_focus(value):
    if not isinstance(value, dict) or value.get('protocol') != 1: return {'protocol': 0}
    surfaces = value.get('surfaces', [])
    if not isinstance(surfaces, list) or len(surfaces)>32: raise ValueError('바탕화면 포커스 항목 수를 확인하세요.')
    output = {'protocol': 1, 'capturing': value.get('capturing') is True, 'surfaces': []}
    for surface in surfaces:
        if not isinstance(surface, dict): raise ValueError('바탕화면 포커스 형식을 확인하세요.')
        item = {key: surface.get(key) is True for key in FOCUS_FLAGS}
        events = surface.get('events', [])
        if not isinstance(events, list) or len(events)>64: raise ValueError('바탕화면 포커스 이벤트 수를 확인하세요.')
        item['events'] = []
        for event in events:
            if not isinstance(event, dict) or event.get('event') not in FOCUS_EVENTS: continue
            ms = number(event.get('ms'))
            if not 0<=ms<=60000: raise ValueError('바탕화면 포커스 이벤트 시간을 확인하세요.')
            item['events'].append(dict(event=event['event'], ms=ms, **{key: event.get(key) is True for key in FOCUS_FLAGS}))
        output['surfaces'].append(item)
    return output


def number(value):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value) or abs(value)>10000000:
        raise ValueError('창 진단 수치가 올바르지 않습니다. 원본 파일은 보존했습니다.')
    return value


def vector(value, length):
    if not isinstance(value, list) or len(value)!=length: raise ValueError('창 진단 좌표 형식을 확인하세요.')
    return [number(item) for item in value]


def clean_report(source):
    if not isinstance(source, dict) or not isinstance(source.get('samples'), list) or not 1<=len(source['samples'])<=128:
        raise ValueError('기존 창 진단 파일 형식을 확인하세요.')
    settings = source.get('settings', {})
    result = {'schema': 1, 'settings': {key: number(settings[key]) if settings.get(key) is not None else None
        for key in ('input:follow_mouse', 'input:float_switch_override_focus')}, 'samples': []}
    origin = number(source['samples'][0]['time'])
    for sample in source['samples']:
        active = sample.get('active')
        output = dict(time=round(number(sample['time'])-origin, 3), active=active if isinstance(active, str) and ADDRESS.fullmatch(active) else None,
            cursor={key: number(sample['cursor'][key]) for key in ('x', 'y')}, windows=[], monitors=[])
        if 'desktopFocus' in sample: output['desktopFocus'] = clean_focus(sample['desktopFocus'])
        if len(sample['windows'])>512 or len(sample['monitors'])>32: raise ValueError('창 진단 항목 수가 한도를 초과했습니다.')
        for client in sample['windows']:
            value = client.get('address')
            if not isinstance(value, str) or not ADDRESS.fullmatch(value): raise ValueError('창 주소 형식을 확인하세요.')
            class_name = client.get('class', '')
            if not isinstance(class_name, str) or not re.fullmatch(r'[A-Za-z0-9_. -]{0,128}', class_name) or DIAG.scrub(class_name)!=class_name:
                class_name = '<other>'
            item = {'address': value, 'class': class_name, 'at': vector(client['at'], 2), 'size': vector(client['size'], 2),
                'tags': [tag for tag in client.get('tags', []) if isinstance(tag, str) and (tag=='shittim-maximized' or RESTORE.fullmatch(tag))]}
            for key in ('mapped', 'floating', 'hidden'): item[key] = client.get(key) is True
            for key in ('monitor', 'workspace', 'fullscreen', 'fullscreenClient'):
                item[key] = number(client[key]) if client.get(key) is not None else None
            output['windows'].append(item)
        for monitor in sample['monitors']:
            item = {key: number(monitor[key]) for key in ('id', 'x', 'y', 'width', 'height', 'scale', 'transform')}
            item['reserved'] = vector(monitor['reserved'], 4); item['focused'] = monitor.get('focused') is True
            output['monitors'].append(item)
        result['samples'].append(output)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    if sys.platform!='linux' or os.geteuid()==0: raise ValueError('Arch 노트북에서 sudo 없이 실행하세요.')
    source = Path(os.environ.get('XDG_STATE_HOME') or Path.home()/'.local/state')/'shittim/window-check.json'
    if not source.is_file(): raise ValueError('저장된 window-check.json이 없습니다. 기존 진단 파일 위치를 확인하세요.')
    if source.stat().st_size>4*1024*1024: raise ValueError('기존 창 진단 파일이 4MiB를 초과했습니다.')
    report = clean_report(json.loads(source.read_text(encoding='utf-8')))
    directory, destination = ROOT/REPORT.parent, ROOT/REPORT
    if directory.is_symlink() or destination.is_symlink(): raise ValueError('진단 경로가 심볼릭 링크이므로 쓰지 않았습니다.')
    directory.mkdir(exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('[Shittim] 기존 로그에서 창 상태만 추출했습니다. 원본과 실행 중인 창은 변경하지 않았습니다.', flush=True)
    if args.publish:
        DIAG.publish(REPORT, 'chore: share laptop window diagnostics')
    else: print('[Shittim] 전송하려면 bash scripts/share-window-diagnostics.sh --publish 를 실행하세요.')


if __name__=='__main__':
    try: main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        detail = error.output if isinstance(error, subprocess.CalledProcessError) and error.output else str(error)
        print('[Shittim:오류] '+DIAG.scrub(detail), file=sys.stderr); sys.exit(1)
