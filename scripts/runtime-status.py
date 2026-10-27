#!/usr/bin/env python3
"""Read-only product deployment status; never restart services or load a plugin."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(root=ROOT):
    digest=hashlib.sha256()
    for folder in ('shell','scripts','config','native','assets/gtk'):
        for path in sorted((root/folder).rglob('*')):
            if path.is_file() and path.suffix in ('.qml','.js','.py','.sh','.lua','.hpp','.cpp','.inc','.json','.css','.in'):
                digest.update(path.relative_to(root).as_posix().encode());digest.update(path.read_bytes().replace(b'\r\n',b'\n'))
    return digest.hexdigest()


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=8).stdout.strip()


def inspect(root=ROOT):
    contract = json.loads((root / 'config/compatibility.json').read_text(encoding='utf-8'))
    result = {'protocol':1, 'repository':{}, 'checks':[], 'ok':True}
    def check(name, state, detail):
        result['checks'].append(dict(name=name, state=state, detail=detail))
        if state == 'error': result['ok'] = False
    try:
        result['repository'] = dict(revision=run('git','-C',str(root),'rev-parse','--short','HEAD'),
                                  dirty=bool(run('git','-C',str(root),'status','--porcelain')))
    except (OSError, subprocess.SubprocessError):
        check('repository','warning','Git 상태를 읽지 못했습니다.')
    try:
        data=json.loads(run('quickshell','ipc','--path',str(root/'shell/shell.qml'),'call','runtime','status'))
        matches=data.get('protocol')==contract['protocol'] and data.get('contract')==contract['runtimeContract'] and Path(data.get('configRoot','')).resolve()==(root/'shell').resolve() and data.get('fingerprint')==fingerprint(root)
        result['runtime']=data
        detail='실행 계약·저장소 경로 일치' if matches else '이전 셸 또는 다른 저장소가 실행 중입니다. shittim.service를 다시 시작하세요.'
        if not data.get('fingerprint'):detail='실행 정보 초기화 중입니다. 잠시 후 다시 검사하세요.'
        check('shell','ok' if matches else 'error',detail)
    except (ValueError, OSError, subprocess.SubprocessError):
        check('shell','error','실행 상태를 읽지 못했습니다. 셸 시작 및 runtime IPC 지원 여부를 확인하세요.')
    try:
        spec=importlib.util.spec_from_file_location('shittim_status_titlebars',root/'scripts/titlebar-tool.py')
        tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
        config=tool.files.Config(root=root)
        version=tool.plugin.query('version')
        result['hyprland']={key:version.get(key) for key in ('commit','tag','abiHash')}
        supported=version.get('commit') in contract['titlebars']
        check('titlebar-compatibility','ok' if supported else 'warning','지원 커밋' if supported else '이 Hyprland 커밋의 native 제목 표시줄은 지원 목록에 없습니다. 기본 셸 지원과 별도입니다.')
        manifest=tool.plugin.read_manifest(config,version)
        loaded=tool.plugin.query('plugin','list')
        if manifest:
            valid=any(plugin.get('name')=='hyprbars' and plugin.get('version')==manifest['renderer'] for plugin in loaded)
            check('titlebar-binary','ok' if valid else 'error','설치 바이너리·ABI·렌더러 일치 및 로드됨' if valid else '설치된 새 렌더러가 아직 로드되지 않았습니다.')
        else:
            check('titlebar-binary','warning','선택 기능인 Shittim native 제목 표시줄이 설치되지 않았습니다.')
        target=config.config/'hypr/shittim-titlebars.lua'
        if target.is_file():
            valid=target.read_text(encoding='utf-8')==tool.source(config)
            check('titlebar-config','ok' if valid else 'error','생성 설정 일치' if valid else '설정이 이전 버전입니다. setup-titlebars.sh를 다시 실행하세요.')
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        check('titlebars','error',str(error) if isinstance(error,ValueError) else 'Hyprland 또는 제목 표시줄 상태를 읽지 못했습니다.')
    return result


if __name__=='__main__':
    if sys.argv[1:]==['--fingerprint']:
        print(fingerprint());sys.exit(0)
    status=inspect()
    print(json.dumps(status,ensure_ascii=False,indent=2))
    sys.exit(0 if status['ok'] else 1)
