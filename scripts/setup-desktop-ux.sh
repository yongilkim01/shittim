#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
if ! command -v python3 >/dev/null && (( SHITTIM_DRY_RUN )); then info 'Python 설치 후 Floating·GTK HUD 설정을 백업하며 적용합니다.'; exit 0; fi
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
config_tool autostart
python3 "$SHITTIM_ROOT/scripts/desktop-ux.py" setup "${shittim_flags[@]}"
