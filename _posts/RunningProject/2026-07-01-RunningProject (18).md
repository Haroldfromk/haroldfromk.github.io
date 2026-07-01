---
title: RunWay (18) 실기기 테스트 & 버그 수정
writer: Harold
date: 2026-07-01 08:33:00 +0900
#last_modified_at: 2026-07-01 08:33:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, SwiftUI, HealthKit]

toc: true
toc_sticky: true
published: true
---

실기기 테스트를 진행하면서 발견한 버그들을 정리한다.

## 발견된 버그

### 1. 일시정지 동기화 안됨

미러링 중 위치 데이터 업데이트가 5초 이상 없으면 주도 기기는 `isPaused`가 걸리는데, 미러링 기기는 그 상태를 전달받지 못해 계속 러닝 중인 것처럼 표시된다.

---

#### Before

미러링 기기(`startOrigin == .remote`)는 `start()`를 호출하지 않고, `startStream()`에서도 FlightData 스트림을 돌리지 않는다. 

타이머 자체가 없으니 `lastReceivedTime` 기준 자체 pause 판단도 동작하지 않는다. 결국 주도 기기가 일시정지 상태가 되어도 미러링 기기는 그 상태를 전달받을 방법이 없어 계속 러닝 중인 것처럼 표시됐다.

---

#### After

`isPaused` 전용 메시지 타입(`pauseData`)을 별도로 만들어서 주도 기기가 일시정지 상태가 되는 순간 즉시 상대 기기로 전달하도록 했다. `sendFlightData()`는 throttle이 걸려 있어 최대 3초 지연이 있는 반면, `sendPauseData()`는 상태 변화 시점에 바로 호출되기 때문에 응답성이 더 빠르다.

```swift
// sendPauseData: iOS / watchOS 동일
func sendPauseData(_ pause: Bool) {
    let message: [String: Any] = [
        "type": "pauseData",
        "isPaused": viewModel?.isPaused ?? false
    ]
    session.sendMessage(message, replyHandler: nil)
}
```

타이머에서 `isPaused = true`가 세팅되는 시점에 바로 호출한다.

```swift
if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 5 {
    timerCancellable.removeAll()
    isPaused = true
    watchConnectivityService.sendPauseData(isPaused)
}
```

`didReceiveMessage()`에서는 `pauseData` 타입을 별도 분기로 처리한다.

```swift
if let type = message["type"] as? String, type == "pauseData" {
    let isPaused = message["isPaused"] as? Bool ?? false
    Task { @MainActor in
        vm?.isPaused = isPaused
    }
    return
}
```

러닝이 재개될 때는 `flightData` 메시지가 다시 들어오는 시점에 `isPaused = false`로 리셋한다. 데이터가 수신된다는 것 자체가 러닝이 재개됐다는 신호이기 때문이다.

```swift
Task { @MainActor in
    vm?.flightData = flightData
    vm?.elapsedTime = elapsedTime
    vm?.isPaused = false
}
```

---

### 2. Pause 개선

기존에는 `isPaused` 상태가 되면 뷰 전체를 덮어버리는 방식이었다. 테스트도 불편하고, 실사용에서 일시정지 상태에서 러닝을 종료하려 해도 overlay가 터치를 가로채 종료 버튼 자체가 눌리지 않는 문제가 있었다.

overlay에 `.allowsHitTesting(false)`를 추가해서 터치가 뒤로 통과되도록 바꿨다. 이제 일시정지 상태에서도 종료 버튼을 그대로 누를 수 있다. 상태를 안내하는 텍스트도 함께 추가했다.

```swift
// iPhone PFDView
Color.rwBg.opacity(0.85)
    .ignoresSafeArea()
    .allowsHitTesting(false)
VStack(spacing: 12) {
    Image(systemName: "pause.circle.fill")
        .font(.system(size: 44))
        .foregroundColor(.rwAmber)
    Text("PAUSED")
        .font(.orbitron(20, weight: .bold))
        .foregroundColor(.rwAmber)
        .kerning(3)
    Text("AWAITING SIGNAL")
        .font(.orbitron(11, weight: .regular))
        .foregroundColor(.rwMuted)
        .kerning(1.5)
}
.allowsHitTesting(false)

// Watch WatchPFDView
Color.rwBg.opacity(0.85)
    .ignoresSafeArea()
    .allowsHitTesting(false)
VStack(spacing: 8) {
    Image(systemName: "pause.circle.fill")
        .font(.system(size: 32))
        .foregroundColor(.rwAmber)
    Text("PAUSED")
        .font(.orbitron(14, weight: .bold))
        .foregroundColor(.rwAmber)
        .kerning(2)
    Text("AWAITING SIGNAL")
        .font(.orbitron(9, weight: .regular))
        .foregroundColor(.rwMuted)
        .kerning(1.5)
}
.allowsHitTesting(false)
```

