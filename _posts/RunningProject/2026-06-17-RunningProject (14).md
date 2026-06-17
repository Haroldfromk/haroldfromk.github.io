---
title: RunWay (14) 문제점 수정 & 일시정지
writer: Harold
date: 2026-06-17 08:33:00 +0900
#last_modified_at: 2026-06-15 08:33:00 +0900
categories: [RunWay]
tags: [watchOS, WatchConnectivity, HealthKit]

toc: true
toc_sticky: true
published: true
---

## 문제점 수정하기

3차 간이테스트를 통해 실기기를 테스트한 결과 아래와 같은 문제점들이 발견되었다.

1. transferUserInfo 거리 단위 오류 (m 단위로 저장됨)
2. transferUserInfo 좌표 배열 미전송 (Summary 경로 미표시)
3. Watch/iPhone PFD 표시값 불일치 및 종료 동기화 미작동 (SwiftData 중복 저장)
4. iPhone 심박, 케이던스 미표시 
5. PFD 자동 전환 간헐적 미작동
6. Watch PFD 데이터 간헐적 수신 실패

빠르게 해결할 수 있는 것부터 순서대로 하나씩 수정해본다.

---

### transferUserInfo (1, 2 Case) 해결하기

1, 2번은 같이 묶어서 해결하는 게 좋아 보인다.

![](/assets/images/upload/IMG_3947.png){: width="50%" height="50%"}

테스트 중 찍었던 스크린샷이다. 321.72km라고 표시되어 있는데, 이게 거리 단위가 m로 저장된 채 그대로 표시된 것이다. 
그리고 지도에 아무것도 표시되지 않는 것을 보면, 좌표가 없을 때를 대비해 만들어두었던 옵셔널 처리 분기가 그대로 노출된 것을 확인할 수 있다.

---

거리 먼저 해보도록 한다.

현재 앱자체에서 swiftdata로 저장할때는 

```swift
// PFDView
func saveRunningData() async {
    let totalDistance = runViewModel.flightData.distance / 1000
    // 생략
}
```

이렇게 1000을 나누어서 km단위로 변환을 해주고 있는 반면 didReceiveUsrInfo를 통해 워치에서 받은 데이터는

```swift
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard let mode = userInfo["mode"] as? String,
        let distance = userInfo["distance"] as? Double,
        // 생략

    let vm = viewModel
    Task { @MainActor in
        let flight = SwiftDataFlight(
            mode: mode,
            distance: distance,
            time: time,
            // 생략
        )
        vm?.pendingWatchData = flight
    }
}
```

이렇게 변환없이 미터 단위로 들어가는걸 알 수 있다.

그래서 데이터를 받아 모델에 저장할때

```swift
distance: (distance / 1000),
```

이렇게 1000을 나눠 주는걸로 고쳐주었다.

---

워치에서 러닝 종료 후 경로가 지도에 나타나지 않는 이유도 같은 곳에서 찾을 수 있다. `PFDView`의 `saveRunningData()`를 보면 된다.

```swift
for (index, coord) in coords.enumerated() {
    let coordinate = SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: index)
    runningData.coordinates.append(coordinate)
}
runningData.alerts.append(contentsOf: totalAlerts)
```

애초에 워치 단독 러닝에서는 이 로직 자체가 거치지 않으므로 좌표 배열이 담기지 않는다.

`alerts` 코드도 함께 언급한 이유는, 지금 좌표만 수정해도 GPWS 경고를 저장해 지도에 Annotation으로 표시하는 부분이 여전히 누락되어 있기 때문이다.

