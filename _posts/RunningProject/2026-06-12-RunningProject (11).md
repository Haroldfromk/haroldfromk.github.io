---
title: RunWay (11) Week 3 — 3차 실기기 테스트 & FlightPhase 복원
writer: Harold
date: 2026-06-12 08:33:00 +0900
categories: [RunWay]
tags: [CoreLocation, SwiftUI, DynamicIsland]

toc: true
toc_sticky: true
published: true
---

## 3차 간이 테스트 결과

`distanceFilter = 5`, `distanceGap <= 2`, β = 0.15 기본 세팅으로 걷기 + 100m 러닝을 간단히 테스트해봤다.

페이스 로딩이 너무 느렸고, 현재 페이스로 수렴하는 속도도 답답할 정도로 굼뜨게 반응했다.

β = 0.15가 과거 데이터를 85%나 유지하다 보니 새로운 속도 변화가 화면에 반영되기까지 시간이 너무 걸렸던 것이다.

AI 추천을 바탕으로 `distanceGap <= 4`, β = 0.25로 조정하기로 했다.

```swift
smoothingSpeedFirst = 0.75 * smoothingSpeedFirst + 0.25 * location.speed
smoothingSpeedSecond = 0.75 * smoothingSpeedSecond + 0.25 * smoothingSpeedFirst

return distanceGap <= 4 && timestampGap >= 5 ? true : false
```

위는 수정한 코드만 가져와봤다.

하지만 이것도 역시 슈퍼가면서 테스트해본 결과 되지 않았다.

그래서 이 부분에 대해 두 AI에게 의견을 물어봤다.

아래는 서로 반박한걸 다시 AI에게 정리를 하라고 한 내용이다.

---

**AI-B의 의견 — IIR 버리고 SMA(이동 평균 큐)로 전환 + 타임아웃 PAUSE**

AI-B는 30초 지연의 원인을 IIR 필터 자체의 구조적 한계로 진단했다. 초기값이 0인 상태에서 β = 0.25로 수렴하려면 수학적으로 10~15번 이상의 업데이트가 필요하고, `distanceFilter = 5` 환경에서는 그게 딱 30초에 해당한다는 것이다. 따라서 IIR을 버리고 최근 N개의 속도를 배열로 관리하는 SMA 방식으로 전환하고, PAUSE는 GPS 업데이트가 끊긴 지 5초가 지나면 자동 감지하는 타임아웃 방식을 제안했다.

**AI-A의 의견 — IIR 유지 + 초기값 처리 수정 + ViewModel 타임아웃 PAUSE**

AI-A는 IIR 자체의 문제가 아니라 초기값 처리의 허점이라고 반박했다. `location.speed`가 음수(-1)일 때도 초기화 조건을 통과해버리는 것이 문제이며, `max(speed, 0)`으로 음수를 보정하고 `speed > 0`일 때만 초기화하도록 수정하면 수렴 지연이 해결된다는 것이다. PAUSE는 Actor에 `await`로 매초 물어보는 대신 ViewModel이 마지막 데이터 수신 시각을 자체적으로 기록해 타이머 콜백에서 체크하는 방식을 제안했다.

**AI-B의 재반박**

AI-B는 ViewModel 타이머에서 매초 `await runningCenter.checkPauseTimeout()`을 호출하면 Actor 점유 문제로 데드락이 발생할 수 있다고 반박했다. 또한 `guard location.speed > 0`으로 데이터를 막아버리면 스트림이 끊겨 GPWS가 오작동할 수 있다고 지적했다.

**AI-A의 재반박**

AI-A는 Swift Actor의 `for await` 루프는 suspension point마다 Actor 점유를 해제하기 때문에 데드락이 발생하지 않는다고 반박했다. 또한 Actor를 전혀 호출하지 않고 ViewModel이 `lastReceivedTime`을 자체 변수로 관리하면 `await` 없이 타임아웃을 체크할 수 있어 구조적으로도 더 깔끔하다고 제안했다. `guard return`으로 스트림을 막는 대신 `max(speed, 0)`으로 음수만 보정해 흘려보내는 방식도 함께 제안했다.

**AI-B의 최종 인정**

Actor Reentrancy를 정확히 짚은 AI-A의 반박을 AI-B가 수용했다. 다만 초기값이 0일 때 `speed > 0` 조건 없이 초기화하는 허점은 여전히 남아있다고 지적했고, 최종적으로 두 AI의 의견이 수렴됐다.

---

**최종 결론**

- **Smoothing**: IIR 유지, `max(speed, 0)`으로 음수 보정, `smoothingSpeedFirst == 0 && speed > 0`일 때만 초기화
- **PAUSE**: ViewModel 타이머 콜백에서 `lastReceivedTime`을 자체 체크. Actor 호출 없이 5초 타임아웃으로 감지

이제 이 결론을 가지고 코드를 수정해본다.

---

### 1. Smoothing 수정하기

현재 IIR은 유지한 상태에서 `max(speed, 0)`으로 음수 보정, `smoothingSpeedFirst == 0 && speed > 0`일 때만 초기화하는 걸로 결론이 났으니 적용해보도록 한다.

