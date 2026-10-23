#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
if (( SHITTIM_DRY_RUN == 0 )); then check_session_versions; fi
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: setup-launcher.sh [--replace-fuzzel|--keep-fuzzel] [--dry-run]'
case "${SHITTIM_ARGS[0]:-}" in
    --replace-fuzzel) config_tool launcher-key --replace-fuzzel ;;
    --keep-fuzzel) config_tool launcher-key ;;
    '') ;;
    *) die "알 수 없는 인자: ${SHITTIM_ARGS[0]}" ;;
esac
config_tool autostart
if (( SHITTIM_DRY_RUN == 0 )); then systemctl --user daemon-reload; fi
info '런처 단축키 구성 완료. Hyprland에서 hyprctl reload를 실행하면 적용됩니다.'
