# 디스플레이 설정

대시보드(상단 바 **SHITTIM 로고**) → 사이드바 **Display**. 연결된 모니터의 배치·해상도·주사율·배율·방향·주 디스플레이를 바꾼다. 값을 고르는 동안은 화면이 바뀌지 않는다. **적용**을 누르면 새 설정을 임시로 적용하고, 15초 안에 **변경 사항 유지**를 누르지 않으면 이전 설정으로 돌아간다.

## 화면

| 영역 | 동작 |
|---|---|
| 배치 | 모니터를 번호가 붙은 카드로 표시한다. 선택한 카드는 시안 이중 테두리. 카드를 끌어 놓으면 가장 가까운 다른 화면의 변에 붙는다(겹치거나 떨어진 위치로는 놓이지 않음). 키보드: Tab 으로 카드 선택 → 화살표 키로 그 방향 옆에 붙임. 바뀐 화면은 원래 자리를 흐린 테두리로 함께 보여 준다. |
| 모니터 | 1 — 내장 디스플레이 / 2 — 제조사 모델. 번호는 Hyprland 모니터 id 순서. |
| 해상도 · 주사율 | `hyprctl -j monitors all` 의 `availableModes` 에 있는 값만. 해상도를 바꾸면 그 해상도의 가장 가까운 주사율을 고른다. |
| 배율 | 100·125·150·160·175·200·225·250·300% 중 **그 해상도에서 Hyprland 가 그대로 쓰는 값만**. Hyprland 는 n/120 배율에서 논리 크기가 정수 픽셀이 아니면 다른 배율로 바꾸므로(`helpers/Monitor.cpp`), 예를 들어 1920×1080 에서는 175% 를 보여 주지 않는다. |
| 방향 | 가로 · 세로(90°) · 가로 (반전)(180°) · 세로 (반전)(270°) = Hyprland transform 0–3. 다른 곳에서 설정한 대칭(4–7)은 그대로 유지만 한다. |
| 주 디스플레이로 사용 | 아래 «주 디스플레이의 뜻» 참조. 다음 로그인부터 적용. |
| 취소 · 적용 | 취소 = 적용 전 변경을 버림. 적용 = 겹침·떨어짐이 없을 때만 켜짐. |
| 밝기 | 기존 백라이트 밝기 제어(이전 Display 메뉴 내용) |

값이 바뀐 행은 시안 글자 + 오른쪽에 «현재 …» 가 함께 보인다. 하단 줄은 오류(빨강) · 배치 문제(노랑) · 적용 중 · 결과를 보여 준다. 대시보드 상세 영역 높이가 정해져 있어 화면은 세로로 스크롤되며, 오른쪽 막대가 위치를 알려 준다.

모니터가 연결·해제되면 목록을 다시 읽는다. 적용 전 변경이 있었다면 초기화하고 하단에 알린다. 꺼진(`disabled`) 모니터와 복제 중인 모니터는 목록 아래에 이름만 표시하며 여기서 켜거나 끄지 않는다.

## 주 디스플레이의 뜻

Hyprland 에는 Windows 의 «주 모니터» 개념이 없다. Shittim 의 상단 바·Dock·바탕화면은 모든 모니터에 나오고, 런처·알림은 포커스된 모니터에 열린다. 그래서 여기서 주 디스플레이는 Hyprland 가 실제로 지원하는 두 가지로 정의한다.

- `cursor:default_monitor` — 로그인할 때 마우스 커서(와 포커스)가 놓이는 모니터
- 작업 공간 1 의 기본 모니터 — `hl.workspace_rule({ workspace = "1", monitor = …, default = true })`

둘 다 Hyprland 가 설정을 읽을 때만 쓰므로 **다음 로그인(또는 `hyprctl reload`)부터** 적용된다. 주 디스플레이만 바꾸면 화면이 바뀌지 않으므로 15초 확인 없이 바로 저장한다.

## 구조

| 책임 | 파일 |
|---|---|
| 화면(View) | `shell/components/control/DisplayPage.qml` · `DisplayArrangement.qml` · `DisplayConfirmCard.qml` · `shell/components/DisplayConfirm.qml` |
| 배치 계산·문구(순수 함수) | `shell/core/DisplayLayout.js` |
| 상태(현재 · 적용 전 변경 · 진행 중 변경) | `shell/services/DisplayState.qml` |
| Hyprland 조회·검증·적용·복원·저장 | `scripts/display-config.py` (`Hyprland` 어댑터 · `validate` · `Guard` · `Files`) |

QML 은 Hyprland 명령 문자열을 만들지 않는다. `display-config.py list|apply|keep|revert` 만 부르고 결과 파일을 읽는다. `display-config.py` 는 UI 가 미리 검사한 값도 다시 검증한다(지원 모드 · 배율 · 방향 · 위치 범위 · 겹침 · 떨어짐 · 연결된 모니터 집합).

## 적용과 자동 복원

