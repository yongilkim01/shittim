#!/usr/bin/env bash
# Video-meeting environment check (portal, PipeWire, Chrome, devices). Read-only.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--static)
python3 "$SHITTIM_ROOT/scripts/meeting-check.py" "${shittim_flags[@]}"
info '실제 Google Meet 참가·공유 검사는 docs/meetings.md의 수동 검사 순서를 따르세요.'
