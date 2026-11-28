---
title: RunWay 러닝 시간이 두 배로 기록된 버그
writer: Harold
date: 2026-11-26 11:20:00 +0900
categories: [RunWay, SwiftUI]
tags: [SwiftUI, WatchConnectivity, Combine, SwiftData, watchOS]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

v1.4.1 을 쓰는 지인에게서 연락이 왔다. 러닝을 마치고 보니 평균 페이스가 갑자기 확 올라가 있었다고 한다. 지난달에도 두 번쯤 그랬다고 했다. 그리고 하나 더, 러닝이 끝나고 샤워하는 중에 워치가 스플릿을 읽었다고 했다.

캡처를 받아 보니 Flight Summary 의 TIME 이 01:26:30 이었다. 실제로 뛴 시간은 43분 남짓이다. 딱 두 배다.

이 글은 그 원인을 찾아간 과정과, 이미 틀리게 저장된 기록을 1.5 에서 고치는 방법이다. 바꾼 것은 두 가지다.

| 자리 | 한 일 |
|---|---|
| 원인 수정 | 워치 3곳, 아이폰 1곳. 러닝이 끝나도 남아 있던 GPS 와 구독을 끊고, 시간을 한쪽에서만 세게 했다 |
| 기록 복구 | 앱을 처음 켤 때 한 번, 그리고 iCloud 복원 직후에도 두 배로 저장된 기록을 찾아 시간과 페이스를 되돌린다 |

먼저 확인 수준을 적어 둔다. 원인은 코드로만 확인했고 실기기에서 재현하지는 않았다. 워치 쪽 수정도 실기기에서 아직 확인 못 했다. 복구는 판단 함수만 테스트했고, 실제로 저장된 기록에 돌려 본 적은 없다.

---

## 숫자 셋이 서로 다른 기록

같은 러닝인데 화면마다 시간이 달랐다.

| 화면 | 값 |
|---|---|
| Flight Summary TIME | 01:26:30 (5190초), 평균 페이스 11:10/km, 7.74km |
| Apple 건강 | 45분 15.56초 (8:40:55 ~ 9:26:10) |
| Flight Data Recorder | 마지막 시각 T+ 00:43:21 (약 2601초) |

[사진]

Flight Data Recorder(이하 FDR)는 러닝 중에 몇 초마다 찍어 둔 표본(시각, 거리, 페이스, 심박수 같은 값)을 시간 순서로 보여주는 화면이다. 그 표본과 스플릿은 멀쩡했다. 7km 째 스플릿이 5:33, 마지막 742m 가 5:44 였다. 거리도 7.74km 로 맞았다.

틀린 건 TIME 하나였고, 평균 페이스는 TIME 을 거리로 나눈 값이라 같이 틀렸다. 5190초를 7.74km 로 나누면 11:10/km 가 나온다. 지인이 본 "확 올라간 페이스"가 이것이다.

두 숫자를 나란히 놓으면 관계가 보인다.

```
5190 ≈ 2601 × 2 − 12
```

FDR 의 끝 시각을 두 배 하고 12초를 빼면 TIME 이 된다. 시간이 처음 12초쯤은 정상으로 흐르다가 그 뒤로는 1초에 2씩 흘렀다는 뜻이다. 12초가 어디서 왔는지는 뒤에 적는다.

Apple 건강의 45분은 운동 세션의 시작과 끝 시각 사이 간격이라 멈춰 있던 시간도 들어간다. FDR 의 경과 시간은 멈춘 시간을 뺀 값이라 둘은 기준이 다르다. 다만 1분 54초 차이가 전부 멈춘 시간인지는 따로 재 보지 않았다.

---

## 버린 가설들

처음부터 원인이 보인 건 아니다. 세 가지를 의심했다가 버렸다.

**스플릿이 두 개뿐이다.** 처음 받은 캡처에는 스플릿이 두 줄만 보였다. 기록이 중간에 끊긴 줄 알았는데, 스크롤하지 않은 화면이었다. 아래에 나머지가 다 있었다.

**오늘 워치에서도 러닝을 시작해서 둘이 겹쳤다.** 아이폰과 워치에서 따로 시작하면 타이머가 두 개 돌 수 있다. 그런데 지인은 아이폰으로 시작하고 아이폰으로 끝냈고 워치는 만지지 않았다고 했다. 그래서 버렸다.

