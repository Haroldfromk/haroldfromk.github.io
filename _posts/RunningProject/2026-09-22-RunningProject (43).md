---
title: RunWay 1.3.2 (2) 기준을 잘못 고른 두 가지
writer: Harold
date: 2026-09-22 09:00:00 +0900
last_modified_at: 2026-09-27 21:00:00 +0900
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

**2026-09-27 덧붙임**: 심사를 넣기 전에 두 가지가 더 나왔다. 지인이 보내준 워치 화면 증상과, 빌드가 통째로 막힌 일이다. 글 뒤쪽에 이어서 적었다.

---

## 한 번 울리고 끝나던 7일 알림

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

### 오래 안 뛴 사람일수록 안 가던 알림

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

### 7·14·21·28일 한 번에 예약

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

## 워치를 차고 있어도 NOT CONNECTED로 보이던 문제

러닝 시작 전 Pre-flight Check에 APPLE WATCH 항목이 있다. 워치를 차고 있어도 여기가 계속 **NOT CONNECTED**로 보인다는 게 걸렸다.

```swift
var watchStatus: (label: String, ok: Bool) {
    let connected = watchConnectivityService.isWatchConnected  // session.isReachable
    return connected ? ("CONNECTED", true) : ("NOT CONNECTED", false)
}
```

`isReachable`이 문제였다. 이 값은 **워치 앱이 포그라운드에 떠 있을 때만** true다. 워치를 차고 있는 것만으로는 안 되고, 손목을 들어 RunWay 워치 앱을 직접 띄워놔야 CONNECTED가 된다.

---

### 애초에 볼 이유가 없던 값

더 이상한 건 **미러링이 이 값과 아무 상관이 없다**는 점이다.

```swift
// 조건 없이 그냥 부른다
try await store.startWatchApp(toHandle: workoutConfiguration)
```

`startWatchApp(toHandle:)`은 시스템에 워치 앱 실행을 요청하는 API다. 워치 앱이 떠 있든 아니든 시스템이 깨운다. **그게 앱 주도 미러링의 핵심이고, 워치를 미리 켜둘 필요가 없게 만드는 이유다.**

그런데 화면은 그 반대를 요구하고 있었다. 워치 앱을 미리 띄워야 CONNECTED가 뜨니까, 사용자 입장에서는 미러링을 쓰려면 워치 앱을 먼저 켜야 하는 것처럼 보인다. **미러링을 만든 의도와 정반대로 읽히는 표시였다.**

정리하면 이 배지는 동작에는 아무 영향이 없고 표시만 틀리고 있었다. 기능이 멀쩡하니 버그로 잡히지도 않는다.

---

### 실제로 필요한 조건

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

### 반대로 기운 결과

실기기로 확인하다가 이상한 걸 봤다. **블루투스를 꺼도 초록불이 그대로다.** 워치를 집에 두고 폰만 들고 나가도 마찬가지였다.

`isPaired`가 그런 값이다. **"이 아이폰에 이 워치를 등록해뒀다"는 사실**이라, 워치가 지금 어디 있는지도 켜져 있는지도 모른다. 서랍에 한 달을 넣어둬도 등록은 그대로다.

그러니까 아까 고친 게 이렇게 됐다.

| 상황 | 전 (isReachable) | 후 (isPaired) |
|---|---|---|
| 워치 차고 있는데 앱은 꺼짐 | 연결 안 됨 (틀림) | 연동됨 (맞음) |
| 워치를 집에 두고 나옴 | 연결 안 됨 (맞음) | **연동됨 (틀림)** |

**전에는 너무 비관적이었고 지금은 너무 낙관적이다.**

---

### 둘 중 하나를 골라야 하는 상황

더 나은 값이 있는지 찾아봤다. 없었다.

