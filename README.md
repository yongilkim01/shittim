# Shittim

Arch Linux + Hyprland + Quickshell 기반 데스크톱 환경. SHITTIM HUD 디자인 시스템을 사용하며 워크스페이스·네트워크·볼륨·배터리·시계를 표시한다.

상단 바 오른쪽을 클릭하면 Control Center를 연다. 원본 시안 5번 패널의 3열 타일·두 줄 슬라이더·3열×2행 버튼을 사용하며 시스템 제어는 하위 화면에서 관리한다. [Control Center 사용법·패키지·실기 검사](docs/control-center.md)를 참고한다.

**Super+Space**로 전용 App Launcher를 연다. 원본 시안 2번 패널을 재현하며 실제 XDG 앱 검색·아이콘·키보드 탐색·터미널 앱 실행을 지원한다. 검증 전까지 **Super+R의 Fuzzel은 유지**한다. [런처 적용·검증·Fuzzel 대체/복원](docs/app-launcher.md)을 참고한다.

상단 바의 종 아이콘은 원본 시안 3번의 Notification Center를 연다. 실제 Linux 알림·팝업·세션 기록·액션·미읽음·ALL/SYSTEM/APP 필터와 Control Center 공통 DND를 지원한다. 다른 알림 데몬은 자동 종료하지 않는다. [알림 적용·충돌 검사·실기 테스트](docs/notifications.md)를 참고한다.

상단 바의 **SHITTIM 로고**는 원본 시안 4번의 System Dashboard를 연다. CPU·RAM·GPU·온도·Storage·Network의 실제 Linux 정보를 표시하며, 사이드바는 기존 런처와 시스템 제어 서비스를 재사용한다. [대시보드 사용법·센서 지원·검증](docs/dashboard.md)을 참고한다.

상단 바의 **음악 아이콘**은 원본 시안 6번의 App / Media Controls를 오른쪽 하단에 연다. 실제 MPRIS 재생·탐색·플레이어 전환과 설치된 즐겨찾기 앱 실행·기존 창 활성화를 지원한다. [미디어 사용법·즐겨찾기 설정·실기 검사](docs/media-controls.md)를 참고한다.

기본 파일 관리자는 **Shittim Files**이며 Nemo는 파일 작업과 보조 탐색에 유지한다. 이미지·PDF·미디어 앱은 **Swayimg / Zathura / VLC**다. Chrome은 AUR 설치를 명시적으로 선택한다. 기본 파일 연결·포털·캡처·잠금·선택적 클립보드 기록과 진단은 [Desktop Essentials](docs/desktop-essentials.md)에 정리되어 있다.

일반 창의 Floating 기본 배치, 마우스 테두리 크기 조절, Alt+Tab, 창 목록의 숨김/복원, Nemo GTK HUD/아이콘 구성은 [Desktop UX](docs/desktop-ux.md)를 따른다. 음표 아이콘 우클릭으로 열린 창을 관리하며 Dock 우클릭으로 해당 앱의 여러 창을 선택한다. 앱 자체 최소화/제목 표시줄의 Hyprland 지원 한계와 실제 마우스 검증 절차도 해당 문서에 구분해 두었다.

원본 성과 호수 배경, 실제 바탕화면 파일 아이콘, 독립된 하단 중앙 Dock, 호버 창 캡처와 절반/사분면 드래그 스냅은 [바탕화면·Dock 통합](docs/desktop-shell.md)을 따른다. Dock 고정·순서와 모니터별 아이콘 위치는 사용자 경로에 저장한다. 앱 자체 최소화는 설치된 Hyprland의 공식 이벤트 지원 여부를 검사해 구분한다.

Kitty·Nemo·Chrome의 공통 제목 표시줄과 최소화·최대화·닫기 버튼은 [선택 설치형 hyprbars 연동](docs/titlebars.md)을 사용한다. 기본 설치는 외부 플러그인을 자동으로 설치하지 않으며, 노트북에서 `bash scripts/setup-titlebars.sh --install-hyprbars`를 실행할 때만 공식 소스를 빌드한다.

## 새 Arch Linux 환경 설치

원본 배치의 전용 [Shittim Files](docs/files.md)와 Dock·앱 제목 표시줄·아이콘·Chrome 색상 테마 적용은 [데스크톱 디자인](docs/desktop-design.md)을 따른다. 기존 설치는 `bash scripts/apply-desktop-design.sh`로 갱신한다.

