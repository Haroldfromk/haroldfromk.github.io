---
title: RunWay (5) RunningCenter Actor
writer: Harold
date: 2026-06-05 08:33:00 +0800
last_modified_at: 2026-06-06 10:24
categories: [RunWay]
tags: [Actor, AsyncStream, FlightPhase, Concurrency]

toc: true
toc_sticky: true
published: true
---

생각보다 빨리 끝나서 오늘 미리 좀 해보려고 한다.

아무래도 Actor쪽이다보니 빨리하는게 좋다고 판단했다.

Actor의 경우 [Swift Concurrency & 격리(Isolation) 핵심 개념 정리](https://haroldfromk.github.io/posts/swift-concurrency-isolation/){:target="_blank"}, [미니프로젝트](https://haroldfromk.github.io/posts/Actor-%EB%AF%B8%EB%8B%88-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8(1)/){:target="_blank"}같이 언급을 많이 했어서 패스하도록 한다.

## RunningCenter Actor 기본 구조 구현

RunWay에서는 GPS, HealthKit, CoreMotion 데이터가 동시에 병렬로 들어온다. 이를 ViewModel에서 직접 처리하면 데이터 레이스 위험이 생기고 ViewModel이 비대해진다.

그래서 `RunningCenter`를 `actor`로 선언하여 모든 러닝 데이터 처리를 단일 격리 영역에서 담당하도록 한다. `actor`는 내부적으로 serial queue를 보장하기 때문에 여러 데이터가 동시에 들어와도 상태 무결성이 유지된다.

다만 `RunningCenter`는 서비스 객체를 직접 들고 있지 않는다. 대신 ViewModel이 서비스에서 받은 데이터를 Actor로 전달하고, Actor는 그 데이터를 가공하여 다시 ViewModel로 내보내는 구조다.

```text
LocationService  → ViewModel → RunningCenter Actor → AsyncStream → ViewModel → View
HealthKitService ↗
```

이 구조에서 `RunningCenter`가 담당할 것들은 아래와 같다.

- GPS 위치 데이터 처리
- 심박수 / 케이던스 데이터 처리
- FlightPhase 상태 관리
- 처리된 데이터를 AsyncStream으로 ViewModel에 전달

```swift
actor RunningCenter {  
}
```

우선 이렇게 기본 뼈대를 만들어 주었다.

---

### Actor에서 지금 할 수 있는 것들

현재 가진 데이터는 `LocationService`의 실시간 GPS 좌표와 `HealthKitService`의 MockData fetch 결과다. 

이 두 가지를 기준으로 Actor에서 처리할 수 있는 것들을 정리해보면 아래와 같다.

- 위치 데이터 받아서 처리 — LocationService에서 좌표 받아서 거리 계산, 경로 누적
- HealthKit 데이터 받아서 저장 — fetch 결과를 Actor 내부에서 관리 (실시간 스트림은 Apple Watch 연동 후 가능, 현재는 MockData fetch 수준)
- FlightPhase 상태 전환 — 러닝 시작/종료에 따라 상태 변경
- AsyncStream으로 ViewModel에 전달 — 위 데이터들을 묶어서 전달

---

#### 1. 위치 데이터 처리
`LocationService`에서 실시간으로 받아오는 `latitude`, `longitude`를 Actor로 전달하여 누적 거리 계산과 경로 좌표 저장을 담당한다.

우선 계획은 다음과 같다.

1. 시뮬레이터 City Run 실행
2. LocationService에서 좌표 실시간 수신
3. Actor로 전달 → 배열에 누적
4. 러닝 종료 시 SwiftData에 저장
5. FlightSummaryView에서 MapPolyline으로 표시

---

이제 코드를 작성해보도록 한다.

```swift
private var totalDistance: Double = 0
private var lastLocation: CLLocation?
var coordinateArray = [(latitude: Double, longitude: Double)]()

func processLocation(_ location: CLLocation) {
    if let last = lastLocation {
        totalDistance += location.distance(from: last)
    }
    lastLocation = location
    coordinateArray.append((latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
}
```

`processLocation`이 호출될 때마다 세 가지 작업이 순서대로 이루어진다.

1. **거리 누적** — `lastLocation`이 있으면 이전 좌표와 현재 좌표 사이의 거리를 `CLLocation`의 `distance(from:)` 메서드로 계산하여 `totalDistance`에 더한다. 처음 호출 시에는 `lastLocation`이 `nil`이므로 건너뛴다.
2. **이전 좌표 갱신** — 현재 좌표를 `lastLocation`에 저장하여 다음 호출 때 기준점으로 사용한다.
3. **경로 좌표 누적** — 현재 좌표를 `coordinateArray`에 추가한다. 이 배열이 나중에 `MapPolyline` 경로 표시에 사용된다.

---

##### 1. 작동 확인하기

Actor만 만들어둔 상태로는 테스트가 불가능하다. ViewModel에서 Actor로 데이터를 넘기는 연결이 필요하다.

순서는 아래와 같다.

1. `RunViewModel`에 `RunningCenter` 인스턴스 추가
2. `LocationService`에서 좌표를 받을 때마다 Actor로 전달
3. 시뮬레이터 City Run으로 `coordinateArray`, `totalDistance` 확인

우선 `RunViewModel`에 `RunningCenter` 인스턴스를 추가한다.

```swift
private let runningCenter = RunningCenter()
```

그리고 `LocationService`에서 좌표가 업데이트될 때마다 Actor로 전달해야 한다. `locationService`의 `latitude`, `longitude`가 바뀌면 `processLocation`을 호출하는 구조로 연결한다.

하지만 지금 그대로 CLLocation을 사용할수있는 변수가 없다.

---

###### LocationService 수정

그래서 LocationService로가서 location을 만들어준다.

```swift
var currentLocation: CLLocation?

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocations = locations.last{
        currentLocation = lastLocations
        // 생략
    }
}
```

이러면 업데이트될때 마다 currentLocation으로 값이 저장이된다.

---

###### ViewModel 수정

```swift
private let runningCenter = RunningCenter()

func processingData() async {
    guard let location = locationService.currentLocation else { return }
    await runningCenter.processLocation(location)
}
```
우선 `RunViewModel`에 `RunningCenter` 인스턴스를 추가를 하고,

이렇게 함수를 하나 만들어 준다.

이때 actor에 접근하므로 비동기가 강제되어 async/await가 필수이다.

이후 start함수가 실행될때 처리를 해볼 예정이라서

```swift
func start() {
    locationService.startTracking()
    Task {
        await processingData()
    }
}
```

이렇게 Task를 사용해서 추가해주었다.

그리고 거리를 가져오는 함수도 만들어준다.

```swift
func getDistance() async -> Double {
    await runningCenter.totalDistance
}
```

이때 `totalDistance`를 이전에 private로 만들었는데, 읽기전용으로 돌리기위해

```swift
private(set) var totalDistance: Double = 0
```
로 바꿔준다.

---

###### 문제 수정

우선 거리계산이 안되는걸 알 수 있다.

캡쳐를 하려고 다시 실행하다가 갑자기 아래 사진과 같은 에러가 발생

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/64cc1538-b7f9-4a6e-8b94-b10b805749f1.png" />

잘되다가 왜 이러는지 모르지만 무튼 위의 info.plist가 있어서 충돌난것,

우리는 수동으로 관리하기때문에 필요가 없다. 지워주니 해결되었다.

다시 돌아와서 거리계산이 현재 0으로 나오는걸 알 수 있다.

<img width="472" height="986" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/a5564b8f-5418-4fc3-a57d-d77a1c633878.png" />{: width="50%" height="50%"}

이건 현재 주소가 바뀔때마다 값이 들어가게끔 되어야하는 구조인데 LocationService의 currentLocation은 업데이트가 되고 있는데, 업데이트가 되어도 그 값이 actor의 `processLocation`로 전해지지 않는 것이 가장 큰 문제이다.

---

### Combine을 활용한 구조 개선
#### LocationService 수정

위 문제를 해결하기 위해 `LocationService`에 Combine `PassthroughSubject`를 도입하고, 위치가 업데이트될 때마다 자동으로 Actor로 전달되는 구조로 변경한다.

`didUpdateLocations`는 위치가 변경될 때마다 시스템이 자동으로 호출해주는 delegate 메서드이므로, 여기서 `send`만 해주면 위치 변화에 자동으로 반응하는 구조가 된다.

사실 Combine 없이도 `@Observable`의 프로퍼티 변화를 감지하는 방식으로 해결할 수 있었다. 하지만 HealthKit, WatchConnectivity 등 다른 센서 데이터도 같은 패턴으로 처리해야 하는 상황에서 Combine Publisher로 통일하는 것이 구조적으로 더 일관성 있다고 판단했다.

---

```swift
// Before
var currentLocation: CLLocation?
// After
var locationPublisher = PassthroughSubject<CLLocation, Never>()
```

이렇게 해주었다.`PassthroughSubject`는 초기값이 없어도 되기에 굳이 옵셔널로 선언해줄 필요가 없다.

---

#### ViewModel 수정

`LocationService`에서 Publisher가 방출하는 위치 데이터를 Actor로 전달하는 구독 관계를 `init`에서 설정한다.

인스턴스가 생성되는 시점에 바로 구독이 연결되므로, 이후 위치가 업데이트될 때마다 자동으로 `RunningCenter`의 `processLocation`이 호출된다.

```swift
@ObservationIgnored private var cancellables = Set<AnyCancellable>()

init() {
    locationService.locationPublisher
        .sink { [weak self] location in
            guard let self else { return }
            Task {
                await self.runningCenter.processLocation(location)
            }
        }
        .store(in: &cancellables)
}
```

`cancellables`는 구독을 메모리에서 유지하기 위한 컨테이너다. 여기에 저장하지 않으면 구독이 즉시 해제되어 데이터가 전달되지 않는다.

이로써 기존에 만들었던 `processingData()`와 `currentLocation` 변수는 더 이상 필요하지 않아 제거했다. (start의 processingData부분도 삭제)

이제 실행해서 테스트 해보기 전

현재 구조에서 `distance`는 Actor 내부에서만 계산되고 있어 View에서 직접 접근할 수 없다. 

그래서 VM에 `distance` 프로퍼티를 추가하고, Combine sink 안에서 위치가 업데이트될 때마다 Actor에서 값을 꺼내 VM 프로퍼티에 반영하도록 했다.

```swift
var distance: Double = 0

init() {
    locationService.locationPublisher
        .sink { [weak self] location in
            guard let self else { return }
            Task {
                await self.runningCenter.processLocation(location)
                self.distance = await self.runningCenter.totalDistance
            }
        }
        .store(in: &cancellables)
}
```

`distance`는 `@Observable`에 의해 View가 자동으로 감지하므로 별도의 polling 없이 실시간으로 업데이트된다.

`MapTestView`에서도 `@State private var distance`를 제거하고 `runViewModel.distance`로 교체한다.

<img width="472" height="986" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/953cbd7f-7d7d-47af-af4e-3d63169f4785.png" />{: width="50%" height="50%"}

우리가 원하는대로 잘 되는걸 알 수 있다.

이렇게 Combine을 통해 위치 업데이트가 발생할 때마다 자동으로 Actor로 전달되고, 거리가 실시간으로 계산되는 구조를 완성했다.

---

#### 2. FlightPhase 상태 관리
러닝 시작/종료 등 사용자 액션에 따라 `FlightPhase`를 전환하고 관리한다. 앱 전체가 동일한 상태를 참조할 수 있도록 Actor 내부에서 단일 상태로 관리한다.

지금은 기본 틀만 잡아두는 수준이다. `enum FlightPhase`를 정의하고 Actor에 `phase` 프로퍼티와 `updatePhase()` 함수를 추가했다.

```swift
enum FlightPhase {
    case preflight
    case cruise
    case touchdown
}

private(set) var phase: FlightPhase = .preflight

func updatePhase(_ phase: FlightPhase) {
    self.phase = phase
}
```

`private(set)`으로 선언하여 외부에서 직접 변경하지 못하도록 하고, `updatePhase()`를 통해서만 상태를 전환할 수 있다.

phase에 따른 실제 동작 분기는 Week2에서 GPWS, MINIMUMS 로직을 붙이면서 채워나갈 예정이다.

---

#### 3. AsyncStream으로 ViewModel에 전달

위에서 처리한 데이터들을 묶어 AsyncStream으로 ViewModel에 전달한다. ViewModel은 이 스트림을 구독하여 View에 필요한 값만 노출한다.

##### 모델링

우선 실시간으로 전달할 데이터를 담을 `FlightData` 모델을 만든다. 기존 `Flight` 모델은 러닝 종료 후 SwiftData에 저장하는 완성된 기록용이고, `FlightData`는 러닝 중 Actor에서 ViewModel로 실시간으로 흘려보내는 현재 상태 스냅샷이다.

```swift
struct FlightData {
    var distance: Double = 0
    var phase: FlightPhase = .preflight
}
```

지금은 `distance`와 `phase`만 있지만 이후 심박수, 케이던스, 페이스 등이 추가될 예정이다.

---

##### RunningCenter 수정하기

```swift
func processLocation(_ location: CLLocation) -> FlightData {
    if let last = lastLocation {
        totalDistance += location.distance(from: last)
    }
    lastLocation = location
    coordinateArray.append((latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
    return FlightData(distance: totalDistance, phase: phase)
}

func streamFlightData(_ location: CLLocation) -> AsyncStream<FlightData> {
    AsyncStream { continuation in
        let data = processLocation(location)
        continuation.yield(data)
        
    }
}
```

우선 이렇게 코드를 수정 및 작성해주었다.

다만 `streamFlightData` 부분에 콜백 함수에 대해 continuation을 사용했다면 `continuation.onTermination`을 사용했을텐데 지금은 없다.

즉, 지금의 코드 작성방식은 벌써 좋지 않은 느낌이 들기 시작한다.

그리고 ViewModel도 아래와 같이 수정해주었다.

```swift
init() {
    locationService.locationPublisher
        .sink { [weak self] location in
            guard let self else { return }
            Task {
                for await data in await runningCenter.streamFlightData(location) {
                    self.distance = data.distance
                }
            }
        }
        .store(in: &cancellables)
}
```

실행해서 확인해보자.

작동은 잘 된다. 하지만 과연 이 구조가 맞는건지 의문이 생겨서 찾아보다가 [참고글](https://matteomanferdini.com/swift-asyncstream/){:target="_blank"}을 발견했다.

거기선 다음과 같이 언급한다.

> Apple's documentation shows how to initialize an `AsyncStream` with a closure that takes a continuation. However, that's useful only when you can use the continuation immediately. If, instead, you need to use the continuation somewhere else or in multiple places, e.g., in a callback closure or with delegation, you have to save it in a stored property.

Apple 문서에서는 클로저 안에서 바로 `continuation`을 사용하는 방식을 보여준다. 하지만 이 방식은 즉시 사용할 수 있을 때만 유용하다. 콜백 클로저나 delegate처럼 다른 곳에서 사용해야 한다면 프로퍼티로 저장해야 한다.

그럼 지금 우리 구조는 즉시 사용하는게 맞나? `print`로 확인해보자.

```swift
func streamFlightData(_ location: CLLocation) -> AsyncStream<FlightData> {
    AsyncStream { continuation in
        print("스트림 생성")
        let data = processLocation(location)
        continuation.yield(data)
    }
}
```

위치 업데이트마다 "스트림 생성"이 찍히는 것을 확인할 수 있다. 

즉, 매번 새 스트림이 생성되고 있는 것이다. 참고글에서 언급한대로 프로퍼티로 저장하는 방식으로 변경해야 한다.

또한 이건 Task도 계속 생성이 되는건가? 싶어서 Instrument의 Swift Concurrency를 통해 확인을 해보았다.

사용 방법은 Command + I 를 누르면 아래와 같이 창이 뜬다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/e671fec2-e78e-4dc3-bf07-7f0126bd4310.png" />

거기서 선택 후 녹화를 하면 자연스레 빌드가 되며 시뮬레이터가 뜨는데, 이때 우리가 테스트할 기능을 사용하면된다.

그랬더니 아래와 같은 충격적인 결과가 나왔다.

스트림 뿐만아니라 Task도 생성이 되면서 호출이 된 것

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/6229fec6-1c6a-49e1-bbe6-cf052a08e9e6.png" />

<img width="800" height="614" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/08f2aba2-9539-4f31-8d2a-3a4dc47f3c2a.png" />

이는 Combine의 `sink`와 비교하면 더 명확하게 이해할 수 있다.

Combine에서는 `sink`를 한 번만 설정하고 Publisher가 값을 방출할 때마다 동일한 구독이 계속 이어진다. 하나의 파이프가 열려있고 값이 계속 흘러오는 구조다.

하지만 지금 방식은 위치 업데이트마다 새 스트림과 새 Task가 생성되므로, 구독이 계속 새로 생기는 것과 같다. 파이프를 계속 새로 만드는 셈이다.

마치 이건 [GitExplorer(4)](https://haroldfromk.github.io/posts/GitExplorer(4)/){:target="_blank"}에서 구독 중첩문제와 상황이 같다는 것.

이 문제를 해결하려면 스트림을 한 번만 열어두고 `continuation`을 프로퍼티로 저장하여, 위치 업데이트가 올 때마다 그 저장된 `continuation`으로 `yield`하는 구조로 변경해야 한다.

---

###### Continuation 별도 관리하기

위의 참고글을 인용하여 `continuation`을 Actor의 프로퍼티로 저장하여 관리한다.

이렇게 하면 스트림을 한 번만 열어두고, 위치 업데이트가 올 때마다 저장된 `continuation`으로 `yield`할 수 있어 매번 새 스트림이 생성되는 문제를 해결할 수 있다.

그리고 이렇게 별도로 관리하게되면 continuation이 AsyncStream 코드블럭 내에서만 작동하는게 아니라서 데이터를 현재 이동거리를 계산하는 `processLocation` 내부에 사용하여 값을 전달할수 있다는 큰 장점이 생기게 된다.

```swift
func processLocation(_ location: CLLocation) {
    if let last = lastLocation {
        totalDistance += location.distance(from: last)
    }
    lastLocation = location
    coordinateArray.append((latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
    let flightData = FlightData(distance: totalDistance, phase: phase)
    continuation?.yield(flightData)
}
```

그리고

```swift
func streamFlightData(_ location: CLLocation) -> AsyncStream<FlightData> {
    AsyncStream<FlightData> { continuation in
        print("스트림 생성")
        self.continuation = continuation
        continuation.onTermination = { _ in
            print("스트림 종료")
            self.continuation = nil
        }
    }
}
```
이렇게 nil을 하여 continuation을 초기화 하려고 했으나

```swift
Actor-isolated property 'continuation' can not be mutated from a Sendable closure
```

위와 같은 에러가 발생

왜 Sendable인가해서 option을 눌러서 확인했을땐 없었는데

[onTermination Docs](https://developer.apple.com/documentation/swift/asyncstream/continuation/ontermination){:target="_blank"}에는 잘 나와있다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/0fa7b084-ccf7-4021-b4d7-4c1f293973b7.png" />

---

###### Sendable

[Sendable Docs](https://developer.apple.com/documentation/Swift/Sendable){:target="_blank"}, [Swift Concurrency Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types){:target="_blank"}를 정리해보면

`Sendable`은 데이터 레이스 없이 동시성 컨텍스트 간에 값을 안전하게 전달할 수 있음을 나타내는 프로토콜이다.

컴파일 타임에 요구사항을 강제하기 때문에 단순히 채택만 한다고 되는 게 아니라, 타입이 실제로 안전한 구조여야 한다.

Swift Concurrency Docs 에서는 이렇게 설명한다.

> A type that can be shared from one concurrency domain to another is known as a sendable type.

동시성 도메인 간에 공유될 수 있는 타입을 `Sendable` 타입이라고 한다.

여기서 동시성 도메인이란 스레드, 액터, Task 등 독립적으로 실행되는 실행 단위를 말한다. 

즉 `@​Sendable` 클로저는 다른 동시성 도메인으로 전달될 수 있으므로, 컴파일러는 이 클로저가 어떤 격리 컨텍스트에서 실행될지 보장할 수 없다고 판단한다

타입별로 간단하게 정리하면:

- **구조체/열거형** — 모든 저장 프로퍼티가 `Sendable`이면 자동으로 준수된다.
- **클래스** — `final`이고 모든 프로퍼티가 불변이어야 한다. `@MainActor` 클래스는 메인 액터가 상태 접근을 조율하므로 예외적으로 가변 프로퍼티도 허용된다.
- **액터** — 내부적으로 순차 처리를 보장하므로 자동으로 준수된다.
- **함수/클로저** — 프로토콜 채택 대신 `@Sendable`을 붙인다. 캡처하는 모든 값이 `Sendable`이어야 하며, 여러 동시성 컨텍스트에서 실행될 수 있다.

컴파일러 검사를 우회하고 싶을 때는 `@unchecked Sendable`을 쓸 수 있지만, 그 경우 스레드 안전성은 개발자가 직접 보장해야 한다.

이해를 돕기위해 시뮬레이터를 참고하면 (해결책이 스포되어있음..)

<iframe 
    src="/assets/demo/simulator_v13.html" 
    width="100%" 
    height="1000" 
    style="border: 2px solid #a0aec0; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>

---

###### 에러 해결하기

`onTermination`은 스트림이 종료될 때 어느 스레드에서든 호출될 수 있는 `@Sendable` 클로저이기 때문에, Actor 격리된 프로퍼티에 직접 접근하면 에러가 발생한다.

즉, `onTermination` 클로저 내부는 암묵적으로 `@Sendable` 컨텍스트다.
`@Sendable`은 어느 스레드에서도 실행될 수 있는 대신, Actor의 격리 영역 밖에 있다. 
그래서 아무리 값을 바꾸려 해도 Actor가 보호하는 `continuation`에는 직접 손댈 수 없는 것이다.

이를 해결하기 위해 값을 바꾸는 메서드를 별도로 만들어서 onTermination 코드블럭에서 실행을 하게 만드는 것이다.

```swift
func streamFlightData() -> AsyncStream<FlightData> {
    AsyncStream<FlightData> { continuation in
        print("스트림 생성")
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task {
                print("스트림 종료")
                await self?.clearContinuation()
            }
        }
    }
}

private func clearContinuation() {
    continuation = nil
}
```

즉 코드블럭에서 값을 직접 바꾸는게 아닌, 메서드를 통해 바꾸도록 시키는것,
그리고 서로 다른 격리 영역에서 접근할땐 이전에 해왔듯이 await를 사용해주면 된다. `Task`가 새로운 비동기 컨텍스트를 만들고, `await`로 Actor의 직렬 큐에서 순번을 기다렸다가 `clearContinuation()`을 실행한다.

그리고 더이상 파라미터가 필요없어서 파라미터 부분을 지워주었다.

---

정리하면:

- `clearContinuation()` — Actor-isolated 메서드이므로 Actor의 직렬 큐를 통해서만 실행된다.
- `Task { await self?.clearContinuation() }` — `@Sendable` 클로저 안에서 직접 프로퍼티를 수정하는 대신, Task를 생성하고 `await`로 Actor의 격리 컨텍스트로 진입한 뒤 안전하게 수정한다.

쉽게 말하면:
- Actor: "내 프로퍼티는 한 번에 하나의 작업만 접근할 수 있어"
- `@Sendable` 클로저: "나는 아무 스레드에서나 실행될 수 있어"
- 컴파일러: "그러면 Actor의 안전 보장이 깨지니까 안 돼!"
- 개발자: "그럼 직접 바꾸지 않고 Actor한테 부탁할게 (`clearContinuation()` 생성)"
- 개발자: "Task로 감싸서 await로 순번 기다릴게"
- `Task { await clearContinuation() }`: "Actor야, 네 차례가 되면 이거 처리해줘"
- Actor: "알겠어, 내 순서가 되면 안전하게 처리할게"

위의 내용 이해륻 돕기위한 만화도 첨부한다.

<img width="1536" height="1024" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/77d180c5-6a3b-4704-8c38-03dcec529ca2.png" />

---

###### init 수정

기존에는 `init` 내부에서 바로 `Task`를 생성하여 스트림을 시작했다.

```swift
init() {
    Task {
        for await data in await runningCenter.streamFlightData() {
            self.distance = data.distance
        }
    }
    locationService.locationPublisher
        .sink { [weak self] location in
            guard let self else { return }
            Task {
                await self.runningCenter.processLocation(location)
            }
        }
        .store(in: &cancellables)
}
```

실제로 로그를 찍어보면 스트림이 두 번 생성되는 것을 확인할 수 있었다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/be9b9764-cda4-4138-8c5d-5eb0f606229c.png" />

```text
스트림 생성
스트림 생성
```

문제는 `init`에 `Task`를 넣어서가 아니다. 생명주기가 긴 스트림을 ViewModel 생성 시점에 시작하면 View의 표시 여부와 관계없이 스트림이 시작될 수 있고, SwiftUI가 View를 구성하는 과정에서 ViewModel을 여러 번 생성하면 스트림도 중복으로 열릴 수 있다.

스트림은 View가 실제로 화면에 표시될 때 시작되는 것이 자연스럽다. 반면 `init`은 객체 생성 시점에 호출되므로 View의 표시 여부와 관계없이 스트림이 시작될 수 있다.

이를 방지하기 위해 스트림 시작 로직을 `startStream()`으로 분리하고 View의 `.task` modifier에서 호출하도록 수정했다.

```swift
init() {
    locationService.locationPublisher
        .sink { [weak self] location in
            guard let self else { return }
            Task {
                await self.runningCenter.processLocation(location)
            }
        }
        .store(in: &cancellables)
}

func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.distance = data.distance
    }
}
```

View에서는 이렇게 호출한다.

```swift
.task {
    await runViewModel.startStream()
}
```

`.task`는 View가 나타날 때마다 이전 Task를 자동으로 취소하고 새로 시작하기 때문에 스트림이 중복으로 열리지 않는다.

수정 후 Swift Concurrency Instrument에서는 Task Continuation이 `RunWayApp.$main` 아래에 연결되는 것을 확인할 수 있었다. 이 프로젝트는 Swift 6 환경에서 Default Actor Isolation을 `MainActor`로 설정하고 있기 때문이다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/7c154faa-2f49-4e08-9ae7-273714d79b30.png" />

정리하면:

- `init` → 위치 업데이트를 받아 `RunningCenter`에 전달
- `startStream()` → `AsyncStream`을 구독하여 데이터를 수신
- `.task` → View가 화면에 표시될 때 스트림 시작

흐름도 달라졌다.

Before: `init` → 내가 직접 생성한 `Task` → stream 소비
After: `RunWayApp.$main` → SwiftUI `.task` → `MainActor` 격리 컨텍스트 → stream 소비

<img width="1536" height="1024" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-5/49eb78a6-be4c-46ae-93f1-bfa809bdf09a.png" />

스트림이 무한 증식하던 문제부터 시작해서 Sendable 에러를 거쳐 최종 구조까지 오는 과정을 한눈에 정리하면 위 만화와 같다.