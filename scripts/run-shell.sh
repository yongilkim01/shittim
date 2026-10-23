#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
(( SHITTIM_DRY_RUN == 0 )) || die '실행 전용 스크립트입니다. 점검은 ./install.sh --dry-run을 사용하세요.'
require_user
[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -n ${WAYLAND_DISPLAY:-} ]] || die '로컬 Wayland 사용자 세션이 필요합니다.'
exec 8>"$XDG_RUNTIME_DIR/shittim-shell.lock"
flock -n 8 || exit 0
if python3 "$SHITTIM_ROOT/scripts/config-tool.py" shell-running; then
    info '같은 진입 파일의 Quickshell이 이미 실행 중입니다.'; exit 0
fi
exec quickshell --path "$SHITTIM_ROOT/shell/shell.qml"
