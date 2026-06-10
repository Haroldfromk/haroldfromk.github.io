---
title: RunWay (10) Week 2 마무리 — 실제 데이터 연동 및 실기기 테스트
writer: Harold
date: 2026-06-10 08:33:00 +0900
categories: [RunWay]
tags: [SwiftData, MapKit, SwiftUI, CoreLocation]

toc: true
toc_sticky: true
published: true
---

## FlightSummaryView 실제 데이터 연동

러닝이 끝난 후 경로와 그 동안 발생한 Alert를 보여주는 SummaryView다.

어제 구현한 Alert 저장이 오늘 작업의 사전 단계였다. 이 기능을 통해 유저는 어느 구간에서 Alert가 발생했는지 지도 위에서 시각적으로 확인할 수 있다.

다만 TouchdownView가 제공하던 거리/시간/페이스 정보가 SummaryView와 중복되어 TouchdownView에서는 해당 정보를 제거했다. 착륙 애니메이션과 VIEW SUMMARY 버튼만 남겨 자연스럽게 SummaryView로 유도하는 구조로 변경했다.

우선 하드코딩되어 있던 부분을 실제 데이터로 교체한다.

```swift
Text(String(format: "%.2f", lastestFlight?.distance ?? 0))
Text(PaceFormatter.format(lastestFlight?.pace ?? 0))
SummaryStatBox(label: "TIME", value: secondToTime(lastestFlight?.time ?? 0), unit: "", color: .rwText)
SummaryStatBox(label: "AVG PACE", value: PaceFormatter.format(lastestFlight?.pace ?? 0), unit: "/km", color: .rwAmber)
```

이전 글에서는 별도로 언급하지 않았는데, 하드코딩된 값을 교체하다 보니 페이스 포맷, 시간 변환 같은 함수가 여러 뷰에서 반복적으로 쓰이고 있다는 걸 알게 됐다. 그래서 `PaceFormatter`에 `secondToTime`도 함께 넣어 한 곳에서 관리하도록 했다.

```swift
struct PaceFormatter {
    private init() {}
    
    static func format(_ pace: Double) -> String { 
        // 생략    
    }
    static func getPaces(_ pace: Double) -> [String] { 
        // 생략    
    }
    static func secondToTime(_ second: Int) -> String { 
        // 생략    
    }
}
```

이렇게 분리해두면 새로운 뷰에서도 별도 구현 없이 바로 가져다 쓸 수 있다.

---

### Map PolyLine 그리기

러닝 경로를 나타내는 기능이다. 다만 일반 러닝앱과 다른 점이라면 Annotation을 통해 어느 지점에서 Alert가 발생했는지도 표기하려고 한다.

우선 지도를 그리려면 좌표가 필요하지만, 어디를 기준으로 보여줄지도 중요하다. 이게 바로 `region`이다.

`region`에는 `center`(중심 좌표)와 `span`(표시 범위)이 필요한데, `span`의 `latitudeDelta`, `longitudeDelta` 값을 어떻게 설정해야 경로가 딱 맞게 보이는지 감이 오지 않아서 이 부분은 AI 도움을 받았다. 

좌표 배열에서 최솟값과 최댓값의 차이에 여백 배율(`1.3`)을 곱해서 자동으로 계산하는 방식이다.

```swift
struct RouteData {
    let coordinates: [CLLocationCoordinate2D]
    
    var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.max()! + lats.min()!) / 2,
            longitude: (lons.max()! + lons.min()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.3,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.3
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
```

---

그리고 하드코딩 되어있던 부분에 `let routeData: RouteData` 변수를 만들어서 매핑을 다시 해주었다.

이후 SummaryView에서 

```swift
❌
let coordinates = lastestFlight?.coordinates
    .sorted { $0.order < $1.order }
    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? []

✅
var coordinates: [CLLocationCoordinate2D] {
    lastestFlight?.coordinates
        .sorted { $0.order < $1.order }
        .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? []
}
```

`order` 기준 오름차순으로 정렬하여 러닝 시작 시점의 좌표부터 순서대로 배열이 구성된다. 값이 없을 경우 빈 배열을 반환한다.

`let`이 아닌 `var` 계산 프로퍼티로 선언한 이유는 Swift의 초기화 순서 때문이다.

