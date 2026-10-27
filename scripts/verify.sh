#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
load_packages
shittim_failures=0
for shittim_package in "${SHITTIM_PACKAGES[@]}"; do
    if ! pacman -Q -- "$shittim_package" >/dev/null 2>&1; then
        if (( SHITTIM_DRY_RUN )); then info "설치 예정 패키지: $shittim_package"
        else warn "누락된 패키지: $shittim_package"; shittim_failures=$((shittim_failures + 1)); fi
    fi
done
[[ -f $SHITTIM_ROOT/shell/shell.qml ]] || die 'shell/shell.qml이 없습니다.'
if command -v python3 >/dev/null; then
    if ! config_tool verify; then shittim_failures=$((shittim_failures + 1)); fi
elif (( SHITTIM_DRY_RUN )); then warn 'Python 설치 후 설정 수집본·링크 검사를 수행합니다.'
else warn 'python3이 없습니다.'; shittim_failures=$((shittim_failures + 1)); fi
if (( SHITTIM_DRY_RUN )); then
    (( shittim_failures == 0 )) || die "설치 전 점검 실패: $shittim_failures"
    info '설치 전 점검 완료. 서비스 시작·파일 변경은 수행하지 않았습니다.'; exit 0
fi
check_session_versions
python3 "$SHITTIM_ROOT/scripts/design-tokens.py" --check || { warn '생성 디자인 파일이 원본 토큰과 다릅니다.'; shittim_failures=$((shittim_failures + 1)); }
python3 -c 'import dbus_next' || { warn 'Control Center용 python-dbus-next가 없습니다.'; shittim_failures=$((shittim_failures + 1)); }
python3 "$SHITTIM_ROOT/scripts/launcher-service.py" --check || { warn 'App Launcher용 GIO·python-gobject 설치를 확인하세요.'; shittim_failures=$((shittim_failures + 1)); }
python3 "$SHITTIM_ROOT/scripts/files-config.py" --verify || { warn 'Shittim Files 등록을 확인하세요: bash scripts/setup-files.sh'; shittim_failures=$((shittim_failures + 1)); }
python3 "$SHITTIM_ROOT/scripts/desktop-tool.py" verify || { warn '기본 데스크톱 설정을 확인하세요: bash scripts/setup-desktop.sh'; shittim_failures=$((shittim_failures + 1)); }
python3 "$SHITTIM_ROOT/scripts/desktop-ux.py" verify || { warn 'Desktop UX 설정을 확인하세요: bash scripts/setup-desktop-ux.sh'; shittim_failures=$((shittim_failures + 1)); }
if ! systemctl is-active --quiet bluetooth.service; then warn 'Bluetooth 서비스가 비활성입니다. 어댑터가 없으면 정상이며 Control Center는 해당 기능을 비활성화합니다.'; fi
for shittim_service in NetworkManager.service upower.service; do
    if ! systemctl is-active --quiet "$shittim_service"; then
        warn "서비스 비활성: $shittim_service"; shittim_failures=$((shittim_failures + 1))
    fi
done
systemctl is-enabled --quiet NetworkManager.service || { warn 'NetworkManager 부팅 시 활성화 누락'; shittim_failures=$((shittim_failures + 1)); }
for shittim_service in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    if ! systemctl --user is-enabled --quiet "$shittim_service" || ! systemctl --user is-active --quiet "$shittim_service"; then
        warn "사용자 서비스/소켓 비활성: $shittim_service"; shittim_failures=$((shittim_failures + 1))
    fi
done
for shittim_unit in shittim.service shittim-fcitx5.service shittim-polkit.service shittim-idle.service; do
    systemctl --user cat "$shittim_unit" >/dev/null || shittim_failures=$((shittim_failures + 1))
done
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    python3 "$SHITTIM_ROOT/scripts/notification-owner.py" --audit
    if systemctl --user is-active --quiet shittim.service; then
        python3 "$SHITTIM_ROOT/scripts/notification-owner.py" --check || { warn '알림 서버 소유권 충돌 또는 미등록: scripts/verify-notifications.sh로 확인하세요.'; shittim_failures=$((shittim_failures + 1)); }
    fi
    if ! systemctl --user is-active --quiet shittim.service; then
        warn '현재 Shittim 서비스가 비활성입니다. 새 설정 적용 후 다음 로그인에서 실행됩니다.'
    fi
    if ! hyprctl -j configerrors | python3 -c 'import json,sys; sys.exit(any(str(error).strip() for error in json.load(sys.stdin)))'; then
        warn 'Hyprland configerrors를 직접 확인하세요. 설정 또는 의존 프로그램 점검이 필요합니다.'
        shittim_failures=$((shittim_failures + 1))
    fi
else info '현재 TTY입니다. Hyprland·Shittim·입력기는 다음 그래픽 로그인에서 확인하세요.'; fi
# Static outside Hyprland: portal/audio/camera runtime checks need the graphical session.
shittim_meeting_flags=()
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || shittim_meeting_flags+=(--static)
python3 "$SHITTIM_ROOT/scripts/meeting-check.py" "${shittim_meeting_flags[@]}" || { warn '화상회의·화면 공유 환경: bash scripts/verify-meeting.sh 출력의 [실패] 항목을 확인하세요.'; shittim_failures=$((shittim_failures + 1)); }
bash "$SHITTIM_ROOT/scripts/verify-power.sh" || { warn '잠금·전원 관리: bash scripts/verify-power.sh 출력의 주의 항목을 확인하세요.'; shittim_failures=$((shittim_failures + 1)); }
fc-match 'Hack Nerd Font Mono'
fc-match D2Coding
(( shittim_failures == 0 )) || die "검증 실패: $shittim_failures. 표시된 항목을 수정한 뒤 다시 실행하세요."
info '설치 상태 검증 완료'
