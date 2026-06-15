---
title: RunWay (12) WatchConnectivity 연동
writer: Harold
date: 2026-06-13 08:33:00 +0900
last_modified_at: 2026-06-15 08:33:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, SwiftUI, Combine]

toc: true
toc_sticky: true
published: true
---

13일차의 Watch UI 설정은 이미 AI를 통해 디자인했으므로 생략한다.

여기선 이후 과정에 대해 서술한다.

## LocationService 만들기

이건 사실 앱에서 구현한것과 같아서 타겟 멤버쉽에 watch를 추가해주었다.

다만 watchOS에서는 pausesLocationUpdatesAutomatically를 지원하지 않아 조건부 컴파일로 분기해주었다.

```swift
func startTracking() {
    locationManager.startUpdatingLocation()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.allowsBackgroundLocationUpdates = true
    #if os(iOS)
    locationManager.pausesLocationUpdatesAutomatically = false
    #endif
}
```

나머지 설정은 iOS와 동일하게 사용 가능했기 때문에 별도 수정 없이 타겟 멤버십만 추가해주면 되었다.

---

## RunningCenter 만들기

`RunningCenter`도 거리/페이스 계산 로직이 동일하므로 타겟 멤버십에 Watch를 추가했다. 거리 계산과 페이스 스무딩 로직은 iPhone과 동일한 구현을 사용한다.

심박수와 케이던스는 Watch에서만 얻을 수 있는 데이터라 해당 부분만 `#if os(watchOS)` 조건 컴파일로 분기 처리할 예정이다. 

현재는 타겟 추가만 해두고 이후 `HealthKitService`와의 연동 시 함께 구현한다. 실제 동작 여부는 Watch 러닝 테스트를 진행하며 확인할 예정이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/share.png){: width="50%" height="50%"}

---

## SharedModel

타겟 멤버십을 공유하다 보니 모델을 각 타겟에서 중복 선언하면 충돌이 발생한다. 그래서 공유가 필요한 모델들을 `SharedModels.swift` 하나로 모아서 iPhone, Watch, Widget Extension 타겟 모두에 추가했다.

```swift
enum FlightPhase: String, Codable, Sendable, Hashable {
    // 생략
}

enum GPWSState: String, Codable, Sendable, Hashable {
    // 생략
}

struct FlightData {
    // 생략
}

struct ModeA {
    // 생략
}
```

---

## VM 만들기

`RunViewModel`에서 Watch에서도 그대로 쓸 수 있는 부분을 가져왔다.

코드가 길어 전부 보여주긴 어렵지만, `Activity` 관련 코드를 제외한 `init` 전체, 프로퍼티 대부분, 러닝을 담당하는 `start()`, `stop()`, `getModeData()`, `resetState()`, `getCoordinates()`, `resumeRunning()`, 그리고 `Activity`를 제외한 `startStream()`을 가져왔다.

---

## View와 연결하기

러닝 관련 기능을 가져왔으니 이제 View에 연결해본다.

우선 `WatchRunWayApp`에서 `WatchViewModel`을 environment로 주입해준다.

```swift
@main
struct WatchRunWayApp: App {
    @State private var watchViewModel = WatchViewModel()
    
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(watchViewModel)
        }
    }
}
```

---

이제부터 시작이다.

먼저 `WatchPaceSettingView`와 `WatchPaceDeviationView`에서 NEXT 버튼을 누를 때 `ModeA`에 값을 담아준다.

```swift
// WatchPaceSettingView
Button {
    viewModel.modeAData = ModeA(targetPace: Double(Int(paceSeconds)), paceDeviation: 0, targetDistance: preset.distance)
    viewModel.navigationPath.append(.paceDeviation(preset: preset, paceSeconds: Int(paceSeconds)))
}

// WatchPaceDeviationView
Button {
    viewModel.modeAData?.paceDeviation = Int(deviation)
    viewModel.navigationPath.append(.missionSummary(preset: preset, paceSeconds: paceSeconds, deviation: Int(deviation)))
}
```

이후 `WatchMissionSummaryView`에서 파라미터로 값을 받는 대신 `viewModel.modeAData`에서 꺼내도록 Computed Property로 변경한다.

```swift
var paceMin: Int { 
    Int(viewModel.modeAData?.targetPace ?? 0) / 60
    }
var paceSec: Int { 
    Int(viewModel.modeAData?.targetPace ?? 0) % 60 
    }
var paceString: String { 
    "\(paceMin)'\(String(format: "%02d", paceSec))\"/km" 
    }
var distanceString: String {
    guard let distance = viewModel.modeAData?.targetDistance, distance > 0 else { return "CUSTOM" }
    return String(format: "%.2f km", distance)
}
var deviationString: String {
    "±\(viewModel.modeAData?.paceDeviation ?? 0) sec" 
    }
```

---

TakeoffView에서`startCountdown()`에 필요한 부분을 추가했다.