`let`으로 선언하면 인스턴스 생성 시점에 값을 확정해야 하는데, 이때는 아직 `self`가 완성되지 않은 상태라 `lastestFlight` 같은 인스턴스 프로퍼티에 접근할 수 없다. 계산 프로퍼티는 실제로 호출될 때 실행되므로 그 시점에는 이미 `self`가 존재해서 문제가 없다.

여기서 `self`는 현재 구조체 인스턴스 자체를 가리킨다. 이 경우 `FlightSummaryView`의 인스턴스이며, `lastestFlight`에 접근하는 것은 사실 `self.lastestFlight`에 접근하는 것과 같다.

이제 시뮬레이터로 확인해본다. 지도 표시가 더 잘 보이도록 Drive 모드로 테스트한다.

---

#### 문제 수정

러닝을 마치고 SummaryView로 넘어가는 순간

`start.coordinate = routeData.coordinates.first!` 여기서 에러가 발생했다.

SummaryView 내부에 MapView가 있는데, `@Query` 결과가 로딩되기 전에 MapView가 먼저 렌더링되면서 `coordinates`가 빈 배열인 상태로 `first!` 강제 언래핑을 시도하기 때문이다.

좌표가 비어있을 때는 임시로 `RoundedRectangle`를 보여주도록 처리했다.

```swift
if !coordinates.isEmpty {
    RouteMapView(routeData: RouteData(coordinates: coordinates))
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
} else {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.rwPanel2)
        .frame(height: 200)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
}
```

하지만 지도가 나오지 않았다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/nmap.png){: width="50%" height="50%"}

좌표가 비어있다는 뜻이므로 저장 로직을 확인해보니, `saveRunningData()`에서 `SwiftDataFlight`만 저장하고 좌표는 전혀 담지 않았던 것이 원인이었다.

또한 Alert도 PFDView에서 개별 저장은 되고 있지만, 처음에 의도했던 `@Relationship` 구조로 `SwiftDataFlight`와 연결되는 방식은 아직 구현되지 않은 상태다.

두 가지를 함께 수정한다.

---

##### Coordinate 수정

현재 좌표에 대한 값을 저장하는 코드가 없다. 좌표는 `RunningCentor` Actor의 `coordinateArray`에 쌓이고 있으므로, 이를 ViewModel로 꺼내오는 구조가 필요하다.

먼저 ViewModel에 좌표 배열 프로퍼티를 추가한다.

```swift
var coordinateArray = [(latitude: Double, longitude: Double)]()
```

Actor에서는 별도 함수 없이 `coordinateArray`를 직접 읽으면 된다.

그 다음 `stop()`에서 Actor의 좌표를 ViewModel로 옮기고 나서 `resetState()`를 호출해야 한다. `reset()`에서 Actor의 `coordinateArray`가 초기화되기 전에 값을 가져와야 하기 때문이다.

처음에는 별도 함수로 분리하려 했다.

```swift
// ❌ 순서 보장 안 됨
func getCoordinates() {
    Task {
        coordinateArray = await runningCenter.coordinateArray
    }
}

func stop() {
    locationService.stopTracking()
    timerCancellable.removeAll()
    getCoordinates()   // Task가 끝나기 전에 아래 줄이 실행될 수 있음
    resetState()       // reset()에서 coordinateArray가 이미 초기화될 수 있음
}
```

하지만 문제는 함수 분리 자체가 아니라 Task를 내부에서 생성한 점이었다.

`getCoordinates()`는 Task를 시작만 하고 즉시 반환하므로, `stop()`에서는 좌표를 가져오기 전에 `resetState()`가 먼저 실행될 수 있다.

즉 Actor의 coordinateArray가 초기화된 뒤에 좌표를 읽게 되는 레이스가 발생할 수 있다.

그래서 좌표 조회와 초기화를 하나의 Task 안에서 순차적으로 실행하도록 변경했다.

```swift
// ✅ 순서 보장
func stop() {
    locationService.stopTracking()
    timerCancellable.removeAll()
    Task {
        coordinateArray = await runningCenter.coordinateArray
        resetState()
    }
}
```

하나의 `Task` 안에서 `await`로 좌표를 받은 후 `resetState()`를 호출하면 순서가 보장된다.

이미지로 이해를 해보면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/task.png){: width="50%" height="50%"}

---

하지만 현재 Touchdown 버튼을 누르면 `saveRunningData()`를 먼저 실행하고 `stop()`을 호출하는 구조다.

