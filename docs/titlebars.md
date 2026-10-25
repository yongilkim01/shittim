# 공통 제목 표시줄

`hyprpm`은 Arch의 별도 공식 패키지다. `--install-hyprbars`는 누락된 `hyprpm`도 빌드 도구와 함께 먼저 설치한다.

Kitty·Nemo·Chrome 같은 일반 창의 바깥쪽에 [공식 hyprbars](https://github.com/hyprwm/hyprland-plugins/tree/main/hyprbars)의 실제 compositor decoration을 추가한다. Quickshell 창을 외부 앱 위에 겹치는 방식은 사용하지 않는다. 기본 `install.sh`는 플러그인을 설치하지 않는다.

노트북의 실행 중인 Hyprland 안에서 선택적으로 실행한다.

```bash
cd ~/projects/shittim
git pull --ff-only
bash scripts/setup-titlebars.sh --install-hyprbars
```

이 옵션은 공식 pacman의 `base-devel`, `cmake`, `cpio`와 공식 Git 저장소에서 빌드한 hyprbars를 설치·활성화한다. pacman과 hyprpm이 표시하는 내용을 확인한다. AUR, 별도 디스플레이 매니저, 컴포지터 교체는 사용하지 않는다. 실행 중인 Hyprland의 정확한 커밋을 공식 호환 목록과 먼저 비교하고, 확인하지 못한 빌드에서는 파일·패키지를 바꾸기 전에 중단한다. 현재 확인 목록은 공식 0.55.0–0.55.4 / 0.56.0–0.56.2다. 설치 패키지 업데이트 후 실행 중인 Hyprland와 헤더가 다르면 작업을 저장하고 재로그인한 후 다시 실행한다.

`hyprpm`은 현재 버전 헤더를 준비하고 플러그인을 빌드하므로 최초 실행에 시간이 걸릴 수 있다. 설치기를 root로 실행하지 않으며 패키지 명령에만 sudo를 사용한다. 다른 플러그인은 활성화하지 않는다. 이미 hyprbars가 등록되어 있으면 중복 add하지 않는다. 공식 호환 커밋으로 고정해 설치하므로 Hyprland 업그레이드 후에는 해당 커밋을 다시 확인해야 한다. 기존 저장소를 자동 삭제하거나 버전/ABI 검사 실패를 우회하지 않는다. 로드 실패 시 설치 출력을 확인한다.

제목 표시줄 높이는 24px, 배경은 `#020f15`, 글꼴은 Hack Nerd Font Mono다. 원본 시안처럼 버튼 배경을 투명하게 하고 청록색 `− / □ / ×`를 오른쪽에 배치한다.

- `−`: 기존 Shittim Special Workspace 숨김. Dock에서 클릭해 복원한다.
- `□`: 최대화/복원. 전체 화면과 별도 동작이다.
- `×`: 선택한 창의 정상 닫기 요청. 강제 종료하지 않는다.
- 제목 표시줄 드래그: Super 없이 창 이동.
- 제목 표시줄 더블클릭: 최대화/복원.

버튼은 앱 자체 최소화 이벤트를 요구하지 않고 기존 `window-service.py` 제어를 사용한다. 따라서 Kitty에도 동일하게 연결할 수 있다. 앱이 제공하는 CSD의 최소화 기능 자체를 수정한 것은 아니다. 대화상자·장식 없는 특수 창·전체 화면에서의 bar 표시 여부는 hyprbars와 앱의 window hints를 따른다.

Nemo는 모든 창을 정상적으로 닫고 다시 실행한다. `GTK_CSD=0`은 새로 실행하는 앱에 적용되며, 앱이 직접 만든 headerbar는 남을 수 있다. Chrome에 자체 버튼과 새 bar가 중복되면 탭 바 빈 곳을 우클릭해 **시스템 제목 표시줄 및 테두리 사용**을 켠다. 브라우저 프로필을 자동 편집하거나 앱을 강제 종료하지 않는다. 앱의 내부 toolbar와 compositor bar는 서로 다른 영역이다.

설정은 백업 후 `~/.config/hypr/shittim-titlebars.lua`에 생성된다. 기존 Hyprland 진입 파일은 설치기의 백업·병합 흐름으로 이 선택 파일을 읽는다. 다음 로그인에서는 `hyprpm reload`로 활성화된 플러그인을 로드한다. 플러그인이 없으면 옵션/버튼 설정을 건너뛰어 기본 셸은 유지한다.

```bash
bash scripts/setup-titlebars.sh --verify
hyprctl configerrors
```

Kitty·Nemo·Chrome을 각각 두 개 열고 비활성 창의 버튼도 올바른 창에 적용되는지, 숨김 후 Dock 복원, 최대화/복원, 드래그, 전체 화면, 다중 모니터를 확인한다. 플러그인의 실제 GPU 렌더링·입력·빌드는 Windows 정적 검사로 검증하지 않았다.

해제 시 설정 파일을 백업하고 hyprbars만 비활성화한다. Dock과 기존 창 관리 기능은 유지한다.

```bash
bash scripts/setup-titlebars.sh --disable
```
