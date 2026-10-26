# Shittim HUD Controls

Shittim에서 직접 그린 최소화·최대화·닫기 세 기호만 포함한다. 저장소의 MIT 라이선스를 따른다. 일반 글자와 기존 한글·모노스페이스 글꼴을 교체하지 않는다.

| 코드 | 기호 |
|---|---|
| U+10FF00 | 최소화 |
| U+10FF01 | 최대화 |
| U+10FF02 | 닫기 |

1000 UPM, 동일한 900 단위 너비와 110 단위 선 굵기를 사용한다. hyprbars가 시스템 sans를 요청하더라도 이 전용 영역은 설치된 기호 글꼴로 폴백한다. 설치 시 `fc-match`로 세 기호의 실제 선택 결과를 확인한 뒤 제목 표시줄 설정을 쓴다.

배포된 TTF를 그대로 설치하므로 실행 환경에는 FontTools가 필요하지 않다. 개발자가 재생성할 때만 Python FontTools와 `python scripts/build-titlebar-font.py`를 사용한다.
