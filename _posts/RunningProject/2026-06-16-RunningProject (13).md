---
title: RunWay (13) Watch 미러링 & 실기기 테스트
writer: Harold
date: 2026-06-16 08:33:00 +0900
#last_modified_at: 2026-06-15 08:33:00 +0900
categories: [RunWay]
tags: [watchOS, WatchConnectivity, HealthKit]

toc: true
toc_sticky: true
published: true
---

## 문제점 수정하기

이전 글 마지막에서 간단하게 실기기 테스트를 진행했다. 결과는 좋지 않았다.

1. 위치 데이터를 전혀 가져오지 못해 페이스, 거리 등 GPS 관련 데이터가 하나도 표시되지 않았다.
2. HealthKit 데이터도 수집되지 않았다. 앱 삭제 후 재설치 시 위치 권한만 요청하고 HealthKit 권한 요청이 뜨지 않은 것으로 보아 권한 요청 자체가 제대로 동작하지 않는 것으로 보인다.

하나씩 원인을 파악해보려 한다.

---

### 1. 위치데이터 문제

앱의 러닝 메커니즘을 그대로 가져왔음에도 불구하고 작동하지 않았다.

우선 Publisher를 통해 데이터를 가져오는지 `print`로 확인했더니 위치값은 정상적으로 받아오고 있었다. `LocationService`에는 문제가 없었다. `FlightData`도 출력이 되었으므로 Actor도 정상이었다.

그래서 `startStream()` 내부에서 데이터가 출력되는지 확인해보니 출력이 되지 않았다. `startStream()`이 호출 자체가 안 되고 있었던 것이다.

`Command + Shift + F`로 `startStream`을 검색해보니 `WatchPFDView`에 연결이 빠져 있었다.

```swift
.task {
    await viewModel.startStream()
}
```

추가해주었더니 View에 데이터가 표시되기 시작했다.

그런데 러닝 종료 시 에러가 출력되었다.

```text
workoutSession(_:didFailWithError:): Error Domain=com.apple.healthkit Code=3 "Unable to perform 'stop' from current state 'NotStarted'" UserInfo={NSLocalizedDescription=Unable to perform 'stop' from current state 'NotStarted'}
```

구글링을 해보니

해당 에러는 세션이 제대로 시작되기 전에 `stop()` 또는 `end()`를 호출했을 때 발생한다. `HKWorkoutSession`의 상태가 `NotStarted`일 때 나타나며, HealthKit 권한을 받지 못했거나 초기화 순서가 맞지 않을 때 주로 발생한다.

권한 문제는 다음 섹션에서 다룬다.

---

### 2. 건강데이터 문제

앱 재설치 시 HealthKit 권한 요청이 뜨지 않는 것부터 이상했다. 처음 설치할 때는 정상적으로 권한 팝업이 떴는데, 삭제 후 재설치하면 위치 권한만 요청하고 HealthKit 권한 요청은 나타나지 않았다.

방식을 바꾸기로했다.

WatchHomeView에서

```swift
.onAppear {
    try await viewModel.healthKitService.requestAuthorization()       
}
```

그래도 안되어서 건강 자체의 허용을 보니 이미 건강데이터는 공유상태였다.

아마 삭제하고 재설치해도 이미 기존의 설정이 저장되는걸로 보인다.

---

`updateForStatistics`에 프린트를 해보니 출력이 된다.

우선 다시 간이 테스트를 해보기로 결정했다.

----

## 2차 간이테스트 결과

1. SummaryView 적용 안됨
2. Cadence 변경필요
3. GPWS 안됨
4. 페이스가 반영이 느린듯한 느낌이 있음
5. transferUserInfo 미구현 - 러닝 결과 iPhone 전송 안 됨

하나씩 수정해나간다.

---

### SummaryView

근본적인 원인은 앱과 Watch의 데이터 로드 방식 차이에서 왔다.

iPhone 앱은 러닝 종료 시 SwiftData에 저장하고 SummaryView에서 그걸 읽어오는 구조다. Watch는 SwiftData 저장이 없으니 `resetState()`에서 모든 데이터가 초기화되어 Summary에 도달했을 때 값이 이미 0이 되어버린다.

그래서 stop에서 resetState를 빼주었다.

그리고 SummaryView에서

```swift
Button {
    Task {
        await viewModel.resetState()
    }
}
```

리셋을 하도록 해주었다.

---

### Cadence