<svg viewBox="0 0 420 250" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="워치의 네 가지 실제 상황과 두 값이 각각 무엇을 구분하는지" style="width:100%;height:auto;color:inherit">
  <text x="0" y="12" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">실제 상황</text>
  <text x="228" y="12" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">isPaired</text>
  <text x="330" y="12" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">isReachable</text>

  <rect x="206" y="60" width="96" height="88" rx="6" fill="currentColor" opacity=".06"/>
  <rect x="308" y="60" width="96" height="88" rx="6" fill="currentColor" opacity=".06"/>

  <line x1="0" y1="22" x2="420" y2="22" stroke="currentColor" stroke-width="1" opacity=".2"/>

  <text x="0" y="46" font-size="12.5" fill="currentColor">워치가 없다</text>
  <text x="248" y="46" font-size="14" fill="#e05c4f" font-weight="700">아니오</text>
  <text x="350" y="46" font-size="14" fill="#e05c4f" font-weight="700">아니오</text>

  <text x="0" y="90" font-size="12.5" fill="currentColor">집에 두고 나왔다</text>
  <text x="248" y="90" font-size="14" fill="#2fa37c" font-weight="700">예</text>
  <text x="350" y="90" font-size="14" fill="#e05c4f" font-weight="700">아니오</text>

  <text x="0" y="134" font-size="12.5" fill="currentColor">차고 있고 앱은 꺼짐</text>
  <text x="0" y="150" font-size="10" fill="currentColor" opacity=".5">앱 주도 미러링의 보통 상태</text>
  <text x="248" y="134" font-size="14" fill="#2fa37c" font-weight="700">예</text>
  <text x="350" y="134" font-size="14" fill="#e05c4f" font-weight="700">아니오</text>

  <text x="0" y="192" font-size="12.5" fill="currentColor">차고 있고 앱도 켜짐</text>
  <text x="248" y="192" font-size="14" fill="#2fa37c" font-weight="700">예</text>
  <text x="350" y="192" font-size="14" fill="#2fa37c" font-weight="700">예</text>

  <line x1="0" y1="212" x2="420" y2="212" stroke="currentColor" stroke-width="1" opacity=".2"/>
  <text x="0" y="234" font-size="12" fill="currentColor" opacity=".75">회색으로 묶인 두 줄은 어느 값으로도 구분되지 않는다</text>
</svg>

**가운데 두 줄이 문제다.** 집에 두고 온 것과 차고 있는데 앱만 꺼진 것을 **어느 값도 구분하지 못한다.** `isPaired`는 둘 다 예라고 하고, `isReachable`은 둘 다 아니오라고 한다.

그래서 어느 쪽을 골라도 한 줄은 틀린다. **틀리는 자리가 다를 뿐이다.**

---

### 그래도 이쪽이 낫다고 본 이유

세 번째 줄이 **앱 주도 미러링에서 가장 흔한 상태**다. 워치를 차고 있고 앱은 안 켠 상태. 애초에 켤 필요가 없게 만든 게 이 기능이니까.

`isReachable`은 그 흔한 상태를 "연결 안 됨"이라고 했다. 그러면 **워치 앱을 먼저 켜야 하는 줄 알게 된다.** 기능을 만든 의도와 정확히 반대로 안내하는 것이다.

`isPaired`도 틀리긴 하는데, **두 번째 줄에서 틀린다.** 워치를 두고 나온 사람에게 "연동됨"이라고 하는 건데, 그 사람은 러닝을 시작하면 바로 안다. 워치가 안 켜지니까. **그리고 기록은 정상으로 남는다.** 미러링이 실패하면 아이폰이 자기 기록을 버리지 않고 저장하기 때문이다.

**틀리는 건 같은데 대가가 다르다.**

---

### 방법이 없다는 애플의 답

혼자 판단한 게 아닌지 확인하려고 자료를 찾아봤다. 마침 같은 질문이 있었다.

한 개발자가 아이폰에서 워치 연결 상태를 실시간으로 알고 싶다며 **일곱 가지를 시도한 뒤** 물었다. 워치 앱에서 주기적으로 신호 보내기, `isReachable` 감시, 확장 실행 세션, 백그라운드 갱신, 블루투스 직접 스캔 등등. 애플 엔지니어가 동료들과 논의하고 답했다.

> 안타깝지만 이 목표를 달성할 좋은 방법이 보이지 않는다

그리고 이유를 짚었는데, 내가 코드를 보며 짐작한 것과 같았다.

> `isReachable`은 "워치 앱이 잠들어 있다"와 "워치가 물리적으로 끊겼다"를 구분하지 못한다

유일한 후보로 확장 실행 세션이 있었지만 **심사 규정 위반이라 거절당할 것**이라고 했다. 권고는 기능 요청서를 내라는 것이었다.

**없는 걸 찾느라 더 헤매지 않아도 된다는 걸 확인한 게 소득이었다.**

---

### 남은 건 자리 문제

문구를 `READY`에서 `PAIRED`로 바꿨다. "준비됨"은 지금 상태를 주장하지만 "연동됨"은 사실만 말한다. 워치 앱이 꺼져 있어도 이상하지 않은 문구다.

그런데 그것만으로는 덜 풀린다. 이 화면을 다시 보면 이유가 보인다.

```
GPS SIGNAL    STRONG      <- 지금 잰 값
APPLE WATCH   PAIRED      <- 지금 잰 값이 아니다
BATTERY       87%         <- 지금 잰 값
WEATHER       맑음         <- 지금 잰 값
```

**셋은 지금을 말하는데 하나만 설정을 말한다.** 재는 값들 사이에 끼어 있으니 그것도 재는 값처럼 읽힌다. 문구를 뭘로 바꿔도 이 힘은 남는다.

