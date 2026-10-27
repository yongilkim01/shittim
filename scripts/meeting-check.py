#!/usr/bin/env python3
"""Video-meeting / screen-sharing environment check for Shittim. Read-only.

Never starts a capture, grants a permission, restarts a service or edits Chrome data.
D-Bus activation of the portal (property read) is allowed, as in verify-desktop.sh.
Levels: 정상 / 장치 없음 (hardware absent, not an install failure) / 정보 / 주의 / 실패.
"""
import argparse
import configparser
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = ['pipewire', 'pipewire-pulse', 'wireplumber', 'xdg-desktop-portal',
            'xdg-desktop-portal-hyprland', 'xdg-desktop-portal-gtk', 'qt6-wayland']
USER_UNITS = ['pipewire.socket', 'pipewire-pulse.socket', 'wireplumber.service']
PORTAL_UNITS = ['xdg-desktop-portal.service', 'xdg-desktop-portal-hyprland.service']
SOURCE_TYPES = {1: '모니터', 2: '창', 4: '가상'}
# Flags that grant media permissions, fake devices or weaken browser security.
UNSAFE_FLAGS = ('--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream', '--disable-web-security',
                '--auto-accept-camera-and-microphone-capture', '--auto-select-desktop-capture-source')
CHROME_CLASSES = ('google-chrome', 'Google-chrome', 'chrome')


class Report:
    def __init__(self):
        self.failures = 0
        self.warnings = 0

    def add(self, level, message):
        if level == '실패':
            self.failures += 1
        elif level == '주의':
            self.warnings += 1
        print(f'[{level}] {message}')


