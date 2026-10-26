# 제목 표시줄 벡터 기호

`controls.hpp`는 Shittim의 MIT 라이선스를 따르는 Cairo 경로다. 24px 버튼 안에 세 기호를 같은 16px 폭·1.6px 선 굵기로 그린다. 글꼴 렌더러를 사용하지 않는다.

최대화 중에는 가운데 기호를 같은 크기의 겹친 두 사각형으로 바꾼다. `displayIcon`이 실제 창 상태에 맞는 경로를 선택하고, 플러그인의 각 `CHyprBar`가 자체 텍스처 4개를 캐시한다. 최대화된 창과 일반 창이 같은 전역 버튼 텍스처를 공유하지 않는다.

자체 장식 창의 `decorate=false` 규칙은 그리기와 공간 예약에 함께 적용한다. 숨긴 hyprbars의 높이를 최대화 영역에서 빼지 않도록 예약 높이를 0으로 반환한다.

`scripts/titlebar-plugin.py`가 실행 중인 Hyprland에 맞는 고정된 공식 hyprland-plugins 소스를 다운로드하고, 버튼 텍스처 생성 구문을 이 헤더에 연결한다. Lua의 `fg_color` 처리에서 빠진 `userfg`도 설정해 지정한 색상을 적용한다. 다른 기호는 원래 텍스트 렌더링을 유지한다. 플러그인 이름·설정 API·동작은 hyprbars를 유지하며 버전 문자열로 수정본 로드 여부를 구분한다. 클릭 영역·간격·마우스 동작은 변경하지 않는다.

원본은 Hypr Development의 BSD 3-Clause 라이선스다. 다운로드 소스의 LICENSE를 보존하고 설치된 바이너리 옆에도 복사한다. 새로운 GitHub 저장소나 포크는 만들지 않는다. 설치 절차와 제한은 [공통 제목 표시줄](../../docs/titlebars.md)을 따른다.

실제 경로의 CPU 검사:

```bash
c++ -std=c++23 tests/titlebar-controls.cpp $(pkg-config --cflags --libs cairo) -o /tmp/shittim-controls-test
/tmp/shittim-controls-test
```

GPU 합성과 플러그인 ABI 확인을 대체하는 검사가 아니다.
