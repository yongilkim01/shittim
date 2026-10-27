#!/usr/bin/env python3
"""Install the floating desktop policy, GTK overlay, and original HUD icon theme."""
import argparse
import configparser
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

SPEC = importlib.util.spec_from_file_location('shittim_config', Path(__file__).with_name('config-tool.py'))
files = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(files)
CSS_BEGIN, CSS_END = '/* >>> Shittim HUD >>> */', '/* <<< Shittim HUD <<< */'
TOKENS = json.loads((Path(__file__).resolve().parents[1] / 'config/design-tokens.json').read_text(encoding='utf-8'))
GTK = {'gtk-theme-name': 'Adwaita-dark', 'gtk-icon-theme-name': 'Shittim-HUD',
       'gtk-font-name': TOKENS['gtkFont']['value'], 'gtk-application-prefer-dark-theme': 'true',
       'gtk-decoration-layout': ':maximize,close', 'gtk-titlebar-double-click': 'toggle-maximize'}
SETTINGS = {
    'org.gnome.desktop.interface': {'gtk-theme': 'Adwaita-dark', 'icon-theme': 'Shittim-HUD',
        'font-name': TOKENS['gtkFont']['value'], 'monospace-font-name': TOKENS['gtkFont']['value'], 'color-scheme': 'prefer-dark'},
    'org.nemo.icon-view': {'default-zoom-level': 'smaller', 'labels-beside-icons': False},
    'org.nemo.window-state': {'start-with-menu-bar': False, 'start-with-status-bar': False,
        'start-with-toolbar': True, 'start-with-sidebar': True},
    'org.nemo.preferences': {'show-home-icon-toolbar': True, 'show-new-folder-icon-toolbar': False,
        'show-computer-icon-toolbar': False, 'show-reload-icon-toolbar': False,
        'show-up-icon-toolbar': False, 'show-edit-icon-toolbar': False,
        'show-search-icon-toolbar': True, 'show-icon-view-icon-toolbar': True, 'show-list-view-icon-toolbar': True},
}


def ini(text, values):
    parser = configparser.ConfigParser(interpolation=None, strict=False); parser.optionxform = str
    parser.read_string(text)
    if not parser.has_section('Settings'):
        parser.add_section('Settings')
    for key, value in values.items():
        parser.set('Settings', key, value)
    result = io.StringIO(); parser.write(result, space_around_delimiters=False)
    return result.getvalue()


def css(text, overlay):
    if text.count(CSS_BEGIN) != text.count(CSS_END) or text.count(CSS_BEGIN) > 1 or (CSS_BEGIN in text and text.index(CSS_BEGIN) > text.index(CSS_END)):
        raise ValueError('GTK CSS의 Shittim 표시가 손상되었습니다. 기존 파일을 확인하세요.')
    existing = re.sub(re.escape(CSS_BEGIN) + r'.*?' + re.escape(CSS_END) + r'\n?', '', text, flags=re.S).rstrip()
    return (existing + '\n\n' if existing else '') + CSS_BEGIN + '\n' + overlay.rstrip() + '\n' + CSS_END + '\n'


