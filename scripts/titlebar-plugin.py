#!/usr/bin/env python3
"""Build and load the pinned hyprbars renderer with Shittim's vector controls."""
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile

UPSTREAM = 'https://github.com/hyprwm/hyprland-plugins.git'
TEXT_RENDER = 'g_pHyprRenderer->renderText(button.icon, fgcol, std::round(button.size * 0.62 * scale), false, "sans", scaledButtonSize)'
# Hyprland 0.57 hyprbars: render context, icon font from bar_text_font, icon textures redrawn per monitor scale.
TEXT_RENDER_CONTEXT = 'g_pHyprRenderer->renderText(button.icon, fgcol, std::round(button.size * 0.62 * scale), false, g_pGlobalState->config.barTextFont->value(), scaledButtonSize)'
DESCRIPTION = '{"hyprbars", "A plugin to add title bars to windows.", "Vaxry", "1.0"}'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def patch_id(config):
    sources = ('controls.hpp', 'interaction.hpp', 'design.hpp', 'hover.cpp.inc', 'input-gate.cpp.inc')
    return hashlib.sha256((''.join(digest(config.root / 'native/titlebars' / name) for name in sources) + digest(Path(__file__))).encode()).hexdigest()[:16]


def identity(config):
    return 'shittim-vector-1-' + patch_id(config)


