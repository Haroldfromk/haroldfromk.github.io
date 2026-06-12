---
title: RunWay (10) Week 3 — GPS 페이스 보정과 GPWS 오작동 잡기
writer: Harold
date: 2026-06-11 08:33:00 +0900
categories: [RunWay]
tags: [CoreLocation, Combine, SwiftUI]

toc: true
toc_sticky: true
published: true
---

## 실기기 테스트 후 문제점 수정

어제 실기기 테스트에서 전반적인 동작은 예상보다 괜찮았다. 경로 좌표 저장, MapPolyline 표시, GPWS Alert annotation까지 의도한 대로 동작했다.

가장 큰 문제는 페이스였다. 

이제 문제점들을 하나하나 자료를 찾아보고 부득이하게 내힘으로 할 수 없는 부분은 AI에게라도 도움을 받아서 문제를 해결해보려 한다.

### 러닝 재시작 시 lastLocation nil 초기화 확인

실기기 테스트 중 러닝을 종료하고 재시작하면 첫 GPS 업데이트에서 거리가 비정상적으로 누적되는 현상이 발생했다. 1초 만에 100m 이상 뛰어버리는 식이다.

`reset()`에 `lastLocation = nil`이 이미 있음에도 이런 현상이 생긴 이유는 `resetState()`가 reset을 기다리지 않기 때문이다.

```swift
func resetState() {
    isRunning = false
    isModeA = false
    elapsedTime = 0
    tempAlertArray = []
    Task {  // 완료를 기다리지 않음
        await runningCenter.reset()
     } 
}
```

`Task { await runningCenter.reset() }`은 새 Task로 띄워지기 때문에 `resetState()`는 reset 완료 여부와 무관하게 즉시 리턴한다. 이 상태에서 빠르게 재시작하면 `lastLocation`이 아직 이전 값을 들고 있는 채로 `processLocation()`이 불려 거리가 누적된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/reset_race_before_v2.png){: width="50%" height="50%"}

즉 이 문제를 해결하려면 actor의 reset이 완전히 보장된 뒤에 `resetState`가 끝나야 한다.

해결책은 간단하다. `resetState()`를 `async`로 만들고 `runningCenter.reset()`을 `await`하면 된다.

```swift
func resetState() async {
    isRunning = false
    isModeA = false
    elapsedTime = 0
    tempAlertArray = []
    await runningCenter.reset()
}
```

`resetState()`가 async가 됐으니 이를 호출하는 `stop()`도 async로 바꾼다.

```swift
func stop() async {
    locationService.stopTracking()
    timerCancellable.removeAll()
    await resetState()
}
```

마지막으로 PFDView의 TOUCHDOWN 버튼에서 `stop()` 호출에 `await`를 붙인다.

```swift
Task {
    await saveRunningData()
    await runViewModel.stop()
    navigateToTouchdown = true
}
```

이제 `saveRunningData()` → `stop()` → `resetState()` → `runningCenter.reset()` 이 순서가 모두 await로 연결된다. 따라서 `runningCenter.reset()`이 완료되기 전에는 다음 단계로 진행할 수 없다.

이전에는 reset 작업을 별도 Task로 실행해 초기화 완료를 기다리지 않았지만, 수정 후에는 reset 완료가 보장된 뒤에만 다음 러닝을 시작할 수 있게 되었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/reset_race_after_v2.png){: width="50%" height="50%"}

아래 만화를 보면 훨씬 이해가 잘 될듯

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/reset.png){: width="50%" height="50%"}

ai로 생성된 이미지다 보니 거리튐의 글자가 깨진건 쩔수..

---

### ModeAView 버튼 simultaneousGesture 위치 수정

실기기 테스트에서 Mission Flight 진입 버튼이 꾹 눌러야만 동작하는 현상이 발견됐다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/before.gif){: width="50%" height="50%"}

시뮬레이터에서는 멀쩡히 탭으로 동작했기 때문에 실기기 테스트 전까지 발견하지 못했다.

원인을 보니 버튼처럼 생겼지만 사실 버튼이 아니었다.

