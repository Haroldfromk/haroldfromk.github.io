---
title: RunWay (26) 미러링 범위 축소
writer: Harold
date: 2026-07-14 15:33:00 +0900
categories: [RunWay]
tags: [HealthKit, WatchConnectivity, ActivityKit]

toc: true
toc_sticky: true
published: true
---

이전글에서 문제 1~7번을 고치고 나서, AI한테 "미러링 4가지 경우의 수(앱주도/워치주도 × 앱종료/워치종료)를 코드로 전부 다시 분석해봐 달라"고 시켰다.

사실 그 전에 실기기 테스트하면서 **워치 위치 정보와 앱 위치 정보가 교차로 발생하는 것 같은 현상**을 이미 한 번 언급했었다. 앱에서 미러링을 시도할 때 워치 GPS랑 앱 GPS가 동시에 따로 작동하는 것처럼 값이 튀는 증상이었다. 당시엔 `start()`에 방어적 리셋(5번 문제)을 걸어서 우회했는데, 근본 원인은 못 찾은 채로 넘어갔었다. 실제 GPS 경로 데이터가 오염될 수 있는 문제라 다이나믹 아일랜드보다 오히려 더 크리티컬한 쪽이었다.

이번에 4가지 경우의 수를 다시 분석하면서, 이 문제를 다시 붙잡고 원인을 제대로 찾아봤다. 그리고 실기기로 나가서 테스트하다가 하나가 더 걸렸다.

---

## 실기기에서 확인한 증상

**워치로 러닝을 시작하니 다이나믹 아일랜드가 READY에서 멈춰있었다.** 뛰기 시작해도 카운트다운도, 페이스도 안 바뀌고 계속 "READY FOR TAKEOFF" 상태 그대로였다. 이건 이번에 새로 발견한 증상이다.

---

## 원인 1 - 워치 GPS가 안 멈추는 이유

`WatchPFDView.swift`의 문서 주석을 보면 이렇게 적혀있다.

```swift
/// 크라운으로 이탈 시 `.onDisappear`에서 상태를 정리한다.
struct WatchPFDView: View {
```

근데 실제 코드엔 `.onDisappear` 자체가 없었다. iPhone의 `PFDView`엔 있는데, 워치 쪽은 처음부터 안 만들어져 있었던 거다. 그러니까 워치에서 화면을 나가도(크라운으로 이탈) `locationService.stopTracking()`이 호출된 적이 없어서 GPS 추적이 백그라운드에서 계속 돌고 있었다. **위치 정보가 교차로 발생하던 게 바로 이거였다.** 멈추지 않고 계속 돌던 이전 추적이 orphan 상태로 남아있는 채로 새 러닝이 시작되니, 두 개의 위치 소스가 동시에 값을 흘려보내고 있었던 거다. 5번 문제 때 걸어둔 `start()`의 방어적 리셋은 `flightData`/`elapsedTime` 값만 0으로 되돌릴 뿐 이 orphan 추적 자체를 멈추는 게 아니라서, 근본적으로는 안 고쳐진 채로 남아있었다.

---

## 원인 2 - 다이나믹 아일랜드가 안 움직이는 이유

`updateCruise()`(페이스/거리로 화면을 갱신하는 함수)를 호출하는 곳을 찾아보니 딱 한 군데뿐이었다.

```swift
// RunViewModel.swift, startStream()
for await data in await runningCenter.streamFlightData() {
    self.flightData = data
    ...
    Task {
        await flightActivityService.updateCruise(
            pace: PaceFormatter.format(data.pace),
            distance: data.distance / 1000,
            heartRate: 0
        )
    }
}
```

이건 iPhone 자신의 GPS 스트림(`runningCenter.streamFlightData()`)에서만 불린다. 근데 워치가 주도할 땐 iPhone이 GPS를 직접 추적하지 않고, 워치가 보내주는 "flightData" WatchConnectivity 메시지를 받아서 화면 값만 갱신한다.

```swift
// WatchConnectivityService+iOS.swift
if let type = message["type"] as? String, type == "flightData" {
    ...
    Task { @MainActor in
        vm?.flightData = flightData   // 화면 값만 갱신
        vm?.isPaused = false
    }
    return
}
```

