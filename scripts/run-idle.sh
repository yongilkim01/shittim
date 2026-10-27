#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다. 점검은 bash scripts/verify-power.sh를 사용하세요.'
require_user
require_command hypridle
require_command systemd-inhibit
exec python3 "$SHITTIM_ROOT/scripts/idle-service.py"
