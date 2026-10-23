#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다. 점검은 ./install.sh --dry-run을 사용하세요.'
require_user
if pgrep -u "$(id -u)" -x fcitx5 >/dev/null; then exit 0; fi
exec fcitx5
