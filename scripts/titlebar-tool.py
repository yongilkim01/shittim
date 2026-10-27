#!/usr/bin/env python3
"""Opt-in titlebar setup; only the explicit build action downloads plugin source."""
import argparse
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location('shittim_config', Path(__file__).with_name('config-tool.py'))
files = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(files)
SPEC_PLUGIN = importlib.util.spec_from_file_location('shittim_titlebar_plugin', Path(__file__).with_name('titlebar-plugin.py'))
plugin = importlib.util.module_from_spec(SPEC_PLUGIN); SPEC_PLUGIN.loader.exec_module(plugin)
# Official hyprland-plugins/hyprpm.toml commit pins for released Hyprland 0.55/0.56.
# https://github.com/hyprwm/hyprland-plugins/blob/main/hyprpm.toml
COMPATIBLE = json.loads((Path(__file__).resolve().parents[1] / 'config/compatibility.json').read_text(encoding='utf-8'))['titlebars']


def remove_legacy_controls(config):
    target = config.data / 'fonts/shittim/ShittimHUDControls-Regular.ttf'
    previous = config.root / 'assets/fonts/ShittimHUDControls-Regular.ttf'
    if target.is_symlink() and target.resolve() == previous.resolve():
        config.backup(target)


def revision(version):
    commit = version.get('commit', '')
    if commit not in COMPATIBLE:
        raise ValueError('이 Hyprland 빌드의 hyprbars 호환성을 아직 확인하지 못했습니다. '
                         '설정은 변경하지 않았습니다. hyprctl version 출력을 보내 주세요.')
    return COMPATIBLE[commit]


def source(config):
    text = (config.root / 'config/titlebars.lua').read_text(encoding='utf-8')
    text = text.replace('__LOAD__', json.dumps(shlex.join(['/usr/bin/python3', str(config.root / 'scripts/titlebar-tool.py'), 'load']), ensure_ascii=False))
    for action in ('close', 'maximize', 'hide'):
        command = shlex.join(['/usr/bin/bash', str(config.root / 'scripts/windows.sh'), action])
        text = text.replace('__' + action.upper() + '__', json.dumps(command, ensure_ascii=False))
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['revision', 'setup', 'disable', 'verify', 'build', 'load'])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if args.action == 'revision':
        result = subprocess.run(['hyprctl', '-j', 'version'], check=True, capture_output=True, text=True, timeout=5)
        print(revision(json.loads(result.stdout))); return
    config = files.Config(dry=args.dry_run)
    destination = config.config / 'hypr/shittim-titlebars.lua'
    if args.action in ('build', 'load'):
        if config.dry:
            files.say('벡터 제목 표시줄 ' + args.action + ' 계획. 파일·세션은 변경하지 않았습니다.'); return
        version = plugin.query('version')
        if args.action == 'build': plugin.build(config, version, revision(version))
        else: plugin.load(config, version)
        return
    if args.action == 'setup':
        config.write(destination, source(config))
        remove_legacy_controls(config)
    elif args.action == 'disable':
        if destination.is_file() and 'Managed by Shittim' not in destination.read_text(encoding='utf-8'):
            raise ValueError('Shittim에서 생성하지 않은 제목 표시줄 설정은 이동하지 않습니다.')
        if not config.dry: plugin.unload_custom(config, plugin.query('plugin', 'list'))
        config.backup(destination)
    else:
        if not destination.is_file() or destination.read_text(encoding='utf-8') != source(config):
            raise ValueError('제목 표시줄 설정이 없거나 다릅니다. setup-titlebars.sh를 실행하세요.')
        result = subprocess.run(['hyprctl', '-j', 'plugin', 'list'], check=True, capture_output=True, text=True, timeout=5)
        if not any(plugin.get('name') == 'hyprbars' for plugin in json.loads(result.stdout)):
            raise ValueError('hyprbars가 로드되지 않았습니다. hyprpm reload 결과를 확인하세요.')
        plugin.verify(config, json.loads(result.stdout))
        result = subprocess.run(['hyprctl', '-j', 'configerrors'], check=True, capture_output=True, text=True, timeout=5)
        errors = [str(error).strip() for error in json.loads(result.stdout) if str(error).strip()]
        if errors:
            raise ValueError('Hyprland 설정 오류:\n' + '\n'.join(errors))
        files.say('공통 제목 표시줄 설정·hyprbars 로드 검사 통과. 실제 앱 버튼은 세션에서 확인하세요.')


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print('[Shittim:오류] ' + str(error), file=sys.stderr); sys.exit(1)
