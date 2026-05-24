---
title: SwiftUI Combine (4)
writer: Harold
date: 2026-05-17 07:16
categories: [Udemy, Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

## Data Streaming: PassthroughSubject의 도입

지금까지 만든 방식은 진정한 의미의 데이터 스트리밍(Data Streaming)이 아니다. 
API를 한 번 호출하고 결과를 통째로 한 번 받고 끝나는 단발성 작업(Future)이었을 뿐이다.

하지만 이번 프로젝트에서는 PassthroughSubject를 도입한다.

**무엇이 다른가?**
* 기존 (단발성): 데이터를 요청하면 서버가 완성된 데이터를 한 번에 다 던져주고 연결을 종료한다.
* PassthroughSubject (스트림): 파이프를 계속 열어두는 방식이다. 데이터를 한 번에 다 주는 것이 아니라, 시간에 따라 지속적으로 흘려보낸다.

예를 들어 파이터 목록을 가져올 때, 기존처럼 한 번에 다 받아오는 것이 아니라 다음과 같이 동작한다.
1. 0초: Jon Jones 데이터 도착 (리스트 추가)
2. 2초 뒤: Israel Adesanya 데이터 도착 (리스트 추가)
3. 5초 뒤: Alex Pereira 데이터 도착 (리스트 추가)

우리는 요청을 딱 한 번만 했지만, 스트림이 열려 있는 동안 데이터가 시간차를 두고 계속 들어오면서 화면의 리스트를 점진적으로 업데이트(Update) 하는 것이다. 

이제 이 PassthroughSubject를 이용해 시간에 따라 데이터가 순차적으로 들어오는 스트리밍 서비스(Mock Service)를 만들고 적용해 본다.

---

## MMAInfoPassthroughApp (PassthroughSubject)

이번엔 PassthroughSubject를 사용한 앱을 만든다.

모델링은 같기에 패스.

---

### StreamingService 만들기

```swift
final class MockStreamingFighterService {
    private let subject = PassthroughSubject<MMAFighter, Error>()
    private var cancellables = Set<AnyCancellable>()

    func streamFighters(interval: TimeInterval = 3.0) -> AnyPublisher<MMAFighter, Error> {
        // Load JSON
        guard let url = Bundle.main.url(forResource: "MMAFighters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(FightersResponse.self, from: data)
        else {
            return Fail(error: NSError(
                domain: "MockStreamingFighterService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "MMAFighters.json not found or invalid"]
            ))
            .eraseToAnyPublisher()
        }

        // Start emitting fighters one by one
        let fighters = response.fighters
        var index = 0

        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if index < fighters.count {
                    self.subject.send(fighters[index])
                    index += 1
                } else {
                    self.subject.send(completion: .finished)
                }
            }
            .store(in: &cancellables)

        return subject.eraseToAnyPublisher()
    }
}
```

Json 로드 부분은 뭐 이미 언급을 전에 했기에 생략한다.

`Timer.publish(every: interval, on: .main, in: .common)`

여기서 주목할건 Timer를 통해 우리가 설정한 interval로 (입력이 없다면 3초가 Default) 값을 보내게 된다. 이떄 인덱스를 1씩 늘린다.

준비된 데이터를 모두 보내면 `.finished`를 호출해 스트림을 완전히 종료한다.

그리고 클로저 내부의 강한 순환 참조(메모리 누수)를 막기 위해 `[weak self]`를 사용했고, 이로 인해 옵셔널이 된 `self`를 `guard let`으로 안전하게 추출(바인딩) 해주었다.

#### in
[RunLoop.Mode Docs](https://developer.apple.com/documentation/foundation/runloop/mode){:target="_blank"}를 정리를 해보면

`in`은 RunLoop가 실행되는 **'환경'** 또는 **'상태'**를 의미한다.

RunLoop는 시스템에서 발생하는 수많은 이벤트를 처리하는데, 특정 순간에 **"어떤 종류의 이벤트만 필터링해서 처리할 것인지"** 결정하는 작업 환경(Mode) '안(in)'에서 동작한다는 뜻이다.

종류는 다음과 같다.

| 모드(Mode) | 설명 |
|---|---|
| `common` | 하나 이상의 다른 런루프 모드를 포함하는 가상 모드(pseudo-mode)이다. |
| `default` | 연결(connection) 객체 이외의 입력 소스를 처리하도록 설정된 모드이다. |
| `eventTracking` | 마우스 드래그 루프와 같이 이벤트를 모달 방식으로 추적할 때 설정되는 모드이다. |
| `modalPanel` | 저장 또는 열기 패널과 같은 모달 패널의 입력을 대기할 때 설정되는 모드이다. |
| `tracking` | 컨트롤 내부에서 추적(tracking)이 발생할 때 설정되는 모드이다. |

---

#### autoconnect
그리고 `autoconnect()`가 있는데, 이건 내가 정리를 해본적이 없어서 좀 적어보려고 한다.

우선 해당 키워드로 검색을 했을때 공통점은 바로 `Timer`에서 쓰였다는 것이다.

[autoconnect() Docs](https://developer.apple.com/documentation/combine/connectablepublisher/autoconnect()){:target="_blank"}에서는 아래와 같이 정의한다.

`ConnectablePublisher`에 연결(connect)하거나 연결을 해제(disconnect)하는 과정을 자동화하는 메서드이다.

**반환값 (Return Value)**
업스트림 Connectable 퍼블리셔에 자동으로 연결을 수행하는 퍼블리셔(`Publishers.Autoconnect<Self>`)를 반환한다.

Docs만 보기엔 조금 정보가 아쉬워서 [Medium](https://medium.com/@iamCoder/understanding-autoconnect-in-combines-timer-publisher-10146a5b0fd7){:target="_blank"}에 좋은글이 있어서 이걸 정리 해본다.

---

##### Timer Publisher 기본 구조

`autoconnect()`를 이해하려면 Timer Publisher가 어떻게 동작하는지부터 알아야 한다.

```swift
let timer = Timer.publish(every: 1.0, on: .main, in: .common)
```

이 코드만으로는 타이머가 작동하지 않는다. `Timer.publish`는 `ConnectablePublisher`를 반환하는데, 이는 **명시적으로 시작 신호를 줘야만 값을 방출**하는 Publisher다.

---

##### connect() — 수동 연결

구독만 하면 아무 일도 일어나지 않는다.

```swift
let cancellable = timer.sink { print($0) }
// 아무것도 출력되지 않음
```

타이머를 시작하려면 `connect()`를 직접 호출해야 한다.

```swift
let connection = timer.connect()  // 이 시점부터 1초마다 값 방출
```

그리고 멈추고 싶을 때는 명시적으로 취소한다.

```swift
connection.cancel()
```

이 방식은 타이머의 시작과 종료 시점을 직접 제어해야 할 때 사용한다.

---

##### autoconnect() — 자동 연결

구독하는 순간 타이머가 바로 시작되길 원한다면 `autoconnect()`를 사용한다.

```swift
let cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { print($0) }
// 구독 즉시 1초마다 값 방출 시작
```

`connect()`를 따로 호출하지 않아도 되고, `cancellable`이 해제되거나 취소되면 타이머도 자동으로 멈춘다.

---

##### connect() vs autoconnect() 비교

| | connect() | autoconnect() |
|---|---|---|
| 시작 시점 | `connect()` 호출 시 | 구독 즉시 |
| 종료 시점 | `connection.cancel()` 호출 시 | 구독 해제 시 자동 |
| 사용 시기 | 시작/종료 타이밍을 직접 제어할 때 | 구독과 동시에 시작해도 될 때 |

---

##### 구독을 반드시 저장해야 하는 이유

```swift
Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { print($0) }
// ❌ 반환값을 저장하지 않으면 즉시 취소됨
```

`.sink`는 `Cancellable` 객체를 반환하는데, 이걸 저장하지 않으면 즉시 해제되면서 구독이 취소된다. 값이 한 번도 출력되지 않는 이유가 바로 이것이다.

```swift
var cancellables = Set<AnyCancellable>()

Timer.publish(every: 1.0, on: .main, in: .common)
    .autoconnect()
    .sink { print($0) }
    .store(in: &cancellables)  // ✅ cancellables가 살아있는 동안 구독 유지
```

`cancellables`는 보통 ViewModel이나 ViewController의 생명주기에 묶여 있어서, 해당 객체가 사라질 때 구독도 함께 정리된다.

구독을 명시적으로 멈추고 싶다면:

```swift
cancellable.cancel()       // 즉시 취소
cancellables.removeAll()   // 전체 취소
```

사진으로 간단하게 정리를 해봤다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/be303eb7-72d9-4c2e-9191-bccc350465aa" />

이건 시뮬레이터

<iframe 
    src="/assets/demo/timer-simulator.html" 
    width="100%" 
    height="480px" 
    frameborder="0" 
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden; background-color: #1e1e1e;"
    title="Timer Simulator">
</iframe>

---

### ViewModel 만들기

```swift
final class FighterStreamViewModel: ObservableObject {
    @Published var fighters: [MMAFighter] = []

    private let service = MockStreamingFighterService()
    private var cancellables = Set<AnyCancellable>()

    func startStreaming() {
        service.streamFighters(interval: 3.0)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { print("Stream completed:", $0) },
                receiveValue: { [weak self] fighter in
                    self?.fighters.append(fighter)
                }
            )
            .store(in: &cancellables)
    }
}
```

여긴 크게 뭐 언급할만한게 없다.

이것도 UI업데이트 이므로 메인스레드에서 작업을 해준다 라는 것과
3초마다 fighter를 받게되고 그걸 fighters라는 배열에 차곡차곡 담아준다. 이게 여기서 핵심이다.

강의에서 `[weak self]`를 언급해서 짤막하게 강의의 내용을 정리

* 메모리 누수 방지: 클로저 내부에서 `self`를 강하게 참조하면 뷰나 뷰모델이 닫혀도 메모리에서 해제되지 않는 강한 순환 참조가 발생한다.
* 자원 반환: `[weak self]`를 통해 약한 참조를 하면 해당 객체를 더 이상 사용하지 않을 때 메모리를 정상적으로 반환(Release)할 수 있다.
* 성능 저하 방지: 약한 참조를 하지 않으면 해당 화면이나 뷰모델을 사용할 때마다 메모리가 반환되지 않고 계속 쌓이게 되어 치명적인 성능 저하를 일으킨다.

### View 만들기

```swift
@StateObject private var vm = FighterStreamViewModel()

VStack {
    List(vm.fighters, id: \.name) { fighter in
        Text(fighter.name)
    }

    Button("Start Streaming Fighters") {
        vm.startStreaming()
    }
}
```

딱히 뭐 없다.

실행을 하면?

빠른 결과를위해 `service.streamFighters(interval: 0.5)`
0.5초로 바꿔둔다.

<img width="288" height="598" alt="Image" src="https://github.com/user-attachments/assets/77e8b45d-e3a4-465b-9430-70f6fe65ddec" />{: width="50%" height="50%"}

중간에 끊었지만 아마 전부 가져오면 구독이 끊기면서 멈췄을것이다.
