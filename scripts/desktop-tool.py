#!/usr/bin/env python3
"""Desktop defaults and bindings. Reuses installer backups and the GIO launcher."""
import argparse
import configparser
import importlib.util
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


files = module('shittim_config', 'config-tool.py')
APPLICATIONS = {
    'org.shittim.Files.desktop': ['inode/directory'],
    'swayimg.desktop': ['image/png', 'image/jpeg', 'image/webp', 'image/gif'],
    'org.pwmt.zathura.desktop': ['application/pdf'],
    'vlc.desktop': ['video/mp4', 'video/x-matroska', 'audio/mpeg', 'audio/flac', 'audio/x-flac'],
    'google-chrome.desktop': ['x-scheme-handler/http', 'x-scheme-handler/https', 'text/html', 'application/xhtml+xml'],
}
KEYS = {'SUPER + B': ('open-desktop.sh', 'browser'), 'SUPER + E': ('open-desktop.sh', 'files'),
        'SUPER + L': ('lock-screen.sh', ''), 'Print': ('screenshot.sh', 'all'), 'SHIFT + Print': ('screenshot.sh', 'region'),
        'SUPER + SHIFT + V': ('clipboard.sh', 'pick')}


def mime_text(original, defaults):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read_string(original)
    if not parser.has_section('Default Applications'):
        parser.add_section('Default Applications')
    for mime, app in defaults.items():
        parser.set('Default Applications', mime, app + ';')
    output = io.StringIO(); parser.write(output, space_around_delimiters=False)
    return output.getvalue()


def key_id(value):
    return '+'.join(sorted(part.strip().upper() for part in value.split('+')))


def binding_marker(key, command):
    return 'Shittim desktop: ' + key + ': ' + hashlib.sha256(command.encode()).hexdigest()[:16]


