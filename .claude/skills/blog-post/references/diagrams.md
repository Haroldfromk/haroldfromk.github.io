# SVG 다이어그램 규칙

포스트용 다이어그램은 SVG 로 그린 뒤 cairosvg 로 PNG 변환한다.

## 색상과 폰트

- 배경은 투명으로 둔다(배경 `<rect>`를 그리지 않는다). 블로그 라이트/다크 테마 둘 다에서 읽혀야 한다
- 색은 CSS 변수를 쓰지 말고 값을 하드코딩한다. 두 가지 색만 쓴다
  - 기본 선과 글자: 회색 `#71717A`
  - 강조(그림에서 말하고 싶은 쪽): 청록 `#0D9488`, 강조 상자 안쪽은 `rgba(13,148,136,0.08)`
  - 덜 중요한 설명 글자는 같은 회색에 opacity 0.7~0.85
- 선 굵기 2, 강조 2.5. 상자는 모서리 rx 12. 점선(`stroke-dasharray="6 5"`)은 "가리키기만 함", "나중에", "물어보기"처럼 약한 관계에 쓴다
- StreamDeck 시리즈의 기존 그림(`touchdeck-structure.png`)이 기준 모양이다
- 모든 `<text>` 요소의 font-family 에 `Noto Sans CJK KR, monospace` 를 넣는다
  - 한 줄이라도 빠지면 그 줄의 한글이 두부 박스로 깨진다. 전체 라인을 개별 확인한다
- 이모지 금지. cairosvg 가 컬러 이모지를 렌더링하지 못한다

## 레이아웃

- 두 text 요소의 bounding box 가 겹치지 않아야 한다
- 같은 y 좌표에 x 범위가 겹치는 라벨이 없는지 확인한다

## 변환

```bash
/opt/homebrew/bin/python3.12 -I -c "
import cairosvg
cairosvg.svg2png(url='<name>.svg', write_to='<name>.png', output_width=<viewBox 너비 × 2>, output_height=<viewBox 높이 × 2>)
"
```

- cairosvg 는 python3.12 에만 깔려 있다(기본 python3 에는 없다)
- viewBox 는 너비 760 정도로 그리고 두 배로 뽑는다. 글자는 11.5~17 사이

## 확인

변환 후 반드시 PNG 를 Read 로 열어서 눈으로 확인한다. SVG 소스 재검토나 font-family grep 만으로는 부족하다.

확인이 끝난 PNG 는 `assets/images/upload/` 에 넣고 `uploadimg` 로 올린다.
