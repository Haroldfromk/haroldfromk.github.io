---
title: RunWay 1.3 (2) 지도 확대 기능과 일시정지 판단 로직 손보기
writer: Harold
date: 2026-08-24 09:00:00 +0900
categories: [RunWay]
tags: [SwiftUI, MapKit, CoreLocation]

toc: true
toc_sticky: true
published: true
---

실사용 피드백이 두 개 들어왔다. 하나는 러닝 종료 후 요약 화면의 지도를 확대할 수 없다는 것, 다른 하나는 제자리에 멈췄을 때 일시정지로 뜨기까지 8초나 걸려서 너무 길다는 것.

---

## 지도가 확대되지 않던 문제

GPWS 경고가 짧은 구간에 몰리면 마커가 서로 겹쳐서 어떤 경고인지 구분이 안 됐다. 확대해서 보고 싶다는 피드백이었는데, 코드를 보니 `RouteMapView`가 애초에 줌 자체를 막아두고 있었다.

```swift
// before
mapView.isScrollEnabled = false
mapView.isZoomEnabled = false
```

단순히 이 두 값만 켜면 될 줄 알았는데, `updateUIView`가 SwiftUI 상태가 바뀔 때마다(예: 스플릿 MAX/MIN 토글) 호출되면서 매번 `setRegion`으로 지도를 초기 위치로 되돌리고 있었다. 이대로 두면 사용자가 확대해서 보는 중에 다른 상태 변화가 생길 때마다 줌이 리셋돼버린다.

```swift
// after
mapView.isScrollEnabled = true
mapView.isZoomEnabled = true
```

region 리셋은 좌표 개수가 실제로 바뀔 때(러닝 데이터가 처음 로드될 때) 딱 한 번만 하도록 `Coordinator`에 마지막 좌표 개수를 저장해뒀다.

```swift
// after
func updateUIView(_ uiView: MKMapView, context: Context) {
    // 생략
    if context.coordinator.lastCoordinateCount != routeData.coordinates.count {
        uiView.setRegion(routeData.region, animated: false)
        context.coordinator.lastCoordinateCount = routeData.coordinates.count
    }
}
```

---

## 일시정지 판단이 너무 느리던 문제

원래 5초로 해뒀다가, 러닝을 시작하자마자 일시정지가 뜨는 문제 때문에 8초로 늘렸었다. 근데 이번엔 반대로 8초가 너무 길다는 피드백이 들어왔다. 그냥 숫자를 다시 낮추기 전에, 애초에 왜 5초에서 오탐이 났는지부터 짚어봤다.

지금까지는 "GPS 데이터가 8초 이상 안 들어오면 일시정지"라는 방식이었다. 근데 `LocationService`의 `distanceFilter`가 5m로 설정돼 있어서, 사용자가 완전히 멈춰 서 있으면 GPS 신호가 멀쩡해도 5m 이상 움직이기 전까지는 애초에 새 위치 자체가 안 들어온다. 즉 "진짜로 멈춤"과 "터널 등에서 GPS 신호만 잠깐 끊김"이 코드 입장에서는 똑같이 "데이터 없음"으로 보여서 구분이 안 되는 구조였다. 5초였을 때 시작 직후 오탐이 난 것도, 카운트다운 후 첫 GPS fix를 아직 못 받은 상태에서부터 이미 타이머가 돌고 있었기 때문이었다.

그래서 접근을 바꿨다. "데이터가 오냐 안 오냐"가 아니라 "실제로 움직이고 있냐"를 직접 보기로 했다.

```swift
// before (LocationService.swift)
locationManager.distanceFilter = 5
```

```swift
// after
locationManager.distanceFilter = kCLDistanceFilterNone
```

`distanceFilter`는 위치가 최소 몇 m 이상 움직여야 새로 알려줄지 정하는 값이다. 5로 두면 5m를 움직이기 전까지는 위치가 갱신되지 않고, `kCLDistanceFilterNone`으로 두면 이 최소 이동 거리 제한을 아예 없애서 기기가 잡을 수 있는 만큼 계속 위치를 넘겨준다.

같은 러닝을 "달리는 중"에서 "멈춤"으로 이어간다고 할 때, 두 설정에서 위치가 언제 들어오는지를 그려보면 이렇다.

![](/assets/images/upload/2026-08-24-RunningProject-38/distance-filter-update-timeline.png)

