---
title: RunWay (31) v1.1 핫픽스
writer: Harold
date: 2026-07-21 10:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, watchOS]

toc: true
toc_sticky: true
published: true
---

심박 기반 러닝 모드를 만들다가 [이전글](https://haroldfromk.github.io/posts/RunningProject-(30)/){:target="_blank"}에서 `reset()`이 `modeAData`를 지우는 진짜 원인을 찾았다. 확인해보니 이 버그는 지금 작업 중인 브랜치에서 생긴 게 아니라 원래 배포된 버전(`v1.0`)에도 그대로 있는 문제였다. 지금 실제로 앱을 쓰고 있는 사람들한테는 Mission Flight GPWS가 페이스든 심박이든 계속 안 뜨고 있었다는 뜻이다.

이걸 심박 기능이랑 같이 묶어서 다음 업데이트 때 내보내는 건 맞지 않다고 봤다. 심박 기능은 아직 실제 기기로 끝까지 검증도 못 한 상태고, 급한 건 지금 배포판에 있는 버그를 최소한으로 고치는 거였다. 그래서 작업하던 브랜치는 그대로 두고, `v1.0` 태그에서 새 브랜치(`hotfix/v1.1`)를 파서 딱 필요한 것만 옮겼다.

---

## 또 다른 문제

옮기려고 보니 [이전글](https://haroldfromk.github.io/posts/RunningProject-(28)/){:target="_blank"}에서 다뤘던 워치 단독 러닝 문제도 같이 짚어야 했다. 그 글에서 `isReachable` 가드를 없애고 `pendingFlightData`를 큐로 바꾸는 수정을 적어놨었는데, 실제로 `v1.0` 코드를 열어보니 그 수정이 하나도 반영이 안 되어 있었다. 글만 쓰고 코드에는 안 옮긴 채로 넘어갔던 것 같다.

그래서 이번에 `hotfix/v1.1` 브랜치에서 그 수정을 처음으로 실제 코드에 넣었다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard let viewModel, !viewModel.pendingFlightQueue.isEmpty else { return }

    for flight in viewModel.pendingFlightQueue {
        // ... userInfo 구성은 기존과 동일, date만 flight.date로 수정
        session.transferUserInfo(userInfo)
    }
    viewModel.pendingFlightQueue.removeAll()
}
```

---

## GPWS 리셋 문제

`RunningCenter`의 `reset()`/`clearModeAData()` 분리도 심박 기능 없이 그대로 옮겼다. 이번 세션에서 새로 만든 `determineGPWSStatus` 같은 건 안 가져오고, 원래 있던 `calculateGPWSStatus` 구조는 그대로 둔 채 `modeAData`만 안 지워지게 손봤다.

```swift
func reset() {
    totalDistance = 0
    smoothingSpeedFirst = 0
    smoothingSpeedSecond = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    phase = .preflight
    isReachedPace = false
    // modeAData는 여기서 지우지 않는다
}

func clearModeAData() {
    modeAData = nil
}
```

`RunViewModel.resetState()`, `WatchViewModel.resetState()` 양쪽에 `clearModeAData()` 호출을 추가하고, `start()` 쪽은 그대로 뒀다.

이 `reset()`이 애초에 왜 `start()` 안에서 방어적으로 한 번 더 불리고 있었는지도 [이전글](https://haroldfromk.github.io/posts/RunningProject-(25)/){:target="_blank"}에 나와 있었다. 워치 미러링 화면 전환이 꼬이면 `resetState()`가 아예 안 불려서, 다음 러닝을 시작해도 `elapsedTime`/`flightData`가 이전 값에서 그대로 이어지는 문제가 있었다. 그걸 막으려고 화면 전환에만 의존하지 않게 `start()`에서도 한 번 더 리셋하도록 만든 거였다. 그때 리셋 대상은 `elapsedTime`/`flightData` 쪽이었지 `modeAData`는 아니었는데, 같은 `reset()` 함수 안에 같이 들어있다 보니 이번에 심박 GPWS를 만지면서 그 부작용이 드러난 거다.

토글로 직접 버그를 켜고 꺼보면서 페이스 구간별로 GPWS가 어떻게 나오는지 확인해볼 수 있게 만들어봤다.

<iframe
  src="/assets/demo/gpws_reset_bug_simulator.html"
  width="100%"
  height="830px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

---

## 편차 초 단위 계산 오류

실기기로 다시 테스트해보니 리셋 버그는 해결됐는데, sink rate 경고에 뜨는 "+18 sec" 같은 편차 표시가 이상했다. 페이스가 목표보다 살짝만 벗어나면 항상 "+0 sec"으로만 뜨고 있었다.

```swift
var gpwsDeviation: Int {
    guard let targetPace = viewModel.modeAData?.targetPace else { return 0 }
    return Int(abs(viewModel.flightData.pace - targetPace))
}
```

문제는 `pace`/`targetPace`가 분 단위 소수라는 거였다. 목표 페이스가 5.5(5분 30초)고 실제 페이스가 5.9면 차이는 0.4분, 초로 치면 24초인데 `Int()`로 먼저 잘라버리면 0.4가 0으로 뭉개진 다음에야 초로 계산되니 결과가 항상 0이었다. 1분 이상 벌어져야만 값이 찍히는 구조였는데, GPWS는 애초에 그렇게 크게 벗어나기 전에 미리 알려주려고 만든 기능이라 이 버그 때문에 편차 표시가 있으나 마나였다.

```swift
var gpwsDeviation: Int {
    guard let targetPace = viewModel.modeAData?.targetPace else { return 0 }
    return Int(abs(viewModel.flightData.pace - targetPace) * 60)
}
```

60을 곱하는 순서만 바꿔서 분 단위 차이를 먼저 초 단위로 바꾼 다음에 잘라내도록 고쳤다.

같이 보다가 GPWS 상태 텍스트 색상도 하나 발견했다. `WatchFlightPaceTab`에서 상태 텍스트가 무슨 상태든 항상 초록색으로 고정되어 있었다. sink rate면 빨간색, minimums면 노란색이 나와야 하는데 실제로는 안 바뀌고 있었다. `gpwsColor`라는 계산 프로퍼티를 만들어서 상태에 맞는 색을 리턴하게 하고, 그 값을 `WatchFlightPaceTab`까지 넘겨줬다.

---

## 경고 중엔 러닝 종료 안 됨

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchgpws.png){: width="50%" height="50%"}

여기까지 고치고 다시 실기기로 테스트해보니 새로운 문제가 나왔다. GPWS 상태 자체는 이제 제대로 뜨는데, sink rate나 minimums 경고가 화면을 덮는 동안에는 러닝을 끝낼 방법이 없었다.

원인은 `WatchGPWSView`를 열어보니 바로 보였다. 이 뷰는 배경을 화면 전체에 깔고 아이콘과 텍스트만 보여주는 순수 표시용 화면이라 탭이나 버튼이 하나도 없었다. 근데 이 뷰가 `WatchPFDView`의 ZStack 안에서 실제 계기판 위에 그대로 얹히는 구조라, 경고가 뜨는 동안엔 그 밑에 있는 END FLIGHT 버튼까지 같이 가려졌다. 바로 아래에 있는 `isPaused` 오버레이는 `.allowsHitTesting(false)`를 걸어서 터치가 그대로 통과하게 해뒀는데, GPWS 오버레이는 그런 처리가 없었다.

터치를 통과시키는 쪽으로 고칠 수도 있었지만, 그러면 경고 화면 뒤에 가려진 버튼을 눈에 안 보이는 채로 더듬어 눌러야 하는 구조가 된다. 그래서 END FLIGHT 버튼을 오버레이 화면에도 하나 더 넣는 쪽으로 갔다. `WatchFlightPaceTab` 안에 있던 2초 홀드 버튼 로직을 `EndFlightHoldButton`이라는 별도 뷰로 빼서, `WatchFlightPaceTab`과 `WatchGPWSView` 양쪽에서 같이 쓰게 만들었다.

```swift
if let gpwsType = gpwsOverlayType {
    WatchGPWSView(
        type: gpwsType,
        deviation: gpwsDeviation,
        onEndFlight: {
            didNavigateToTouchdown = true
            Task {
                await viewModel.saveRunningData()
                viewModel.updatePhase(.touchdown)
                await viewModel.stop()
                viewModel.navigateTo(.touchdown)
            }
        }
    )
    .transition(.opacity)
}
```

이제 경고가 뜬 상태에서도 그 화면 안에서 바로 END FLIGHT를 길게 눌러 러닝을 끝낼 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchrunninggpws.gif){: width="50%" height="50%"}

---

## MINIMUMS 거리 안 바뀜

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchminimus.png)

이 김에 워치 MINIMUMS 화면도 다시 봤다. 목표 거리 50m 전부터 뜨는 경고인데, 그 안에서 얼마나 더 가까워졌든 서브타이틀은 항상 "50 m"로 고정이었다.

```swift
var subtitle: String {
    switch self {
    ...
    case .minimums:  return "50 m"
    }
}
```

목표 거리(`targetDistance`)랑 지금까지 온 거리(`flightData.distance`)는 이미 다 갖고 있어서, 그 차이를 5m 단위로 내림해서 보여주는 쪽으로 바꿨다.

```swift
var gpwsRemainingMeters: Int {
    guard let targetDistance = viewModel.modeAData?.targetDistance else { return 0 }
    let remaining = targetDistance * 1000 - viewModel.flightData.distance
    return max(0, Int(remaining / 5) * 5)
}
```

`WatchGPWSView`에 이 값을 받는 `remainingMeters` 프로퍼티를 추가하고, minimums일 때만 이 값을 서브타이틀로 쓰게 분기했다. 이제 50 → 45 → 40처럼 목표 지점에 가까워질수록 숫자가 줄어드는 걸 볼 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchminimums.gif)

---

## STATUS 칸에 미션 여부 안 보임

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchpace.png){: width="50%" height="50%"}

워치 화면을 다시 보다가 하나 더 걸렸다. STATUS 칸이 어떤 러닝을 하든 항상 "PACE"라는 고정 텍스트만 보여주고 있었다. Free Flight인지, 목표 페이스를 설정한 Mission Flight인지 구분이 전혀 안 됐고, 목표 페이스가 몇인지도 워치 화면 어디서도 확인할 방법이 없었다.

새 영역을 하나 더 만들 수도 있었지만 화면이 이미 빡빡해서, 어차피 고정 텍스트만 뱉던 이 칸을 재활용하기로 했다. Free Flight면 "FREE", Mission Flight면 "PACE"와 목표 페이스를 3초마다 번갈아 보여주는 식으로.

```swift
private var statusText: String {
    guard isMissionMode else { return "FREE" }
    return showTargetPace ? targetPaceText : "PACE"
}
```

번갈아 보여주는 건 END FLIGHT 버튼 홀드에 쓰던 것과 같은 방식으로 `Timer`를 하나 돌려서 처리했다.

```swift
.onAppear {
    statusCycleTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
        showTargetPace.toggle()
    }
}
.onDisappear {
    statusCycleTimer?.invalidate()
    statusCycleTimer = nil
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchpacegpws.png){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchpacegpws1.png){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchfree.png){: width="50%" height="50%"}

