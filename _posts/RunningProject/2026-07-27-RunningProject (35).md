---
title: RunWay 1.2 (4) TOUCHDOWN 홀드, 스플릿 탭바 겹침, 미션 목표 표시 고치기
writer: Harold
date: 2026-07-27 22:30:00 +0900
categories: [RunWay]
tags: [SwiftUI]

toc: true
toc_sticky: true
published: true
---

워치는 러닝 종료 버튼이 2초 길게 눌러야 확인되는 방식인데, 아이폰 PFDView의 TOUCHDOWN 버튼은 그냥 한 번 탭하면 바로 종료된다. 뛰다가 화면을 잘못 건드리면 러닝이 그대로 끝나버리는 문제라 아이폰도 같은 방식으로 바꿨다. 겸사겸사 시뮬레이터로 오래 뛰어보다가 발견한, 스플릿 목록이 하단 탭바에 가려지는 문제도 같이 고쳤고, Flight Summary에 미션 목표가 안 보이던 것도 이 김에 추가했다.

---

## 워치 버튼 참고해서 PFDView 종료 버튼 수정

워치 쪽 `EndFlightHoldButton`은 `DragGesture(minimumDistance: 0)`으로 손가락이 닿아있는 동안 0.05초 간격 타이머를 돌려서 진행률을 채우고, 2초를 다 채우면 성공 햅틱과 함께 종료 클로저를 부르는 방식이다.

```swift
// EndFlightHoldButton (Watch)

.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            if !isHolding {
                isHolding = true
                startHold()
            }
        }
        .onEnded { _ in cancelHold() }
)
```

같은 방식을 아이폰 TOUCHDOWN 버튼에도 그대로 붙였다. 다만 시간은 그대로 안 가져오고 1초로 줄였다. 워치는 화면이 작아서 실수로 스칠 가능성이 아이폰보다 훨씬 높다고 보고 2초를 준 거라, 화면이 큰 아이폰까지 똑같이 2초씩 기다리게 할 필요는 없다고 판단했다. `PFDView.swift`에 `TouchdownHoldButton`이라는 이름으로 따로 뺐고, 기존 TOUCHDOWN 버튼의 빨간 배경은 그대로 두고 그 위에 흰색 반투명 진행률 바를 왼쪽부터 채워지게 얹었다.

```swift
// TouchdownHoldButton

private struct TouchdownHoldButton: View {
    var onTouchdown: () -> Void = {}

    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color.rwRed)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: geo.size.width * holdProgress)
                    .animation(.linear(duration: 0.05), value: holdProgress)
            }

            HStack(spacing: 8) {
                Image(systemName: "airplane.arrival").font(.system(size: 15, weight: .semibold))
                Text(isHolding ? "HOLD TO CONFIRM..." : "TOUCHDOWN ■").font(.orbitron(15, weight: .bold)).kerning(1)
            }
            .foregroundColor(.white)
        }
        // 생략
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding {
                        isHolding = true
                        startHold()
                    }
                }
                .onEnded { _ in cancelHold() }
        )
    }

    private func startHold() {
        holdProgress = 0
        let interval = 0.05
        let steps = 1.0 / interval
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                holdProgress += CGFloat(1.0 / steps)
                if holdProgress >= 1.0 {
                    holdTimer?.invalidate()
                    holdTimer = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onTouchdown()
                }
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
    }
}
```

손을 떼면 `cancelHold()`가 진행률을 다시 0으로 돌려놔서, 1초를 다 채우지 못하고 뗀 홀드는 아무 일도 없었던 것처럼 취소된다. 워치가 성공 햅틱을 `WKInterfaceDevice.current().play(.success)`로 주는 것처럼, 아이폰은 `UINotificationFeedbackGenerator().notificationOccurred(.success)`로 맞췄다.

근데 처음 짠 코드는 이거였다.

```swift
// before

holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
    holdProgress += CGFloat(1.0 / steps)
    if holdProgress >= 1.0 {
        timer.invalidate()
        holdTimer = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onTouchdown()
    }
}
```

이러면 다음 에러가 난다.

```
Main actor-isolated property 'holdProgress' can not be mutated from a Sendable closure
```

