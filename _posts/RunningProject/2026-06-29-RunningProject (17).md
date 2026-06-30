---
title: RunWay () 미러링 중 강제종료 PFD 좀비 세션 이슈 재도전
writer: Harold
date: 2026-06-29 08:33:00 +0900
last_modified_at: 2026-06-30 03:33:00 +0900
categories: [RunWay]
tags: [HealthKit, WatchConnectivity, SwiftUI]

toc: true
toc_sticky: true
published: false
---

가장 치명적인 문제인 좀비 세션이 남아있다.

증상을 다시 정리하면, 미러링 중 iPhone 앱을 강제종료하면 Watch는 정상적으로 홈으로 복귀하지만, iPhone을 재실행하면 PFD 화면이 그대로 남아 있고 GPS 추적이 다시 시작되어버린다. `startDate` 기반으로 좀비 세션을 감지해서 무시해보려 했지만 재현이 계속됐고, `.end()`를 호출하면 Watch 쪽 세션까지 같이 끊어지는 부작용까지 있어서 그동안 보류해왔다.

다시 정확한 시나리오를 짚어보면 이렇다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-29-RunningProject-17/zombie_session_full_scenario.png){: width="70%" height="70%"}

1. Watch에서 미러링으로 러닝을 시작하면 iPhone이 PFDView로 전환된다.
2. 이 상태에서 Watch 앱과 iPhone 앱을 둘 다 강제종료한다.
3. 두 앱 프로세스 모두 사라졌지만, `HKWorkoutSession`은 시스템 데몬(`healthd`) 레벨에서 관리되는 자원이라 `.end()`가 명시적으로 호출되지 않으면 세션 자체는 `.running` 상태로 계속 살아있다.
4. iPhone 앱을 다시 켜면, 그냥 러닝 후 강제종료했을 때는 HomeView부터 보이지만, 미러링으로 들어왔던 경우에는 `retrieveRemoteSession()`에 등록해둔 `workoutSessionMirroringStartHandler`가 이 살아있는 세션을 곧바로 감지해 `handleStateChange(.running)`을 호출하고, `navigationPath.append(.pfd)`로 이어지면서 켜자마자 PFD로 가버린다.

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

처음엔 좀비 세션을 `session?.end()`로 강제 종료시키려 했는데, 이렇게 하니 Watch 쪽 실제 워크아웃 세션까지 같이 끊겨버려서 이후 Watch에서 새로 러닝을 시작해도 미러링 자체가 안 되는 부작용이 생겼다. 그래서 `.end()` 호출 없이 `session = nil`로만 무시하는 방식으로 바꿨지만, 5초가 지나도 PFD가 그대로 유지되는 현상은 여전했다. `session = nil`이면 `handleStateChange(.running)` 자체를 호출하지 않을 텐데도 PFD로 전환이 됐다는 게 이상해서, 다른 경로로도 화면 전환이 일어나는 건 아닌지 의심이 들었다.

`startDate`와 `elapsed` 값을 직접 출력해서 확인하려 했지만, 앱을 강제종료하면 디버거 연결도 함께 끊겨서 Xcode에서 매번 다시 Run을 눌러야 콘솔을 볼 수 있는 번거로움이 있어 검증을 보류했었다.

이번엔 디버거를 붙인 상태에서만 보던 `print()` 로그로는 한계가 있다고 판단했다. 강제종료 직후, 즉 디버거가 연결되어 있지 않은 시점에 시스템이 무슨 일을 하고 있는지가 핵심인데, `print()`는 그 순간을 전혀 못 보여주기 때문이다.

그래서 AI에게 이 상황을 설명하고 어떻게 접근하면 좋을지 물어봤다. Console.app과 `os_log`를 쓰면 디버거 연결 없이도 시스템 레벨 로그를 확인할 수 있다는 답을 받았고, 정직하게 말하면 이 둘의 존재 자체를 잘 모르고 있었다. 그래서 이번 트러블슈팅은 `print()`를 `os_log`로 바꾸고, Console.app으로 강제종료 전후의 실제 시스템 동작을 들여다보는 방식으로 다시 시작해보기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-29-RunningProject-17/zombie.png){: width="70%" height="70%"}