1. **적용** → `display-config.py apply '<계획 JSON>'` 이 현재 모니터 상태를 다시 읽어 검증하고, 되돌릴 **이전 상태**(모드 · 위치 · 배율 · 방향)를 `$XDG_RUNTIME_DIR/shittim/display-transaction.json` 에 기록한다.
2. 같은 명령이 `systemd-run --user --unit=shittim-display-guard` 로 **복원 감시 프로세스를 별도 사용자 유닛**으로 띄운다. Quickshell·`shittim.service` 를 멈추거나 재시작해도 이 유닛은 그대로 남는다. `systemd-run` 이 없거나 실패하면 **아무것도 바꾸지 않고** 오류를 표시한다.
3. 감시 프로세스가 `hyprctl eval 'hl.monitor({...}) …'` 로 모든 모니터 규칙을 한 번에 적용하고, 5초 안에 실제 상태가 요청과 같은지 확인한다. 거부되거나 다르면 즉시 이전 상태로 되돌리고 «적용하지 못함» 으로 끝낸다.
4. 확인 창을 띄운다(대시보드가 열려 있으면 그 안에, 아니면 모든 화면 위에). 기본 포커스는 **이전 설정으로 복원**이고 Esc 도 복원이다.
5. 감시 프로세스는 다음 중 하나로 끝난다.
   - 유지 → 저장(아래) 후 종료
   - 복원 버튼 · 15초 경과 · 변경한 모니터 분리 · SIGTERM(유닛 정지·`RuntimeMaxSec=120`) · 예기치 않은 오류 → 이전 상태 적용
6. 이전 상태 적용이 실패하면 `hyprctl reload` 로 Hyprland 설정 파일 기준 상태로 되돌린다. 그것도 실패하면 «복원하지 못함» 과 아래 TTY 복구 명령을 표시한다.

진행 상태는 `$XDG_RUNTIME_DIR/shittim/display-status.json` 에 남고 UI 는 이것을 읽는다. 그래서 확인 대기 중 Quickshell 이 재시작돼도 확인 창이 다시 뜨고, 응답하지 않으면 감시 프로세스가 그대로 복원한다.

### 화면이 보이지 않을 때

아무것도 누르지 말고 15초 기다리면 이전 설정으로 돌아온다. 돌아오지 않으면 Ctrl+Alt+F3 으로 TTY 에 로그인해서:

```bash
python3 ~/projects/shittim/scripts/display-config.py restore   # 마지막 변경 전 상태로
python3 ~/projects/shittim/scripts/display-config.py reset     # 저장한 배치를 지우고 Hyprland 설정 다시 읽기
```

TTY 에는 `HYPRLAND_INSTANCE_SIGNATURE` 가 없으므로 스크립트가 `hyprctl -i 0` 으로 실행 중인 Hyprland 를 고른다. Ctrl+Alt+F1 로 그래픽 세션에 돌아간다.

## 저장(영속화)

임시 적용과 저장을 분리한다. **변경 사항 유지**를 누른 뒤에만 저장한다.

- `~/.config/shittim/display.json` — 저장된 배치(정본). 모니터는 설명(제조사 모델 시리얼)이 유일하면 `desc:…`, 같은 모니터가 둘이면 포트 이름으로 기억한다. 지금 연결되지 않은 모니터의 저장값은 지우지 않는다.
- `~/.config/hypr/shittim-monitors.lua` — 위에서 생성하는 `hl.monitor` 규칙과 주 디스플레이 규칙. 관리용 `~/.config/hypr/hyprland.lua` 가 원래 설정(`shittim-base.lua`)과 다른 Shittim 파일 **다음에** 읽으므로 원래 `hl.monitor` 규칙보다 우선한다. 원래 설정 파일은 고치지 않는다.

기존 설치는 관리용 `hyprland.lua` 에 이 줄이 없다. `./install.sh`(또는 `bash scripts/setup-autostart.sh`)를 한 번 다시 실행해야 다음 로그인에도 유지된다. 그 전에 유지를 누르면 화면에는 적용되지만, 결과 문구가 재실행이 필요하다고 알려 준다.

규칙은 `mode` · `position` · `scale` · `transform` 만 쓴다. 원래 설정이 같은 모니터에 `bitdepth` · `vrr` · `cm` 같은 다른 항목을 **다른 이름(예: `desc:`)의 규칙**으로 두었다면, Hyprland 는 마지막에 맞는 규칙 하나만 쓰므로 그 항목은 기본값이 된다(`MonitorRuleManager::get` 이 뒤에서부터 첫 일치 규칙을 반환). 현재 저장소의 원래 설정은 `output = ""` 기본 규칙 하나뿐이라 해당하지 않는다.

## 검증

Windows · WSL 에서 한 것:

- `tests/test_display.py`(가짜 Hyprland): `hyprctl -j monitors` 형식 해석, 2자리 배율 → n/120 복원, 지원하지 않는 모드·배율·방향·위치·겹침·떨어짐·미연결 모니터 거부, Lua 규칙 문자열·이스케이프, 시간 초과 복원, 유지 후에만 저장, 다른 변경의 응답 무시, 복원 버튼·SIGTERM, 적용 거부·불일치 → 복원, 모니터 분리 → 복원, 복원 실패 → `reload` → 최종 실패 보고, 예기치 않은 예외에도 복원, 감시 프로세스 없이 아무것도 안 바꿈, 동시 변경 거부, 주 디스플레이만 바꾸면 저장만, `restore` 명령, 저장 병합, 관리용 `hyprland.lua` 가 저장 파일을 마지막에 읽음.
- `shell/tests/tst_display.qml`: 배율 선택지, 배치 규칙, 드롭 위치 붙이기, 크기 변경 후 이웃 따라오기, 행 값, 실제 모드만 나오는 선택 목록과 키보드 선택, 적용·취소 버튼 상태, 확인 창 기본 포커스(Enter = 복원)·Esc, 카드 드래그·화살표 키, 주 디스플레이 체크.
- Hyprland 0.55.0 소스로 확인: `hl.monitor` 필드와 같은 이름 규칙 덮어쓰기(`LuaBindingsConfigRules.cpp`), 규칙 선택 순서(`MonitorRuleManager.cpp`), 모드 선택·배율 보정(`helpers/Monitor.cpp`), `hyprctl eval` 오류 반환(`ConfigManager::eval`), `monitors` JSON 필드(`HyprCtl.cpp`), `cursor:default_monitor`·작업 공간 `default`.

노트북에서 확인할 것(실제 모니터 필요 — 아직 하지 않음):

```bash
cd ~/projects/shittim
git pull --ff-only
./install.sh                              # 관리용 hyprland.lua 에 저장 파일 읽기 추가
systemctl --user restart shittim.service
python3 scripts/display-config.py list    # 실제 모니터 목록·모드가 화면과 같은지
```

1. Display 화면의 모니터 수 · 해상도 · 주사율 · 배율 · 위치가 `list` 결과와 같은지.
2. 위험이 적은 변경(주사율 하나)을 적용 → 확인 창 → **아무것도 누르지 않고** 15초 → 이전 설정으로 복원되는지.
3. 같은 변경 → **변경 사항 유지** → `~/.config/hypr/shittim-monitors.lua` 생성 → `hyprctl reload` 후에도 유지되는지.
4. 확인 창이 떠 있는 동안 `systemctl --user restart shittim.service` → 확인 창이 다시 뜨는지, 응답하지 않으면 복원되는지.
5. 외부 모니터: 배치 드래그 · 배율 · 세로 방향 · 주 디스플레이(재로그인 후 커서 위치) · 확인 대기 중 케이블 분리 → 복원.

시험 중 화면이 안 보이면 위 «화면이 보이지 않을 때» 를 따른다. 15초 자동 복원은 Quickshell 과 별개인 사용자 유닛이 하므로, 셸이 멈춰도 동작한다(`systemctl --user status shittim-display-guard` 로 확인 대기 중임을 볼 수 있다).

## 참고한 오픈소스

| 저장소(검토 커밋) | 참고한 것 | Shittim 에서 바꾼 것 | 라이선스 |
|---|---|---|---|
| [43PR/dotfiles](https://github.com/43PR/dotfiles/blob/6b5c0c203fee96bff017a0398ea8c0c14591f17a/.config/quickshell/SettingsPages/DisplayPage.qml) `6b5c0c2` | Lua 설정에서 `hyprctl monitors all -j` 로 읽고 `hyprctl eval 'hl.monitor({...})'` 로 적용 · 규칙마다 `transform` 을 항상 씀 · 배율을 n/120 정수 픽셀로 제한 · `dofile` 로 생성 파일을 읽는 저장 방식 | 확인·자동 복원 없음 → 별도 유닛의 감시 프로세스 추가 · 저장은 유지 후에만 · 드래그 배치 · 화면과 로직이 한 파일 → View/State/순수 함수/백엔드 분리 · 오류를 사용자 문구로 | MIT — 코드는 복사하지 않음(설계만 참고) |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell/blob/48b323fa9d7ada89939ba6b3ea4e4fdf93d126a6/services/Hypr.qml) `48b323f` | Hyprland raw 이벤트 중 모니터 이벤트로 목록 새로 읽기 · 싱글톤 서비스/화면 분리 | 디스플레이 설정 화면은 없음(TODO) — 이벤트 이름은 `monitoradded`/`monitorremoved`(+v2)/`configreloaded` 로 한정 | GPL-3.0 — 코드 복사 없음 |
| [ViegPhunt/Dotfiles](https://github.com/ViegPhunt/Dotfiles) `d01a3e6` | 모니터 설정을 별도 파일로 분리 | 해당 저장소는 정적 `monitor=` 한 줄뿐 | MIT — 코드 복사 없음 |
| [ViegPhunt/Arch-Hyprland](https://github.com/ViegPhunt/Arch-Hyprland) `9e7ff93` | — (설치 스크립트뿐, 모니터 관련 코드 없음) | — | MIT |

네 저장소 모두 «적용 후 확인 · 자동 복원» 과 «드래그 배치» 는 없었다. 코드·리소스를 가져오지 않았으므로 저작권 고지 의무는 생기지 않는다.