```swift
NavigationLink(destination: TakeoffView()) {
    HStack(spacing: 8) {
        Image(systemName: "checklist")
        Text("PRE-FLIGHT CHECK")
    }
    // 생략
    .simultaneousGesture(TapGesture().onEnded({ _ in
        runViewModel.getModeData(modeAData)
    }))
}
```

`NavigationLink` 안에 `simultaneousGesture`를 넣어두면 `NavigationLink`의 제스처와 충돌해서 실기기에서 긴 press로만 인식된다. 해결책은 간단했다. `simultaneousGesture`를 `NavigationLink` 바깥으로 빼주면 된다.

```swift
NavigationLink(destination: TakeoffView()) {
    HStack(spacing: 8) {
        Image(systemName: "checklist")
        Text("PRE-FLIGHT CHECK")
    }
    // 생략
}
.simultaneousGesture(TapGesture().onEnded {
    let pace = Double(targetPaceMin * 60 + targetPaceSec) / 60.0
    let modeAData = ModeA(targetPace: pace, paceDeviation: paceDeviation, targetDistance: targetDistance)
    runViewModel.getModeData(modeAData)
})
```

탭 한 번에 바로 넘어간다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/after.gif){: width="50%" height="50%"}

---

### timestamp / horizontalAccuracy 필터 — 노이즈 위치 무시

[Vol.5 — How to filter locations](https://medium.com/how-to-track-users-location-with-high-accuracy-ios/make-it-even-better-than-nike-how-to-filter-locations-tracking-highly-accurate-location-in-774be045f8d6){:target="_blank"}를 읽다가 CoreLocation의 캐시 위치 문제를 알게 됐다.

GPS 신호가 나쁜 환경(흐린 날씨, 고층 빌딩 사이, 나무가 많은 공원 등)에서는 GPS 하드웨어가 위치를 얻지 못한다. 이때 CoreLocation은 신호가 좋았던 시점에 저장해둔 캐시 위치를 `didUpdateLocations`로 보낸다. 캐시 위치는 현재 사용자 위치가 아니기 때문에 그대로 처리하면 앱이 부정확하게 동작한다.

글에서는 `location.timestamp`와 현재 시간의 차이가 10초를 초과하는 위치는 무시하는 방식을 제안한다. 사람이 10초에 약 40m를 뛸 수 있기 때문에 이 필터 없이는 실제 위치보다 40m 뒤처진 위치가 표시될 수 있다.

RunWay에서도 같은 현상이 발생했다. 앱을 켜자마자 위치 추적이 자동으로 시작되는 구조라 러닝 시작 전에 이미 캐시 위치가 들어와 거리가 순간적으로 튀는 현상이 발견됐다.

그리고 내용을 읽다가 댓글에서 더 Swift스러운 방식을 제안한 코드를 발견했다.

```swift
extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        let filterdLocations = locations.filter {
            fabs($0.timestamp.timeIntervalSinceNow) <= 10 && // 오래된 캐시 위치 무시
            $0.horizontalAccuracy >= 0  &&                   // 유효하지 않은 좌표 무시
            $0.horizontalAccuracy <= 100                     // 정확도 낮은 위치 무시
        }

        filterdLocations.forEach {
            locationDataArray += [$0]
            notifiyDidUpdateLocation(newLocation: $0)
        }
    }
}
```

`filter`로 세 조건을 한 번에 처리하는 구조가 깔끔해서 이 방식을 참고해 RunWay에 적용해보려 한다.

현재 `didUpdateLocations`를 보면

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocations = locations.last {
        locationPublisher.send(lastLocations)
        latitude = lastLocations.coordinate.latitude
        longitude = lastLocations.coordinate.longitude
        accuracy = lastLocations.horizontalAccuracy
    }
}
```

위치 변화가 감지되는 즉시 그대로 전달하는 구조다. 

어떠한 필터링 없이 순수한 raw data가 그대로 들어가는데, 이 raw data에 항상 정확한 정보만 있다고 단정할 수 없다. 당시에는 미처 생각하지 못했던 부분이다.

그래서 우리 코드에 맞게 수정했다.

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let filterdLocations = locations.filter {
        fabs($0.timestamp.timeIntervalSinceNow) <= 10 && // 오래된 캐시 위치 무시
        $0.horizontalAccuracy >= 0  &&                   // 유효하지 않은 좌표 무시
        $0.horizontalAccuracy <= 50                      // 정확도 낮은 위치 무시
    }
    
    guard let location = filterdLocations.last else { return }
    locationPublisher.send(location)
    latitude = location.coordinate.latitude
    longitude = location.coordinate.longitude
    accuracy = location.horizontalAccuracy
}
```