`CLLocation.speed`는 GPS가 속도를 측정하지 못했을 때 `-1`을 반환한다. 실제로 음수로 이동하는 게 아니라 Apple이 "측정 불가" 상태를 나타내기 위해 정해둔 값이다. [Apple Developer Documentation — speed](https://developer.apple.com/documentation/corelocation/cllocation/speed){:target="_blank"}를 보면 이를 확인할 수 있다.

이 `-1`이 그대로 IIR 필터에 들어가면 `smoothingSpeedFirst`에 음수가 누적된다.

UI에는 `rawPace.isFinite && rawPace > 0` 조건으로 걸러져 표시되지 않지만, smoothing 변수 내부에는 음수 잔상이 쌓인 채로 있어서 이후 양수 speed가 들어와도 그 잔상을 털어내는 데 시간이 걸리게 된다. 

이게 초반 페이스 수렴이 느렸던 원인이었다.

---

다시 돌아와서 일단은 위의 내용들이 자기네들끼리 내린 결론이라 가이드가 필요해서 달라고 했다...

가이드는 아래와 같다.

1. `location.speed`를 `max(speed, 0)`으로 음수 보정
2. 기존 `if smoothingSpeedFirst == 0` 조건에 `&& speed > 0` 추가
3. smoothing 계산에서 `location.speed` → `speed` 변수로 교체
4. `rawPace` 계산은 그대로 `smoothingSpeedSecond` 기반으로 유지

---

이걸 기반으로 수정해본다. 
우선 음수 보정을 위해 변수를 하나 만든다. (CoreLocation은 speed가 -1로 들어오는 경우가 있어 이를 0으로 보정한다.)

```swift
let compensatedSpeed = max(location.speed, 0)
```

이후 조건을 추가하고, 코드 블럭 내부도 음수 보정된 속도값으로 바꿔준다.

```swift
if smoothingSpeedFirst == 0 && compensatedSpeed > 0 {
    smoothingSpeedFirst = compensatedSpeed
    smoothingSpeedSecond = compensatedSpeed
}
```

IIR 필터 계산식에도 동일하게 적용한다.

```swift
smoothingSpeedFirst = 0.75 * smoothingSpeedFirst + 0.25 * compensatedSpeed
smoothingSpeedSecond = 0.75 * smoothingSpeedSecond + 0.25 * smoothingSpeedFirst
```

종합하면 이 부분만 바뀐 것이다.

```swift
let compensatedSpeed = max(location.speed, 0)
            
if smoothingSpeedFirst == 0 && compensatedSpeed > 0 {
    smoothingSpeedFirst = compensatedSpeed
    smoothingSpeedSecond = compensatedSpeed
}

smoothingSpeedFirst = 0.75 * smoothingSpeedFirst + 0.25 * compensatedSpeed
smoothingSpeedSecond = 0.75 * smoothingSpeedSecond + 0.25 * smoothingSpeedFirst
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/smooth.png){: width="50%" height="50%"}

---

### 2. Pause 수정하기

이제 Pause도 수정한다. 기존에는 거리 기반으로 움직이지 않을 경우를 감지하려 했는데, GPS는 값이 튀기도 하고 filter나 gap으로 제대로 인식하기가 어렵다 보니 시간 기반으로 방향을 바꾸게 됐다. 사실 이건 AI들끼리 이야기를 나누기 전에 혼자 생각해봤던 방법이긴 했다.

이것도 자기네들끼리 나눈 대화이다 보니 가이드를 달라고 했다.

1. ViewModel에 `lastReceivedTime: Date = .now` 변수 추가
2. `startStream()`에서 데이터 받을 때마다 `lastReceivedTime` 업데이트
3. `start()`의 타이머 콜백에서 5초 이상 업데이트가 없으면 타이머 멈추기
4. 재개는 `startStream()`에서 데이터가 다시 들어올 때 `timerCancellable.isEmpty` 체크로 처리

---

가이드가 거의 답을 다 제시한 것 같긴 한데, 그래도 과정을 기록해본다.

먼저 마지막으로 데이터를 받은 시간을 기록할 변수를 만든다.

```swift
var lastReceivedTime: Date = .now
```

스트림으로 값을 받을 때마다 계속 업데이트되어야 하므로 `startStream()`에 추가한다.

```swift
func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
        lastReceivedTime = .now
        //생략
    }
}
```

이러면 스트림은 실시간으로 받긴 하지만, `distanceFilter = 5` 환경에서는 5m 이동했을 때만 위치 정보가 들어오므로 `lastReceivedTime`도 그 시점에 갱신된다.

그리고 `start()`의 타이머 콜백과 `startStream()`의 재개 타이머 콜백 둘 다 동일하게, 러닝 중이면서 5초 이상 업데이트가 없을 경우 구독을 취소해 타이머를 멈추게 한다.

```swift
func start() {
    isRunning = true
    isPaused = false
    locationService.startTracking()
    timerCancellable.removeAll()
    timerPublisher
        .autoconnect()
        .sink { [weak self] _ in
            guard let self else { return }
            elapsedTime += 1
            if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 5 {
                timerCancellable.removeAll()
                isPaused = true
            }
        }.store(in: &timerCancellable)
}
```

재개할 때는 데이터가 다시 들어오면 `timerCancellable.isEmpty`를 체크해서 타이머를 다시 시작한다. 이때도 5초 이상 업데이트가 없으면 다시 멈추도록 동일한 조건을 콜백 안에 넣어준다.

기존에 작성했던 `data.isPaused`는 이제 Actor에서 판단하는 방식이 아니기 때문에 지워준다. 관련된 `detectPause()` 함수와 `FlightData`의 `isPaused`도 함께 제거한다.

다만 PFDView에서 `flightData.isPaused`를 참조하던 부분이 에러가 나므로, ViewModel에 `isPaused` 플래그를 직접 관리해서 PFDView가 `runViewModel.isPaused`로 일시정지 뷰를 보여주도록 변경한다.

시작할 때는 `false`로 초기화, 5초 타임아웃 시 `true`, 데이터가 다시 들어오면 `false`로 되돌리는 구조다.

최종 수정 코드는 아래와 같다.

```swift
func start() {
    isRunning = true
    isPaused = false
    locationService.startTracking()
    timerCancellable.removeAll()
    timerPublisher
        .autoconnect()
        .sink { [weak self] _ in
            guard let self else { return }
            elapsedTime += 1
            if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 5 {
                timerCancellable.removeAll()
                isPaused = true
            }
        }.store(in: &timerCancellable)
}