GPS 데이터가 다시 들어오면 `startStream()`에서 자동으로 해제된다.

---

### 3. elapsedTime 싱크 문제

`elapsedTime`은 `FlightData` 구조체가 아닌 ViewModel에서 별도 타이머로 관리되어 미러링 기기에 전달되지 않고 있었다. 미러링 기기는 타이머 자체가 없으니 항상 0으로 표시됐다.

`sendFlightData()`에 포함시키는 방법도 있었지만 3초 throttle 때문에 화면에서 숫자가 3초마다 뚝뚝 튀는 문제가 있었다. 그래서 `elapsedTime`만 별도 함수로 분리해서 타이머에서 1초마다 전송하는 방식으로 갔다. 페이로드가 작아서 블루투스 부담도 크지 않다.

```swift
func sendElapsedTime(_ time: Int) {
    let message: [String: Any] = [
        "type": "elapsedTime",
        "elapsedTime": time
    ]
    session.sendMessage(message, replyHandler: nil)
}
```

타이머에서 1초마다 호출한다.

```swift
elapsedTime += 1
watchConnectivityService.sendElapsedTime(elapsedTime)
```

`didReceiveMessage()`에도 분기를 추가했다. iOS/watchOS 양쪽 동일하게 적용한다.

```swift
if type == "elapsedTime" {
    let elapsedTime = message["elapsedTime"] as? Int ?? 0
    Task { @MainActor in
        vm?.elapsedTime = elapsedTime
    }
    return
}
```

---

### 4. 종료 시나리오별 동기화 문제

실기기 테스트 결과 시나리오별로 다른 문제가 확인됐다.

- iPhone 주도 미러링
    - 앱 종료: 정상 작동
    - Watch 종료 후 Watch 주도 미러링 시도: iPhone이 반응하지 않음. 단, 이후 iPhone 주도로 한 번 더 러닝을 하고 나면 Watch 주도 미러링이 다시 가능해짐. `resetState()`에서 `startOrigin`이 리셋되지 않아 이전 세션 상태가 남아있는 것으로 추정.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-18/iphone_led_scenarios.png){: width="50%" height="50%"}

---

- Watch 주도 미러링
    - 앱 종료: 정상 작동
    - Watch 종료: Watch가 Summary 없이 바로 홈으로 돌아감. `stopOrigin = .local`임에도 TOUCHDOWN → Summary 흐름을 타지 않는 것으로 보임.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-18/watch_led_scenarios.png){: width="50%" height="50%"}

---

#### sink의 print를 사용해 출력해보기

일단 워치에서 워치종료를 하면 home으로 안가지고 summary로 가졌다. 위에서 발견한 시나리오와는 다르다.

---

1. 워치시작 워치 종료 (정상)
```text 
receive subscription: (PassthroughSubject)
request unlimited
The session has completed activation.
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.running, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: nil, startOrigin: Optional(RunWayWatch_Watch_App.StartOrigin.local)))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.local), startOrigin: nil))
```

---

여기서부터 문제

2. 앱 시작 워치 종료
```text
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.running, runningMode: RunWayWatch_Watch_App.RunningMode.standalone, stopOrigin: nil, startOrigin: Optional(RunWayWatch_Watch_App.StartOrigin.remote)))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.local), startOrigin: nil))
```

---

3. 워치로 미러링 시작 (엡에서 미러링 안됨)
```text
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.running, runningMode: RunWayWatch_Watch_App.RunningMode.standalone, stopOrigin: nil, startOrigin: Optional(RunWayWatch_Watch_App.StartOrigin.local)))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.local), startOrigin: nil))
```

---

4. 이후 앱으로 미러링 시작 (워치 미러링 됨)
```text
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.running, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: nil, startOrigin: Optional(RunWayWatch_Watch_App.StartOrigin.remote)))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.remote), startOrigin: nil))
```

---

5. 이후 워치로 미러링 시작 워치 종료 (home 비정상)
```text
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.running, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: nil, startOrigin: Optional(RunWayWatch_Watch_App.StartOrigin.local)))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.local), startOrigin: nil))
receive value: (SessionStateEvent(state: RunWayWatch_Watch_App.WorkoutSessionState.stopped, runningMode: RunWayWatch_Watch_App.RunningMode.mirrored, stopOrigin: Optional(RunWayWatch_Watch_App.StopOrigin.remote), startOrigin: nil))
```

---