```swift
func startCountdown() {
    withAnimation { countdownActive = true }
    countdownValue = 3

    Task {
        for i in 0..<5 {
            if i < 3 {
                countdownValue = 3 - i
                viewModel.updatePhase(.takeoff) // new
                WKInterfaceDevice.current().play(i == 0 ? .click : .directionUp)
                try? await Task.sleep(for: .seconds(1))
            } else if i == 3 {
                countdownValue = 0
                WKInterfaceDevice.current().play(.success)
                try? await Task.sleep(for: .seconds(1))
            } else {
                countdownActive = false
                viewModel.updatePhase(.cruise) // new
                viewModel.start() // new
                viewModel.navigationPath.append(.pfd)
            }
        }
    }
}
```

---

PFDView의 경우도 Computed Property로 전부 교체해준다.

```swift
var pace: String {
    PaceFormatter.format(viewModel.flightData.pace)
}
var distance: Double {
    viewModel.flightData.distance / 1000
}
var elapsed: String {
    PaceFormatter.secondToTime(viewModel.elapsedTime)
}    
var hr: Int {
    Int(viewModel.healthData.heartRate)
}
var cadence: Int {
    Int(viewModel.healthData.cadence)
}
var gpwsStatus: String {
    viewModel.flightData.gpwsStatus?.rawValue ?? "NORMAL"
}
```

그리고 러닝 종료도 추가해준다.

```swift
onEndFlight: {
    Task {
        viewModel.updatePhase(.touchdown)
        await viewModel.stop()
        viewModel.navigationPath.append(.touchdown)
    }
}
```

---

마지막으로 SummaryView도 바꿔준다.

```swift
WatchSummaryRow(label: "DISTANCE", value: String(format: "%.2f km", viewModel.flightData.distance / 1000), color: .rwText)
WatchSummaryRow(label: "TIME", value: PaceFormatter.secondToTime(viewModel.elapsedTime), color: .rwText)
WatchSummaryRow(label: "AVG PACE", value: PaceFormatter.format(viewModel.flightData.pace) + "/km", color: .rwAmber)
WatchSummaryRow(label: "CALORIES", value: String(format: "%.0f kcal", viewModel.healthData.activeEnergy), color: .rwAmber)
```

AI가 미리 만들어둔 UI에 값을 매핑하는 작업이라 코드 자체는 단순하지만, 아키텍처 설계와 데이터 흐름을 잡는 과정이 핵심이었다.

---

## HealthKitService 구현

View와의 연결까지 마쳤지만 아직 심박수와 케이던스 데이터가 없다. `sendMessage`로 iPhone에 전송하려면 먼저 Watch에서 데이터를 수집해야 하기 때문이다.

그래서 Watch용 `HealthKitService`를 구현해보려 한다. Watch에서의 HealthKit은 처음이라 아래 자료를 참고했다.

