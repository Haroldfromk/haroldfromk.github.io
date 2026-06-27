---
title: RunWay (15) iPhone 주도 미러링 & CoreMotion
writer: Harold
date: 2026-06-22 08:33:00 +0900
last_modified_at: 2026-06-25 08:33:00 +0900
categories: [RunWay]
tags: [watchOS, WatchConnectivity, HealthKit]

toc: true
toc_sticky: true
published: true
---

요새 너무 빡시게 달리기도 해서 며칠간 휴식을 좀 취하고 오늘 다시 이어서 해본다.

# iPhone 주도 미러링

이전까지 Watch 주도의 미러링이었다면, 이번엔 iPhone을 주도로 미러링을 해보려고 한다.

시작하기 전 플로우를 정리해보면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/iphone_led_mirroring_flow.png){: width="50%" height="50%"}

사실 기본적으로 Watch 주도의 미러링과는 개념이 같기 때문에 그것과 유사하게 하면 될 것 같다.

---

## HealthKitService 수정

우선 앱에서도 운동 시작을 알릴 `startWorkout`을 만들어 보도록 한다.

Watch 주도 미러링 때처럼 iPhone에도 `HKWorkoutSession`을 직접 생성하는 함수를 만들면 되겠다고 생각했다.

### 문제점?

그런데 여기서 한 가지 문제가 생긴다. `HKLiveWorkoutBuilder`를 iPhone에서 직접 써서 운동 데이터를 수집하는 기능이 iOS 26부터 지원되기 때문이다. 우리 프로젝트의 최소 버전은 18.5로 잡아두었는데, builder 없이는 iPhone이 직접 `HKWorkoutSession`을 만들고 관리할 수가 없다.

| | iOS 18.5 | iOS 26 |
|---|---|---|
| iPhone에서 `HKWorkoutSession` 생성 | 불가 | 가능 |
| `HKLiveWorkoutBuilder` 직접 사용 | 불가 | 가능 |
| 워크아웃 세션의 주인 | Watch만 가능 | iPhone도 가능 |
| 호환 기기 | 더 넓음 | 최신 기기로 한정 |

어차피 완성도를 높이는 방향으로 가는 게 맞다고 판단해서, Deploy Version을 26으로 올리기로 했다.

---

### StartWorkout

이제 버전을 올렸으니 구현을 해보도록 한다.

우선 builder와 `HKLiveWorkoutBuilderDelegate`를 적용해준다. 이때 별도로 extension을 사용해서 관리를 하려고 한다.

```swift
extension HealthKitService: HKLiveWorkoutBuilderDelegate {

    func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
        session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
        builder = session?.associatedWorkoutBuilder()
        session?.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: workoutConfiguration)

        let startDate = Date()
        session?.startActivity(with: startDate)
        try await builder?.beginCollection(at: startDate)

        if WCSession.default.isReachable {
            do {
                //try await session?.startMirroringToCompanionDevice()
                print("iPhone: startWatchApp called")
            } catch {
                print("iPhone: startWatchApp failed - \(error)")
        }
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {

    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {

    }


}
```

`startWorkout`은 기존에 Watch에서 구현한 코드를 그대로 가져왔다. 그리고 delegate에서 필수적인 메서드도 가져오면 기본 세팅은 끝이 난다.

일부러 지금 `startMirroringToCompanionDevice`에 대해 주석을 해두었는데, 이건 앱에서는 사용할 수 없는 메서드이기 때문이다. 

iPhone이 직접 세션을 만든 경우에는 그 세션을 Watch에 공유하는 방향이 반대이므로, `startMirroringToCompanionDevice()`가 아니라 `startWatchApp(toHandle:)`를 호출해야 한다.

즉 `isReachable`의 코드블럭은

```swift
if WCSession.default.isReachable {
    do {
        try await store.startWatchApp(toHandle: workoutConfiguration)
        print("iPhone: startWatchApp called")
    } catch {
        print("iPhone: startWatchApp failed - \(error)")
    }
}
```

이렇게 해줘야 한다.

> Launches or wakes the companion watchOS app to create a new workout session

[startWatchApp(toHandle:) docs](https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:)){:target="_blank"}를 보면 위와 같이 되어 있다.

새 워크아웃 세션을 생성하기 위해 동반 watchOS 앱을 실행하거나 깨운다는 것이다.

다시말해 앱을 켜고 러닝을 하면 Watch가 자동으로 앱을 실행하게 된다.

---

### VM에서 호출하기

Watch와 마찬가지로 cruise일때 적용을 해보도록 한다.

```swift
func updatePhase(_ phase: FlightPhase) {
    currentPhase = phase
    Task {
        await runningCenter.updatePhase(phase)
    }
    switch currentPhase {
    case .cruise:
        Task {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor
            do {
                try await healthKitService.startWorkout(workoutConfiguration: config)
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

// HealthKitService
func stopWorkout() {
    session?.stopActivity(with: Date())
}
```

이때 워크아웃을 중단하는것도 만들어야 하므로 같이 추가해준다.

---

### Watch에서 미러링 수신하기

