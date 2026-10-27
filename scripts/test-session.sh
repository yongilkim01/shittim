#!/usr/bin/env bash
# Starts a nested compositor and private D-Bus session. Input is confined to the child.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
[[ ${#SHITTIM_ARGS[@]} -le 1 && ( ${SHITTIM_ARGS[0]:-} == "" || ${SHITTIM_ARGS[0]:-} == --native ) ]] || die '사용법: test-session.sh [--native]'
require_user
for shittim_command in Hyprland hyprctl quickshell python3 dbus-run-session wtype cc wayland-scanner pkg-config; do require_command "$shittim_command"; done
exec dbus-run-session -- python3 "$SHITTIM_ROOT/scripts/test-session.py" "${SHITTIM_ARGS[@]}"
