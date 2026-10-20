---
name: blog-post
description: haroldfromk.github.io Jekyll 블로그 포스트를 작성하거나 다듬을 때 쓴다. 문체 규칙(em dash 와 가운뎃점 금지, 기술 용어 영어 유지), 헤더 이름과 구분선, 개념 설명과 코드에 나온 API 설명, 새 창 링크, front matter 형식, 그림과 스크린샷 넣는 법을 적용하고 lint script 로 검증한다. _posts 아래 markdown 을 쓰거나 고치거나 검토할 때, 또는 블로그 글 정리를 요청받을 때 사용한다.
argument-hint: [post-path]
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/lint_post.py *)
---

# 블로그 포스트 작성 규칙

대상 파일: $ARGUMENTS

현재 시각: !`date "+%Y-%m-%d %H:%M:%S %z"`

## Front matter

```yaml
---
title: 제목
writer: Harold
date: YYYY-MM-DD HH:MM:SS +0900
categories: [상위분류, 하위분류]
tags: [Tag1, Tag2]

toc: true
toc_sticky: true
published: true
---
```

- 파일명은 `_posts/<분류>/YYYY-MM-DD-<slug>.md` 이고, 날짜는 front matter 의 date 와 같은 날로 맞춘다
- date 는 위의 현재 시각보다 미래면 안 된다. 미래 날짜 포스트는 `blogrun` 에서 보이지 않는다
- tags 는 기존 포스트처럼 대문자로 시작하는 형식(SwiftUI, Combine)을 따른다

## 문체

- em dash (U+2014), en dash (U+2013), 가운뎃점 (U+00B7) 을 쓰지 않는다. 하이픈(-)만 쓴다
- 기술 용어는 한글로 번역하지 않고 영어 그대로 쓴다 (route, parameter, context window)

## 개념 설명

- 글에 처음 나오는 핵심 개념(기술 이름, 원리, 용어)은 "이걸 썼다"로 끝내지 말고 반드시 설명한다. 그게 무엇인지, 쉬운 비유, 이 글에서 왜 필요했는지를 쓴다
- 핵심 개념은 그 개념을 모르면 글의 흐름을 따라갈 수 없는 것이다. 이런 개념은 처음 나오는 자리에 `### <개념>이란?` 같은 소제목을 두고 설명한다
- 지나가듯 한 번 나오는 말은 소제목 없이 괄호 안 한 줄로 푼다. 예: `UserDefaults`(기기에 작게 저장하는 칸)
- 개념 설명에는 가급적 그림을 직접 만들어 넣어 이해를 돕는다. 그림은 성질 하나만 단순하게 그린다. 넣는 법은 아래 이미지 규칙을 따른다
- 비전공자도 따라올 수 있게 쓴다. 설명에 쓴 낱말이 또 다른 설명이 필요한 말이면 그것도 풀어 쓴다

## 코드에 나온 API

- 코드 블록에 처음 나온 Apple 프레임워크나 라이브러리 API(타입, 메서드, 속성, 함수)는 그 코드 블록 바로 아래에 설명한다. Swift 와 Python 표준 라이브러리도 포함한다. `guard let`, `if` 같은 언어 문법은 대상이 아니다. 나중에 이 글을 보고 그 API를 다시 쓸 수 있어야 한다
- 설명은 코드 블록마다 `####` 소제목 하나 아래에 모은다. 소제목은 그 코드가 하는 일과 핵심 API 이름으로 짓는다(예: `#### NSBitmapImageRep으로 아이콘을 PNG로 만들기`). 아래 헤더 규칙을 따른다
- 소제목 아래 모양은 내용에 따라 세 가지로 고른다
  - 기본은 문장이다. API 한두 개면 "[`Bundle(url:)`](문서){:target="_blank"}은 번들 폴더를 열어 `Info.plist`를 읽는다. 번들이 아니면 nil이라 `guard let`으로 걸렀다"처럼 쓴다
  - 코드가 순서대로 여러 API를 부르면(그림판 만들기 → 그리기 → PNG로 뽑기, 압축기 만들기 → 설정 → 시작) 번호 목록으로 단계를 풀어 쓴다. 단계마다 그 단계에서 쓴 API를 문장 안에서 설명한다
  - 같은 종류의 옵션이 나란히 여러 개일 때만(설정 속성, 설정 키, modifier 목록) `| API | 하는 일 |` 표로 쓴다. 한두 줄짜리 표는 만들지 않는다