우선 [startWatchApp Docs](https://developer.apple.com/documentation/healthkit/hkhealthstore/startwatchapp(with:completion:)){:target="_blank"}를 보니 `WKApplicationDelegate`를 사용하여 workout을 시작하는 예시가 있어 이것을 먼저 적용해본다.

```swift
class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task {
            await WorkoutManager.shared.startWorkout()
        }
    }
}
```

다만 문서 예시는 `WorkoutManager.shared`처럼 싱글톤을 전제로 만들어져 있다. 우리 프로젝트는 의도적으로 싱글톤을 쓰지 않고 있어서 처음에는 다른 방법을 고민했다.

`@WKApplicationDelegateAdaptor`로 등록한 `AppDelegate`가 `HealthKitService` 인스턴스를 들고 있고, `WatchViewModel`이 그걸 주입받아 쓰는 구조를 생각해봤다. 하지만 `@WKApplicationDelegateAdaptor`가 자체적으로 인스턴스를 새로 만들기 때문에, `WatchViewModel`이 들고 있는 `HealthKitService`와 `AppDelegate`가 들고 있는 `HealthKitService`가 서로 다른 인스턴스가 되어 세션 불일치 문제가 생길 수 있었다.

결국 `HealthKitService`를 싱글톤으로 바꾸기로 했다. `HKHealthStore` 자체가 Apple 문서에서도 앱당 하나만 만들라고 권장하는 자원이고, 워크아웃 세션도 기기당 하나만 의미가 있으니 본질적으로 "앱에 하나"가 자연스럽다. Apple 샘플 코드에서도 `WorkoutManager.shared`를 쓰고 있는 게 같은 이유일 것이다.

무분별한 싱글톤 사용은 의존성 추적이 어려워지는 문제가 있지만, 이 경우는 시스템적으로 하나만 존재해야 하는 자원이라는 근거가 명확하고 나머지는 전부 DI로 관리하고 있어서 크게 문제될 것이 없다고 판단했다.

[WKApplicationDelegate Docs](https://developer.apple.com/documentation/WatchKit/WKApplicationDelegate){:target="_blank"}를 보면 `NSObject`를 상속한 delegate 클래스를 만들고, SwiftUI `App`에서 `@WKApplicationDelegateAdaptor`로 등록해주는 방식을 안내하고 있다.

```swift
import WatchKit

class MyWatchAppDelegate: NSObject, WKApplicationDelegate {

}
```

```swift
import SwiftUI

@main
struct MyWatchApp_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor var appDelegate: MyWatchAppDelegate
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
    }
}
```

그대로 따라가되, `handle(_:)` 안에서 `HealthKitService.shared.startWorkout()`을 호출하는 구조로 가기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/single.png){: width="50%" height="50%"}

---

### 싱글턴으로 리팩토링

이참에 지금까지 iPhone과 Watch에 각각 별도로 만들어두었던 `HealthKitService`도 하나로 합치기로 했다. Apple 샘플 프로젝트처럼 공통 부분은 `HealthKitService.swift`에 두고, 플랫폼별 전용 코드는 extension으로 분리하는 구조다.

- `HealthKitService.swift` — 공통 (싱글톤 선언, session, builder, startWorkout, stopWorkout)
- `HealthKitService+iOS.swift` — iPhone 전용 (retrieveRemoteSession, fetch 함수들 등)
- `HealthKitService+watchOS.swift` — Watch 전용 (streamHealthData, updateForStatistics 등)

각 파일에 해당 타겟 멤버십만 걸어주면 `#if os()` 분기 없이도 컴파일러가 타겟에 포함된 파일만 빌드하게 된다.

<script src="https://gist.github.com/Haroldfromk/4b97a23a28484fd1599cd25228e208bb.js"></script>

코드는 생략하도록 한다.

---

`WatchConnectivityService`도 지금까지 iPhone용, Watch용으로 완전히 별도 파일로 나뉘어 있었는데, 같은 패턴으로 정리하기로 했다.

다만 한 가지 걸리는 부분이 있었다. iPhone은 `weak var viewModel: RunViewModel?`을, Watch는 `weak var viewModel: WatchViewModel?`을 들고 있어서, `viewModel`의 타입 자체가 플랫폼마다 다르다. `HealthKitService`를 합칠 때는 이런 VM 타입 의존성이 없었어서 새로운 고민이었다.

```swift
#if os(iOS)
weak var viewModel: RunViewModel?
#elseif os(watchOS)
weak var viewModel: WatchViewModel?
#endif
```

이렇게 `viewModel` 프로퍼티 타입만 `#if os()`로 분기해서 공통 파일에 두고, 나머지는 동일하게 extension으로 나누기로 했다.

- `WatchConnectivityService.swift` — 공통 (클래스 선언, session, lastSentTime, viewModel, activationDidCompleteWith)
- `WatchConnectivityService+iOS.swift` — iPhone 전용 (sendFlightData, didReceiveUserInfo 등)
- `WatchConnectivityService+watchOS.swift` — Watch 전용 (sendHealthData, sendRunningData, sendModeData 등)

이렇게 분리하고 나니 새로운 경고가 떴다.

```text
Conformance of 'WatchConnectivityService' to protocol 'WCSessionDelegate' crosses into main actor-isolated code and can cause data races; this is an error in the Swift 6 language mode
```

`WCSessionDelegate`는 `NSObjectProtocol`을 상속하는데, 이게 `@MainActor`로 격리되어 있다. 그런데 클래스 자체는 `nonisolated`로 선언했으니, Swift 동시성 모델에서 격리 충돌이 발생한 것이다.

해결을 위해 `WCSessionDelegate` 준수를 클래스 선언에서 분리하고, `@preconcurrency`가 붙은 별도 extension으로 옮겼다.

```swift
nonisolated final class WatchConnectivityService: NSObject {
    // 생략
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            print("The session has completed activation.")
        }
    }
}
```

`@preconcurrency`는 Swift 동시성 도입 이전에 설계된 프로토콜(`WCSessionDelegate`)이 `nonisolated` 클래스에서 준수될 때 발생하는 격리 충돌 경고를 억제해준다. `WCSession`의 delegate 콜백은 어차피 백그라운드 스레드에서 호출되니, 이 방식이 적절했다.

---

### AppDelegate 파일 만들기

이제 [WKApplicationDelegate Docs](https://developer.apple.com/documentation/WatchKit/WKApplicationDelegate){:target="_blank"}에 안내된 대로 delegate 클래스를 만들어본다

```swift
class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task {
            do {
                try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
            } catch {
                print(error)
            }
        }
    }
}
```

`handle(_:)` 안에서 에러가 나면 어떻게 처리할지가 고민이었다. 단순히 `print(error)`로 묻어버리면, 나중에 사용자에게 알려주거나 UI에 반영할 방법이 없어진다.

`RunViewModel`이 이미 `alertPublisher`로 에러를 Combine을 통해 흘려서 View가 구독하는 패턴을 쓰고 있으니, `AppDelegate`도 같은 방식으로 가는 게 맞다고 생각했다. `HealthKitService`(이미 싱글톤이니)에 에러 publisher를 두고, `AppDelegate`는 에러를 그쪽으로 흘려보내기만 하고, 실제 처리는 `WatchViewModel`이나 View 쪽에서 구독해서 하는 구조다.

다만 지금은 `HealthKitService`에 아직 publisher 자체가 없는 상태라서, 이 부분은 일단 `print(error)`로 임시 처리해두고 다음에 다루기로 한다.

---

### WatchRunWayApp에 적용하기

이제 WatchApp에 적용을 해본다.

```swift
@main
struct WatchRunWayApp: App {

    @WKApplicationDelegateAdaptor var appDelegate: AppDelegate

    @State private var watchViewModel = WatchViewModel()
    @State private var navigationViewModel = NavigationViewModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(watchViewModel)
                .environment(navigationViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
```

[WKApplicationDelegateAdaptor Docs](https://developer.apple.com/documentation/swiftui/wkapplicationdelegateadaptor){:target="_blank"}에 의하면 `@WKApplicationDelegateAdaptor`는 SwiftUI의 `App` 라이프사이클 안에서 `WKApplicationDelegate`를 함께 사용할 수 있게 해주는 프로퍼티 래퍼다.

---

### WatchViewModel에 적용하기

이제 앱에서 했던 것과 동일하게 Watch에도 화면 전환을 연결해본다.

다만 그 전에 `NavigationViewModel`을 다시 걷어내야 했다. `WatchAppDelegate`가 `HealthKitService.shared.sessionStatePublisher`를 구독해서 화면 전환을 트리거해야 하는데, `NavigationViewModel`이 별도 객체로 분리되어 있어 `WatchViewModel.init()` 시점에 `@Environment`로 받아올 방법이 없었다.

생각해보면 `NavigationViewModel` 분리는 애초에 watchOS NavigationStack 경고를 해결하려고 시도했던 거였는데, 경고 자체는 해결되지 않고 구조만 복잡해진 채로 남아 있었다. 이번 기회에 다시 `WatchViewModel`이 `navigationPath`를 직접 들고 있는 구조로 되돌렸다.

---

이제 적용을 해보면 우선 코드구조 자체는 RunViewModel에서 했던 방식과 같다.

`WatchViewModel.init()`에 그대로 적용을 해주면 된다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] state in
        guard let self else { return }
        if state == .running {
            self.navigateTo(.pfd)
        } else if state == .stopped {
            Task {
                await self.resetState()
            }
        }
    }
    .store(in: &cancellables)
```

iPhone에서 러닝을 시작하면 `startWatchApp(toHandle:)` → Watch가 `handle(_:)`로 받아서 `startWorkout()` 호출 → `HKWorkoutSession`이 `.running`으로 전환 → `sessionStatePublisher`가 그 상태를 흘려보내고 → `WatchViewModel`이 구독하고 있다가 `navigateTo(.pfd)`로 화면을 전환한다.

---

#### 문제 1. isRemoted가 잘못 설정됨

테스트 도중 문제를 발견했다.

일단 Watch가 켜지지 않기도 했지만, 앱에서 러닝 종료 시 바로 홈 화면으로 점프되어버렸다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/problem.gif){: width="50%" height="50%"}

신기한 건 TOUCHDOWN 화면이 잠깐 보였다가 곧바로 홈으로 튕긴다는 점이었다. 즉 화면 전환 자체는 정상적으로 일어났는데, 그 직후에 뭔가가 강제로 `navigationPath`를 비워버리는 셈이었다.

원인은

```swift
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

이 부분이었다. `.running` 상태가 들어오면 무조건 `isRemoted = true`로 세팅하고 있는데, iOS 26으로 올리면서 이제는 iPhone에서도 직접 `HKWorkoutSession`을 만들 수 있게 됐다. 

그래서 iPhone 단독으로 러닝을 시작해도 똑같이 `.running` 신호가 들어오면서 `isRemoted`가 `true`가 되어버린 것이다.

`isRemoted`는 원래 "Watch에서 미러링된 세션을 받았다"는 의미로 만들었던 플래그인데, 지금은 `.running`이라는 상태값 자체에만 반응하다 보니 출처(Watch가 먼저 시작했는지, iPhone이 직접 시작했는지)를 구분하지 못하고 있었다. 

그 결과 iPhone 단독 러닝에서도 종료 시 `.stopped` 핸들러가 자동으로 `resetState()`를 호출해버려, TOUCHDOWN을 거치지 않고 곧바로 홈으로 돌아가는 문제가 생긴 것이다.

게다가 Watch 쪽에서도 신기한 현상이 있었다. Watch 앱을 직접 켜지 않아도, iPhone에서 러닝을 시작하는 순간 Watch 인터페이스에 운동 링이 자동으로 표시됐다. 

iOS 26부터는 페어링된 Watch에 운동 상태를 시스템 레벨에서 자동으로 동기화해주는 것으로 보인다.

결국 `retrieveRemoteSession()`(Watch 주도로 시작된 세션을 받는 경로)과 `startWorkout()`(iPhone이 직접 시작한 세션)이 같은 `sessionStatePublisher`를 공유하면서, 어느 경로로 들어온 `.running`인지 구분할 방법이 없는 게 근본 원인이었다.

---

#### 해결책

그래서 이제는 Publisher로 전달할 때 State만 전달하는 게 아니라, Tuple로 미러링인지 아닌지도 같이 보내는 게 좋다고 판단했다.

```swift
// Before
var sessionStatePublisher = PassthroughSubject<HKWorkoutSessionState, Never>()

@MainActor
func handleiOSStateChange(_ toState: HKWorkoutSessionState) {
    if toState == .stopped {
        session?.end()
        sessionStatePublisher.send(toState)
    } else if toState == .running {
        print("iPhone: sending .running to sessionStatePublisher")
        sessionStatePublisher.send(toState)
    }
}
// After
var sessionStatePublisher = PassthroughSubject<(HKWorkoutSessionState, Bool), Never>()

@MainActor
func handleiOSStateChange(_ toState: HKWorkoutSessionState, isMirrored: Bool) {
    if toState == .stopped {
        session?.end()
        sessionStatePublisher.send((toState, isMirrored))
    } else if toState == .running {
        print("iPhone: sending .running to sessionStatePublisher")
        sessionStatePublisher.send((toState, isMirrored))
    }
}
```

이 `isMirrored` 값을 어디서 들고 있을지가 문제였다. 공통 `HealthKitService`에 플래그를 하나 추가해서, 세션이 시작되는 시점마다 직접 세팅해주는 방식으로 갔다.

```swift
var isMirroredSession: Bool = false
```

`startWorkout()`은 iPhone이든 Watch든 자기 자신이 직접 세션을 시작하는 경우이므로, 호출 시작 지점에서 `false`로 세팅한다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    isMirroredSession = false
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    // 생략
}
```

반대로 `retrieveRemoteSession()`은 Watch에서 미러링된 세션을 받는 경로이므로, 세션을 받는 시점에 `true`로 세팅한다.

```swift
func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        print("iPhone: mirroring start handler fired")
        Task { @MainActor in
            self.session = mirroredSession
            self.session?.delegate = self
            self.isMirroredSession = true
            print("Start mirroring remote session: \(mirroredSession)")

            if mirroredSession.state == .running {
                print("iPhone: session already running, handling directly")
                self.handleiOSStateChange(.running, isMirrored: self.isMirroredSession)
            }
        }
    }
}
```

이제 `RunViewModel`에서도 `isRemoted`를 세팅할 때 Tuple로 받은 `isMirrored` 값을 그대로 사용하도록 바꿔주었다.

```swift
healthKitService.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.0 == .running {
            isRemoted = result.1
            self.navigationPath.append(.pfd)
        } else if result.0 == .stopped {
            if result.1 {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

`.running`일 때는 받은 `isMirrored` 값을 그대로 `isRemoted`에 반영하고, `.stopped`일 때는 `isMirrored`가 `true`인 경우(Watch가 종료를 트리거한 경우)에만 자동으로 `resetState()`를 호출하도록 가드를 걸었다. 이제 iPhone이 직접 시작한 러닝은 종료 시 자동으로 홈으로 튕기지 않고, TOUCHDOWN → Summary 흐름을 그대로 따라가게 된다.

---

#### 문제 2. PFD가 중복 push 됨

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/problem1.gif){: width="50%" height="50%"}

현재 PFDView가 빠르게 2번 호출되고 있다.

원인을 따라가보면, `TakeoffView`의 카운트다운이 끝나면 이미 `runViewModel.navigationPath.append(.pfd)`를 직접 호출하고 있는데, `sessionStatePublisher`도 `.running`이 들어오면 똑같이 PFD를 push하고 있었다. iPhone이 직접 시작한 러닝에서는 이 두 경로가 동시에 실행되면서 PFD가 중복으로 push되고 있었던 것이다.

```swift
healthService.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.0 == .running {
            isRemoted = result.1
            self.navigationPath.append(.pfd)
        } else if result.0 == .stopped {
            if isRemoted {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

`sessionStatePublisher`를 통한 PFD 전환은 원래 Watch 주도 미러링 시나리오를 위해 만든 거였다. 

`TakeoffView`를 거치지 않고 Watch에서 바로 러닝이 시작되니, 이 경로를 통해서만 PFD로 넘어갈 수 있기 때문이다. 반면 iPhone이 직접 시작한 경우는 `TakeoffView`가 이미 화면 전환을 처리하고 있으니 여기서 또 보낼 필요가 없었다.

그래서 `isRemoted`(미러링 여부)일 때만 PFD를 push하도록 가드를 추가했다.

```swift
if isRemoted {
    self.navigationPath.append(.pfd)
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/done1.gif){: width="50%" height="50%"}

이제는 잘 된다.

---

#### 문제 3. Watch 앱이 실행되지 않음

Watch 앱이 실행되지 않는 문제를 해결해본다.

우선 근본적인 원인을 파악하기 위해 콘솔에 출력을 해보면서 어디서 멈추는지 확인해보았다. 일단 `AppDelegate`가 실행되는지부터 확인해보니 출력이 되지 않았다.

즉 iPhone에서 Watch 앱을 실행시키는 로직 자체가 작동하지 않고 있었던 것이다. 그래서 `startWorkout`에

```swift
print("iPhone: isReachable = \(WCSession.default.isReachable)")
```

이렇게 찍어보니 `false`가 떴다. iPhone과 Watch가 같이 있음에도 `false`가 뜨는 게 이상했는데, 찾아보니 `isReachable`은 Watch 앱이 foreground에서 떠 있거나 워크아웃처럼 백그라운드에서 높은 우선순위로 실행 중일 때만 `true`가 된다고 한다. 그러니까 지금 우리가 Watch 앱을 막 켜려고 하는 시점에는 당연히 `false`인 게 정상이었던 것이다. `startWatchApp(toHandle:)`은 원래 Watch 앱이 꺼져있는 상태에서 깨우기 위해 쓰는 API인데, `isReachable`로 막아버리면 정작 필요한 상황에서는 호출이 안 되는 구조였다.

그래서 `isReachable` 분기를 빼고

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    // 생략

    print("iPhone: isReachable = \(WCSession.default.isReachable)")

    #if os(iOS)
    do {
        print("iPhone: about to call startWatchApp")
        try await store.startWatchApp(toHandle: workoutConfiguration)
        print("iPhone: startWatchApp called")
    } catch {
        print("iPhone: startWatchApp failed - \(error)")
    }
    #else
    if WCSession.default.isReachable {
        do {
            try await session?.startMirroringToCompanionDevice()
            print("Watch: startMirroringToCompanionDevice called")
        } catch {
            print("Watch: mirroring failed - \(error)")
        }
    }
    #endif
}
```

이렇게 iOS 분기에서만 `if`를 빼고 무조건 호출하도록 바꾸니 Watch가 실행되는 것을 확인했다. Watch 쪽(`startMirroringToCompanionDevice()`)은 iPhone 앱이 떠 있어야 의미가 있는 호출이라 가드를 그대로 남겨두었다.

하지만 PFDView로 넘어가지는 않았다. 이제 이 부분을 확인해보려 한다. 

---

#### 문제 4. PFD전환이 안됨

PFD로 전환이 안 되던 이유는 watchOS 쪽 `didChangeTo`에서 `.running`에 대한 처리 자체가 없었기 때문이었다. `.stopped`만 처리하고 있었고 `.running`은 그냥 비어 있었던 것이다.

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {

    #if os(iOS)
    Task {
        await self.handleiOSStateChange(toState, isMirrored: self.isMirroredSession)
    }
    #elseif os(watchOS)
    Task {
        await self.handleWatchOSStateChange(toState, date: date)
    }
    #endif
}

// HealthKitService(watch)
@MainActor
func handleWatchOSStateChange(_ toState: HKWorkoutSessionState, date: Date) async {
    print("Watch: workout session changed to \(toState.rawValue)")
    if toState == .stopped {
        await finishWatchWorkout(at: date)
        sessionStatePublisher.send((toState, isMirroredSession))
    } else if toState == .running {
        sessionStatePublisher.send((toState, isMirroredSession))
    }
}
```

