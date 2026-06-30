---
title: RunWay (16) CoreMotion & Alert 처리, SwiftChart, 온보딩/스플래시 연결
writer: Harold
date: 2026-06-28 08:33:00 +0900
# last_modified_at: 2026-06-26 08:33:00 +0900
categories: [RunWay]
tags: [CoreMotion, SwiftChart, SwiftUI]

toc: true
toc_sticky: true
published: true
---

가장 큰 산인 미러링이 끝났다. 물론 그동안에 충분히 휴식도 취하면서 하느라 애초에 생각했던 계획보다 조금 일정이 미뤄졌지만 크게 문제는 없는 부분이다.

이제는 나머지 부분을 해보려 한다.

먼저 쉬운것부터 차례로 해본다.


## 온보딩 & 스플래시 화면 프로젝트 연결

이미 AI를 통해 디자인을 만들어 두었기에 프로젝트에 연결만 하면 된다.

`SplashView`는 만들어져 있었지만, 분기 끝에서 `ContentView()`를 호출하고 있었다. 우리 프로젝트는 `ContentView`가 아니라 `RunWayApp`의 `TabView`(`HomeView`/`LogbookView`/`AlertsView`)가 실제 메인 진입점이었기 때문에, 그대로는 연결이 안 됐다.

그래서 `RunWayApp`에 있던 `TabView` 구조를 별도 뷰로 분리했다.

```swift
struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Deck", systemImage: "house.fill") }
            NavigationStack { LogbookView() }
                .tabItem { Label("Logbook", systemImage: "list.bullet.clipboard") }
            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
        }
    }
}
```

`RunWayApp`은 이제 `SplashView`를 보여주는 것으로 단순화했다.

```swift
@main
struct RunWayApp: App {
    @State private var runViewModel = RunViewModel()
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(runViewModel)
                .modelContainer(for: [SwiftDataAlert.self, SwiftDataCoordinate.self, SwiftDataFlight.self])
        }
    }
}
```

`SplashView`의 분기도 `ContentView()` 대신 `RootTabView()`를 보여주도록 바꿨다.

```swift
if hasCompletedOnboarding {
    RootTabView()
} else {
    OnboardingView()
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/done111.gif){: width="50%" height="50%"}

이렇게 이제는 온보딩뷰와 스플래시뷰 모두 연결이 되었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/watchsplash.gif){: width="50%" height="50%"}

워치도 해주었다. (다만 워치의 온보딩은 굳이 필요없을듯 해서 하지는 않았다.)

---

## SwiftChart 주간 차트 구현

미리 준비해둔 `FlightCalendarView`를 연결해보려 한다.

`FlightCalendarView`는 캘린더 형식으로 되어 있어서, 하루에 몇 km를 러닝했는지 시각적으로 한눈에 알 수 있게 해주는 뷰다.

```swift
@Query(sort: \SwiftDataFlight.date, order: .reverse) private var flights: [SwiftDataFlight]
```

4일차였는지 기억이 안 나는데, 그때 아마 `HealthKitService`에 fetch 목적으로 만들어둔 게 있었다.

```swift
func fetchDistance() async {
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
    let queryPredicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
    let samplePredicate = HKSamplePredicate.quantitySample(type: HKQuantityType(.distanceWalkingRunning), predicate: queryPredicate)
    let query = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum, anchorDate: startDate, intervalComponents: .init(day: 1))

    let result = try! await query.result(for: store)
    for stat in result.statistics() {
        let value = stat.sumQuantity()?.doubleValue(for: .meter()) ?? 0
        print("📍 Distance: \(value) m / \(stat.startDate)")
    }
}
```

이게 생각해보니 순수 러닝이 아니라 일반적인 모든 Workout(걷기 포함)에 적용되는 거라 사용하지 않는 걸로 결정했다.

일단은 `HealthKitService` 내의 fetch 함수들은 혹시 다른 데 쓰일지도 모르니 지우지는 않고 킵해두기로 했다.

대신 RunWay 앱으로 직접 기록한 러닝만 정확히 보여줘야 하니, SwiftData의 `SwiftDataFlight`를 그대로 쓰는 방향으로 갔다.

캘린더 작업은 크게 두 부분으로 나뉜다. 하나는 "이 달의 합계/평균을 계산하는 로직"이고, 다른 하나는 "달력 그리드를 어떻게 구성할지 결정하는 로직"이다.

```swift
private var monthTitle: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: displayedMonth).uppercased()
}

