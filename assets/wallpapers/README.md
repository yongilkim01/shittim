# 기본 배경화면

`shittim-lake.png`는 사용자가 제공한 차분한 초기 시안에서 글씨·상단 바·시계·HUD 표시를 제거하고, 어두운 남청색·청록색 산과 호수 구도를 16:9 배경으로 재생성한 이미지다. 기본 내장 `image_gen` 도구를 사용했다. 원본 생성 파일은 Codex 생성 이미지 폴더에 보존하고, 프로젝트가 읽는 이미지는 이 디렉터리에 저장한다. `DesktopSurface.qml`과 설치 검증이 같은 기본 파일을 사용한다.

실제 생성 파일은 1672×941 PNG다. 첨부된 1410×375 참고 이미지보다 픽셀 수가 많으며, 요청한 3840×2160 출력은 생성 도구가 반환하지 않았다. 별도 확대 파일을 4K 원본으로 표기하지 않는다.

생성 요청 원문:

```text
Use case: precise-object-edit / stylized-concept.
Asset type: high-resolution desktop wallpaper for Shittim, a finished opaque landscape image.
Input image: the attached panoramic desktop reference is the visual source. Reconstruct ONLY its underlying landscape, removing every interface overlay. Preserve its restrained dark navy / blackened teal palette, quiet low contrast, layered wooded mountain valley, sparse fine stars, two very thin shooting-star streaks, calm lake reflections, and slender futuristic citadel located about three quarters across the frame on the distant shore. The citadel and one delicate vertical cyan light beam are small accents; do not enlarge or dramatize them.
Remove ALL words, numbers, logos, top bar, icons, time, date, SHITTIM text, system information, horizontal divider lines, HUD circles, clock rings, borders, and interface graphics; naturally reconstruct scenery where these were. Keep the tower's actual architectural light, but remove decorative HUD rings around it.
Make a clean 16:9 wallpaper at 3840x2160 if supported, otherwise the highest native landscape resolution available. Expand the reference's panoramic landscape naturally vertically to fit 16:9 while keeping the tower on the right, distant shore in the lower quarter, and plenty of subdued open sky. Match the attached image's subdued colors, not the vivid saturated blue / dense glowing stars of a dramatic fantasy wallpaper. No large bright nebula, excessive cyan glow, oversaturated blue, bright white clouds, high-contrast reflective lake, people, or additional buildings. Sharp fine painted/illustrated details, quiet atmospheric depth, no text anywhere.
```