위 그림에서 보듯 예전 설정(5m)에서는 멈추는 순간 초록 점(위치 데이터)이 아예 끊긴다. 코드 입장에서는 이게 "사용자가 멈췄다"인지 "GPS 신호만 잠깐 안 잡힌다"인지 구분할 방법이 없다. 새 설정(None)에서는 멈춰도 파란 점이 계속 들어오고, 그 점들이 실어오는 raw 속도값이 낮다는 걸로 "진짜 정지"를 판단할 수 있게 된다.

배터리가 더 닳지 않을까 걱정했는데, 따져보니 러닝 페이스(초당 3m 안팎)에서는 5m 필터를 쓰던 때도 이미 1.5~2초에 한 번씩 위치가 들어오고 있었다. 그러니까 실제로 뛰는 동안은 차이가 거의 없고, 차이가 나는 구간은 완전히 멈춰 서 있을 때뿐이다. 신호등 대기 정도는 길어야 몇십 초라 배터리에 미치는 영향은 미미했고, 실제로 10km 넘게 뛰어봐도 배터리는 무리 없이 버텼다.

멈춰 있어도 위치가 계속 들어오게 만든 다음, `RunningCenter`에서 raw 속도가 일정 시간 이상 낮게 유지되는지로 정지를 판단한다. 페이스 계산에 쓰는 `smoothingSpeedSecond`는 이중 지수 이동평균이라 감쇠가 느려서(α=0.8), 실제로 멈춘 뒤에도 임계값 아래로 내려오기까지 여러 초가 걸린다. 그래서 정지 판단에는 스무딩 전 raw `location.speed`를 그대로 썼다.

```swift
// after (RunningCenter.swift)
private var lowSpeedSince: Date?
private(set) var isStationary: Bool = false
private let stationarySpeedThreshold: Double = 0.5 // m/s
private let stationaryDuration: TimeInterval = 2.0

let compensatedSpeed = max(location.speed, 0)

if location.speedAccuracy >= 0 {
    if compensatedSpeed < stationarySpeedThreshold {
        if lowSpeedSince == nil {
            lowSpeedSince = location.timestamp
        }
        isStationary = location.timestamp.timeIntervalSince(lowSpeedSince!) >= stationaryDuration
    } else {
        lowSpeedSince = nil
        isStationary = false
    }
}
```

시속 1.8km가 어느 정도인지 감이 잘 안 올 수 있는데, 보통 걷는 속도가 시속 4~5km고 마트에서 어슬렁거리는 정도가 시속 2~3km다. 시속 1.8km면 그보다도 느려서 1km를 걷는 데 33분 넘게 걸리는 속도, 사실상 제자리걸음 수준이다. 그래서 이 아래는 "느리게 걷는 중"이 아니라 "가만히 서 있는데 GPS가 흔들리는 오차"로 본다. 이게 2초 이상 지속되면 정지로 판단한다. GPS 타임스탬프 기준으로 계산해서 실기기 타이머 흔들림과 무관하다.

정리하면, 위치 데이터는 멈춰도 계속 들어오고, 실제로 멈추면 그 안에 실린 raw 속도값이 낮게 나온다. 그 낮은 상태가 2초 넘게 이어지는지만 보고 일시정지 여부를 정하는 것이 이번에 바뀐 로직의 핵심이다.

raw 값을 그대로 쓰면 걸리는 문제가 두 가지 있다. GPS가 속도를 못 구했을 때 음수(`-1`)를 반환한다는 것, 그리고 도심처럼 신호가 튀는 환경에서는 값이 순간적으로 엉뚱하게 나올 수 있다는 것이다. 음수는 `max(location.speed, 0)`로 이미 0 이상으로 잘라내고 있고, 순간적으로 튀는 값은 "2초 연속"이라는 조건 자체가 걸러준다. 한 샘플만 튀어서는 2초를 못 채우니까 정지/재개 판정에 영향을 주지 못한다.

그래도 조금 더 확실히 하려고, iOS가 그 속도값을 얼마나 믿을 만하다고 보는지 알려주는 `speedAccuracy`도 같이 확인한다. 이 값이 음수면 "이 샘플의 speed 자체를 기기도 못 믿는다"는 뜻이라, 이런 샘플은 저속/정상 어느 쪽으로도 취급하지 않고 그냥 건너뛴다. 신뢰 못 할 샘플 하나 때문에 이미 쌓아온 판정이 잘못 리셋되거나 앞당겨지는 걸 막기 위해서다.