```swift
Button {
    saveRunningData()
    runViewModel.stop()
    navigateToTouchdown = true
}
```

문제는 `coordinateArray`가 `stop()` 내부의 `Task`에서 Actor로부터 가져오는 구조라, `saveRunningData()`가 실행되는 시점에는 아직 `coordinateArray`가 비어있다는 점이다.

좌표 저장과 리셋의 순서 문제를 해결하기 위해 버튼의 동작 전체를 하나의 `Task`로 묶었다. `saveRunningData()`가 완료된 후 `stop()`이 호출되므로 좌표 초기화 전에 저장이 보장된다.

```swift
Button {
    Task {
        await saveRunningData()
        runViewModel.stop()
        navigateToTouchdown = true
    }
}
```

`saveRunningData()`에서는 `await runViewModel.getCoordinates()`로 Actor에서 좌표 배열을 받아와 `SwiftDataCoordinate`로 변환하여 `runningData`에 연결한다.

그리고 `enumerated()`로 각 좌표에 순서 번호를 부여했다. 이후 `order` 기준으로 정렬하면 러닝 시작 시점부터의 좌표 순서를 쉽게 복원할 수 있다.

```swift
func saveRunningData() async {
    let totalDistance = runViewModel.flightData.distance / 1000
    let totalTime = runViewModel.elapsedTime
    let totalPace = (Double(totalTime) / 60) / totalDistance
    let mode = runViewModel.isModeA ? "modeA" : "modeB"
    let coords = await runViewModel.getCoordinates()
    
    let runningData = SwiftDataFlight(mode: mode, distance: totalDistance, time: totalTime, pace: totalPace, heartRate: 0, cadence: 0, fuel: 0, date: .now)
    
    for (index, coord) in coords.enumerated() {
        let coordinate = SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: index)
        runningData.coordinates.append(coordinate)
    }
    
    modelContext.insert(runningData)
}

// VM
func getCoordinates() async -> [(latitude: Double, longitude: Double)] {
        return await runningCenter.coordinateArray
    }
```

다만 ViewModel에 추가했던 `coordinateArray` 프로퍼티는 `getCoordinates()`가 Actor에서 직접 반환하는 구조로 바뀌면서 더 이상 필요하지 않아 제거했다.

---

##### Alerts 수정

이왕 하는 김에 Alerts도 같이 담기게끔 해준다.

현재 Alerts는

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

`onChange`를 통해 GPWS 상태가 바뀔 때마다 즉시 SwiftData에 저장된다. 이 구조에서 `saveRunningData()`에 Alert를 연결하려면 두 가지 방법이 있다.

1. 실시간 저장 대신 임시 배열에 쌓아두다가 러닝 종료 시 한꺼번에 SwiftData에 저장
2. 지금처럼 실시간 저장을 유지하고, `saveRunningData()` 시점에 SwiftData에서 fetch해서 연결

2번은 `modelContext.fetch()`로 바로 꺼낼 수 있어 구현은 간단하다.

하지만 현재 `saveRunningData()`는 러닝 중 수집한 데이터를 ViewModel에서 모아두었다가, 종료 시 하나의 Flight로 조립하여 저장하는 흐름이다.

Alert만 SwiftData에서 다시 조회해 연결하면 데이터 수집 경로가 Alert와 나머지 데이터로 나뉘게 된다.

1번은 모든 데이터를 동일하게 메모리에서 관리하다가 종료 시 한 번에 저장하므로 현재 구조와 더 일관성이 있다고 판단하여 1번으로 진행한다.

---

먼저 `saveAlert()`를 수정한다. `modelContext.insert()` 대신 ViewModel의 임시 배열에 쌓는 방식으로 바꾼다.

```swift
func saveAlert() {
    // 생략
    runViewModel.tempAlertArray.append(gpwsAlert)
}

// VM
var tempAlertArray: [SwiftDataAlert] = []
```

그리고 `saveRunningData()`에서 해당 배열을 `runningData.alerts`에 연결하여 한 번에 저장한다.

```swift
func saveRunningData() async {
    // 생략
    let totalAlerts = runViewModel.tempAlertArray
    // 생략
    runningData.alerts.append(contentsOf: totalAlerts)
    modelContext.insert(runningData)
}
```

`@Relationship`으로 연결되어 있으므로 `runningData`를 `insert()`하면 Alert도 함께 저장된다.