def patch_source(directory, config):
    source = directory / 'barDeco.cpp'
    text = source.read_text(encoding='utf-8')
    modern = '#include <hyprland/src/desktop/state/WindowState.hpp>' in text
    context = 'Render::CRenderContext& ctx' in text
    text_render = TEXT_RENDER_CONTEXT if context else TEXT_RENDER
    maximized = ('Fullscreen::controller()->getFullscreenModes(m_pWindow.lock()).internal == Fullscreen::FSMODE_MAXIMIZED' if modern
                 else 'm_pWindow->m_fullscreenState.internal == FSMODE_MAXIMIZED')
    maximized = '(' + maximized + ') || m_pWindow->m_ruleApplicator->m_tagKeeper.isTagged("shittim-maximized", true)'
    original = 'const bool NEEDICON = ' if context else 'if ((!button.iconTex || button.iconTex->m_texID == 0) && !button.icon.empty()) {'
    foreground = 'auto fgcol = button.userfg ? button.fgcol : (button.bgcol.r + button.bgcol.g + button.bgcol.b < 1) ? CHyprColor(0xFFFFFFFF) : CHyprColor(0xFF000000);'
    begin = 'void CHyprBar::renderBarButtonsText('
    end = 'void CHyprBar::draw('
    need = 'if (NEEDICON) {'
    if (text.count(text_render) != 1 or text.count(original) != 1 or text.count(begin) != 1 or text.count(end) != 1 or text.count(foreground) != 1 or
            (context and text.count(need) != 1)):
        raise ValueError('확인한 hyprbars 렌더링 소스와 다릅니다. 원본 플러그인을 유지했습니다.')
    reserved = 'm_hidden || !ENABLED ? 0 : HEIGHT'
    if text.count(reserved) != 1:
        raise ValueError('확인한 hyprbars 공간 예약 소스와 다릅니다. 원본 플러그인을 유지했습니다.')
    text = text.replace(reserved, 'm_hidden || !ENABLED || !m_pWindow.lock() || !m_pWindow->m_ruleApplicator->decorate().valueOrDefault() ? 0 : HEIGHT')
    input_hook = 'bool CHyprBar::inputIsValid() {'
    if text.count(input_hook) != 1:
        raise ValueError('확인한 hyprbars 입력 판별 소스와 다릅니다. 원본 플러그인을 유지했습니다.')
    input_gate = (config.root / 'native/titlebars/input-gate.cpp.inc').read_text(encoding='utf-8')
    text = text.replace(input_hook, input_hook + '\n' + input_gate)
    setup = ('const auto controlIcon = ShittimHUD::displayIcon(button.icon, button.icon == "□" && (' + maximized + '));\n'
             '        const int controlIndex = ShittimHUD::controlIndex(controlIcon);\n'
             '        auto& iconTex = controlIndex >= 0 ? m_shittimControls[controlIndex].texture : button.iconTex;\n'
             '        ' + foreground + '\n'
             '        if (controlIndex >= 0 && m_shittimControls[controlIndex].color != fgcol) {\n'
             '            iconTex = nullptr; m_shittimControls[controlIndex].color = fgcol;\n'
             '        }\n'
             '        ' + ('const bool NEEDICON = ' if context else
             'if ((!iconTex || iconTex->m_texID == 0 || '
             '(controlIndex >= 0 && iconTex->m_size.x != std::ceil(scaledButtonSize))) && !button.icon.empty()) {'))
    expression = ('controlIndex >= 0 ? '
                  'ShittimHUD::controlTexture(controlIcon, scaledButtonSize, fgcol, '
                  '[](cairo_surface_t* surface) { return g_pHyprRenderer->createTexture(surface); }) : ' + text_render)
    start, stop = text.index(begin), text.index(end)
    body = text[start:stop].replace(foreground, '').replace('button.iconTex', 'iconTex')
    body = body.replace(original.replace('button.iconTex', 'iconTex'), setup).replace(text_render, expression)
    if context:
        # The scale stamp is shared by all windows; per-window control textures also follow their own size.
        body = body.replace(need, 'if (NEEDICON || (controlIndex >= 0 && iconTex && iconTex->m_size.x != std::ceil(scaledButtonSize))) {')
    includes = '#include "shittim-controls.hpp"\n'
    patched = includes + text[:start] + body + text[stop:]
    if modern:
        patched = patched.replace('#include "barDeco.hpp"', '#include "barDeco.hpp"\n#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>', 1)
    hooks = {
        'void CHyprBar::onMouseMove(Vector2D coords) {': '\n    updateShittimHover();',
        ('void CHyprBar::renderPass(Render::CRenderContext& ctx, PHLMONITOR pMonitor, const float& a) {' if context else
         'void CHyprBar::renderPass(PHLMONITOR pMonitor, const float& a) {'): '\n    updateShittimHover();',
        'CHyprBar::~CHyprBar() {': '\n    clearShittimHover();',
        'void CHyprBar::onConfigReloaded() {': '\n    clearShittimHover();',
    }
    for hook, addition in hooks.items():
        if patched.count(hook) != 1: raise ValueError('확인한 hyprbars 호버 갱신 구문과 다릅니다.')
        patched = patched.replace(hook, hook + addition)
    rectangle = ('g_pHyprOpenGL->renderRect(ctx, buttonBox, color, {.round = sc<int>(std::round(scaledButtonSize / 2.0)), .roundingPower = 2.F});' if context else
                 'g_pHyprOpenGL->renderRect(buttonBox, color, {.round = static_cast<int>(std::round(scaledButtonSize / 2.0)), .roundingPower = 2.F});')
    if patched.count(rectangle) != 1: raise ValueError('확인한 hyprbars 버튼 배경 구문과 다릅니다.')
    highlight = '''
        if (m_shittimHoverIndex == static_cast<int>(i))
            ShittimHUD::drawHoverFrame({buttonBox.x, buttonBox.y, buttonBox.w, buttonBox.h}, scale, a,
                [&](ShittimHUD::HoverRect r, ShittimHUD::HoverColor c) {
                    g_pHyprOpenGL->renderRect(__CTX__CBox{r.x, r.y, r.width, r.height}, CHyprColor{c.r, c.g, c.b, c.a}, {.round = 0});
                });'''.replace('__CTX__', 'ctx, ' if context else '')
    patched = patched.replace(rectangle, rectangle + highlight)
    patched = '#include "shittim-interaction.hpp"\n#include <format>\n' + patched
    events = '<hyprland/src/ipc/s2/S2.hpp>' if context else '<hyprland/src/managers/EventManager.hpp>'
    patched = patched.replace('#include "barDeco.hpp"', '#include "barDeco.hpp"\n#include ' + events, 1)
    hit_flags = 'Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING'
    under_cursor = ('Desktop::CViewHitTester{*Desktop::viewState()}.windowAt(g_pInputManager->getMouseCoordsInternal(), ' + hit_flags + ')' if modern
                    else 'g_pCompositor->vectorToWindowUnified(g_pInputManager->getMouseCoordsInternal(), ' + hit_flags + ')') + ' == m_pWindow.lock()'
    hover = (config.root / 'native/titlebars/hover.cpp.inc').read_text(encoding='utf-8').replace('__SHITTIM_MAXIMIZED__', maximized).replace('__SHITTIM_UNDER_CURSOR__', under_cursor)
    if context:
        hover = hover.replace('g_pEventManager', 'IPC::Socket2::sock()')
    source.write_text(patched + '\n' + hover, encoding='utf-8')
    header = directory / 'barDeco.hpp'
    text = header.read_text(encoding='utf-8')
    if text.count('  private:') != 1:
        raise ValueError('확인한 hyprbars 창별 텍스처 구조와 다릅니다.')
    cache = ('  private:\n'
             '    // Per-window textures keep maximized and normal windows independent.\n'
             '    struct SShittimControl { SP<Render::ITexture> texture; CHyprColor color = CHyprColor(0, 0, 0, 0); };\n'
             '    std::array<SShittimControl, 4> m_shittimControls;\n'
             '    int m_shittimHoverIndex = -1;\n'
             '    std::string m_shittimHoverPayload;\n'
             '    void updateShittimHover();\n'
             '    void clearShittimHover();\n')
    header.write_text('#include <array>\n' + text.replace('  private:', cache), encoding='utf-8')
    main = directory / 'main.cpp'
    text = main.read_text(encoding='utf-8')
    foreground = 'button.fgcol = parser.parsed();'
    if text.count(DESCRIPTION) != 1 or text.count(foreground) != 1:
        raise ValueError('확인한 hyprbars 플러그인 정보와 다릅니다.')
    replacement = '{"hyprbars", "Shittim vector controls; based on official hyprbars.", "Vaxry / Shittim", "' + identity(config) + '"}'
    main.write_text(text.replace(DESCRIPTION, replacement).replace(foreground, foreground + '\n        button.userfg = true;'), encoding='utf-8')
    shutil.copyfile(config.root / 'native/titlebars/controls.hpp', directory / 'shittim-controls.hpp')
    shutil.copyfile(config.root / 'native/titlebars/design.hpp', directory / 'design.hpp')
    shutil.copyfile(config.root / 'native/titlebars/interaction.hpp', directory / 'shittim-interaction.hpp')


