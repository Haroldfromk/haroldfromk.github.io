---
title: RunWay (22) Critical Issue 해결하기
writer: Harold
date: 2026-07-05 11:33:00 +0900
#last_modified_at: 2026-07-03 11:33:00 +0900
categories: [RunWay]
tags: [HealthKit, CoreLocation, WeatherKit, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

App Store 심사를 기다리는 동안에도 야외 테스트는 계속 돌리고 있다. 마트 가는 길에 잠깐 뛰어보다가, 미러링 관련해서 방향에 따라 증상이 다르게 나타나는 버그를 발견했다.

## 빌드 전 - 앱 주도 미러링

iPhone에서 러닝을 시작해서 Watch로 미러링하는 상황에서 두 가지 문제가 나왔다.

1. Watch에서 location을 제대로 receive 못하는 건지, WatchPFD에 표시가 안 됨
2. 앱에서 러닝을 종료해도 Watch에서 같이 종료가 안 됨

## 빌드 후 (코드 수정 없음) - 워치 주도 미러링

코드는 하나도 안 건드리고 재빌드만 했는데, 위 두 문제는 사라졌다. 대신 이번엔 반대로 Watch 주도 미러링에서 새 증상이 나타났다.

1. startTracking이 안 된 건지 location이 아예 안 됨
2. avgPace가 `--'--"`로 표시됨

코드 변경 없이 재빌드만 했는데 증상이 완전히 다른 방향으로 옮겨간 게 이상했다. 특정 방향에 고정된 버그라기보다는, 매번 다른 쪽이 걸리는 레이스 컨디션에 가깝다는 심증이 들었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3987.png){: width="50%" height="50%"}

## 워치주도 미러링 원인 추적

`updatePhase(.cruise)`를 열어보니 `startOrigin = .local` 대입이 `Task { }` 안에 있었다.

```swift
case .cruise:
    Task {
        // 생략
        HealthKitService.shared.startOrigin = .local
        try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
    }
```

문제는 이 함수를 호출하는 쪽 코드가 이렇게 붙어있다는 거다.

```swift
viewModel.updatePhase(.cruise)
viewModel.start()
```

`updatePhase(.cruise)`는 `Task`를 스케줄만 하고 바로 리턴하니까, 다음 줄 `start()`가 실행되는 시점에 `startOrigin`이 아직 `.local`로 세팅되기 전일 수 있다. 그런데 `start()`는 이 값을 한 번, 동기적으로만 체크한다.

```swift
func start() {
    ...
    if HealthKitService.shared.startOrigin == .local {
        locationService.startTracking()
    }
}
```

이 체크가 실패하면 `locationService.startTracking()`이 그 러닝 내내 한 번도 호출되지 않는다. Watch에서 겪은 "location이 아예 안 됨" 증상이 정확히 이거였다.

그런데 `updatePhase()`도, 호출 순서(`updatePhase(.cruise)` -> `start()`)도 iPhone과 Watch가 토씨 하나 안 다르다. 그러면 왜 iPhone은 멀쩡했을까.

답은 `start()`가 실제로 하는 일이 서로 다르다는 데 있었다. iPhone의 `start()`는 이미 `locationService.startTracking()` 호출을 갖고 있지 않다. 이건 며칠 전 TakeoffView에 Pre-flight Check를 붙이면서 `prepareTracking()`을 따로 뺐기 때문이다. TakeoffView에 진입하는 순간(`.task`) `startOrigin`과 무관하게 GPS를 미리 켜두고, 카운트다운이 끝나 `start()`가 불릴 때는 이미 GPS가 돌고 있는 상태라 이 레이스에 걸릴 일이 없었던 거다.

Watch는 이 사전 준비 단계가 없어서, `start()`가 여전히 그 순간의 `startOrigin` 값에 의존하고 있었고, 그래서 레이스에 그대로 노출됐다.

## 해결

두 가지 수정 방향이 있었다. 하나는 Watch에도 iPhone처럼 `prepareTracking()` 패턴을 도입해서 카운트다운 화면에서 GPS를 미리 켜두는 것. 다른 하나는 `updatePhase()` 안의 `startOrigin = .local` 대입을 `Task` 밖으로 빼서 레이스 자체를 없애는 것.

전자로 가기로 했다. 어차피 iPhone도 원래 이 패턴이었는데 Watch만 예외로 남아있던 거라, 이번 기회에 두 플랫폼 아키텍처를 다시 맞추는 게 낫다고 판단했다.

