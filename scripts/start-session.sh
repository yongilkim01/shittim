#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다. 점검은 ./install.sh --dry-run을 사용하세요.'
require_user
require_command start-hyprland
[[ -z ${SSH_CONNECTION:-} && -z ${SSH_TTY:-} ]] || die 'SSH에서는 Hyprland를 자동 실행하지 않습니다.'
[[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]] || die '이미 그래픽 세션이 실행 중입니다.'
export QT_IM_MODULE=${QT_IM_MODULE:-fcitx}
export XMODIFIERS=${XMODIFIERS:-@im=fcitx}
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
exec start-hyprland
