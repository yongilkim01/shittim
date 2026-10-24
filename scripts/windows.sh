#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다.'
[[ ${#SHITTIM_ARGS[@]} -eq 1 ]] || die '사용법: windows.sh show|next|previous|commit|hide|fit|maximize|close'
case ${SHITTIM_ARGS[0]} in
    show|next|previous|commit)
        exec quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call windows "${SHITTIM_ARGS[0]}" ;;
    hide|fit|maximize|close) exec python3 "$SHITTIM_ROOT/scripts/window-service.py" "${SHITTIM_ARGS[0]}" ;;
    *) die '지원하지 않는 창 명령입니다.' ;;
esac