**잴 수 없는 걸 재는 자리에 둔 게 문제였다.** 그러면 답은 자리를 옮기는 것이다.

```swift
do {
    try await store.startWatchApp(toHandle: workoutConfiguration)
    // 여기 오면 워치가 실제로 깨어난 것
} catch {
    // 여기 오면 워치가 없거나 꺼져 있는 것
}
```

**시작 전에는 "설정돼 있다"까지만 말할 수 있고, 시작한 뒤에는 "실제로 됐다"를 말할 수 있다.** 러닝이 시작된 직후에 "워치 연동됨" 또는 "워치 없이 진행합니다"를 알려주면 추측이 아니라 사실이다.

이번엔 문구만 바꾸고 자리를 옮기는 건 다음으로 미뤘다. 화면에서 항목 하나를 빼는 일이라 지금 검증 중인 것들과 섞기엔 크다.

---

## 여기까지 둘을 정리하면

두 개를 따로 고쳤는데 고치고 나니 같은 모양이었다.

| | 기준으로 삼았던 것 | 실제로 필요했던 것 |
|---|---|---|
| 리마인더 | 마지막 러닝 + 7일, 그 한 시점 | 안 뛰는 상태가 이어지는 동안 계속 |
| 워치 항목 | 워치 앱이 지금 떠 있는가 | 워치가 페어링돼 있는가 |

왼쪽 열은 둘 다 **그때 손에 잡히던 값**이다. 알림은 한 시점에 거는 게 코드가 제일 짧고, 워치는 `isReachable`이 이름부터 연결 상태처럼 보인다. 오른쪽 열은 둘 다 **기능이 무엇을 위한 것인지 다시 물어야 나오는 값**이다.

그래서 고치는 일이 코드 문제가 아니라 질문 문제였다. 리마인더는 "얼마나 자주 보낼까"가 아니라 **"이 알림은 무엇을 위한 것인가"**였고, 답이 "안 뛰는 사람을 다시 부르는 것"이라 한 번으로는 안 됐다. 워치 항목은 "왜 연결 표시가 안 뜨나"가 아니라 **"이 표시는 무엇을 알려주려는 것인가"**였고, 답이 "미러링이 되는가"라 `isReachable`은 애초에 답이 아니었다.

**둘 다 코드를 고치기 전에 질문을 고쳐야 했다.**

---

## 워치 화면이 떴다가 홈으로 돌아간다는 제보

1.3.2를 아직 안 올린 상태에서 1.3.1을 쓰는 지인에게 연락이 왔다.

1. 아이폰 앱만 켜고 워치 앱은 따로 실행하지 않음
2. 앱에서 러닝 시작
3. 카운트다운 후 워치 앱이 켜지긴 하는데, **PFD 화면이 보였다가 바로 홈 화면으로 돌아감**

그리고 덧붙인 게 있다. **앱에서 러닝을 끝내고 다시 시작하면 그때는 멀쩡하다.**

iPhone 14 Pro / iOS 26.6.2, Apple Watch Nike Series 7 / watchOS 26.2. 내 워치에서는 재현되지 않았다.

---

### 홈으로 돌아가는 하나뿐인 길

워치 내비게이션을 비우는 코드를 전부 찾아봤다.

```swift
func resetState() async {
    // 생략
    resetNavigation()      // navigationPath = [] -> 홈 화면
}
```

이걸 부르는 자리가 넷인데, 사용자는 아무것도 안 눌렀다고 한다. **누군가 대신 러닝을 끝내고 있다는 뜻이다.**

---

### 틀린 가설 둘

여기서 두 번 헛짚었다. 지우면 남는 게 별로 없어서 순서대로 적는다.

**첫 번째.** 지난 러닝의 종료 신호가 뒤늦게 배달된 것이라고 봤다. 아이폰은 워치가 안 잡히면 종료 신호를 `transferUserInfo`로 큐에 쌓아뒀다가 나중에 보내는데, 받는 쪽은 그게 언제 만들어진 신호인지 따지지 않는다. 그럴듯했다. 재현 절차를 만들어 부탁했는데 **재현되지 않았다.**

나중에 보니 **절차가 가설을 비켜가고 있었다.** 연결을 끊었다가 다시 잇는 순서였는데, 다시 잇는 순간 워치 앱이 아직 살아있어서 거기서 배달되고 끝난다. 새 러닝까지 갈 게 없었다.

**두 번째.** 스플래시 화면이 `if isActive { WatchHomeView() } else { 스플래시 }` 로 화면을 통째로 갈아끼운다는 걸 발견했다. **1.5초 동안 `NavigationStack`이 아예 존재하지 않는다.** 그 사이에 `navigateTo(.pfd)`가 불리면 받아줄 스택이 없다.