---

## 아이폰 수신 쪽 유실 위험

여기까지 고치고 나서 워치 단독 러닝이 끝난 뒤 Logbook에 제대로 전달되는지만 다시 확인해보려고 했는데, 확인하다가 반대편에도 같은 종류의 문제가 있는 걸 찾았다.

`WatchConnectivityService+iOS.swift`의 `didReceiveUserInfo`가 `SwiftDataFlight`를 만들어서 `pendingWatchData`라는 단일 값에 넣고, `HomeView`의 `onChange`가 그걸 받아서 `modelContext.insert()`한 다음 비우는 구조였다.

```swift
// HomeView.swift
.onChange(of: runViewModel.pendingWatchData) { _, newValue in
    if let flight = newValue {
        if flight.distance >= 0.05 {
            modelContext.insert(flight)
        }
        runViewModel.pendingWatchData = nil
    }
}
```

문제는 워치 쪽을 큐로 고치면서 아이폰이 연결 안 된 사이 워치에서 러닝을 두 번 하고 나중에 연결되면, 두 기록이 짧은 간격을 두고 연달아 도착할 수 있게 됐다는 거다. 

아이폰이 두 번째 기록을 수신하는 순간 `pendingWatchData`를 덮어써버리면, `HomeView`가 첫 번째 기록을 미처 저장하기 전에 사라질 수 있다. 워치 쪽 큐 수정 전에는 애초에 두 건이 연달아 전송될 일 자체가 없었으니 드러나지 않았던 문제가, 이번에 고치면서 새로 노출된 셈이다.

