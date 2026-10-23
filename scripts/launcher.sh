#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_command quickshell
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: launcher.sh [toggle|show|hide|reload|status]'
shittim_action=${SHITTIM_ARGS[0]:-toggle}
case "$shittim_action" in
    toggle|show|hide|reload|status) ;;
    *) die "지원하지 않는 런처 명령: $shittim_action" ;;
esac
run quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call launcher "$shittim_action"
