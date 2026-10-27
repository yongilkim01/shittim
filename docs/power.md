# 잠금 화면 · 자동 잠금 · 전원 관리

| 기능 | 담당 | 파일 |
|---|---|---|
| 세션 잠금·비밀번호 인증 | hyprlock (Wayland ext-session-lock + PAM `/etc/pam.d/hyprlock`) | `config/templates/shittim-lock.conf.in` → `~/.config/hypr/shittim-lock.conf` |
| 잠금 진입점 (중복 방지) | `scripts/lock-screen.sh` (flock) | Super+L · 전원 메뉴 · hypridle `lock_cmd` |
| 유휴 시간 → 잠금·화면 끄기·절전 | hypridle | `$XDG_RUNTIME_DIR/shittim/hypridle.conf` (생성물) |
| 전원 공급 판별·정책 적용·덮개 | `scripts/idle-service.py` (`shittim-idle.service`) | `$XDG_RUNTIME_DIR/shittim/power-status.json` |
| 설정 값 검증·저장 (유일한 쓰기 경로) | `scripts/power-policy.py set` | `~/.config/shittim/power.json` (기본값 `config/power.json`) |
| 잠금 확인 후 절전·화면 켜기/끄기 | `scripts/power-action.sh` | `hyprctl -j locked` · `hl.dsp.dpms` |
| 설정 화면 | 대시보드 «Power» → «전원 및 잠금» | `shell/components/control/PowerLockPage.qml` |
| 잠금·절전·절전 방지 버튼 | Control Center «Power» | `shell/components/control/PowerPage.qml` |
| 상태 연결 | `PowerPolicyState` | `shell/services/PowerPolicyState.qml` |

## 기본 정책

| 항목 | 배터리 사용 시 | 전원 연결 시 | 선택지 |
|---|---|---|---|
| 자동 잠금 | 5분 | 5분 | 사용 안 함 · 1 · 2 · 3 · 5 · 10 · 15 · 30분 |
| 화면 끄기 | 10분 | 15분 | 사용 안 함 · 1 · 2 · 3 · 5 · 10 · 15 · 30분 · 1시간 |
| 자동 절전 | 사용 안 함 | 사용 안 함 | 사용 안 함 · 10 · 15 · 20 · 30 · 45분 · 1 · 2시간 |
| 덮개를 닫을 때 | 시스템 설정 | 시스템 설정 | 시스템 설정 · 절전 · 잠그고 화면 끄기 · 아무것도 안 함 |

- 첫 설치에서 자동 절전은 꺼져 있다. 사용자가 켤 때만 동작한다.
- 선택지는 고정 목록이다. 잘못된 값이 든 파일은 무시하고 기본값으로 동작한다(반복 잠금 방지). 다음 저장 때 손상 파일은 `power.json.invalid` 로 남긴다.
- 배터리가 없는 PC 는 «전원 연결 시» 정책만 쓰고 «배터리 사용 시» 탭은 비활성이다. 덮개가 없으면 덮개 항목을 숨긴다.

## 동작