워치 쪽과 똑같은 방식으로 고쳤다.

```swift
// RunViewModel.swift
var pendingWatchDataQueue: [SwiftDataFlight] = []

// WatchConnectivityService+iOS.swift
vm?.pendingWatchDataQueue.append(flight)

// HomeView.swift
.onChange(of: runViewModel.pendingWatchDataQueue) { _, newValue in
    guard !newValue.isEmpty else { return }
    for flight in newValue where flight.distance >= 0.05 {
        modelContext.insert(flight)
    }
    runViewModel.pendingWatchDataQueue.removeAll()
}
```

`didReceiveUserInfo`는 큐에 추가만 하고, `HomeView`가 그 시점의 큐 전체를 한 번에 순회해서 저장한 뒤 비운다. 두 기록이 거의 동시에 도착해도 어느 한쪽이 덮어써질 일이 없다.

---

## onChange가 놓치는 타이밍

이걸로 됐다고 생각했는데, 실기기로 워치 단독 마트 왕복 러닝을 두 번 기록해봤더니 또 문제가 있었다. 워치 앱은 계속 켜둔 채로, 정상적으로 END FLIGHT부터 RETURN TO BASE까지 매번 거쳤는데, 집에 와서 아이폰 앱을 켜보니 Logbook에 아무 기록도 없었다.

