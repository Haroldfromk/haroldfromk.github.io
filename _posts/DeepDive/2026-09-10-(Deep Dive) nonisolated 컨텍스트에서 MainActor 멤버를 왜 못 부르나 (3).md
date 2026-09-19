---
title: (Deep Dive) nonisolated 컨텍스트에서 MainActor 멤버를 왜 못 부르나 (3)
writer: Harold
date: 2026-09-10 00:00
categories: [Deep Dive]
tags: [Myself]
published: false
toc: true
toc_sticky: true
---

<!--
발행 전 체크리스트
- [ ] TODO를 실제로 돌려서 나온 값으로 다 바꿨는가
- [ ] 가설이 틀렸으면 틀렸다고 그대로 썼는가
- [ ] 남은 질문을 채웠는가
-->

---

## 시작하게 된 이유

RunWay와 GitExplorer에서 `nonisolated`로 선언한 타입/함수 안에서 다른 멤버를 불렀는데, 그 멤버가 `@MainActor`에 격리되어 있어서 막힌 경우가 여러 번 있었다. 그런데 그 멤버들 중 일부는 내가 `@MainActor`를 붙인 적이 없는 것들이었다. 왜 격리되어 있었는지가 핵심 질문이다.

---

## 문제 상황 1 - 명시적으로 MainActor인 경우

RunWay의 디버그 로거 케이스. `nonisolated` delegate 메서드 안에서 `ZombieSessionLogger.shared`를 부르다 에러가 났다.

```text
Main actor-isolated static property 'shared' can not be referenced from a nonisolated context
```

이건 이해가 된다. 원인을 찾아보니 `Logger` 인스턴스를 담은 클래스가 어떤 이유로든 MainActor에 격리되어 있었기 때문이다. 해결은 클래스 자체를 `nonisolated`로 선언하는 것이었다.

---

## 문제 상황 2 - 아무 데도 @MainActor를 안 붙였는데?

GitExplorer 심화편에서 만난 케이스가 더 흥미롭다. `GitHubNetworkService`에 `@MainActor`를 명시한 적이 없는데도 이런 에러가 났다.

```text
Call to main actor-isolated instance method 'fetchGitUser(user:)' in a synchronous nonisolated context
```

원인은 코드가 아니라 **Xcode 설정**이었다. Xcode 26부터 `Default Actor Isolation` 빌드 설정의 기본값이 `MainActor`로 바뀌었다. 즉 아무 표시가 없는 타입도 프로젝트 설정에 따라 기본적으로 MainActor에 격리될 수 있다.

---

## 왜 그런가

<!-- TODO: Default Actor Isolation 빌드 설정을 직접 켜고 끄면서 같은 에러가 재현/해제되는지 확인 -->

`nonisolated`는 "이 선언만큼은 격리에서 빼달라"는 명시적 요청이다. 그런데 그 요청이 통하려면, 부르려는 대상이 애초에 격리되어 있지 않아야 한다. 대상이 (명시적으로든, 프로젝트 기본값으로든) MainActor에 격리되어 있으면 `nonisolated` 쪽에서 아무리 선언해도 상대방의 격리는 그대로 남는다. `nonisolated`는 "내가 이 값을 어떻게 대할지"를 정하는 게 아니라 "나 자신이 격리에 소속되는지"만 정한다.

---

## 재현/실험할 것

- Xcode 프로젝트에서 `Default Actor Isolation`을 `MainActor` / `nonisolated`로 각각 설정하고 같은 코드가 어떻게 다르게 컴파일되는지 확인
- Swift Tools Version 6.0 vs 6.2에서 기본값이 다른지 확인 (정확한 SE 번호는 아직 확인 안 됨 - CLAUDE.md의 SE-0461, nonisolated 실행 위치 변경과는 별개 사안이니 헷갈리지 않게 구분해서 정리. 번호는 실제 찾아보고 채울 것)
- `nonisolated`로 선언한 타입이 MainActor 격리된 멤버를 파라미터로 받는 방식으로 바꾸면(GitExplorer 심화1에서 쓴 우회법) 왜 통과하는지

---

## 정리

<!-- TODO -->

---

## 남은 질문

<!-- TODO -->