이미 예상했던 문제였다. `cyclingCadence`를 러닝 케이던스 대용으로 사용했는데 실제로 값이 들어오지 않았다.

대안으로 `stepCount`를 사용해서 경과 시간으로 나누는 방식으로 변경했다. [Apple Developer Forums](https://developer.apple.com/forums/thread/708208){:target="_blank"}에서도 러닝 케이던스는 직접 계산해야 한다고 확인된 내용이다.

```swift
let typesToRead: Set = [
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.stepCount)
]

// updateForStatistics
case HKQuantityType.quantityType(forIdentifier: .stepCount):
    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
    let elapsedMinutes = (builder?.elapsedTime ?? 0) / 60.0
    cadence = elapsedMinutes > 0 ? steps / elapsedMinutes : 0
```

`builder?.elapsedTime`으로 워크아웃 경과 시간을 가져와서 분 단위로 변환 후 걸음 수를 나누는 방식이다.

---

### GPWS

페이즈를 Actor에 전달하지 않아서 발생한 문제였다.

```swift
func updatePhase(_ changedPhase: FlightPhase) {
    currentPhase = changedPhase
    Task {
        await runningCenter.updatePhase(changedPhase)
    }
    // ...
}
```

그리고 간이 테스트 시 걷기 속도로 테스트하기 위해 페이스 범위를 15분까지 늘리고, 거리는 100m로 줄여주었다.

```swift
// pace
.digitalCrownRotation(
    $crownValue,
    from: 180,
    through: 900, // 수정
    by: 5,
    sensitivity: .low,
    isContinuous: false,
    isHapticFeedbackEnabled: true
)
// distance
.digitalCrownRotation(
    $crownValue,
    from: 0.1, // 수정
    through: 42.2,
    by: 0.5,
    sensitivity: .low,
    isContinuous: false,
    isHapticFeedbackEnabled: true
)
```

페이즈 수정 후 시뮬레이터 확인 결과 GPWS가 여전히 작동하지 않았다. print로 확인해보니 `modeB`로 인식되고 있었다.

추적해보니 `WatchPaceDeviationView`에서 `getModeData()`를 호출하지 않은 것이 원인이었다.

```swift
Button {
    let modeAData = ModeA(targetPace: Double(paceSeconds) / 60.0, paceDeviation: Int(deviation), targetDistance: preset.distance)
    viewModel.getModeData(modeAData)
    viewModel.navigateTo(.missionSummary(preset: preset, paceSeconds: paceSeconds, deviation: Int(deviation)))
}
```

`modeA`로 인식은 됐지만 `isReachedPace`가 `true`로 바뀌지 않는 문제가 남아 있었다. (`MINIMUMS`는 정상 작동)

앱과 비교해보니 `targetPace` 단위 문제였다.

```text
Watch: 330 (초)  vs  iOS: 5.5 (분)
```

`/ 60.0`으로 분 단위로 변환해주어 해결했다.

이후 오차가 `0초`로 표시되던 문제도 수정했다.

```swift
// before
return abs(Int(viewModel.flightData.pace - targetPace))
// after
return abs(Int((viewModel.flightData.pace - targetPace) * 60))
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/done.gif){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/done1.gif){: width="50%" height="50%"}

GPWS가 정상 작동하는 것을 확인했다. (2번째 사진)


---

### transferUserInfo

앱의 HomeView에서 `pendingWatchData` 값이 들어왔을 때 SwiftData에 등록하도록 했는데 값이 들어오지 않았다.

생각해보니 `sendRunningData()` 호출 자체를 안 하고 있었다.

```swift
func resetState() async {
    watchConnectivityService.sendRunningData()
    isRunning = false
    isModeA = false
    isPaused = false
    elapsedTime = 0
    tempAlertArray = []
    flightData = FlightData()
    await runningCenter.reset()
    healthKitService.resetWorkout()
    navigationPath = []
}
```

리셋 직전에 호출하도록 추가했다. print로 확인해보니 전송 자체는 되고 있었다.

```text
send ["date": 1781544344.453758, "pace": 4.956632898774108, "distance": 363.26026362067626, "cadence": 0.0, "mode": "modeB", "activeEnergy": 19.610396768383033, "time": 98, "heartRate": 118.0]
```

하지만 앱 시뮬레이터에서 수신 확인은 불가능하다. [Apple 공식 문서](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo(_:)){:target="_blank"}에 명시되어 있다.

> Always test Watch Connectivity data transfers on paired devices. The Simulator app doesn't support the transferUserInfo(_:) method.

그래서 이 경우엔 실기기에서만 확인 가능하다.

---

## 미러링 구현

미러링 구현에 앞서 어떤 경우에 미러링이 필요한지 정리해야 한다.

1. **앱 + Watch 동시 사용**
iPhone 앱에서 러닝을 시작하면 Watch에서도 같이 워크아웃 세션이 열려야 심박수와 케이던스를 수집할 수 있다. Watch에서 `startMirroringToCompanionDevice()`를 호출해 iPhone과 세션을 공유하고, 심박/케이던스를 `sendMessage`로 실시간 전송한다.

2. **Watch 단독 사용**
iPhone 앱 없이 Watch만으로 러닝하는 경우다. 미러링 없이 Watch 자체 세션으로 운영하고, 러닝 종료 후 `transferUserInfo`로 결과를 iPhone에 전송한다.

`WCSession.isReachable`로 iPhone 연결 여부를 판단해서 두 경우를 분기한다.

즉 플로우를 정리하면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/mirroring_scenarios.png){: width="50%" height="50%"}

미러링경우 이전글에서의 Apple에서 제공한 Sample Project와 더불어 [참고글](https://sasq.ca/blog/2025/3/2/building-a-workout-app-for-apple-watch){:target="_blank"}을 하나 더 같이 해서 진행을 해보려 한다.

---

### 1. 동시 사용

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/togetherfinal.png){: width="50%" height="50%"}

iPhone에서 러닝을 시작하면 `startMirroringToCompanionDevice()`로 Watch와 세션을 공유한다. 

Watch는 HealthKit에서 심박수와 케이던스를 수집해 `sendMessage()`로 iPhone에 실시간 전송하고, iPhone은 GPS 기반으로 페이스와 거리를 계산하며 GPWS를 판단한다. 계산된 `FlightData`는 다시 `sendMessage()`로 Watch에 전달되어 PFD에 표시된다.

---

#### Enum을 사용한 분기처리

구현에 앞서 미러링 여부를 `enum`으로 관리한다. 

`Bool` 플래그 하나로도 가능하지만, 나중에 코드를 봤을 때 `runningMode == .mirrored`가 `!isMirrored`보다 의도가 명확하게 읽히기 때문이다.

그래서 VM에 아래와 같이 추가를 해주었다.

```swift
enum RunningMode {
    case standalone
    case mirrored
}

var runningMode: RunningMode = .standalone
```

---

#### HealthKitService 수정

현재 `startWorkout()` 내부에 `startMirroringToCompanionDevice()`를 호출하고 있었지만, iPhone 쪽에서 미러링 세션을 받는 처리가 없어서 실질적으로 동작하지 않았다.

우선 iPhone이 연결되어 있을 때만 미러링을 시도하도록 수정한다.

```swift
import WatchConnectivity

if WCSession.default.isReachable {
    try await session?.startMirroringToCompanionDevice()
}
```

`isReachable`이 `true`일 때만 미러링을 시작하고, `false`이면 Watch 단독으로 실행한다.

그리고 `startWorkout()`이 미러링 여부를 `RunningMode` enum으로 반환하도록 변경했다.

워크아웃 시작 자체에는 영향이 없고, 반환값으로 현재 어떤 모드로 운영되는지만 알려준다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws -> RunningMode {
    // 생략
    if WCSession.default.isReachable {
        try await session?.startMirroringToCompanionDevice()
        return .mirrored
    }

    let startDate = Date()
    session?.startActivity(with: startDate)
    try await builder?.beginCollection(at: startDate)

    return .standalone
}
```

---

#### VM에서 분기처리

이제 VM에서 `runningMode`를 기준으로 분기처리를 해준다.

`standalone`이면 `LocationService`와 `RunningCenter`를 직접 사용하고, `mirrored`면 HealthKit 데이터만 수집해서 `sendMessage`로 iPhone에 전송한다.

나눈 기준은 아래와 같다.

`standalone`일 때만 GPS 및 러닝 데이터 관련 로직이 동작하고, `mirrored`일 때는 HealthKit 데이터 수집과 전송만 담당한다.

코드 생략하기가 애매해서 이 부분은 전체를 가져왔다.

```swift
func updatePhase(_ changedPhase: FlightPhase) {
    currentPhase = changedPhase
    Task {
        await runningCenter.updatePhase(changedPhase)
    }
    switch changedPhase {
    case .cruise:
        Task {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor
            do {
                runningMode = try await healthKitService.startWorkout(workoutConfiguration: config)
            } catch {
                print(error)
            }
        }
    case .touchdown:
        healthKitService.stopWorkout()
    default:
        break
    }
}

// MARK: - Running

func start() {
    isRunning = true
    isPaused = false
    lastReceivedTime = .now

    if runningMode == .standalone {
        locationService.startTracking()
    }

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

func stop() async {
    if runningMode == .standalone {
        locationService.stopTracking()
    }
    timerCancellable.removeAll()
}


func startStream() async {
    Task {
        for await data in healthKitService.streamHealthData() {
            self.healthData = data
            watchConnectivityService.sendHealthData()
        }
    }

    if runningMode == .standalone {
        Task {
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
    }
}

func getModeData(_ data: ModeA) {
    isModeA = true
    modeAData = data
    Task {
        await runningCenter.setModeAData(data)
    }
}

func resetState() async {
    watchConnectivityService.sendRunningData()
    isRunning = false
    isModeA = false
    isPaused = false
    elapsedTime = 0
    tempAlertArray = []
    flightData = FlightData()
    modeAData = nil
    runningMode = .standalone
    await runningCenter.reset()
    healthKitService.resetWorkout()
    navigationPath = []
}
```

---

#### 문제점

하지만 구현 중 생각을 해보니 문제점을 발견했다.

`runningMode`가 결정되는 시점이 `startWorkout()`의 반환값을 받는 순간인데, 이건 `TakeoffView`의 카운트다운 중 `updatePhase(.cruise)`가 호출될 때다.

문제는 `startStream()`이 `WatchPFDView`의 `.task`로 호출되는데, `startWorkout()`이 완료되기 전에 PFD 화면으로 넘어가면서 `startStream()`이 먼저 실행될 수 있다는 점이다. 이 경우 `runningMode`가 아직 `.standalone`인 채로 분기되어 미러링 모드임에도 GPS와 RunningCenter를 사용하게 된다.

즉 분기가 이루어지기 전에 스트림이 먼저 시작되는 타이밍 문제다.

그래서 `startWorkout()`에서 미러링 여부를 반환하는 방식을 포기하고 원복했다.

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
}
```

---

#### 해결책

`WCSessionDelegate`의 `sessionReachabilityDidChange`를 활용한다. iPhone 연결 상태가 변할 때마다 자동으로 호출되므로 별도의 타이밍 처리 없이 `runningMode`를 실시간으로 업데이트할 수 있다.

```swift
func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
        viewModel?.runningMode = session.isReachable ? .mirrored : .standalone
    }
}
```

그리고 [WCSessionDelegate Docs](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate){:target="_blank"}를 보면

> The methods of this protocol are called on a background thread of your app, so any code you write should be written with that fact in mind. In particular, if your method implementations initiate modifications to your app’s interface, make sure to redirect those modifications to your app’s main thread.

`WCSessionDelegate`의 메서드는 백그라운드 스레드에서 호출되기 때문에 `@MainActor`로 격리된 `runningMode`에 접근하려면 `Task { @MainActor in }`으로 감싸야 한다.

---

#### 앱에서 미러링 처리하기

미러링은 어느 기기가 먼저 시작하느냐에 따라 두 가지 경우로 나뉜다.

1. **Watch가 먼저 시작한 경우** 
    - Watch에서 `startMirroringToCompanionDevice()`를 호출하면 iPhone의 `workoutSessionMirroringStartHandler`가 트리거되고, iPhone에서 자동으로 러닝을 시작한다.

2. **iPhone이 먼저 시작한 경우** 
    - iPhone에서 `startWatchApp(toHandle:)`으로 Watch 앱을 실행하면, Watch가 미러링 세션을 수신해 자동으로 카운트다운을 시작한다.

두 기기가 서로 상대방이 먼저 시작했는지 감지하고 반응하는 양방향 구조가 필요하기 때문에 구현 난이도가 높다. 

현재는 Watch가 먼저 시작한 경우만 구현하고, iPhone이 먼저 시작하는 경우는 이후에 추가할 예정이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/watch_mirroring_decision.png){: width="50%" height="50%"}

---

일단 Apple에서 재공한 sample project에서 눈여겨볼 부분이 있다.

- `startWatchWorkout()`
    - iPhone에서 운동 시작할 때 Watch 앱도 같이 켜진다.
    - `healthStore.startWatchApp(toHandle:)`으로 Watch에 워크아웃 설정을 전달하면 Watch 앱이 자동으로 실행된다.
- `retrieveRemoteSession()`
    - Watch에서 `startMirroringToCompanionDevice()` 호출하면 iPhone에서 이 핸들러가 트리거되어 미러링 세션을 받는다.

현재는 Watch 주도로 구현하기 때문에 `startWatchWorkout()`은 사용하지 않는다. 다만 iPhone 주도 시나리오를 추가할 때 반드시 필요한 요소다.

---

##### HealthKitService

이제 우리 프로젝트에 적용해본다.

앱의 `HealthKitService`는 현재 시뮬레이터 샘플 데이터 생성과 Fetch 기능만 있는 상태다. 미러링 세션을 받으려면 `HKWorkoutSession`과 delegate가 필요해진다. `extension`으로 코드를 분리했다.

```swift
extension HealthKitService: HKWorkoutSessionDelegate {
    