`Timer.scheduledTimer`의 콜백은 `@Sendable` 클로저라, 그 안에서 `holdProgress` 같은 뷰의 `@State`(메인 액터에 격리된 값)를 바로 바꾸면 안 된다. 콜백 안에서 `Task { @MainActor in ... }`로 한 번 더 감싸서 메인 액터로 넘겨줘야 한다.

```swift
// after

holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    Task { @MainActor in
        holdProgress += CGFloat(1.0 / steps)
        if holdProgress >= 1.0 {
            holdTimer?.invalidate()
            holdTimer = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onTouchdown()
        }
    }
}
```

콜백이 주는 `timer` 파라미터도 그대로 캡처해서 쓰면 안 된다. `Timer` 타입 자체가 `Sendable`이 아니라서, `Task { @MainActor in }` 안에서 그 값을 쓰려고 하면 또 에러가 난다. 그래서 `timer.invalidate()` 대신, 이미 메인 액터에 있는 `holdTimer`(같은 타이머를 담고 있는 `@State` 변수)로 멈추게 했다. 같은 패턴을 쓰던 워치 쪽 `EndFlightHoldButton`과 `statusCycleTimer`도 똑같이 고쳤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/stopbutton.gif){: width="50%" height="50%"}

---

## 스플릿 목록이 탭바에 가려지는 문제

시뮬레이터로 24km짜리 러닝을 하나 만들어서 FLIGHT SUMMARY를 열어봤더니, 스플릿 목록 아래쪽이 하단 탭바(Deck/Logbook/Alerts)에 가려서 마지막 줄이 반쯤 잘려 보였다. 기종마다 이 부분이 다르게 보이면 안 되니까 짚고 넘어가기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/splits_tabbar_before.png){: width="50%" height="50%"}

스와이프를 해봐도 아래로 안 넘어가고 그대로 멈춰있었다.

[이전글](https://haroldfromk.github.io/posts/RunningProject-(33)/){:target="_blank"}에서 스플릿이 몇 개 없을 땐 스크롤이 필요 없는데도 스크롤이 되는 게 어색해서 'scrollDisabled'을 사용했었다.

```swift
// FlightSummaryView (기존)

GeometryReader { proxy in
    ScrollView(showsIndicators: false) {
        VStack(spacing: 10) {
            // 생략
        }
        .background(
            GeometryReader { contentProxy in
                Color.clear.preference(key: ContentHeightPreferenceKey.self, value: contentProxy.size.height)
            }
        )
    }
    .scrollDisabled(contentHeight <= proxy.size.height)
}
.onPreferenceChange(ContentHeightPreferenceKey.self) { contentHeight = $0 }
```

콘텐츠 높이(`contentHeight`)와 화면에 주어진 높이(`proxy.size.height`)를 직접 비교해서 스크롤 여부를 결정하는 방식인데, 스플릿이 24개나 되는 긴 러닝에서 이 비교가 꼬였는지 스크롤이 필요한 상황인데도 막혀서, 화면에 다 못 담은 아래쪽 내용이 탭바 뒤로 그냥 잘려 보이는 상태가 됐다.

처음엔 `scrollBounceBehavior(.basedOnSize)`라는, iOS가 정확히 이 상황(콘텐츠가 작으면 바운스 없이 고정, 크면 스크롤)을 위해 만든 modifier로 바꿔봤다. 근데 이건 화면 전체를 다시 스크롤 가능한 상태로 만드는 거라, "전체 화면은 안 스크롤되게 하고 싶다"는 원래 방향이랑 안 맞았다. 화면 전체가 스크롤되기 시작하면 지도나 상단 카드까지 같이 밀려 올라가는 게 이 화면 성격(고정된 계기판처럼 보이게 하고 싶었던 것)과는 안 맞는다는 피드백을 받고 다시 생각했다.

그래서 바깥 `ScrollView`를 아예 없애고 `GeometryReader`로 화면 전체 높이를 받아서, 그 안에 있는 `VStack`을 고정 높이로 박아버렸다.

```swift
// FlightSummaryView

GeometryReader { proxy in
    VStack(spacing: 10) {
        // 생략

        if !splits.isEmpty {
            SplitsChartView(splits: splits, totalDistance: displayFlight?.distance ?? 0)
                .frame(maxHeight: .infinity)
        } else {
            Spacer(minLength: 0)
        }

        // 생략
    }
    .frame(width: proxy.size.width, height: proxy.size.height)
}
```

배지/지도 카드/통계 박스는 원래 크기 그대로 두고, `SplitsChartView`에만 `.frame(maxHeight: .infinity)`를 줬다. `VStack`의 높이가 `proxy.size.height`로 고정돼 있으니까, 다른 항목들이 자기 크기만큼 차지하고 남는 공간을 이 스플릿 박스 하나가 전부 가져간다. `SplitsChartView` 내부의 `ScrollView`도 원래 있던 `.frame(maxHeight: 260)` 고정값 대신 똑같이 `.frame(maxHeight: .infinity)`로 바꿔서, 밖에서 받은 공간만큼만 채우고 그 안에서 스플릿이 넘치면 내부적으로 스크롤되게 했다. 이러면 스플릿이 3개든 24개든 전체 화면 크기 자체는 절대 안 바뀌고, 스플릿 목록만 자기한테 주어진 공간 안에서 늘었다 줄었다 하면서 필요할 때만 그 안에서 스크롤된다. 탭바를 가릴 일 자체가 구조적으로 없어진다.

두 방식이 어떻게 다른지 눈으로 볼 수 있게 만들었다. 스플릿 개수와 화면 크기를 바꿔가며 비교할 수 있다.

<iframe
  src="/assets/demo/summary_layout_simulator.html"
  width="100%"
  height="855px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

수정 전으로 두고 스플릿을 24개까지 늘리면 화면 밖으로 300pt 넘게 밀려나고, 스플릿 17줄과 GO TO DECK 버튼이 통째로 손이 안 닿는 곳으로 간다. 화면을 큰 기종으로 바꿔도 밀려나는 양만 줄어들 뿐 문제 자체는 그대로다. **화면 크기로는 해결되지 않는 문제**라는 게 여기서 드러난다. 수정 후로 바꾸면 어떤 조합에서도 밀려나는 게 0이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/after.png){: width="50%" height="50%"}