달라진 점은 위치 데이터를 그대로 넘기는 대신 세 가지 조건으로 필터링해 노이즈 데이터를 걸러낸다는 것이다. 

원본 코드에서는 `NotificationCenter`로 위치를 실시간 스트림 했지만, RunWay는 `PassthroughSubject`를 통해 Combine 스트림으로 흘려보내는 구조라 그에 맞게 변경했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/filter.png){: width="50%" height="50%"}

---

### 앱 시작 시 위치 추적 자동 활성화 문제

이건 오늘 `simultaneousGesture` 기능까지 구현하고 확인겸 잠시 나갔다가 발견하게 된 부분이라 급하게 추가를 하였다.

![](/assets/images/upload/runninglocation.png){: width="50%" height="50%"}

앱을 켜자마자 위치 추적이 활성화되면서 `didUpdateLocations`이 바로 호출되기 시작한다.

이 상태에서 러닝을 시작하면 그 사이에 쌓인 위치 데이터가 그대로 `processLocation()`으로 넘어가 거리가 튀는 문제가 생긴다.

```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
        // 생략
        // 항상 허용 — 백그라운드 포함 수집 가능
    case .authorizedAlways:
        locationManager.startUpdatingLocation()
        break
        // 앱 사용 중 허용 — 정상 동작
    case .authorizedWhenInUse:
        locationManager.startUpdatingLocation()
        break
    default:
        break
    }
}
```

현재는 이렇게 앱을 켜자마자 `locationManagerDidChangeAuthorization`로 인해서 바로 
`locationManager.startUpdatingLocation()`이게 작동한다.

그래서 이부분을 전부 `break`로 처리하고 `startTracking`에서 호출하도록 한다.

```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            //생략
            // 항상 허용 — 백그라운드 포함 수집 가능
        case .authorizedAlways:
            break
            // 앱 사용 중 허용 — 정상 동작
        case .authorizedWhenInUse:
            break
        default:
            break
        }
    }

func startTracking() {
    locationManager.startUpdatingLocation()
    // 생략
}
```

`break`는 해당 케이스에서 아무것도 하지 않겠다는 의미다. Swift의 `switch`는 빈 케이스를 허용하지 않기 때문에 명시적으로 작성해야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/running.png){: width="50%" height="50%"}

---

### 신호 대기 자동 일시정지 기초 구현

전부터 필요하다고 생각했던 기능이다. 구현 우선순위에서 밀려있다가 이번에 함께 작업했다.

러닝 중 신호등 앞에서 멈추면 타이머와 위치 데이터가 계속 쌓인다. 이 상태에서 러닝을 재개하면 정지해있던 시간과 위치가 그대로 반영되어 페이스와 거리 데이터가 오염된다.

---

#### RunningCenter 수정

5초 이상 위치 변화가 없으면 자동으로 일시정지하는 방식으로 구현해보려 한다. `lastLocation`과 현재 위치의 거리가 2m 이하이고, timestamp 차이가 5초 이상이면 정지 상태로 판단한다. 

GPS 노이즈로 인해 제자리에 서있어도 좌표가 흔들릴 수 있기 때문에 오차는 2m로 잡았다.

```swift
private func detectPause(_ location: CLLocation) -> Bool  {
    guard let last = lastLocation else { return false }
    let distanceGap = location.distance(from: last)
    let timestampGap = location.timestamp.timeIntervalSince(last.timestamp)
    
    return distanceGap <= 2 && timestampGap >= 5 ? true : false
}
```

이렇게 코드를 작성해주었다.

그리고 true일때는 해당 기능이 작동하면 안되므로

```swift
func processLocation(_ location: CLLocation) {
    if detectPause(location) { return }
    
    // 생략
}
```

위와 같이 `Guard let` 느낌으로 코드를 작성해주었다.