def query(*args):
    result = subprocess.run(['hyprctl', '-j', *args], check=True, capture_output=True, text=True, timeout=10)
    return json.loads(result.stdout)


def command(*args):
    result = subprocess.run(list(args), check=True, capture_output=True, text=True, timeout=60)
    # hyprctl can report an IPC failure in stdout even with exit status zero.
    if args[0] == 'hyprctl' and result.stdout.strip() != 'ok':
        raise ValueError('Hyprland 요청 실패: ' + result.stdout.strip())
    return result


def manifest_path(config):
    return config.data / 'shittim/titlebars/current.json'


def read_manifest(config, version):
    path = manifest_path(config)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding='utf-8'))
    library = Path(data['library'])
    base = (config.data / 'shittim/titlebars').resolve()
    if base not in library.resolve().parents or not library.is_file() or digest(library) != data['sha256']:
        raise ValueError('설치된 제목 표시줄 바이너리가 없거나 달라졌습니다. --install-hyprbars로 다시 빌드하세요.')
    if data['commit'] != version.get('commit') or data['abiHash'] != version.get('abiHash') or data['renderer'] != identity(config):
        raise ValueError('제목 표시줄 빌드와 현재 Hyprland/렌더러가 다릅니다. --install-hyprbars로 다시 빌드하세요.')
    return data


def build(config, version, revision):
    if not re.fullmatch('[0-9a-f]{40}', version.get('commit', '')) or not version.get('abiHash'):
        raise ValueError('실행 중인 Hyprland 커밋과 ABI 정보를 확인할 수 없습니다.')
    header_root = Path('/var/cache/hyprpm') / getpass.getuser() / 'headersRoot'
    env = dict(os.environ, PKG_CONFIG_PATH=str(header_root / 'share/pkgconfig') + os.pathsep + os.environ.get('PKG_CONFIG_PATH', ''))
    flags = subprocess.run(['pkg-config', '--cflags', '--keep-system-cflags', 'hyprland'], env=env,
                           check=True, capture_output=True, text=True, timeout=10).stdout
    headers = [Path(flag[2:]) / 'hyprland/src/version.h' for flag in shlex.split(flags) if flag.startswith('-I')]
    if not any(path.is_file() and re.search(r'#define GIT_COMMIT_HASH\s+"' + re.escape(version['commit']) + '"', path.read_text()) for path in headers):
        raise ValueError('Hyprland 헤더와 실행 중인 버전이 다릅니다. hyprpm update 후 필요하면 재로그인하세요. 기존 플러그인은 유지했습니다.')
    config.state.mkdir(parents=True, exist_ok=True)
    log_path = config.state / 'titlebars-build.log'
    print('[Shittim] 벡터 제목 표시줄 빌드 로그: ' + str(log_path), flush=True)
    with log_path.open('w', encoding='utf-8') as log, tempfile.TemporaryDirectory(prefix='titlebars-', dir=config.state) as temporary:
        directory = Path(temporary)
        commands = [['git', 'init', str(directory)],
                    ['git', '-C', str(directory), 'fetch', '--depth=1', UPSTREAM, revision],
                    ['git', '-C', str(directory), 'checkout', '--detach', 'FETCH_HEAD']]
        try:
            for args in commands:
                subprocess.run(args, check=True, stdout=log, stderr=log, timeout=180)
            resolved = subprocess.run(['git', '-C', str(directory), 'rev-parse', 'HEAD'], check=True, capture_output=True, text=True, timeout=10).stdout.strip()
            if resolved != revision:
                raise ValueError('다운로드한 hyprbars 커밋이 다릅니다.')
            patch_source(directory / 'hyprbars', config)
            subprocess.run(['make', '-C', str(directory / 'hyprbars'), '-j2', 'LIBS=-lcairo'], env=env, check=True, stdout=log, stderr=log, timeout=600)
        except (OSError, subprocess.SubprocessError) as error:
            raise ValueError('제목 표시줄 빌드 실패. 기존 플러그인은 유지했습니다. 로그: ' + str(log_path)) from error
        binary = directory / 'hyprbars/hyprbars.so'
        key = hashlib.sha256((version['commit'] + version['abiHash'] + identity(config) + digest(binary)).encode()).hexdigest()[:24]
        destination = config.data / 'shittim/titlebars' / key / 'hyprbars.so'
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            shutil.copyfile(binary, destination)
            shutil.copyfile(directory / 'LICENSE', destination.parent / 'LICENSE.hyprland-plugins')
        config.write(manifest_path(config), json.dumps(dict(library=str(destination), commit=version['commit'], abiHash=version['abiHash'],
                     upstream=revision, renderer=identity(config), sha256=digest(destination)), indent=2) + '\n')


