#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다. 점검은 ./install.sh --dry-run을 사용하세요.'
require_user
[[ -n ${WAYLAND_DISPLAY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die 'Hyprland 그래픽 세션에서 실행해야 합니다.'
shittim_environment=()
for shittim_variable in WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE QT_IM_MODULE XMODIFIERS XDG_CONFIG_HOME XDG_DATA_HOME XDG_DATA_DIRS GTK_CSD PATH QS_ICON_THEME; do
    [[ -z ${!shittim_variable+x} ]] || shittim_environment+=("$shittim_variable")
done
dbus-update-activation-environment --systemd "${shittim_environment[@]}"
systemctl --user start shittim.service shittim-fcitx5.service shittim-polkit.service
