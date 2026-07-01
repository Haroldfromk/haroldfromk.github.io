---
title: RunWay (6) ViewModel과 View 데이터 흐름 연결
writer: Harold
date: 2026-06-07 08:33:00 +0900
# last_modified_at: 2026-06-07 08:33:00 +0800
categories: [RunWay]
tags: [AsyncStream, ViewModel, Observable, MainActor, SwiftUI]

toc: true
toc_sticky: true
published: true
---

## PFD 실시간 데이터 표시
### PFDView가 요구하는 데이터

Mock UI 기준으로 PFDView에 하드코딩된 값들을 추려보면 아래와 같다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/CleanShot_07-08.23.png){: width="50%" height="50%"}

- 현재 페이스 (`5'32"`), 평균 페이스
- 누적 거리 (`8.42` km)
- 고도 (`0.42` km)
- 경과 시간 (`48:12`)
- 방향 (`N 180°`)

이 중 ADI의 경사도(`-1.2%`)와 수직속도(`VS -0.6 m/s`), 심박수(`HR N1%`), 케이던스(`CAD N1%`)는 Apple Watch 연동 후에 연결할 데이터라 지금은 하드코딩 유지한다.

현재 `locationPublisher`로 전달되는 `lastLocations`가 PFD에 필요한 값들을 이미 다 들고 있다.

- `lastLocations.speed` → m/s → min/km 변환으로 페이스 계산 가능
- `lastLocations.course` → 방향 (0~360°)
- 거리 - `RunningCentor`에서 이미 계산 중
- 경과 시간 - 러닝 시작 시점 기준으로 ViewModel에서 관리

즉 publisher를 통해 실시간으로 스트림되고 있는 값을 꺼내서 쓰기만 하면 된다. `FlightData`에 추가가 필요하다.

---

#### FlightData 추가 모델링

현재는 기본 뼈대만 잡아놓은 상태라 거리와 페이즈밖에 없다.

```swift
struct FlightData {
    var distance: Double = 0
    var phase: FlightPhase = .preflight
}
```

하지만 위에서 언급한대로 페이스, 고도, 방향 값이 추가로 필요하다.

여기서 한 가지 결정이 필요했다. 계산된 값들을 ViewModel에서 별도 프로퍼티로 관리할 건지, 아니면 `FlightData`에 담아서 넘길 건지.

우리 아키텍처에서 `RunningCentor`는 모든 계산을 총괄하는 역할이다. `locationPublisher`로 실시간 위치 정보를 받아 가공하고, 그 결과를 `AsyncStream<FlightData>`로 흘려보내는 구조다. 

즉 ViewModel이 계산에 끼어들면 책임이 분산되고 구조의 일관성이 깨진다.

따라서 계산 결과까지 `FlightData`에 모델링하여 `RunningCentor`에서 한 번에 넘기는 방식으로 결정했다.

```swift
struct FlightData {
    var distance: Double = 0
    var phase: FlightPhase = .preflight
    var pace: Double = 0
    var altitude: Double = 0
    var heading: Double = 0      
}
```

그래서 이렇게 모델링을 해주었다.

`FlightData`에 초기값이 모두 설정되어 있어서 기존 코드에서 빌드 에러는 발생하지 않는다. Swift에서 struct는 값 타입이라 초기값이 있는 프로퍼티는 생성 시 생략이 가능하기 때문이다.

하지만 이건 함정이다. `processLocation`에서 `FlightData`를 생성할 때 새로 추가한 값들을 실제로 채워주지 않으면 전부 `0`으로 흘러가도 컴파일러가 잡아주지 않는다. 

빌드가 된다고 끝난 게 아니라는 뜻이다.

또한 여기서 경과 시간이 없는 것을 의아하게 생각할 수 있다. 

시간은 러닝 종료 후 `Flight`에 누적 기록으로 저장되는 값이라 `FlightData`에서 관리할 필요가 없다. 실시간 표시는 ViewModel에서 타이머로 별도 관리하며, 러닝 종료 후 `Flight`에 저장된다.

---

##### 값 타입과 참조 타입

여기서 오래간만에 다시 리마인드를 해본다.

Swift에서 `struct`는 값 타입, `class`는 참조 타입이다. 이번 `FlightData`처럼 실시간 스냅샷을 전달하는 용도라면 값 타입이 적합하다. 복사본이 전달되므로 Actor 내부 상태와 ViewModel이 같은 인스턴스를 공유하지 않아 데이터 레이스 위험이 없다.