`start()` 안에 있던 GPS 시작 로직을 떼어내서, `updatePhase(.cruise)`와 무관하게 미리 호출할 수 있는 별도 함수로 뺐다.

```swift
func prepareTracking() {
    locationService.startTracking()
}

func start() {
    isRunning = true
    isPaused = false
    lastReceivedTime = .now

    //생략
}
```

`start()`가 더 이상 `startOrigin`을 확인하지 않는다. GPS를 켤지 말지는 이미 `prepareTracking()` 시점에 끝난 일이고, `start()`는 타이머만 신경 쓰면 된다. 레이스 컨디션이 발생할 자리 자체가 없어진 셈이다.

취소 시 GPS를 정리할 함수도 하나 추가했다. iOS의 `stopTracking()`과 이름과 역할을 맞췄다.

```swift
/// `WatchTakeoffView`에서 ROTATE 없이 이탈 시 위치 추적을 중단한다.
func stopTracking() {
    locationService.stopTracking()
}
```

`WatchTakeoffView`에는 `didStartFlight` 플래그를 하나 추가했다. ROTATE를 눌러서 정상적으로 러닝을 시작한 건지, 아니면 카운트다운 도중에 크라운으로 빠져나간 건지를 구분하기 위해서다.

```swift
@State private var countdownActive = false
@State private var countdownValue = 3
@State private var didStartFlight = false
```

뷰가 나타날 때 GPS를 미리 켜고, 사라질 때는 `didStartFlight`가 `false`일 때만(즉 정상적으로 러닝을 시작하지 않고 나갔을 때만) GPS를 끈다.

```swift
.navigationBarHidden(true)
.task {
    viewModel.prepareTracking()
}
.onDisappear {
    if !didStartFlight {
        viewModel.stopTracking()
    }
}
```

ROTATE 카운트다운이 끝나는 시점에 `didStartFlight = true`를 세팅해서, 그 이후에 뷰가 사라지는 건 "정상적으로 PFD로 넘어간 것"이라고 표시해준다.

```swift
} else {
    countdownActive = false
    viewModel.updatePhase(.cruise)
    viewModel.start()
    didStartFlight = true
    viewModel.navigateTo(.pfd)
}
```

이렇게 하면 `updatePhase(.cruise)` -> `start()`로 이어지는 순서는 그대로 두면서도, `start()`가 더 이상 그 사이의 타이밍에 의존하지 않게 된다. iOS와 동일한 구조가 됐으니, 앞으로 두 플랫폼 코드를 나란히 놓고 봐도 헷갈릴 일이 줄어들 것 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/watch.png){: width="50%" height="50%"}

---

## 평균페이스 --:-- 문제 원인 추적

이렇게 나오는 문제는 아래 스샷을 보면 알듯 집에서 기기 연동 테스트를 하면서 거리가 0이었기에 페이스 자체도 --:-- 으로 계산을 할 수 없는 값이 저장 되었기 때문이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3988.png){: width="50%" height="50%"}

이렇게 확신을 할 수 있었던 이유는

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3989.png){: width="50%" height="50%"}

이렇게 순수하게 데이터를 가져왔을때는 계산이 정상적으로 되기 때문이다.

코드를 열어보니 원인이 명확했다. PFD 화면에 실시간으로 뜨는 페이스에는 이미 방어 코드가 있었다.

```swift
var avgPace: String {
    guard runViewModel.elapsedTime > 0, runViewModel.flightData.distance > 0 else { return "--'--\"" }
    let avg = (Double(runViewModel.elapsedTime) / 60) / (runViewModel.flightData.distance / 1000)
    guard avg.isFinite && avg > 0 else { return "--'--\"" }
    ...
}
```

근데 정작 SwiftData에 저장하는 함수 `saveRunningData()`에는 이 가드가 빠져 있었다.

```swift
func saveRunningData() async {
    let totalDistance = runViewModel.flightData.distance / 1000
    let totalTime = runViewModel.elapsedTime
    let totalPace = (Double(totalTime) / 60) / totalDistance
    ...
}
```

거리가 0이면 `totalPace`는 0으로 나누기라 `inf`가 나온다. 화면에는 가드 덕분에 `--'--"`로 멀쩡하게 보였지만, 저장은 그 가드를 거치지 않은 `inf` 값으로 그대로 됐던 거다. 그러니까 화면만 보고는 이상한 걸 눈치챌 수가 없었다.