이제 워치 시점에서 보면 `sendRunningData()` 코드를 보면 된다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    let userInfo: [String: Any] = [
        "mode": viewModel?.isModeA == true ? "modeA" : "modeB",
        "distance": viewModel?.flightData.distance ?? 0,
        "time": viewModel?.elapsedTime ?? 0,
        "pace": viewModel?.flightData.pace ?? 0,
        "heartRate": viewModel?.healthData.heartRate ?? 0,
        "cadence": viewModel?.healthData.cadence ?? 0,
        "activeEnergy": viewModel?.healthData.activeEnergy ?? 0,
        "date": Date().timeIntervalSince1970
    ]
    session.transferUserInfo(userInfo)
}
```

여기엔 `flightData`의 기본적인 정보만 전달되고 있다. 러닝이 끝나고 담긴 최종 데이터이지만, 좌표와 alerts는 어디에도 보이지 않는다.

워치에서 이 함수가 어느 시점에 호출되는지 확인해보면 `WatchSummaryView`에서 `resetState()`가 호출될 때다.

즉 앱의 `PFDView`처럼 단순히 `flightData`만 보내는 게 아니라, `SwiftDataFlight` 형태로 좌표와 alerts까지 함께 담아서 보내는 방향으로 바꿔주어야 한다.

우선 앱과 동일하게 WatchPFDView에서도 아래와 같이 함수를 구현해주었다.

```swift
// WatchPFDView
func saveAlert() {
    let currentPace = viewModel.flightData.pace
    let currentDistance = viewModel.flightData.distance
    let currentGpws = viewModel.flightData.gpwsStatus?.rawValue ?? "normal"
    let currentLatitude = viewModel.flightData.latitude
    let currentLongitude = viewModel.flightData.longitude
    
    let gpwsAlert = SwiftDataAlert(gpwsState: currentGpws, pace: currentPace, distance: currentDistance, timestamp: .now, latitude: currentLatitude, longitude: currentLongitude)
    viewModel.tempAlertArray.append(gpwsAlert)
}

func saveRunningData() async {
    let totalDistance = viewModel.flightData.distance / 1000
    let totalTime = viewModel.elapsedTime
    let totalPace = (Double(totalTime) / 60) / totalDistance
    let mode = viewModel.isModeA ? "modeA" : "modeB"
    let coords = await viewModel.getCoordinates()
    let totalAlerts = viewModel.tempAlertArray
    let hr = Int(viewModel.healthData.heartRate)
    let cad = Int(viewModel.healthData.cadence)
    let fuel = Int(viewModel.healthData.activeEnergy)
    
    let runningData = SwiftDataFlight(mode: mode, distance: totalDistance, time: totalTime, pace: totalPace, heartRate: hr, cadence: cad, fuel: fuel, date: .now)
    
    for (index, coord) in coords.enumerated() {
        let coordinate = SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: index)
        runningData.coordinates.append(coordinate)
    }
    runningData.alerts.append(contentsOf: totalAlerts)
    
    viewModel.pendingFlightData = runningData
}

// VM
var pendingFlightData: SwiftDataFlight?
```

기본적으로는 WatchVM도 RunVM의 코드를 대부분 차용해서 겹치는 부분이 많다.

다만 워치에선 건강정보를 바로 받으므로 health쪽은 버퍼대신 직접 가져오게 하고, 또한 vm에 임시로 담아둘 모델이 필요해서 `pendingFlightData`를 만들어 주었다.

그리고 리셋 할때 다시 nil로 초기화 해주었다.

```swift
func resetState(navigation: NavigationViewModel) async {
    // 생략
    pendingFlightData = nil
    navigation.reset()
}
```

이제 WatchPFDView에 적용을 해주면 된다.

적용할 부분은 2군데이다.

```swift
onEndFlight: {
    Task {
        await saveRunningData()
        viewModel.updatePhase(.touchdown)
        await viewModel.stop()
        navigation.navigateTo(.touchdown)
    }
}