`LocationService`에서 Combine을 통해 위치 정보가 실시간으로 `RunningCentor`에 전달되므로 `detectPause`는 매 업데이트마다 호출된다. 

정지 상태면 `true`를 반환해 처리를 건너뛰고, 다시 움직이면 `false`가 되어 정상적으로 위치값을 처리한다.

--- 

#### ViewModel 수정

이렇게 위치계산은 일시적으로 정지하나 타이머는 계속 흘러간다 왜냐면 Timer는 ViewModel에서 관리하기 때문이다.

---

##### 문제점

하지만 여기서 고민을 해야할 부분이 있다.

Actor의 경우 자체적으로 받아서 pause를 한다고 치자, 그렇다면 VM은 이걸 어떻게 감지하고 타이머를 정지시키냐는 것이다.

그렇다고해서 위에서 만든 `detectPause`를 사용 할 수도 없다.

```swift
func detectPauseFromActor() async -> Bool {
    return await runningCenter.detectPause()
}
```

`detectPause`에 파라미터 문제를 제외하더라도 가장 큰 문제는 `await`다. 

이 Task가 언제 완료될지 보장할 수 없기 때문에 `processLocation`이 멈추는 시점과 타이머가 멈추는 시점이 달라질 수 있다.

즉 둘의 멈추는 시점을 거의 일치화 하는게 이 문제를 해결할 키포인트 이다.

우선 Flow를 다시 한번 생각을 해본다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/flow.png){: width="50%" height="50%"}

이 Flow를 보면 VM은 순수하게 Actor(RunningCenter)의 Stream만을 기다리고 있다.

그리고 전달된 FlightData를 받아서 저장한다. 이 Data를 이용하여 각 View들은 UI를 Update하고 있다.

그렇다면 `detectPause`일때의 Flow는 어떻게 될까?

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/pause.png){: width="50%" height="50%"}

이런식으로 진행이 된다.

아래 VM의 보더 색이 없는 이유는 데이터를 받지 못한 비활성화 상태를 표현한 것이다.

이렇듯 VM은 업데이트가 없을 때 이를 감지해야 하는데, Actor를 통해 감지하면 위에서 언급했듯 `await` 때문에 딜레이가 발생할 수밖에 없다.

---

##### 해결책

현재 VM은 `startStream()`을 통해 `AsyncStream`으로 데이터를 전달받고 있다.

그렇다면 Actor에서 return으로 멈추기 보다 `detectPause`의 값을 FlightData에 같이 전달을 하는 방법이 어떨까 라는 생각이 들었다.

즉 detectPause에 따라 `processLocation`이 잠시 멈추더라도 fligtdata에 true/false값을 같이 흘러 보낸다면 VM은 어차피 AsyncStream을 상시 대기상태로 받고있기때문에, 그걸 감지해서 timer를 일시정지 하게 하면 되는것이다.

즉 flow를 다시 그려보면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/timerpause.png){: width="50%" height="50%"}

이렇게 되는 것이다.

---

그래서 `FlightData`를 수정한다.

```swift
struct FlightData {
    // 생략
    var isPaused: Bool = false
}
```

이렇게 isPaused를 추가해 주었다.

---

이제 Actor를 다시 수정해보도록 한다.

```swift
func processLocation(_ location: CLLocation) {
    let isPaused = detectPause(location)
    
    if isPaused {
        let flightData = FlightData(distance: totalDistance, phase: phase, pace: 0, altitude: 0, heading: 0, gpwsStatus: gpwsStatus, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, isPaused: isPaused)
        continuation?.yield(flightData)
    } else {
        // 생략
        let flightData = FlightData(distance: totalDistance, phase: phase, pace: rawPace, altitude: rawAltitude, heading: rawHeading, gpwsStatus: gpwsStatus, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, isPaused: isPaused)
        continuation?.yield(flightData)
    }
}
```

`detectPause`의 결과값을 `flightData`에 담아주었다.

처음에는 `guard let` 방식으로 `return`을 통해 이후 코드 블럭을 막는 방식을 썼지만, 여기서는 `if-else`로 각 조건에 따라 다르게 처리하도록 변경했다. 