**타이머를 다시 걸면 틱이 두 배가 된다.** RunWay 는 1초 타이머를 프로퍼티에 한 번 만들어 두고, 러닝을 시작할 때마다 `autoconnect().sink` 로 다시 구독한다. 같은 타이머에 구독을 두 번 걸면 1초에 두 번 불리지 않을까 싶었다. 0.2초 타이머를 같은 방식으로 2초 동안 돌리는 스크립트를 만들어 봤다. 두 배라면 20번이어야 하는데 10번이었다. 아니었다.

하나 더 확인한 것이 있다. 위치를 받는 `LocationService` 가 누가 시키지 않아도 스스로 `startTracking()` 을 부르는 경로가 있는지 찾았다. 없었다. 위치 추적은 항상 누군가 켜야 켜진다. 그렇다면 남은 질문은 "누가 켜 놓고 안 껐나"였다.

---

## 시간을 두 기기가 같이 세는 구조

원인을 따라가려면 RunWay 가 시간을 어떻게 세는지부터 알아야 한다.

---

### 미러링 세션이란?

RunWay 러닝은 아이폰에서도, 워치에서도 시작할 수 있다. 어느 쪽에서 시작하든 두 기기에 같은 러닝이 보인다.

아이폰에서 시작하면 아이폰이 워치에 운동 세션을 하나 열고, 워치 화면은 아이폰이 보내 주는 값을 따라 그린다. 이게 미러링 세션이다. 반대로 워치에서 시작하면 워치의 원래 세션이 주인이 되고, 아이폰이 워치 값을 따라 그린다.

코드에서는 이 구분을 `startOrigin` 이라는 값 하나로 한다. 각 기기에서 "이 러닝은 내가 시작했나"를 적어 둔 것이다.

| 값 | 뜻 |
|---|---|
| `.local` | 이 기기가 시작한 러닝이다. 시간과 위치를 이 기기가 센다 |
| `.remote` | 상대 기기가 시작한 러닝을 따라 보여준다 |
| `nil` | 러닝 중이 아니다 |

아이폰 주도 러닝이면 아이폰은 `.local`, 워치는 `.remote` 다. 워치 주도 러닝이면 반대다.

---

### 경과 시간을 주고받는 방식

TIME 은 1초 타이머가 1씩 더해 가는 값(`elapsedTime`)이다. 시작한 쪽 기기의 타이머가 1을 더하고, 더한 값을 상대에게 보낸다. 받은 쪽은 그 값으로 자기 화면을 덮어쓴다.

```swift
// RunWayWatch Watch App/Services/WatchConnectivityService+watchOS.swift
func sendElapsedTime(_ time: Int) {
    let message: [String: Any] = [
        "type": "elapsedTime",
        "elapsedTime": time
    ]
    session.sendMessage(message, replyHandler: nil)
}
```

#### sendMessage로 경과 시간 보내기