처음엔 `Main actor-isolated property 'sessionStatePublisher' can not be referenced from a nonisolated context` 에러가 났는데, `nonisolated` 컨텍스트에서 `@MainActor`로 격리된 프로퍼티를 직접 접근할 수 없어서였다. iOS 쪽에서 이미 했던 패턴(`handleiOSStateChange`)과 동일하게 `@MainActor` 메서드로 분리해 `Task { await ... }`로 감싸는 방식으로 해결했다.

`.running`/`.stopped` 처리를 하나의 핸들러(`handleWatchOSStateChange`)로 통합하면서, iOS의 `handleiOSStateChange`와 구조적으로 대칭이 되도록 정리했다.

`WatchViewModel`에서도 동일하게 구독해 화면 전환을 연결했다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.0 == .running {
            self.navigateTo(.pfd)
        } else if result.0 == .stopped {
            Task {
                await self.resetState()
            }
        }
    }
    .store(in: &cancellables)
```

이제 PFD 전환까지는 정상적으로 됐다. 다만 iPhone에서 러닝을 종료했을 때 Watch가 같이 종료되지는 않았다. 이 부분은 iPhone이 만든 세션과 Watch가 `handle(_:)`에서 만든 세션이 진짜 같은 워크아웃으로 공유되고 있는지부터 다시 확인이 필요해 보인다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/IMG_0028.gif){: width="50%" height="50%"}

---

#### 시나리오 정리하기

문제를 깊게 파기 전에, 지금 Watch가 마주할 수 있는 상황을 먼저 정리해보았다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/runningmode_decision_flow.png){: width="50%" height="50%"}

Watch 입장에서 실제로 구분해야 하는 경우는 셋이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/sce.png){: width="50%" height="50%"}

1. **Watch 단독** — `WatchTakeoffView`에서 시작했고, iPhone이 없거나 미러링이 안 잡힌 경우
2. **Watch 주도 미러링** — `WatchTakeoffView`에서 시작했는데 iPhone이 미러링을 받아준 경우
3. **iPhone 주도 미러링** — `AppDelegate.handle(_:)`로 시작된 경우. 이건 항상 미러링이다

("iPhone 단독"은 Watch가 아예 켜지지 않으니 Watch 쪽에서는 신경 쓸 필요가 없는 경우다.)

이 세 가지가 결국 `WatchViewModel.runningMode`라는 하나의 값(`.standalone` / `.mirrored`)으로 모이고, 이 값이 GPS 스트림 분기와 종료 시 자동 화면 전환 두 곳에서 쓰이는 구조다.

지금까지는 `runningMode`를 `sessionReachabilityDidChange`에서 `isReachable` 값에 따라 실시간으로 갱신하고 있었는데, 이게 문제였다. `isReachable`은 "지금 이 순간 iPhone과 통신 가능한가"를 나타내는 값이라 수시로 바뀌는데, `runningMode`는 "이 워크아웃이 어떻게 시작됐는가"라는 시작 시점에 고정되어야 하는 값이다. 둘을 같은 걸로 취급하면, 예를 들어 Watch 단독으로 뛰다가 중간에 iPhone을 꺼내 보기만 해도 `runningMode`가 `.mirrored`로 잘못 바뀔 수 있다.

그래서 `runningMode`는 시작 시점에 한 번 확정하고, 그 값을 세션이 끝날 때까지 유지하는 방향으로 가기로 했다.

---

#### 종료 동기화는 어떻게 할 것인가

`runningMode`를 정리하다 보니, 더 큰 문제가 남아 있다는 걸 깨달았다. 미러링 중에 어느 쪽에서 종료를 누르든 양쪽이 같이 종료되어야 한다는 점이다. 폰에서 켜고 워치에서 종료하는 사람도 있을 거고, 반대인 경우도 있을 테니 한쪽만 처리하면 안 된다.

문제는 지금 구조상 iPhone과 Watch가 진짜로 하나의 세션을 공유하고 있는 게 아니라는 점이다. iPhone이 `stopWorkout()`을 부르면 iPhone 자신의 `HKWorkoutSession`만 끝나고, Watch가 `handle(_:)`에서 만든 자신만의 세션은 전혀 영향을 받지 않는다. 즉 같은 설정으로 시작된, 사실상 독립된 두 개의 세션인 셈이다.

그래서 세션 레벨에서 동기화를 시도하는 대신, "누가 직접 멈췄는지"를 명시적으로 알려주는 방향으로 가기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/stop_sync_local_remote_flow.png){: width="50%" height="50%"}

1. 한쪽이 직접 종료 버튼을 눌러서 `stopWorkout()`을 호출하면, 그 기기는 TOUCHDOWN → Summary로 정상적으로 자기 흐름을 진행한다.
2. 동시에 `sendMessage()`로 "내가 멈췄다"는 신호를 반대쪽 기기로 보낸다.
3. 신호를 받은 쪽은 TOUCHDOWN을 거치지 않고 곧바로 홈으로 복귀한다.

종료를 직접 누른 기기만 러닝 절차를 다 거치고, 신호로 전달받은 쪽은 곧바로 정리되는 구조다.

---

#### SessionStateEvent로 모델링하기

기존에는 `sessionStatePublisher`가 `(HKWorkoutSessionState, Bool)` 튜플을 보내고 있었는데, 여기에 "종료를 누른 게 나인지 상대인지"까지 더해야 하다 보니 튜플로는 한계가 보였다. 인덱스(`result.0`, `result.1`)로 접근하는 것도 의미가 잘 안 드러나고, 항목이 하나 더 늘어나면 더 헷갈릴 것 같았다.

그래서 차라리 별도 모델을 만들어 의미를 명확히 했다. 다만 `HKWorkoutSessionState`를 모델에 그대로 박아두면 도메인 모델이 HealthKit 프레임워크에 종속되어버린다. VM이 View를 몰라야 하는 것과 같은 이유로, 모델은 가능하면 특정 프레임워크를 모르는 게 맞다고 판단했다. 그래서 우리만의 추상 상태값을 따로 만들고, `HealthKitService`가 `HKWorkoutSessionState`를 받아서 이 값으로 변환해 publisher에 흘리는 방식으로 갔다.

```swift
enum WorkoutSessionState {
    case running
    case stopped
    case other
}

