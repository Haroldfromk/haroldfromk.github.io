---
title: RunWay (8) SwiftData 연동
writer: Harold
date: 2026-06-09 08:33:00 +0900
categories: [RunWay]
tags: [SwiftData, SwiftUI, Actor]

toc: true
toc_sticky: true
published: true
---

## SwiftData 사용하기

러닝 기록을 저장하기 위해 CoreData와 SwiftData를 고민하다가 SwiftData를 선택했다.

가장 큰 이유는 SwiftData가 CoreData를 개선한 방식이기도 하지만, 모델링이 편하다는 장점도 있다. `@Model`만 붙여주면 되기 때문이다.

물론 Xcode에서 CoreData → SwiftData 마이그레이션을 제공하긴 하지만, 신규 프로젝트에서 굳이 마이그레이션을 거칠 이유가 없다고 판단했다.

---

## 모델 설계

러닝 기록을 저장하기 위한 모델을 설계한다.

러닝 전체 데이터를 담는 `Flight`와 GPWS 경고 이력을 담는 `Alert`다. `Alert`를 `Flight` 안에 포함시키는 이유는 간단하다. 어떤 러닝에서 어떤 페이스 경고가 발생했는지를 한 번에 확인하기 위해서다. 러닝 기록을 보면서 그날 경고도 같이 볼 수 있어야 하니까.

다만 SwiftData는 `@Model`을 `class`에만 적용할 수 있어, 기존 `struct` 기반 모델과는 별도로 class 모델을 새로 만들었다.

---

### Flight

러닝 한 세션의 전체 데이터를 담는 모델이다. 거리, 시간, 페이스, 심박수, 케이던스, 칼로리, 날짜와 함께 경고 이력(`alerts`)과 GPS 경로(`coordinates`)를 포함한다.

```swift
@Model
class SwiftDataFlight {
    var id: UUID
    var mode: String       
    var distance: Double    
    var time: Int           
    var pace: Double       
    var heartRate: Int      
    var cadence: Int        
    var fuel: Int           
    var date: Date
    
    @Relationship(deleteRule: .cascade) var alerts: [SwiftDataAlert] = []
    @Relationship(deleteRule: .cascade) var coordinates: [SwiftDataCoordinate] = []
    
    init(mode: String, distance: Double, time: Int, pace: Double, heartRate: Int, cadence: Int, fuel: Int, date: Date) {
        self.id = UUID()
        self.mode = mode
        self.distance = distance
        self.time = time
        self.pace = pace
        self.heartRate = heartRate
        self.cadence = cadence
        self.fuel = fuel
        self.date = date
    }
}
```

---

### Alert

GPWS 경고 발생 시 자동 저장되는 모델이다. 경고 종류, 발생 시각, 당시 페이스, 누적 거리, GPS 좌표를 저장한다. 

`SwiftDataFlight`와 연결되며 Flight 삭제 시 경로 좌표도 함께 삭제된다.

```swift
@Model
class SwiftDataAlert {
    var id: UUID
    var gpwsState: String   // "sinkRate" / "overspeed" / "minimums"
    var pace: Double        // min/km
    var distance: Double    // km
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    
    init(gpwsState: String, pace: Double, distance: Double, timestamp: Date, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.gpwsState = gpwsState
        self.pace = pace
        self.distance = distance
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }
}
```

---

### Coordinates

러닝 경로 전체의 GPS 좌표를 저장하는 모델이다. 러닝 중 위치가 업데이트될 때마다 누적되며 `order`로 순서를 보장한다.

좌표 배열을 `SwiftDataFlight`에 직접 넣지 않고 별도 모델로 분리한 이유는 좌표 수가 러닝 시간에 따라 수백~수천 개까지 늘어날 수 있기 때문이다. 하나의 모델에 담기엔 부담이 크고, `@Relationship`으로 연결하면 필요할 때만 불러올 수 있어 더 효율적이다.

그리고 기존 `RunningCentor`에서 좌표를 튜플 배열 `[(latitude: Double, longitude: Double)]`로 관리하고 있는데, SwiftData는 튜플을 직접 저장할 수 없어 별도 모델로 전환하게 되었다.

`SwiftDataFlight`와 연결되며 MapPolyline 경로 표시에 사용된다.

```swift
@Model
class SwiftDataCoordinate {
    var latitude: Double
    var longitude: Double
    var order: Int
    
    init(latitude: Double, longitude: Double, order: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.order = order
    }
}
```

---

## Container 추가하기

