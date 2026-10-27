#!/usr/bin/env bash
# xdg-desktop-portal-hyprland custom_picker_binary: Shittim HUD picker, official picker as fallback.
# stdout is the portal protocol; nothing else may be printed there.
set -u
shittim_root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd -P)
shittim_allow=0
for shittim_arg in "$@"; do [[ $shittim_arg == --allow-token ]] && shittim_allow=1; done
shittim_output=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/shittim-share-picker.XXXXXX") || exec hyprland-share-picker "$@"
trap 'rm -f -- "$shittim_output"' EXIT
SHITTIM_PICKER_OUTPUT=$shittim_output SHITTIM_PICKER_ALLOW_TOKEN=$shittim_allow \
    timeout 300 quickshell --path "$shittim_root/shell/share-picker.qml" </dev/null >/dev/null 2>&1
shittim_result=$(cat -- "$shittim_output")
case $shittim_result in
    '[SELECTION]'*) printf '%s\n' "$shittim_result" ;;
    '[CANCEL]'*) exit 1 ;;
    # The HUD picker did not start or crashed: keep sharing usable with the official picker.
    *) rm -f -- "$shittim_output"; trap - EXIT; exec hyprland-share-picker "$@" ;;
esac
