---
title: RunWay 1.4 (4) 캘린더 날짜 탭과 끝났는데 안 끝나던 러닝
writer: Harold
date: 2026-10-02 18:00:00 +0900
categories: [RunWay]
tags: [SwiftUI, SwiftData]

toc: true
toc_sticky: true
published: true
---

Flight Calendar는 한 달치 러닝을 잔디밭처럼 보여주는 화면이다. 뛴 날은 거리에 따라 초록이 진해지고, 안 뛴 날은 비어 있다.

그런데 그게 전부였다. 어떤 날에 12.0이라고 적혀 있는 걸 보고 "이날 뭘 뛴 거지" 싶어서 눌러도 아무 일도 일어나지 않았다. 그 기록을 보려면 Logbook으로 가서 월을 펼치고 주를 펼쳐서 다시 찾아야 했다.

화면에 뭔가 띄워놓고는 그게 무슨 뜻인지, 거기서 뭘 할 수 있는지는 말해주지 않는 자리가 이것 말고도 있었다. 이번에 둘을 고쳤다.

---

## 안 하기로 했던 결정의 번복

이건 원래 안 하기로 결정했던 기능이다. 로드맵에 이렇게 적혀 있었다.

> **캘린더뷰에서 러닝 Summary 바로 보기** - 2026-07-18 안 하는 걸로 결정.
> 캘린더뷰에서도 Summary를 바로 보여주면 Logbook의 존재 이유와 겹친다고 판단.

당시 걸렸던 건 진입 경로 중복이었다. Logbook에서 Summary로 가는 길이 이미 있는데 캘린더에서도 가면, 캘린더가 Logbook을 흉내 내는 꼴이 되는 게 아닌가 싶었다. 같은 이유로 Alerts에서 경고 항목을 눌러 Summary로 가는 설계도 접어뒀었다.

다시 보니 전제가 틀렸다. **입구가 여러 개고 출구가 하나인 건 앱에서 이상한 구조가 아니다.** 사진 앱에서 한 장의 사진으로 가는 길은 라이브러리, 앨범, 검색, 추억으로 여러 개지만 도착하는 상세 화면은 하나다. 입구가 많다고 출구가 흔들리지는 않는다.

그리고 두 화면이 하는 일이 애초에 다르다. Logbook은 최근 순으로 훑는 자리고, 캘린더는 달 전체에서 패턴을 보는 자리다. "이번 달 셋째 주에 왜 비었지"는 캘린더에서만 보이는 질문이고, 그 옆 칸을 눌러 바로 확인하지 못할 이유가 없다.

---

## 하루에 두 번 뛴 날

구현은 단순할 줄 알았는데 한 가지가 걸렸다. **하루에 러닝이 하나라는 보장이 없다.**

캘린더 칸은 그날 거리를 전부 더해서 보여준다. 5km씩 두 번 뛴 날은 10.0으로 나온다. 그러면 그 칸을 눌렀을 때 어느 러닝으로 가야 하나.

처음 떠올린 건 그날 기록을 고르는 화면을 하나 두고 항상 거기로 보내는 방식이었다. 일관되긴 한데, 대부분의 날은 러닝이 하나다. 고를 게 하나뿐인 화면을 매번 거치게 만드는 셈이다.

그래서 개수로 갈랐다. 하나면 바로 Summary로, 둘 이상이면 고르는 화면으로 보낸다.

```swift
/// 날짜 한 칸. 그날 기록이 있으면 누를 수 있게 감싼다.
///
/// 기록이 하나뿐이면 바로 요약 화면으로, 둘 이상이면 어느 러닝인지 고르는 화면으로
/// 보낸다. 대부분의 날은 하나라서, 고를 게 없는데도 매번 한 번 더 누르게 만들
/// 이유가 없다.
@ViewBuilder
private func dayCellLink(for date: Date) -> some View {
    let dayFlights = flightsOn(date)
    let cell = DayCell(
        date: date,
        km: dayFlights.reduce(0.0) { $0 + $1.distance },
        isToday: calendar.isDateInToday(date),
        runCount: dayFlights.count
    )

    if dayFlights.count == 1, let only = dayFlights.first {
        NavigationLink { FlightSummaryView(selectedFlight: only) } label: { cell }
            .buttonStyle(.plain)
    } else if dayFlights.count > 1 {
        NavigationLink { CalendarDayView(date: date, flights: dayFlights) } label: { cell }
            .buttonStyle(.plain)
    } else {
        cell
    }
}
```