- API 이름은 백틱으로 감싸 그 API의 문서 링크로 하고 `{:target="_blank"}`를 붙인다. 예: [`GeometryReader`](https://developer.apple.com/documentation/swiftui/geometryreader){:target="_blank"}
- 그게 무엇인지, 이 코드에서 무엇에 썼는지, 인자와 돌려주는 값의 뜻을 쓴다. 쓸 때 주의할 점은 마지막에 한두 문장으로 쓴다
- 같은 API는 글에서 처음 나올 때만 설명한다. `CGFloat`, `CGSize`처럼 아주 기본적인 타입은 한 줄로 묶어 짧게 쓴다

### Apple 문서 링크 확인

Apple 문서 링크는 넣기 전에 열리는지 확인한다. 문서 주소 `https://developer.apple.com/documentation/<경로>` 의 `<경로>` 를 그대로 쓴다.

```bash
curl -s -o /dev/null -w '%{http_code}\n' "https://developer.apple.com/tutorials/data/documentation/<경로>.json"
```

- 200 이 나와야 한다. 경로는 소문자로 쓴다 (`swiftui/appstorage`)
- 같은 이름의 메서드가 여러 개면(overload) 경로 끝에 `-3n9rf` 같은 꼬리가 붙어서 이름만으로는 404 가 난다. 꼬리는 추측하지 말고, 상위 타입의 JSON 에서 `references` 의 key 를 찾아 고른다. 예: `foundation/bundle.json` 안의 `.../Bundle/init(url:)-3n9rf`
- Apple 이 아닌 문서는 링크 주소를 그대로 열어 200 인지 확인한다

## 링크

- 외부 링크는 inline 으로 쓰고 바로 뒤에 `{:target="_blank"}` 를 붙여 새 창에서 열리게 한다
- `[text]: url` 형태의 reference 링크는 쓰지 않는다
- 이 블로그의 다른 포스트 링크(haroldfromk.github.io)에는 붙이지 않는다

링크는 두 자리에 둔다.

- 본문: 읽다가 바로 눌러보는 링크다
  - API 는 설명하는 자리에 [`API 이름`](url){:target="_blank"} 처럼 백틱 링크로 건다. Docs 나 출처는 붙이지 않는다
  - 문장에서 문서 자체를 가리킬 때는 링크 텍스트를 `Docs` 로 끝낸다. 예: `[TabView Docs](url){:target="_blank"}에 예시가 있다`
- `## 참고자료`: 다 읽고 나서 더 볼 자료를 글 끝에 모은다
  - 본문에 링크하지 않은 자료만 넣는다. WWDC 영상, RFC, 개요 문서, 다른 블로그 글 같은 것이다. 본문에 이미 링크한 API 는 다시 넣지 않는다
  - 넣을 자료가 없으면 `## 참고자료` 헤더와 그 위의 `---` 를 같이 지운다
  - 한 줄에 하나씩 `- [이름 (출처)](url){:target="_blank"}` 로 쓴다. 예: `[AppStorage (Apple)]`, `[ChaChaPoly (CryptoKit, Apple)]`
  - RFC, WWDC, Swift Evolution 처럼 이름에 번호가 붙는 자료는 출처 번호를 앞에 쓴다. 예: `[RFC 6762: Multicast DNS]`, `[WWDC25: Use structured concurrency with Network framework]`, `[SE-0296: Async/await]`

## 구조

- 모든 `##`, `###` 헤더 바로 위에는 `---` 구분선을 둔다
- `##` 헤더 바로 아래에 `###` 를 두지 않는다. 최소 한 문단의 도입부를 먼저 쓴다
- `####` 는 코드 블록 아래 API 설명에만 쓰고, 위에 `---` 를 두지 않는다

### 헤더 이름

- 그 섹션이 다루는 것을 한국어 명사구로 짓는다. "~했다", "~이다" 같은 문장으로 끝내지 않는다
  - `##` 는 이 섹션에서 풀어낸 일이나 문제: `## 맥에서 키를 누른 것과 같은 입력`, `## 끝없이 돌던 인사`
  - `###` 개념 설명은 `<개념>이란?` 또는 질문: `### HMAC 서명이란?`, `### 서명과 암호화는 무엇이 다른가`
  - `####` 는 `<API 이름>로 <하는 일>하기`: `#### CGEvent로 키 누르고 떼기`
- API 와 기술 이름은 백틱 없이 그대로 쓰고, 바로 뒤에 한국어 조사를 붙인다 (`GeometryReader로`, `AppStorage로`)
- 헤더에 백틱과 이모지를 쓰지 않는다
- `12-4.` 같은 번호는 붙이지 않는다. 따라 하는 순서가 중요한 단계(`### 1. 폴더 만들기`)에만 쓴다

## 이미지

- 본문에는 `/assets/images/upload/<filename>.png` 로 쓰고, 파일을 그 폴더에 넣는다
- `uploadimg` 를 실행하면 R2 에 올라가고 본문 경로가 R2 URL 로 바뀐다. R2 폴더명은 포스트 파일명을 따르므로 업로드 후에는 파일명을 바꾸지 않는다
- 직접 그린 그림은 alt text 에 그림이 말하는 내용을 한 문장으로 쓴다. 이미지가 안 보여도 alt 만 읽고 뜻이 통해야 한다
- 실행 화면을 찍은 스크린샷은 alt 를 비워도 된다. 대신 바로 아래 문단에서 무엇을 찍은 화면이고 어디를 보면 되는지 쓴다
- 스크린샷은 글로 설명한 결과를 처음 보여주는 자리에 넣는다. 사용자가 준 스크린샷의 파일명과 위치는 사용자에게 확인한다
- SVG 그림을 새로 만들거나 고칠 때만 [references/diagrams.md](references/diagrams.md) 를 읽는다

## 검증

작성이나 수정이 끝나면 반드시 실행하고, ERROR 가 0개가 될 때까지 고친다.

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/lint_post.py <post-path>
```

WARN 은 사람이 판단할 항목이라 고치지 말고 사용자에게 보고한다.

작업이 끝나면 바꾼 것, 확인한 것, 남은 WARN 을 한국어로 보고한다.
