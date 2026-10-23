# Shittim

Hyprland용 Quickshell 0.3.2 데스크톱 셸. SHITTIM HUD 디자인 시스템을 사용하며 왼쪽에는 워크스페이스, 오른쪽에는 네트워크·볼륨·배터리·초 단위 시계를 표시한다.

## 저장소 구조

```text
shittim/
├── shell/
│   ├── shell.qml
│   ├── components/
│   ├── ui/
│   └── tests/
├── dotfiles/
├── scripts/
├── docs/
├── README.md
└── LICENSE
```

모노레포 전환 1단계로 Quickshell 소스와 테스트를 `shell/`에 모았다. `dotfiles/`와 `scripts/`는 `.gitkeep`만 둔 빈 디렉터리다. 향후 루트의 `install.sh`에서 Arch Linux 환경을 구성할 예정이며, 이번 단계에서는 설치 프로그램이나 실제 설정 파일을 제공하지 않는다.

`shell/shell.qml`의 `import "./components"`, 컴포넌트와 테스트의 `import "../ui"`, `shell/ui/qmldir`의 싱글턴 등록은 기존 상대 관계를 유지한다. 기능과 디자인 코드는 변경하지 않았다.

저장소 루트에서 실행한다. 기존 루트의 `shell.qml`로 실행한 인스턴스는 종료하고 새 경로로 한 번만 실행한다. Hyprland의 `exec-once` 등에서 이전 진입 파일 경로를 사용한다면 `shell/shell.qml` 경로로 직접 수정해야 한다. 기존 사용자 설정은 자동으로 수정하지 않는다.

```sh
cd /home/yongil/projects/shittim
quickshell --path "$PWD/shell/shell.qml"
```

## SHITTIM HUD 디자인 시스템

`shell/ui/Theme.qml`이 색상·폰트·크기·간격·모션의 정본이다. 기본 배경은 `#020f15`, 상단 바는 40px이다. 얇은 시안 경계, 직선 패널, 절제된 모서리와 활성·호버 강조를 사용한다.

`shell/ui/`의 `HudPanel`, `HudButton`, `HudText`, `HudDivider`, `HudProgress`, `HudIcon`, `HudStatus`를 재사용한다. 컴포넌트의 `import "../ui"`와 `qmldir` 싱글턴 등록을 사용하며 별도 설치나 외부 라이브러리는 필요하지 않다. 폰트는 Arch에 설치된 Hack Nerd Font Mono와 D2Coding을 사용한다.

사용 예·토큰·레이아웃·검증 절차는 [디자인 문서](docs/DESIGN.md)에 있다. 저장소 루트의 `qmltestrunner -input shell/tests`는 시스템 장치와 독립적인 Qt Quick 기본 요소 검사다. 실제 Quickshell·Hyprland·오디오·네트워크·배터리 검증은 Arch에서 수행한다.

## 볼륨

- `Quickshell.Services.Pipewire`의 `Pipewire.defaultAudioSink`를 사용한다. PulseAudio 호환 서버를 거치지 않고 PipeWire의 현재 기본 출력 장치를 추적한다.
- `PwObjectTracker.objects`를 `[sink]`에 바인딩해 기본 출력 장치가 바뀌면 새 장치를 추적한다. `sink.ready`와 `sink.audio`를 확인한 뒤 볼륨과 음소거 상태를 읽고 조작한다.
- `audio.volume`의 1.0을 100%로 표시한다. 음량 0%·1~50%·50% 초과 및 음소거에 따라 Nerd Font 아이콘을 바꾼다. 음소거 시 `Theme.danger`와 `MUTE`, 그 외에는 `Theme.textPrimary`를 사용한다. 호버 시 얇은 볼륨 진행률을 표시한다.
- 볼륨 표시를 왼쪽 클릭하면 음소거를 전환한다. 마우스 휠 위·아래 한 칸에 5%씩 조절하며 설정값은 0~100%로 제한한다. 작은 휠 델타는 누적하며 장치를 바꾸면 누적값을 초기화한다.
- 휠 조절은 음소거 상태를 바꾸지 않는다. 외부 도구에서 설정한 100% 초과 볼륨은 실제 값으로 표시하고, 이 컴포넌트로 조절할 때 0~100% 제한을 적용한다.
- 기본 출력 장치가 없거나 준비 중이면 `N/A`를 표시하고 조작을 비활성화한다. 유효하지 않은 볼륨 값은 `--%`로 표시한다. 외부 볼륨·음소거 변경은 QML 바인딩으로 반영한다.

API: [Pipewire](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/Pipewire/), [PwNodeAudio](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwNodeAudio/), [PwObjectTracker](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pipewire/PwObjectTracker/), [v0.3.2 볼륨 구현](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/pipewire/node.cpp).

