# 화상회의 · 화면 공유

Google Meet 같은 브라우저 회의를 Shittim 에서 쓰기 위한 공통 환경이다. 회의 서비스별 코드는 없고 Zoom·Teams·Discord(웹/Electron)도 같은 포털·PipeWire 경로를 쓴다.

## 구성

| 영역 | 구현 | 위치 |
|---|---|---|
| 오디오 서버 | PipeWire · pipewire-pulse · WirePlumber 사용자 서비스 (기존) | `scripts/install-packages.sh` |
| 화면 공유 포털 | ScreenCast·Screenshot=hyprland, 나머지=gtk 명시 선택 (기존). 공유 대상 선택 창은 Shittim HUD 선택 창(아래) | `config/hyprland-portals.conf` → `~/.config/xdg-desktop-portal/hyprland-portals.conf` |
| 공유 선택 창 | xdph `custom_picker_binary` 로 `scripts/share-picker.sh` → `shell/share-picker.qml`(Quickshell, HUD). 시작 실패 시 기본 `hyprland-share-picker` 로 자동 전환. `allow_token_by_default = true` | `~/.config/hypr/xdph.conf` (Shittim 관리 표시가 없는 기존 파일은 덮어쓰지 않음) |
| 선택 창 표시 | `qt6-wayland` 추가 — `hyprland-share-picker`(Qt6) 가 XWayland 대신 Wayland 로 뜬다 | `scripts/packages.txt` |
| Chrome | 플래그를 **추가하지 않는다**. 프로필·쿠키·비밀번호·확장·권한을 건드리지 않는다 | `scripts/meeting-check.py` 가 위험 플래그만 검사 |
| 마이크 | 기본 입력 장치 볼륨·음소거·선택, 녹음 중인 앱 목록 | `shell/services/MicrophoneState.qml` |
| 카메라 | `/dev/videoN` 존재·캡처 가능 여부·사용 중인 프로세스 | `scripts/camera-service.py` → `shell/services/CameraState.qml` |
| 화면 공유 상태 | xdph 가 만드는 PipeWire `Video/Source` 노드(`xdph-streaming-*`) 관찰 | `shell/services/ScreenShareState.qml` |
| 분류 규칙 | 마이크/녹음 스트림/공유 스트림 판정 (UI·서비스 공용, 단위 시험 대상) | `shell/core/DeviceData.js` |

### 책임 분리

- **서비스**(`shell/services/`)는 상태만 수집한다. 마이크는 Quickshell PipeWire, 카메라는 별도 프로세스, 화면 공유는 PipeWire 노드 — 셋이 서로를 모른다.
- **화면**(`DeviceActivity`, `DevicesPage`, `MicrophoneSection`)은 필요한 서비스만 속성으로 받는다. 마이크 음소거 버튼은 카메라·공유 서비스 없이 동작한다.
- `ControlContent` 의 `microphone`/`camera`/`screenShare` 는 선택 속성이다. 기존 화면·시험은 그대로 돈다.
- 공유 시작·중지와 권한 허용은 회의 앱과 포털이 맡는다. Shittim 은 관찰만 하고 캡처를 시작·허용·중단하지 않는다.

### 상태를 아는 방법과 한계

| 상태 | 근거 | 한계 |
|---|---|---|
| 마이크 사용 중 | PipeWire `Stream/Input/Audio` 노드 (`stream.monitor`·`stream.capture.sink` 제외) | 앱 이름은 `application.name` 그대로 (Chrome = `Google Chrome`) |
| 카메라 사용 중 | `/dev/videoN` 을 연 프로세스 (`/proc/<pid>/fd`), inotify open/close 이벤트로 다시 조회 | 같은 사용자 프로세스만 보인다. Meet 의 장치 나열처럼 0.3초 안에 닫는 열기는 무시 |
| 화면 공유 중 | `xdph-streaming-*` 노드 존재 (공유 시작 시 생성, 중지 시 제거 — xdph `Screencopy.cpp`) | 어떤 앱이 무엇을 공유하는지는 노드에 없어 표시하지 않는다 |

브라우저 안의 상태(Meet 마이크 버튼, 카메라 끄기)는 추측하지 않는다. Meet 에서 마이크를 끄면 Chrome 스트림이 남아 있는 동안 “사용 중”으로 보일 수 있다.

## UI