- [Building a multidevice workout app](https://developer.apple.com/documentation/healthkit/building-a-multidevice-workout-app)
- [Build a workout app for Apple Watch](https://developer.apple.com/documentation/HealthKit/build-a-workout-app-for-apple-watch){:target="_blank"}

---

샘플 코드를 참고해서 우리 앱에 필요한 부분만 추려서 구현해보려 한다. 상세하게 기록해두는 이유는 나중에 이 글을 참고해서 기능을 이어나갈 수 있도록 하기 위해서다.

### 1. 필요한 프로퍼티 설정

```swift
var heartRate: Double = 0
var activeEnergy: Double = 0
var cadence: Double = 0
```

iPhone 앱에서는 얻을 수 없는 데이터들이다. Watch의 내장 센서를 통해 심박수, 케이던스, 소모 칼로리를 받아온다.

---

### 2. Workout 관련 프로퍼티 생성

```swift
var workout: HKWorkout?

let typesToShare: Set = [HKQuantityType.workoutType()]
let typesToRead: Set = [
    HKQuantityType(.heartRate),
    HKQuantityType(.activeEnergyBurned),
    HKQuantityType(.cyclingCadence),
]
```

[`HKWorkout`](https://developer.apple.com/documentation/healthkit/hkworkout)은 단일 신체 활동에 대한 정보를 저장하는 샘플 타입이다. 러닝이 완료되면 이 객체에 결과가 담긴다.

`typesToShare`는 HealthKit에 저장할 데이터 타입을 지정한다. [App-o-Mat의 설명](https://app-o-mat.com/article/watchkit-workout-apps/healthkit-permissions)에 따르면 `workoutType()`은 거리, 페이스, 시간, 칼로리를 포함하는 워크아웃 전체를 나타내므로 하나로 충분하다. 

반면 `typesToRead`는 심박수, 케이던스, 칼로리가 서로 다른 `HKQuantityType`이므로 각각 명시해야 한다.

다만 케이던스가 현재 `cyclingCadence`인데 러닝 케이던스가 없다보니 일단은 이걸로 하긴했지만 테스트해보고 원하는값이 아니면 바꿀 예정이다.

---

### 3. Store, Session, Builder 셋업하기

```swift
let healthStore = HKHealthStore()
var session: HKWorkoutSession?
var builder: HKLiveWorkoutBuilder?
```

- [`HKHealthStore`](https://developer.apple.com/documentation/healthkit/hkhealthstore) — HealthKit에서 관리하는 모든 데이터에 접근하는 진입점이다.
- [`HKWorkoutSession`](https://developer.apple.com/documentation/healthkit/hkworkoutsession) — 워크아웃의 생명주기를 관리한다. 시작, 일시정지, 종료 등 운동 자체의 상태를 담당한다.
- [`HKLiveWorkoutBuilder`](https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder) — 데이터 수집을 담당한다. 언제부터 언제까지 데이터를 모을지 관리하며, 수집이 끝나면 `finishWorkout()`으로 최종 워크아웃 객체를 생성해 HealthKit에 저장한다.

세션이 운동의 흐름을 관리한다면, 빌더는 그 흐름 안에서 데이터를 모으고 정산하는 역할이다. 그래서 종료 시에도 `session.stopActivity()`와 `builder.endCollection()`을 따로 호출해야 한다.

그리고 `workout`을 프로퍼티로 보관하는 이유는 러닝 종료 후 Summary 화면 표시, SwiftData 저장, `transferUserInfo`로 iPhone 전송 시 참조하기 위해서다.

---

### 4. 권한 요청

```swift
override init() {
    super.init()
    guard HKHealthStore.isHealthDataAvailable() else {
        print("HealthKit only available in iOS, iPadOS, and watchOS")
        return
    }

    requestAuthorization()
}

func requestAuthorization() {
    Task {
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        } catch {
            print("Failed to request authorization: \(error)")
        }
    }
}
```

`init()`에서 먼저 `isHealthDataAvailable()`로 HealthKit 사용 가능 여부를 확인하고, 가능한 경우에만 권한을 요청한다. 에러 처리는 일단 `print`로 해두었고, 이후 `AlertItem` 방식으로 개선할 예정이다.

---

### 5. startWorkout / stopWorkout

클래스 선언부터 먼저 정리하고 가야 할 것 같다.

```swift
final class HealthKitService: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate { 

}
```

`HKWorkoutSessionDelegate`는 워크아웃 세션 상태 변화를, `HKLiveWorkoutBuilderDelegate`는 실시간 데이터 수집을 처리하기 위해 채택한다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
    builder = session?.associatedWorkoutBuilder()
    session?.delegate = self
    builder?.delegate = self
    builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: workoutConfiguration)

    try await session?.startMirroringToCompanionDevice()

    let startDate = Date()
    session?.startActivity(with: startDate)
    try await builder?.beginCollection(at: startDate)
}


func stopWorkout() {
    session?.stopActivity(with: Date())
}
```

워크아웃 세션과 빌더를 생성하고, 델리게이트를 연결한다. `startMirroringToCompanionDevice()`로 iPhone에 세션을 미러링한 뒤, 세션 시작과 데이터 수집을 시작한다. `stopWorkout()`은 세션을 중지하며, `builder.endCollection()`과 `builder.finishWorkout()`은 Watch VM 작성 이후 추가 예정이다.

이 부분은 Apple 샘플 코드를 참고했다.

---

### 6. updateForStatistics

```swift
func updateForStatistics(_ statistics: HKStatistics) {
    Task { @MainActor in
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
            
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            let energyUnit = HKUnit.kilocalorie()
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
            
        case HKQuantityType(.cyclingCadence):
            let cadenceUnit = HKUnit.count().unitDivided(by: .minute())
            cadence = statistics.mostRecentQuantity()?.doubleValue(for: cadenceUnit) ?? 0
            
        default:
            return
        }
    }
}
```

`HKLiveWorkoutBuilderDelegate`에서 데이터가 수집될 때마다 호출되는 함수다. `HKStatistics` 타입을 받아서 어떤 종류의 데이터인지 분기하고 각 프로퍼티를 업데이트한다.

심박수는 `mostRecentQuantity()`로 가장 최근 값을, 소모 칼로리는 `sumQuantity()`로 누적 합산 값을 가져온다. 케이던스도 심박수와 마찬가지로 최근 값을 사용한다. 

이부분 역시 샘플 코드를 그대로 가져왔다.

다만 다른 샘플코드에서 `DispatchQueue.main.async`를 사용하여 담아내길래 혹시 몰라 `Task { @MainActor in }`으로 명시했다.

---

### 8. AsyncStream으로 실시간 데이터 전달

`workoutBuilder(_:didCollectDataOf:)`에서 데이터를 받으면 AsyncStream으로 흘려서 외부에서 구독할 수 있게 한다.

#### 모델링

AsyncStream으로 전달할 데이터 모델을 먼저 정의한다.

```swift
struct WatchHealthData {
    var heartRate: Double = 0
    var cadence: Double = 0
    var activeEnergy: Double = 0
}
```

심박수, 케이던스, 소모 칼로리를 담는다.

---

#### 기본 뼈대 작성

`RunningCenter`에서 사용한 AsyncStream 패턴 그대로 적용한다.

```swift
var continuation: AsyncStream<WatchHealthData>.Continuation?

func streamHealthData() -> AsyncStream<WatchHealthData> {
    AsyncStream<WatchHealthData> { continuation in
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.clearContinuation()
            }
        }
    }
}

private func clearContinuation() {
    continuation = nil
}
```

`streamHealthData()`가 호출될 때 `continuation`을 저장해두고, `workoutBuilder(_:didCollectDataOf:)`에서 `updateForStatistics()` 호출 후 `continuation?.yield()`로 데이터를 흘린다. VM에서 이 스트림을 구독해서 View에 전달하고 `WatchConnectivityService`로 전송하는 구조다.

---

### 8. delegate 함수 연결해주기

두 가지 델리게이트를 채택했으므로 각각 필수 함수를 구현해야 한다.

샘플 코드에 아래 주석이 달려 있었다.

> HealthKit calls the delegate methods on an anonymous serial background queue, so the methods need to be nonisolated explicitly.

HealthKit은 delegate 메서드를 익명의 직렬 백그라운드 큐에서 호출하기 때문에 `nonisolated`를 명시해야 한다.

```swift
// 워크아웃 세션 상태 변화 (시작, 일시정지, 종료 등)
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {

}

// 세션 에러 처리
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
    print("\(#function): \(error)")
}

