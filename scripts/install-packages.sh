#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command sudo
load_packages
info '공식 저장소만 사용합니다. AUR helper 설치·실행은 하지 않습니다.'
if (( SHITTIM_DRY_RUN )); then
    run sudo pacman -Syu
    run sudo pacman -S --needed -- "${SHITTIM_PACKAGES[@]}"
    info '실제 설치 시 전체 업그레이드 후 패키지 이름과 공식 저장소 소속을 다시 검사합니다.'
    exit 0
fi
if [[ ${SHITTIM_WITH_POWER_PROFILES:-0} == 1 ]]; then
    for shittim_competitor in tlp auto-cpufreq tuned tuned-ppd; do
        if pacman -Q -- "$shittim_competitor" >/dev/null 2>&1; then
            die "다른 전원 관리 패키지($shittim_competitor)가 있습니다. --with-power-profiles 없이 설치하고 기존 서비스를 유지하세요."
        fi
    done
fi
sudo pacman -Syu
for shittim_package in "${SHITTIM_PACKAGES[@]}"; do
    # Read all metadata so pacman cannot fail with SIGPIPE under pipefail.
    shittim_repo=$(LC_ALL=C pacman -Si -- "$shittim_package" | awk '/^Repository[[:space:]]*:/ && !found {print $3; found=1}')
    [[ $shittim_repo == core || $shittim_repo == extra || $shittim_repo == multilib ]] || die "공식 패키지를 찾지 못했습니다: $shittim_package. AUR로 자동 전환하지 않습니다."
done
sudo pacman -S --needed -- "${SHITTIM_PACKAGES[@]}"
check_session_versions
require_command python3
require_command systemctl
systemctl --user show-environment >/dev/null || die '사용자 systemd에 연결할 수 없습니다. su/sudo 대신 TTY에 직접 로그인한 뒤 실행하세요.'
if ! systemctl is-active --quiet NetworkManager.service; then
    for shittim_competitor in systemd-networkd.service dhcpcd.service iwd.service connman.service; do
        if systemctl is-active --quiet "$shittim_competitor"; then
            die "다른 네트워크 관리자($shittim_competitor)가 실행 중입니다. 현재 연결을 유지했으며 NetworkManager로 자동 전환하지 않습니다."
        fi
    done
fi
sudo systemctl enable NetworkManager.service
if ! systemctl is-active --quiet NetworkManager.service; then sudo systemctl start NetworkManager.service; fi
if ! systemctl is-active --quiet upower.service; then sudo systemctl start upower.service; fi
sudo systemctl enable bluetooth.service
if [[ -d /sys/class/bluetooth ]] && ! systemctl is-active --quiet bluetooth.service; then sudo systemctl start bluetooth.service; fi
if [[ ${SHITTIM_WITH_POWER_PROFILES:-0} == 1 ]]; then sudo systemctl enable --now power-profiles-daemon.service; fi
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
info '현재 네트워크·오디오 서비스를 restart하지 않았습니다. UPower는 D-Bus로 활성화되는 서비스입니다.'
