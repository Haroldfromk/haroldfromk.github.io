---
title: RunWay 1.3.2 (2) 기준을 잘못 고른 두 가지
writer: Harold
date: 2026-09-22 09:00:00 +0900
categories: [RunWay]
tags: [UserNotifications, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

[이전 글](https://haroldfromk.github.io/posts/RunningProject-(41)/){:target="_blank"}에서 GPWS 경고와 건강 앱 중복 저장을 고쳤다. 1.3.2를 마무리하면서 두 개를 더 손봤는데, 앞의 둘과 성격이 달라서 따로 적는다.

7일 리마인더와 Pre-flight Check의 APPLE WATCH 항목이다. 기능도 화면도 다른데 **틀린 자리가 같았다.**

둘 다 **기능이 실제로 필요로 하는 조건 대신, 그때 손에 잡히던 값을 기준으로 삼았다.** 알림은 "마지막 러닝 + 7일"이라는 한 시점에 걸어뒀는데 필요한 건 안 뛰는 상태가 이어지는 동안이었고, 워치 항목은 앱이 떠 있는지를 봤는데 필요한 건 워치가 페어링돼 있는지였다.

둘 다 처음 만들 때는 맞는 코드처럼 보였다.

---

## 7일 알림이 한 번 울리고 끝나고 있었다

1.3.2 마무리하면서 리마인더를 다시 봤다. 마지막 러닝으로부터 일주일이 지나면 다시 뛰라고 알려주는 기능인데, **그 한 번을 놓치면 그다음이 없었다.**

```swift
let fireDate = lastRunDate.addingTimeInterval(inactivityThreshold)
guard fireDate > .now else { return }
// 생략
let trigger = UNTimeIntervalNotificationTrigger(
    timeInterval: fireDate.timeIntervalSinceNow,
    repeats: false
)
```

`repeats: false`라 딱 한 번 울린다. 다시 예약되는 시점은 **다음 러닝을 저장할 때**뿐이다. 그런데 알림을 받고도 안 뛰면 다음 러닝이 없으니 예약도 다시 안 잡힌다. **알림이 계속 필요한 사람에게서 알림이 먼저 끊긴다.**

---

### 오래 안 뛴 사람일수록 알림이 안 갔다

위 코드의 두 번째 줄이 더 문제였다.

```swift
guard fireDate > .now else { return }
```

발화 시점이 이미 지났으면 그냥 돌아간다. 두 달 동안 안 뛴 사람이 앱을 열면 `lastRunDate + 7일`은 한참 전이다. 그래서 **예약이 아예 안 잡힌다.**

주석에는 "다음 러닝을 저장하는 시점에 다시 계산되기 때문"이라고 적어뒀었다. 틀린 말은 아닌데, **다음 러닝이 없는 사람을 위한 기능**에 그 전제를 쓴 게 문제였다. 제일 오래 쉰 사람에게만 알림이 안 가는 구조였다.

---

### 반복 트리거로 못 바꾼 이유

`repeats: true`로 바꾸면 되는 줄 알았는데 안 된다. `UNTimeIntervalNotificationTrigger`는 반복으로 만들면 **첫 발화도 간격만큼 뒤로 밀린다.** 예약을 거는 순간부터 7일을 세는 것이다.

이 기능은 "마지막 러닝으로부터 7일"이어야 한다. 앱을 여는 시점은 마지막 러닝 4일 뒤일 수도, 6일 뒤일 수도 있다. 반복 트리거를 쓰면 그때마다 기준점이 앱을 연 순간으로 옮겨가서, 열어볼수록 알림이 뒤로 밀린다.

첫 알림용 하나와 반복용 하나를 따로 두면 해결되지만, 그러면 예약 두 개를 서로 다른 규칙으로 관리해야 한다. 어차피 예약을 여러 개 쓸 거면 **전부 단발로 두는 쪽이 계산이 한 군데로 모인다.**

---

### 7·14·21·28일을 한 번에 깔아둔다

iOS는 앱 하나당 대기 중인 로컬 알림을 64개까지 들고 있는다. 네 개는 넉넉하다.

```swift
private static let reminderDays = [7, 14, 21, 28]

private static func reschedule(lastRunDate: Date) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

    var didSchedule = false
    for elapsedDays in reminderDays {
        let fireDate = lastRunDate.addingTimeInterval(TimeInterval(elapsedDays) * day)
        guard fireDate > .now else { continue }   // return 이 아니라 continue
        add(elapsedDays: elapsedDays, fireDate: fireDate, to: center)
        didSchedule = true
    }

    guard !didSchedule, let first = reminderDays.first else { return }
    add(elapsedDays: first, fireDate: Date().addingTimeInterval(TimeInterval(first) * day), to: center)
}
```

바뀐 건 세 군데다.

1. **`return`을 `continue`로.** 마지막 러닝이 열흘 전이면 7일치는 이미 지났지만 14·21·28일치는 아직 앞에 있다. 지난 것만 건너뛰고 나머지를 건다.
2. **네 단계가 전부 지났으면 지금부터 다시 첫 단계를 건다.** 아까 그 두 달 쉰 사람 경우다. 앱을 연 이상 기준점을 옮겨도 되는 유일한 상황이라 여기서만 `Date()`를 쓴다.
3. **지울 때 옛 식별자도 같이 지운다.** 단계가 하나였던 시절의 예약이 남아있으면 7일 알림이 두 번 온다.

문구는 단계마다 다르게 했다. 같은 문장이 네 번 오면 알림을 꺼버릴 것 같아서다.

```swift
private static func body(elapsedDays: Int) -> String {
    switch elapsedDays {
    case 7:
        return String(localized: "일주일째 활주로가 비어있어요. 오늘 다시 이륙해볼까요?")
    // 생략
    default:
        return String(localized: "한 달째 활주로가 비어있어요. 오늘 다시 관제탑에 불을 켜볼까요?")
    }
}
```

문자열을 배열에 담아두고 꺼내 쓰는 쪽이 짧지만 그렇게 안 했다. **String Catalog는 소스에 리터럴이 그대로 적힌 자리만 훑는다.** 36번 글에서 한 번 밟은 함정이라 이번엔 분기로 늘어놨다.

한 달 뒤에도 안 뛰면 그때는 알림이 멈춘다. 끝없이 보내면 알림 자체를 꺼버릴 수 있고, 그러면 그 뒤로는 아무것도 못 알린다. **네 번까지만 보내고 그만두는 쪽**을 골랐다.

---

## 워치를 차고 있어도 NOT CONNECTED로 보였다

러닝 시작 전 Pre-flight Check에 APPLE WATCH 항목이 있다. 워치를 차고 있어도 여기가 계속 **NOT CONNECTED**로 보인다는 게 걸렸다.

```swift
var watchStatus: (label: String, ok: Bool) {
    let connected = watchConnectivityService.isWatchConnected  // session.isReachable
    return connected ? ("CONNECTED", true) : ("NOT CONNECTED", false)
}
```

`isReachable`이 문제였다. 이 값은 **워치 앱이 포그라운드에 떠 있을 때만** true다. 워치를 차고 있는 것만으로는 안 되고, 손목을 들어 RunWay 워치 앱을 직접 띄워놔야 CONNECTED가 된다.

---

### 애초에 이 값을 볼 이유가 없었다

더 이상한 건 **미러링이 이 값과 아무 상관이 없다**는 점이다.

```swift
// 조건 없이 그냥 부른다
try await store.startWatchApp(toHandle: workoutConfiguration)
```

`startWatchApp(toHandle:)`은 시스템에 워치 앱 실행을 요청하는 API다. 워치 앱이 떠 있든 아니든 시스템이 깨운다. **그게 앱 주도 미러링의 핵심이고, 워치를 미리 켜둘 필요가 없게 만드는 이유다.**

그런데 화면은 그 반대를 요구하고 있었다. 워치 앱을 미리 띄워야 CONNECTED가 뜨니까, 사용자 입장에서는 미러링을 쓰려면 워치 앱을 먼저 켜야 하는 것처럼 보인다. **미러링을 만든 의도와 정반대로 읽히는 표시였다.**

정리하면 이 배지는 동작에는 아무 영향이 없고 표시만 틀리고 있었다. 기능이 멀쩡하니 버그로 잡히지도 않는다.

---

### 실제로 필요한 조건으로 바꿨다

미러링이 되려면 **워치가 페어링돼 있고, 거기에 RunWay 워치 앱이 설치돼 있으면** 된다. 둘 다 이미 있던 값이다.

```swift
var watchStatus: (label: String, ok: Bool) {
    guard watchConnectivityService.isWatchPaired else { return ("NOT PAIRED", false) }
    guard watchConnectivityService.isWatchAppInstalled else { return ("APP NOT INSTALLED", false) }
    return ("READY", true)
}
```

두 단계로 나눈 이유가 있다. 전에는 `NOT CONNECTED` 하나라서 **워치가 없는 건지, 앱을 안 깔았는지, 그냥 앱이 꺼져있는 건지 구분이 안 됐다.** 이제는 문구만 보고 뭘 해야 하는지 알 수 있다.

덤으로 하나가 더 정리됐다. 심박 모드 토글이 쓰던 조건이 이것과 똑같았다.

```swift
// 전
var isHeartRateModeAvailable: Bool {
    watchConnectivityService.isWatchPaired && watchConnectivityService.isWatchAppInstalled
}

// 후
var isHeartRateModeAvailable: Bool { watchStatus.ok }
```

같은 규칙을 두 군데 적어두면 한쪽만 고쳤을 때 **체크리스트는 준비됐다는데 토글은 잠겨있는** 상태가 된다. 지금은 그럴 일이 없다. 쓰지 않게 된 `isWatchConnected`는 지웠다.

---

## 정리하면서 남는 것

두 개를 따로 고쳤는데 고치고 나니 같은 모양이었다.

| | 기준으로 삼았던 것 | 실제로 필요했던 것 |
|---|---|---|
| 리마인더 | 마지막 러닝 + 7일, 그 한 시점 | 안 뛰는 상태가 이어지는 동안 계속 |
| 워치 항목 | 워치 앱이 지금 떠 있는가 | 워치가 페어링돼 있는가 |

왼쪽 열은 둘 다 **그때 손에 잡히던 값**이다. 알림은 한 시점에 거는 게 코드가 제일 짧고, 워치는 `isReachable`이 이름부터 연결 상태처럼 보인다. 오른쪽 열은 둘 다 **기능이 무엇을 위한 것인지 다시 물어야 나오는 값**이다.

그래서 고치는 일이 코드 문제가 아니라 질문 문제였다. 리마인더는 "얼마나 자주 보낼까"가 아니라 **"이 알림은 무엇을 위한 것인가"**였고, 답이 "안 뛰는 사람을 다시 부르는 것"이라 한 번으로는 안 됐다. 워치 항목은 "왜 연결 표시가 안 뜨나"가 아니라 **"이 표시는 무엇을 알려주려는 것인가"**였고, 답이 "미러링이 되는가"라 `isReachable`은 애초에 답이 아니었다.

**둘 다 코드를 고치기 전에 질문을 고쳐야 했다.**

---

## 남은 것

APPLE WATCH 항목에 아직 구멍이 하나 있다. `isWatchPaired`는 세션 활성화가 끝나야 제대로 된 값을 주는데, 그 활성화가 **비동기라 앱 켜는 즉시 끝나지 않는다.** 그 사이에 화면을 보면 워치가 멀쩡히 페어링돼 있어도 NOT PAIRED가 뜬다.

스플래시가 1초쯤 돌고 홈 화면을 거쳐야 이 화면에 오니까 실제로 걸릴 일은 거의 없다. 그래도 **없는 워치를 없다고 하는 것과, 있는 워치를 없다고 하는 건 다른 문제라** 마저 닫을 생각이다. 활성화가 끝났다고 알려주는 콜백이 지금은 로그만 찍고 있다.

그리고 미러링이 잘 안 된다는 피드백을 따로 받았다. 코드를 보니 아이폰이 미러링됐다고 판단하는 근거가 **"워치 앱을 깨워달라는 요청이 안 튕겼다"**는 것뿐이다. 워치가 실제로 세션을 시작했는지는 확인한 적이 없다. 이건 재현부터 해야 해서 1.3.3으로 미룬다.
