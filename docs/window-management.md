# 창 관리 적용과 검증

## 변경 동작

- 커서 이동은 포인터 이벤트만 바꾸고 클릭은 키보드 포커스를 바꾼다. 창을 닫으면 최근 사용한 창을 선택한다.
- 최대화는 창별 원래 위치·크기·Floating 여부를 `shittim-restore_...` 태그에 기록하고 `shittim-maximized` 태그로 상태를 표시한다. Hyprland의 native 최대화/fullscreen은 같은 작업 공간에 한 소유자만 둘 수 있어, Shittim 최대화에는 사용하지 않는다. 여러 Kitty·Files·Chrome을 겹쳐 최대화할 수 있다.
- 작업 영역은 모니터의 실제 예약 공간·회전·배율을 읽는다. 상단 바·Dock 예약 영역 안쪽에 8px 여유를 두고 native hyprbars의 높이는 추가로 확보한다. Files의 자체 제목 표시줄은 창 내부에 포함한다.
- 복원은 해당 창의 기록만 사용한다. 모니터가 사라졌거나 줄어들면 현재 모니터 안으로 보정한다. 복원 경로에는 창 숨김·닫기 명령이 없다. 크기 변경 실패 시 기존 geometry 복구를 시도하며 실패를 반환한다.
- 숨김 후 Dock 복원, Shittim 재시작, 설정 재로딩 뒤에도 창 태그가 남는다. 창을 닫으면 기록도 사라진다. 별도 창 기록 파일은 만들지 않는다.
- 최대화 상태에서 제목 표시줄을 드래그하면 원래 크기를 포인터 아래로 복원한다. 화면 상단 스냅·Super+Up·Dock·Files·공통 제목 표시줄은 같은 창 제어기를 사용한다. 전체 화면은 Super+F로 별도 전환한다.
- Dock 우클릭 메뉴에서도 최대화·해제와 전체 화면을 조작한다. 창 목록의 아이콘·Files·native 제목 표시줄이 같은 최대화 상태를 표시한다.
- 모니터 연결/분리·설정 변경·전체 화면 해제로 Dock이 돌아올 때 최대화 창만 작업 영역에 다시 맞춘다. 일반 창과 전체 화면 게임은 재배치하지 않는다. Files는 초기 비율을 생성 때만 적용하고 창 제어 중 중복 요청을 막는다.

고정·그룹 창의 최대화는 임의로 그룹/고정을 풀지 않고 오류를 표시한다. 앱의 최소 크기 제약은 유지하므로 아주 작은 화면에서는 목표 영역을 초과할 수 있다. native CSD 앱이 직접 요청하는 최대화는 앱과 기존 suppress-maximize 설정의 영향을 받는다. 공통 hyprbars와 Shittim 버튼·단축키 경로가 이 창별 정책을 사용한다.

## 노트북 적용

진행 중인 파일 작업을 마친 뒤 Files 창을 정상적으로 닫는다. 이전 코드로 최대화한 Kitty·Chrome은 먼저 한 번 복원한다. 저장소를 갱신한 다음 일반 사용자로 실행한다.

```bash
cd ~/projects/shittim
bash scripts/setup-desktop-ux.sh
bash scripts/setup-titlebars.sh --install-hyprbars
hyprctl reload
systemctl --user restart shittim.service
bash scripts/setup-titlebars.sh --verify
bash scripts/verify-desktop-ux.sh
```

Files를 다시 열어 다음을 검사한다.

1. Kitty 두 개와 Files를 열고 각 창 본문을 클릭한 뒤 입력한다. 포인터만 옮겼을 때 키보드 포커스가 바뀌지 않고, 클릭하면 즉시 바뀌어야 한다. Alt+Tab·Dock·마우스 세 경로를 번갈아 사용한다.
2. Kitty를 최대화하고 Files·다른 Kitty도 최대화한다. 먼저 최대화한 창이 원래 크기로 돌아가지 않아야 한다. 각 창의 가운데 버튼은 복원 아이콘이어야 한다.
3. Files의 네 변, 특히 Dock 위의 아랫변 발광을 확인한다. 최대화·복원을 10회 반복해 창이 유지되고 정상 크기로 복원되는지 확인한다.
4. 최대화한 창을 숨겼다가 Dock으로 복원하고, 전체 화면 진입/해제·Super+Up·제목 표시줄 드래그·상단 스냅을 확인한다. Dock 미리보기를 닫은 후 그 뒤 창을 클릭해 입력한다.
5. 다른 배율의 모니터에 창을 옮기고 최대화·복원한다. 모니터 연결/분리 후 최대화 창이 현재 작업 영역 안에 있는지 확인한다. 전체 화면 게임과 일반 창은 각각 확인한다.