    func retrieveRemoteSession() {
        store.workoutSessionMirroringStartHandler = { mirroredSession in
            Task { @MainActor in
                self.session = mirroredSession
                self.session?.delegate = self
                print("Start mirroring remote session: \(mirroredSession)")
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .stopped {
            Task { @MainActor in
                session?.end()
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        print(error)
    }
    
}
```

`didChangeTo`에서 Watch 러닝이 종료되는 시점을 감지해 iPhone 세션도 함께 닫아준다. Watch 쪽 구현과 동일하지만, 현재 iPhone은 빌더를 통한 데이터 수집 구조가 아니기 때문에 세션 종료만 처리했다. iPhone 주도 미러링을 추가할 때는 빌더 처리도 함께 필요하다.

에러는 현재 `print(error)`로 처리했으며, 이후 Combine을 통해 통일할 예정이다.

그리고 `RunViewModel`의 `init()`에서 미러링 세션 수신 핸들러를 등록해준다.

```swift
init() {
    // 생략
    healthService.retrieveRemoteSession()
}
```

현재는 Watch에서 미러링을 시작하면 iPhone이 세션을 수신하는 것까지만 구현된 상태다. 같이 카운트다운이 되거나 PFD 화면으로 자동 전환되는 부분은 아직 구현되지 않았다. 

Watch에서 카운트다운 시작 시 `sendMessage()`로 앱에 신호를 보내고, 앱에서 수신해 화면을 전환하는 흐름이 추가로 필요하다.

---

##### 화면 전환하기

Watch에서 러닝이 시작되면 iPhone에서도 자동으로 PFD 화면으로 전환되어야 한다.

`didChangeTo`에서 `.running` 상태를 감지하고, Combine의 `PassthroughSubject`로 흘려서 `RunViewModel`이 구독하고 있다가 값을 받으면 PFD 화면으로 전환하는 방식을 택했다.

```swift
// HealthKitService
var sessionStatePublisher = PassthroughSubject<HKWorkoutSessionState, Never>()

func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    if toState == .stopped {
        Task { @MainActor in
            session?.end()
        }
    } else if toState == .running {
        sessionStatePublisher.send(toState)
    }
}   
```

```swift
// RunViewModel init()
healthService.sessionStatePublisher
    .sink { [weak self] state in
        guard let self else { return }
        if state == .running {
            self.navigationPath.append(.pfd)
        }
    }
    .store(in: &cancellables)
```

화면 전환이 가능한 이유에 대해 다시 이야기를 해보면 `HomeView`의 `NavigationStack`이 `runViewModel.navigationPath`를 바인딩하고 있기 때문이다. `navigationPath`에 `.pfd`가 추가되는 순간 SwiftUI가 자동으로 PFD 화면으로 전환한다.

이 화면 전환 방식은 전에 AI를 통해 구현을 했었다.

---

##### iPhone GPS 시작하기

화면전환이 된다고해서 무조건 되는게 아니다.

현재 미러링 모드에서 앱의 PFDView에 표시되려면 아래 과정이 필요하다.

1. iPhone `LocationService` → GPS 수집 및 `start()` 호출
2. `RunningCenter`에서 페이스/거리 계산
3. `FlightData` → `WatchConnectivityService.sendMessage()` → Watch 전송
4. Watch `WatchConnectivityService`에서 수신 → `WatchViewModel.flightData` 업데이트 → PFD 표시

반대로 Watch에서 수집한 심박/케이던스는 `sendMessage()`로 iPhone에 전송되어 iPhone PFD에도 표시되어야 한다. 즉 양방향 데이터 전송 구조가 필요하다.

---

###### GPS 수집

미러링 모드에서 iPhone도 GPS를 수집해야 하기 때문에 `isRemoted` 플래그를 통해 분기 처리를 했다.

```swift
// ViewModel
var isRemoted: Bool = false

healthService.sessionStatePublisher
    .sink { [weak self] state in
        guard let self else { return }
        if state == .running {
            isRemoted = true
            self.navigationPath.append(.pfd)
        }
    }
    .store(in: &cancellables)

func resetState() async {
    // 생략
    isRemoted = false
    await runningCenter.reset()
    navigationPath = []
}
        
// PFDView
.task {
    if runViewModel.isRemoted {
        try? await Task.sleep(for: .seconds(3))
        runViewModel.start()
    }
    await runViewModel.startStream()
}
```

`start()`를 먼저 호출해 GPS를 활성화한 뒤 `startStream()`으로 스트림을 구독하는 순서다. 또한 Watch의 카운트다운과 타이밍을 맞추기 위해 3초의 딜레이를 두었다.

---

###### Watch로 Location정보 전송하기

실시간 스트림에서 FlightData를 받을 때 `isRemoted`일 경우 Watch로 함께 전송하면 된다.

```swift
// ViewModel
func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
        // 생략
        if isRemoted {
            watchConnectivityService.sendFlightData(data)
        }
        // 생략
    }
}

// WatchConnectivityService
func sendFlightData(_ data: FlightData) {
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

---

###### Watch에서 FlightData 받기

`didReceiveMessage`에서 `type`을 확인해 `flightData`면 파싱해서 `WatchViewModel.flightData`에 넣어준다. 이미 PFD가 `viewModel.flightData`를 바라보고 있으니 자동으로 반영된다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let type = message["type"] as? String else { return }
    
    if type == "flightData" {
        let pace = message["pace"] as? Double ?? 0
        let distance = message["distance"] as? Double ?? 0
        let altitude = message["altitude"] as? Double ?? 0
        let heading = message["heading"] as? Double ?? 0
        let gpwsRaw = message["gpwsStatus"] as? String ?? "normal"
        let latitude = message["latitude"] as? Double ?? 0
        let longitude = message["longitude"] as? Double ?? 0
        
        let flightData = FlightData(
            distance: distance,
            pace: pace,
            altitude: altitude,
            heading: heading,
            gpwsStatus: GPWSState(rawValue: gpwsRaw),
            latitude: latitude,
            longitude: longitude
        )
        
        Task { @MainActor in
            viewModel?.flightData = flightData
        }
    }
}
```

참고로 `WatchViewModel`이 `@Observable`을 채택하고 있기 때문에 `viewModel.flightData`가 업데이트되면 `WatchPFDView`가 자동으로 다시 그려진다. 

별도의 `onChange` 없이도 실시간으로 반영되는 구조다.

`@Observable` 쓰면 쓸수록 상당히 편리하다.

---

##### 문제점

구현이 끝난 것처럼 보이지만 아직 문제가 남아 있다.

Free Flight는 상관없지만 Mission Flight(ModeA)에서는 목표 페이스, 허용 오차, 목표 거리 같은 `ModeA` 설정 정보가 Watch에만 있고 iPhone으로 전달되지 않는다. iPhone은 GPS로 페이스를 계산하지만 목표 페이스를 모르기 때문에 GPWS 판단이 불가능하다.

`ModeA` 정보도 `sendMessage()`로 iPhone에 전달해야 한다.

`sendMessage()`로 이미 러닝 정보를 전달하고 있는데 왜 또 보내야 하나 싶을 수 있다. 어차피 딕셔너리 구조이기 때문에 `type` 키로 구분해서 원하는 데이터만 파싱하면 된다. 

`ModeA` 정보는 러닝 시작 시 한 번만 보내면 되고, `flightData`는 실시간으로 계속 전송하는 방식이다.

---

###### Watch에서 ModeA Data 보내기

보내는 함수를 먼저 만들어준다. 연결 위치는 `getModeData()`가 포인트다. 

페이스 설정이 완료되면 `getModeData()`가 호출되어 VM에 저장하는데, 이 시점에 함께 iPhone으로 전송하도록 했다.

```swift
// WatchConnectivityService
func sendModeData(_ modeA: ModeA) {
    let message: [String: Any] = [
        "type": "modeData",
        "targetPace": modeA.targetPace,
        "paceDeviation": modeA.paceDeviation,
        "targetDistance": modeA.targetDistance
    ]
    session.sendMessage(message, replyHandler: nil)
}

// WatchViewModel
func getModeData(_ data: ModeA) {
    isModeA = true
    modeAData = data
    Task {
        await runningCenter.setModeAData(data)
    }
    if runningMode == .mirrored {
        watchConnectivityService.sendModeData(data)
    }
}
```

단 미러링 상관없이 보내면 안되기에 `runningMode == .mirrored`일 때만 보내도록 분기해주었다.

---

###### iPhone에서 ModeA Data 받기

이제 `didReceiveMessage`에서 데이터를 받는 부분을 추가해야 한다.

기존에 이미 HealthData를 받고 있었기 때문에 `type` 키로 구분해서 처리한다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    let vm = viewModel
    
    if let type = message["type"] as? String, type == "modeData" {
        let targetPace = message["targetPace"] as? Double ?? 0
        let paceDeviation = message["paceDeviation"] as? Int ?? 0
        let targetDistance = message["targetDistance"] as? Double ?? 0
        let modeA = ModeA(targetPace: targetPace, paceDeviation: paceDeviation, targetDistance: targetDistance)
        Task { @MainActor in
            vm?.getModeData(modeA)
        }
    } else {
        guard let heartRate = message["heartRate"] as? Double,
              let cadence = message["cadence"] as? Double,
              let activeEnergy = message["activeEnergy"] as? Double else { return }
        Task { @MainActor in
            vm?.healthData?.heartRate = heartRate
            vm?.healthData?.cadence = cadence
            vm?.healthData?.activeEnergy = activeEnergy
            vm?.heartRateBuffer.append(heartRate)
            vm?.cadenceBuffer.append(cadence)
        }
    }
}
```

---

###### 잠시 Flow 정리

지금까지의 과정을 보면 알겠지만 결국 서로 주고받고 그걸 어떻게 적용하냐의 문제다.

Watch에서 미러링 세션을 시작하면 iPhone이 감지해 PFD로 전환하고 GPS 수집을 시작한다. 수집된 FlightData는 다시 Watch로 전송되어 PFD에 표시되는 구조다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/watch_mirroring_flow.png){: width="50%" height="50%"}

