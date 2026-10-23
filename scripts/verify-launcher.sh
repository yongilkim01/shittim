#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
require_command quickshell
require_command timeout
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_launcher*.py' -v
python3 "$SHITTIM_ROOT/scripts/launcher-service.py" --check
require_command xdg-terminal-exec
xdg-terminal-exec --print-id
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
[[ -n ${WAYLAND_DISPLAY:-} ]] || die '실제 Quickshell 검사는 Hyprland의 Kitty에서 실행하세요.'
timeout 15s quickshell --path "$SHITTIM_ROOT/shell/verify-launcher.qml"
bash "$SHITTIM_ROOT/scripts/launcher.sh" status
hyprctl -j configerrors | python3 -c 'import json,sys; sys.exit(any(str(error).strip() for error in json.load(sys.stdin)))'
info '런처 코드·GIO 목록·터미널 선택·IPC 검사 완료. 실제 단축키·앱 실행·다중 모니터는 docs/app-launcher.md를 확인하세요.'