---

## os_log로 전환하기

먼저 좀비 세션이 의심되는 지점들(`startWorkout`, `stopWorkout`, `retrieveRemoteSession`, `handleiOSStateChange`, `workoutSession(_:didChangeTo:...)`)에 로깅을 다시 심어야 했다. 바로 전 작업에서 Alert 처리를 일괄 적용하면서 곳곳에 있던 `print()`를 대부분 `alertPublisher`로 정리해버렸는데, 디버깅용 로그까지 같이 사라진 곳이 많았다.

게다가 디버거가 연결되어 있지 않은 강제종료 직후의 시점을 보려면, 애초에 `print()`로는 확인이 불가능했다. OSLog는 성능 오버헤드가 낮고 기기에 보관되어 나중에 다시 조회할 수 있다는 장점이 있고, 외부 Console 앱으로 로그를 읽거나 Xcode 15 안에서 구조화된 로깅의 이점을 누릴 수 있다. 그래서 이번엔 처음부터 `os_log` 기반인 `Logger`로 다시 세팅하기로 했다.

`OSLog` 자체는 [OSLog Docs](https://developer.apple.com/documentation/OSLog){:target="_blank"}에 따르면 과거 로그 데이터를 읽기 위한 통합 로깅 시스템이며, Console이나 Instruments 같은 Apple 도구와 함께 커스텀 디버깅·분석 도구를 만들 수 있게 해준다. 그리고 [Logger Docs](https://developer.apple.com/documentation/os/logger){:target="_blank"}를 보면 `Logger`는 통합 로깅 시스템에 문자열을 보간해서 기록하는 객체로  정의되어 있다.

```swift
import OSLog

private let logger = Logger(subsystem: "com.haroldfromk.RunWay", category: "HealthKitService")
```

`Logger`를 만들 때 `subsystem`은 보통 앱의 bundle identifier로, `category`는 어떤 파일/모듈에서 찍은 로그인지 구분하는 용도로 쓴다. Console.app에서 나중에 이 값들로 필터링할 수 있다.

```swift
logger.info("startWorkout called, session state: \(String(describing: self.session?.state))")
```

이렇게 의심되는 지점마다 현재 세션 상태를 같이 찍어두면, Console.app에서 시점별로 `session?.state`가 어떻게 변하는지 추적할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-29-RunningProject-17/log.png){: width="50%" height="50%"}

---

### 별도의 Debug 전용 Class 생성

어차피 디버그 목적으로 사용될 거라 굳이 여러 class에서 import를 하는 것보다 싱글턴으로 관리해서 사용하는 게 좋다고 판단했다.

```swift
import OSLog

final class ZombieSessionLogger {
    static let shared = Logger(subsystem: "com.haroldfromk.RunWay", category: "ZombieSession")
}
```

`Logger(subsystem:category:)`의 두 파라미터는 Console.app에서 나중에 로그를 필터링하기 위한 메타데이터다. `subsystem`은 보통 앱의 bundle identifier를 그대로 쓰는데, 어떤 앱에서 나온 로그인지 구분하는 큰 단위다.

`category`는 그 안에서 더 세부적으로, 어떤 기능/모듈에서 찍은 로그인지 나누는 용도다. 우리는 이번 좀비 세션 추적에만 쓸 거라 `category`를 `"ZombieSession"`으로 명확하게 지정해서, Console.app에서 이 카테고리로만 필터링하면 다른 로그에 섞이지 않고 추적하던 로그만 모아 볼 수 있다.

---

막상 적용해보니 `nonisolated` 컨텍스트에서 `ZombieSessionLogger.shared`를 호출하는 곳에서 에러가 났다.

```text
Main actor-isolated static property 'shared' can not be referenced from a nonisolated context
```

