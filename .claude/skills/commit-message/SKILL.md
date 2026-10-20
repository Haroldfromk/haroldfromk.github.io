---
name: commit-message
description: staged 된 변경사항을 보고 Conventional Commits 형식의 커밋 메시지를 제안한다. 커밋 메시지를 써달라고 하거나 지금 변경을 커밋하려고 할 때 사용한다.
---

# 커밋 메시지 작성

## 지금 staged 된 변경

!`git diff --staged --stat`

## 형식

`<type>(<scope>): <요약>`

- type 은 feat, fix, refactor, docs, test, chore 중 하나
- scope 는 변경된 주요 모듈 이름
- 요약은 한국어로 50자 이내, 마침표 없이

## 예시

```text
feat(profile): 프로필 화면에 로딩 상태 표시
fix(api): token 만료 시 재시도 무한 루프 수정
refactor(network): APIClient 의 에러 매핑을 enum 으로 분리
```

## 규칙

- 위 목록만으로 판단이 어려우면 `git diff --staged` 로 필요한 파일만 열어본다
- 메시지만 제안하고, 사용자가 승인하기 전에는 커밋하지 않는다
- staged 된 변경이 없으면 어떤 파일을 add 할지 먼저 물어본다
