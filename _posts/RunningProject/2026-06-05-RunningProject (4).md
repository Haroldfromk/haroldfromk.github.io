---
title: RunWay (4) DI + 데이터 흐름
writer: Harold
date: 2026-06-05 07:33:00 +0800
categories: [RunWay]
tags: [DI, MVVM, Observable]

toc: true
toc_sticky: true
published: true
---

## RunViewModel 만들기

현재까지 `LocationService`와 `HealthKitService`를 각각 구현했다.

하지만 View가 이 서비스들을 직접 들고 있으면 데이터 수집과 화면 표시가 한곳에 섞이게 된다.
또한 이후 위치 정보와 HealthKit 데이터를 조합해야 하는 시점이 오면 View에서 처리하기에는 책임이 커지게 된다.
그래서 `RunViewModel`이 두 서비스를 주입받아 데이터를 중간에서 관리하도록 구조를 정리해보려 한다.

다만 Week2에서 `RunningCenter Actor`가 도입되면 데이터 조합, GPS/심박수 처리, FlightPhase 상태 관리 등 대부분의 로직이 Actor로 이동하게 된다. 그때가 되면 `RunViewModel`은 Actor에서 AsyncStream으로 받은 데이터를 View에 노출하는 얇은 계층만 남게 된다.

지금 단계에서는 Actor 없이 서비스를 직접 연결하는 구조로 구성하고, Week2에서 자연스럽게 리팩토링하는 방향으로 진행한다.

---

지금은 TestMapView라는곳에 

```swift
@State private var service = LocationService()
@State private var healthService = HealthKitService()
```

직접적으로 생성해서 받고 있었는데, 이젠 서비스들을 ViewModel로 이관하여 처리를 해보도록 한다.

---

### LocationService 기능 연결

`LocationService`는 이미 `startTracking()`과 `stopTracking()`이 구현되어 있다.

`RunViewModel`에서는 이를 그대로 래핑하여 시작/종료 액션을 담당하도록 한다.

```swift
func start() {
    locationService.startTracking()
}

func stop() {
    locationService.stopTracking()
}
```

아직 위치 데이터 자체는 `LocationService`를 통해 직접 확인하지만, 사용자 액션은 ViewModel을 거치도록 구조를 정리해둔다.

지금은 단순 래핑이지만 View가 Service를 직접 참조하지 않고 ViewModel만 바라보도록 구조를 잡아두는 데 의미가 있다. Week2에서 `RunningCenter Actor`가 도입되면 `start()` 하나로 HealthKit 시작, FlightPhase 전환 등 여러 동작이 자연스럽게 묶이게 된다.

현재 단계에서는 `RunViewModel`이 시작/종료 액션만 담당하고, 위치 데이터는 `LocationService`를 통해 직접 확인한다. 아직 데이터 가공 로직이 없기 때문에 모든 값을 ViewModel로 전달하는 것은 오히려 불필요한 추상화가 될 수 있다.

이후 `RunningCenter Actor`가 도입되면 위치, 심박수, 거리 등의 데이터를 Actor에서 집계하게 되고, 그 시점부터 `RunViewModel`이 View에 필요한 값만 노출하도록 구조를 변경할 예정이다.

그래서 `MapTestView`는 아래와 같이 변경되었다.

```swift
@State private var runViewModel = RunViewModel()
@State private var locationService = LocationService()

// Before
Button { service.startTracking() }
Button { service.stopTracking() }

// After
Button { runViewModel.start() }
Button { runViewModel.stop() }
```

---

#### 문제 해결

`MapTestView`에서 `runViewModel.start()`를 호출해도 로그에 아무것도 출력되지 않는 문제가 발생했다.

원인은 객체가 서로 달랐기 때문이다. `MapTestView`에 `@State private var locationService`가 따로 선언되어 있어서 `runViewModel` 내부의 `locationService`와 전혀 다른 인스턴스였다. 버튼은 `runViewModel.start()`를 호출하지만 로그는 `MapTestView`의 `locationService.logs`를 보고 있으니 당연히 출력이 안 되는 구조였다.

해결 방법은 `MapTestView`의 `@State private var locationService`를 제거하고, `RunViewModel`에서 `locationService`의 프로퍼티를 노출하여 하나의 인스턴스만 사용하도록 수정했다.

```swift
// RunViewModel에 추가
var latitude: Double { locationService.latitude }
var longitude: Double { locationService.longitude }
var accuracy: Double { locationService.accuracy }
var logs: [String] { locationService.logs }
```

이렇게 하면 View는 `runViewModel`만 바라보고, 서비스 인스턴스도 하나로 통일된다.

---

### HealthKitService 기능 연결

`LocationService`와 달리 `HealthKitService`는 지금 단계에서 View에 직접 노출할 실시간 데이터가 없다.

대신 이전에 시뮬레이터에 MockData를 저장한것을 fetch하고 그 결과를 ViewModel 프로퍼티에 저장하고, 
이를 차트로 시각화하는 방식으로 데이터 흐름을 확인해보려 한다.

---

#### Charts를 활용한 Test UI 만들기

우선 ViewModel 연결 전에 하드코딩된 MockData로 UI를 먼저 구성한다.

Swift Charts를 사용하여 일주일치 걸음수를 막대 차트로 표시한다.