---

## Flight Summary에 미션 목표 표시하기

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/summarybefore.png){: width="50%" height="50%"}

Flight Summary에서 Mission Flight로 뛴 기록을 봐도 그냥 "MISSION FLIGHT"라고만 나오고, 그 미션이 어떤 목표(페이스였는지 심박이었는지, 목표가 얼마였는지)였는지는 어디서도 안 보였다. 찾아보니 러닝 하나가 끝날 때 `SwiftDataFlight`에 저장하는 값은 `mode`("modeA"/"modeB") 하나뿐이었다. 정작 그 미션의 목표 페이스/심박/거리 같은 실제 설정값(`ModeA`)은 러닝 도중에만 메모리에 떠 있다가, 저장하는 순간 그냥 버려지고 있었다.

`ModeA`가 들고 있는 값 그대로 몇 개 필드를 추가했다.

```swift
// SwiftDataFlight

var missionTarget: String = ModeATarget.pace.rawValue
var missionTargetPace: Double = 0
var missionPaceDeviation: Int = 0
var missionTargetHeartRate: Double = 0
var missionHeartRateDeviation: Int = 0
var missionTargetDistance: Double = 0
```

기존 필드들과 달리 선언부에 기본값을 직접 줬다. SwiftData는 이미 저장된 기존 기록들도 자동으로 마이그레이션해주는데, 이때 기준으로 삼는 게 init 파라미터가 아니라 이 선언부의 기본값이라서, 여기 없으면 이 필드가 없던 버전에서 업데이트한 기존 유저의 기록을 읽다가 문제가 생길 수 있다. 이전에 `SwiftDataAlert`에 필드 추가할 때도 같은 방식을 썼다.

러닝 기록을 `SwiftDataFlight`로 만드는 곳이 한 군데가 아니어서 세 군데 다 고쳐야 했다. 아이폰이 직접 뛴 경우(`RunViewModel.saveRunningData()`), 워치가 직접 뛴 경우(`WatchViewModel.saveRunningData()`), 워치 단독 러닝 기록을 아이폰이 나중에 전달받아 저장하는 경우(`WatchConnectivityService+iOS.swift`의 `didReceiveUserInfo`) 셋 다 이미 갖고 있던 `modeAData`를 그대로 넘기게 고쳤다.