가장 중요한 과정이다 CoreData사용할때 NSPersistentContainer를 추가하는것과 같은 맥락이다.

다만 그때는 기존에 완성된 코드를 사용하곤 했는데, SwiftData는 그것보단 훨씬 간단하다.

```swift
import SwiftData

@main
struct RunWayApp: App {
    
    @State private var runViewModel = RunViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // 생략
            }
            .environment(runViewModel)
            .modelContainer(for: [SwiftDataAlert.self, SwiftDataCoordinate.self, SwiftDataFlight.self])
        }
    }
}
```

`SwiftData`를 import하고, 사용할 모델이 여러 개이므로 배열로 한 번에 등록했다.

모델이 여러 개일 때 `.modelContainer`를 중복으로 사용하면 크래시가 발생할 수 있어 반드시 배열로 한 번에 등록해야 한다. [Apple Developer Forums](https://developer.apple.com/forums/thread/744316){:target="_blank"}에서도 같은 문제가 보고되어 있다.

---

## GPWS 경고 자동 저장

처음에는 `RunningCentor`의 `processLocation`에서 GPWS 상태를 감지하기 때문에 여기서 바로 저장하는 것을 고려했다.

하지만 Actor에서 직접 SwiftData `ModelContext`를 쓰려면 `@MainActor` 격리 문제가 생긴다. 

Actor는 자체 격리 영역에서 동작하고, SwiftData의 `ModelContext`는 `@MainActor` 위에서 동작하기 때문에 서로 직접 접근할 수 없다.

그래서 저장은 View에서 담당한다. `PFDView`에서 `@Environment(\.modelContext)`로 컨텍스트를 받아서 GPWS 상태 변경 시 `SwiftDataAlert`를 저장하는 방식으로 해결한다.

---

### View 수정

이제 `PFDView`를 수정한다.

CoreData에서도 Context를 썼듯 SwiftData에서도 동일하게 `ModelContext`를 사용한다.

```swift
@Environment(\.modelContext) private var modelContext
```

CoreData 때는 별도 변수를 만들거나 Singleton으로 관리했는데, SwiftUI에서는 `@Environment`로 주입받으면 되므로 훨씬 간단하다.

---

#### 기능 구현하기

흔히 CRUD라고 하는 기본 기능이 있는데, 여기서는 저장만 하면 되므로 C(Create)만 한다.

```swift
func saveAlert() {
    let gpwsAlert = SwiftDataAlert(gpwsState: , pace: , distance: , timestamp: .now, latitude: , longitude: )
    modelContext.insert(gpwsAlert)
}
```

파라미터를 채우려면 `pace`, `distance`는 `runViewModel.flightData`에서 바로 꺼낼 수 있다. 문제는 `latitude`와 `longitude`다.

현재 `FlightData`에는 좌표가 없어서 `RunningCentor`의 `lastLocation`에서 꺼내야 하는데, Actor를 View에서 직접 접근하려면 `await`가 필요하다.

좌표 값을 가져오는 방법은 두 가지를 고민했다. ViewModel에 `currentLatitude`, `currentLongitude` 프로퍼티를 추가해서 `LocationService`에서 직접 받아 노출하는 방법과, `FlightData`에 추가하여 Actor에서 흘려보내는 방법이다.

[RunWay(5)](https://haroldfromk.github.io/posts/RunningProject-(5)/){:target="_blank"}에서 설계한 것처럼 `FlightData`는 러닝 중 실시간 스냅샷이다. 

이미 `heading`, `altitude`도 `CLLocation`에서 꺼내서 담고 있으니 현재 위치도 같이 포함하는 게 일관성 있다. View가 `LocationService`를 직접 알 필요도 없어진다.

```swift
struct FlightData {
    // 생략
    var latitude: Double = 0
    var longitude: Double = 0
}

// RunningCenter
let flightData = FlightData(distance: totalDistance,
    // 생략
    latitude: location.coordinate.latitude,
    longitude: location.coordinate.longitude)
```

그리고 `GPWSState`를 SwiftData에 String으로 저장하기 위해 `String` rawValue를 추가했다.

```swift
enum GPWSState: String {
    case normal, sinkRate, overspeed, minimums
}
```

rawValue가 케이스 이름과 동일하므로 별도 매핑 없이 `.rawValue`로 바로 꺼낼 수 있다.

그래서 코드로 정리하면 아래와 같다.

```swift
func saveAlert() {
    let currentPace = runViewModel.flightData.pace
    let currentDistance = runViewModel.flightData.distance
    let currentGpws = runViewModel.flightData.gpwsStatus?.rawValue ?? "normal"
    let currentLatitude = runViewModel.flightData.latitude
    let currentLongitude = runViewModel.flightData.longitude
    
    let gpwsAlert = SwiftDataAlert(gpwsState: currentGpws, pace: currentPace, distance: currentDistance, timestamp: .now, latitude: currentLatitude, longitude: currentLongitude)
    modelContext.insert(gpwsAlert)
}
```

이제 어디서 해당 기능을 통해 alert를 저장하냐 인데

```swift
.onChange(of: runViewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue {
        triggerGPWS(status)
        if status != .normal && status != .minimums {
            saveAlert()
        }
    }
}
```

이미 우리는 onChange에서 gpwsStatus의 변화를 감지하여 트리거를 하고있었기에 normal, minimus가 아닌경우에만 저장을 하도록 해주면 된다.

---

## 러닝 종료 시 Flight 저장

실시간으로 러닝 중 발생한 Alert 저장은 끝났다. 이제는 러닝이 종료될 때 전체 기록을 `SwiftDataFlight`에 저장하는 차례다.

```swift
func saveRunningData() {
    let runningData = SwiftDataFlight(mode: , distance: , time: , pace: , heartRate: 0, cadence: 0, fuel: 0, date: .now)
    modelContext.insert(runningData)
}
```

이번에도 데이터를 어떻게 가져올지가 핵심이다. `distance`는 m 단위라 km으로 변환이 필요하고, `pace`는 저장된 값이 없으므로 종료 시점의 `elapsedTime`과 `distance`로 직접 계산한다. 

`heartRate`, `cadence`, `fuel`은 Watch 연동 전이라 임시로 0으로 처리한다.

남은 하나는 `mode`를 어떻게 처리할 것인가이다.

현재 Mode A인지 Mode B인지는 페이스를 세팅하고 달리느냐로 구분된다. 페이스를 세팅하는 순간 `ModeA` 데이터가 생성되어 Actor에 전달되는 구조다.

이를 활용하여 ViewModel에 `isModeA` 플래그를 추가하고, `getModeData`가 호출되는 시점에 `true`로 바꾸는 방식으로 해결한다.

```swift
// ViewModel
var isModeA: Bool = false

func getModeData(_ data: ModeA) {
    isModeA = true
    Task {
        await runningCenter.setModeAData(data)
    }
}
```

이제 `saveRunningData`에서 `isModeA`로 mode를 결정할 수 있다.

```swift
func saveRunningData() {
    let totalDistance = runViewModel.flightData.distance / 1000
    let totalTime = runViewModel.elapsedTime
    let totalPace = (Double(totalTime) / 60) / totalDistance
    let mode = runViewModel.isModeA ? "modeA" : "modeB"
    
    let runningData = SwiftDataFlight(mode: mode, distance: totalDistance, time: totalTime, pace: totalPace, heartRate: 0, cadence: 0, fuel: 0, date: .now)
    modelContext.insert(runningData)
}
```

그리고 러닝이 종료될 때 누르는 Touchdown에 기능을 추가해주면 된다.

저장 후 `stop()`을 호출해야 한다. 순서가 바뀌면 `stop()`에서 `elapsedTime`이 0으로 초기화되어 저장 시 잘못된 값이 들어간다.

```swift
Button {
    saveRunningData()
    runViewModel.stop()
    navigateToTouchdown = true
}
```

---

## TouchdownView 실제 데이터 연결

현재 하드코딩되어있는 TouchdownView에 실제 러닝이 끝난 데이터를 연결해보도록 한다.

여기서도 심박과 케이던스는 아직 구현할 수 없기에 하드코딩된 값 그대로 둔다.

러닝 이후에는 SwiftData에 저장이 될것이기 때문에 가장 최신 데이터를 불러오는 방안으로 하면 될 것 같다.

SwiftData는 `@Query`를 사용하여 쉽게 fetch를 할 수 있다.

```swift
@Query(sort: \SwiftDataFlight.date, order: .reverse) private var flights: [SwiftDataFlight]

var latestFlight: SwiftDataFlight? {
    flights.first
}
```

날짜 기준으로 내림차순 정렬하여 가장 최근에 저장된 Flight가 첫 번째로 오도록 했다. `.first`로 꺼내면 방금 종료된 러닝 데이터가 된다.

이제 하드코딩된 값들을 바꿔준다.

![](/assets/images/upload/touchdownview.png){: width="50%" height="50%"}

실행하면 적용이 잘된걸 알 수 있다.

---

## Distance 초기화

지금까지는 러닝 정지 시 `elapsedTime`만 초기화했는데, 이제 거리도 함께 초기화한다.

시간은 ViewModel에서 관리하므로 `stop()`에서 바로 0으로 돌리면 됐다. 하지만 거리는 Actor에서 관리하고 있다.

이미 여러 번 다뤘지만 ViewModel에서 Actor 프로퍼티를 직접 수정할 수 없다. Actor 내에 reset 함수를 만들고 `Task { await }` 를 통해 간접적으로 초기화하는 방식으로 해결한다.

```swift
// RunningCenter
func reset() {
    totalDistance = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    isReachedPace = false
}

// VM
func stop() {
    isRunning = false
    locationService.stopTracking()
    timerCancellable.removeAll()
    elapsedTime = 0
    Task {
        await runningCenter.reset()
    }
}   
```

거리뿐만 아니라 러닝 관련 상태값 전체를 초기화하여 다음 러닝을 위한 깨끗한 상태로 만든다.

---

## UI 보완 및 문제 수정

### PFDView 상태 초기화

러닝 종료 후 다시 시작하면 PFDView의 상태값이 이전 러닝 것이 남아있는 문제가 있다. `gpwsState`, `flashOn` 등 `@State` 프로퍼티가 초기화되지 않아 이전 GPWS 경고 상태가 그대로 표시된다.

ViewModel에 `resetState()`를 만들어 `stop()` 시 Actor와 ViewModel 상태를 한 번에 초기화한다. PFDView의 `@State`는 `onAppear`에서 따로 초기화한다.

```swift
// ViewModel
func resetState() {
    isRunning = false
    isModeA = false
    elapsedTime = 0
    Task {
        await runningCenter.reset()
    }
}

func stop() {
    locationService.stopTracking()
    timerCancellable.removeAll()
    resetState()
}

// PFDView
.onAppear {
    gpwsState = nil
    flashOn = false
}
```

---

### Free Flight ModeA 잔존 문제

러닝 종료 후 Free Flight으로 다시 시작하면 이전 `modeAData`가 Actor에 남아있어 GPWS가 의도치 않게 동작하는 문제가 있다.

`reset()`에 `modeAData = nil`을 추가하고, ViewModel에서도 `isModeA = false`로 초기화한다. `isModeA`는 앞서 만든 `resetState()`에서 이미 처리되므로 Actor의 `reset()`만 수정하면 된다.

```swift
// RunningCenter
func reset() {
    totalDistance = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    isReachedPace = false
    modeAData = nil
}
```

---

## AlertsView에 연결

이제 하드코딩된 Mock 데이터를 `SwiftDataAlert`로 교체한다.

`@Query`로 전체 Alert를 불러오고 날짜별로 그룹핑하여 표시한다. 상단 Summary 카드는 전체 Alert에서 `gpwsState`별로 카운트하고, 리스트는 날짜 헤더 아래 해당 날짜의 Alert 목록이 나오는 구조로 만들었다.

날짜 헤더에는 비행기 아이콘과 날짜, 해당 날짜 Alert 개수를 함께 보여준다. GLIDE PATH는 페이스 복귀 알림이라 저장하지 않으므로 Summary 카드도 SINK RATE / OVERSPEED 두 가지만 남겼다.

```swift
@Query(sort: \SwiftDataAlert.timestamp, order: .reverse) private var alerts: [SwiftDataAlert]

var groupedAlerts: [String: [SwiftDataAlert]] {
    Dictionary(grouping: alerts) { alert in
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: alert.timestamp)
    }
}

var sortedDates: [String] {
    groupedAlerts.keys.sorted(by: >)
}

var sinkRateCount: Int { alerts.filter { $0.gpwsState == "sinkRate" }.count }
var overspeedCount: Int { alerts.filter { $0.gpwsState == "overspeed" }.count }
```

그리고 날짜별 목록은 `DisclosureGroup`을 사용하여 폴더식으로 펼쳤다 닫았다 할 수 있도록 했다. 날짜가 많아질수록 화면이 길어지는 문제를 자연스럽게 해결할 수 있고, 원하는 날짜만 열어서 확인하는 방식이 더 직관적이다.

![](/assets/images/upload/folder.gif){: width="50%" height="50%"}

실행하면 기록이 뜨는 걸 알 수 있다. `DisclosureGroup` 덕분에 별도 화면 전환 없이 한 화면에서 날짜별로 접었다 펼 수 있어 더 깔끔해졌다.