private var monthTotalKm: String {
    let total = flights
        .filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
        .reduce(0.0) { $0 + $1.distance }
    return String(format: "%.1f", total)
}

private var monthRunCount: Int {
    flights.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) && $0.distance > 0 }.count
}

private func kmFor(_ date: Date) -> Double {
    flights
        .filter { calendar.isDate($0.date, inSameDayAs: date) }
        .reduce(0.0) { $0 + $1.distance }
}

private var monthAvgPace: String {
    let monthFlights = flights.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    guard !monthFlights.isEmpty else { return "--'--\"" }
    let avgPace = monthFlights.reduce(0.0) { $0 + $1.pace } / Double(monthFlights.count)
    return PaceFormatter.format(avgPace)
}
```

`monthTotalKm`, `monthRunCount`, `monthAvgPace`는 모두 이번 달에 해당하는 `flights`만 필터링한 다음 합산/평균을 내는 단순한 계산 로직이다. 

`kmFor(_:)`는 특정 하루에 해당하는 기록들을 합산해, 같은 날 여러 번 뛰었을 경우에도 그 날의 총 거리를 정확히 반영하도록 했다.

```swift
@State private var displayedMonth: Date = Date()

private func changeMonth(_ delta: Int) {
    if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
        }
    }
}

private func daysInMonth() -> [Date?] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
        return []
    }

    var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

    var date = monthInterval.start
    while date < monthInterval.end {
        days.append(date)
        guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
        date = next
    }

    return days
}
```

반면 `changeMonth(_:)`와 `daysInMonth()`는 데이터 계산이 아니라 달력 자체를 그리기 위한 구성 로직이다. `changeMonth`는 좌우 화살표를 눌렀을 때 보여줄 달을 바꿔준다.

`daysInMonth()`가 하는 일을 풀어보면 이렇다. 먼저 `calendar.dateInterval(of: .month, for: displayedMonth)`로 이번 달의 시작일과 끝일을 구한다. 그다음 `dateComponents([.weekday], from: monthInterval.start).weekday`로 그 달의 1일이 무슨 요일인지 알아낸다(일요일이 1, 월요일이 2, ... 토요일이 7).

요일 헤더가 일요일부터 시작하니까(`["S", "M", "T", "W", "T", "F", "S"]`), 1일이 화요일(weekday = 3)이라면 그 앞에 일요일·월요일 칸 2개를 비워둬야 그리드가 어긋나지 않는다. 그래서 `Array(repeating: nil, count: firstWeekday - 1)`로 1일 이전의 빈 칸을 먼저 만들어두는 것이다.

그 다음 `while` 루프로 그 달의 시작일부터 마지막 날까지 하루씩 더해가며 `days` 배열에 실제 날짜를 채워 넣는다. 결과적으로 `[nil, nil, 1일, 2일, 3일, ...]` 같은 형태의 배열이 만들어지고, 이게 그대로 7열 그리드의 각 칸에 순서대로 들어가게 된다.

```swift
LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
    ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
        if let date = date {
            DayCell(date: date, km: kmFor(date), isToday: calendar.isDateInToday(date))
        } else {
            Color.clear.frame(height: 38)
        }
    }
}
```

`daysInMonth()`가 만든 배열을 7개씩 끊어서 그려주는 게 `LazyVGrid`다. `nil`인 칸은 빈 공간(`Color.clear`)으로, 실제 날짜가 있는 칸은 `DayCell`로 채워서 보여준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/calendar.png){: width="50%" height="50%"}


![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/screen1.png){: width="50%" height="50%"}

---

이제 `HomeView`에도 하드코딩되어 있던 부분을 고쳐보도록 한다.

여기서의 포인트는 ComputedProperty라고 생각한다.

```swift
var weeklyDistances: [Double] {
    let today = Calendar.current.startOfDay(for: .now)
    let weekday = Calendar.current.component(.weekday, from: today) // 일=1, 월=2, ...
    let daysFromMonday = (weekday + 5) % 7 // 월요일까지 거슬러간 일수
    guard let monday = Calendar.current.date(byAdding: .day, value: -daysFromMonday, to: today) else {
        return Array(repeating: 0, count: 7)
    }

    return (0..<7).map { offset in
        guard let day = Calendar.current.date(byAdding: .day, value: offset, to: monday) else { return 0 }
        return flights
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .reduce(0.0) { $0 + $1.distance }
    }
}
```

`weeklyDistances`가 하는 일을 풀어보면, 먼저 오늘이 무슨 요일인지 알아낸 다음 이번 주 월요일이 며칠 전인지를 계산한다. `Calendar`의 `weekday` 값은 일요일이 1, 월요일이 2, ..., 토요일이 7로 매겨지는데, 월요일을 0으로 맞추려면 `(weekday + 5) % 7`이 필요하다. 예를 들어 오늘이 수요일(weekday = 4)이면 `(4 + 5) % 7 = 2`로, 월요일까지 2일을 거슬러가야 한다는 뜻이 된다.

이렇게 이번 주 월요일을 구하고 나면, 거기서부터 7일을 하루씩 더해가며(`offset` 0~6) 그날에 해당하는 `flights`를 필터링해서 거리를 합산한다. 결과로 `[월, 화, 수, 목, 금, 토, 일]` 순서의 7개짜리 거리 배열이 만들어지고, 이게 그대로 주간 차트의 막대 높이로 쓰인다.

```swift
var weeklyTotalKm: Double {
    weeklyDistances.reduce(0, +)
}
```

`weeklyTotalKm`은 그 7일치 배열을 그냥 다 더한 값이다. "21.4 km total this week" 같은 하단 텍스트에 쓰인다.

```swift
// before
var weeklyAvgPace: String {
    let weekFlights = flights.filter { flight in
        let today = Calendar.current.startOfDay(for: .now)
        let weekday = Calendar.current.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = Calendar.current.date(byAdding: .day, value: -daysFromMonday, to: today),
                let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) else { return false }
        return flight.date >= monday && flight.date <= sunday
    }
    guard !weekFlights.isEmpty else { return "--'--\"" }
    let avg = weekFlights.reduce(0.0) { $0 + $1.pace } / Double(weekFlights.count)
    return PaceFormatter.format(avg)
}