Arch에서 기존 PulseAudio 호환 서버의 도구로 비교한다.

```sh
pactl info
pactl get-sink-volume @DEFAULT_SINK@
pactl get-sink-mute @DEFAULT_SINK@
pactl list short sinks
```

외부 변경 반영은 다음 명령으로 확인한다. UI에서 왼쪽 클릭 후 `get-sink-mute`, 휠 한 칸 이동 후 `get-sink-volume`을 다시 실행해 음소거 전환과 5% 조절을 비교한다. 0%·100%에서 휠을 더 움직여도 범위를 벗어나지 않아야 한다.

```sh
pactl set-sink-volume @DEFAULT_SINK@ 50%
pactl set-sink-mute @DEFAULT_SINK@ toggle
pactl set-sink-mute @DEFAULT_SINK@ 0
```

출력 장치 변경은 다른 출력 장치 연결 후 데스크톱 설정 또는 `pactl set-default-sink`로 기본 장치를 바꿔 확인한다. `set-default-sink`에는 `pactl list short sinks`에 나온 실제 장치 이름을 전달한다. 장치 제거·기본 출력 미지정 상태에서도 `N/A` 처리와 나머지 상단 바 동작을 확인한다. Windows에서는 Quickshell·PipeWire 실행 검증을 하지 않는다.

## 네트워크

- `Quickshell.Networking` 내장 모듈로 NetworkManager D-Bus 상태를 읽는다. NetworkManager와 시스템 D-Bus가 필요하며 `nmcli` 프로세스나 폴링 타이머는 사용하지 않는다.
- `Networking.devices.values`에서 Wi-Fi와 유선 장치를 탐색한다. 인터페이스 이름을 고정하지 않고 `lo`, `p2p-dev-*`를 제외한다.
- 연결된 Wi-Fi 장치의 `networks.values`에서 `connected` 네트워크를 골라 `WifiNetwork.name`의 실제 SSID를 표시한다. 연결 프로필 이름을 사용하지 않는다.
- SSID를 구분자로 분리하거나 셸 명령에 전달하지 않는다. 공백·한글·콜론·역슬래시·따옴표를 그대로 보존하며 `HudText`의 일반 텍스트 모드로 표시해 HTML처럼 보이는 SSID도 문자로 처리한다. 텍스트 폭은 `Theme.networkTextWidth`(200px)로 제한하고 긴 이름은 말줄임한다.
- `signalStrength`는 0~1이다. 25%·50%·75%를 경계로 Nerd Font Wi-Fi 아이콘을 바꾼다.
- 연결 시 SSID, 해제 시 `Wi-Fi disconnected`, 연결 중 `Wi-Fi connecting`, 종료 중 `Wi-Fi disconnecting`, 소프트웨어 끄기 `Wi-Fi off`, 하드웨어 차단 `Wi-Fi blocked`를 표시한다.
- 연결된 유선은 `LAN`으로 표시한다. 유선과 Wi-Fi 동시 연결 시 둘 다 표시하며, Wi-Fi 장치 없이 유선만 있으면 해제 상태도 `LAN disconnected`로 표시한다. 이는 장치 연결 상태이며 인터넷 도달 가능 여부를 보장하는 표시는 아니다.
- 장치가 없으면 `No network device`, 백엔드를 사용할 수 없으면 `Network unavailable`을 표시한다. QML 바인딩으로 장치 추가·제거, 연결 상태, 무선 활성화, SSID·신호 강도 변경을 반영한다.
- 사용자 확인 결과의 `QM_Wifi_20F`는 활성 연결 프로필 이름이다. 실제 SSID가 같을 때만 같은 문구가 표시된다.