.onChange(of: viewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue, status != .normal && status != .minimums {
        saveAlert()
    }
}
```

러닝이 종료될 때 러닝 정보를 저장하는 것과, `gpwsStatus`의 값이 바뀔 때마다 이를 감지해서 alert를 저장하는 부분이다.

`flightData`가 `@Observable`이기 때문에 값이 바뀔 때마다 GPWS 오버레이는 이미 자동으로 표시되고 있었지만, `saveAlert()` 호출이 빠져 있었던 것이다.

이제 `sendRunningData`를 수정해야한다. SwiftDataFlight 모델에 맞게끔 데이터를 더 추가해주어야 하기 때문이다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    guard let flight = viewModel?.pendingFlightData else { return }
    
    let coordinates = flight.coordinates
        .sorted { $0.order < $1.order }
        .map { [$0.latitude, $0.longitude] }
    
    let alerts = flight.alerts.map { alert in
        [
            "gpwsState": alert.gpwsState,
            "pace": alert.pace,
            "distance": alert.distance,
            "timestamp": alert.timestamp.timeIntervalSince1970,
            "latitude": alert.latitude,
            "longitude": alert.longitude
        ] as [String: Any]
    }
    
    let userInfo: [String: Any] = [
        "mode": flight.mode,
        "distance": flight.distance,
        "time": flight.time,
        "pace": flight.pace,
        "heartRate": flight.heartRate,
        "cadence": flight.cadence,
        "activeEnergy": flight.fuel,
        "date": Date().timeIntervalSince1970,
        "coordinates": coordinates,
        "alerts": alerts
    ]
    session.transferUserInfo(userInfo)
}
```

이때 `coordinates`, `alerts`는 자체적으로 여러 값을 들고 있는 구조이기 때문에 `map`을 통해 1차 가공을 먼저 해주고, 그 다음 `userInfo`에 담아서 보내야 한다.

그리고 `saveRunningData()`에서 `let totalDistance = viewModel.flightData.distance / 1000`로 이미 단위 변환을 해주었기 때문에, 앱의 `didReceiveUserInfo`에서는 다시 1000으로 나누는 부분을 원래대로 돌려놓는다.

```swift
// Before
distance / 1000
// After
distance
```

그리고 좌표와 alerts를 받는 쪽인 앱의 `didReceiveUserInfo`도 함께 수정해야 한다. 보낼 때 `[[Double]]`, `[[String: Any]]` 형태로 직렬화했으니 받을 때도 동일하게 파싱해서 `SwiftDataFlight`에 채워줘야 한다.

```swift
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    guard let mode = userInfo["mode"] as? String,
            let distance = userInfo["distance"] as? Double,
            let time = userInfo["time"] as? Int,
            let pace = userInfo["pace"] as? Double,
            let heartRate = userInfo["heartRate"] as? Double,
            let cadence = userInfo["cadence"] as? Double,
            let activeEnergy = userInfo["activeEnergy"] as? Double,
            let dateInterval = userInfo["date"] as? Double else { return }

    let coordinatesRaw = userInfo["coordinates"] as? [[Double]] ?? []
    let alertsRaw = userInfo["alerts"] as? [[String: Any]] ?? []

    // Parse raw dictionaries into Sendable tuples before crossing isolation boundary
    let parsedCoordinates: [(latitude: Double, longitude: Double, order: Int)] = coordinatesRaw.enumerated().compactMap { index, coord in
        guard coord.count == 2 else { return nil }
        return (latitude: coord[0], longitude: coord[1], order: index)
    }

    let parsedAlerts: [(gpwsState: String, pace: Double, distance: Double, timestamp: Double, latitude: Double, longitude: Double)] = alertsRaw.compactMap { alertDict in
        guard let gpwsState = alertDict["gpwsState"] as? String,
                let pace = alertDict["pace"] as? Double,
                let distance = alertDict["distance"] as? Double,
                let timestamp = alertDict["timestamp"] as? Double,
                let latitude = alertDict["latitude"] as? Double,
                let longitude = alertDict["longitude"] as? Double else { return nil }
        return (gpwsState: gpwsState, pace: pace, distance: distance, timestamp: timestamp, latitude: latitude, longitude: longitude)
    }

    let vm = viewModel
    Task { @MainActor in
        let flight = SwiftDataFlight(
            mode: mode,
            distance: distance,
            time: time,
            pace: pace,
            heartRate: Int(heartRate),
            cadence: Int(cadence),
            fuel: Int(activeEnergy),
            date: Date(timeIntervalSince1970: dateInterval)
        )

        for coord in parsedCoordinates {
            let coordinate = SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: coord.order)
            flight.coordinates.append(coordinate)
        }

        for alert in parsedAlerts {
            let swiftDataAlert = SwiftDataAlert(
                gpwsState: alert.gpwsState,
                pace: alert.pace,
                distance: alert.distance,
                timestamp: Date(timeIntervalSince1970: alert.timestamp),
                latitude: alert.latitude,
                longitude: alert.longitude
            )
            flight.alerts.append(swiftDataAlert)
        }

        vm?.pendingWatchData = flight
    }
}
```

