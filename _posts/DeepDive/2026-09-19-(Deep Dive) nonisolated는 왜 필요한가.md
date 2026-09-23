---
title: (Deep Dive) nonisolated는 왜 필요한가
writer: Harold
date: 2026-09-23 18:00
categories: [Deep Dive]
tags: [Myself]
published: true
toc: true
toc_sticky: true
---

## 시작하게 된 이유

`nonisolated`를 실전에서는 에러 지우는 용도로만 써봤다. actor isolation 에러가 나면 일단 `nonisolated`를 붙이거나 `Task { @MainActor in }`으로 감싸서 넘어갔는데, 정작 "이게 정확히 뭘 하는 키워드인가"는 설명 못 한다. 이번엔 실제 프로젝트 사례를 뒤지는 대신, `nonisolated` 하나만 놓고 최소 코드로 정의부터 다시 확인한다.

Udemy Async/Await 시리즈, Concurrency 격리 정리글에서 actor/MainActor 기본 개념은 이미 다뤘으니 여기서 다시 설명하지 않는다.

정리하는 과정도 AI와 계속 대화하면서 진행했다. 다만 AI가 하는 말을 그대로 받아 적지는 않았다. 설명이 조금이라도 애매하거나 내 경험과 안 맞으면 다시 물어보고, 공식 문서를 직접 찾아서 대조하고, 실제로 코드를 컴파일해서 맞는지 확인하는 식으로 진행했다. 그래서 이 글에 나오는 내용은 AI의 설명 그 자체가 아니라, 그 설명을 검증하고 다듬은 결과에 가깝다.

---

## 1. 문제 상황

`@MainActor` 타입이 `CustomStringConvertible`을 준수하게 만들어봤다. `CustomStringConvertible`은 `print()`나 문자열 보간(`\(value)`)에서 이 타입을 어떻게 문자열로 보여줄지 직접 정하게 해주는 프로토콜이다. `description`이라는 프로퍼티 하나만 구현하면 된다.

```swift
@MainActor
final class AppSettings: CustomStringConvertible {
    let name: String
    let timeout: Double

    init(name: String, timeout: Double) {
        self.name = name
        self.timeout = timeout
    }

    var description: String {
        "AppSettings(name: \(name), timeout: \(timeout))"
    }
}
```

`description`은 `let name`, `let timeout`만 읽는다. 둘 다 불변이라 어느 스레드에서 읽어도 안전할 것 같은데, 그냥 빌드하면 에러가 발생한다.

![](/assets/images/upload/CleanShot_19-17.4536.png)

---

## 2. 첫 번째 에러 - 데이터 레이스

```text
1. Conformance of 'AppSettings' to protocol 'CustomStringConvertible' crosses into main actor-isolated code and can cause data races
```

---

### 데이터 레이스가 뭔지

여기서 말하는 데이터 레이스가 정확히 뭔지, 왜 위험한지는 [이전글](https://haroldfromk.github.io/posts/swift-concurrency-isolation/){:target="_blank"}에서 이미 다뤘다.

짧게만 정리하면, MainActor로 격리된 코드가 격리 밖으로 "넘어가면" 서로 다른 실행 흐름이 같은 상태를 동시에 건드릴 수 있게 되고, 컴파일러는 그 가능성 자체를 막으려는 것이다. 계좌 잔고로 예를 들면, 두 흐름이 같은 값을 동시에 읽고 각자 계산한 뒤 나중에 쓰는 쪽이 앞의 변경을 덮어써버리는 식이다. 이게 데이터 레이스다.

![](/assets/images/upload/datarace.png)

---

### 진짜로 값이 깨지는지 확인해보기

근데 `AppSettings`는 `let name`, `let timeout`만 있어서 애초에 이 그림 같은 상황이 나올 수가 없다. 실제로 값이 깨지는 걸 보려면 진짜 가변 상태가 있는 별도 코드가 필요하다. 위 그림을 그대로 코드로 옮겨서 확인해봤다.

```swift
// @MainActor도 Sendable도 없는 평범한 클래스
final class BankAccount {
    var balance: Int

    init(balance: Int) {
        self.balance = balance
    }

    func withdraw(_ amount: Int) {
        balance -= amount
    }
}

let account = BankAccount(balance: 1000)

DispatchQueue.concurrentPerform(iterations: 1000) { _ in
    account.withdraw(1)
}

print("예상 잔고: \(1000 - 1000)")
print("실제 잔고: \(account.balance)")
```

빌드는 통과한다. 다만 경고가 하나 뜬다.

```text
warning: capture of 'account' with non-Sendable type 'BankAccount' in a '@Sendable' closure [#SendableClosureCaptures]
```

20번 실행해서 실제 잔고를 모아봤다.

```text
0, 513, 554, 142, 48, 392, 433, 571, 0, 475,
114, 471, 462, 630, 96, 472, 18, 0, 573, 595
```

예상값은 항상 0인데, 20번 중 3번만 우연히 맞았다. 나머지는 인출이 사라져서 잔고가 이상하게 남았다. 실행할 때마다 결과가 다른 것도 데이터 레이스의 특징이다.

---

#### Sendable???

`Sendable`을 스치듯 언급하고 넘어가기엔 계속 나온다. Sendable이 정확히 뭔지는 [이전글](https://haroldfromk.github.io/posts/swift-concurrency-isolation/){:target="_blank"}에서 이미 다뤘다.

---

##### Sendable 다시 보기

짧게만 정리하면, 값 타입이거나 불변이면 안전해서 Sendable이고, 참조 타입인데 내부 값이 바뀔 수 있으면 격리로 보호해야 해서 Sendable이 아니다.

![](/assets/images/upload/sendable.png)

`nonisolated`가 "이 멤버를 어디서 호출해도 되는가"를 다뤘다면, `Sendable`은 "이 값을 다른 스레드나 작업으로 넘겨도 되는가"를 다룬다. 둘 다 "동시성 경계를 넘을 때 안전한가"라는 같은 문제의 다른 면이다.

![](/assets/images/upload/nonisolated_vs_sendable_diagram.png)

좀 더 크게 보면, `Sendable`을 준수한다는 건 격리됐든 안 됐든 상관없이 통하는 일종의 공인된 안전 표시다. 컴파일러 입장에서는 "이 값이 `Sendable`을 준수하는가"만 확인하면 되고, 그 값이 actor 안에 있었는지 밖에 있었는지는 중요하지 않다. `Sendable`을 준수하는 값이라면 격리 경계를 넘나들어도 공식적으로 안전하다고 전제하는 것이다.

---

##### 경고와 에러가 갈리는 이유

실전에서 이런 경고나 에러를 만나면, 그 클로저를 받는 메서드가 정말 `@Sendable`을 요구하는지 직접 확인하는 게 좋다. Xcode에서 그 메서드 이름 위에 Option 키를 누른 채 클릭하면 파라미터까지 포함한 선언이 바로 뜨고, Command 키를 누른 채 클릭하면 실제 선언으로 이동한다. 이번에도 그렇게 확인했다.

같은 패턴을 순수 Swift로 선언한 `@Sendable` 클로저 파라미터에 넣으면 이건 경고가 아니라 에러다. [Sendable-closure-captures Docs](https://docs.swift.org/compiler/documentation/diagnostics/sendable-closure-captures){:target="_blank"} 예제로 확인했다.

```swift
func callConcurrently(_ closure: @escaping @Sendable () -> Void) async { }

class MyModel {
    func log() { }
}

func capture(model: MyModel) async {
    await callConcurrently {
        model.log()   // error: capture of 'model' with non-Sendable type 'MyModel' in a '@Sendable' closure
    }
}
```

근데 `DispatchQueue.concurrentPerform`에 똑같은 패턴을 넣으면 경고로만 뜬다. 실제 선언을 찾아보면 이유가 나온다.

```swift
@preconcurrency public class func concurrentPerform(iterations: Int, execute work: @Sendable (Int) -> Void)
```

`@Sendable`은 우리 코드가 아니라 이 API 선언 자체에 있다. `work`의 타입이 `@Sendable (Int) -> Void`라서, 우리가 넘긴 평범한 클로저 리터럴도 그 자리에 들어가는 순간 `@Sendable` 클로저로 취급된다.

그리고 선언 맨 위에 `@preconcurrency`가 붙어있다. 이게 경고로 완화된 진짜 이유다. `@preconcurrency`는 글 처음 "문제 상황"의 에러 스크린샷에서 Xcode가 제안한 고치는 방법("Turn data races into runtime errors with '@preconcurrency'")에도 이미 나왔던 속성이다. "에러를 경고로 낮춰서 하위 호환을 지키는" 역할을 여기서도 그대로 하고 있다.

정확히 뭘 하는 속성인지 [Swift Language Reference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/){:target="_blank"}를 찾아봤다.

> Apply this attribute to a declaration, to suppress strict concurrency checking... When you use this symbol in a scope that has minimal concurrency checking, concurrency-related constraints specified by that symbol, such as Sendable requirements or global actors, aren't checked.

번역하면, 이 속성을 선언에 붙이면 엄격한 동시성 검사가 꺼진다. 그 선언을 쓰는 쪽 코드의 검사가 느슨하게 설정되어 있으면, 그 선언이 요구하는 Sendable 조건이나 글로벌 액터 같은 조건을 확인하지 않는다는 뜻이다. 원래는 Swift 6으로 옮겨가는 중에 쓰라고 만든 도구다. 아직 Swift 6 방식에 맞춰 고치지 못한 라이브러리에는 `@preconcurrency`를 붙여서 경고만 뜨게 낮춰두고, 나중에 그 라이브러리가 대응을 마치면 떼어내는 식으로 쓰라는 것이다.

그리고 결정적인 문장이 하나 더 있다.

> Declarations from Objective-C are always imported as if they were marked with the preconcurrency attribute.

Objective-C에서 그대로 들여온 선언은 개발자가 아무것도 안 해도 `@preconcurrency`가 붙은 것처럼 취급된다는 뜻이다. 뒤에 나올 `WCSessionDelegate`가 딱 이 경우다.

`concurrentPerform`은 조금 다르다. 위 선언을 보면 `@preconcurrency`가 직접 적혀있다. `concurrentPerform`은 Objective-C 선언을 그대로 들여온 게 아니라, Apple이 Swift 쪽에서 따로 덧붙인 메서드다. 그래서 자동으로 붙는 게 아니라 선언에 직접 적혀있는 것이다. Swift Concurrency 이전부터 쓰던 API라 기존 코드가 한 번에 에러로 깨지지 않도록 Apple이 직접 붙여둔 것이고, 위에서 본 마이그레이션 용도 그대로다. `callConcurrently`(우리가 만든 순수 Swift 함수)는 `@preconcurrency`가 없어서 그대로 에러였고, `concurrentPerform`은 이 속성 때문에 경고로 낮아진 것이다.

![](/assets/images/upload/preconcurrency.png)

즉 "격리가 없어서 안 봐준다"가 아니라, 검사 자체(Sendable)는 똑같이 걸리는데 API 선언에 `@preconcurrency`가 있느냐 없느냐로 심각도가 갈린다는 게 정확한 설명이다.

그럼 자주 쓰는 `Task { }`는 어느 쪽일까. `Task`의 클로저도 당연히 `@Sendable`일 거라고 생각했는데, 현재 SDK의 `Task.init` 선언을 보니 아니었다.

```swift
public init(name: String? = nil, priority: TaskPriority? = nil, operation: sending @escaping @isolated(any) () async -> Success)
```

`@Sendable`이 아니라 `sending`이다. 둘이 어떻게 다른지 `MyModel`을 `Task`에 넘기는 세 가지 경우로 확인해봤다.

```swift
// 1) 함수 안에서 새로 만들고, 넘긴 뒤 다시 안 씀
func newModelToTask() {
    let model = MyModel()
    Task {
        model.log()
    }
}

// 2) 함수 안에서 새로 만들었지만, 넘긴 뒤 밖에서 또 씀
func newModelToTaskAndReuse() {
    let model = MyModel()
    Task {
        model.log()
    }
    model.log()
}

// 3) 파라미터로 받은 값을 넘김
func paramModelToTask(model: MyModel) {
    Task {
        model.log()
    }
}
```

| 경우 | 결과 |
|---|---|
| 1) 새로 만들고 다시 안 씀 | 통과 |
| 2) 새로 만들었지만 밖에서 또 씀 | `sending value of non-Sendable type ... risks causing data races` 에러 |
| 3) 파라미터로 받은 값 | `passing closure as a 'sending' parameter risks causing data races ...` 에러 |

