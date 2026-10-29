# SHITTIM HUD

## 디자인 토큰

`shell/ui/Theme.qml`에서 색상·폰트·간격·크기·애니메이션을 관리한다.

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

기본 배경은 `#020f15`이다. 시안은 활성·호버·중요 정보에 집중한다. 평면과 얇은 직선을 사용하며, 그림자·블러·반복(펄스) 발광은 사용하지 않는다. 떠 있는 층(팝업·Dock·툴팁)에만 정적인 옅은 외곽 후광을 쓴다(아래 2.0 참조). 패널 등장 시간은 토큰만 제공하며 현재 상단 바에는 등장 애니메이션을 실행하지 않는다.

## Design System 2.0 (2026-10-29)

색·배경·로고는 그대로 두고 테두리·모서리·계층·상태 표현을 정교하게 만든 개정이다. 시각 목표는 사용자 시안(시스템 설정 창: 좌측 메뉴, 시스템 개요 게이지, 저장 공간·네트워크·세부 설정 카드)이다.

### 참고 저장소에서 가져온 것

| 저장소 (라이선스) | 확인한 구현 | 채택 | 채택하지 않음 |
| --- | --- | --- | --- |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0) | C++ 토큰(`tokens.hpp`: 간격·둥글기·시간·곡선), 중앙 `Anim`/`CAnim`, `StateLayer`(호버 0.08 + 누름 파문), 단계별 표면색 `Colours.layer`, `Elevation` dp 그림자, SDF 셰이더 프레임 | 모션·상태 값을 토큰으로 모으기, 상태 표현을 색과 형태로 분리, 떠 있는 층에만 높이감 | Material You 색, 둥근 블롭 변형, 과한 탄성 곡선 |
| [43PR/dotfiles](https://github.com/43PR/dotfiles) (MIT) | `Theme.qml` 의미 색(`bgPanel`·`bgCard`·`trackBg`), 상태 우선순위(누름 > 활성 > 경고, 호버 오버레이), 36×20 토글, 강조색 아이콘 상자·자간 라벨, 모서리만 그라데이션인 테두리 | 상태 우선순위, 선택 = 1px 강조 테두리 + 옅은 강조 채움, 토글 크기·동작, 모서리 강조 | 파일마다 다시 만든 인라인 컴포넌트(중복) |
| [ViegPhunt/Dotfiles](https://github.com/ViegPhunt/Dotfiles) (MIT) | waybar·swaync·rofi·wlogout CSS(QML 없음), 호버 밑줄 / 활성 전체 테두리 | 선택 막대(버튼 하단 강조선) | 파스텔 다색 모듈, 반복 펄스 발광 |
| [ViegPhunt/Arch-Hyprland](https://github.com/ViegPhunt/Arch-Hyprland) (MIT) | `install.sh`(stow)만 있고 UI 파일 없음 | — | — |

네 저장소 모두 화면 가장자리 스냅·HUD식 깎인 모서리는 구현하지 않았다. README 스크린샷은 동영상·첨부 링크라 시각 특징은 확인하지 않았다. 코드는 복사하지 않았다.

### 표면 계층 (`HudFrame.level`)

| 단계 | 쓰는 곳 | 모서리 | 강조선 | 기타 |
| --- | --- | --- | --- | --- |
| `window` | 대시보드·제어 센터·런처·알림 센터 바깥 틀 | 우상·좌하 14px | 네 모서리 밝은 시안 2px, 28px | 안쪽 4px 보조선 |
| `panel` | 시스템 개요, 미디어 플레이어, 알림 팝업, Dock | 좌상·우하 10px (비대칭) | 깎인 모서리에 어두운 시안 2px, 18px | |
| `card` | 저장 공간·네트워크, 목록 항목(`HudPanel`) | 좌상·우하 6px | 깎인 모서리에 어두운 시안 1px, 10px | |
| `control` | 버튼·타일·메뉴 항목·설정 행(`ControlFrame`) | 한 모서리 4~6px | 없음 (켜진 타일만 10px) | 상태가 테두리·채움으로 드러남 |

떠 있는 층(`glow: true`: 런처·알림·미디어·Dock·툴팁)만 옅은 외곽 후광을 가진다. 강한 시안은 `window` 모서리, 선택·켜짐 상태, 게이지 값에만 쓴다.

### 상태 우선순위

비활성 > 누름 > 선택(켜짐) > 오류/경고 > 포커스·호버 > 기본. 채움은 시안의 고정 투명도로 통일한다.

| 상태 | 채움 | 테두리 | 글자 |
| --- | --- | --- | --- |
| 기본 | `surface` | `border` | `textSecondary` |
| 호버 | `hoverFill` (8%) | `accentDim` | `accentBright` |
| 포커스 | — | `accent` | — |
| 선택·켜짐 | `selectedFill` (15%) | `accent` + 하단/좌측 강조 막대 | `accentBright` 굵게 |
| 누름 | `pressedFill` (18%), 90ms | `accent` | `accentBright` |
| 오류·긴급 | — | `warning`·`danger` 테두리와 강조선 | 같은 색 |
| 비활성 | `disabledFill` | `border` 반투명 | `textMuted` |

### 공용 컴포넌트

| 컴포넌트 | 역할 |
| --- | --- |
| `HudFrame` | 모든 표면의 틀. 단계·모서리별 깎임·강조선·이중선·후광. QtQuick.Shapes 하나로 그려 Canvas 재그리기가 없다 |
| `HudPanel` | `card` 단계 목록 항목 |
| `HudButton` | 상태 우선순위 + 선택 막대. `compact`는 상단 바 워크스페이스 칩 |
| `HudToggle` | 켜짐/꺼짐 스위치. 손잡이 이동 160ms, 켜지면 손잡이 후광 |
| `HudSlider` | 그라데이션 채움, 누르면 손잡이 1.2배, 호버·드래그·포커스 시 후광 고리 |
| `HudProgress` | 둥근 트랙·그라데이션 채움·현재 값 밝은 끝 |
| `HudSectionHeader` | 강조 막대(또는 아이콘)·제목·보조 값·`⋯` 표지 |
| `HudToolTip` | 창 안 힌트. `HudInfoCard` 카드 + 150ms 페이드. 상단 바는 `BarTooltip`(팝업 창) |
| `HudCallout`/`HudInfoCard` | 화살표가 있는 떠 있는 카드. 좌상·우하 강조선과 후광 |
| `ControlFrame` | 기존 API를 유지한 `control` 단계 `HudFrame` |

### 토큰 추가

`hoverFill` `pressedFill` `selectedFill` `accentGlow` `trackFill` `frameLine` `disabledFill`, 단계별 `windowCut` `panelCut` `cardCut` `controlCut` 과 `windowAccent` `panelAccent` `cardAccent`, `accentLineWidth` `frameInset` `sectionBarWidth`, `toggleWidth` `toggleHeight`, `pressDuration` 90 `toggleDuration` 160. 정본은 `config/design-tokens.json`이고 `scripts/design-tokens.py --write`로 `Theme.qml`을 생성한다.

### 적용 범위

대시보드(창 틀·좌측 메뉴 레일 표시·시스템 개요 게이지·저장 공간·네트워크 그래프 채움), 제어 센터(창 틀·타일 상태), 전원 및 잠금·디스플레이 설정(`ControlFrame` 행), 런처·알림 센터·알림 팝업·미디어·Dock 틀, 상단 바 노치 강조선, 모든 창 안 툴팁. 잠금 화면(hyprlock)과 GTK 앱 색은 이번 개정 범위 밖이다. 배치 좌표는 바꾸지 않아 기존 화면 시험이 그대로 통과한다.

## 모듈과 사용법

일반 Qt Quick 디렉터리 import와 `qmldir`를 사용한다. `shell/ui/Theme.qml`의 `pragma Singleton`과 `shell/ui/qmldir`의 `singleton Theme` 등록이 한 쌍이다. 시스템의 import 경로 설정이나 빌드 과정 없이 `shell/shell.qml`에서 컴포넌트를 불러온다.

`shell/components/`의 파일에서는 다음과 같이 사용한다. `../ui` 상대 import는 이동 전과 같다.

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
| `HudStatus` | `glyph`, `text`, `color`, `maximumTextWidth`, `hovered`. `compact`는 바용 크기, `iconOnly`는 호버 시에만 텍스트 표시 |
| `HudPanel` | `active`, `corners`. 얇은 경계와 정적인 모서리 장식 |
| `HudButton` | `text`, `active`, `enabled`, `clicked`. `compact`는 작은 워크스페이스 표시. 마우스 호버·왼쪽 클릭·키보드 Space/Return |
| `HudDivider` | `vertical`로 방향 지정. 기본 세로 구분선 |
| `HudProgress` | `value` 0~1, `fillColor`. 범위 제한과 200ms 폭 전환 |

`HudText`는 한글이 있으면 D2Coding을 선택한다. 혼합 문자열의 아이콘은 `HudIcon`으로 분리한다. 영문과 아이콘은 Hack Nerd Font Mono를 사용한다. 두 폰트는 대상 Arch 환경에 설치되어 있어야 한다. 텍스트의 고정 높이를 지정하지 않고 실제 폰트의 implicitHeight를 사용한다.

상태 조회는 기존 기능 컴포넌트, 시각 규칙은 `shell/ui/`가 담당한다. `shell/ui/`는 Hyprland·UPower·NetworkManager·PipeWire를 import하지 않는다. 새 기능도 먼저 공통 토큰과 기본 요소를 재사용한다.

## 상단 바

- 왼쪽: SHITTIM 텍스트와 실제 Hyprland 워크스페이스. 별도 시스템 마크는 표시하지 않는다.
- 오른쪽: Network → Volume → Battery → 구분선 → Clock. 날짜·시각은 `MM/dd HH:mm`으로 표시한다.
- 배경은 `#020f15`, 높이는 40px. 하단의 얇은 시안 경계가 양 끝에서 사선으로 올라가며, 바깥 모서리는 투명하다. Canvas는 크기 변경 때만 다시 그린다.
- 활성 워크스페이스: 기본 20×18px의 밝은 시안 면과 어두운 숫자. 비활성: 배경 없이 청록 숫자. 이름이 길면 표시 폭이 늘어난다. 호버 150ms, OutCubic.
- 네트워크는 평소 아이콘만 표시하고 호버 시 실제 SSID 또는 연결 상태를 표시한다. 긴 SSID는 200px 말줄임이며 원본 데이터는 보존한다.
- 공간이 부족하면 워크스페이스 영역이 줄고 가로로 스크롤할 수 있다. 오른쪽 상태 영역과 겹치지 않는다.
- 정상 상태의 아이콘·수치는 밝은 시안으로 통일한다. 배터리 부족과 음소거는 Danger, 네트워크 연결 중은 Warning.
- 배터리는 평소 아이콘과 잔량만 표시한다. 호버 시 충전·방전 등의 상태와 진행률을 표시한다. 볼륨은 클릭 음소거·5% 휠 조절을 유지하며 호버 시 진행률과 음소거 문구를 표시한다.
- 바 전용 `compact` 표현은 상태 조회 로직과 분리되어 있다. 일반 패널용 HUD 컴포넌트의 기본 표현은 유지한다.

## 검증

Qt Quick 기본 요소는 저장소 루트에서 `qmltestrunner -input shell/tests`로 검사할 수 있다. 이 검사는 실제 Quickshell 시스템 모듈이나 Linux 장치를 검증하지 않는다.

이번 디렉터리 이동을 적용할 때는 이전 `shell.qml`로 실행한 인스턴스를 종료한 뒤 새 진입 파일로 한 번만 실행한다. 이후 같은 경로의 파일 수정에는 자동 재로딩을 사용할 수 있다. Hyprland의 자동 실행 명령도 이전 경로를 사용 중이면 새 경로로 직접 수정한다.

```sh
cd /home/yongil/projects/shittim
quickshell --version
fc-match "Hack Nerd Font Mono"
fc-match D2Coding
quickshell --path /home/yongil/projects/shittim/shell/shell.qml
```

1366px·1920px 화면에서 바 높이·구분선·글자 잘림을 확인한다. 한글과 긴 SSID, 다수 워크스페이스, 네트워크·볼륨·배터리 각 상태에서도 확인한다. 워크스페이스 전환, 외부 상태 변경 반영, 볼륨 클릭 음소거·5% 휠·0~100% 제한, 기본 출력 장치 변경, 배터리 없는 경우의 숨김 동작을 기존과 비교한다.
