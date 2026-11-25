# 스펙: blog-post 스킬 보강

작성일: 2026-11-19

## 목적

블로그 레포의 기존 `.claude/skills/blog-post/` 스킬을 보강한다. 새 스킬을 만들거나 사용자 레벨로 옮기지 않는다. 같은 이름의 스킬이 두 개 생기면 어느 쪽이 쓰일지 모른다.

| 지금 있는 것 | 내용 |
| --- | --- |
| SKILL.md | 작업 분담(뼈대는 메인, 본문과 그림은 Sonnet, 검토는 Opus), front matter, 문체, 개념 설명, API 설명, 링크, 헤더, 이미지 규칙 |
| references/diagrams.md | SVG 규칙: 배경 투명, 회색 `#71717A`와 청록 `#0D9488` 두 색, CJK 폰트, 이모지 금지, 라벨 겹침 금지, python3.12 cairosvg로 2배 변환, PNG 육안 확인 |
| scripts/lint_post.py | 금지 문자, 헤더 구분선, `##` 도입부, 헤더 이름, 새 창 링크, 참고자료 형식, front matter와 날짜 |

비어 있는 건 SVG 검사 자동화와 lint 규칙 두 개다. 아래 두 가지만 추가하고 나머지는 건드리지 않는다. 진행 중인 강의가 없으므로 강의 트랜스크립트 흐름은 넣지 않는다.

## 추가 1: check_svg.py

`references/diagrams.md`의 규칙을 스크립트로 검사하고, error가 없을 때만 PNG로 변환한다. 기준은 지금 diagrams.md다. 규칙을 새로 만들지 않는다.

- 위치: `scripts/check_svg.py`
- 실행: cairosvg가 python3.12에만 있으므로 `/opt/homebrew/bin/python3.12 -I ${CLAUDE_SKILL_DIR}/scripts/check_svg.py <이름>.svg`
- 변환: error가 0개면 viewBox의 2배 크기로 같은 이름의 PNG를 만들고 마지막 줄에 경로를 출력한다
- 출력과 종료 코드: lint_post.py와 같은 형식(`<파일>:<줄>: ERROR [<규칙>] ...`), error가 있으면 1

| 규칙 | 검사 | 등급 |
| --- | --- | --- |
| font | 모든 `<text>`, `<tspan>`의 실제 적용 font-family(자기 속성, style, 부모 `<g>` 상속 포함)에 `Noto Sans CJK KR`이 없으면 위반. 요소마다 따로 판정 | ERROR |
| emoji | 텍스트에 이모지 문자. lint_post.py의 EMOJI 범위를 같이 쓴다 | ERROR |
| background | viewBox 전체를 덮는 `<rect>`에 fill이 있으면 위반 (배경은 투명) | ERROR |
| css-var | 파일 어디든 `var(` | ERROR |
| color | fill, stroke에 `#71717A`, `#0D9488`, `rgba(13,148,136,0.08)`, none 외의 색 | WARN |
| overlap | x, y, font-size, text-anchor, 글자 수로 bounding box를 추정해서 겹치는 라벨 쌍 | WARN |
| font-size | 11.5보다 작거나 17보다 큰 글자 | WARN |

### SKILL.md와 diagrams.md 고칠 곳

- SKILL.md front matter의 `allowed-tools`에 check_svg.py 실행 명령을 추가한다.
- diagrams.md의 "변환" 절을 check_svg.py 실행으로 바꾼다. "확인" 절(PNG를 Read로 열어 눈으로 확인)은 그대로 둔다. 스크립트는 육안 확인을 대신하지 않는다.

## 추가 2: lint_post.py 규칙 두 개

사용자가 정한 규칙 중 아직 검사하지 않는 두 가지를 기존 lint_post.py에 더한다. 기존 규칙과 출력 형식은 바꾸지 않는다.

| 규칙 | 검사 | 등급 |
| --- | --- | --- |
| meta | 본문에 "다음 강의에서", "연습으로 남" 같은 메타 마무리 문장 | ERROR |
| header | 헤더에 "(Fluent 버전)"처럼 `(... 버전)` 라벨. 기존 `check_header_name`에 더한다 | ERROR |

SKILL.md의 "문체"와 "헤더 이름"에도 같은 내용을 한 줄씩 추가해서, lint에 걸리기 전에 쓰는 단계에서부터 피하게 한다.

## 검증 방법과 범위 밖

기존 글과 그림에 돌려서, 새 규칙이 맞는 것을 틀렸다고 하지 않는지 확인한다.

- [ ] 보강 전후로 `_posts/`의 최근 글 3개에 lint_post.py를 돌려서, 기존 규칙의 결과가 그대로인지 확인한다
- [ ] 새 규칙 두 개에 걸리는 문장을 넣은 시험용 md 파일로 ERROR가 나오는지 확인한다
- [ ] 레포에 있는 기존 SVG를 check_svg.py로 검사해서, 기준 그림(`touchdeck-structure`)에 ERROR가 없는지 확인한다. 나오면 규칙과 그림 중 무엇이 맞는지 사용자에게 묻는다
- [ ] 일부러 규칙을 어긴 시험용 SVG(폰트 빠진 줄, 이모지, 배경 rect)로 ERROR가 나오는지 확인한다

범위 밖

- SKILL.md의 기존 규칙(작업 분담, 링크, API 설명 등)은 고치지 않는다.
- `deploy_post.py`, `upload_new_images.py`는 수정하지 않는다.
- 블로그 메모 양식 변경은 별도 스펙(`_specs/blog-notes-defect-log.md`)에서 다룬다.