| 구분 | struct (값 타입) | class (참조 타입) |
|------|------|------|
| 전달 방식 | 복사본 전달 | 참조(주소) 전달 |
| 메모리 | 스택 | 힙 |
| 공유 여부 | 독립적 | 같은 인스턴스 공유 |
| Sendable | 자동 준수 (프로퍼티가 모두 Sendable이면) | 별도 보장 필요 |
| 적합한 용도 | 스냅샷, 데이터 전달 | 상태 공유, 생명주기 관리 |

아래는 이해를 돕기위한 만화

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/structvsclass.png){: width="50%" height="50%"}

---

#### FlightData 처리하기

현재 데이터 흐름을 다시한번 정리하면 아래와 같다.

```text
View (.task) → startStream() → AsyncStream 대기
LocationService → locationPublisher.send() → ViewModel → RunningCentor.processLocation()
                                                                      ↓
                                                          continuation.yield(FlightData)
                                                                      ↓
                                                          ViewModel → View 업데이트
```

여기서 `processLocation`이 계산을 담당하므로, 새로 추가한 `pace`, `altitude`, `heading`도 이 안에서 계산하여 `FlightData`에 담아 넘기면 된다.

```swift
func processLocation(_ location: CLLocation) {
    if let last = lastLocation {
        totalDistance += location.distance(from: last)
    }
    lastLocation = location
    coordinateArray.append((latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
    let rawPace = location.speed
    let rawAltitude = location.altitude
    let rawHeading = location.course
    let flightData = FlightData(distance: totalDistance, phase: phase, pace: rawPace, altitude: rawAltitude, heading: rawHeading)
    continuation?.yield(flightData)
}
```

사실 별거 없다. 이미 위에서 말한대로 `location`이 필요한 정보를 다 가지고 있어서 꺼내서 쓰기만 했다.

데이터가 제대로 출력되는지 확인하기 위해 `print(flightData)`를 추가하고 실행해본다.

```text
FlightData(distance: 7.550938113023038, phase: RunWay.FlightPhase.preflight, pace: 3.64, altitude: 0.0, heading: 108.19)
FlightData(distance: 14.30981173764481, phase: RunWay.FlightPhase.preflight, pace: 3.32, altitude: 0.0, heading: 98.08)
```

데이터가 흘러오는 건 확인했다. 다만 몇 가지 짚어볼 것들이 있다.

