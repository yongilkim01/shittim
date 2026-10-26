# 데스크톱 디자인 적용

| 영역 | 조정 |
|---|---|
| Dock | 원본의 64px 높이·32px 아이콘·52px 앱 간격·하단 8px 여백. 절단 모서리와 정적인 얇은 발광, 비활성 앱은 희미한 테두리, 활성 앱은 청록색 면 |
| Dock 끝 | 설정 뒤 구분선과 휴지통. 얇은 선 아이콘 사용. 설정 좌클릭은 Control Center, 우클릭은 App Launcher. 휴지통은 Shittim Files에서 열기 |
| 앱 목록 | 설치된 앱과 기존 사용자 고정 순서 유지. 시안 속 미설치 앱을 추가하지 않음 |
| 공통 제목 표시줄 | 24px 높이, 투명 버튼 배경. Shittim hyprbars 렌더러가 `− / □ / ×`를 글꼴 없이 직접 그린다. 세 기호 모두 실제 폭 16px·선 굵기 1.6px·24px 칸·10px 간격·동일한 청록색. [벡터 렌더러 설치](titlebars.md) 필요 |
| 창 외곽 | 일반 창의 대각선 절단 모서리, 1px 청록색 테두리, 범위 5px의 낮은 농도 발광. 전체 화면은 모서리 규칙에서 제외 |
| 보조 Nemo | 본문 32px 아이콘(`smaller`), 10px 보조 글자, 줌에서 작아지는 파일명은 별도 보정. 메뉴·상태 표시줄 숨김. 원본에서 읽은 `#000c11` 사이드바와 `#000e14`–`#01131c` 본문 색상 |
| Shittim Files | 통합 Home 탭, 96px 사이드바, 기본 폭에서 6열 파일 배열, 32px 아이콘과 9px 글자. 창을 키워도 UI 배율은 유지하며 열 수·목록 영역이 늘어난다. 자체 버튼·프레임은 Qt 벡터 경로 사용. [기능·검증](files.md) |
| 아이콘 | Desktop도 채워진 파란 폴더, Nemo는 서랍형 폴더, Kitty는 원본의 `>_` 터미널. 사용자가 지정한 개별 아이콘 파일은 우선 유지 |
| Chrome | 별도 색상 테마의 탭·툴바·주소창 배경 및 아이콘. 브라우저 개인 설정 파일은 직접 편집하지 않음 |

노트북에서 한 번 실행한다. 현재 설치된 Shittim 제목 표시줄 설정이 있을 때만 함께 갱신하며 새 플러그인을 설치하지 않는다. 기존 사용자 설정은 설치기의 백업/병합 흐름을 따른다.

```bash
cd ~/projects/shittim
git pull --ff-only
bash scripts/apply-desktop-design.sh
```

Nemo는 파일 작업을 마친 뒤 모든 창을 정상적으로 닫고 다시 연다. 메뉴는 Alt를 눌러 일시적으로 표시할 수 있다. 확대·축소는 메뉴의 보기 기능으로 조절한다. 기존 폴더별 보기 설정이 저장되어 있으면 그 폴더는 기존 크기를 유지할 수 있다. 공통 제목 표시줄 자체를 설치하지 않았다면 [제목 표시줄 설치](titlebars.md)를 먼저 따른다.

Chrome의 탭·주소창은 GTK CSS로 전체를 제어하지 못하므로 [공식 Chrome 색상 테마 형식](https://developer.chrome.com/docs/extensions/develop/ui/themes)으로 별도 제공한다.

1. Chrome에서 `chrome://extensions`를 연다.
2. 개발자 모드를 켜고 **압축해제된 확장 프로그램을 로드합니다**를 선택한다.
3. 저장소 안의 `assets/chrome-theme` 폴더를 선택한다. 기본 경로는 `/home/yongil/projects/shittim/assets/chrome-theme`이며 실제 저장소 위치에 맞춘다.

테마는 색상만 포함하며 스크립트/접근 권한/웹페이지 수정 코드를 포함하지 않는다. 원래 테마로 돌아가려면 Chrome 설정 → 모양 → 테마 초기화를 사용한다. 공통 hyprbars와 Chrome 자체 버튼이 중복되면 탭 바 빈 곳 우클릭의 **시스템 제목 표시줄 및 테두리 사용**을 켠다.

Nemo의 구조 한계를 피해 기본 파일 관리자를 별도 Shittim Files로 전환했다. 기존 Nemo 창 자체가 새 앱으로 변하는 것은 아니다. Shittim Files는 원본 크기의 실제 QML 렌더링으로 배치를 비교했다. 파일 목록과 순서는 실제 폴더 내용을 따른다. Chrome 내부 탭 배치와 웹사이트 본문은 색상 테마로 재현되지 않으며 원본과 1:1 완료로 보고하지 않는다.

창별 `rounding_power=1`은 [Hyprland 0.55 Lua 규칙 파서](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/config/lua/bindings/LuaBindingsInternal.hpp)에서 지원되는 값이다. [창 모서리 계산](https://github.com/hyprwm/Hyprland/blob/v0.55.0/src/desktop/view/Window.cpp)이 반경을 절반으로 보정하므로 규칙의 `rounding=12`로 약 6px 절단을 지정했다. 전역 `decoration.rounding_power=1`을 사용한 구성은 아니다.

Dock/QML과 새 SVG는 Qt로 렌더링했고, Nemo는 별도 HOME·가상 X 서버의 실제 GTK3로 테마·아이콘·메뉴 숨김을 확인했다. 이 환경에는 Hyprland가 없으므로 외부 창 장식·발광·hyprbars 버튼의 실제 GPU 합성, 브라우저 결과와 모니터 배율은 노트북에서 확인한다.
