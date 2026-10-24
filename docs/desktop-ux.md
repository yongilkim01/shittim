# Floating Desktop / Nemo HUD

후속 바탕화면·독립 Dock·스냅 확장과 최신 최소화 지원 범위는 [바탕화면·Dock 통합](desktop-shell.md)을 따른다. 아래 내용은 초기 Floating/Nemo 기반과 복구 방법을 기록한다.

일반 창을 Floating으로 열고, 앱의 CSD 제목 표시줄과 Hyprland 테두리 조절을 사용한다. Top Bar·Control Center·런처·알림·대시보드·미디어·Dock의 기존 배치와 크기는 유지한다.

## 적용

새 설치는 기존 `./install.sh`에 `setup-desktop-ux` 단계가 포함된다. 기존 환경에서는 다음 순서로 적용한다. 사용자의 원본 `dotfiles/hypr/hyprland.lua`와 `shittim-base.lua`는 편집하지 않는다.

```bash
cd ~/projects/shittim
bash scripts/setup-desktop-ux.sh
hyprctl reload
systemctl --user restart shittim.service
bash scripts/verify-desktop-ux.sh
```

GTK CSD 환경은 새 앱·D-Bus 활성화에도 전달되어야 한다. 작업을 저장하고 한 번 로그아웃·로그인한 뒤 Nemo·Chrome을 새로 열어 검사한다. 설치 중 자동 로그아웃, Nemo 강제 종료, 브라우저 프로필 변경은 하지 않는다. 기존 패키지의 GTK·Adwaita·GSettings·python-gobject·Lua를 사용하며 추가 AUR, 외부 테마 코드, 플러그인 빌드를 요구하지 않는다.

설치 전 변경 계획:

```bash
./install.sh --dry-run
bash scripts/setup-desktop-ux.sh --dry-run
bash scripts/verify-desktop-ux.sh --dry-run
```

## 창 배치 정책