// 실시간 데이터 수집 시 호출
nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    Task { @MainActor in
        for type in collectedTypes {
            if let quantityType = type as? HKQuantityType, let statistics = workoutBuilder.statistics(for: quantityType) {
                updateForStatistics(statistics)
            }
        }
        continuation?.yield(WatchHealthData(heartRate: heartRate, cadence: cadence, activeEnergy: activeEnergy))
    }
}

// 워크아웃 이벤트 수집 시 호출
nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    // 비어있어도 상관 없음
}
```

샘플 코드에서는 수집된 `[HKStatistics]` 배열을 `NSKeyedArchiver`로 `Data` 타입으로 직렬화한 뒤 미러링 세션의 `sendData()`로 전송하는 구조였다.

```swift
let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: allStatistics, requiringSecureCoding: true)
```

우리는 `WatchConnectivityService`로 전송하는 구조를 택했기 때문에 직렬화 과정 없이 `continuation?.yield()`로 `WatchHealthData`를 바로 넘기는 방식으로 변경했다. `HealthKitService`는 데이터 수집만 담당하고, 전송 책임은 VM이 갖는 방식이다.

#### didChangeTo 함수 구현하기

이 부분을 별도로 뺀 이유는 어떻게 구현해야 할지 감이 오지 않았기 때문이다. 레퍼런스도 많지 않아서 어떤 케이스를 처리해야 하는지부터 파악이 필요했다.

우리 앱에서 필요한 케이스는 세 가지다.

- `.running` — 워크아웃이 시작되거나 재개된 상태
- `.paused` — 일시정지 상태
- `.stopped` — 워크아웃이 종료된 상태. 이 시점에서 `endCollection()`, `finishWorkout()`을 호출해 수집된 데이터를 정산하고 저장한다

처음에는 `stopWorkout()` 내부에서 `finishWorkout()`까지 호출하려 했지만, Apple 샘플에서는 `stopActivity()`만 호출하고 실제 데이터 정산은 `didChangeTo(.stopped)`에서 수행한다. `WorkoutSession`이 상태 전환을 완료한 이후 Builder를 종료하는 구조가 더 자연스럽다고 판단해 동일한 패턴을 사용했다.

샘플 코드에는 `.stopped` 케이스만 있어서 우선 그것만 구현했다.

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    if toState == .stopped {
        Task { @MainActor in
            do {
                try await builder?.endCollection(at: date)
                workout = try await builder?.finishWorkout()
                session?.end()
            } catch {
                print(error)
            }
        }
    }
}
```

`endCollection(at:)`으로 빌더에게 데이터 수집 종료를 알리고, `finishWorkout()`으로 수집된 데이터를 하나의 `HKWorkout` 객체로 정산해 HealthKit에 저장한다. `workout` 프로퍼티에 보관하는 이유는 Summary 표시, SwiftData 저장, `transferUserInfo`로 iPhone 전송 시 참조하기 위해서다. 저장이 완료된 후 `session?.end()`로 세션을 닫는다.

원래는 CompletionHandler 방식이었지만 현재는 async/await를 지원하므로 변경했다. `HealthKitService`가 `@Observable`을 채택해 암묵적으로 `@MainActor`로 격리되는데, `nonisolated` delegate 안에서 일반 `Task`를 쓰면 `@MainActor` 격리 프로퍼티 접근 시 동시성 위반이 발생한다. 그래서 `Task { @MainActor in }`으로 명시했다.

---

### 9. resetWorkout 함수 만들기

운동이 끝나면 초기화를 해줄 함수를 구현한다.

```swift
func resetWorkout() {
    builder = nil
    workout = nil
    session = nil
    activeEnergy = 0
    heartRate = 0
    cadence = 0
}
```

세션, 빌더, 운동 결과, 수집 데이터를 전부 초기화한다. 다음 러닝을 위해 반드시 필요한 함수다.

---

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/healthkit.png){: width="50%" height="50%"}

---

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/healthsum.png){: width="50%" height="50%"}

간단하게 정리한 만화 두개를 준비해보았다.

---

## WatchVM에 HealthKit 연결

이제 VM에 HealthKit 관련 부분만 추가해주면 된다.

생소한 부분이라 이것도 상세하게 기록하면서 진행한다.

---

### Phase 감지 기능 구현하기

