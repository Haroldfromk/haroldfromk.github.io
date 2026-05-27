---
title: Combine Operators
writer: Harold
date: 2026-05-18 08:06
categories: [Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

Combine에서 자주 사용하는 오퍼레이터를 카테고리별로 정리한다.

---

## Transforming
값의 형태를 바꾸거나 새로운 Publisher로 전환한다.

### `map`

각 값을 다른 타입이나 형태로 변환한다.

```swift
[1, 2, 3].publisher
    .map { $0 * 10 }
    .sink { print($0) }

// 10
// 20
// 30
```

---

### `compactMap`

`map`과 동일하지만 변환 결과가 `nil`이면 자동으로 제거한다.

```swift
["1", "two", "3", "four", "5"].publisher
    .compactMap { Int($0) }
    .sink { print($0) }

// 1
// 3
// 5
```

---

### `flatMap`

각 값을 새로운 Publisher로 변환하고, 그 Publisher의 값을 펼쳐서 단일 스트림으로 만든다.

`map`을 쓰면 `Publisher<Publisher<[T]>>` 형태로 중첩이 생긴다. `flatMap`은 이 중첩을 펼쳐서 `Publisher<[T]>`로 만든다.

```swift
// map을 쓰면
$searchText
    .map { query in service.search(query: query) }
    .sink { value in
        // value의 타입: AnyPublisher<[Result], Error>
        // Publisher가 그대로 넘어옴 → sink 안에서 한 번 더 구독 필요
    }

// flatMap을 쓰면
$searchText
    .flatMap { query in service.search(query: query) }
    .sink { value in
        // value의 타입: [Result]
        // 값이 바로 넘어옴
    }
```

---

### `switchToLatest`

각 값을 Publisher로 변환한 뒤, 새 Publisher가 오면 이전 것을 즉시 취소하고 최신 것으로 교체한다.

```swift
let subject = PassthroughSubject<String, Never>()

subject
    .map { query in service.search(query: query) }
    .switchToLatest()
    .sink { print($0) }

subject.send("a")   // "a" 요청 시작
subject.send("ab")  // "a" 요청 취소 → "ab" 요청 시작
subject.send("abc") // "ab" 요청 취소 → "abc" 요청 시작

// 최종적으로 "abc" 결과만 도착
```

---

### `scan`

이전 값과 새 값을 합쳐 누적 계산한다.

```swift
[1, 2, 3, 4, 5].publisher
    .scan(0) { acc, value in acc + value }
    .sink { print($0) }

// 1  (0 + 1)
// 3  (1 + 2)
// 6  (3 + 3)
// 10 (6 + 4)
// 15 (10 + 5)
```

---

### `collect`

여러 값을 배열로 묶어서 한 번에 방출한다.

```swift
// 개수로 묶기
[1, 2, 3, 4, 5].publisher
    .collect(2)
    .sink { print($0) }

// [1, 2]
// [3, 4]
// [5]

// 시간으로 묶기
let subject = PassthroughSubject<Int, Never>()

subject
    .collect(.byTime(RunLoop.main, .seconds(3)))
    .sink { print($0) }

subject.send(1)
subject.send(2)
subject.send(3)
// 3초 경과
subject.send(4)
subject.send(5)
// 3초 경과

// [1, 2, 3]
// [4, 5]
```

---

### `prepend` / `append`

스트림 앞뒤에 값을 추가한다.

```swift
[3, 4, 5].publisher
    .prepend(1, 2)
    .append(6, 7)
    .sink { print($0) }

// 1, 2, 3, 4, 5, 6, 7
```

---

## Filtering
조건에 맞지 않는 값을 걸러낸다.

### `filter`

조건을 만족하는 값만 통과시킨다.

```swift
[1, 2, 3, 4, 5].publisher
    .filter { $0 % 2 == 0 }
    .sink { print($0) }

// 2
// 4
```

---

### `removeDuplicates`

이전 값과 동일한 값이 연속으로 들어오면 무시한다.

```swift
[1, 1, 2, 2, 2, 3, 1].publisher
    .removeDuplicates()
    .sink { print($0) }

// 1
// 2
// 3
// 1  ← 연속이 아니라서 통과
```

---

### `first` / `last`

첫 번째 또는 마지막 값만 받고 완료한다.

```swift
[1, 2, 3, 4, 5].publisher
    .first { $0 > 3 }
    .sink { print($0) }

// 4

[1, 2, 3, 4, 5].publisher
    .last { $0 < 4 }
    .sink { print($0) }

// 3
```

---

### `drop(while:)` / `prefix(while:)`

조건이 참인 동안 값을 버리거나(drop), 통과시킨다(prefix).

```swift
[1, 2, 3, 4, 5].publisher
    .drop(while: { $0 < 3 })
    .sink { print($0) }

// 3, 4, 5

[1, 2, 3, 4, 5].publisher
    .prefix(while: { $0 < 3 })
    .sink { print($0) }

// 1, 2
```

---

## Combining
여러 Publisher를 하나로 합친다.

### `merge`

타입이 같은 여러 Publisher를 하나의 스트림으로 합친다. 어느 쪽에서든 값이 오면 즉시 방출한다.

```swift
let pubA = PassthroughSubject<String, Never>()
let pubB = PassthroughSubject<String, Never>()

pubA.merge(with: pubB)
    .sink { print($0) }

pubA.send("A-1") // A-1
pubB.send("B-1") // B-1
pubA.send("A-2") // A-2
pubB.send("B-2") // B-2
// 어느 쪽에서 오든 도착 순서대로 방출
```

---

### `combineLatest`

여러 Publisher 중 하나라도 새 값이 오면 각 Publisher의 최신 값을 묶어서 방출한다. 모든 Publisher에서 최소 1개 이상 값이 도착해야 첫 방출이 일어난다.

```swift
let strPublisher = PassthroughSubject<String, Never>()
let numPublisher = PassthroughSubject<Int, Never>()

strPublisher
    .combineLatest(numPublisher)
    .sink { str, num in print("Receive: \(str), \(num)") }

strPublisher.send("a")
strPublisher.send("b")
strPublisher.send("c")
// 여기까지는 아무것도 출력되지 않음
// numPublisher에 값이 없어서 쌍이 안 만들어짐

numPublisher.send(1) // Receive: c, 1
numPublisher.send(2) // Receive: c, 2
numPublisher.send(3) // Receive: c, 3

// 중간에 섞이면
strPublisher.send("a")
numPublisher.send(1)   // Receive: a, 1
strPublisher.send("b") // Receive: b, 1
strPublisher.send("c") // Receive: c, 1
numPublisher.send(2)   // Receive: c, 2
numPublisher.send(3)   // Receive: c, 3
```

---

### `zip`

여러 Publisher의 값을 순서대로 쌍으로 묶어서 방출한다. 양쪽에서 각각 하나씩 도착해야 방출한다.

```swift
let strPublisher = PassthroughSubject<String, Never>()
let numPublisher = PassthroughSubject<Int, Never>()

strPublisher
    .zip(numPublisher)
    .sink { str, num in print("Receive: \(str), \(num)") }

strPublisher.send("a")
numPublisher.send(1)   // Receive: a, 1
strPublisher.send("b")
strPublisher.send("c")
// "b", "c"는 대기 중 — numPublisher 값 기다림

numPublisher.send(2)   // Receive: b, 2
numPublisher.send(3)   // Receive: c, 3
```

`combineLatest`는 최신값 조합으로 방출하고, `zip`은 순서대로 쌍을 맞춰서 방출한다.

---

## Timing
시간 기반으로 이벤트 흐름을 제어한다.

### `debounce`

마지막 이벤트가 발생하고 지정한 시간이 지난 뒤 한 번만 방출한다.

```swift
let subject = PassthroughSubject<String, Never>()

subject
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .sink { print($0) }

subject.send("h")
subject.send("ha")
subject.send("har")
subject.send("harold")
// 0.5초 안에 연속 입력 → 마지막 값만 통과

// harold
```

---

### `throttle`

지정한 시간 간격 동안 최대 한 번만 통과시킨다.

```swift
let subject = PassthroughSubject<Int, Never>()

subject
    .throttle(for: .seconds(3), scheduler: RunLoop.main, latest: false)
    .sink { print($0) }

subject.send(1) // 1 통과
subject.send(2) // 차단
subject.send(3) // 차단
// 3초 후
subject.send(4) // 4 통과
```

| | `debounce` | `throttle` |
|---|---|---|
| 동작 방식 | 이벤트 멈추고 N초 뒤 통과 | N초 간격으로 한 번씩 통과 |
| 통과 값 | 마지막 값 | 첫 번째 또는 마지막 값 |

---

### `delay`

스트림의 값을 지정한 시간만큼 지연시켜 방출한다.

```swift
[1, 2, 3].publisher
    .delay(for: .seconds(2), scheduler: RunLoop.main)
    .sink { print($0) }

// 2초 후
// 1, 2, 3
```

---

### `timeout`

지정한 시간 안에 값이 오지 않으면 에러를 방출한다.

```swift
let subject = PassthroughSubject<Int, Never>()

subject
    .timeout(.seconds(3), scheduler: RunLoop.main)
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )

// 3초 안에 값이 오지 않으면
// finished (타임아웃으로 완료 처리)
```

---

## Error Handling
에러를 처리하고 파이프라인을 유지한다. Combine 파이프라인은 에러가 발생하면 즉시 종료되기 때문에 이를 막는 오퍼레이터들이다.

### `catch`

에러 발생 시 다른 Publisher로 대체한다. `flatMap` 안쪽에 써야 외부 스트림이 살아있다.

```swift
// ❌ catch가 flatMap 바깥 → 에러 발생 시 전체 스트림 종료
$searchText
    .flatMap { query in service.search(query: query) }
    .catch { _ in Just([]) }

// ✅ catch가 flatMap 안쪽 → 내부 요청만 실패, 외부 스트림 생존
$searchText
    .flatMap { query in
        service.search(query: query)
            .catch { _ in Just([]) }
    }
```

---

### `retry`

에러 발생 시 지정한 횟수만큼 처음부터 다시 시도한다.

```swift
service.fetchData()
    .retry(2)           // 실패하면 최대 2번 재시도
    .catch { _ in Just(Data()) }
    .sink { print($0) }
    .store(in: &cancellables)
```

---

### `tryCatch`

`catch`와 비슷하지만 대체 Publisher를 만들 때 에러를 던질 수 있다.

```swift
service.fetchData()
    .tryCatch { error -> AnyPublisher<Data, Error> in
        guard isRetryable(error) else { throw error }
        return fallbackService.fetchData()
    }
    .sink { print($0) }
    .store(in: &cancellables)
```

---

### `setFailureType`

에러 타입이 `Never`인 Publisher를 특정 에러 타입으로 변환한다. 에러 타입을 맞춰야 할 때 사용한다.

```swift
Just("value")
    .setFailureType(to: URLError.self)
    .flatMap { value in
        service.fetch(value) // Error 타입이 URLError인 Publisher와 연결 가능
    }
    .sink { print($0) }
    .store(in: &cancellables)
```

---

### `replaceError`

에러 발생 시 지정한 기본값으로 대체하고 스트림을 완료한다.

```swift
service.fetchPosts()
    .replaceError(with: [])
    .sink { print($0) }
    .store(in: &cancellables)

// 에러 발생 시 빈 배열로 대체
// []
```

단, `replaceError`는 에러를 대체한 뒤 스트림을 완료 처리한다. 이후 이벤트를 계속 받아야 한다면 `flatMap` 안쪽의 `catch`를 사용해야 한다.

---

## Scheduling
값이 어떤 스레드에서 실행될지 제어한다.

### `receive(on:)`

이후 오퍼레이터와 `sink`를 지정한 스케줄러에서 실행한다. 네트워크 응답 후 UI 업데이트 전에 메인 스레드로 전환할 때 필수다.

```swift
service.fetchData()
    .receive(on: DispatchQueue.main)
    .sink { self.data = $0 }
    .store(in: &cancellables)
```

---

### `subscribe(on:)`

Publisher 자체의 실행 스레드를 지정한다. 무거운 작업을 백그라운드에서 실행할 때 사용한다.

```swift
HeavyService.shared.process()
    .subscribe(on: DispatchQueue.global())
    .receive(on: DispatchQueue.main)
    .sink { self.result = $0 }
    .store(in: &cancellables)
```

---

## Sharing
같은 Publisher를 여러 곳에서 구독할 때 중복 실행을 방지한다.

### `share`

구독자가 여러 명이어도 Publisher를 한 번만 실행한다.

```swift
let sharedRequest = service.fetchPosts().share()

// 두 곳에서 구독해도 네트워크 요청은 한 번만 나감
sharedRequest
    .sink { self.posts = $0 }
    .store(in: &cancellables)

sharedRequest
    .map { $0.count }
    .sink { self.count = $0 }
    .store(in: &cancellables)
```

---

## Subscribing
파이프라인의 끝에서 값을 소비한다. 엄밀히 말해 Operator가 아니라 Subscriber지만, 파이프라인을 완성하는 필수 블록이다.

### `sink`

값과 완료 이벤트를 클로저로 받는다.

```swift
service.fetchPosts()
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion { print(error) }
        },
        receiveValue: { posts in self.posts = posts }
    )
    .store(in: &cancellables)
```

---

### `assign(to:on:)`

값을 프로퍼티에 바로 바인딩한다. `sink`보다 간결하다.

```swift
service.fetchPosts()
    .receive(on: DispatchQueue.main)
    .assign(to: \.posts, on: self)
    .store(in: &cancellables)
```

---

## Debugging
파이프라인의 동작을 확인할 때 사용한다. 개발 중에만 쓰고 배포 시 제거한다.

### `print`

파이프라인의 모든 이벤트(구독, 값, 완료)를 콘솔에 출력한다.

```swift
$searchText
    .print("searchText")
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .sink { print($0) }
    .store(in: &cancellables)

// receive subscription: (searchText)
// request unlimited
// receive value: (harold)
```

---

### `handleEvents`

파이프라인의 값 흐름에는 영향을 주지 않으면서, 특정 시점에 추가 작업을 끼워 넣을 때 사용한다. 로딩 상태 변경, 로그 출력, 분석 이벤트 전송 등에 쓴다.

```swift
service.fetchPosts()
    .handleEvents(
        receiveSubscription: { _ in self.isLoading = true },
        receiveCompletion: { _ in self.isLoading = false },
        receiveCancel: { self.isLoading = false }
    )
    .sink { self.posts = $0 }
    .store(in: &cancellables)
```