- **TopBar**: 사용 중일 때만 마이크·카메라·화면 아이콘이 상태 영역 왼쪽에 나타난다(평소 레이아웃 변화 없음). 음소거된 마이크는 빨간 아이콘. 툴팁에 앱 이름, 클릭 시 Control Center «회의 장치».
- **Control Center 개요**: 미구현이던 Screen Cast 타일을 **Meeting** 타일로 바꿨다. 무언가 사용 중이면 강조되고 툴팁에 요약.
- **회의 장치 페이지**: 마이크 상태·음소거, 카메라 목록(사용 중/사용 가능/권한 없음/카메라 장치 없음, 도우미 오류 시 «다시 연결»), 화면 공유 상태와 시작·중지 안내.
- **오디오 페이지**: 출력 장치 아래에 입력 장치 볼륨·음소거·선택을 추가했다.
- 기존 `XF86AudioMicMute` 키는 그대로 기본 입력을 음소거한다.

### 공유 선택 창

xdph 기본 선택 창(Qt 위젯, 밝은 회색)은 HUD 와 맞지 않아 Shittim 선택 창으로 바꿨다. 포털이 공유 요청마다 `scripts/share-picker.sh` 를 실행하고, 이 스크립트가 별도 Quickshell 인스턴스(`shell/share-picker.qml`)를 띄운다.

- 위쪽 탭 «전체 화면» / «애플리케이션 창». «전체 화면» 탭은 왼쪽에 모니터 카드(미리보기, «모니터 N», «1920 × 1080 (16:9)»), 오른쪽에 열린 창 미리보기 목록(앱 아이콘·이름·종류)을 함께 보여 주며 오른쪽 목록에서 창을 바로 고를 수도 있다. «애플리케이션 창» 탭은 창 미리보기를 크게 3열로 보여 준다. 미리보기는 정지 화면(`ScreencopyView`, Dock 미리보기와 같은 방식), 앱 이름·종류는 Desktop Entry 에서 읽는다(같은 앱 창이 여럿이면 창 제목).
- 고르기 → «공유 시작» 순서다(Windows·macOS 공유 창과 같음). 카드를 누르면 체크 표시만 되고 아래 안내가 «선택한 화면만 공유됩니다» / «선택한 창만 공유됩니다» 로 바뀐다. 더블클릭·Enter 두 번은 바로 공유.
- Esc·바깥 클릭·취소·X = 공유 안 함. 아무것도 자동 선택하지 않는다. 탭을 바꿔도 고른 대상은 유지된다.
- 첫 선택 재사용(포털 restore token)은 화면에 따로 표시하지 않고 xdph `allow_token_by_default` 를 따른다(Shittim 설치값 = 켬).
- 포털과 주고받는 형식은 xdph 1.4.1 과 최신판이 같다(`[SELECTION]r/screen:<이름>`, `window:<번호>`). xdph 1.4.1 은 모니터 목록을 넘기지 않아 Quickshell 의 화면 목록을 쓴다.
- 영역(Region) 공유는 넣지 않았다. 필요하면 `~/.config/hypr/xdph.conf` 를 지우면 기본 선택 창으로 돌아간다.
- HUD 선택 창이 시작하지 못하면 기본 선택 창이 대신 뜬다. 공유 기능 자체는 막히지 않는다.

**선택 창이 두 번 뜨던 이유**: Chrome 은 자기 공유 창의 미리보기용으로 한 번, «공유» 를 누를 때 한 번, 포털에 두 번 요청한다. 두 번째 요청에 첫 선택을 재사용하려면 restore token 이 허용돼야 하는데 xdph 기본값은 꺼짐이다. `allow_token_by_default = true` 와 위 기본 체크로 한 번만 고르게 했다. 토큰은 그 앱이 같은 공유를 다시 요청할 때만 쓰이며, Shittim 이 공유를 시작하지는 않는다. 한 번만 뜨는지는 실장비 확인 대상 ❓.

### 탭을 옮길 때 뜨는 작은 회의 창

