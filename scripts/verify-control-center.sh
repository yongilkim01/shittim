#!/usr/bin/env bash
# Read-only checks; hardware interactions remain an explicit manual test.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
require_command quickshell
require_command timeout
python3 -c 'import dbus_next'
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -v
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
[[ -n ${WAYLAND_DISPLAY:-} ]] || die '실제 Quickshell import 검사는 Hyprland의 Kitty에서 실행하세요.'
timeout 15s quickshell --path "$SHITTIM_ROOT/shell/verify-control-center.qml"
info 'Control Center 코드 검사 완료. 실제 연결·페어링·슬라이더·모니터 제거는 문서의 실기 항목을 확인하세요.'
