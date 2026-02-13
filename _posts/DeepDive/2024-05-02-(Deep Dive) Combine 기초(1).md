---
title: (Deep Dive) Combine 기초(1)
writer: Harold
date: 2024-05-02 13:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

코드를 통해 이해해보기.

## Publisher & Subscriber

```swift
let just = Just(1000)
let subscription1 = just.sink { value in
    print("Received Value: \(value)")
} // Received Value: 1000 하나만 전송하고 끝.

let arrayPublisher = [1, 3, 5, 7, 9].publisher
let subscription2 = arrayPublisher.sink { value in
    print("Received Value: \(value)")
}
// Received Value: 1
// Received Value: 3
// Received Value: 5
// Received Value: 7
// Received Value: 9
// 5개 전송 다하고 끝

class MyClass {
    var property: Int = 0 {
        didSet {
            print("Did set property to \(property)")
        }
    }
}

let object = MyClass()
let subscription3 = arrayPublisher.assign(to: \.property, on: object)
// assign의 경우 object에 어떤 property에 값을 할당할 것을 말함.
// 여기선 object의 property에 property(arrayPublisher의 하나하나의 값)를 할당 
// Did set property to 1
// Did set property to 3
// Did set property to 5
// Did set property to 7
// Did set property to 9

print("Final Value: \(object.property)") // 마지막의 값 확인.
// Final Value: 9
```

## Subject - Publisher

```swift
// PassthroughSubject
let relay = PassthroughSubject<String, Never>()
let subscription1 = relay.sink { value in
    print("Subscription1 received value: \(value)")
}

relay.send("Hello")
relay.send("World!")
// Subscription1 received value: Hello
// Subscription1 received value: World!

// CurrentValueSubject
let variable = CurrentValueSubject<String, Never>("") // 초기값 설정이 필요

let subscription2 = variable.sink { value in
    print("Subscription2 received value: \(value)")
}

variable.send("More text")
// Subscription2 received value:  → 비어있는건 초기값 때문
// Subscription2 received value: More text
```

다른 케이스

```swift
let variable = CurrentValueSubject<String, Never>("")
variable.send("Initial text") // Subscription 전에 이렇게 initialize도 가능.

let subscription2 = variable.sink { value in
    print("Subscription2 received value: \(value)")
}

variable.send("More text")
// Subscription2 received value: Initial text
// Subscription2 received value: More text

variable.value // "More text" 현재 이 값을 들고있음.
```

PassthroughSubject 에서,

```swift
let publisher = ["Here", "we", "go"].publisher // 데이터가 주어진 상태의 publisher
publisher.subscribe(relay)
// Subscription1 received value: Here
// Subscription1 received value: we
// Subscription1 received value: go
```

이렇게 된다.

즉 저건 아래와 같다.
```swift
relay.send("Here")
relay.send("We")
relay.send("go")
```

이렇게 publisher를 통해 relay에게 `["Here", "we", "go"]` 이 값들을 전달을 해주었다.

## Subscription

```swift
let subject = PassthroughSubject<String, Never>()

// The print() operator prints you all lifecycle events
let subscription = subject.sink { value in
    print("Subscriber received value: \(value)")
}

subject.send("Hello")
subject.send("Hello again")
subject.send("Hello for the last time")
subject.send(completion: .finished) // 끝
subject.send("Hello ?? :(")

// Subscriber received value: Hello
// Subscriber received value: Hello again
// Subscriber received value: Hello for the last time
```

completion을 통해 완료되었음을 알렸으므로, subscription도 끝났으므로 아래 Hello?? 는 나오지 않는다.

이걸 프린트를 통해 과정을 다시 한번 호출을 해본다.

```swift
let subject = PassthroughSubject<String, Never>()

// The print() operator prints you all lifecycle events
let subscription = subject
    .print() // added
    .sink { value in
    print("Subscriber received value: \(value)")
}

subject.send("Hello")
subject.send("Hello again")
subject.send("Hello for the last time")
subject.send(completion: .finished) // subscription.cancel() 이것도 같음.
subject.send("Hello ?? :(")

// receive subscription: (PassthroughSubject)         → 관계 형성
// request unlimited                                  → 무제한 요청
// receive value: (Hello)                             → Hello를 받음
// Subscriber received value: Hello                   → Subscriber에게 Hello 전달
// receive value: (Hello again)                       → 상동 
// Subscriber received value: Hello again             → 상동
// receive value: (Hello for the last time)           → 상동
// Subscriber received value: Hello for the last time → 상동 
// receive finished                                   → Subscriber가 모든 데이터를 받았음을 알림. (그 밑에 있는건 전달하지 않음.)
```

이런식의 sequence를 보면 이해가 더 잘된다.

## @Published

```swift
final class SomeViewModel {
    @Published var name: String = "Jack" // Publisher 와 같은 의미로 사용
    var age: Int = 20
}

final class Label {
    var text: String = ""
}

let label = Label()
let vm = SomeViewModel()

print("text: \(label.text)")
vm.$name.assign(to: \.text, on: label) // @Published 를통해 label의 text property에 name 프로퍼티 전달.
print("text: \(label.text)")
// text: 
// text: Jack

vm.name = "Jason" // 
print("text: \(label.text)")
// text: Jason
```

이걸 사용해서 값이 변할때마다 UIComponent에 변화를 줄 수 있다.

ex) UILabel.text 를 변경.

## URLSessionTask에서의 Publisher

```swift
struct SomeDecodable: Decodable { }

URLSession.shared.dataTaskPublisher(for: URL(string: "https://www.google.com")!) // publisher
    .map { data, response in
        return data
    }
    .decode(type: SomeDecodable.self, decoder: JSONDecoder())
```

이런 형태를 가진다.

## Notifications에서의 Publisher

```swift
let center = NotificationCenter.default // center 생성
let noti = Notification.Name("MyNoti") // Notification 생성
let notiPublisher = center.publisher(for: noti, object: nil) // publisher 생성
let subscription = notiPublisher.sink { _ in // Noti를 받으면 프린트문 호출
    print("Noti Received")
}

center.post(name: noti, object: nil) // Noti에 보내본다, 실제로 호출을 하는지
```

## KeyPath binding to NSObject instances의 Publisher

```swift
let ageLabel = UILabel()
print("text: \(ageLabel.text)")

Just(28)
    .map { "Age is \($0)"}
    .assign(to: \.text, on: ageLabel)
print("text: \(ageLabel.text)")
```

## Timer에서의 Publisher

```swift
// autoconnect 를 이용하면 subscribe 되면 바로 시작함
let timerPublisher = Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()

let subscription2 = timerPublisher.sink { time in
    print("timne \(time)")
}

// time: 2024-05-02 12:56:42 +0000
// time: 2024-05-02 12:56:43 +0000
// time: 2024-05-02 12:56:44 +0000
// time: 2024-05-02 12:56:45 +0000
// time: 2024-05-02 12:56:46 +0000
```

다만 이상태로는 무한대로 시간을 출력하므로 5초뒤에 끊어주는 메서드가 필요.

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    subscription2.cancel()
}
```

