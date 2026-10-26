# 공통 제목 표시줄

`hyprpm`은 Arch의 별도 공식 패키지다. `--install-hyprbars`는 누락된 `hyprpm`도 빌드 도구와 함께 먼저 설치한다.

Kitty·Nemo·Chrome 같은 일반 창의 바깥쪽에 [공식 hyprbars](https://github.com/hyprwm/hyprland-plugins/tree/main/hyprbars) 기반의 실제 compositor decoration을 추가한다. Shittim은 고정된 공식 소스의 버튼 렌더링 부분을 수정해 최소화·최대화·닫기를 글꼴 없이 그린다. Quickshell 창을 외부 앱 위에 겹치는 방식은 사용하지 않는다. 기본 `install.sh`는 플러그인을 설치하지 않는다. 별도 Shittim Files는 자체 프레임과 세 버튼을 사용하고 전용 창 규칙으로 hyprbars를 비활성화하므로 이 플러그인이 필요하지 않다.

노트북의 실행 중인 Hyprland 안에서 선택적으로 실행한다.

```bash
cd ~/projects/shittim
git pull --ff-only
bash scripts/setup-titlebars.sh --install-hyprbars
```

이 옵션은 공식 pacman의 `base-devel`, `cmake`, `cpio`, `hyprpm`을 설치하고 현재 Hyprland에 맞는 공식 소스에 `native/titlebars/controls.hpp`를 적용해 빌드한다. pacman과 hyprpm이 표시하는 내용을 확인한다. AUR, 별도 디스플레이 매니저, 컴포지터 교체는 사용하지 않는다. 실행 중인 Hyprland의 정확한 커밋을 공식 호환 목록과 먼저 비교하고, 확인하지 못한 빌드에서는 파일·패키지를 바꾸기 전에 중단한다. 현재 확인 목록은 공식 0.55.0–0.55.4 / 0.56.0–0.56.2다. 설치 패키지 업데이트 후 실행 중인 Hyprland와 헤더가 다르면 `hyprpm update` 후 작업을 저장하고 필요하면 재로그인한 후 다시 실행한다.

`hyprpm`은 현재 버전 헤더를 준비하므로 최초 실행에 시간이 걸릴 수 있다. 설치기를 root로 실행하지 않으며 패키지 명령에만 sudo를 사용한다. 다른 플러그인의 활성화 설정은 변경하지 않는다. 이미 공식 hyprbars가 등록되어 있으면 중복 add하지 않는다. 고정 소스의 예상 렌더링 구문이 달라지면 수정을 거부하며, 헤더 커밋과 실행 중인 Hyprland가 다를 때도 중단한다. 빌드 로그는 `${XDG_STATE_HOME:-~/.local/state}/shittim/titlebars-build.log`다. 빌드 실패 시 기존 제목 표시줄을 교체하지 않는다.

제목 표시줄 높이는 24px, 배경은 `#020f15`, 제목 글꼴은 Hack Nerd Font Mono다. 세 버튼은 모두 24px 칸·10px 간격·동일한 `#00d9f5`를 사용한다. 설정의 표준 유니코드 `−`(U+2212), `□`(U+25A1), `×`(U+00D7)를 렌더러가 식별해 선·사각형·대각선으로 그린다. 세 기호의 실제 폭은 모두 16 논리 픽셀, 선 굵기는 모두 1.6 논리 픽셀이다. 모니터 배율에 따라 함께 확대되며 기호 글꼴과 전용 문자 코드가 필요하지 않다. 다른 기호와 제목 텍스트의 기존 렌더링은 유지한다.

[원본 hyprbars](https://github.com/hyprwm/hyprland-plugins/blob/3aa21f2e0ca72412f1b434c3126f8f1fec3c716c/hyprbars/barDeco.cpp#L351)는 기호를 버튼 크기의 62%인 sans 글자로 그린다. 기본 플러그인만 쓰면 글리프별 면적 차이로 최소화·닫기가 작게 보일 수 있다. 이번 수정은 그 경로를 세 기호에 한해 Cairo 벡터 경로로 대체한다. Lua의 `fg_color` 처리에서 빠진 사용자 색상 플래그도 설정해 실제 지정 색상을 사용한다. 생성 텍스처는 기존 GPU 렌더링·위치·투명도·클릭 처리에 그대로 연결하며 필요한 크기가 바뀔 때 갱신한다.

빌드한 `.so`와 원본 BSD 3-Clause 라이선스는 `${XDG_DATA_HOME:-~/.local/share}/shittim/titlebars/`의 버전별 경로에 저장한다. 로드 전에 바이너리 SHA-256, Hyprland 커밋·ABI, 수정 코드 버전을 확인한다. 빌드 완료 후에만 기본 hyprbars를 비활성화하고 수정본 하나를 로드한다. 로드 실패 시 이전 수정본 또는 기본 플러그인 복구를 시도하며 실패를 출력한다. 검증은 실제 로드된 버전이 `shittim-vector-1-...`인지 확인한다. 기본 글꼴 렌더러만 쓰는 경우에는 별도 주의를 출력한다.

이 변경은 `git pull`이나 `apply-desktop-design.sh`만으로 설치되지 않는다. 위의 `bash scripts/setup-titlebars.sh --install-hyprbars`를 한 번 실행해 수정본을 빌드·로드해야 한다. 다음 로그인에서는 생성한 Lua 설정이 저장소의 로더를 실행하며 다운로드·빌드 없이 수정본을 다시 로드한다. Hyprland 또는 렌더러 코드 변경 후에는 같은 설치 명령으로 다시 빌드한다. 이전 버전이 만든 전용 기호 글꼴 링크는 현재 저장소의 이전 글꼴을 가리킬 때만 백업으로 이동하며 사용자가 교체한 글꼴은 보존한다.

- `−`: 기존 Shittim Special Workspace 숨김. Dock에서 클릭해 복원한다.
- `□`: 최대화/복원. 전체 화면과 별도 동작이다.
- `×`: 선택한 창의 정상 닫기 요청. 강제 종료하지 않는다.
- 제목 표시줄 드래그: Super 없이 창 이동.
- 제목 표시줄 더블클릭: 최대화/복원.

버튼은 앱 자체 최소화 이벤트를 요구하지 않고 기존 `window-service.py` 제어를 사용한다. 따라서 Kitty에도 동일하게 연결할 수 있다. 앱이 제공하는 CSD의 최소화 기능 자체를 수정한 것은 아니다. 대화상자·장식 없는 특수 창·전체 화면에서의 bar 표시 여부는 hyprbars와 앱의 window hints를 따른다.

Nemo는 모든 창을 정상적으로 닫고 다시 실행한다. `GTK_CSD=0`은 새로 실행하는 앱에 적용되며, 앱이 직접 만든 headerbar는 남을 수 있다. Chrome에 자체 버튼과 새 bar가 중복되면 탭 바 빈 곳을 우클릭해 **시스템 제목 표시줄 및 테두리 사용**을 켠다. 브라우저 프로필을 자동 편집하거나 앱을 강제 종료하지 않는다. 앱의 내부 toolbar와 compositor bar는 서로 다른 영역이다.

설정은 백업 후 `~/.config/hypr/shittim-titlebars.lua`에 생성된다. 기존 Hyprland 진입 파일은 설치기의 백업·병합 흐름으로 이 선택 파일을 읽는다. 플러그인이 없으면 옵션/버튼 설정을 건너뛰어 기본 셸은 유지한다. 로더는 동시에 여러 번 실행되어도 파일 잠금을 통해 중복 로드를 방지한다.

```bash
bash scripts/setup-titlebars.sh --verify
hyprctl configerrors
```

Kitty·Nemo·Chrome을 각각 두 개 열고 세 기호의 너비, 비활성 창의 버튼 대상, 숨김 후 Dock 복원, 최대화/복원, 드래그, 전체 화면, 다중 모니터를 확인한다. 재로그인 후 `--verify`를 다시 실행해 자동 로드를 확인한다. 실제 C++ 경로의 CPU 래스터 검사에서는 100/125/150/200% 배율에서 세 폭이 각각 16/20/24/32px임을 확인했다. 플러그인 전체의 컴파일·GPU 렌더링·입력·재로그인은 Arch 노트북에서 검증해야 한다.

해제 시 설정 파일을 백업하고 hyprbars만 비활성화한다. Dock과 기존 창 관리 기능은 유지한다.

```bash
bash scripts/setup-titlebars.sh --disable
```
