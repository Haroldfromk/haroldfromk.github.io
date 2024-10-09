---
title: (Deep Dive) Combine 기초
writer: Harold
date: 2024-05-02 13:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Udemy, Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

컴바인에 대해 공부를 해야할 필요성을 느껴 공부를 하게 되었는데, Udemy 공부를 하면서 코드의 흐름은 파악이 되지만 정확하게 어떤 의미로 작동하는지를 확실하게 하기 위해 여기에 적는다.

이전에 패캠 강의를 구매해두고 Udemy꺼만 봤는데, 이럴때 도움이 될줄은 몰랐다.

내가 찾은 이미지와 내용 + 패캠강의를 mix시켜 적어보도록 한다.

[사용예시](https://www.swiftbysundell.com/basics/combine/){:target="_blank"}

이런식으로 API를 처리 할 수 있다.

## 1. Combine???

2019년도에 애플이 공개한 비동기 이벤트를 처리할 수 있는 Framework

우선 이미지로 보면

![](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*nQg-PRjr3kvlF7JSxMxT8g.png)

![](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*naRxPopRFiLC6WzgbSc2zg.png)

RxSwift 보다 성능이 우월하다.

3rd party library 와 framework의 차이 때문 → 약간 인텔 맥과 애플 실리콘 맥의 차이랄까

[성능비교](https://medium.com/@M0rtyMerr/will-combine-kill-rxswift-64780a150d89){:target="_blank"}는 여기서

## 2. Components

주요 Components에는 Publisher, Subscriber, Operator가 있다.

1. Publisher
- 생산자, 배출자의 개념 (value 생산)
    - 시간이 지남에 따라 일련의 값을 전달하는데 적합한 개체
    - Output, Failure 두개의 값을 전달 (성공, 실패)
    - 하나 이상의 Subscriber에게 값을 전달.
2. Subscriber (value를 다룸)
- 받는자
    - Publisher로 부터 값을 받음.
3. Operator (value와 함께 기능 수행)
- 가공자, 연산자의 개념
    - 연산자는 값 변경, 값 추가, 값 제거 또는 기타 여러 작업에 대한 동작을 설명.
    - 여러 연산자를 함께 연결하여 복잡한 처리를 수행할 수 있다.

![](https://koenig-media.raywenderlich.com/uploads/2020/01/Publisher-Subscriber-474x500.png)

![](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*jLmJpJX952LXGsqpOKYQfQ.png)

### 1. Publisher

정의는 아래와 같이 되어있음.

```swift
public protocol Publisher<Output, Failure> {

    /// The kind of values published by this publisher.
    associatedtype Output

    /// The kind of errors this publisher might publish.
    ///
    /// Use `Never` if this `Publisher` does not publish errors.
    associatedtype Failure : Error

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Implementations of ``Publisher`` must implement this method.
    ///
    /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
    ///
    /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input
}
```

---

기능.
- 데이터를 배출
    - 구체적인 output 및 failure 타입을 정의
    - Subscriber가 요청한 만큼 데이터를 제공해줌. (그래서 배출의 의미)
- Built in Publisher인 `Just`, `Future`가 있다.
    - Just : Value를 다룸
    - Future : Fuction을 다룸
- iOS 에서는 자동으로 제공해주는 녀석들이 있음
    - NotificationCenter
    - Timer
    - URLSession.dataTask

### 2. Subscriber

정의는 아래와 같이 되어있음.

```swift
public protocol Subscriber<Input, Failure> : CustomCombineIdentifierConvertible {

    /// The kind of values this subscriber receives.
    associatedtype Input

    /// The kind of errors this subscriber might receive.
    ///
    /// Use `Never` if this `Subscriber` cannot receive errors.
    associatedtype Failure : Error

    /// Tells the subscriber that it has successfully subscribed to the publisher and may request items.
    ///
    /// Use the received ``Subscription`` to request items from the publisher.
    /// - Parameter subscription: A subscription that represents the connection between publisher and subscriber.
    func receive(subscription: any Subscription)

    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements the subscriber expects to receive.
    func receive(_ input: Self.Input) -> Subscribers.Demand

    /// Tells the subscriber that the publisher has completed publishing, either normally or with an error.
    ///
    /// - Parameter completion: A ``Subscribers/Completion`` case indicating whether publishing completed normally or with an error.
    func receive(completion: Subscribers.Completion<Self.Failure>)
}
```

---

기능.
- Publisher 에게 데이터를 요청한다
    - Input, Failure 타입의 정의가 필요하다.
        - 이때 Publisher와 같은 타입이 되어야 한다!
            - 요청한것과 같은 데이터 타입이 되어야한다는 뜻.
            - Publisher의 output, Failure = Subscriber의 input, Failure
- Publisher 구독 후, 갯수를 요청함
- 파이프라인을 취소할 수 있음
- Built in Subscriber인  `assign` 과 `sink` 가 있다
    - `assign` 는 `Publisher`가 제공한 데이터를 특정 객체의 키패스에 할당
        - `Publisher`로 부터 받은 값을 주어진 instance의 property에 할당
        - 주어지는 값이 무조건 있어야하기 때문에 sink와는 다르게 `publisher`의 `Failure` 타입이 `Never`일때만 사용 가능
    - `sink` 는 Publisher가 제공한 데이터를 받을수 있는 클로져를 제공함
        - 클로져에서 새로운 값이나 종료 이벤트에 대해 처리

## 3. 진행되는 패턴

Publisher와 Subscriber의 관계는 위의 사진도 있지만 아래 사진으로도 다시한번 보여줄게 좋을것 같다.

![](https://www.donnywals.com/wp-content/uploads/Custom-subscriber.png)

1. Subscriber가 Publisher에게 붙음
2. 붙은걸 인지하면 Publisher가 Subsciption을 생성
3. Publisher가 Subscriber에게 Subsciption을 전달.
4. Subscriber가 Value를 요청
5. Publisher가 Value를 Subsciption을 통해 전달.
6. Value전달이 끝나면 Completion을 통해 전달이 완료되었음을 Subscriber에게 전달

### 1. Subscription ?

- Subscriber 가 Publisher가 연결됨을 나타내는 녀석
    - 쉽게 생각하면, Publisher 가 발행한 구독 티켓
    - 이 구독 티켓만 있으면, 데이터를 받을수 있음
    - 이 구독 티켓이 사라지면 구독 관계도 사라짐
- `Cancellable` protocol을 따르고 있음
    - `Cancellable` protocol의 cancel을 하게 되면 Subscriber와 Publisher 구독관계도 파기가됨.

Cancellable의 정의는 아래와 같이 되어있음.

```swift
public protocol Cancellable {

    /// Cancel the activity.
    ///
    /// When implementing ``Cancellable`` in support of a custom publisher, implement `cancel()` to request that your publisher stop calling its downstream subscribers. Combine doesn't require that the publisher stop immediately, but the `cancel()` call should take effect quickly. Canceling should also eliminate any strong references it currently holds.
    ///
    /// After you receive one call to `cancel()`, subsequent calls shouldn't do anything. Additionally, your implementation must be thread-safe, and it shouldn't block the caller.
    ///
    /// > Tip: Keep in mind that your `cancel()` may execute concurrently with another call to `cancel()` --- including the scenario where an ``AnyCancellable`` is deallocating --- or to ``Subscription/request(_:)``.
    func cancel()
}
```

## 4. Subject - Publisher

- `send(_:)`  메소드를 이용해서 이벤트 값을 주입시킬수 있는 Publisher
- 기존의 비동기처리 방식에서 Combine으로 전환시 유용함
- 2가지 Built in 타입이 있음
    - `PassthroughSubject`
        - Subcriber가 달라고 요청하면, 그때 부터 받은 값을 전달해주기만 함
        - 전달한 값을 들고 있지 않음
    - `CurrentValueSubject`
        - Subcriber가 달라고 요청하면, 최근에 가지고 있던 값을 전달하고, 그때 부터 받은 값을 전달 함
        - 전달한 값을 들고 있음

![](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*lX7mRYm51nIKe6rlmK2JhQ.png)

## 5. @Published - Publisher

- `@Published` 로 선언된 프로퍼티를 Publisher로 만들어 준다.
- 클래스에 한해서 사용됨 (구조체에서 사용안됨)
- `$` 를 이용해서 퍼블리셔에 접근할수 있음
- @Published 속성은 변경되는 사항을 등록한 모든 View에 알림.
- 값이 변경되면 새 값을 전송하거나 게시한다.
- View는 @StateObject 프로퍼티 래퍼를 사용해 이 ObservableObject와 연결될 수 있음.
- ex)

```swift
class Weather {
    @Published var temperature: Double
    init(temperature: Double) {
        self.temperature = temperature
    }
}

let weather = Weather(temperature: 20)
let subscription = weather.$temperature.sink {
    print ("Temperature now: \($0)")
}
weather.temperature = 25

// Temperature now: 20.0
// Temperature now: 25.0 → 위에서 값이 25로 변경이 되었기에 게시를 해줌.
```

> ObservableObject
>> @Published 속성값이 변경됨을 View에 알림

[출처](https://velog.io/@juneyj1/Swift%EC%9D%98-Combine-Published){:target="_blank"}

## 6. Operator

- Publisher 에게 받은 값을 가공해서 Subscriber 에게 제공
- Input, Output, Failure type 을 받는데 타입이 다를수 있음
- Built in Operator가 많이 있음
    - map, filter, reduce, collect, combineLatest ....

![CleanShot 2024-05-02 at 21 51 22@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1dff7031-8137-4f80-a155-621e6f178a14)
![CleanShot 2024-05-02 at 21 51 47@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8e8825e1-1656-4a44-9063-48414fe2af87)

![CleanShot 2024-05-02 at 21 52 01@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2e533472-2695-42ec-84f4-2897e8c385b3){: width="40%" height="40%"}

## 7. Scheduler

- Scheduler 는 언제, 어떻게 클로져를 실행할지 정해준다.
- Operator 에서 Scheduler를 파라미터로 받을때가 있음
    - 작업에 따라서, 백그라운드 혹은 메인스레드에서 작업이 실행될 수 있게 도와줌
- Scheduler 가 스레드 자체는 아님

![](https://assets.alexandria.raywenderlich.com/books/comb/images/35d36351f3e562d6e28ac9b88365ea8be68cd99fe2038435462b1a4a9ae9e3fb/original.png)

### 1. 2가지 Scheduler Methods

`subscribe(on:)` 을 이용해서, publisher 가 어느 스레드에서 수행할지 결정해주는것 

- 무거운 작업은 메인스레드가 아닌 다른 스레드에서 작업할수 있게 도와줌
    - 예) 백그라운드 계산이 많이 필요한것
    - 예) 파일 다운로드해야하는 경우


![](https://trycombine.com/images/subscribe-receive/subscribe-on.png)

`receive(on:)` 을 이용해서 operator, subscriber 가 어느 스레드에서 수행할지 결정해주는것

- UI 업데이트 필요한 데이터를 메인스레드에서 받을수 있게 도와줌
    - 예) 서버에서 가져온 데이터를 UI 업데이트 할때

![](https://trycombine.com/images/subscribe-receive/receive-on.png)


![](https://assets.alexandria.raywenderlich.com/books/comb/images/8036670b2676b93304f725db41ff6d65ab6be5366fac275ed32aaf2e6ea12800/original.png)

**일반적인 패턴**

```swift
let jsonPublisher = MyJSONLoaderPublisher() // Some publisher.

jsonPublisher
    .subscribe(on: backgroundQueue) // background queue 에서 진행하게 설정.
    .receive(on: RunLoop.main) // UI update를 위해 main thread로 이동
    .sink { value in // label의 text값을 변경.
		label.text = value
}
```

**UI 업데이트 시**

🔴 이렇게 하지말고
```swift 
// 가능하지만, Apple의 권고 사항이 아니다.
pub.sink {
    DispatchQueue.main.async {
        // Do update ui
    }
}
```

🟢 이렇게 하기
```swift
pub.receive(on: DispatchQueue.main).sink {
        // Do update ui
}
```


## 이미지 출처

https://medium.com/harrythegreat/swift-combine-%EC%9E%85%EB%AC%B8%ED%95%98%EA%B8%B0-%EA%B0%80%EC%9D%B4%EB%93%9C-1-525ccb94af57

https://www.kodeco.com/7864801-combine-getting-started

https://www.donnywals.com/understanding-combines-publishers-and-subscribers/

https://ahmadgsufi.medium.com/mastering-the-power-of-subjects-in-combine-a-comprehensive-guide-434ece579c2e

https://www.kodeco.com/books/combine-asynchronous-programming-with-swift/v1.0/chapters/17-schedulers

https://trycombine.com/posts/subscribe-on-receive-on/

https://tanaschita.com/20221121-cheatsheet-combine-operators/