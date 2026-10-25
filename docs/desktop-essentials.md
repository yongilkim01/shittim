# Desktop Essentials

기존 HUD 레이아웃과 자동 실행을 유지하면서 기본 앱·파일 연결·Wayland 유틸리티를 구성한다. 실제 노트북 설정을 Windows에서 읽거나 패키지를 설치하지 않았다. 아래 자동화는 Arch Linux에서 사용자가 실행할 때 적용된다.

## 앱과 패키지

| 역할 | 공식 패키지 | Desktop Entry |
|---|---|---|
| 파일 관리자 | 기존 Quickshell·python-gobject / 보조 nemo, gvfs, udisks2 | org.shittim.Files.desktop |
| PNG/JPEG/WebP/GIF | swayimg | swayimg.desktop |
| PDF | zathura, zathura-pdf-mupdf | org.pwmt.zathura.desktop |
| 동영상·음악·MPRIS | vlc, vlc-gui-qt, vlc-plugin-ffmpeg, vlc-plugin-dbus | vlc.desktop |
| 수동 잠금 | hyprlock | 전용 스크립트 |
| 캡처 | 기존 grim + slurp | 전용 스크립트 |
| 포털 | xdg-desktop-portal, 기존 Hyprland/GTK 백엔드 | 세션 D-Bus |
| X11 앱 호환 | xorg-xwayland | 필요한 앱의 호환 실행 |
| 클립보드 | 기존 wl-clipboard + cliphist | 기본 수집 꺼짐 |
| 브라우저 | **AUR google-chrome** | google-chrome.desktop |