enum RunningMode {
    case standalone
    case mirrored
}

enum StopOrigin {
    case local
    case remote
}

struct SessionStateEvent {
    let state: WorkoutSessionState
    let runningMode: RunningMode
    let stopOrigin: StopOrigin?  // .running일 때는 nil, .stopped일 때만 의미 있음
}
```

```swift
var sessionStatePublisher = PassthroughSubject<SessionStateEvent, Never>()
```

이제 `result.0 == .running` 대신 `event.state == .running`, `event.runningMode == .mirrored`, `event.stopOrigin == .remote`처럼 의미가 바로 드러나는 형태로 분기할 수 있다. `SessionStateEvent`는 `import HealthKit` 없이도 정의가 가능한 순수 모델이 됐고, `HKWorkoutSessionState` → `WorkoutSessionState` 변환은 `HealthKitService` 내부에서만 처리한다.

---

#### 코드 리팩토링 (iOS+Watch)

지금까지 정리한 내용을 코드에 반영해본다.

---

##### 1. WorkoutSessionState 변환 적용하기

새롭게 모델링한 부분을 적용한다. 일단 먼저

```swift
var sessionStatePublisher = PassthroughSubject<SessionStateEvent, Never>()
```

이렇게 publisher부터 바꾸어 주었다. 그러면 관련 컴파일 에러가 발생하기 때문에 추적하기 쉬워진다.

컴파일 에러를 수정해본다.
```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            self.navigateTo(.pfd)
        } else if result.state == .stopped {
            if self.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

이렇게 Tuple 형식이던 걸 바꿔주면 된다.

그리고 업데이트하고 전달할 함수를 구현해주었다.

```swift
@MainActor
func updateAndSendState(_ event: SessionStateEvent) {
    sessionState = event
    sessionStatePublisher.send(event)
}
```

처음엔 watchOS 전용으로 분기해서 넣으려 했는데, 생각해보니 `sessionState`나 `sessionStatePublisher` 모두 플랫폼과 무관한 공통 프로퍼티고 세팅+전송하는 동작 자체도 iOS든 watchOS든 똑같이 필요했다. 그래서 분기 없이 공통 `HealthKitService.swift`에 두기로 했다.

이제 `handleWatchOSStateChange`를 수정한다.

```swift
@MainActor
func handleWatchOSStateChange(_ toState: HKWorkoutSessionState, date: Date) async {
    let state: WorkoutSessionState = toState == .running ? .running : toState == .stopped ? .stopped : .other

    if toState == .stopped {
        await finishWatchWorkout(at: date)
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: .local)
        updateAndSendState(event)
    } else if toState == .running {
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: nil)
        updateAndSendState(event)
    }
}
```

---

###### 문제점: runningMode를 누가 들고 있어야 하나

`handleWatchOSStateChange`에서 `SessionStateEvent`를 만들려면 `runningMode`와 `stopOrigin`이 필요한데, 이 두 값은 지금 `WatchViewModel`이 들고 있다. `HealthKitService`(서비스 레이어)가 이 값을 만들려면 결국 VM의 상태를 알아야 하는 셈인데, 의존성 방향이 거꾸로 가는 게 마음에 걸렸다.

방향을 두 가지로 고민했다.

1. `HealthKitService`가 `runningMode`/`stopOrigin`을 자체적으로 들고 있고, VM은 필요할 때 읽기만 한다.
2. `HealthKitService`는 상태값만 보내고, VM이 publisher를 구독하면서 자기가 알고 있는 정보를 조합해서 최종 판단한다.

`SessionStateEvent`를 만든 의도 자체가 "한 이벤트 안에 state, mode, origin을 다 담아서 흘려보내자"였으니, 2번처럼 VM이 다시 조합해야 한다면 이 모델을 만든 의미가 흐려진다. 

---

###### runningMode를 HealthKitService로 옮기기

그래서 1번 방향으로 가기로 했다. `runningMode`와 `stopOrigin`을 `WatchViewModel`에서 빼서 `HealthKitService`로 옮기고, VM의 부담도 함께 줄이기로 했다.

`WatchViewModel`에 있던 `runningMode`를 빼서 `HealthKitService`로 옮긴다.

```swift
var runningMode: RunningMode = .standalone
var stopOrigin: StopOrigin?
```

---

###### RunningMode 시작 시점 확정하기 (startWorkout 수정)

처음엔 `sessionReachabilityDidChange`에서 `isReachable` 값이 바뀔 때마다 `runningMode`를 갱신하는 방식으로 가려고 했다. 하지만 `isReachable`은 "지금 이 순간 iPhone과 통신 가능한가"를 나타내는, 수시로 바뀌는 값이다. 

`runningMode`는 "이 워크아웃이 어떻게 시작됐는가"라는, 세션이 시작되는 시점에 한 번 고정되어야 하는 값이라 둘을 같은 걸로 취급하면 안 됐다. Watch 단독으로 뛰다가 중간에 iPhone을 잠깐 꺼내보기만 해도 `runningMode`가 `.mirrored`로 잘못 바뀔 수 있었기 때문이다.

그래서 `runningMode`는 `startWorkout()`이 호출되는 시점, 즉 워크아웃이 실제로 시작되는 그 순간에 한 번만 확정하고, 세션이 끝날 때까지 그 값을 유지하는 방향으로 가기로 했다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    // 생략
    try await builder?.beginCollection(at: startDate)
    runningMode = .standalone

    #if os(iOS)
    do {
        try await store.startWatchApp(toHandle: workoutConfiguration)
        runningMode = .mirrored
    } catch {
        print("iPhone: startWatchApp failed - \(error)")
    }
    #else
    if WCSession.default.isReachable {
        do {
            try await session?.startMirroringToCompanionDevice()
            runningMode = .mirrored
        } catch {
            print("Watch: mirroring failed - \(error)")
        }
    }
    #endif
}
```

이렇게 운동을 시작할 때마다 `runningMode`를 먼저 `.standalone`으로 초기화하고, 미러링이 성공한 경우에만 `.mirrored`로 덮어쓰도록 했다.

`init()` 시점의 기본값에만 의존하면 두 번째 러닝부터는 이전 값이 남아있을 수 있어서, `startWorkout()`이 호출될 때마다 명시적으로 리셋해주는 게 안전하기 때문이다.

---

###### handleiOSStateChange 수정

이제 그리고 `handleiOSStateChange`도 수정을 해준다

```swift
@MainActor
func handleiOSStateChange(_ toState: HKWorkoutSessionState) {

    let state: WorkoutSessionState
    switch toState {
    case .running:
        state = .running
    case .stopped:
        state = .stopped
    default:
        state = .other
    }

    if toState == .stopped {
        session?.end()
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin)
        updateAndSendState(event)
    } else if toState == .running {
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: nil)
        updateAndSendState(event)
    }
}   
```

`retrieveRemoteSession`에 에러가 발생하므로

```swift
if mirroredSession.state == .running {
    self.handleiOSStateChange(.running)
}
```

이렇게 수정을 해준다.

---

###### WatchViewModel 수정

이제 여기도 수정을 해주도록 한다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            self.navigateTo(.pfd)
        } else if result.state == .stopped {
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

이젠 싱글턴인 `HealthKitService`가 `runningMode`를 직접 들고 있으니, `WatchViewModel`이 자체적으로 갖고 있던 `runningMode` 프로퍼티는 더 이상 필요가 없다. 

다만 그 값을 읽을 때는 `HealthKitService.shared.runningMode`로 다시 싱글톤을 거칠 필요 없이, `sink`로 받은 `result`에 이미 `runningMode`가 같이 들어 있으니 `result.runningMode`로 바로 읽으면 된다.

그리고 VM에서 `runningMode`라는 프로퍼티가 사라졌으므로 관련 에러는 전부

```swift
if HealthKitService.shared.sessionState?.runningMode == .standalone {
    locationService.startTracking()
}
```

이런 식으로 고쳐준다.

다만 이때 `resetState`의 경우는

```swift
func resetState() async {
    // 생략
    HealthKitService.shared.runningMode = .standalone
    // 생략
}
```

모델(`sessionState`)에 접근해서 고치는 게 아니라, 별도로 만든 `runningMode` 프로퍼티 자체를 바꿔주어야 한다.

`sessionState`는 가장 최근에 전달된 상태값을 그대로 담아두는 용도라 `let` 멤버를 가진 구조체라서 내부 값만 따로 바꿀 수 없기 때문이다.

---

###### RunViewModel 수정

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.runningMode == .mirrored {
                self.navigationPath.append(.pfd)
            }
        } else if result.state == .stopped {
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

기존에 튜플로 받던 `result.1` 같은 인덱스 접근을 `result.runningMode`로 바꿔주었다. 그리고 `isRemoted`라는 별도 Bool 프로퍼티에 값을 옮겨 담는 대신, `result.runningMode == .mirrored` 조건으로 바로 분기하도록 했다.

`isRemoted`를 참조하던 다른 곳들(`PFDView.task`의 GPS 시작 분기, `resetState()`의 위치 추적 중단 분기)도 같은 방식으로 `HealthKitService.shared.sessionState?.runningMode == .mirrored`로 고쳐주어야 한다.

`resetState()`도 `WatchViewModel`과 마찬가지로 `isRemoted = false` 대신 `HealthKitService.shared.runningMode = .standalone`으로 초기화하도록 바꿔주었다.

여기 코드는 생략

---

###### sessionReachabilityDidChange 정리하기

`runningMode`는 이제 `startWorkout()` 시작 시점에 이미 확정되고 있다. 그런데 `sessionReachabilityDidChange`가 여전히 `isReachable` 변화에 따라 실시간으로 `runningMode`를 덮어쓰고 있었다.

```swift
func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
        HealthKitService.shared.runningMode = session.isReachable ? .mirrored : .standalone
    }
}
```

이대로 두면 처음에 걱정했던 문제(Watch 단독으로 뛰다가 iPhone을 잠깐 꺼내보기만 해도 `runningMode`가 `.mirrored`로 잘못 바뀌는 것)가 그대로 남는다. 

이후 iPhone 쪽 `WCSessionDelegate`에는 이 메서드 자체가 없어도 빌드 에러가 없었다. `sessionReachabilityDidChange`가 옵셔널 메서드라서 빈 본문으로 남겨둘 필요 없이 완전히 삭제해도 됐다.

그래서 `sessionReachabilityDidChange` 함수를 그냥 지워주었다.

---

##### 2. 종료 신호 보내고 받기

중요한 부분이다. iPhone과 Watch는 실제로 같은 워크아웃 세션을 공유하고 있지 않기 때문에, 한쪽이 멈췄다는 사실을 상대 기기에 명시적으로 알려줘야 한다. 그래서 `WatchConnectivity`의 `sendMessage()`로 "내가 지금 멈췄다"는 신호를 직접 보내기로 했다.

종료를 누른 쪽은 `stopWorkout()`을 호출하면서 동시에 이 신호를 상대 기기로 전송하고, 받는 쪽은 `didReceiveMessage`에서 그 신호를 인식해야 한다.

---

이제 종료 신호를 보내고 받는 함수를 구현하도록 한다.

```swift
func sendStopSignal() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    let message: [String: Any] = ["type": "remoteStopped"]
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
}