우선 `pace`의 경우 [CLLocation.speed Docs](https://developer.apple.com/documentation/corelocation/cllocation/speed){:target="_blank"}를 보면 단위가 m/s라고 나와있다. PFD에 표시하려면 min/km로 변환이 필요하다.

`altitude`는 시뮬레이터 환경이라 `0.0`으로 찍힌다. 실기기에서는 정상적으로 값이 들어온다.

`heading`의 경우 [Getting heading and course information Docs](https://developer.apple.com/documentation/corelocation/getting-heading-and-course-information){:target="_blank"}를 보면 0°가 북쪽 기준이다. 현재 `108.19`는 동쪽 방향인 걸 알 수 있다.

여기서는 굳이 heading에 대해 방향을 같이 넘길필요는 없고, 그저 pace만 바꿔주면된다.

m/s -> min/km로 바꿔주면 된다.

즉 `1 / (speed * 60 / 1000)` 이렇게 계산을 해주면 된다.

```swift
let rawPace = 1 / (location.speed * 60 / 1000)
```

이렇게 변경을 해주고 실행을 하면

```text
FlightData(distance: 608.5788572025573, phase: RunWay.FlightPhase.preflight, pace: 0.5093724531377344, altitude: 0.0, heading: 358.59)
```

이렇게 나온다 (drive로 해놔서 빠르다.)

지금은 이렇게 숫자로 나오지만 view에서 별도로 처리를 다시 해야한다.

---

### PFDView와 연결하기

UI 작업은 AI의 도움을 받아 빠르게 처리했다. 데이터 흐름과 동시성 로직에 집중하기 위한 선택이다.

여기서 한 가지 정리가 필요했다. 지금까지는 테스트 목적으로 각 View에서 ViewModel을 개별 생성해서 썼는데, PFDView까지 연결하려면 동일한 인스턴스를 여러 View가 공유해야 한다. 각자 생성하면 서로 다른 인스턴스라 데이터가 공유되지 않는다.

그래서 `RunWayApp`에서 단 한 번 생성하고 `.environment`로 하위 View 전체에 주입하는 방식으로 전환했다.

```swift
struct RunWayApp: App {
    @State private var runViewModel = RunViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // 생략
            }
            .environment(runViewModel)
        }
    }
}

struct PFDView: View {
    @Environment(RunViewModel.self) var runViewModel
    //생략

    .task {
        await runViewModel.startStream()
    }
}
```

이렇게 해주면 된다.

그리고 이젠 MapTestView가 필요없어서 삭제해준다.

#### ViewModel 수정

현재 `startStream()`에서는 `distance`만 꺼내서 별도 프로퍼티로 관리하고 있다. 하지만 `FlightData`에 프로퍼티가 추가될수록 ViewModel도 같이 늘어나는 구조라 좋지 않다.

애초에 스트림으로 받는 값 자체가 `FlightData`인데 굳이 꺼내서 따로 관리할 이유가 없다. `FlightData`를 통째로 ViewModel 프로퍼티로 두고 받으면 이후 프로퍼티가 추가되어도 ViewModel을 건드릴 필요가 없다.

```swift
var flightData = FlightData()

func startStream() async {
    for await data in await runningCenter.streamFlightData() {
        self.flightData = data
    }
}
```

---

#### View 수정

이제 하드코딩된 값을 실제 데이터로 교체한다.

PFDView는 크게 5개 영역으로 나뉜다. 왼쪽의 페이스를 담당하는 `SpeedTapeView`, 가운데 방향과 자세를 보여주는 `ADIView`, 오른쪽 고도를 담당하는 `AltTapeView`, 하단의 누적 거리를 표시하는 `DIST` 카드, 그리고 경과 시간을 표시하는 `FLIGHT TIME` 카드다.

단 ADIView, AltTapeView의 경우 Watch와의 연동이 필요해 여기서는 구현하지 않는다.

---

##### SpeedTapeView 수정

먼저 pace를 담당하는 SpeedTapeView부터 수정해본다.

우선 위의 결과를 보면 분초 식으로 나와야하는데 소수점으로 나온다. 이걸 먼저 변환하기 위한 함수를 만든다.

```swift
func formatPace(_ pace: Double) -> String {
    guard pace.isFinite, pace > 0 else {
        return "--:--"
    }

    let totalSeconds = Int(round(pace * 60))

    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60

    return String(format: "%d:%02d", minutes, seconds)
}
```

`pace`는 현재 min/km 단위의 `Double`값이다. 이걸 화면에 `5'32"` 형식으로 표시하려면 변환이 필요하다.

우선 `guard`문에서 `pace.isFinite`로 값이 유한한지 확인한다. GPS 신호가 불안정하거나 속도가 0일 때 `infinity`나 `nan`이 들어올 수 있는데, `isFinite`는 이 두 경우를 한 번에 걸러준다. 유효하지 않은 값이면 `--:--`를 반환한다.

유효한 값이면 `pace * 60`으로 전체 초를 구하고, `60`으로 나눈 몫이 분, 나머지가 초가 된다.

기존에 pace를 나타내던곳에 

```swift
Text(formatPace(runViewModel.flightData.pace))
```

로 해준다.

실행해보면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/Jun-07-2026%2012-42-59.gif){: width="50%" height="50%"}

반영이 잘 되는걸 알 수 있지만 페이스 범위가 맞지 않는다. 현재 페이스에 대해서 유동적으로 범위가 변해야할 필요가 있다.

---

###### pace 동적 관리

현재 페이스 기준으로 위에 2개 아래 2개 그리고 중간값 이렇게 5개가 필요하다.

페이스를 15초(`0.25 min/km`) 단위로 반올림하여 가운데 기준값을 잡고, 위아래로 15초씩 배열을 만든다.

만약 페이스가 `4'29"`라면 `4'30"`을 기준으로 `[4'00", 4'15", 4'30", 4'45", 5'00"]` 이렇게 배열이 만들어져야 한다.

먼저 페이스 기준 반올림을 구하는 로직을 만들어야한다.

```swift
(pace / 0.25).rounded() * 0.25
```

---

식을 정리해보면 `0.25`는 0.25분, 즉 15초를 의미한다.

페이스를 0.25로 나눠서 반올림한 뒤 다시 0.25를 곱하면 가장 가까운 15초 단위로 보정된다.

예를 들어 페이스가 `4.37` min/km라면

```swift
4.37 / 0.25 = 17.48  // 0.25 단위로 몇 칸인지
17.48.rounded() = 17  // 가장 가까운 정수로 반올림
17 * 0.25 = 4.25      // 다시 min/km로 환산
```

즉 `4'22"`는 `4'15"`로 보정된다. 

이렇게 페이스를 `:00`, `:15`, `:30`, `:45` 단위로 끊어서 GPS 오차로 인한 잦은 변동을 줄여준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/pace.png){: width="50%" height="50%"}

