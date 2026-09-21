---
title: (Deep Dive) nonisolated는 왜 필요한가
writer: Harold
date: 2026-09-19 18:00
categories: [Deep Dive]
tags: [Myself]
published: false
toc: true
toc_sticky: true
---

## 시작하게 된 이유

`nonisolated`를 실전에서는 에러 지우는 용도로만 써봤다. actor isolation 에러가 나면 일단 `nonisolated`를 붙이거나 `Task { @MainActor in }`으로 감싸서 넘어갔는데, 정작 "이게 정확히 뭘 하는 키워드인가"는 설명 못 한다. 이번엔 실제 프로젝트 사례를 뒤지는 대신, `nonisolated` 하나만 놓고 최소 코드로 정의부터 다시 확인한다.

Udemy Async/Await 시리즈, Concurrency 격리 정리글에서 actor/MainActor 기본 개념은 이미 다뤘으니 여기서 다시 설명하지 않는다.

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

### 데이터 레이스가 뭔지

여기서 말하는 데이터 레이스가 정확히 뭔지, 왜 위험한지는 예전에 [Swift Concurrency & 격리(Isolation) 핵심 개념 정리](https://haroldfromk.github.io/posts/swift-concurrency-isolation/){:target="_blank"} 에서 이미 다뤘다. 

짧게만 정리하면, MainActor로 격리된 코드가 격리 안 된 컨텍스트로 "넘어가면" 서로 다른 실행 흐름이 같은 상태를 동시에 건드릴 수 있게 되고, 컴파일러는 그 가능성 자체를 막으려는 것이다. 계좌 잔고로 예를 들면 이런 식이다.

![](/assets/images/upload/nonisolated_data_race_diagram.png)

두 흐름이 같은 값을 동시에 읽고, 각자 계산한 뒤 나중에 쓰는 쪽이 앞의 변경을 덮어써버린다. 이게 데이터 레이스다.

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

`Sendable`을 스치듯 언급하고 넘어가기엔 계속 나온다. 여기서 제대로 짚어본다. 공식 정의는 이렇다.

> A thread-safe type whose values can be shared across arbitrary concurrent contexts without introducing a risk of data races.

번역하면, "값을 임의의 동시성 컨텍스트 간에 안전하게 공유할 수 있는, 스레드 안전한 타입"이다.

![](/assets/images/upload/sendable.png)

`nonisolated`가 "이 멤버를 어디서 호출해도 되는가"를 다뤘다면, `Sendable`은 "이 값을 다른 실행 컨텍스트로 넘겨도 되는가"를 다룬다. 둘 다 "동시성 경계를 넘을 때 안전한가"라는 같은 문제의 다른 면이다.

실전에서 이런 경고나 에러를 만나면, 그 클로저를 받는 메서드가 정말 `@Sendable`을 요구하는지 직접 확인하는 게 좋다. Xcode에서 그 메서드 이름 위에 Option 키를 누른 채 클릭하면 시그니처가 바로 뜨고, Command 키를 누른 채 클릭하면 실제 선언으로 이동한다. 이번에도 그렇게 확인했다.

같은 패턴을 순수 Swift로 선언한 `@Sendable` 클로저 파라미터에 넣으면 이건 하드 에러다. 공식 문서 예제로 확인했다.

```swift
func callConcurrently(_ closure: @escaping @Sendable () -> Void) { }

class MyModel {
    func log() { }
}

func capture(model: MyModel) async {
    callConcurrently {
        model.log()   // error: capture of 'model' with non-Sendable type 'MyModel' in a '@Sendable' closure
    }
}
```

근데 `DispatchQueue.concurrentPerform`에 똑같은 패턴을 넣으면 경고로만 뜬다. 실제 선언을 찾아보면 이유가 나온다.

```swift
@preconcurrency public class func concurrentPerform(iterations: Int, execute work: @Sendable (Int) -> Void)
```

`@Sendable`은 우리 코드가 아니라 이 API 선언 자체에 있다. `work`의 타입이 `@Sendable (Int) -> Void`라서, 우리가 넘긴 평범한 클로저 리터럴도 그 자리에 들어가는 순간 `@Sendable` 클로저로 취급된다. `Task { }`도 같은 구조다. `Task.init`의 `operation` 파라미터가 `@Sendable`이라서, 우리가 직접 `@Sendable`이라고 쓴 적 없어도 `Task { ... }`의 클로저는 `@Sendable`이 된다.

그리고 선언 맨 위에 `@preconcurrency`가 붙어있다. 이게 경고로 완화된 진짜 이유다. `@preconcurrency`는 [#ConformanceIsolation](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"} 문서에서 이미 본 그 도구, "에러를 경고로 낮춰서 하위 호환을 지키는" 역할을 여기서도 그대로 하고 있다. `callConcurrently`(우리가 만든 순수 Swift 함수)는 `@preconcurrency`가 없어서 하드 에러였고, `concurrentPerform`은 Dispatch가 Swift Concurrency 이전부터 있던 API라 `@preconcurrency`로 감싸져서 경고로 낮아진 것이다.

즉 "격리가 없어서 안 봐준다"가 아니라, 검사 자체(Sendable)는 똑같이 걸리는데 API 선언에 `@preconcurrency`가 있느냐 없느냐로 심각도가 갈린다는 게 정확한 설명이다.

`Task`도 `callConcurrently`와 같은 쪽이다. `Task { @MainActor in ... }` 안에서 non-Sendable 타입을 캡처하면 `Capture of 'self' with non-Sendable type ... in a '@Sendable' closure` 같은 하드 에러가 난다. `Task`의 클로저도 순수 Swift가 선언한 `@Sendable` 파라미터라서 그렇다.

`nonisolated`를 쓰다 보면 유독 `Sendable` 에러도 같이 자주 만나게 되는데, 이유가 있다. 공식 문서에 이런 문장이 있다.

> Classes marked with @MainActor are implicitly sendable, because the main actor coordinates all access to its state.

`@MainActor` 클래스는 그 자체로 이미 Sendable이라는 뜻이다. 근데 플레인 클래스(액터도 아니고 `@MainActor`도 아닌)는 Sendable이 아니다. 두 경우를 나란히 확인해봤다.

```swift
@MainActor
final class MainActorModel {
    func log() { }
}

final class PlainModel {
    func log() { }
}

func captureMainActor(model: MainActorModel) async {
    callConcurrently {
        model.log()
    }
}

func capturePlain(model: PlainModel) async {
    callConcurrently {
        model.log()
    }
}
```

결과가 다르다.

```text
// MainActorModel
error: call to main actor-isolated instance method 'log()' in a synchronous nonisolated context [#ActorIsolatedCall]

// PlainModel
error: capture of 'model' with non-Sendable type 'PlainModel' in a '@Sendable' closure [#SendableClosureCaptures]
```

`MainActorModel`은 캡처 자체는 통과한다 (`@MainActor`라서 Sendable이니까). 대신 그 안에서 격리된 메서드(`log()`)를 동기 호출하려다 막힌다. 이게 이 글 3번 헤더에서 본 바로 그 에러(`ActorIsolatedCall`)다. `PlainModel`은 애초에 캡처하는 시점에서 막힌다 (`SendableClosureCaptures`).

즉 `nonisolated`가 필요해지는 상황(`@MainActor` 타입의 멤버를 격리 밖에서 쓰려는 상황)과 `Sendable` 에러가 나는 상황(non-Sendable 타입을 동시성 경계 밖으로 넘기려는 상황)이 자주 같은 코드에서 겹쳐 나타난다. 서로 다른 두 검사(격리 검사, Sendable 검사)가 같은 자리에서 나란히 걸리는 것뿐이지, 하나가 다른 하나를 일으키는 건 아니다.

---

### 프로토콜 타입으로 감싸면 왜 위험한가

그런데 정확히 어떤 상황에서 이 위험이 실제로 터지는지는 공식 문서에 따로 적혀있다.

> When a type conforms to a protocol, any generic code can perform operations on that type through the protocol. If the operations that the type used to satisfy the protocol requirements are actor-isolated, this may result in a diagnostic indicating that the conformance crosses into actor-isolated code.

번역하면, "타입이 프로토콜을 준수하면, 어떤 제네릭 코드든 그 프로토콜을 통해 이 타입에 연산을 수행할 수 있다. 프로토콜 요구사항을 만족시키는 연산이 actor에 격리되어 있다면, 이 준수가 actor로 격리된 코드로 넘어간다는 진단이 나올 수 있다"는 뜻이다.

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

그냥 `CustomStringConvertible`을 만족하는 값 하나일 뿐이다. `description`이 `nonisolated`라서 이게 안전하게 성립한 것이다. 만약 `description`이 격리된 채였다면(1번 상태) 애초에 `AppSettings`가 `CustomStringConvertible`을 준수하지도 못했을 것이고, 억지로 통과됐다면 `printAnywhere(settings)` 호출이 실제 레이스로 이어졌을 것이다.

![](/assets/images/upload/nonisolated_protocol_erasure_diagram.png)

프로토콜 타입으로 감싸이는 순간 "이건 MainActor에 격리되어 있다"는 정보가 겉으로 드러나지 않는다. 그 값을 들고 있는 임의의 Background Thread는 그걸 모른 채로 그냥 호출한다. 만약 그 구현이 실제로 격리된 가변 상태를 건드리는 것이었다면, 그 순간 진짜 레이스가 난다. 지금 `AppSettings`가 딱 그 상황이다. `@MainActor`인 타입이 `CustomStringConvertible`을 준수하는 것 자체가 "이 준수가 격리 경계를 넘나든다"는 뜻이다.

---

## 3. 두 번째 에러 - nonisolated 요구사항

```text
2. Main actor-isolated property 'description' cannot satisfy nonisolated requirement
```

여기에 답이 이미 적혀있다. `CustomStringConvertible.description` 요구사항 자체가 `nonisolated` 요구사항이라는 뜻이다. 즉 이 프로퍼티는 어디서든, 어떤 실행 컨텍스트에서든 `await` 없이 동기적으로 호출 가능해야 한다는 게 프로토콜의 전제다.

실제로 이 진단 코드([#ConformanceIsolation](https://docs.swift.org/compiler/documentation/diagnostics/conformance-isolation/){:target="_blank"})의 공식 문서에 그대로 나와있다.

> If the conformance needs to be usable anywhere, then each of the operations used to satisfy its requirements must be marked nonisolated. This means that they will not have access to any actor-specific operations or state, because these operations can be called concurrently from anywhere.

번역하면, "준수가 아무 데서나 쓰일 수 있어야 한다면, 그 요구사항을 만족시키는 연산들은 반드시 nonisolated로 표시해야 한다. 이 연산들은 어디서든 동시에 호출될 수 있기 때문에, actor 전용 연산이나 상태에 접근할 수 없게 된다"는 뜻이다. 지금까지 설명한 것과 정확히 같은 내용이다.

여기서 "어디서든 호출 가능"이라는 말을 헷갈리면 안 된다. 코드상 그 심볼을 참조할 수 있다는 접근 제어 얘기가 아니다. `@MainActor` 멤버도 코드 어디서든 참조는 할 수 있다.

다만 실제로 호출하려면 조건이 붙는다. 지금 내가 MainActor 위에 있으면 그냥 동기 호출되고, 밖에 있으면 `await`로 액터에 진입하는 절차가 필요하다.

그런데 `description`의 실제 구현체는 MainActor에 격리되어 있다. MainActor 밖에서 그 값을 들고 있는 코드가 `.description`을 부르는 순간, await도 없이 액터에 진입할 방법이 없다. 계약(동기 호출 가능)과 실제(격리됨)가 충돌하니, 컴파일러는 "격리된 멤버는 이 요구사항을 만족할 수 없다"고 원천 차단한다.

즉 필요한 건 `description`만 이 타입의 격리에서 빼주는 것이다. 그 역할을 하는 키워드가 `nonisolated`다.

비유하면 이렇다. `AppSettings`는 직원(MainActor 배지)만 출입 가능한 회사다. 근데 `CustomStringConvertible`이라는 협회에 가입하려면, 규정상 접수처만큼은 배지 없이 누구나 예약 없이 즉시 응대 가능해야 한다. 마침 접수처가 하는 일은 회사 기밀이 아니라 공개 정보(`name`, `timeout`) 안내뿐이라, 접수처(`description`)만 `nonisolated`로 열어서 그 규정을 만족시킨 것이다.

![](/assets/images/upload/requirenonisolated.png)

---

## 4. nonisolated로 고치기

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

## 5. 프로퍼티만이 아니라 함수도 똑같다

지금까지는 `description`이라는 프로퍼티(계산 프로퍼티)로만 봤다. `nonisolated`가 함수에도 똑같이 적용되는지 `Equatable`의 `==`로 확인해봤다. `==`는 static **함수**다.

```swift
extension AppSettings: Equatable {
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.name == rhs.name && lhs.timeout == rhs.timeout
    }
}
```

`nonisolated` 없이 그대로 빌드하면 `description` 때와 완전히 같은 모양의 에러가 난다.

```text
error: conformance of 'AppSettings' to protocol 'Equatable' crosses into main actor-isolated code and can cause data races [#ConformanceIsolation]
    |- note: isolate this conformance to the main actor with '@MainActor'
    |- note: turn data races into runtime errors with '@preconcurrency'
    `- note: mark all declarations used in the conformance 'nonisolated'
    `- note: main actor-isolated operator function '==' cannot satisfy nonisolated requirement
```

"cannot satisfy nonisolated requirement"가 이번엔 프로퍼티가 아니라 **operator function**을 가리킨다. 고치는 방법도 똑같다.

```swift
extension AppSettings: Equatable {
    nonisolated static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.name == rhs.name && lhs.timeout == rhs.timeout
    }
}
```

```swift
let a = await AppSettings(name: "prod", timeout: 30)
let b = await AppSettings(name: "prod", timeout: 30)
print(a == b)   // await 없이 호출됨
```

실행 결과:

```text
true
```

`nonisolated`는 프로퍼티냐 함수냐를 가리지 않는다. "이 멤버가 격리된 상태를 안 건드리니 격리 없이 호출 가능해야 하는 자리를 채울 수 있다"는 조건만 본다.

---

## 6. 그렇다면 왜 이전에는 괜찮았나 (Swift 5 vs 6)

같은 코드(1번의 `nonisolated` 없는 버전)를 `Package.swift`의 `swiftLanguageMode`만 `.v5`로 내려서 다시 빌드해봤다.

```swift
// Package.swift
swiftSettings: [
    .swiftLanguageMode(.v5)   // .v6 → .v5
]
```

결과가 둘로 갈렸다.

**프로토콜 준수 쪽은 경고로 낮아졌다.**

```text
warning: conformance of 'AppSettings' to protocol 'CustomStringConvertible' crosses into main actor-isolated code and can cause data races; this is an error in the Swift 6 language mode [#ConformanceIsolation]
```

컴파일러가 직접 "이건 Swift 6 모드에서나 에러다"라고 말해준다. 즉 이 검사 자체가 Swift 6에서 새로 강제된 것이다.

**하지만 호출 지점 에러는 Swift 5에서도 그대로 에러였다.**

```text
error: main actor-isolated property 'description' cannot be accessed from outside of the actor
```

가설은 "Swift 5에서는 다 괜찮았을 것"이었는데 틀렸다. Swift 5에서도 격리된 멤버를 actor 밖에서 직접 접근하는 건 원래부터 에러였다. Swift 6에서 새로 생긴 건 "프로토콜 준수가 격리 경계를 넘는지" 검사하는 부분 하나뿐이고, 그마저도 Swift 5에서는 경고로만 존재했지 아예 없던 검사는 아니었다.

즉 "이전엔 몰라도 됐다"가 아니라 "이전엔 경고로 알려주기만 하고 넘어가 줬다"에 가깝다.

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

당연한 결과다. `summary()`는 격리 없이 아무 데서나 동기 호출될 수 있어야 하는데, 그 안에서 격리된 메서드를 동기적으로 부르면 똑같은 모순이 생긴다. `loadDefaultLabel()`도 `nonisolated`로 표시하면 통과한다.

공식 문서([#ActorIsolatedCall](https://docs.swift.org/compiler/documentation/diagnostics/actor-isolated-call){:target="_blank"})에는 이 상황의 해결책이 세 가지로 정리되어 있다.

1. 호출하는 멤버도 `nonisolated`로 표시한다 (지금 한 것)
2. 호출자 자체를 굳이 밖에서 부를 필요가 없다면, `nonisolated`를 빼고 그냥 `@MainActor`로 둔다
3. `Task { @MainActor in ... }`로 감싸서 새 태스크를 만들어 그 안에서 부른다

3번은 앞서 다른 글에서 이미 본 그 밴드에이드다. 왜 그게 필요했는지 이제 설명이 된다.

nonisolated 컨텍스트에서 MainActor 멤버를 부르려니 이 문제가 났고, `Task { @MainActor in }`로 액터에 새로 진입한 것이다.

이 전파는 실전에서는 훨씬 크게 번질 수 있다. GitExplorer(심화1)에서는 `nonisolated`를 붙인 메서드 안에서 부르는 멤버들이 줄줄이 걸려서, 결국 멤버 하나씩이 아니라 **타입 전체**를 `nonisolated`로 선언하는 쪽을 택했다.

```swift
nonisolated final class GitHubNetworkService {
    // 메서드마다 nonisolated를 따로 붙일 필요 없음
}
```

이 타입은 UI와 무관한 네트워크 레이어라 애초에 `@MainActor`일 이유가 없었다. 판단 기준은 이랬다.

- 그 타입이 UI 상태를 다루는가 (`@MainActor`가 실제로 필요한가) → 멤버 하나씩 `nonisolated`
- 그 타입이 UI와 무관한 레이어인가 → 타입 전체를 `nonisolated`로 선언하는 게 더 설계 의도에 맞음

---

## 정리

- `nonisolated`는 실행 스레드를 바꾸는 키워드가 아니라, 특정 멤버를 타입의 격리에서 빼주는 키워드다
- 필요한 이유는 프로토콜 요구사항처럼 애초에 격리되지 않은 자리에 멤버를 맞춰 넣어야 할 때다
- 프로퍼티든 함수든 상관없다. "격리 없이 호출 가능해야 하는 자리를 채우는가"만 본다
- 안 쓰면 나는 에러는 최소 두 종류(준수 자체의 경계 문제, 실제 접근 위반)로 성격이 다르다
- Swift 5 → 6 변화는 "없던 규칙이 생김"이 아니라 "경고였던 규칙 일부가 에러로 격상됨"이었다 (적어도 이 케이스에서는)
- `nonisolated`는 전파된다. 하나에 붙이면 그 안에서 부르는 것들도 격리 없이 안전해야 하고, 이게 많이 번지면 멤버 하나씩보다 타입 전체를 `nonisolated`로 선언하는 게 나을 수 있다
- `@MainActor`를 아예 안 쓰면 `nonisolated`도 필요 없어지지만, 그건 안전해져서가 아니라 컴파일러가 더 이상 안 봐줘서다. 진짜 가변 상태가 있는 코드는 경고 한 줄만 뜨고 그대로 빌드되어 실제로 깨진다

---

## 남은 질문

- `@preconcurrency`를 붙이면 Swift 6에서도 이 경고/에러가 어떻게 달라지는지
- `nonisolated`가 실행 스레드까지 바꾸는지는 여기서 다루지 않았다. 별도로 확인이 필요하다.
- 공식 문서에 `nonisolated let`이라는 변형도 나온다. `Identifiable`의 `id`처럼 저장 프로퍼티 자체가 프로토콜 요구사항일 때 쓰는 패턴인데, 이번 글의 `description`/`==`(계산 프로퍼티·함수)와는 다른 경우라 아직 확인 안 해봄
