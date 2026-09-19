---
title: (Deep Dive) Sendable이 아닌 타입은 왜 actor 밖으로 못 나가나 (5)
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

RunWay에서 actor 안에 Combine의 `PassthroughSubject`를 프로퍼티로 두고 밖에서 구독하려다 에러가 났다.

```text
Non-Sendable type 'PassthroughSubject<FlightPhase, Never>' of property 'phasePublisher' cannot exit actor-isolated context
```

`Sendable`을 준수하지 않는 서드파티 타입(Combine)이 actor 경계를 못 넘는다는 건데, 그때는 `AsyncStream`으로 갈아타서 해결했다. `Sendable`이 왜 필요한지는 알겠는데, "왜 하필 Combine 타입이 문제였나"는 짚고 넘어간 적이 없다.

---

## 문제 상황

```swift
actor FlightDataCenter {
    let phasePublisher = PassthroughSubject<FlightPhase, Never>()
}

// 밖에서
someActor.phasePublisher // 여기서 에러
```

`PassthroughSubject`는 참조 타입이고 내부적으로 여러 구독자를 동기적으로 관리하는데, 그 내부 상태를 여러 곳에서 동시에 건드릴 수 있어서 `Sendable`을 준수하지 않는다.

---

## 왜 그런가

<!-- TODO: actor 프로퍼티가 Sendable이 아닐 때 정확히 어떤 조건에서 에러가 나는지 - 읽기만 해도 에러인지, 밖으로 꺼내려 할 때만인지 검증 -->

actor는 내부 상태를 직렬화해서 보호하지만, 그 상태를 밖으로 꺼내는 순간부터는 actor가 더 이상 보호해줄 수 없다. 꺼낸 값이 `Sendable`이면 "복사되거나 소유권이 완전히 넘어가는 값이니 밖에서 마음대로 써도 안전하다"고 컴파일러가 판단할 수 있지만, `PassthroughSubject`처럼 참조 타입이고 내부 가변 상태를 가진 타입은 밖에서도 actor 내부와 같은 인스턴스를 공유하게 되므로 격리가 깨진다.

---

## 재현/실험할 것

- `PassthroughSubject`를 `let` 상수로 선언해도 여전히 막히는지 (참조 타입은 let이어도 내부가 가변이라 Sendable이 안 될 것으로 예상)
- Combine 대신 `AsyncStream`으로 바꾸면 왜 통과하는지 - `AsyncStream`은 어떻게 Sendable 문제를 피해가는 구조인지
- actor 안에 `PassthroughSubject`를 두고, 구독 자체는 actor 내부 메서드로만 하게 만들면 (참조를 밖으로 안 꺼내면) 에러가 사라지는지

---

## 정리

<!-- TODO -->

---

## 남은 질문

<!-- TODO -->