// after
var weeklyAvgPace: String {
    let weekFlights = flights.filter { flight in
        let today = Calendar.current.startOfDay(for: .now)
        let weekday = Calendar.current.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = Calendar.current.date(byAdding: .day, value: -daysFromMonday, to: today),
              let sundayStart = Calendar.current.date(byAdding: .day, value: 6, to: monday),
              let sundayEnd = Calendar.current.date(byAdding: .day, value: 1, to: sundayStart) else { return false }
        return flight.date >= monday && flight.date < sundayEnd
    }
    guard !weekFlights.isEmpty else { return "--'--\"" }
    let avg = weekFlights.reduce(0.0) { $0 + $1.pace } / Double(weekFlights.count)
    return PaceFormatter.format(avg)
}
```

`weeklyAvgPace`는 같은 방식으로 이번 주 월요일과 일요일 범위를 구하고, 그 범위 안에 있는 `flights`만 걸러낸 다음 페이스(`pace`)의 평균을 낸다.

처음엔 `sunday`를 `monday`에 6일을 더한 값으로만 잡았는데, 이 값은 "일요일 00시 00분"을 가리킨다. `flight.date`는 실제 러닝이 끝난 시각(예: 일요일 17시 55분)이라서 `flight.date <= sunday` 비교가 그 시각을 통과시키지 못해, 일요일에 뛴 기록이 전부 빠지는 버그가 있었다. `sundayEnd`(다음 월요일 00시)를 상한으로 잡고 `<`로 비교하도록 고쳐서, 일요일 하루 전체(00:00~23:59:59)가 빠짐없이 포함되도록 했다.

이번 주에 기록이 하나도 없으면 `"--'--\""`로 빈 값을 표시하고, 있으면 `PaceFormatter.format(_:)`으로 다른 화면들과 동일한 형식으로 맞춰서 보여준다.

---

그리고 요일 텍스트에 토요일(인덱스 5)만 항상 초록색으로 표시하던 하드코딩도 남아 있었다. 

디자인 목업 때 `오늘`을 표시하려고 고정 인덱스를 썼던 거였는데, 이제 요일이 실제 날짜 기반으로 바뀌었으니 오늘에 해당하는 요일을 동적으로 계산해서 강조해야 했다.

```swift
private var todayWeekdayIndex: Int {
    let weekday = Calendar.current.component(.weekday, from: .now)
    return (weekday + 5) % 7
}
```

```swift
Text(weekDays[i])
    .font(.system(size: i == todayWeekdayIndex ? 12 : 10, weight: i == todayWeekdayIndex ? .bold : .regular))
    .foregroundColor(i == todayWeekdayIndex ? .rwGreen : .rwMuted)