```swift
// RunViewModel.saveRunningData()

let runningData = SwiftDataFlight(
    mode: isModeA ? "modeA" : "modeB",
    distance: totalDistance, time: totalTime, pace: totalPace,
    heartRate: avgHR, cadence: avgCad,
    fuel: Int(healthData.activeEnergy), date: .now,
    missionTarget: modeAData?.target.rawValue ?? ModeATarget.pace.rawValue,
    missionTargetPace: modeAData?.targetPace ?? 0,
    missionPaceDeviation: modeAData?.paceDeviation ?? 0,
    missionTargetHeartRate: modeAData?.targetHeartRate ?? 0,
    missionHeartRateDeviation: modeAData?.heartRateDeviation ?? 0,
    missionTargetDistance: modeAData?.targetDistance ?? 0
)
```

워치 단독 러닝은 조금 더 손이 갔다. 워치가 러닝을 저장한 뒤 `WCSession`으로 아이폰에 데이터를 넘길 때 딕셔너리 형태로 직렬화해서 보내는데, 이 딕셔너리에 목표값이 안 실려있으면 애초에 아이폰 쪽에서 받을 게 없다. 그래서 워치 쪽 전송 코드(`sendRunningData()`)에도 같이 추가했다.

```swift
// WatchConnectivityService+watchOS.swift, sendRunningData()

let userInfo: [String: Any] = [
    // 생략
    "missionTarget": flight.missionTarget,
    "missionTargetPace": flight.missionTargetPace,
    "missionPaceDeviation": flight.missionPaceDeviation,
    "missionTargetHeartRate": flight.missionTargetHeartRate,
    "missionHeartRateDeviation": flight.missionHeartRateDeviation,
    "missionTargetDistance": flight.missionTargetDistance
]
```

받는 쪽(`didReceiveUserInfo`)은 Swift 6 동시성 규칙 때문에 살짝 걸렸다. 이 딕셔너리(`userInfo`)는 nonisolated 컨텍스트에서 받는데, 그걸 그대로 `Task { @MainActor in ... }` 클로저 안에서 읽으면 데이터 레이스 위험이 있다고 컴파일 에러가 난다. 그래서 기존 코드가 이미 하던 방식대로, Task 밖에서 먼저 지역 변수로 꺼내놓고 그 변수만 클로저 안에서 쓰게 했다.

마지막으로 `FlightSummaryView`에 미션 요약 문자열 하나를 추가했다.

```swift
// FlightSummaryView

var missionDetailText: String? {
    guard let flight = displayFlight, flight.mode == "modeA" else { return nil }
    let targetText: String
    if flight.missionTarget == ModeATarget.heartRate.rawValue {
        targetText = "HEART RATE \(Int(flight.missionTargetHeartRate))bpm"
    } else {
        let minutes = Int(flight.missionTargetPace)
        let seconds = Int((flight.missionTargetPace - Double(minutes)) * 60)
        targetText = "PACE \(minutes)'\(String(format: "%02d", seconds))\"/km"
    }
    guard flight.missionTargetDistance > 0 else { return targetText }
    return targetText + " · " + String(format: "%.1fkm", flight.missionTargetDistance)
}
```

Free Flight면 `nil`을 반환해서 원래대로 "Airbus A320-200"이 보이고, Mission Flight면 그 자리에 목표 기준 이름("PACE" 또는 "HEART RATE")과 값, 목표 거리를 보여준다. 처음엔 "TARGET 5'30\"/km"처럼 썼는데 이 숫자가 페이스인지 심박인지 라벨만 봐서는 애매해서, 기준 이름을 그대로 라벨로 바꿨다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/summa.png){: width="50%" height="50%"}


---

## 실기기 후 보완

여기까지 고치고 실기기로 테스트를 좀 오래 해봤는데, 세 가지가 더 나왔다.

### 1. 아이폰 주도 미러링 종료 시 워치가 간헐적으로 안 끝남

아이폰 주도 미러링 중에 아이폰에서 러닝을 끝냈는데 워치는 가끔 안 끝나는 문제가 있었다. `sendStopSignal()`을 보면 원인이 바로 보인다.

