#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && (( SHITTIM_DRY_RUN == 0 )); then shittim_flags+=(--live); fi
python3 "$SHITTIM_ROOT/scripts/desktop-tool.py" verify "${shittim_flags[@]}"
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
if (( SHITTIM_DRY_RUN )); then info '설치 전 코드 점검 완료. 설정·서비스·클립보드는 변경하지 않았습니다.'; exit 0; fi
for shittim_command in nemo swayimg zathura vlc hyprlock grim slurp wl-copy wl-paste playerctl; do require_command "$shittim_command"; done
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl -j configerrors | python3 -c 'import json,sys; sys.exit(any(str(error).strip() for error in json.load(sys.stdin)))'
    systemctl --user show-environment | sed -n '/^XDG_CURRENT_DESKTOP=/p;/^WAYLAND_DISPLAY=/p'
    # D-Bus activation is allowed; do not restart an in-progress screen-sharing session.
    timeout 10 gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop >/dev/null
    systemctl --user --no-pager --plain status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service || warn '포털 백엔드가 아직 비활성일 수 있습니다. 실제 파일 선택·화면 공유와 다음 로그인을 확인하세요.'
    python3 "$SHITTIM_ROOT/scripts/diagnose-media.py"
else info '현재 TTY입니다. Hyprland의 Kitty에서 다시 실행해 포털·MPRIS를 확인하세요.'; fi
info '검사 완료. 실제 파일 열기·재생·캡처·잠금·화면 공유는 README의 수동 검사를 수행하세요.'
