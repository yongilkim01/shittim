#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: dashboard.sh [toggle|show|hide|status]'
shittim_action=${SHITTIM_ARGS[0]:-toggle}
case $shittim_action in toggle|show|hide|status) ;; *) die '지원하지 않는 대시보드 명령입니다.' ;; esac
run quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call dashboard "$shittim_action"