```

`weeklyDistances`를 계산할 때 썼던 것과 같은 방식(`(weekday + 5) % 7`)으로 월요일을 0으로 맞춘 인덱스를 구해서, 그 인덱스에 해당하는 요일을 색뿐 아니라 크기와 굵기도 같이 키워서 더 또렷하게 강조되도록 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/weekly.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/screen2.png){: width="50%" height="50%"}

---

## CoreMotion AltTape / GLIDE PATH 연동 검토

### GLIDE PATH 삭제

GLIDE PATH는 `ADIView`에 "GLIDE PATH / -1.2% / VS -0.6 m/s"로 하드코딩되어 있었다. 항공기 계기판 디자인 목업 단계에서 활주로 접근 시 하강 경로 각도를 표시하던 UI였는데, 막상 러닝에 적용하려고 보니 "각도"라는 개념 자체가 자연스럽게 매핑되지 않았고, CoreMotion 데이터와도 직접적인 연관이 없었다.

게다가 GPWS 로직을 다시 보니 허용 오차 판단은 이미 페이스 기준으로만 처리하고 있었고, `GPWSState` enum에도 GLIDE PATH에 대응하는 케이스가 없어서 실제로는 코드 어디에도 쓰이지 않는 개념이었다. 그래서 ALT(고도)만 남기고 GLIDE PATH는 그대로 지우기로 했다.

---

### AltTape 검토

ALT(고도) 부분을 어떻게 구현할지 고민해보았다. GPS(`CLLocation.altitude`)와 CoreMotion(`CMAltimeter`)을 비교해본 결과 후자가 우리 의도(출발 지점 기준 상대적인 오르막/내리막)에 더 맞다는 결론까지는 도달했지만, 워크아웃 일시정지 중 오프셋이 튀는 등 처리해야 할 함정이 적지 않았다.

생각해보니 RunWay는 평지 위주의 일반적인 러닝을 타겟으로 하는 앱이라, 고도 변화가 핵심 정보가 아니다. 그래서 이번 버전에서는 ALT를 구현하지 않기로 했다. 나중에 트레일 러닝이나 언덕 코스 같은 시나리오가 필요해지면 그때 다시 검토하기로 한다.

---

## Alert 처리 누락 부분 전부 적용하기

`LocationService`는 이미 에러 처리 구조가 잡혀 있다. `alertPublisher`로 `AlertItem`을 흘려보내면, VM이 구독해서 사용자에게 alert로 보여주는 방식이다.

```swift
func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
    alertPublisher.send(AlertContext.unableToGetLocations)
}

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .notDetermined:
        locationManager.requestWhenInUseAuthorization()
    case .restricted:
        alertPublisher.send(AlertContext.restrictedGetAuthorization)
    case .denied:
        alertPublisher.send(AlertContext.deniedGetAuthorization)
    case .authorizedAlways:
        break
    case .authorizedWhenInUse:
        break
    default:
        break
    }
}
```

반면 그동안 작업하면서 곳곳에 `print(error)`로만 확인하고 넘어간 부분들이 쌓여 있었다. `HealthKitService`를 비롯해 미러링 작업 중에도 디버깅용으로 `print`만 박아두고 정식 에러 처리를 미뤄둔 곳이 여럿이었다.

Command+Shift+F로 프로젝트 전체에서 `print`가 쓰인 곳을 검색해, 단순 디버깅 로그인지 실제로 사용자에게 알려야 하는 에러인지를 하나씩 구분하고, 에러 처리가 필요한 곳은 `LocationService`와 동일한 패턴으로, `AlertItem`을 만들어 `alertPublisher`로 흘려보내는 형태로 통일하려고 한다.

알파벳 순으로 하나씩 해본다.

---

### FlightActivityService

여기 있는 `print`들은 alert로 바꿀 필요가 없다고 판단했다. 

Live Activity/Dynamic Island는 보조 기능이라, 시스템 설정에서 비활성화되어 있거나 시작이 실패해도 메인 러닝 추적 자체에는 영향이 없다. 

사용자가 의도적으로 Live Activities를 꺼둔 경우에 굳이 경고창을 띄우면 오히려 방해가 될 수 있어서, 그대로 디버깅용 로그로 남겨두기로 했다.

---

### HealthKitService

먼저 공통적으로 다루는 부분에 대해서 해본다.

`print`가 쓰인 곳은 두 군데였다.

```swift
#if os(iOS)
do {
    try await store.startWatchApp(toHandle: workoutConfiguration)
    runningMode = .mirrored
} catch {
    print("iPhone: startWatchApp failed - \(error)")
}
#else
if WCSession.default.isReachable {
    do {
        try await session?.startMirroringToCompanionDevice()
        runningMode = .mirrored
    } catch {
        print("Watch: mirroring failed - \(error)")
    }
}
#endif
```

미러링 실패는 치명적인 에러는 아니다. 미러링이 안 되어도 iPhone과 Watch는 각자 단독으로 정상 동작하기 때문이다. 다만 사용자가 "왜 Watch가 안 켜지지?"라고 느낄 수 있으니, alert까지는 아니더라도 가볍게 인지시킬 필요는 있어 보였다.

```swift
nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
    print("\(#function): \(error)")
}
```

반면 이건 워크아웃 세션 자체의 실패라서 더 심각하다. 발생하면 GPS/HealthKit 기반 추적이 끊기는 상황일 수 있어서, 사용자에게 직접 알려줘야 하는 진짜 에러로 분류했다.

미러링 실패는 토스트처럼 잠깐 떴다가 사라지는 형태가 맞아 보이는데, 이건 호출하는 쪽(VM)에서 처리해야 하는 부분이라 따로 풀어야 할 게 좀 있다. 일단 먼저 처리하기 쉬운 쪽, 즉 `LocationService`와 동일한 패턴으로 바로 적용할 수 있는 `alertPublisher` 방식부터 처리하고 미러링 토스트는 나중으로 미루기로 했다.

---

그래서 여기선 `didFailWithError`에 대해서만 먼저 다뤄보기로 한다.

`LocationService`처럼 에러를 실시간 스트림할 Publisher를 만들어준다.

```swift
var alertPublisher = PassthroughSubject<AlertItem, Never>()

nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
    Task { @MainActor in
        alertPublisher.send(AlertContext.workoutSessionFailed)
    }
}

// AlertContext
static let workoutSessionFailed = AlertItem(
    title: "Workout Session Error",
    message: "Something went wrong while tracking your run.\nPlease restart your flight."
)
```

이렇게 `AlertItem`을 만들어 `alertPublisher`를 통해 흘려보내도록 했다.

`HomeView`와 `PFDView` 둘 다 이미 같은 `runViewModel.alertItem`/`didError`를 구독해서 `.alert`를 띄우는 구조였기 때문에, 별도로 어디서 보여줄지 신경 쓸 필요는 없었다. 

워크아웃 세션 에러는 보통 러닝 중에 발생하니까, 그 순간 화면에 떠 있는 `PFDView`가 자연스럽게 alert를 보여주게 된다.

---

### WatchConnectivityService

`WatchConnectivityService.session(_:activationDidCompleteWith:error:)`도 같은 패턴으로 `print`만 처리하고 있었다. 다만 이건 앱이 시작되는 시점에 한 번 호출되는 콜백이라, 사용자가 즉시 취할 수 있는 행동이 마땅치 않고(재부팅이나 재페어링 정도), 적절한 alert 타이밍을 잡기도 어려웠다. 그래서 이건 alert로 전환하지 않고 디버깅 로그로 남겨두기로 했다.

```swift
extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            print("The session has completed activation.")
        }
    }
}
```

---

### RunViewModel

```swift
case .cruise:
    Task {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            HealthKitService.shared.startOrigin = .local
            try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
        } catch {
            print(error)
        }
    }