설치된 Arch Linux x86_64에서 네트워크 연결과 일반 사용자 계정, `git`, `sudo` 및 해당 사용자의 sudo 권한을 먼저 준비한다. Arch 설치 ISO/chroot나 root 계정에서 실행하지 않는다. TTY 로그인 비밀번호는 유지하며 디스플레이 매니저와 자동 로그인은 설치하지 않는다.

```bash
git clone https://github.com/yongilkim01/shittim.git
cd shittim
./install.sh --dry-run
./install.sh
./scripts/verify.sh
```

Chrome까지 설치하려면 `./install.sh --with-chrome`을 사용한다. AUR 빌드 코드 실행 전 터미널에서 별도 확인을 받으며, 기존 `yay`가 있으면 활용한다. `yay`가 없으면 AUR 소스를 내려받아 검토한 뒤 일반 사용자로 `makepkg -si`를 실행한다. Chrome 프로필과 기존 브라우저 데이터는 변경하지 않는다.

`--dry-run`은 파일·패키지·서비스를 변경하지 않는다. Python이 없는 최소 설치에서는 설정 파일의 상세 검사가 Python 설치 뒤 수행됨을 알린다. 실제 설치는 다음 순서로 진행한다.

1. `install-packages.sh`: `pacman -Syu`로 전체 업그레이드하고 공식 저장소의 패키지를 `--needed`로 설치한다. pacman의 확인 질문은 유지한다.
2. `link-dotfiles.sh`: 수집본을 검사한 뒤 파일별로 백업하고 사용자 설정에 심볼릭 링크한다.
3. `setup-autostart.sh`: 원본 Lua 설정을 보존하고 Hyprland 진입 파일·사용자 서비스·로그인 프로필을 구성한다.
4. `setup-files.sh`: 전용 파일 관리자 앱을 등록하고 기존 Nemo 고정 항목을 백업하며 한 번 이관한다.
5. `setup-desktop.sh`: 설치된 앱의 MIME 연결, Hyprland 전용 포털 선택, 충돌을 검사한 단축키를 백업하며 구성한다.
6. `setup-desktop-ux.sh`: Floating 창 정책, 창 관리 단축키, GTK HUD 스타일·아이콘·Nemo 설정을 백업하며 적용한다.
7. `verify.sh`: 패키지, 링크, 자동 실행, 기본 앱, Desktop UX, 진입점, 서비스 상태를 검사한다. `--with-chrome`이면 공식 패키지 단계 뒤 AUR Chrome 설치를 별도로 수행한다.

설치 전체를 `sudo`로 실행하지 않는다. pacman과 시스템 서비스 구성에만 sudo를 사용한다. 이미 활성화된 네트워크·오디오·데스크톱을 강제로 restart하지 않는다. 다른 네트워크 관리자와 충돌하면 연결을 끊는 대신 원인을 출력하고 중단한다. 실패 단계와 종료 코드를 확인해 원인을 해결한 뒤 `./install.sh`를 재실행한다. 패키지 업그레이드는 자동으로 되돌리지 않는다.

