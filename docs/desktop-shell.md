# 바탕화면·하단 Dock·드래그 스냅

기본 배경은 `assets/wallpapers/shittim-lake.png`다. 사용자가 제공한 초기 시안의 절제된 남청색·청록색 산과 호수·성 구도를 따라 내장 이미지 생성 도구로 재생성했다. 글씨·상단 바·시계·HUD는 이미지에 포함하지 않는다. 실제 크기는 1672×941이며 생성 프롬프트와 출처는 [배경 파일 설명](../assets/wallpapers/README.md)에 기록한다. 각 모니터의 Background layer에 비율을 유지하는 `PreserveAspectCrop`으로 표시한다. 별도 배경 데몬이나 Nemo 데스크톱 프로세스를 추가하지 않는다. Top Bar·Control Center·알림·대시보드·미디어의 기존 배치를 유지하며, 미디어 내부의 기존 앱 목록도 유지한다.

## 기능 상태

| 기능 | 상태 | 실제 확인할 내용 |
|---|---|---|
| 원본 배경·모니터별 바탕화면 | 구현 완료, 실제 환경 검증 필요 | 해상도·배율·모니터 연결/분리 |
| XDG Desktop 파일, Home/Trash/Projects | 구현 완료, 실제 환경 검증 필요 | 사용자 파일·아이콘·한글 이름 |
| 선택·더블클릭·다중 선택·드래그 위치 저장·메뉴 | 구현 완료, 실제 환경 검증 필요 | 실제 Wayland 포인터/키보드 |
| 파일 열기·복사/붙여넣기·잘라내기·이름 변경·휴지통 | 구현 완료, 실제 환경 검증 필요 | Nemo D-Bus, 충돌/권한 오류 대화상자 |
| 외부 앱과 파일 드래그 앤 드롭 | 부분 구현 | Qt URI drag/drop 연결. 다른 앱별 수락·클립보드 호환성은 실기 필요 |
| 하단 중앙 Dock·고정/해제/순서·상태·메뉴·창 선택 | 구현 완료, 실제 환경 검증 필요 | 창 생명주기·포커스·모니터별 레이어 |
| 실시간 창 미리보기 | 구현 완료, 실제 환경 검증 필요 | `hyprland-toplevel-export-v1`와 실제 GPU 캡처 |
| Dock 최소화/복원 | 구현 완료, 실제 환경 검증 필요 | 기존 Special Workspace 숨김/복원 재사용 |
| 앱 자체 최소화 버튼 | 부분 구현 | 공식 `window.minimize` 이벤트가 선언된 설치본에서만 연결. v0.55.0은 미지원 |
| 절반·네 사분면·상단 최대화·미리보기·드래그 복원 | 구현 완료, 실제 환경 검증 필요 | 실제 CSD 드래그·포인터 해제·최소 크기 제약 |

여기서 실제 환경은 사용자의 Arch Hyprland 세션이다. Windows Qt UI 시험이나 WSL의 파일/Lua 시험을 실제 Wayland 검증으로 취급하지 않는다.

## 적용

새 설치는 기존 `install.sh`의 `setup-desktop-ux` 단계로 설치된다. 추가 패키지·AUR·root 권한·외부 플러그인이 필요하지 않다. 이미 설치된 Nemo/GVfs, Python GObject, wl-clipboard, Quickshell과 Lua를 재사용한다.

변경본을 노트북으로 받은 뒤 기존 환경에서는 아래 순서로 실행한다.

```bash
cd ~/projects/shittim
bash scripts/setup-desktop-ux.sh
hyprctl reload
systemctl --user restart shittim.service
bash scripts/verify-desktop-ux.sh
```

GTK 제목 표시줄 설정은 작업을 저장한 후 로그아웃·로그인하고 앱을 새로 열어 검사한다. 설치기가 앱을 강제 종료하거나 로그인 세션을 재시작하지 않는다. 기존 설치기의 설정/백업 정책을 유지한다.

