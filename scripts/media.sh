#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: media.sh [toggle|show|hide|status|reload]'
shittim_action=${SHITTIM_ARGS[0]:-toggle}
case $shittim_action in toggle|show|hide|status|reload) ;; *) die '지원하지 않는 미디어 명령입니다.' ;; esac
run quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call media "$shittim_action"
