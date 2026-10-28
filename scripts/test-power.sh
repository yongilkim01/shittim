#!/usr/bin/env bash
# Guided lock/idle/suspend test on the running session; see docs/power.md. Locks the screen (and suspends with --with-suspend).
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
[[ ${#SHITTIM_ARGS[@]} -le 1 && ( ${SHITTIM_ARGS[0]:-} == "" || ${SHITTIM_ARGS[0]:-} == --with-suspend || ${SHITTIM_ARGS[0]:-} == --screen-wake ) ]] || die '사용법: test-power.sh [--with-suspend | --screen-wake]'
(( SHITTIM_DRY_RUN == 0 )) || die '실기 검사 전용입니다. 설치 점검은 bash scripts/verify-power.sh를 사용하세요.'
require_user
for shittim_command in hyprctl hyprlock quickshell systemd-inhibit pgrep python3; do require_command "$shittim_command"; done
exec python3 "$SHITTIM_ROOT/scripts/test-power.py" "${SHITTIM_ARGS[@]}"
