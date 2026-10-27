#!/usr/bin/env bash
# Lock screen, idle and power policy check. Read-only: never locks, turns off the screen or suspends.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/common.sh"
no_extra_args
require_user
require_command python3
shittim_failures=0
fail() { warn "$*"; shittim_failures=$((shittim_failures + 1)); }
for shittim_command in hyprlock hypridle systemd-inhibit loginctl busctl; do
    command -v "$shittim_command" >/dev/null || fail "필요한 명령 없음: $shittim_command"
done
python3 "$SHITTIM_ROOT/scripts/power-policy.py" >/dev/null || fail '전원 설정을 읽지 못했습니다.'
shittim_check=$(python3 "$SHITTIM_ROOT/scripts/idle-service.py" --check) || fail '유휴 정책 점검 실패'
python3 - "$shittim_check" <<'PY' || fail '유휴 정책 결과 해석 실패'
import json, sys
data = json.loads(sys.argv[1])
names = {'battery': '배터리 사용 시', 'ac': '전원 연결 시'}
print('[Shittim] 현재 전원:', names.get(data['source'], data['source']), '· 배터리', '있음' if data['hasBattery'] else '없음', '· 덮개', data['lid'] or '없음')
print('[Shittim] 시스템(logind) 덮개 동작:', data['logind'])
if data['settingsError']:
    print('[Shittim:주의] ~/.config/shittim/power.json 이 손상되어 기본값을 씁니다.', file=sys.stderr)
print('[Shittim] 적용할 hypridle 설정:')
print(data['hypridle'], end='')
PY
shittim_lock=${XDG_CONFIG_HOME:-$HOME/.config}/hypr/shittim-lock.conf
[[ -f $shittim_lock ]] || fail "잠금 화면 설정 없음: $shittim_lock (bash scripts/setup-desktop.sh)"
systemctl --user cat shittim-idle.service >/dev/null 2>&1 || fail 'shittim-idle.service 없음 (bash scripts/setup-autostart.sh)'
if systemctl --user is-enabled --quiet hypridle.service 2>/dev/null; then
    warn '기존 hypridle.service 가 켜져 있습니다. 두 개가 동시에 돌지 않도록 Shittim 은 그쪽이 실행 중이면 적용하지 않습니다.'
fi
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    systemctl --user is-active --quiet shittim-idle.service || fail 'shittim-idle.service 비활성: systemctl --user start shittim-idle.service'
    shittim_status=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/shittim/power-status.json
    if [[ -f $shittim_status ]]; then
        python3 - "$shittim_status" <<'PY' || fail '자동 잠금 정책이 적용되지 않았습니다.'
import json, sys, time
data = json.load(open(sys.argv[1], encoding='utf-8'))
fresh = time.time() - data['time'] < 10
print('[Shittim] hypridle:', data['idle'], '· 상태 갱신', '정상' if fresh else '멈춤')
lid = data['lid']
print('[Shittim] 덮개 정책:', lid['policy'], '· logind 대신 처리' if lid['inhibited'] else '· logind 가 처리', ('· 오류 ' + lid['error']) if lid['error'] else '')
sys.exit(0 if fresh and data['idle'] == 'running' and not lid['error'] else 1)
PY
    else fail "상태 파일 없음: $shittim_status"; fi
    hyprctl -j locked >/dev/null || fail 'hyprctl locked 질의 실패 (Hyprland 0.55 이상 필요)'
    info "inhibitor 목록 (Shittim·hypridle 항목 확인):"
    systemd-inhibit --list --no-pager 2>/dev/null | grep -Ei 'shittim|hypridle|WHO' || true
else info '현재 TTY입니다. 서비스·잠금 상태는 Hyprland 세션에서 다시 검사하세요.'; fi
(( shittim_failures == 0 )) || die "전원·잠금 검사 실패 ${shittim_failures}건"
info '전원·잠금 검사 통과. 실제 잠금·해제·절전은 docs/power.md의 수동 검사 순서를 따르세요.'
