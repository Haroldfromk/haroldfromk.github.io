---
title: Combine Remind (1)
writer: Harold
date: 2024-12-18 11:16
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

Combine을 UIKit에서만 사용해봤었는데, SwiftUI에서도 적용을 해보려한다.

그전에 Combine 사용한지 오래 되었기에, Udemy 강의를 가볍게 정리를 하면서 Remind를 하려고한다.

이전에 서술한 내용이 있는 부분은 패스를 할 예정.

[이전글](https://haroldfromk.github.io/posts/(Deep-Dive)-Combine-%EA%B8%B0%EC%B4%88/){:target="_blank"}은 여기에.


## Reactive Programming?

Reactive Programming는 비동기 데이터 및 이벤트를 선언적이고 데이터 중심적으로 관리하는 프로그래밍 패러다임이다.

## Reactive Programming 장점

1. Code Readability: 선언적 스타일로 작성해 코드 가독성 향상.
2. Immutable State: 상태 변경 없이 항상 새로운 상태를 생성.
3. Asynchronous Scenarios: 복잡한 비동기 작업을 간단히 처리하는 다양한 연산자 제공.
4. Real-Time Applications: 실시간 및 이벤트 중심 애플리케이션 개발에 적합.

## Reactive(반응형) vs Imperative(명령형)

### **Immutable vs Mutable**

| **반응형 프로그래밍**             | **명령형 프로그래밍**                         |
|----------------------------------|--------------------------------------------|
| 불변성(immutability)을 강조       | 가변 변수(mutable variables)를 자주 사용       |
| 데이터는 변경 불가하며, 변경 시 새로운 데이터 생성 | 데이터는 수정 가능하며, race condition이나 예기치 못한 변경이 발생할 수 있음 |
| Side Effect에 대한 risk를 줄이고 동시 접근을 단순화 |                                              |

---

### **Control Flow: 선언형 vs 명시적**

| **반응형 프로그래밍**                     | **명령형 프로그래밍**                      |
|------------------------------------------|------------------------------------------|
| 선언형 접근 방식                          | 명시적 단계별 접근 방식                   |
|"어떻게 할지(How)" 보다 "무엇을 할지(What)"에 집중                | "특정 작업을 어떻게 달성할지(How)"에 집중한다      |
| 데이터 스트림을 변환하는 연산자 사용      | 반복문과 조건문을 자주 포함한다|

---

### **동기 vs 비동기**

| **반응형 프로그래밍**                               | **명령형 프로그래밍**                        |
|----------------------------------------------------|-------------------------------------------|
| 비동기 작업을 처리하는 데 적합                     | 주로 동기적으로 작동                         |
| 비동기 이벤트와 데이터 스트림을 효율적으로 관리     | 차단 작업(blocking operations)으로 인해 높은 동시성이 필요한 애플리케이션에서 병목 현상을 유발할 수 있음 |
| 비차단(non-blocking) 및 이벤트 기반(event-driven) 처리 |                                             |

---

## Combine

Combine은 Swift에서 비동기적이고 이벤트 기반 코드를 처리하기 위한 Framework이다.

[WWDC2019](https://developer.apple.com/kr/videos/play/wwdc2019/722/){:target="_blank"}에서 소개되었다.

### Combine의 장점
1. Improved Code Readability
2. Enhanced Error Handling
3. Asynchronous Operation Support
4. Intergration with Swiftui for reactive UI

## Playground를 통한 예시

[이전글](https://haroldfromk.github.io/posts/(Deep-Dive)-Combine-%EA%B8%B0%EC%B4%88(1)/){:target="_blank"} 에서도 코드 예시가 있으니 참고할 것.

여기선 추가로 알면 좋을 부분에 대해 서술을 한다.

```swift
let timerPublisher = Timer.publish(every: 1, on: .main, in: .common)
let cancellable = timerPublisher.autoconnect().sink { timestamp in
    print("Timestamp: \(timestamp)")
}
```

이렇게 했는데 왜 출력이 되지 않을까? 강의를 멈추고 생각을 해보았다.

그러다가 플레이그라운드를 다시 만들어서 해보았다.

아이러니 하게도 combine1.playground 로 작성한것과 playground가 프로젝트 형식으로 swift 파일로 만들어진 것과 차이가 난다.

playground 파일 자체에서는 출력이되는데, 프로젝트처럼 만들어진 playground는 안되는걸 확인.

## SwiftUI에서의 간단한 예시

```swift
private var cancellables: Set<AnyCancellable> = []
    
    init() {
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { _ in
                let currentOrientation = UIDevice.current.orientation
                print(currentOrientation)
            }.store(in: &cancellables)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
```

앱을 작동하고 화면을 전환할때마다 (portrait or landscape) `currentOrientation`이 출력된다.

## tryMap을 사용한 간단한 에러 핸들링

### catch

```swift
enum NumberError: Error {
    case operationFailed
}


let numbersPublisher = [1, 2, 3, 4, 5].publisher

let doubledPublisher = numbersPublisher
    .tryMap { number in
        if number == 4 {
            throw NumberError.operationFailed
        }
        
        return number * 2
    }
    .catch { error in
        if let numberError = error as? NumberError {
            print("Error occurred: \(numberError)")
        }
        
        return Just(0)
}

let cancellable = doubledPublisher.sink { completion in
    switch completion {
        case .finished:
            print("finished")
        case .failure(let error):
            print(error)
    }
} receiveValue: { value in
    print(value)
}

// 2
// 4
// 6
// Error occurred: operationFailed
// 0
// finished
```

### mapError

```swift
let doubledPublisher = numbersPublisher
    .tryMap { number in
        if number == 4 {
            throw NumberError.operationFailed
        }
        
        return number * 2
        
    }.mapError { error in
        return NumberError.operationFailed
    }

let cancellable = doubledPublisher.sink { completion in
    switch completion {
        case .finished:
            print("finished")
        case .failure(let error):
            print(error)
    }
} receiveValue: { value in
    print(value)
}

// 2
// 4
// 6
// operationFailed
```

## Operator

### Zip

```swift
let publisher1 = [1,2,3,4].publisher
let publisher2 = ["A", "B", "C", "D", "E"].publisher
let publisher3 = ["John", "Doe", "Mary", "Steven"].publisher

let zippedPublisher = Publishers.Zip3(publisher1, publisher2, publisher3)

let cancellable = zippedPublisher.sink { value in
    print("\(value.0), \(value.1), \(value.2)")

// 1, A, John
// 2, B, Doe
// 3, C, Mary
// 4, D, Steven    
```

![CleanShot 2024-12-18 at 13 42 25](https://github.com/user-attachments/assets/56967797-6c4e-4bad-9e5e-6b0185b7eb61)

Zip은 4까지 있다. 즉 4개의 배열까지 처리가 가능.

### switchToLatest

```swift
let outerPublisher = PassthroughSubject<AnyPublisher<Int, Never>, Never>()
let innerPublisher1 = CurrentValueSubject<Int, Never>(1)
let innerPublisher2 = CurrentValueSubject<Int, Never>(2)

let cancellable = outerPublisher
    .switchToLatest()
    .sink { value in
        print(value)
}

outerPublisher.send(AnyPublisher(innerPublisher1))
innerPublisher1.send(10)

outerPublisher.send(AnyPublisher(innerPublisher2))
innerPublisher2.send(20)
innerPublisher1.send(100)

// 1
// 10
// 2
// 20
```

innerPublisher1.send(100) 을 마지막에 했음에도 안되는 이유.

innerPublisher1의 구독관계가 끊겼기 때문.

구독관계는 일반적인경우 

```swift
let cancellable = outerPublisher
    .print() // new
    .switchToLatest()
    .sink { value in
        print(value)
}

// receive subscription: (PassthroughSubject)
// request unlimited
// receive value: (AnyPublisher)
// 1
// 10
// receive value: (AnyPublisher)
// 2
// 20
```

여기서 하면 나오지만 이번경우에는 위와같이 나오기에 정확하게 파악이 어렵다.

```swift
outerPublisher.send(AnyPublisher(innerPublisher1.print())) // modified
innerPublisher1.send(10)

outerPublisher.send(AnyPublisher(innerPublisher2.print())) // modified
innerPublisher2.send(20)
innerPublisher1.send(100)

/*
receive subscription: (CurrentValueSubject)
request unlimited
receive value: (1)
1
receive value: (10)
10
receive cancel
receive subscription: (CurrentValueSubject)
request unlimited
receive value: (2)
2
receive value: (20)
20
*/
```

이젠 구독관계를 자세히 알 수 있다. 위에서 언급을 했지만 다시 말하면 switchToLatest는 새로 전달된 innerPublisher의 구독으로 전환되기 때문에, 이전 innerPublisher의 구독은 자동으로 취소된다.
따라서 innerPublisher1.send(100)은 더 이상 전달되지 않는다.

재구독을 할 수 있는 방법이 존재는 한다.
>View에 어떤 publisher가 있다면, `store`를 통해 cancellables에 담고, view가 deinit을 할때 cancellables를 리셋하고 View가 다시 렌더링 될때 구독을 새로 하면 되기는 한다.
> ex: cancellables.removeall()

## retry

```swift
let publisher = PassthroughSubject<Int, Error>()

let retriedPublisher = publisher
    .tryMap { value in
        if value == 3 {
            throw SampleError.operationFailed
        }
        return value
    }.retry(2)

let cancellable = retriedPublisher.sink { completion in
    switch completion {
        case .finished:
            print("Pubisher has completed.")
        case .failure(let error):
            print("Publisher failed with error \(error)")
    }
} receiveValue: { value in
    print(value)
}

publisher.send(1)
publisher.send(2)
publisher.send(3) // failed
publisher.send(4)
publisher.send(5)
publisher.send(3) // failed
publisher.send(6)
publisher.send(7)
publisher.send(3) // failed
publisher.send(8)

/*
1
2
4
5
6
7
Publisher failed with error operationFailed
*/
```

retry는 내가 지정한 횟수까지는 error가 발생해도 넘어간다. 즉 기회를 준다고 생각하면된다.

원래는 에러가 발생하면 그시점으로부터 구독이 바로 끊기게 되는데, retry는 구독을 유지하고 재시도한다.