다른 배경 데몬이나 `nemo-desktop`을 직접 실행하는 사용자 설정이 있다면 어느 프로그램이 바탕화면을 담당할지 먼저 정리한다. Shittim은 다른 프로그램을 자동으로 종료하지 않는다. 저장소의 현재 수집 설정에는 실행 중인 별도 배경 데몬 지시가 없다.

## 바탕화면 사용

- 한 번 클릭: 선택. Ctrl+클릭: 선택 추가/해제. 빈 곳 드래그: 영역 선택. 빈 곳 클릭: 해제.
- 더블클릭/Enter: 파일 기본 앱 또는 Nemo 폴더 열기. `.desktop` 파일은 직접 명령을 실행하지 않고 Nemo에서 처리한다.
- 드래그: 선택한 아이콘 위치 이동. 모니터 이름별 위치를 저장하고 화면 크기가 줄면 표시 영역에 맞춘다.
- Ctrl+A/C/X/V, F2, Delete: 전체 선택/복사/잘라내기/붙여넣기/이름 변경/휴지통 이동.
- 아이콘 우클릭: 파일 메뉴. 빈 곳 우클릭: 바탕화면 폴더 열기, 붙여넣기, 새 폴더, 새로고침.
- F5: 파일 목록/서비스 재시도. 파일 목록은 GIO 디렉터리 변경 감시로 갱신한다.

XDG Desktop 경로를 GLib에서 읽는다. 사용자가 바탕화면을 비활성화하여 HOME과 동일하게 설정한 경우 HOME 전체를 바탕화면 파일 목록으로 노출하지 않는다. Home/Trash/Projects 기본 바로가기는 삭제·잘라내기·이름 변경·복사 대상에서 보호한다. Projects는 실제 `~/projects` 또는 `~/Projects`를 사용하며, 둘 다 없으면 사용자가 열 때만 `~/projects`를 만든다. 숨김 파일은 표시하지 않는다. 한 번에 최대 4096개 항목을 읽는다.