이 `inf`가 진짜 문제가 되는 건 월별/주간 평균을 계산할 때다.

```swift
private var monthAvgPace: String {
    let monthFlights = flights.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    guard !monthFlights.isEmpty else { return "--'--\"" }
    let avgPace = monthFlights.reduce(0.0) { $0 + $1.pace } / Double(monthFlights.count)
    return PaceFormatter.format(avgPace)
}
```

`inf`가 하나라도 섞여서 `reduce`로 더해지는 순간, 나머지가 다 정상 값이어도 합계 자체가 `inf`가 되어버린다. 그래서 이번 달 평균 전체가 `--:--`(사실상 `inf`)로 나왔던 거다.

## 해결

세 군데를 고쳤다. 저장 시점, 집계 시점, 그리고 이미 저장된 값 순서로 하나씩 짚어봤다.

먼저 저장 시점에 0으로 나누는 걸 막았다. 화면에 뜨는 값만 방어하고 정작 저장되는 값은 그대로 뒀던 게 이번 문제의 시작이었으니, 여기부터 고치는 게 순서였다.

```swift
// saveRunningData
let totalDistance = runViewModel.flightData.distance / 1000
let totalTime = runViewModel.elapsedTime
let rawPace = (Double(totalTime) / 60) / totalDistance
let totalPace = rawPace.isFinite ? rawPace : 0
```

`totalDistance`가 0이면 `rawPace`는 `inf`가 된다. `Double`은 0으로 나눠도 크래시가 안 나고 그냥 `inf`나 `nan`을 반환해버리기 때문에, 이 값이 조용히 SwiftData까지 흘러들어가는 게 문제였다. `isFinite`로 한 번 걸러서, 계산이 불가능한 상황이면 `inf`나 `nan` 대신 `0`을 저장하도록 했다. `0`으로 저장해두면 나중에 화면이나 집계 쪽에서 "이 세션은 페이스 계산이 안 됐다"고 판단하기도 더 쉽다.

Watch 쪽 `WatchPFDView.swift`에도 완전히 같은 계산식이 그대로 있었다. iPhone만 고치고 넘어갔으면 똑같은 문제가 워치 단독 러닝에서도 재현됐을 거라, 여기도 동일하게 가드를 추가했다.

집계 계산에도 방어를 하나 더 걸었다. 이미 저장된 `inf` 레코드가 있을 수 있어서, 여기서도 한 번 걸러줘야 한다.

```swift
// FlightCalendarView
private var monthAvgPace: String {
    let monthFlights = flights.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    let validFlights = monthFlights.filter { $0.pace.isFinite && $0.pace > 0 }
    guard !validFlights.isEmpty else { return "--'--\"" }
    let avgPace = validFlights.reduce(0.0) { $0 + $1.pace } / Double(validFlights.count)
    return PaceFormatter.format(avgPace)
}
```

마지막으로 이미 박혀있는 `inf` 레코드가 몇 개나 되는지 확인해봤다. `LogbookView`에 `@Environment(\.modelContext) private var modelContext`를 선언하고, `.task`에서 전체 레코드를 훑어봤다.

