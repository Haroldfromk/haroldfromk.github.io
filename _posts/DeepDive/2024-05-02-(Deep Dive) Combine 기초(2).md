---
title: (Deep Dive) Combine 기초(2)
writer: Harold
date: 2024-05-02 13:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

코드를 통해 이해해보기. 2탄

## Scheduler

```swift
let arrPublisher = [1,2,3].publisher

let queue = DispatchQueue(label: "custom")

let subscription = arrPublisher
    .map { value -> Int in // operator
        print("transform: \(value), thread: \(Thread.current)")
        return value
    }
    .sink { value in
    print("Receive value: \(value), thread: \(Thread.current)")
}

// transform: 1, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
// transform: 2, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
// transform: 3, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
// Receive value: 1, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
// Receive value: 2, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
// Receive value: 3, thread: <_NSMainThread: 0x600001704000>{number = 1, name = main}
```

operator가 Heavy 한 task를 수행하지 않는 경우는 위와 같이 main에서 처리할 수도 있다.

```swift
let subscription = arrPublisher
    .subscribe(on: queue) // main thread가 아닌 우리가 설정한 custom thread에서의 작업을 설정.
    .map { value -> Int in // operator
        print("transform: \(value), thread: \(Thread.current)")
        return value
    }
    .receive(on: DispatchQueue.main) // 작업이 완료되고 받는 작업은 main thread에서
    .sink { value in
    print("Receive value: \(value), thread: \(Thread.current)")
}

// transform: 1, thread: <NSThread: 0x600001715580>{number = 6, name = (null)}
// transform: 2, thread: <NSThread: 0x600001715580>{number = 6, name = (null)}
// transform: 3, thread: <NSThread: 0x600001715580>{number = 6, name = (null)}
// Receive value: 1, thread: <_NSMainThread: 0x600001710000>{number = 1, name = main}
// Receive value: 2, thread: <_NSMainThread: 0x600001710000>{number = 1, name = main}
// Receive value: 3, thread: <_NSMainThread: 0x600001710000>{number = 1, name = main}
```

1번만 main thread 이다.

이렇게 Scheduler를 통해 Heavy한작업은 background로 돌리면서 thread 관리가 가능하다.

## Operator

```swift
// Transform - Map
let numPublisher = PassthroughSubject<Int, Never>()
let subscription1 = numPublisher
    .map { $0 * 2}
    .sink { value in
        print("Transformed Value: \(value)")
    }

numPublisher.send(10)
numPublisher.send(20)
numPublisher.send(30)

// Transformed Value: 20
// Transformed Value: 40
// Transformed Value: 60
```

```swift
// Filter
let stringPublisher = PassthroughSubject<String, Never>()
let subscription2 = stringPublisher
    .filter { $0.contains("a") }
    .sink { value in
        print("Filtered Value: \(value)")
    }

stringPublisher.send("abc")
stringPublisher.send("Jack")
stringPublisher.send("Joon")
stringPublisher.send("Jenny")
stringPublisher.send("Jason")

// Filtered Value: abc
// Filtered Value: Jack
// Filtered Value: Jason
```

## CombineLatest

2개의 publisher를 합쳐서 가장 최근의 두 publisher값을 리턴

```swift
// Basic CombineLatest
let strPublisher = PassthroughSubject<String, Never>()
let numPublisher = PassthroughSubject<Int, Never>()

strPublisher.combineLatest(numPublisher).sink { (str, num) in
    print("Receive: \(str), \(num)")
}

// 위와 같은 표현
Publishers.CombineLatest(strPublisher, numPublisher).sink { (str, num) in
    print("Receive: \(str), \(num)")
}

strPublisher.send("a")
strPublisher.send("b")
strPublisher.send("c")

// 여기까지만하면 아무런 값이 리턴이 되지 않음
// numPublisher에는 아무런 값이 들어오지 않았기 때문이다.
numPublisher.send(1) // added
numPublisher.send(2) // added
numPublisher.send(3) // added

// Receive: c, 1
// Receive: c, 2
// Receive: c, 3
```

이렇게 c는 고정이고 1,2,3인 이유는

a,b,c 중 c가 제일 최근이고, 그다음에 1들어오면

c,1이 제일 최신, 이후 2가 들어오면
c,2가 최신이 되기때문.

두개를 섞어서 다시 해보면

```swift
strPublisher.send("a")
numPublisher.send(1)
strPublisher.send("b")
numPublisher.send(2)
numPublisher.send(3)
strPublisher.send("c")

// Receive: a, 1
// Receive: b, 1
// Receive: b, 2
// Receive: b, 3
// Receive: c, 3
```

## Advanced CombineLast

```swift
// Advanced CombineLatest

let usernamePublisher = PassthroughSubject<String, Never>()
let passwordPublisher = PassthroughSubject<String, Never>()

let validatedCredentialsSubscription = usernamePublisher.combineLatest(passwordPublisher)
    .map { (username, password) -> Bool in
        return !username.isEmpty && !password.isEmpty && password.count > 12
    }.sink { valid in
        print("Credential valid? : \(valid)")
    }

usernamePublisher.send("Harold")
passwordPublisher.send("weakpw")
passwordPublisher.send("verystrongpassword")

// Credential valid? : false
// Credential valid? : true
```

## Merge

2개의 Publisher의 output type이 같을때만 가능

```swift
// Merge

let publisher1 = [1, 2, 3, 4, 5].publisher
let publisher2 = [300, 400, 500].publisher

let mergePublisherSubscription = publisher1.merge(with: publisher2)
    .sink { value in
        print("Merge: subscription received value: \(value)")
    }

// 위와 같은 의미.
Publishers.Merge(publisher1, publisher2).sink { value in
    print("Merge: subscription received value: \(value)")
}

// Merge: subscription received value: 1
// Merge: subscription received value: 2
// Merge: subscription received value: 3
// Merge: subscription received value: 4
// Merge: subscription received value: 5
// Merge: subscription received value: 300
// Merge: subscription received value: 400
// Merge: subscription received value: 500    
```

## RemoveDuplicates

```swift
var subscriptions = Set<AnyCancellable>()

// removeDuplicates
let words = "hey hey there! Mr Mr?"
    .components(separatedBy: " ") // ["hey", "hey", "there!", "Mr", "Mr?"]

words
    .removeDuplicates() // 중복값 제거 operator
    .sink { value in
        print(value)
    }.store(in: &subscriptions) // 현재 이 subscription을 위에 선언한 subscriptions에 저장.

// hey
// there!
// Mr
// Mr?    
```

## compactMap

nil값은 제거

```swift
let strings = ["a", "1.24", "3", "def", "45", "0.23"].publisher

strings.compactMap { Float($0) }
    .sink { value in
        print(value)
    }.store(in: &subscriptions)

// 1.24
// 3.0
// 45.0
// 0.23    
```

## ignoreOutput

```swift
let numbers = (1...10_000).publisher

numbers
    .ignoreOutput()
    .sink (receiveCompletion: { print("Completed with: \($0)") },
            receiveValue: { print($0) })
    .store(in: &subscriptions)
// Completed with: finished
```

첨부터 ignore 했기에 아무런 값도 넘어가지 않음.

## prefix

```swift
let tens = (1...10).publisher

tens
    .prefix(2) // 앞에 n개만 받겠다.
    .sink(receiveCompletion: { print ("Completed with: \($0)") },
          receiveValue: { print($0) })
    .store(in: &subscriptions)

// 1
// 2
// Completed with: finished
```

2개만 받았으므로 끝.
