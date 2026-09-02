---
title: RunWay 1.3 (3) 워치 단독 러닝 기록이 조용히 사라지던 문제
writer: Harold
date: 2026-08-24 20:00:00 +0900
categories: [RunWay]
tags: [SwiftData, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

워치랑 아이폰을 같이 두고 워치 단독으로 러닝을 했는데, 끝나고 보니 아이폰 로그북에 기록이 안 남아있었다. 오늘 고친 것들이랑은 무관한 문제였지만, 원인을 끝까지 따라가보니 훨씬 오래된 구조적 틈이 있었다.

이 글의 원인 분석과 해결 방향은 AI와 대화하면서 하나씩 짚어나간 과정을 그대로 옮긴 것이다. 특히 뒤에 나오는 "앱이 안 켜져있는데 어떻게 백그라운드에서 저장이 되는지"는 나도 처음엔 잘 안 와닿아서 몇 번을 되물으며 이해했다.

쉽게 비유하면 이렇다. 원래는 기록이 도착해도 "관제탑(HomeView)"이 켜져 있어야만 그걸 받아서 보관함에 넣어주는 구조였다. 관제탑이 꺼져있는 상태(화면이 안 떠있는 상태)에서 도착한 기록은 그대로 흩어져 사라졌다. 그래서 관제탑 유무와 상관없이 도착 즉시 스스로 기록하는 "비행 기록 장치"로 바꿨다.

![](/assets/images/upload/2026-08-24-RunningProject-39/flight-recorder-concept.png)

---

## 전송은 됐는데, 저장이 안 됨

워치가 단독으로 러닝을 끝내면 `WatchConnectivityService+watchOS.swift`의 `sendRunningData()`가 기록을 `transferUserInfo`로 아이폰에 넘긴다.

```swift
// WatchConnectivityService+watchOS.swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard let viewModel, !viewModel.pendingFlightQueue.isEmpty else { return }

    for flight in viewModel.pendingFlightQueue {
        // 생략
        session.transferUserInfo(userInfo)
    }
    viewModel.pendingFlightQueue.removeAll()
}
```

`transferUserInfo`는 `sendMessage`와 달리 시스템이 관리하는 큐라서, 아이폰 앱이 백그라운드거나 잠깐 꺼져 있어도 살아남는다. 여기까진 문제가 없었다.

문제는 아이폰이 이걸 받는 쪽이었다. `WatchConnectivityService+iOS.swift`의 `didReceiveUserInfo`를 보니, 받은 데이터를 SwiftData에 바로 저장하는 게 아니라 `RunViewModel.pendingWatchDataQueue`라는 메모리상의 배열에 담아두기만 했다.

```swift
// before (WatchConnectivityService+iOS.swift)
Task { @MainActor in
    // 생략
    vm?.pendingWatchDataQueue.append(flight)
}
```

이걸 실제로 SwiftData에 써넣는 건 `HomeView`의 화면 생명주기에 맡겨져 있었다.

```swift
// HomeView.swift
.onChange(of: runViewModel.pendingWatchDataQueue) { _, newValue in
    drainPendingWatchData(newValue)
}
.onAppear {
    // pendingWatchDataQueue가 미리 채워져 있을 수 있다. 그 경우 .onChange는 관찰 시작
    // 이전 값이라 못 잡으므로, 여기서 한 번 더 드레인한다.
    drainPendingWatchData(runViewModel.pendingWatchDataQueue)
}
```

즉 "워치→아이폰 전송"과 "아이폰이 그걸 실제로 저장"하는 것 사이에, `HomeView`가 화면에 떠야만 이어지는 틈이 있었다. iOS가 워치 데이터 수신을 처리하려고 앱을 백그라운드에서 잠깐 살렸는데 `HomeView`가 뜨기도 전에 프로세스가 다시 정리되면, `pendingWatchDataQueue`에 담긴 기록은 메모리에만 있다가 그대로 사라진다. 전송 자체는 성공했는데 저장으로 이어지지 못하는 셈이다.

---

## 받는 즉시 저장하도록 변경

처음엔 `WatchConnectivityService`에 `ModelContext`를 직접 심어줄까 했다. 근데 그러면 원래 WatchConnectivity 메시지 송수신만 담당하던 클래스가 `import SwiftData`까지 해가면서 영속성 계층을 알아야 하는 게 이상했다. 통신 담당이 저장 방식까지 알 필요는 없다.

다시 보니 이미 있는 길이 있었다. `RunViewModel`은 View가 아니라 `@Environment(\.modelContext)`에 접근할 수 없어서, 애초에 `HomeView`가 앱 시작 시점에 자기 `modelContext`를 주입해주는 구조였다.

```swift
// RunViewModel.swift (이미 있던 코드)
/// `HomeView`에서 주입되는 SwiftData 컨텍스트.
///
/// `RunViewModel`은 View가 아니라 `@Environment(\.modelContext)`에 접근할 수 없어
/// `HomeView`가 앱 시작 시 자신의 `modelContext`를 여기에 주입해준다.
@ObservationIgnored var modelContext: ModelContext?
```

그리고 `WatchConnectivityService`는 이미 `viewModel: RunViewModel?` 참조를 들고 있다. 새 경로를 만들 필요 없이, 이 기존 참조를 통해 `RunViewModel`한테 저장을 맡기면 됐다.

막상 옮기려고 보니 `HomeView`의 기존 `drainPendingWatchData()`에는 그냥 `insert`만 하는 게 아니라 두 가지가 더 있었다. 같은 세션 id로 이미 저장된 기록이 있으면 건너뛰는 중복 체크, 그리고 저장 후 `RunReminderService`로 리마인더 알림을 다시 스케줄하는 것. 이 두 개를 빼고 옮기면 새 경로가 기존 경로보다 오히려 허술해지는 셈이라 그대로 가져왔다.

```swift
// RunViewModel.swift
/// 워치에서 받은 러닝 기록을 화면 생명주기와 무관하게 즉시 저장한다.
/// `modelContext`가 아직 없는 예외적인 경우엔 `pendingWatchDataQueue`에 담아
/// `HomeView`의 `drainPendingWatchData()`가 안전망으로 처리하게 한다.
func saveIncomingWatchFlight(_ flight: SwiftDataFlight) {
    guard let modelContext else {
        pendingWatchDataQueue.append(flight)
        return
    }
    guard flight.distance >= 0.1 else { return }
    let flightID = flight.id
    var descriptor = FetchDescriptor<SwiftDataFlight>(predicate: #Predicate { $0.id == flightID })
    descriptor.fetchLimit = 1
    guard (try? modelContext.fetch(descriptor).first) == nil else { return }
    modelContext.insert(flight)
    try? modelContext.save()
    RunReminderService.rescheduleFromLatestFlight(modelContext: modelContext)
}
```

```swift
// after (WatchConnectivityService+iOS.swift)
Task { @MainActor in
    // 생략
    vm?.saveIncomingWatchFlight(flight)
}
```

`WatchConnectivityService`는 여전히 SwiftData를 전혀 모른다. 그저 이미 참조하고 있던 `RunViewModel`에게 "이 기록 좀 맡아줘"라고 부탁할 뿐이고, 저장을 어떻게 할지는 전부 `RunViewModel` 안에 있다. `insert` 직후 `save()`를 명시적으로 호출해서 SwiftData의 자동 저장 시점을 기다리지 않고 그 자리에서 디스크에 반영되게 했다. 이러면 적어도 저장 자체가 `HomeView`의 `.onChange`/`.onAppear` 타이밍에 걸리는 일은 없어진다.

![](/assets/images/upload/2026-08-24-RunningProject-39/watch-data-save-flow.png)

정리하면, 저장으로 이어지는 주 통로 자체를 `HomeView`에서 `didReceiveUserInfo` 콜백으로 옮긴 것이다. `HomeView`의 `drainPendingWatchData()`는 지우지 않고 그대로 뒀지만, 이제는 주 통로가 아니라 `modelContext`가 아직 안 붙어있는 예외적인 상황에서만 쓰이는 보조 안전망으로 격하됐다.

---

## `modelContext`는 여전히 `HomeView`에 묶여있었다

여기까지 써두고 다시 읽어보다가 걸리는 부분이 있었다. `vm`(`RunViewModel`)은 `RunWayApp`의 `@State` 프로퍼티라서, 앱 프로세스가 시작되기만 하면(화면이 실제로 안 떠도) `init()`이 돌면서 바로 확보된다. 근데 `modelContext`는 다르다.

```swift
// RunViewModel.swift (이미 있던 코드)
/// `HomeView`에서 주입되는 SwiftData 컨텍스트.
///
/// `RunViewModel`은 View가 아니라 `@Environment(\.modelContext)`에 접근할 수 없어
/// `HomeView`가 앱 시작 시 자신의 `modelContext`를 여기에 주입해준다.
@ObservationIgnored var modelContext: ModelContext?
```

```swift
// HomeView.swift
.onAppear {
    runViewModel.modelContext = modelContext
    // 생략
}
```

`runViewModel.modelContext = modelContext`는 `HomeView`가 실제로 화면에 떠야만(`.onAppear`) 실행된다. iOS가 워치 데이터 수신을 처리하려고 앱을 순전히 백그라운드에서만 깨운 거라면, 윈도우 자체가 뜨지 않은 채로 프로세스만 실행될 수 있다. `.onAppear`는 뷰가 실제 윈도우에 붙어야 발동하지, 앱 프로세스가 시작됐다고 자동으로 발동하지 않는다.

그러면 `vm`은 확보되는데 `vm.modelContext`가 nil인 상태가 될 수 있고, `saveIncomingWatchFlight(_:)`는 `guard let modelContext else { pendingWatchDataQueue.append(flight); ... }` 폴백으로 빠져버린다. 정확히 원래 있던 것과 똑같은 취약점으로 되돌아가는, 하필 제일 중요한 케이스(앱이 완전히 꺼져 있던 경우)에서만 벌어지는 문제다.

`modelContext`도 `vm`과 똑같이, 뷰가 아니라 앱 프로세스가 시작되는 시점에 확보돼야 한다. `RunWayApp.init()`은 이미 그 자리에서 `modelContainer`를 만들고 있으니, 거기서 바로 `RunViewModel`에 심어주면 된다.

```swift
// before (RunWayApp.swift)
init() {
    // 생략
    modelContainer = container
}
```

```swift
// after
init() {
    // 생략
    modelContainer = container
    runViewModel.modelContext = container.mainContext
}
```

`HomeView`의 `runViewModel.modelContext = modelContext` 줄은 지울 필요가 없다. 이제는 그냥 같은 값을 한 번 더 대입하는, 아무 부작용 없는 코드가 됐을 뿐이다. 이러면 `vm`과 `modelContext` 둘 다, 화면이 뜨는지와 완전히 무관하게 앱 프로세스가 시작되는 순간 확보된다.

앱이 완전히 꺼져있던 상태에서 워치가 기록을 보냈을 때, 실제로 어떤 순서로 저장까지 이어지는지 정리하면 이렇다.

![](/assets/images/upload/2026-08-24-RunningProject-39/init-flow.png)

`RunWayApp.init()` 안에서 일어나는 두 줄(`RunViewModel()` 생성, `modelContext` 대입)이 전부 `WCSession.activate()`보다 먼저 끝난다는 게 핵심이다. 그래서 iOS가 `didReceiveUserInfo` 콜백을 부를 시점엔 `vm`과 `modelContext`가 이미 둘 다 준비돼있고, `HomeView`는 이 흐름에 한 번도 등장하지 않는다.

---

## 프로세스가 뭔데 백그라운드에서 저장이 된다는 거지

"iOS가 앱을 백그라운드에서 실행한다"는 말이 처음엔 잘 안 와닿아서 AI한테 몇 번을 되물었다.

설치된 앱은 그냥 저장공간에 들어있는 코드 덩어리일 뿐이다. 이 코드를 메모리에 올려서 실제로 돌아가게 만든 상태를 "프로세스"라고 부른다. 이걸 하는 주체는 유저(아이콘 탭)일 수도, iOS 자신일 수도 있다. iOS는 원래부터 설치된 아무 앱이나 직접 실행시킬 권한을 갖고 있고, 유저가 탭하든 iOS가 알아서 하든 "이 앱을 메모리에 올리고 시작 지점부터 실행해라"라는 명령 자체는 똑같다. 워치 연동만의 특별한 뒷문이 아니라 [Transferring data with Watch Connectivity Docs](https://developer.apple.com/documentation/WatchConnectivity/transferring-data-with-watch-connectivity){:target="_blank"}에도 나오는, `transferUserInfo`가 원래 보장하는 동작이다.

여기서 "앱이 안 켜져있다"를 두 상태로 나눠야 한다.

![](/assets/images/upload/2026-08-24-RunningProject-39/process-states.png)

**백그라운드 정지 상태**라면 사실 오늘 버그와는 상관이 없었다. 프로세스가 메모리에 그대로 남아있으니, `RunViewModel`도 `modelContext`도 예전에(마지막으로 앱을 열었을 때) 이미 다 준비된 채로 얼어있을 뿐이다.

**완전히 종료된 상태**여야만 iOS가 진짜로 프로세스를 처음부터 새로 만들고, `RunWayApp.init()`이 그야말로 처음 실행된다. 이때만 `HomeView`가 단 한 번도 안 뜬 채로 `modelContext`가 비어있을 위험이 실제로 있었다.

그래서 워치와 아이폰을 같이 두고 러닝을 끝내면, 유저가 눈치채지도 못하는 사이에 iOS가 잠깐 프로세스를 띄워 저장까지 끝내버린다. 한참 뒤에 앱을 열면 그 기록이 이미 로그북에 들어있다. 단, 둘이 블루투스로 통신 가능한 거리에 있어야 하고, 정확히 언제 실행될지는 iOS가 배터리/발열 상태를 보고 알아서 정한다.

---

## 정리

| 구분 | 기존 | 개선안 |
|---|---|---|
| 저장으로 이어지는 주 통로 | `HomeView` (화면 생명주기) | `didReceiveUserInfo` 콜백 (수신 즉시) |
| 저장을 트리거하는 것 | SwiftUI `.onChange`/`.onAppear` | 수신 즉시 함수 호출 |
| 실제 저장 로직 위치 | `HomeView` | `RunViewModel.saveIncomingWatchFlight(_:)` |
| `modelContext` 확보 시점 | `HomeView`가 화면에 뜬 뒤 | `RunWayApp.init()`, 앱 프로세스 시작 시점 |
| `WatchConnectivityService`의 책임 | 통신만 담당, SwiftData는 모름 | 통신만 담당, SwiftData는 모름 (변화 없음) |
| 유실 가능성 | 화면이 뜨기 전에 프로세스가 정리되면 유실 | 화면 없이 백그라운드로만 실행돼도 저장됨 |
| `pendingWatchDataQueue`의 역할 | 유일한 저장 통로 | 주 통로 자리에서 밀려나, `modelContext` 미확보 시에만 쓰이는 보조 안전망으로 격하 |

---

## Alerts도 로그북처럼 월별로 정리

이건 버그 수정은 아니고, 기록이 쌓이면서 관리 방식을 손볼 때가 됐다고 느껴서 정리한 부분이다. `AlertsView`는 원래 경고를 날짜 하나로만 묶어서 쭉 나열했는데, 기록이 쌓일수록 스크롤만 길어지는 구조였다.

`LogbookView`는 이미 월 -> 주 단위로 묶고 최신 것만 기본으로 펼쳐두는 방식을 쓰고 있어서, 같은 구조를 그대로 가져왔다. 다만 경고는 러닝 기록만큼 하루에 여러 건씩 쌓이지 않아서 주 단위까지는 필요 없다고 보고, 월 -> 날짜 두 단계로만 묶었다.

```swift
// AlertsView.swift
struct AlertDayGroup: Identifiable {
    let id: String
    let label: String
    let alerts: [SwiftDataAlert]
}

struct AlertMonthGroup: Identifiable {
    let id: String
    let label: String
    let days: [AlertDayGroup]
}
```

펼침/접힘 상태를 기억하는 방식도 `LogbookView`와 똑같이 맞췄다. 유저가 직접 건드리지 않은 그룹은 가장 최신 것만 기본으로 펼쳐진다.

다 붙여놓고 보니 month 카드끼리 간격이 휑하게 보였다. 헤더, 요약 카드와 같은 `VStack(spacing: 10)` 안에 그냥 얹혀있다 보니 그 간격을 그대로 물려받고 있었던 것이다. month 리스트만 따로 `VStack(spacing: 6)`으로 한 번 더 감싸서 그 간격만 줄였다.

---

## 18km 실기기 테스트에서 나온 것

### 정지 중에도 심박은 계속 재는 중이라서

Mission Flight를 심박 기준으로 걸어두고 뛰다가 멈췄더니, 쉬면서 심박이 자연히 내려가는 것만으로 SINK RATE가 떴다.

원인은 페이스와 심박이 서로 다르게 다뤄지고 있었던 것이다. 페이스는 정지 중엔 `lastValidPace`로 값 자체를 얼려두지만, 심박 모드는 `healthCenter.currentHeartRate`를 매번 그대로 읽어서 `determineGPWSStatus`에 넘긴다. 정지했다고 심박 센서가 멈추는 것도 아니라서, 쉬는 동안 떨어지는 심박이 계속 실시간으로 GPWS 판정에 들어갔다.

```swift
// before (RunningCenter.swift)
gpwsStatus = await determineGPWSStatus(pace: rawPace)
```

```swift
// after
if !isStationary {
    gpwsStatus = await determineGPWSStatus(pace: rawPace)
}
```

값을 얼리는 대신, 정지 중엔 판정 자체를 건너뛰고 직전 상태를 그대로 유지하도록 했다. 페이스든 심박이든 똑같이 적용되는 조건이라 모드별로 따로 처리할 필요가 없었다.

이후 실기기로 다시 확인했을 때, 멈춰서 쉬는 동안 심박이 실제로 내려가는데도 SINK RATE가 뜨지 않는 걸 확인했다. 의도한 대로 동작하는 게 실기기에서 검증됐다.

### 배터리는 일단 지켜보기로

같은 테스트에서 워치 배터리가 77%에서 21%까지 떨어졌다. 일반적인 애플워치 GPS 러닝이면 이 정도 거리에서 최소 30% 이상은 남아야 할 것 같다는 이야기가 나왔다.

가장 먼저 의심한 건 이번에 `distanceFilter`를 `5m`에서 `kCLDistanceFilterNone`으로 바꾼 부분이었다. 정지 판단 반응성을 살리려고 오늘 바꾼 값이라 시점도 겹쳤다. 다만 이건 실제로 기기에 연결해서 전력 소모를 재봐야 확실해지는 문제라, 코드만 보고 바로 결론 낼 수는 없었다. 워치 자체의 배터리 효율 저하일 가능성도 있어서, 일단은 그대로 두고 다음 테스트에서 계속 지켜보기로 했다.

이후 워치 설정에서 배터리 성능 상태를 확인해보니 최대 용량이 77%였다. 90% 밑으로 내려가면 효율이 떨어지기 시작하고 80% 언저리부터는 눈에 띄게 나빠진다고 알려져 있는데, 그 기준으로 보면 이미 상당히 열화된 상태다. `distanceFilter` 설정보다는 워치 배터리 자체의 노화가 이번 드레인의 더 유력한 원인으로 보여서, 이 설정은 그대로 두기로 했다.

---

## 러닝 기록 삭제 기능

로그북에서 개별 러닝 기록을 지울 방법이 없었다. v1.4 작업을 하다가 발견한 문제인데, 생각해보니 이건 원래 v1.3에 들어갔어야 할 기본 기능이라 이 브랜치로 옮겨와서 작업했다.

처음엔 Logbook 목록에서 항목을 꾹 눌러(long press) 컨텍스트 메뉴로 삭제하는 방식을 만들었다. 근데 붙여놓고 보니 발견이 잘 안 될 것 같았다. 결국 그 방식은 빼고, 상세 화면(Flight Summary) 헤더의 휴지통 버튼으로만 삭제할 수 있게 정리했다. 방금 끝낸 러닝을 보여주는 화면에서는 이 버튼이 안 뜨고, 로그북에서 들어온 과거 기록 화면에서만 보인다.

```swift
// FlightSummaryView.swift
.customNavHeader("FLIGHT SUMMARY") {
    if !isPostRun, selectedFlight != nil {
        Button {
            showingDeleteConfirmation = true
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.rwRed)
        }
    }
}
```

삭제 확인 창은 처음엔 `.confirmationDialog`로 만들었다. 근데 Logbook의 컨텍스트 메뉴 삭제 버튼을 누른 직후에는, 확인 창이 화면 중앙이 아니라 화살표가 달린 채로 엉뚱한 위치에 떴다. 액션시트 계열이라 팝오버처럼 특정 지점에 앵커링되는 성질이 있어서 그런 것으로 보였다. 여기선 단순히 확인/취소만 물어보면 되니 앵커가 필요 없는 `.alert`로 바꿨더니 항상 화면 정중앙에 뜨는 걸로 정리됐다.

```swift
// before
.confirmationDialog("이 러닝 기록을 삭제할까요?", isPresented: ..., titleVisibility: .visible) {
    // 생략
}

// after
.alert("이 러닝 기록을 삭제할까요?", isPresented: ...) {
    // 생략
}
```