마지막으로 `resetState()`에서 임시 배열도 초기화해야 한다. 그렇지 않으면 다음 러닝 시작 시 이전 Alert가 남아있게 된다.

```swift
func resetState() {
    // 생략
    tempAlertArray = []
    // 생략
}
```

이제 작동하는지 테스트를 해보도록 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/drive.gif){: width="50%" height="50%"}

이렇게 나오는걸 알 수 있다.

---

#### Summary에 Alerts 추가하기

지도 위에 GPWS 경고 발생 지점을 표시한다. `lastestFlight?.alerts`를 `RouteMapView`에 넘겨 annotation으로 찍는 구조다.

```swift
var alerts: [SwiftDataAlert] {
    lastestFlight?.alerts ?? []
}

// RouteMapView 호출부
RouteMapView(routeData: RouteData(coordinates: coordinates), alerts: alerts)
```

`RouteMapView`에서는 `alerts`를 순회하며 각 좌표에 annotation을 추가한다. SINK RATE는 빨간색, OVERSPEED는 amber로 구분하여 어느 지점에서 어떤 경고가 발생했는지 시각적으로 확인할 수 있다.

```swift
if let alerts = self.alerts, !alerts.isEmpty {
    for alert in alerts {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)
        annotation.title = alert.gpwsState
        mapView.addAnnotation(annotation)
    }
}
```

이제 테스트를 해본다 (목표 페이스 4:30, 오차 10s)

3분가량 시뮬레이터를 켜두고 테스트를 했다 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/firsttest.gif){: width="50%" height="50%"}

일단 지도에는 찍히나 sinkrate는 갑자기 사라졌다. 그리고 탭해도 어떤 정보인지 보이지가 않았다.

1. Sinkrate 사라짐 문제
2. 탭했을때 보이지 않는 문제

---

순서대로 해결해본다.

**1번** — annotation이 일부만 표시되거나 사라지는 문제였다. 두 가지 원인이 있었다.

첫 번째는 `updateUIView`를 비워두었던 구조 문제였다. `@Query` 결과가 업데이트될 때 SwiftUI가 `updateUIView`를 호출하는데 거기서 아무것도 하지 않으니 annotation이 반영되지 않았다. `updateUIView`에서 기존 overlay/annotation을 제거하고 다시 그리는 방식으로 변경했다.

두 번째는 MapKit의 Collision Avoidance 동작이었다. 시뮬레이터 특성상 좌표가 1m 내외로 밀집되는 경우가 생기는데, 이때 MapKit이 가독성을 위해 우선순위가 낮은 annotation을 임의로 숨기는 최적화 알고리즘이 작동한다.

당시 저장된 좌표 예시를 보면

```text
sinkRate  37.33065541, -122.03032381
sinkRate  37.33067157, -122.03024990
overspeed 37.33070704, -122.03039943
```

위도·경도 소수점 5번째 자리 차이는 실제 거리로 약 1m 내외다. `frame(height: 200)`의 작은 지도에서는 이 차이가 몇 픽셀에 불과해 마커가 겹치게 된다.

`displayPriority = .required`를 추가하여 겹치더라도 무조건 표시하도록 강제했다.

실기기에서 실제로 뛰면 좌표가 충분히 분산되어 이 문제는 자연스럽게 완화될 것으로 예상된다.

```swift
func updateUIView(_ uiView: MKMapView, context: Context) {
    guard !routeData.coordinates.isEmpty else {
        uiView.removeAnnotations(uiView.annotations)
        uiView.removeOverlays(uiView.overlays)
        return
    }
    
    uiView.removeOverlays(uiView.overlays)
    uiView.removeAnnotations(uiView.annotations)
    
    uiView.setRegion(routeData.region, animated: false)
    
    let polyline = MKPolyline(
        coordinates: routeData.coordinates,
        count: routeData.coordinates.count
    )
    uiView.addOverlay(polyline)

    if let first = routeData.coordinates.first {
        let start = MKPointAnnotation()
        start.coordinate = first
        start.title = "START"
        uiView.addAnnotation(start)
    }

    if let last = routeData.coordinates.last {
        let end = MKPointAnnotation()
        end.coordinate = last
        end.title = "END"
        uiView.addAnnotation(end)
    }

    if let alerts = self.alerts, !alerts.isEmpty {
        for alert in alerts {
            let annotation = AlertAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)
            annotation.title = alert.gpwsState
            annotation.pace = alert.pace
            annotation.distance = alert.distance
            annotation.timestamp = alert.timestamp
            uiView.addAnnotation(annotation)
        }
    }
}
 func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    //생략
    view.displayPriority = .required
 }
```