이해를 돕기위한 사진을 추가하니 보면 이해가 될듯

---

이제 이 값을 기준으로 배열을 만들어 준다.

```swift
let center = (pace / 0.25).rounded()
let paces = [-2, -1, 0, 1, 2].map { (center + Double($0)) * 0.25 }
```

이렇게 중간값을 설정하고 map을 통해서 바로 시간값을 만들어 주면 된다.

---

UI에 적용을 해본다.

우선 현재 페이스 기준으로 5개 눈금을 만드는 함수를 작성한다.

```swift
func getPaces(_ pace: Double) -> [String] {
    guard pace.isFinite, pace > 0 else {
        return []
    }
    
    let center = (pace / 0.25).rounded()
    let paces = [-2, -1, 0, 1, 2].map { formatPace((center + Double($0)) * 0.25) }
    
    return paces
}
```

다만 이 함수를 `body` 안에서 `ForEach`, 가운데 조건 비교, `.last` 체크에 각각 호출하면 매 렌더링마다 불필요하게 반복 계산이 된다. 계산 프로퍼티로 분리해서 한 번만 계산하도록 한다.

```swift
var dynamicPaces: [String] {
    getPaces(runViewModel.flightData.pace).reversed()
}
```

이후 하드코딩된 부분에 값을 넣어주면 된다.

`.reversed()`를 사용한 이유는 SpeedTape가 위쪽이 빠른 페이스(숫자가 작은 값)이기 때문이다. 배열 그대로 쓰면 위에서부터 느린 페이스가 표시되므로 순서를 뒤집어준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/afterpace.gif){: width="50%" height="50%"}

이제 실행하면 이렇게 값이 바뀌는걸 알 수 있다.

애니메이션으로 하려면 조금 더 찾아봐야할듯하다... (AI의 도움을 받을지도)

---

Avg의 경우 현재 시간값을 가져오지는 않아서 그대로 둔다. (추후 변경 예정)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/avg.png){: width="50%" height="50%"}

---

##### DIST 수정

여긴 별거 없다. 하드코딩된 부분을 아래와 같이 교체한다.

```swift
Text(runViewModel.flightData.distance.formatted(.number.precision(.fractionLength(2))))
```

소수점 둘째 자리까지 표시하기 위해 `.formatted`를 사용했다. [이전 글](https://haroldfromk.github.io/posts/HealthKit-(4)/){:target="_blank"}에서 다뤘던 내용이라 별도 설명은 생략한다.

그런데 현재는 Meter단위라서 변환이 필요하다. 코드가 길어질듯해서 그냥 Computed Property로 방향을 바꾼다.

```swift
var cumulativeDistance: String {
    (runViewModel.flightData.distance / 1000).formatted(.number.precision(.fractionLength(2)))
}
```

---

##### ADIView 수정

여기서 할 수 있는 마지막 데이터 연결이다.

상단 헤딩 테이프의 `270 | N 180° | 90` 부분을 현재 heading 기준으로 동적으로 바꿔준다.

Computed Property 2개를 만든다.

`dynamicDirection`은 현재 heading을 45도 단위로 분류해 방향 문자열을 반환한다. 가운데 표시용이다.

`dynamicHeading`은 현재 heading을 90도 단위로 반올림해 기준값을 잡고, 좌(-90°) · 중 · 우(+90°) 3개 배열을 만든다. 

360도를 넘어가는 경우 `truncatingRemainder`로 보정한다. (즉 나머지를 사용)

```swift
var dynamicDirection: String {
    switch runViewModel.flightData.heading {
    case 0..<22.5, 337.5...360:
        return "N"
    case 22.5..<67.5:
        return "NE"
    case 67.5..<112.5:
        return "E"
    case 112.5..<157.5:
        return "SE"
    case 157.5..<202.5:
        return "S"
    case 202.5..<247.5:
        return "SW"
    case 247.5..<292.5:
        return "W"
    case 292.5..<337.5:
        return "NW"
    default:
        return "--"
    }
}

var dynamicHeading: [String] {
    let center = (runViewModel.flightData.heading / 90).rounded() * 90
    return [-1, 0, 1].map { offset in
        let degree = (center + Double(offset) * 90).truncatingRemainder(dividingBy: 360)
        let adjusted = degree < 0 ? degree + 360 : degree
        switch adjusted {
        case 0: return "N"
        case 90: return "E"
        case 180: return "S"
        case 270: return "W"
        default: return "\(Int(adjusted))°"
        }
    }
}
```

이후 해당 값들을 하드코딩된 부분에 넣어준다.

제대로 되는지 확인을 하기위해 극단적인 변화를 주었다. (Run이 아닌 Drive로 변경)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/change.gif){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/change2.gif){: width="50%" height="50%"}