`workoutSession(_:didChangeTo:...)`처럼 `nonisolated`로 선언된 delegate 메서드 안에서 로그를 찍으려다 발생한 문제였다. 디버그용 로거가 굳이 `@MainActor`에 격리될 이유는 없으니, 클래스 자체를 `nonisolated`로 선언해서 어디서든 자유롭게 호출할 수 있도록 바꿨다.

```swift
nonisolated final class ZombieSessionLogger {
    static let shared = Logger(subsystem: "com.haroldfromk.RunWay", category: "ZombieSession")
}
```

---

### 적용하기

이제 의심되는 지점들에 `ZombieSessionLogger.shared`를 적용해본다.

사용법은 `print()`와 거의 비슷하다. 어디서든 `import OSLog`만 해두면 `ZombieSessionLogger.shared.info("로그 내용")` 형태로 바로 호출할 수 있다. `Logger`의 로그 레벨에는 `.info`, `.debug`, `.notice`, `.error`, `.fault` 등이 있는데, 이번엔 단순히 흐름을 추적하는 용도라 `.info` 레벨로 통일해서 찍었다.

```swift
import OSLog

func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    ZombieSessionLogger.shared.info("startWorkout called, session state: \(String(describing: self.session?.state))")
    runningMode = .standalone
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    // 생략
}

func stopWorkout() {
    ZombieSessionLogger.shared.info("stopWorkout called, session state: \(String(describing: self.session?.state))")
    stopOrigin = .local
    session?.stopActivity(with: Date())
}

func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        ZombieSessionLogger.shared.info("retrieveRemoteSession fired, mirroredSession state: \(mirroredSession.state.rawValue)")
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

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
    ZombieSessionLogger.shared.info("didChangeTo called, toState: \(toState.rawValue), fromState: \(fromState.rawValue)")
    #if os(iOS)
    Task {
        await self.handleiOSStateChange(toState)
    }
    #elseif os(watchOS)
    Task {
        await self.handleWatchOSStateChange(toState, date: date)
    }
    #endif
}
```

다만 이것만으로는 부족했다. `session = nil`로 무시했는데도 PFD로 전환됐다는 게 계속 이상했는데, 혹시 `sessionStatePublisher`를 구독하는 `RunViewModel` 쪽에서 다른 경로로 화면 전환이 일어나고 있는 건 아닐지 의심이 들었다. 그래서 마지막으로 화면 전환이 실제로 발생하는 지점, 즉 `RunViewModel`의 구독부에도 로그를 추가했다.

```swift
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        ZombieSessionLogger.shared.info("RunViewModel received state=\(String(describing: result.state)), startOrigin=\(String(describing: result.startOrigin)), stopOrigin=\(String(describing: result.stopOrigin))")
        if result.state == .running {
            if result.startOrigin == .remote {
                self.navigationPath.append(.pfd)
            }
        } else if result.state == .stopped {
            // 생략
        }
    }
    .store(in: &cancellables)
```

이렇게 세션이 시작되거나 끝나거나, 상태가 바뀌거나, 최종적으로 화면 전환이 결정되는 모든 지점에 로그를 심어두면, 강제종료 후 재실행했을 때 어느 시점에 어떤 상태로 세션이 다시 잡히고, 그게 정확히 어떤 경로로 PFD까지 이어지는지 Console.app에서 시간 순서대로 추적할 수 있다.

---

### 적용했는데 검색이 안 된다

막상 적용하고 Console.app에서 `category:ZombieSession`이나 `didChangeTo called`로 검색해봤는데 아무것도 안 나왔다. 그런데 그냥 "Zombie"로 검색하니 로그가 나오긴 했다.

```text
정보	15:20:26.953095+0900	RunWay	retrieveRemoteSession fired, mirroredSession state: 2
정보	15:20:26.954706+0900	RunWay	RunViewModel received state=<private>, startOrigin=<private>, stopOrigin=<private>
```

`retrieveRemoteSession fired, mirroredSession state: 2`까지는 정확한 값이 잘 찍혔는데, 
`RunViewModel received state=<private>, startOrigin=<private>, stopOrigin=<private>`는 정작 필요한 값이 전부 `<private>`로 가려져 있었다.