이부분은 AI의 도움을 받아 해결했다.

- [MKMarkerAnnotationView](https://developer.apple.com/documentation/mapkit/mkmarkerannotationview){:target="_blank"} — 기본 `displayPriority`가 `defaultLow`임을 명시
- [MKAnnotationView - displayPriority](https://developer.apple.com/documentation/mapkit/mkannotationview/displaypriority){:target="_blank"} — `required`로 설정하면 항상 표시, 다른 우선순위는 숨겨질 수 있음
- [MKFeatureDisplayPriority](https://developer.apple.com/documentation/mapkit/mkfeaturedisplaypriority){:target="_blank"} — `required`, `defaultHigh`, `defaultLow` 상수 정의

---

**2번** — annotation을 탭해도 정보가 표시되지 않은 건 `canShowCallout`이 설정되지 않은 것이 원인이었다. 또한 페이스/거리/시간을 callout에 보여주려면 `MKPointAnnotation`에 해당 프로퍼티가 없어서 커스텀 클래스가 필요했다.

```swift
@MainActor
class AlertAnnotation: MKPointAnnotation, @unchecked Sendable {
    var pace: Double = 0
    var distance: Double = 0
    var timestamp: Date = .now
    
    nonisolated override init() {
        super.init()
    }
}
```

다만 `MKPointAnnotation`을 상속할 때 Swift 6 동시성 규칙에서 actor isolation 불일치 에러가 발생했다. 이 부분은 AI 도움을 받아 해결했다.

부모 `init()`은 `nonisolated`인 반면 하위 클래스 자동 생성 `init()`은 `@MainActor`에 격리되어 충돌하는 문제로, `nonisolated override init()`을 명시적으로 추가하여 해결했다.

callout에는 페이스, 거리, 발생 시각을 표시했다.

```swift
case "sinkRate":
    view.markerTintColor = UIColor(Color.rwRed)
    view.glyphTintColor = .white
    view.glyphImage = UIImage(systemName: "arrow.down.circle.fill")
    view.canShowCallout = true
    if let a = annotation as? AlertAnnotation {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.text = "\(PaceFormatter.format(a.pace))/km · \(String(format: "%.2f km", a.distance / 1000)) · \(formatter.string(from: a.timestamp))"
        label.numberOfLines = 0
        view.detailCalloutAccessoryView = label
    }
```

이제는 실행하니 잘 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/done.png){: width="50%" height="50%"}

여기까지 오면서 생각보다 많은 문제가 있었다. 단순히 데이터를 연결하는 작업이라 생각했는데 `UIViewRepresentable` 라이프사이클, SwiftData 저장 순서, MapKit의 내부 최적화 알고리즘까지 다양한 문제가 얽혀있었다.

AI 도움을 받은 부분도 있었지만 문제가 뭔지 파악하고 어떤 방향으로 해결할지는 직접 판단했다. 결과적으로 의도한 대로 경로와 Alert 지점이 지도 위에 표시되는 걸 확인했다.

---

##### UIViewRepresentable 라이프사이클

annotation이 사라진 근본적인 원인은 `UIViewRepresentable` 라이프사이클을 제대로 이해하지 못한 것이었다.

처음에는 `makeUIView()`에서 Polyline과 Annotation을 모두 추가했다.

```swift
func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView()
    // Polyline 추가
    // Annotation 추가
    return mapView
}
```

"alerts가 바뀌면 SwiftUI가 알아서 다시 그려주겠지"라고 생각했는데, `UIViewRepresentable`은 일반 SwiftUI View와 다르게 동작한다.

`makeUIView()`는 UIKit View를 처음 한 번 생성할 때만 호출된다. 이후 SwiftUI 상태가 변경되면 기존 `MKMapView`를 재사용하면서 `updateUIView()`만 호출하는 구조다.

```text
앱 시작 → makeUIView() → MKMapView 생성
@Query 변경 → updateUIView() 호출 → 기존 MKMapView 재사용
```

`updateUIView()`를 비워두었으니 SwiftData에 Alert가 저장되어도 지도에는 반영되지 않았던 것이다.

해결은 `updateUIView()`에서 기존 데이터를 모두 지우고 다시 그리도록 수정했다.

```swift
func updateUIView(_ uiView: MKMapView, context: Context) {
    uiView.removeAnnotations(uiView.annotations)
    uiView.removeOverlays(uiView.overlays)
    // Polyline, Annotation 다시 추가
}
```

일반 SwiftUI View는 상태가 바뀌면 body 전체가 다시 계산되지만, `UIViewRepresentable`은 UIKit View를 새로 만들지 않고 재사용한다. 그래서 데이터가 바뀌면 `updateUIView()`에서 직접 반영해야 한다는 점을 기억해야 한다.

처음 Mock UI를 만들 때는 데이터가 고정값이라 `updateUIView()`를 비워두어도 문제가 없었다. 실제 `@Query` 데이터로 교체하면서 비로소 이 문제가 드러났다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/uiview.png){: width="50%" height="50%"}

---

## LogbookView 실제 데이터 연동

먼저 LogbookView를 수정한다. 테스트 데이터가 계속 쌓이는 문제를 해결하기 위해 삭제 기능도 함께 추가할 예정이라 이 작업을 먼저 진행한다.

전체, ModeA, ModeB 각각의 데이터를 불러오도록 `@Query`를 작성한다. SwiftData 필터 사용법은 [Fetching, sorting, and filtering data](https://developer.apple.com/tutorials/app-dev-training/swiftdata-sorting-and-filtering){:target="_blank"}를 참고했다.

```swift
@Query(sort: \SwiftDataFlight.date, order: .reverse) private var flights: [SwiftDataFlight]

@Query(filter: #Predicate<SwiftDataFlight> { data in
    data.mode.contains("modeA")
}) var modeAFlights: [SwiftDataFlight]

@Query(filter: #Predicate<SwiftDataFlight> { data in
    data.mode.contains("modeB")
}) var modeBFlights: [SwiftDataFlight]
```

선택된 필터에 따라 다른 배열을 반환하는 computed property를 추가한다.

```swift
var filteredFlights: [SwiftDataFlight] {
    switch selectedFilter {
    case 0: return flights
    case 1: return modeAFlights
    case 2: return modeBFlights
    default: return flights
    }
}
```

`filteredFlights`를 `ForEach`에 적용하면 필터 탭에 따라 목록이 바뀐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/log.gif){: width="50%" height="50%"}

탭바 배경이 떴다 사라지는 건 알려진 버그로 각 뷰에 `.toolbarBackground(.hidden, for: .tabBar)`를 개별 적용하여 처리했다.

위의 Map을 테스트하다보니 상당히 많은 데이터가 쌓여있다...

---

### LogbookView와 SummaryView 연동

#### SummaryView 수정

이제 로그북에서 특정 러닝을 탭하면 해당 기록의 SummaryView를 보여주려 한다.

문제는 현재 `FlightSummaryView`가 `@Query`로 가장 최근 Flight만 가져오는 구조라는 점이다. 러닝이 끝난 직후에는 최신 데이터가 곧 방금 끝낸 러닝이니 문제가 없지만, 로그북에서 특정 날짜의 기록을 탭했을 때는 그 flight를 직접 넘겨줘야 한다.

```swift
let selectedFlight: SwiftDataFlight?
    
var displayFlight: SwiftDataFlight? {
    selectedFlight ?? lastestFlight
}
```

`selectedFlight`를 옵셔널로 선언하고, `displayFlight` computed property에서 값이 있으면 `selectedFlight`를, 없으면 `lastestFlight`를 사용하도록 분기했다.

TouchdownView에서는 파라미터 없이 호출하여 `lastestFlight`를 사용하고, LogbookView에서는 선택한 flight를 넘겨 해당 기록을 표시하게 된다.

---

#### LogbookView 수정

```swift
ForEach(filteredFlights) { entry in
    NavigationLink(destination: FlightSummaryView(selectedFlight: entry)) {
        LogEntryRow(flight: entry)
    }
    .buttonStyle(.plain)
}
```

여긴 사실 별거 없다. 

해당되는 entry를 그대로 전달 해주기만 하면 된다.

---

#### 문제 수정

LogbookView에서 SummaryView로 넘어가면 지도가 이전 러닝 데이터 그대로 남아있는 문제가 있었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/problem.gif){: width="50%" height="50%"}