`@Sendable`인 `callConcurrently`는 Sendable이 아닌 값을 캡처하는 것 자체를 막았다. `sending`은 그보다 너그럽다. 넘긴 뒤에 원래 쪽에서 그 값을 더 이상 건드릴 수 없는 경우(1번)는 허락하고, 넘긴 뒤에도 원래 쪽에서 쓸 수 있는 경우만 막는다. 2번은 넘긴 뒤 직접 또 썼고, 3번은 파라미터라 이 함수를 부른 쪽이 그 값을 계속 들고 있을 수 있어서 막혔다.

그러니 `Task`도 검사는 받지만, `callConcurrently`와 똑같은 기준은 아니다.

그런데 왜 하필 `concurrentPerform`의 `work` 파라미터가 `@Sendable`로 선언됐을까. [concurrentPerform Docs](https://developer.apple.com/documentation/dispatch/dispatchqueue/concurrentperform(iterations:execute:)){:target="_blank"}의 설명에 답이 있다.

> This method implements an efficient parallel for-loop. The dispatch queue executes the submitted block the specified number of times and waits for all iterations to complete before returning. If the target queue is a concurrent queue, the blocks run in parallel and must therefore be reentrant-safe.

번역하면, 이 블록은 지정된 횟수만큼 실행되고, 큐가 concurrent 큐라면 그 블록들이 실제로 동시에 돌아가기 때문에 여러 번 겹쳐 실행돼도 안전해야 한다는 뜻이다. `work`가 `@Sendable`인 건 우연이 아니라, 이 API 자체가 "이 블록은 여러 스레드에서 동시에 실행될 수 있다"는 걸 전제로 설계됐기 때문이다. 그 전제를 타입으로 강제한 게 `@Sendable`이다.

그리고 여기엔 actor가 하나도 없다. `BankAccount`도 `concurrentPerform`도 actor를 쓰지 않는데 Sendable 검사가 걸렸다. 즉 진짜 기준은 "actor를 넘나드는가"가 아니라 "동시에 실행될 수 있는 곳으로 넘어가는가"다. actor는 그런 곳의 한 형태일 뿐이고, `Task`나 `DispatchQueue.concurrentPerform`처럼 actor 없이 그냥 동시에 도는 것도 해당된다(기준은 위에서 본 것처럼 조금씩 다르다).

이 김에 `Sendable` 자체가 언제부터 있었는지도 찾아봤다. [Sendable Docs](https://developer.apple.com/documentation/swift/sendable){:target="_blank"}를 보면 `Sendable` 프로토콜은 iOS 8.0부터 있었다고 나온다. 근데 이건 오해하기 쉬운 표시다. Swift Evolution [SE-0302](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md){:target="_blank"}("Sendable and @Sendable closures")에서 `Sendable`은 "marker protocol"로 정의되어 있다.

> This proposal introduces the concept of a "marker" protocol, which indicates that the protocol has some semantic property but is entirely a compile-time notion that does not have any impact at runtime.

빌드할 때 컴파일러만 확인하는 표시일 뿐, 앱이 실행될 때는 아무 영향이 없다는 뜻이다. 실행할 때 필요한 게 없으니, Swift가 지원하는 가장 오래된 OS를 도입 버전으로 그냥 붙여놓은 것에 가깝다.

실제로 `Sendable`이 등장한 건 2021년이다. WWDC21의 [Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/){:target="_blank"} 세션이 actor를 소개하면서 참고 자료로 SE-0302를 걸어두고 있다. 그리고 non-Sendable 값을 경계 너머로 넘길 때 실제로 경고가 뜨기 시작한 건 Swift 5.6부터다. [Swift CHANGELOG](https://github.com/swiftlang/swift/blob/main/CHANGELOG.md){:target="_blank"}의 Swift 5.6 항목에 이렇게 적혀있다.

> Swift will now produce warnings to indicate potential data races when non-`Sendable` types are passed across actor or task boundaries.

WWDC22의 [Eliminate data races using Swift Concurrency](https://developer.apple.com/videos/play/wwdc2022/110351/){:target="_blank"} 세션은 이 Sendable 검사를 본격적으로 다룬다. `Sendable`이라는 안전장치는 2021년 Swift Concurrency(`async`/`await`, actor)와 함께 생겼고, 검사가 실제로 켜진 건 그 이후라는 것이다.

정리하면 이렇다. GCD 기반 병렬 실행(`concurrentPerform`)은 훨씬 오래전부터 있었지만, 그걸 타입으로 강제하는 `Sendable`은 한참 뒤에 생겼다. Apple이 `concurrentPerform`에 `@Sendable`을 뒤늦게 붙이고 `@preconcurrency`로 감싼 것도 이 시차 때문이다. 기초 Swift 강의들이 `Sendable`을 다루지 않는 것도, 애초에 그 강의들이 만들어질 때는 이 개념 자체가 없었기 때문일 가능성이 크다.

---

##### MainActor 클래스는 왜 다른가

`nonisolated`를 쓰다 보면 유독 `Sendable` 에러도 같이 자주 만나게 되는데, 이유가 있다. [Sendable Docs](https://developer.apple.com/documentation/swift/sendable){:target="_blank"}에 이런 문장이 있다.

> Classes marked with @MainActor are implicitly sendable, because the main actor coordinates all access to its state.

`@MainActor` 클래스는 그 자체로 이미 Sendable이라는 뜻이다. 근데 액터도 아니고 `@MainActor`도 아닌 그냥 평범한 클래스는 Sendable이 아니다. 두 경우를 나란히 확인해봤다.

```swift
func callConcurrently(_ closure: @escaping @Sendable () -> Void) async { }

@MainActor
final class MainActorModel {
    func log() { }
}

final class PlainModel {
    func log() { }
}

func captureMainActor(model: MainActorModel) async {
    await callConcurrently {
        model.log()
    }
}

func capturePlain(model: PlainModel) async {
    await callConcurrently {
        model.log()
    }
}
```

결과가 다르다.

![](/assets/images/upload/CleanShot_23-00.4449.png)

`MainActorModel`은 캡처 자체는 통과한다. 위에서 인용한 [Sendable Docs](https://developer.apple.com/documentation/swift/sendable){:target="_blank"} 문장 그대로, `@MainActor` 클래스라 이미 Sendable이기 때문이다. 대신 그 안에서 격리된 메서드(`log()`)를 동기 호출하려다 막힌다. 이게 `ActorIsolatedCall`이다. 격리된 멤버를 격리 밖에서 동기로 부를 때 나는 에러고, 뒤의 "함수도 안 쓰면 빌드 에러가 난다"에서 다시 나온다. `PlainModel`은 애초에 캡처하는 시점에서 막힌다 (`SendableClosureCaptures`).

정리하면 이렇다. 위 두 함수는 `callConcurrently { model.log() }`라는 똑같은 코드 모양이다. 여기서 `model`이 `MainActorModel`이면 격리 검사가 걸려서 `nonisolated`가 필요한 상황이 되고, `PlainModel`이면 Sendable 검사가 걸려서 Sendable 에러가 난다. 

즉 `model.log()`라는 같은 자리를 서로 다른 두 검사(격리 검사, Sendable 검사)가 타입에 따라 나눠서 잡아내는 것이지, 하나가 다른 하나를 일으키는 건 아니다.

![](/assets/images/upload/nonisolated_mainactor_vs_plain_diagram.png)

---

##### Sendable이 막으려는 것

actor는 왜 애초에 이 검사에서 예외일까. [Sendable Docs](https://developer.apple.com/documentation/swift/sendable){:target="_blank"}에 답이 있다.

> All actor types implicitly conform to Sendable because actors ensure that all access to their mutable state is performed sequentially.

actor의 참조를 여기저기 넘겨도 안전한 이유는, 누가 그 참조를 들고 있든 실제 접근은 항상 한 줄로 서서 순서대로 처리되기 때문이다. actor가 Sendable인 건 "격리를 무시해도 된다"는 뜻이 아니라 "격리(한 번에 하나씩 처리) 자체가 이미 안전을 보장한다"는 뜻이다.

그렇다면 `Sendable` 검사가 원래 막으려는 건 정확히 그 반대 상황이다. 순서를 지켜줄 장치가 없는 값(`BankAccount`처럼 격리도 없고 `Sendable`도 아닌 값)이 동시에 실행되는 곳으로 넘어가서, 서로 다른 흐름이 동시에 그 값을 건드리는 상황이다. `BankAccount`를 순수 Swift `@Sendable` 파라미터(`callConcurrently`)에 넘겼다면 컴파일 자체가 안 됐을 것이다. 그러면 잔고가 깨지는 일도 애초에 일어날 수 없다.

근데 실제로는 `DispatchQueue.concurrentPerform`을 썼고, 그건 `@preconcurrency`라서 경고만 뜨고 통과했다. 그래서 컴파일이 됐고, 그 결과로 진짜 오염(20번 중 17번 잔고가 틀림)을 볼 수 있었다. `Sendable` 검사가 원래 하려던 일이 정확히 이 상황을 막는 것이었는데, `@preconcurrency`가 문지기를 느슨하게 풀어놔서 그 실패를 직접 눈으로 본 셈이다.

![](/assets/images/upload/sendableblock.png)

---

### 프로토콜 타입으로 감싸면 왜 위험한가

Sendable 얘기가 길어졌다. 원래 하려던 얘기로 돌아오면, `AppSettings`가 정확히 어떤 상황에서 이 위험을 실제로 만나게 되는지는 [Conformance-isolation Docs](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"}에 따로 적혀있다.

> When a type conforms to a protocol, any generic code can perform operations on that type through the protocol. If the operations that the type used to satisfy the protocol requirements are actor-isolated, this may result in a diagnostic indicating that the conformance crosses into actor-isolated code.

번역하면, "타입이 프로토콜을 준수하면, 어떤 제네릭 코드든 그 프로토콜을 통해 이 타입에 연산을 수행할 수 있다. 프로토콜 요구사항을 만족시키는 연산이 actor에 격리되어 있다면, 이 타입이 프로토콜을 따르는 것 자체가 actor로 격리된 코드로 넘어간다는 에러가 나올 수 있다"는 뜻이다.

즉 위험한 건 `AppSettings`를 직접 아는 코드가 아니다. `any CustomStringConvertible`이나 제네릭 `<T: CustomStringConvertible>`처럼 **프로토콜 타입으로만** 이 값을 들고 있는 코드다. 그런 코드는 이 값이 실제로 MainActor에 격리된 `AppSettings`인지 알지도, 알 필요도 없이 아무 스레드에서나 `.description`을 부를 수 있다.

실제로 이런 코드를 만들어서 확인해봤다. `printAnywhere`가 `T`를 정말 신경 안 쓴다는 걸 보여주려고, `AppSettings`(MainActor)와 전혀 무관한 타입을 하나 더 만들어서 같은 함수로 둘 다 불러봤다.

```swift
// MainActor와 전혀 무관한 타입. CustomStringConvertible만 준수한다.
struct DeviceInfo: CustomStringConvertible {
    let model: String
    var description: String { "DeviceInfo(model: \(model))" }
}

// T가 AppSettings인지 DeviceInfo인지, MainActor인지 아닌지 전혀 모른 채로
// 그냥 .description을 부른다
nonisolated func printAnywhere<T: CustomStringConvertible>(_ value: T) -> String {
    let thread = Thread.isMainThread ? "Main Thread" : "Background Thread"
    return "\(thread): \(value.description)"
}

@MainActor
func callFromBackgroundQueue() {
    let settings = AppSettings(name: "prod", timeout: 30)
    let device = DeviceInfo(model: "iPhone")

    DispatchQueue.global().async {
        let settingsResult = printAnywhere(settings)   // T = AppSettings (MainActor)
        let deviceResult = printAnywhere(device)       // T = DeviceInfo (MainActor 아님)
        print(settingsResult)
        print(deviceResult)
    }
}
```

`printAnywhere`의 코드는 둘 다 똑같다. `T`가 MainActor 타입인지 아닌지에 따라 분기하지 않는다. 실제로 `DispatchQueue.global()`(임의의 백그라운드 스레드)에서 둘 다 불러봤다.

```text
Background Thread: AppSettings(name: prod, timeout: 30.0)
Background Thread: DeviceInfo(model: iPhone)
```

똑같은 함수, 똑같은 스레드에서 둘 다 아무 문제 없이 호출됐다. `printAnywhere` 입장에서는 `AppSettings`가 MainActor에 격리되어 있다는 사실 자체가 안 보인다.

그냥 `CustomStringConvertible`을 만족하는 값 하나일 뿐이다. `description`이 `nonisolated`라서 이게 안전하게 성립한 것이다. 만약 `description`에 `nonisolated`가 없어서 MainActor에 격리된 채였다면(글 처음 에러가 났던 코드) 애초에 `AppSettings`가 `CustomStringConvertible`을 준수하지도 못했을 것이다. 억지로 통과시키는 방법은 두 가지인데 결과가 다르다. Swift 5 모드로 내리면 경고만 뜨고 빌드되고, `description`이 백그라운드 스레드에서 아무 말 없이 실행된다. 바뀌는 값을 건드리는 코드였다면 그대로 레이스가 난다. Swift 6 모드에서 프로토콜 이름 앞에 `@preconcurrency`를 붙여(`: @preconcurrency CustomStringConvertible`) 통과시키면, 뒤의 "진짜로 크래시까지 재현해보기"에서 볼 것처럼 실행 중에 크래시가 난다.

![](/assets/images/upload/nonisolated_protocol_erasure_diagram.png)

프로토콜 타입으로 감싸이는 순간 "이건 MainActor에 격리되어 있다"는 정보가 겉으로 드러나지 않는다. 그 값을 들고 있는 임의의 Background Thread는 그걸 모른 채로 그냥 호출한다. 만약 그 구현이 실제로 격리된 가변 상태를 건드리는 것이었다면, 그 순간 진짜 레이스가 난다. 지금 `AppSettings`가 딱 그 상황이다. `@MainActor`인 타입이 `CustomStringConvertible`을 준수하는 것 자체가 격리 경계를 넘나든다는 뜻이다.

---

## 3. 두 번째 에러 - nonisolated 요구사항

```text
2. Main actor-isolated property 'description' cannot satisfy nonisolated requirement
```

여기에 답이 이미 적혀있다. `CustomStringConvertible.description` 요구사항 자체가 `nonisolated` 요구사항이라는 뜻이다. 즉 이 프로퍼티는 어디서든, 어떤 스레드에서든 `await` 없이 동기적으로 호출 가능해야 한다는 게 프로토콜의 전제다.

실제로 [Conformance-isolation Docs](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"}에 그대로 나와있다.

> If the conformance needs to be usable anywhere, then each of the operations used to satisfy its requirements must be marked nonisolated. This means that they will not have access to any actor-specific operations or state, because these operations can be called concurrently from anywhere.

번역하면, "이 타입을 그 프로토콜로 아무 데서나 쓸 수 있어야 한다면, 그 요구사항을 만족시키는 연산들은 반드시 nonisolated로 표시해야 한다. 이 연산들은 어디서든 동시에 호출될 수 있기 때문에, actor 전용 연산이나 상태에 접근할 수 없게 된다"는 뜻이다. 지금까지 설명한 것과 정확히 같은 내용이다.

여기서 "어디서든 호출 가능"이라는 말을 헷갈리면 안 된다. 코드에서 그 이름을 쓸 수 있느냐(`private`, `public` 같은 접근 제어) 얘기가 아니다. `@MainActor` 멤버도 코드 어디서든 참조는 할 수 있다.

다만 실제로 호출하려면 조건이 붙는다. 지금 내가 MainActor 위에 있으면 그냥 동기 호출되고, 밖에 있으면 `await`로 액터에 진입하는 절차가 필요하다.

그런데 `description`의 실제 구현체는 MainActor에 격리되어 있다. MainActor 밖에서 그 값을 들고 있는 코드가 `.description`을 부르는 순간, await도 없이 액터에 진입할 방법이 없다. 계약(동기 호출 가능)과 실제(격리됨)가 충돌하니, 컴파일러는 "격리된 멤버는 이 요구사항을 만족할 수 없다"고 막아버린다.

즉 필요한 건 `description`만 이 타입의 격리에서 빼주는 것이다. 그 역할을 하는 키워드가 `nonisolated`다.

비유하면 이렇다. `AppSettings`는 직원(MainActor 배지)만 출입 가능한 회사다. 근데 `CustomStringConvertible`이라는 협회에 가입하려면, 규정상 접수처만큼은 배지 없이 누구나 예약 없이 즉시 응대 가능해야 한다. 마침 접수처가 하는 일은 회사 기밀이 아니라 공개 정보(`name`, `timeout`) 안내뿐이라, 접수처(`description`)만 `nonisolated`로 열어서 그 규정을 만족시킨 것이다.

![](/assets/images/upload/requirenonisolated.png)

---

## 4. 해결: nonisolated로 고치기

`nonisolated`는 `@MainActor`(또는 actor) 타입의 멤버 중 하나를 골라 "이건 격리에서 빼달라"고 명시하는 키워드다. (isolated가 "격리된"이라는 뜻이니, 그 반대로 읽으면 된다.)

```swift
@MainActor
final class AppSettings: CustomStringConvertible {
    let name: String
    let timeout: Double

    init(name: String, timeout: Double) {
        self.name = name
        self.timeout = timeout
    }

    nonisolated var description: String {
        "AppSettings(name: \(name), timeout: \(timeout))"
    }
}
```

`description`만 `nonisolated`로 뺐다. 그래서 이 프로퍼티는 `await` 없이, MainActor 바깥에서도 바로 호출할 수 있다.

```swift
func runNonisolatedDemo() async {
    let settings = await AppSettings(name: "prod", timeout: 30)
    print(settings.description)   // await 없이 호출됨
    print(settings)
}
```

실행 결과:

```text
AppSettings(name: prod, timeout: 30.0)
AppSettings(name: prod, timeout: 30.0)
```

`nonisolated`는 "이 멤버는 실제로 격리된 상태를 안 건드리니, 프로토콜이 원하는 대로 아무 데서나 불러도 안전하다"고 컴파일러에게 알려주는 역할을 한다.

---

### let만 읽는데 왜 에러가 났나

고치긴 했는데 처음 의문이 남는다. 글 처음에 `description`은 `let name`, `let timeout`만 읽으니 어느 스레드에서 읽어도 안전할 것 같다고 했다. 그런데 왜 에러가 났을까.

[Conformance-isolation Docs](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"}에 힌트가 있었다. `Identifiable`의 `id`처럼 프로퍼티 자체가 프로토콜 요구사항일 때는 `var id`를 `nonisolated let id`로 바꾸라는 예시가 나온다. 그래서 `nonisolated` 없이 `let`만 써도 되는지, `description` 같은 계산 프로퍼티와 뭐가 다른지 한꺼번에 확인해봤다.

```swift
import Foundation

final class Box {}   // Sendable이 아닌 평범한 클래스

@MainActor
final class A: Identifiable {
    let id = UUID()          // 저장 프로퍼티, Sendable 타입
}

@MainActor
final class B: Identifiable {
    let raw = UUID()
    var id: UUID { raw }     // let만 읽는 계산 프로퍼티
}

protocol HasBox {
    var box: Box { get }
}

@MainActor
final class C: HasBox {
    let box = Box()          // 저장 프로퍼티, Sendable이 아닌 타입
}
```

| 타입 | `id` / `box` | 결과 |
|---|---|---|
| `A` | `let` 저장 프로퍼티 (Sendable 타입) | 통과 |
| `B` | `let`만 읽는 계산 프로퍼티 | `ConformanceIsolation` 에러 |
| `C` | `let` 저장 프로퍼티 (Sendable이 아닌 타입) | `ConformanceIsolation` 에러 |

`nonisolated` 없이 통과한 건 `A` 하나뿐이었다. `B`는 `description`과 똑같은 상황이다. `let`만 읽는데도 에러가 났다. `C`는 `let` 저장 프로퍼티인데도 타입이 Sendable이 아니라서 에러가 났다.

[SE-0434](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0434-global-actor-isolated-types-usability.md){:target="_blank"}(Swift 6.0에서 구현)에 이 규칙이 적혀있다. 전역 액터에 격리된 구조체를 예로 들어 설명하는데, 위 실험처럼 클래스에서도 결과가 같았다.

> `let` properties of such types are implicitly treated as `nonisolated` within the current module if they have `Sendable` type, but `var` properties are not.

Sendable 타입의 `let` 프로퍼티는 같은 모듈 안에서 자동으로 `nonisolated`로 취급되고, `var`는 그렇지 않다는 뜻이다. 그리고 이 규칙은 저장 프로퍼티에만 해당한다고 같은 곳에 적혀있다.

> Because `nonisolated` access only applies to stored properties, wrapped properties and `lazy`-initialized properties with `Sendable` type still must be isolated because they are computed properties

즉 격리는 본문이 무엇을 읽는지가 아니라, 어떻게 선언했는지로 정해진다. 컴파일러는 `description`의 본문을 들여다보고 "`let`만 읽네" 하고 봐주지 않는다. 계산 프로퍼티인 이상 클래스의 격리(MainActor)를 그대로 따르고, 그래서 `nonisolated`를 직접 붙여야 했던 것이다.

---

## 5. 프로퍼티만이 아니라 함수도 똑같다

지금까지는 `description`이라는 프로퍼티(계산 프로퍼티)로만 봤다. `nonisolated`가 함수에도 똑같이 적용되는지 확인해봤다.

---

### 함수도 안 쓰면 빌드 에러가 난다

```swift
extension AppSettings {
    func label() -> String {   // nonisolated 없음
        "\(name) (\(timeout)s)"
    }
}

func callLabelDirectly(_ settings: AppSettings) {
    print(settings.label())
}
```

평범한 코드에서 동기 호출하면, 예상대로 에러가 난다. 위의 "MainActor 클래스는 왜 다른가"에서 `MainActorModel.log()`를 부를 때 본 것과 같은 `ActorIsolatedCall`이다.

![](/assets/images/upload/CleanShot_23-12.1254.png)

```text
error: call to main actor-isolated instance method 'label()' in a synchronous nonisolated context [#ActorIsolatedCall]
```

Xcode가 에러 옆에 고칠 방법도 하나 제안한다. "Add '@MainActor' to make global function 'callLabelDirectly' part of global actor 'MainActor'." `nonisolated`를 붙이라는 게 아니라, 호출자 쪽에 `@MainActor`를 붙이라는 제안이다. 실제로 그렇게 해봤다.

```swift
@MainActor
func callLabelViaMainActor(_ settings: AppSettings) {
    print(settings.label())
}
```

이것도 에러 없이 통과한다. 근데 이건 `nonisolated`가 문제를 고쳐준 것과는 다르다. 호출자 자체가 `label()`과 같은 액터(MainActor)로 들어가버려서, 애초에 격리 경계를 넘는 일이 없어진 것이다. `nonisolated`를 붙이는 원래 방법은 "이 함수는 격리 없이도 안전하다"를 증명하는 것이고, 호출자에 `@MainActor`를 붙이는 건 "아예 격리 안으로 들어가서 부르겠다"는 것이다. 결과는 둘 다 컴파일이 통과하지만, 의미가 다르다. 이렇게 하면 이 함수를 더 이상 격리 밖(백그라운드 스레드 등)에서 동기로 부를 수 없다는 뜻이기도 하다.

호출자는 그대로 두고 `label()`에 `nonisolated`를 붙이면 문제없이 통과한다. 여기까지는 지금까지 본 것과 다르지 않다.

---

### 근데 RunWay 사례는 빌드 에러조차 없었다

실제로 함수에서 이 문제를 겪었던 사례가 있다. RunWay 만들 때 `WCSessionDelegate` 콜백 메서드에 `nonisolated`를 빠뜨려서 생긴 크래시다. [이전글](https://haroldfromk.github.io/posts/RunningProject-(15)/){:target="_blank"}에도 그대로 남아있다.

사실 이 패턴을 처음 만난 건 RunWay가 아니라 GitExplorer였다([이전글](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/){:target="_blank"}). 그때는 `UserDefaults` 접근에서 멈추는 걸로 착각해서 한참 삽질하다가, 워치 시뮬레이터랑 같이 실행해보고 나서야 크래시 리포트로 `WatchConnectivityService.session(...)`이 범인이라는 걸 알아냈다. RunWay 때는 같은 패턴이라는 걸 바로 알아봐서, 크래시 로그만 보고 바로 원인을 잡을 수 있었다.

---

#### 실전에서 만난 크래시

```swift
// Before: 클래스는 nonisolated지만 메서드는 암묵적으로 MainActor로 추론됨
extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // 실행하면 크래시
    }
}

// After
extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        // 정상 동작
    }
}
```

이 사례는 앞의 `callLabelDirectly`와 성격이 다르다. 컴파일은 그냥 통과했다. 에러도 경고도 없이 조용히 넘어갔다가, 실행해보고 크래시 로그를 보고 나서야 문제를 알아차렸다.

이걸 세 가지로 나눠서 따라가봤다. 메서드가 왜 `@MainActor`가 됐는지, 왜 컴파일 에러가 안 났는지, 왜 크래시가 났는지.

---

#### 메서드가 왜 MainActor가 됐나

원인은 Xcode 빌드 설정 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`다. RunWay 프로젝트에는 실제로 이렇게 켜져 있다.

![](/assets/images/upload/CleanShot_23-04.0101.png)

[SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md){:target="_blank"}("Control default actor isolation inference", Swift 6.2에서 구현)이 추가한 컴파일러 옵션(`-default-isolation MainActor`)을 Xcode 빌드 설정으로 꺼내놓은 것이다. 격리가 따로 정해지지 않은 선언은 전부 `@MainActor`로 보겠다는 설정이다.

근데 `WatchConnectivityService`는 클래스 자체에 `nonisolated`가 붙어있었다. 그런데도 메서드가 왜 `@MainActor`가 됐는지, 클래스 본문과 extension에 메서드를 하나씩 두고 이 설정을 켠 채로 빌드해봤다.

```swift
nonisolated final class CacheService: NSObject {
    func inBody() {}          // 클래스 본문 안
}

extension CacheService {
    func inExtension() {}     // extension 안
}

nonisolated func callSync(_ s: CacheService) {
    s.inBody()
    s.inExtension()
}
```

```text
error: call to main actor-isolated instance method 'inExtension()' in a synchronous nonisolated context [#ActorIsolatedCall]
```

에러는 `inExtension()`에서만 났다. 클래스 본문 안에 있는 메서드는 클래스의 `nonisolated`를 물려받지만, extension 안에 있는 메서드는 물려받지 않고 빌드 설정의 기본값(`MainActor`)을 따른다. 설정을 끄고 같은 코드를 빌드하면 에러가 나지 않는다.

RunWay의 델리게이트 메서드들은 `WatchConnectivityService+iOS.swift`, `+watchOS.swift` 같은 extension 파일에 나눠져 있었다. 그래서 클래스에 `nonisolated`를 붙여놨는데도 extension 안의 메서드는 조용히 `@MainActor`가 된 것이다. RunWay 기록에 "`nonisolated`는 클래스 선언이 아니라 메서드 단위로 명시해야 한다"고 적었던 게 정확히는 이 extension 얘기였다.

![](/assets/images/upload/nonisolated_extension_isolation_diagram.png)

---

#### 왜 컴파일 에러가 안 났나

`WCSessionDelegate`는 Objective-C 프레임워크(WatchConnectivity)의 델리게이트 프로토콜이다. 위의 "경고와 에러가 갈리는 이유"에서 본 대로 Objective-C 선언은 자동으로 `@preconcurrency`가 붙은 것처럼 취급된다. 근데 그건 프로토콜 쪽 얘기고, 우리가 그 프로토콜을 준수하는 쪽은 별개다. Foundation의 Objective-C 델리게이트 프로토콜(`NSCacheDelegate`)로 확인해봤다.

```swift
@MainActor
final class CacheOwner: NSObject, NSCacheDelegate {   // 프로토콜 이름 앞에 @preconcurrency 없음
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {}
}
```

```text
error: conformance of 'CacheOwner' to protocol 'NSCacheDelegate' crosses into main actor-isolated code and can cause data races [#ConformanceIsolation]
```

Objective-C 프로토콜이라도 `@MainActor` 메서드로 준수하면, 글 처음 `AppSettings`가 `CustomStringConvertible`을 준수할 때와 똑같은 `ConformanceIsolation` 에러가 난다. RunWay 코드가 `extension WatchConnectivityService: @preconcurrency WCSessionDelegate`처럼 프로토콜 이름 앞에 `@preconcurrency`를 직접 적은 이유가 이거다. 이렇게 프로토콜 이름 앞에 붙이는 `@preconcurrency`는 [SE-0423](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md){:target="_blank"}("Dynamic actor isolation enforcement from non-strict-concurrency contexts", Swift 6.0에서 구현)이 도입한 기능이다.

> A `@preconcurrency` conformance can be written at the primary declaration or in an extension, and witness checker diagnostics about actor isolation will be suppressed.

프로토콜 이름 앞에 `@preconcurrency`를 붙이면, 프로토콜을 따르는 쪽의 격리 에러가 뜨지 않게 된다는 뜻이다. 그래서 `ConformanceIsolation` 에러는 사라졌다.

이게 정확히 무슨 약속인지는 [Conformance-isolation Docs](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"}에 더 분명하게 적혀있다.

> If the protocol requirements themselves are meant to always be used from the correct isolation domain (for example, the main actor) but the protocol itself did not describe that requirement, the conformance can be marked with @preconcurrency. This approach moves isolation checking into a run-time assertion, which will produce a fatal error if an operation is called without already being on the right actor.

번역하면, 프로토콜 요구사항이 원래 항상 올바른 격리 영역(예를 들어 메인 액터)에서 불리는데 프로토콜 선언에 그게 안 적혀있을 뿐이라면, 프로토콜 이름 앞에 `@preconcurrency`를 붙이면 된다는 뜻이다. 대신 격리 검사는 빌드할 때가 아니라 앱이 실행되는 중으로 미뤄지고, 올바른 액터가 아닌 곳에서 불리면 그 자리에서 앱이 강제 종료된다.

즉 프로토콜 이름 앞의 `@preconcurrency`는 "이 메서드들은 어차피 메인 액터에서만 불린다"는 약속이다. 그런데 `WCSessionDelegate`는 그 약속이 성립하지 않는 프로토콜이었다. 이건 아래 "진짜 해결은 nonisolated였다"에서 공식 문서로 다시 확인한다.

남은 건 호출하는 쪽이다. 원래라면 격리 위반은 부르는 자리에서 걸린다("함수도 안 쓰면 빌드 에러가 난다"의 `callLabelDirectly`처럼). 그런데 `session(...)`을 실제로 부르는 건 우리 Swift 코드가 아니라 WatchConnectivity 프레임워크 내부다. 컴파일러가 볼 수 있는, 부르는 코드 자체가 없다. `ConformanceIsolation` 에러는 `@preconcurrency`가 지웠고 부르는 쪽은 보이지 않으니, 에러도 경고도 뜰 자리가 없었던 것이다.

---

#### 진짜로 크래시까지 재현해보기

컴파일도 경고도 없었는데 왜 하필 크래시가 났을까. 같은 SE-0423에 답이 있다.

> the compiler will emit a runtime check to assert that the current executor matches the expected executor of the isolated actor. Calling an isolated synchronous function from outside the isolation domain will result in a runtime error that halts program execution.

번역하면, 컴파일러가 "지금 실행 중인 곳이 이 액터가 기대하는 곳이 맞는가"를 확인하는 코드를 자동으로 넣어두고, 격리된 동기 함수를 격리 밖에서 부르면 프로그램을 멈춘다는 뜻이다. 빌드할 때 못 막은 걸 실행 중에 막는 것이다. 이 글에서는 이걸 런타임 체크라고 부른다. 실제로 RunWay 크래시 로그를 보면 이 확인 함수가 그대로 찍혀있다.

```text
bl     0x1016c937c   ; symbol stub for: Swift._checkExpectedExecutor(...)
```

처음에는 "백그라운드 스레드에서 부르기만 하면 되겠지" 하고 가장 단순하게 만들어봤다.

```swift
let settings = await AppSettings(name: "prod", timeout: 30)
DispatchQueue.global().async {
    print(settings.label())   // label()에 nonisolated 없음
}
```

빌드하면 경고가 뜬다.

```text
warning: call to main actor-isolated instance method 'label()' in a synchronous nonisolated context [#ActorIsolatedCall]
```

`callLabelDirectly`에서는 에러였던 게 여기선 경고다. `DispatchQueue.global().async`의 클로저 파라미터가 `@preconcurrency`라서, Sendable 캡처 검사뿐 아니라 이 격리 검사도 경고로 낮아진 것이다. 근데 실행하면 크래시가 안 났다. `prod (30.0s)`가 그대로 찍히고 멀쩡하게 끝났다.

이유는 런타임 체크가 들어가는 자리에 있었다. SE-0423을 다시 읽어보니 이 체크는 아무 데나 들어가지 않는다.

- `: @preconcurrency LabelProviding`처럼 프로토콜 이름 앞에 `@preconcurrency`를 붙인 프로토콜을 통해 격리된 메서드를 부를 때. 프로토콜 타입으로 부르면 컴파일러가 만든 중간 연결 코드를 거쳐 실제 메서드로 가는데, 이 연결 코드를 **witness**라고 부른다
- `@objc` 클래스의 격리된 메서드를 Objective-C 쪽에서 부를 때. 이때도 Objective-C 호출을 Swift 메서드로 이어주는 연결 코드를 거치는데, 이걸 **thunk**라고 부른다
- 격리된 함수 자체를 `@preconcurrency`가 붙은 API처럼 엄격한 검사를 안 하는 곳에 넘길 때

위 코드는 `label()`을 프로토콜도 `@objc`도 거치지 않고 `AppSettings` 타입 그대로 직접 불렀다. 어디에도 해당하지 않으니 체크 자체가 없었던 것이다. 그래서 두 가지 경로로 다시 만들었다.

**`@objc` 경로 (RunWay와 같은 모양)**

```swift
@objc protocol ObjCLabelProviding {
    func label() -> String
}

@MainActor
final class ObjCSettings: NSObject, @preconcurrency ObjCLabelProviding {
    let name: String
    init(name: String) { self.name = name }

    func label() -> String { name }   // nonisolated 없음
}

let objc = await ObjCSettings(name: "objc")
DispatchQueue.global().async {
    _ = objc.perform(#selector(ObjCLabelProviding.label))   // 여기서 크래시
}
```

![](/assets/images/upload/crash.png)

**순수 Swift 프로토콜 경로**

```swift
protocol LabelProviding {
    func label() -> String
}

@MainActor
final class SwiftSettings: @preconcurrency LabelProviding {
    let name: String
    init(name: String) { self.name = name }

    func label() -> String { name }   // nonisolated 없음
}

let erased: any LabelProviding = await SwiftSettings(name: "witness")
DispatchQueue.global().async {
    print(erased.label())   // 여기서 크래시
}
```

둘 다 진짜로 죽었다. `exit code 133`(SIGTRAP). 위 `@objc` 경로를 실행한 Xcode 스크린샷을 보면 91번 줄 `objc.perform(...)`에서 멈췄고, 왼쪽 스레드 목록에는 `7 closure #4 in runRuntimeCr...`만 보인다. 그 사이 줄들은 Xcode가 접어서 보여준다. 터미널에서 디버거(lldb)로 찍어도 기본 출력에서는 일부 줄이 빠져 보이는데, 컴파일러가 만든 코드라 디버거가 숨기기 때문이다. `thread backtrace -u`로 숨김 없이 찍으면 두 경로가 이렇게 나온다.

```text
// @objc 경로
frame #5: libswift_Concurrency.dylib`_checkExpectedExecutor(...) + 60
frame #6: ConcurrencyLab`@objc ObjCSettings.label() at <compiler-generated>:0
frame #7: ConcurrencyLab`closure #4 in runRuntimeCrashComparisonDemo(objc=...) at RuntimeIsolationCrashDemo.swift:91:22

// 순수 Swift 프로토콜 경로
frame #5: libswift_Concurrency.dylib`_checkExpectedExecutor(...) + 60
frame #6: ConcurrencyLab`protocol witness for LabelProviding.label() in conformance SwiftSettings at <compiler-generated>:0
frame #7: ConcurrencyLab`closure #3 in runRuntimeCrashComparisonDemo(erased=...) at RuntimeIsolationCrashDemo.swift:84:26
```

두 경로 모두 frame #6에 컴파일러가 만든 코드(`<compiler-generated>`)가 있다. 하나는 `@objc` thunk, 하나는 프로토콜 witness, 즉 런타임 체크가 들어가는 자리로 앞에서 설명한 두 연결 코드다. 그리고 바로 위 frame #5가 `_checkExpectedExecutor`다. 런타임 체크가 정확히 이 연결 코드 안에 들어있다는 뜻이다.

Objective-C가 없어도 크래시가 났다는 게 중요하다. 순수 Swift 경로는 앞의 "프로토콜 타입으로 감싸면 왜 위험한가"에서 `printAnywhere`로 본 상황 그대로다. `any LabelProviding`으로 감싸는 순간 이 값이 MainActor 타입이라는 정보가 안 보이고, 그대로 백그라운드에서 불린다. 그러니까 크래시 조건은 "Objective-C냐"가 아니라 "격리 밖에서, 프로토콜 이름 앞에 `@preconcurrency`를 붙인 프로토콜의 witness나 `@objc` thunk를 거쳐서 부르느냐"다.

![](/assets/images/upload/runtime_check_paths_diagram.png)

`ConcurrencyLab`에 이 경로들을 모아뒀다. `swift run ConcurrencyLab runtimecrash objc`와 `swift run ConcurrencyLab runtimecrash witness`로 각각 확인할 수 있고, 마지막에 실제로 프로그램이 죽는 게 정상이다.

---

#### 진짜 해결은 nonisolated였다

After 코드는 `@preconcurrency`와 `nonisolated`를 둘 다 쓴다. 근데 크래시를 막은 건 `nonisolated`다. 이게 왜 필요한지는 [WCSessionDelegate Docs](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate){:target="_blank"}에 그대로 적혀있다.

> The methods of this protocol are called on a background thread of your app, so any code you write should be written with that fact in mind.

번역하면, 이 프로토콜의 메서드들은 앱의 백그라운드 스레드에서 호출되니 그 사실을 염두에 두고 코드를 작성하라는 뜻이다. `WCSession`이 실제로 백그라운드 스레드에서 부른다는 게 공식적으로 명시되어 있다. 앞에서 본 프로토콜 이름 앞 `@preconcurrency`의 약속("어차피 메인 액터에서만 불린다")과 정반대다. 약속이 처음부터 틀렸으니 런타임 체크에 걸려 앱이 죽은 것이다. 그러니 이 메서드는 진짜로 격리 없이 안전해야 하고, 그걸 선언하는 게 `nonisolated`다.

`@preconcurrency`는 컴파일러의 경고와 에러만 낮출 뿐 메서드의 격리 상태는 그대로 둔다. 메서드는 여전히 `@MainActor`이고, 백그라운드에서 불리는 순간 런타임 체크에 걸린다.

![](/assets/images/upload/preconcurrency_vs_nonisolated_diagram.png)

실제로 `ObjCSettings.label()`에 `nonisolated`를 붙이니 크래시 없이 `exit code 0`으로 끝났다. 그리고 컴파일러가 이런 경고를 하나 띄웠다.

```text
warning: '@preconcurrency' on conformance to 'ObjCLabelProviding' has no effect
```

프로토콜을 따르는 메서드가 전부 `nonisolated`가 되면, 프로토콜 이름 앞의 `@preconcurrency`는 더 이상 할 일이 없다는 뜻이다. `@preconcurrency`는 고장 난 코드가 컴파일되게 해준 쪽이었고, 실제로 고친 건 `nonisolated`였다.

---

#### 왜 Objective-C 델리게이트에서 유독 자주 터지나

순수 Swift에서도 크래시가 날 수 있다는 걸 봤다. 그래도 실전에서 이 크래시를 만나는 건 대부분 Objective-C 델리게이트다. 이유는 두 가지라고 본다.

첫째, 부르는 쪽이 보이지 않는다. SE-0423의 Motivation 섹션에 이렇게 적혀있다.

> Many Swift programs need to interoperate with frameworks written in C/C++/Objective-C whose implementations cannot participate in static data race safety.

번역하면, C/C++/Objective-C로 작성된 프레임워크와 같이 써야 하는 Swift 프로그램이 많은데, 그 프레임워크 내부 코드는 Swift 컴파일러가 빌드할 때 하는 데이터 레이스 검사를 받을 수 없다는 뜻이다. `WCSessionDelegate`를 실제로 호출하는 코드는 WatchConnectivity 내부에 있어서, 컴파일러가 부르는 쪽을 검사할 방법이 없다.

둘째, 프로토콜 이름 앞에 `@preconcurrency`를 붙일 일이 많다. Objective-C 델리게이트 프로토콜은 Swift Concurrency 이전에 만들어져서 격리 정보가 없다. 그런데 앱 코드는 RunWay처럼 `@MainActor`가 기본인 경우가 많으니, 준수하는 순간 `ConformanceIsolation` 에러를 만나고, 가장 빠른 탈출구가 프로토콜 이름 앞의 `@preconcurrency`다. 직접 만든 Swift 프로토콜이었다면 프로토콜 쪽 격리를 맞추는 식으로 풀 여지가 있으니, 이 구멍을 낼 일이 상대적으로 적을 것이다.

그러니까 "Objective-C라서 크래시가 난다"가 아니라, "Objective-C 델리게이트는 이 구멍(프로토콜 이름 앞의 `@preconcurrency`)을 만들기 쉽고, 그 구멍으로 들어오는 호출을 컴파일러가 볼 수도 없다"가 정확하다.

![](/assets/images/upload/objc.png)

`nonisolated`는 프로퍼티냐 함수냐를 가리지 않는다. 근데 이 사례에서 배운 진짜 교훈은 따로 있다. 컴파일러가 항상 에러로 막아주는 게 아니라는 것이다. `@preconcurrency`가 낀 자리에서는 에러가 경고로 낮아지거나 아예 조용히 통과하고, 실제로 실행해서 크래시를 봐야만 문제가 드러날 수 있다.

---

## 6. 그렇다면 왜 이전에는 괜찮았나 (Swift 5 vs 6)

글 처음 에러가 났던 코드(`description`에 `nonisolated`가 없는 `AppSettings`)를 `Package.swift`의 `swiftLanguageMode`만 `.v5`로 내려서 다시 빌드해봤다.

```swift
// Package.swift
swiftSettings: [
    .swiftLanguageMode(.v5)   // .v6 → .v5
]
```

결과가 둘로 갈렸다.

**프로토콜을 따르는 줄의 에러는 경고로 낮아졌다.**

```text
warning: conformance of 'AppSettings' to protocol 'CustomStringConvertible' crosses into main actor-isolated code and can cause data races; this is an error in the Swift 6 language mode [#ConformanceIsolation]
```

컴파일러가 직접 "이건 Swift 6 모드에서나 에러다"라고 말해준다. 즉 이 검사는 Swift 6에서 에러로 바뀐 것이다.

**하지만 부르는 쪽 에러는 Swift 5에서도 그대로 에러였다.**

```text
error: main actor-isolated property 'description' cannot be accessed from outside of the actor
```

가설은 "Swift 5에서는 다 괜찮았을 것"이었는데 틀렸다. Swift 5에서도 격리된 멤버를 actor 밖에서 직접 접근하는 건 원래부터 에러였다. 이 코드에서 Swift 6이 새로 에러로 만든 건 "프로토콜을 따르는 선언이 격리 경계를 넘는지" 검사하는 부분이다. 그마저도 Swift 5에 경고로 이미 있었지, 아예 없던 검사는 아니었다.

즉 "이전엔 몰라도 됐다"가 아니라 "이전엔 경고로 알려주기만 하고 넘어가 줬다"에 가깝다.

---

### Swift 6 발표글에 적힌 변화

그러면 공식적으로는 Swift 6에서 동시성의 뭐가 바뀌었다고 말할까. [Swift 6 발표글](https://www.swift.org/blog/announcing-swift-6/){:target="_blank"}에 이렇게 나와있다.

> Swift 6 now includes a new, opt-in language mode that extends Swift's safety guarantees to prevent data races in concurrent code by diagnosing potential data races in your code as compiler errors.

Swift 6 언어 모드를 켜면 데이터 레이스 가능성을 컴파일 에러로 알려준다는 뜻이다. 바로 뒤에 이전 버전 얘기도 있다.

> Data-race safety checks were previously available as warnings in Swift 5.10 through the -strict-concurrency=complete compiler flag.

같은 검사가 Swift 5.10에도 있었지만, `-strict-concurrency=complete` 플래그를 따로 켜야 경고로 보였다는 것이다. [Migration Guide Docs](https://www.swift.org/migration/documentation/migrationguide/){:target="_blank"}는 이걸 한 문장으로 정리한다.

> When enabled, compiler safety checks that were previously optional become required.

선택이던 검사가 필수가 됐다는 말이다. 위 실험에서 컴파일러가 "this is an error in the Swift 6 language mode"라고 적어준 것과 같은 얘기다.

발표글에는 Swift 6에서 괜한 경고(실제로는 안전한 코드에 뜨는 경고)도 줄었다고 적혀있다. 규칙만 세진 게 아니라 판단도 정확해졌다는 뜻인데, 이 부분은 이번 글에서 직접 확인하지는 않았다.

---

### 플래그를 안 켜면 경고조차 안 보였다

여기서 꼬리질문이 하나 생겼다. 플래그를 따로 켜야 경고로 보였다면, 플래그를 안 켠 평범한 Swift 5 프로젝트에서는 뭐가 보였을까.

Swift 5.6 때 나온 [SE-0337](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md){:target="_blank"} 제안서의 첫 부분에 이유가 나온다.

> However, Swift 5.5 does not fully enforce Sendable nor all uses of the main actor because interacting with modules which have not been updated for Swift Concurrency was found to be too onerous.

Swift 5.5는 `Sendable`과 MainActor 규칙을 전부 강제하지 않았다. 아직 동시성 대응이 안 된 라이브러리와 같이 쓰기가 너무 번거로웠기 때문이라고 한다. 그래서 이 제안서가 검사 수준을 나눴고, Swift 6 모드도 아니고 플래그도 안 켰다면 가장 느슨한 **Minimal**이 기본값이 됐다.

직접 확인해봤다. "MainActor 클래스는 왜 다른가"의 `capturePlain`(평범한 클래스를 `@Sendable` 클로저에 캡처)과, 글 처음 에러가 났던 `AppSettings`(`description`에 `nonisolated` 없음)를 설정만 바꿔가며 빌드했다. 설정 단계는 Xcode의 Strict Concurrency Checking 항목에 나오는 세 단계(Minimal, Targeted, Complete)와 같다.

| 설정 | `capturePlain` | `AppSettings` |
|---|---|---|
| Swift 5, 기본값 (Minimal) | 아무것도 안 뜸 | 경고 |
| Swift 5, Targeted | 경고 | 경고 |
| Swift 5, Complete | 경고 | 경고 |
| Swift 6 | 에러 | 에러 |

`capturePlain`은 Swift 5 기본 설정에서 경고 한 줄 없이 그냥 통과했다. 위의 "경고와 에러가 갈리는 이유"에서 Sendable 경고가 Swift 5.6부터 뜨기 시작했다고 했지만, 기본 설정에서는 이렇게 아예 안 뜨는 코드도 있었던 것이다. "진짜로 값이 깨지는지 확인해보기"의 `BankAccount` 코드도 마찬가지다. Swift 6에서는 `@preconcurrency` 덕분에 경고로 낮아졌던 코드인데, Swift 5 기본 설정에서는 그 경고조차 없었다. 반면 `AppSettings`는 기본 설정에서도 경고가 떴다.

그러니 "이전엔 괜찮았다"는 느낌은 두 경우 중 하나다. 경고가 떴는데 넘어갔거나, 기본 설정이라 애초에 안 보였거나.

Apple의 [Build Settings Reference Docs](https://developer.apple.com/documentation/xcode/build-settings-reference#Strict-Concurrency-Checking){:target="_blank"}에도 이 설정에 대해 이렇게 적혀있다.

> This is always 'complete' when in the Swift 6 language mode and produces errors instead of warnings.

Swift 6 모드에서는 이 단계를 고를 수 없고 항상 Complete이며, 경고 대신 에러를 낸다는 것이다.

빌드할 때만 달라진 것도 아니다. "진짜로 크래시까지 재현해보기"에서 본 런타임 체크도 Swift 5 모드에서는 꺼져 있다. [SE-0423](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md){:target="_blank"} 맨 위에 이 체크가 `DynamicActorIsolation`이라는 기능으로 묶여 있다고 적혀있고, 이 기능은 Swift 6 모드에서만 기본으로 켜진다. `AppSettings`를 `@preconcurrency`로 준수시키고 `printAnywhere`로 백그라운드 스레드에서 부르는 코드를 만들어봤다. Swift 6 모드에서는 크래시가 났는데, Swift 5 모드로 빌드하니 크래시 없이 백그라운드 스레드에서 그대로 실행되고 끝났다. Swift 5 모드에서 이 기능만 따로 켜서(`-enable-upcoming-feature DynamicActorIsolation`) 빌드하면 다시 크래시가 난다.

Swift 5 → 6의 차이를 한 줄로 줄이면 이렇게 된다. 켜야 보이던 검사가 항상 켜지고, 경고가 에러가 됐고, 빌드할 때 못 잡은 건 실행 중에라도 잡게 됐다.

---

### 마이그레이션 가이드에 정리된 해결책

마이그레이션 가이드의 [Common Compiler Errors Docs](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/commonproblems#Protocol-Conformance-Isolation-Mismatch){:target="_blank"}에는 Swift 6으로 넘어갈 때 자주 만나는 에러로 이 글의 상황이 그대로 나온다. `@MainActor` 클래스가 격리 없는 프로토콜을 준수하는 예시와 함께, 해결책을 이렇게 나열한다.

- 프로토콜이 원래 MainActor에서만 쓰이는 거라면, 프로토콜에 `@MainActor`를 붙인다
- 요구사항을 `async`로 바꾼다. 대신 이걸 부르는 곳마다 `await`를 붙여야 한다
- 프로토콜 이름 앞에 `@preconcurrency`를 붙인다. 가이드에도 이렇게 하면 실행 중에 확인하는 코드가 들어간다("This inserts runtime checks")고 적혀있다. 위의 "진짜로 크래시까지 재현해보기"에서 본 크래시가 바로 이 확인 코드에 걸린 것이다
- 메서드에 `nonisolated`를 붙인다

이 글에서 고른 건 마지막 방법이다. `CustomStringConvertible`이나 `WCSessionDelegate`는 내가 고칠 수 없는 프로토콜이라 앞의 두 방법은 쓸 수 없다. `@preconcurrency`는 RunWay 크래시 재현에서 봤듯 에러만 지워줄 뿐, 다른 스레드에서 불리면 실행 중에 앱이 죽는다.

---

## 7. nonisolated가 퍼지는 문제

GitExplorer를 만들 때 `nonisolated` 하나를 붙였다가 연쇄적으로 다른 곳까지 다 고쳐야 했던 적이 있다. 최소 코드로 재현해봤다. [이전글 참고](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/){:target="_blank"}

```swift
extension AppSettings {
    private func loadDefaultLabel() -> String {   // nonisolated 없음
        "default"
    }

    nonisolated func summary() -> String {
        "summary: \(name), \(loadDefaultLabel())"
    }
}
```

`summary()`는 nonisolated인데, 그 안에서 부르는 `loadDefaultLabel()`은 아니다. 빌드하면 이런 에러가 난다.

```text
error: call to main actor-isolated instance method 'loadDefaultLabel()' in a synchronous nonisolated context [#ActorIsolatedCall]
    `- note: calls to instance method 'loadDefaultLabel()' from outside of its actor context are implicitly asynchronous
```

`summary()`는 `nonisolated`라서 어느 스레드에서든 `await` 없이 불릴 수 있다. 그런데 그 안에서 MainActor에서만 부를 수 있는 `loadDefaultLabel()`을 `await` 없이 부르니 막힌 것이다. `loadDefaultLabel()`에도 `nonisolated`를 붙이면 통과한다. 하나에 `nonisolated`를 붙이면, 그 안에서 부르는 것들도 따라서 붙여야 하는 셈이다.

![](/assets/images/upload/nonisolated_propagation_diagram.png)

[Actor-isolated-call Docs](https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call){:target="_blank"}에는 이 에러의 해결책이 두 가지 나온다. 여기에 방금 한 방법까지 더하면 세 가지다.

1. 부르는 대상(`loadDefaultLabel()`)에도 `nonisolated`를 붙인다 (방금 한 방법, 문서에는 없음)
2. 부르는 쪽(`summary()`)을 굳이 밖에서 부를 일이 없다면, `nonisolated`를 빼고 그냥 `@MainActor`로 둔다
3. `Task { @MainActor in ... }`로 감싸서, MainActor에서 도는 새 작업을 만들어 그 안에서 부른다

세 번째 방법은 "시작하게 된 이유"에서 말한, 에러가 나면 일단 감싸고 넘어갔던 그 방법이다. 왜 그게 통했는지 이제 설명이 된다. `nonisolated`인 곳에서 MainActor 멤버를 바로 부를 수 없으니, `Task { @MainActor in }`로 MainActor 위에서 도는 새 작업을 만들어 그 안에서 부른 것이다.

---

### Task로 감싸면 다 해결되나

그럼 `summary()`도 `Task`로 감싸면 되지 않을까 싶어서 해봤다.

```swift
extension AppSettings {
    private func loadDefaultLabel() -> String {   // nonisolated 없음
        "default"
    }

    nonisolated func summary() -> String {
        var label = "(아직 없음)"
        Task { @MainActor in
            label = self.loadDefaultLabel()
        }
        return "summary: \(name), \(label)"
    }
}
```

`loadDefaultLabel()`을 부르는 에러는 사라졌는데, 대신 다른 에러가 났다.

```text
error: sending 'label' risks causing data races [#SendingRisksDataRace]
note: 'label' is captured by a main actor-isolated closure. main actor-isolated uses in closure may race against later nonisolated uses
```

`Task` 안의 코드는 바로 실행되는 게 아니라, 나중에 MainActor 차례가 왔을 때 실행된다. 그 사이에 `summary()`는 먼저 `return`까지 가버린다. 그래서 `Task` 안에서 `label`을 바꾸는 것과 밖에서 `label`을 읽는 게 동시에 일어날 수 있고, 컴파일러가 그걸 막은 것이다.

즉 `Task`로 감싸는 방법은 "부르고 끝"인 코드에는 통하지만, 결과를 바로 돌려줘야 하는 `summary()` 같은 함수에는 쓸 수 없다.

---

### 타입 전체를 nonisolated로

이 전파는 실전에서는 훨씬 크게 번질 수 있다. GitExplorer(심화1)에서는 `nonisolated`를 붙인 메서드 안에서 부르는 멤버들이 줄줄이 걸려서, 결국 멤버 하나씩이 아니라 **타입 전체**를 `nonisolated`로 선언하는 쪽을 택했다.

```swift
nonisolated final class GitHubNetworkService {
    // 클래스 본문 안의 메서드는 nonisolated를 따로 붙일 필요 없음
}
```

원래 아무것도 안 붙인 평범한 클래스는 격리가 없으니, 굳이 `nonisolated`를 붙일 이유가 없어 보인다. 근데 GitExplorer 프로젝트에도 "메서드가 왜 MainActor가 됐나"에서 본 `Default Actor Isolation = MainActor` 설정이 켜져 있었다(이전글에도 그대로 적혀있다). 아무것도 안 붙이면 `@MainActor`가 되니, 빼려면 `nonisolated`를 직접 적어야 했던 것이다.

그리고 "메서드가 왜 MainActor가 됐나"에서 확인한 것처럼, 클래스에 붙인 `nonisolated`는 클래스 본문 안의 메서드에만 적용된다. extension으로 나눠둔 메서드는 여전히 `@MainActor`라서, 따로 `nonisolated`를 붙여야 한다.

이 타입은 UI와 상관없는 네트워크 코드라 애초에 `@MainActor`일 이유가 없었다. 판단 기준은 이랬다.

- 그 타입이 UI 상태를 다루는가 (`@MainActor`가 실제로 필요한가) → 필요한 멤버에만 하나씩 `nonisolated`
- 그 타입이 UI와 상관없는 코드인가 → 타입 전체를 `nonisolated`로 선언

![](/assets/images/upload/nonisolated_member_vs_type_diagram.png)

---

## 8. async 함수에 붙은 nonisolated는 다르다

여기까지 정리하고 AI와 글을 다시 검토하다가, AI가 내가 전혀 몰랐던 부분을 하나 짚어줬다. 지금까지 이 글에서 본 `nonisolated` 멤버는 전부 동기(`description`, `label()`, `summary()`)였는데, `async` 함수에 붙은 `nonisolated`는 실행되는 곳이 다르다는 것이다. 게다가 그 동작이 Swift 6.2에서 또 바뀌었다고 했다.

처음 듣는 얘기라 그대로 받아 적지 않고, 공식 문서를 찾아보고 직접 돌려서 확인했다.

---

### 동기와 async는 실행되는 곳이 다르다

MainActor에서 `nonisolated` 동기 함수와 `nonisolated` async 함수를 하나씩 불러서, 각각 어느 스레드에서 도는지 찍어봤다.

```swift
import Foundation

func currentThread() -> String {
    Thread.isMainThread ? "Main Thread" : "Background Thread"
}

@MainActor
final class AppSettings {
    nonisolated func syncLabel() -> String {
        "동기 nonisolated: \(currentThread())"
    }

    nonisolated func asyncLabel() async -> String {
        "async nonisolated: \(currentThread())"
    }
}

@MainActor
func callFromMainActor() async {
    let settings = AppSettings()
    print("부르는 쪽: \(currentThread())")
    print(settings.syncLabel())
    print(await settings.asyncLabel())
}
```

`Thread.isMainThread`를 async 함수 안에서 바로 쓰면 "unavailable from asynchronous contexts" 에러가 나서, 동기 함수(`currentThread()`)로 한 번 감싸서 찍었다.

```text
부르는 쪽: Main Thread
동기 nonisolated: Main Thread
async nonisolated: Background Thread
```

같은 `nonisolated`인데 동기 함수는 부른 쪽(메인 스레드)에서 그대로 돌았고, async 함수는 백그라운드 스레드로 넘어갔다. [SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md){:target="_blank"}에 이 차이가 그대로 적혀있다.

> nonisolated synchronous functions always run on the caller's actor, while nonisolated async functions always switch off of the caller's actor.

동기 `nonisolated` 함수는 항상 부른 쪽 액터에서 실행되고, async `nonisolated` 함수는 항상 부른 쪽 액터에서 벗어나서 실행된다는 뜻이다. 원래 이렇게 만든 이유도 같은 곳에 나온다. async 함수가 액터를 붙잡고 있지 않게 해서, 특히 메인 액터가 예상치 못하게 오래 묶이는 걸 막으려는 것이었다.

근데 SE-0461은 바로 이 차이가 `nonisolated`를 이해하기 어렵게 만든다고 지적한다. 같은 키워드인데 함수가 동기냐 async냐에 따라 실행되는 곳이 달라지기 때문이다.

---

### Swift 6.2에서 바뀐 것

SE-0461(Swift 6.2에서 구현)의 제목이 곧 바뀐 내용이다.

> Run nonisolated async functions on the caller's actor by default

`nonisolated` async 함수도 기본적으로 부른 쪽 액터에서 실행되게 바꾸자는 것이다. 다만 기존 코드의 동작이 달라지는 변화라 바로 기본값이 되지는 않았고, `NonisolatedNonsendingByDefault`라는 기능을 켜야 적용된다. 대신 새 표기 두 개는 바로 쓸 수 있다.

- `nonisolated(nonsending)`: 부른 쪽 액터에서 실행
- `@concurrent`: 항상 부른 쪽 액터에서 벗어나서 실행

위 코드에 두 함수를 더 넣고, 이 기능을 끈 채로 한 번, 켠 채로(`-enable-upcoming-feature NonisolatedNonsendingByDefault`) 한 번 돌려봤다.

```swift
nonisolated(nonsending) func nonsendingLabel() async -> String {
    "nonisolated(nonsending): \(currentThread())"
}

@concurrent nonisolated func concurrentLabel() async -> String {
    "@concurrent: \(currentThread())"
}
```

| 함수 | `NonisolatedNonsendingByDefault` 끔 | 켬 |
|---|---|---|
| 동기 `nonisolated` | Main Thread | Main Thread |
| async `nonisolated` | Background Thread | **Main Thread** |
| `nonisolated(nonsending)` | Main Thread | Main Thread |
| `@concurrent` | Background Thread | Background Thread |

기능을 켜면 그냥 `nonisolated` async 함수가 `nonisolated(nonsending)`처럼 동작한다. 이제 동기든 async든 `nonisolated`는 부른 쪽에서 실행되고, 액터에서 벗어나고 싶으면 `@concurrent`를 직접 적어야 한다.

이 기능은 Xcode에서는 Approachable Concurrency 설정으로 켜진다. [Build Settings Reference Docs](https://developer.apple.com/documentation/xcode/build-settings-reference#Approachable-Concurrency){:target="_blank"}에 이 설정이 켜는 기능 목록이 나와있고, 그 안에 `NonisolatedNonsendingByDefault`가 들어있다.

> Enables upcoming features that aim to provide a more approachable path to Swift Concurrency: DisableOutwardActorInference, GlobalActorIsolatedTypesUsability, InferIsolatedConformances, InferSendableFromCaptures, and NonisolatedNonsendingByDefault.

---

### GitExplorer의 nonisolated async 다시 보기

여기서 꼬리질문이 생겼다. 내 프로젝트는 이 설정이 어떻게 되어 있을까.

확인해보니 RunWay와 GitExplorer 둘 다 `SWIFT_APPROACHABLE_CONCURRENCY = YES`였다. GitExplorer를 빌드해서 컴파일러에 실제로 넘어가는 옵션도 확인해봤는데, `-enable-upcoming-feature NonisolatedNonsendingByDefault`가 그대로 들어가 있었다.

그런데 GitExplorer 심화1([이전글](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/){:target="_blank"})에서는 네트워크 호출이 메인 스레드에서 시작되는 걸 막으려고, `@MainActor` 뷰모델의 `asyncFetchFavoriteDataBefore()`에 `nonisolated`를 붙였다. 그리고 이렇게 적었다. "`nonisolated`로 분리되어 `MainActor`의 격리 영역 밖에서 실행되고". 이 설정이 켜져 있으면 그 설명이 맞지 않을 수 있다.

같은 모양으로 최소 코드를 만들어서 확인해봤다. GitExplorer처럼 기본 격리를 MainActor로 두고(`-default-isolation MainActor`), `NonisolatedNonsendingByDefault`만 끄고 켜면서 빌드했다.

```swift
import Foundation

// 기본 격리가 MainActor라서 nonisolated를 붙여야 어디서든 부를 수 있다
nonisolated func currentThread() -> String {
    Thread.isMainThread ? "Main Thread" : "Background Thread"
}

@MainActor
final class FavoriteViewModel {
    var names = ["apple", "swiftlang"]
    var users: [String] = []

    // 심화1에서 메인 스레드에서 빼려고 nonisolated를 붙였던 함수
    nonisolated func asyncFetchFavoriteDataBefore() async -> [String] {
        print("fetch 시작: \(currentThread())")
        var result = [String]()
        for name in await names {
            result.append(name)
        }
        return result
    }

    func reloadData() async {
        users = await asyncFetchFavoriteDataBefore()
    }
}
```

| `NonisolatedNonsendingByDefault` | `fetch 시작` |
|---|---|
| 끔 | Background Thread |
| 켬 (GitExplorer와 같은 상태) | **Main Thread** |
| 켬 + 함수에 `@concurrent` | Background Thread |

GitExplorer 설정에서는 `nonisolated`를 붙여도 메인 스레드에서 그대로 시작됐다. 부르는 쪽(`reloadData()`)이 MainActor라서, 그 격리를 그대로 따라간 것이다. 심화1에서 의도한 대로 메인 스레드에서 빼려면 `@concurrent`를 붙여야 했다.

그렇다고 앱이 멈추는 문제가 있었던 건 아니다. 네트워크 요청을 `await`로 기다리는 동안에는 메인 스레드가 막히지 않는다. 다만 "`nonisolated`를 붙이면 메인 스레드에서 빠진다"고 알고 있던 게, 이 설정에서는 async 함수에 한해 틀린 얘기였다.

---

## 9. nonisolated 말고 @MainActor로 푸는 방법

async 얘기를 정리하면서 AI가 하나를 더 짚어줬다. 앞의 "Swift 6.2에서 바뀐 것"에서 인용한 Approachable Concurrency 목록에 `InferIsolatedConformances`라는 기능도 들어있는데, 이게 글 처음의 에러 자체와 관련이 있다는 것이다. RunWay와 GitExplorer에도 이 기능이 켜져 있으니, 내 프로젝트에서는 글 처음의 코드(`description`에 `nonisolated`가 없는 `AppSettings`)가 에러가 안 날 수도 있다고 했다. 이것도 직접 확인해봤다.

---

### 프로토콜 이름 앞에 @MainActor 붙이기

[SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md){:target="_blank"}(Swift 6.2에서 구현)에서 새로 생긴 방법이다. `description`에 `nonisolated`를 붙이는 대신, `CustomStringConvertible` 이름 앞에 `@MainActor`를 붙인다.

```swift
@MainActor
final class AppSettings: @MainActor CustomStringConvertible {
    let name: String
    let timeout: Double

    init(name: String, timeout: Double) {
        self.name = name
        self.timeout = timeout
    }

    var description: String {   // nonisolated 없음
        "AppSettings(name: \(name), timeout: \(timeout))"
    }
}
```

`description`은 그대로 MainActor에 격리된 채로 두고, 대신 "`AppSettings`를 `CustomStringConvertible`로 쓰는 건 MainActor에서만 된다"고 표시하는 것이다. 여기에 "프로토콜 타입으로 감싸면 왜 위험한가"의 코드(`DeviceInfo`, `printAnywhere`, `callFromBackgroundQueue()`)를 그대로 붙이고, MainActor에서 부르는 함수를 하나 더 만들어서 빌드해봤다.

```swift
@MainActor
func callFromMainActor() {
    let settings = AppSettings(name: "prod", timeout: 30)
    print(printAnywhere(settings))
}
```

`final class AppSettings: @MainActor CustomStringConvertible` 줄에서는 에러가 안 났다. `callFromMainActor()`도 통과했고, 실행하면 `Main Thread: AppSettings(name: prod, timeout: 30.0)`이 찍혔다. 에러는 `callFromBackgroundQueue()`의 `DispatchQueue.global().async` 안에서 `printAnywhere(settings)`를 부르는 줄에서만 났다.

```text
error: main actor-isolated conformance of 'AppSettings' to 'CustomStringConvertible' cannot be used in nonisolated context [#IsolatedConformances]
```

즉 에러가 나는 자리가 옮겨갔다. 원래는 `AppSettings`가 `CustomStringConvertible`을 따른다고 적은 선언에서 막았다. 이제는 `CustomStringConvertible`로 쓰는 걸 MainActor 안으로 제한했으니, MainActor 밖에서 그렇게 쓰려는 곳에서 막는다.

---

### @MainActor가 두 번 붙는 이유

위 코드를 다시 보면 좀 이상하다. `@MainActor`가 class 앞에도 붙고, 프로토콜 이름 앞에도 붙어서 두 번 들어갔다.

이 어색함은 SE-0470에도 그대로 적혀있다.

> However, the inference rule feels uneven: why is the `@MainActor` in one place inferred but not in the other?

한쪽의 `@MainActor`는 알아서 추론해주면서, 왜 다른 쪽은 안 해주냐는 것이다.

그래도 두 개가 하는 일은 다르다. `var count`를 읽는 `description`으로, 붙이는 위치만 바꿔가며 빌드해봤다.

```swift
import Foundation

@MainActor                    // ① class 앞
final class AppSettings: @MainActor CustomStringConvertible {   // ② 프로토콜 이름 앞
    var count = 0
    var description: String { "count: \(count)" }
}

nonisolated func printAnywhere<T: CustomStringConvertible>(_ value: T) -> String {
    value.description
}

func callFromBackground(_ s: AppSettings) {
    DispatchQueue.global().async {
        print(printAnywhere(s))
    }
}
```

| ① class 앞 | ② 프로토콜 이름 앞 | 결과 |
|---|---|---|
| `@MainActor` | 없음 | `class AppSettings` 줄에서 `ConformanceIsolation` 에러 (글 처음과 같은 상황) |
| 없음 | `@MainActor` | 백그라운드로 넘길 때 Sendable 경고, `printAnywhere(s)` 줄에서 `IsolatedConformances` 에러 |
| `@MainActor` | `@MainActor` | `printAnywhere(s)` 줄에서만 `IsolatedConformances` 에러 |

- ① class 앞의 `@MainActor`: 클래스 안의 값(`count`, `description`)을 MainActor가 지키게 한다. "누가 이 값을 만질 수 있나"를 정한다
- ② 프로토콜 이름 앞의 `@MainActor`: `AppSettings`를 `CustomStringConvertible`로 쓰는 걸 MainActor 안으로 제한한다. "이 타입을 이 프로토콜로 어디서 쓸 수 있나"를 정한다

②만 붙이면 클래스 안의 값은 보호받지 못한다. 그래서 백그라운드로 넘길 때 Sendable 경고가 떴다. 둘 다 있어야 "값도 MainActor가 지키고, 프로토콜로도 MainActor에서만 쓴다"가 된다. 중복이 아니라 각자 다른 걸 정하는 것이다.

다만 대부분은 둘 다 원하니까, 매번 두 번 적게 하는 게 어색했던 것이다. 그래서 SE-0470은 ①만 적어도 ②가 붙은 것처럼 보는 규칙을 같이 넣었다. 그게 아래 "내 프로젝트에서는 자동으로 적용된다"에서 볼 `InferIsolatedConformances`다.

---

### nonisolated와 뭐가 다른가

둘 다 글 처음의 에러를 없애지만 방향이 반대다.

- `nonisolated`: `description`을 격리에서 빼서, 어디서든 쓸 수 있게 한다. 대신 `description` 안에서 MainActor 상태를 못 쓴다
- 프로토콜 이름 앞에 `@MainActor`: `description`은 격리된 채로 두고, `CustomStringConvertible`로 쓰는 걸 MainActor 안으로 제한한다. 대신 백그라운드에서는 `CustomStringConvertible`로 못 쓴다

`var` 상태를 읽는 `description`으로 차이를 확인해봤다.

```swift
@MainActor
final class Counter: @MainActor CustomStringConvertible {
    var count = 0
    var description: String { "count: \(count)" }
}
```

프로토콜 이름 앞에 `@MainActor`를 붙인 쪽은 통과했다. 같은 코드에서 그 `@MainActor`를 빼고 `description`에 `nonisolated`를 붙이면 에러가 났다.

```text
error: main actor-isolated property 'count' can not be referenced from a nonisolated context
```

그러니 고르는 기준은 이렇다. `AppSettings`처럼 `let`만 읽고 백그라운드에서도 찍어야 하면 `nonisolated`, UI 상태처럼 MainActor 값을 읽어야 하고 MainActor에서만 쓰면 프로토콜 이름 앞에 `@MainActor`다.

그럼 RunWay의 `WCSessionDelegate`도 `nonisolated` 대신 이 방법으로 풀 수 있을까. "진짜로 크래시까지 재현해보기"의 `@objc` 예제에서 프로토콜 이름 앞의 `@preconcurrency`를 `@MainActor`로 바꿔서 돌려봤다.

```swift
@MainActor
final class ObjCSettings: NSObject, @MainActor ObjCLabelProviding {
    let name: String
    init(name: String) { self.name = name }

    func label() -> String { name }   // nonisolated 없음
}

DispatchQueue.global().async {
    _ = objc.perform(#selector(ObjCLabelProviding.label))
}
```

빌드는 에러도 경고도 없이 통과했는데, 실행하니 똑같이 크래시가 났다(`exit code 133`). Objective-C 쪽에서 `perform(selector:)`로 부르는 건 컴파일러가 볼 수 없어서, "MainActor에서만 쓴다"는 약속이 깨져도 빌드할 때는 못 잡고 실행 중에 죽는다. 그러니 `WCSessionDelegate`처럼 프레임워크가 백그라운드에서 부르는 델리게이트는 여전히 `nonisolated`가 답이다.

---

### 내 프로젝트에서는 자동으로 적용된다

SE-0470은 `@MainActor` 타입이면 프로토콜 이름 앞의 `@MainActor`를 안 적어도 붙은 것처럼 보는 규칙도 같이 넣었다. 그게 `InferIsolatedConformances` 기능이다. 글 처음의 코드를 프로토콜 이름 앞의 `@MainActor` 없이 원래대로 두고, 이 기능만 켜서(`-enable-upcoming-feature InferIsolatedConformances`) 빌드해봤다.

| 설정 | 글 처음의 코드(`nonisolated` 없음) 결과 |
|---|---|
| 기본 Swift 6 (이 글의 실험 환경) | `class AppSettings: CustomStringConvertible` 줄에서 `ConformanceIsolation` 에러 |
| `InferIsolatedConformances` 켬 | 그 줄은 통과, 백그라운드에서 쓰는 곳에서만 `IsolatedConformances` 에러 |

켜면 `@MainActor`를 직접 적은 것과 똑같이 동작했다.

"GitExplorer의 nonisolated async 다시 보기"에서 GitExplorer를 빌드해 컴파일러에 넘어가는 옵션을 봤을 때, 같은 목록에 `-enable-upcoming-feature InferIsolatedConformances`도 들어있었다. 이 글의 실험은 전부 기본 설정인 ConcurrencyLab에서 했기 때문에 글 처음의 에러가 `class AppSettings: CustomStringConvertible` 줄에서 났다. 같은 코드를 RunWay나 GitExplorer에 넣으면 그 줄은 조용히 통과하고, 백그라운드에서 쓰는 순간에야 에러가 난다. 에러가 안 난다고 `description`이 어디서든 안전해진 게 아니라, MainActor에서만 `CustomStringConvertible`로 쓸 수 있게 된 것이다.

---

## 정리

- `nonisolated`는 특정 멤버를 타입의 격리에서 빼주는 키워드다. 동기 멤버는 실행 스레드를 바꾸지 않고, 부른 쪽 스레드에서 그대로 실행된다(`printAnywhere`가 `Background Thread`에서 그대로 실행된 것처럼)
- 필요한 때는 프로토콜 요구사항처럼 애초에 격리되지 않은 자리에 멤버를 맞춰 넣어야 할 때다. 프로퍼티든 함수든 상관없다
- 격리는 본문이 무엇을 읽는지가 아니라 선언으로 정해진다. `let`만 읽는 계산 프로퍼티(`description`)도 타입의 격리를 따르고, 자동으로 `nonisolated` 취급되는 건 Sendable 타입의 `let` 저장 프로퍼티뿐이다
- 안 쓰면 나는 에러는 두 종류다. 프로토콜을 따르는 선언 자체가 막히는 `ConformanceIsolation`, 격리 밖에서 부를 때 막히는 `ActorIsolatedCall`
- `@preconcurrency`는 이 검사들을 낮춘다. API 선언에 붙어 있으면 부르는 쪽 에러가 경고로 낮아지고(`concurrentPerform`, `DispatchQueue.async`), 프로토콜 이름 앞에 붙이면 `ConformanceIsolation` 에러가 아예 사라진다(`@preconcurrency WCSessionDelegate`)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`일 때 클래스에 붙인 `nonisolated`는 클래스 본문 안의 메서드에만 적용된다. extension 안의 메서드는 빌드 설정의 기본값(`MainActor`)을 따른다. RunWay 델리게이트 메서드가 조용히 `@MainActor`가 된 이유다
- RunWay 크래시가 빌드할 때 안 잡힌 건, `ConformanceIsolation` 에러는 `@preconcurrency`가 지웠고 부르는 쪽은 Objective-C 프레임워크 안이라 컴파일러가 볼 수 없었기 때문이다
- 그 대신 실행 중에 확인하는 런타임 체크(`_checkExpectedExecutor`, [SE-0423](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md){:target="_blank"})가 있다. 이 체크는 프로토콜 witness나 `@objc` thunk 같은 연결 코드 안에 들어있어서, 같은 메서드도 타입 그대로 부르면 체크가 없고 프로토콜이나 `@objc`를 거쳐 격리 밖에서 부르면 크래시가 난다. Objective-C가 꼭 있어야 하는 건 아니다
- `@preconcurrency`는 경고와 에러만 낮출 뿐, 메서드의 격리 상태는 그대로 둔다. `nonisolated`는 격리 자체를 없애서 다른 스레드에서 불려도 안전하게 만든다. `nonisolated`를 붙이자 프로토콜 이름 앞의 `@preconcurrency`에 "has no effect" 경고가 뜬 게 그 증거다. 에러를 지운 건 `@preconcurrency`였고, 실제로 고친 건 `nonisolated`였다
- 다른 스레드에서 충돌한다고 무조건 크래시가 나는 건 아니다. `BankAccount`는 20번 중 17번 값이 깨졌는데도 크래시가 없었다. 격리된 타입이 아니라 확인할 액터 자체가 없었기 때문이다
- Swift 5 → 6 변화는 "없던 규칙이 생김"이 아니라 "켜야 보이던 검사가 항상 켜지고, 경고가 에러로 바뀜"이었다. Swift 5 기본 설정(Minimal)에서는 Sendable 캡처처럼 경고조차 안 뜨던 검사도 있었고, 런타임 체크도 Swift 6 모드에서만 기본으로 켜진다
- `nonisolated`는 퍼진다. 하나에 붙이면 그 안에서 부르는 것들도 격리 없이 안전해야 하고, 이게 많이 번지면 타입 전체를 `nonisolated`로 선언하는 게 나을 수 있다
- `Task { @MainActor in }`로 감싸면 에러는 사라지지만, 안의 코드는 바로가 아니라 나중에 실행된다. 그래서 결과를 바로 돌려줘야 하는 함수에는 쓸 수 없다
- async 함수에 붙은 `nonisolated`는 원래 부른 쪽 액터에서 벗어나서 실행됐다. Swift 6.2의 `NonisolatedNonsendingByDefault`(Xcode의 Approachable Concurrency 설정)를 켜면 동기 함수처럼 부른 쪽에서 실행되고, 액터에서 벗어나려면 `@concurrent`를 직접 붙여야 한다. GitExplorer도 이 설정이 켜져 있어서, 메인 스레드에서 빼려고 `nonisolated`를 붙인 async 함수가 실제로는 메인 스레드에서 시작되고 있었다
- Swift 6.2부터는 `nonisolated` 대신 프로토콜 이름 앞에 `@MainActor`를 붙일 수도 있다(`: @MainActor CustomStringConvertible`). `description`은 격리된 채로 MainActor 값을 읽을 수 있고, 대신 MainActor 밖에서 `CustomStringConvertible`로 쓰는 곳에서 에러가 난다. class 앞과 프로토콜 이름 앞의 `@MainActor`는 각각 다른 걸 정한다(값을 누가 만지나, 프로토콜로 어디서 쓰나). 다만 Objective-C 델리게이트처럼 프레임워크가 백그라운드에서 부르는 경우엔 이 방법으로도 실행 중에 크래시가 난다. Approachable Concurrency(`InferIsolatedConformances`)가 켜진 프로젝트에서는 이게 자동으로 적용돼서, 글 처음의 에러가 `class AppSettings: CustomStringConvertible` 줄에서 안 난다