```swift
// LogbookView
@Environment(\.modelContext) private var modelContext

.task {
    let descriptor = FetchDescriptor<SwiftDataFlight>()
    if let allFlights = try? modelContext.fetch(descriptor) {
        let corrupted = allFlights.filter { !$0.pace.isFinite || $0.distance == 0 }
        print("망가진 레코드 수: \(corrupted.count)")
    }
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3992.png){: width="50%" height="50%"}

현재 내 앱 기준으로 망가진 레코드는 총 14개가 나온 상태였다. 기기 연동 테스트하면서 쌓인 레코드라 실사용 데이터는 아니었고, 지우는 쪽으로 정리했다.

```swift
.task {
    let descriptor = FetchDescriptor<SwiftDataFlight>()
    if let allFlights = try? modelContext.fetch(descriptor) {
        let corrupted = allFlights.filter { !$0.pace.isFinite || $0.distance == 0 }
        for flight in corrupted {
            modelContext.delete(flight)
        }
        try? modelContext.save()
        print("\(corrupted.count)개 삭제 완료")
    }
}
```

`delete()`만으로는 바로 반영되지 않을 수 있어서 `save()`까지 명시적으로 호출했다. 실행 후 다시 확인해보니 망가진 레코드 수가 0으로 나왔고, `monthAvgPace`/`weeklyAvgPace`도 정상적으로 계산됐다. 이 코드는 일회성 정리용이라 확인 끝나고 바로 지웠다.

이제는 잘 되는걸 알 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3991.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/pacedone.png){: width="50%" height="50%"}

---

## 또 다른 문제, 러닝 바로 종료시 페이스 튐 문제

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/IMG_3993.png){: width="50%" height="50%"}

집에서 다시 테스트하며 앱에서 러닝을 바로 종료를 해보니 페이스가 엄청나게 튀는 문제를 발견했다.

그리고 그건 아래와 같이 모든 데이터를 오염시키기 시작했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/paceerror.png){: width="50%" height="50%"}

`saveRunningData()`의 계산식은 지난번 그대로다.

```swift
// saveRunningData
let totalDistance = runViewModel.flightData.distance / 1000
let totalTime = runViewModel.elapsedTime
let rawPace = (Double(totalTime) / 60) / totalDistance
```

몇 초 만에 바로 종료하면 `totalTime`도 몇 초, `totalDistance`도 GPS가 한두 번 찍힌 수준(몇 미터)이라 시간 대비 거리가 극단적으로 작다. 이 나눗셈 결과가 수백~수천 min/km로 튀는데, 지난번 고친 `isFinite` 체크는 이걸 못 잡는다. `inf`가 아니라 그냥 아주 큰 유한값이기 때문이다. 그 값 하나가 차트 평균 계산에 그대로 들어가면서 축 전체가 눌려버린 게 이번 문제였다.

## 해결

가장 근본적인 해결은 애초에 몇 미터짜리 기록을 유효한 러닝으로 취급하지 않는 것이다. 최소 거리 기준을 하나 두기로 했다.

```swift
let totalDistance = runViewModel.flightData.distance / 1000
let totalTime = runViewModel.elapsedTime
let minimumValidDistance = 0.05 // km, 약 50m 미만은 유효한 러닝으로 보지 않음
let rawPace = (Double(totalTime) / 60) / totalDistance
let totalPace = (rawPace.isFinite && totalDistance >= minimumValidDistance) ? rawPace : 0
```

`WatchPFDView.swift`에도 완전히 같은 계산식이 있었으니 똑같이 적용했다.

집계 쪽도 `isFinite`만으로는 부족해서, 사람이 뛸 수 있는 현실적인 페이스 범위로 상한선을 하나 더 걸었다. 30min/km면 시속 2km 수준이라 거의 걷는 것보다 느린 속도인데, 정상적인 러닝 기록에서는 나올 수 없는 값이라 이 정도를 상한선으로 잡았다.

```swift
private var monthAvgPace: String {
    let monthFlights = flights.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    let validFlights = monthFlights.filter { $0.pace.isFinite && $0.pace > 0 && $0.pace < 30 }
    guard !validFlights.isEmpty else { return "--'--\"" }
    let avgPace = validFlights.reduce(0.0) { $0 + $1.pace } / Double(validFlights.count)
    return PaceFormatter.format(avgPace)
}
```

이미 저장된 레코드 중에도 이번 케이스로 오염된 게 있어서, 지난번 정리 스크립트에 조건을 하나 추가해서 같이 지웠다.

```swift
.task {
    let descriptor = FetchDescriptor<SwiftDataFlight>()
    if let allFlights = try? modelContext.fetch(descriptor) {
        let corrupted = allFlights.filter { !$0.pace.isFinite || $0.distance == 0 || $0.pace > 30 }
        for flight in corrupted {
            modelContext.delete(flight)
        }
        try? modelContext.save()
        print("\(corrupted.count)개 삭제 완료")
    }
}
```

이번에 겪은 두 문제(`inf`, 비정상적으로 큰 값)는 결국 같은 원인에서 갈라져 나온 것이었다. 화면에 보이는 값과 저장되는 값이 서로 다른 가드를 갖고 있었고, 저장 쪽 가드가 허술했던 게 문제였다. 

앞으로 페이스 관련 계산을 추가할 땐 "화면에 안 보이면 괜찮다"가 아니라 "저장되는 값 자체가 안전한가"를 먼저 확인해야겠다는 생각이 들었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-05-RunningProject-22/image11.png){: width="50%" height="50%"}