찾아보니 [OSLogPrivacy Docs](https://developer.apple.com/documentation/os/oslogprivacy){:target="_blank"}에 정의된 옵션이 로그 메시지의 값을 가릴지 보여줄지를 결정한다고 한다. `os_log`는 포맷 문자열이 컴파일 타임 상수여야 하는데, 문자열 보간(`\()`)으로 들어가는 동적인 값은 런타임에 결정되는 데이터라서 프라이버시 보호가 필요한 값으로 자동 표시된다. 코드에 직접 박힌 정적 문자열은 민감하지 않다고 가정되지만, 변수나 계산된 값은 개인정보 노출을 막기 위해 기본적으로 마스킹된다는 것이다.

`mirroredSession.state.rawValue`처럼 `Int` 같은 기본 타입은 예외적으로 그대로 보였지만, `String(describing:)`으로 감싼 보간값은 이 규칙에 걸려 마스킹됐던 것이다. 해결 방법은 명시적으로 `privacy: .public`을 지정해주는 것이었다.

이걸 고치고 다시 재현해보니, `retrieveRemoteSession`이 9초 간격으로 두 번 호출됐고 둘 다 `mirroredSession state: 2`(`.running`)로 동일했다. 강제종료 전후로 한 번씩 호출된 것으로 보였고, 재실행 시점에 같은 살아있는 세션을 다시 잡아내고 있다는 단서였다.

---

### privacy로 해결하기

`mirroredSession.state.rawValue`처럼 `Int`나 `String` 리터럴 같은 기본 타입은 자동으로 public 처리되어 그대로 잘 찍히고 있었다. 문제는 `String(describing:)`으로 감싼 보간값들이었다. 커스텀 enum이나 옵셔널을 거쳐서 만들어진 문자열은 시스템이 민감할 수 있다고 판단해서 기본적으로 마스킹한다. 그래서 의심되는 보간값마다 `privacy: .public`을 명시해주었다.

```swift
ZombieSessionLogger.shared.info("RunViewModel received state=\(String(describing: result.state), privacy: .public), startOrigin=\(String(describing: result.startOrigin), privacy: .public), stopOrigin=\(String(describing: result.stopOrigin), privacy: .public)")
```

```swift
ZombieSessionLogger.shared.info("startWorkout called, session state: \(String(describing: self.session?.state), privacy: .public)")
```

```swift
ZombieSessionLogger.shared.info("stopWorkout called, session state: \(String(describing: self.session?.state), privacy: .public)")
```

---

### 재현 결과로 원인 확정하기

이렇게 고치고 다시 같은 시나리오로 재현해보니, 드디어 진짜 값이 보였다.

```text
정보	15:29:31.536163+0900	RunWay	retrieveRemoteSession fired, mirroredSession state: 2
정보	15:29:31.536207+0900	RunWay	RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
정보	15:29:41.958224+0900	RunWay	retrieveRemoteSession fired, mirroredSession state: 2
정보	15:29:41.999140+0900	RunWay	RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
```

`retrieveRemoteSession`이 10초 간격으로 두 번 호출됐는데, 둘 다 `mirroredSession state: 2`(`.running`), `startOrigin=.remote`로 완전히 동일했다.

이 10초라는 간격이 정확히 iPhone 앱을 강제종료하고 다시 켜는 데 걸린 시간과 일치했다. 즉 첫 번째 로그가 강제종료 직전의 정상적인 미러링 시작이고, 두 번째 로그는 재실행하자마자 다시 잡힌 좀비 세션인 것으로 보였다.

`RunViewModel`의 구독부 로직을 보면

```swift
if result.state == .running {
    if result.startOrigin == .remote {
        self.navigationPath.append(.pfd)
    }
}
```

`startOrigin == .remote`인 조건이 두 번 다 만족되니, 재실행 시점에도 똑같이 `navigationPath.append(.pfd)`가 실행되어버린다.

근본적으로는 강제종료를 해도 `HKWorkoutSession`이 운영체제 차원에서 계속 `.running`으로 살아있기 때문에 벌어지는 일이었다. 앱이 죽어도 세션 자체는 안 죽으니, 앱을 다시 켜면 `retrieveRemoteSession()`이 그 살아있는 세션을 또 발견하고, 마치 새로 미러링이 시작된 것처럼 똑같은 흐름을 한 번 더 타면서 PFD로 직행하는 것이다.

정확히 어디서 그 흐름이 일어나는지 짚어보면 이렇다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-29-RunningProject-17/zombie_trigger_exact_path.png){: width="70%" height="70%"}

