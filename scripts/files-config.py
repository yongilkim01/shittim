#!/usr/bin/env python3
"""Install the actual Shittim Files desktop entry and migrate the file-manager pin once."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

SPEC=importlib.util.spec_from_file_location('shittim_config',Path(__file__).with_name('config-tool.py'))
files=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(files)
APP='org.shittim.Files.desktop'


def desktop_quote(value):
    result=str(value).replace('\\','\\\\\\\\').replace('"','\\\\"').replace('`','\\\\`').replace('$','\\\\$').replace('%','%%')
    return '"'+result+'"'


def entry(config):
    return ('[Desktop Entry]\nType=Application\nName=Shittim Files\nName[ko]=Shittim 파일 관리자\n'
            'Comment=Shittim HUD file manager\nIcon=system-file-manager\nTerminal=false\n'
            'StartupWMClass=org.shittim.Files\nCategories=System;FileManager;\nMimeType=inode/directory;\n'
            'Exec=/usr/bin/python3 '+desktop_quote(config.root/'scripts/files-client.py')+' %U\n')


def setup(config):
    manifest=config.config/'shittim/files.json'
    config.write(config.data/'applications'/APP,entry(config))
    personal=config.config/'shittim/dock.json'
    if not manifest.exists() and personal.is_file():
        data=json.loads(personal.read_text(encoding='utf-8'))
        favorites=data.get('favorites')
        if not isinstance(favorites,list): raise ValueError('Dock 설정 형식이 올바르지 않습니다.')
        if 'nemo.desktop' in favorites:
            data['favorites']=list(dict.fromkeys(APP if value=='nemo.desktop' else value for value in favorites))
            config.write(personal,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    config.write(manifest,json.dumps({'desktopEntry':APP,'pinMigration':True})+'\n')
    files.say('Shittim Files 앱 등록 완료. Nemo는 보조 파일 관리자로 유지합니다.')


def verify(config):
    for relative in ('shell/files.qml','shell/components/files/FilesView.qml','scripts/files-client.py','scripts/files-service.py'):
        if not (config.root/relative).is_file(): raise ValueError('파일 관리자 소스 누락: '+relative)
    if config.dry:
        files.say('Shittim Files 소스 검사 통과. 앱 등록·기본 파일 연결은 설치 후 검사합니다.')
        return
    desktop=config.data/'applications'/APP
    if not desktop.is_file() or desktop.read_text(encoding='utf-8')!=entry(config):
        raise ValueError('Shittim Files 앱 등록이 없습니다. bash scripts/setup-files.sh를 실행하세요.')
    spec=importlib.util.spec_from_file_location('shittim_launcher',config.root/'scripts/launcher-service.py')
    launcher=importlib.util.module_from_spec(spec);spec.loader.exec_module(launcher)
    _,_,desktop_type=launcher.load_gio()
    app=desktop_type.new_from_filename(str(desktop))
    if app is None or app.get_is_hidden(): raise ValueError('GIO가 Shittim Files 앱 등록을 읽지 못했습니다.')
    files.say('Shittim Files 진입점·GIO 앱 등록 검사 통과')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run',action='store_true')
    parser.add_argument('--verify',action='store_true')
    args=parser.parse_args()
    try:
        config=files.Config(dry=args.dry_run)
        (verify if args.verify else setup)(config)
    except (OSError,ValueError,ImportError) as error:
        print('[Shittim:오류] '+(str(error) if isinstance(error,ValueError) else type(error).__name__),file=sys.stderr)
        return 1
    return 0


if __name__=='__main__': sys.exit(main())