[`sendMessage(_:replyHandler:errorHandler:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage%28%5F%3Areplyhandler%3Aerrorhandler%3A%29){:target="_blank"}는 WatchConnectivity(워치와 아이폰이 데이터를 주고받는 틀)에서 지금 바로 상대에게 닿아야 하는 짧은 메시지를 보내는 방법이다. 첫 인자는 보낼 dictionary 다. 여기서는 `type` 으로 무슨 메시지인지 적고 `elapsedTime` 에 초를 담았다. `replyHandler` 를 nil 로 주면 답장을 기다리지 않는다. 워치에서 보내면 아이폰 앱을 백그라운드에서 깨워 받게 하지만, 아이폰에서 보낼 때는 워치 앱이 떠 있어야 닿는다. 답장을 기다리지 않고 1초마다 새 값을 보내는 이런 용도에 맞는다.

워치가 이 메시지를 받는 쪽은 이렇다. 아이폰 쪽도 v1.4.1 에서는 같은 모양이었다.

```swift
// RunWayWatch Watch App/Services/WatchConnectivityService+watchOS.swift
if let type = message["type"] as? String, type == "elapsedTime" {
    let elapsedTime = message["elapsedTime"] as? Int ?? 0
    Task { @MainActor in
        viewModel?.elapsedTime = elapsedTime
    }
    return
}
```

받은 값으로 조건 없이 덮어쓴다. 타이머가 한쪽에만 있으면 문제없다. 시작한 쪽이 10, 11, 12 를 보내고 상대는 그대로 받아 적는다.

그런데 두 기기에 타이머가 하나씩 돌면 이렇게 된다.

| 순간 | 아이폰 | 워치 |
|---|---|---|
| 아이폰 타이머 틱 | 10 → 11, 워치에 11 을 보냄 | 11 로 덮어씀 |
| 워치 타이머 틱 | 12 로 덮어씀 | 11 → 12, 아이폰에 12 를 보냄 |
| 아이폰 타이머 틱 | 12 → 13, 워치에 13 을 보냄 | 13 으로 덮어씀 |
| 워치 타이머 틱 | 14 로 덮어씀 | 13 → 14, 아이폰에 14 를 보냄 |

양쪽이 1초에 한 번씩 1을 더하는데, 서로 상대가 더한 값을 받아서 다시 더한다. 그래서 1초에 2씩 흐른다. 이게 두 배의 정체다.

그러면 이제 질문이 바뀐다. 지인은 아이폰으로 시작했으니 워치는 `.remote` 였고, 워치에 타이머가 있으면 안 된다. 워치 타이머는 어디서 생겼나.

---

## 워치에 남아 있던 것들

워치 타이머를 만드는 코드는 한 곳뿐이다. 워치가 러닝을 시작할 때 부르는 `startStream()` 안이다.

```swift
// RunWayWatch Watch App/ViewModels/WatchViewModel.swift (v1.4.1)
if HealthKitService.shared.startOrigin == .local  {
    Task {
        for await data in await runningCenter.streamFlightData() {
            self.flightData = data
            lastReceivedTime = .now
            if isPaused != data.isStationary {
                isPaused = data.isStationary
                watchConnectivityService.sendPauseData(isPaused)
            }
            if timerCancellable.isEmpty {
                timerPublisher
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self else { return }
                        if !isPaused {
                            elapsedTime += 1
                            watchConnectivityService.sendElapsedTime(elapsedTime)
                        }
                        // ...
                    }.store(in: &timerCancellable)
            }
        }
    }
}
```

#### Task와 AsyncStream으로 위치 계산 결과 구독하기

1. [`Task`](https://developer.apple.com/documentation/swift/task){:target="_blank"}는 지금 하던 일과 따로 도는 작업 하나를 만든다. 안의 코드는 기다릴 일이 있으면 기다렸다가 이어서 돈다
2. `streamFlightData()` 는 GPS 위치가 들어올 때마다 계산한 값(거리, 페이스, 멈췄는지)을 하나씩 흘려 주는 [`AsyncStream`](https://developer.apple.com/documentation/swift/asyncstream){:target="_blank"}을 돌려준다. `for await` 는 그 흐름에서 값이 올 때마다 한 바퀴씩 돈다. 값이 안 오면 그 자리에서 기다린다
3. 값이 처음 왔을 때 `timerCancellable` 이 비어 있으면 1초 타이머를 건다. [`Timer.publish(every:on:in:)`](https://developer.apple.com/documentation/foundation/timer/publish%28every%3Atolerance%3Aon%3Ain%3Aoptions%3A%29){:target="_blank"}는 정해진 간격마다 신호를 내는 Combine publisher 를 만들고, [`autoconnect()`](https://developer.apple.com/documentation/combine/connectablepublisher/autoconnect%28%29){:target="_blank"}는 누군가 구독하는 순간 타이머를 켠다
4. [`sink(receiveValue:)`](https://developer.apple.com/documentation/combine/publisher/sink%28receivevalue%3A%29){:target="_blank"}는 신호가 올 때마다 할 일을 건다. 여기서는 `elapsedTime` 에 1을 더하고 아이폰에 보낸다
5. [`store(in:)`](https://developer.apple.com/documentation/combine/anycancellable/store%28in%3A%29-6cr9i){:target="_blank"}는 그 구독을 `timerCancellable` 이라는 Set 에 넣어 둔다. Set 에서 빼면(`removeAll()`) 구독이 풀리고 타이머가 멈춘다. 그래서 `timerCancellable.isEmpty` 는 "지금 타이머가 안 돌고 있다"는 뜻으로 쓰인다

이 코드는 워치가 시작한 러닝(`.local`)일 때만 들어온다. 문제는 한 번 들어오고 나면 그 뒤로 `startOrigin` 을 다시 보지 않는다는 것이다.

---

### 취소되지 않는 Task란?

`Task { ... }` 로 만든 작업은 만든 쪽과 따로 산다. 만든 함수가 끝나도, 만든 화면이 사라져도 계속 돈다. 멈추게 하려면 만들 때 받은 손잡이로 `cancel()` 을 부르거나, 안에서 기다리는 흐름이 끝나야 한다.

AsyncStream 의 흐름이 끝나는 건 보내는 쪽이 [`finish()`](https://developer.apple.com/documentation/swift/asyncstream/continuation/finish%28%29){:target="_blank"}를 불렀을 때다. 그 전까지 `for await` 는 "다음 값이 언젠가 오겠지" 하고 영원히 기다린다.

수도꼭지에 빗대면 쉽다. `for await` 는 꼭지 아래에 받쳐 둔 양동이다. 물이 안 나오면 그냥 기다리고, 다시 나오면 다시 받는다. 양동이를 치우거나(`cancel()`) 수도를 잠가야(`finish()`) 끝난다.

위 코드는 둘 다 안 한다. Task 의 손잡이를 어디에도 적어 두지 않았고, `streamFlightData()` 의 흐름도 러닝이 끝날 때 `finish()` 하지 않는다. 그래서 워치에서 시작한 러닝이 한 번이라도 있었다면, 그때 만든 양동이가 그 뒤로도 계속 받쳐져 있다. 물(GPS 위치)만 다시 나오면 다시 돈다.

---

### 꺼지지 않은 GPS

물이 다시 나오는 경로도 있었다. 워치에서 시작한 러닝을 아이폰에서 끝낸 경우다.

워치의 러닝 종료 함수 `stop()` 은 GPS 를 이렇게 끈다.

```swift
// RunWayWatch Watch App/ViewModels/WatchViewModel.swift
func stop() async {
    if HealthKitService.shared.startOrigin == .local {
        locationService.stopTracking()
        altimeterService.stopTracking()
    }
    timerCancellable.removeAll()
}
```

그런데 아이폰이 끝낸 러닝은 워치에서 `finishWatchWorkout → saveRunningData → resetState` 순서로만 마무리되고, `stop()` 을 거치지 않는다. 그리고 v1.4.1 의 `resetState()` 에는 GPS 를 끄는 줄이 없었다. 타이머는 멈추지만 GPS 는 켜진 채로 남는다.

지인이 말한 "샤워 중에 워치가 스플릿을 읽었다"도 이것으로 설명된다. 러닝이 끝났는데 GPS 가 계속 위치를 받으니 거리가 쌓이고, 1km 가 차면 스플릿 안내가 나온다. 이건 코드로 이어 본 설명이고 실기기에서 본 건 아니다.

---

## 원인 사슬

지금까지를 이어 붙이면 이렇다.

1. 예전에 워치에서 시작해 아이폰으로 끝낸 러닝이 있었다. 워치는 `resetState()` 만 거쳐서 GPS 가 켜진 채 남았다
2. 그 러닝에서 만든 FlightData 구독 Task 도 취소되지 않고 남았다. 흐름도 `finish()` 되지 않아 계속 기다린다
3. 다음에 아이폰에서 러닝을 시작했다. 워치는 미러링 세션(`.remote`)으로 따라온다. 그런데 남아 있던 GPS 가 위치를 주니 남은 Task 가 다시 돈다. 타이머는 지난 러닝이 끝날 때 멈췄으니 `timerCancellable.isEmpty` 가 참이고, 워치에 타이머가 하나 생긴다
4. 이제 아이폰과 워치가 둘 다 1초에 1씩 더하고, 서로 받은 값으로 조건 없이 덮어쓴다. 1초에 2씩 흐른다

처음 12초가 정상이었던 건 3번의 순서 때문으로 보인다. 워치 타이머는 남아 있던 GPS 가 첫 위치를 준 뒤에야 생긴다. 그 지연이 12초였다는 추정이다.

FDR 과 스플릿이 멀쩡했던 이유도 여기서 나온다. 표본과 스플릿의 시각은 타이머가 아니라 GPS 시각으로 잰다.

```swift
// RunWay/Shared/Actor/RunningCenter.swift
private func movingElapsed(at timestamp: Date) -> Int {
    guard let runStartTime else { return 0 }
    return max(0, Int(timestamp.timeIntervalSince(runStartTime) - pausedDuration))
}
```

#### timeIntervalSince로 GPS 시각 기준 경과 시간 재기

[`timeIntervalSince(_:)`](https://developer.apple.com/documentation/foundation/date/timeintervalsince%28%5F%3A%29){:target="_blank"}는 두 시각 사이가 몇 초인지 [`TimeInterval`](https://developer.apple.com/documentation/foundation/timeinterval){:target="_blank"}(초 단위 Double)로 돌려준다. 여기서는 GPS 위치에 붙어 온 시각에서 러닝 시작 시각을 빼고, 멈춰 있던 시간(`pausedDuration`)을 다시 뺀다. 타이머가 몇 번 불렸는지와는 상관없이 실제 시계로 잰 값이다.

그래서 TIME 만 두 배가 되고, 표본으로 그리는 FDR 은 43:21 로 맞았다.

이 사슬에서 확인 안 된 고리가 하나 있다. 1번, "예전에 워치에서 시작해 아이폰으로 끝낸 러닝이 있었다"는 전제는 지인에게 아직 확인 못 했다. 그리고 이 사슬 전체를 실기기에서 재현해 보지는 않았다.

---

## 워치 3곳과 아이폰 1곳

고친 자리는 네 곳이다. 원인 쪽(워치)을 막고, 그래도 워치에 타이머가 생겼을 때를 대비해 아이폰도 막았다.

---

### 워치: 러닝이 끝나면 GPS 끄기

`resetState()` 에서 `stopTracking()` 을 부른다. 아이폰이 끝낸 경로도 결국 여기를 지나니, 어느 쪽에서 끝내든 GPS 가 꺼진다.

```swift
// RunWayWatch Watch App/ViewModels/WatchViewModel.swift
func resetState() async {
    watchConnectivityService.sendRunningData()
    timerCancellable.removeAll()
    // stop() 은 startOrigin 이 .local 일 때만 GPS 를 끄고, 아이폰이 끝낸 경로는 stop() 을
    // 아예 안 거친다. 여기서 안 끄면 GPS 가 켜진 채 남아 러닝이 끝난 뒤에도 거리가 쌓인다.
    stopTracking()
    isRunning = false
    // ...
}
```

---

### 워치: 남은 Task 가 미러링 세션에서 돌지 않게 하기

Task 를 제대로 끝내려면 손잡이를 저장해 두고 러닝이 끝날 때마다 취소하거나, 흐름을 `finish()` 하도록 바꿔야 한다. 이번에는 그렇게 하지 않고 한 줄로 막았다. 워치에는 테스트 타깃이 없어 자동 테스트를 붙일 수 없고 실기기에서도 아직 확인 못 했다. 그런 상태에서 구독 구조까지 바꾸면 틀렸을 때 알 길이 없어서 줄 수가 적은 쪽을 골랐다. 값이 와도 지금 러닝이 워치가 시작한 것이 아니면 건너뛴다.

```swift
// RunWayWatch Watch App/ViewModels/WatchViewModel.swift
for await data in await runningCenter.streamFlightData() {
    // 이 Task 는 러닝이 끝나도 살아 있다. 아이폰이 시작한 다음 러닝에서
    // 여기가 돌면 워치에 타이머가 하나 더 생겨 시간이 두 배로 흐른다.
    guard HealthKitService.shared.startOrigin == .local else { continue }
    self.flightData = data
    // ...
}
```

`continue` 는 이번 값은 버리고 다음 값을 기다린다는 뜻이다. Task 는 여전히 살아 있지만, 미러링 세션에서는 타이머까지 가지 못한다.

---

### 워치: 미러링 세션이 시작될 때 비우기

아이폰이 시작한 러닝이 워치에 들어오는 순간(`.running` 상태, `startOrigin == .remote`)에는 이미 지난 러닝의 거리와 페이스를 비우고 있었다. 거기에 두 줄을 더했다. 혹시 남아 있는 워치 타이머를 멈추고 GPS 를 끈다.

```swift
// RunWayWatch Watch App/ViewModels/WatchViewModel.swift
if result.state == .running {
    if result.startOrigin == .remote {
        self.flightData = FlightData()
        self.elapsedTime = 0
        self.isPaused = false
        self.lastSplitKm = nil
        // 미러링에서 시간과 위치는 아이폰 것만 쓴다. 워치 것이 남아 돌면 안 된다.
        self.timerCancellable.removeAll()
        self.stopTracking()
        // ...
    }
}
```

미러링 세션에서 시간과 위치는 아이폰 것만 쓴다. 그러니 워치에서 이 둘이 돌고 있을 이유가 없다.

---

### 아이폰: 내가 시작한 러닝이면 워치 시간 무시하기

워치 쪽 세 곳이 다 맞게 고쳐졌다면 이건 필요 없다. 그래도 넣었다. 워치는 실기기에서 아직 확인 못 했고, 다른 경로로 워치 타이머가 또 생길 수도 있다. 그때도 시간이 두 배가 되지 않게, 아이폰이 시작한 러닝에서는 워치가 보낸 경과 시간을 받지 않는다.

```swift
// RunWay/Services/WatchConnectivityService+iOS.swift
nonisolated static func shouldAcceptWatchElapsedTime(startOrigin: StartOrigin?) -> Bool {
    startOrigin != .local
}