이렇게 잘 되는걸 알 수 있다.

---

##### Flight Time 구현하기

런닝에서의 핵심인 시간이다. 지금까지는 시간계산보다는 Location이 제공하는 자체 값을 이용해왔었다.

이제는 시작 버튼과 동시에 타이머를 연동해서 초단위로 값을 가져오도록 한다.

처음에는 `elapsedTime`을 `RunningCentor` Actor에서 관리할지 고민했다. Watch, Dynamic Island 등 여러 곳에서 동일한 시간값을 참조해야 하기 때문이다.

고민 과정에서 몇 가지를 짚어봤다. 우선 GPWS 판단 기준이 avg 페이스가 아닌 실시간 페이스다. 실시간 페이스는 `location.speed`에서 바로 뽑기 때문에 Actor가 시간값을 알 필요가 없다. 

그리고 위치 업데이트가 5미터 기준이라 초당 업데이트가 아니다. 빠르게 뛰면 잦고, 느리게 뛰면 드물어지는 거리 기반 구조다. 타이머와는 역할 자체가 다르다.

결국 시간이 Actor에서 필요한 경우는 없었다. 평균 페이스(`totalDistance / elapsedTime`)와 종료 후 `Flight.time` 저장용으로만 쓰이는 값이라 ViewModel에서 관리하는 게 맞다.

위치정보도 Combine을 사용했기에 시간도 Combine의 `Timer.publish`를 써서 구현한다.

---

###### ViewModel 수정하기

`Timer.publish`로 선언하고 `connect()`로 시작 시점을 직접 제어하는 방식을 택했다. `autoconnect()`를 쓰면 구독 즉시 시작되어 일시정지 구현이 어렵기 때문이다.

처음에는 기존 `cancellables`에 함께 넣으려 했다. 하지만 `stop()` 시 location 구독까지 같이 취소되는 문제가 있어 `timerCancellable`을 별도로 분리했다.

분리 후 `timerPublisher.connect().store(in: &timerCancellables)`로 담으려 했는데 에러가 발생했다. `store`는 `Set<AnyCancellable>`을 받아야 하기 때문이다. 

Option을 눌러 `connect()`의 반환 타입을 확인해보면 `any Cancellable`임을 알 수 있다. 그래서 `timerCancellable` 프로퍼티에 직접 `connect()`를 할당하는 방식으로 해결했다.

```swift
var timerPublisher = Timer.publish(every: 1, on: .main, in: .default)
@ObservationIgnored private var timerCancellable: Cancellable?

func start() {
    locationService.startTracking()
    timerCancellable = timerPublisher.connect()
}

func stop() {
    locationService.stopTracking()
    timerCancellable?.cancel()
}
```

---

###### View 수정하기

타이머를 구독하는 주체는 바로 PFDView이다.

단 여기서 잘 생각해야할게 구독 관리이다. 잘못 사용하면 구독이 PFDView 렌더링할 때마다 생성되기 때문이다.

`.onReceive`는 View 생명주기에 맞춰 자동으로 구독을 관리해주기 때문에 별도로 `sink`를 쓸 필요가 없다.

`timerPublisher`가 `Date` 타입을 방출하지만 실제 날짜값은 필요 없고 1초마다 호출됐다는 신호로만 쓰면 되므로 `_`로 무시하고 `elapsedTime`만 올려준다.