일반 파일 열기는 GIO 기본 앱 연결, 폴더 열기는 `nemo --no-desktop`의 배열 인수로 처리한다. 파일 이름을 셸 명령에 삽입하지 않는다. 이름 변경/휴지통은 GIO를 쓰고 영구 삭제 명령은 제공하지 않는다. 복사/이동은 [Nemo의 실제 FileOperations 인터페이스](https://github.com/linuxmint/nemo/blob/master/data/dbus-interfaces.xml)의 `CopyURIs`/`MoveURIs`에 위임한다. Shittim이 대용량 디렉터리 복사를 재구현하지 않으며, 진행·이름 충돌·작업 중 I/O 오류는 Nemo가 표시한다. 서비스 호출 실패는 바탕화면 하단에 표시한다.

파일 클립보드는 `x-special/gnome-copied-files` 형식으로 다른 GTK 파일 관리자와 공유한다. 외부 드롭은 로컬 `file:` URI만 받으며 기본 복사다. 폴더로 드롭하면 그 폴더가 대상이다. 이동은 명시적인 잘라내기/붙여넣기를 사용한다. 원격 URL·앱 명령 문자열을 파일 작업으로 실행하지 않는다. 자동 동기화 이전에 파일이 사라지면 작업 오류로 처리한다.

아이콘 위치는 `${XDG_STATE_HOME:-$HOME/.local/state}/shittim/desktop-layout.json`, 고정 앱은 `${XDG_CONFIG_HOME:-$HOME/.config}/shittim/dock.json`에 원자적으로 저장한다. 파일 권한은 0600이며 Git에 추가하지 않는다. 개인 Dock 설정의 다른 키와 실행 앱 클래스 매핑을 유지한다. 손상된 JSON은 덮어쓰지 않고 오류로 처리한다.

## Dock 사용

Dock은 모니터마다 하단 중앙 Top layer에 표시된다. 입력 영역은 실제 Dock/팝업에 한정하고 일반 창 위의 투명 영역이 클릭을 가로채지 않게 한다. 하단에는 Dock 본체 높이와 아래 여백만 작업 영역으로 예약하므로 최대화/타일링 창은 Dock 위에서 끝난다. 메뉴/미리보기를 열어도 예약 높이는 바뀌지 않는다. 해당 모니터의 현재 워크스페이스에 전체 화면 창이 있으면 숨긴다. 긴 앱 목록은 가로로 스크롤한다. 사용자가 직접 배치한 Floating 창은 예약 공간에 걸칠 수 있으며, 해당 창에서 `bash scripts/windows.sh fit` 또는 창 목록의 정렬 버튼으로 현재 작업 영역 안에 맞출 수 있다.

Dock 본체는 52px, 아이콘은 30px, 화면 하단 여백은 2px이다. Hyprland 창 바깥 여백은 4px로 줄인다. 미리보기/메뉴 공간을 포함한 투명 layer surface의 크기는 호버 때도 유지하며, Dock 전용 `no_anim` 규칙으로 컴포지터가 전체 표면을 늘이거나 움직이지 않게 한다. 포커스를 옮길 때 포인터가 창 중앙으로 이동하지 않도록 `cursor.no_warps`를 켠다. 두 Hyprland 정책은 `bash scripts/setup-desktop-ux.sh` 후 `hyprctl reload`로 반영한다.

Quickshell도 `Shittim-HUD` 아이콘 테마를 사용한다. Nemo의 공식 `system-file-manager` 이름과 일반 앱 대체 아이콘을 테마에 포함하며, 시스템 테마에서 찾지 못하면 저장소의 해당 SVG로 대체한다. 실제 앱 아이콘과 사용자 지정 파일 아이콘을 우선한다.

`fit`은 일반 Floating 창의 크기/위치를 보정하고, 최대화 창은 최대화를 다시 적용해 작업 영역을 갱신한다. 타일링 창은 컴포지터가 예약 영역을 반영하므로 그대로 유지한다. 전체 화면 창에서는 먼저 전체 화면을 해제하라는 안내를 출력한다. 앱 서비스의 일반 stderr 경고는 실행 실패로 표시하지 않으며, 실제 오류 응답이나 프로세스 종료는 계속 보고한다.

고정 앱 순서를 유지하면서 식별 가능한 실행 앱을 뒤에 추가한다. 설치된 앱 카탈로그와 `WindowState`를 기존 `MediaState`의 클래스 매칭 규칙으로 연결하고, 고정/실행 아이콘을 중복 생성하지 않는다. 실행 창 수는 최대 네 개의 점, 활성 앱은 시안 테두리, 모든 창이 숨겨진 앱은 어두운 아이콘과 계속 남는 실행 점으로 구분한다. 한 앱에 일반 창과 숨긴 창이 함께 있으면 미리보기에서 각각 표시한다.

- 좌클릭: 창이 없으면 실행, 한 개면 활성화/복원, 여러 개면 선택할 창 미리보기.
- 우클릭: 대상 창 선택, 복원/활성화, 최소화, 새 창, 닫기, 고정/해제. 여러 창일 때 메뉴의 드롭다운으로 대상을 먼저 고른다.
- 고정 앱 아이콘을 좌우로 끌어 순서를 바꾼다.
- 런처 또는 대시보드 Apps에서 앱 우클릭 → Dock에 고정/해제.
- Dock 끝의 설정 버튼 좌클릭 → Control Center, 우클릭 → 기존 App Launcher. 휴지통 버튼 → Nemo의 휴지통 열기.

새 창은 Desktop Entry의 `new-window` 액션이 있으면 사용하고, 없으면 기존 GIO 실행을 요청한다. 앱이 단일 인스턴스로 설계된 경우 별도 창 생성까지 강제하지 않는다. 앱 식별이 모호하거나 카탈로그에 없는 창은 잘못 연결하지 않고 기존 전체 창 목록에서 관리한다. 닫기는 선택한 한 창의 정상 종료 요청이다.

호버 400ms 후 미리보기를 열고 Dock↔미리보기 이동에는 350ms 유예를 둔다. [Quickshell ScreencopyView](https://quickshell.org/docs/v0.1.0/types/Quickshell.Wayland/ScreencopyView/)의 `captureSource`/`live`/`hasContent`는 실제 v0.3.2 소스에서도 확인했다. 창별 Wayland Toplevel을 캡처하며, 전체 모니터를 잘라 만든 가짜 썸네일을 사용하지 않는다. 팝업이 보이는 동안만 live를 켠다. 프로토콜 미지원·XWayland 매핑 부재·숨긴 창의 버퍼 부재 등에서는 실제 앱 아이콘/창 제목과 사용 불가 문구로 대체한다. 캡처 파일이나 창 이미지를 디스크에 저장하지 않는다.

## 최소화 지원 범위

Kitty를 포함한 공통 제목 표시줄·버튼이 필요하면 [선택 설치형 hyprbars 연동](titlebars.md)을 사용한다. 아래 내용은 외부 플러그인 없는 기본 환경의 앱 자체 버튼 지원 범위다.

기존 `WindowState`와 `window-service.py`의 Special Workspace 이동/원래 워크스페이스/전체 화면 상태 복원을 재사용한다. 새 별도 숨김 모델을 만들지 않는다. Dock·기존 창 목록·미디어 앱 목록이 같은 창 상태를 읽는다.

확인한 Hyprland v0.55.0은 앱 CSD의 최소화 요청을 외부에서 사용할 Lua/IPC 이벤트로 전달하지 않는다. 최신 공식 소스에는 [window.minimize Lua 이벤트](https://github.com/hyprwm/Hyprland/blob/main/src/config/lua/LuaEventHandler.cpp)가 있다. 설치기는 실제 `Hyprland` 실행 파일에 그 정확한 이벤트 선언 문자열이 있는지 검사하고, 있을 때만 콜백을 생성한다. 지원하지 않는 버전에 알 수 없는 `hl.on` 이벤트를 등록하지 않는다. 선언 문자열 검사는 실제 앱의 요청 전달 검증을 대신하지 않으며 결과를 설치/검증 출력에 표시한다. Shittim 제목 표시줄(hyprbars)은 자기 막대 위의 클릭을 소비하므로(`info.cancelled`) `desktop-snap.lua`의 `mouse:272` 바인드는 제목 표시줄 끌기를 보지 못한다. v0.57.0용 수정본은 끌기 시작·끝을 플러그인 이벤트 `shittim.titlebar_drag`(창, 시작 여부)로 알리고, `hl.plugin.hyprbars.shittim_drag_events`가 있을 때만 Lua가 이를 구독한다. v0.57.0은 설정을 다시 읽을 때마다 Lua 이벤트 처리기를 새로 만들면서 이미 등록된 플러그인 이벤트를 연결하지 않으므로(`ConfigManager.cpp:533`, `LuaEventHandler.cpp:163`) 수정본이 `config.reloaded`마다 이벤트를 다시 등록한다. hyprbars의 `inputIsValid()`는 커서 아래에 top 레이어(스냅 미리보기·상단 바)가 있으면 입력을 버리므로, 끌기 중 버튼을 떼면 이 검사보다 먼저 끌기를 끝낸다. 참고 저장소 4곳(caelestia·ViegPhunt 2곳·43PR)에는 가장자리 스냅 구현이 없고 `SUPER + 끌기` 이동만 있다. v0.55·0.56 수정본에는 이 이벤트가 없어 제목 표시줄 끌기는 스냅되지 않는다. v0.57.0도 앱 CSD의 최소화 요청은 적용하지 않는다. `window.minimize`는 외부 작업 표시줄(`ForeignToplevelWlr`) 요청에서만 socket2 `minimized`와 함께 발생하므로 `WindowState`가 500 ms 안의 같은 요청을 한 번만 처리한다.

이벤트가 있으면 CSD 최소화 요청을 동일한 큐/숨김 코드로 전달하고 GTK 최소화 버튼도 활성화한다. 없으면 GTK에는 동작 가능한 최대화/닫기만 구성하며 Dock 메뉴/창 목록의 최소화가 대안이다. 이전 버전에서 CSD 최소화까지 지원하려면 컴포지터 업데이트 또는 버전에 맞는 Hyprland 플러그인이 필요하다. 바이너리 ABI 의존 플러그인이나 컴포지터 패치를 자동 설치하지 않는다. Quickshell 숨김 버튼만 되는 환경을 앱 자체 최소화 완료라고 보고하지 않는다.

## 스냅

`config/desktop-snap.lua`는 공식 v0.55.0의 `hl.bind`, 비소비/투명/수정 키 무시 옵션, `hl.timer`, Window의 실제 위치/크기, 모니터/포인터 조회 API를 쓴다. 보조 키 없는 원래 앱 제목 표시줄 드래그를 유지한다. 포인터를 누른 동안만 40ms 간격으로 메모리 내 상태를 읽고, 일반 클릭/텍스트 선택처럼 창이 움직이지 않으면 스냅하지 않는다. 크기가 바뀌는 테두리 리사이즈, 전체 화면 게임, 고정/그룹/특수 워크스페이스는 제외한다. 매 프레임 별도 프로세스를 만들지 않고 스냅 영역이 바뀌거나 드롭할 때만 IPC를 보낸다.

왼쪽/오른쪽은 절반, 네 모서리는 사분면, 상단은 Shittim의 창별 최대화다. `window-service.py`가 `hyprctl -j monitors`의 논리 작업 영역·예약 공간·배율·회전·음수 좌표를 사용한다. Dock 여유는 모니터의 실제 예약 공간에 포함하며 스냅에서 이중으로 빼지 않는다. 실제 창 적용은 포인터를 놓았을 때만 수행한다. Overlay layer의 시안 미리보기는 빈 입력 마스크를 써서 드래그를 방해하지 않는다.

절반·사분면 스냅 전 크기는 Lua 세션의 창 주소별 메모리에 보관하고 다음 드래그에서 복원한다. 창 종료 시 제거하고 설정 재로딩 후에는 이 스냅 이력을 유지하지 않는다. 최대화 복원 기록은 창의 전용 태그에 보관하므로 Shittim 재시작·설정 재로딩 뒤에도 남고 창 종료 때 사라진다. 최대화된 창을 드래그하면 그 창의 원래 크기를 포인터 아래로 복원한다. 앱의 최소 크기는 Hyprland가 적용하므로 목표 사분면보다 작은 크기를 강제하지 않는다. 원래 앱의 드래그가 컴포지터에 전달되는 시점·포인터 바인딩 공존·최소 크기·최대화 해제는 실제 앱에서 반드시 검증한다.

## 실기 검사

```bash
cd ~/projects/shittim
bash scripts/verify-desktop-ux.sh
quickshell ipc --path "$PWD/shell/shell.qml" call desktop status
quickshell ipc --path "$PWD/shell/shell.qml" call snap status
```

1. 재로그인 후 원본 배경과 하단 Dock, Home/Trash/Projects가 나오는지 확인한다.
2. Nemo에서 실제 XDG 바탕화면 폴더를 연다. 임시 파일/폴더를 만들고 Shittim 목록에 자동 반영되는지, 단일/다중 선택·더블클릭·위치 이동·Shittim 재시작 후 위치 복원을 확인한다.
3. **임시 파일만** 써서 복사/붙여넣기·잘라내기·이름 변경·휴지통 이동을 시험한다. Nemo→바탕화면, 바탕화면→Nemo 드롭과 동일 이름 충돌/읽기 전용 대상 오류를 확인한다.
4. 런처 우클릭으로 앱 고정, Dock에서 순서 이동/고정 해제, 재시작 후 유지, 여러 창 구분·호버 이동·우클릭 대상 선택·새 창·닫기를 확인한다.
5. Dock 메뉴로 숨기고 점/아이콘 상태를 확인한 뒤 좌클릭으로 복원한다. 다른 워크스페이스·다른 모니터·여러 창·Shittim 재시작 후에도 확인한다.
6. 설치 출력에 앱 최소화 이벤트 선언이 있다고 나온 환경에서만 Nemo/Chrome 자체 최소화 버튼을 별도로 검사한다. 이벤트 미지원 환경은 미지원으로 기록한다.
7. Nemo/Chrome 제목 영역을 **키보드에서 손을 뗀 채** 양옆/네 모서리/상단으로 끈다. 드래그 중 미리보기만, 놓으면 배치되는지 확인한다. 영역을 벗어나면 사라지는지, 스냅된 창을 다시 끌면 원래 크기로 돌아오는지 확인한다.
8. 최대화/전체 화면을 구분하고 전체 화면 게임에서 Dock이 숨는지 확인한다. 모니터별 배율·연결/분리·회전·작은 화면·큰 최소 크기 앱을 검사한다.
9. Top Bar·워크스페이스·런처·Control Center·알림·대시보드·미디어·Alt+Tab·한글 입력·자동 실행을 확인한다.

GTK/Nemo 내부 레이아웃을 이미지처럼 재작성하지 않았으며, 기존 HUD CSS·아이콘·폰트 설정을 유지한다. 새 파일 관리자를 추가하지 않는다.

자동 검사 결과: Arch WSL Python 121개, Windows Qt QML 92개 통과. Python에는 실제 GIO 임시 파일 조회·이름 변경·휴지통 이동·변경 감시·프로세스 종료와 실제 Lua 인터프리터의 드래그/스냅 계산 검사가 포함된다. Bash 문법, 전체 QML 파싱, 로컬 import 경계, 원본 PNG 해시도 확인했다. Qt의 실제 DesktopView/DockView를 테스트 데이터로 렌더링해 배치와 잘림을 확인했다. 이 렌더링은 Arch 앱/창 캡처가 아니다. Linux 메타데이터를 Windows qmllint로 읽을 때 PanelWindow 생성성·Screen 크기 등의 기존 플랫폼 차이 경고가 남으므로 이를 실제 Quickshell 실행 성공으로 보고하지 않는다.

## 파일

- 배경: `assets/wallpapers/shittim-lake.png`.
- 바탕화면: `scripts/desktop-service.py`, `shell/services/DesktopState.qml`, `shell/components/DesktopSurface.qml`, `shell/components/desktop/{DesktopModel,DesktopView}.qml`.
- Dock: `shell/services/DockState.qml`, `shell/components/DesktopDock.qml`, `shell/components/dock/DockView.qml`.
- 스냅: `config/desktop-snap.lua`, `shell/services/SnapState.qml`, `shell/components/SnapPreview.qml`, 기존 `scripts/window-service.py` 확장.
- 기존 연결: `scripts/{desktop-ux.py,dock-settings.py,launcher-service.py,verify-desktop-ux.sh}`, `shell/services/{LauncherState,WindowState}.qml`, `shell/services/qmldir`, `shell/ui/Theme.qml`, `shell/shell.qml`, 런처/대시보드의 고정 메뉴.
- 검사: `tests/test_desktop_surface.py`, `tests/test_desktop_snap.py`, 관련 기존 Python 검사와 `shell/tests/tst_desktop.qml`.
