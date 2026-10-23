#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
if (( SHITTIM_DRY_RUN )); then
    info 'Hyprland >= 0.55, start-hyprland, Quickshell >= 0.3.2를 실제 설치 후 확인합니다.'
    if command -v python3 >/dev/null; then config_tool autostart
    else info 'Python 설치 후 사용자 설정·로그인 프로필의 백업과 자동 실행을 구성합니다.'; fi
    exit 0
fi
check_session_versions
config_tool autostart
systemctl --user daemon-reload
fc-cache -f
info '자동 실행 구성 완료. 현재 Hyprland·Shittim·Fcitx5는 재시작하지 않았습니다.'