```

이건 `TakeoffView.startCountdown()`의 카운트다운 마지막 단계에서 호출되는데, `runViewModel.navigationPath.append(.pfd)`가 호출되기 *전*이라 실제로는 아직 `TakeoffView`가 화면에 떠 있는 시점이다. 즉 여기서 `startWorkout()`이 실패하면 `TakeoffView`가 떠 있는 동안 발생하는 에러다. `print`만 하고 넘어가면 사용자는 카운트다운이 끝났는데 PFD에서 데이터가 안 들어오는 걸 보게 되어도 원인을 알 수가 없다.

```swift
case .cruise:
    Task {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            HealthKitService.shared.startOrigin = .local
            try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.workoutSessionFailed)
        }
    }
```

이걸 보여주려면 `TakeoffView`에도 `HomeView`/`PFDView`와 동일한 alert 표시 구조가 필요했다. `TakeoffView`에 다음을 추가했다.

```swift
@State private var showAlert = false

.alert(runViewModel.alertItem?.title ?? "",
       isPresented: $showAlert,
       presenting: runViewModel.alertItem
) { details in
    Button("OK") {
        runViewModel.didError = false
        showAlert = false
    }
} message: { item in
    Text(item.message)
}
.onChange(of: runViewModel.didError) { _, newValue in
    if newValue { showAlert = true }
}
```

이렇게 추가를 하게 되면, 카운트다운 중 `TakeoffView`가 화면에 떠 있는 동안 발생한 에러도 자연스럽게 alert로 표시된다.

---

### AppDelegate (Watch)

```swift
class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task {
            do {
                HealthKitService.shared.startOrigin = .remote
                try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
            } catch {
                print(error)
            }
        }
    }
}
```

`handle(_:)`은 Watch 앱의 진입점 역할이라, 이 시점에 화면에 어떤 View가 떠 있을지 보장할 수 없다. iPhone이 막 시작시켜서 Watch 앱이 켜지는 순간일 수도 있기 때문이다.

다만 `startWorkout()`이 실패하면 `.running` 이벤트가 흐르지 않으니 PFD로 전환되지 않고, Watch는 결국 `WatchHomeView`에 머물게 된다. 그러니 alert를 보여줄 화면은 `WatchHomeView`로 정해졌다.

다만 Watch에서도 `.alert(...)`가 정상적으로 동작하는지 먼저 확인이 필요했는데, [alert Docs](https://developer.apple.com/documentation/swiftui/view/alert(_:ispresented:presenting:actions:message:)-8584l){:target="_blank"}를 보면 watchOS도 명시적으로 지원 대상에 포함되어 있었다. 

다만 "iOS, tvOS, watchOS에서는 알림이 `Text` 라벨을 가진 컨트롤만 지원하며, 다른 타입의 뷰를 전달하면 그 내용은 무시된다"는 제약과, 메시지도 스타일 없는 텍스트만 지원한다는 제약이 있었다. 

> On iOS, tvOS, and watchOS, alerts only support controls with labels that are Text. Passing any other type of view results in the content being omitted. 
> Only unstyled text is supported for the message.

우리가 쓰는 패턴(`Button("OK") { ... }`, `Text(item.message)`)이 이미 이 제약에 맞는 단순한 형태라 그대로 적용할 수 있었다.

그래서 일단 `print` 대신 `alertPublisher`로 흘려보내도록 고쳤다.

```swift
class AppDelegate: NSObject, WKApplicationDelegate {
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
}
```

---

이제 `WatchHomeView`에 적용을 해본다. 앱의 `HomeView`에서 하는 것과 크게 달라지는 건 없다.

그러고 보니 `HomeView`의 변수 이름도 짚어볼 부분이 있었다. `showLocationError`라는 이름으로 alert state를 두고 있는데, 실제로는 `runViewModel.alertItem`/`didError`를 공유하는 구조라 위치 에러뿐 아니라 이번에 추가한 워크아웃 세션 에러도 같은 alert로 뜨게 된다. 이름이 더 이상 정확하지 않아서, `TakeoffView`/`PFDView`처럼 `showAlert`로 통일했다.

```swift
// Before
@State private var showLocationError = false

