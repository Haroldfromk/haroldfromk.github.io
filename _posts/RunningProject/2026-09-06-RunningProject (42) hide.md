---
title: RunWay () 앱 강제종료 시 워치에 남는 것들 다시 열어볼 때
writer: Harold
date: 2026-09-06 03:00:00 +0900
categories: [RunWay]
tags: [HealthKit, WatchConnectivity, ActivityKit]

toc: true
toc_sticky: true
published: false
---

이 글은 읽히려고 쓴 글이 아니라 **다시 시작할 때 읽으려고 쓴 글**이다.

앱 주도 미러링으로 뛰다가 아이폰 앱을 강제 종료하면 워치와 건강 앱에 이상한 것들이 남는다. 고칠 방향은 잡았는데 지금 하지 않기로 했다. 1.4에 분석 기능이 들어가면서 분량이 커졌고, 이 문제는 1.5나 그 이후로 밀릴 가능성이 크다. **그때가 되면 나도, 같이 보던 AI도 지금 알아낸 걸 기억하지 못한다.**

그래서 결론만 적지 않고 **어떻게 그 결론에 닿았는지, 무엇을 확인했고 무엇을 확인하지 못했는지, 어떤 선택지를 왜 버렸는지**까지 적는다. 코드 위치도 함께 적는다.

---

## 세 줄 요약

- 앱 주도 미러링에서 **워치는 표시 장치다.** 거리도 시간도 아이폰이 계산해서 보내준다. 아이폰이 죽으면 워치 화면은 마지막 값에서 굳는다.
- 굳은 화면을 사용자가 워치에서 끝내면, 그 러닝은 **앱 Logbook에는 안 남고 건강 앱에만 남는다.** 게다가 시간이 방치한 만큼 부풀어 있다.
- 고칠 자리는 **워치 쪽**이다. 워치는 살아 있고 자기 세션의 주인이라 손댈 수 있다. 아이폰 쪽은 앱이 죽어 있는 동안 할 수 있는 게 없다.

---

## 층을 나눠서 봐야 한다

이 문제를 한 덩어리로 보면 "강제 종료하면 이상해진다"에서 더 나아가지 못한다. **일곱 개 층이 각각 다르게 반응하고, 고칠 수 있는 층과 없는 층이 나뉜다.**

시점을 옮겨가며 층별로 어떻게 되는지 눌러볼 수 있게 만들었다. `지금`이 v1.3.2 기준이고 `제안`이 이 글에서 세운 설계다.

<iframe
  src="/assets/demo/force_quit_layers_simulator.html"
  width="100%"
  height="920px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

두 구조에서 **"강제 종료 직후"는 완전히 같다.** 앱이 죽어 있는 동안은 어떤 코드도 돌지 않기 때문이다. 갈라지는 건 그다음부터다.

---

## 왜 워치 화면이 굳는가

핵심은 **앱 주도 미러링에서 워치가 자기 타이머조차 안 만든다**는 것이다. 이걸 모르면 엉뚱한 데를 고치게 된다.

### 워치가 시작되는 경로가 두 개다

```swift
// AppDelegate.swift - 앱 주도. startWatchApp(toHandle:)이 여기를 부른다
func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task {
        do {
            HealthKitService.shared.startOrigin = .remote
            try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
        } catch {
            // 생략
        }
    }
}
```

이 경로는 `HealthKitService.startWorkout()`만 부르고 **`WatchViewModel.start()`는 부르지 않는다.** `start()`를 부르는 곳은 프로젝트 전체에서 한 군데뿐이다.

```swift
// WatchTakeoffView.swift:165 - 워치 주도로 시작할 때만
await viewModel.start()
```

그래서 앱 주도 미러링 중인 워치에는 다음이 **전부 없다.**

- 1초 타이머 (`timerPublisher`)
- GPS 추적 (`locationService.startTracking()`)
- 15초 GPS 유실 안전망

세 번째가 특히 중요하다. 안전망 코드는 있지만 `start()` 안에 있다.

```swift
// WatchViewModel.swift - start() 안의 타이머
if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 15 {
    timerCancellable.removeAll()
    isPaused = true
    watchConnectivityService.sendPauseData(isPaused)
}
```

**미러링에서는 이 블록이 아예 실행되지 않는다.** 처음에 나는 이걸 보고 "미러링 중에도 15초마다 이게 돌면 매번 일시정지되는 것 아닌가" 하고 의심했는데, 타이머 자체가 안 만들어져서 그런 일은 없다. 대신 **값이 안 온다는 걸 알아챌 장치도 없다**는 뜻이 된다.

