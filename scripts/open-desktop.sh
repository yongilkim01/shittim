#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -eq 1 ]] || die '사용법: open-desktop.sh [browser|files]'
case ${SHITTIM_ARGS[0]} in browser|files) ;; *) die '지원하지 않는 앱입니다.' ;; esac
run python3 "$SHITTIM_ROOT/scripts/desktop-tool.py" launch "${SHITTIM_ARGS[0]}"
