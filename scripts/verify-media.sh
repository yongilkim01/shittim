#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_media*.py' -v
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_launcher*.py' -v
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_qml_imports.py' -v
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
if (( SHITTIM_DRY_RUN )); then info '정적·단위 검사 완료. 실제 플레이어와 창은 제어하지 않았습니다.'; exit 0; fi
[[ -n ${WAYLAND_DISPLAY:-} ]] || die '실제 UI 검사는 Hyprland의 Kitty에서 실행하세요.'
bash "$SHITTIM_ROOT/scripts/media.sh" status
python3 "$SHITTIM_ROOT/scripts/test-media.py"
info 'IPC와 실제 MPRIS 서비스 탐색 확인. 상단 바 음악 아이콘에서 재생·Seek·앱 포커스 이동을 확인하세요.'