---

### 횟수를 알려주는 점

같은 칸을 눌렀는데 어떤 날은 Summary가 나오고 어떤 날은 목록이 나오면, 쓰는 쪽에서는 왜 그런지 알 수가 없다.

그런데 생각해보니 이건 목적지 문제만이 아니었다. **칸에 합산 거리만 보이니까 두 번 뛴 날이 한 번 길게 뛴 날처럼 읽히고 있었다.** 5km씩 두 번 뛴 날과 10km를 한 번에 뛴 날이 캘린더에서 똑같이 10.0으로 보인다. 그건 목적지와 무관하게 그 자체로 정보를 숨기고 있던 거다.

그래서 두 번 이상 뛴 날은 거리 아래에 점을 찍었다. 뛴 횟수를 알려주면서, 누르면 왜 다른 화면으로 가는지도 같이 설명된다.

![10월 1일 칸에 거리 5.8 아래로 점 네 개가 찍혀 있는 캘린더](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-47/runway14_calendar_dots.webp)

```swift
// 거리만 보이면 같은 날 두 번 뛴 것이 한 번 길게 뛴 것처럼 읽힌다.
// 누르면 고르는 화면으로 가는 이유도 이 점이 미리 알려준다.
if runCount > 1 {
    HStack(spacing: 3) {
        ForEach(0..<min(runCount, 4), id: \.self) { _ in
            Circle()
                .fill(Color.rwBg.opacity(0.65))
                .frame(width: 3, height: 3)
        }
    }
}
```

점은 네 개까지만 찍는다. 56pt짜리 칸에 다섯 개 넘게 들어가면 점이 아니라 선으로 보인다. 다섯 번 뛴 날과 여섯 번 뛴 날을 칸에서 구별해야 할 이유도 없다.

---

## 기존 행을 그대로 쓴 고르는 화면

그날 기록을 고르는 `CalendarDayView`를 새로 만들면서, 행은 Logbook이 쓰는 `LogEntryRow`를 그대로 가져왔다.

```swift
ForEach(flights) { flight in
    NavigationLink {
        FlightSummaryView(selectedFlight: flight)
    } label: {
        LogEntryRow(flight: flight)
    }
    .buttonStyle(.plain)
}
```

![캘린더에서 하루를 눌렀을 때 나오는 그날 기록 목록](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-47/runway14_calendar_day.webp)

캘린더에서 날짜를 누르고, 그날 기록 중 하나를 골라 요약으로, 거기서 다시 Flight Data Recorder까지 들어가는 흐름은 이렇게 이어진다.

![캘린더에서 날짜를 눌러 그날 기록을 고르고 요약을 거쳐 Flight Data Recorder 까지 들어가는 모습](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-47/runway14_calendar_to_fdr.gif)

같은 기록이 화면마다 다른 모양으로 보이면 같은 것인지 알아보기 어렵다는 이유도 있지만, 더 직접적인 이유가 따로 있었다. 이 행에는 이런 주석이 붙어 있다.

```swift
// `date`는 기록을 저장하는 시점, 즉 러닝을 끝낸 시각이다. 같은 날 두 번
// 뛴 기록을 구분하려면 날짜만으로는 부족해서 시각도 같이 보여준다.
Text(flight.date.formatted(date: .abbreviated, time: .shortened))
```