func handleStopSignal() {
    Task { @MainActor in
        HealthKitService.shared.stopOrigin = .remote
        let event = SessionStateEvent(
            state: .stopped,
            runningMode: HealthKitService.shared.runningMode,
            stopOrigin: .remote
        )
        HealthKitService.shared.updateAndSendState(event)
    }
}
```

`sendStopSignal()`은 종료를 직접 누른 쪽에서 호출해 상대 기기에 신호를 보내는 함수다. `handleStopSignal()`은 그 신호를 받은 쪽에서 호출하는 함수인데, 함수 이름은 둘 다 "stop"이지만 의미가 정반대다.

`sendStopSignal`을 호출하는 쪽은 이미 "내가 직접 멈췄다"는 걸 알고 있으니 `stopOrigin`을 `.local`로 처리하면 되고, `handleStopSignal`을 호출하는 쪽은 상대방이 보낸 신호를 받은 입장이니 그 종료가 "원격에서 발생한 것"이라는 의미로 `stopOrigin = .remote`를 내부에 고정해두었다. 신호를 받는다는 것 자체가 곧 "상대가 멈췄다"는 뜻이므로, 굳이 파라미터로 받을 필요 없이 함수 내부에서 항상 `.remote`로 세팅하는 게 맞았다.

다만 이 두 함수만 만들어둔다고 바로 동작하는 건 아니다. `handleStopSignal()`은 "신호를 받았을 때" 처리하는 쪽만 구현되어 있을 뿐, "직접 종료했을 때 `.local` 이벤트를 흘려보내고 `sendStopSignal()`을 호출"하는 부분이 아직 빠져 있다. 이 연결이 빠진 채로는 신호를 받는 쪽이 영원히 신호를 받을 일이 없다.

iPhone 주도/Watch 주도 두 시나리오, 그리고 iPhone에서 종료/Watch에서 종료 두 경우를 조합하면 총 네 가지 케이스가 나오는데, 

| 시작 주체 | 종료 누른 쪽 | iPhone 동작 | Watch 동작 |
|---|---|---|---|
| iPhone 주도 | iPhone에서 종료 | `.local` → TOUCHDOWN → Summary | `.remote` 수신 → 곧바로 홈 |
| iPhone 주도 | Watch에서 종료 | `.remote` 수신 → 곧바로 홈 | `.local` → TOUCHDOWN → Summary |
| Watch 주도 | iPhone에서 종료 | `.local` → TOUCHDOWN → Summary | `.remote` 수신 → 곧바로 홈 |
| Watch 주도 | Watch에서 종료 | `.remote` 수신 → 곧바로 홈 | `.local` → TOUCHDOWN → Summary |

시작 주체와 종료 주체는 서로 독립적이다. 즉, `local`과 `remote`는 **누가 운동을 시작했는가**가 아니라 **누가 종료를 눌렀는가**에 의해 결정된다.

따라서 종료를 처리하는 로직도 시작 경로를 구분할 필요가 없다. 종료가 발생하는 공통 지점(`handleiOSStateChange` / `handleWatchOSStateChange`의 `.stopped` 분기)에서만 처리하면 네 가지 시나리오를 모두 커버할 수 있다.

다시 말해 **누가 시작했는지는 중요하지 않다.**

핵심은 **`stopWorkout()`을 호출한 기기**가 항상 `.local`이라는 점이다. 시작을 iPhone에서 했든 Watch에서 했든, 종료 버튼을 누른 쪽은 `stopWorkout()`을 호출하면서 `stopOrigin = .local`로 기록하고, 반대편 기기는 종료 이벤트를 전달받아 `.remote`로 처리하면 된다.

즉, **`local`과 `remote`는 "누가 시작했는가"가 아니라 "누가 `stopWorkout()`을 호출했는가"만 보면 된다.**

그래서 `stopOrigin = .local`은 `stopWorkout()` 안에서 한 번만 설정해도 네 가지 종료 시나리오를 모두 자연스럽게 처리할 수 있다.

```swift
func stopWorkout() {
    stopOrigin = .local
    session?.stopActivity(with: Date())
}
```

정리하면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/stopbrief.png){: width="50%" height="50%"}

---

##### 3. StopOrigin 분기 처리 연결하기

`HealthKitService`와 `WatchConnectivityService`는 서로 모르는 관계다. `stopWorkout()`이나 `handleiOSStateChange`/`handleWatchOSStateChange` 안에서 `sendStopSignal()`을 직접 호출하고 싶었지만, 의존성이 없어서 그럴 수 없었다.

대신 둘 다 알고 있는 VM이 다리 역할을 하기로 했다. `sessionStatePublisher`를 구독하는 시점에, `.stopped`이고 `stopOrigin == .local`(내가 직접 멈춘 경우)일 때만 VM이 `watchConnectivityService.sendStopSignal()`을 호출하는 방식이다.

이건 `WatchViewModel`과 `RunViewModel` 양쪽 모두에 똑같이 적용해야 한다. 어느 기기든 직접 종료를 누르면 상대에게 알려야 하기 때문이다.


```swift
// WatchViewModel
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            self.navigateTo(.pfd)
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            }
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)