### 그러면 워치 화면의 숫자는 어디서 오는가

전부 아이폰이 보내주는 메시지다.

```swift
// WatchConnectivityService+watchOS.swift - 경과 시간 수신
if let type = message["type"] as? String, type == "elapsedTime" {
    let elapsedTime = message["elapsedTime"] as? Int ?? 0
    Task { @MainActor in
        viewModel?.elapsedTime = elapsedTime
    }
    return
}

// 거리, 페이스, 고도, 좌표 수신
if type == "flightData" {
    // 생략
    guard HealthKitService.shared.startOrigin == .remote else { return }
    // 생략
    viewModel?.flightData = flightData
}
```

아이폰이 1초마다 `sendElapsedTime()`을, 그리고 계산할 때마다 `sendFlightData()`를 보낸다. 워치는 받아서 대입만 한다.

**아이폰이 죽으면 두 메시지가 동시에 끊긴다.** 워치에는 자기 타이머가 없으니 시간도 안 흐르고, GPS가 없으니 거리도 안 는다. 그래서 화면이 그 값 그대로 굳는다. **일시정지가 아니다.** `isPaused`를 건드리는 것도 아이폰이 보내는 `pauseData` 메시지가 유일한 출처라, 아이폰이 죽으면 일시정지 표시조차 뜨지 않는다.

이것이 실기기에서 관찰한 "5초에서 멈춘 채, 일시정지도 아닌 상태"의 정체다.

---

## 왜 앱 Logbook에는 안 남는가

워치에서 END FLIGHT를 눌러 끝내면 워치는 건강 앱에 저장한다.

```swift
// HealthKitService+watch.swift
func finishWatchWorkout(at date: Date) async {
    do {
        try await builder?.endCollection(at: date)
        workout = try await builder?.finishWorkout()
        session?.end()
    } catch {
        alertPublisher.send(AlertContext.workoutSessionFailed)
    }
}
```

그런데 앱 Logbook용 기록은 만들지 않는다. 첫 줄에 가드가 있다.

```swift
// WatchViewModel.swift
func saveRunningData() async {
    guard HealthKitService.shared.startOrigin == .local else { return }
    // 생략
    pendingFlightQueue.append(runningData)
}
```

`startOrigin == .local`, 즉 **워치가 주도한 러닝일 때만** 기록을 만든다. 미러링 러닝은 아이폰이 저장하는 게 당연하니 이 가드가 원래는 맞다. 문제는 **아이폰이 죽어서 저장할 주체가 사라진 경우**를 이 가드가 구분하지 못한다는 것이다.

그래서 결과가 이렇게 어긋난다.

| | 남는가 | 시간 |
|---|---|---|
| 앱 Logbook | 안 남는다 | |
| 애플 건강 앱 | 남는다 | 방치한 시간까지 포함해 부풀어 있다 |

시간이 부푸는 이유는 `finishWatchWorkout(at:)`에 넘기는 시각이 **사용자가 END FLIGHT를 누른 순간**이기 때문이다. 화면은 5초에 멈춰 있었어도 세션은 그동안 계속 돌고 있었다.

---

## 하려는 것

세 가지다. 순서대로 위험이 낮다.

### 1. 워치에 신호 끊김 오버레이

값이 N초 동안 안 오면 워치 화면에 오버레이를 띄우고 **종료 버튼을 함께 준다.** 일시정지 화면과 비슷한 모양이면 된다.

필요한 준비가 두 가지다.

**첫째, 수신 시각을 기록해야 한다.** `lastReceivedTime`이라는 프로퍼티가 이미 있는데, 미러링에서는 갱신되는 곳이 없다.

```swift
// before - .local 분기 안에서만 갱신된다
if HealthKitService.shared.startOrigin == .local {
    Task {
        for await data in await runningCenter.streamFlightData() {
            self.flightData = data
            lastReceivedTime = .now
            // 생략
        }
    }
}
```

```swift
// after - 수신 핸들러에서도 갱신한다
// WatchConnectivityService+watchOS.swift, flightData / elapsedTime 수신부
Task { @MainActor in
    viewModel?.lastReceivedTime = .now
    // 생략
}
```

