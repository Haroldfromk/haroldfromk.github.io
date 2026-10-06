---
title: RunWay 1.4 (1) 안 쓰던 값 셋, 없던 값 하나
writer: Harold
date: 2026-10-01 10:00:00 +0900
last_modified_at: 2026-10-06 02:00:00 +0900
categories: [RunWay]
tags: [SwiftData, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

1.3.2를 심사에 넣고 1.4를 시작했다. 할 일이 여덟 가지쯤 되는데, 그중 하나만 성격이 달라서 순서를 그것부터 잡았다.

---

## 1.3.3을 1.4에 합친 이유

원래는 작은 버전을 하나 끼워 넣을 생각이었다. 이유는 딱 하나였다.

**좌표에 시각을 저장하는 작업은 미루는 만큼 그대로 잃는다.** 나중에 필드를 추가해도 그 전에 저장된 기록에는 값이 없다. 나중에 채워 넣을 방법이 아예 없다.

나머지는 미뤄도 손해가 없다. 미러링 신뢰성도, 업데이트 알림도 언제 하든 같은 일이다. 그런데 이것만 **하루 미룰 때마다 그날 뛴 기록이 영영 비어버린다.**

그래서 "이것만 먼저 내자"였는데, 1.4를 한 달 안에 낼 계획이라 접었다. 한 달치면 감수할 만하고, 버전을 하나 더 내면 심사도 한 번 더다. 대신 **1.4 작업 중에서 이걸 제일 먼저** 했다.

---

## 좌표에 시각이 없던 문제

저장하는 모델이 이렇게 생겼었다.

```swift
@Model
class SwiftDataCoordinate {
    var latitude: Double = 0
    var longitude: Double = 0
    var order: Int = 0
}
```

위도, 경도, 순서. 지도에 선을 긋는 데는 이걸로 충분하다. 그런데 **경로 중간의 한 지점을 짚어서 "여기서 몇 분 페이스였나"를 물으면 답할 수가 없다.**

순서가 있으니 알 수 있지 않나 싶은데, 안 된다. **저장하기 직전에 좌표를 솎아내기 때문이다.**

지도에 그릴 정밀도만 있으면 되니까 곡선을 유지하는 데 필요한 점만 남기고 버린다. 직선 구간은 양 끝만 남고 가운데가 통째로 사라진다. 그래서 남은 좌표들 사이의 **시간 간격이 제각각**이다. 1번과 2번 사이는 3초인데 2번과 3번 사이는 40초일 수 있다.

**순서는 남은 점들의 나열 순서일 뿐, 얼마나 걸렸는지는 아무것도 말해주지 않는다.**

<svg viewBox="0 0 680 280" width="100%" xmlns="http://www.w3.org/2000/svg" style="max-width:680px;display:block;margin:20px auto;color:inherit" role="img" aria-labelledby="c44t c44d">
<title id="c44t">솎아낸 좌표는 순서만 남고 시간 간격은 사라진다</title>
<desc id="c44d">위는 3초마다 수집한 좌표가 놓인 실제 경로다. 곡선 구간의 점은 남고 직선 구간 가운데 열두 개는 버려져서, 남은 점 사이가 3초와 39초로 벌어진다. 아래는 저장된 배열인데 남은 여섯 개가 균등하게 늘어서 있어 순서만으로는 그 차이를 알 수 없다.</desc>
<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">

<text x="0" y="22" font-size="12" font-weight="600" fill="currentColor" stroke="none">실제 경로 · 3초마다 한 점</text>

<path d="M110,112 L132,86 L162,68 L200,60 L540,60 L566,36" stroke-width="1.6" opacity="0.5"/>

<g opacity="0.4" stroke-width="1.4">
<circle cx="226" cy="60" r="3.5"/><circle cx="252" cy="60" r="3.5"/><circle cx="279" cy="60" r="3.5"/>
<circle cx="305" cy="60" r="3.5"/><circle cx="331" cy="60" r="3.5"/><circle cx="357" cy="60" r="3.5"/>
<circle cx="383" cy="60" r="3.5"/><circle cx="409" cy="60" r="3.5"/><circle cx="435" cy="60" r="3.5"/>
<circle cx="461" cy="60" r="3.5"/><circle cx="488" cy="60" r="3.5"/><circle cx="514" cy="60" r="3.5"/>
</g>

<g fill="currentColor" stroke="none">
<circle cx="110" cy="112" r="5"/><circle cx="132" cy="86" r="5"/><circle cx="162" cy="68" r="5"/>
<circle cx="200" cy="60" r="5"/><circle cx="540" cy="60" r="5"/><circle cx="566" cy="36" r="5"/>
</g>

<text x="370" y="38" font-size="11" text-anchor="middle" fill="currentColor" stroke="none" opacity="0.65">직선 구간 열두 개는 버린다</text>

<g stroke-width="1.2" opacity="0.4">
<path d="M110,124 L110,140 M132,98 L132,140 M162,80 L162,140 M200,72 L200,140 M540,72 L540,140 M566,48 L566,140"/>
</g>

<g stroke-width="1.4" opacity="0.7">
<path d="M110,146 L566,146"/>
<path d="M110,141 L110,151 M132,141 L132,151 M162,141 L162,151 M200,141 L200,151 M540,141 L540,151 M566,141 L566,151"/>
</g>

<text x="0" y="170" font-size="11" font-weight="600" fill="currentColor" stroke="none" opacity="0.75">실제 시간</text>
<g font-size="11" text-anchor="middle" fill="currentColor" stroke="none">
<text x="121" y="170" opacity="0.7">3초</text>
<text x="147" y="170" opacity="0.7">3초</text>
<text x="181" y="170" opacity="0.7">3초</text>
<text x="370" y="170" font-weight="700">39초</text>
<text x="553" y="170" opacity="0.7">3초</text>
</g>

<path d="M0,198 L680,198" stroke-width="1" opacity="0.18"/>

<text x="0" y="224" font-size="12" font-weight="600" fill="currentColor" stroke="none">저장된 배열 · order 만 있을 때</text>

<path d="M110,250 L540,250" stroke-width="1.4" opacity="0.4"/>
<g fill="currentColor" stroke="none">
<circle cx="110" cy="250" r="5"/><circle cx="196" cy="250" r="5"/><circle cx="282" cy="250" r="5"/>
<circle cx="368" cy="250" r="5"/><circle cx="454" cy="250" r="5"/><circle cx="540" cy="250" r="5"/>
</g>
<g font-size="11" text-anchor="middle" fill="currentColor" stroke="none" opacity="0.75">
<text x="110" y="274">0</text><text x="196" y="274">1</text><text x="282" y="274">2</text>
<text x="368" y="274">3</text><text x="454" y="274">4</text><text x="540" y="274">5</text>
</g>
<text x="672" y="250" font-size="11" text-anchor="end" fill="currentColor" stroke="none" opacity="0.65">간격이 전부 같아 보인다</text>

</g>
</svg>

---

### 시각 하나로 되는 이유

페이스를 따로 저장할까 했는데 그럴 필요가 없었다. 좌표 두 개 사이의 거리는 위도·경도로 계산되고, 시간 차이만 알면 나눠서 속도가 나온다.

```swift
/// 러닝 시작부터 이 좌표를 수집한 시점까지의 경과 시간 (초).
var elapsedTime: Int = 0
```

선언부에 기본값을 둔 건 SwiftData 때문이다. 자동 마이그레이션이 `init` 파라미터가 아니라 **이 자리의 값을 보고** 기존 레코드를 채운다. 1.1에서 한 번 밟은 함정이라 이번엔 처음부터 이렇게 뒀다.

값을 담는 쪽은 이미 필요한 게 다 있었다.

```swift
// RunningCenter
let elapsed = runStartTime.map { Int(location.timestamp.timeIntervalSince($0)) } ?? 0
coordinateArray.append((
    latitude: location.coordinate.latitude,
    longitude: location.coordinate.longitude,
    elapsedTime: max(0, elapsed)
))
```

위치가 들어올 때마다 `location.timestamp`가 같이 오고, 러닝 시작 시각도 같은 객체 안에 이미 있었다. **새로 계산할 게 없었다.**

---

### 솎아낸 뒤 짝이 어긋나는 자리

막힌 건 여기였다. 좌표를 솎아내는 함수가 이렇게 생겼다.

```swift
static func simplify(_ coordinates: [(latitude: Double, longitude: Double)]) -> [(latitude: Double, longitude: Double)]
```

**좌표만 넣고 좌표만 받는다.** 남은 좌표가 원래 몇 번째였는지 알 수가 없으니, 시각 배열과 짝을 맞출 방법이 없다.

세 가지를 생각했다.

1. 좌표 타입 자체에 시각을 넣어서 통째로 넘긴다
2. 시각도 같이 받는 함수를 따로 만든다
3. **남은 좌표의 원래 번호를 돌려받는다**

3번으로 갔다. 함수 안을 열어보니 이미 번호로 계산하고 있었다.

```swift
let keptIndices = simplifiedIndices(points, tolerance: tolerance)
return keptIndices.map { coordinates[$0] }   // 번호를 좌표로 바꿔서 돌려주고 있었다
```

**번호를 좌표로 바꿔서 돌려주는 그 마지막 줄 때문에 정보가 사라지고 있었다.** 그래서 번호를 그대로 돌려주는 입구를 하나 더 냈다.

```swift
static func keptIndices(of coordinates: [(latitude: Double, longitude: Double)]) -> [Int]

static func simplify(_ coordinates: [(latitude: Double, longitude: Double)]) -> [(latitude: Double, longitude: Double)] {
    keptIndices(of: coordinates).map { coordinates[$0] }
}
```

기존 함수는 새 함수 위에 한 줄로 남겼다. 쓰던 곳을 안 건드려도 된다.

저장하는 쪽은 이렇게 된다.

```swift
let keptIndices = PolylineSimplifier.keptIndices(
    of: coords.map { (latitude: $0.latitude, longitude: $0.longitude) }
)
runningData.coordinates = keptIndices.enumerated().map { order, index in
    let coord = coords[index]
    return SwiftDataCoordinate(
        latitude: coord.latitude,
        longitude: coord.longitude,
        order: order,
        elapsedTime: coord.elapsedTime
    )
}
```

---

### 화면에 쓰는 값을 안 건드린 이유

좌표를 담는 배열에 시각이 들어가니 그 배열을 쓰는 곳이 전부 걸렸다. 그중 하나가 러닝 중 화면에 경로를 그리는 버퍼다.

거기까지 바꾸면 `NavDisplayForeground`와 `PFDView`까지 번진다. 그런데 **지도에 선을 긋는 데는 시각이 필요 없다.** 넘길 때 떼기로 했다.

```swift
// 화면에 경로만 그리므로 시각은 떼고 넘긴다.
coordinateBuffer = await runningCenter.coordinateArray
    .map { (latitude: $0.latitude, longitude: $0.longitude) }
```

**값이 더 있다고 다 넘길 이유는 없다.** 안 쓰는 쪽에 넘기면 그쪽 타입까지 따라 바뀐다.

---

### 워치 전송 쪽 수정

워치 단독으로 뛴 기록은 아이폰으로 넘어온다. 그때 좌표를 이렇게 싣고 있었다.

```swift
.map { [$0.latitude, $0.longitude] }
```

숫자 두 개짜리 배열이다. 세 번째로 시각을 넣었는데, 받는 쪽을 조금 느슨하게 뒀다.

```swift
guard coord.count >= 2 else { return nil }
let elapsed = coord.count >= 3 ? Int(coord[2]) : 0
```

두 앱은 같이 올라가지만 **워치만 늦게 업데이트되는 짧은 구간**이 생길 수 있다. 그때 두 개짜리가 와도 기록이 통째로 버려지지 않게 했다.

---

### 이전 기록의 한계

채울 방법이 없다. 그래서 읽는 쪽에서 **0이면 "구간 페이스 없음"으로 다뤄야** 한다.

화면은 아직 안 만들었다. 저장만 먼저 해둔 것이고, 경로를 드래그해서 페이스를 보는 화면은 1.4 후반에 붙인다. **오늘 뛴 러닝부터는 값이 들어간다.**

---

## 월 합계에 빠져 있던 총 러닝 시간

캘린더 화면 위쪽에 그 달 요약이 세 칸 있다. 거리, 횟수, 평균 페이스.

**얼마나 오래 뛰었는지가 없었다.** 기록마다 시간을 이미 갖고 있는데도.

한 칸 더 넣는 건 쉬운데 표기가 걸렸다. 기존에 쓰던 형식이 `00:06:12`인데 여덟 글자다. 세 칸이 네 칸이 되면 한 칸이 115pt에서 84pt로 줄고, 작은 기기에서는 80pt다. **글꼴이 넓은 편이라 안 들어간다.**

```swift
/// - Returns: `"6:12"` 형식의 문자열
static func secondToHourMinute(_ second: Int) -> String {
    let minutes = (second / 60) % 60
    let hours = second / 3600
    return String(format: "%d:%02d", hours, minutes)
}
```

네 글자로 줄였다. **월 합계에서 초는 의미가 없다.** 100시간이 넘어도 여섯 글자라 여유가 있다.

두 줄로 나누는 것도 생각했는데 안 된다. 이 화면은 스크롤을 막아둔 화면이라, **세로가 64pt 늘면 작은 기기에서 달력 아랫부분이 잘린다.**

![캘린더 월 요약에 TOTAL, RUNS, AVG PACE, TOTAL TIME 네 칸이 가로로 붙은 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-01-RunningProject-44/runway14_calendar_summary.webp)

네 번째 칸이 이번에 넣은 것이다. `8:55` 가 8시간 55분인데, 여기에 `00:08:55` 를 넣으면 칸을 넘는다.

---

## 로그북에 빠져 있던 끝난 시각

목록의 각 줄이 날짜만 보여주고 있었다. 같은 날 두 번 뛰면 **거리 빼고는 똑같아 보인다.**

```swift
// 전
Text(flight.date.formatted(date: .abbreviated, time: .omitted))

// 후
Text(flight.date.formatted(date: .abbreviated, time: .shortened))
```

한 단어 바꾸는 것으로 끝났다. `date`가 기록을 저장하는 시점, 즉 **러닝을 끝낸 시각**이라 값은 이미 있었다.

**없어서 못 보여준 게 아니라 안 보여주고 있었던 것이다.** 이런 게 생각보다 많다.

![로그북 목록에서 같은 날 뛴 러닝들이 끝낸 시각으로 구별되는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-01-RunningProject-44/runway14_logbook_time.webp)

10월 5일 하나에 일곱 줄이 있다. 날짜만 뜨던 때라면 거리 말고는 어느 게 어느 러닝인지 알 수가 없었다.

---

## 새 러닝에 지난 러닝 값이 보이던 문제

1.3.2 검증하다가 발견한 것이다.

워치에서 러닝을 끝내고 앱을 백그라운드로 보낸 뒤 아이폰에서 바로 새 러닝을 시작하면, **워치 화면에 직전 러닝의 거리와 페이스가 잠깐 보인다.**

미러링에서 워치의 값은 아이폰이 보내주는 것으로만 갱신된다. 3초 간격이라 첫 데이터가 올 때까지는 이전 값이 그대로 남는다.

기록에는 영향이 없고 몇 초 뒤 알아서 맞춰진다. 그래서 1.3.2를 막지는 않았다. 다만 하나 걸리는 게 있었다. **이전 러닝이 경고 상태로 끝났다면 새 러닝 시작 직후에 진동이 한 번 울린다.**

고치는 자리는 이미 있었다. 1.3.2에서 화면 경로를 갈아끼우게 만든 그 줄 옆이다.

```swift
if result.startOrigin == .remote {
    self.flightData = FlightData()
    self.elapsedTime = 0
    self.isPaused = false

    self.navigationPath = [.pfd]
}
```

---

## 정리

네 가지를 했는데 셋이 **"값은 이미 있는데 안 쓰고 있던 것"**이었다.

| | 있던 것 | 안 하던 것 |
|---|---|---|
| 로그북 시각 | `date`에 종료 시각 | 화면에 안 보여줌 |
| 월 총 시간 | 기록마다 `time` | 합산을 안 함 |
| 워치 이전 값 | 비우는 자리 | 비우지를 않음 |

나머지 하나인 좌표 시각만 **정말로 없던 값**이었고, 그래서 그것만 시기가 걸렸다.

**이미 있는 걸 안 쓰는 건 언제 고쳐도 같은 일이다.** 없는 걸 안 만들어두면 그 사이가 영영 빈다. 순서를 정할 때 이 둘을 구분하는 게 생각보다 중요했다.
