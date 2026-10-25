#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: setup-titlebars.sh [--install-hyprbars|--disable|--verify]'
shittim_mode=${SHITTIM_ARGS[0]:-}
case $shittim_mode in ''|--install-hyprbars|--disable|--verify) ;; *) die '지원하지 않는 인자입니다.' ;; esac
if (( SHITTIM_DRY_RUN )); then
    info '선택 기능: 공식 hyprbars를 현재 Hyprland와 일치하는 버전으로 설치·로드하고 공통 제목 표시줄을 구성합니다.'
    info '--install-hyprbars에서만 빌드 도구 설치와 공식 Git 저장소 다운로드·빌드를 요청합니다. AUR은 사용하지 않습니다.'
    info '일반 install.sh에는 플러그인 설치를 추가하지 않습니다. 실제 파일·패키지·세션은 변경하지 않았습니다.'
    exit 0
fi
require_command python3
require_command hyprctl
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die '실행 중인 Hyprland의 터미널에서 실행하세요.'
if [[ $shittim_mode == --verify ]]; then exec python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" verify; fi
if [[ $shittim_mode == --disable ]]; then
    require_command hyprpm
    python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" disable
    hyprpm disable hyprbars
    hyprpm reload
    hyprctl reload
    info '공통 제목 표시줄을 해제했습니다. 기존 Dock·단축키는 유지됩니다.'
    exit 0
fi
# Check the running compositor, not just the installed package version, before any changes.
shittim_revision=$(python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" revision)
if [[ $shittim_mode == --install-hyprbars ]]; then
    info '공식 hyprbars 소스를 다운로드·빌드합니다. 플러그인은 Hyprland 안에서 실행됩니다.'
    info '빌드 도구는 공식 패키지로 설치하며 pacman과 hyprpm의 확인 문구를 읽고 진행하세요.'
    require_command sudo
    sudo pacman -S --needed -- base-devel cmake cpio hyprpm
fi
require_command hyprpm
if [[ $shittim_mode == --install-hyprbars ]]; then
    shittim_plugins=$(hyprpm list)
    if [[ $shittim_plugins != *'Plugin hyprbars'* ]]; then
        hyprpm add https://github.com/hyprwm/hyprland-plugins "$shittim_revision"
    fi
fi
hyprpm enable hyprbars
hyprpm reload
python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" setup
config_tool autostart
hyprctl reload
python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" verify
info '제목 표시줄의 −는 Shittim 숨김, □는 최대화/복원, X는 정상 닫기입니다. 제목 표시줄을 드래그해 창을 이동합니다.'
info 'Nemo는 새로 실행하고 Chrome에 자체 버튼이 중복되면 시스템 제목 표시줄 사용을 켜세요. 앱을 강제 종료하지 않았습니다.'