**둘째, 감시할 타이머가 필요하다.** 미러링에서는 타이머가 아예 없으므로 새로 만들어야 한다. 기존 `start()`의 타이머를 재사용하면 `elapsedTime`까지 자기가 증가시키게 되어 아이폰 값과 충돌한다. **시간을 세지 않고 감시만 하는 타이머**를 따로 두는 편이 안전하다.

```swift
// after - 미러링 전용 감시. 시간은 세지 않는다
private func startSignalWatchdog() {
    signalCancellable = timerPublisher.autoconnect()
        .sink { [weak self] _ in
            guard let self, isRunning else { return }
            let gap = Date.now.timeIntervalSince(lastReceivedTime)
            isSignalLost = gap >= Self.signalLostThreshold
        }
}
```

**자동으로 끝내지는 않는다.** 이유는 아래 "버린 선택지"에 적었다.

### 2. 종료 시 마감 시각 보정

```swift
// before - 누른 순간으로 마감한다
await finishWatchWorkout(at: date)
```

```swift
// after - 신호가 끊긴 상태면 마지막으로 값을 받은 시각으로 마감한다
await finishWatchWorkout(at: isSignalLost ? lastReceivedTime : date)
```

한 줄이지만 효과가 크다. 건강 앱에 남는 기록이 실제 뛴 만큼으로 줄어든다.

### 3. 그 기록을 아이폰 Logbook으로 보내기

워치에는 아이폰이 꺼져 있어도 기록을 보낼 수 있는 경로가 이미 있다.

```swift
// WatchConnectivityService+watchOS.swift
/// `sendMessage`와 달리 iPhone이 연결되어 있지 않아도 큐에 쌓였다가 나중에 전달되므로,
/// `isReachable` 가드를 걸지 않는다. 전송을 마친 기록만 큐에서 제거한다.
func sendRunningData() {
    // 생략
    session.transferUserInfo(userInfo)
}
```

아이폰 쪽 수신부도 이미 있다. `didReceiveUserInfo`가 `RunViewModel.saveIncomingWatchFlight(_:)`로 바로 저장한다. 콜드 런치 초반에 도착해도 저장되도록 `modelContext`를 `RunWayApp.init()`에서 확보해두는 처리까지 되어 있다(v1.3에서 워치 단독 러닝 기록이 간헐적으로 유실되던 문제를 고치며 넣은 것).

그러니 **필요한 건 `saveRunningData()`의 가드를 여는 것뿐이다.**

```swift
// after
// 미러링이어도 신호가 끊긴 채 종료했다면, 아이폰은 이 러닝을 저장하지 못한다.
// 그때는 워치가 대신 기록을 만들어 전송 큐에 넣는다.
guard HealthKitService.shared.startOrigin == .local || isSignalLost else { return }
```

**다만 여기에 미해결 문제가 하나 있다.** 아래에 적었다.

---

## 미해결 질문

다시 시작할 때 여기부터 보면 된다.

### 좌표를 누가 들고 있는가

`saveRunningData()`가 좌표를 가져오는 곳은 워치의 계산기다.

```swift
func getCoordinates() async -> [CLLocationCoordinate2D] {
    return await runningCenter.coordinateArray
}
```

미러링 중인 워치는 GPS를 켜지 않으므로 **이 배열이 비어 있을 것이다.**(추정. 확인 필요) 그러면 "하려는 것" 3번을 적용해도 Logbook에 **지도가 빈 기록**이 들어간다.

여기서 갈 수 있는 길이 셋이다.

1. **지도 없이 저장한다.** 거리와 시간은 맞으니 아무것도 없는 것보다 낫다는 판단이다. 다만 Logbook의 다른 기록들과 생김새가 달라진다
2. **좌표를 따로 쌓는다.** 수신하는 `flightData`에 위도와 경도가 실려 오므로, 미러링 중에도 그걸 배열에 모아두면 지도를 그릴 수 있다
3. **Logbook 전달 자체를 포기한다.** "하려는 것"에서 3번을 빼고 1번, 2번만 한다. 그러면 건강 앱에는 실제 뛴 만큼 남고 Logbook에는 안 남는 상태가 된다

2번이 맞아 보인다. 다만 아이폰이 `sendFlightData()`를 보내는 주기가 워치가 보내는 주기(3초 스로틀)와 같은지 확인하지 않았다. 주기가 성기면 지도가 각지게 나온다.

### 아이폰의 남은 세션은 어떻게 되는가

v1.3.2에서 미러링 러닝의 중복 저장을 고쳤는데, 그 `discardWorkout()`은 **정상 종료 경로에만 있다.**

