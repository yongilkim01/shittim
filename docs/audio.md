# 오디오 설정

대시보드 «오디오» 메뉴. 출력·입력 장치, 실제 마이크 입력 레벨, 앱별 볼륨·음소거·출력 장치를 다룬다. 장치·앱 목록은 PipeWire가 실제로 알려 주는 것만 표시한다.

## 구조

| 층 | 파일 | 책임 |
| --- | --- | --- |
| 화면 | `shell/components/control/AudioSettingsPage.qml` | 표시와 사용자 입력. 서비스 계약만 호출하고 명령을 만들지 않는다 |
| 상태 | `shell/services/AudioState.qml` | 기본 출력·출력 장치·재생 스트림·앱 묶음·밸런스·앱 출력 이동 요청·오류 |
| 상태 | `shell/services/MicrophoneState.qml` | 기본 입력·입력 장치·녹음 중인 앱·입력 레벨(요청 시에만) |
| 계산 | `shell/core/AudioData.js` | 장치 종류, 앱 묶기, 밸런스, dB 레벨 막대, 오류 문구 (Quickshell 형식 없음, 단위 시험) |
| 어댑터 | `scripts/audio-route.py` | 앱 스트림을 다른 출력으로 보내기 (`pw-dump` 검사 → `pw-metadata`) |
| 공용 UI | `shell/ui/HudSelect`, `HudOptionList`, `HudLevelMeter` | 드롭다운 필드, 페이지 안 선택 목록, 막대형 레벨 미터 |

상단 바 볼륨(`Volume.qml`), 제어 센터 볼륨 슬라이더(`ControlOverview`·`AudioPage`), 오디오 설정 화면, 회의 장치 표시(`DeviceActivity`)는 모두 같은 `AudioState`·`MicrophoneState` 싱글턴과 같은 PipeWire 노드에 묶여 있다. 어느 쪽에서 바꾸든, `wpctl` 같은 외부 프로그램이 바꾸든 PipeWire 이벤트로 모든 화면이 함께 갱신된다. 폴링하지 않는다.

## PipeWire / WirePlumber 연동

| 기능 | 방법 |
| --- | --- |
| 장치·스트림 목록, 연결·해제 | Quickshell `Pipewire.nodes` (레지스트리 이벤트) |
| 볼륨·음소거 | `PwNodeAudio.volume` / `muted` |
| 좌우 밸런스 | `PwNodeAudio.volumes` + `channels`. 큰 쪽 채널을 현재 볼륨으로 두고 반대쪽을 줄인다. 좌우 채널이 없으면 비활성 |
| 기본 장치 변경 | `Pipewire.preferredDefaultAudioSink/Source` (WirePlumber `default.configured.*` 메타데이터). 2초 안에 실제 기본값이 바뀌지 않으면 오류 표시 |
| 앱 현재 출력 | `Pipewire.linkGroups` (스트림 → 출력 장치 연결) |
| 앱 출력 변경 | `audio-route.py move STREAM SERIAL` → `pw-metadata -n default STREAM target.object SERIAL Spa:Id`. «기본 출력 따라가기»는 같은 키를 지운다. pipewire-pulse가 pavucontrol 요청을 처리하는 방식과 같다 |
| 입력 레벨 | Quickshell `PwNodePeakMonitor`. 모니터 스트림(`stream.monitor=true`)이라 회의 «마이크 사용 중» 판정에 들어가지 않는다 |
| 설정 유지 | WirePlumber 상태(`~/.local/state/wireplumber`)가 기본 장치·장치·앱 볼륨·앱 출력 지정을 기억한다. Shittim은 별도 설정 파일을 쓰지 않는다 |

`audio-route.py`는 인자 목록으로만 실행하며(셸 없음), 스트림 id와 대상 serial은 숫자만 받고 `pw-dump`로 실제 `Stream/Output/Audio`와 `Audio/Sink`인지 확인한 뒤에만 메타데이터를 바꾼다. 실패 코드(`StreamNotFound` `TargetNotFound` `MetadataFailed` `PipeWireUnavailable` `ToolMissing` `Timeout`)는 화면에서 한국어 문구로 바뀐다. `pw-metadata`·`pw-dump`는 `pipewire` 패키지에 들어 있어 의존성이 늘지 않는다.

## 앱과 스트림

