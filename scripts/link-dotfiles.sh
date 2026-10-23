#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
if ! command -v python3 >/dev/null && (( SHITTIM_DRY_RUN )); then
    info 'Python 설치 후 설정 검사와 파일별 백업·심볼릭 링크를 수행합니다.'; exit 0
fi
config_tool link