func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
        lastReceivedTime = .now
        isPaused = false
        if timerCancellable.isEmpty {
            timerPublisher
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self else { return }
                    elapsedTime += 1
                    if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 5 {
                        timerCancellable.removeAll()
                        isPaused = true
                    }
                }.store(in: &timerCancellable)
        }
    }
}

func resetState() async {
    isRunning = false
    isModeA = false
    isPaused = false // new
    elapsedTime = 0
    tempAlertArray = []
    flightData = FlightData()
    await runningCenter.reset()
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/pause.png){: width="50%" height="50%"}

---

이렇게 보완을 했지만 또 실기기테스트를 해봐야 할 것 같다.

새벽에 간단하게 테스트 해본결과 일단은 페이스가 초반에 잘 되는걸 확인했다. 또한 퍼즈도 잘되었다. 움직일때 알아서 퍼즈가 풀리기도 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/test.gif){: width="50%" height="50%"}

다만 페이스의 정확도는 조금 더 알아볼 필요가 있어보인다.

그래서 베타값은 0.2로 바꾸어서 다시 테스트를 해볼 생각이다.

---

## LocationService 권한 거부 Alert 처리 (Combine PassthroughSubject)

현재 앱에서 에러 핸들링이 필요한 부분은 사실상 여기밖에 없다. 네트워크나 외부 API를 쓰지 않기 때문이다.

물론 이후 Watch 연동과 HealthKit을 사용하게 되면 추가 에러 핸들링이 필요하겠지만, 지금 당장은 LocationService의 `didFailWithError`와 `locationManagerDidChangeAuthorization`에서 콘솔로만 출력하던 부분을 Alert로 바꿔 사용자가 직접 알 수 있도록 한다.

---

### 모델링

[이전 글](https://haroldfromk.github.io/posts/MapKit-(3)/){:target="_blank"}의 Alert 방식을 착안하여 그대로 가져왔다.

```swift
struct AlertItem: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let dismissButton: Alert.Button
}

struct AlertContext {
    
    static let unableToGetLocations = AlertItem(
        title: Text("Location Error"),
        message: Text("Unable to retrieve your location.\nPlease try again."),
        dismissButton: .default(Text("OK"))
    )
    
    // 나머지도 같은 방식이라 생략
}
```

이걸 Combine을 통해 View로 전달해 사용자가 직접 확인할 수 있게 만들 것이다.

---

### LocationService 수정

기존에 `print`로만 처리하던 에러 케이스들을 수정한다.

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
    print(error)
}

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .restricted:
        print("Location access restricted")
    case .denied:
        print("Location access denied")
    }
}
```

우선 `PassthroughSubject`로 Publisher를 하나 만들어준다.

```swift
var alertPublisher = PassthroughSubject<AlertItem, Never>()
```

이후 각 케이스에서 `send()`로 해당 Alert를 흘려보낸다.

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
    alertPublisher.send(AlertContext.unableToGetLocations)
}

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .restricted:
        alertPublisher.send(AlertContext.restrictedGetAuthorization)
    case .denied:
        alertPublisher.send(AlertContext.deniedGetAuthorization)
    }
}
```

이렇게 보내는쪽의 준비는 끝이났다.

---

### ViewModel 수정

View가 직접적으로 구독을 하는게 아니라 VM에서 구독을하여 View로 다시 전달을 하는 방향으로 코드 작성을 해본다.

그게 지금까지 해온 방식이며, 앞으로도 고수할 방식이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/pipeflow.png){: width="50%" height="50%"}

그래서 여기서 구독을 하도록 한다.

VM객체가 생성되자마자 구독을 하는게 좋기때문에 `init()`을 사용해서 구독을 하도록한다.

```swift
var alertItem: AlertItem?
    
init() {
    // 생략
    locationService.alertPublisher
        .sink { [weak self] alert in
            guard let self else { return }
            self.alertItem = alert
        }
        .store(in: &cancellables)
}
```

이렇게 `alertItem`을 VM에서 관리하면 View는 단순히 `alertItem`이 세팅되는 걸 감지해서 Alert를 띄우기만 하면 된다. 에러 처리 로직이 VM에 집중되어 View가 깔끔해지는 구조다.

---

### View 수정

이제 View에서 받아서 처리하면 된다.

고민이 필요한 부분은 어느 View에서 Alert를 보여줄 것인가다.

`locationManagerDidChangeAuthorization`에서 발생하는 권한 에러는 앱 진입 시점에 발생하므로 `HomeView`에서 처리한다.

반면 `didFailWithError`는 위치 업데이트 도중 발생하는 에러다. `startUpdatingLocation()`이 호출되는 시점은 러닝 시작 이후이므로 `PFDView`에서 Alert를 처리하는 게 맞다.

