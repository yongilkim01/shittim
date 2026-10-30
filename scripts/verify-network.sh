#!/usr/bin/env bash
# Network settings: code tests, then a read-only look at the running NetworkManager. Changes nothing, connects nowhere.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_arch
require_command python3
bash -n "$SHITTIM_ROOT/scripts/verify-network.sh"
python3 -m unittest discover -s "$SHITTIM_ROOT/tests" -p 'test_network*.py' -v
shittim_qmltest=$(command -v qmltestrunner || true)
if [[ -z $shittim_qmltest && -x /usr/lib/qt6/bin/qmltestrunner ]]; then shittim_qmltest=/usr/lib/qt6/bin/qmltestrunner; fi
if [[ -n $shittim_qmltest ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$shittim_qmltest" -input "$SHITTIM_ROOT/shell/tests/tst_network.qml"
else warn 'qmltestrunner가 없어 화면 단위 테스트를 건너뜁니다.'; fi
if (( SHITTIM_DRY_RUN )); then info '코드 검사 완료. NetworkManager에는 접속하지 않았습니다.'; exit 0; fi

systemctl is-active --quiet NetworkManager.service || die 'NetworkManager.service가 실행 중이 아닙니다. ./install.sh 또는 sudo systemctl enable --now NetworkManager.service'
python3 -c 'import dbus_next' 2>/dev/null || die 'python-dbus-next가 없습니다. sudo pacman -S python-dbus-next'
command -v ping >/dev/null || warn 'ping(iputils)이 없어 진단의 게이트웨이·지연 측정을 할 수 없습니다.'
[[ $(sysctl -n net.ipv4.ping_group_range 2>/dev/null) != "1	0" ]] || warn '일반 사용자 ping이 막혀 있습니다(net.ipv4.ping_group_range).'
# Names, states and permission levels only; no addresses, SSIDs or profile contents are printed.
python3 "$SHITTIM_ROOT/scripts/network-service.py" --check || die 'NetworkManager D-Bus 상태를 읽지 못했습니다.'
pgrep -u "$USER" -f 'polkit-kde-authentication-agent|polkit-kde-agent' >/dev/null \
    || warn 'polkit 인증 에이전트가 보이지 않습니다. 관리자 인증이 필요한 변경(IP·DNS 적용)은 실패할 수 있습니다.'
info '검사 완료. 대시보드 › 네트워크에서 목록·상세·트래픽을 확인하고, 설정 변경은 docs/network.md의 순서로 시험하세요.'