실제 클릭 문제나 잘림이 남으면 다음 한 줄로 12초 동안 상태를 수집한다. 실행 후 창을 클릭하고 최대화·복원한다. 이 검사는 창 조작이나 강제 종료를 하지 않는다.

```bash
bash scripts/verify-window-management.sh --watch 12
```

결과는 `${XDG_STATE_HOME:-~/.local/state}/shittim/window-check.json`에 소유자만 읽고 쓸 수 있는 파일로 저장한다. 포커스 주소·커서 위치·창 class·geometry·최대화/숨김 상태·모니터 예약 영역과 바탕화면 입력 상태를 기록하며, 창 제목·파일 경로·입력 내용은 수집하지 않는다. Git 추가나 업로드는 하지 않는다. 상태 검사는 실제 키 입력 성공 여부를 대신하지 않는다.

Kitty → 바탕화면 → 같은 Kitty 클릭 후 키보드가 복귀하지 않는 문제는 기존 `activewindow` 기록만으로 판별할 수 없다. 최신 코드로 셸을 다시 시작한 뒤 위 검사를 수행한다.

```bash
systemctl --user restart shittim.service
bash scripts/verify-window-management.sh --watch 12
bash scripts/share-window-diagnostics.sh --publish
```

12초 동안 Kitty를 클릭해 입력하고, 빈 바탕화면을 클릭한 다음 같은 Kitty를 다시 클릭해 입력한다. 이때 `desktopFocus`는 바탕화면의 입력 요청(`requested`), 실제 grab 상태(`grabbed`), Qt 창이 키보드를 받은 상태(`windowActive`), 내부 Item 포커스(`viewFocused`)를 구분한다. 마지막 64개의 상태 변경과 바탕화면 클릭·grab 해제 순서만 메모리에 보관한다. 캡처 종료 시 수집을 멈추고, 진단 프로세스가 중단돼도 35초 후 자동 종료한다. `protocol:0`이면 실행 중인 셸이 새 진단 API에 응답하지 않은 것이므로 포커스 해제를 확인한 것으로 해석하지 않는다. 진단은 포커스 설정이나 실제 창 동작을 변경하지 않는다.

파일을 다른 PC로 직접 옮기기 어려우면 이미 수집한 로그를 다음 명령으로 전송한다. 다시 재현할 필요가 없다.

```bash
git pull --ff-only
bash scripts/share-window-diagnostics.sh --publish
```

이 명령은 기존 파일을 읽고 허용된 수치·상태 항목만 `diagnostics/windows-latest.json`으로 추출해 그 파일 하나만 커밋·푸시한다. 원본 로그·실행 중인 창은 변경하지 않는다. 다른 스테이징 변경·미전송 코드 커밋이 있으면 전송을 중단하며, 강제 푸시하지 않는다. `--publish` 없이 실행하면 추출 파일만 생성한다. 같은 보고서의 중복 커밋을 막고, 푸시만 실패했다면 같은 명령으로 다시 전송한다.

## 개발 환경 검사 범위

격리된 Linux 테스트에서 창별 최대화·복원·숨김·실패 복구·모니터 작업 영역 계산을 검사한다. Lua 포인터 관찰자는 실제 Lua 인터프리터에서 검사한다. Windows Qt에서는 Files 크기 변경이 다른 축의 크기를 바꾸거나 창 닫기 신호를 내지 않는지, 버튼/테두리와 기존 셸 UI를 검사한다. 실제 Hyprland 포커스·Wayland configure·플러그인 GPU 렌더링·다중 모니터 조작은 위 노트북 절차로 검증한다.

## 2026-10-26 재현 로그 분석