하지만 예상치 못한 문제가 발생했다.

기존에 사용하던 [alert(item:content:)](https://developer.apple.com/documentation/swiftui/view/alert(item:content:)){:target="_blank"}가 Deprecated되었다. 새로운 [alert(_:isPresented:presenting:actions:message:)](https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:presenting:actions:message:)-29bp4){:target="_blank"}를 확인하니 방식이 바뀌면서 `AlertItem`의 `title`과 `message`도 `Text`가 아닌 `String`으로 변경이 필요하다.

#### 재수정 (모델, VM)

방식이 바뀌면서 모델도 수정이 필요하다.

```swift
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct AlertContext {
    
    static let unableToGetLocations = AlertItem(
        title: "Location Error",
        message: "Unable to retrieve your location.\nPlease try again."
    )
    // 생략
}
```

`dismissButton`을 제거하고 `title`, `message`를 `String`으로 변경했다.

VM에서는 `didError` 플래그를 추가해 Alert 트리거를 제어한다.

```swift
var didError = false

init() {
    // 생략
    locationService.alertPublisher
        .sink { [weak self] alert in
            guard let self else { return }
            self.alertItem = alert
            didError = true
        }
        .store(in: &cancellables)
}
```

`alertItem`이 세팅되는 동시에 `didError = true`로 바꿔 View의 `isPresented`를 트리거한다.

---

#### View 진짜 수정

우선 docs의 양식을 보고 그대로 차용한다.

```swift
.alert(runViewModel.alertItem?.title ?? "" ,
    isPresented: Bindable(runViewModel).didError,
    presenting: runViewModel.alertItem
) { details in
    Button("OK") {
        runViewModel.didError = false
    }
} message: { item in
    Text(item.message)
}
```

이때 `didError`가 `@State`가 아닌 일반 프로퍼티지만 `RunViewModel`이 `@Observable`을 준수하므로 `Bindable`을 사용할 수 있다.

[Bindable Docs](https://developer.apple.com/documentation/swiftui/bindable){:target="_blank"}를 보면 `@Observable`을 준수하는 데이터 모델 객체의 mutable 프로퍼티에 바인딩을 만들기 위해 사용하는 것이라고 나와 있다. 즉 `@State`나 `@Binding` 없이도 `Observable` 객체의 프로퍼티를 `$` 문법으로 바인딩할 수 있게 해주는 래퍼다.

docs의 예시는 대부분 `@Bindable var model: MyModel` 형태로 프로퍼티 래퍼를 직접 선언하는 방식이다. `HomeView`처럼 아직 `RunViewModel`을 많이 사용하지 않는 경우라면 이 방식도 가능하다.

하지만 `@Environment`처럼 이미 다른 방식으로 주입된 객체는 `@Bindable`을 다시 선언할 수 없다. `PFDView`가 바로 그 경우인데, 이미 여러 UI에서 `runViewModel`을 참조하고 있어 선언 방식을 바꾸기 어렵다.

이럴 때는 `Bindable(runViewModel).didError`처럼 인스턴스를 직접 감싸서 바인딩을 만드는 방식을 쓸 수 있다. 이후 HealthKit 연동 등 VM이 커질 것을 고려해 `HomeView`도 동일한 방식으로 통일했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/alerttest.gif){: width="50%" height="50%"}

그럼 이렇게 Alert가 잘 뜨는걸 알 수 있다.

---

## FlightPhase 5단계 복원 (takeoff, approach)

현재는 아래와 같이 3단계로만 관리하고 있다.

```swift
enum FlightPhase {
    case preflight
    case cruise
    case touchdown
}
```

사실 이 enum은 Week 2에서 만들어두었지만 실제로 쓰이지 않고 있었다. `FlightData`에 `phase`가 포함되어 있고 Actor에 `updatePhase()`도 있었지만, 어디서도 호출하는 곳이 없었던 것이다.

기능 구현을 우선하기 위해 3단계로 축소해뒀던 것인데, Dynamic Island 연동과 Watch 연동까지 생각하면 원래 계획대로 `takeoff`와 `approach`를 추가해야 할 시점이 됐다.

전환 시점을 정리하면, `takeoff`는 카운트다운이 시작되는 순간 전환되었다가 ROTATE 후 바로 `cruise`로 넘어간다. `approach`는 MINIMUMS가 트리거되는 시점에 함께 전환되며, ModeA에서만 사용된다. 유저가 종료하면 `touchdown`으로 바뀐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/flightphase_flow_v7.png){: width="50%" height="50%"}

```swift
enum FlightPhase {
    case preflight
    case takeoff
    case cruise
    case approach
    case touchdown
}
```

우선 이렇게 케이스를 추가해준다.

---

이제 어디서 추가할지에 대해 다시 포인트를 짚어보면

1. TakeoffView에서 러닝 시작 시 takeoff → 바로 cruise
2. RunningCentor의 MINIMUMS 트리거 시 approach
3. TOUCHDOWN 시 touchdown

이렇게 된다.

즉 Phase는 기존과는 다른 Flow를 가지게 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/phase_update_flow_v2.png){: width="50%" height="50%"}

이렇게 View에서 Phase를 전달하고 VM이 받아 Actor로 전달하는 구조다.

Phase 전환은 유저가 View에서 버튼을 누르는 시점에 트리거되기 때문이다.

---

### takeoff