[이전글](https://haroldfromk.github.io/posts/HealthKit-(4)/){:target="_blank"}에서도 Charts를 사용했었기에 참고하면 될듯

```swift
Chart(steps, id: \.date) { item in
    BarMark(
        x: .value("Date", item.date, unit: .day),
        y: .value("Steps", item.count)
    )
}
.chartXAxis {
    AxisMarks(values: .stride(by: .day)) {
        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
    }
}
```

이게 기본적인 Bar를 사용한 ChartUI를 구성하는 방법이다.

x, y에 어떤값을 기준으로 할지를 정하고, `chartXAxis` Modifier를 통해 x축에 대해서 간단한 설명을 해주었다.

그리고 view에는 하드코딩으로 임시 데이터를 넣어줬다.

```swift
let steps: [(date: Date, count: Double)] = [
    (Date().addingTimeInterval(-6 * 86400), 4200),
    (Date().addingTimeInterval(-5 * 86400), 5800),
    (Date().addingTimeInterval(-4 * 86400), 3100),
    (Date().addingTimeInterval(-3 * 86400), 6500),
    (Date().addingTimeInterval(-2 * 86400), 4900),
    (Date().addingTimeInterval(-1 * 86400), 5200),
    (Date(), 3800)
]
```

`addingTimeInterval`은 초 단위로 날짜를 더하거나 뺀다. 하루는 86400초이므로 `-6 * 86400`은 6일 전을 의미한다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-4/d21aff4d-146d-4d61-9752-861ea2448898.png" />

---

#### ViewModel 연결 및 실제 데이터 적용

UI가 완성되었기에, 하드코딩된 데이터를 제거하고, ViewModel에서 `fetchStepsCount()`를 호출하여 실제 데이터를 차트에 연결한다.

---

##### HealthKitService 수정

우선 HealthService의 fetchStepCount를 일부 수정한다.

```swift
// Before
func fetchStepsCount() async {
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
    let endDate = Date()
    
    let queryPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
    let sameplePredicate = HKSamplePredicate.quantitySample(type: HKQuantityType(.stepCount), predicate: queryPredicate)
    
    let stepsCountQuery = HKStatisticsCollectionQueryDescriptor(predicate: sameplePredicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: .init(day: 1))
    
    let stepsCount = try! await stepsCountQuery.result(for: store)
    
    for steps in stepsCount.statistics() {
        let value = steps.sumQuantity()?.doubleValue(for: .count()) ?? 0
            print("👟 Steps: \(value) 보 / \(steps.startDate)")
    }
}
// After
func fetchStepsCount() async -> [(date: Date, count: Double)] {
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
    let endDate = Date()
    
    let queryPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
    let samplePredicate = HKSamplePredicate.quantitySample(type: HKQuantityType(.stepCount), predicate: queryPredicate)
    
    let stepsCountQuery = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: .init(day: 1))
    
    let stepsCount = try! await stepsCountQuery.result(for: store)
    
    return stepsCount.statistics().map { steps in
        let value = steps.sumQuantity()?.doubleValue(for: .count()) ?? 0
        return (date: steps.startDate, count: value)
    }
}
```

이전에는 값을 단순히 프린트하여 데이터가 제대로 들어오는지만 확인했다. 이제는 그 값을 차트에 보여줘야 하기 때문에 반환하도록 수정한다.

```swift
return stepsCount.statistics().map { steps in
    let value = steps.sumQuantity()?.doubleValue(for: .count()) ?? 0
    return (date: steps.startDate, count: value)
}
```

`map`을 통해 각 통계 구간의 시작 날짜와 걸음수를 튜플로 묶어 배열로 반환하는 구조이다.

---

##### ViewModel 적용

```swift
var stepDateData = [(date: Date, count: Double)]()

func getSteps() async {
    stepDateData = await healthService.fetchStepsCount()
}   
```

fetch한 결과를 담을 프로퍼티와 그것을 호출하는 함수만 만들어주었다. `stepDateData`가 바뀌면 `@Observable`에 의해 View가 자동으로 업데이트된다.

---

##### View에 적용

```swift
struct StepChartView: View {
    
    @State private var runViewModel = RunViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 생략
            Chart(runViewModel.stepDateData, id: \.date) { item in
               // 생략
            }
            // 생략
        }
        .task {
            await runViewModel.getSteps()
        }
    }
}
```

하드코딩된 데이터를 제거하고 `runViewModel.stepDateData`를 차트에 연결했다. `.task` modifier로 뷰가 나타날 때 자동으로 fetch가 실행된다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-05-RunningProject-4/bbce60f9-5947-4a46-ae5a-8e58c6f5aa5f.png" />

이렇게 값을 가져와서 chart에 그려주는걸 알 수 있다.

---

## 현재 구조의 한계와 앞으로의 방향

현재 `RunViewModel`은 서비스를 단순 래핑하는 수준에 머물러 있다. 이 과정에서 몇 가지 미결 사항이 남았다.

**현재 문제점**
- `locationService`의 위치 데이터 프로퍼티 노출 방식 미결정
- `HealthKitService` 연결이 `stepCounts` fetch 외에 미구현
- 각 View에서 서비스를 따로 생성 중 → 동일 인스턴스 공유 안 됨 (environment 주입 필요)

**Week2에서 이어서 해야 할 것**
- `RunningCenter Actor` 도입 후 데이터 조합, GPS/심박수 처리, FlightPhase 상태 관리 등 대부분 로직 이전
- `RunWayApp.swift`에서 단일 인스턴스 생성 후 environment로 내려보내는 구조 확정
- 실제 UI와 연결하면서 ViewModel 역할 구체화

지금 단계에서 억지로 구조를 완성하려 하면 오버엔지니어링이 될 수 있다. Week2에서 실제 UI와 Actor가 붙으면서 자연스럽게 채워지는 구조로 가는 것이 맞다고 판단했다.