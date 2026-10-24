#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
python3 "$SHITTIM_ROOT/scripts/desktop-ux.py" verify "${shittim_flags[@]}"
if (( SHITTIM_DRY_RUN == 0 )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl -j configerrors | python3 -c 'import json,sys; errors=json.load(sys.stdin); print("Hyprland 설정 오류:",len(errors)); sys.exit(bool(errors))'
    quickshell ipc --path "$SHITTIM_ROOT/shell/shell.qml" call windows status
    gsettings get org.gnome.desktop.interface gtk-theme || warn 'GTK 기본 설정 파일을 사용합니다. GNOME 스키마는 이 환경에 없을 수 있습니다.'
    gsettings get org.gnome.desktop.interface icon-theme || warn '아이콘 테마는 GTK settings.ini에서도 설정됩니다.'
    gsettings get org.nemo.icon-view default-zoom-level || warn 'Nemo 설정 스키마를 확인하세요.'
fi
info '실제 제목 표시줄·최소화·테두리 드래그·다중 모니터는 docs/desktop-ux.md 절차로 확인하세요.'