러닝의 시작점이 어디인지를 생각해보면 `TakeoffView`의 카운트다운 버튼이다.

```swift
Button {
    startCountdown()
}
```

즉 `startCountdown()` 내부에서 phase를 변경해줘야 한다.

```swift
func startCountdown() {
    countdownActive = true
    countdownValue = 3
    for i in 0..<5 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
            if i < 3 {
                countdownValue = 3 - i
            }
            else if i == 3 {
                countdownValue = 0
            }
            else {
                countdownActive = false
                navigateToPFD = true
                runViewModel.start()
            }
        }
    }
}
```

카운트다운이 시작되는 시점(`i < 3`)에 `takeoff`로, ROTATE 후 러닝이 실제로 시작되는 시점(`else`)에 `cruise`로 전환하면 된다.

그러기 위해선 VM에 Actor로 전달할 함수를 하나 만들어준다.

```swift
func updatePhase(_ phase: FlightPhase) {
    Task {
        await runningCenter.updatePhase(phase)
    }
}
```

사실 `updatePhase()`는 Week 2에서 이미 만들어두었던 함수다. 당시 [RunWay (5) RunningCenter Actor](https://haroldfromk.github.io/posts/RunningProject-5/){:target="_blank"} 포스팅에서 기본 틀만 잡아두고 "실제 동작 분기는 이후에 채워나갈 예정"이라고 했었는데, 오늘이 바로 그 시점이다.

이제 View에서 연결해주자.

```swift
func startCountdown() {
    countdownActive = true
    countdownValue = 3
    for i in 0..<5 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
            if i < 3 {
                countdownValue = 3 - i
                runViewModel.updatePhase(.takeoff) // new
            }
            else if i == 3 {
                countdownValue = 0
            }
            else {
                countdownActive = false
                navigateToPFD = true
                runViewModel.updatePhase(.cruise) // new
                runViewModel.start()
            }
        }
    }
}
```

생략하기 애매해서 전체 코드를 가져왔다. 카운트다운 시작 시점에 `.takeoff`, ROTATE 후 `.cruise`로 전환된다.

---

### approach

`approach`는 ModeA에서만 사용된다. MINIMUMS가 트리거되는 시점이 바로 approach 진입 시점이므로 `PFDView`의 `onChange`에 조건을 추가해준다.

```swift
// before
.onChange(of: runViewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue {
        triggerGPWS(status)
        if status != .normal && status != .minimums {
            saveAlert()
        }
    }
}

// after
.onChange(of: runViewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue {
        triggerGPWS(status)
        if status == .minimums {
            runViewModel.updatePhase(.approach)
        }
        if status != .normal && status != .minimums {
            saveAlert()
        }
    }
}
```

---

### touchdown

러닝이 종료될 때 phase를 `touchdown`으로 바꿔주면 된다.

`PFDView`의 TOUCHDOWN 버튼에서 종료 처리를 하고 있으므로 여기에 추가한다. 순서를 보장하기 위해 `Task` 안에 함께 넣어준다.

```swift
// before
Button {
    Task {
        await saveRunningData()
        await runViewModel.stop()
        navigateToTouchdown = true
    }
}

// after
Button {
    Task {
        await saveRunningData()
        await runViewModel.stop()
        runViewModel.updatePhase(.touchdown)
        navigateToTouchdown = true
    }
}
```

---

### RunningCenter 수정하기

만들어뒀던 `updatePhase()`를 실제로 연결할 차례다.

```swift
func updatePhase(_ phase: FlightPhase) {
    self.phase = phase
}
```

하지만 여기서 문제가 생긴다. 현재 `FlightData`는 `processLocation()` 내부에서만 yield되는 구조라, `updatePhase()`를 호출해도 다음 위치 업데이트가 오기 전까지는 View에 반영되지 않는다.

Dynamic Island에서 실시간으로 반영하려면 즉각적인 업데이트가 필요하다. 그런데 그러자니 `FlightData` 전체를 건드려서 값을 전달해야 한다.

---

#### FlightData 모델 수정

여기서 의문이 생겼다. `FlightData`에 `phase`가 있어야 할 이유가 있는가?

View에서 받긴 하지만 실제로 `flightData.phase`를 참조하는 곳이 없다. Phase는 궁극적으로 Dynamic Island 연동에서 필요한 부분이고, Watch에서는 페이스나 거리 같은 러닝 데이터가 필요하지 phase를 구분해서 보여줄 이유가 없다.

결론적으로 `FlightData`에서 `phase`는 필요없다고 판단해 제거하기로 했다.

```swift
struct FlightData {
    var distance: Double = 0
    var pace: Double = 0
    var altitude: Double = 0
    var heading: Double = 0
    var gpwsStatus: GPWSState? = nil
    var latitude: Double = 0
    var longitude: Double = 0
}
```

---

#### Phase 실시간 스트림

##### Combine?

지금까지 Actor 외부의 실시간 스트림은 모두 Combine을 사용해왔다. Phase도 동일하게 적용해보려 했다.

```swift
var phasePublisher = PassthroughSubject<FlightPhase, Never>()

func updatePhase(_ phase: FlightPhase) {
    self.phase = phase
    phasePublisher.send(phase)
}
```

VM에서 이 스트림을 받아주려 했으나

```swift
var currentPhase: FlightPhase = .preflight

Task {
    await runningCenter.phasePublisher
        .sink { [weak self] phase in
            guard let self else { return }
            self.currentPhase = phase
        }
        .store(in: &cancellables)
}
```

```text
Non-Sendable type 'PassthroughSubject<FlightPhase, Never>' of property 'phasePublisher' cannot exit actor-isolated context
```

에러가 발생했다. 근본적인 원인은 `PassthroughSubject`가 `Sendable`을 준수하지 않기 때문이다. Actor 격리 컨텍스트 밖으로 꺼낼 수 없는 것이다.

---

##### AsyncStream 사용

기존에 `FlightData`를 Actor에서 VM으로 전달할 때 이미 AsyncStream을 사용하고 있으니 Phase도 동일한 방식으로 가기로 했다.

```swift
var phaseContinuation: AsyncStream<FlightPhase>.Continuation?

private func clearContinuation() {
    continuation = nil
    phaseContinuation = nil
}

func streamPhaseData() -> AsyncStream<FlightPhase> {
    AsyncStream<FlightPhase> { continuation in
        self.phaseContinuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.clearContinuation()
            }
        }
    }
}

func updatePhase(_ phase: FlightPhase) {
    self.phase = phase
    phaseContinuation?.yield(phase)
}
```

VM에서는 `init()`에서 바로 스트리밍을 열어준다. phase는 러닝 시작 전부터 변할 수 있기 때문이다.

```swift
init() {
    // 생략
    Task {
        for await data in await runningCenter.streamPhaseData() {
            self.currentPhase = data
        }
    }
}
```

러닝을 중단할 때 phase도 초기화해줘야 하므로 `reset()`에 추가한다.

```swift
// RunningCenter
func reset() {
    totalDistance = 0
    smoothingSpeedFirst = 0
    smoothingSpeedSecond = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    phase = .preflight
    isReachedPace = false
    modeAData = nil
}
```

---

##### 문제 발생?

phase 변화를 확인하기 위해 print를 추가하고 실행해봤는데 에러가 발생했다.

```swift
Task {
    for await data in await runningCenter.streamPhaseData() {
        self.currentPhase = data
        print(currentPhase)
    }
}
```

```text
Thread 1 Queue : com.apple.main-thread (serial)
```

알고 보니 `PFDView`를 수정하면서 `.onChange` 앞에 `.`을 빠뜨린 게 원인이었다. 빌드 에러 없이 통과했지만 크래시가 발생한 것이다.

점 하나를 추가하고 나서 출력이 정상적으로 됐다.

```text
takeoff
takeoff
takeoff
cruise
approach
touchdown
```

---

하지만 이걸로 해결된 게 아니었다.

러닝 종료 후 다시 `HomeView`에서 러닝을 시작하려고 하니 버튼이 작동하지 않았다. 혼자 해결하려 했지만 되지 않아 AI의 도움을 받았는데, 이마저도 계속 안 되거나 작동은 되지만 `NavigationStack` 계층 구조 경고 메세지가 뜨는 등 해결하는 데 꽤 오래 걸렸다.

이 부분에 대해 문제를 AI를 통해 작성하게 했다.

아랫부분이 AI가 작성한 내용이다.

---

원인은 두 가지가 복합적으로 작용한 것이었다.

첫째, `HomeView`에서 `Bindable(runViewModel).didError`로 VM 전체를 바인딩한 것이 문제였다. `@Observable` 객체를 `Bindable`로 감싸는 순간 SwiftUI는 해당 객체의 상태 변화 추적 범위를 넓히게 된다. 러닝 중에는 `flightData`, `elapsedTime`, `lastReceivedTime` 등이 1초마다 계속 바뀌는데, 화면에 보이지 않는 백그라운드 상태의 `HomeView`가 이 변화에 반응해 지속적으로 재렌더링을 시도하고 있었던 것이다. 이 상태에서 `AppState.shared.reset()`으로 `sessionID`를 바꿔 뷰를 강제 재생성하면 `NavigationStack` 내부 상태가 꼬여 버튼이 먹통이 되었다.

둘째, `AppState.sessionID` 방식 자체의 구조적 한계였다. 이 방식은 뷰 컨테이너를 통째로 파괴하고 새로 만드는 방식인데, 화면 전환 애니메이션이 완전히 끝나기 전에 부모 뷰가 사라지면서 SwiftUI 내부에서 Race Condition이 발생했다.

기존 방식과 새로운 방식을 비교하면 아래와 같다.

| | 기존 (`AppState.sessionID`) | 새로운 (`NavigationPath`) |
|---|---|---|
| 홈 복귀 방법 | `sessionID` 변경 → 뷰 강제 파괴 후 재생성 | `navigationPath = []` → 스택 선언형 초기화 |
| 화면 전환 | 각 View의 `@State Bool` 플래그 | `navigationPath.append()` |
| 문제점 | 애니메이션 도중 부모 뷰 파괴 → Race Condition | 없음 |
| 아키텍처 | 두 개의 상태 제어 주체 (`sessionID` + `@State`) | 단일 파이프라인 (`navigationPath`) |

최종 해결책은 `AppState` 방식을 완전히 걷어내고 `[FlightDestination]` 열거형 배열 하나로 전체 네비게이션을 단일 파이프라인으로 관리하는 것이었다. `NavigationStack(path:)`에 이 배열을 바인딩해두면, `resetState()`에서 배열을 비우는 것만으로 SwiftUI가 선언형으로 루트인 `HomeView`까지 자동 복귀시켜 준다. 뷰를 강제로 파괴할 필요가 없으니 타이밍 충돌도 원천적으로 사라진다.

```swift
// RunViewModel
var navigationPath: [FlightDestination] = []

func resetState() async {
    // ... 기존 초기화 ...
    await runningCenter.reset()
    navigationPath = [] // 배열을 비우면 HomeView(Root)로 자동 복귀
}
```

```swift
// HomeView
NavigationStack(path: $vm.navigationPath) {
    // ...
    .navigationDestination(for: FlightDestination.self) { destination in
        switch destination {
        case .modeA:     ModeAView()
        case .takeoff:   TakeoffView()
        case .pfd:       PFDView()
        case .touchdown: TouchdownView()
        case .summary:   FlightSummaryView(selectedFlight: nil)
        }
    }
}
```

각 View에서의 화면 전환은 `runViewModel.navigationPath.append()`로, 홈 복귀는 `resetState()`의 `navigationPath = []`로만 처리하는 단일 파이프라인 구조가 완성되었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/aisolution.png){: width="50%" height="50%"}