`config/window-management.lua`를 사용자 설정 뒤의 `shittim-windows.lua`로 적용한다. [Hyprland 0.55 창 규칙](https://wiki.hypr.land/0.55.0/Configuring/Basics/Window-Rules/)의 정적 `float`, `size`, `center`를 사용한다. 시작 시 이미 Floating인 창, 전체 화면 상태, 클라이언트 전체 화면 상태, 콘텐츠 유형을 검사한다. 일반 창의 기본 크기는 모니터 논리 크기의 78% × 72%다. 자동 Floating 대화상자·부모 팝업의 크기와 배치는 기존 컴포지터 처리를 사용한다. 앱의 최소 크기는 컴포지터/앱 제약을 따른다.

창 규칙은 시작 시 한 번 적용하므로 이후 특정 창을 Tiling으로 전환할 수 있다. 앱의 전체 화면·최대화 요청을 억제하거나 전체 화면 상태를 0으로 강제하는 규칙은 추가하지 않는다. 명시적인 `game` 콘텐츠 창도 일반 창 크기 규칙에서 제외한다. 게임이 콘텐츠 유형이나 전체 화면 의도를 늦게 알리는 경우에는 실제 게임에서 확인해야 한다.

클릭 포커스(`input.follow_mouse=0`), 얇은 시안 활성 테두리, 테두리 크기 조절 및 커서, 모니터/창 사이 자석 정렬을 설정한다. `general.snap`은 **가까운 경계에 붙이는 정렬**이다. 화면 절반·사분면으로 자동 크기 변경하는 Windows식 Aero Snap은 구현하지 않았다.

모니터 사이 드래그를 허용하기 위해 창을 한 모니터 안에 영구 고정하지 않는다. Dock/창 목록에서 활성화할 때 모든 모니터 작업 영역 밖에 있는 일반 Floating 창은 다시 화면 안으로 정렬한다. 창 목록의 정렬 버튼은 바의 예약 영역·배율·회전·음수 좌표를 반영해 크기/위치를 복구한다. 전체 화면 창은 이 보정을 적용하지 않는다. 앱이 강제하는 최소 크기 때문에 작은 화면에서 완전히 맞추지 못할 수 있다.

## 마우스 및 키보드

| 조작 | 동작 |
|---|---|
| Nemo/Chrome 자체 제목 표시줄 드래그 | 앱이 지원하는 CSD 이동, 보조 키 불필요 |
| 제목 표시줄 더블클릭/최대화 버튼 | 앱의 최대화 요청, 이전 Floating 크기로 복원 |
| 창 테두리/모서리 드래그 | Hyprland 크기 조절, 보조 키 불필요 |
| 창 내부 클릭 | 창 포커스 및 최상단 활성화 |
| 상단 바 음표 아이콘 **우클릭** | 전체 열린 창 목록, 숨긴 창 포함 |
| Dock 앱 아이콘 우클릭 | 해당 앱의 여러 창 목록 |
| 창 목록의 `−` / 눈 아이콘 | 숨김 / 복원 |
| 창 목록의 사각형 / 전체 화면 / 격자 / 정렬 / X | 최대화·복원 / 전체 화면 / Floating·Tiling / 화면 안 정렬 / 정상 닫기 |
| Dock 앱 아이콘 클릭 | 해당 앱의 최근 창 복원·활성화, 창이 없으면 기존 GIO 런처로 실행 |
| Alt+Tab / Alt+Shift+Tab | 최근 창 순서 전환; Alt를 놓으면 활성화 |
| Super+Tab | 열린 창 목록, Enter 선택 / Escape 취소 |
| Super+H | 현재 창 숨김 |
| Super+↑ | 최대화/복원 |
| Super+F | 전체 화면 전환 |
| Super+C | 창 닫기 |
| Super+V | 해당 창 Floating/Tiling 전환 |
| Super+Ctrl+Home | 현재 Floating 창을 화면 안으로 정렬 |
| Super+왼쪽/오른쪽 드래그 | 이동/크기 조절 보조 기능 |

`shittim-windows.lua`는 이 정책에 필요한 키만 명시적으로 다시 바인딩한다. 기존 Super+↑ 방향 포커스는 최대화로 바뀐다. 원래 사용자 설정은 백업과 기본 파일에 유지한다. 다른 워크스페이스/모니터의 창을 선택하면 그 창을 활성화한다. 알림·런처·설정·미디어 패널과 새 창 목록은 동시에 포커스를 잡지 않는다. Alt 해제 이벤트가 세션에서 전달되지 않으면 Enter로 확정할 수 있으며 노트북에서 양쪽 Alt와 역방향 전환을 검사한다.

Dock은 기존 고정 앱 순서를 유지하고 식별 가능한 실행 앱을 뒤에 표시한다. 활성 앱은 기존 HUD 테두리 색으로 구분한다. Desktop Entry ID를 클래스와 무조건 동일시하지 않고 기존 `StartupWMClass`, 앱 ID, 사용자 `windowClasses` 매핑 및 모호성 제외 규칙을 재사용한다. 클래스가 모호하거나 등록 앱을 찾을 수 없는 창은 잘못된 아이콘에 연결하지 않고 전체 창 목록에서 관리한다.

## 숨김/복원 및 제목 표시줄 제한

숨김은 실제 `window.move({workspace=...,follow=false})`로 창마다 별도의 `special:shittim-hidden-<원래 워크스페이스>-<내부 FS>-<클라이언트 FS>-<주소>`에 옮긴다. 일반 워크스페이스로 복원하고 포커스·Z 순서를 올린다. 원래 워크스페이스가 사라졌으면 현재 포커스된 모니터의 일반 워크스페이스를 사용한다. 제목·파일명·탭 정보 등을 디스크에 저장하지 않는다. Shittim 재시작 뒤에도 컴포지터의 실제 특수 워크스페이스 이름에서 복원 정보를 읽는다. 고정(pin)·그룹·사용자 특수 워크스페이스 창은 그룹/배치를 손상시키지 않도록 숨김을 거부한다.

최대화(`mode="maximized"`)와 전체 화면(`mode="fullscreen"`)은 [0.55 공식 디스패처](https://wiki.hypr.land/0.55.0/Configuring/Basics/Dispatchers/)로 별도로 처리한다. 닫기는 `window.close()`의 정상 종료 요청이며 SIGKILL하지 않는다. 모든 제어는 검증한 16진 창 주소와 고정된 동작만 배열 인수로 `hyprctl`에 전달한다. 앱 제목을 Lua나 셸 명령으로 결합하지 않는다. `follow=false`, `release`, `non_consuming`, `ignore_mods`는 공식 v0.55.0 Lua 구현에서도 확인했다.

**앱 자체 최소화 버튼은 공통 지원 완료가 아니다.** 확인한 Hyprland v0.55.0의 [`CWindow::onUpdateState`](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/desktop/view/Window.cpp)는 XDG/XWayland의 전체 화면·최대화 요청만 처리하고 `requestsMinimize`를 적용하지 않는다. [`ForeignToplevelWlr`](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/protocols/ForeignToplevelWlr.cpp)의 `minimized` IPC 이벤트는 지원하므로 해당 이벤트는 Shittim 숨김/복원에 연결한다. 이를 GTK/Chrome CSD 버튼의 최소화 이벤트와 혼동하지 않는다. Nemo용 GTK 제목 표시줄은 `:maximize,close`로 설정하며, 실제 숨김 버튼은 Shittim 창 목록에서 제공한다. Chrome 자체 최소화 버튼의 무응답이 이 제한에 해당할 수 있다.

`GTK_CSD=1`과 GTK 제목 표시줄 설정은 **GTK가 자체 장식을 지원하는 창**에 적용한다. Chrome/Electron은 자체 탭/제목 영역과 Ozone 설정에 따라 다르며 브라우저 개인 설정을 임의 편집하지 않는다. Qt 앱은 각 앱의 CSD 지원을 따른다. XWayland의 SSD 전용 앱이나 Kitty처럼 자체 제목 표시줄이 없는 앱에 Quickshell이 일반적인 제목 표시줄을 강제로 붙이지 않는다. 창 위에 입력을 가로채는 가짜 제목 표시줄 오버레이도 설치하지 않는다. 이러한 앱에서도 보조 키 없는 테두리 조절, Shittim 창 목록의 숨김·최대화·닫기 버튼을 사용할 수 있다. 공통 제목 표시줄 드래그까지 제공하려면 별도 Hyprland 장식 플러그인/컴포지터 지원이 필요하며 이번에는 만들지 않았다.

## Nemo / GTK HUD

Nemo의 GTK3를 중심으로 설치된 Adwaita-dark 기반에 `assets/gtk/hud.css`를 적용한다. 배경 `#020f15`, 콘텐츠 `#041923`, 강조 `#00d9f5`, 얇은 청록 구분선, 어두운 사이드바/툴바/선택 색을 사용한다. GTK3/4의 `settings.ini`는 관련 키만 병합하고 사용자 CSS는 유지한 채 표시된 HUD 블록만 추가·갱신한다. [GTK3](https://docs.gtk.org/gtk3/class.Settings.html), [GTK4](https://docs.gtk.org/gtk4/class.Settings.html)의 설정 로딩 방식에 맞춘다.

글꼴은 Hack Nerd Font Mono 10pt와 기존 Fontconfig의 D2Coding 한글 폴백을 사용한다. Nemo 아이콘 보기 크기는 `standard`, 홈/새 폴더 버튼은 켜고 컴퓨터/새로고침 버튼은 정리한다. 실제 설치된 GSettings 스키마와 키·허용값·쓰기 권한을 확인한 뒤 적용하고 현재 값을 읽어 검증한다. 스키마가 없는 구성은 건너뛰며 출력으로 구분한다.

`assets/icons/Shittim-HUD`는 직접 작성한 MIT 라이선스 SVG 폴더·홈·다운로드·사진·문서·휴지통과 기본 파일 형식 아이콘이다. 사용자 XDG 데이터 디렉터리에 파일별 심볼릭 링크로 설치한다. 없는 아이콘은 설치된 Adwaita/hicolor를 상속한다. 전체 외부 아이콘 팩을 복사하지 않는다. 실제 사진 미리보기는 Nemo의 기존 썸네일 동작을 따른다.

GTK4 및 포털 파일 선택기도 같은 색/폰트 정책을 사용한다. libadwaita나 자체 스타일을 강제하는 앱의 모든 위젯까지 동일한 외형을 보장하지 않는다. GTK CSS만으로 Nemo의 레이아웃을 원본 HUD 패널처럼 절단하거나 기능을 재배치하지 않는다. 파일 작업 코드를 수정하지 않으며 완전한 HUD 파일 관리자는 별도 개발 범위다.

## 백업 및 복구

기존 GTK 파일·아이콘 링크·Hyprland 진입 파일은 원래 설치기의 `~/.local/state/shittim/backups/<설치 시각>/...`에 보존한다. 변경할 GSettings의 원래 사용자 값/미설정 상태도 **적용 전에** 같은 백업 트리의 `desktop-gsettings.json`에 저장한다. 백업은 저장소 밖에 두며 자동 Git 추가하지 않는다. 재실행 시 내용이 같으면 파일 백업이 중복 생성되지 않는다.

Floating 정책을 되돌릴 때 실행한다. 생성 정책을 이동하므로 원본 사용자 Lua가 다음 reload부터 적용된다. 숨긴 창은 먼저 창 목록에서 복원한다.

```bash
mv ~/.config/hypr/shittim-windows.lua ~/.config/hypr/shittim-windows.lua.disabled
hyprctl reload
```

다시 적용하려면 `bash scripts/setup-desktop-ux.sh`를 실행한다. 이전 GTK 파일은 설치 출력에 나온 해당 백업 파일을 확인하고 원래 경로로 복사한다. 사용자 CSS의 `/* >>> Shittim HUD >>> */` ~ `/* <<< Shittim HUD <<< */` 블록만 제거해도 HUD 덧씌우기를 해제할 수 있다.

GSettings 복구는 출력된 실제 백업 경로를 지정한다. 아래 `<설치 시각>` 등의 경로는 사용자의 백업 위치로 바꾼다.

```bash
python3 scripts/desktop-ux.py restore-gsettings "$HOME/.local/state/shittim/backups/<설치 시각>/desktop-gsettings.json"
```

XDG_CONFIG_HOME/XDG_DATA_HOME/XDG_STATE_HOME을 지정한 환경에서는 각 경로를 따른다. 아이콘 테마·설정도 사용자 데이터 디렉터리 밖으로 추측해서 쓰지 않는다.

## 실제 Arch 검사

```bash
cd ~/projects/shittim
bash scripts/verify.sh
bash scripts/verify-desktop-ux.sh
hyprctl -j clients
hyprctl -j monitors
```

`clients`에는 제목/경로가 포함될 수 있으므로 원시 출력을 Git에 올리지 않는다. `verify-desktop-ux.sh`는 설정/아이콘/GSettings와 Hyprland 설정 오류, Shittim 창 개수만 점검하며 앱 내용은 출력하지 않는다.

1. 새 로그인 후 Kitty 3개, Nemo, Chrome을 열어 자동 분할 없이 겹치는지 확인한다. 이미 열려 있던 Tiling 창은 Super+V로 전환한다.
2. Nemo/Chrome의 제목/탭 빈 영역을 **보조 키 없이** 드래그한다. 가장자리·모서리를 드래그해 커서와 크기 조절을 검사한다. 더블클릭/최대화 버튼으로 이전 위치·크기가 복원되는지 확인한다.
3. 음표 아이콘 우클릭 → 창 목록의 `−`로 숨긴다. Dock에서 앱을 클릭해 원래 워크스페이스·모니터·위치로 복원되는지 확인한다. 다른 창이 같은 앱이면 Dock 우클릭으로 해당 창을 고른다.
4. 숨긴 상태에서 `systemctl --user restart shittim.service` 후 목록과 Dock에서 다시 복원한다. 그룹·고정 창을 숨기려 하면 실패 안내가 나오는지 확인한다.
5. Alt+Tab, Alt+Shift+Tab, 좌/우 Alt 해제, Enter, Escape, 외부 클릭을 검사한다. Top Bar·런처·알림·설정·대시보드·미디어를 차례로 열어 포커스 충돌을 확인한다.
6. 창 목록/단축키로 최대화와 전체 화면을 각각 시험한다. 실제 전체 화면 게임, 다중 모니터 이동, 서로 다른 배율/회전, 모니터 분리 후 창 복구는 해당 하드웨어에서 검사한다.
7. Nemo의 폴더/형식 아이콘, 툴바/사이드바, 선택 색, 한글 파일명을 확인한다. 임시 폴더에서 복사·이동·삭제, 이미지/PDF 열기, 브라우저 파일 선택기를 검사한다.

정적 검증은 실제 Hyprland의 포커스·마우스/CSD 이벤트나 GTK/Nemo 렌더링 성공을 대신하지 않는다. Windows에서는 새 창 목록 QML을 테스트 데이터로 렌더링할 수 있지만 이를 노트북 실제 창 캡처로 보고하지 않는다.

검사 결과: Arch WSL의 Python 테스트 110개, Windows Qt의 QML 테스트 87개 통과. Bash/QML 구문, 로컬 import 경계, SVG 19개 XML도 검사했다. GSettings는 임시 스키마·메모리 백엔드에서 실제 읽기/변경/백업/복구를 확인했다. Linux 타입 메타데이터를 Windows qmllint에서 읽을 때 PanelWindow 생성성, Screen의 크기, 기존 UntypedObjectModel.values 경고가 남으므로 이를 실제 Quickshell 세션 로딩 검증으로 대체하지 않는다. 이 환경에는 GTK 런타임이 없어 GTK CSS의 실제 파싱·Nemo 렌더링은 노트북에서 확인해야 한다.

## 변경 파일

- 정책/설치: `config/window-management.lua`, `scripts/desktop-ux.py`, `scripts/setup-desktop-ux.sh`, `scripts/verify-desktop-ux.sh`, `scripts/config-tool.py`, `scripts/session-services.sh`, `scripts/verify.sh`, `install.sh`.
- 창 관리: `scripts/window-service.py`, `scripts/windows.sh`, `shell/services/WindowState.qml`, `shell/components/WindowManager.qml`, `shell/components/windows/{WindowModel,WindowView}.qml`, `shell/shell.qml`, `shell/services/qmldir`.
- 기존 연결: `shell/services/MediaState.qml`, `shell/components/{TopBar,AppMediaControls}.qml`, `shell/components/media/{MediaView,MediaButton}.qml`. 기존 패널 레이아웃은 유지하고 창 상태/우클릭 기능만 연결한다.
- 테마: `assets/gtk/hud.css`, `assets/icons/Shittim-HUD/index.theme`, `assets/icons/Shittim-HUD/scalable/{places,mimetypes}/*.svg`.
- 검사: `tests/test_window_service.py`, `tests/test_desktop_ux.py`, `shell/tests/{tst_windows,tst_media}.qml`, README와 이 문서.