#### startOrigin / stopOrigin 리셋 누락

5번에서 `.stopped, stopOrigin: .remote`가 한 번 더 오는 게 문제였다. Watch가 `stopOrigin: .local`로 `sendStopSignal()`을 iPhone에 보내면, iPhone `handleStopSignal()`이 `updateAndSendState(.stopped, stopOrigin: .remote)`를 발행하고, 이게 Watch `sessionStatePublisher`로 다시 흘러들어와 `resetState()`를 트리거하는 구조였다.

근본 원인은 `resetWorkout()`에서 `startOrigin`과 `stopOrigin`을 초기화하지 않아 이전 세션의 상태가 남아있었던 것이다. 두 값을 `resetWorkout()`에 추가했다.

```swift
func resetWorkout() {
    builder = nil
    workout = nil
    session = nil
    startOrigin = nil
    stopOrigin = nil
}
```

이후 5번 시나리오에서 `.remote`가 다시 오지 않는 것을 확인했다.

---

#### 앱 주도 미러링에서 Watch 종료 후 Watch 주도 미러링 불가

앱 주도 미러링 상태에서 Watch가 종료하면, 이후 Watch에서 새로 주도로 미러링을 시작해도 iPhone이 반응하지 않는 문제였다.

`retrieveRemoteSession()`에 로그를 추가해서 확인해보니 핸들러 등록 자체는 정상이었다.

```text
retrieveRemoteSession: handler registered
```

Watch가 미러링을 시도해도 핸들러가 전혀 불리지 않다가, 앱에서 다시 미러링을 한 번 거치고 나서야 비로소 핸들러가 발동됐다.

```text
retrieveRemoteSession handler fired: state=1
```

`state=1`은 `HKWorkoutSessionState.notStarted`의 rawValue로, 앱이 새로 미러링을 시작하면서 세션이 생성됐지만 아직 `.running` 상태가 아닌 시점에 핸들러가 불린 것이다. 즉 Watch가 시도한 미러링이 아니라 앱이 다시 주도로 시작한 세션을 잡은 것이었다.

원인은 iPhone 주도 미러링에서 Watch가 종료해도 iPhone 쪽 `HKWorkoutSession`이 살아있는 채로 남아있어서, `HKHealthStore`가 "아직 세션 중"으로 인식하고 새 미러링 신호를 무시하는 것이었다. `retrieveRemoteSession()`을 재호출해도 해결되지 않았고, 세션을 명시적으로 종료해야 했다.

iPhone 쪽 `resetWorkout()`에 `session?.end()`를 추가했다.

```swift
// HealthKitService+iOS
func resetWorkout() {
    session?.end()
    builder = nil
    workout = nil
    session = nil
    startOrigin = nil
    stopOrigin = nil
}
```

이후 Watch 주도 미러링 핸들러가 정상적으로 발동되는 것을 확인했다.

```text
retrieveRemoteSession handler fired: state=2
```

`state=2`는 `HKWorkoutSessionState.running`의 rawValue로, Watch가 이미 러닝 중인 세션을 미러링으로 전달했다는 의미다. 기존에는 핸들러 자체가 발동되지 않아 이 로그가 찍히지 않았다.

---

## 정리

여기도 간단하게 정리를 해보려 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-18/result.png){: width="50%" height="50%"}

실기기 테스트를 통해 발견한 버그들을 하나씩 잡아나갔다. 일시정지 동기화는 `sendPauseData()`를 별도로 만들어 해결했고, Pause overlay는 `.allowsHitTesting(false)`로 종료 버튼 접근성을 확보했다. `elapsedTime` 싱크는 1초마다 별도 전송하는 방식으로 해결했다. 미러링 세션 관련 두 문제는 `resetWorkout()`에서 `startOrigin`/`stopOrigin` 초기화 누락과 iPhone 세션 미종료가 원인이었고, 각각 `resetWorkout()`에 nil 초기화와 `session?.end()` 추가로 해결했다.

탭바 배경색이 뷰 전환 시 흰색으로 튀는 현상도 발견했다. `RunWayApp.swift`의 `init()`에서 `UITabBarAppearance`로 배경색과 아이콘 색을 전역으로 세팅하고, `RootTabView`에 `.tint(.rwGreen)`을 추가해 해결했다. 시뮬레이터에서는 여전히 간헐적으로 튀지만 실기기에서는 정상 동작한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-18/problem.png){: width="50%" height="50%"}

