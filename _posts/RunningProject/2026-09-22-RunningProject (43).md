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

## 워치 화면이 떴다가 바로 홈으로 돌아간다는 제보를 받았다

1.3.2를 아직 안 올린 상태에서 1.3.1을 쓰는 지인에게 연락이 왔다. 증상이 구체적이었다.

1. 아이폰 앱만 켜고 워치 앱은 실행하지 않음
2. 앱에서 러닝 시작
3. 카운트다운 후 워치 앱이 켜지긴 하는데, **PFD 화면이 보였다가 바로 홈 화면으로 돌아감**

그리고 하나 덧붙였다. **앱에서 러닝을 끝내고 다시 시작하면 그때는 멀쩡하다.**

iPhone 14 Pro / iOS 26.6.2, Apple Watch Nike Series 7 / watchOS 26.2.

---

### 홈으로 돌아가는 길은 하나뿐이었다

워치 내비게이션을 비우는 코드가 어디 있나 전부 찾아봤다.

```swift
func resetState() async {
    // 생략
    resetNavigation()      // navigationPath = [] -> 홈 화면
}
```

`resetState()`를 부르는 곳이 셋인데 그중 둘은 이 상황과 무관하다. **누군가 러닝을 끝내고 있다는 뜻이다.** 사용자는 아무것도 안 눌렀는데.

---

### 처음 세운 가설은 틀렸다

제일 먼저 의심한 건 **지난 러닝의 종료 신호가 뒤늦게 배달된 것**이었다.

아이폰이 종료 신호를 보내는 코드는 이렇게 생겼다.

```swift
func sendStopSignal() {
    let message: [String: Any] = ["type": "remoteStopped"]
    guard session.isReachable else {
        session.transferUserInfo(message)   // 상대가 없으면 큐에 쌓아둔다
        return
    }
    // 생략
}
```

`transferUserInfo`는 상대가 지금 없어도 **큐에 넣어뒀다가 다음에 세션이 살아날 때 배달한다.** 종료 신호가 유실되지 않게 하려고 일부러 그렇게 만든 것이다.

그리고 받는 쪽은 아무것도 안 따진다.

```swift
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let type = userInfo["type"] as? String, type == "remoteStopped" {
        handleStopSignal()      // 언제 만들어진 신호인지 안 본다
    }
}
```

워치 앱이 꺼진 채로 아이폰에서 러닝을 끝내면 신호가 큐에 남고, 다음에 워치 앱이 깨어나는 순간 배달된다. 그게 하필 새 러닝을 시작하는 순간이다. 큐는 한 번 배달하면 비워지니 **"재시작하면 멀쩡하다"도 맞아떨어졌다.**

그래서 재현 절차를 만들어 지인에게 부탁했다. 러닝 중 워치를 비행기 모드로 바꾸고, 아이폰에서 종료하고, 비행기 모드를 풀고, 새 러닝을 시작하는 순서였다.

**재현되지 않았다.**

지금 보면 절차 자체가 틀렸다. 비행기 모드를 푸는 순간 워치 앱은 아직 살아있으니 그때 배달되고 끝난다. 새 러닝까지 갈 게 없다. **가설을 검증하는 절차가 가설을 비켜가고 있었다.**

---

### 스플래시가 1.5초 동안 NavigationStack을 막고 있었다

다시 코드를 보다가 스플래시 화면에서 걸렸다.

```swift
struct WatchSplashView: View {
    var body: some View {
        if isActive {
            WatchHomeView()        // NavigationStack 이 이 안에 있다
        } else {
            // 스플래시. 1.5초 뒤에 isActive = true
        }
    }
}
```

**1.5초 동안 `NavigationStack`이 아예 존재하지 않는다.**