def run(command, timeout=10):
    """(returncode, stdout) without a shell; missing programs return (127, '')."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except FileNotFoundError:
        return 127, ''
    except subprocess.TimeoutExpired:
        return 124, ''
    return result.returncode, result.stdout


def portal_preferences(text):
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        parser.read_string(text)
    except configparser.Error:
        return None
    return dict(parser['preferred']) if parser.has_section('preferred') else {}


def check_portal_config(report, config_home):
    expected = (ROOT / 'config/hyprland-portals.conf').read_text(encoding='utf-8')
    path = config_home / 'xdg-desktop-portal/hyprland-portals.conf'
    if not path.is_file():
        report.add('실패', f'포털 선택 파일 없음: {path} — bash scripts/setup-desktop.sh 로 설치하세요.')
        return
    preferences = portal_preferences(path.read_text(encoding='utf-8', errors='replace'))
    if preferences is None:
        report.add('실패', f'포털 선택 파일을 읽지 못했습니다: {path}')
        return
    screencast = preferences.get('org.freedesktop.impl.portal.ScreenCast', preferences.get('default', ''))
    if screencast.split(';')[0] != 'hyprland':
        report.add('실패', f'화면 공유 백엔드가 hyprland가 아닙니다({screencast or "미지정"}): {path}')
    elif path.read_text(encoding='utf-8', errors='replace') != expected:
        report.add('주의', f'포털 선택 파일이 Shittim 기본값과 다르지만 화면 공유는 hyprland입니다: {path}')
    else:
        report.add('정상', '포털 선택: 화면 공유·스크린샷=hyprland, 파일 선택=gtk')


def check_backends(report, share=Path('/usr/share/xdg-desktop-portal/portals')):
    hyprland = share / 'hyprland.portal'
    if not hyprland.is_file() or 'org.freedesktop.impl.portal.ScreenCast' not in hyprland.read_text(errors='replace'):
        report.add('실패', f'Hyprland 화면 공유 백엔드 정의가 없습니다: {hyprland}')
    else:
        report.add('정상', 'Hyprland ScreenCast 백엔드 설치됨')
    others = sorted(path.stem for path in share.glob('*.portal')
                    if path.stem not in ('hyprland', 'gtk') and 'ScreenCast' in path.read_text(errors='replace'))
    if others:
        # Explicit [preferred] wins, so these are not used; reported for troubleshooting only.
        report.add('정보', '다른 화면 공유 백엔드도 설치됨(선택 파일로 사용 안 함): ' + ', '.join(others))
    if shutil.which('hyprland-share-picker'):
        report.add('정상', '공유 대상 선택 창(hyprland-share-picker) 있음')
    else:
        report.add('실패', 'hyprland-share-picker 가 없습니다. xdg-desktop-portal-hyprland 설치를 확인하세요.')


def xdph_settings(text):
    """screencopy:* values from xdph.conf (hyprlang subset: `screencopy { key = value }`)."""
    settings, section = {}, None
    for line in text.splitlines():
        line = line.split('#', 1)[0].strip()
        if line.endswith('{'):
            section = line[:-1].strip()
        elif line == '}':
            section = None
        elif '=' in line and section == 'screencopy':
            key, value = line.split('=', 1)
            settings[key.strip()] = value.strip()
    return settings


def check_picker(report, config_home):
    path = config_home / 'hypr/xdph.conf'
    settings = xdph_settings(path.read_text(encoding='utf-8', errors='replace')) if path.is_file() else {}
    picker = settings.get('custom_picker_binary', '')
    if not picker:
        report.add('주의', f'Shittim 공유 선택 창 미사용({path}) — 기본 선택 창이 뜹니다. bash scripts/setup-desktop.sh')
    elif not os.access(picker, os.X_OK):
        report.add('실패', f'공유 선택 창 실행 파일이 없거나 실행 권한이 없습니다: {picker}')
    else:
        report.add('정상', f'공유 선택 창: {picker}')
    if settings.get('allow_token_by_default', '').lower() not in ('true', '1', 'yes', 'on'):
        report.add('주의', 'allow_token_by_default 꺼짐 — Chrome 공유 때 선택 창이 두 번 뜰 수 있습니다.')


def source_type_names(mask):
    return [name for bit, name in SOURCE_TYPES.items() if mask & bit]


def parse_busctl_uint(text):
    parts = text.split()
    if len(parts) == 2 and parts[0] == 'u' and parts[1].isdigit():
        return int(parts[1])
    return None


def check_portal_runtime(report, environment):
    desktops = environment.get('XDG_CURRENT_DESKTOP', '')
    if desktops.split(':')[0] != 'Hyprland':
        report.add('실패', f'사용자 서비스 환경 XDG_CURRENT_DESKTOP={desktops or "(없음)"}. Hyprland 로그인 후 다시 확인하세요.')
    else:
        report.add('정상', 'XDG_CURRENT_DESKTOP=Hyprland (포털 선택 파일 적용 조건)')
    code, output = run(['busctl', '--user', 'get-property', 'org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop',
                        'org.freedesktop.portal.ScreenCast', 'AvailableSourceTypes'], timeout=15)
    mask = parse_busctl_uint(output) if code == 0 else None
    if mask is None:
        report.add('실패', '포털 ScreenCast D-Bus 인터페이스에 연결하지 못했습니다. systemctl --user status xdg-desktop-portal-hyprland 로 원인을 확인하세요.')
    elif not (mask & 1 and mask & 2):
        report.add('실패', '포털이 제공하는 공유 대상: ' + (', '.join(source_type_names(mask)) or '없음') + ' (모니터·창 둘 다 필요)')
    else:
        report.add('정상', '포털 공유 대상: ' + ', '.join(source_type_names(mask)))
    for unit in PORTAL_UNITS:
        code, _ = run(['systemctl', '--user', 'is-active', '--quiet', unit])
        report.add('정상' if code == 0 else '정보', f'{unit}: ' + ('실행 중' if code == 0 else '대기 (공유 요청 때 D-Bus로 시작)'))


def check_permissions(report):
    code, output = run(['hyprctl', '-j', 'getoption', 'ecosystem:enforce_permissions'])
    try:
        enforced = code == 0 and int(json.loads(output).get('int', 0)) != 0
    except (ValueError, AttributeError):
        report.add('정보', 'Hyprland 권한 강제 설정을 읽지 못했습니다.')
        return
    if enforced:
        report.add('주의', 'Hyprland 권한 강제가 켜져 있습니다. xdg-desktop-portal-hyprland 의 screencopy 허용 규칙이 있어야 공유가 됩니다.')
    else:
        report.add('정상', 'Hyprland 권한 강제 꺼짐 (포털 화면 캡처 허용)')


def chrome_flag_findings(text):
    """[(level, message)] for the Chrome launcher flags file; comments and blank lines are ignored."""
    flags = []
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            try:
                flags.extend(shlex.split(line))
            except ValueError:
                flags.append(line)
    findings = []
    for flag in flags:
        name = flag.split('=', 1)[0]
        if name in UNSAFE_FLAGS:
            findings.append(('실패', f'권한 자동 허용/보안 해제 플래그: {flag} — 제거하세요.'))
        elif name == '--ozone-platform' and flag.endswith('=x11'):
            findings.append(('주의', f'{flag}: X11(XWayland) 강제. Wayland 창 공유·배율 표시가 달라질 수 있습니다.'))
        elif name == '--disable-features' and 'WebRTCPipeWireCapturer' in flag:
            findings.append(('실패', f'{flag}: Wayland 화면 공유(PipeWire 캡처)를 끕니다.'))
        elif 'WebRTCPipeWireCapturer' in flag:
            findings.append(('정보', f'{flag}: 현재 Chrome 기본값과 같아 필요 없는 플래그입니다.'))
    return findings


def check_chrome(report, config_home, clients_json):
    binary = shutil.which('google-chrome-stable') or shutil.which('google-chrome')
    if not binary:
        report.add('정보', 'Google Chrome 미설치 — ./install.sh --with-chrome 또는 bash scripts/install-chrome.sh')
        return
    code, output = run([binary, '--version'])
    report.add('정상', output.strip() if code == 0 and output.strip() else f'Chrome: {binary}')
    flags = config_home / 'chrome-flags.conf'
    if flags.is_file():
        findings = chrome_flag_findings(flags.read_text(encoding='utf-8', errors='replace'))
        for level, message in findings:
            report.add(level, message)
        if not findings:
            report.add('정상', f'{flags}: 회의·공유에 영향을 주는 플래그 없음')
    else:
        report.add('정상', 'chrome-flags.conf 없음 — Chrome 기본값(Wayland 자동 선택·PipeWire 화면 캡처) 사용')
    windows = chrome_windows(clients_json)
    if windows is None:
        return
    if not windows:
        report.add('정보', '실행 중인 Chrome 창 없음 — Wayland/XWayland 실행 방식은 Chrome 실행 후 확인합니다.')
    elif any(xwayland for _, xwayland in windows):
        report.add('주의', 'Chrome 이 XWayland로 실행 중입니다. chrome://flags 의 Preferred Ozone platform 을 Auto/Wayland 로 두세요.')
    else:
        report.add('정상', f'Chrome 창 {len(windows)}개 Wayland 실행')


def chrome_windows(clients_json):
    if clients_json is None:
        return None
    try:
        clients = json.loads(clients_json)
    except ValueError:
        return None
    return [(client.get('title', ''), bool(client.get('xwayland'))) for client in clients
            if isinstance(client, dict) and str(client.get('class', '')).startswith(CHROME_CLASSES)]


def audio_devices(json_text, kind):
    """Names of real sinks/sources from `pactl -f json list <kind>`; sink monitors are not microphones."""
    try:
        items = json.loads(json_text)
    except ValueError:
        return None
    names = []
    for item in items if isinstance(items, list) else []:
        if kind == 'sources' and item.get('monitor_of_sink') not in (None, '', 'n/a'):
            continue
        names.append(item.get('description') or item.get('name') or '?')
    return names


def screencast_nodes(dump_json):
    try:
        objects = json.loads(dump_json)
    except ValueError:
        return None
    names = []
    for item in objects if isinstance(objects, list) else []:
        props = ((item.get('info') or {}).get('props') or {}) if isinstance(item, dict) else {}
        if item.get('type') == 'PipeWire:Interface:Node' and str(props.get('node.name', '')).startswith('xdph-streaming-'):
            names.append(props['node.name'])
    return names


def check_audio(report):
    for unit in USER_UNITS:
        code, _ = run(['systemctl', '--user', 'is-active', '--quiet', unit])
        report.add('정상' if code == 0 else '실패', f'{unit}: ' + ('실행 중' if code == 0 else '비활성 — systemctl --user enable --now ' + unit))
    for kind, label, missing in (('sinks', '스피커/출력 장치', '출력 장치 없음'), ('sources', '마이크 장치', '마이크 장치 없음')):
        code, output = run(['pactl', '-f', 'json', 'list', kind])
        names = audio_devices(output, kind) if code == 0 else None
        if names is None:
            report.add('실패', f'{label} 목록을 읽지 못했습니다 (pipewire-pulse 연결 확인).')
        elif names:
            report.add('정상', f'{label}: ' + ', '.join(names))
        else:
            report.add('장치 없음', missing)


def check_cameras(report):
    code, output = run([sys.executable, str(ROOT / 'scripts/camera-service.py'), '--check'])
    try:
        cameras = json.loads(output)['cameras'] if code == 0 else None
    except (ValueError, KeyError):
        cameras = None
    if cameras is None:
        report.add('실패', '카메라 상태를 읽지 못했습니다.')
    elif not cameras:
        report.add('장치 없음', '카메라 장치 없음')
    for camera in cameras or []:
        if camera.get('error') == 'permission':
            report.add('주의', f'{camera["name"]} (/dev/{camera["node"]}): 접근 권한 없음 — 그래픽 세션에서 직접 로그인했는지 확인하세요.')
        else:
            users = camera.get('users') or []
            report.add('정상', f'{camera["name"]} (/dev/{camera["node"]})' + (' · 사용 중: ' + ', '.join(users) if users else ' · 사용 가능'))


def check_streams(report):
    code, output = run(['pw-dump'], timeout=15)
    names = screencast_nodes(output) if code == 0 else None
    if names is None:
        report.add('정보', 'pw-dump 로 화면 공유 스트림을 확인하지 못했습니다.')
    elif names:
        report.add('정보', f'진행 중인 화면 공유 스트림 {len(names)}개 — 공유를 끝냈다면 이 값이 0이 되어야 합니다.')
    else:
        report.add('정상', '남아 있는 화면 공유 스트림 없음')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--static', action='store_true', help='패키지·설정 파일만 검사 (TTY·설치 전)')
    options = parser.parse_args(argv)
    report = Report()
    config_home = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    print('== 패키지')
    for package in PACKAGES:
        code, _ = run(['pacman', '-Q', '--', package])
        report.add('정상' if code == 0 else '실패', package + ('' if code == 0 else ' 미설치 — ./install.sh 로 설치하세요.'))
    print('== 데스크톱 포털')
    check_portal_config(report, config_home)
    check_backends(report)
    check_picker(report, config_home)
    live = not options.static and bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))
    clients = None
    if live:
        code, environment = run(['systemctl', '--user', 'show-environment'])
        check_portal_runtime(report, dict(line.split('=', 1) for line in environment.splitlines() if '=' in line))
        check_permissions(report)
        code, clients = run(['hyprctl', '-j', 'clients'])
        clients = clients if code == 0 else None
    print('== Chrome')
    check_chrome(report, config_home, clients)
    if live:
        print('== 오디오')
        check_audio(report)
        print('== 카메라')
        check_cameras(report)
        print('== 화면 공유 스트림')
        check_streams(report)
    else:
        print('[정보] Hyprland 세션 밖입니다. 오디오·카메라·포털 실행 검사는 Hyprland 의 터미널에서 다시 실행하세요.')
    print(f'== 결과: 실패 {report.failures} · 주의 {report.warnings}')
    return 1 if report.failures else 0


if __name__ == '__main__':
    sys.exit(main())