`FlightPhase` 변화에 따라 워크아웃을 시작하고 종료하는 함수를 만든다.

```swift
func updatePhase(_ changedPhase: FlightPhase) {
    currentPhase = changedPhase
    
    switch changedPhase {
    case .cruise:
        Task {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor
            try? await healthKitService.startWorkout(workoutConfiguration: config)
        }
    case .touchdown:
        healthKitService.stopWorkout()
    default:
        break
    }
}
```

`.cruise`일 때 워크아웃을 시작하고, `.touchdown`일 때 종료한다.

`HKWorkoutConfiguration`은 어떤 종류의 운동을 할지 설정하는 객체다. 여기서는 실외 러닝으로 지정했다.

`stopWorkout()`은 내부적으로 `session?.stopActivity()`만 호출한다. 실제 데이터 정산인 `endCollection()`과 `finishWorkout()`은 `HKWorkoutSessionDelegate`의 `didChangeTo` 메서드에서 세션 상태가 `.stopped`로 변경될 때 자동으로 처리된다. Apple 샘플 코드도 동일한 패턴을 사용했다.

---

### streamHealthData 구독하기

`RunningCenter`에서 사용한 `AsyncStream` 패턴과 동일하게 적용했다. `HealthKitService`는 데이터 수집만 담당하고, 전달은 스트림으로 흘리는 구조다.

```swift
func startStream() async {
    for await data in await healthKitService.streamHealthData() {
        self.healthData = data
        // WatchConnectivityService.sendMessage 연동 예정
    }
}
```

`HealthKitService`에서 흘러오는 `WatchHealthData`를 구독해서 View에 전달한다. `sendMessage` 연동은 `WatchConnectivityService` 구현 이후 추가 예정이다.

우선 기본 뼈대만 구성해두었다.

다만 두 스트림을 순차적으로 구독하면 첫 번째가 끝나야 두 번째가 시작되기 때문에 각각 `Task`로 분리해서 동시에 구독하도록 수정했다.

```swift
func startStream() async {
    Task {
        for await data in healthKitService.streamHealthData() {
            self.healthData = data
            // WatchConnectivityService.sendMessage 연동 예정
        }
    }
    Task {
        for await data in await runningCenter.streamFlightData() {
            // 생략
        }
    }
}
```

---

### 리셋 연결하기

러닝이 종료되면 HealthKit 세션, 빌더, 수집 데이터도 함께 초기화해야 다음 러닝을 깨끗하게 시작할 수 있다. `resetState()`에 `healthKitService.resetWorkout()`을 추가했다.