// RunViewModel
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.runningMode == .mirrored {
                self.navigationPath.append(.pfd)
            }
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            }
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

`stopOrigin == .local` 분기는 양쪽 다 동일한데, `.running` 처리 방식은 조금 다르다.

`RunViewModel`은 `runningMode == .mirrored`일 때만 PFD를 push하는데, 처음엔 `WatchViewModel`은 가드 없이 무조건 `navigateTo(.pfd)`를 호출해도 괜찮다고 생각했다. 

iPhone이 직접 시작한 러닝은 `TakeoffView`에서 이미 `navigationPath.append(.pfd)`를 호출하고 있으니, `sessionStatePublisher`에서 또 push하면 중복이 생기는 게 명확했고, Watch는 iPhone 주도(`AppDelegate.handle(_:)`)로 시작된 경우에만 `sessionStatePublisher`가 유일한 전환 수단이 된다고 봤기 때문이다.

그런데 다시 생각해보니 이 가정이 틀렸다. `WatchTakeoffView`로 직접 시작한 경우에도 `startWorkout()`이 호출되고 `.running` 상태가 되면서 `sessionStatePublisher`가 똑같이 흘러간다. 그러면 `WatchTakeoffView`가 이미 `navigateTo(.pfd)`를 호출한 직후에, `sessionStatePublisher` 구독부가 또 한 번 호출하게 되는 셈이다. `navigateTo()` 안에 있는 `guard navigationPath.last != destination else { return }` 가드가 우연히 이 중복을 막아주고 있었을 뿐, 설계상 안전했던 게 아니었다.

진짜 필요한 구분은 `runningMode`(미러링 성립 여부)가 아니라 "이 워크아웃을 누가 시작했는가"다. 

`WatchTakeoffView`로 시작했다면 미러링 여부와 무관하게 Watch는 항상 자기가 직접 화면을 전환하니 `sessionStatePublisher`는 push할 필요가 없고, `AppDelegate.handle(_:)`로 시작했다면 `TakeoffView`를 거치지 않으니 `sessionStatePublisher`가 유일한 전환 경로가 된다. 이건 `stopOrigin`이 종료 주체를 구분해줬던 것과 같은 맥락이라, 시작 주체를 나타내는 별도 값이 필요해 보인다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/pfdsce.png){: width="50%" height="50%"}

---

##### 4. StartOrigin 모델 추가하기

`StopOrigin`과 똑같은 패턴으로, 이 워크아웃을 누가 시작시켰는지를 나타내는 값을 추가했다.

```swift
enum StartOrigin {
    case local
    case remote
}
```

`local`은 `WatchTakeoffView`처럼 그 기기가 직접 카운트다운을 거쳐 시작한 경우, `remote`는 `AppDelegate.handle(_:)`처럼 상대 기기가 시작시킨 신호를 받아서 시작한 경우다.

이 값이 곧 화면 전환 책임이 어디에 있는지를 말해준다.

`.local`이면 `TakeoffView`(또는 `WatchTakeoffView`)가 이미 자기 화면을 PFD로 직접 전환해주고 있으니 `sessionStatePublisher`는 또 push할 필요가 없고, `.remote`면 그 기기가 카운트다운 화면을 거친 적이 없으니 `sessionStatePublisher`가 PFD로 넘어가는 유일한 경로가 된다.

`SessionStateEvent`에도 이 값을 추가했다.

```swift
struct SessionStateEvent {
    let state: WorkoutSessionState
    let runningMode: RunningMode
    let stopOrigin: StopOrigin?      // .running일 때는 nil
    let startOrigin: StartOrigin?    // .stopped일 때는 nil
}
```

---

`stopOrigin`처럼 `HealthKitService`에 저장 프로퍼티를 두고, 시작 시점에 한 번 확정한다.

```swift
var startOrigin: StartOrigin?
```

`startWorkout()`은 `WatchTakeoffView`(또는 iPhone의 `TakeoffView`)에서 호출되는 함수이므로, 호출되는 즉시 `.local`로 세팅한다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    startOrigin = .local
    runningMode = .standalone
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    // 생략
}
```

반대로 `AppDelegate.handle(_:)`는 상대 기기가 시작시킨 워크아웃을 받아서 처리하는 진입점이므로, 여기서는 `startWorkout()`을 호출하기 전에 `.remote`로 세팅해준다.

```swift
class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task {
            do {
                HealthKitService.shared.startOrigin = .remote
                try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
            } catch {
                print(error)
            }
        }
    }
}
```

`startWorkout()`은 어느 기기든 자기 자신이 직접 워크아웃을 시작하는 함수이므로, 처음엔 함수 안에서 무조건 `.local`로 세팅하려고 했다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    startOrigin = .local
    runningMode = .standalone
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    // 생략
}
```

그런데 `AppDelegate.handle(_:)`도 결국 내부적으로 `startWorkout()`을 호출한다. 

`handle(_:)`는 상대 기기가 시작시킨 워크아웃을 받아서 처리하는 진입점이니 `.remote`가 되어야 하는데, `startWorkout()`이 무조건 `.local`로 세팅해버리면 그 다음에 `AppDelegate`가 다시 `.remote`로 덮어써야 한다. 호출 순서를 헷갈리면 잘못된 값이 남을 수 있어 불안했다.

게다가 순서가 바뀌면(`startWorkout()`을 먼저 부르고 그 안에서 `.local`이 세팅된 뒤에 `.remote`로 고치는 식이 아니라 반대로 하면) 의도와 다르게 동작할 위험도 있다.

그래서 `startWorkout()`에서는 `startOrigin`을 건드리지 않고, 호출하는 쪽이 각자 자기 책임으로 세팅하도록 정리했다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    runningMode = .standalone
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    // 생략
}
```

`startOrigin = .local`을 세팅하는 위치는 실제로 `startWorkout()`을 호출하는 `WatchViewModel.updatePhase(_:)`의 `.cruise` 분기 안이다.

카운트다운이 끝나면 `viewModel.updatePhase(.cruise)`가 호출되고, 그 안에서 `HealthKitService.shared.startWorkout()`을 부른다. 그러니 `startOrigin`을 세팅할 타이밍도 이 호출 직전이 가장 정확하다.

그래서 Run, WatchVM 모두 적용을 해준다.

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
                HealthKitService.shared.startOrigin = .local
                try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
            } catch {
                print(error)
            }
        }
    case .touchdown:
        HealthKitService.shared.stopWorkout()
    default:
        break
    }
}
```

그리고 VM 구독부도 `startOrigin`을 반영해서 고쳐준다.