---

## Dynamic Island FlightPhase 연동

미리 준비한 UI를 활용해 연동하려고 한다.

우선 Widget Extension 타겟을 추가한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/widget.png){: width="50%" height="50%"}

타겟 추가 시 반드시 Live Activity를 체크해야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/liveact.png){: width="50%" height="50%"}

그리고 iPhone 앱 타겟의 `Info.plist`에 아래 키를 추가해야 한다. 추가하지 않으면 `Activity.request()`가 항상 실패한다.

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-12-RunningProject-11/plist.png){: width="50%" height="50%"}

---

에러가 하나 발생했다. `FlightActivityService`의 `update()` 내부에서 `activity?.update()`를 호출할 때 Race Condition 경고가 떴다.

```swift
func update(with newState: FlightActivityAttributes.ContentState) async {
    let activity = self.activity
    await activity?.update(.init(state: newState, staleDate: nil))
}
```

`Activity` 타입 자체가 non-Sendable이라 로컬 복사로도 해결이 안 됐고, `@preconcurrency import ActivityKit`으로 해결했다. Dynamic Island UI를 AI에게 맡긴 만큼 어쩔 수 없는 선택이었다.

그러다보니 Dynamic Island UI와 기본기능은 이미 완성된 상태였다. 

그래서 지금은 UI보다 연동에 집중하기로 했다.