같은 날 두 번 뛴 기록을 구분하려고 시각을 같이 보여주게 해둔 행이다. 그런데 이번에 만든 화면은 **애초에 같은 날 기록만 모아놓은 화면**이다. 다른 데서 필요했던 이유가 여기서는 화면의 존재 이유 그 자체가 된다. 새로 만들었으면 같은 고민을 다시 했을 자리다.

---

## 안 쓰이게 된 함수 정리

캘린더에는 날짜별 거리를 구하는 함수가 있었다.

```swift
private func kmFor(_ date: Date) -> Double {
    flights
        .filter { calendar.isDate($0.date, inSameDayAs: date) }
        .reduce(0.0) { $0 + $1.distance }
}
```

이제는 거리만 필요한 게 아니라 **그날 기록 자체**가 필요하다. 개수를 세야 하고, 하나면 그 하나를 넘겨줘야 하고, 둘 이상이면 전부 넘겨줘야 한다. 그래서 기록을 돌려주는 쪽으로 바꿨다.

```swift
/// 특정 날짜의 러닝 기록. 끝난 시각 순으로 정렬한다.
private func flightsOn(_ date: Date) -> [SwiftDataFlight] {
    flights
        .filter { calendar.isDate($0.date, inSameDayAs: date) }
        .sorted { $0.date < $1.date }
}
```

거리는 받은 배열에서 바로 더하면 되니 `kmFor`는 아무 데서도 안 쓰이게 됐다. 남겨두면 다음에 보는 사람이 둘 중 뭘 써야 하는지 한 번 더 생각해야 하니 지웠다.

---

## 로드맵 메모 갱신

코드만 고치고 로드맵을 그대로 두면 문서에는 "안 하는 걸로 결정"이 남고 앱에는 기능이 들어가 있는 상태가 된다. 나중에 보면 어느 쪽이 맞는지 알 수가 없다.

그래서 그 항목에 뒤집은 날짜와 이유를 덧붙였다. 결정을 지우지 않고 남겨둔 건, 한 번 아니라고 판단했던 기록도 다음에 비슷한 걸 정할 때 쓰이기 때문이다.

같은 문단에 Alerts도 똑같은 이유로 "그대로 두기로 결정"이라고 적혀 있다. 전제가 틀렸다면 그쪽도 같이 다시 봐야 하는데, 이번에는 손대지 않고 메모만 남겨뒀다.

---

## 뭘 통과한 건지 알 수 없던 체크리스트

러닝 준비 화면에는 출발 전 점검 체크리스트가 있다. GPS 신호, 애플워치, 배터리, 날씨 네 칸이다.

이 중 애플워치 칸이 이상했다. **워치를 집에 두고 나와도 초록 체크로 통과했다.** 1.3.2에서 문구를 손대면서 이미 알고 있었는데, 그때는 표기만 `NOT CONNECTED`에서 `PAIRED`로 바꾸고 나머지는 1.4로 미뤄뒀다.

아이폰이 물어볼 수 있는 건 "워치가 등록돼 있나"와 "워치 앱이 깔려 있나" 두 가지뿐이다. "지금 차고 있나"에 답하는 API는 없다. 애플 개발자 포럼에서 DTS가 직접 그렇게 답한 글까지 확인했는데, 그 과정은 1.3.2 글에 적어뒀다.

그러면 이 칸은 **항상 통과한다.** 항상 통과하는 항목은 점검이 아니다.

---

### 깨워서 확인하는 길을 접은 이유

방법이 아예 없는 건 아니다. 준비 화면에 들어올 때 `startWatchApp`으로 워치 앱을 깨우면 `isReachable`이 참이 되고, 그러면 진짜 연결 여부를 알 수 있다.

안 했다. 아직 러닝을 시작하지도 않았는데 워치 앱이 켜지고 배터리를 쓴다. 애초에 `isConnected` 기준을 버린 이유가 **"항상 워치를 켜둬야 한다"가 미러링의 의도와 안 맞아서**였는데, 이쪽으로 가면 그 문제가 그대로 돌아온다.