class Desktop:
    def __init__(self, config=None):
        self.files = config or files.Config()
        self.manifest = self.files.config / 'shittim/desktop.json'

    def commands(self):
        return {key: shlex.join(['/usr/bin/bash', str(self.files.root / 'scripts' / script)] + ([arg] if arg else []))
                for key, (script, arg) in KEYS.items()}

    def installed(self):
        launcher = module('shittim_launcher', 'launcher-service.py')
        gio, _, desktop = launcher.load_gio()
        # NoDisplay apps remain valid file handlers; Hidden entries do not.
        return {app.get_id() for app in gio.AppInfo.get_all() if isinstance(app, desktop)
                and app.get_id() in APPLICATIONS and not app.get_is_hidden()}

    def bindings(self, replace=False):
        commands = self.commands()
        conflicts = set()
        base = self.files.config / 'hypr/shittim-base.lua'
        if not base.is_file():
            base = self.files.root / 'dotfiles/hypr/hyprland.lua'
        text = base.read_text(encoding='utf-8') if base.is_file() else ''
        text = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('--'))
        variables = dict(re.findall(r'local\s+(\w+)\s*=\s*["\']([^"\']*)["\']', text))
        source_conflicts, source_defaults = set(), set()
        for match in re.finditer(r'hl\.bind\(([^,\n]+),\s*([^\n]+)', text):
            pieces = [piece.strip() for piece in match[1].split('..')]
            resolved = ''.join(piece[1:-1] if piece[:1] in ('"', "'") and piece[-1:] == piece[:1] else variables.get(piece, '?') for piece in pieces)
            for key, command in commands.items():
                if key_id(resolved) != key_id(key):
                    continue
                argument = re.search(r'hl\.dsp\.exec_cmd\(([^)]+)\)', match[2])
                arg = argument[1].strip() if argument else ''
                arg = arg[1:-1] if arg[:1] in ('"', "'") and arg[-1:] == arg[:1] else variables.get(arg, '')
                if key == 'SUPER + E' and arg in ('dolphin', 'nemo'):
                    source_defaults.add(key)
                elif arg != command:
                    source_conflicts.add(key)
        if re.search(r'\b(?:dofile|require)\s*\(', text):
            source_conflicts.update(commands)
            source_defaults.clear()
        if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') and not self.files.dry:
            result = subprocess.run(['hyprctl', '-j', 'binds'], capture_output=True, text=True, timeout=5, check=True)
            existing = json.loads(result.stdout)
            for key, command in commands.items():
                mask = (64 if 'SUPER' in key else 0) | (1 if 'SHIFT' in key else 0)
                symbol = key.split('+')[-1].strip().upper()
                for binding in existing:
                    if binding.get('submap', '') or binding.get('modmask') != mask or str(binding.get('key', '')).upper() != symbol:
                        continue
                    allowed = binding.get('description') == binding_marker(key, command)
                    allowed = allowed or (binding.get('dispatcher') in ('exec', 'exec_cmd') and binding.get('arg') == command)
                    allowed = allowed or (key == 'SUPER + E' and binding.get('dispatcher') in ('exec', 'exec_cmd') and binding.get('arg') in ('dolphin', 'nemo'))
                    # Lua handlers expose a function reference, not their command.
                    # The captured, simple default file-manager binding is explicitly
                    # migrated to the managed file handler; opaque/custom Lua remains a conflict.
                    allowed = allowed or (key in source_defaults and key not in source_conflicts and not binding.get('description')
                                          and str(binding.get('dispatcher', '')).startswith('function:') and str(binding.get('arg', '')).isdigit())
                    if not allowed:
                        conflicts.add(key)
        else:
            conflicts.update(source_conflicts)
        for key in sorted(conflicts):
            files.say('단축키 충돌' + (' 교체: ' if replace else ' 유지·건너뜀: ') + key)
        return {key: command for key, command in commands.items() if replace or key not in conflicts}, sorted(conflicts) if not replace else []

    def lua(self, bindings):
        lines = ['-- Managed by Shittim: desktop essentials; original Lua remains unchanged.']
        for key, command in bindings.items():
            lines.extend(['hl.unbind(' + json.dumps(key) + ')',
                          'hl.bind(' + json.dumps(key) + ', hl.dsp.exec_cmd(' + json.dumps(command, ensure_ascii=False) + '), {description=' + json.dumps(binding_marker(key, command)) + '})'])
        return '\n'.join(lines) + '\n'

    def setup(self, replace=False):
        available = set(APPLICATIONS) if self.files.dry else self.installed()
        for app_id in APPLICATIONS:
            if app_id not in available:
                files.say('설치되지 않은 기본 앱은 연결하지 않습니다: ' + app_id)
        defaults = {mime: app_id for app_id, types in APPLICATIONS.items() if app_id in available for mime in types}
        for name in ('mimeapps.list', 'hyprland-mimeapps.list'):
            path = self.files.config / name
            self.files.write(path, mime_text(path.read_text(encoding='utf-8') if path.is_file() else '', defaults))
        portal = self.files.root / 'config/hyprland-portals.conf'
        self.files.write(self.files.config / 'xdg-desktop-portal/hyprland-portals.conf', portal.read_text(encoding='utf-8'))
        self.files.link(self.files.root / 'dotfiles/hypr/shittim-lock.conf', self.files.config / 'hypr/shittim-lock.conf')
        bindings, conflicts = self.bindings(replace)
        self.files.write(self.files.config / 'hypr/shittim-desktop.lua', self.lua(bindings))
        self.files.write(self.manifest, json.dumps({'bindings': bindings, 'conflicts': conflicts, 'defaults': defaults}, ensure_ascii=False, indent=2) + '\n')
        if not self.files.dry:
            subprocess.run(['luac', '-p', str(self.files.config / 'hypr/shittim-desktop.lua')], check=True)
        files.say('클립보드 기록과 자동 잠금은 켜지 않았습니다. 포털은 다음 로그인부터 새 설정을 사용합니다.')

    def verify(self, live=False):
        if self.files.dry:
            files.say('기본 앱·포털·단축키 설치 전 점검: 실제 파일·서비스는 변경하지 않았습니다.')
            return
        if not self.manifest.is_file():
            raise ValueError('데스크톱 설정 파일이 없습니다: ' + str(self.manifest)
                             + '\nbash scripts/setup-desktop.sh 실행 후 bash scripts/verify-desktop.sh로 다시 검사하세요.'
                             + '\n설치가 중단되었다면 ./install.sh를 먼저 완료하세요.')
        data = json.loads(self.manifest.read_text(encoding='utf-8'))
        errors = []
        for name, expected in [('hypr/shittim-desktop.lua', self.lua(data['bindings'])),
                ('xdg-desktop-portal/hyprland-portals.conf', (self.files.root / 'config/hyprland-portals.conf').read_text(encoding='utf-8'))]:
            path = self.files.config / name
            if not path.is_file() or path.read_text(encoding='utf-8') != expected:
                errors.append('설정 불일치: ' + str(path))
        if not (self.files.config / 'hypr/shittim-lock.conf').is_file():
            errors.append('화면 잠금 설정 누락')
        available = self.installed()
        for app_id in APPLICATIONS:
            if app_id not in available and app_id != 'google-chrome.desktop':
                errors.append('기본 앱 누락: ' + app_id)
        if 'google-chrome.desktop' not in available:
            files.say('Chrome 미설치: bash scripts/install-chrome.sh로 AUR 설치를 선택할 수 있습니다.')
        environment = dict(os.environ, XDG_CURRENT_DESKTOP='Hyprland')
        expected_defaults = {mime: app_id for app_id, types in APPLICATIONS.items() if app_id in available for mime in types}
        for mime, app_id in expected_defaults.items():
            result = subprocess.run(['xdg-mime', 'query', 'default', mime], env=environment, capture_output=True, text=True, timeout=5)
            if result.returncode or result.stdout.strip() != app_id:
                errors.append('파일 연결 불일치: ' + mime)
        for key in data['conflicts']:
            files.say('기존 사용자 단축키 유지: ' + key + ' (필요하면 setup-desktop.sh --replace-bindings)')
        if live:
            result = subprocess.run(['hyprctl', '-j', 'binds'], capture_output=True, text=True, timeout=5, check=True)
            current = json.loads(result.stdout)
            for key, command in data['bindings'].items():
                mask = (64 if 'SUPER' in key else 0) | (1 if 'SHIFT' in key else 0)
                symbol = key.split('+')[-1].strip().upper()
                matches = [binding for binding in current if not binding.get('submap', '') and binding.get('modmask') == mask and str(binding.get('key', '')).upper() == symbol]
                if len(matches) != 1 or matches[0].get('description') != binding_marker(key, command):
                    errors.append('현재 세션 단축키 불일치: ' + key + ' (hyprctl reload 후 다시 검사)')
        if errors:
            raise ValueError('\n'.join(errors))
        files.say('기본 앱·XDG 파일 연결·포털·잠금 설정 검사 통과')

    def clipboard(self, enabled):
        if enabled:
            text = self.files.service('clipboard.sh', 'Shittim optional volatile clipboard history')
            text = text.replace('PartOf=graphical-session.target', 'PartOf=shittim.service\nAfter=shittim.service')
            # service() invokes scripts without arguments; give this service its watch action.
            text = text.replace('\nRestart=on-failure', ' watch\nRestart=on-failure')
            text += 'StandardOutput=null\nStandardError=null\n'
            text += '\n[Install]\nWantedBy=shittim.service\n'
            self.files.write(self.files.config / 'systemd/user/shittim-clipboard.service', text)
        if not self.files.dry:
            subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
            subprocess.run(['systemctl', '--user', 'enable' if enabled else 'disable', '--now', 'shittim-clipboard.service'], check=True)
        files.say('클립보드 기록: ' + ('사용자가 요청하여 활성화했습니다. 일반 텍스트도 민감할 수 있으니 필요할 때만 사용하세요.' if enabled else '비활성화했습니다. 현재 세션 기록 삭제는 clipboard.sh clear를 사용하세요.'))