`retrieveRemoteSession()`이 좀비 세션을 `.running` 상태로 전달받으면, 그 즉시 `if mirroredSession.state == .running { self.handleiOSStateChange(.running) }`로 처리해서 `sessionStatePublisher`에 이벤트를 흘려보낸다. 이 경로 어디에도 "이게 좀비인지 정상 시작인지"를 구분하는 지점이 없다. 그래서 `RunViewModel`의 구독부가 그 이벤트를 받으면 그냥 평소처럼 `navigationPath.append(.pfd)`를 실행해버리는 것이다.

---

### session = nil이 아니라 더 근본적인 판단 기준이 필요하다

"그러면 강제종료되는 순간에 `session?.end()`를 호출하면 되지 않나?"라는 생각이 들었다. 찾아보니 이게 원천적으로 불가능했다.

사용자가 앱 스위처에서 위로 스와이프해서 강제종료하면, iOS는 그 즉시 프로세스를 죽여버리고 `applicationWillTerminate(_:)`를 포함한 어떤 생명주기 콜백도 호출하지 않는다. iOS가 메모리 회수 등의 이유로 백그라운드 앱을 시스템 차원에서 종료하는 경우라면 운 좋게 `applicationWillTerminate(_:)`가 호출될 수도 있지만, 사용자가 직접 강제종료하는 경우엔 그런 기회 자체가 없다.

즉 "강제종료되는 순간에 정리 코드를 실행한다"는 접근 자체가 막혀 있는 셈이었다. 그래서 방향을 바꿔야 했다.

종료 시점에 끼어드는 대신, 재실행 시점에 "이 세션이 좀비인지 아닌지"를 판단하는 쪽으로 다시 가야 했다.

---

### UserDefaults를 통한 문제 해결

방향을 다시 정리하면, "이게 좀비인지 아닌지를 시간이나 추측으로 판단하지 말고, 사실에 기반해서 판단하자"는 것이었다. 정상적인 흐름이라면 러닝을 시작할 때 `true`로, 정상적으로 TOUCHDOWN까지 가서 종료될 때 `false`로 바뀌는 플래그를 `UserDefaults`에 하나 두면, 앱이 다음번에 켜졌을 때 그 값이 `true`로 남아있다는 것 자체가 "직전 세션이 정상적으로 끝나지 않았다"는 명확한 증거가 된다.

```swift
extension HealthKitService {
    static let isRunningKey = "RunWay.isRunningInProgress"
}
```

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    UserDefaults.standard.set(true, forKey: HealthKitService.isRunningKey)
    // 생략
}

