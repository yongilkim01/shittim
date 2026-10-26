#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
if (( SHITTIM_DRY_RUN )); then info '창 포커스·최대화·Dock 예약 영역을 읽고 사용자 상태 디렉터리에 검사 결과를 저장합니다.'; exit 0; fi
require_command python3
require_command hyprctl
exec python3 "$SHITTIM_ROOT/scripts/window-diagnostics.py" "${SHITTIM_ARGS[@]}"
