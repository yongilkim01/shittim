# Shittim

Hyprland용 Quickshell 0.3.2 상단 바. 왼쪽에는 워크스페이스, 오른쪽에는 배터리와 초 단위 시계를 표시한다.

## 배터리

- `Quickshell.Services.UPower`의 `UPower.displayDevice`를 사용한다. UPower 데몬이 필요하다.
- DisplayDevice는 합성 장치이므로 `isLaptopBattery` 대신 `ready`, 배터리 타입, `isPresent`로 표시 가능 여부를 확인한다. `isLaptopBattery`가 요구하는 `powerSupply`는 DisplayDevice에서 보장되지 않는다.
- Quickshell 0.3.2의 `percentage`는 0~1 범위이므로 100을 곱해 반올림한다.
- 충전 중은 `Charging`, 완충은 `Full`로 표시하고 녹색을 사용한다. 100%만으로 완충을 판단하지 않는다.
- 충전 대기는 `Plugged in`, 방전 대기는 `On battery`, 알 수 없는 상태는 `Unknown`으로 표시한다.
- 충전 중·완충을 제외한 잔량 20% 이하는 빨간색 `LOW`로 표시한다.
- 초기화 전, 배터리 미탐지 또는 제거 시 `BAT N/A`를 표시한다. 유효하지 않은 잔량은 `--%`로 표시한다.

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

실기 확인: `100% Full`, 어댑터 분리 후 잔량 갱신, 연결 후 `Charging` 또는 `Plugged in`, 20% 이하 `LOW`, 워크스페이스 전환, 시계의 초 갱신을 확인한다. 배터리가 없는 환경은 `BAT N/A`가 표시되어야 한다. Windows에서는 Linux UPower와 Hyprland 동작을 검증할 수 없다.
