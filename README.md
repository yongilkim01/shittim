# Shittim

Hyprland용 Quickshell 0.3.2 상단 바. 왼쪽에는 워크스페이스, 오른쪽에는 배터리와 초 단위 시계를 표시한다.

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
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff -- components/TopBar.qml
Get-Content components/Battery.qml, README.md
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim add -- components/Battery.qml components/TopBar.qml README.md
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim diff --cached
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim commit -m "Add UPower battery indicator to top bar"
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