```swift
// WatchConnectivityService (기존)

func sendStopSignal() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    let message: [String: Any] = ["type": "remoteStopped"]
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
}
```

`session.isReachable`이 그 순간 `false`면 신호를 그냥 버리고 끝난다. 워치 화면이 꺼져있거나 다른 화면을 보고 있으면 이게 잠깐 `false`가 될 수 있는데, 그럼 종료 신호 자체가 증발해버린다. `sendMessage`는 상대 앱이 그 순간 살아있어야만 도착하는 방식이라 어쩔 수 없이 실패할 수 있는데, `transferUserInfo`는 큐에 쌓아뒀다가 상대 세션이 다시 살아나는 대로 전달해주기 때문에 이걸 대체 경로로 붙였다.

```swift
// WatchConnectivityService

func sendStopSignal() {
    guard WCSession.default.activationState == .activated else { return }
    let message: [String: Any] = ["type": "remoteStopped"]
    guard session.isReachable else {
        session.transferUserInfo(message)
        return
    }
    session.sendMessage(message, replyHandler: nil) { [weak self] _ in
        self?.session.transferUserInfo(message)
    }
}
```

근데 `transferUserInfo`로 받는 쪽(`didReceiveUserInfo`)은 지금까지 워치 단독 러닝 기록을 파싱하는 용도로만 쓰고 있어서, 아이폰 쪽엔 이 딕셔너리 안에 `type` 키가 있으면 러닝 기록 파싱보다 먼저 종료 처리하도록 분기를 추가했고, 워치 쪽엔 아예 `didReceiveUserInfo` 자체가 없어서 새로 만들어줘야 했다.

---

### 2. 지도 종료 마커 E → F

지인한테 앱을 보여줬는데, 지도에 찍히는 시작/종료 마커가 "S"/"E"라서 시작/종료(Start/End)가 아니라 방위(남쪽/동쪽)처럼 보인다는 피드백을 받았다. "F"(Finish)로 바꾸면 그런 오해가 없을 것 같아서 그렇게 고쳤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/mapbefore.png){: width="50%" height="50%"}

```swift
// Before

case "END":
    view.markerTintColor = UIColor(Color.rwGreen)
    view.glyphTintColor = UIColor(Color.rwBg)
    view.glyphText = "E"
    view.glyphImage = nil

// After

case "END":
    view.markerTintColor = UIColor(Color.rwGreen)
    view.glyphTintColor = UIColor(Color.rwBg)
    view.glyphText = "F"
    view.glyphImage = nil
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/mapafter.png){: width="50%" height="50%"}

---

### 3. 워치 GPWS 피크 기능 안내가 없음

워치 GPWS 경고 화면에서 배경을 길게 누르면 PFD가 잠깐 보이는 기능을 아무 안내 없이 숨겨뒀던 것도 걸렸다. 

해당 내용은 글자도 작고 매번 봐도 거슬리지 않는 짧은 문구라, 그냥 GPWS가 뜰 때마다 계속 보여주는 쪽으로 설정했다.

```swift
// WatchGPWSView

Text("Hold background to peek PFD")
    .font(.system(size: 9, weight: .semibold))
    .foregroundColor(type.accentColor.opacity(0.7))
```

그리고 이 문구는 영어 하드코딩이라 로컬라이징이 필요했다. `Localizable.xcstrings`에 실제 한국어/일본어 번역을 채워 넣어서, 시스템 언어에 따라 자동으로 바뀌게 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/watchgpws.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/gpwspfdbutton.gif)![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-27-RunningProject-35/gpws11.gif)

---

## 기종이 다른 문제 해결

|  | 경우의 수 | 방법 |
|---|---|---|
| 홀드 시간 (워치 vs 아이폰) | 2가지뿐 | 숫자 2개로 하드코딩 |
| 스플릿 박스 높이 (아이폰 SE~Pro Max) | 기종마다 제각각 | `GeometryReader`로 실행 시점에 읽기 |

경우의 수가 딱 두 개로 정해져 있으면 숫자로 나눠도 충분하지만, 같은 "아이폰"이어도 화면 크기가 계속 갈리는 문제라면 숫자를 미리 정하지 말고 매번 실제 값을 읽어오는 쪽이 맞다.
