#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
python3 "$SHITTIM_ROOT/scripts/files-config.py" --verify "${shittim_flags[@]}"
if (( SHITTIM_DRY_RUN == 0 )); then
    require_command quickshell
    require_command nemo
    if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
        require_command timeout
        timeout 15s quickshell --path "$SHITTIM_ROOT/shell/verify-files.qml"
    else
        info '실제 Quickshell UI 읽기 검사는 Hyprland의 Kitty에서 다시 실행하세요.'
    fi
    if quickshell ipc --path "$SHITTIM_ROOT/shell/files.qml" call files ping >/dev/null 2>&1; then
        quickshell ipc --path "$SHITTIM_ROOT/shell/files.qml" call files status
    else
        info '파일 관리자 창은 아직 실행되지 않았습니다. Dock의 파일 아이콘 또는 Super+E로 여세요.'
    fi
fi
info '창 이동·최소화와 Dock 복원·복사 충돌·다중 모니터 검증은 docs/files.md를 확인하세요.'
