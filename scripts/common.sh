#!/usr/bin/env bash
# Shared paths and checks; sourcing this file makes no changes.
set -Eeuo pipefail
SHITTIM_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SHITTIM_DRY_RUN=0
SHITTIM_ARGS=()
for shittim_arg in "$@"; do
    if [[ $shittim_arg == --dry-run ]]; then SHITTIM_DRY_RUN=1
    else SHITTIM_ARGS+=("$shittim_arg"); fi
done
export PYTHONDONTWRITEBYTECODE=1

info() { printf '[Shittim] %s\n' "$*"; }
warn() { printf '[Shittim:주의] %s\n' "$*" >&2; }
die() { printf '[Shittim:오류] %s\n' "$*" >&2; exit 1; }
trap 'shittim_status=$?; printf "[Shittim:오류] %s:%s (종료 코드 %s)\n" "${BASH_SOURCE[0]}" "$LINENO" "$shittim_status" >&2; exit "$shittim_status"' ERR

require_user() { [[ $EUID -ne 0 ]] || die 'sudo ./install.sh로 실행하지 마세요. 일반 사용자로 실행해야 합니다.'; }
require_arch() {
    [[ $(uname -s) == Linux && -f /etc/arch-release ]] || die 'Arch Linux에서 실행해야 합니다.'
    command -v pacman >/dev/null || die 'pacman을 찾을 수 없습니다.'
}
require_command() { command -v "$1" >/dev/null || die "필요한 명령이 없습니다: $1"; }
no_extra_args() { [[ ${#SHITTIM_ARGS[@]} -eq 0 ]] || die "알 수 없는 인자: ${SHITTIM_ARGS[*]}"; }
run() {
    if (( SHITTIM_DRY_RUN )); then printf '[계획]'; printf ' %q' "$@"; printf '\n'
    else "$@"; fi
}
config_tool() {
    require_command python3
    local flags=()
    (( SHITTIM_DRY_RUN == 0 )) || flags+=(--dry-run)
    python3 "$SHITTIM_ROOT/scripts/config-tool.py" "$@" "${flags[@]}"
}
load_packages() { mapfile -t SHITTIM_PACKAGES < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$SHITTIM_ROOT/scripts/packages.txt"); }
check_session_versions() {
    local version
    version=$(pacman -Q hyprland | awk '{print $2}')
    (( $(vercmp "$version" '0.55.0') >= 0 )) || die "Hyprland $version: Lua 자동 실행에는 0.55 이상이 필요합니다."
    version=$(pacman -Q quickshell | awk '{print $2}')
    (( $(vercmp "$version" '0.3.2') >= 0 )) || die "Quickshell $version: 0.3.2 이상이 필요합니다."
    require_command start-hyprland
}