func stopWorkout() {
    UserDefaults.standard.set(false, forKey: HealthKitService.isRunningKey)
    // 생략
}
```

이 플래그를 언제 읽어야 하는지가 중요했다. `retrieveRemoteSession()`의 핸들러 안에서 읽으면, 그 사이에 다른 코드가 먼저 `true`로 바꿔버렸을 수도 있어서 정확한 판단이 안 될 수 있었다. 그래서 `RunViewModel.init()`에서 `retrieveRemoteSession()`을 호출하기 *전에*, 가장 먼저 이 값을 읽어서 따로 저장해두기로 했다.

```swift
init() {
    let wasRunningBeforeThisLaunch = UserDefaults.standard.bool(forKey: HealthKitService.isRunningKey)
    HealthKitService.shared.wasZombieSuspected = wasRunningBeforeThisLaunch
    
    // 생략
    
    HealthKitService.shared.retrieveRemoteSession()
    // 생략
}
```

이렇게 하면 앱이 켜진 그 순간의 진짜 상태를 정확히 기억해두고, 이후 어떤 코드가 `UserDefaults` 값을 바꾸더라도 영향을 받지 않게 된다.

---

### 플래그가 true일 때 무엇을 할 것인가

`false`(정상 종료)일 때는 그냥 평소처럼 처리하면 되니 신경 쓸 게 없었다. 진짜 고민은 `true`(좀비 의심)일 때 뭘 해야 하느냐였다.

처음 떠올린 후보는 세 가지였다.

1. PFD로 보내지 않고 그냥 무시한다
2. 사용자에게 alert를 띄워서 "이전 러닝이 비정상 종료됐다"는 걸 알리고 선택권을 준다
3. 좀비 세션을 조용히 정리하고 플래그도 깨끗이 되돌린다

2번은 사용자 경험상 너무 무겁다고 판단해서 제외했다. 1번과 3번을 같이 가는 게 맞다고 생각했다. 단순히 화면 전환만 막는 걸로는(1번만) 시스템에 살아있는 `.running` 세션 자체가 그대로 남아있게 되니, 다음에도 또 같은 좀비를 만날 수 있었다. 그래서 화면은 막으면서(1번) 살아있는 세션도 같이 정리하는(3번) 방향으로 가기로 했다.

문제는 "세션을 정리한다"는 게 정확히 뭘 의미하는지였다. 좀비 세션에 `session?.end()`를 부르면 되지 않을까 다시 생각해봤는데, 이전에 이걸 시도했을 때 Watch 쪽 진짜 세션까지 같이 끊겨버리는 부작용이 있었다.

`end()`가 정확히 어떤 효과를 내는지 다시 확인해봤다. [end Docs](https://developer.apple.com/documentation/healthkit/hkworkoutsession/end()){:target="_blank"}는 "워크아웃 세션을 끝낸다"는 한 줄 설명뿐이라 정확한 동작까지는 안 나와 있었는데, Xcode SDK에 포함된 `HKWorkoutSession.h` 헤더 파일의 주석을 보면 좀 더 자세히 적혀 있었다.

```text
@method        end
@abstract      Ends the workout session.
@discussion    This method will end the session if it is currently running or stopped. The state of the workout session will transition to HKWorkoutSessionStateEnded. Once a workout session is ended, it cannot be reused to start a new workout session. Sensor algorithms will be stopped, no new data will be generated for this session, and the system will exit session mode.
```

세션이 `.running`이든 `.stopped`든 상태와 무관하게 그 세션을 끝내고 `.ended`로 전환시키며, **한 번 `.ended`가 되면 그 세션은 다시 새로운 워크아웃을 시작하는 데 재사용할 수 없다**고 적혀 있다. 일시정지처럼 되돌릴 수 있는 동작이 아니라, 세션의 생명주기를 완전히 끝내버리는 영구적인 동작이었다.

그러니까 처음 겪었던 부작용은 당연한 결과였다. 미러링된 세션은 iPhone과 Watch가 같은 세션을 공유하는 관계라, 한쪽에서 `.end()`를 부르면 그 세션 자체가 영구히 끝나버려서 양쪽 다 더 이상 그 세션을 쓸 수 없게 되는 것이었다.

다만 이번 상황은 다르다고 봤다. 좀비 세션을 만나는 시점은 이미 Watch도 강제종료되어 있는 상태이기 때문에, 그 세션은 어차피 양쪽 다 더 이상 쓸 일이 없는 죽은 관계다. `.end()`로 영구히 끝내도 부작용이 없을 거라 판단했다.

다만 혹시나 하는 마음에, 정말로 좀비라고 확신할 수 있는 경우(`UserDefaults` 플래그가 `true`인 경우)에만 `.end()`를 부르도록 가드를 걸어서, 정상적인 미러링 시작 케이스에는 절대 영향이 없도록 했다.

---

### 적용하기

지금까지 정리한 내용을 코드에 반영했다.

```swift
var wasZombieSuspected: Bool = false
```

```swift
func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        Task { @MainActor in
            if mirroredSession.state == .running && self.wasZombieSuspected {
                ZombieSessionLogger.shared.info("zombie session detected — ending it")
                mirroredSession.end()
                UserDefaults.standard.set(false, forKey: HealthKitService.isRunningKey)
                self.session = nil
                return
            }

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

`wasZombieSuspected`가 `true`인데 세션이 `.running`으로 들어오면, 그 즉시 `mirroredSession.end()`로 세션을 영구히 끝내고 `UserDefaults` 플래그도 `false`로 되돌린 다음 `return`한다. `self.session`, `runningMode`, `startOrigin` 같은 값들도 일절 세팅하지 않고, `handleiOSStateChange(.running)`도 호출하지 않으니 `sessionStatePublisher`로 이벤트 자체가 발행되지 않는다. 정상적인 미러링 시작이라면 `wasZombieSuspected`가 `false`라서 이 가드를 그대로 통과해 평소처럼 처리된다.

---

### wasZombieSuspected 단독 조건으로 변경

`mirroredSession.state == .running && self.wasZombieSuspected` 조건에서 `state` 체크를 빼기로 했다. 이전 로그에서 핸들러가 `state=1`(`.notStarted`)로 먼저 들어오고, 그 직후 `didChangeTo`로 `.running`이 오는 패턴이 포착됐기 때문이다. `state == .running`을 같이 체크하면 이 케이스를 막지 못한다.

```swift
if self.wasZombieSuspected {
    ZombieSessionLogger.shared.info("zombie session detected — ignoring")
    self.session = nil
    return
}
```

적용 후 재현해보니 `wasZombieSuspected=false`인데도 PFD로 가는 현상이 반복됐다.

```text
정보	RunWay	09:27:48.787651+0900	RunViewModel init: wasZombieSuspected set to false
정보	RunWay	09:27:48.838778+0900	retrieveRemoteSession: wasZombieSuspected=false, state=2
정보	RunWay	09:27:48.838800+0900	handleiOSStateChange called: toState=2
정보	RunWay	09:27:48.838815+0900	RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
```

`wasZombieSuspected=true`로 감지에 성공한 직후, 다시 재실행하면 `false`로 리셋되어 PFD로 직행하는 패턴이 반복됐다.

```text
정보	RunWay	09:27:57.085022+0900	RunViewModel init: wasZombieSuspected set to true
정보	RunWay	09:27:57.125680+0900	retrieveRemoteSession: wasZombieSuspected=true, state=2
정보	RunWay	09:27:57.125688+0900	zombie session detected — ignoring
정보	RunWay	09:28:04.628314+0900	RunViewModel init: wasZombieSuspected set to false
정보	RunWay	09:28:04.687958+0900	retrieveRemoteSession: wasZombieSuspected=false, state=2
정보	RunWay	09:28:04.687966+0900	handleiOSStateChange called: toState=2
정보	RunWay	09:28:04.687973+0900	RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
```

home → pfd → home → pfd 반복이 이루어지고 있었다. `wasZombieSuspected=true`로 막혔다가, 다음 재실행에서 `false`로 덮어써지면서 다시 PFD로 가는 구조였다.

---

### mirroredSession.end() 제거

`end()`를 호출하면 healthd가 `workoutSessionMirroringStartHandler`를 연속으로 재트리거하는 현상이 확인됐다. 로그를 보니 좀비를 `end()`로 정리했더니 새로운 `state=2` 세션이 또 들어오는 무한루프가 생겼다.

```text
정보	RunWay	09:58:22.322114+0900	retrieveRemoteSession: wasZombieSuspected=true, state=2
정보	RunWay	09:58:22.322266+0900	zombie session detected — ending it
정보	RunWay	09:58:22.333930+0900	retrieveRemoteSession: wasZombieSuspected=true, state=2
정보	RunWay	09:58:22.333962+0900	zombie session detected — ending it
정보	RunWay	09:58:22.338567+0900	retrieveRemoteSession: wasZombieSuspected=true, state=2
정보	RunWay	09:58:22.338675+0900	zombie session detected — ending it
```

(이후 동일한 패턴이 수십 번 연속으로 트리거됐다.)

`end()` 없이 ignoring만 하도록 바꿨다. 그런데 이번엔 다른 문제가 생겼다. 좀비를 무시한 후 Watch에서 새로 러닝을 시작해도 `workoutSessionMirroringStartHandler`가 전혀 불리지 않았다. 시스템에 여전히 `.running` 세션이 살아있어서 healthd가 "이미 미러링 중"으로 인식하고 새 콜백을 주지 않는 것으로 보였다.

---

### appLaunchTime 기반 좀비 판별

`wasZombieSuspected` 단독으로는 좀비와 진짜 새 세션을 구분할 수 없다는 게 명확해졌다. 앱이 켜진 시각을 기록해두고, 세션의 `startDate`와 비교하는 방식으로 전환했다. 앱 재실행 이전에 시작된 세션은 좀비, 이후에 시작된 세션은 진짜 새 미러링으로 판단하는 것이다.

`RunViewModel.init()`에서 앱 시작 시각을 저장하고:

```swift
init() {
    let appLaunchTime = Date()
    HealthKitService.shared.appLaunchTime = appLaunchTime
    // 생략
}
```

`retrieveRemoteSession()`에서 비교:

```swift
if self.wasZombieSuspected {
    let sessionStart = mirroredSession.startDate ?? .distantPast
    let isNewSession = sessionStart > self.appLaunchTime
    ZombieSessionLogger.shared.info("zombie check: sessionStart=\(sessionStart.timeIntervalSince1970, privacy: .public), appLaunchTime=\(self.appLaunchTime.timeIntervalSince1970, privacy: .public), isNewSession=\(isNewSession, privacy: .public)")
    if isNewSession {
        self.wasZombieSuspected = false
        UserDefaults.standard.set(false, forKey: HealthKitService.isRunningKey)
    } else {
        ZombieSessionLogger.shared.info("zombie session detected — ignoring")
        self.session = nil
        return
    }
}
```

로그상으로 좀비 감지 자체는 정확하게 작동했다.

```text
정보	RunWay	09:53:31.268034+0900	retrieveRemoteSession: wasZombieSuspected=true, state=2
정보	RunWay	09:53:31.268125+0900	zombie check: sessionStart=1782780799.559969, appLaunchTime=1782780811.202153, isNewSession=false
정보	RunWay	09:53:31.268186+0900	zombie session detected — ignoring
```

세션이 앱 재실행보다 12초 전에 시작된 것으로 확인되어 좀비로 정확히 판별됐다. 그러나 좀비를 무시한 후 Watch에서 새 미러링을 시작해도 핸들러가 불리지 않아 미러링 자체가 불가능한 상태가 됐다. `end()`를 다시 넣으면 Watch 세션까지 끊기고, 넣지 않으면 새 미러링이 안 되는 딜레마였다.

---

### 롤백 결정

`appLaunchTime` 방식까지 적용했지만 결국 해결하지 못했다. 좀비를 ignoring하면 Watch에서 새 미러링을 시작할 수 없고, `end()`로 정리하면 Watch 세션까지 끊기거나 healthd가 핸들러를 폭탄처럼 재트리거했다. 근본적으로 `HKWorkoutSession`이 시스템 데몬(`healthd`) 레벨에서 관리되는 자원이라, 앱 레벨에서 완벽하게 제어하는 데 한계가 있었다.

v1.0 기준으로 미러링 중 강제종료는 일반적인 사용 시나리오가 아니라는 판단 하에, 좀비 세션 관련 코드를 전부 롤백하고 known limitation으로 남겨두기로 했다. `ZombieSessionLogger`와 `os_log` 기반 로깅 구조는 향후 디버깅을 위해 그대로 유지한다.

---