처음에는 구현하는 나조차도 방향이 잘안잡히고 어려웠는데, 하다보니 이젠 어디에 뭐가 부족하고 문제점이 뭔지 알게 되었다.

---

###### iPhone에서 ModeA를 적용하여 보내기

`ModeA` 데이터를 Actor에 전달해야 하지만 별도로 처리할 필요가 없다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    let vm = viewModel
    
    if let type = message["type"] as? String, type == "modeData" {
        // 생략
        Task { @MainActor in
            vm?.getModeData(modeA)
        }
    }
}
```

`didReceiveMessage`에서 `getModeData()`를 바로 호출하는데, 이 함수 안에서 이미 `runningCenter.setModeAData()`를 호출하고 있기 때문이다.

```swift
func getModeData(_ data: ModeA) {
    isModeA = true
    modeAData = data
    Task {
        await runningCenter.setModeAData(data)
    }
}
```

수신한 즉시 Actor까지 전달이 완료되는 구조라 별도 처리가 필요 없다.

gpws상태도 flightData에 그대로 담아서 전달을 하기에 별도의 후처리가 필요없다.

---

#### 최종 정리

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/watch_mirroring_flow_final.png){: width="50%" height="50%"}

지금까지의 작업을 하나의 흐름으로 정리하면 위와 같다.

Watch에서 시작된 워크아웃 세션은 HealthKit 미러링을 통해 iPhone으로 전달된다. iPhone은 GPS를 이용해 거리와 페이스를 계산하고, Watch에서 전달받은 ModeA 설정을 기반으로 GPWS를 판단한다. 이후 계산 결과를 FlightData 형태로 다시 Watch에 전달하여 PFD에 반영한다.

결과적으로 Watch는 데이터 수집과 사용자 인터페이스를 담당하고, iPhone은 계산과 판단 로직을 담당하는 구조가 되었다.

---

### 2. 워치 단독 사용

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-15-RunningProject-13/standalone.png){: width="50%" height="50%"}

iPhone 없이 Watch만으로 러닝하는 경우다. `CoreLocation`으로 GPS를 직접 처리하고 `HealthKit`으로 심박수, 케이던스, 칼로리를 수집한다. `RunningCenter`에서 페이스와 거리를 계산하고, 러닝 종료 후 `transferUserInfo()`로 결과를 iPhone에 전송해 Logbook에 저장한다.

앞서 VM에서 `runningMode == .standalone`일 때만 `locationService`와 `runningCenter`가 동작하도록 분기처리를 완료했기 때문에 별도의 추가 구현 없이 동작한다.

---

## 3차 간이 테스트 결과

1. **PFD 자동 전환** - 간헐적으로 동작. 주머니에서 꺼냈을 때 전환된 것으로 보아 `workoutSessionMirroringStartHandler` 트리거 타이밍 문제로 추정.
2. **Watch PFD 데이터** - 페이스/거리 표시는 되나 간헐적으로 못 받아오는 경우 있음. `sendMessage()` 연결 불안정 시 실패하는 것으로 추정.
3. **iPhone 심박/케이던스 미표시** - `runningMode`가 `.mirrored`로 전환되기 전에 스트림이 시작되는 타이밍 문제로 추정.
4. **transferUserInfo** - LogbookView 기록 확인. 다만 거리 단위가 m로 저장되는 문제와 좌표 배열이 전송되지 않아 Summary에 경로가 표시되지 않는 문제 확인.
5. **PFD 표시값 불일치** - Watch PFD와 iPhone PFD가 서로 다른 값을 표시. 데이터 전송 타이밍 차이로 추정.
6. **종료 동기화 미작동** - Watch에서 종료해도 iPhone PFD가 자동으로 종료되지 않아 수동으로 종료 필요. 결과적으로 SwiftData에 중복 저장되는 문제 발생.

이렇게 확인이 되었다.

---

## 3차 간이 테스트 결과 분석

테스트 결과를 바탕으로 AI를 통해 문제점을 파악해 달라고 했다.

**1. PFD 자동 전환 간헐적 미작동**

야외 환경에서는 Wi-Fi가 끊기고 블루투스(BLE) 단일 파이프라인으로만 통신한다. `startMirroringToCompanionDevice()` 호출 시 내부적으로 핸드셰이킹 패킷을 iPhone으로 전송하는데, 신호 차폐나 블루투스 전력 절감 모드로 2~3초 이상 지연되면 핸들러 트리거 타이밍을 놓쳐버린다.

나이키 앱의 경우 핸들러가 씹히는 상황을 대비해 `sendMessage(["action": "startWorkout"])`를 동시에 쏘는 이중 안전장치 구조를 사용한다. 우리도 이 방식을 적용할 필요가 있다.

**2. Watch/iPhone PFD 표시값 불일치**

iPhone은 GPS 기반으로 페이스를 계산해 Watch로 `sendMessage()`를 쏘고, Watch는 HealthKit 데이터를 iPhone으로 쏘는 양방향 구조다. 야외 블루투스 환경에서 초당 1번씩 양방향 딕셔너리를 밀어내면 송수신 큐에 정체가 생겨 패킷이 드랍되거나 한꺼번에 몰려서 도착하는 현상이 생긴다.

**3. 종료 동기화 미작동**

현재 iPhone의 `didChangeTo .stopped`에서 `session?.end()`만 호출하고 있어 VM에 종료 신호가 전달되지 않는다. `sessionStatePublisher`로 `.stopped`도 흘려주면 해결할 수 있다.

---

### 2번 문제 해결 방향

AI를 통해 해결 방향을 추가로 분석했다. 제시된 세 가지 방법 중 우선순위는 다음과 같다.

**1순위: Throttling (전송 빈도 최적화)**

초당 1번씩 양방향으로 패킷을 쏘면 블루투스 큐가 밀리는 게 근본 원인이다. 3초에 1번만 전송하도록 가드문을 추가하면 트래픽이 1/3로 줄어 큐 정체가 사라진다. 종료 동기화 문제도 큐가 깨끗해지면 자연스럽게 해결될 가능성이 높다.

**2순위: 이동 평균 보정**

Throttling으로 3초 주기로 데이터를 받아도 야외 환경에서 간혹 신호 유실이 생길 수 있다. 최근 3개 수치의 평균값을 UI에 뿌려주면 숫자가 툭툭 끊기지 않고 부드럽게 변한다.

**2번(딕셔너리 경량화)** 은 파싱 구조를 전면 수정해야 해서 현재 단계에서는 보류한다.

작업 순서는 Throttling 적용 → 실기기 테스트 → 이동 평균 보정 순으로 진행한다.