`[[Double]]`로 보낸 좌표는 `coord[0]`이 위도, `coord[1]`이 경도이므로 순서를 맞춰서 꺼내야 한다.

다만 `[[String: Any]]` 형태의 `alertsRaw`를 그대로 `Task { @MainActor in }` 클로저 안에서 쓰면 data race 경고가 발생한다. `[String: Any]`는 `Sendable`을 준수하지 않아 격리 경계를 넘어 전달할 수 없기 때문이다.

그래서 딕셔너리 파싱 자체를 `Task` 바깥에서 먼저 끝내고, `Sendable`한 튜플로 변환한 결과만 `Task` 안에 넘기는 방식으로 고쳤다.

```swift
let parsedCoordinates: [(latitude: Double, longitude: Double, order: Int)] = coordinatesRaw.enumerated().compactMap { index, coord in
    guard coord.count == 2 else { return nil }
    return (latitude: coord[0], longitude: coord[1], order: index)
}

let parsedAlerts: [(gpwsState: String, pace: Double, distance: Double, timestamp: Double, latitude: Double, longitude: Double)] = alertsRaw.compactMap { alertDict in
    guard let gpwsState = alertDict["gpwsState"] as? String,
          let pace = alertDict["pace"] as? Double,
          let distance = alertDict["distance"] as? Double,
          let timestamp = alertDict["timestamp"] as? Double,
          let latitude = alertDict["latitude"] as? Double,
          let longitude = alertDict["longitude"] as? Double else { return nil }
    return (gpwsState: gpwsState, pace: pace, distance: distance, timestamp: timestamp, latitude: latitude, longitude: longitude)
}
```

이렇게 하면 `Task`가 캡처하는 값이 모두 `Sendable`한 튜플이라 data race 경고 없이 깨끗하게 통과한다.

---

### Watch/iPhone PFD 표시값 불일치 및 종료 동기화 미작동 (SwiftData 중복 저장)

이건 어제 글에서 AI를 통해 원인과 해결책을 물어보았었다. 이부분은 내가 할 수 있는 범위를 넘어섰기 때문이다.

물어본결과 원인은 두 가지였다.

1. 야외 블루투스 환경에서 초당 1번씩 양방향으로 데이터를 쏘면 송수신 큐에 정체가 생겨 패킷이 드랍되거나 한꺼번에 몰려서 도착하는 현상이 생기고, 이 때문에 표시값이 어긋난다.
2. iPhone의 `didChangeTo .stopped`에서 `session?.end()`만 호출하고 VM에 종료 신호를 전달하지 않아 화면이 자동으로 닫히지 않는다.

해결 방향도 두 가지다.

1. `sendMessage()` 호출부에 3초 주기 Throttling을 적용해 큐 정체를 줄인다.
2. `sessionStatePublisher`로 `.stopped`도 흘려보내 VM이 화면을 자동으로 닫도록 한다.

---

우선 1번부터 해보도록한다.

양쪽에서 `sendMessage`를 통해 전달을 하므로 모두 throttle을 사용해보도록 한다.

3초 가드문 적용은 양쪽 모두 동일한 방식이다.