```swift
func resetState() async {
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

---

## 정리

지금까지 구현한 내용을 Flow로 정리하면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/watch_architecture.png){: width="50%" height="50%"}

공유할 수 있는 건 타겟 멤버십으로 공유하되, ViewModel은 iPhone과 Watch 각자의 역할에 맞게 분리했다. `LocationService`, `RunningCenter`, `FlightData`는 공유하고, HealthKit 데이터 수집은 Watch VM에서만 담당한다.

여기까지 구현하면 Watch는 독립적으로 러닝을 수행할 수 있는 상태가 된다. GPS는 `LocationService`가 수집하고, `RunningCenter`가 거리와 페이스를 계산한다. `HealthKitService`는 심박수, 케이던스, 칼로리를 수집하며, `WatchViewModel`이 이 데이터를 통합해 View에 전달한다.

즉, iPhone과 통신하지 않아도 Watch 단독으로 러닝 세션을 수행하고 결과를 생성할 수 있다. 이제 남은 작업은 이 데이터를 iPhone으로 전달하는 것이다.

---

## WatchConnectivity 구현

WatchConnectivity 설정에 앞서 앱과 Watch 간의 데이터 전달 방향성을 먼저 정리해야 한다.

앱은 어떤 데이터를 제공하고 받을 것인지, Watch는 어떤 데이터를 제공하고 받을 것인지를 생각해봤다.

지금 내린 결론은 Watch → iPhone 단방향이다.

이후 계획에는 양방향 연동이 포함되지만, 지금 당장 구현하기보다는 v1.1 또는 v1.2에서 추가할 예정이다.

아래 다이어그램처럼 세 가지 시나리오로 나눠서 방향성을 정리했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/watchconnectivity_scenarios_blog.png){: width="50%" height="50%"}

---

### Watch 기본 설정

우선 `Info.plist` 설정부터 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/infplist.png){: width="50%" height="50%"}

이후 Signing & Capabilities에서 BackgroundModes, HealthKit을 추가하고 아래 사진과 같이 체크를 해준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/deliback.png){: width="50%" height="50%"}

앱과 추가하는건 같지만 워치에선 Background Modes가 일부라서 Workout Processing에 체크를 해주면 된다.

---

### WatchConnectivity 기본 설정하기

기본 세팅이 끝났으니 이제 코드를 구현해본다.

```swift
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    
    private var session = WCSession.default
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            print("The session has completed activation.")
        }
    }
    
}
```

여기까지가 기초적인 세팅이다. iPhone 쪽도 이 구조는 동일하지만, `sessionDidBecomeInactive`와 `sessionDidDeactivate` 두 메서드가 반드시 추가로 필요하다.

---

### 데이터 송신 기능 구현하기

#### 시나리오 정의

Watch에서 iPhone으로 보내는 데이터는 두 가지 시나리오로 나뉜다.

1. 앱과 Watch를 동시에 사용하는 경우
    - Watch가 실시간으로 심박수와 케이던스를 `sendMessage`로 전달하고, iPhone은 GPS와 페이스를 자체적으로 계산한다.

2. Watch 단독으로 러닝하는 경우
    - Watch가 GPS, 심박수, 케이던스를 모두 처리하고, 러닝 종료 후 `transferUserInfo`로 결과 데이터를 iPhone에 전달해 로그북에 저장한다.

---

#### 전송 메서드 선택

그렇다면 왜 메서드가 다른가? WatchConnectivity에서 데이터를 전송하는 방법은 크게 네 가지다.

- `sendMessage(_:replyHandler:errorHandler:)`: 
    - 즉시 전송. 상대 앱이 실행 중일 때만 작동하며, 앱이 꺼져 있으면 메시지가 버려진다. 실시간 심박/케이던스처럼 최신 값만 의미 있는 데이터에 적합하다.

- `transferUserInfo(_:)`: 
    - 큐 기반 전송. 상대 앱이 꺼져 있어도 데이터가 큐에 쌓여 나중에 전달된다. 시뮬레이터에서는 동작하지 않는다. 러닝 종료 후 결과처럼 반드시 전달되어야 하는 데이터에 적합하다.

- `transferFile(_:metadata:)`: 
    - 파일 전송. 이미지나 오디오처럼 용량이 큰 파일을 전송할 때 사용한다.

- `updateApplicationContext(_:)`: 
    - 최신 상태 동기화. 이전에 보낸 데이터를 덮어쓰며, 상대 앱이 다음에 실행될 때 가장 최근 상태만 전달된다. 양쪽 기기의 최신 상태를 맞춰두는 용도에 적합하다.

유튜브를 보다가 간략하게 정리해준 영상을 보고 캡쳐를 해뒀다가 여기에 다시 정리를 해보았다.

---

#### ViewModel 의존성 주입

이제 구현을 시작한다.

그전에 `WatchConnectivityService`는 `NSObject` 서브클래스라 SwiftUI를 import하지 않으므로 `@Environment`로 ViewModel을 가져올 수 없다. 

대신 `weak var`로 참조를 만들고, `WatchViewModel.init()`에서 직접 주입하는 방식으로 해결한다. `weak`를 쓰는 이유는 VM과 Service가 서로를 참조할 때 생기는 순환 참조를 방지하기 위해서다.

```swift
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    weak var viewModel: WatchViewModel?
    // 생략
}

final class WatchViewModel {
    // 생략
    init() {
        // 생략
        watchConnectivityService.viewModel = self
    }
}
```

---

#### 구현하기 (Watch)

##### sendMessage

이제 워치에서 측정한 건강 데이터를 전달하는 `sendMessage`를 구현한다.

```swift
func sendHealthData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    let message: [String: Any] = [
        "heartRate": viewModel?.healthData.heartRate ?? 0,
        "cadence": viewModel?.healthData.cadence ?? 0,
        "activeEnergy": viewModel?.healthData.activeEnergy ?? 0
    ]
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
}
```

`sendMessage`의 payload는 반드시 `[String: Any]` 딕셔너리 타입이어야 한다. `viewModel?.healthData`에서 최신 값을 꺼내 담아서 전송한다.

전송 전에 세션 활성화 상태(`activationState == .activated`)와 상대방 앱 연결 상태(`isReachable`)를 먼저 체크해 불필요한 전송을 막는다.

---

##### transferUserInfo

Watch 단독 러닝이 종료됐을 때 전체 러닝 결과를 iPhone으로 전달하는 메서드다. `sendMessage`와 달리 iPhone 앱이 꺼져 있어도 큐에 쌓여 나중에 전달된다.

건강 데이터뿐만 아니라 거리, 시간, 페이스, 날짜까지 러닝 결과 전체를 담아 보낸다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
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

`transferUserInfo`는 `isReachable` 체크가 필요 없다. 상대방이 연결되지 않아도 전송이 보장되는 구조이기 때문이다. 

`date`는 `Date` 타입을 딕셔너리에 직접 담을 수 없어 `timeIntervalSince1970`으로 변환했다.

---

##### VM 수정하기

앞서 구현 예정으로 남겨뒀던 부분에 `sendHealthData()`를 추가한다.

```swift
func startStream() async {
    Task {
        for await data in healthKitService.streamHealthData() {
            self.healthData = data
            watchConnectivityService.sendHealthData() // added
        }
    }
    // 생략
}
```

HealthKit 데이터가 업데이트될 때마다 iPhone으로 실시간 전송한다.

---


#### 구현하기 (iPhone)

이제 앱에서 데이터를 받아야 한다.

`WatchConnectivityService`를 타겟 공유로 사용할 수도 있지만, 송신과 수신 역할이 명확하게 나뉘므로 별도로 관리하는 방향으로 결정했다.

##### 기본 세팅

Watch 쪽과 구조는 동일하다. 다만 iPhone에서는 `sessionDidBecomeInactive`와 `sessionDidDeactivate` 두 메서드가 추가로 필요하다.

```swift
private var session = WCSession.default