원인은 `coordinates`와 `alerts`가 `lastestFlight`를 참조하고 있어서 `selectedFlight`로 어떤 값이 넘어와도 항상 최신 Flight 데이터를 보여주고 있었기 때문이다.

```swift
// before
var coordinates: [CLLocationCoordinate2D] {
    lastestFlight?.coordinates ...
}
var alerts: [SwiftDataAlert] {
    return lastestFlight?.alerts ?? []
}

// after
var coordinates: [CLLocationCoordinate2D] {
    displayFlight?.coordinates ...
}
var alerts: [SwiftDataAlert] {
    return displayFlight?.alerts ?? []
}
```

`displayFlight`를 참조하도록 바꾸어 선택한 Flight에 맞는 데이터가 표시되도록 했다.

그리고 Logbookview 최신순으로 정렬하도록 했다. (최신순으로 안해서 어제의 테스트 데이터는 gpws 알람 발생시 좌표를 저장하지 않았는데 날짜를 잘못보고 오류인줄 알았다.)

```swift
@Query(filter: #Predicate<SwiftDataFlight> { data in
    data.mode.contains("modeA")
}, sort: \SwiftDataFlight.date, order: .reverse) var modeAFlights: [SwiftDataFlight]

@Query(filter: #Predicate<SwiftDataFlight> { data in
    data.mode.contains("modeB")
}, sort: \SwiftDataFlight.date, order: .reverse) var modeBFlights: [SwiftDataFlight]
```

