#!/usr/bin/env bash
# Developer/CI checks; does not install packages, modify settings or use user IPC.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_command python3
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 "$SHITTIM_ROOT/scripts/design-tokens.py" --check
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -v
shittim_qmltest=$(command -v qmltestrunner || true)
[[ -n $shittim_qmltest ]] || shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner
[[ -x $shittim_qmltest ]] || die 'Qt 화면 검사를 위해 qt6-declarative의 qmltestrunner가 필요합니다.'
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
require_command g++
require_command pkg-config
shittim_build=$(mktemp -d)
trap 'rm -rf -- "$shittim_build"' EXIT
read -r -a shittim_cairo_flags <<< "$(pkg-config --cflags --libs cairo)"
g++ -std=c++23 "$SHITTIM_ROOT/tests/titlebar-hover.cpp" -o "$shittim_build/titlebar-hover" "${shittim_cairo_flags[@]}"
"$shittim_build/titlebar-hover"
g++ -std=c++23 "$SHITTIM_ROOT/tests/titlebar-controls.cpp" -o "$shittim_build/titlebar-controls" "${shittim_cairo_flags[@]}"
"$shittim_build/titlebar-controls"
info '코드·모델·화면·생성 토큰 검사 통과. compositor 검사는 별도 test-session.sh로 실행합니다.'
