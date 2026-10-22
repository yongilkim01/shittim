# Shittim

Hyprland용 Quickshell 0.3.2 상단 바. 왼쪽에는 워크스페이스, 오른쪽에는 네트워크·배터리·초 단위 시계를 표시한다.

## 네트워크

- `Quickshell.Networking` 내장 모듈로 NetworkManager D-Bus 상태를 읽는다. NetworkManager와 시스템 D-Bus가 필요하며 `nmcli` 프로세스나 폴링 타이머는 사용하지 않는다.
- `Networking.devices.values`에서 Wi-Fi와 유선 장치를 탐색한다. 인터페이스 이름을 고정하지 않고 `lo`, `p2p-dev-*`를 제외한다.
- 연결된 Wi-Fi 장치의 `networks.values`에서 `connected` 네트워크를 골라 `WifiNetwork.name`의 실제 SSID를 표시한다. 연결 프로필 이름을 사용하지 않는다.
- SSID를 구분자로 분리하거나 셸 명령에 전달하지 않는다. 공백·한글·콜론·역슬래시·따옴표를 그대로 보존하며 `Text.PlainText`로 표시해 HTML처럼 보이는 SSID도 문자로 처리한다. 표시 폭은 240px로 제한하고 긴 이름은 말줄임한다.
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
- 정상 배터리는 녹색(`#a6e3a1`), 충전 상태와 관계없이 잔량 20% 이하는 빨간색(`#f38ba8`)과 `LOW`로 표시한다. 기존 시계는 기본 글자색(`#cdd6f4`)을 사용하며 배터리와 16px 간격으로 배치한다.
- 초기화 전, 배터리 미탐지 또는 제거 시 배터리 UI를 숨긴다. 오른쪽 Row는 숨겨진 항목의 간격도 제거한다. 유효하지 않은 잔량은 `--%`로 표시한다.
- QML 바인딩으로 잔량·상태·존재 여부 변경을 자동 반영한다. 타이머나 sysfs 폴링은 사용하지 않는다.
- UPower 데몬이 없어서 초기화되지 않으면 배터리는 숨겨지며 기존 워크스페이스와 시계는 유지된다. 데몬을 나중에 설치·시작했다면 Quickshell을 다시 실행한다. Quickshell 자체에 UPower 모듈이 빠진 빌드는 지원하지 않는다.

API: [UPower](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPower/), [UPowerDevice](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPowerDevice/), [상태 열거형](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.UPower/UPowerDeviceState/), [0.3.2 잔량 변환 소스](https://github.com/quickshell-mirror/quickshell/blob/v0.3.2/src/services/upower/device.cpp).

## Windows에서 검토 후 커밋·푸시

PowerShell에서 실행한다. 소유권 경고를 피하기 위한 `-c safe.directory=...`는 해당 명령에만 적용된다.

```powershell
Set-Location C:\Users\User\Desktop\Yongil\projects\shittim
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff --check
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff -- components/TopBar.qml README.md
Get-Content components/Network.qml
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim add -- components/Network.qml components/TopBar.qml README.md
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff --cached
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim commit -m "feat: add network status indicator to top bar"
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
quickshell -p "$PWD/shell.qml"
```

로컬 수정이 있으면 먼저 보존하고 pull한다. 이미 같은 셸이 실행 중이면 파일 자동 재로딩을 확인하거나, 기존 실행을 종료한 뒤 위 실행 명령을 사용한다. Hyprland 세션의 터미널에서 실행한다.

사용자가 확인한 장치는 `BAT0`이며 당시 sysfs 출력은 잔량 `100`, 상태 `Full`이었다. 현재 값은 하드코딩하지 않고 UPower에서 읽는다. 다음 명령으로 실제 장치와 표시용 합성 장치를 비교할 수 있다.

```sh
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/BAT0/status
upower -i /org/freedesktop/UPower/devices/DisplayDevice
```

실기 확인: 동일한 완충 상태에서 `100% Full`, 어댑터 분리 후 `Discharging`과 잔량 갱신, 연결 후 `Charging` 또는 `Plugged in`, 충전 중을 포함한 20% 이하 빨간색 `LOW`, 워크스페이스 전환, 시계의 초 갱신을 확인한다. 배터리가 없는 환경은 배터리 UI와 해당 간격이 사라져야 한다. 아이콘은 Hack Nerd Font Mono 설치 여부도 확인한다. Windows에서는 Linux UPower와 Hyprland 동작을 검증할 수 없다.