```swift
// iPhone WatchConnectivityService
private var lastSentTime: Date = .distantPast

func sendFlightData(_ data: FlightData) {
    let now = Date()
    guard now.timeIntervalSince(lastSentTime) >= 3.0 else { return }
    lastSentTime = now

    let message: [String: Any] = [
        "type": "flightData",
        "pace": data.pace,
        "distance": data.distance,
        "altitude": data.altitude,
        "heading": data.heading,
        "gpwsStatus": data.gpwsStatus?.rawValue ?? "normal",
        "latitude": data.latitude,
        "longitude": data.longitude
    ]
    session.sendMessage(message, replyHandler: nil)
}
```

```swift
// Watch WatchConnectivityService
private var lastSentTime: Date = .distantPast

func sendHealthData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }

    let now = Date()
    guard now.timeIntervalSince(lastSentTime) >= 3.0 else { return }
    lastSentTime = now

    let message: [String: Any] = [
        "heartRate": viewModel?.healthData.heartRate ?? 0,
        "cadence": viewModel?.healthData.cadence ?? 0,
        "activeEnergy": viewModel?.healthData.activeEnergy ?? 0
    ]
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
}
```

별도로 Combine을 쓰지 않고도 마지막 전송 시각을 기록해 3초가 지나지 않으면 전송을 건너뛰는 방식으로 충분했다.

`Date.distantPast`는 1년이 아니라 사실상 무한히 먼 과거를 나타내는 값이다. `lastSentTime`을 `.distantPast`로 초기화해두면 첫 호출 때는 현재 시각과의 차이가 당연히 3초를 훌쩍 넘기므로 무조건 조건을 통과해 바로 전송된다. 이후부터는 호출 시점의 현재 시각과 `lastSentTime`의 차이가 3초 이상일 때만 `lastSentTime`을 갱신하고 전송을 진행한다. 3초 이내에 다시 호출되면 가드문에서 그대로 리턴되어 전송이 스킵된다.

GPS와 HealthKit 데이터는 1초마다 계속 수집되지만, 무선 전송만 3초에 1번으로 낮춰 블루투스 큐의 병목을 줄이는 구조다.

---

2번의 경우도 해보도록 한다.

애초에 VM에서는 운동 session이 종료된 걸 모르기 때문에 같이 전달을 하도록 해준다.

```swift
// HealthKitService
func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    if toState == .stopped {
        Task { @MainActor in
            session?.end()
            sessionStatePublisher.send(toState)
        }
    } else if toState == .running {
        sessionStatePublisher.send(toState)
    }
}

// ViewModel
healthService.sessionStatePublisher
    .sink { [weak self] state in
        guard let self else { return }
        if state == .running {
            isRemoted = true
            self.navigationPath.append(.pfd)
        } else if state == .stopped {
            Task {
                await self.resetState()
            }
        }
    }
    .store(in: &cancellables)
```

VM에선 `.stopped`일 경우 `resetState()`를 통해 모든 상태를 초기화해주도록 한다. 여기엔 `navigationPath = []`도 포함되어 있어 자연스럽게 홈 화면으로 이동하게 된다.

---

### Watch PFD 데이터 간헐적 수신 실패

이건 사실 어제 글에서 분석했던 BLE 핸드셰이킹 지연 추정이 틀렸을 가능성이 있다. 코드를 다시 살펴보니 `HealthKitService.startWorkout()`에 있던 `startMirroringToCompanionDevice()` 호출 자체가 사라져 있었다.

어제 밤 3차 간이테스트 때는 분명 이 코드가 있었는데, 오늘 watchOS `NavigationStack` 경고를 디버깅하면서 코드를 여러 번 수정하고 되돌리는 과정(`git checkout .` 등)을 거쳤었다. 그 과정에서 미커밋 상태였던 미러링 코드가 같이 날아간 것으로 보인다. 그러니까 어제 "간헐적으로 동작"했다고 기록한 것도, 사실은 미러링이 한 번도 안 됐고 주머니에서 꺼냈을 때 우연히 다른 경로로 화면이 바뀐 걸 잘못 해석했을 가능성도 있다.

