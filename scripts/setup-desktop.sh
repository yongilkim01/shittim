#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
require_user
require_arch
[[ ${#SHITTIM_ARGS[@]} -le 1 ]] || die '사용법: setup-desktop.sh [--replace-bindings] [--dry-run]'
shittim_flags=()
case ${SHITTIM_ARGS[0]:-} in '') ;; --replace-bindings) shittim_flags+=(--replace-bindings);; *) die '지원하지 않는 옵션입니다.';; esac
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
if ! command -v python3 >/dev/null && (( SHITTIM_DRY_RUN )); then info 'Python 설치 후 기본 앱·포털·단축키를 백업하며 구성할 계획입니다.'; exit 0; fi
python3 "$SHITTIM_ROOT/scripts/desktop-tool.py" setup "${shittim_flags[@]}"
info '기본 앱·포털·단축키 구성 완료. 현재 세션을 재시작하지 않았습니다. 적용은 hyprctl reload 및 다음 로그인에서 확인하세요.'