// ...

if let type = message["type"] as? String, type == "elapsedTime" {
    let elapsedTime = message["elapsedTime"] as? Int ?? 0
    Task { @MainActor in
        guard Self.shouldAcceptWatchElapsedTime(startOrigin: HealthKitService.shared.startOrigin) else { return }
        vm?.elapsedTime = elapsedTime
    }
    return
}
```

판단을 함수 하나로 뺀 건 테스트하려고다. `.local` 이면 버리고, `nil` 이나 `.remote` 면 받는다. `nil` 은 워치 단독 러닝을 아이폰이 따라 보여주는 경우인데, 그때 아이폰에는 세션이 없어 값이 비어 있다. 이 둘을 테스트로 묶어 뒀다.

시간 기준을 아예 GPS 이동 시간으로 바꾸는 방법도 생각했다. 그러면 타이머가 몇 개든 상관없어진다. 하지만 그건 TIME 이라는 기록의 뜻을 바꾸는 일이라 이번 수정에는 넣지 않았다.

고친 뒤라면 이 기록의 TIME 은 약 00:43:21, 평균 페이스는 약 5:36/km 이 된다(2601초 ÷ 60 ÷ 7.74km).

---

## 이미 틀리게 저장된 기록 되돌리기

원인을 고쳐도 지인의 기기에는 이미 두 배로 저장된 기록이 남아 있다. 지인 말로는 지난달에도 두 번쯤 그랬다. 지인만의 일도 아니다. 1.4.1 을 쓰면서 워치에서 시작해 아이폰으로 끝낸 적이 있고, 그 뒤 워치 앱이 꺼지지 않은 채 아이폰에서 새 러닝을 시작했다면 누구에게나 날 수 있다.

그래서 1.5 에 1회 자동 복구를 넣었다. 앱이 저장된 기록을 훑어 두 배로 저장된 것을 찾고, 시간과 페이스를 되돌린다.

처음에는 다른 길도 생각했다. 지인의 아이폰을 케이블로 Mac 에 연결해 개발 빌드를 깔고 고치는 것이다. 하지만 Mac 에서 앱의 DB 를 직접 열 수는 없어서 어차피 같은 복구 코드가 필요하다. 1.4.1 태그로 빌드를 따로 만들어야 하고, 덮어 설치가 거부되기라도 하면 기록 50건을 잃는다. 실제로 거부되는지는 확인 안 했다. 이 방법은 버렸다.

---

### 무엇을 기준으로 고치나

기준은 FDR 의 끝 시각, 즉 마지막 표본의 경과 시간이다. 앞에서 본 대로 표본은 `movingElapsed` 로 GPS 시각을 재서 타이머와 따로 논다. 타이머가 두 배로 흘러도 표본은 멀쩡했다.

그러면 "TIME 이 마지막 표본과 다르면 고친다"로 충분할 것 같지만 그렇지 않다. 정상 기록도 TIME 이 몇 초 길다. 타이머는 러닝 시작과 함께 돌고, 표본은 GPS 첫 위치가 온 뒤에야 찍히기 시작한다. 그리고 표본은 5초 간격이라 마지막 표본이 러닝 끝보다 최대 5초쯤 앞선다.

그래서 배율로 본다.

```swift
// RunWay/Services/FlightTimeRepair.swift
static func repairedTime(storedTime: Int, lastSampleElapsed: Int?) -> Int? {
    guard let lastSampleElapsed, lastSampleElapsed >= 60 else { return nil }
    let ratio = Double(storedTime) / Double(lastSampleElapsed)
    guard ratio >= 1.8, ratio <= 2.2 else { return nil }
    return lastSampleElapsed
}
```

조건은 셋이다.

| 조건 | 이유 |
|---|---|
| 표본이 있어야 한다 | v1.4 이전 기록은 표본이 없어서 기준으로 삼을 값이 없다 |
| 마지막 표본이 60초 이상 | 아주 짧은 러닝은 정상이어도 배율이 크게 나온다. 9초 뛰고 표본이 5초에 하나 찍혔으면 정상인데 1.8배다 |
| 배율이 1.8 이상 2.2 이하 | 두 배 버그로 생긴 배율이 나올 수 있는 범위다 |

배율의 범위는 이렇게 정했다. 워치 타이머는 조금 늦게 생기니 배율은 2 바로 아래로 나온다. 지인 기록이 5190 ÷ 2601 = 1.995 다. 반대로 표본이 5초 간격이라 마지막 표본이 일찍 끊기면 배율이 2 를 조금 넘을 수 있다. 위로는 2.2 근처가 끝이다. 이보다 크게 벌어진 기록은 다른 사정이 있는 것이라 손대지 않는다.

고친 시간은 마지막 표본의 경과 시간이다. 페이스는 저장할 때와 같은 식(시간 ÷ 60 ÷ 거리)으로 다시 계산한다.

여기서 분명히 적어 둘 것이 있다. **1.8, 2.2, 60초는 기록 한 건에만 맞춰 본 값이다.** 지인 기록 하나가 이 범위 안에 들어오고, 정상 기록이 들어오지 않는 것을 테스트로 확인했을 뿐이다. 다른 사람의 두 배 기록이 이 범위에 다 들어오는지는 모른다.

---

### 못 잡는 기록

러닝 도중에 워치 타이머가 생긴 기록은 못 잡는다. 앞의 사슬에서 워치 타이머는 GPS 첫 위치가 오면 생기니 보통은 시작 직후다. 그런데 어떤 이유로 러닝 중간에 생겼다면 그때부터만 두 배가 된다. 그러면 배율이 1.8 보다 작게 나와서 이 조건을 통과하지 못한다.

이런 기록을 잡으려고 범위를 아래로 넓히면 정상 기록까지 건드릴 위험이 커진다. 그래서 두 배로 저장된 것이 분명한 기록만 고치기로 했다.

---

### 언제 도는가

앱 시작 때 한 번 돈다.

```swift
// RunWay/Services/FlightTimeRepair.swift
@discardableResult
static func repair(in modelContext: ModelContext) -> Int {
    guard let flights = try? modelContext.fetch(FetchDescriptor<SwiftDataFlight>()) else { return 0 }
    var repairedCount = 0
    for flight in flights {
        let lastSampleElapsed = flight.samples.map(\.elapsedTime).max()
        guard let time = repairedTime(storedTime: flight.time, lastSampleElapsed: lastSampleElapsed) else { continue }
        flight.time = time
        flight.pace = pace(time: time, distance: flight.distance)
        repairedCount += 1
    }
    if repairedCount > 0 {
        try? modelContext.save()
    }
    return repairedCount
}