`diagnostics/windows-latest.json`의 첫 Files 창은 3.649초에 `(422,153)`·`436×382`, 포인터는 `(821,175)`였다. 4.170초에는 창 목록에서 빠졌다. 숨김이나 다른 작업 공간으로 이동한 상태가 아니다. 이 포인터는 Files 자체 최대화 버튼 안이면서, 높이 0으로 숨긴 hyprbars의 닫기 입력 범위 안이기도 하다. 기존 플러그인은 그리기에서는 `decorate=false`를 검사했지만 입력에서는 검사하지 않고 설정 높이 24px를 사용했다. `input-gate.cpp.inc`로 그리기·예약 공간과 입력의 활성 조건을 맞춘다. 재생성한 native 플러그인 설치가 필요하다.

바탕화면은 기존에 항상 keyboard interactivity `OnDemand`였다. Hyprland 0.55/0.56의 `rawSurfaceFocus`는 바탕화면 surface에 키보드를 전달하면서 마지막 활성 앱을 유지하고, 마우스 클릭 경로는 클릭한 앱과 마지막 앱이 같으면 window refocus를 생략한다. 그 결과 `activewindow`가 Kitty여도 실제 키보드 surface는 바탕화면에 남을 수 있다. 바탕화면 입력은 명시적으로 선택·편집할 때만 활성화하고, 기존 셸 패널과 같은 `HyprlandFocusGrab`으로 외부 클릭에서 입력을 반환한다. 기본 상태와 입력 반환 후에는 interactivity `None`을 사용한다. 바탕화면 단축키·이름 변경 입력은 유지하며, 앱을 여는 동작은 실행 전에 grab을 해제한다. 공식 [surface 포커스 처리](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/desktop/state/FocusState.cpp#L201)와 [마우스 클릭 처리](https://github.com/hyprwm/Hyprland/blob/v0.56.0/src/managers/input/InputManager.cpp#L807)를 대조했다.

노트북에서는 창을 닫는 정상 동작으로 Files를 종료한 뒤 셸과 플러그인을 갱신한다. 이후 같은 최대화 버튼의 왼쪽·가운데·오른쪽을 각각 눌러 보이지 않는 외부 닫기 버튼이 더 이상 반응하지 않는지 확인한다. Kitty → 빈 바탕화면 → 같은 Kitty와 Kitty → 바탕화면 아이콘 → 다른 앱 전환을 각각 검사한다. 로컬 버튼 geometry·입력 조건·DesktopView 검사는 실제 Wayland 입력 검증을 대신하지 않는다.

## 후속 포커스 로그와 입력 순서 수정

`2140552`로 전달된 노트북 로그는 최신 진단 API(`protocol:1`)가 실행 중임을 확인한다. 바탕화면 클릭 후 3410ms에 `grab-cleared`와 입력 해제가 기록되지만, 3411ms에 지연된 `desktop-press`가 들어와 즉시 grab을 다시 만든다. 8237ms와 11885ms에도 같은 순서가 반복된다. 해당 샘플의 포인터는 Kitty 영역 `(141,85)`·`998×518` 안이다. 외부 클릭 해제 자체가 없었던 것이 아니라, 해제에 사용된 클릭을 바탕화면의 새 클릭으로 다시 처리한 것이다.

`DesktopView.releaseFocus(true)`는 진행 중인 제스처를 무효화하고 입력 반환 상태로 전환한다. 그 상태에서 뒤늦게 도착한 누름은 포커스·선택·드래그·더블클릭·메뉴 동작을 시작하지 않는다. 대응하는 버튼 해제를 처리하거나, 포인터가 바탕화면을 떠났다가 버튼을 누르지 않은 상태로 다시 들어오면 정상 입력을 재개한다. 고정 시간 지연이나 창 위치 추측은 사용하지 않는다. 진단에는 차단된 포커스 요청을 `press-ignored`로 남긴다.

이 변경은 셸의 QML에만 적용하므로 native 제목 표시줄을 다시 빌드할 필요가 없다. 저장소 갱신 후 `systemctl --user restart shittim.service`로 적용한다. 로그와 같은 해제→지연 누름 순서, 아이콘/빈 영역의 우클릭·드래그 차단, 지연 누름이 없는 외부 클릭 뒤 재진입을 Qt 테스트에서 재현한다. 실제 노트북에서 Kitty 본문 클릭 후 입력과 바탕화면 선택·더블클릭·F2 이름 변경을 함께 확인한다.
