#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
require_command python3
if (( SHITTIM_DRY_RUN )); then info '기존 창 진단 파일에서 허용된 상태 항목만 추려 전송합니다. 재현과 창 조작은 하지 않습니다.'; exit 0; fi
exec python3 "$SHITTIM_ROOT/scripts/share-window-diagnostics.py" "${SHITTIM_ARGS[@]}"