Chrome 이 Meet 에 기본으로 켜 둔 **자동 PIP(Picture-in-Picture)** 다([Google 공지](https://workspaceupdates.googleblog.com/2024/08/picture-in-picture-in-google-meet-will-open-when-switching-tabs.html)). Shittim 은 Chrome 프로필 설정을 바꾸지 않으므로 사용자가 끈다: Meet 탭 주소창 왼쪽 «사이트 정보» 아이콘 → «자동 PIP 모드»(Automatic picture-in-picture) 끄기. 사이트 설정에서 «차단» 으로 두면 계속 유지된다. Meet 메뉴의 수동 PIP 는 그대로 쓸 수 있다.

## Chrome

현재 Chrome 은 Wayland 세션에서 Ozone 플랫폼을 자동 선택하고(Chrome 140 부터 `--ozone-platform-hint=auto` 기본, [보도](https://www.omgubuntu.co.uk/2025/08/chrome-140-wayland-auto-detection-linux)) PipeWire 화면 캡처도 기본으로 켜져 있다. 그래서 `chrome-flags.conf` 를 만들지 않는다. 런처·Dock·Super+B 는 기존 `google-chrome.desktop` 을 그대로 실행한다.

`meeting-check.py` 는 사용자의 `~/.config/chrome-flags.conf` 를 읽기만 하고 다음을 알려 준다.

- 실패: `--use-fake-ui-for-media-stream`·`--auto-accept-camera-and-microphone-capture` 등 권한 자동 허용, `--disable-web-security`, `--disable-features=WebRTCPipeWireCapturer`
- 주의: `--ozone-platform=x11`, 실행 중 Chrome 창이 XWayland (`hyprctl clients`)
- 정보: 이제 필요 없는 `--enable-features=WebRTCPipeWireCapturer`

## 설치

`./install.sh` 가 그대로 처리한다. 새 단계는 없다.

1. `install-packages`: `qt6-wayland` 가 공식 패키지 목록에 추가되어 함께 설치된다. 나머지 오디오·포털 패키지는 이미 목록에 있다.
2. `setup-desktop`: 포털 선택 파일 설치(기존, 백업 포함), `~/.config/hypr/xdph.conf`(공유 선택 창). Shittim 표시가 없는 기존 `xdph.conf` 는 유지하고 안내만 한다.
3. `verify`: `meeting-check.py` 를 실행한다. TTY 에서는 패키지·설정만(`--static`), Hyprland 안에서는 전부.

포털·PipeWire 서비스를 restart 하지 않는다. 진행 중인 공유나 통화를 끊지 않기 위해서다. 포털 선택 파일을 처음 설치했다면 로그아웃·로그인 뒤에 적용된다.

기존 설치 업데이트:

```bash
cd ~/projects/shittim
git pull --ff-only
sudo pacman -S --needed qt6-wayland
bash scripts/setup-desktop.sh
systemctl --user restart shittim.service
# 화면 공유 중이 아닐 때만: xdph 는 시작할 때 xdph.conf 를 읽는다
systemctl --user restart xdg-desktop-portal-hyprland
bash scripts/verify-meeting.sh
```

## 진단

```bash
bash scripts/verify-meeting.sh          # Hyprland 안의 Kitty 에서
python3 scripts/camera-service.py --check
```

검사 항목: 패키지, 포털 선택 파일·Hyprland 백엔드·share picker, `XDG_CURRENT_DESKTOP`, 포털 ScreenCast D-Bus 의 공유 대상(모니터·창), Hyprland 권한 강제, PipeWire/WirePlumber 서비스, 스피커·마이크 목록, 카메라, 남은 공유 스트림. 장치가 없으면 `[장치 없음]` 으로 보고하고 설치 실패로 세지 않는다.

## 기능별 상태

| 기능 | 상태 |
|---|---|
| 마이크 입력·음소거·입력 볼륨·장치 선택 | 구현 완료, 실제 환경 검증 필요 |
| 스피커 출력·볼륨·장치 선택 | 기존 기능, 실제 환경 검증 필요 |
| USB·Bluetooth 장치 연결/해제 반영 | PipeWire 노드 변화로 자동 반영, 실제 환경 검증 필요. Bluetooth 헤드셋 마이크는 WirePlumber 가 통화 프로필로 전환해야 나타난다 |
| 웹캠 사용·선택 | Chrome 이 V4L2 로 직접 사용 (Shittim 개입 없음), 실제 환경 검증 필요 |
| 카메라 연결·사용 상태 표시 | 구현 완료, 실제 환경 검증 필요 |
| Chrome 탭 공유·탭 오디오 | Chrome 자체 기능, 실제 환경 검증 필요 |
| 창 공유·전체 모니터 공유·멀티 모니터 선택 | xdph 포털 + share picker, 실제 환경 검증 필요 |
| 공유 중 상태 표시·종료 후 정리 확인 | 구현 완료(TopBar·Control Center·`pw-dump` 검사), 실제 환경 검증 필요 |
| 창·모니터 공유 시 **시스템 오디오** 공유 | 미구현 — 기술적 제약. Shittim 이 아니라 Chrome 이 Linux 에서 «시스템 오디오도 공유» 를 제공해야 한다. 버전별 제공 여부 ❓ — 실장비에서 체크박스 유무로 확인 |
| 공유 중지 버튼을 Shittim 에 두기 | 미구현 — 공유 세션은 앱 소유라 밖에서 끊으면 앱 상태가 어긋난다 |

## 실장비 수동 검사

계정 로그인과 실제 회의 참가는 사용자가 직접 한다.

1. `bash scripts/verify-meeting.sh` — `[실패]` 0건.
2. Chrome 으로 `https://meet.google.com` → «새 회의» (혼자 참가). 마이크·카메라 권한 요청이 **뜨는지** 확인하고 직접 허용.
3. TopBar 에 마이크·카메라 아이콘이 생기는지, 툴팁에 `Google Chrome`·`chrome` 이 보이는지.
4. Control Center → 오디오: 입력 장치 바꾸기·음소거 → Meet 의 입력 레벨 표시가 따라오는지. 출력 장치 바꾸기.
5. Meet 설정 → 동영상: 카메라 둘 이상이면 바꾸기. USB 웹캠 뽑기/꽂기 → 회의 장치 페이지 목록 갱신.
6. 공유 → 탭(«탭 오디오도 공유» 켜고 YouTube 탭) / 창 / 전체 화면. 창·화면은 hyprland-share-picker 에서 고른다. 모니터가 둘이면 두 번째 모니터 선택.
7. 공유 중: TopBar 화면 아이콘. 공유 중인 창을 드래그·크기 조절·스냅·최대화/복원·다른 워크스페이스로 이동 → 상대 화면(같은 회의를 다른 기기/탭에서) 확인.
8. 공유 중인 창을 **최소화** → 상대 화면이 어떻게 보이는지 기록. Shittim 최소화는 특수 워크스페이스로 옮기는 방식이라 그 창이 그려지지 않아 화면이 멈춰 보일 수 있다 ❓.
9. Chrome 의 «공유 중지» → TopBar 화면 아이콘이 사라지고 `verify-meeting.sh` 의 «남아 있는 화면 공유 스트림 없음».
10. 회의 나가기 → 마이크·카메라 아이콘이 사라지는지. 이어서 런처·Dock·Alt+Tab·한글 입력 등 기존 기능 확인.

## 참고 저장소

| 저장소 | 본 것 | 가져온 방식 |
|---|---|---|
| [Caelestia Shell](https://github.com/caelestia-dots/shell) (GPL-3.0) | `services/Audio.qml`: 기본 sink/source 를 한 서비스가 추적, `Pipewire.preferredDefaultAudioSource` 로 입력 선택, `application.name` 으로 앱 이름 | 패턴만. 코드 복사 없음 (GPL 의무 없음) |
| [43PR dotfiles](https://github.com/43PR/dotfiles) (MIT) | `SettingsPages/AudioPage.qml` 의 입력 장치 필터(`!isSink && !isStream && audio`), `install.sh` 의 PipeWire 사용자 서비스 활성화 | 같은 판정 규칙을 `DeviceData.js` 에 독자 작성 |
| [ViegPhunt Dotfiles](https://github.com/ViegPhunt/Dotfiles) (MIT) | `install_archpkg.sh` 의 포털 3종 패키지, `environment.conf` 의 `OZONE_PLATFORM` 전역 환경변수 | 패키지 구성만 확인. 전역 Ozone 환경변수는 Chrome 기본값과 겹쳐 쓰지 않음 |
| [ViegPhunt Arch-Hyprland](https://github.com/ViegPhunt/Arch-Hyprland) (MIT) | 설치 스크립트 구성 | 해당 기능 관련 구현 없음 |

화면 공유 스트림 이름은 [xdg-desktop-portal-hyprland](https://github.com/hyprwm/xdg-desktop-portal-hyprland) `src/portals/Screencopy.cpp` 의 `getRandName("xdph-streaming-")` · `PW_KEY_MEDIA_CLASS "Video/Source"` 에서 확인했다. Quickshell 0.3.2 의 `Pipewire.nodes` 는 노드 종류를 걸러내지 않고 `Video/Source` 를 `VideoSource` 로 분류한다(`qml.cpp`, `node.cpp`).