override init() {
    super.init()
    
    if WCSession.isSupported() {
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
    if let error = error {
        print(error.localizedDescription)
    } else {
        print("The session has completed activation.")
    }
}

func sessionDidBecomeInactive(_ session: WCSession) { }

func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
}
```

---

##### didReceiveMessage

별도 함수 구성 없이 자동완성으로 코드 블럭 내부를 구현하면 된다. `didReceiveUserInfo`도 마찬가지다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/didreceive.png){: width="50%" height="50%"}

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let heartRate = message["heartRate"] as? Double,
          let cadence = message["cadence"] as? Double,
          let activeEnergy = message["activeEnergy"] as? Double else { return }
    
    Task { @MainActor in
        viewModel?.healthData?.heartRate = heartRate
        viewModel?.healthData?.cadence = cadence
        viewModel?.healthData?.activeEnergy = activeEnergy
    }
}
```

`RunViewModel`에도 동일하게 `weak var`로 의존성을 주입해준다.

```swift
var healthData: WatchHealthData? = nil

init() {
    // 생략
    watchConnectivityService.viewModel = self
}
```

`healthData`를 옵셔널로 선언한 이유는 Watch 없이 iPhone만으로 러닝하는 경우도 있기 때문이다. 값이 없으면 HR, 케이던스를 표시하지 않거나 기본값으로 처리할 수 있다.

---

##### didReceiveUserInfo

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
        viewModel?.pendingWatchData = flight
    }
}
```

`modelContext`가 `WatchConnectivityService`에 없어서 직접 SwiftData에 저장할 수 없다. 대신 `pendingWatchData`에 임시 보관하고 View에서 저장하는 방식을 택했다.

ViewModel에 옵셔널로 선언한 이유는 Watch 단독 러닝을 하지 않을 때는 값이 없어야 하기 때문이다.

```swift
var pendingWatchData: SwiftDataFlight? = nil
```

---

##### VM 수정하기

이제 받은 데이터를 처리해야 한다.

1. healthData
2. pendingWatchData

---

###### healthData

`PFDView`에서 `healthData`를 받아 게이지에 매핑한다. Watch 없이 러닝할 경우 `healthData`가 `nil`이므로 `--`로 처리했다.

```swift
Group {
    if let healthData = runViewModel.healthData {
        HStack(spacing: 8) {
            N1GaugeView(label: "HR N1%", value: Int(healthData.heartRate), color: .rwRed, zone: "ZONE 4")
            N1GaugeView(label: "CAD N1%", value: Int(healthData.cadence), color: .rwGreen, zone: "ZONE 4")
        }
    } else {
        HStack(spacing: 8) {
            N1GaugeView(label: "HR N1%", value: 0, color: .rwRed, zone: "--")
            N1GaugeView(label: "CAD N1%", value: 0, color: .rwGreen, zone: "--")
        }
    }
}
.padding(.horizontal, 16)
```

`Group`으로 묶어서 `.padding()`을 한 번에 처리했다.

---

SummaryView에서는 평균값이 필요한데, 지금은 실시간으로 데이터를 받아 모델에 저장하는 구조라 별도로 누적 배열을 만들었다.

```swift
// ViewModel
var heartRateBuffer: [Double] = []
var cadenceBuffer: [Double] = []

// WatchConnectivityService
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let heartRate = message["heartRate"] as? Double,
          let cadence = message["cadence"] as? Double,
          let activeEnergy = message["activeEnergy"] as? Double else { return }
    
    Task { @MainActor in
        viewModel?.healthData?.heartRate = heartRate
        viewModel?.healthData?.cadence = cadence
        viewModel?.healthData?.activeEnergy = activeEnergy
        
        viewModel?.heartRateBuffer.append(heartRate)
        viewModel?.cadenceBuffer.append(cadence)
    }
}
```

데이터를 받을 때마다 `healthData`는 최신값으로 업데이트하고, 버퍼 배열에는 계속 누적한다.

`saveRunningData()`에서 버퍼 평균을 계산해 SwiftData에 저장한다.

```swift
let avgHR = runViewModel.heartRateBuffer.isEmpty ? 0 : Int(runViewModel.heartRateBuffer.reduce(0, +) / Double(runViewModel.heartRateBuffer.count))
let avgCad = runViewModel.cadenceBuffer.isEmpty ? 0 : Int(runViewModel.cadenceBuffer.reduce(0, +) / Double(runViewModel.cadenceBuffer.count))
let avgFuel = Int(runViewModel.healthData?.activeEnergy ?? 0)

let runningData = SwiftDataFlight(mode: mode, distance: totalDistance, time: totalTime, pace: totalPace, heartRate: avgHR, cadence: avgCad, fuel: avgFuel, date: .now)
```

SummaryView에서는 저장된 값을 Computed Property로 꺼내 표시한다. 값이 0이면 Watch 연동 없이 러닝한 경우이므로 `--`로 처리했다.

```swift
var avgHeartRate: String {
    guard let hr = displayFlight?.heartRate, hr > 0 else { return "--" }
    return "\(hr)"
}