def loaded_record(config):
    return config.data / 'shittim/titlebars/loaded.json'


def unload_custom(config, plugins):
    custom = [p for p in plugins if p.get('name') == 'hyprbars' and p.get('version', '').startswith('shittim-vector-')]
    if not custom:
        return None
    record = json.loads(loaded_record(config).read_text(encoding='utf-8'))
    library = Path(record['library'])
    if (config.data / 'shittim/titlebars').resolve() not in library.resolve().parents or record['renderer'] != custom[0]['version']:
        raise ValueError('로드된 Shittim 플러그인의 경로를 확인할 수 없어 교체하지 않았습니다.')
    command('hyprctl', 'plugin', 'unload', str(library))
    return record


def load(config, version):
    import fcntl
    config.state.mkdir(parents=True, exist_ok=True)
    with (config.state / 'titlebars-load.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = read_manifest(config, version)
        if data is None:
            command('hyprpm', 'enable', 'hyprbars')
            command('hyprpm', 'reload')
            return
        plugins = query('plugin', 'list')
        if any(p.get('name') == 'hyprbars' and p.get('version') == data['renderer'] for p in plugins):
            return
        previous = unload_custom(config, plugins)
        # Only a loaded stock hyprbars needs hyprpm; after a Hyprland upgrade hyprpm can refuse every reload.
        stock = previous is None and any(p.get('name') == 'hyprbars' for p in plugins)
        attempted_load = False
        try:
            if stock:
                command('hyprpm', 'disable', 'hyprbars')
                command('hyprpm', 'reload')
                if any(p.get('name') == 'hyprbars' for p in query('plugin', 'list')):
                    raise ValueError('기존 hyprbars를 해제하지 못했습니다. 중복 플러그인은 로드하지 않았습니다.')
            attempted_load = True
            command('hyprctl', 'plugin', 'load', data['library'])
            if not any(p.get('name') == 'hyprbars' and p.get('version') == data['renderer'] for p in query('plugin', 'list')):
                raise ValueError('벡터 렌더러의 실제 로드 상태가 다릅니다.')
            config.write(loaded_record(config), json.dumps(data, indent=2) + '\n')
            command('hyprctl', 'reload')
        except (ValueError, OSError, subprocess.SubprocessError):
            if attempted_load:
                # Loading can fail before or after dlopen; unload only our known path.
                subprocess.run(['hyprctl', 'plugin', 'unload', data['library']], capture_output=True, timeout=10)
            if previous and previous.get('commit') == version.get('commit') and previous.get('abiHash') == version.get('abiHash'):
                command('hyprctl', 'plugin', 'load', previous['library'])
                config.write(loaded_record(config), json.dumps(previous, indent=2) + '\n')
            elif stock:
                command('hyprpm', 'enable', 'hyprbars')
                command('hyprpm', 'reload')
            raise


def verify(config, plugins):
    if not manifest_path(config).exists():
        print('[Shittim:주의] 기본 글꼴 렌더러입니다. 같은 크기의 벡터 기호는 setup-titlebars.sh --install-hyprbars로 설치하세요.')
        return
    data = read_manifest(config, query('version'))
    if not any(p.get('name') == 'hyprbars' and p.get('version') == data['renderer'] for p in plugins):
        raise ValueError('벡터 제목 표시줄이 빌드되었지만 로드되지 않았습니다. setup-titlebars.sh를 실행하세요.')
    else:
        print('[Shittim] 벡터 기호 렌더러·바이너리·Hyprland ABI 검사 통과.')