다시 추가해주었다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
    builder = session?.associatedWorkoutBuilder()
    session?.delegate = self
    builder?.delegate = self
    builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: workoutConfiguration)

    let startDate = Date()
    session?.startActivity(with: startDate)
    try await builder?.beginCollection(at: startDate)

    if WCSession.default.isReachable {
        do {
            try await session?.startMirroringToCompanionDevice()
            print("Watch: startMirroringToCompanionDevice called")
        } catch {
            print("Watch: mirroring failed - \(error)")
        }
    }
}
```

---

#### 크래시 발생

다시 실기기로 테스트해보니 러닝 시작 시 앱이 튕겼다. Xcode를 Watch에 직접 붙여서 디버깅했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-17-RunningProject-14/probl.png){: width="50%" height="50%"}

스택 트레이스를 보니 `_dispatch_assert_queue_fail`에서 발생했고, 호출 스택을 따라가보니 `HealthKitService.workoutSession(_:didChangeTo:from:date:)`가 원인이었다.

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    if toState == .stopped {
        Task { @MainActor in
            try await builder?.endCollection(at: date)
            workout = try await builder?.finishWorkout()
            session?.end()
        }
    }
}
```

`Task { @MainActor in }` 클로저 안에서 `@Observable` 프로퍼티에 직접 접근하는 방식이 Swift 6의 실행 컨텍스트 검증(`_checkExpectedExecutor`)과 충돌해 트랩이 발생한 것으로 보인다. `@MainActor`로 격리된 별도 메서드로 분리해 해결했다.

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    Task {
        await self.finishWorkout(at: date)
    }
}

@MainActor
private func finishWorkout(at date: Date) async {
    do {
        try await builder?.endCollection(at: date)
        workout = try await builder?.finishWorkout()
        session?.end()
    } catch {
        print(error)
    }
}
```

같은 패턴의 문제가 iPhone 쪽 `HealthKitService`에도 있었다. 이쪽은 `nonisolated` 명시 자체가 빠져 있었는데, Xcode 26의 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 기본값 때문에 컴파일러가 암묵적으로 `@MainActor`로 가정해버린 게 원인이었다. 동일하게 `nonisolated`를 명시하고 별도 메서드로 분리해 수정했다.

---

#### 미러링은 됐지만 화면 전환이 안 됨

크래시를 잡고 나니 미러링 자체는 되는데 iPhone PFD로 화면이 안 넘어가는 문제가 남았다. 로그를 보니

```text
Start mirroring remote session: <HKWorkoutSession:0x11c8945a0 ... running [Mirrored]>
```

세션을 받았을 때 이미 `running` 상태였다. `didChangeTo`는 상태가 *바뀌는* 시점에만 호출되기 때문에, delegate를 설정하기 전에 이미 `.running`으로 전이된 세션을 받으면 그 콜백을 영원히 받을 수 없는 구조였다.

그래서 세션을 받는 즉시 현재 상태를 직접 확인해서 처리하도록 수정했다.

```swift
func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        Task { @MainActor in
            self.session = mirroredSession
            self.session?.delegate = self

            if mirroredSession.state == .running {
                self.handleStateChange(.running)
            }
        }
    }
}

nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    print("iPhone: workout session changed to \(toState.rawValue)")
    Task {
        await self.handleStateChange(toState)
    }
}

