---
title: SwiftUI Combine (1)
writer: Harold
date: 2026-05-16 06:16
categories: [Udemy, Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

이전에 정리를 한적이 있긴한데, 강의에 적힌걸 번역해서 여기에 적어본다.

내용이 꽤나 많을지도?

## Combine이란?

Combine은 비동기 값을 데이터 스트림으로 처리하는 Apple의 프레임워크다.

4가지 핵심 구성요소가 있다.

- **Publisher** – 시간이 지남에 따라 값을 생산하는 소스 (네트워크 요청, 타이머, Subject 등)
- **Subscriber** – 값을 소비하는 리스너 (`.sink`)
- **Operator** – Publisher에 체이닝하여 스트림을 변환하거나 제어하는 메서드 (`map`, `filter`, `decode`, `debounce` 등)
- **Subject** – 값을 수동으로 `.send()`로 밀어넣을 수 있는 특수 Publisher. Subscriber 역할도 한다.
  - **PassthroughSubject** – 새 값만 구독자에게 방출한다.
  - **CurrentValueSubject** – 최신 값을 저장하고 있어, 새 구독자에게 즉시 현재 값을 전달한다.

---

### UFC 파이터 앱 예시

```swift
let subject = CurrentValueSubject<[MMAFighter], Never>([])

subject
    .map { $0.count }       // operator
    .sink { count in        // subscriber
        print("Roster has \(count) fighters")
    }

subject.send([MMAFighter(name: "Jon Jones", fightTeam: "Jackson Wink", country: "USA", record: "28-1", age: 36)])
```

출력:

```
Roster has 1 fighters
```

- Subject = Publisher이자 새 값을 밀어넣는 곳
- Operator = `map`이 파이터 목록을 숫자로 변환
- Subscriber = `sink`가 숫자를 출력

---

### 간단한 멘탈 모델

- Publishers는 값을 방출한다.
- Operators는 값을 변환한다.
- Subscribers는 값을 소비한다.
- Subject는 값을 수동으로 보낼 수 있는 특수한 Publisher다.

---

## Combine vs Async/Await vs Escaping Closure

### 1. Escaping Closure (기존 방식)

비동기 작업이 끝났을 때 실행될 클로저를 전달하는 방식이다.

```swift
func fetchFighters(completion: @escaping ([MMAFighter]) -> Void) {
    DispatchQueue.global().async {
        let fighters = [MMAFighter(name: "Jon Jones", fightTeam: "...", country: "USA", record: "28-1", age: 36)]
        completion(fighters)
    }
}

fetchFighters { fighters in
    print("Got:", fighters)
}
```

**장점:** 단순하고 널리 쓰이며 이해하기 쉽다.

**단점:**
- 콜백이 중첩되기 쉽다 ("콜백 지옥")
- 여러 요청을 합치거나 재시도 로직을 구성하기 어렵다.
- 스트림 값을 변환하는 내장 도구가 없다.

---

### 2. Async/Await (현대 Swift)

비동기 작업을 동기 코드처럼 보이게 만드는 방식이다.

```swift
func fetchFighters() async throws -> [MMAFighter] {
    [MMAFighter(name: "Jon Jones", fightTeam: "...", country: "USA", record: "28-1", age: 36)]
}

Task {
    do {
        let fighters = try await fetchFighters()
        print("Got:", fighters)
    } catch {
        print("Error:", error)
    }
}
```

**장점:**
- 훨씬 깔끔하고 콜백 중첩이 없다.
- `try/throw`로 에러 처리가 편리하다.
- 일회성 비동기 작업(네트워크 호출, DB 쿼리)에 최적이다.

**단점:**
- 시간이 지남에 따라 값이 계속 오는 스트림(실시간 검색, 알림, 지속적인 업데이트)에는 적합하지 않다.
- 그런 경우엔 `AsyncStream` 등의 도구가 별도로 필요하다.

---

### 3. Combine

비동기 값을 Publisher로 표현하며, 시간이 지남에 따라 여러 값을 방출할 수 있다. Operator로 변환/필터링하고, Subscriber로 소비한다.

```swift
service.fetchFighters(search: "jon")
    .map { $0.count }
    .sink { count in
        print("Found \(count) fighters")
    }
    .store(in: &cancellables)
```

**장점:**
- 데이터 스트림(텍스트 변경, 타이머, 로스터 업데이트)에 최적이다.
- Combine, Merge, Debounce, Retry 등 조합이 가능하다.
- SwiftUI의 `@Published`와 통합하여 반응형 UI를 만들 수 있다.

**단점:**
- 학습 곡선이 있다 (Publisher, Subscriber, Subject).
- 단순 일회성 비동기 작업에는 Async/Await보다 무겁다.

---

### 핵심 차이

- **Escaping Closure** = 저수준, 일회성 콜백. 단순하지만 제한적.
- **Async/Await** = 일회성 비동기 작업에 최적. 동기 코드처럼 읽힌다.
- **Combine** = 시간이 지남에 따라 값이 계속 변하는 스트림에 최적. 선언적으로 반응한다.

> **UFC 앱 맥락에서**
> - Escaping Closure: "파이터 한 번 가져오고 콜백 줘"
> - Async/Await: "파이터 한 번 가져와, 깔끔하게"
> - Combine: "JSON이 바뀌거나 검색어가 바뀌거나 로스터가 업데이트될 때마다 UI를 자동으로 반영해줘"

---

## Publisher의 종류

Publisher는 값을 시간이 지남에 따라 생산할 수 있는 모든 것이다.

방출할 값의 타입(Output)과 에러 타입(Failure)을 정의한다.
Subscriber가 붙어서 값을 받는다.

크게 두 가지로 나뉜다.

- **Built-in Publisher** → Apple이 제공
- **Subject Publisher** → 직접 생성하고 제어 (PassthroughSubject, CurrentValueSubject)

---

### 1. Built-in Publisher

**Sequence Publisher**

기존 컬렉션을 Publisher로 변환한다.

```swift
[1, 2, 3].publisher   // 1, 2, 3 순서대로 방출
Just(value)           // 값 하나 방출 후 완료
Empty()               // 아무것도 방출하지 않고 완료
Fail()                // 즉시 에러 발생
```

**Timer Publisher**

```swift
Timer.publish(every: 1, on: .main, in: .common)
// 설정한 간격마다 값을 방출
```

**Notification Publisher**

```swift
NotificationCenter.Publisher
// 알림이 발생할 때 값을 방출
```

**URLSession Publisher**

```swift
URLSession.shared.dataTaskPublisher(for: url)
// 네트워크 데이터와 응답을 방출
```

**Property Publisher**

```swift
// SwiftUI ObservableObject 안에서
@Published var property: Type

$property  // Publisher로 사용 가능, 프로퍼티 변경을 구독
```

**Operator로 생성된 Publisher**

`map`, `filter`, `combineLatest` 등 많은 Operator는 새 Publisher를 반환한다.

```swift
let numbers = [1, 2, 3].publisher
let squared = numbers.map { $0 * $0 }  // 새 Publisher
```

---

### 2. Subject Publisher

`.send()`로 값을 수동으로 밀어넣을 수 있는 특수 Publisher다.

**PassthroughSubject\<Output, Failure\>**
- 새 값만 방출한다.
- 나중에 구독한 Subscriber에게 이전 값을 전달하지 않는다.
- 이벤트에 사용한다.

**CurrentValueSubject\<Output, Failure\>**
- 항상 최신 값을 저장한다.
- 새 구독자에게 즉시 현재 값을 전달한다.
- 상태에 사용한다.

---

### 3. Custom Publisher

`Publisher` 프로토콜을 직접 구현하여 만들 수 있다. 다만 고급 주제이며 직접 프레임워크를 만드는 게 아니라면 보통 필요 없다.

---

### 한눈에 정리

- 시퀀스 Publisher (`Just`, `.publisher`, `Empty`, `Fail`)
- 시스템 Publisher (`Timer`, `NotificationCenter`, `URLSession`)
- 프로퍼티 Publisher (`@Published`)
- Subject (`PassthroughSubject`, `CurrentValueSubject`)
- Operator로 생성된 Publisher (모든 Operator는 새 Publisher를 생성)

---

## Subject: PassthroughSubject vs CurrentValueSubject

### 쉬운 설명

**PassthroughSubject - 메가폰**

* 누군가 듣고 있을 때 소리치면 들린다.
* 아무도 없을 때 소리치면 메시지는 사라진다.
* 나중에 참여한 사람은 이전에 한 말을 못 듣는다. 앞으로 하는 말만 들린다.

MMA 로스터로 비유하면:
- 로스터를 업데이트하면 구독자는 그 업데이트만 본다.
- 나중에 구독한 사람은 이전 로스터를 못 본다. 이후 업데이트만 본다.

**CurrentValueSubject - 화이트보드**

* 항상 현재 상태가 적혀있다.
* 누가 들어오든 즉시 현재 내용을 볼 수 있다.
* 업데이트하면 모두가 새 내용을 보고, 화이트보드는 그 값을 유지한다.

MMA 로스터로 비유하면:
- 구독자는 즉시 현재 전체 로스터를 받는다.
- 파이터를 추가하면 모두가 업데이트된 전체 로스터를 본다.
- 나중에 구독한 사람도 최신 로스터를 즉시 받는다.

---

### 예시 코드

```swift
import Combine

var cancellables = Set<AnyCancellable>()

// PassthroughSubject: 업데이트만 전달, 이전 값 없음
let passthroughRoster = PassthroughSubject<[String], Never>()

// CurrentValueSubject: 항상 최신 값 보유
let currentRoster = CurrentValueSubject<[String], Never>(["Jon Jones"])

// --- PassthroughSubject 예시 ---
print("=== PassthroughSubject Example ===")
passthroughRoster
    .sink { print("Subscriber1 sees:", $0) }
    .store(in: &cancellables)

passthroughRoster.send(["Jon Jones", "Islam Makhachev"])

// 첫 번째 업데이트 이후 새 구독자 참여
passthroughRoster
    .sink { print("Subscriber2 sees:", $0) }
    .store(in: &cancellables)

passthroughRoster.send(["Jon Jones", "Islam Makhachev", "Israel Adesanya"])

// --- CurrentValueSubject 예시 ---
print("\n=== CurrentValueSubject Example ===")
currentRoster
    .sink { print("Subscriber1 sees:", $0) }
    .store(in: &cancellables)

currentRoster.send(["Jon Jones", "Islam Makhachev"])

// 업데이트 이후 새 구독자 참여
currentRoster
    .sink { print("Subscriber2 sees:", $0) }
    .store(in: &cancellables)

currentRoster.send(["Jon Jones", "Islam Makhachev", "Israel Adesanya"])
```

출력:

```
=== PassthroughSubject Example ===
Subscriber1 sees: ["Jon Jones", "Islam Makhachev"]
Subscriber1 sees: ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]
Subscriber2 sees: ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]

=== CurrentValueSubject Example ===
Subscriber1 sees: ["Jon Jones"]
Subscriber1 sees: ["Jon Jones", "Islam Makhachev"]
Subscriber2 sees: ["Jon Jones", "Islam Makhachev"]
Subscriber1 sees: ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]
Subscriber2 sees: ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]
```

---

### 핵심 정리

- **PassthroughSubject**: 구독 중일 때만 값을 받는다. 이전 값은 없다.
- **CurrentValueSubject**: 구독 즉시 현재 값을 받고, 이후 모든 업데이트를 계속 받는다.

---

## Stream이란?

Combine에서 Stream은 **시간이 지남에 따라 도착하는 값의 시퀀스**다.

Swift에서 익숙한 정적 시퀀스인 Array는 이렇다.

```swift
let numbers = [1, 2, 3]
```

반복할 수 있지만 모든 값이 이미 존재한다.

Stream은 모든 값이 아직 없는 Array와 같다. 값들이 시간이 지남에 따라 "**흘러 들어온다**".

---

### Stream의 특성

- **순서 보장**: 값은 생산된 순서대로 도착한다.
- **비동기성**: 다음 값이 언제 올지 모른다.
- **잠재적으로 무한**: 스트림은 종료되거나(complete), 에러가 나거나(fail), 영원히 계속될 수 있다.

---

### Combine에서의 예시

```swift
let subject = PassthroughSubject<String, Never>()

subject
    .sink { print("Received:", $0) }

subject.send("Jon Jones")
subject.send("Islam Makhachev")
subject.send("Israel Adesanya")
```

출력:

```
Received: Jon Jones
Received: Islam Makhachev
Received: Israel Adesanya
```

- Stream은 시간이 지남에 따라 방출되는 파이터 이름의 흐름이다.
- `.send()`를 호출할 때마다 Stream에 값이 추가된다.
- Subscriber는 값이 흘러올 때마다 Stream을 듣는다.

---

### Stream vs Array 비교

- Array = 모든 값이 처음부터 존재한다.
- Stream = 값이 시간이 지남에 따라 나타나고, 도착할 때마다 반응한다.

---

### 비동기 작업에서 Stream이 중요한 이유

- **네트워크 호출 한 번 (파이터 한 번 가져오기) = 단일 값.** Stream이 아님. 일회성 비동기 결과 (Async/Await이 더 적합).
- **실시간 타이핑 검색창 = Stream.** 키 입력마다 새 값이 생성되고 순서대로 반응해야 한다.
- **로스터 업데이트 피드 = Stream.** 시간이 지남에 따라 파이터가 추가/삭제/변경될 수 있다.

Combine에서:
- Publisher가 Stream을 생산한다.
- Subscriber가 Stream을 소비한다.
- Operator가 값이 흐르면서 Stream을 변환한다.

---

## `.sink`와 `.send`

### .sink란?

Publisher에서 데이터를 듣는 방법이다. (🎧 헤드폰 비유)

* 데이터를 직접 제어하지 않는다.
* 새 값이 도착할 때만 반응한다.

헤드폰을 꽂는 것과 같다. 음악이 나오면 들리지만, 직접 음악을 틀지는 않는다.

```swift
let numbers = [1, 2, 3].publisher

numbers.sink { value in
    print("Got:", value)
}
```

출력:

```
Got: 1
Got: 2
Got: 3
```

---

### .send란?

Subject에 새 데이터를 밀어넣는 방법이다. (🎛️ 라디오 DJ 비유)

* 값을 직접 공급한다.
* 구독 중인 모든 Subscriber가 보낸 값을 받는다.

라디오 방송국의 DJ와 같다. 음악을 틀면 듣고 있는 모두가 듣는다.

```swift
import Combine

let subject = PassthroughSubject<String, Never>()

subject.sink { value in
    print("Got:", value)
}

subject.send("Jon Jones")
subject.send("Islam Makhachev")
```

출력:

```
Got: Jon Jones
Got: Islam Makhachev
```

---

### 한 줄 요약

- `.sink` = "흘러오는 것을 듣겠다"
- `.send` = "무언가를 밀어넣겠다" (Subject에서만 동작)

---

### UFC 앱에서의 활용

- `.sink`는 서비스가 파이터를 발행할 때 ViewModel이나 SwiftUI View에서 소비할 때 사용한다.
- `.send`는 Subject를 사용하여 새 파이터를 로스터에 추가하는 등 변경을 수동으로 발행할 때 사용한다.

---

## Subscriber란?

Combine에서 Subscriber는 Publisher를 구독하고, Publisher가 새 값을 보낼 때마다 반응하는 것이다.

- Publisher = "나는 시간이 지남에 따라 값을 생산할 수 있다"
- Subscriber = "나는 그 값을 받고 싶다"

Subscriber 없이는 Publisher가 아무것도 하지 않는다. **Subscriber가 있어야 데이터 스트림에 생명력을 불어넣는다.**

---

### 예시: UFC 파이터 (간단)

파이터 이름 목록을 관리하는 ViewModel:

```swift
import Combine

class ViewModel {
    @Published var names: [String] = []
}
```

`@Published`는 자동으로 `names`를 Publisher로 만든다.
`names`가 변경될 때마다 새 값을 방출한다.

이제 Publisher를 구독한다:

```swift
let vm = ViewModel()
var cancellables = Set<AnyCancellable>()

vm.$names   // Publisher
    .sink { updatedNames in
        print("Subscriber received names:", updatedNames)
    }
    .store(in: &cancellables)

// names 배열 변경
vm.names = ["Jon Jones", "Islam Makhachev"]
vm.names = ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]
```

출력:

```
Subscriber received names: []
Subscriber received names: ["Jon Jones", "Islam Makhachev"]
Subscriber received names: ["Jon Jones", "Islam Makhachev", "Israel Adesanya"]
```

---

### 무슨 일이 일어나는가

- Subscriber가 붙으면(`.sink`), 현재 `names` 값(빈 배열)을 즉시 받는다.
- `vm.names`가 업데이트되면 Publisher가 자동으로 새 배열을 보낸다.
- Subscriber는 매번 반응하여 업데이트된 목록을 출력한다.

---

### 핵심 정리

- `.sink`가 Subscriber를 생성한다.
- Subscriber는 Publisher가 값을 방출할 때마다 반응하는 코드다.
- `@Published`를 사용하면 모든 프로퍼티 변경이 자동으로 Subscriber에게 새 데이터를 방출한다.

---

## @Published를 Subject 대신 앱에서 사용하는 이유

### `@Published`는 실제로 무엇을 하는가?

아래와 같이 선언하면:

```swift
@Published var fighters: [MMAFighter] = []
```

두 가지를 자동으로 얻는다.

1. 일반 프로퍼티처럼 읽고 쓸 수 있는 저장 프로퍼티 (`fighters`)

```swift
fighters = [MMAFighter(name: "Jon Jones", ...)]
```

2. 프로퍼티가 변경될 때마다 새 값을 방출하는 Publisher (`$fighters`)

```swift
vm.$fighters.sink { updated in
    print("Fighters changed:", updated)
}
```

즉 `@Published`는 이미 **상태 저장소 + Publisher**다.

---

### Subject와 비교

`@Published`가 없다면, `CurrentValueSubject`로 같은 동작을 수동으로 구현할 수 있다.

```swift
let fightersSubject = CurrentValueSubject<[MMAFighter], Never>([])

// 상태 업데이트
fightersSubject.send([MMAFighter(name: "Jon Jones", ...)])

// 상태 관찰
fightersSubject
    .sink { print("Fighters changed:", $0) }
```

동작하긴 하지만, 직접 관리해야 할 것들이 생긴다.

- 상태가 변경될 때마다 `.send`를 직접 호출해야 한다.
- Subject를 어딘가에 저장해야 한다.
- 원시 프로퍼티와 Subject 둘 다 노출된다.

---

### `@Published`가 그것을 대체하는 이유

`@Published`를 사용하면:

- 프로퍼티(`fighters`)가 현재 상태를 보유한다.
- Wrapper가 프로퍼티가 변경될 때마다 자동으로 업데이트를 보낸다.
- SwiftUI View는 `@StateObject` 또는 `@ObservedObject`로 직접 관찰할 수 있다.

따라서 ViewModel에서:

```swift
@Published var fighters: [MMAFighter] = []
```

이것은 사실상 아래의 축약형이다.

```swift
var fightersSubject = CurrentValueSubject<[MMAFighter], Never>([])

var fighters: [MMAFighter] {
    get { fightersSubject.value }
    set { fightersSubject.send(newValue) }
}
```

---

### 핵심 아이디어

"상태를 저장하고 변경될 때 UI에 알리는 것"이 목적이라면, `@Published`가 이미 내부적으로 Subject다.

`@Published`와 별도의 Subject를 함께 사용하면 작업이 중복된다.
