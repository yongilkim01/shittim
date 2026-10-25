#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
shittim_flags=()
(( SHITTIM_DRY_RUN == 0 )) || shittim_flags+=(--dry-run)
bash "$SHITTIM_ROOT/scripts/setup-desktop-ux.sh" "${shittim_flags[@]}"
shittim_titlebars="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/shittim-titlebars.lua"
if [[ -f $shittim_titlebars ]]; then
    if [[ $(< "$shittim_titlebars") == *'Managed by Shittim'* ]]; then
        python3 "$SHITTIM_ROOT/scripts/titlebar-tool.py" setup "${shittim_flags[@]}"
    else
        warn '사용자 제목 표시줄 설정은 유지했습니다. 공통 제목 표시줄은 docs/titlebars.md를 확인하세요.'
    fi
fi
if (( SHITTIM_DRY_RUN )); then
    info '디자인 적용 계획 완료. 앱·서비스·설정은 변경하지 않았습니다.'
    exit 0
fi
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload
    systemctl --user restart shittim.service
else
    info '현재 Hyprland 세션 밖입니다. 다음 로그인에서 셸 디자인을 확인하세요.'
fi
info 'Dock·GTK·설치된 Shittim 제목 표시줄 디자인을 갱신했습니다. Nemo는 작업을 저장하고 정상적으로 닫은 뒤 다시 여세요.'
info "Chrome 내부 색상 테마: $SHITTIM_ROOT/assets/chrome-theme (docs/desktop-design.md 참고). 브라우저 프로필은 자동 편집하지 않았습니다."