@MainActor
private func handleStateChange(_ toState: HKWorkoutSessionState) {
    if toState == .stopped {
        session?.end()
        sessionStatePublisher.send(toState)
    } else if toState == .running {
        print("iPhone: sending .running to sessionStatePublisher")
        sessionStatePublisher.send(toState)
    }
}
```

이후 다시 테스트하니 PFD로 정상 전환됐고, Watch에서 러닝을 종료하면 iPhone도 같이 홈으로 돌아가는 것까지 확인했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-17-RunningProject-14/testt.gif){: width="50%" height="50%"}

그리고 미러링을 통해 러닝이 종료되면 앱에서 계속 위치를 추적하려고 하는 기능이 활성화된 상태로 남아있어서 비활성화를 해주도록 한다.

```swift
func resetState() async {
    if isRemoted {
        locationService.stopTracking()
    }
    // 생략
}
```

이제는 미러링을 통해 종료되어도 위치추적이 비활성화로 바뀌게 된다.

다만 일시정지는 앱에서는 되지만 워치에서는 구현이 되지않아서 문제점을 먼저 해결하고 구현 해보려 한다.

---

### iPhone 심박, 케이던스 미표시

현재 Watch에서는 되지만 앱에서는 안 된다.

우선 앱의 `didReceiveMessage`에 print를 해서 값을 제대로 받아오는지 출력을 해보았다. (일단은 콘솔 확인을 하기 위해 심박만 해보았다.)

```text
82.0
81.0
81.0
```

이런 식으로 문제없이 들어오는 걸 확인했다.

하지만

```swift
Task { @MainActor in
    vm?.healthData?.heartRate = heartRate
    vm?.healthData?.cadence = cadence
    vm?.healthData?.activeEnergy = activeEnergy
    vm?.heartRateBuffer.append(heartRate)
    vm?.cadenceBuffer.append(cadence)
    print(vm?.healthData?.heartRate ?? 0)
}
```

여기에 print를 해보니 0이 되었다.

VM에서

```swift
var healthData: WatchHealthData? = nil
```

이렇게 옵셔널로 해두었던 게 원인이었다. `healthData`가 `nil`인 상태에서 `vm?.healthData?.heartRate = heartRate`처럼 옵셔널 체이닝으로 대입하면, `nil`이라는 사실만 확인하고 그냥 조용히 무시되어버린다. 

값은 잘 도착했지만 실제로는 어디에도 저장되지 않고 있었던 것이다.

어차피

```swift
struct WatchHealthData {
    var heartRate: Double = 0
    var cadence: Double = 0
    var activeEnergy: Double = 0
}
```

이런 식으로 초기값을 설정해두었기 때문에 옵셔널로 둘 이유가 없었다. 기본값으로 바로 초기화해주면 된다.

```swift
var healthData = WatchHealthData()

func resetState() async {
    // 생략
    healthData = WatchHealthData()
    // 생략
}
```

우선 VM에서 바꿀 것들을 바꿔주었다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    // 생략
    else {
        // 생략
        Task { @MainActor in
            vm?.healthData.heartRate = heartRate
            vm?.healthData.cadence = cadence
            vm?.healthData.activeEnergy = activeEnergy
            vm?.heartRateBuffer.append(heartRate)
            vm?.cadenceBuffer.append(cadence)
        }
    }
}
```

여기도 `healthData`가 옵셔널이었던 부분을 고쳐준다.

PFDView에선

```swift
N1GaugeView(label: "HR N1%", value: Int(runViewModel.healthData.heartRate), color: .rwRed, zone: "ZONE 4")
N1GaugeView(label: "CAD N1%", value: Int(runViewModel.healthData.cadence), color: .rwGreen, zone: "ZONE 4")

let avgFuel = Int(runViewModel.healthData.activeEnergy)
```

이렇게 바꿔주었다.

바로 확인을 해보니

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-17-RunningProject-14/done.png){: width="50%" height="50%"}

심박이 적용이 된걸 알 수 있었다.

---

## Watch 일시정지 구현

다만 위의 스크린샷을 보면 앱은 일시정지 되지만 워치는 아직 구현이 되어있지 않다.

이제 워치에서도 5초이상 위치변화가 없으면 일시정지가 되는 로직을 구현해보려한다.

어차피 앱이랑 구현한 매커니즘은 같기때문에 크게 어렵진 않아 보인다.

우선 WatchPFDView에도

