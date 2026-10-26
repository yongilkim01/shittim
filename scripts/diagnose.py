#!/usr/bin/env python3
"""Collect a filtered login report; optionally commit and push only that report."""
import argparse
from datetime import datetime, timezone
import importlib.util
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
REPORT = Path('diagnostics/latest.txt')
SPEC = importlib.util.spec_from_file_location('shittim_config', ROOT / 'scripts/config-tool.py')
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)
LAUNCH = re.compile(r'Shittim|shittim|start-hyprland|start-session|Hyprland|uwsm|tty|DISPLAY|XDG_VTNR|SSH_|^\s*(if\b|then\b|else\b|elif\b|fi\b|\[|test\b|exec\b|exit\b|return\b|logout\b|source\b|\.\s)')


def scrub(text, home=None):
    home = str(home or Path.home())
    result = []
    for line in text.splitlines():
        line = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', line)
        if (CONFIG.SECRET.search(line) or
                re.search(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', line) or
                re.search(r'[A-Za-z0-9+/_=-]{40,}', line)):
            result.append('[민감 정보 의심 줄 제외]')
            continue
        line = line.replace(home, '$HOME').replace(socket.gethostname(), '<HOST>')
        line = re.sub(r'\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b', '<MAC>', line)
        line = re.sub(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', '<IP>', line)
        # Never preserve terminal escape sequences in the published report.
        result.append(''.join(c for c in line if c == '\t' or ord(c) >= 32))
    return '\n'.join(result)


def command(args, timeout=10):
    try:
        completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, timeout=timeout,
                                   text=True, errors='replace',
                                   env=dict(os.environ, LC_ALL='C', SYSTEMD_COLORS='0', SYSTEMD_PAGER='cat'))
        return '[종료 코드 {}]\n{}'.format(completed.returncode, completed.stdout[-24000:])
    except subprocess.TimeoutExpired:
        return '[시간 제한: {}초]'.format(timeout)
    except OSError as error:
        return '[실행 불가: {}]'.format(error)


def read_tail(path):
    try:
        if not path.is_file():
            return '[파일 없음]'
        with path.open('rb') as stream:
            stream.seek(0, 2)
            stream.seek(max(0, stream.tell() - 24000))
            return stream.read().decode('utf-8', errors='replace')
    except OSError as error:
        return '[읽기 실패: {}]'.format(error)


def profile_excerpt(path):
    try:
        if not path.is_file():
            return '[파일 없음]'
        if path.stat().st_size > 1024 * 1024:
            return '[크기 제한 초과]'
        lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
        selected = ['{}: {}'.format(number, line) for number, line in enumerate(lines, 1) if LAUNCH.search(line)]
        return '\n'.join(selected) or '[자동 실행 관련 줄 없음]'
    except OSError as error:
        return '[읽기 실패: {}]'.format(error)


def collect():
    home = Path.home()
    config = Path(os.environ.get('XDG_CONFIG_HOME') or home / '.config')
    sections = ['Shittim 로그인 진단', '수집 시각: ' + datetime.now(timezone.utc).isoformat(),
                '자동 실행/서비스/설정 변경 없음. 의심 줄은 제외되며 원본 로그는 복사하지 않음.']

    def add(title, value):
        sections.append('\n=== {} ===\n{}'.format(scrub(title, home), scrub(value, home)))

    add('저장소 버전', command(['git', 'log', '-1', '--format=%h %s']))
    add('세션 환경 (허용한 변수만)', '\n'.join('{}={}'.format(name, os.environ.get(name, '<unset>')) for name in (
        'SHELL', 'XDG_SESSION_ID', 'XDG_SESSION_TYPE', 'XDG_VTNR', 'XDG_CURRENT_DESKTOP',
        'XDG_SESSION_DESKTOP', 'DISPLAY', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR', 'XDG_CONFIG_HOME')))
    add('현재 터미널', command(['tty']))
    add('실행 파일', '\n'.join('{}={}'.format(name, shutil.which(name) or '<missing>') for name in (
        'bash', 'start-hyprland', 'Hyprland', 'quickshell', 'systemctl', 'dbus-update-activation-environment')))
    add('설치 버전', command(['pacman', '-Q', 'hyprland', 'quickshell', 'bash', 'systemd', 'util-linux']))
    profiles = [home / name for name in ('.bash_profile', '.bash_login', '.profile', '.bashrc', '.zprofile', '.zshrc')]
    zdot = Path(os.environ.get('ZDOTDIR') or home)
    if zdot.is_absolute() and zdot != home:
        profiles += [zdot / '.zprofile', zdot / '.zshrc']
    for path in profiles:
        add('프로필 발췌 ' + str(path), profile_excerpt(path))
        if path.is_file() and path.name in ('.bash_profile', '.bash_login', '.profile', '.bashrc'):
            add('Bash 문법 ' + path.name, command(['bash', '-n', str(path)]))
    add('자동 실행 중지 파일', '있음' if (config / 'shittim/disable-autostart').exists() else '없음')
    add('설치 상태 검증', command(['bash', str(ROOT / 'scripts/verify.sh')], timeout=30))
    add('Hyprland 설정 오류', command(['hyprctl', '-j', 'configerrors']))
    units = ['shittim.service', 'shittim-fcitx5.service', 'shittim-polkit.service']
    add('사용자 서비스 상태', command(['systemctl', '--user', 'show', *units,
        '-p', 'Id', '-p', 'ActiveState', '-p', 'SubState', '-p', 'Result', '-p', 'ExecMainStatus']))
    add('사용자 서비스 정의', command(['systemctl', '--user', 'cat', *units]))
    add('사용자 서비스 로그', command(['journalctl', '--user', '-b', '--no-pager', '-n', '100',
        '-u', units[0], '-u', units[1], '-u', units[2]]))
    add('tty1 로그인 서비스 로그', command(['journalctl', '-b', '--no-pager', '-n', '80', '-u', 'getty@tty1.service']))
    add('현재 사용자 Hyprland journal', command(['journalctl', '-b', '--no-pager', '-n', '100',
        '_UID=' + str(os.getuid()), '_COMM=Hyprland', '_COMM=start-hyprland']))
    add('수동 실행 로그', read_tail(home / 'shittim-start.log'))
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR') or '/run/user/{}'.format(os.getuid()))
    try:
        logs = sorted((runtime / 'hypr').glob('*/hyprland.log'), key=lambda p: p.stat().st_mtime, reverse=True)
        for index, path in enumerate(logs[:3], 1):
            add('Hyprland 실행 로그 {}'.format(index), read_tail(path))
    except OSError as error:
        add('Hyprland 로그 탐색', str(error))
    return '\n'.join(sections) + '\n'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()


def publish(report=REPORT, message='chore: collect laptop login diagnostics'):
    if git('branch', '--show-current') != 'main':
        raise ValueError('main 브랜치에서 실행하세요. 진단 파일은 보존했습니다.')
    if git('diff', '--cached', '--name-only'):
        raise ValueError('이미 스테이징된 변경이 있어 자동 커밋을 중단했습니다. 진단 파일은 보존했습니다.')
    remote = git('remote', 'get-url', '--push', 'origin').rstrip('/')
    if remote.endswith('.git'):
        remote = remote[:-4]
    if remote not in ('https://github.com/yongilkim01/shittim', 'git@github.com:yongilkim01/shittim', 'ssh://git@github.com/yongilkim01/shittim'):
        raise ValueError('origin이 Shittim 저장소가 아니므로 업로드하지 않았습니다.')
    git('fetch', 'origin', 'main')
    git('merge-base', '--is-ancestor', 'origin/main', 'HEAD')
    pending = git('diff', '--name-only', 'origin/main', 'HEAD')
    if pending and pending != report.as_posix():
        raise ValueError('아직 업로드하지 않은 다른 변경 커밋이 있어 중단했습니다. 진단 파일은 보존했습니다.')
    git('add', '--', report.as_posix())
    staged = git('diff', '--cached', '--name-only')
    if staged and staged != report.as_posix():
        raise ValueError('진단 파일만 스테이징되었는지 확인할 수 없어 중단했습니다.')
    if staged:
        git('commit', '-m', message, '--', report.as_posix())
    elif not pending:
        print('[Shittim] 같은 진단 파일이 이미 저장소에 있습니다. 다시 커밋하지 않았습니다.')
        return
    print('[Shittim] 진단 파일을 origin/main으로 푸시합니다.', flush=True)
    subprocess.run(['git', 'push', 'origin', 'HEAD:refs/heads/main'], cwd=ROOT, check=True)
    print('[Shittim] 진단 업로드 완료: ' + git('rev-parse', '--short', 'HEAD'))


def main():
    parser = argparse.ArgumentParser(description='TTY 로그인 진단을 수집합니다. 설정을 변경하지 않습니다.')
    parser.add_argument('--publish', action='store_true', help='진단 파일만 커밋하고 origin/main으로 푸시')
    args = parser.parse_args()
    if sys.platform != 'linux' or os.geteuid() == 0:
        raise ValueError('Arch 노트북에서 sudo 없이 실행하세요.')
    directory = ROOT / REPORT.parent
    destination = ROOT / REPORT
    if directory.is_symlink() or destination.is_symlink():
        raise ValueError('진단 경로가 심볼릭 링크이므로 쓰지 않았습니다.')
    report = collect()
    directory.mkdir(exist_ok=True)
    destination.write_text(report, encoding='utf-8', newline='\n')
    print('[Shittim] 진단 파일 저장: ' + str(destination), flush=True)
    if args.publish:
        publish()
    else:
        print('[Shittim] 업로드하려면 ./scripts/diagnose.sh --publish 를 실행하세요.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        # Git errors can include remote URLs; apply the same filtering before printing.
        detail = error.output if isinstance(error, subprocess.CalledProcessError) and error.output else str(error)
        print('[Shittim:오류] ' + scrub(detail), file=sys.stderr)
        sys.exit(1)