여기서 한 가지 짚을 부분이 있다. "멈춰 있어도 GPS 좌표 자체는 미세하게 흔들리는데, 그 흔들림이 속도값에도 그대로 옮겨붙는 거 아니냐"는 의문이 들 수 있다. 만약 속도를 "이전 좌표와 지금 좌표 사이 거리 ÷ 걸린 시간"으로 직접 계산했다면 실제로 그랬을 것이다. 좌표가 5m 흔들리는 걸 1초 만에 움직인 걸로 계산하면 초당 5m(시속 18km)짜리 가짜 속도가 나온다.

근데 [`CLLocation.speed`](https://developer.apple.com/documentation/corelocation/cllocation/speed){:target="_blank"}는 그렇게 계산되는 값이 아니다. GPS 칩이 위성 신호의 도플러 편이(주파수 변화)를 직접 측정해서 뽑아내는, 좌표와는 별도 경로로 측정된 값이다.

도플러 편이는 구급차 사이렌과 같은 원리다. 사이렌이 나한테 다가올 때는 소리가 더 높게, 멀어질 때는 더 낮게 들리는데, 이건 소리를 내는 쪽과 듣는 쪽이 서로 가까워지거나 멀어지면서 파동의 주파수가 다르게 느껴지기 때문이다. GPS 위성도 정해진 주파수로 신호를 계속 쏘고 있는데, 내가 그 위성에 가까워지거나 멀어지는 속도에 따라 아이폰이 받는 신호의 주파수가 미세하게 달라진다. 위성의 위치와 속도는 이미 정밀하게 알려져 있으니, 이 주파수 차이만 측정하면 "내가 이 위성 쪽으로/반대로 초당 몇 m씩 움직이고 있는지"를 거꾸로 계산할 수 있다. 하늘에 떠 있는 여러 위성에서 이 값을 동시에 받아 종합하면 실제 이동 속도가 나온다.

즉 속도는 좌표 두 점을 비교해서 얻는 값이 아니라, 애초에 완전히 다른 방식(주파수 측정)으로 독립적으로 구해지는 값이다. 그래서 좌표가 좀 흔들린다고 속도값이 그만큼 같이 흔들리진 않고, 가만히 서 있을 때 속도 노이즈가 보통 0.5m/s 밑에서 잡히는 것도 이 특성 덕분이다. 원리를 더 자세히 보고 싶으면 [Principle of speed measurement using GPS](https://www.onosokki.co.jp/English/hp_e/products/keisoku/automotive/lc8_principle.htm){:target="_blank"}에 정리돼 있다.

물론 도심 건물 사이처럼 신호가 반사되는 환경에서는 이 값도 가끔 튈 수 있다. 근데 이 경우도 튀는 방향이 항상 "더 빠르게"쪽이라, 저속 지속 시간 카운트가 리셋돼서 정지 감지가 몇 초 늦어지는 것 이상의 문제는 안 생긴다. 반대 방향(실제로 뛰고 있는데 속도가 갑자기 0 근처로 잘못 찍혀서 멈춘 걸로 오판하는 상황)은 구조적으로 일어나기 어렵다.

`distanceFilter`를 없애면서 생기는 부작용도 하나 막아야 했다. 멈춰 있는 동안에도 위치가 계속 들어오면 GPS 오차로 좌표가 미세하게 흔들리면서 누적 거리가 조금씩 늘어날 수 있다. 그래서 정지 상태로 판단된 동안은 거리 누적 자체를 건너뛴다.

```swift
// after
if let last = lastLocation, !isStationary {
    totalDistance += location.distance(from: last)
}
lastLocation = location
```

기존의 "N초간 데이터 없음" 타이머는 완전히 없애지 않고 GPS 신호 자체가 통째로 끊기는 경우(터널, 엘리베이터 등)의 안전망으로 남겨뒀다. 다만 이건 더 이상 일반적인 정지 판단 용도가 아니라서 8초에서 15초로 늘렸다.

```swift
// after (RunViewModel.swift / WatchViewModel.swift)
if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 15 {
    timerCancellable.removeAll()
    isPaused = true
    watchConnectivityService.sendPauseData(isPaused)
}
```

결과적으로 진짜 멈췄을 때는 2초 안에 일시정지가 뜨고, GPS 신호만 잠깐 끊긴 경우는 15초까지는 계속 달리는 중으로 유지된다. 이 로직은 iPhone/Watch가 공유하는 `RunningCenter`에 있어서 두 플랫폼 모두 한 번에 고쳐졌다.

덤으로 페이스 표시 자체도 더 자주 갱신된다. 5m 필터를 쓰던 때는 뛰는 중에도 대략 1.5~2초에 한 번씩만 갱신됐는데, 이제는 기기가 잡을 수 있는 만큼(대략 1초에 한 번) 위치가 계속 들어오니 화면도 그만큼 더 부드럽게 따라온다.

원래는 `stationaryDuration`을 3초로 잡았었는데, 지인이 실사용해보고 "3초도 생각보다 길게 느껴진다"고 해서 2초로 한 번 더 낮췄다. GPS가 대략 1초에 한 번 들어오니 2초는 사실상 저속 샘플 2번 연속 확인인 셈인데, 한 샘플만 튀어서는 여전히 이 조건을 못 채우니 노이즈 방어는 그대로 유지된다.

---

## 실기기 10km 테스트에서 나온 문제들

여기까지 고치고 실제로 10km를 뛰면서 테스트해봤다. 예상 못 한 문제 네 개가 더 나왔다.

---

### 1. GPWS 경고 햅틱이 약하게 느껴짐

`WatchGPWSView.swift`를 보니 햅틱이 경고 화면이 뜨는 순간 딱 한 번만 재생되고 끝나는 구조였다. 러닝 중에는 손목에 집중하기 어려우니 한 번으로는 놓치기 쉽다.

```swift
// before
private func playHapticPattern() {
    hapticTask?.cancel()
    let pattern = type.hapticPattern
    hapticTask = Task {
        for i in 0..<pattern.repeatCount {
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(pattern.type)
            if i < pattern.repeatCount - 1 {
                try? await Task.sleep(for: .seconds(pattern.interval))
            }
        }
    }
}
```

경고가 해소되기 전까지는 패턴 묶음을 2초 간격으로 계속 반복하도록 바꿨다.

```swift
// after
private func playHapticPattern() {
    hapticTask?.cancel()
    let pattern = type.hapticPattern
    hapticTask = Task {
        while !Task.isCancelled {
            for i in 0..<pattern.repeatCount {
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(pattern.type)
                if i < pattern.repeatCount - 1 {
                    try? await Task.sleep(for: .seconds(pattern.interval))
                }
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(2.0))
        }
    }
}
```

`onDisappear`에서 이미 `hapticTask?.cancel()`을 호출하고 있어서, 경고가 사라지면 이 반복도 바로 멈춘다.

---

### 2. 러닝 시작하자마자 일시정지가 뜸

정지 판단 로직 자체는 잘 만들었는데, 생각 못 한 사각지대가 있었다. ROTATE 카운트다운이 끝나고 실제로 뛰기 시작하기까지는 반응 시간이 걸리고, GPS 속도값도 막 켜진 직후에는 안정화되는 데 시간이 좀 걸린다. 이 몇 초 사이엔 raw 속도가 계속 낮게 나오는 게 당연한데, 정지 판단 로직 입장에서는 이것도 "2초 이상 저속 지속"으로 보여서 러닝 시작과 동시에 일시정지가 떠버렸다.

러닝 시작 후 5초 동안은 정지 판단 자체를 쉬게 했다.

```swift
// after
private let startupGracePeriod: TimeInterval = 5.0

if compensatedSpeed < stationarySpeedThreshold {
    if lowSpeedSince == nil {
        lowSpeedSince = location.timestamp
    }
    let pastStartupGrace = location.timestamp.timeIntervalSince(runStartTime!) >= startupGracePeriod
    isStationary = pastStartupGrace && location.timestamp.timeIntervalSince(lowSpeedSince!) >= stationaryDuration
} else {
    lowSpeedSince = nil
    isStationary = false
}
```

---

### 3. 미러링 중 일시정지가 뜨자마자 바로 풀림 + 정지 근처에서 페이스가 튐

증상은 하나처럼 보였는데 원인은 두 개였다.

첫 번째는 미러링(한쪽 기기가 GPS를 주도하고, 다른 쪽은 그 데이터만 받는 상황) 중 발생하는 문제였다. `WatchConnectivityService`의 flightData 수신 핸들러를 보니, 메시지를 받을 때마다 무조건 `isPaused = false`로 덮어쓰는 코드가 있었다.

```swift
// before
vm?.flightData = flightData
vm?.isPaused = false
```

이건 `distanceFilter`가 5m였던 예전 설계의 흔적이다. 그때는 "데이터가 온다 = 5m 이상 움직였다 = 안 멈췄다"가 성립했다. 근데 이번에 `distanceFilter`를 없애면서 정지 중에도 flightData가 계속 전송되게 됐으니, 이 가정 자체가 깨진 거다. 그 결과 상대 기기가 정지를 판단해서 `pauseData(true)`를 보내도, 뒤이어 도착하는(3초 주기) flightData 메시지가 매번 그걸 다시 false로 덮어써버렸다.

```swift
// after
vm?.flightData = flightData
// isPaused는 여기서 건드리지 않는다. pauseData 메시지만 신뢰한다.
```

두 번째는 정지 근처에서 나타나는 페이스 계산 자체의 문제였다. 페이스는 `1 / 속도`로 구하는데, 속도가 0에 가까워지면 이 값이 순간적으로 폭발적으로 커진다. 정지 중에는 새로 계산하지 않고 마지막 유효 페이스를 그대로 유지하도록 고쳤다.

```swift
// after (RunningCenter.swift)
let rawPace: Double
if smoothingSpeedSecond < stationarySpeedThreshold {
    rawPace = lastValidPace
} else {
    rawPace = 1 / (smoothingSpeedSecond * 60 / 1000)
    lastValidPace = rawPace
}
```

이걸로 끝난 줄 알았는데, 야외에서 가만히 서있는 채로 다시 테스트해보니 GPWS 오버레이가 뜬 상태에서 편차(초) 숫자가 계속 커졌다. 원인은 이 조건문 자체였다. `isStationary`(raw 속도 기준, 빠르게 반응)는 이미 `true`로 바뀌었는데, `smoothingSpeedSecond`(이중 지수평균, 감쇠가 느림)는 그 시점에도 아직 임계값 위에 남아있을 수 있다. 그 사이에는 `else` 분기를 계속 타면서 `1 / smoothingSpeedSecond`를 새로 계산하는데, 분모가 서서히 줄어드는 만큼 페이스가 계속 부풀어올랐다. 정지 판단은 빠르게 끝났는데, 페이스 얼리기는 느린 값을 기준으로 삼고 있었던 것이다.

조건을 이미 계산해둔 `isStationary`로 바꿨다.

```swift
// after (수정)
let rawPace: Double
if isStationary {
    rawPace = lastValidPace
} else {
    rawPace = 1 / (smoothingSpeedSecond * 60 / 1000)
    lastValidPace = rawPace
}
```

---

### 4. 걸을 때 페이스 뒷자리 초가 계속 바뀜

이건 정지 근처 문제가 아니라, 정상적으로 걷는 중에도 페이스 표시가 계속 미세하게 흔들리는 문제였다. 원인을 다시 짚어보니 이번에도 `distanceFilter` 제거의 부작용이었다.

페이스 스무딩 계수(0.8/0.2)는 예전 5m 필터 기준으로 맞춰져 있었다. 그때는 걷는 속도(초당 1.2~1.4m 정도)로 5m를 채우는 데 4초 가까이 걸려서 위치가 뜨문뜨문 들어왔다. `distanceFilter`를 없애면서 걷든 뛰든 상관없이 대략 1초에 한 번씩 들어오게 됐는데, 걷는 상황 기준으로는 업데이트 빈도가 대략 4배 늘어난 셈이다.

스무딩 계수는 "샘플 하나당 얼마나 반영할지"를 정하는 값이라, 같은 계수라도 샘플이 훨씬 자주 들어오면 실제 시간 기준 스무딩 효과는 그만큼 약해진다. 예전엔 4초에 한 번 20%씩 반영되던 게 이제는 1초에 한 번 20%씩 반영되니, 화면에 보이는 흔들림도 그만큼 커진 것이다.

```swift
// before
smoothingSpeedFirst = 0.8 * smoothingSpeedFirst + 0.2 * compensatedSpeed
smoothingSpeedSecond = 0.8 * smoothingSpeedSecond + 0.2 * smoothingSpeedFirst
```

```swift
// after
smoothingSpeedFirst = 0.85 * smoothingSpeedFirst + 0.15 * compensatedSpeed
smoothingSpeedSecond = 0.85 * smoothingSpeedSecond + 0.15 * smoothingSpeedFirst
```

처음엔 0.9/0.1까지 강하게 걸어볼까 했는데, 반응성을 덜 희생하는 절충안으로 0.85/0.15를 먼저 시도해보기로 했다. 계산상 노이즈가 대략 15% 정도 줄어드는 수준(0.9/0.1이었으면 30% 정도)이라 0.1의 절반 정도 효과인 셈이다. 이걸로도 부족하면 다음 테스트에서 더 올려볼 생각이다.

이렇게 고친 뒤 다시 나가서 확인해보니, 정지 중 페이스가 얼어있는 건 정상 작동했다. 근데 이번엔 다른 게 눈에 띄었다.

---

### 5. 일시정지 중에도 경과 시간이 계속 흐름

페이스는 멈췄는데 경과 시간(elapsedTime)은 계속 올라가고 있었다. `PFDView`의 PAUSED 오버레이 문구를 다시 보니 "AWAITING SIGNAL"이라고 적혀 있었는데, 여기서 원래 의도가 드러났다. `isPaused`는 애초에 "GPS 신호를 기다리는 중"이라는 뜻으로 설계된 값이었다. 신호가 잠깐 끊긴 것뿐이니 실제로는 계속 뛰고 있는 셈이라, 경과 시간은 일부러 안 멈추게 만들어둔 거였다.

문제는 오늘 `isPaused`를 "GPS 신호 대기"뿐 아니라 "진짜로 멈춰 섬"(`isStationary`)까지 같이 나타내도록 넓혀버렸다는 점이다. 신호등 앞에서 실제로 멈춘 상황도 이제 이 값이 true가 되는데, 시간은 예전 설계 그대로 계속 흐르고 있었던 것. 일반적인 러닝 앱들처럼 진짜 멈추면 시간도 같이 멈추는 게 맞다고 보고, 1초마다 도는 타이머에서 `isPaused`일 때는 경과 시간을 올리지 않도록 고쳤다.

```swift
// before
.sink { [weak self] _ in
    guard let self else { return }
    elapsedTime += 1
    watchConnectivityService.sendElapsedTime(elapsedTime)
    // 생략
}
```

```swift
// after
.sink { [weak self] _ in
    guard let self else { return }
    if !isPaused {
        elapsedTime += 1
        watchConnectivityService.sendElapsedTime(elapsedTime)
    }
    // 생략
}
```

iPhone/Watch 양쪽 타이머(러닝 시작 시점 하나, 첫 위치 수신 시점 하나, 총 네 곳)에 전부 같은 방식으로 적용했다.

"AWAITING SIGNAL"이라는 문구 자체는 바꿀까 하다가 그대로 두기로 했다. RunWay는 애초에 러닝을 비행으로 재해석하는 컨셉이라, "일시정지"를 "신호 대기"라는 항공 용어로 표현한 것도 나름의 톤이라고 봤다.

---

### 6. SINK RATE랑 OVERSPEED 진동이 구분이 안 감

경고 유형별로 다른 햅틱 패턴을 넣긴 했는데, 실제로 차고 뛰어보니 SINK RATE(위로 2회)랑 OVERSPEED(아래로 3회)가 손목에서 비슷하게 느껴진다는 피드백이 들어왔다. `.directionUp`/`.directionDown`은 이름만 다르지 실제 느낌 차이가 크지 않았던 것 같다.

방향으로 구분하는 대신, OVERSPEED 쪽을 반복 횟수와 속도로 확실히 차별화하기로 했다. "너무 빠르다"는 경고이니만큼 진동 자체도 더 빠르고 급하게 느껴지게 바꿨다.

```swift
// before
case .overspeed: return (.directionDown, 3, 0.2)
```

```swift
// after
case .overspeed: return (.directionDown, 4, 0.15)
```

SINK RATE는 2회에 0.45초 간격으로 그대로 두고, OVERSPEED만 4회에 0.15초 간격으로 바꿔서 두 패턴의 체감 속도 차이를 크게 벌렸다.