`.onChange(of: pendingWatchDataQueue)`가 왜 안 불렸는지 다시 짚어봤다.

```swift
.onChange(of: runViewModel.pendingWatchDataQueue) { _, newValue in
    guard !newValue.isEmpty else { return }
    for flight in newValue where flight.distance >= 0.05 {
        modelContext.insert(flight)
    }
    runViewModel.pendingWatchDataQueue.removeAll()
}
```

`WatchConnectivityService`는 `HomeView`가 뜨기 한참 전, 아이폰 앱이 켜지자마자 가장 먼저 만들어진다. `didReceiveUserInfo`도 이 시점에 바로 불릴 수 있다는 뜻이다.

문제는 `.onChange`가 동작하는 방식이었다. `.onChange`는 자기가 지켜보기 시작한 그 이후에 일어나는 변화만 감지한다. 택배가 이미 문 앞에 와 있는데 그제서야 나가서 문을 지켜보기 시작하면, "택배가 도착하는 순간" 자체를 못 보는 것과 같다.

워치를 계속 켜둔 채로 집에 와서 아이폰 앱을 콜드 런치하면 정확히 이 상황이 된다. `HomeView`가 뜨기도 전에 `pendingWatchDataQueue`엔 이미 워치가 보낸 기록이 들어가 있다. `.onChange`가 지켜보기 시작한 시점엔 이미 다 도착해 있는 상태니, 거기서부터는 "변화"라고 할 게 없어서 콜백 자체가 평생 안 불리는 거였다.

토글로 켜고 꺼보면서 타이밍이 어떻게 갈리는지 확인해볼 수 있게 만들어봤다.

<iframe
  src="/assets/demo/onchange_race_simulator.html"
  width="100%"
  height="680px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

`HomeView`의 `.onAppear`에서도 같은 걸 한 번 더 확인하도록 고쳤다.

```swift
.onChange(of: runViewModel.pendingWatchDataQueue) { _, newValue in
    drainPendingWatchData(newValue)
}
.onAppear {
    runViewModel.modelContext = modelContext
    drainPendingWatchData(runViewModel.pendingWatchDataQueue)
}

private func drainPendingWatchData(_ queue: [SwiftDataFlight]) {
    guard !queue.isEmpty else { return }
    for flight in queue where flight.distance >= 0.05 {
        modelContext.insert(flight)
    }
    runViewModel.pendingWatchDataQueue.removeAll()
}
```

`.onChange`가 문 앞을 지켜보는 역할이라면, `.onAppear`는 지켜보기 시작하기 전에 문 앞에 이미 뭐가 와 있는지 한 번 미리 확인하는 역할이다. 화면이 떠 있는 동안 도착하는 기록은 `.onChange`가, 화면이 뜨기 전에 이미 도착해있던 기록은 `.onAppear`가 나눠서 맡는 구조가 됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-21-RunningProject-31/sum1.png){: width="50%" height="50%"}

---

## 브랜치 정리

`reset()`/워치 단독 러닝 수정까지만 놓고 보면 `v1.0`에서 갈라진 `hotfix/v1.1` 브랜치엔 딱 5개 파일만 바뀌었다. 버전 번호(1.0 → 1.1, build 2)까지 포함해서다. 여기에 실기기 재테스트 과정에서 나온 편차 계산, 색상, 오버레이 수정으로 `WatchPFDView.swift`/`WatchGPWSView.swift`, 그리고 아이폰 수신 큐 수정으로 `RunViewModel.swift`/`WatchConnectivityService+iOS.swift`/`HomeView.swift`까지 붙었다. 심박 기능이 들어간 브랜치는 손대지 않고 그대로 남겨뒀고, 이 핫픽스는 완전히 별도로 진행한다.

---

## 배포 성공

업데이트 노트에 1.1에서 어떤 문제를 고쳤는지 적어서 제출했다. 영어/일본어는 AI 번역을 받았다. 그러고 나서 심사를 기다렸다.

In Review가 뜨고 나서 3시간 반쯤 지나서야 승인이 났다.

지금까지 중 가장 오래 걸린 심사였다. 그래도 1.0 때 이미 몇 번 리젝을 겪고 나서 승인받아본 적이 있어서, 이번에도 무난히 통과할 거라고는 생각하고 있었다.