실행해보니 잘 되는걸 알 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/summarydone.gif){: width="50%" height="50%"}

그리고 Logbook으로 들어갔는데 또 Logbook으로 가게되는 로직은 view의 구조가 이상해지기 때문에 이걸 방지하도록 한다.

```swift
if selectedFlight == nil {
    Button {
        navigateToLogbook = true
    } label: {
        Text("SAVE TO LOGBOOK")
            .font(.orbitron(13, weight: .bold))
            .foregroundColor(.rwBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.rwGreen)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 36)
}
```

`selectedFlight`에 값이 없을때 즉 러닝후에만 버튼이 활성화 되도록 바꿔주었다.

---

또 다른 문제가 있었다. SAVE TO LOGBOOK 버튼을 누르면 앱이 멈추는 현상이 발생했다.

원인은 `FlightSummaryView`가 LogbookView와 러닝 종료 두 가지 경로에서 진입 가능한 구조이기 때문이다. LogbookView에서 Summary를 확인한 뒤, 러닝을 마치고 다시 Summary로 들어와 SAVE TO LOGBOOK 버튼으로 LogbookView를 push하면 NavigationStack에 뷰가 중첩으로 쌓이면서 흐름이 꼬이게 된다.

이 부분은 AI 도움을 받아 해결했다.

해결 방법은 버튼을 누르면 홈으로 직접 이동하도록 `AppState`를 만들어 NavigationStack을 리셋하는 방식이다.

```swift
// AppState.swift
@Observable
class AppState {
    static let shared = AppState()
    var sessionID = UUID()
    
    func reset() {
        sessionID = UUID()
    }
}

// SummaryView
if selectedFlight == nil {
    Button {
        AppState.shared.reset()
    } label: {
        Text("GO TO DECK")
            .font(.orbitron(13, weight: .bold))
            .foregroundColor(.rwBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.rwGreen)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 36)
}
```

먼저 LogbookView에서는 버튼이 안보이게 해두었다. 그리고 `TabView`에 `.id(AppState.shared.sessionID)`를 붙여두면 `reset()`이 호출될 때 NavigationStack이 초기화되면서 홈 화면으로 돌아간다. 

버튼 텍스트도 `GO TO DECK`으로 변경했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/logbookimage.png){: width="50%" height="50%"}

이번 작업을 하면서 렌더링, 라이프사이클, NavigationStack 구조 등 평소에 깊게 다루지 않았던 부분에서 AI 도움을 많이 받았다. 나중에 이 개념들을 딥다이브 형식으로 한번 정리해볼 필요가 있다고 느꼈다.

---

## FlightSummaryView 보완

FlightLoad는 필요없을듯해서 지우고 하단 ui을 4개로만 만들어 주었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/ui.png){: width="50%" height="50%"}

5개에서 4개로 변경

---

## HomeView LastFlight 실제 데이터 연동

HomeView의 LAST FLIGHT 섹션이 아직 하드코딩된 샘플 데이터로 표시되고 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/sample.png){: width="50%" height="50%"}

