---
title: RunWay 1.4 (12) 재현 대신 끝까지 편 열한 걸음
writer: Harold
date: 2026-10-06 10:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, HealthKit, OSLog]

toc: true
toc_sticky: true
published: true
---

워치에서 끝냈는데 아이폰이 안 끝나는 문제를 계속 못 잡고 있다. 일곱 번 중 두 번만 나고, 길이로도 조건으로도 선이 안 그어진다.

이쯤 되면 재현으로 잡는 건 운에 기대는 일이다. 다른 길을 하나 택했다. **버튼에서 신호까지 가는 길을 코드로 끝까지 펴보는 것.** 운에 안 기대고, 러닝을 나가지 않아도 된다.

AI 에게 그 구간 전체를 훑어달라고 했다. 사람이 읽으면 이미 아는 곳을 또 읽게 되는데, 처음 보는 쪽은 그냥 한 줄씩 따라간다.

---

## 열한 걸음짜리 체인

버튼을 누르고 아이폰에 신호가 닿기까지 거치는 자리를 전부 세어보니 이렇게 나왔다.

<iframe
  src="/assets/demo/watch_stop_chain.html"
  width="100%"
  height="800px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

위쪽 줄이 정상 경로고 **맨 아래 줄이 조용히 돌아서는 자리**다. 각 상자에 붙은 작은 글자가 지금 찍히는 로그 이름이다.

버튼 하나가 이만큼을 거친다. 중간 어디서 멈춰도 **밖에서는 똑같이 "아무 일도 안 일어난 것"으로 보인다.**

---

## 조용히 돌아서는 네 자리

세 자리는 전에 찾아뒀다. 이번에 훑으면서 하나가 더 나왔고, 그보다 중요한 건 **어디에 흔적이 없는지**가 분명해진 것이다.

### 세션이 없을 때

```swift
func stopWorkout() {
    stopOrigin = .local
    session?.stopActivity(with: Date())
}
```

옵셔널 체이닝이다. 세션이 `nil` 이면 아무 일도 안 하고 그냥 지나간다. 상태 변화 콜백이 없으니 그걸 받아 신호를 보내는 자리도 안 돈다.

로그를 한 줄 넣어뒀었는데 **있다/없다만 적고 있었다.** 세션이 살아는 있지만 이미 끝난 상태면 `stopActivity` 를 불러도 콜백이 안 오는데, 그 경우를 못 가린다. 상태값까지 남기도록 고쳤다.

### 상태가 stopped 로 안 올 때

```swift
if toState == .stopped {
    // 발행
} else if toState == .running {
    // 발행
}
// 그 외는 아무것도 안 한다
```

**이번에 새로 찾은 자리다.** `.ended` 로 바로 넘어가면 어느 갈래에도 안 들어간다. 이벤트가 아예 안 나가고, 종료 신호는 그 이벤트를 받아야 나간다.

두 갈래만 적어두면 나머지는 없는 것처럼 느껴지는데, 실제로는 **나머지로 빠졌을 때 가장 조용하다.**

### 마무리가 안 끝날 때

```swift
if toState == .stopped {
    await finishWatchWorkout(at: date)   // 이게 안 끝나면
    updateAndSendState(event)            // 여기가 영영 안 돈다
}
```

`finishWatchWorkout` 안에는 HealthKit 의 `endCollection` 과 `finishWorkout` 이 들어 있다. 워크아웃을 닫고 건강 앱에 쓰는 일이다.

**긴 러닝일수록 정리할 데이터가 많다.** 길이와 상관이 있으면서 간헐적이라는 성질이 둘 다 맞아떨어지는 유일한 자리다. 지금 가장 유력하게 보고 있다.

### 보내지 않기로 할 때

```swift
if HealthKitService.shared.startOrigin != .local {
    watchConnectivityService.sendStopSignal()
}
```

```swift
guard WCSession.default.activationState == .activated else { return }
```

둘 다 **이른 return 이라 아무 말도 안 남긴다.** 두 번째는 실제로 한 번 걸리는 걸 봤다. 앱이 막 켜진 직후, 세션 활성화가 끝나기 전에 종료를 누른 경우였다.

---

## 열세 개로 늘린 흔적

빈 자리마다 한 줄씩 넣었다. 이제 체인에 끊긴 데가 없다.

```
watch.tapped → watch.saved → stopWorkout → watch.state
  → watch.finishing → watch.finished → watch.published
  → watch.sink → send.message / send.queued / send.notActivated
  → receive → vm.sink → vm.done → pfd.gone
```

**마지막으로 찍힌 줄이 어디서 멈췄는지 가리킨다.** 재현이 되든 안 되든, 나면 그때 잡힌다.

`watch.sink` 는 아이폰의 `vm.sink` 와 같은 이유로 넣었다. 구독이 살아 있는 인스턴스와 화면에 떠 있는 인스턴스가 다르면 여기까지 와도 아무 일이 안 난다. 아이폰 쪽은 그 주소를 찍고 있었는데 워치 쪽은 안 찍고 있었다.

---

## 이렇게 해서 얻은 것

원인은 아직 모른다. 네 자리 중 어디인지도 모르고, 다섯 번째가 없다고 말할 수도 없다.

대신 **"아무 일도 안 일어났다"는 상태가 없어졌다.** 전에는 증상이 나도 받아올 게 없었는데, 이제는 어디까지 갔는지가 남는다.

그리고 훑는 동안 재현을 기다리지 않아도 됐다. 2시간을 걸어서 안 나온 날에도 코드는 읽을 수 있었다.