이건 그럴듯한 정도가 아니라 확신했다. 그런데 지인에게 추가로 들은 게 정반대였다.

| | 두 번째 가설의 예측 | 실제 |
|---|---|---|
| 워치 앱 완전 종료 | 문제 발생 | **정상** |
| 워치 앱 백그라운드 | 정상 | **문제 발생** |

스플래시는 앱이 처음부터 뜰 때만 돈다. **완전 종료가 멀쩡하다는 건 그 경로가 문제없다는 뜻이다.** 뒤집혀 있었다.

---

### 서머리를 안 봤다는 한마디

세 번째로 들은 말이 답이었다.

> 워치에서 러닝을 종료하고 **서머리를 안 봤다**

워치에서 러닝을 끝내면 착륙 화면이 뜬다. 거기 이 코드가 있다.

```swift
.onDisappear {
    guard !didNavigateToSummary else { return }
    Task { await viewModel.resetState() }      // navigationPath = [] -> 홈
}
```

**SUMMARY를 누르지 않으면 `didNavigateToSummary`가 `false`로 남는다.** 그 상태로 손목을 내리면 앱이 백그라운드로 가는데, **백그라운드로 갈 때는 `onDisappear`가 불리지 않는다.** 뒷정리가 안 된 채로 착륙 화면이 그대로 남는다.

<svg viewBox="0 0 420 300" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="착륙 화면이 남은 채로 새 러닝이 시작될 때 벌어지는 일" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="ta" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
  </defs>

  <text x="0" y="12" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">지난 러닝</text>
  <rect x="0" y="22" width="420" height="44" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="14" y="41" font-size="12.5" fill="currentColor" font-weight="600">END FLIGHT -&gt; 착륙 화면</text>
  <text x="14" y="58" font-size="11" fill="currentColor" opacity=".6">아무것도 누르지 않고 손목을 내린다</text>

  <line x1="60" y1="66" x2="60" y2="84" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ta)"/>

  <rect x="0" y="88" width="420" height="44" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="14" y="107" font-size="12.5" fill="#e05c4f" font-weight="600">onDisappear 가 안 불린다</text>
  <text x="14" y="124" font-size="11" fill="#e05c4f" opacity=".85">경로에 .touchdown 이 남은 채 앱이 잠든다</text>

  <line x1="60" y1="132" x2="60" y2="150" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ta)"/>

  <text x="0" y="146" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">새 러닝</text>
  <rect x="0" y="154" width="420" height="44" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="14" y="173" font-size="12.5" fill="currentColor" font-weight="600">아이폰이 러닝 시작 -&gt; navigateTo(.pfd)</text>
  <text x="14" y="190" font-size="11" fill="currentColor" opacity=".6">경로 = [.pfd, .touchdown, .pfd] 로 위에 쌓인다</text>

  <line x1="60" y1="198" x2="60" y2="216" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ta)"/>

  <rect x="0" y="220" width="420" height="44" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="14" y="239" font-size="12.5" fill="#e05c4f" font-weight="600">덮인 착륙 화면의 onDisappear 가 그제서야 불린다</text>
  <text x="14" y="256" font-size="11" fill="#e05c4f" opacity=".85">resetState() -&gt; 방금 시작한 러닝을 정리해버린다</text>

  <line x1="60" y1="264" x2="60" y2="282" stroke="#e05c4f" stroke-width="1.2" marker-end="url(#ta)"/>
  <text x="76" y="286" font-size="12.5" fill="#e05c4f" font-weight="700">PFD 가 번쩍하고 홈 화면</text>
</svg>

`onDisappear`는 **사용자가 나간 것과 다른 화면이 위에 덮인 것을 구분하지 못한다.** 그래서 새 러닝 화면이 올라타는 순간, 가려진 옛 화면이 "내가 사라졌네, 정리하자"며 방금 시작한 러닝을 치운다.

---

### 전부 맞아떨어진 제보

| 들은 말 | 설명 |
|---|---|
| 워치에서 종료했다 | 착륙 화면으로 가는 유일한 길 |
| 서머리를 안 봤다 | `didNavigateToSummary == false`. 바로 이 조건 |
| 백그라운드일 때만 난다 | 앱이 살아서 착륙 화면을 들고 있어야 한다 |
| 완전 종료하면 정상 | 새로 뜨면 경로가 비어있다 |
| 재시작하면 정상 | 이미 `resetState()`가 돌아서 깨끗하다 |

아이폰 러닝이 계속 돌던 것도 맞는다. `resetState()`는 아이폰에 종료 신호를 보내지 않는다.

그리고 이건 **내 책상에서 재현된다.** 고친 코드에서 조건 한 줄만 빼고 이렇게 했다.