```swift
// WatchViewModel
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.startOrigin == .remote {
                self.navigateTo(.pfd)
            }
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            }
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)


// RunViewModel
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.startOrigin == .remote {
                self.navigationPath.append(.pfd)
            }
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            }
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

`.running`일 때 `runningMode == .mirrored` 대신 `startOrigin == .remote`로 가드를 바꿨다. `RunViewModel`은 원래도 `runningMode`로 가드를 걸고 있었지만, `WatchViewModel`은 무조건 push하던 걸 이번에 가드를 추가한 것이다. 

이제 양쪽 다 "내가 직접 시작한 경우(`.local`)는 이미 화면을 전환했으니 건너뛰고, 상대가 시작시킨 경우(`.remote`)만 push한다"는 동일한 규칙을 따른다.

이렇게 하면 `startWorkout()`을 어디서 부르든 호출 직전에 의도를 명시적으로 적어두는 셈이라, 순서를 신경 쓸 필요 없이 항상 정확한 값이 세팅된다.

---

##### 5. 기타 에러 해결하기

이젠 모델을 추가/변경한 부분에 대한 컴파일 에러를 해결해보도록 한다.

`SessionStateEvent`에 `startOrigin` 필드가 추가되면서, 이 구조체를 직접 만드는 모든 곳에서 인자를 채워줘야 했다. 규칙은 단순하다. `.running`을 만들 때는 `startOrigin`이 의미 있는 값이니 채워주고 `stopOrigin`은 `nil`로, `.stopped`를 만들 때는 반대로 `stopOrigin`을 채우고 `startOrigin`은 `nil`로 둔다.

```swift
// WatchConnectivityService
func handleStopSignal() {
    Task { @MainActor in
        HealthKitService.shared.stopOrigin = .remote
        let event = SessionStateEvent(
            state: .stopped,
            runningMode: HealthKitService.shared.runningMode,
            stopOrigin: .remote,
            startOrigin: nil
        )
        HealthKitService.shared.updateAndSendState(event)
    }
}

// HealthKitService
@MainActor
func handleWatchOSStateChange(_ toState: HKWorkoutSessionState, date: Date) async {
    let state: WorkoutSessionState = toState == .running ? .running : toState == .stopped ? .stopped : .other

    if toState == .stopped {
        await finishWatchWorkout(at: date)
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin, startOrigin: nil)
        updateAndSendState(event)
    } else if toState == .running {
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: nil, startOrigin: startOrigin)
        updateAndSendState(event)
    }
}

@MainActor
func handleiOSStateChange(_ toState: HKWorkoutSessionState) {
    let state: WorkoutSessionState
    switch toState {
    case .running:
        state = .running
    case .stopped:
        state = .stopped
    default:
        state = .other
    }

    if toState == .stopped {
        session?.end()
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin, startOrigin: nil)
        updateAndSendState(event)
    } else if toState == .running {
        print("iPhone: sending .running to sessionStatePublisher")
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: nil, startOrigin: startOrigin)
        updateAndSendState(event)
    }
}
```

`handleWatchOSStateChange`의 `.stopped` 분기는 원래 `stopOrigin: .local`로 하드코딩되어 있었는데, 이건 `stopWorkout()`이 직접 멈춘 경우(`.local`)와 `handleStopSignal()`이 신호로 받은 경우(`.remote`)를 구분하지 못하는 실수였다. 

이번에 저장 프로퍼티 `stopOrigin`을 그대로 읽도록 같이 고쳤다.

그리고 이전에 싱글턴으로 고치면서 `PFDView`의 코드도 같이 수정을 해야 했는데, 빠뜨려서 에러가 발생했다. 정확한 위치는 안 나오고 `var body: some View {` 자체에 에러가 표시됐는데, 알고 보니 `isRemoted`를 지우면서 이 부분을 놓쳤던 게 원인이었다.

```swift
// before
.task {
    if runViewModel.isRemoted {
        try? await Task.sleep(for: .seconds(3))
        runViewModel.start()
    }
    await runViewModel.startStream()
}

// after
.task {
    if HealthKitService.shared.sessionState?.runningMode == .mirrored {
        try? await Task.sleep(for: .seconds(3))
        runViewModel.start()
    }
    await runViewModel.startStream()
}
```

이렇게 빌드가 성공해서 실행을 해보니 크래시가 발생했다.

```text
RunWay.debug.dylib`@objc WatchConnectivityService.session(_:activationDidCompleteWith:error:):
    0x1015b50e4 <+0>:   sub    sp, sp, #0x70
    ...
    0x1015b5158 <+116>: bl     0x1016c937c               ; symbol stub for: Swift._checkExpectedExecutor(_filenameStart: Builtin.RawPointer, _filenameLength: Builtin.Word, _filenameIsASCII: Builtin.Int1, _line: Builtin.Word, _executor: Builtin.Executor) -> ()
->  0x1015b515c <+120>: ldur   x0, [x29, #-0x28]
    ...
    bl     0x1015b4eec               ; session at WatchConnectivityService.swift:61
```

`handleStopSignal()`을 의심했지만 정확한 위치는 아니었다. 스택 트레이스를 다시 따라가보니 `session(_:activationDidCompleteWith:error:)`에서 발생한 것이었다.

`WatchConnectivityService`를 `nonisolated`로 선언했지만, extension 안의 delegate 메서드 자체에는 `nonisolated`를 명시하지 않으면 Xcode 26의 기본 액터 격리(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) 설정 때문에 다시 `@MainActor`로 추론되어버린다. 

예전에 `HealthKitService`에서 겪었던 것과 똑같은 패턴이었다.

```swift
extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            print("The session has completed activation.")
        }
    }
}
```

`nonisolated`를 명시적으로 붙여주니 해결됐다.

---

그런데 한 번 실행 후에 재실행을 하니 크래시가 발생했다. 신기한 건 시뮬레이터에서는 괜찮았는데 실기기에서만 발생했다는 점이다.

```text
RunWay.debug.dylib`@objc WatchConnectivityService.session(_:didReceiveUserInfo:):
    ...
    bl     0x1034066b0               ; symbol stub for: Swift._checkExpectedExecutor(...)
->  0x1032c1bb0 <+120>: ldr    x0, [sp, #0x20]
    ...
    bl     0x1032beb8c               ; session at WatchConnectivityService+iOS.swift:66
```

위의 `session(_:activationDidCompleteWith:error:)`에서 겪었던 것과 똑같은 패턴의 크래시였다. `+iOS` extension의 `session(_:didReceiveUserInfo:)`에 `nonisolated`가 빠져 있어서, Xcode 26의 기본 액터 격리 설정 때문에 다시 `@MainActor`로 추론되어버린 것이었다. 

`+iOS`, `+watchOS` extension에 있는 `WCSessionDelegate` 콜백 메서드들을 다시 점검해서, 빠져 있던 `nonisolated`를 전부 추가했다.

---

##### 6. 실기기 테스트

이제 제대로 실행이 되니 실제로 4가지 시나리오가 다 정상 동작하는지 확인해본다.

1. iPhone 주도 시작 → iPhone에서 종료
2. iPhone 주도 시작 → Watch에서 종료
3. Watch 주도 시작 → iPhone에서 종료
4. Watch 주도 시작 → Watch에서 종료

각 시나리오마다 확인할 부분은 동일하다.

- `startOrigin`에 따라 PFD로 정상 전환되는지
- 종료를 누른 쪽은 `stopOrigin = .local`로 TOUCHDOWN → Summary 흐름을 그대로 거치는지
- 종료를 누르지 않은 쪽은 신호를 받아 곧바로 홈으로 복귀하는지
- 추가로 Watch 단독(iPhone 미연결) 러닝도 회귀 없이 그대로 동작하는지

---

#### 문제 발견

실제로 테스트해보니 여러 문제가 발견됐다.

1. iPhone에서 시작했을 때:
    - Watch는 켜지지만 PFD로 전환되지 않았다. 그리고 iPhone에서 러닝을 종료하면 TOUCHDOWN을 거치지 않고 곧바로 홈으로 돌아갔다.
2. Watch에서 시작했을 때(iPhone은 PFD로 정상 전환됨):
    - iPhone에서 러닝을 종료하면 iPhone도 곧바로 홈으로 돌아가고, Watch도 같이 홈으로 돌아갔다.
3. Watch에서 시작했을 때(iPhone은 PFD로 정상 전환됨):
    - Watch에서 러닝을 종료하면 Watch도 곧바로 홈으로 돌아가고, iPhone도 같이 홈으로 돌아갔다.

종료를 직접 누른 쪽은 TOUCHDOWN → Summary를 거쳐야 하는데, 모든 경우에서 곧바로 홈으로 가버린다. `stopOrigin`이 `.local`/`.remote` 구분 없이 항상 자동 정리(`resetState()`) 부분을 타고 있는 것으로 보인다.

---

##### 1. iPhone에서 시작 시 Watch PFD 미전환 + 종료 시 Summary 생략 문제

일단 문제를 생각해보면

1. Watch PFD 미전환: `if result.startOrigin == .remote`가 true가 안 되는 게 원인으로 보인다.
2. iPhone Summary 생략: `if result.runningMode == .mirrored`가 작동해서, `.local`임에도 자동 `resetState()`가 호출되는 것으로 보인다.

확인이 필요한 부분은 `startOrigin`/`stopOrigin`이 정확한 시점에 정확한 값으로 세팅되고 있는지다.

---

###### Watch PFD 미전환

WatchVM에 print를 찍어 확인을 해보니 `.remote`가 아닌 `.local`로 넘어오고 있었다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        // 생략
        print("Watch: received state=\(result.state), startOrigin=\(String(describing: result.startOrigin)), stopOrigin=\(String(describing: result.stopOrigin))")
        // 생략
    }
```

확인해보니 위에서 `startWorkout()`일 때 `.local` 세팅을 빼기로 했는데, 그게 그대로 남아있었다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    startOrigin = .local
    // 생략
}
```

`AppDelegate.handle(_:)`에서 `startOrigin = .remote`로 세팅한 직후, `startWorkout()`을 호출하면 그 안에서 다시 `.local`로 덮어쓰고 있었던 것이다.

그래서 Watch에서도 운동을 시작할 때마다 `.remote`였다가 곧바로 `.local`로 바뀌어버리고 있었다.

---

###### 종료 분기를 stopOrigin 기준으로 정리하기

iPhone, Watch 양쪽 모두 같은 문제를 겪고 있었다. `runningMode == .mirrored`로 자동 정리 여부를 판단하고 있었는데, 이 조건은 "지금 미러링 중인가"만 보는 거라서, 직접 종료를 누른 쪽에서도 참이 되어버린다. 

그래서 iPhone이든 Watch든 직접 종료 버튼을 눌러도 TOUCHDOWN을 거치지 않고 곧바로 홈으로 돌아가는 문제가 생겼다.

진짜 필요한 기준은 `stopOrigin`이었다. `.local`(내가 직접 멈춤)이면 TOUCHDOWN → Summary로 정상 진행하고, `.remote`(상대가 멈춰서 신호를 받음)일 때만 자동으로 `resetState()`를 호출해야 한다.

```swift
// Before
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.runningMode == .mirrored {
                self.navigationPath.append(.pfd)
            }
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            }
            if result.runningMode == .mirrored {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)