<svg viewBox="0 0 420 268" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="워치 앱 콜드 런치에서 스플래시와 내비게이션 스택의 타이밍 비교" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="sa" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
  </defs>

  <text x="0" y="12" font-size="11" fill="#e05c4f" font-family="monospace">수정 전</text>

  <rect x="0" y="22" width="420" height="30" rx="6" fill="none" stroke="#e05c4f" stroke-width="1.2"/>
  <text x="12" y="41" font-size="11.5" fill="#e05c4f" font-weight="600">스플래시 (NavigationStack 없음)</text>
  <rect x="240" y="22" width="180" height="30" rx="6" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="252" y="41" font-size="11.5" fill="currentColor" font-weight="600" opacity=".75">WatchHomeView</text>

  <line x1="0" y1="62" x2="0" y2="76" stroke="currentColor" stroke-width="1" opacity=".35"/>
  <line x1="100" y1="62" x2="100" y2="76" stroke="currentColor" stroke-width="1" opacity=".35"/>
  <line x1="240" y1="62" x2="240" y2="76" stroke="currentColor" stroke-width="1" opacity=".35"/>
  <text x="0" y="88" font-size="9.5" fill="currentColor" opacity=".5" font-family="monospace">t=0 앱 실행</text>
  <text x="86" y="88" font-size="9.5" fill="#e05c4f" font-family="monospace">navigateTo(.pfd)</text>
  <text x="240" y="88" font-size="9.5" fill="currentColor" opacity=".5" font-family="monospace">t=1.5 화면 교체</text>

  <text x="0" y="112" font-size="11.5" fill="#e05c4f">경로만 바뀌고 받아줄 스택이 없다. 이후 화면이 통째로</text>
  <text x="0" y="128" font-size="11.5" fill="#e05c4f">갈아끼워지면서 PFD 가 사라지면 러닝이 끝나버린다.</text>

  <line x1="0" y1="146" x2="420" y2="146" stroke="currentColor" stroke-width="1" opacity=".2"/>

  <text x="0" y="170" font-size="11" fill="#2fa37c" font-family="monospace">수정 후</text>

  <rect x="0" y="180" width="420" height="30" rx="6" fill="none" stroke="#2fa37c" stroke-width="1.4"/>
  <text x="12" y="199" font-size="11.5" fill="#2fa37c" font-weight="600">WatchHomeView (NavigationStack 항상 존재)</text>
  <rect x="0" y="180" width="240" height="30" rx="6" fill="currentColor" opacity=".07"/>
  <text x="252" y="199" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">회색 구간 = 스플래시가 덮고 있음</text>

  <line x1="100" y1="212" x2="100" y2="226" stroke="currentColor" stroke-width="1" opacity=".35"/>
  <text x="86" y="238" font-size="9.5" fill="#2fa37c" font-family="monospace">navigateTo(.pfd)</text>

  <text x="0" y="260" font-size="11.5" fill="#2fa37c">스택이 처음부터 살아있어서 경합 자체가 없다.</text>
</svg>

아이폰이 `startWatchApp(toHandle:)`으로 워치 앱을 깨우면 `AppDelegate.handle()`이 곧바로 워크아웃을 시작하고, 세션이 `.running`이 되면서 `navigateTo(.pfd)`가 불린다. **그게 1.5초 안에 일어나면 받아줄 스택이 없는 상태에서 경로만 바뀐다.**

---

### onDisappear는 누가 나갔는지 모른다

그리고 PFD 화면에 이런 코드가 있었다.

```swift
.onDisappear {
    guard !didNavigateToTouchdown else { return }
    guard HealthKitService.shared.session != nil else { return }
    Task {
        await viewModel.stop()
        HealthKitService.shared.stopWorkout()
        await viewModel.resetState()      // 홈으로
    }
}
```

**"사용자가 PFD에서 뒤로 스와이프하면 러닝을 끝내라"**는 뜻으로 쓴 코드다. 그런데 `onDisappear`는 사용자가 나간 건지 SwiftUI가 화면을 다시 만든 건지 구분하지 못한다. 화면이 통째로 갈아끼워지는 상황에서는 조건 둘 다 통과한다.

**"두 번째 러닝은 멀쩡하다"가 여기서 설명된다.** 두 번째에는 앱이 이미 떠 있어서 스플래시가 안 돌고 화면 교체도 없다. 큐 가설은 우연히 들어맞았는데 이건 구조상 그럴 수밖에 없다.