```swift
// RunWayApp
init() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(red: 11/255, green: 14/255, blue: 20/255, alpha: 1.0)
    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
    UITabBar.appearance().unselectedItemTintColor = UIColor(red: 136/255, green: 148/255, blue: 158/255, alpha: 1.0) // rwMuted
}

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Deck", systemImage: "house.fill") }
            NavigationStack { LogbookView() }
                .tabItem { Label("Logbook", systemImage: "list.bullet.clipboard") }
            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
        }
        .tint(.rwGreen)
    }
}
```

---

## 추가 보완

테스트하다 보니 정상 흐름 외에 탭바로 중간에 이탈하는 경우를 처리하지 않았다는 걸 발견했다. 러닝 중 탭바로 홈으로 가거나, TouchdownView나 FlightSummaryView에서 `GO TO DECK` 버튼을 안 누르고 나가는 경우 `resetState()`가 호출되지 않아 이전 세션 상태가 남아있는 채로 다음 러닝이 시작되는 문제가 생긴다.

세 곳에 `.onDisappear`를 추가했다.

---

### PFDView

러닝 중 탭바로 이탈하면 워크아웃 세션이 살아있는 채로 홈으로 가버린다. 처음엔 `isRunning`으로 체크하려 했는데, 미러링 중 iPhone은 `startOrigin == .remote`라 `start()`를 호출하지 않아 `isRunning`이 `false`인 경우가 있었다. 그래서 `HealthKitService.shared.session != nil`로 워크아웃 세션 자체가 살아있는지를 기준으로 바꿨다. 단독이든 미러링이든 세션이 있으면 정리한다.

다만 터치다운 버튼을 눌렀을 때도 `.onDisappear`가 트리거되면서 `resetState()`가 먼저 호출되어 `navigationPath`가 초기화되는 문제가 있었다. `didNavigateToTouchdown` 플래그를 추가해서 정상 이탈과 탭바 이탈을 구분했다.

```swift
@State private var didNavigateToTouchdown = false

// 터치다운 버튼
Button {
    didNavigateToTouchdown = true
    Task {
        // 생략
    }
}

.onDisappear {
    guard !didNavigateToTouchdown else { return }
    guard HealthKitService.shared.session != nil else { return }
    Task {
        await runViewModel.stop()
        HealthKitService.shared.stopWorkout()
        await runViewModel.resetState()
    }
}
```

---

### TouchdownView

TouchdownView에서 Summary로 정상 이동하지 않고 탭바로 나가는 경우를 처리했다. Summary로 이동했을 때는 `resetState()`가 불리면 안 되니까 `didNavigateToSummary` 플래그로 구분했다.

```swift
@State private var didNavigateToSummary = false

// Summary 버튼
Button {
    didNavigateToSummary = true
    runViewModel.navigationPath.append(.summary)
}

.onDisappear {
    if !didNavigateToSummary {
        Task {
            await runViewModel.flightActivityService.endActivity()
            await runViewModel.resetState()
        }
    }
}
```

---

### FlightSummaryView

`GO TO DECK` 버튼을 안 누르고 탭바로 나가는 경우를 처리했다. Logbook에서 열린 경우는 `selectedFlight != nil`이라 조건으로 막았다.

```swift
.onDisappear {
    guard selectedFlight == nil else { return }
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

---

### WatchPFDView

iPhone과 동일하게 `END FLIGHT` 없이 크라운으로 이탈하는 경우를 처리했다. `didNavigateToTouchdown` 플래그로 정상 종료와 이탈을 구분했다.

```swift
@State private var didNavigateToTouchdown = false

// onEndFlight 클로저
onEndFlight: {
    didNavigateToTouchdown = true
    Task {
        await saveRunningData()
        viewModel.updatePhase(.touchdown)
        await viewModel.stop()
        viewModel.navigateTo(.touchdown)
    }
}

.onDisappear {
    guard !didNavigateToTouchdown else { return }
    guard HealthKitService.shared.session != nil else { return }
    Task {
        await viewModel.stop()
        HealthKitService.shared.stopWorkout()
        await viewModel.resetState()
    }
}
```

---

### WatchTouchdownView

Summary로 이동하지 않고 크라운으로 나가는 경우를 처리했다.

```swift
@State private var didNavigateToSummary = false

// SUMMARY 버튼
Button {
    didNavigateToSummary = true
    viewModel.navigateTo(.summary)
}

.onDisappear {
    guard !didNavigateToSummary else { return }
    Task {
        await viewModel.resetState()
    }
}
```

---

### WatchSummaryView

Watch는 탭바가 없고 크라운으로만 이탈하니 `RETURN TO BASE` 버튼을 안 눌러도 `.onDisappear`에서 무조건 `resetState()`를 호출한다.

```swift
.onDisappear {
    Task {
        await viewModel.resetState()
    }
}
```