```swift
// HealthKitService+iOS.swift - handleiOSStateChange(.stopped)
if runningMode == .mirrored {
    builder?.discardWorkout()
}
session?.end()
```

강제 종료는 이 경로를 지나가지 않는다. 그러면 아이폰의 남은 세션을 시스템이 마감해 저장하고, 워치도 저장하니 **강제 종료한 러닝이 건강 앱에 두 건 남을 수 있다.** 실기기로 확인하지 않았다. 워치를 끄고 한 실험에서는 아이폰 기록 한 건만 남는 것을 확인했지만, 워치를 켠 상태는 확인하지 못했다.

확인 방법은 간단하다. 워치를 켜고 미러링으로 시작한 뒤 아이폰을 강제 종료하고, 워치에서 종료한 다음 건강 앱 운동 목록을 열어보면 된다.

두 건이 맞다면 `recoverActiveWorkoutSession()`으로 회수해서 `discardWorkout()`으로 버리는 방향이 필요하다. 이 API는 iOS 26.0부터 쓸 수 있고 이 프로젝트의 배포 타겟이 26.0이라 조건은 맞는데, **회수한 세션에서 빌더를 다시 얻을 수 있는지, 시스템이 마감하기 전에 손이 닿는지를 확인하지 못했다.**

### 오버레이 임계값은 몇 초인가

기존 GPS 유실 안전망이 15초다(원래 8초였다가 상향). 미러링 신호 끊김도 같은 값으로 맞출지, 더 짧게 잡을지 정해야 한다.

짧으면 오검출이 늘고, 길면 사용자가 그만큼 굳은 화면을 본다. **오검출의 대가가 오버레이 하나뿐이므로 짧게 잡아도 손해가 크지 않다.** 10초 근처를 시작점으로 보되 실기기에서 조정하는 게 맞다.

---

## 검토했다가 버린 선택지

여기가 이 문서에서 제일 중요한 부분일 수 있다. **다시 시작할 때 같은 길을 또 걸어보지 않으려고 적는다.**

### 신호가 끊기면 워치가 자동으로 러닝을 종료한다

**버렸다.** 값이 안 온다는 게 앱이 죽었다는 뜻이 아니기 때문이다. 아이폰을 주머니에 넣었다가 블루투스가 잠깐 흔들리거나, 전화가 오거나, 아이폰이 잠깐 버벅이기만 해도 몇십 초는 쉽게 빈다. 그때마다 러닝을 끝내면 **멀쩡히 뛰던 사용자가 기록을 잃는다.**

지금의 굳은 화면은 불편하긴 해도 사용자가 직접 끝낼 수 있어서 데이터는 지킨다. 자동 종료는 그 안전망을 없애는 쪽이다. 오검출의 대가를 비교하면 답이 나온다.

| | 오검출 시 손해 |
|---|---|
| 자동 종료 | 뛰고 있던 러닝이 끝난다 |
| 오버레이 표시 | 잘못 뜬 오버레이 하나 |

### 워치 앱이 스스로 종료한다

**버렸다.** 앱이 스스로 종료하는 건 애플이 권장하지 않아 심사에서 문제가 될 수 있고, 무엇보다 세션이 정리 없이 죽으면 **지금 아이폰에서 겪는 것과 똑같은 상태를 워치에서 만들게 된다.** 문제를 옮기는 것뿐이다.

### 신호가 끊기면 워치가 GPS를 켜서 이어 달린다

**보류했다.** 사용자에게는 이게 제일 좋은 결과다. 러닝이 안 끊긴다.

그런데 `startOrigin`을 `.remote`에서 `.local`로 승격하는 구조 변경이다. 그때까지의 거리는 아이폰이 계산한 값이고 이후는 워치가 계산한 값이라 이어 붙이는 문제도 생긴다. 무엇보다 **26번 글에서 워치 주도 미러링을 걷어낸 이유와 정면으로 부딪힌다.** 그때 문제의 절반 이상이 그 조합 하나에서 나왔었다.

강제 종료는 드문 상황인데 이건 평상시 코드 경로를 바꾸는 일이다. 손익이 안 맞는다.

### Live Activity를 앱이 정리한다

**필요 없었다.** 강제 종료하면 다이나믹 아일랜드에 러닝이 남길래 앱 시작 시 `Activity<FlightActivityAttributes>.activities`를 순회해 끝내는 코드를 준비했는데, **그 코드 없이도 앱을 다시 켜면 시스템이 정리한다.** 실기기에서 확인했다.