// After
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.startOrigin == .remote {
                self.navigateTo(.pfd)
            }
        } else if result.state == .stopped {
            if result.stopOrigin == .local {
                watchConnectivityService.sendStopSignal()
            } else if result.stopOrigin == .remote {
                Task {
                    await self.resetState()
                }
            }
        }
    }
    .store(in: &cancellables)
```

시작 분기는 `startOrigin`, 종료 분기는 `stopOrigin`이 각각 책임지는 구조로 정리되면서, `runningMode`는 더 이상 화면 전환에 쓰이지 않게 됐다. `runningMode`는 GPS 스트림을 직접 추적할지 여부를 결정하는 원래 역할로만 남는다.

`WatchViewModel`, `RunViewModel` 양쪽 모두 동일한 형태로 적용했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/IMG_0037.gif){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/IMG_0038.gif){: width="50%" height="50%"}

잘 되는걸 알 수 있다.

2. Watch에서 시작 후 iPhone에서 종료 시 iPhone도 Summary 없이 홈으로 가는 문제
3. Watch에서 시작 후 Watch 종료 시 Watch도 Summary 없이 홈으로 가는 문제

2번, 3번 모두 1번과 동일한 원인이었다. `runningMode == .mirrored`로 자동 정리 여부를 판단하던 게 문제였고, `stopOrigin` 기준으로 바꾸면서 세 가지 경우 모두 한 번에 해결됐다.

---

##### 2. Watch 미러링 문제

갑자기 새로운 문제가 발생했다. 잘되던 미러링이 안 되기 시작한 것이다. 하지만 반대 방향(iPhone에서 시작 → Watch로 미러링)은 계속 잘 되고 있어서, Watch 주도 미러링 쪽만 문제가 생긴 것으로 보인다. 한번 다시 확인해보려 한다.

갑자기 안 되기 시작한 이유를 생각해보면, 바로 전 단계에서 VM 구독부의 화면 전환 가드를 `runningMode`에서 `startOrigin`으로 바꾼 게 원인일 가능성이 높았다. `retrieveRemoteSession()`은 `runningMode = .mirrored`만 세팅하고 있었으니, `runningMode`로 가드를 걸 때는 잘 동작했지만 `startOrigin`으로 가드를 바꾸는 순간 이 경로가 비어버린 값을 참조하게 된 것이다.

일단 print를 찍어 확인을 해보니 워치에서 러닝을 시작하면 `handleiOSStateChange`에서 출력이 되는 걸 확인했다.

그래서 publisher에서 어떻게 값을 전달하는지 콘솔에 출력을 해보기로 했다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        // 생략
        print("iPhone: received state=\(result.state), startOrigin=\(String(describing: result.startOrigin)), stopOrigin=\(String(describing: result.stopOrigin))")
        // 생략
    }
```

그랬더니 `iPhone: received state=running, startOrigin=nil, stopOrigin=nil`이 찍혔다.

즉 `startOrigin`이 `nil`로 들어오고 있었던 것이다.

거슬러 올라가보니 `retrieveRemoteSession()`에서 `runningMode = .mirrored`는 세팅하고 있었지만, `startOrigin`은 세팅하지 않고 있었다. 이건 Watch가 먼저 시작해서 iPhone이 미러링으로 받는 경로이므로, iPhone 입장에서는 명백히 `.remote`여야 했다.

```swift
func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        Task { @MainActor in
            self.session = mirroredSession
            self.session?.delegate = self
            self.runningMode = .mirrored
            self.startOrigin = .remote

            if mirroredSession.state == .running {
                self.handleiOSStateChange(.running)
            }
        }
    }
}
```

이젠 워치에서도 미러링이 잘 되는걸 알 수 있다.

사진은 생략...

---

##### 3. 러닝 종료 후 재시작 시 초가 리셋되지 않는 문제

러닝이 종료되면 `elapsedTime = 0`으로 초기화하도록 해두었음에도, 가끔 초가 리셋되지 않고 그대로 남아있는 문제가 발생했다. 특히 iPhone에서 자주 보였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/IMG_0039.gif){: width="50%" height="50%"}

원인을 따라가보니 정상적인 종료 흐름(TOUCHDOWN 버튼)에서는 `stop()`이 먼저 호출되어 타이머가 멈춘다.

```swift
func stop() async {
    locationService.stopTracking()
    timerCancellable.removeAll()
}
```

하지만 상대 기기가 멈췄다는 신호를 받아서 곧바로 `resetState()`만 호출되는 경로(`stopOrigin == .remote`)는 `stop()`을 거치지 않는다. 그러면 타이머 구독이 살아있는 상태에서 `elapsedTime = 0`만 세팅되고, 곧바로 타이머가 다시 `elapsedTime`을 증가시켜버린다.

그래서 `resetState()`에도 타이머 구독을 직접 취소하도록 추가했다.

```swift
func resetState() async {
    if HealthKitService.shared.sessionState?.runningMode == .mirrored {
        locationService.stopTracking()
    }
    timerCancellable.removeAll()
    // 생략
}
```

이렇게 하면 `stop()`을 거치지 않고 `resetState()`만 호출되는 경로에서도 타이머가 확실히 멈춘다.

그리고 `WatchViewModel.resetState()`에도 같은 문제가 있을 수 있어 동일하게 추가해주었다.

```swift
func resetState() async {
    watchConnectivityService.sendRunningData()
    timerCancellable.removeAll()
    // 생략
}
```

이제는 리셋이 되는걸 확인했다.

---

# 정리

오늘 다룬 내용이 많아서, 전체 구조를 한 번 정리해본다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-23-RunningProject-15/mirroring_system_summary.png){: width="70%" height="70%"}

핵심은 `HealthKitService`가 `HKWorkoutSessionState`를 받아서 `SessionStateEvent`라는 하나의 이벤트로 가공해 `sessionStatePublisher`를 통해 흘려보내고, `WatchViewModel`과 `RunViewModel`이 똑같은 구조로 그걸 구독해서 세 가지 값을 각자 다른 용도로 쓰는 것이다.

- `startOrigin`(`.local`/`.remote`) — 이 워크아웃을 내가 직접 시작했는지, 상대가 시작시켜서 따라왔는지. `.remote`일 때만 PFD로 push한다.
- `runningMode`(`.standalone`/`.mirrored`) — 지금 미러링 중인지 여부. `.standalone`일 때만 GPS를 직접 추적한다.
- `stopOrigin`(`.local`/`.remote`) — 종료를 누른 게 나인지 상대인지. `.local`이면 Touchdown → Summary를 거치고 동시에 `sendStopSignal()`로 상대에게 알리고, `.remote`면 곧바로 홈으로 복귀한다.

세 값 모두 "주체가 누구인가"라는 같은 질문에 대한 답이고, 시점만 다를 뿐이다. 시작 시점엔 `startOrigin`이, 종료 시점엔 `stopOrigin`이 책임지고, `runningMode`는 그 사이 내내 데이터 흐름을 어떻게 처리할지를 결정한다.