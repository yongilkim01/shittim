#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -eq 1 ]] || die '사용법: notifications.sh status|dndOn|dndOff|clear|hide'
case ${SHITTIM_ARGS[0]} in status|dndOn|dndOff|clear|hide) ;; *) die '지원하지 않는 알림 명령입니다.' ;; esac
run quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call notifications "${SHITTIM_ARGS[0]}"