var avgCadence: String {
    guard let cad = displayFlight?.cadence, cad > 0 else { return "--" }
    return "\(cad)"
}
```

---

그리고 SummaryView에서도 

```swift
VStack(spacing: 0) {
    WatchSummaryRow(label: "DISTANCE", value: String(format: "%.2f km", viewModel.flightData.distance / 1000), color: .rwText)
    WatchSummaryRow(label: "TIME", value: PaceFormatter.secondToTime(viewModel.elapsedTime), color: .rwText)
    WatchSummaryRow(label: "AVG PACE", value: PaceFormatter.format(viewModel.flightData.pace) + "/km", color: .rwAmber)
    WatchSummaryRow(label: "CALORIES", value: String(format: "%.0f kcal", viewModel.healthData.activeEnergy), color: .rwAmber)
}
```

하드코딩 부분에 매핑을 해준다.

---

###### pendingWatchData

WatchConnectivity에서 바로 저장하는 방법도 있지만 `modelContext`가 없어서 아키텍처 흐름과 맞지 않는다. 고민 끝에 항상 살아있는 루트 뷰인 `HomeView`에서 `pendingWatchData` 변화를 감지해 저장하는 방식으로 결정했다.

```swift
@Environment(\.modelContext) private var modelContext

.onChange(of: runViewModel.pendingWatchData) { _, newValue in
    if let flight = newValue {
        modelContext.insert(flight)
        runViewModel.pendingWatchData = nil
    }
}
```

저장 후 `nil`로 초기화해서 중복 저장을 방지한다.

`pendingWatchData` 추가를 하면서 생각이 났기에 `resetState()`에도 초기화 항목을 추가했다.

```swift
func resetState() async {
    isRunning = false
    isModeA = false
    isPaused = false
    elapsedTime = 0
    tempAlertArray = []
    flightData = FlightData()
    heartRateBuffer = []
    cadenceBuffer = []
    healthData = nil
    pendingWatchData = nil
    await runningCenter.reset()
    navigationPath = []
}
```

---

## 문제 수정

```swift
RunWay/WatchConnectivityService.swift
```

앱 실행 시 여기서 크래시가 발생했다. [이전 글](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/#nonisolated%EB%A1%9C-%EB%B0%B1%EA%B7%B8%EB%9D%BC%EC%9A%B4%EB%93%9C-%EC%9E%91%EC%97%85-%EB%B6%84%EB%A6%AC%ED%95%98%EA%B8%B0){:target="_blank"}에서도 같은 문제가 있었다.

Xcode 26의 기본 설정인 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`로 인해 클래스가 암묵적으로 `@MainActor`에 격리되면서, WatchConnectivity delegate가 백그라운드 스레드에서 호출될 때 크래시가 발생하는 구조다.

`nonisolated`를 클래스 선언에 추가해서 해결했다. 다만 이렇게 하면 `Task { @MainActor in }` 안에서 `self`를 캡처할 때 data race 에러가 발생한다. `viewModel`을 함수 내부에서 로컬 변수로 먼저 캡처한 뒤 Task에 넘기는 방식으로 해결했다.

```swift
nonisolated final class WatchConnectivityService: NSObject, WCSessionDelegate {

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // 생략
        let vm = viewModel
        Task { @MainActor in
            vm?.healthData?.heartRate = heartRate
            vm?.healthData?.cadence = cadence
            vm?.healthData?.activeEnergy = activeEnergy
            vm?.heartRateBuffer.append(heartRate)
            vm?.cadenceBuffer.append(cadence)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // 생략
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
            vm?.pendingWatchData = flight
        }
    }
}
```

이젠 실행이 된다.

---

## 워치 인식 문제 해결

Xcode에서 Watch를 인식하지 못해서 Devices and Simulators 목록을 확인해보니

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/developer.png){: width="50%" height="50%"}

Developer Mode가 비활성화된 게 원인이었다. 활성화 후 재부팅해도 연결이 안 돼서 사진에는 없지만 Connect 버튼을 직접 눌러주니 연결이 시작됐다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/connect.png){: width="50%" height="50%"}

처음 연결 시 심볼 데이터를 다운로드하기 때문에 완료될 때까지 기다려야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-13-RunningProject-12/down.png){: width="50%" height="50%"}

---

갑자기 pid 570 에러가 발생했다.

워치에서 앱을 삭제후 개발자 모드를 끄고 다시 켜서 재부팅을 하니 해결이 되었다.

워치 테스트 해보고 또 적어보도록 하겠다.

---

## 간이 테스트 결과

실기기 테스트에서 두 가지 문제를 확인했다.

첫째, 위치 데이터를 전혀 가져오지 못해 페이스, 거리 등 GPS 관련 데이터가 하나도 표시되지 않았다.

둘째, HealthKit 데이터도 수집되지 않았다. 앱 삭제 후 재설치 시 위치 권한만 요청하고 HealthKit 권한 요청이 뜨지 않은 것으로 보아 권한 요청 자체가 제대로 동작하지 않는 것으로 보인다.

내용이 길기도 하고 많이했기에 다음글에서 수정을 해보도록 하겠다.