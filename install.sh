#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/scripts/common.sh"
shittim_remaining=()
for shittim_arg in "${SHITTIM_ARGS[@]}"; do
    if [[ $shittim_arg == --with-power-profiles ]]; then export SHITTIM_WITH_POWER_PROFILES=1
    elif [[ $shittim_arg == --with-chrome ]]; then export SHITTIM_WITH_CHROME=1
    else shittim_remaining+=("$shittim_arg"); fi
done
SHITTIM_ARGS=("${shittim_remaining[@]}")
if [[ ${SHITTIM_ARGS[0]:-} == --help ]]; then
    printf '사용법: ./install.sh [--dry-run] [--with-power-profiles] [--with-chrome]\n일반 사용자로 실행합니다. Chrome AUR 설치는 추가 확인 후 실행합니다.\n'; exit 0
fi
no_extra_args
require_user
require_arch
require_command sudo
[[ -f $SHITTIM_ROOT/shell/shell.qml ]] || die 'shell/shell.qml이 없습니다.'
[[ ${SHELL##*/} == bash || ${SHELL##*/} == zsh ]] || die 'TTY 자동 실행은 Bash와 Zsh 로그인 셸을 지원합니다. 로그인 셸은 자동 변경하지 않습니다.'
if command -v python3 >/dev/null; then
    python3 "$SHITTIM_ROOT/scripts/config-tool.py" verify --dry-run
fi
if (( SHITTIM_DRY_RUN == 0 )); then
    require_command flock
    shittim_lock_dir=${XDG_STATE_HOME:-$HOME/.local/state}/shittim
    mkdir -p -- "$shittim_lock_dir"
    exec 9>"$shittim_lock_dir/install.lock"
    flock -n 9 || die '다른 Shittim 설치가 진행 중입니다.'
fi
shittim_stage=preflight
trap 'shittim_status=$?; printf "[Shittim:실패] 단계=%s, 종료 코드=%s. 원인을 해결한 뒤 재실행하세요.\n" "$shittim_stage" "$shittim_status" >&2; exit "$shittim_status"' ERR
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
for shittim_stage in install-packages install-chrome link-dotfiles setup-autostart setup-desktop setup-desktop-ux verify; do
    if [[ $shittim_stage == install-chrome && ${SHITTIM_WITH_CHROME:-0} != 1 ]]; then
        info 'Chrome AUR 설치는 선택 사항입니다. 원하면 ./install.sh --with-chrome 또는 bash scripts/install-chrome.sh를 실행하세요.'
        continue
    fi
    info "단계: $shittim_stage"
    bash "$SHITTIM_ROOT/scripts/$shittim_stage.sh" "${shittim_flags[@]}"
done
if (( SHITTIM_DRY_RUN )); then info '설치 계획 확인 완료. 파일·패키지·서비스는 변경하지 않았습니다.'
else
    info '설치 완료. 실행 중인 데스크톱을 강제로 종료하거나 재시작하지 않았습니다.'
    info '다음 로그인부터 tty1에서 비밀번호로 로그인하면 start-hyprland와 Shittim이 실행됩니다.'
    info '커널·그래픽 드라이버가 갱신되었다면 작업을 저장한 뒤 직접 재부팅하세요.'
fi