"Busan Night Run" 텍스트부터 거리, 페이스, 날짜까지 전부 고정값이다. 이제 실제 SwiftData 데이터로 교체한다.

`@Query`로 최신 Flight를 가져오고, 경로 미리보기용 좌표 배열도 함께 변환한다.

```swift
@Query(sort: \SwiftDataFlight.date, order: .reverse) private var flights: [SwiftDataFlight]

var lastestFlight: SwiftDataFlight? {
    flights.first
}

var routeCoordinates: [CLLocationCoordinate2D] {
    lastestFlight?.coordinates
        .sorted { $0.order < $1.order }
        .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? []
}
```

하드코딩된 값들을 실제 데이터로 교체하고, 경로가 없을 때는 미리보기를 표시하지 않도록 처리했다.

```swift
Text(lastestFlight?.date.formatted(date: .abbreviated, time: .omitted) ?? "--")
Text(String(format: "%.2f", lastestFlight?.distance ?? 0))
Text(PaceFormatter.format(lastestFlight?.pace ?? 0) + "/km")

if !routeCoordinates.isEmpty {
    GeometryReader { geo in
        // 경로 미리보기
    }
    .frame(width: 100, height: 90)
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/homedone.png){: width="50%" height="50%"}

지금 미리보기상 아래로 치우치는데, 이건 실제러닝을 해봐야 조금 더 자세히 파악이 가능 할 것같다.

---

그리고 원래는 GeoCoder를 통해 최근 러닝에 대해서 어느지역의 러닝이라고 하려고 했지만 생각해보니 굳이 그런 개인정보를 노출할 필요는 없다고 판단.

그냥 시간대와 모드의 조합으로 바꿔 주었다.

```swift
var timeOfDay: String {
    let hour = Calendar.current.component(.hour, from: lastestFlight?.date ?? .now)
    switch hour {
    case 5..<12: return "Morning"
    case 12..<17: return "Afternoon"
    case 17..<21: return "Evening"
    default: return "Night"
    }
}

Text("\(timeOfDay) \(lastestFlight?.mode == "modeA" ? "Mission" : "Free") Run")
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-10-RunningProject-9/text.png){: width="50%" height="50%"}

이렇게 시간대로 하게끔 했다.

지금은 SwiftData를 전부 밀어서 저렇다.

---

## 실기기 테스트

시뮬레이터에서 확인하지 못했던 부분들을 실기기로 테스트했다. 전반적인 동작은 정상이었으나 몇 가지 문제를 발견했다.

**정상 동작 확인**
- 백그라운드 위치 추적 (잠금화면 상태)
- MapPolyline 경로 표시
- Alert Annotation 정상 표시

**발견된 문제**
- ModeAView 버튼 꾹 눌러야 동작
- 러닝 재시작 시 이전 거리 누적
- GPWS Alert 연속 발생 (SINK RATE ↔ OVERSPEED)
- 방향 전환 시 페이스 100분대로 튀는 현상
- ModeA 페이스 오차 범위 진입 후 GPWS 비활성화
- MINIMUMS도 GPWS 비활성화와 함께 작동 안 함
- 신호 대기 시 일시정지 기능 없음

페이스 관련 문제들은 GPS raw data 보정이 없어서 생기는 것으로 판단했다. Week 3에서 smoothing 처리를 통해 개선할 예정이다.

---

CoreLocation 보정을 하기위한 좋은 참고글이있어 별도로 정리해둔다.

- [Vol.1 — CoreLocation 소개](https://medium.com/how-to-track-users-location-with-high-accuracy-ios/tracking-location-in-ios-vol-1-introduction-98c535e646a9){:target="_blank"}
- [Vol.3 — 백그라운드 추적, distanceFilter](https://medium.com/how-to-track-users-location-with-high-accuracy-ios/tracking-highly-accurate-location-in-ios-vol-3-7cd827a84e4d){:target="_blank"}
- [Vol.5 — 위치 필터링 (핵심)](https://medium.com/how-to-track-users-location-with-high-accuracy-ios/make-it-even-better-than-nike-how-to-filter-locations-tracking-highly-accurate-location-in-774be045f8d6){:target="_blank"}
- [Freeletics GPS 정확도 테스트 가이드](https://freeletics.engineering/2019/06/03/ios_gps_testing.html){:target="_blank"}