한 앱이 여러 스트림을 열 수 있다(예: 브라우저 탭마다). 같은 `application.process.binary`(없으면 `application.name`, 그것도 없으면 노드 이름)의 재생 스트림을 한 줄로 묶는다.

- 볼륨: 가장 큰 스트림 값을 보여 주고, 바꾸면 모든 스트림에 같은 값을 쓴다.
- 음소거: 모든 스트림이 음소거일 때만 음소거로 표시하고, 누르면 모두 바꾼다.
- 출력: 모든 스트림이 같은 장치면 그 장치, 다르면 «여러 장치», 아직 연결 전이면 «연결 중». 바꾸면 모든 스트림을 옮긴다.
- 이름·아이콘: `application.name`·`application.icon-name`(없으면 실행 파일 이름). 아이콘을 못 찾으면 기본 글리프.
- 출력 장치가 하나뿐이거나 이동 중이면 출력 선택을 끄고 이유를 툴팁으로 보여 준다.

## 마이크 입력 레벨과 개인정보

«입력 확인» 토글을 켠 동안, 그리고 오디오 화면이 보이는 동안에만 측정한다. 토글을 끄거나 화면을 떠나거나 페이지가 닫히면 모니터 스트림이 닫힌다(`watchLevel`/`unwatchLevel`). 피크 값 하나만 메모리에 두며 녹음·저장·전송하지 않는다. 레벨은 -60~0 dB를 24칸 막대로 보여 주고, 위쪽 4칸은 경고색이다.

«입력» 머리말의 «사용 중: 앱»은 실제로 마이크를 녹음 중인 앱이고, 장치 음소거와는 별개다. 앱 자체 음소거(예: Discord 음소거 버튼)는 PipeWire가 알 수 없어 표시하지 않는다.

## 참고 저장소

| 저장소 | 확인한 오디오 구현 | 반영 |
| --- | --- | --- |
| caelestia-dots/shell (GPL-3.0) | `services/Audio.qml`: Quickshell Pipewire, `preferredDefaultAudioSink/Source`로 기본 장치 변경, 스트림 이름은 `application.name` → 설명 → 이름 순. `nexus/pages/audio/AppVolumes.qml`: 스트림마다 한 줄. 시각화는 cava | 같은 Quickshell API와 이름 우선순위. 앱 단위 묶기·출력 이동은 caelestia에 없음 |
| 43PR/dotfiles (MIT) | `SettingsPages/AudioPage.qml`: 출력·입력 목록(`isSink && !isStream`), 스트림 목록, 스트림별 음소거·볼륨 | 장치·스트림 분류 방식 |
| ViegPhunt/Dotfiles (MIT) | `wpctl set-volume/set-mute @DEFAULT_AUDIO_SINK@` 단축키만 | — |
| ViegPhunt/Arch-Hyprland (MIT) | UI·오디오 코드 없음 | — |

코드는 복사하지 않았다.

## 시험

- `shell/tests/tst_audio.qml` (11): 실제 PipeWire 속성 모양의 장치 종류, 밸런스 계산, 앱 묶기(여러 스트림·이름 없는 스트림·연결 전), dB 막대, 마우스·키보드 장치 선택, 음소거·볼륨, 빈 목록, 오류 표시, 레벨 측정 시작·종료(토글·화면 숨김·페이지 소멸), 앱 출력 이동·기본으로 되돌리기, 마이크 사용과 음소거 구분.
- `tests/test_audio_route.py` (5): serial 지정·기본 복귀 인자, 스트림·출력 확인, 명령 주입 거부, 실패 코드.
- 실제 PipeWire 1.6.10 + WirePlumber 0.5.18(가상 출력 2개, 재생 스트림) 위에서 확인: `audio-route.py`로 스트림 이동·기본 복귀, 잘못된 입력 거부. Quickshell 0.3.2를 화면 없이 실행해 Shittim `AudioState`·`MicrophoneState`로 장치 목록, 기본 출력 변경, 볼륨 30%, 밸런스 -0.5(채널 0.30/0.15), 앱 묶기·출력 이동·앱 볼륨·음소거, 입력 레벨 모니터 시작·해제를 확인했다.

## 노트북에서 확인할 것

실제 마이크 신호로 레벨 막대가 움직이는지, 내장 스피커·HDMI·USB·Bluetooth 장치 종류 표시, 장치 연결·해제 때 목록과 기본값, 앱 아이콘, Chrome·Discord 등 여러 스트림 앱의 묶음, 재로그인 후 앱 출력 지정 유지.
