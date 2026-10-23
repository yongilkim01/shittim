#!/usr/bin/env python3
"""File operations for the installer. Never execute captured configuration."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid
from xml.sax.saxutils import escape


MARKER = 'Managed by Shittim'
BEGIN = '# >>> Shittim TTY autostart >>>'
END = '# <<< Shittim TTY autostart <<<'
SECRET = re.compile(
    r'password|passwd|passphrase|api[_-]?key|access[_-]?key|private[_-]?key|'
    r'client[_-]?secret|secret|token|credential|authorization|\bpsk\b|'
    r'BEGIN [A-Z ]*PRIVATE KEY|(?:https?|socks\d?)://[^\s/]+:[^\s/@]+@|'
    r'\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|AKIA[A-Z0-9]{16})\b', re.I)
SUSPICIOUS_NAME = re.compile(r'(^|[./_-])(secrets?|credentials?|id_rsa|id_ed25519|auth|passwords?|tokens?)([./_-]|$)|\.(pem|key|p12|pfx|nmconnection|env|bak|log)$', re.I)
GROUPS = ('hypr', 'kitty', 'fcitx5', 'fontconfig', 'environment.d')
UNITS = ('shittim.service', 'shittim-fcitx5.service', 'shittim-polkit.service')
DEFAULT_HYPRLAND = Path('/usr/share/hypr/hyprland.lua')


def say(message):
    print('[Shittim] ' + str(message))


def inside(path, directory):
    return path == directory or directory in path.parents


def allowed(relative):
    if any(part.startswith('.') for part in relative.parts) or SUSPICIOUS_NAME.search(relative.as_posix()):
        return False
    if len(relative.parts) < 2:
        return False
    group = relative.parts[0]
    if group == 'hypr':
        return relative.suffix in ('.lua', '.conf') and relative.name != 'shittim-base.lua'
    if group == 'kitty':
        return relative.suffix == '.conf'
    if group == 'fcitx5':
        return relative.as_posix() in ('fcitx5/config', 'fcitx5/profile') or relative.suffix == '.conf'
    if group == 'fontconfig':
        return relative.suffix == '.conf' and relative.name != '99-shittim-d2coding.conf'
    return group == 'environment.d' and relative.suffix == '.conf'


def safe_text(path):
    if path.stat().st_size > 1024 * 1024:
        raise ValueError('크기 제한 초과')
    data = path.read_bytes()
    text = data.decode('utf-8')
    if any(ord(char) < 32 and char not in '\n\r\t' for char in text):
        raise ValueError('바이너리 또는 제어 문자')
    if SECRET.search(text):
        raise ValueError('비밀 정보 의심 패턴')
    if re.search(r'''["'][A-Za-z0-9+/=_-]{40,}["']''', text):
        raise ValueError('긴 인증 값 의심 문자열')
    return text


class Config:
    def __init__(self, root=None, home=None, dry=False):
        self.root = Path(root or Path(__file__).resolve().parent.parent).resolve()
        self.home = Path(home or os.environ.get('HOME') or Path.home()).absolute()
        self.config = Path(os.environ.get('XDG_CONFIG_HOME') or self.home / '.config')
        self.state = Path(os.environ.get('XDG_STATE_HOME') or self.home / '.local/state') / 'shittim'
        for path in (self.home, self.config, self.state):
            if not path.is_absolute() or any(c in str(path) for c in '\n\r\0'):
                raise ValueError('HOME/XDG 경로는 제어 문자 없는 절대 경로여야 합니다.')
        if inside(self.state.resolve(), self.root):
            raise ValueError('민감한 백업이 Git에 들어가지 않도록 XDG_STATE_HOME을 저장소 밖에 두세요.')
        if any(c in str(self.root) for c in '\n\r\0'):
            raise ValueError('저장소 경로에 제어 문자를 사용할 수 없습니다.')
        self.dry = dry
        self.backups = self.state / 'backups' / (datetime.now().strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:8])

    def backup(self, path):
        if not path.exists() and not path.is_symlink():
            return
        if inside(path, self.config):
            relative = Path('config') / path.relative_to(self.config)
        elif inside(path, self.root / 'dotfiles'):
            relative = Path('repository-dotfiles') / path.relative_to(self.root / 'dotfiles')
        elif inside(path, self.home):
            relative = Path('home') / path.relative_to(self.home)
        else:
            raise ValueError('백업 허용 경로 밖: ' + str(path))
        # Isolate each backup: an earlier directory symlink must never become
        # an ancestor through which a later backup writes into the old target.
        destination = self.backups / uuid.uuid4().hex[:8] / relative
        say(('백업 계획: ' if self.dry else '백업: ') + str(path))
        if not self.dry:
            self.backups.mkdir(parents=True, mode=0o700, exist_ok=True)
            destination.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            shutil.move(str(path), str(destination))
            say('백업 위치: ' + str(destination))

    def parents(self, path):
        if inside(path, self.config):
            boundary = self.config
        elif inside(path, self.root / 'dotfiles'):
            boundary = self.root / 'dotfiles'
        elif inside(path, self.home):
            boundary = self.home
        else:
            raise ValueError('쓰기 허용 경로 밖: ' + str(path))
        if self.dry:
            return
        boundary.mkdir(parents=True, exist_ok=True)
        current = boundary
        for part in path.parent.relative_to(boundary).parts:
            current /= part
            if current.is_symlink() and current.is_dir():
                original = current.resolve()
                self.backup(current)
                shutil.copytree(original, current, symlinks=True)
            elif current.is_symlink() or (current.exists() and not current.is_dir()):
                self.backup(current)
            current.mkdir(mode=0o700, exist_ok=True)

    def write(self, path, text):
        if path.is_file() and not path.is_symlink() and path.read_text(encoding='utf-8') == text:
            return
        say(('생성 계획: ' if self.dry else '생성: ') + str(path))
        if self.dry:
            return
        self.parents(path)
        # Create the complete replacement first; keep the original if writing fails.
        fd, name = tempfile.mkstemp(prefix='.shittim-', dir=str(path.parent))
        temporary = Path(name)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as handle:
                handle.write(text)
            self.backup(path)
            os.replace(temporary, path)
        finally:
            if temporary.exists():
                temporary.unlink()

    def link(self, source, destination):
        if not source.is_file():
            raise ValueError('링크 원본 없음: ' + str(source))
        if destination.is_symlink() and destination.resolve() == source.resolve():
            return
        say(('링크 계획: ' if self.dry else '링크: ') + str(destination))
        if self.dry:
            return
        self.parents(destination)
        self.backup(destination)
        destination.symlink_to(source.resolve())

    def inventory(self):
        result = []
        errors = []
        base = self.root / 'dotfiles'
        for path in sorted(base.rglob('*')):
            relative = path.relative_to(base)
            if path.name == '.gitkeep':
                continue
            if path.is_symlink():
                errors.append(str(relative) + ': 저장소 안의 심볼릭 링크는 수집·배포하지 않습니다.')
                continue
            if path.is_dir():
                continue
            try:
                if not allowed(relative):
                    raise ValueError('허용되지 않은 파일 형식 또는 경로')
                text = safe_text(path)
                if relative.as_posix() == 'hypr/hyprland.lua' and MARKER in text:
                    raise ValueError('생성된 진입 파일 대신 보존된 원본 Lua 설정을 수집해야 합니다.')
                result.append((relative, path))
            except (ValueError, OSError, UnicodeError) as error:
                errors.append(str(relative) + ': ' + str(error))
        if errors:
            raise ValueError('dotfiles 검사 실패 (내용은 출력하지 않음):\n' + '\n'.join(errors))
        return result

    def capture(self, update=False):
        self.inventory()
        count = 0
        skipped = 0
        candidates = []
        for group in GROUPS:
            base = self.config / group
            if not base.is_dir():
                say('없어서 건너뜀: ' + str(base))
                continue
            for directory, dirs, files in os.walk(base, followlinks=False):
                dirs[:] = sorted(name for name in dirs if not (Path(directory) / name).is_symlink() and not name.startswith('.'))
                for name in sorted(files):
                    source = Path(directory) / name
                    relative = source.relative_to(self.config)
                    if allowed(relative):
                        candidates.append((relative, source))
        legacy_font = self.home / '.fonts.conf'
        if legacy_font.is_file() and not (self.config / 'fontconfig/fonts.conf').exists():
            candidates.append((Path('fontconfig/fonts.conf'), legacy_font))
        # A managed entrypoint loads the preserved user's original configuration.
        main = self.config / 'hypr/hyprland.lua'
        if main.is_file() and MARKER in main.read_text(encoding='utf-8', errors='replace'):
            candidates = [(r, s) for r, s in candidates if r.as_posix() != 'hypr/hyprland.lua']
            original = self.config / 'hypr/shittim-base.lua'
            if original.is_file() and original.resolve() != DEFAULT_HYPRLAND:
                candidates.append((Path('hypr/hyprland.lua'), original))
        for relative, source in candidates:
            try:
                resolved = source.resolve(strict=True)
                if not (inside(resolved, self.config.resolve()) or inside(resolved, (self.root / 'dotfiles').resolve()) or source == legacy_font):
                    raise ValueError('설정 디렉터리 밖을 가리키는 링크')
                text = safe_text(source)
                if MARKER in text:
                    continue
            except (ValueError, OSError, UnicodeError) as error:
                say('제외: ' + str(relative) + ' (' + str(error) + ')')
                skipped += 1
                continue
            target = self.root / 'dotfiles' / relative
            if target.is_file() and target.read_text(encoding='utf-8') != text and not update:
                say('기존 수집본과 달라 건너뜀: ' + str(relative) + ' (--update로 백업 후 갱신)')
                skipped += 1
                continue
            self.write(target, text)
            count += 1
        say('수집 대상 {}개, 제외/보류 {}개. 원본은 수정하지 않았습니다.'.format(count, skipped))
        say('Git에 추가하기 전 diff를 직접 검토하고 ./scripts/check-secrets.sh를 실행하세요.')

    def destination(self, relative):
        if relative.as_posix() == 'hypr/hyprland.lua':
            return self.config / 'hypr/shittim-base.lua'
        return self.config / relative

    def link_dotfiles(self):
        files = self.inventory()
        for relative, source in files:
            self.link(source, self.destination(relative))
        if not files:
            say('아직 수집된 dotfiles가 없습니다. 기존 설정을 보존하며 새 환경에는 공식 기본 설정을 사용합니다.')

    def profile(self):
        shell = Path(os.environ.get('SHELL', '/bin/bash')).name
        if shell == 'bash':
            path = next((self.home / name for name in ('.bash_profile', '.bash_login', '.profile') if (self.home / name).exists()), self.home / '.bash_profile')
        elif shell == 'zsh':
            path = Path(os.environ.get('ZDOTDIR') or self.home) / '.zprofile'
            if not inside(path.absolute(), self.home):
                raise ValueError('ZDOTDIR은 홈 디렉터리 안에 있어야 합니다.')
        else:
            raise ValueError('TTY 자동 실행은 Bash와 Zsh만 지원합니다. 로그인 셸은 자동 변경하지 않습니다.')
        text = path.read_text(encoding='utf-8') if path.is_file() else ''
        if text.count(BEGIN) != text.count(END) or text.count(BEGIN) > 1:
            raise ValueError('로그인 프로필의 Shittim 관리 블록이 손상되었습니다: ' + str(path))
        clean = re.sub(re.escape(BEGIN) + '.*?' + re.escape(END) + r'\n?', '', text, flags=re.S)
        commands = '\n'.join(line for line in clean.splitlines() if not line.lstrip().startswith('#'))
        launch_lines = [line.strip() for line in commands.splitlines() if re.search(r'\b(start-hyprland|Hyprland|uwsm)\b', line)]
        if launch_lines:
            if all(re.fullmatch(r'(?:exec\s+)?(?:/usr/bin/)?start-hyprland\s*;?', line) for line in launch_lines):
                say('기존 start-hyprland 로그인 명령을 유지합니다: ' + str(path))
                return path, text
            raise ValueError('기존 로그인 프로필에 별도 그래픽 세션 명령이 있습니다. 자동 수정하지 않습니다: ' + str(path))
        launch = shlex.quote(str(self.root / 'scripts/start-session.sh'))
        disabled = shlex.quote(str(self.config / 'shittim/disable-autostart'))
        block = ('\n' + BEGIN + '\n'
                 'if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ] &&\n'
                 '   [ -z "${SSH_CONNECTION:-}" ] && [ -z "${SSH_TTY:-}" ] &&\n'
                 '   [ "$(tty 2>/dev/null)" = /dev/tty1 ] &&\n'
                 '   [ ! -e ' + disabled + ' ]; then\n'
                 '    exec /usr/bin/bash ' + launch + '\nfi\n' + END + '\n')
        return path, clean.rstrip('\n') + block

    def lua(self):
        base = self.config / 'hypr/shittim-base.lua'
        start = '/usr/bin/bash ' + shlex.quote(str(self.root / 'scripts/session-services.sh'))
        stop = 'systemctl --user stop ' + ' '.join(UNITS)
        return ('-- ' + MARKER + '; original settings are loaded without editing.\n'
                'assert(hl and hl.on and hl.exec_cmd, "Shittim requires Hyprland >= 0.55 Lua API")\n'
                'dofile(' + json.dumps(str(base), ensure_ascii=False) + ')\n'
                'hl.env("QT_IM_MODULE", os.getenv("QT_IM_MODULE") or "fcitx")\n'
                'hl.env("XMODIFIERS", os.getenv("XMODIFIERS") or "@im=fcitx")\n'
                'hl.on("hyprland.start", function()\n    hl.exec_cmd(' + json.dumps(start, ensure_ascii=False) + ')\nend)\n'
                'hl.on("hyprland.shutdown", function()\n    hl.exec_cmd(' + json.dumps(stop) + ')\nend)\n')

    def service(self, script, description):
        argument = str(self.root / 'scripts' / script).replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%').replace('$', '$$')
        return ('# ' + MARKER + '\n[Unit]\nDescription=' + description + '\n'
                'PartOf=graphical-session.target\nStartLimitIntervalSec=30\nStartLimitBurst=3\n\n'
                '[Service]\nType=simple\nExecStart=/usr/bin/bash "' + argument + '"\n'
                'Restart=on-failure\nRestartSec=2\n')

    def generated(self):
        return {
            self.config / 'hypr/hyprland.lua': self.lua(),
            self.config / 'systemd/user/shittim.service': self.service('run-shell.sh', 'Shittim desktop shell'),
            self.config / 'systemd/user/shittim-fcitx5.service': self.service('run-fcitx5.sh', 'Shittim input method'),
            self.config / 'systemd/user/shittim-polkit.service': self.service('run-polkit.sh', 'Shittim authentication agent'),
        }

    def autostart(self):
        self.inventory()
        profile, profile_text = self.profile()
        main = self.config / 'hypr/hyprland.lua'
        base = self.config / 'hypr/shittim-base.lua'
        captured = self.root / 'dotfiles/hypr/hyprland.lua'
        if captured.is_file():
            self.link(captured, base)
        elif not base.is_file():
            if main.is_file() and MARKER not in main.read_text(encoding='utf-8'):
                self.write(base, main.read_text(encoding='utf-8'))
            elif (self.config / 'hypr/hyprland.conf').exists():
                raise ValueError('기존 hyprland.conf를 자동 변환하거나 무시하지 않습니다. Lua 설정을 먼저 확인하세요.')
            elif DEFAULT_HYPRLAND.is_file():
                self.link(DEFAULT_HYPRLAND, base)
                say('설치된 Hyprland 패키지의 공식 기본 Lua 설정을 사용합니다.')
            elif self.dry:
                say('Hyprland 설치 후 /usr/share/hypr/hyprland.lua를 기본 설정으로 연결할 계획입니다.')
            else:
                raise ValueError('수집된 설정, 기존 Lua 설정, 공식 기본 Lua 설정을 모두 찾지 못했습니다.')
        if base.is_file() and MARKER in base.read_text(encoding='utf-8'):
            raise ValueError('기본 설정이 Shittim 진입 파일을 다시 불러옵니다. 복구 후 재실행하세요.')
        if not self.dry:
            subprocess.run(['luac', '-p', str(base)], check=True)
        for path, text in self.generated().items():
            self.write(path, text)
        self.write(profile, profile_text)
        if not self.dry:
            subprocess.run(['luac', '-p', str(main)], check=True)
        self.font_alias()

    def font_alias(self):
        if self.dry:
            say('Fontconfig에서 설치된 D2Coding/D2Koding Nerd Font를 탐색해 D2Coding 별칭을 구성할 계획입니다.')
            return
        families = subprocess.check_output(['fc-list', '--format=%{family}\n'], text=True).splitlines()
        candidates = sorted({name.strip() for line in families for name in line.split(',') if re.search(r'D2[CkK]oding', name, re.I) and 'Nerd' in name})
        if not candidates:
            raise ValueError('D2Coding Nerd Font를 찾지 못했습니다. ttf-d2coding-nerd 설치를 확인하세요.')
        family = next((name for name in candidates if 'Mono' in name), candidates[0])
        text = '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">\n<!-- ' + MARKER + ' -->\n<fontconfig><alias><family>D2Coding</family><prefer><family>' + escape(family) + '</family></prefer></alias></fontconfig>\n'
        self.write(self.config / 'fontconfig/conf.d/99-shittim-d2coding.conf', text)

    def verify(self, preflight=False):
        files = self.inventory()
        if not (self.root / 'shell/shell.qml').is_file():
            raise ValueError('Quickshell 진입 파일이 없습니다.')
        profile, text = self.profile()
        if preflight:
            say('설정 수집본 검사 및 로그인 셸 점검 완료. 설치할 파일 수: ' + str(len(files)))
            return
        errors = []
        for relative, source in files:
            target = self.destination(relative)
            if not target.is_symlink() or not target.exists() or target.resolve() != source.resolve():
                errors.append('설정 링크 불일치/누락: ' + str(target))
        for path, expected in self.generated().items():
            if not path.is_file() or path.read_text(encoding='utf-8') != expected:
                errors.append('자동 실행 파일 불일치/누락: ' + str(path))
        if not profile.is_file() or profile.read_text(encoding='utf-8') != text:
            errors.append('로그인 자동 실행 설정 누락: ' + str(profile))
        base = self.config / 'hypr/shittim-base.lua'
        if not base.is_file():
            errors.append('Hyprland 원본 설정 누락/잘못된 링크: ' + str(base))
        alias = self.config / 'fontconfig/conf.d/99-shittim-d2coding.conf'
        if not alias.is_file() or MARKER not in alias.read_text(encoding='utf-8'):
            errors.append('D2Coding 폰트 별칭 누락')
        for group in GROUPS:
            directory = self.config / group
            if directory.is_dir():
                for path in directory.rglob('*'):
                    if path.is_symlink() and not path.exists():
                        errors.append('끊어진 설정 링크: ' + str(path))
        if errors:
            raise ValueError('\n'.join(errors))
        say('설정 링크, Hyprland·Shittim 자동 실행, 진입 파일 검사 통과')

    def shell_running(self):
        entry = (self.root / 'shell/shell.qml').resolve()
        for process in Path('/proc').glob('[0-9]*'):
            try:
                if process.stat().st_uid != os.getuid():
                    continue
                args = (process / 'cmdline').read_bytes().decode().split('\0')
                if Path(args[0]).name not in ('quickshell', 'qs'):
                    continue
                for index, arg in enumerate(args[1:], 1):
                    path = args[index + 1] if arg in ('-p', '--path') else arg.split('=', 1)[1] if arg.startswith('--path=') else None
                    if path:
                        candidate = Path(path)
                        if not candidate.is_absolute():
                            candidate = (process / 'cwd').resolve() / candidate
                        if candidate.is_dir():
                            candidate /= 'shell.qml'
                        if candidate.resolve() == entry:
                            return True
            except (OSError, UnicodeError, IndexError):
                continue
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['capture', 'link', 'autostart', 'verify', 'scan', 'shell-running'])
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true')
    args = parser.parse_args()
    config = Config(dry=args.dry_run)
    if args.action == 'shell-running':
        return 0 if config.shell_running() else 1
    if args.action == 'capture':
        config.capture(args.update)
    elif args.action == 'link':
        config.link_dotfiles()
    elif args.action == 'autostart':
        config.autostart()
    elif args.action == 'scan':
        say('수집본 검사 통과: {}개 파일'.format(len(config.inventory())))
    else:
        config.verify(preflight=args.dry_run)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, UnicodeError, subprocess.CalledProcessError) as error:
        print('[Shittim:오류] ' + str(error), file=sys.stderr)
        sys.exit(1)
