---
title: (Deep Dive) 프로토콜 준수가 actor 경계를 넘는다는 게 무슨 말인가 (4)
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

RunWay에서 `WatchConnectivityService`를 `nonisolated final class`로 선언했는데, `WCSessionDelegate` 프로토콜을 준수시키는 부분에서 이런 진단이 나왔다.

```text
Conformance of 'WatchConnectivityService' to protocol 'WCSessionDelegate' crosses into main actor-isolated code and can cause data races; this is an error in the Swift 6 language mode
```

"crosses into main actor-isolated code"라는 표현이 낯설었다. 클래스는 `nonisolated`인데 프로토콜 준수가 어떻게 격리를 "넘나든다"는 건지 이해가 안 됐다.

---

## 문제 상황

`WCSessionDelegate`는 `NSObjectProtocol`을 상속하는데, 이게 `@MainActor`로 격리되어 있다. 클래스 자체는 `nonisolated`로 선언했지만, 그 클래스가 준수하는 프로토콜(정확히는 프로토콜이 상속한 상위 프로토콜)이 MainActor 격리를 요구하고 있어서 충돌이 난 것이다.

해결은 프로토콜 준수를 분리하고 `@preconcurrency`를 붙인 별도 extension으로 옮기는 것이었다.

```swift
nonisolated final class WatchConnectivityService: NSObject {
    // 생략
}

extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // 생략
    }
}
```

---

## 왜 그런가

<!-- TODO: @preconcurrency가 정확히 뭘 끄는지 CLAUDE.md의 탈출구 비교표(타입 전체를 끄는지, 런타임 검사가 남는지)와 대조해서 검증 -->

`@preconcurrency`는 "이 프로토콜은 Swift 6 이전에 만들어진 것이니, 그 시절 기준으로 격리를 판단해달라"는 하위 호환 신호다. `WCSessionDelegate`처럼 Swift 6 동시성 이전에 설계된 Apple 프레임워크 프로토콜은 실제로 어느 스레드에서 호출될지 프로토콜 자체엔 명시되어 있지 않은데, 컴파일러는 보수적으로 MainActor 격리를 추론한다. `@preconcurrency`는 그 추론을 끄고 이전 방식(컴파일 에러 대신 경고, 또는 검사 생략)으로 되돌린다.

---

## 재현/실험할 것

- `@preconcurrency` 없이 그대로 두면 정확히 어떤 진단이 나오는지 (경고인지 에러인지, Swift 5/6 모드에 따라 다른지)
- `@preconcurrency import`(모듈 단위)와 `@preconcurrency`(선언 단위)를 각각 적용했을 때 차이
- 이렇게 검사를 끈 상태에서 실제로 다른 스레드에서 delegate 콜백이 오면 무슨 일이 생기는지 (컴파일 타임엔 안전해 보이지만 런타임은?)

---

## 정리

<!-- TODO -->

---

## 남은 질문

<!-- TODO -->
