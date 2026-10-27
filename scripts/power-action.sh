#!/usr/bin/env bash
# Session power actions shared by the shell, hypridle and the lid handler.
# suspend never runs before Hyprland reports the session as locked.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -eq 1 ]] || die '사용법: power-action.sh lock|suspend|screen-off|screen-on'
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || die 'Hyprland 세션에서 실행하세요.'

locked() { hyprctl -j locked 2>/dev/null | grep -Eq '"locked"[[:space:]]*:[[:space:]]*true'; }

lock_now() {
    locked && return 0
    setsid -f /usr/bin/bash "$SHITTIM_ROOT/scripts/lock-screen.sh" </dev/null >/dev/null 2>&1
    local attempt
    for attempt in $(seq 1 25); do
        locked && return 0
        sleep 0.2
    done
    return 1
}

case ${SHITTIM_ARGS[0]} in
    lock) run lock_now || die '잠금 화면을 시작하지 못했습니다.';;
    suspend)
        if (( SHITTIM_DRY_RUN )); then run systemctl suspend; exit 0; fi
        if ! lock_now; then
            notify-send -a Shittim -u critical '절전 취소' '화면이 잠기지 않아 절전하지 않았습니다.' 2>/dev/null || true
            die '화면이 잠기지 않아 절전하지 않았습니다.'
        fi
        systemctl suspend;;
    screen-off) run hyprctl dispatch 'hl.dsp.dpms({action="off"})' >/dev/null;;
    screen-on) run hyprctl dispatch 'hl.dsp.dpms({action="on"})' >/dev/null;;
    *) die '지원하지 않는 동작입니다.';;
esac
