---
title: RunWay 1.4.1 몇 초 만에 끝나버린 워치 러닝
writer: Harold
date: 2026-11-16 21:30:00 +0900
categories: [RunWay, SwiftUI]
tags: [SwiftUI, WatchConnectivity, HealthKit, OSLog, watchOS]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

지인이 러닝 중에 워치 앱이 꺼진다고 알려 왔다. 지인은 1.4.1 을 쓰고 있고, 내 기기에서는 같은 일이 재현되지 않았다.

지인은 앱이 꺼진 걸 바로 알아채지 못했다. 계속 뛰다가 워치가 진동해서 보니 건강 앱이 "야외 운동 중이세요?"라고 묻는 알림이었다. 처음에는 그 알림이 러닝 화면을 덮어서 앱이 꺼졌다고 생각했다. 그런데 **순서가 거꾸로였다.** RunWay 의 운동 세션이 먼저 없어졌고, 그래서 시스템이 "운동 중인 것 같은데 기록할까요?"라고 물은 것이다. 알림은 원인이 아니라 결과다.

이 글은 원인을 좁혀 간 과정을 적는다. 범인은 아직 하나로 정하지 못했고, 코드는 한 줄도 고치지 않았다.

---

## 건강 앱에 남은 일곱 건

지인의 건강 앱에서 RunWay 가 남긴 기록 7건을 받아 왔다. 기록마다 지속 시간, 시작과 종료 시각, 건강에 추가된 시각, 기기 정보를 적었다.

| # | 기기 | 날짜 | 지속 | 시작 → 종료 | 건강에 추가 | 관련 샘플 | 워크아웃 이벤트 |
|---|---|---|---|---|---|---|---|
| 1 | 아이폰 iPhone15,2 / iOS 26.6.1 | 9/4 | 1.17초 | 20:08:19 → 20:08:21 | 20:08:32 | 0.03 kcal, 4.2 KPH, 10걸음, 1.5 m | 00:00:00 동작 재개 |
| 2 | 아이폰 iPhone15,2 / 26.6.2 | 9/20 | 0.64초 | 08:20:21 → 08:20:21 | 08:20:33 | 4.4 KPH, 17걸음, 0.8 m | 00:00:00 동작 재개 |
| 3 | 아이폰 iPhone15,2 / 26.6.2 | 9/22 | 0.92초 | 08:23:01 → 08:23:02 | 08:23:10 | 4.3 KPH, 13걸음, 1.1 m | 00:00:00 동작 재개 |
| 4 | 애플워치 Watch6,7 / watchOS 26.2 | 9/27 | 9.15초 | 22:04:10 → 22:04:19 | 22:04:46 | 0.12 kcal, 49 BPM | 00:00:00 동작 재개, 00:00:05 동작 일시정지 |
| 5 | 애플워치 Watch6,7 / 26.2 | 9/27 | 16.32초 | 22:04:46 → 22:05:02 | 22:13:26 | 0.17 kcal, 46 BPM | 00:00:00 동작 재개, 00:00:06 동작 일시정지 |
| 6 | 애플워치 Watch6,7 / 26.2 | 10/26 | 4.73초 | 20:55:20 → 20:55:25 | 20:55:25 | (안 나옴) | 00:00:00 동작 재개 |
| 7 | 애플워치 Watch6,7 / 26.2 | 11/7 | 4.29초 | 19:41:12 → 19:41:16 | 19:41:16 | (안 나옴) | 00:00:00 동작 재개 |

7건 전부 건강 앱의 "실내 운동" 항목이 "아니요"였다. 제보는 "다 워치에서 꺼졌다"였지만 표를 보면 7건 중 3건은 아이폰 기록이다.

---

### 모델 식별자란?

모델 식별자는 건강 앱 기록의 "기기" 세부 항목에 찍히는 `iPhone15,2`, `Watch6,7` 같은 값이다. 판매 이름이 아니라 애플이 하드웨어마다 붙이는 내부 이름이다. 자동차로 치면 "소나타"가 판매 이름이고 차대번호 앞자리의 형식 코드가 모델 식별자다. 같은 아이폰 14 Pro 계열이라도 Pro 는 `iPhone15,2`, Pro Max 는 `iPhone15,3` 으로 갈린다.

지인의 기기는 `iPhone15,2` 가 아이폰 14 Pro, `Watch6,7` 이 애플워치 시리즈 7 45mm GPS 모델이다. 4건의 워치 기록이 전부 같은 기기에서 나왔다는 것을 이 값으로 알 수 있다.