- **잠금**: 모든 경로가 `lock-screen.sh` → `hyprlock --config shittim-lock.conf` 로 모인다. 이미 잠겨 있으면 flock 이 두 번째 실행을 막는다. 인증은 hyprlock 이 PAM 으로 한다. Shittim 은 비밀번호를 읽거나 저장하지 않으며 PAM 설정을 바꾸지 않는다.
- **자동 잠금·화면 끄기·자동 절전**: `idle-service.py` 가 2초마다 전원 공급(sysfs `power_supply`)과 `power.json` 을 확인한다. 정책이 바뀔 때만 hypridle 설정을 새로 쓰고 hypridle 을 다시 시작한다(유휴 시간이 처음부터 다시 셈된다).
- **절전 전 잠금**: hypridle `before_sleep_cmd = loginctl lock-session` + `inhibit_sleep = 3` 이 화면이 잠길 때까지 절전을 미룬다(lock_cmd 가 스크립트라 자동 모드 2 로는 기다리지 않음 — hypridle 소스 확인). Shittim 버튼·자동 절전·덮개 절전은 `power-action.sh suspend` 를 거친다. 이 스크립트는 `hyprctl -j locked` 가 true 가 된 뒤에만 `systemctl suspend` 를 부르고, 5초 안에 잠기지 않으면 절전을 취소하고 알린다.
- **화면 끄기·켜기**: `hyprctl dispatch 'hl.dsp.dpms({action="off"})'` (Hyprland 0.55 Lua 디스패처, 소스 확인). 입력이 들어오면 hypridle `on-resume` 과 절전 복귀 `after_sleep_cmd` 가 화면을 켠다.
- **덮개**: «시스템 설정» 이면 logind(`HandleLidSwitch*`) 가 처리하고 Shittim 은 관여하지 않는다. 다른 값을 고르면 `systemd-inhibit --what=handle-lid-switch` 로 logind 처리를 막고 Shittim 이 처리한다. 외부 모니터가 연결된 상태(도킹)에서는 아무것도 하지 않는다. 권한이 없어 inhibitor 를 잡지 못하면 logind 설정대로 동작하고 설정 화면에 표시한다. 같은 이벤트에 두 곳이 반응하지 않는다.
- **유휴 억제**: 앱이 Wayland idle-inhibit · `org.freedesktop.ScreenSaver` · systemd `idle` inhibitor 를 요청하면 hypridle 이 존중한다(동영상 전체 화면, 화상회의 등). Control Center 의 «절전 방지» 는 logind `idle` inhibitor 를 잡아 자동 잠금·화면 끄기·자동 절전을 멈춘다. 켜져 있으면 TopBar 에 󰅶 아이콘이 보이고 누르면 꺼진다. Shittim 을 다시 시작하면 꺼진다. 직접 잠그거나 절전하는 것은 막지 않는다.
- **기존 hypridle**: 사용자가 따로 hypridle 을 돌리고 있으면 Shittim 은 hypridle 을 하나 더 띄우지 않고 설정 화면에 그 사실을 표시한다.
- **설정 화면 상태 문구**: 저장 여부와 실제 적용 여부를 구분한다. `power-status.json` 의 적용 값이 저장된 값과 같고 hypridle 이 실행 중일 때만 «적용되었습니다» 로 표시한다.

## 설치 · 적용

`./install.sh` 가 `hypridle` 패키지, `shittim-idle.service`, 잠금 화면 설정을 함께 설치한다. 실행 중인 세션은 재시작하지 않는다.

```bash
cd ~/projects/shittim
git pull
./install.sh
systemctl --user start shittim-idle.service
systemctl --user restart shittim.service
bash scripts/verify-power.sh
```

`shittim-idle.service` 는 다음 로그인부터 Hyprland 시작 때 함께 실행되고 Hyprland 종료 때 멈춘다.

## 노트북 실기 검사 (실제 잠금·절전 포함 — 작업 저장 후)

아래 항목을 한 번에 진행하는 안내 스크립트가 있다. 각 단계에서 할 일을 보여 주고 결과는 스크립트가 직접 확인한다(`hyprctl locked`·DPMS·창 목록·inhibitor·절전 시간). 비밀번호 입력, 덮개 여닫기, 어댑터 뽑기와 화면에서만 보이는 것(오류 문구, 모든 모니터, TopBar 아이콘)은 사람이 하고 y/n 으로 답한다. 설정은 검사 중에만 짧게 바꾸고 끝나면(Ctrl+C 로 중단해도) 원래 파일 그대로 되돌린다. 자동 절전은 검사 내내 꺼 둔다.

```bash
bash ~/projects/shittim/scripts/test-power.sh                 # 잠금·자동 잠금·화면 끄기·절전 방지·전원 감지
bash ~/projects/shittim/scripts/test-power.sh --with-suspend  # + 실제 절전 · 덮개 절전 (복귀 직후 잠김 확인)
```

각 단계는 `s` 로 건너뛸 수 있다. 결과는 화면과 `~/.local/state/shittim/power-test-<시각>.txt` 에 남는다.

손으로 할 때의 순서:

1. **수동 잠금**: Super+L → HUD 잠금 화면. 틀린 비밀번호 → «비밀번호가 올바르지 않습니다». 맞는 비밀번호 + Enter → 데스크톱 복귀, 창 그대로.
2. **중복 잠금**: 잠긴 상태에서 다른 TTY 로 `bash ~/projects/shittim/scripts/lock-screen.sh` → 아무 일도 없어야 한다(`pgrep -c hyprlock` = 1).
3. **Control Center**: Power → «잠금». «절전» 은 한 번 누르면 «한 번 더 눌러 절전» 으로 바뀌고 두 번째에 절전한다. 복귀 시 잠금 화면.
4. **자동 잠금 짧게**: 대시보드 Power → 자동 잠금 1분, 화면 끄기 2분 → 손 떼고 기다린다. 1분 뒤 잠금, 2분 뒤 화면 꺼짐, 키 입력 → 화면 켜지고 잠금 화면. 끝나면 원래 값으로 되돌린다.
5. **절전 방지**: Control Center Power → «절전 방지» → TopBar 󰅶 → 1분이 지나도 잠기지 않음 → 아이콘을 눌러 끄기.
6. **전원 연결/분리**: 어댑터를 빼고 꽂을 때 설정 화면 하단 문구의 «배터리 사용 시 / 전원 연결 시» 가 바뀐다.
7. **덮개**: 덮개 설정을 «절전» 으로 바꾼 뒤 덮개를 닫았다 연다 → 잠금 화면.
8. **멀티 모니터**: 외부 모니터 연결 상태에서 Super+L → 모든 모니터가 잠금 화면.

`bash scripts/verify-power.sh` 는 위 항목을 대신하지 않는다. 설치·서비스·상태 파일만 읽는다.

## 문제 발생 시 복구 (TTY)

잠금 화면이 계속 뜨거나 자동 잠금이 원하지 않게 동작하면 Ctrl+Alt+F2 로 TTY 에 로그인한다.

```bash
systemctl --user stop shittim-idle.service              # 자동 잠금·화면 끄기·자동 절전 즉시 중지
rm ~/.config/shittim/power.json                         # 기본값으로 되돌리기
pkill -USR1 hyprlock                                    # 잠금 화면 해제 (hyprlock 의 SIGUSR1 처리)
```

Ctrl+Alt+F1 로 돌아가면 데스크톱이 그대로 있다.

hyprlock 이 비정상 종료되어 Hyprland 가 «lockscreen crashed» 빨간 화면을 보이면 세션은 계속 잠겨 있다(안전한 상태). Hyprland 기본값(`misc:allow_session_lock_restore = false`)에서는 잠금 프로그램을 다시 붙일 수 없으므로, 작업을 포기하고 TTY 에서 `pkill Hyprland` 로 세션을 끝낸 뒤 tty1 에서 다시 로그인한다. 열려 있던 앱은 종료된다.

## 참고한 저장소

- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0): 사용자 설정(JSON)과 실행 중 상태(runtime 폴더) 분리, 타임아웃을 데이터 목록으로 다루는 방식, «Keep awake» 토글 UI. 코드는 가져오지 않았다. 잠금을 Quickshell `WlSessionLock`+`PamContext` 로 직접 하고 절전 전 delay inhibitor 가 없어 경쟁 조건이 남는 점은 따르지 않았다.
- [ViegPhunt/Dotfiles](https://github.com/ViegPhunt/Dotfiles) · [43PR/dotfiles](https://github.com/43PR/dotfiles) (MIT): hyprlock 단독 설정·키 바인딩 수준. 두 저장소 모두 절전 전에 잠그지 않는다(`systemctl suspend` 직접 호출) — Shittim 은 잠금 확인 후 절전한다.
- [ViegPhunt/Arch-Hyprland](https://github.com/ViegPhunt/Arch-Hyprland): 관련 구현 없음.
- 네 저장소 모두 hypridle·덮개 처리가 없다. hypridle 동작(`inhibit_sleep`, inhibitor 종류)은 [hypridle 소스](https://github.com/hyprwm/hypridle) `src/core/Hypridle.cpp`, `src/config/ConfigManager.cpp` 에서, hyprlock 위젯 옵션은 [hyprlock 소스](https://github.com/hyprwm/hyprlock) `src/config/ConfigManager.cpp` 에서, DPMS·`locked` 질의는 Hyprland v0.55.0 소스에서 확인했다.