// After
@State private var showAlert = false
```

이에 맞춰 `.alert(...)`와 `.onChange(of: runViewModel.didError)`의 `showLocationError`도 모두 `showAlert`로 바꿔주었다.

그리고 `WatchViewModel.init()`에도 동일하게 `HealthKitService.shared.alertPublisher`를 구독하는 부분을 추가했다.

```swift
HealthKitService.shared.alertPublisher
    .sink { [weak self] alert in
        guard let self else { return }
        self.alertItem = alert
        didError = true
    }
    .store(in: &cancellables)
```

`LocationService.alertPublisher`를 구독하던 기존 패턴과 똑같이, `HealthKitService`에서 흘러나온 에러도 같은 `alertItem`/`didError`로 흘려보내도록 했다. 이제 iPhone과 Watch 모두 `LocationService`와 `HealthKitService` 양쪽에서 발생하는 에러를 동일한 alert 구조로 보여줄 수 있게 됐다.

---

### HealthKitService (Watch)

```swift
@MainActor
func finishWatchWorkout(at date: Date) async {
    do {
        try await builder?.endCollection(at: date)
        workout = try await builder?.finishWorkout()
        session?.end()
    } catch {
        print(error)
    }
}
```

이건 워크아웃을 마무리하는 시점의 실패라서 사용자가 즉시 할 수 있는 행동은 없지만, 데이터가 정상적으로 저장되지 않았을 수 있으니 알려줄 필요는 있다고 판단했다.

```swift
@MainActor
func finishWatchWorkout(at date: Date) async {
    do {
        try await builder?.endCollection(at: date)
        workout = try await builder?.finishWorkout()
        session?.end()
    } catch {
        alertPublisher.send(AlertContext.workoutSessionFailed)
    }
}
```

---

### WatchViewModel

```swift
case .cruise:
    Task {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            HealthKitService.shared.startOrigin = .local
            try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
        } catch {
            print(error)
        }
    }
