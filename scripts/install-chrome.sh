#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
if pacman -Q google-chrome >/dev/null 2>&1; then info 'Google Chrome이 이미 설치되어 있습니다.'; exit 0; fi
if (( SHITTIM_DRY_RUN )); then
    info '선택한 Chrome은 공식 패키지가 아닌 AUR google-chrome입니다. 실제 실행 시 별도 동의와 빌드 파일 검토 후 설치합니다.'
    exit 0
fi
[[ -t 0 ]] || die 'AUR 설치는 대화형 터미널에서 직접 확인해야 합니다. 자동 승인하지 않습니다.'
info 'google-chrome은 AUR의 비공식 패키지입니다. 빌드 파일은 사용자 권한으로 코드를 실행합니다.'
if command -v yay >/dev/null; then
    read -r -p '기존 yay를 사용하고 패키지·빌드 파일을 검토하며 설치할까요? [y/N] ' shittim_answer
    [[ $shittim_answer == y || $shittim_answer == Y ]] || { info 'Chrome 설치를 건너뜁니다.'; exit 0; }
    yay -S --needed -- google-chrome
else
    require_command git
    shittim_cache=${XDG_CACHE_HOME:-$HOME/.cache}/shittim/aur
    mkdir -p -- "$shittim_cache"
    shittim_build=$(mktemp -d "$shittim_cache/google-chrome.XXXXXXXX")
    git clone -- https://aur.archlinux.org/google-chrome.git "$shittim_build/source"
    info "빌드 파일 위치: $shittim_build/source"
    git -C "$shittim_build/source" log -1 --format='%H'
    # Show tracked text with control bytes escaped. Do not source PKGBUILD to inspect it.
    while IFS= read -r shittim_file; do
        printf '\n--- %s ---\n' "$shittim_file"
        git -C "$shittim_build/source" show "HEAD:$shittim_file" | cat -v
    done < <(git -C "$shittim_build/source" ls-files)
    read -r -p '위 AUR 파일을 검토했고 이 소스를 빌드·설치하는 데 동의하나요? [y/N] ' shittim_answer
    [[ $shittim_answer == y || $shittim_answer == Y ]] || { info "빌드하지 않았습니다. 검토 사본: $shittim_build"; exit 0; }
    sudo pacman -S --needed -- base-devel
    (cd -- "$shittim_build/source" && makepkg -si)
fi
pacman -Q google-chrome >/dev/null || die 'Chrome 패키지 설치를 확인하지 못했습니다.'
info 'Google Chrome 설치 완료. 프로필과 사용자 데이터는 변경하지 않았습니다.'