static func repairOnce(in modelContext: ModelContext) {
    guard !UserDefaults.standard.bool(forKey: didRunKey) else { return }
    repair(in: modelContext)
    UserDefaults.standard.set(true, forKey: didRunKey)
}
```

#### ModelContext와 UserDefaults로 저장된 기록 한 번 고치기

1. [`FetchDescriptor`](https://developer.apple.com/documentation/swiftdata/fetchdescriptor){:target="_blank"}는 SwiftData(앱의 기록을 저장하는 Apple 의 DB 틀)에서 무엇을 가져올지 적는 요청서다. 조건 없이 `SwiftDataFlight` 만 적어서 러닝 기록 전부를 가져온다
2. [`fetch(_:)`](https://developer.apple.com/documentation/swiftdata/modelcontext/fetch%28%5F%3A%29){:target="_blank"}는 그 요청서로 기록을 꺼낸다. [`ModelContext`](https://developer.apple.com/documentation/swiftdata/modelcontext){:target="_blank"}는 꺼낸 기록을 들고 있다가 바뀐 것을 모아 저장하는 작업대다
3. 기록마다 표본 중 가장 큰 경과 시간을 구해 `repairedTime` 에 묻는다. nil 이면 건너뛰고, 값이 오면 `time` 과 `pace` 를 바꾼다
4. 하나라도 바꿨으면 [`save()`](https://developer.apple.com/documentation/swiftdata/modelcontext/save%28%29){:target="_blank"}로 DB 에 쓴다
5. `repairOnce` 는 [`UserDefaults`](https://developer.apple.com/documentation/foundation/userdefaults){:target="_blank"}(기기에 작게 저장하는 칸)에 `didRepairDoubledFlightTime` 을 적어 두고, 이미 적혀 있으면 돌지 않는다. [`bool(forKey:)`](https://developer.apple.com/documentation/foundation/userdefaults/bool%28forkey%3A%29){:target="_blank"}는 그 칸에 아무것도 없으면 `false` 를 준다

한 번 고친 기록은 배율이 1 근처가 되니 다시 돌아도 걸리지 않는다.

예외가 하나 있다. iCloud 에서 복원한 직후에는 매번 돈다. 두 배로 저장된 기록이 고치기 전 모습으로 이미 백업에 올라가 있을 수 있기 때문이다. 복원하면 그 틀린 기록이 다시 들어온다.

```swift
// RunWay/Views/Settings/DataBackupView.swift
let count = try await CloudBackupService.restore(into: modelContext, existingIDs: existingIDs)
// 백업에는 시간이 두 배로 저장된 기록이 고치기 전 모습으로 올라가 있을 수 있다.
FlightTimeRepair.repair(in: modelContext)
```

---

### 판단 함수의 테스트

판단은 `repairedTime` 과 `pace` 두 함수에 모았다. DB 를 건드리지 않고 숫자만 받아서 숫자를 돌려주니 테스트하기 쉽다. 테스트는 7개다.

| 테스트 | 넣은 값 | 기대 |
|---|---|---|
| 두 배 기록은 고친다 | 5190초, 표본 2601초 | 2601 |
| 정상 기록은 그대로 | 2610초 / 2601초, 2601초 / 2601초 | nil |
| 배율 경계 | 1799 / 1000, 1800 / 1000, 2200 / 1000, 2201 / 1000 | nil, 1000, 1000, nil |
| 표본이 없으면 그대로 | 5190초, 표본 없음 | nil |
| 표본 1분 미만은 그대로 | 9 / 5, 118 / 59, 120 / 60 | nil, nil, 60 |
| 페이스 다시 계산 | 2601초, 7.74km | 약 5.6008 |
| 거리 0 | 2601초, 0km | 0 |

아이폰 쪽 `shouldAcceptWatchElapsedTime` 테스트 2개를 포함해 iOS 단위 테스트 57개가 통과했다. 워치는 시뮬레이터 빌드까지 성공했다.

`repair(in:)` 처럼 실제 DB 를 훑는 쪽은 테스트하지 않았다. 지인의 기록처럼 실제로 저장된 기록에 돌려 본 적도 없다.

---

## 아직 확인 못 한 것

코드와 테스트로 본 것까지다. 나머지는 실기기와 지인의 기록이 있어야 한다.

- 원인 사슬의 전제. 지인이 예전에 워치에서 시작해 아이폰으로 끝낸 러닝이 있었는지 아직 확인 못 했다
- 원인 사슬 자체. 워치에서 시작해 아이폰으로 끝내고, 이어서 아이폰으로 새 러닝을 시작했을 때 TIME 이 두 배로 흐르는지 실기기에서 재현하지 않았다
- 워치 수정 세 곳이 실기기에서 맞게 도는지. 특히 러닝이 끝난 뒤 GPS 가 실제로 꺼지는지
- 12초가 정말 워치 GPS 첫 위치까지의 지연인지. 지금은 추정이다
- 복구가 실제로 저장된 기록에서 맞게 도는지. 지인이 말한 지난달 두 건이 같은 버그인지, 1.8 ~ 2.2 안에 드는지 아직 모른다
- 1.8, 2.2, 60초가 다른 사람의 기록에도 맞는지. 기록 한 건에만 맞춰 본 값이다
- 남아 있는 Task 자체. 이번에는 한 줄로 막았을 뿐, 러닝이 끝나도 Task 가 살아 있는 구조는 그대로다

---

## 참고자료

- [Transferring data with Watch Connectivity (Apple)](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity){:target="_blank"}