---

### 한 단어로 전달되지 않는 것

그래서 통과 문구를 `PAIRED`에서 `REGISTERED`로 바꿨다. PAIRED는 "지금 짝지어져 있다"로 읽히는데 REGISTERED는 등록 상태라는 게 드러난다.

여기서 멈출 수도 있었지만 **영어 한 단어로는 "등록됐을 뿐 연결은 아니다"까지 전달되지 않는다.** 그래서 이 칸을 눌러 설명을 볼 수 있게 했다.

![러닝 준비 화면의 APPLE WATCH 항목을 눌렀을 때 뜨는 설명](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-47/runway14_takeoff_watch.webp)

설명을 세 문단으로 나눴다. 첫 문단은 **이 통과 표시가 보장하는 것**, 둘째 문단은 **보장하지 않는 것과 그래서 언제 확인되는지**, 셋째 문단은 **이 항목이 실제로 막는 것**이다. "워치를 집에 두고 나왔는데 왜 통과지"는 둘째 문단에서 풀린다.

```swift
/// `watchStatus`가 통과했을 때 그 표시가 무슨 뜻인지 설명하는 문구.
///
/// 이 칸은 워치를 집에 두고 나와도 통과한다. 애플이 "지금 워치를 차고 있나"를 알려주는
/// API를 주지 않기 때문인데, 그걸 모르는 사람에게는 통과 표시가 "지금 연결돼 있다"는
/// 약속으로 읽힌다. 문구를 PAIRED 에서 REGISTERED 로 바꾼 것도 같은 이유지만,
/// 영어 한 단어로는 "등록됐을 뿐 연결은 아니다"까지 전달되지 않아 설명을 따로 둔다.
var watchStatusExplanation: String {
    // 생략
}
```

---

### 탭이 먹는 항목의 기준

네 칸을 전부 누를 수 있게 하지는 않았다. GPS 신호의 `STRONG`이나 배터리의 `82%`는 값이 그대로 뜻이라 덧붙일 게 없다. 설명이 필요한 건 애플워치 하나뿐이다.

그래서 체크리스트 항목에 `note`를 두고, `note`가 있는 항목만 이름 옆에 작은 아이콘이 붙고 탭이 먹게 했다.

```swift
/// `note`가 있는 항목만 눌러서 설명을 볼 수 있다. 다른 항목은 값이 그대로 뜻이지만
/// APPLE WATCH 만 통과 표시가 뜻하는 범위가 좁아서(``RunViewModel/watchStatusExplanation``)
/// 따로 설명이 필요하다.
var checkItems: [(icon: String, name: String, value: String, ok: Bool, note: String?)] {
    [
        ("wifi", "GPS SIGNAL", runViewModel.gpsSignalStatus.label, runViewModel.gpsSignalStatus.ok, nil),
        ("applewatch", "APPLE WATCH", runViewModel.watchStatus.label, runViewModel.watchStatus.ok, runViewModel.watchStatusExplanation),
        ("battery.75", "BATTERY", batteryStatus.label, batteryStatus.ok, nil),
        ("cloud.sun", "WEATHER", runViewModel.weatherLabel, runViewModel.weatherOk, nil),
    ]
}
```

`NOT PAIRED`와 `APP NOT INSTALLED` 두 상태는 그대로 뒀다. 그 둘은 유저가 실제로 조치할 수 있는 진짜 실패라서, 설명을 덧붙일 게 아니라 눈에 띄게 두는 게 맞다.

---

## 어느 러닝인지 말하지 않는 종료 신호

아이폰에서 러닝을 끝내면 워치에도 종료 신호를 보낸다. 그런데 보내는 순간 워치 앱이 꺼져 있을 수 있다. 그러면 신호가 사라져서 워치 쪽 러닝만 계속 돌아간다.

그래서 상대가 못 받는 상황이면 보관했다가 나중에 배달하는 방식으로 보낸다.

