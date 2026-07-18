---
title: RunWay (28) 워치 단독 러닝 문제
writer: Harold
date: 2026-07-17 11:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, watchOS]

toc: true
toc_sticky: true
published: true
---

갑자기 문득 생각해보니 항상 워치 테스트할때는 기록을 해야해서 핸드폰을 같이 들고 다녔다. 그러다보니 워치 단독으로 러닝했을때의 시점은 정확하게 체크가 된것이 아니었다.

그래서 아이폰은 집에 두고 워치만 차고 마트에 갔다. 가는 길에 한 번, 오는 길에 한 번, 러닝을 두 번 따로 종료했다. 집에 와서 앱을 켜봤는데 Logbook에 아무 기록도 없었다.

## 원인

### 1. isReachable 가드로 인한 데이터 미전달

`WatchConnectivityService+watchOS.swift`의 `sendRunningData()`를 보면 이렇게 되어 있었다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    guard let flight = viewModel?.pendingFlightData else { return }
    ...
    session.transferUserInfo(userInfo)
}
```

`transferUserInfo`는 원래 아이폰이 연결되어 있지 않아도 큐에 쌓아뒀다가 나중에 전달하는 API다. 함수 위에 달린 주석도 그렇게 적혀 있었다. 그런데 정작 코드에는 `session.isReachable`을 체크하는 가드가 있었다. 아이폰이 당장 연결 안 돼 있으면 `transferUserInfo` 자체를 호출조차 안 하고 그냥 리턴하는 구조였던 거다. 마트에 가느라 아이폰과 거리가 멀어진 시점이 정확히 이 조건에 걸렸다.

---

### 2. 새 기록이 이전 기록을 덮어쓰는 구조

두 번째 문제는 `pendingFlightData`가 배열이 아니라 단일 값이었다는 것. `resetState()`가 러닝이 끝날 때마다 이 값을 무조건 새 기록으로 덮어썼다.

```swift
var pendingFlightData: SwiftDataFlight? = nil
```

이 두 개가 겹치니까, 아이폰이 안 잡힌 채로 러닝을 두 번 하면 첫 번째 기록은 전송 시도도 못 하고 두 번째 기록에 덮어써져 사라지고, 두 번째 기록도 마지막에 아이폰이 여전히 안 잡혀 있으면 그대로 유실되는 구조였다.

물론 이 문제는 `isReachable`이 해결되었을때 나타났을 문제였을테지만, 관련 코드를 보면서 이상하다고 생각하여 보다가 발견을 하게 되었다.

---

## 수정

`pendingFlightData`를 배열(`pendingFlightQueue`)로 바꿔서 여러 기록이 쌓일 수 있게 하고, `isReachable` 가드를 없애서 `transferUserInfo`가 항상 호출되도록 했다. 큐는 전송을 마친 뒤에만 비운다.

```swift
// WatchVM
var pendingFlightQueue: [SwiftDataFlight] = []

// WatchConnectivityService+watchOS
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard let viewModel, !viewModel.pendingFlightQueue.isEmpty else { return }

    for flight in viewModel.pendingFlightQueue {
        // ... userInfo 구성은 기존과 동일
        session.transferUserInfo(userInfo)
    }
    viewModel.pendingFlightQueue.removeAll()
}
```

덤으로 하나 더 발견했다. 전송하는 JSON의 `date` 필드가 `flight.date`(실제 러닝 날짜)가 아니라 `Date()`(전송하는 시점)로 찍히고 있었다. 

지금까지는 러닝 끝나고 거의 바로 전송됐으니 두 값이 비슷해서 티가 안 났는데, 이제 지연 전송이 정상 시나리오가 된 이상 이것도 같이 고쳤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-28/sum.png){: width="50%" height="50%"}

---

### 하지만 아직 남아있는 문제

이 수정은 워치 앱이 러닝 사이사이 계속 떠 있는 걸 전제로 한다. `pendingFlightQueue`가 메모리에만 있는 배열이라, 워치 앱을 완전히 강제 종료했다가 다시 켜면 그사이 안 보낸 기록은 여전히 사라진다. 일단 이번에 실제로 겪은 상황(앱은 안 껐고 그냥 폰이 멀리 있었던 경우)은 해결됐지만, 이 부분은 그대로 남아있다.

처음엔 App Group으로 아이폰과 SwiftData 저장소를 아예 공유해버리면 이 문제 자체가 사라지지 않을까 싶었다. 워치가 `transferUserInfo`로 넘기는 대신 공유 저장소에 바로 쓰면 "전송"이라는 개념이 필요 없어질 테니까. 근데 검색결과 [Reddit](https://www.reddit.com/r/iOSProgramming/comments/1q63t1l/help_watchos_complication_cant_read_app_group/){:target="_blank"}에 이런내용이 있어서, AI에게 물어보니 App Group은 같은 기기 안에서 앱과 익스텐션(위젯 등)이 샌드박스를 공유하는 장치였다.

워치 앱과 아이폰 앱은 물리적으로 다른 기기에서 도는 별개의 프로세스라, 같은 App Group ID를 써도 각자 자기 기기 디스크에 따로 컨테이너가 생긴다. 이름만 같을 뿐 서로 다른 파일이라 동기화가 안 되는 거였다.

결국 기기 간 데이터 전달은 WatchConnectivity 아니면 CloudKit(iCloud 동기화)로만 가능하다는 얘기다. 
이 한계를 제대로 고치려면 `pendingFlightQueue`를 메모리 배열이 아니라 워치 자체 로컬 디스크에 저장해두고, `sendRunningData()`가 거기서 아직 안 보낸 기록만 조회해서 보내는 방식으로 바꿔야 할 것 같다. 이건 다음에 꼭 필요로 한다면 고치는 걸로....

`sendMessage`/`transferUserInfo`를 처음 붙였던 [이전글](https://haroldfromk.github.io/posts/RunningProject-(12)/){:target="_blank"}에서는 이 둘의 차이를 "즉시 전달 vs 큐 기반 전달"로만 정리하고 넘어갔었는데, `isReachable` 가드 하나가 그 구분 자체를 무의미하게 만들 수 있다는 걸 이번에 제대로 확인했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-28/sum1.png){: width="50%" height="50%"}