두 방식 모두 같은 의도를 가지지만 구조가 다르다.

---

이제 VM에서 처리할 차례다.

```swift
func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
    }
}
```

`startStream()`에서 `FlightData`를 받는 시점에 `isPaused`를 확인해 타이머를 제어하면 된다.

물론 `await`와 `distanceFilter` 특성상 약간의 딜레이는 있을 수 있으나, 현재 구조에서 할 수 있는 최선의 방법이다.

그래서 

```swift
func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
        if data.isPaused {
            timerCancellable.removeAll()
        } else if isRunning && timerCancellable.isEmpty {
            timerPublisher
                .autoconnect()
                .sink { [weak self] _ in
                    self?.elapsedTime += 1
                }.store(in: &timerCancellable)
        }
    }
}
```

데이터를 받는 즉시 `isPaused`를 확인한다.

`true`면 `removeAll()`로 타이머 구독을 취소하고, 다시 `false`로 돌아왔을 때 러닝 중이면서 구독이 비어있는 상태라면 타이머를 새로 시작한다.

즉 정리해보면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/resumetree.png){: width="50%" height="50%"}

이렇게 별도의 재개하는 함수를 만들 필요없이 `startStream()`의 흐름 안에서 일시정지와 재개가 모두 처리된다.

이후 PFDView에도 일시정지 상태를 알리기 위해

```swift
if runViewModel.flightData.isPaused {
    Color.rwBg.opacity(0.85)
        .ignoresSafeArea()
    VStack(spacing: 8) {
        Image(systemName: "pause.circle.fill")
            .font(.system(size: 44))
            .foregroundColor(.rwAmber)
        Text("PAUSED")
            .font(.orbitron(20, weight: .bold))
            .foregroundColor(.rwAmber)
            .kerning(3)
    }
}
```

이렇게 코드를 추가로 작성했다.

smoothing 작업 전에 지금까지 구현한 기능들을 실기기로 먼저 검증하고 결과를 정리하도록 하겠다. 추가로 발견된 문제가 있다면 함께 기록할 예정

---

## 2차 실기기 테스트 결과

### 정상 동작 확인
- 앱 시작 시 위치 추적 자동 활성화 문제 해결
- MINIMUMS 정상 동작
- 경로 보정 정상 동작
- 방향 전환 시 페이스 튀는 현상 개선 (추가 테스트 필요)

### 발견된 문제
- 페이스가 10분대로 튀는 현상 지속 — smoothing 필요
- PAUSE 오버레이가 VStack 뒤에 가려짐 — ZStack 순서 수정 필요
- PAUSE 작동 안 함 — `distanceFilter` 조정 필요
- 러닝 종료 후 재시작 시 거리 40m 누적 — `flightData` 리셋 필요
- GPWS 알림 과도하게 발생 — smoothing으로 해결 예상

이렇게 확인이 되었다.

---

## 문제 수정하기

### 페이스 smoothing — IIR 필터 적용

timestamp/accuracy 필터를 적용했음에도 실기기 테스트에서 페이스가 여전히 튀는 현상이 발생했다. 필터가 잘못된 위치 데이터를 걸러내더라도 GPS 특성상 순간 속도 값 자체의 변동은 막을 수 없기 때문이다.

이 문제를 해결하기 위해 [Software Correction of Speed Measurement Determined by Phone GNSS Modules in Applications for Runners](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10007219/) 논문을 참고했다. 논문에서는 스마트폰 환경의 연산 비용을 고려해 FIR 필터 대신 2차 IIR 필터 2개를 직렬로 연결하는 방식을 제안한다.

```text
The proposed solution uses simple logic to establish the runner activity state and two IIR filters to correct the speed and acceleration calculated by the GNSS receiver. The effectiveness of the proposed method for amateur GNSS devices (sports watches and smartphones) has been verified by comparing the achieved results with professional GNSS signal recorders.
```

IIR 필터 수식은 [Apple 특허 US9597014](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9597014)에서 확인할 수 있다.

```text
In some implementations of the apparatus, the GPS data may be speed and the control logic may be configured to perform a data refinement process, in part, by determining the first refined data by smoothing the GPS data according to an Infinite Impulse Response (IIR) filtering model.

RS = (1 - β) × RSprev + β × S
```