1. 앱에서 러닝 시작
2. 워치 앱이 켜짐
3. **워치에서 러닝을 끝내고 바로 크라운을 눌러 시계 화면으로 나간다**
4. 그 상태에서 앱에서 다시 러닝 시작
5. **PFD로 갔다가 바로 홈으로 돌아간다**

3번이 조건이다. **앱 안의 홈 화면으로 가는 게 아니라 앱 자체가 뒤로 물러나야 한다.** 앱 안에서 홈으로 가면 그게 곧 착륙 화면을 벗어나는 것이라 뒷정리가 제대로 돌고, 그러면 재현되지 않는다.

---

### 고친 것

뒷정리에 조건을 걸었다.

```swift
.onDisappear {
    guard !didNavigateToSummary else { return }
    guard HealthKitService.shared.session?.state != .running else { return }
    Task { await viewModel.resetState() }
}
```

**새 러닝이 돌고 있으면 이 화면의 뒷정리로 그걸 건드리지 않는다.** 정상적으로 나가는 경우는 세션이 이미 `.ended`라 그대로 통과한다. 요약 화면에도 같은 구멍이 있어서 같이 막았다.

그리고 새 러닝이 옛 화면 위에 쌓이지 않게 했다.

```swift
// 전
self.navigateTo(.pfd)          // 경로에 덧붙인다

// 후
self.navigationPath = [.pfd]   // 경로를 갈아끼운다
```

조건을 뺐다 넣었다 하면서 확인했다. **빼면 재현되고 넣으면 재현되지 않는다.** 착륙 화면에서 뒤로 스와이프해 나가는 정상 경로도 그대로 동작한다. 새로 넣은 조건이 멀쩡한 경로까지 막으면 곤란해서 같이 봤다.

앞서 세운 가설 둘에 맞춰 손댔던 것은 **전부 되돌렸다.** 실제 원인이 아니었는데 릴리스에 남겨둘 이유가 없다. 구조가 취약한 건 맞아서 다음 버전 후보에 적어뒀다.

---

## 기록이 아예 사라질 수 있던 구조

위 문제를 파다가 별개 버그를 하나 주웠다. 이쪽이 더 나쁘다.

워치 단독 러닝에서 END FLIGHT를 누르면 기록이 만들어져 대기열에 들어간다. 그런데 아이폰으로 넘기는 호출은 다른 데 있었다.

```swift
func resetState() async {
    watchConnectivityService.sendRunningData()   // 여기서만 보냈다
    // 생략
}
```

**`resetState()`는 사용자가 화면을 직접 벗어나야 돈다.** 그러니 끝내자마자 홈으로 나가면 전송이 일어나지 않는다.

```swift
var pendingFlightQueue: [SwiftDataFlight] = []
```

그리고 이 대기열은 **메모리에만 있다.** watchOS가 앱을 정리하면 같이 사라진다.

```
END FLIGHT -> 기록이 메모리 대기열로
           -> 홈 버튼 (뒷정리 안 됨, 전송 안 됨)
           -> watchOS 가 앱을 정리
           -> 기록이 영영 사라진다
```

고친 건 한 줄이다. **기록을 만드는 그 자리에서 바로 넘긴다.**

```swift
pendingFlightQueue.append(runningData)
watchConnectivityService.sendRunningData()
```

`transferUserInfo`라 아이폰이 그 순간 안 잡혀도 시스템 큐에 남았다가 배달된다. **앱이 정리돼도 기록은 이미 시스템으로 넘어가 있다.**

화면 문제는 눈에 보이기라도 한다. 이건 **기록이 안 온 걸 나중에야 알게 되는 쪽**이라 더 나쁘다. 39번 글에서 워치 단독 기록이 간헐적으로 저장되지 않던 문제를 받는 쪽에서 고쳤는데, 보내는 쪽에 같은 성격의 구멍이 남아있었다.

---

### 세 번 틀리고 나서 남은 것

가설을 셋 세웠고 둘이 틀렸다. 되짚어보면 틀린 둘은 **코드만 보고 세운 것**이고, 맞은 하나는 **지인이 "서머리를 안 봤다"고 말해준 뒤에 나왔다.**

처음 받은 증상 설명 세 줄로는 답이 안 나오는 문제였다. 그런데 나는 그 세 줄로 두 번이나 결론을 냈다. 재현되지 않는다는 답을 듣고도 **가설을 의심하는 대신 절차를 의심하지 않았다.**

**남이 겪은 버그는 내가 코드를 아무리 봐도 조건을 채울 수 없다.** 조건은 그 사람만 안다.

---

## 메인 액터에 묶여 있던 값 타입

위 수정을 하고 빌드했는데 엉뚱한 데서 열 개쯤 에러가 났다. 내가 건드리지도 않은 파일이었다.