---

### 연동 순서

Dynamic Island와 연동할 포인트를 먼저 정리했다.

1. `start()` → `startActivity()`
2. `startStream()`에서 `flightData` 받을 때 → `updateCruise()`
3. `TakeoffView` 카운트다운 → `updateTakeoff()`
4. `PFDView` GPWS 트리거 → `updateGPWS()`, `clearGPWS()`
5. MINIMUMS → `updateApproach()`
6. `stop()` → `endActivity()`

---

### 1. startActivity()

`start()`가 호출되는 시점이 러닝 시작이므로 여기서 Live Activity를 시작한다. ModeA라면 미션명과 목표 페이스를, ModeB라면 "FREE FLIGHT"와 기본값을 넘긴다.

`getModeData()`에서 Actor에 데이터를 넘길 때 VM에도 함께 저장해두어야 `start()` 시점에 `modeAData`를 참조할 수 있다.

```swift
var modeAData: ModeA?

func getModeData(_ data: ModeA) {
    isModeA = true
    modeAData = data
    Task {
        await runningCenter.setModeAData(data)
    }
}

func start() {
    isRunning = true
    isPaused = false
    locationService.startTracking()
    timerCancellable.removeAll()
    let missionName = isModeA ? "MISSION FLIGHT" : "FREE FLIGHT"
    let targetPace = isModeA ? PaceFormatter.format(modeAData?.targetPace ?? 0) : "--'--\""
    flightActivityService.startActivity(missionName: missionName, targetPace: targetPace)
    // 생략
}
```

---

### 2. updateCruise

Dynamic Island에 실시간 데이터를 전달하는 함수다.

`startStream()`에서 `flightData`를 받을 때마다 `updateCruise()`를 호출해 페이스와 거리를 업데이트한다.

```swift
func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
        lastReceivedTime = .now
        isPaused = false
        Task {
            await flightActivityService.updateCruise(
                pace: PaceFormatter.format(data.pace),
                distance: data.distance,
                heartRate: 0
            )
        }
        // 생략
    }
}
```

`await`로 직접 호출하면 업데이트가 끝날 때까지 다음 데이터를 받지 못하므로 `Task`로 분리해 스트림이 블로킹되지 않도록 했다.

---

### 3. updateTakeoff

카운트다운 시 Dynamic Island도 함께 카운트되도록 연동한다.

`TakeoffView`의 카운트다운 로직에 추가해주면 된다.

```swift
if i < 3 {
    countdownValue = 3 - i
    runViewModel.updatePhase(.takeoff)
    Task {
        await runViewModel.flightActivityService.updateTakeoff(countdownValue: 3 - i)
    }
}
```

`flightActivityService`가 `private`으로 선언되어 있어 View에서 접근이 불가능했기 때문에 지워주었다.

---

### 4. updateGPWS, clearGPWS, updateApproach

`PFDView`의 GPWS 상태 변화를 감지하는 `onChange`에 Dynamic Island 업데이트를 함께 연동한다. 상태에 따라 세 가지로 분기한다.

- `.normal`: GPWS 해제 → `clearGPWS()`로 Dynamic Island를 정상 상태로 복귀
- `.minimums`: `approach` phase 전환 + `updateApproach()`로 50m 남은 것을 표시
- `.sinkRate`, `.overspeed`: Alert 저장 + `updateGPWS()`로 경고 상태 표시