Swayimg의 [지원 형식](https://github.com/artemsen/swayimg)과 [Arch 빌드 의존성](https://archlinux.org/packages/extra/x86_64/swayimg/)에서 JPEG·PNG·GIF·WebP를 확인했다. imv는 이번 구성에 추가하지 않는다. VLC는 [Qt GUI](https://archlinux.org/packages/extra/x86_64/vlc-gui-qt/), [FFmpeg 모듈](https://archlinux.org/packages/extra/x86_64/vlc-plugin-ffmpeg/), [D-Bus 모듈](https://archlinux.org/packages/extra/x86_64/vlc-plugin-dbus/)을 명시했다. mpv의 MPRIS 플러그인을 가정하지 않는다.

기존 설치의 Dolphin은 제거하지 않는다. 기본 파일 관리자는 [Shittim Files](files.md)이며 Nemo를 파일 작업 보조로 사용한다. 기본 Dock은 Shittim Files·Kitty·Chrome·VLC·Swayimg·Zathura다. 첫 등록 때 개인 Dock의 Nemo 고정만 새 앱으로 이관하고 백업하며 나머지 설정은 유지한다. 개인 목록을 쓴다면 필요한 Desktop Entry ID를 직접 추가한다. App Launcher와 App Dock은 기존 GIO 카탈로그·실행·아이콘·창 매칭을 그대로 공유한다.

Nemo는 전체 Cinnamon 데스크톱을 설치하거나 `nemo-desktop`을 자동 실행하지 않는다. GVfs와 udisks2는 휴지통·사용자 마운트를 지원하고 기존 Polkit 에이전트가 권한 요청을 처리한다. 장치 자동 마운트나 네트워크 공유용 선택 모듈을 강제로 켜지 않는다. 실제 이동식 장치는 Nemo에서 사용자가 열고 안전하게 해제해 확인한다.

## 설치와 Chrome

```bash
cd ~/projects/shittim
./install.sh --dry-run --with-chrome
./install.sh --with-chrome
```

공식 패키지를 전체 업그레이드 후 설치하고, 선택한 Chrome을 설치한 다음 기존 링크·자동 실행과 새 기본 데스크톱을 구성한다. 기존 로그인 비밀번호·Hyprland·입력기·오디오 자동 실행은 유지한다. 설치 전체를 sudo로 실행하지 않는다.

Chrome 설치는 선택적이다. `--with-chrome`이 없으면 건너뛰고 정확한 설치 명령을 안내한다. 이미 `google-chrome` 패키지가 있으면 재설치하지 않는다. 기존 `yay`가 있으면 사용자 확인 후 `yay -S --needed -- google-chrome`을 사용한다. 없으면 AUR 저장소를 사용자 캐시의 새 디렉터리에 Clone하고 커밋과 추적 파일을 **실행하지 않고 표시**한다. 검토 후 확인해야만 `base-devel`을 설치하고 일반 사용자로 `makepkg -si`를 실행한다. helper 설치·원격 스크립트 파이프 실행·`--noconfirm`·비대화형 자동 승인은 하지 않는다. Chrome 프로필과 사용자 데이터는 건드리지 않는다.

나중에 Chrome만 추가했다면 파일 연결도 갱신한다:

```bash
bash scripts/install-chrome.sh
bash scripts/setup-desktop.sh
```

Chrome이 없거나 사용자가 AUR 설치를 거절하면 Chrome 연결을 새로 만들지 않는다. 다른 브라우저로 몰래 대체하지 않는다. 설치 중 공식 패키지명·저장소를 `pacman -Si`로 다시 검사하므로 Arch 패키지가 바뀌면 AUR로 자동 전환하지 않고 해당 이름을 보고한다.

## 기본 앱·백업

설치된 GIO Desktop Entry만 MIME에 등록한다. Swayimg처럼 `NoDisplay=true`인 앱도 파일 연결에는 사용할 수 있으므로 설치된 앱으로 인정하며, 런처 목록의 숨김 정책은 유지한다. `Hidden=true`인 항목은 제외한다. `~/.config/mimeapps.list`와 Hyprland 전용 `hyprland-mimeapps.list`의 해당 기본값만 갱신하고 다른 MIME·섹션 값은 유지한다. INI 정규화로 주석·공백이 달라질 수 있지만 원본 전체는 저장소 밖 `~/.local/state/shittim/backups/`에 백업한다. 재실행해 내용이 같으면 추가 백업하지 않는다. XDG_CONFIG_HOME/XDG_STATE_HOME을 사용하면 그 경로를 따른다.

HTTP·HTTPS·HTML·XHTML=Chrome, 폴더=Nemo, 이미지 4종=Swayimg, PDF=Zathura, MP4·Matroska·MP3·FLAC=VLC다. `desktop-tool.py verify`는 GIO 설치 여부와 실제 `xdg-mime query default` 결과를 검사한다. 별도 데스크톱의 사용자 정책이나 `BROWSER` 환경 변수가 xdg-open에 영향을 주면 실제 실행도 확인해야 한다.

## 단축키와 Lua

원본 `shittim-base.lua`와 수집된 `dotfiles/hypr/hyprland.lua`는 편집하지 않는다. 기존 진입 파일 마지막에서 별도 `shittim-desktop.lua`가 있으면 불러온다. 공식 0.55+의 [hl.bind / hl.unbind](https://wiki.hypr.land/Configuring/Basics/Binds/)와 이미 사용 중인 `hl.dsp.exec_cmd`만 사용한다.

공식 [Lua 바인딩 구현](https://github.com/hyprwm/Hyprland/blob/main/src/config/lua/bindings/LuaBindingsToplevel.cpp)과 [IPC 구현](https://github.com/hyprwm/Hyprland/blob/main/src/ipc/s1/Commands.cpp)을 함께 확인했다. Lua의 dispatcher/arg는 함수와 참조 ID일 수 있으므로 명령문과 비교하지 않는다. 생성 바인딩에 키·명령 해시를 담은 고유 `description`을 붙이고 실제 세션 검사에서는 이 표식을 확인한다. 처음의 설명 없는 Lua Super+E는 원본 소스에 단순한 기본 Dolphin/Nemo 연결이 확인될 때만 요청한 Nemo 연결로 전환한다. 다른 불투명 Lua 콜백은 사용자 충돌로 유지한다.

| 단축키 | 작업 |
|---|---|
| Super+B | Chrome: 기존 Shittim 창 매칭·활성화 우선, 없으면 기존 GIO 실행 |
| Super+E | xdg-open으로 홈 폴더 열기, 기본 연결 Nemo |
| Super+L | 전용 HUD Hyprlock 수동 잠금 |
| Print | 전체 캡처 저장·클립보드 복사 |
| Shift+Print | slurp 영역 선택 후 저장·복사, Escape는 취소 |
| Super+Shift+V | 선택적으로 수집한 세션 클립보드 기록 |

Hyprland 세션에서는 `hyprctl -j binds`를 읽어 충돌을 검사한다. 이미 관리 중인 정확한 명령과 알려진 Dolphin/Nemo 기본 Super+E만 교체한다. 다른 사용자 명령은 건너뛰고 알린다. TTY에서는 원본 Lua의 리터럴·단순 지역 변수 바인딩을 검사하며, 다른 Lua 파일을 포함하면 숨은 바인딩을 추측하지 않고 보수적으로 건너뛴다. 정적 분석은 임의 Lua 평가를 대신할 수 없으므로 로그인 후 `verify-desktop.sh`와 실제 단축키를 확인한다. `verify-desktop.sh`는 그래픽 세션에서 실제 활성 바인딩도 검사하므로 설정 적용 전에는 `hyprctl reload`가 필요하다. 설치 중 verify는 다음 로그인에 사용할 파일만 검사한다.

충돌 키 교체를 의도했다면:

```bash
bash scripts/setup-desktop.sh --replace-bindings
hyprctl reload
```

Chrome 단축키는 현재 Shittim IPC의 `media launch`를 이용한다. Shell이 없을 때만 동일 GIO Catalogue 코드를 한 번 실행한다. 임의 명령 문자열을 IPC로 받지 않는다. 기존 창 활성화는 앞서 구현한 정확한 Desktop ID·StartupWMClass 규칙을 따른다. 매칭 불확실성을 제목으로 추정하지 않는다.

## 포털·캡처·잠금

Hyprland 전용 `xdg-desktop-portal/hyprland-portals.conf`에서 기본·파일 선택은 GTK, ScreenCast·Screenshot은 Hyprland를 명시한다. [공식 포털 선택 규칙](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html)을 사용하며 wlr/GNOME/KDE 백엔드를 새로 설치하지 않는다. 이미 있는 다른 데스크톱의 패키지·서비스는 제거하지 않는다. 기존 session-services.sh가 Wayland·Hyprland·XDG 데스크톱 환경을 D-Bus/systemd에 전달한다.

현재 파일 선택·화면 공유를 끊지 않도록 포털 서비스를 자동 restart하지 않는다. 작업 저장 후 한 번 로그아웃·로그인한다. `verify-desktop.sh`는 포털 D-Bus 객체와 서비스 상태를 읽지만 실제 브라우저 파일 대화상자·공유 스트림 성공을 주장하지 않는다. Control Center의 미구현 Screen Cast 타일을 작동하는 것처럼 활성화하지 않는다. 공유는 Chrome 등 포털 클라이언트에서 시작한다.

캡처는 기존 control-service.py를 확장해 Control Center Screenshot과 같은 경로를 쓴다. 생성된 파일명만 사용하고 slurp 좌표를 검증한 뒤 `grim -g`에 별도 인수로 전달한다. `PICTURES/Screenshots`에 저장하고 wl-copy로 PNG를 복사한다. 취소 시 캡처하지 않는다. 캡처 프로세스 시간 초과는 종료·회수하고, 저장 성공 후 복사 실패는 Control Center에 별도로 표시한다.

잠금은 [Hyprlock 공식 설정](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/)에 맞춘 `shittim-lock.conf`를 명시적으로 사용한다. 기존 개인 `hyprlock.conf`와 PAM 설정은 유지한다. 어두운 HUD 색·각진 입력창·같은 폰트를 사용하며 자동 로그인·화면 꺼짐·절전·자동 잠금을 추가하지 않는다. 중복 스크립트 잠금은 flock으로 막는다. 실제 비밀번호·키보드 배열과 잠금 해제는 노트북에서 확인해야 한다.

## 클립보드 정책

wl-copy/wl-paste는 즉시 사용할 수 있지만 **기록 수집은 기본 꺼짐**이다. Super+Shift+V만으로 수집이 켜지지 않는다. 필요하면 그래픽 세션에서 직접 실행한다:

```bash
bash scripts/clipboard.sh enable
bash scripts/clipboard.sh pick
bash scripts/clipboard.sh clear
bash scripts/clipboard.sh disable
```

enable은 사용자 서비스 하나를 생성하고 Shittim과 함께 시작·종료되게 한다. wl-paste는 텍스트만 감시한다. Cliphist DB는 `$XDG_RUNTIME_DIR/shittim-clipboard/history.db`에 두고 권한을 제한한다. 최대 50개·항목당 100KiB이고 개인 cliphist 설정이 경로를 바꾸지 못하도록 한다. 홈·저장소에 영구 DB나 내용 로그를 만들지 않는다. 런타임 파일은 마지막 사용자 세션 종료·재부팅에 의해 정리되며, 수동 삭제는 clear다. disable은 수집을 중지하고 재시작 자동 수집을 끈다.

민감하다고 표시된 `CLIPBOARD_STATE=sensitive`·비어 있음·삭제 이벤트는 저장하지 않는다. 민감 표시가 없는 일반 텍스트에는 비밀번호가 들어 있을 수도 있으므로 완전한 비밀 탐지를 보장하지 않는다. 이것이 기본 수집을 끄는 이유다. 선택 화면은 기존 Fuzzel의 dmenu 기능을 HUD 색으로 사용하고, 선택 문자열을 셸 코드로 실행하지 않는다. [Cliphist의 문서화된 DB·크기 옵션](https://github.com/sentriz/cliphist#configuration)을 사용한다.

## MPRIS 점검과 진단

기존 Quickshell 0.3.2 내장 MPRIS 탐색·재생·Seek·여러 플레이어 선택 방식과 지원 플래그는 유지했다. 진단용 IPC와 이미지 로딩 상태만 추가했고 UI 레이아웃은 변경하지 않았다. 진단은 플레이어의 실제 D-Bus GetAll과 Shittim 정보를 비교한다:

```bash
python3 scripts/diagnose-media.py
```

| 코드 | 구분 |
|---|---|
| MprisNotRegistered | 플레이어가 세션 버스에 없음. 먼저 Chrome/VLC 재생 확인 |
| MetadataMissing | 플레이어는 있지만 곡 제목·아티스트 정보 없음 |
| ShittimNotDetected / ShittimIPCUnavailable | MPRIS는 있으나 Shell 탐색·IPC 확인 필요 |
| MetadataSyncMismatch / UIDisplayMismatch | Native 상태 또는 화면 모델의 메타데이터 불일치 |
| PlaybackSyncMismatch | 재생 상태 동기화 불일치 |
| ArtworkRejected | 제공된 URI를 안전한 이미지 정책이 거부 |
| ArtworkLoadFailed | 패널을 연 상태에서 이미지 로딩 실패 |

각 플레이어의 canSeek·이전/다음·제어 가능 여부도 표시한다. 패널이 닫혀 있으면 이미지를 읽지 않으므로 `artworkState=panelClosed`가 정상이다. 곡 전환 직전/직후에는 수집 시점 차이가 있을 수 있으니 잠시 뒤 다시 검사한다. 출력에는 제목·아티스트·로컬 파일 경로·아트 URI를 포함하지 않는다. 내부 비교용 `media diagnostics` IPC는 로컬 메타데이터를 포함하므로 그 원시 출력을 Git에 올리지 않는다.

Chrome의 MPRIS 등록은 버전·사이트·Media Session 및 실행 플래그에 좌우된다. YouTube 재생 후 `playerctl -l`에서 실제 이름을 확인한다. 등록되지 않으면 chrome://version의 실행 환경과 미디어 키 관련 기능을 확인하고, 해당 버전에 관련 chrome://flags 항목이 있을 때 기본/활성 상태를 검토한다. 특정 버전에만 있는 플래그를 설치 스크립트로 강제하지 않는다. 사이트가 아티스트·아트·탐색을 제공하지 않으면 해당 정보·버튼이 없는 것이 정상이다.

VLC의 D-Bus 인터페이스는 [공식 소스](https://github.com/videolan/vlc/tree/master/modules/control/dbus)에서 확인했다. README의 실제 WAV 생성·`vlc --extraintf=dbus` 절차로 Chrome과 독립적으로 검사한다. 이전/다음은 곡 목록에서, Seek는 충분히 긴 로컬 파일에서 시험한다. 실제 재생 제어를 자동으로 호출해 사용자의 곡을 바꾸지 않는다.

## 참고 프로젝트 분석

| 프로젝트 | 확인한 구성 | Shittim 적용 |
|---|---|---|
| [43PR](https://github.com/43PR/dotfiles) | 공식/AUR 패키지, 사용자 서비스, 파일별 링크·백업, Portal·XWayland·캡처·Cliphist | 서비스 재사용·파일별 백업·필요 유틸만 채택. 셸 교체·테마 생성·자동 AUR 실행은 가져오지 않음 |
| [ViegPhunt/Dotfiles](https://github.com/ViegPhunt/Dotfiles) | Nemo/GVfs·이미지/PDF/미디어 앱, 모듈화된 키·환경·시작 설정, GTK/Hyprland/wlr 포털 | 앱 역할과 모듈 분리 참고. 기존 Kitty·Shittim 유지, 포털은 GTK/Hyprland만 선택 |
| [ViegPhunt/Arch-Hyprland](https://github.com/ViegPhunt/Arch-Hyprland) | pacman 설치·별도 앱 스크립트·서비스·Stow·터미널 연결 | 단계별 실패 보고와 기존 백업을 확장. 원격 코드 실행·SDDM·Ghostty 교체는 적용하지 않음 |

코드나 에셋을 복사하지 않고 구성 방식을 참고했다. 기존 단일 Shittim 저장소와 자체 스크립트를 유지한다.

## 변경 파일과 검증 범위

신규: `config/hyprland-portals.conf`, `dotfiles/hypr/shittim-lock.conf`, `scripts/{desktop-tool.py,setup-desktop.sh,install-chrome.sh,open-desktop.sh,screenshot.sh,lock-screen.sh,clipboard.sh,verify-desktop.sh,diagnose-media.py,make-test-media.py}`, `tests/test_desktop_essentials.py`, 이 문서.

수정: `install.sh`, `scripts/{packages.txt,config-tool.py,control-service.py,verify.sh}`, `config/dock.json`, `shell/services/{MediaState.qml,SystemControl.qml}`, `shell/components/{AppMediaControls.qml,media/MediaView.qml}`, `tests/{test_launcher_gio.py,test_control_service.py}`, `README.md`와 미디어 문서의 기본 앱 설명.

Windows에서는 QML 모델/화면 회귀, Python·QML 구문을 검사한다. Arch WSL에서는 임시 홈의 파일 연결·백업·반복 실행·충돌·Lua 실행과 실제 GIO 기본 앱 해석, 캡처 인수·취소·복사, 진단의 민감 정보 제거를 검사한다. 실제 Chrome AUR 빌드·Nemo·VLC 재생·PAM 잠금·하드웨어 캡처·Portal 공유·멀티 모니터는 노트북에서 README의 A~D 절차로 확인한다.

최종 검사: QML 테스트 81개, Arch WSL Python 테스트 88개 통과. 전체 Bash 문법과 QML 구문·로컬 import 경계도 통과했다. 실제 WAV 생성기는 임시 경로에서 60초 파일의 헤더·길이와 기존 파일 덮어쓰기 방지를 확인했다. 공식 Linux 타입 메타데이터를 Windows qmllint에서 사용할 때 남는 PanelWindow·Margins·Screen·ObjectModel 동적 속성 경고는 실제 Quickshell 로딩 검증을 대신하지 않으며, 노트북에서 서비스 재시작 후 확인해야 한다.