```
main actor-isolated conformance of 'FlightActivityAttributes' to
'ActivityAttributes' cannot be used in @concurrent context
```

`FlightActivityAttributes`는 Live Activity에 넘길 값을 담아두는 구조체다. 페이스, 거리, 심박 같은 것들이다. 그런데 **이게 메인 액터에 묶여 있다**고 한다. 아무것도 안 붙였는데.

프로젝트 설정을 보니 이유가 있었다.

```
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

**아무 표시도 없는 타입은 전부 `@MainActor`가 된다는 설정이다.** 화면 관련 코드가 대부분이라 이게 편한데, 값만 담는 타입까지 같이 묶인다. 그리고 타입이 묶이면 그 타입의 프로토콜 준수도 같이 묶인다.

문제는 이 값을 받는 쪽이다.

```swift
await activity?.update(.init(state: newState, staleDate: nil))
await activity?.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 10))
```

`Activity.update`와 `Activity.end`는 **메인 액터 밖에서 도는 함수**다. 메인 액터에 묶인 준수를 거기서 쓸 수 없다.

고치는 건 한 단어였다.

```swift
nonisolated struct FlightActivityAttributes: ActivityAttributes {
```

**이 타입은 애초에 특정 액터에 속할 이유가 없다.** 값을 담고 옮기기만 한다. 기본값이 `MainActor`라서 얹혀 있었을 뿐이다.

이 에러가 지금 나온 건 컴파일러 검사가 엄격해졌기 때문이다. 코드는 그대로였고 원래부터 어긋나 있었다. **"되니까 맞다"와 "맞으니까 된다"는 다르다는 걸 다시 봤다.**

---

## 워치에서 끝내면 앱 기록만 안 남던 문제

실기기로 네 경우를 돌려보다가 하나가 걸렸다.

**앱에서 시작하고 워치에서 종료하면 그 러닝이 앱 Logbook에 안 들어온다.** 건강 앱에는 멀쩡히 남는다. 기기도 Apple Watch고 심박도 들어있다. 러닝 자체는 제대로 수집됐는데 앱 기록만 없다.

---

### 나란히 놓으니 한 줄만 다른 네 경우

| | 시작 | 종료 | 저장을 부르는 쪽 | 앱 기록 |
|---|---|---|---|---|
| 1 | 앱 | 앱 | 아이폰이 직접 | 성공 |
| 2 | 앱 | **워치** | **아이폰이 신호를 받고** | **실패** |
| 3 | 앱 (워치 끔) | 앱 | 아이폰이 직접 | 성공 |
| 4 | 워치 | 워치 | 워치가 보낸 기록 수신 | 성공 |

**저장 함수 자체는 멀쩡하다.** 1번과 3번이 같은 함수로 저장에 성공한다. 2번에서만 어딘가에 걸린다.

다른 점은 하나다. **아이폰이 자기가 끝낸 게 아니라 남이 끝냈다고 전해 들은 경우**라는 것.

---

### 어디서 빠지는지 알 방법이 없던 상태

종료할 때 아이폰 화면이 홈으로 돌아갔다. 그 말은 원격 종료를 처리하는 분기가 돌았다는 뜻이고, 그 안에서 저장이 먼저 불린다. **저장 함수는 불렸는데 조용히 빠져나갔다.**

빠져나갈 수 있는 자리가 넷이다.

```swift
guard let modelContext else { return }
guard HealthKitService.shared.startOrigin == .local else { return }
guard totalDistance >= minimumValidDistance else { return }   // 0.1km
if let existing = try? modelContext.fetch(existingDescriptor).first { return }
```

**넷 다 아무 말 없이 돌아간다.** 어느 줄에서 멈췄는지 밖에서는 알 수가 없다.

그래서 네 자리에 각각 이유를 남기게 고쳤다. 화면에도 띄우게 했는데, 이건 밖에 나가서 확인해야 하는 문제라 맥에 붙여둘 수가 없어서다.

![저장을 건너뛴 이유가 화면에 뜬 모습. startOrigin 이 nil 이라고만 나온다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-22-RunningProject-43/runway132_save_skip_alert.webp){: width="360" }
_밖에서 두 번 돌려봤는데 두 번 다 이 문구였다. 그런데 `startOrigin`을 비우는 코드는 저장보다 **뒤에** 있다._

여기서 한 번 더 막혔다. **비우는 코드가 저장 뒤에 있는데 어떻게 이미 비어 있을 수 있나.** 순서가 뒤집혔거나 저장이 두 번 불렸다는 뜻인데, 알림이 마지막 이유 하나만 보여줘서 앞에서 무슨 일이 있었는지는 알 수가 없었다.

---

### 순서를 찍어서 찾은 답

조건 넷에 각각 이유를 붙이고, 그 순서를 한 번에 보여주게 했다. 알림은 마지막 것만 보여줘서 앞 단계를 놓치기 때문이다.

시뮬레이터에서 재현하니 이렇게 나왔다.

![조건 넷에 이유를 붙이고 순서를 모아 한 번에 보여준 화면. 열 줄이 나온다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-22-RunningProject-43/runway132_save_skip_trace.webp){: width="360" }
_같은 저장 함수가 두 번 불렸고, 그 사이에 정리가 끼어 있다._

```
1. 원격 종료 신호 받음 (처리중=false)
2. 원격 종료 신호 받음 (처리중=false)
3. 분기 진입, startOrigin=Optional(.local)
4. 분기 진입, startOrigin=Optional(.local)
5. 저장 진입: 0m, 0초
6. 건너뜀: 거리가 0.000km 로 최소 0.1km 미만입니다
7. resetState 진입 (여기서 startOrigin 이 nil 이 된다)
8. 저장 진입: 264m, 42초, startOrigin=nil
9. 건너뜀: startOrigin 이 nil 입니다
10. resetState 진입
```

두 군데가 눈에 걸린다.

**1번과 2번이 둘 다 `처리중=false`다.** 중복 처리를 막으려고 둔 값인데, 첫 번째가 `true`로 바꿨으면 두 번째는 `true`여야 한다.

**5번은 0m인데 8번은 264m다.** 같은 러닝인데 거리가 다르다.

**하나의 객체라면 둘 다 불가능하다.**

---

### 두 개 살아있던 뷰모델

```swift
// RunWayApp.swift
@State private var runViewModel = RunViewModel()
```

이 한 줄이 원인이었다. **SwiftUI가 App 구조체를 다시 만들 때마다 이 초기값도 새로 만들어진다.** `@State`는 첫 번째만 쓰고 나머지는 버린다.

버려지니까 없는 셈 치면 되는데, **버려진 인스턴스도 `init()`에서 이미 구독을 걸어둔 상태다.** 보통은 해제되면서 구독도 같이 끊긴다. 그런데 안 끊겼다.

```swift
Task {
    for await data in await runningCenter.streamPhaseData() {
        self.currentPhase = data
    }
}
```

**끝나지 않는 스트림을 `self`를 붙든 채 기다리고 있었다.** 그래서 버려진 인스턴스가 죽지 않고, 죽지 않으니 구독도 살아있다.

<svg viewBox="0 0 420 268" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="버려진 뷰모델이 살아남아 종료 신호에 같이 반응하는 과정" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="ga" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
  </defs>

  <rect x="0" y="8" width="180" height="48" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="14" y="28" font-size="11" fill="currentColor" opacity=".55" font-family="monospace">버려진 것</text>
  <text x="14" y="46" font-size="12.5" fill="#e05c4f" font-weight="600">RunViewModel (유령)</text>

  <rect x="240" y="8" width="180" height="48" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".35"/>
  <text x="254" y="28" font-size="11" fill="currentColor" opacity=".55" font-family="monospace">실제로 쓰는 것</text>
  <text x="254" y="46" font-size="12.5" fill="currentColor" font-weight="600">RunViewModel</text>

  <text x="14" y="76" font-size="11" fill="#e05c4f">스트림이 self 를 붙들어 안 죽는다</text>
  <text x="254" y="76" font-size="11" fill="currentColor" opacity=".6">화면이 쓰는 인스턴스</text>

  <line x1="90" y1="86" x2="90" y2="106" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ga)"/>
  <line x1="330" y1="86" x2="330" y2="106" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ga)"/>

  <rect x="0" y="110" width="420" height="40" rx="8" fill="currentColor" opacity=".06"/>
  <text x="14" y="135" font-size="12.5" fill="currentColor" font-weight="600">종료 신호 하나에 구독이 두 번 반응한다</text>

  <line x1="90" y1="150" x2="90" y2="170" stroke="#e05c4f" stroke-width="1.2" marker-end="url(#ga)"/>
  <line x1="330" y1="150" x2="330" y2="170" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ga)"/>

  <rect x="0" y="174" width="180" height="48" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="14" y="194" font-size="11.5" fill="#e05c4f" font-weight="600">거리가 0 이라 저장 안 함</text>
  <text x="14" y="212" font-size="11.5" fill="#e05c4f" font-weight="600">그리고 정리까지 해버린다</text>

  <rect x="240" y="174" width="180" height="48" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".35"/>
  <text x="254" y="194" font-size="11.5" fill="currentColor" opacity=".75">264m 를 저장하려는데</text>
  <text x="254" y="212" font-size="11.5" fill="currentColor" opacity=".75">기준값이 이미 비워졌다</text>

  <line x1="180" y1="198" x2="236" y2="198" stroke="#e05c4f" stroke-width="1.4" marker-end="url(#ga)"/>
  <text x="0" y="248" font-size="12" fill="#e05c4f" font-weight="600">유령이 공용 값을 비우는 바람에 진짜가 저장하지 못한다</text>
</svg>

**중복을 막으려고 둔 표시는 인스턴스마다 따로 있다.** 그러니 두 개가 각자 자기 표시를 보고 통과한다. 반면 `HealthKitService`는 앱 전체에서 하나를 쓴다. **유령이 그 공용 값을 비워버리니 진짜가 저장할 수 없었다.**

---

### 왜 이 경우에만 났는가

| | 저장하는 시점 |
|---|---|
| 앱에서 종료 | 화면에서 버튼을 누를 때. **구독보다 먼저** |
| 워치 단독 | 아예 다른 함수 |
| **앱 시작, 워치 종료** | **구독을 거쳐서** |

**구독을 통해 저장하는 경로가 이것 하나뿐이다.** 나머지는 유령이 있어도 티가 안 난다. 그래서 다른 셋은 멀쩡했다.

---

### 고친 것

```swift
Task { [weak self] in
    guard let center = self?.runningCenter else { return }
    for await data in await center.streamPhaseData() {
        guard let self else { break }
        self.currentPhase = data
    }
}
```

반복마다 살아있는지 확인한다. 버려진 인스턴스가 정상적으로 해제되고, 해제되면 구독도 끊긴다.

---

### 이번에 만든 문제가 아니라는 확인

문제의 코드는 6월부터 있었다. 확인해보려고 **1.3.1 커밋으로 되돌려 같은 시험을 해봤더니 똑같이 저장되지 않았다.**

다만 **실기기에서도 전에 그랬는지는 모른다.** 버려진 인스턴스가 생기느냐는 우리가 정하는 게 아니라 시스템이 정하는 것이라 환경에 따라 다를 수 있다. 그리고 평소에 아이폰으로 러닝을 끝내왔다면 이 경로를 한 번도 안 밟았을 수도 있다.

---

### 곁가지 하나

유령은 종료 신호만 받은 게 아니었다. **`init()`에서 건 구독 전부**를 같이 받고 있었다. 위치 권한 오류와 워크아웃 오류 알림도 포함된다.

저장이 안 되는 게 제일 눈에 띄었을 뿐이고, **알림이 중복으로 뜨는 일도 있었을 수 있다.** 그건 조용히 지나갔을 것이다.

---

## 남은 것

워치 화면 문제를 파면서 세웠다가 틀린 가설 둘은 **구조 자체가 취약한 건 맞았다.** 종료 신호가 언제 만들어진 건지 받는 쪽이 모르는 것, 스플래시가 1.5초 동안 내비게이션을 막는 것 둘 다 그대로 남아있다. 실제 증상으로 확인된 적이 없어 이번엔 뺐고, 그 자리를 손댈 일이 생기면 같이 정리할 생각이다.

APPLE WATCH 항목에도 구멍이 하나 있다. `isWatchPaired`는 세션 활성화가 끝나야 제대로 된 값을 주는데, 그 활성화가 **비동기라 앱 켜는 즉시 끝나지 않는다.** 그 사이에 화면을 보면 워치가 멀쩡히 페어링돼 있어도 NOT PAIRED가 뜬다.

스플래시가 1초쯤 돌고 홈 화면을 거쳐야 이 화면에 오니까 실제로 걸릴 일은 거의 없다. 그래도 **없는 워치를 없다고 하는 것과, 있는 워치를 없다고 하는 건 다른 문제라** 마저 닫을 생각이다. 활성화가 끝났다고 알려주는 콜백이 지금은 로그만 찍고 있다.

그리고 미러링이 잘 안 된다는 피드백을 따로 받았다. 코드를 보니 아이폰이 미러링됐다고 판단하는 근거가 **"워치 앱을 깨워달라는 요청이 안 튕겼다"**는 것뿐이다. 워치가 실제로 세션을 시작했는지는 확인한 적이 없다. 위에서 고친 스플래시 문제가 그 제보의 정체일 수도 있는데, **워치가 시작을 알려주지 않는 구조 자체는 그대로 남아 있다.** 이건 1.3.3에서 본다.

마지막으로 이 글에 적은 워치 수정 둘은 **아직 실기기에서 확인하지 못했다.** 확인할 것도 정해뒀다. 워치 앱을 완전히 끈 상태에서 아이폰으로 러닝을 시작했을 때 PFD가 뜨고 유지되는지, 그리고 PFD에서 뒤로 스와이프했을 때 러닝이 여전히 끝나는지다. 뒤쪽은 이번에 추가한 조건이 정상 종료까지 막아버리면 곤란해서 같이 본다.