설치 후 작업을 저장하고 직접 로그아웃한 다음 **tty1에서 비밀번호로 로그인**하면 `start-hyprland` → Shittim 순서로 실행된다. 커널·그래픽 드라이버가 갱신되었다면 직접 재부팅한다. 설치 프로그램은 재부팅·로그아웃하지 않는다. 장치별 NVIDIA 설정 등은 [Hyprland 설치 안내](https://wiki.hypr.land/Getting-Started/Master-Tutorial/)를 확인한다.

## 기본 데스크톱과 미디어 테스트

기존 노트북에서 이번 구성을 적용할 때:

```bash
cd ~/projects/shittim
./install.sh --dry-run --with-chrome
./install.sh --with-chrome
hyprctl reload
systemctl --user restart shittim.service
bash scripts/verify-desktop.sh
```

포털 설정은 현재 화면 공유를 끊지 않도록 자동 restart하지 않는다. 작업 저장 후 한 번 로그아웃·로그인하면 새 선택이 적용된다.

| 단축키 | 기능 |
|---|---|
| Super+B | Chrome 실행 또는 기존 창 활성화 |
| Super+E | Shittim Files로 홈 폴더 열기 |
| Super+L | Shittim HUD Hyprlock으로 수동 잠금 |
| Print / Shift+Print | 전체 / 영역 캡처, 파일 저장과 클립보드 복사 |
| Super+Shift+V | 선택적으로 켠 클립보드 기록 보기 |

충돌한 사용자 단축키는 유지하고 설치 출력에 표시한다. 의도적으로 교체할 때만 `bash scripts/setup-desktop.sh --replace-bindings` 후 `hyprctl reload`를 실행한다. 자동 잠금·절전·클립보드 수집은 기본으로 켜지 않는다.

**A. 브라우저**: Super+B, 런처의 Chrome 검색, 앱 바 Chrome 아이콘을 각각 확인한다. 아래 명령의 연결 결과는 `google-chrome.desktop`이어야 한다.

```bash
xdg-mime query default x-scheme-handler/http
xdg-mime query default x-scheme-handler/https
xdg-settings get default-web-browser
xdg-open https://www.youtube.com
```

**B. 파일 관리자**: Super+E로 홈 폴더를 열고 실제 PNG/JPEG/WebP/GIF·PDF·MP4/MKV·MP3/FLAC 파일을 Shittim Files에서 연다. 이미지=Swayimg, PDF=Zathura, 영상·음악=VLC여야 한다. 실제 파일 경로를 따옴표로 감싸 `xdg-open "경로"`로도 확인한다.

**C. 시스템**: Print / Shift+Print와 Control Center Screenshot을 확인한다. 캡처는 `$(xdg-user-dir PICTURES)/Screenshots`에 저장되고 이미지 붙여넣기가 가능해야 한다. `printf 'Shittim clipboard test' | wl-copy` 후 `wl-paste`로 텍스트 복사를 확인한다. Super+L은 현재 사용자 비밀번호로 잠금 해제되어야 한다. Chrome의 파일 업로드·저장 대화상자와 화면 공유 선택도 확인한다. 설치 검사가 실제 잠금이나 화면 공유를 대신 검증하지 않는다.

**D. 미디어**: Chrome에서 YouTube 음악을 재생한 뒤 아래를 실행한다. `playerctl metadata`는 곡·URL 정보를 포함할 수 있으므로 출력을 그대로 Git에 올리지 않는다.

```bash
playerctl -l
playerctl metadata
playerctl status
python3 scripts/diagnose-media.py
bash scripts/verify-media.sh
```

상단 음악 아이콘에서 곡·아트·재생/일시정지와 지원되는 이전/다음·Seek를 확인한다. Chrome을 종료하면 플레이어 목록이 갱신되어야 한다. Chrome과 별개인 로컬 MPRIS 검사는 다음 실제 WAV 파일로 진행한다. 이미 파일이 있으면 생성기는 덮어쓰지 않고 중단한다.

```bash
python3 scripts/make-test-media.py
vlc --extraintf=dbus "$HOME/Music/shittim-test.wav"
playerctl -l
playerctl --player=vlc status
python3 scripts/diagnose-media.py
```

여러 VLC 인스턴스가 있으면 `playerctl -l`에 표시된 실제 이름을 `--player=`에 지정한다. WAV에는 아티스트·아트가 없으므로 빈 아티스트와 기본 아이콘이 정상이다. 개인 음악 파일로 아티스트·앨범 아트와 긴 곡 Seek를 추가 검사한다. Chrome에 MPRIS가 등록되지 않아도 VLC가 정상이라면 브라우저 쪽 설정·지원 문제를 구분할 수 있다.

## 기존 Arch Linux 설정 수집

이 스크립트는 실제 Arch 노트북에서 실행한다. Windows에는 노트북 설정 사본을 임의로 만들지 않는다.

수집기에는 Python 3가 필요하다. 아직 없다면 `sudo pacman -Syu --needed python`으로 설치한 뒤 진행한다.

```bash
cd /home/yongil/projects/shittim
./scripts/capture-config.sh --dry-run
./scripts/capture-config.sh
./scripts/check-secrets.sh
git status --short
git add -N -- dotfiles
git diff -- dotfiles
```

마지막 diff를 직접 검토한 뒤 안전한 파일만 커밋한다. 이전 수집본과 다른 파일은 기본적으로 보류한다. 갱신하려면 `./scripts/capture-config.sh --update`를 사용하며 이전 수집본은 저장소 밖 사용자 상태 디렉터리에 백업한다. 수집기가 Git add·commit·push를 자동 수행하지는 않는다.

```bash
./scripts/check-secrets.sh
git add -- dotfiles
git diff --cached -- dotfiles
git commit -m "chore: capture reviewed Arch desktop configuration"
git push origin main
```

수집된 설정을 원격에 반영하면 새 기기에서는 같은 저장소를 clone하고 `./install.sh`만 실행하면 된다. 수집본이 없으면 기존 사용자 설정을 유지하고, Hyprland Lua 설정마저 없는 새 환경에는 설치된 패키지의 `/usr/share/hypr/hyprland.lua`를 사용한다. Kitty·Fcitx5·Fontconfig는 수집본이 없으면 기본 동작을 사용한다. 한글 입력 프로필도 수집되지 않았다면 첫 세션에서 `fcitx5-configtool`로 Hangul을 추가한다.

수집 허용 범위:

- `~/.config/hypr/`의 Lua·conf 파일: `hyprland.lua`와 분리된 설정 모듈.
- `~/.config/kitty/`의 conf 파일.
- `~/.config/fcitx5/`의 `config`, `profile`, conf 파일.
- `~/.config/fontconfig/`의 conf 파일. 현대 경로가 없을 때만 `~/.fonts.conf`도 확인한다.
- `~/.config/environment.d/`의 conf 파일.

`XDG_CONFIG_HOME`을 지정했다면 해당 경로를 사용한다. 파일이 없으면 건너뛴다. SSH 키, NetworkManager 연결 프로필, 임의 셸 프로필, 브라우저 저장소는 수집하지 않는다. 설정 밖을 가리키는 링크·바이너리·큰 파일·인증 값 의심 패턴은 제외하며 내용은 출력하지 않는다. `.gitignore`와 `check-secrets.sh`로 추가 검사한다. 정적 패턴 검사만으로 모든 형태의 비밀을 판별할 수는 없으므로 커밋 전 직접 검토가 필수다.

외부 스크립트·테마·플러그인·절대 경로를 참조하는 설정은 해당 의존성이 새 기기에도 있는지 검토한다. 제외된 파일과 AUR 프로그램을 자동으로 복사하거나 실행하지 않는다. 원본 설정은 수집 과정에서 수정하지 않는다.

## 자동 실행과 복구

Hyprland 0.55 이상과 Quickshell 0.3.2 이상을 확인한다. 공식 Lua API인 [`hl.on("hyprland.start", ...)`와 `hl.exec_cmd()`](https://wiki.hypr.land/Configuring/Basics/Autostart/)를 사용하며, `start-hyprland`는 [공식 TTY 실행 방식](https://wiki.hypr.land/Getting-Started/Master-Tutorial/)이다. `hyprland.conf`를 Lua로 추측 변환하지 않는다.

- `~/.config/hypr/shittim-base.lua`: 수집된 원본의 링크. 수집본이 없으면 기존 Lua 원본의 사본 또는 설치된 공식 기본 설정의 링크다.
- `~/.config/hypr/hyprland.lua`: 원본을 `dofile()`로 불러오고 시작·종료 이벤트만 추가하는 관리 파일. 원본의 분리된 모듈은 기존 설정 디렉터리에서 그대로 참조한다.
- `~/.config/systemd/user/shittim*.service`: Shittim·Fcitx5·인증 에이전트 사용자 서비스. Hyprland 시작 이벤트가 서비스를 시작하며 로그는 journal에 남는다.
- Bash의 실제 로그인 프로필 또는 Zsh의 `.zprofile`: tty1, SSH 아님, 기존 그래픽 세션 없음 조건에서만 시작한다. Bash·Zsh 외 로그인 셸은 자동 변경하지 않고 중단한다.

기존 프로필에 단순한 `start-hyprland` 자동 실행이 있으면 그 명령과 조건을 유지하며 중복 블록을 추가하지 않는다. 이 경우 기존 TTY·SSH 조건은 사용자가 확인한다. 별도 config 인자, UWSM 등 복잡한 세션 명령은 자동으로 덮어쓰지 않고 중단한다.

저장소 경로는 실행 스크립트 위치에서 계산한다. 관리 파일에는 설치 시점의 실제 경로를 기록하므로 저장소를 옮긴 뒤에는 `./scripts/setup-autostart.sh`를 다시 실행한다. 같은 사용자 세션의 Shittim은 서비스와 `flock`으로 중복 실행을 막고 이미 직접 실행된 같은 Quickshell 진입점도 `/proc`에서 확인한다. 수동 실행도 `./scripts/run-shell.sh`를 사용한다.

원본을 교체할 때는 `${XDG_STATE_HOME:-$HOME/.local/state}/shittim/backups/` 아래에 날짜·실행별로 백업한다. 다른 설정 파일을 통째로 지우지 않으며 디렉터리 링크가 있으면 원본을 보존한 로컬 사본으로 전환한 뒤 필요한 파일만 연결한다. 백업은 Git 저장소 밖에 남긴다.

복구가 필요하면 Ctrl+Alt+F2로 tty2에 로그인한다. 새로 설치한 tty1 자동 실행을 잠시 막으려면:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/shittim"
touch "${XDG_CONFIG_HOME:-$HOME/.config}/shittim/disable-autostart"
```

기존 프로필의 자동 실행을 그대로 사용한 경우에는 해당 프로필의 기존 명령을 직접 비활성화한다. 백업 위치와 원인을 확인해 설정을 복원하거나 수정하고 설치를 재실행한다. 정상화한 뒤 위 `disable-autostart` 파일을 제거한다.

```bash
./scripts/verify.sh --dry-run
./scripts/verify.sh
hyprctl -j configerrors
systemctl --user status shittim.service shittim-fcitx5.service shittim-polkit.service
journalctl --user -u shittim.service -b --no-pager
```

TTY에서는 아직 그래픽 프로세스가 없어도 설치 상태를 검사한다. 새 설정 적용 전의 기존 Hyprland 세션에서 Shittim 서비스가 비활성이면 다음 로그인 안내를 표시한다.

### 로그인 실패 진단 파일 전달

tty2 또는 수동으로 실행한 Hyprland의 Kitty에서 저장소 디렉터리로 이동한 뒤 실행한다. 재부팅이나 데스크톱 종료는 필요 없다.

```bash
git pull --ff-only
./scripts/diagnose.sh --publish
```

로그인 프로필의 실행 조건, 설치 검사 결과, 관련 서비스 상태·현재 부팅 journal, 최근 Hyprland 로그, `~/shittim-start.log`를 `diagnostics/latest.txt` 하나에 모으고 해당 파일만 커밋·푸시한다. 기존 설정·서비스는 변경하지 않으며 프로필을 실행하지 않는다. 없는 명령·접근 권한·시간 초과도 보고서에 기록하고 다른 수집을 계속한다. journal 접근에 sudo를 요구하지 않는다.

비밀 정보 의심 줄과 긴 인증 값은 제외하고 홈 경로·호스트 이름·IPv4·MAC 주소를 가린다. 전체 환경 변수, Wi-Fi 설정, SSH 파일, 셸 기록은 수집하지 않는다. 임의 애플리케이션이 로그에 출력한 모든 개인 정보를 자동으로 판별할 수는 없다. 업로드 전에 직접 검토하려면 `./scripts/diagnose.sh`로 수집만 하고 `diagnostics/latest.txt`를 읽는다. 원본 로그는 Git에 복사하지 않는다.

`--publish`는 main 브랜치와 Shittim origin을 확인한다. 이미 스테이징한 변경이나 미전송된 다른 파일의 커밋이 있으면 중단하며, 다른 변경을 함께 커밋하지 않는다. Git 인증·사용자 이름·이메일은 기존 설정을 사용한다. 푸시가 실패해도 진단 파일과 생성한 커밋은 남으며 강제 푸시·자동 병합을 하지 않는다. 인증 문제를 해결한 뒤 `git push origin main`으로 다시 전송할 수 있다.

### `start-hypland` 오타 복구

진단에서 `.bash_profile`의 `exec start-hypland` 오타가 확인된 경우 다음을 실행한다.

```bash
git pull --ff-only
./scripts/repair-login.sh
```

오타가 있는 단순 실행 줄을 원문 주석이 붙은 `:` 명령으로 바꾸고, Shittim의 정상 tty1 자동 실행 블록을 유지·구성한다. 비어 있는 `if` 본문이 생기지 않도록 하며 Bash 문법 검사 후에만 적용한다. 원래 프로필과 `disable-autostart` 파일은 저장소 밖 설치기 백업 경로로 이동·보존한다. 중지 파일을 해제하므로 다음 tty1 로그인에서 정상 자동 실행이 적용된다. 현재 세션은 종료하지 않는다. 작업을 저장한 뒤 SUPER+M으로 로그아웃하고 Ctrl+Alt+F1의 tty1에서 로그인한다. `./scripts/repair-login.sh --dry-run`으로 변경 없이 확인할 수도 있다. 복잡한 인자가 붙은 오타 명령은 자동으로 수정하지 않는다.

## 패키지

전체 목록은 `scripts/packages.txt`에 있다. 작성 시 Arch 공식 저장소에서 이름을 확인했고 실제 설치에서도 `pacman -Si`로 공식 저장소 소속을 다시 검사한다. AUR이 필요한 항목이 추가되면 별도 안내와 명시적 동의가 필요하며 현재 설치기는 AUR을 사용하지 않는다.

| 역할 | 공식 패키지 |
| --- | --- |
| 데스크톱 | `hyprland`, `quickshell`, `kitty`, `git`, `dolphin`, `fuzzel` |
| 네트워크·전원 | `networkmanager`, `upower` |
| 오디오 | `pipewire`, `pipewire-audio`, `pipewire-pulse`, `wireplumber`, `libpulse` |
| 밝기·미디어 단축키 | `brightnessctl`, `playerctl` |
| 한글 입력 | `fcitx5`, `fcitx5-hangul`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-configtool` |
| 폰트 | `ttf-hack-nerd`, `ttf-d2coding-nerd`, `fontconfig` |
| 데스크톱 통합 | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`, `polkit-kde-agent`, `wl-clipboard`, `xdg-utils`, `xdg-user-dirs` |
| 설치·검증 도구 | `python`, `lua`, `util-linux`, `procps-ng`, `dbus` |

수집된 Hyprland 설정의 파일 관리자(SUPER+E), 런처(SUPER+R), 밝기·미디어 키에 필요한 [Dolphin](https://archlinux.org/packages/extra/x86_64/dolphin/), [Fuzzel](https://archlinux.org/packages/extra/x86_64/fuzzel/), [brightnessctl](https://archlinux.org/packages/extra/x86_64/brightnessctl/), [playerctl](https://archlinux.org/packages/extra/x86_64/playerctl/)도 설치 목록에 포함한다. 설치와 검증은 같은 `scripts/packages.txt`를 읽는다.

Arch의 D2Coding Nerd Font 실제 family를 `fc-list`에서 탐색하고 `D2Coding` 별칭을 사용자 Fontconfig에 추가한다. 기존 `shell/`의 폰트 지정·디자인 코드는 변경하지 않는다. 관련 공식 패키지: [Hyprland](https://archlinux.org/packages/extra/x86_64/hyprland/), [Quickshell](https://archlinux.org/packages/extra/x86_64/quickshell/), [Fcitx5 Hangul](https://archlinux.org/packages/extra/x86_64/fcitx5-hangul/), [Hack Nerd Font](https://archlinux.org/packages/extra/any/ttf-hack-nerd/), [D2Coding Nerd Font](https://archlinux.org/packages/extra/any/ttf-d2coding-nerd/).

## 설치기 검사

```bash
for script in install.sh scripts/*.sh; do bash -n "$script" || exit; done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
./scripts/check-secrets.sh
```

파일 작업 테스트는 임시 홈 디렉터리를 사용한다. 실제 pacman 설치·Hyprland 그래픽 실행·노트북 장치 검증은 해당 Arch 환경에서 수행한다.

## 저장소 구조

```text
shittim/
├── shell/
│   ├── shell.qml
│   ├── components/
│   ├── ui/
│   └── tests/
├── dotfiles/
│   ├── hypr/
│   ├── kitty/
│   ├── fcitx5/
│   ├── fontconfig/
│   └── environment.d/
├── scripts/
│   ├── capture-config.sh
│   ├── install-packages.sh
│   ├── link-dotfiles.sh
│   ├── setup-autostart.sh
│   ├── verify.sh
│   └── ...
├── tests/
├── docs/
├── install.sh
├── README.md
└── LICENSE
```

Quickshell 소스와 UI 테스트는 `shell/`, 설치기 테스트는 루트 `tests/`에 있다. 실제 사용자 dotfiles는 Arch에서 수집해 검토한 뒤 같은 저장소에 반영한다.

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
git -c safe.directory=C:/Users/User/Desktop/Yongil/projects/shittim commit -m "feat: automate Arch desktop setup"
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