```swift
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

유실을 막으려고 일부러 그렇게 둔 건데, **보관 기간에 제한이 없다.** 그러면 이런 순서가 가능해진다.

1. 러닝 A를 아이폰에서 끝내는데 마침 워치 앱이 꺼져 있다
2. 종료 신호가 보관함에 들어간다
3. 나중에 러닝 B를 워치로 시작한다
4. 보관돼 있던 A의 종료 신호가 배달되고, **러닝 B가 끝나버린다**

받는 쪽이 이걸 거를 방법이 없었다. 들어있는 게 "끝내라" 한 마디뿐이라 어느 러닝 것인지 물어볼 수가 없다.

```swift
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    if let type = userInfo["type"] as? String, type == "remoteStopped" {
        handleStopSignal()
    }
}
```

---

### 세션 id 대신 시각

러닝 중 계기 값은 이미 세션 id를 같이 실어 보내고 받는 쪽이 그걸로 거른다. **"신호에 어느 러닝인지 적어 보낸다"는 규칙이 이미 있었는데 종료 신호만 안 지키고 있었다.**

그래서 같은 id를 실을까 하다가 시각으로 갔다. id로 거르려면 양쪽이 같은 id를 알고 있어야 하는데 그게 성립하는 건 러닝이 시작된 뒤부터다. 그 전에 오간 신호는 여전히 못 거른다. "지금 러닝이 이 신호보다 나중에 시작됐으면 내 것이 아니다"는 그런 전제가 필요 없다.

```swift
@MainActor
private static func isStopSignalCurrent(sentAt: Double?) -> Bool {
    guard let sentAt,
          let startDate = HealthKitService.shared.session?.startDate else { return true }
    return startDate.timeIntervalSince1970 <= sentAt
}
```

`sentAt`이 없으면 그냥 처리한다. 한쪽 기기만 먼저 업데이트되는 구간이 반드시 생기는데, 그때 종료 신호가 전부 무시되면 러닝이 아예 안 끝난다. 잘못 끝나는 것보다 안 끝나는 쪽이 더 나쁘다.

새 러닝을 시작할 때 보관 중인 종료 신호도 취소한다. 어차피 도착해도 버릴 신호면 오기 전에 치우는 게 낫다.

받은 내용을 그대로 `Task { @MainActor in }` 안으로 넘기려다 한 번 막혔다. `[String: Any]`는 그 경계를 넘을 수 있는 타입이 아니다. 필요한 건 보낸 시각 하나뿐이라 밖에서 꺼내 그 값만 넘기는 걸로 바꿨고, 결과적으로 판단 함수도 딕셔너리 대신 숫자 하나만 받게 돼서 더 단순해졌다.

덧붙이면 **이 버그는 증상으로 본 적이 없다.** 재현 방법을 못 찾았다. 고친 건 규칙이 한 군데서만 안 지켜지고 있던 것이지, 그 일이 실제로 일어났다는 걸 확인한 게 아니다.

---

## 러닝을 안 하는데 들리던 음성 안내

시뮬레이터를 켜둔 채로 다른 작업을 하는데 구간 안내 음성이 들렸다. 러닝은 하고 있지 않았다.

먼저 뭐가 돌고 있는지 봤다.

```
PID 5533  RunWay.app/RunWay
PID 5536  RunWayActivityExtensionExtension
PID 7718  RunWayWatch Watch App
```

Live Activity 확장까지 살아 있었다. 그건 러닝이 진행 중일 때만 떠 있어야 한다. 시뮬레이터 로그를 보니 더 분명했다.

```
18:49:08  RunWay  Beginning discovery for point: com.apple.AudioUnit-Speech
18:49:08  RunWay  Set volume on device 86 to 0.60
18:52:14  RunWay  Set volume on device 86 to 0.60
18:54:50  RunWay  Set volume on device 86 to 0.60
18:55:04  RunWay  CLLocationManager _cmd:stopUpdatingLocation
```

2~3분 간격으로 말하고 있었고, 위치 추적이 멈추는 순간 같이 끝났다. **끝난 줄 알았던 러닝이 계속 거리를 쌓고 있었고, 1km를 넘길 때마다 구간 음성이 나가고 있었다.**

---

### 끝내는 자리와 멈추는 자리의 불일치

원인은 위치 추적을 멈추는 자리였다. `.touchdown`은 러닝이 끝나는 자리인데 거기서는 워크아웃 세션만 멈추고 있었다.

```swift
case .touchdown:
    HealthKitService.shared.stopWorkout()
