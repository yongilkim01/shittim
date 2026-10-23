#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_command hyprlock
[[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] || die 'Wayland 사용자 세션에서 실행하세요.'
if (( SHITTIM_DRY_RUN )); then run hyprlock --config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/shittim-lock.conf"; exit 0; fi
exec 9>"$XDG_RUNTIME_DIR/shittim-lock.lock"
flock -n 9 || exit 0
hyprlock --config "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/shittim-lock.conf"