```swift
@State private var elapsedTime = 0

.onReceive(runViewModel.timerPublisher) { _ in
    elapsedTime += 1
}

func secondToTime(_ second: Int) -> String {
    let seconds = second % 60
    let minutes = (second / 60) % 60
    let hours = second / 3600
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/timer.gif){: width="50%" height="50%"}

작동은 하지만 두 가지 문제가 있다. 다시 시작했을 때 `elapsedTime`이 리셋되지 않고, 타이머도 재작동하지 않는다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/stop.gif){: width="50%" height="50%"}

---

###### 문제 해결하기

정지 후 다시 시작했을 때 타이머가 재작동하지 않는 문제가 있다.

원인은 `connect()`로 한 번 연결된 `timerPublisher`를 `cancel()` 후 재사용할 수 없기 때문이다. 그래서 `start()` 호출 시마다 `autoconnect()`와 `sink`로 새로 구독하는 방식으로 변경했다. 구독을 `Set<AnyCancellable>`인 `timerCancellable`에 저장하고, `stop()` 시 `removeAll()`로 정리한다.

`elapsedTime`도 View의 `@State`에서 ViewModel로 옮겼다. View에서 관리하면 나중에 `Flight`에 저장할 때 ViewModel로 다시 넘겨야 하는 문제가 생기기 때문이다.

```swift
var timerPublisher = Timer.publish(every: 1, on: .main, in: .default)
var elapsedTime = 0

func start() {
    locationService.startTracking()
    timerPublisher
        .autoconnect()
        .sink { [weak self] _ in
            self?.elapsedTime += 1
        }.store(in: &timerCancellable)
}

func stop() {
    locationService.stopTracking()
    timerCancellable.removeAll()
}
```

View에서는 Computed Property로 시간을 String으로 변환해서 표시한다.

```swift
var elapsedTime: String {
    secondToTime(runViewModel.elapsedTime)
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/done.gif){: width="50%" height="50%"}

이제 정지 후 재시작도 정상 작동한다. 다만 현재는 `stop()` 시 `elapsedTime`을 리셋하지 않는다. 이후 정지와 일시정지를 세분화하면서 함께 처리할 예정이다.

다만 `start()`를 여러 번 누르면 구독이 중복으로 쌓여 `elapsedTime`이 2씩 올라가는 문제가 생길 수 있다. `start()` 진입 시 `timerCancellable.removeAll()`로 기존 구독을 먼저 정리하도록 보완했다.

```swift
func start() {
    locationService.startTracking()
    timerCancellable.removeAll()
    timerPublisher
        .autoconnect()
        .sink { [weak self] _ in
        self?.elapsedTime += 1
    }.store(in: &timerCancellable)
}
```

이해를 돕기위한 이미지

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/connect.png){: width="50%" height="50%"}

참고로 `connect()`는 1회성이다. `cancel()` 이후 재사용이 불가능하다.

---

그리고 또 한가지

같은 기능을 `Task`로도 구현할 수 있다. `Task.sleep`으로 1초를 직접 기다리고, 취소될 때까지 반복하는 구조다.

그리고 `connect()`와 달리 `Task`는 `cancel()` 후 새로 생성하면 재사용이 가능하다.

```swift
// Task 방식
var elapsedTime = 0
private var timerTask: Task<Void, Never>?

func start() {
    timerTask?.cancel()
    timerTask = Task { 
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            elapsedTime += 1
        }
    }
}

func stop() {
    timerTask?.cancel()
    timerTask = nil
}
```

두 방식 모두 동일하게 동작한다. Combine은 이미 프로젝트에서 사용 중인 패턴이라 일관성을 위해 선택했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/timer.png){: width="50%" height="50%"}

---

##### Avg pace 구하기

이제 타이머도 해결되었으니 거리를 이용해서 평균 페이스를 구해서 적용을 해보려 한다.

`elapsedTime(초) / 60`으로 분으로 변환하고, `distance(m) / 1000`으로 km로 변환한 뒤 나누면 min/km 단위의 평균 페이스가 나온다.

```swift
var avgPace: String {
    guard runViewModel.elapsedTime > 0 else { return "--:--" }
    let avgPaceValue = (Double(runViewModel.elapsedTime) / 60) / (runViewModel.flightData.distance / 1000)
    return "AVG " + formatPace(avgPaceValue)
}   
```

이렇게 Computed Property를 이용해 계산한다. 다만 `elapsedTime`은 `Int`라서 `Double`로 형변환을 해주었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/avg.gif){: width="50%" height="50%"}


아래는 오늘 최종적으로 구현한 기능들이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-07-RunningProject-6/ttl.gif){: width="50%" height="50%"}

---

## UI 보완 사항 체크

데이터를 연결하면서 어디가 보완이 필요한지를 좀 확인을 해보았다.

물론 즉각적인 보완이 가능한 부분은 바로바로 해결을 해주었다.

- [x] `AVG` 페이스 하드코딩 - 타이머 구현 후 완료
- [x] `FLIGHT TIME` - 타이머 구현 후 완료
- [x] `AltTapeView` 단위 `km` → `m` 수정 필요 - 완료
- [ ] SpeedTape 애니메이션 미구현