- `RS` — 현재 보정된 속도
- `RSprev` — 이전 보정된 속도  
- `S` — 현재 GPS 속도
- `β` — smoothing 계수


러닝앱때문에 별걸 다 찾아보고 읽어본다...

여기선 그냥 저 수식을 사용해서 필터를 적용하면된다. 다만 더 나은 정확도를 위해 힘들더라도 2중 필터를 해보려고 한다.

2중 필터는 아래와 같다.

```text
RS1 = (1 - β) × RS1prev + β × S
RS2 = (1 - β) × RS2prev + β × RS1
```

---

#### IIR 필터 구현하기

이제 이걸 직접 Swift에서 구현해보려 한다.

식 자체는 크게 어렵지 않다. 수식을 그대로 코드로 옮기면 된다. 다만 가장 큰 고민은 β, 즉 smoothing 계수를 얼마로 설정하느냐였다.

---

##### β smoothing 계수 란?

β는 **"방금 들어온 GPS 속도를 얼마나 믿을 것인가"** 에 대한 신뢰도 값이다. 이 값 하나에 따라 페이스가 날뛰거나, 반대로 너무 굼떠지거나 둘 중 하나가 된다.

**β 값이 높을 때 — 반응은 빠르지만 노이즈에 취약**

현재 GPS 속도를 그대로 반영하는 세팅이다. 반응 속도는 빠르지만 GPS가 조금만 튀어도 페이스가 10분대, 20분대로 출렁거린다. 보정 전 앱의 상태가 바로 이랬다.

**β 값이 낮을 때 — 안정적이지만 반응이 느림**

새로 들어온 GPS 값을 일단 의심하고 과거 흐름을 더 많이 반영하는 세팅이다. GPS 노이즈에 흔들리지 않고 페이스가 안정적으로 유지된다. GPWS 오작동도 함께 잡힌다. 다만 갑자기 멈추거나 가속할 때 페이스가 즉각 반응하지 않고 슬금슬금 따라오는 지연이 생긴다.

결국 **반응 속도와 부드러움은 서로 트레이드오프 관계**다.

인간의 달리기 속도는 자동차처럼 급변하지 않기 때문에, 러닝 앱에서는 반응성을 조금 양보하더라도 노이즈를 확실히 잡아주는 낮은 β 값이 정석이다. 이 부분은 AI의 도움을 받아 정리했다.

---

다시 돌아와서 

```swift
actor RunningCentor {
    var smoothingSpeedFirst: Double = 0
    var smoothingSpeedSecond: Double = 0
}
```

이렇게 변수를 만들어 준다.

이제 필터공식을 적용한다. (AI 추천으로 계수는 0.15로 하였다.)

```swift
// processLocation 내부
smoothingSpeedFirst = 0.85 * smoothingSpeedFirst + 0.15 * location.speed
smoothingSpeedSecond = 0.85 * smoothingSpeedSecond + 0.15 * smoothingSpeedFirst
```

하지만 초기에는 0으로 시작하는데 이걸 그대로 적용하면 `smoothingSpeedFirst` 는 0.15 * location.speed의 값으로 들어가게 되어 오히려 더 느려지는 현상이 발생한다.

second는 (0.15*0.15) * location.speed가 되어버린다.

그래서 초기값이 0일때 보정이 필요하다.

```swift
if smoothingSpeedFirst == 0 {
    smoothingSpeedFirst = location.speed
    smoothingSpeedSecond = location.speed
}
smoothingSpeedFirst = 0.85 * smoothingSpeedFirst + 0.15 * location.speed
smoothingSpeedSecond = 0.85 * smoothingSpeedSecond + 0.15 * smoothingSpeedFirst

let rawPace = 1 / (smoothingSpeedSecond * 60 / 1000)
```

그러면 처음에 러닝할때만 

```
smoothingSpeedFirst = location.speed 가 된다.
(0.85 * location.speed + 0.15 * location.speed)
smoothingSpeedSecond = location.speed
(0.85 * location.speed + 0.15 * location.speed)
```

즉 rawPace에는 location.speed가 들어가게된다.

하지만 이후부터는 값이 바뀌면서 필터링이 되기 시작한다.

