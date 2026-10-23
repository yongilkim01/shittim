#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
[[ ${#SHITTIM_ARGS[@]} -eq 1 ]] || die '사용법: clipboard.sh [enable|disable|watch|store|pick|clear]'
case ${SHITTIM_ARGS[0]} in
    enable|disable) run python3 "$SHITTIM_ROOT/scripts/desktop-tool.py" "clipboard-${SHITTIM_ARGS[0]}"; exit;;
    watch|store|pick|clear) ;;
    *) die '지원하지 않는 클립보드 명령입니다.';;
esac
[[ -n ${XDG_RUNTIME_DIR:-} && -d $XDG_RUNTIME_DIR && -O $XDG_RUNTIME_DIR ]] || die '사용자 세션의 XDG_RUNTIME_DIR가 필요합니다.'
umask 077
shittim_clip_dir=$XDG_RUNTIME_DIR/shittim-clipboard
if (( SHITTIM_DRY_RUN )); then info '클립보드 명령 계획만 확인했습니다. 데이터를 읽거나 기록하지 않았습니다.'; exit 0; fi
mkdir -p -m 700 -- "$shittim_clip_dir"
[[ ! -L $shittim_clip_dir && -O $shittim_clip_dir ]] || die '안전한 클립보드 임시 디렉터리가 아닙니다.'
chmod 700 -- "$shittim_clip_dir"
export CLIPHIST_DB_PATH=$shittim_clip_dir/history.db
export CLIPHIST_MAX_ITEMS=50 CLIPHIST_MAX_STORE_SIZE=100KiB
export CLIPHIST_CONFIG_PATH=/dev/null
require_command cliphist
case ${SHITTIM_ARGS[0]} in
    watch)
        exec 9>"$shittim_clip_dir/watch.lock"
        flock -n 9 || exit 0
        exec wl-paste --type text --watch /usr/bin/bash "$SHITTIM_ROOT/scripts/clipboard.sh" store
        ;;
    store)
        case ${CLIPBOARD_STATE:-data} in sensitive|nil|clear) exit 0;; esac
        exec cliphist store
        ;;
    pick)
        require_command fuzzel
        shittim_choice=$(cliphist list | fuzzel --dmenu --prompt 'CLIPBOARD > ' --background=020f15ff --text-color=d5f8ffff --selection-color=08232eff --selection-text-color=00d9f5ff --border-color=00d9f5ff --border-width=1 --border-radius=0) || exit 0
        [[ -n $shittim_choice ]] || exit 0
        printf '%s\n' "$shittim_choice" | cliphist decode | wl-copy
        ;;
    clear) cliphist wipe;;
esac