```

GPS와 고도계는 `resetState()`에서만 멈춘다. 그리고 `resetState()`는 **요약 화면을 떠날 때** 돈다.

그러니까 러닝을 끝내도 요약 화면을 보고 있는 동안은 GPS가 계속 돌고 거리가 쌓인다. 보통은 몇 초 보다 나가니까 티가 안 났을 뿐이다. 요약 화면을 켜둔 채 두면 끝난 러닝의 구간 안내가 계속 나오고 배터리도 계속 먹는다.

고치는 건 간단했다. 끝나는 자리에서 멈추게 했다.

```swift
case .touchdown:
    HealthKitService.shared.stopWorkout()
    // 러닝이 끝나는 자리는 여기다. 예전에는 `resetState()`에서만 멈춰서, 요약
    // 화면을 떠나기 전까지 GPS가 계속 돌고 거리가 쌓였다. 그러면 1km를 넘길 때마다
    // 끝난 러닝의 스플릿 음성이 나가고 배터리도 계속 먹는다. 화면을 어떻게 오가든
    // 러닝이 끝난 순간 멈추는 게 맞아서 이쪽으로 옮겼다.
    locationService.stopTracking()
    altimeterService.stopTracking()
```

`resetState()`의 기존 호출은 남겨뒀다. 워치에서 원격으로 끝내는 경로는 `.touchdown`을 안 거치고 바로 `resetState()`로 가기 때문이다. 두 번 멈춰도 아무 일도 안 생긴다.

---

### 러닝 장비를 쥐고 있던 화면 전환

이 문제가 눈에 띈 건 다른 수정 때문이었다. 러닝 직후 요약 화면에서 Flight Data Recorder로 들어가면 홈까지 튕겨 나가는 버그가 있었다.

```swift
.onDisappear {
    guard isPostRun else { return }
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

`resetState()` 안에 `navigationPath = []`가 있다. 스택을 통째로 비우는 것이다. 그런데 `onDisappear`는 **사용자가 화면을 떠난 것과 위에 다른 화면이 덮인 것을 구별하지 못한다.** Recorder를 푸시하는 그 행동 자체가 정리를 부르고, 스택이 풀리면서 홈까지 밀려났다.

그래서 Recorder가 떠 있는 동안은 정리를 건너뛰게 했다.

```swift
guard isPostRun, !isShowingRecorder else { return }
```

그랬더니 이번엔 **요약으로 돌아오지 않고 탭바로 나가버리면 정리가 영영 안 도는** 경로가 생겼다. `onDisappear`는 이미 한 번 불렸고, 탭을 바꿔도 다시 안 불린다. 탭 내용이 살아있기 때문이다. 음성이 계속 들린 게 이 상태였다.

한쪽을 막으니 다른 쪽이 열렸다. 이 콜백만으로는 못 닫는 모양이다.

그런데 멈추는 자리를 `.touchdown`으로 옮기고 나니 이 경로로 빠져나가도 **밖에서 보이는 건 없어졌다.** GPS도 워크아웃 세션도 Live Activity도 러닝이 끝나는 순간 멈추니까. 남는 건 뷰모델 정리뿐이고 그것도 다음 러닝을 시작하면 스스로 풀린다.

화면 전환이 러닝 장비를 쥐고 있던 게 문제였지, 화면 전환을 더 정교하게 막는 게 답이 아니었다. 구조가 어긋난 건 그대로라 이슈로는 남겼다.