```swift
.onChange(of: runViewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue {
        triggerGPWS(status)
        switch status {
        case .normal:
            Task {
                await runViewModel.flightActivityService.clearGPWS()
            }
        case .minimums:
            runViewModel.updatePhase(.approach)
            Task {
                await runViewModel.flightActivityService.updateApproach(remainingMeters: 50)
            }
        case .sinkRate, .overspeed:
            saveAlert()
            Task {
                await runViewModel.flightActivityService.updateGPWS(type: status)
            }
        }
    }
}
```

---

### 5. updateTouchdown

`PFDView`의 TOUCHDOWN 버튼을 누르는 시점의 `flightData`를 Dynamic Island에 전달한다.

`stop()`이 호출되면 `resetState()`에서 데이터가 초기화되기 때문에, `stop()` 이전에 미리 값을 캡처해두는 것이 핵심이다.

```swift
Button {
    Task {
        let distance = runViewModel.flightData.distance / 1000
        let time = PaceFormatter.secondToTime(runViewModel.elapsedTime)
        let avgPace = PaceFormatter.format((Double(runViewModel.elapsedTime) / 60) / (runViewModel.flightData.distance / 1000))
        await saveRunningData()
        await runViewModel.stop()
        runViewModel.updatePhase(.touchdown)
        await runViewModel.flightActivityService.updateTouchdown(
            distance: distance,
            elapsedTime: time,
            avgPace: avgPace
        )
        runViewModel.navigationPath.append(.touchdown)
    }
}
```

---

### 6. endActivity

Dynamic Island를 종료한다.

TOUCHDOWN 직후보다 `FlightSummaryView`에서 GO TO DECK을 누를 때 종료하는 게 자연스럽다고 판단했다. 러닝 결과를 확인하는 동안 Dynamic Island에 최종 기록이 유지되기 때문이다.

```swift
Button {
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

`resetState()` 이전에 `endActivity()`를 먼저 호출해야 한다. `resetState()`가 실행되면 `navigationPath`가 비워지면서 홈으로 복귀하는데, 그 전에 Live Activity를 정리해주는 순서가 맞다.

---

이렇게 각 포인트에 연동을 마쳤다.

다만 셋업 과정에서 몇 가지 문제가 있었다.

첫째, `startActivity()`를 `start()` 안에서 호출하고 있었는데, `TakeoffView`의 카운트다운 시작 시점에 먼저 호출해야 카운트다운과 Dynamic Island가 동기화된다는 것을 뒤늦게 파악했다. `start()`에서 호출을 제거하고 `startCountdown()` 안으로 옮겼다.

둘째, `start()` 호출 시 `lastReceivedTime`을 리셋하지 않아 출발하자마자 PAUSE가 되는 문제가 있었다. `lastReceivedTime = .now`를 `start()` 첫 줄에 추가해서 해결했다.

셋째, 앱 재실행 후 이전 Live Activity가 시스템에 남아 있어 `visibility` 에러로 새 Activity 시작이 실패하는 경우가 있었다. `startActivity()` 앞에 기존 Activity를 먼저 종료하는 코드를 추가하고, `RunViewModel`의 `init()`에서도 앱 시작 시 정리하도록 했다.

```swift
// init()
Task {
    for activity in Activity<FlightActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}

// startActivity
func startActivity(missionName: String, targetPace: String) async {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
        print("⚠️ Live Activities 비활성화됨")
        return
    }
    for act in Activity<FlightActivityAttributes>.activities {
        await act.end(nil, dismissalPolicy: .immediate)
    }
    // 생략
}
```

실내에서 간단히 테스트해봤으나 GPS 데이터가 느리게 잡혀 cruise 전환 확인은 실외 테스트가 필요하다.

---

## 간단하게 테스트 후 발견한 문제

- Dynamic Island 에서 km인데 실제 숫자의 단위는 m를 기준으로 표시
    - `updateCruise()`에서 `distance`를 미터로 넘기고 있었는데, Dynamic Island UI는 km 기준으로 표시하고 있었다. `/1000`으로 변환해서 전달하도록 수정했다.

```swift
Task {
    await flightActivityService.updateCruise(
        pace: PaceFormatter.format(data.pace),
        distance: data.distance / 1000, // modified
        heartRate: 0
    )
}

case .cruise:
    // 거리
    VStack(spacing: 1) {
        Text("DISTANCE")
            .font(.system(size: 8))
            .foregroundColor(.white.opacity(0.5))
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(String(format: "%.2f", state.distance))
                // 생략
        }
    }
```

---

- GPWS 조건에 만족해야만 MINIMUMS도 트리거됨
    - 기존 코드에서 `isReachedPace`가 `false`면 `calculateGPWSStatus()` 자체를 호출하지 않아 MINIMUMS도 울리지 않는 문제가 있었다. MINIMUMS는 거리 기반이라 페이스 도달 여부와 무관하게 트리거되어야 하므로 별도로 분리했다.

```swift
// processLocation
let targetDistanceM = modeAData?.targetDistance ?? 0 * 1000
if totalDistance >= targetDistanceM - 50 && totalDistance < targetDistanceM {
    gpwsStatus = .minimums
} else if isReachedPace {
    gpwsStatus = calculateGPWSStatus(rawPace)
} else {
    gpwsStatus = .normal
}
```