`flightActivityService.updateCruise()` 호출이 이 수신 로직 어디에도 없다. 그러니까 `startActivity()`로 Live Activity가 처음 뜬 뒤로는 `.preflight`(READY) 상태에서 한 발짝도 못 움직이고 있었던 거다.

---

## 결단 - 워치 주도 미러링을 없애기로 했다

지금까지 고친 문제들을 세어보면, 절반 이상이 "워치 주도 + 앱이 그걸 실시간으로 따라가야 한다"는 요구사항에서 나왔다.

- 4번: 워치 주도 + 앱 종료 시 지도가 안 나옴
- 6번: 원격 종료 이벤트 중복 발행
- 이번에 찾은 워치 GPS orphan 추적 (실제 경로 데이터가 오염될 수 있는 문제라 제일 크리티컬했다)
- 다이나믹 아일랜드 READY 멈춤

양방향 미러링은 원래 하드웨어/OS 레벨에서도 까다로운 기능이고, 이 구조를 유지하는 한 비슷한 종류의 엣지케이스가 계속 나올 가능성이 높다고 판단했다. 그래서 미러링 범위를 이렇게 좁히기로 했다.

- **앱 주도 + 워치 미러링**: 유지한다. 심박수 같은 워치 센서 데이터가 필요하니까.
- **워치 주도**: 미러링을 아예 안 한다. 워치가 완전히 독립적으로 뛰고, 종료하면 기존에 있던 "워치 단독 러닝" 경로로 기록만 iPhone Logbook에 전달한다.

실사용 관점에서도 자연스러운 선택이라고 생각한다. 워치로 뛸 땐 보통 폰을 안 보거나 주머니에 넣어두니까, 폰 화면에 실시간으로 뭔가 뜰 필요가 딱히 없다. 종료하고 나서 기록만 로그북에 잘 들어오면 충분하다.

---

## 구현

### 1. 워치가 리딩일 땐 미러링 시도 자체를 안 함

`startWorkout()`은 iPhone과 Watch 양쪽에서 공유하는 함수라, `#if os(watchOS)` 조건 안에서 무조건 `startMirroringToCompanionDevice()`를 호출하고 있었다. 이 함수는 워치가 직접 주도할 때(`WatchViewModel.updatePhase(.cruise)`)와 iPhone의 주도를 받아서 미러링을 완성할 때(`AppDelegate.handle(_:)`) 양쪽 다에서 호출되는데, 마침 이 두 경우 `startOrigin`이 각각 `.local`/`.remote`로 이미 다르게 세팅되어 있어서 이 값으로 두 경우를 구분할 수 있었다.

```swift
// HealthKitService.swift
#else
    if startOrigin != .local, WCSession.default.isReachable {
        do {
            try await session?.startMirroringToCompanionDevice()
            runningMode = .mirrored
        } catch {
            print("Watch: mirroring failed - \(error)")
        }
    }
#endif
```

`startOrigin == .local`(워치가 직접 주도)일 땐 이 블록 자체를 건너뛰어서, iPhone의 `workoutSessionMirroringStartHandler`가 아예 실행되지 않는다.

---

### 2. 종료 신호도 미러링 중일 때만 보냄

워치가 독립 실행 중이었다면 iPhone에 종료 신호를 보낼 이유가 없다. 오히려 iPhone이 다른 화면을 보고 있었다면 불필요하게 리셋될 수 있어서, 이것도 막았다.

```swift
// WatchViewModel.swift
if result.stopOrigin == .local {
    if result.runningMode == .mirrored {
        watchConnectivityService.sendStopSignal()
    }
}
```

---

### 3. 빠져있던 `.onDisappear` 추가

주석에만 있고 실제로는 없던 안전장치를 iPhone의 `PFDView`와 똑같은 패턴으로 채워 넣었다.

```swift
// WatchPFDView.swift
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

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-14-RunningProject-26/runway26-scope-narrowing.png){: width="75%" height="75%"}

이제 4가지 경우의 수가 사실상 3가지로 줄었다. 앱 주도(워치 미러링 + 워치 종료 포함)는 그대로, 워치 주도는 미러링 없이 독립 실행 하나로 합쳐졌다. 다시 실기기로 테스트해보고 이상 없으면 App Store Connect에 재제출할 예정이다.
