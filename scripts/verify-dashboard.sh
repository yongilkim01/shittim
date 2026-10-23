#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_dashboard*.py' -v
if (( SHITTIM_DRY_RUN )); then info '코드·수집기 검사 완료. 실행 중인 Shittim은 변경하지 않았습니다.'; exit 0; fi
python3 "$SHITTIM_ROOT/scripts/dashboard-service.py" --once
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
[[ -n ${WAYLAND_DISPLAY:-} ]] || die '실제 UI 검사는 Hyprland의 Kitty에서 실행하세요.'
bash "$SHITTIM_ROOT/scripts/dashboard.sh" status
python3 "$SHITTIM_ROOT/scripts/test-dashboard.py"
info '실제 데이터·코드·IPC 검사 완료. SHITTIM 로고로 열고 닫은 뒤 측정 프로세스 상태와 장치별 센서를 확인하세요.'