def launch(which):
    app_id = {'browser': 'google-chrome.desktop', 'files': 'org.shittim.Files.desktop'}[which]
    config = files.Config()
    if which == 'files':
        # Open the actual home folder through the configured inode/directory association.
        return subprocess.run(['xdg-open', str(config.home)], check=True).returncode
    try:
        result = subprocess.run(['quickshell', 'ipc', '--path', str(config.root / 'shell/shell.qml'), 'call', 'media', 'launch', app_id],
                                capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            if result.stdout.strip() == 'requested':
                return 0
            raise ValueError('앱이 준비되지 않았거나 설치되지 않았습니다. Shittim의 앱 목록·설치를 확인하세요.')
    except (OSError, subprocess.TimeoutExpired):
        pass
    # Shittim is not running. Use the same checked GIO launch protocol once.
    launcher = module('shittim_launcher', 'launcher-service.py')
    gio, glib, desktop = launcher.load_gio()
    loop = glib.MainLoop()
    outcome = []
    def emit(message):
        if message.get('event') == 'launched':
            outcome.append(message.get('ok', False)); loop.quit()
    catalogue = launcher.Catalogue(gio, desktop, emit)
    catalogue.refresh(); catalogue.handle({'action': 'launch', 'id': app_id, 'request': 1})
    if not outcome:
        glib.timeout_add_seconds(10, lambda: (outcome.append(False), loop.quit(), False)[-1]); loop.run()
    if not outcome[0]:
        raise ValueError('앱 실행 실패. 설치와 Desktop Entry를 확인하세요.')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['setup', 'verify', 'launch', 'clipboard-enable', 'clipboard-disable'])
    parser.add_argument('application', nargs='?', choices=['browser', 'files'])
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--replace-bindings', action='store_true')
    parser.add_argument('--live', action='store_true')
    args = parser.parse_args()
    if args.action == 'launch':
        if not args.application:
            parser.error('launch에는 browser 또는 files가 필요합니다.')
        return launch(args.application)
    desktop = Desktop(files.Config(dry=args.dry_run))
    if args.action == 'setup':
        desktop.setup(args.replace_bindings)
    elif args.action.startswith('clipboard-'):
        desktop.clipboard(args.action == 'clipboard-enable')
    else:
        desktop.verify(args.live)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except FileNotFoundError as error:
        target = json.dumps(str(error.filename), ensure_ascii=False) if error.filename else '(경로 정보 없음)'
        print('[Shittim:오류] 파일 또는 실행 명령을 찾을 수 없습니다: ' + target, file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, configparser.Error, subprocess.SubprocessError) as error:
        # No command output, browser profile data, or media metadata is forwarded.
        print('[Shittim:오류] ' + (str(error) if isinstance(error, ValueError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
