# SHITTIM HUD

## 디자인 토큰

`ui/Theme.qml`에서 색상·폰트·간격·크기·애니메이션을 관리한다.

| 역할 | 토큰 |
| --- | --- |
| 바탕·패널·호버 면 | `background`, `surface`, `surfaceElevated` |
| 핵심 정보·활성·보조 장식 | `accent`, `accentBright`, `accentDim` |
| 본문·보조·비활성 텍스트 | `textPrimary`, `textSecondary`, `textMuted` |
| 얇은 경계·활성 경계 | `border`, `borderActive`, `lineWidth` |
| 정상·진행 중·위험 | `success`, `warning`, `danger` |
| 영문·아이콘 / 한글 | `fontMono` / `fontKorean` |
| 정보 계층 | `textCaption`, `textStatus`, `textBody`, `textTitle`, `textValue` |
| 간격 | `spaceXS` 4 / `spaceS` 8 / `spaceM` 12 / `spaceL` 16 / `spaceXL` 24 |
| 상단 바·컨트롤 | `barHeight` 40 / `controlHeight` 28 |
| 전환 | `hoverDuration` 150 / `stateDuration` 200 / `panelDuration` 250ms |

기본 배경은 `#020f15`이다. 시안은 활성·호버·중요 정보에 집중한다. 평면과 얇은 직선을 사용하며, 그림자·블러·반복 발광은 사용하지 않는다. 패널 등장 시간은 토큰만 제공하며 현재 상단 바에는 등장 애니메이션을 실행하지 않는다.

## 모듈과 사용법

일반 Qt Quick 디렉터리 import와 `qmldir`를 사용한다. `Theme.qml`의 `pragma Singleton`과 `qmldir`의 `singleton Theme` 등록이 한 쌍이다. 시스템의 import 경로 설정이나 빌드 과정 없이 기존 `shell.qml`에서 컴포넌트를 불러온다.

`components/`의 파일에서는 다음과 같이 사용한다.

```qml
import QtQuick
import "../ui"

HudPanel {
    width: 320
    height: 180
    HudText {
        anchors.centerIn: parent
        text: "시스템 상태"
        textStyle: "section"
        color: Theme.accent
    }
}
```

| 컴포넌트 | 사용 |
| --- | --- |
| `HudText` | `textStyle`: `status`, `caption`, `section`, `body`, `title`, `value`, `secondary`. 일반 텍스트·한 줄·말줄임 기본값 |
| `HudIcon` | Nerd Font 전용 아이콘. `text`와 `color` 지정 |
| `HudStatus` | `glyph`, `text`, `color`, `maximumTextWidth`, `hovered`. 시스템 상태용 공통 배치 |
| `HudPanel` | `active`, `corners`. 얇은 경계와 정적인 모서리 장식 |
| `HudButton` | `text`, `active`, `enabled`, `clicked`. 마우스 호버·왼쪽 클릭·키보드 Space/Return |
| `HudDivider` | `vertical`로 방향 지정. 기본 세로 구분선 |
| `HudProgress` | `value` 0~1, `fillColor`. 범위 제한과 200ms 폭 전환 |

`HudText`는 한글이 있으면 D2Coding을 선택한다. 혼합 문자열의 아이콘은 `HudIcon`으로 분리한다. 영문과 아이콘은 Hack Nerd Font Mono를 사용한다. 두 폰트는 대상 Arch 환경에 설치되어 있어야 한다. 텍스트의 고정 높이를 지정하지 않고 실제 폰트의 implicitHeight를 사용한다.

상태 조회는 기존 기능 컴포넌트, 시각 규칙은 `ui/`가 담당한다. `ui/`는 Hyprland·UPower·NetworkManager·PipeWire를 import하지 않는다. 새 기능도 먼저 공통 토큰과 기본 요소를 재사용한다.

## 상단 바

- 왼쪽: 정적인 모서리 장식의 시스템 마크, SHITTIM, 워크스페이스.
- 오른쪽: Network → Volume → Battery → Clock. 초 단위 시계 형식은 유지한다.
- 활성 워크스페이스: 시안 경계·문자·하단 선. 비활성: 어두운 면과 청록 문자. 호버 150ms, OutCubic.
- 긴 SSID: 200px 말줄임. 실제 SSID 데이터는 보존한다.
- 공간이 부족하면 워크스페이스 영역이 줄고 가로로 스크롤할 수 있다. 오른쪽 상태 영역과 겹치지 않는다.
- 배터리 부족과 음소거는 Danger, 네트워크 연결 중은 Warning. 충전·완충·연결 상태는 Success.
- 배터리·볼륨 하단에는 얇은 진행률을 표시하며 볼륨 진행률은 호버 중에만 보인다.

## 검증

Qt Quick 기본 요소는 `qmltestrunner -input tests`로 검사할 수 있다. 이 검사는 실제 Quickshell 시스템 모듈이나 Linux 장치를 검증하지 않는다.

Arch에서는 변경분을 반영한 후 실행 중인 셸의 자동 재로딩을 확인한다. 새로 실행해야 한다면 기존 인스턴스를 종료한 뒤 한 번만 실행한다.

```sh
cd /home/yongil/projects/shittim
quickshell --version
fc-match "Hack Nerd Font Mono"
fc-match D2Coding
quickshell --path /home/yongil/projects/shittim/shell.qml
```

1366px·1920px 화면에서 바 높이·구분선·글자 잘림을 확인한다. 한글과 긴 SSID, 다수 워크스페이스, 네트워크·볼륨·배터리 각 상태에서도 확인한다. 워크스페이스 전환, 외부 상태 변경 반영, 볼륨 클릭 음소거·5% 휠·0~100% 제한, 기본 출력 장치 변경, 배터리 없는 경우의 숨김 동작을 기존과 비교한다.