---

### 고친 것

스플래시를 **화면을 대체하는 것에서 덮개로** 바꿨다.

```swift
// 전
if isActive { WatchHomeView() } else { 스플래시 }

// 후
WatchHomeView()
    .overlay { if !isActive { splash } }
```

한 줄짜리 변경처럼 보이지만 의미가 다르다. **홈 화면은 앱이 켜진 순간부터 계속 살아있고, 스플래시는 그 위를 잠깐 가릴 뿐이다.** 스택이 처음부터 있으니 경로가 언제 바뀌든 받아줄 곳이 있다.

그리고 `onDisappear`에 조건을 하나 더 걸었다.

```swift
guard !viewModel.navigationPath.contains(.pfd) else { return }
```

**경로에 아직 `.pfd`가 남아있다면 사용자가 나간 게 아니라 화면이 다시 만들어진 것이다.** 사용자가 뒤로 스와이프하면 경로에서 빠지니까 그때는 그대로 통과한다.

---

### 아직 확인 못 했다

이건 **코드를 읽고 세운 가설이고 실기기로 확정하지 못했다.** 내 워치에서는 재현되지 않는데, 1.5초 고정 타이머와의 경합이라 기기가 얼마나 빨리 뜨느냐에 달려 있다. 지인은 Series 7이다.

확인할 방법은 하나 생각해뒀다. 이 상황이 실제로 일어났다면 워치 세션이 러닝 시작 몇 초 만에 정상 종료 절차를 타므로, **건강 앱에 몇 초짜리 러닝 기록이 남아 있어야 한다.** 1.3.1은 아이폰이 자기 기록을 따로 저장하니 정상 러닝은 두 건이 비슷한 길이로 남고, 이 경우만 한쪽이 몇 초짜리다. 길이로 구분된다.

다만 남의 건강 앱을 뒤져달라고 하기가 그래서 확인은 미뤄뒀다. **스플래시가 스택을 막고 있는 것과 `onDisappear`로 종료를 판단하는 것은 이 증상과 무관하게 위험한 구조라, 원인 확정을 기다리지 않고 고쳤다.**

---

## 값만 담는 타입이 메인 액터에 묶여 있었다

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

## 남은 것

APPLE WATCH 항목에 아직 구멍이 하나 있다. `isWatchPaired`는 세션 활성화가 끝나야 제대로 된 값을 주는데, 그 활성화가 **비동기라 앱 켜는 즉시 끝나지 않는다.** 그 사이에 화면을 보면 워치가 멀쩡히 페어링돼 있어도 NOT PAIRED가 뜬다.

스플래시가 1초쯤 돌고 홈 화면을 거쳐야 이 화면에 오니까 실제로 걸릴 일은 거의 없다. 그래도 **없는 워치를 없다고 하는 것과, 있는 워치를 없다고 하는 건 다른 문제라** 마저 닫을 생각이다. 활성화가 끝났다고 알려주는 콜백이 지금은 로그만 찍고 있다.

그리고 미러링이 잘 안 된다는 피드백을 따로 받았다. 코드를 보니 아이폰이 미러링됐다고 판단하는 근거가 **"워치 앱을 깨워달라는 요청이 안 튕겼다"**는 것뿐이다. 워치가 실제로 세션을 시작했는지는 확인한 적이 없다. 위에서 고친 스플래시 문제가 그 제보의 정체일 수도 있는데, **워치가 시작을 알려주지 않는 구조 자체는 그대로 남아 있다.** 이건 1.3.3에서 본다.

마지막으로 이 글에 적은 워치 수정 둘은 **아직 실기기에서 확인하지 못했다.** 확인할 것도 정해뒀다. 워치 앱을 완전히 끈 상태에서 아이폰으로 러닝을 시작했을 때 PFD가 뜨고 유지되는지, 그리고 PFD에서 뒤로 스와이프했을 때 러닝이 여전히 끝나는지다. 뒤쪽은 이번에 추가한 조건이 정상 종료까지 막아버리면 곤란해서 같이 본다.
