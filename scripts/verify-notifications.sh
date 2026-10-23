#!/usr/bin/env bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
for shittim_script in "$SHITTIM_ROOT/install.sh" "$SHITTIM_ROOT"/scripts/*.sh; do bash -n "$shittim_script"; done
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_notification*.py' -v
python3 "$SHITTIM_ROOT/scripts/notification-owner.py" --audit
if (( SHITTIM_DRY_RUN )); then info '읽기 전용 검사 완료. 알림 전송·서비스 변경 없음.'; exit 0; fi
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
require_command quickshell
require_command notify-send
[[ -n ${WAYLAND_DISPLAY:-} ]] || die 'Hyprland의 Kitty에서 실행하세요.'
bash "$SHITTIM_ROOT/scripts/notifications.sh" status
python3 "$SHITTIM_ROOT/scripts/notification-owner.py" --check || die '다른 알림 데몬 또는 Shittim 실행 상태를 확인하세요. 어떤 데몬도 자동 종료하지 않았습니다.'
python3 "$SHITTIM_ROOT/scripts/test-notifications.py"
info '실제 D-Bus 수신·교체·철회·DND 공유 검사를 통과했습니다. 팝업·액션·모니터 배치는 docs/notifications.md를 확인하세요.'