class UX:
    def __init__(self, config=None):
        self.files = config or files.Config()
        self.manifest = self.files.config / 'shittim/desktop-ux.json'

    def lua(self):
        text = (self.files.root / 'config/window-management.lua').read_text(encoding='utf-8')
        command = shlex.join(['/usr/bin/bash', str(self.files.root / 'scripts/windows.sh')])
        for key, operation, options in [('ALT + Tab', 'next', '{}'), ('ALT + SHIFT + Tab', 'previous', '{}'),
                ('ALT + Alt_L', 'commit', '{release=true,non_consuming=true,ignore_mods=true}'),
                ('ALT + Alt_R', 'commit', '{release=true,non_consuming=true,ignore_mods=true}'),
                ('SUPER + Tab', 'show', '{}'), ('SUPER + H', 'hide', '{}'), ('SUPER + UP', 'maximize', '{}'), ('SUPER + CTRL + Home', 'fit', '{}')]:
            text += '\nbind(' + json.dumps(key) + ', hl.dsp.exec_cmd(' + json.dumps(command + ' ' + operation, ensure_ascii=False) + '), ' + options + ')'
        # Force GTK3 client-side title bars where GTK itself supports decorations.
        snap = shlex.join(['quickshell','ipc','--path',str(self.files.root / 'shell/shell.qml'),'call','snap','event'])
        text += '\n' + (self.files.root / 'config/desktop-snap.lua').read_text(encoding='utf-8').replace('__SHITTIM_SNAP_COMMAND__',json.dumps(snap,ensure_ascii=False))
        if self.native_minimize():
            command = shlex.join(['quickshell','ipc','--path',str(self.files.root / 'shell/shell.qml'),'call','windows','nativeMinimize'])
            text += '\nhl.on("window.minimize",function(w,state)\n    if w and w.address and w.address:match("^0x%x+$") then hl.exec_cmd(' + json.dumps(command,ensure_ascii=False) + ' .. " " .. w.address .. " " .. (state and "1" or "0")) end\nend)\n'
        return text + '\nhl.env("GTK_CSD", "1")\n'

    def native_minimize(self):
        binary = shutil.which('Hyprland')
        try:
            return binary is not None and b'window.minimize\0' in Path(binary).read_bytes()
        except OSError: return False

    def gsettings(self):
        from gi.repository import Gio, GLib
        source = Gio.SettingsSchemaSource.get_default()
        changes, records = [], []
        for schema, values in SETTINGS.items():
            definition = source.lookup(schema, True) if source else None
            if definition is None:
                files.say('GSettings 스키마 없음: ' + schema + ' (설치 패키지와 세션에서 다시 확인하세요.)')
                continue
            settings = Gio.Settings.new_full(definition, None, None)
            for key, value in values.items():
                if not definition.has_key(key):
                    files.say('지원하지 않는 설정은 건너뜀: ' + schema + '/' + key); continue
                desired = GLib.Variant('b' if isinstance(value, bool) else 's', value)
                if not definition.get_key(key).range_check(desired):
                    raise ValueError('지원하지 않는 설정 값: ' + schema + '/' + key)
                records.append({'schema': schema, 'key': key, 'value': value})
                if settings.get_value(key) != desired:
                    if not settings.is_writable(key):
                        raise ValueError('수정할 수 없는 설정: ' + schema + '/' + key)
                    original = settings.get_user_value(key)
                    changes.append((settings, key, desired, {'schema': schema, 'key': key,
                                    'original': original.print_(True) if original else None}))
        if changes:
            self.files.backups.mkdir(mode=0o700, parents=True, exist_ok=True)
            backup = self.files.backups / 'desktop-gsettings.json'
            backup.write_text(json.dumps([change[3] for change in changes], ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            backup.chmod(0o600)
            files.say('GSettings 원본 백업: ' + str(backup))
            for settings, key, desired, _ in changes:
                if not settings.set_value(key, desired):
                    raise ValueError('설정 적용 실패: ' + key)
            Gio.Settings.sync()
        return records

    def setup(self):
        for version in ('3.0', '4.0'):
            directory = self.files.config / ('gtk-' + version)
            settings, style = directory / 'settings.ini', directory / 'gtk.css'
            values = dict(GTK)
            if self.native_minimize(): values['gtk-decoration-layout'] = ':minimize,maximize,close'
            if version == '4.0':
                values['gtk-theme-name'] = 'Adwaita'
            self.files.write(settings, ini(settings.read_text(encoding='utf-8') if settings.is_file() else '', values))
            self.files.write(style, css(style.read_text(encoding='utf-8') if style.is_file() else '',
                                       (self.files.root / 'assets/gtk/hud.css').read_text(encoding='utf-8')))
        icons = self.files.root / 'assets/icons/Shittim-HUD'
        for source in sorted(icons.rglob('*')):
            if source.is_file():
                self.files.link(source, self.files.data / 'icons/Shittim-HUD' / source.relative_to(icons))
        self.files.write(self.files.config / 'hypr/shittim-windows.lua', self.lua())
        if self.files.dry:
            records = []
            files.say('GSettings는 실제 설치 시 현재 값을 백업한 뒤 적용합니다.')
        else:
            subprocess.run(['luac', '-p', str(self.files.config / 'hypr/shittim-windows.lua')], check=True)
            records = self.gsettings()
        self.files.write(self.manifest, json.dumps({'settings': records,'nativeMinimize':self.native_minimize()}, ensure_ascii=False, indent=2) + '\n')
        files.say('앱 자체 최소화 이벤트: ' + ('이벤트 선언 발견, 연동 구성. 실제 앱에서 검증하세요.' if self.native_minimize() else '설치된 Hyprland에서 지원 확인 안 됨. Dock 메뉴/창 목록의 최소화를 사용하세요.'))
        files.say('Floating·GTK HUD·아이콘 구성 완료. hyprctl reload와 다음 로그인 후 앱을 다시 열어 확인하세요.')

    def verify(self):
        if self.files.dry:
            files.say('Floating·테마 점검 계획. 파일·창·설정은 변경하지 않았습니다.'); return
        errors = []
        if not (self.files.root / 'assets/wallpapers/shittim-lake.png').is_file(): errors.append('원본 배경화면 PNG가 없습니다.')
        if not self.manifest.is_file():
            raise ValueError('Desktop UX 설정이 없습니다. bash scripts/setup-desktop-ux.sh를 실행하세요.')
        path = self.files.config / 'hypr/shittim-windows.lua'
        if not path.is_file() or path.read_text(encoding='utf-8') != self.lua():
            errors.append('Floating 정책 불일치: ' + str(path))
        entry = self.files.config / 'hypr/hyprland.lua'
        if not entry.is_file() or json.dumps(str(path), ensure_ascii=False) not in entry.read_text(encoding='utf-8'):
            errors.append('Hyprland 진입 파일에 Floating 정책 연결이 없습니다. bash scripts/setup-autostart.sh를 실행하세요.')
        for version in ('3.0', '4.0'):
            directory = self.files.config / ('gtk-' + version)
            for name in ('settings.ini', 'gtk.css'):
                if not (directory / name).is_file(): errors.append('GTK 설정 누락: ' + str(directory / name))
            if (directory / 'settings.ini').is_file():
                parser = configparser.ConfigParser(interpolation=None); parser.optionxform = str
                parser.read_string((directory / 'settings.ini').read_text(encoding='utf-8'))
                expected = dict(GTK)
                if self.native_minimize(): expected['gtk-decoration-layout'] = ':minimize,maximize,close'
                if version == '4.0': expected['gtk-theme-name'] = 'Adwaita'
                for key, value in expected.items():
                    if parser.get('Settings', key, fallback=None) != value: errors.append('GTK 설정 불일치: ' + version + '/' + key)
            if (directory / 'gtk.css').is_file():
                text = (directory / 'gtk.css').read_text(encoding='utf-8')
                if text != css(text, (self.files.root / 'assets/gtk/hud.css').read_text(encoding='utf-8')):
                    errors.append('GTK HUD 스타일 불일치: ' + version)
        for source in (self.files.root / 'assets/icons/Shittim-HUD').rglob('*'):
            if source.is_file():
                target = self.files.data / 'icons/Shittim-HUD' / source.relative_to(self.files.root / 'assets/icons/Shittim-HUD')
                if not target.is_symlink() or target.resolve() != source.resolve(): errors.append('아이콘 링크 불일치: ' + str(target))
        records = json.loads(self.manifest.read_text(encoding='utf-8'))['settings']
        if records:
            from gi.repository import Gio
            source = Gio.SettingsSchemaSource.get_default()
            for record in records:
                definition = source.lookup(record['schema'], True) if source else None
                if definition is None or not definition.has_key(record['key']):
                    errors.append('GSettings 스키마 누락: ' + record['schema']); continue
                current = Gio.Settings.new_full(definition, None, None).get_value(record['key']).unpack()
                if current != record['value']: errors.append('GSettings 불일치: ' + record['schema'] + '/' + record['key'])
        if errors: raise ValueError('\n'.join(errors))
        files.say('Floating 정책·GTK 설정·HUD 아이콘 링크 검사 통과')

    def restore_settings(self, backup):
        from gi.repository import Gio, GLib
        path = Path(backup).resolve()
        if not files.inside(path, (self.files.state / 'backups').resolve()):
            raise ValueError('Shittim 백업 디렉터리 안의 desktop-gsettings.json을 지정하세요.')
        records = json.loads(path.read_text(encoding='utf-8'))
        source = Gio.SettingsSchemaSource.get_default()
        validated = []
        for record in records:
            schema, key = record['schema'], record['key']
            if schema not in SETTINGS or key not in SETTINGS[schema]:
                raise ValueError('허용하지 않는 설정 백업 항목입니다.')
            definition = source.lookup(schema, True) if source else None
            if definition is None or not definition.has_key(key):
                raise ValueError('원래 설정 스키마를 찾을 수 없습니다: ' + schema)
            original = record['original']
            try:
                variant = None if original is None else GLib.Variant.parse(definition.get_key(key).get_value_type(), original, None, None)
            except GLib.Error as error:
                raise ValueError('설정 백업 값의 형식이 유효하지 않습니다.') from error
            if variant is not None and not definition.get_key(key).range_check(variant):
                raise ValueError('설정 백업 값이 유효하지 않습니다.')
            settings = Gio.Settings.new_full(definition, None, None)
            if not settings.is_writable(key): raise ValueError('설정을 복구할 수 없습니다: ' + key)
            validated.append((settings, key, variant))
        for settings, key, variant in validated:
            if self.files.dry: continue
            if variant is None: settings.reset(key)
            elif not settings.set_value(key, variant): raise ValueError('설정 복구 실패: ' + key)
        if not self.files.dry: Gio.Settings.sync()
        files.say('GSettings 원본 복구' + (' 계획 완료' if self.files.dry else ' 완료'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['setup', 'verify', 'restore-gsettings'])
    parser.add_argument('backup', nargs='?')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    ux = UX(files.Config(dry=args.dry_run))
    if args.action == 'restore-gsettings':
        if not args.backup: parser.error('복구할 desktop-gsettings.json 경로가 필요합니다.')
        ux.restore_settings(args.backup)
    elif args.action == 'setup': ux.setup()
    else: ux.verify()


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, KeyError, TypeError, configparser.Error, subprocess.SubprocessError, ImportError) as error:
        print('[Shittim:오류] ' + str(error), file=sys.stderr); sys.exit(1)