확인할 때 함정이 있다. **앱이 전경에 있는 동안에는 자기 Live Activity가 다이나믹 아일랜드에 표시되지 않는다.** 그래서 보는 시점에 따라 결론이 정반대로 나온다.

| 시점 | 보이는 것 | 잘못된 결론 |
|---|---|---|
| 강제 종료 직후 | 남아 있다 | "안 고쳐졌다" |
| 앱을 다시 켠 화면 | 안 보인다 | "고쳐졌다" |
| 앱을 켠 뒤 홈으로 나갔을 때 | 사라져 있다 | 여기가 진짜 답 |

화면을 잠그고 보는 쪽이 제일 확실하다. 잠금 화면에는 Live Activity가 배너로 뜬다.

다만 **앱을 다시 켜기 전까지는 멈춘 값을 그대로 띄우고 있다.** 이걸 없앨 방법은 없지만(서버 푸시가 없으므로) 거짓말을 멈출 수는 있다. `startActivity()`, `update()`, `endActivity()` 세 곳 모두 `staleDate: nil`로 넘기고 있는데, 여기에 기한을 넣으면 갱신이 끊긴 시점부터 시스템이 오래된 것으로 표시하고 위젯에서 `context.isStale`로 분기할 수 있다. **위 1번, 2번과 성격이 같아서 같이 하면 된다.**

---

## 다시 시작할 때 확인 순서

1. **문제가 아직 있는지부터 확인한다.** 워치를 켜고 미러링으로 시작, 아이폰 강제 종료, 워치 화면이 굳는지 확인
2. 워치에서 END FLIGHT로 종료
3. 건강 앱 운동 목록을 연다. **몇 건인지, 시간이 얼마인지** 확인
4. 앱 Logbook을 연다. 없는 게 맞다
5. `runningCenter.coordinateArray`가 미러링 중에 비어 있는지 확인 (위 미해결 질문)

3번 결과에 따라 할 일이 갈린다. 두 건이면 아이폰 세션 회수까지 필요하고, 한 건이면 워치 쪽만 손보면 된다.

---

## 관련 파일

| 파일 | 무엇이 있는가 |
|---|---|
| `RunWayWatch/Services/AppDelegate.swift` | 앱 주도 시작 진입점. `startOrigin = .remote` 세팅 |
| `RunWayWatch/ViewModels/WatchViewModel.swift` | `start()`(워치 주도 전용), `lastReceivedTime`, `saveRunningData()`의 `.local` 가드, `pendingFlightQueue` |
| `RunWayWatch/Services/WatchConnectivityService+watchOS.swift` | `flightData`/`elapsedTime`/`pauseData` 수신, `sendRunningData()`의 `transferUserInfo` |
| `RunWayWatch/Services/HealthKitService+watch.swift` | `finishWatchWorkout(at:)`, `handleWatchOSStateChange` |
| `RunWay/Services/HealthKitService+iOS.swift` | `handleiOSStateChange`, `resetWorkout()`, `discardWorkout()` 위치 |
| `RunWay/Services/WatchConnectivityService+iOS.swift` | `didReceiveUserInfo` 수신 후 `saveIncomingWatchFlight(_:)` |
| `RunWay/Services/FlightActivityService.swift` | `staleDate: nil` 세 곳 |
| `RunWay/Views/Running/PFDView.swift` | 화면 이탈 정리가 `session != nil`을 기준으로 쓴다 |

관련 글은 17번(좀비 세션 첫 시도와 롤백), 26번(미러링 범위 축소), 41번(건강 앱 중복 저장)이다.

---

## 마지막으로

이 문제를 오래 붙잡고 있으면서 배운 게 하나 있다.

17번 글에서는 "healthd가 들고 있어서 앱 코드로는 불가능하다"로 끝냈다. 그 문장은 절반만 맞았다. 정확히는 **그 세션의 주인이 아이폰이 아니어서 불가능했다.** 미러링 범위를 줄이면서 주인이 바뀌자 막혀 있던 이유가 같이 사라졌다.

지금 남은 것들도 같은 방식으로 갈린다. 아이폰이 죽어 있는 동안 아이폰에서 할 수 있는 일은 없다. 반면 **워치는 살아 있고 자기 세션의 주인이다.** 그래서 고칠 수 있다.

무엇을 고칠 수 있는지는 그 자원을 누가 들고 있느냐로 결정된다. 다음에 이 문제를 열 때도 그 질문부터 하면 된다.