```swift
if viewModel.isPaused {
    Color.rwBg.opacity(0.85)
        .ignoresSafeArea()
    VStack(spacing: 8) {
        Image(systemName: "pause.circle.fill")
            .font(.system(size: 32))
            .foregroundColor(.rwAmber)
        Text("PAUSED")
            .font(.orbitron(14, weight: .bold))
            .foregroundColor(.rwAmber)
            .kerning(2)
    }
}
```

이런식으로 해주었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-17-RunningProject-14/IMG0023.gif){: width="50%" height="50%"}

이제 일시정지도 되는 걸 알 수 있다.

다만 아무래도 미러링을 하면 딜레이가 있고 PFD에서도 바로 카운트가 올라가는 게 아니라 PFDView로 전환되고 `task`를 통해 `startStream`이 작동하는 구조라서 약 3초 정도의 차이가 있었다.

(개인이 개발하는 시점에선 이 부분은 별도 메모만 해두고 이후에 버전업이나 그럴 때 개선하는 게 좋아 보인다는 생각이 들었다. 아직 미러링이 할 게 많기 때문이다.)

### 문제점

하지만 문제가 있었다.

워치에서 미러링을 통해 앱이 PFDView로 전환된 상태에서, Watch 앱과 iPhone 앱을 모두 강제종료하면 문제가 생긴다. 다시 iPhone 앱을 켜면 HomeView가 아니라 PFDView가 바로 뜨고, `task`의 `startStream()`까지 그대로 작동해버린다.

그냥 앱으로 러닝을 실행하고 강제종료했을 때는 HomeView부터 보이지만, 미러링을 통한 강제종료는 PFDView부터 보인다는 건 개인적으로 `WorkoutSession`이 `running`으로 유지되는 게 아닌가? 라는 생각이 들었다.

AI에게 물어보니 같은 의견이었다. `HKWorkoutSession`은 앱 프로세스가 아니라 시스템(데몬) 레벨에서 관리되기 때문에, 앱이 강제종료되어도 `.end()`가 명시적으로 호출되지 않으면 세션 자체는 `running` 상태로 계속 살아있다는 것이다. 그래서 앱을 다시 켜면 `retrieveRemoteSession()`에 등록해둔 `workoutSessionMirroringStartHandler`가 이 살아있는 세션을 곧바로 감지해 `handleStateChange(.running)`을 호출하고, `navigationPath.append(.pfd)`로 이어지면서 켜자마자 PFD로 가버리는 것이다.

해결 방향으로 `mirroredSession.startDate`를 기준으로 일정 시간(5초) 이상 지난 세션은 좀비 세션으로 간주해 무시하는 방식을 시도해보았다.

```swift
if mirroredSession.state == .running {
    let elapsed = Date().timeIntervalSince(mirroredSession.startDate ?? .now)
    if elapsed > 5 {
        self.session = nil
    } else {
        self.handleStateChange(.running)
    }
}
```

처음엔 좀비 세션을 `session?.end()`로 강제 종료시키려 했는데, 이렇게 하니 Watch 쪽 실제 워크아웃 세션까지 같이 끊겨버려서 이후 Watch에서 새로 러닝을 시작해도 미러링 자체가 안 되는 부작용이 생겼다. 그래서 `.end()` 호출 없이 `session = nil`로만 무시하는 방식으로 바꿨지만, 5초가 지나도 PFD가 그대로 유지되는 현상은 여전했다.

`startDate`와 `elapsed` 값을 직접 출력해서 확인하려 했지만, 앱을 강제종료하면 디버거 연결도 함께 끊겨서 Xcode에서 매번 다시 Run을 눌러야 콘솔을 볼 수 있는 번거로움이 있어 검증을 보류했다. 추측대로 `startDate`가 기대와 다르게 갱신되고 있는 건지, 아니면 다른 경로로 화면 전환이 일어나는 건지는 아직 명확하지 않다. 일단은 이슈로 남겨두고 다음에 다시 다룰 예정이다.

오늘은 컨디션이 안좋아서 여기까지...