---

### 워크아웃 이벤트란?

기록의 "워크아웃 이벤트" 줄에 보이는 "동작 재개", "동작 일시정지"가 워크아웃 이벤트다. 운동 중에 일어난 일을 시각과 함께 적어 두는 메모라고 보면 된다.

**RunWay 가 적은 것이 아니다.** RunWay 는 운동 세션을 직접 일시정지한 적이 없다. `session.pause()` 를 부르는 곳도, `isAutoPauseEnabled` 도 코드에 없다. 앱의 정지 버튼은 화면에 보이는 시간만 멈춘다. 코드에서 운동 설정을 만들 때 쓰는 [`HKWorkoutConfiguration`](https://developer.apple.com/documentation/healthkit/hkworkoutconfiguration){:target="_blank"}도 달리기와 야외 두 값뿐이다. 그러니 이 이벤트는 시스템이 적은 것이다.

그래서 4번과 5번의 "00:00:05 동작 일시정지"는 앱이 멈췄다는 뜻이 아니라 **지인이 멈춰 서 있었다**는 뜻으로 읽힌다.

---

## 기록에서 읽어낸 것

7건을 지속 시간, 저장 시각, 기기별로 나눠 보았다. 아이폰 기록이 남은 이유까지 따라가면 용의자의 모양이 조금씩 드러난다.

---

### 짧게는 1초, 길게는 16초

지속 시간은 0.64초에서 16.32초 사이였다. 가장 긴 것이 16.32초다.

4번과 5번의 평균 심박은 49, 46 BPM(1분에 몇 번 뛰는지)이고 소모 열량은 0.12, 0.17 kcal 다. 뛰는 사람의 값이 아니라 가만히 서 있는 사람의 값이다. 시작 버튼을 누르고 출발하기도 전에 끝난 것으로 보인다.

![7건의 지속 시간을 가로 막대로 그린 그림. 아이폰 기록 3건은 1.17초, 0.64초, 0.92초로 아주 짧고, 워치 기록 4건은 9.15초, 16.32초, 4.73초, 4.29초이며 전부 20초 눈금 안에서 끝난다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-16-RunningProject-59/runway-watch-short-duration.png)

---

### 저장 시각으로 읽는 9월 27일

같은 날 22시대에 워치 기록이 둘 있다. 4번이 건강에 추가된 시각이 22:04:46 이고, 5번의 시작 시각도 정확히 22:04:46 이다. 4번은 22:04:19 에 끝나고 27초 뒤에 저장됐는데, 저장되자마자 다시 시작한 것이다.

5번은 22:05:02 에 끝났는데 건강에 추가된 시각은 22:13:26 이다. 끝나고 저장되기까지 8분 24초가 밀렸다.

이 밀림은 [55번 글](https://haroldfromk.github.io/posts/RunningProject-(55)/)의 "심박 회복이 붙잡고 있던 세션"에서 이미 본 현상이다. 워치OS 가 심박이 얼마나 빨리 내려오는지 재려고 끝난 세션을 몇 분 붙잡고 있는 것이다.

![9월 27일 두 기록의 시간선. 4번은 22:04:10 에서 22:04:19 까지이고 27초 뒤인 22:04:46 에 저장된다. 5번은 22:04:46 에 시작해 22:05:02 에 끝나고, 8분 24초 뒤인 22:13:26 에 저장된다. 4번의 저장 시각과 5번의 시작 시각이 같다. 22:05:10 부터 22:13:00 까지는 생략했다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-16-RunningProject-59/runway-watch-short-sept27-r2.png)

---

### 아이폰 기록이 남았다는 것

v1.4.1 에서 아이폰에서 러닝을 시작하면 먼저 워치 앱을 깨우는 요청을 보낸다. 요청이 에러 없이 돌아오면 아이폰은 곧바로 미러링 모드(`.mirrored`)로 바꾼다. 워치가 실제로 시작됐는지는 확인하지 않는다. 그리고 `.mirrored` 인 채로 끝나면 아이폰은 자기 쪽 기록을 버린다. 같은 러닝이 건강 앱에 두 번 남지 않게 하려는 것이다. 아이폰은 자기 세션을 직접 돌리고, 워치가 만든 세션을 받아 오는 코드는 10월 2일에 지웠다.

```swift
if toState == .stopped {
    // 미러링 중이면 Apple Health 저장은 Watch의 builder가 한다. iPhone의 builder를
    // 그대로 두면 시스템이 이것까지 마감해 저장해서, 같은 러닝이 건강 앱에 두 번 남는다.
    if runningMode == .mirrored {
        builder?.discardWorkout()
    }
    session?.end()
    // 생략
}
```

이 코드는 `RunWay/Services/HealthKitService+iOS.swift` 의 `handleiOSStateChange` 중 세션이 멈췄을 때의 부분이다(v1.4.1).

#### discardWorkout으로 아이폰 기록 버리기

[`discardWorkout()`](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/discardworkout%28%29){:target="_blank"}은 [`HKWorkoutBuilder`](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder){:target="_blank"}가 모아 둔 데이터를 건강 앱에 저장하지 않고 버린다. `HKWorkoutBuilder` 는 운동 중의 심박과 거리를 모아 두었다가 건강 앱에 기록으로 저장하는 도구다. 여기서는 미러링 모드일 때만 불러서, 저장은 워치 쪽 한 곳만 하게 했다.

바로 아래 줄의 [`end()`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/end%28%29){:target="_blank"}는 운동 세션 자체를 끝낸다. 버리는 일과 끝내는 일은 따로라서 둘 다 불러야 한다.

그래서 **아이폰 기록이 건강 앱에 남았다는 것만으로는 아무것도 알 수 없다.** 이 버리기는 1.3.2 (2026-09-06 커밋)에서 들어왔고 1.3.1 에는 없다. 9월 기록은 1.3.1 시기라, 버리는 코드가 없어서 남았을 수 있다.

단서가 되는 것은 같은 날 워치 기록이 없다는 점이다. 7건 중에는 같은 날 아이폰 기록과 워치 기록이 함께 있는 날이 없다. 아이폰이 워치를 깨우는 요청만 보내고 워치는 실제로 시작되지 않았을 가능성을 떠올리게 하지만, 아직 확인하지 못했다.

---

## 아니었던 것들

처음 의심한 것들을 코드와 기록으로 하나씩 지웠다.

| 가설 | 왜 아니었나 |
|---|---|
| 1km 지점 크래시 | 7건 전부 1km 근처에도 못 갔다. 가장 멀리 간 것이 1.5 m 다. 구간 진동과 음성도 0으로 나누는 계산을 `isFinite` 검사로 막아 두었다 |
| 건강 앱 알림이 러닝 화면을 덮음 | 순서가 거꾸로다. 세션이 먼저 없어졌고 알림은 그 뒤에 왔다 |
| 미러링 단계를 건너뜀 | 미러링을 건너뛰어도 세션은 이미 시작된 뒤라 그대로 돈다. `startActivity` 와 `beginCollection` 이 미러링 코드보다 먼저 돈다 |
| 세션 없이 러닝 화면이 뜸 | 건강 앱에 기록이 남았다는 것 자체가 세션이 시작됐다는 뜻이다. `WatchTakeoffView` 는 세션 상태와 상관없이 PFD 로 넘어가므로 화면이 떴다는 것만으로는 세션을 알 수 없다 |
| 앱이 세션을 일시정지함 | `session.pause()` 호출도 `isAutoPauseEnabled` 도 없다. 앱의 정지 버튼은 화면의 시간만 멈추니, 기록의 일시정지는 시스템이 적은 것이다 |
| 백그라운드 모드 누락 | `WKBackgroundModes` 에 `workout-processing`, `UIBackgroundModes` 에 `location`, `audio` 가 다 들어 있다 |
| 15초 무응답 타이머 | `WatchViewModel.start()` 에 아이폰 데이터가 15초 동안 없으면 "멈춤"으로 표시하는 타이머가 있어 숫자가 겹쳐 의심했다. 표시만 바꾸고 세션은 끝내지 않는다 |

---

## 첫째 용의자, 사라지는 화면

워치의 러닝 화면 `WatchPFDView` 는 화면이 사라질 때 러닝을 정리하도록 되어 있다. 사용자가 러닝 도중 뒤로 나가면 남은 세션이 계속 돌지 않게 하려는 장치다.

```swift
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

이 코드는 `RunWayWatch Watch App/Views/WatchPFDView.swift` 의 233줄에서 241줄이다(v1.4.1).

#### onDisappear로 화면이 사라질 때 정리하기

1. [`onDisappear(perform:)`](https://developer.apple.com/documentation/swiftui/view/ondisappear%28perform%3A%29){:target="_blank"}은 이 뷰가 화면에서 빠질 때 안의 코드를 한 번 실행한다.
2. 첫 `guard` 는 착륙 화면으로 정상적으로 넘어가는 중이면 아무것도 하지 않고 빠진다.
3. 둘째 `guard` 는 `HealthKitService.shared.session` 이 있는지 본다. 세션이 **있으면** 정리를 이어 가고, 없으면 빠진다.
4. `Task` 안에서 러닝 계산을 멈추고(`viewModel.stop()`), 운동 세션을 끝내고(`stopWorkout()`), 화면 상태를 처음으로 돌린다(`resetState()`).

둘째 `guard` 가 첫째 용의자의 핵심이다. 세션이 있다는 것만 보고 정리한다.

---

### onDisappear란?

`onDisappear` 는 "이 뷰가 화면에서 빠졌다"만 알려 준다. 문 앞에 달아 둔 종 같은 것이다. 손님이 나가도 종이 울리고, 다른 사람이 들어와 가려도 종이 울린다. 종소리만으로는 어느 쪽인지 알 수 없다.

사용자가 크라운으로 나간 것인지, 다른 화면이 위를 덮은 것인지, 화면이 꺼진 것인지를 `onDisappear` 는 구분하지 못한다. 이 글에서 의심하는 것은 마지막 경우다. 다만 **워치 화면이 꺼질 때 운동 중인 앱의 `onDisappear` 가 실제로 불리는지는 아직 확인하지 못했다.**

`onDisappear` 가 불릴 때와 안 불릴 때는 [49번 글](https://haroldfromk.github.io/posts/RunningProject-(49)/)의 "워치에서 끝냈는데 안 돌아오는 PFD"에서 여러 번 다뤘다.

![onDisappear 가 구분하지 못하는 경우를 그린 그림. 크라운으로 나감, 다른 화면이 덮음, 화면이 꺼짐 세 상자가 모두 onDisappear 하나로 모이고, 그 뒤에 세션이 있으면 러닝을 끝낸다. 앞의 둘은 실선이고 화면이 꺼짐만 확인하지 못한 경우로 점선으로 그렸다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-16-RunningProject-59/runway-watch-short-ondisappear-r2.png)

---

### 이미 한 번 잡았던 함정

착륙 화면 `WatchTouchdownView` 에는 같은 함정을 반대 방향으로 막아 둔 가드가 이미 있다. 그때 남긴 주석이 이 함정을 정확히 설명한다.

```swift
// 사용자가 이 화면을 벗어나면 뒷정리를 하는 자리다.
//
// onDisappear 는 "사용자가 나갔다"와 "다른 화면이 위에 덮였다"를 구분하지 못한다.
// 아이폰이 새 러닝을 시작하면 이 화면 위로 PFD 가 밀고 들어오는데, 그때도 여기가
// 불려서 방금 시작한 러닝을 그대로 정리해버린다. 그래서 워크아웃 세션이 돌고 있으면
// 손대지 않는다. 정상적으로 나가는 경우는 세션이 이미 .ended 라 그대로 통과한다.
.onDisappear {
    guard !didNavigateToSummary else { return }
    guard HealthKitService.shared.session?.state != .running else { return }
    Task {
        await viewModel.resetState()
    }
}
```

이 코드는 `RunWayWatch Watch App/Views/WatchTouchdownView.swift` 의 80줄에서 92줄이다(v1.4.1).

두 가드를 나란히 보면 방향이 반대다. PFD 는 세션이 **있으면** 정리하고, 착륙 화면은 세션이 **돌고 있으면** 손대지 않는다. PFD 쪽에는 같은 막이 없다.

PFD 의 가드는 2026-07-14 부터 이 모양이다. 그러니 이 용의자는 9월 기록에도, 10월 이후 기록에도 해당될 수 있다.

---

### 깨우기 지속 시간과 16초

가장 긴 기록이 16.32초다. 애플워치는 손목을 내리면 화면이 꺼질 수 있다. 화면을 깨웠을 때 얼마나 켜 둘지는 설정의 깨우기 지속 시간으로 정한다. 이 설정이 있다는 것은 [Apple 지원 문서](https://support.apple.com/guide/watch/adjust-the-display-settings-apd127ec93ac/watchos){:target="_blank"}에서 확인했다. 하지만 문서에는 고를 수 있는 초 값이 나오지 않아서 기본값이 몇 초인지는 확인하지 못했다.

가설은 이렇다. 지인이 시작 버튼을 누르고 손목을 내린 채 서 있었다. 화면이 꺼지면서 PFD 의 `onDisappear` 가 불렸다. 세션이 있었으니 정리해 버렸다. 4번과 5번에 찍힌 "동작 일시정지"가 서 있었다는 것과 맞는다.

**아직 확인하지 못한 것**은 두 가지다. 워치 화면이 꺼질 때 운동 중인 앱의 `onDisappear` 가 실제로 불리는지, 그리고 지인 워치의 깨우기 지속 시간과 "항상 켬" 설정이다. 시리즈 7 은 항상 켬을 지원해서, 켜져 있으면 손목을 내려도 화면이 남는다.

약점도 있다. 1초 안팎인 아이폰 기록은 이 가설로 설명하기 어렵다. 워치 앱이 뜨고 화면이 그려지고 다시 사라지기에 1초는 너무 짧다.

---

## 둘째 용의자, 늦게 도착한 종료 신호

한쪽 기기에서 러닝을 끝내면 상대 기기에 종료 신호를 보낸다. 상대가 그 순간 닿지 않으면 신호를 보관함에 넣어 두었다가 나중에 배달되게 한다.

```swift
func sendStopSignal() {
    guard WCSession.default.activationState == .activated else {
        RemoteStopLogger.log("send.notActivated",
                             "세션이 활성 상태가 아니라 못 보냄")
        return
    }
    let message: [String: Any] = [
        "type": "remoteStopped",
        "sentAt": Date().timeIntervalSince1970
    ]
    guard session.isReachable else {
        RemoteStopLogger.log("send.queued", "상대가 안 닿아 보관함으로 넘김")
        session.transferUserInfo(message)
        return
    }
    RemoteStopLogger.log("send.message", "바로 보냄")
    session.sendMessage(message, replyHandler: nil) { [weak self] error in
        RemoteStopLogger.log("send.failed", "\(error.localizedDescription) / 보관함으로 재시도")
        self?.session.transferUserInfo(message)
    }
}
```

이 코드는 `RunWay/Shared/Service/WatchConnectivityService.swift` 의 90줄에서 110줄이다(v1.4.1).

#### transferUserInfo로 못 보낸 신호 맡겨 두기

아래는 이 코드에서 쓴 [`WCSession`](https://developer.apple.com/documentation/watchconnectivity/wcsession){:target="_blank"}의 멤버들이다.

| API | 하는 일 |
|---|---|
| [`activationState`](https://developer.apple.com/documentation/watchconnectivity/wcsession/activationstate){:target="_blank"} | 아이폰과 워치 사이의 연결 통로가 열려 있는지 알려 준다. `.activated` 가 아니면 아무것도 못 보낸다 |
| [`isReachable`](https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable){:target="_blank"} | 지금 상대 앱이 즉시 응답할 수 있는 상태인지 알려 준다 |
| [`sendMessage(_:replyHandler:errorHandler:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage%28%5F%3Areplyhandler%3Aerrorhandler%3A%29){:target="_blank"} | 상대에게 바로 보낸다. 상대 앱이 그 순간 살아 있지 않으면 실패하고, 실패는 `errorHandler` 로 온다 |
| [`transferUserInfo(_:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferuserinfo%28%5F%3A%29){:target="_blank"} | 보낼 내용을 보관함에 넣는다. 연결이 다시 열리면 배달된다 |

코드는 상대가 닿으면 `sendMessage` 로 바로 보내고, 안 닿거나 보내다 실패하면 `transferUserInfo` 로 보관함에 넘긴다. 보내는 내용에는 `sentAt` 으로 보낸 시각을 같이 싣는다.

---

### transferUserInfo란?

`transferUserInfo` 는 우체국 보관함 같은 것이다. 받는 사람이 집에 없으면 편지를 보관함에 넣어 두고, 사람이 돌아오면 그때 전해 준다.

핵심은 **보관 기간에 제한이 없다**는 점이다. 연결이 다시 열릴 때 배달된다. 그래서 지난 러닝의 종료 신호가 다음 러닝이 시작된 뒤에 도착할 수 있다. 편지를 쓴 날과 받는 날이 다를 수 있다는 이야기다.

이 문제는 [47번 글](https://haroldfromk.github.io/posts/RunningProject-(47)/)의 "어느 러닝인지 말하지 않는 종료 신호"에서 이미 한 번 다뤘고, 보낸 시각 `sentAt` 으로 지난 신호를 거르는 장치를 그때 만들었다.

![보관함에 남은 종료 신호가 다음 러닝에 배달되는 순서. 러닝 A 가 끝나며 종료 신호를 보냈는데 상대가 안 닿아 보관함에 들어간다. 러닝 B 가 시작된 직후 보관함이 배달되고, 이때 startDate 가 비어 있다면(확인하지 못했다) 검사를 통과해서 방금 시작한 러닝 B 가 끝난다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-16-RunningProject-59/runway-watch-short-pending-stop-r2.png)

---

### 거르는 장치의 두 구멍

받는 쪽에서 신호가 지금 러닝의 것인지 가리는 함수다.

```swift
guard let sentAt,
      let startDate = HealthKitService.shared.session?.startDate else { return true }
return startDate.timeIntervalSince1970 <= sentAt
```

이 코드는 `WatchConnectivityService.swift` 의 `isStopSignalCurrent` 안의 165줄에서 167줄이다(v1.4.1). 지금 러닝이 신호보다 **나중에** 시작됐으면 그 신호는 지난 러닝의 것이니 버린다. 시작 시각 [`startDate`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/startdate){:target="_blank"}는 운동 세션이 시작된 시각이다.

구멍이 두 개 보인다.

**구멍 1, 보관함은 보낸 기기가 자기 쪽만 비운다.** 새 러닝을 시작할 때 아직 배달되지 않은 종료 신호를 치우는 `cancelPendingStopSignals()` 가 있다. 이 함수는 `outstandingUserInfoTransfers`, 곧 이 기기가 보낸 전송만 취소한다. 새 러닝을 시작한 기기는 자기가 보낸 쪽 보관함만 비운다. 상대 기기 보관함에 남은 지난 신호는 그대로 배달된다.

워치가 러닝을 시작하면(`WatchViewModel.start()`) 워치는 자기 보관함만 비운다. 아이폰이 워치로 보내 둔 지난 종료 신호는 남아서 배달될 수 있고, 워치의 새 러닝을 끝낼 수 있다. 워치 기록 4건에 해당하는 경우다.

아이폰이 러닝을 시작하는 경우는 워치에서 아래 `handle(_:)` 로 들어온다.

```swift
func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task {
        do {
            HealthKitService.shared.startOrigin = .remote
            try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.workoutSessionFailed)
        }
    }
}
```

이 코드는 `RunWayWatch Watch App/Services/AppDelegate.swift` 의 23줄에서 32줄이다(v1.4.1). 이 길은 `cancelPendingStopSignals()` 를 부르지 않으니, 워치가 아이폰으로 보내 둔 지난 종료 신호는 비워지지 않고 남아서 아이폰의 새 러닝을 끝낼 수 있다.

**구멍 2, `startDate` 가 없으면 무조건 통과한다.** 위 함수의 첫 `guard` 가 `startDate` 를 못 얻으면 `return true` 로 신호를 받아들인다. 워치의 운동 시작 코드는 아래와 같다. 세션을 만들고 `startActivity` 를 부르는 일은 `await` 없이 한 번에 이어진다. 앱에는 화면 일을 맡은 한 줄짜리 작업 줄(메인 스레드, `MainActor`)이 있어서 앞의 일이 끝나야 다음 일을 시작하고, 종료 신호를 처리하는 코드도 같은 줄에서 돈다. 그래서 이 단계들 사이에 끼어들 수는 없다.

```swift
func startWorkout(workoutConfiguration: HKWorkoutConfiguration) async throws {
    runningMode = .standalone
    session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
    builder = session?.associatedWorkoutBuilder()
    session?.delegate = self
    builder?.delegate = self
    builder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: workoutConfiguration)

    let startDate = Date()
    session?.startActivity(with: startDate)
    try await builder?.beginCollection(at: startDate)
    // 생략
}
```

이 코드는 `RunWay/Shared/Service/HealthKitService.swift` 의 119줄에서 129줄이다(v1.4.1).

#### HKWorkoutSession으로 운동 세션 시작하기

1. [`HKWorkoutSession(healthStore:configuration:)`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/init%28healthstore%3Aconfiguration%3A%29){:target="_blank"}으로 운동 세션을 만든다. 이 순간 `session` 은 생기지만 아직 시작된 것이 아니다.
2. [`associatedWorkoutBuilder()`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/associatedworkoutbuilder%28%29){:target="_blank"}로 이 세션의 기록을 모을 도구(builder)를 얻는다.
3. [`startActivity(with:)`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/startactivity%28with%3A%29){:target="_blank"}가 세션을 시작한다. 이 호출 뒤에 `session.startDate` 가 언제 채워지는지는 확인하지 못했다.
4. `beginCollection(at:)` 으로 builder 가 데이터를 모으기 시작한다.

`startActivity(with:)` 를 부른 뒤 `session.startDate` 가 언제 채워지는지는 아직 확인 못 했다. 상태가 running 으로 바뀌기 전까지 비어 있다면 그 사이가 틈이다. 그 사이에 지난 신호가 오면 검사를 통과하고, 막 시작한 러닝이 끝난다. 수 초짜리 워치 기록이 만들어지는 모양이다.

**아직 확인하지 못한 것**은 `startDate` 가 비어 있는 구간이 실제로 있는지, 있다면 얼마나 긴지, 보관함 배달 시점과 겹치는지다.

---

### 버전에 따라 갈리는 9월

`sentAt` 과 시각 비교, 보관함 비우기는 1.4 에서 처음 들어갔다. 보관함으로 대신 보내는 방식은 2026-07-28 커밋부터 있었고 1.2 에 처음 실렸다. 그러니 1.3.x 에는 지난 종료 신호를 거르는 장치가 하나도 없었다. 아이폰이 자기 기록을 버리는 코드는 1.3.2 부터라서, 1.3.1 시기의 아이폰 기록에는 그 코드가 관여하지 않는다.

태그가 가리키는 커밋 날짜는 v1.3.1 이 9월 3일, v1.3.2 가 9월 30일, v1.4 가 10월 6일, v1.4.1 이 10월 18일이다. 이 기준이면 9월의 다섯 건(아이폰 3건과 9/27 워치 2건)은 1.3.x 시기이고, 10/26 과 11/7 은 1.4.1 시기다.

![9월 1일부터 11월 10일까지의 시간축. 태그 v1.3.1 은 9월 3일, v1.3.2 는 9월 30일, v1.4 는 10월 6일, v1.4.1 은 10월 18일이다. 아이폰 기록 3건과 9월 27일 워치 기록 2건은 거르는 장치가 없던 1.3.x 구간에 있고, 10월 26일과 11월 7일의 워치 기록은 sentAt 거르기가 있는 구간에 있다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-16-RunningProject-59/runway-watch-short-versions-r2.png)

**아직 확인하지 못한 것**은 앱스토어의 실제 출시일(태그 날짜와 다를 수 있다)과 지인이 자동 업데이트를 쓰는지다. 그래서 9월 기록과 10월 이후 기록은 범인이 다를 수 있다.

---

## 두 용의자가 남기는 흔적

두 용의자는 러닝을 끝내는 방향이 다르다. (가) 화면이 사라져서 끝난 경우는 워치가 스스로 `stopWorkout()` 을 불러서 종료의 출처 `stopOrigin` 이 `.local` 이 된다. (나) 지난 신호가 끝낸 경우는 `handleStopSignal` 이 `stopOrigin` 을 `.remote` 로 둔다.

이 단계마다 이미 로그를 남기고 있다. 원격 종료가 안 먹는 문제를 보려고 1.4 에서 넣어 둔 `RemoteStopLogger` 다. 로거를 만든 이야기는 [53번 글](https://haroldfromk.github.io/posts/RunningProject-(53)/)에 있다.

```swift
nonisolated enum RemoteStopLogger {
    // 생략
    private static let logger = Logger(subsystem: "com.haroldfromk.RunWay", category: "RemoteStop")

    // 생략
    static func log(_ step: String, _ detail: String = "") {
        logger.notice("[\(step, privacy: .public)] \(detail, privacy: .public)")
        // 생략
    }
}
```

이 코드는 `RunWay/Debug/RemoteStopLogger.swift` 의 선언과 `log` 함수다(v1.4.1). 파일에 따로 남기는 부분은 디버그 빌드에서만 도는 것이라 생략했다.

#### Logger.notice로 디스크에 남기기

| API | 하는 일 |
|---|---|
| [`Logger(subsystem:category:)`](https://developer.apple.com/documentation/os/logger/init%28subsystem%3Acategory%3A%29){:target="_blank"} | 로그를 앱 이름(subsystem)과 갈래(category)로 묶어서 나중에 골라 볼 수 있게 한다 |
| [`notice(_:)`](https://developer.apple.com/documentation/os/logger/notice%28%5F%3A%29){:target="_blank"} | 기본 수준의 기록을 남긴다. 기기의 디스크에 저장되어 러닝이 끝난 뒤에도 받아 볼 수 있다 |
| [`info(_:)`](https://developer.apple.com/documentation/os/logger/info%28%5F%3A%29){:target="_blank"} | 메모리에만 머물다 사라지는 수준이다. 그 순간 Mac 에서 로그를 지켜보고 있지 않았다면 남지 않는다 |
| [`OSLogPrivacy.public`](https://developer.apple.com/documentation/os/oslogprivacy/public){:target="_blank"} | 문자열 값을 `privacy: .public` 으로 적으면 배포판에서도 `<private>` 로 가려지지 않고 그대로 보인다 |

언제 날지 모르는 간헐적인 문제라 `notice` 를 골랐다. `info` 로 남기면 러닝이 끝난 뒤에는 받을 수가 없다.

---

### 통합 로그란?

통합 로그는 기기 전체가 함께 쓰는 로그 저장소다. `OSLog` 의 `Logger` 로 적은 줄이 여기에 쌓이고, 앱을 배포해도 남는다. 건물 관리실의 출입 기록 같은 것이다. 앱이 꺼져도 기록은 관리실에 남아 있다. 다만 기기 안에 남는 기간은 길지 않다.

기록을 읽는 법은 기기를 Mac 에 연결해 `log collect --device` 로 모은 뒤 `log show` 로 `category == "RemoteStop"` 인 줄만 고르는 것이다. [`Logger`](https://developer.apple.com/documentation/os/logger){:target="_blank"} 문서에 쓰는 법이 있다.

---

### 로그 줄로 가르는 법

남는 줄의 순서로 두 용의자를 가를 수 있다.

| 경우 | 남는 줄의 순서 |
|---|---|
| (가) 화면이 사라짐 | `watch.tapped` 없음, `[stopWorkout] 세션=상태2`, `[watch.state] toState=6`, `[watch.sink] stopOrigin=local`, 이어서 `send.*`(워치가 시작한 러닝이면 `watch.notSending`), `[watch.published] stopOrigin=local`. `receive` 줄은 없다 |
| (나) 지난 신호 | `[receive] sentAt=... 세션시작=... 통과=true`, `[handle]`, `[watch.sink] stopOrigin=remote`. `stopWorkout` 줄은 없다. 아이폰에서 정상으로 끝냈을 때도 같은 줄이 남는다. `sentAt` 이 `세션시작` 보다 나중이면 정상이고, `세션시작=없음` 이면 구멍 2 다 |
| 정상 종료 | `[watch.tapped]` 가 맨 앞에 있다 |
| 아무 줄도 없음 | 앱이 충돌로 죽었다 |

상태 숫자는 [`HKWorkoutSessionState`](https://developer.apple.com/documentation/healthkit/hkworkoutsessionstate){:target="_blank"}의 값을 숫자로 적은 것이다. 2 가 `running`, 6 이 `stopped` 다.

---

## 지금 말할 수 있는 것

앱이 꺼진 것이 먼저였고 건강 앱의 알림은 그 결과였다. 7건 모두 길어야 16초 안에 끝났다. 심박이 남은 4번과 5번은 출발하기 전 값이었다.

용의자는 둘이다. (가) 화면이 사라질 때 세션이 있으면 끝내 버리는 PFD 의 가드. (나) 보관함에서 늦게 도착한 지난 종료 신호와, 그것을 거르는 장치의 두 구멍. (나)의 두 구멍은 범인이 아니더라도 코드에 실제로 있는 틈이다. (가)는 화면이 꺼질 때 `onDisappear` 가 불려야만 문제가 된다.

9월 기록과 10월 이후 기록은 앱 버전이 달라서 범인이 다를 수 있다.

아직 확인하지 못한 것은 이렇다. 워치 화면이 꺼질 때 `onDisappear` 가 불리는지, 지인 워치의 깨우기 지속 시간과 항상 켬 설정, 9월에 지인이 쓴 앱 버전, 같은 날 아이폰 기록과 워치 기록이 함께 없는 이유. 원인이 확정되지 않아서 코드는 고치지 않았다.