그리고 리셋할때는 당연히 새롭게 만든 두 값들도 초기화가 되어야 하므로

```swift
func reset() {
    totalDistance = 0
    smoothingSpeedFirst = 0
    smoothingSpeedSecond = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    isReachedPace = false
    modeAData = nil
}
```

이렇게 추가해 주었다.

---

### FlightData 리셋 문제

러닝을 종료하고 바로 재시작하면 이전 페이스가 UI에 잠깐 남아있다가 사라지는 현상이 발견됐다.

원인은 단순했다. `resetState()`에서 `flightData`를 초기화하지 않아 이전 러닝 데이터가 그대로 남아있었던 것이다.

```swift
func resetState() async {
    isRunning = false
    isModeA = false
    elapsedTime = 0
    tempAlertArray = []
    flightData = FlightData()
    await runningCenter.reset()
}
```

이렇게 모델 자체를 리셋해주었다. init이 필요없는건 애초에 초기값을 다 세팅해뒀기 때문.

---

### Pause 오버레이 ZStack 순서 수정

실기기 테스트에서 PAUSE 오버레이가 딱 한 번 보였는데, PFDView UI에 가려져 거의 보이지 않았다.

원인은 `ZStack` 순서 문제였다. PAUSE 오버레이가 `VStack` 앞에 선언되어 있어 UI 뒤에 깔리고 있었던 것이다.

```swift
// ❌ VStack 앞에 선언 — UI에 가려짐
if runViewModel.flightData.isPaused { ... }
VStack { ... }

// ✅ VStack 뒤에 선언 — UI 위에 덮임
VStack { ... }
if runViewModel.flightData.isPaused { ... }
```

---

### Pause가 제대로 되지 않던 문제 수정

멈춰있었지만 PAUSE가 작동하지 않았다. 원인을 파악하기 위해 두 AI에게 의견을 물어봤는데, 서로 다른 해결책을 제시했다.

**AI-A의 의견 — `distanceFilter = 0`**

업데이트를 매초 받아서 `detectPause`를 더 자주 체크하자는 방식이다. 이론적으로는 `timestampGap`이 1초 단위로 정확히 쌓여서 5초 감지가 더 세밀해진다.

**AI-B의 의견 — `distanceFilter = 10` + `distanceGap <= 4`**

GPS 드래프트로 인해 정지 상태에서도 좌표가 매초 2~5m씩 튀는데, `distanceFilter = 0`이면 이 노이즈가 매초 `RunningCenter`에 들어와 `distanceGap <= 2` 조건이 절대 충족되지 않는다. `distanceFilter = 10`으로 노이즈를 하드웨어 선에서 차단하고, `distanceGap` 임계값을 4m로 넓혀서 소프트웨어에서 2차로 잡자는 방식이다.

timestamp/accuracy 필터가 이미 적용되어 있어도 GPS 드래프트 자체는 막을 수 없다는 점에서 AI-B의 논리가 더 설득력 있었다. `distanceFilter = 10`, `distanceGap <= 4`로 적용했다. (이 내용은 AI가 작성했다.)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-11-RunningProject-10/compare.png){: width="50%" height="50%"}

이렇게 만화로 정리를 다시 해보았다.

---

하지만 이것이 정답이라는 보장은 없다.

`distanceFilter = 10`으로 설정한 만큼 들어오는 위치 업데이트 자체가 줄어든다. 러닝 중에는 약 10m 이동할 때마다 업데이트가 발생하므로 페이스 변화가 늦게 반영될 수 있고, 경로 좌표 역시 이전보다 듬성듬성 저장된다.

반대로 값을 너무 낮추면 GPS 노이즈가 그대로 들어와 PAUSE 감지가 어려워질 수 있다.

즉 노이즈를 줄이는 대신 업데이트 빈도가 감소하는 구조인 셈이다.

현재로서는 AI-B의 의견이 더 설득력 있다고 판단해 적용했지만, 실제로 어떤 값이 가장 적절한지는 계속 테스트해봐야 한다. 결국 실기기에서 직접 뛰어보면서 가장 안정적으로 동작하는 값을 찾아가는 수밖에 없다.