```

iPhone의 `RunViewModel`과 동일한 케이스다. `WatchTakeoffView`가 카운트다운 중 화면에 떠 있는 시점이라, 같은 방식으로 alert를 흘려보내면 자연스럽게 보여질 수 있다.

```swift
case .cruise:
    Task {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            HealthKitService.shared.startOrigin = .local
            try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.workoutSessionFailed)
        }
    }
```

---

### WatchHomeView

```swift
.onAppear {
    Task {
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            print(error)
        }
    }
}
```

HealthKit 권한 요청 실패는 `LocationService`의 권한 거부 케이스와 비슷하게, 사용자가 설정에서 직접 바꿔야 하는 상황이라 alert로 안내하는 게 맞다고 판단했다.

```swift
.onAppear {
    Task {
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.healthKitAuthorizationFailed)
        }
    }
}
```

`AlertContext`에도 새 케이스를 추가했다.

```swift
static let healthKitAuthorizationFailed = AlertItem(
    title: "HealthKit Access Denied",
    message: "Please enable Health access in Settings to track your run."
)
```

---

확실히 Combine + Alert 모델화 덕분에 유지보수 및 추가가 쉬웠다. 

`AlertItem`/`AlertContext`라는 공통 모델과 `alertPublisher`라는 일관된 통로만 만들어두니, 어디서 에러가 발생하든 같은 패턴(`publisher.send(AlertContext.xxx)`)으로 연결하기만 하면 됐다.

화면마다 따로 alert 로직을 새로 짤 필요 없이, `LocationService`에서 시작한 구조를 `HealthKitService`까지 그대로 확장할 수 있었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/combine.png){: width="50%" height="50%"}

---

## OnboardingView로 권한 요청 옮기기

권한 요청 시점을 정리하면서, 위치 권한과 HealthKit 권한이 처리되는 방식이 서로 달랐다는 걸 다시 확인했다.

위치 권한은 `LocationService`가 `CLLocationManager`의 delegate 콜백(`locationManagerDidChangeAuthorization`)에서 알아서 처리하는 구조라, `LocationService` 인스턴스가 만들어지는 순간 자동으로 요청이 트리거된다.

```swift
func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            
            // 아직 권한 요청 전 — 권한 요청
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        // 생략
        default:
            break
        }
    }
```

iPhone에서 HealthKit 권한이 굳이 필요한가 싶었지만, iOS 26으로 올라가면서 iPhone도 `HKWorkoutSession`/`HKLiveWorkoutBuilder`를 직접 운용할 수 있게 된 게 이번 iPhone 주도 미러링의 핵심이었다. 

`startWorkout()`의 iOS 분기에서 이미 `HKLiveWorkoutDataSource`를 쓰고 있으니, 이 경로가 정상 동작하려면 iPhone도 HealthKit 권한이 있어야 했다. 혹시 몰라서가 아니라, iOS 26 이후로 생긴 실질적인 요구사항이었다.

권한 요청은 앱을 처음 쓸 때 한 번에 받아두는 게 사용자 경험상 자연스러우니, HealthKit 권한 요청을 `OnboardingView`가 완료되는 시점으로 옮겨서, 사용자가 온보딩을 마치고 `RootTabView`로 넘어갈 때 이미 필요한 권한이 다 갖춰진 상태가 되도록 했다.

```swift
private func complete() {
    Task {
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.healthKitAuthorizationFailed)
        }
    }
    hasCompletedOnboarding = true
}
```

Watch는 따로 온보딩 화면을 만들지 않았기 때문에, 기존처럼 `WatchHomeView.onAppear`에서 HealthKit 권한을 요청하는 구조를 그대로 유지하기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-26-RunningProject-16/done11.gif){: width="50%" height="50%"}

그러면 이렇게 실행시 요청이 나오게 된다.