API: [Networking](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/Networking/), [NetworkDevice](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/NetworkDevice/), [Network](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/Network/), [WifiNetwork](https://quickshell.org/docs/v0.3.2/types/Quickshell.Networking/WifiNetwork/), [v0.3.2 SSID·신호 강도 구현](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/network/nm/network.cpp).

Arch에서 NetworkManager와 실제 SSID·신호를 확인한다.

```sh
quickshell --version
systemctl is-active NetworkManager.service
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
nmcli radio wifi
nmcli -f IN-USE,SSID,SIGNAL,DEVICE device wifi list --rescan no
```

실기 확인: 연결된 SSID·신호 아이콘, Wi-Fi 해제·재연결, 무선 끄기·켜기, 유선 연결·분리, 동시 연결, 장치가 없는 환경을 확인한다. 공백·한글·특수문자가 있는 SSID와 연결 프로필 이름이 다른 경우도 비교한다. 테스트에 사용하는 Wi-Fi 장치 이름은 위 목록에서 확인한다.

```sh
nmcli radio wifi off
nmcli radio wifi on
```

Windows에서는 실제 NetworkManager 통신과 Quickshell UI를 검증할 수 없다. 기존 셸이 실행 중이면 파일 변경의 자동 재로딩을 확인하며, 다른 Kitty에서 같은 셸을 추가 실행하지 않는다.

## 배터리

- `Quickshell.Services.UPower`의 `UPower.displayDevice`를 사용한다. UPower 데몬이 필요하다.
- DisplayDevice는 합성 장치이므로 `isLaptopBattery` 대신 `ready`, 배터리 타입, `isPresent`로 표시 가능 여부를 확인한다. `isLaptopBattery`가 요구하는 `powerSupply`는 DisplayDevice에서 보장되지 않는다.
- Quickshell 0.3.2의 `percentage`는 0~1 범위이므로 100을 곱해 반올림한다.
- Nerd Font 배터리 아이콘과 잔량을 표시한다. 충전 중은 번개 아이콘과 `Charging`, 완충은 `Full`, 방전 중은 `Discharging`으로 구분한다. 100%만으로 완충을 판단하지 않는다.
- 충전 대기는 `Plugged in`, 방전 대기는 `On battery`, 알 수 없는 상태는 `Unknown`으로 표시한다.
- 충전·완충은 `Theme.success`, 그 외 정상 상태는 `Theme.textPrimary`, 충전 상태와 관계없이 잔량 20% 이하는 `Theme.danger`와 `LOW`로 표시한다. 배터리 아래 얇은 잔량 진행률을 표시한다. 시계와 상태 정보는 HUD 공통 간격과 구분선을 사용한다.
- 초기화 전, 배터리 미탐지 또는 제거 시 배터리 UI를 숨긴다. 오른쪽 Row는 숨겨진 항목의 간격도 제거한다. 유효하지 않은 잔량은 `--%`로 표시한다.
- QML 바인딩으로 잔량·상태·존재 여부 변경을 자동 반영한다. 타이머나 sysfs 폴링은 사용하지 않는다.
- UPower 데몬이 없어서 초기화되지 않으면 배터리는 숨겨지며 기존 워크스페이스와 시계는 유지된다. 데몬을 나중에 설치·시작했다면 Quickshell을 다시 실행한다. Quickshell 자체에 UPower 모듈이 빠진 빌드는 지원하지 않는다.

API: [UPower](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPower/), [UPowerDevice](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPowerDevice/), [상태 열거형](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPowerDeviceState/), [0.3.2 잔량 변환 소스](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/upower/device.cpp).

## Windows에서 검토 후 커밋·푸시

PowerShell에서 실행한다. 소유권 경고를 피하기 위한 `-c safe.directory=...`는 해당 명령에만 적용된다.

```powershell
Set-Location C:\Users\User\Desktop\Yongil\projects\shittim
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff --check
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff -- shell/components/TopBar.qml README.md
Get-Content shell/ui/Theme.qml
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim add --all
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff --cached
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim commit -m "refactor: move Quickshell sources into shell directory"
```

변경 검토 및 사용자 승인 후에만 푸시한다.

```powershell
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim push origin main
```

## Arch 노트북에서 적용

Windows 변경이 원격에 푸시된 뒤, 노트북의 Shittim 저장소 디렉터리에서 실행한다.

```sh
git status --short
git pull --ff-only origin main
quickshell --version
sudo pacman -S --needed upower
sudo systemctl start upower.service
upower -d
quickshell -p "$PWD/shell/shell.qml"
```

로컬 수정이 있으면 먼저 보존하고 pull한다. 이번 경로 이동을 반영할 때는 기존 실행을 종료한 뒤 위 실행 명령을 사용한다. Hyprland 세션의 터미널에서 실행한다. 이후 같은 진입 파일 경로에서 소스만 수정하면 자동 재로딩을 사용할 수 있다.

사용자가 확인한 장치는 `BAT0`이며 당시 sysfs 출력은 잔량 `100`, 상태 `Full`이었다. 현재 값은 하드코딩하지 않고 UPower에서 읽는다. 다음 명령으로 실제 장치와 표시용 합성 장치를 비교할 수 있다.

```sh
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/BAT0/status
upower -i /org/freedesktop/UPower/devices/DisplayDevice
```

실기 확인: 동일한 완충 상태에서 `100% Full`, 어댑터 분리 후 `Discharging`과 잔량 갱신, 연결 후 `Charging` 또는 `Plugged in`, 충전 중을 포함한 20% 이하 빨간색 `LOW`, 워크스페이스 전환, 시계의 초 갱신을 확인한다. 배터리가 없는 환경은 배터리 UI와 해당 간격이 사라져야 한다. 아이콘은 Hack Nerd Font Mono 설치 여부도 확인한다. Windows에서는 Linux UPower와 Hyprland 동작을 검증할 수 없다.
