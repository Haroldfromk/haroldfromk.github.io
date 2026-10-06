---
title: RunWay 1.4 (3) 5초마다 계기를 담아 러닝 되감기
writer: Harold
date: 2026-10-02 10:00:00 +0900
categories: [RunWay]
tags: [SwiftData, SwiftUI, Canvas, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

러닝이 끝나면 Flight Summary에 총 거리, 평균 페이스, 1km 단위 스플릿이 나온다. 그런데 "7분쯤에 왜 갑자기 힘들었지"처럼 특정 순간을 짚어보려고 하면 볼 수 있는 게 없었다. 1km 평균값으로는 그 안에서 벌어진 일이 전부 뭉개진다.

그래서 지나간 러닝의 어느 시점이든 짚어서 그때의 계기 값을 보는 화면을 만들었다. 이름은 Flight Data Recorder. 항공기 사고 조사에서 비행기록장치를 되감아 시점별 고도와 속도를 보는 것과 같은 자리다.

![Flight Data Recorder 화면에서 트레이스를 끌자 항공기와 판독 값이 같이 움직이는 모습](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_scrub.gif)

만들면서 가장 오래 붙잡은 건 화면이 아니라 **되감을 데이터가 애초에 없다는 것**이었고, 그다음은 내가 중복으로 저장해둔 걸 다시 걷어낸 일이었다.

---

## Flight Summary 분리와 절반의 되돌림

되감기 얘기를 하려면 이 화면이 왜 생겼는지부터 적어야 한다.

Flight Summary에는 지도, 숫자 세 칸, 그리고 1km 스플릿 목록이 다 들어있었다. 이 화면은 통째로 스크롤하지 않는 구조라, 스플릿이 많아지면 **그 목록만 자기 안에서 따로 스크롤**해야 했다. 다른 화면에는 없는 예외였다.

거기에 **총 러닝 시간이 아예 없었다.** 기록마다 저장은 되고 있는데 보여주는 자리가 없었다.

그래서 화면을 둘로 나눴다. 요약에는 지도와 한눈에 볼 숫자만 남기고, 나머지는 DETAILS 버튼 뒤로 보냈다. 스플릿도 같이 넘겼다.

---

### 분리 후 휑해진 요약 화면

실기기로 열어보니 아니었다.

러닝을 끝내고 제일 먼저 보는 게 스플릿이다. 그걸 버튼 뒤로 보내니 **요약 화면이 휑해지고, 정작 제일 보고 싶은 걸 한 번 더 눌러야** 했다. 화면을 나눈 이유는 "스플릿만 따로 스크롤하는 예외를 없애자"였는데, 그걸 없애려다 더 자주 하는 동작을 불편하게 만든 셈이다.

스플릿을 요약으로 되돌렸다. 나이키 러닝도 스플릿 목록은 요약에 두고 그 아래에 상세 버튼을 둔다. 애초에 맞추려던 모양이 그거였다.

상세 화면에는 **숫자 세 칸에 안 들어가는 것들**만 남겼다. 상승고도, 소모 칼로리, GPWS 경고 수, 그리고 Mission Flight 목표. 총 러닝 시간은 요약 줄에 들어갔다. 이 화면을 건드린 이유가 그거였으니까.

되돌리면서 상세 화면 문서 주석에 **왜 스플릿이 여기 없는지**를 적어뒀다.

```swift
/// 구간 기록은 요약 화면에 그대로 둔다. 러닝을 끝내고 제일 먼저 보는 것이라 한 번 더
/// 눌러야 나오면 불편해서다. 한때 이쪽으로 옮겨봤는데 요약이 휑해지고 매번 한 번 더
/// 눌러야 해서 되돌렸다. 다시 옮길 생각이라면 그 두 가지를 먼저 해결해야 한다.
```

없는 이유를 안 적어두면 다음에 같은 생각이 들었을 때 똑같이 옮겼다가 똑같이 되돌리게 된다.

---

### 내용보다 먼저 정해진 이름

처음 붙인 버튼 이름은 DETAILS였다. 이게 **이 화면이 뭘 하는 자리인지 아무것도 말해주지 않았다.** 앱의 다른 라벨은 전부 항공 용어인데 여기만 평범한 단어였다.

이름을 Flight Data Recorder로 바꾸면서 이 화면이 뭐가 될지가 같이 정해졌다. 그런데 그 시점에 화면이 실제로 하는 일은 숫자 세 칸을 더 보여주는 게 전부였다. **되감을 데이터가 하나도 없었다.**

그래서 이 글의 나머지는 이름을 먼저 붙여놓고 그 이름에 맞는 내용을 뒤따라 만든 이야기다.

---

## 기존 저장물로 되감지 못하는 이유

되감으려면 몇 초 간격의 값이 쭉 있어야 한다. 그런데 RunWay가 저장하고 있던 건 두 종류뿐이었다.

하나는 `SwiftDataSplit`. 1km에 하나씩이라 10km를 뛰어도 10개다. 계기를 움직이기엔 너무 성기다.

다른 하나는 `SwiftDataCoordinate`. 개수는 충분하다. 그래서 처음엔 여기에 페이스와 심박을 같이 얹으면 되겠다고 생각했다. 그런데 이게 안 된다.

좌표는 저장 직전에 `PolylineSimplifier`로 솎아낸다. Douglas-Peucker 방식인데, 이건 **모양을 유지하면서 점을 줄이는** 알고리즘이다. 즉 꺾이는 지점은 남기고 직선 구간은 양 끝만 남기고 버린다.

<svg viewBox="0 0 420 180" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="솎아낸 좌표는 꺾이는 구간에만 모여 있고 직선 구간에는 양 끝만 남는다" style="width:100%;height:auto;color:inherit">
  <text x="0" y="14" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">솎아낸 뒤 남은 좌표</text>

  <path d="M24 70 C70 42, 104 44, 128 72 C146 94, 160 110, 188 112 L396 112"
        fill="none" stroke="currentColor" stroke-opacity=".28" stroke-width="2"/>

  <circle cx="24" cy="70" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="58" cy="52" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="92" cy="50" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="128" cy="72" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="152" cy="99" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="188" cy="112" r="4" fill="currentColor" opacity=".85"/>
  <circle cx="396" cy="112" r="4" fill="currentColor" opacity=".85"/>

  <path d="M188 134 L396 134" fill="none" stroke="currentColor" stroke-opacity=".35" stroke-width="1"/>
  <path d="M188 130 L188 138" stroke="currentColor" stroke-opacity=".35" stroke-width="1"/>
  <path d="M396 130 L396 138" stroke="currentColor" stroke-opacity=".35" stroke-width="1"/>
  <text x="292" y="152" font-size="10.5" fill="currentColor" opacity=".55"
        font-family="monospace" text-anchor="middle">이 구간에 좌표 2개</text>

  <text x="24" y="172" font-size="10.5" fill="currentColor" opacity=".55" font-family="monospace">직선으로 달려도 페이스와 심박은 계속 변한다</text>
</svg>

직선으로 1km를 달려도 좌표는 두 개만 남는다. 그런데 그 1km 동안 페이스도 심박도 계속 변한다. **모양을 위해 남긴 점과 신호를 위해 필요한 점이 다르다.** 솎아내기는 모양을 최적화하는 것이지 신호를 최적화하는 게 아니다.

결국 시간 간격이 일정한 별도의 기록이 필요했다.

---

## 5초 간격 계기 표본

`SwiftDataSample`을 새로 만들었다. 경과 시간, 누적 거리, 페이스, 심박, 케이던스, 고도, 진행 방향을 담는다.

간격은 5초로 정했다. 1초마다 담으면 러닝 페이스가 그렇게 자주 의미 있게 변하지도 않는데 용량만 다섯 배가 된다. 화면 갱신도 이미 3초 간격으로 돈다. 10km를 5초마다 담으면 약 720개라 부담이 없다.

수집은 `RunningCenter`에서 한다. 위치 갱신마다 호출되지만 마지막으로 담은 시점에서 5초가 지나야 실제로 쌓는다.

```swift
private func recordSample(_ flightData: FlightData, at timestamp: Date) async {
    guard let runStartTime else { return }
    let elapsed = max(0, Int(timestamp.timeIntervalSince(runStartTime)))
    if let last = lastSampleElapsedTime, elapsed - last < sampleInterval { return }
    lastSampleElapsedTime = elapsed

    let heartRate = await healthCenter.currentHeartRate
    let cadence = await healthCenter.currentCadence
    sampleArray.append((
        elapsedTime: elapsed,
        distance: flightData.distance,
        pace: flightData.pace,
        heartRate: heartRate,
        cadence: cadence,
        altitude: flightData.altitude,
        heading: flightData.heading
    ))
}
```

정지 중에도 담는다. 쉰 구간이 비어 있으면 되감을 때 그 시간이 통째로 사라지기 때문이다.

---

### 네 군데의 저장 경로

새 데이터를 하나 추가한다는 건 저장 경로를 전부 찾아야 한다는 뜻이다. RunWay는 네 군데였다.

아이폰 단독 저장, 워치 단독 저장, 워치에서 아이폰으로 전송, 그리고 CloudKit 백업. 한 군데라도 빠뜨리면 그 경로로 저장한 러닝만 되감기가 안 된다.

이 중 워치 전송에서 한 번 더 생각할 게 있었다. 기존 스플릿은 키 이름이 붙은 딕셔너리로 보내고 있었다.

```swift
let splits = flight.splits.map { split in
    [
        "order": split.order,
        "pace": split.pace,
        // 생략
    ] as [String: Any]
}
```

스플릿은 10km에 10개라 이래도 된다. 표본은 720개다. 같은 방식이면 `"elapsedTime"`, `"heartRate"` 같은 키 문자열이 720번 반복된다. 보내는 값보다 키 이름이 더 무거워지는 셈이다.

그래서 좌표가 쓰던 방식대로 순서가 고정된 숫자 배열로 보냈다.

```swift
let samples = flight.samples
    .sorted { $0.order < $1.order }
    .map { [Double($0.elapsedTime), $0.distance, $0.pace, $0.heartRate, $0.cadence, $0.altitude, $0.heading] }
```

받는 쪽은 순서를 보고 다시 푼다. 순서가 어긋나면 심박 자리에 케이던스가 들어가므로, 양쪽 주석에 배열 순서를 적어뒀다.

---

## 같은 시간축에 세운 네 줄

화면은 나이키 러닝처럼 지도 위를 손가락으로 따라가는 방식을 생각해봤는데, 그대로 따라 하는 건 별로였다. 그리고 지도는 어디를 달렸는지는 알려주지만 "같은 페이스인데 왜 심박이 올랐나"처럼 **두 지표를 나란히 놓고 봐야 하는 질문**에는 답이 안 된다.

그래서 비행기록장치 판독지처럼 계기별 추이를 각각 한 줄로 뽑아 같은 시간축 위에 세웠다. PACE, BPM, SPM, ALT 네 줄이고, 세로선 하나가 네 줄을 관통한다. 선 위를 밀면 위쪽 판독 패널이 그 시점 값으로 바뀐다.

<!-- 스크린샷: Xcode 캔버스 "표본 있음" 프리뷰, 네 줄이 전부 그려진 모습 -->

색은 기존 `SplitsChartView`와 똑같이 맞췄다. 같은 지표가 화면마다 다른 색이면 그게 제일 헷갈린다.

---

### 값이 없는 구간의 선 끊기

워치 없이 뛰면 심박과 케이던스가 안 들어온다. 그 값은 0으로 저장된다.

0을 그대로 그으면 심박이 바닥을 찍은 것처럼 보인다. 실제로는 "0이었다"가 아니라 "기록이 없다"인데 그림은 전자로 읽힌다. 그래서 0인 구간은 선을 그리지 않고 끊었다.

```swift
var path = Path()
var isDrawing = false
for index in values.indices {
    guard hasValue(values[index]) else {
        isDrawing = false
        continue
    }
    let nextPoint = point(at: index)
    if isDrawing {
        path.addLine(to: nextPoint)
    } else {
        path.move(to: nextPoint)
        isDrawing = true
    }
}
```

그런데 이 규칙을 네 줄에 똑같이 먹였다가 버그를 만들었다.

**고도는 0이 정상 값이다.** RunWay의 ALT는 기압계로 재는 상대 고도라서 러닝 시작 지점이 0이다. 평지를 달리면 계속 0 근처고, 내리막을 달리면 음수다. 그러니 "0은 기록 없음" 규칙을 먹이는 순간 **평지와 내리막이 통째로 사라진다.**

![판독 패널의 ALT는 0인데 ALT 줄만 선이 하나도 그려지지 않은 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_alt_missing.webp)

위 판독 패널은 ALT를 0이라고 멀쩡히 보여주는데 아래 ALT 줄만 통째로 비어 있다. 값이 있다고 적어놓고 그 값을 안 그리고 있었던 것이다.

페이스와 심박과 케이던스는 0이 나올 수 없는 값이라 0이면 기록이 없는 게 맞다. 고도만 다르다. 그래서 0을 기록 없음으로 볼지를 줄마다 따로 정하게 바꿨다.

```swift
private struct Lane {
    let label: String
    let color: Color

    /// 0을 "기록 없음"으로 볼지 여부.
    let treatsZeroAsMissing: Bool

    let value: (SwiftDataSample) -> Double
}

private var lanes: [Lane] {
    [
        Lane(label: "PACE", color: .rwAmber, treatsZeroAsMissing: true) { $0.pace },
        Lane(label: "BPM", color: .rwRed, treatsZeroAsMissing: true) { $0.heartRate },
        Lane(label: "SPM", color: .rwGreen, treatsZeroAsMissing: true) { $0.cadence },
        Lane(label: "ALT", color: .rwBlue, treatsZeroAsMissing: false) { $0.altitude }
    ]
}
```

---

### 페이스 축을 안 뒤집은 이유

페이스는 값이 작을수록 빠르다. 그래서 그래프에서 "위로 올라가면 빨라지는" 게 직관적일 것 같아 축을 뒤집을까 고민했다.

안 뒤집었다. 네 줄 중 하나만 축이 거꾸로면 **같은 모양이 줄마다 다른 뜻이 된다.** 네 줄을 겹쳐 세운 이유 자체가 같은 시간축에서 모양을 비교하려는 건데, 그중 하나만 반대로 읽어야 하면 비교가 더 어려워진다.

---

## 지도 대신 좌표로 그린 코스

계기만 보면 몸이 뭘 했는지는 알아도 어디였는지는 모른다. 그래서 코스도 같이 보여주기로 했다.

처음엔 요약 화면이 쓰던 `MKMapView`를 가져다 썼다. 경로를 그리고 그 위에 항공기 마커를 띄웠다.

![지도 위에 경로만 그려지고 항공기 마커는 보이지 않는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_map_hidden.webp)

띄워놓고 보니 지도가 문제였다. 지명과 도로와 녹지가 전부 들어오는데, 그중 어느 것도 "이 러닝의 코스가 어떻게 생겼나"에는 보태는 게 없다. 되감아 보는 자리에서 알고 싶은 건 "어느 건물 앞이었나"가 아니라 "코스 어디쯤이었나"다. 그런데 그 답을 주는 선 하나가 가장 가려져 있었다.

그래서 지도를 걷어내고 좌표만 이어 그렸다.

![좌표만 이어 그린 코스 위에 항공기와 밝은 꼬리가 올라간 모습](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_course.webp)

계기 네 줄과 같은 어두운 판에 같은 테두리를 쓰니 한 덩어리로 읽힌다. 마커는 SF Symbol `airplane`을 쓰고 저장된 방위로 기수를 돌렸다. 이 심볼은 기수가 오른쪽을 보고 있어서 방위 0이 위쪽이 되게 하려면 90도를 빼야 한다.

```swift
Image(systemName: "airplane")
    .font(.system(size: 17, weight: .bold))
    .foregroundColor(.rwGreen)
    .rotationEffect(.degrees(heading - 90))
```

---

### 좌표 중복 저장과 되돌림

항공기를 띄우려면 그 시점의 위치가 필요하다. 그런데 표본에는 위치가 없었다.

좌표에서 시각으로 찾아 쓰려니 앞에서 적은 문제가 걸렸다. 좌표는 솎아낸 뒤라 표본 시각과 맞는 점이 없는 구간이 생긴다. 그래서 `SwiftDataSample`에 위도와 경도를 추가하고, 표본을 담을 때 그 자리 좌표를 같이 적었다. 저장 경로 네 군데에 다시 반영하고, 전송 배열도 아홉 개로 늘렸다.

그런데 이렇게 하고 나니 **이미 저장된 기록에서는 항공기가 전혀 안 떴다.** 좌표 필드가 없던 시절에 저장한 기록이라 전부 0이었기 때문이다.

여기서 "새로 뛰면 됩니다"로 넘어갈 수도 있었는데, 그 전에 솎아내기 기준을 다시 봤다.

```swift
/// 허용 오차 하한(m). GPS 자체 오차(3~5m)보다 작은 기준은 의미가 없다.
private static let minTolerance = 3.0
/// 허용 오차 상한(m). 아무리 긴 경로여도 모양 자체가 뭉개지지 않도록 막는다.
private static let maxTolerance = 18.0
```

Douglas-Peucker가 점을 버리는 조건은 **그 점이 양 옆 점을 잇는 직선에서 허용 오차 안에 있을 때**다. 뒤집어 말하면 버려진 자리는 원래 거의 직선이었다는 뜻이다. 그러면 남은 두 점 사이를 이어서 위치를 구해도 **오차가 똑같이 그 안**이다. 최대 18m.

코스 그림은 폭이 300pt 남짓이고 거기에 수백 미터가 들어간다. 18m면 몇 픽셀이다.

처음에 "솎아냈으니 좌표를 못 쓴다"고 판단한 건 반만 맞았다. 계기 값을 얹는 용도로는 못 쓰는 게 맞다. 솎아내기는 **위치**에 대한 보장이지 그 자리의 심박이나 페이스에 대한 보장이 아니니까. 하지만 **위치 자체를 구하는 데는** 그 보장이 그대로 쓸 수 있는 보장이었다.

그래서 필드를 다시 뺐다. 저장 경로 네 군데에서 두 필드가 사라졌고, 전송 배열도 다시 일곱 개로 돌아갔고, 기존 기록에서도 항공기가 바로 떴다.

```swift
private func positionAt(elapsedTime: Int) -> (latitude: Double, longitude: Double)? {
    guard let first = coordinates.first, let last = coordinates.last else { return nil }
    if elapsedTime <= first.elapsedTime { return (first.latitude, first.longitude) }
    if elapsedTime >= last.elapsedTime { return (last.latitude, last.longitude) }

    guard let nextIndex = coordinates.firstIndex(where: { $0.elapsedTime >= elapsedTime }),
          nextIndex > 0 else { return (first.latitude, first.longitude) }
    let before = coordinates[nextIndex - 1]
    let after = coordinates[nextIndex]

    let span = Double(after.elapsedTime - before.elapsedTime)
    guard span > 0 else { return (after.latitude, after.longitude) }
    let ratio = Double(elapsedTime - before.elapsedTime) / span
    return (
        latitude: before.latitude + (after.latitude - before.latitude) * ratio,
        longitude: before.longitude + (after.longitude - before.longitude) * ratio
    )
}
```

---

### 모양이 늘어나지 않는 투영

지도를 안 쓰니 위경도를 화면 좌표로 옮기는 걸 직접 해야 했다.

여기서 그냥 위도와 경도를 각각 폭에 맞춰 늘리면 코스가 찌그러진다. 경도 1도의 실제 거리는 위도가 높을수록 짧아지기 때문이다. 서울 위도에서는 경도 1도가 위도 1도의 약 80% 거리다. 그대로 그리면 가로로 퍼진다.

그래서 경도 폭에 위도의 코사인을 곱하고, 가로세로 배율도 같은 값을 쓴다.

```swift
longitudeScale = cos(((latitudes.max() ?? 0) + minLatitude) / 2 * .pi / 180)

// 제자리 러닝처럼 폭이 0이면 나눌 수 없다. 아주 작은 값을 둬서 가운데 점으로 떨어지게 한다.
let latitudeSpan = max((latitudes.max() ?? 0) - minLatitude, 1e-9)
let longitudeSpan = max(((longitudes.max() ?? 0) - minLongitude) * longitudeScale, 1e-9)

scale = min(usableWidth / longitudeSpan, usableHeight / latitudeSpan)
```

---

## 왕복 구간에서 무의미해지는 밝기

처음엔 지나온 구간을 밝게, 남은 구간을 어둡게 그렸다. 항공기를 찾지 않아도 어디까지 왔는지 읽히니 괜찮아 보였다.

왕복을 생각하지 않은 결과였다. 돌아오는 길은 가는 길 위에 그대로 겹쳐 그려진다. 트랙에서 바퀴를 돌면 더하다. **한 바퀴만 돌아도 코스 전체가 밝아져서 밝기 구분이 아무 뜻도 없어진다.**

그래서 코스 전체는 어둡게 깔고, 항공기 바로 뒤 2분만 밝은 꼬리로 긋는 방식으로 바꿨다. 레이더 잔상 같은 모양이다. 코스가 몇 번을 겹쳐도 지금 어느 방향으로 가던 중인지는 계속 보인다. 전체에서 어디까지 왔는지는 위 판독 패널의 경과 시간과 거리가 숫자로 말해준다.

여기서 걸린 게 두 가지 있었다.

**꼬리 길이를 거리가 아니라 시간으로 잡았다.** 거리로 잡으면 쉬거나 걸은 구간에서 꼬리가 거의 안 자란다. 멈춰 있던 시간이 그림에서 사라지는 셈이다.

**그라디언트로 한 번에 칠하지 않고 토막마다 진하기를 올렸다.** `GraphicsContext`의 선형 그라디언트는 색이 직선 방향으로만 변한다. 꼬리가 코너를 돌거나 되돌아오는 구간이면 진하기가 거꾸로 뒤집힌다. 왕복 때문에 바꾸는 건데 왕복에서 깨지면 의미가 없다.

```swift
private func drawTrail(in context: inout GraphicsContext, using projection: Projection) {
    let points = trailPoints(using: projection)
    guard points.count > 1 else { return }

    for index in 1..<points.count {
        let progress = Double(index) / Double(points.count - 1)
        var segment = Path()
        segment.move(to: points[index - 1])
        segment.addLine(to: points[index])
        context.stroke(segment, with: .color(.rwGreen.opacity(0.15 + 0.85 * progress)), style: strokeStyle)
    }
}
```

꼬리의 양 끝도 좌표 사이를 이어서 맞췄다. 좌표가 있는 자리에서만 끊으면 직선 구간처럼 좌표가 드문 곳에서 꼬리 길이가 들쭉날쭉해지고, 머리 쪽은 항공기와 떨어져 보인다.

---

## 끌 수 있는 자리의 일원화

코스에서도 끌어서 시점을 옮길 수 있게 만들어봤다. 겹친 구간에서 손가락이 조금만 움직여도 갈 때와 올 때를 오가며 튀길래, 손가락 근처 좌표들 중에서 지금 짚은 시각과 가까운 쪽을 고르는 처리까지 넣었다.

그런데 그걸 다 하고 나서 더 근본적인 어긋남이 보였다.

트레이스 네 줄은 가로축이 시간이라 **항상 왼쪽이 시작**이다. 코스는 지리를 따라 그려지니 시작점이 어디로 갈지 알 수 없다. 그래서 같은 화면에서 한쪽은 왼쪽에서 오른쪽으로 끌고, 다른 쪽은 길이 난 대로 끌어야 한다.

시작이 왼쪽에 오도록 코스를 돌리는 방법도 있다. 회전은 모양도 좌회전/우회전도 그대로 유지되니 거짓말이 아니다. 좌우로 뒤집는 건 좌회전이 우회전이 되니까 절대 안 되고. 그런데 회전하면 북쪽이 위라는 게 깨져서 바로 앞 요약 화면 지도와 방향이 달라 보인다. 게다가 기준을 시작점에서 끝점으로 잡으면 왕복과 랩에서는 그 방향 자체가 없어진다.

결국 끌 수 있는 자리를 트레이스 한 곳으로 모았다. 코스는 보기만 하는 그림이 되고, 시작이 왼쪽에 와야 할 이유도 같이 사라진다. 공들여 만든 겹침 처리는 그대로 지웠다.

대신 코스와 트레이스 사이에 어디를 끌어야 하는지 한 줄을 넣었다. 코스를 끌어보고 아무 반응이 없으면 고장으로 보이기 때문이다.

![코스 아래에 어디를 끌어야 하는지 알려주는 한 줄이 들어간 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_hint.webp)

---

## 요약에서 들어가면 홈으로 튕기던 문제

화면을 다 만들고 실기기로 보는데, 러닝을 막 끝낸 직후 요약 화면에서 Flight Data Recorder로 들어가면 **홈으로 빠져나왔다.** Logbook에서 들어가면 멀쩡했다.

![러닝 직후 요약 화면에서 버튼을 눌렀는데 홈으로 빠져나오는 모습](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_bounce_home.gif)

원인은 요약 화면의 `onDisappear`였다.

```swift
.onDisappear {
    guard isPostRun else { return }
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

러닝 직후 흐름에서는 화면을 떠날 때 러닝 상태를 정리해야 한다. 그런데 `resetState()` 안에 `navigationPath = []`가 있다. 스택을 통째로 비우는 것이다.

`onDisappear`는 **사용자가 화면을 떠난 것과 위에 다른 화면이 덮인 것을 구별하지 못한다.** Recorder를 푸시하는 순간 요약 화면의 `onDisappear`가 돌고, 그게 스택을 비우면서 홈까지 밀려난 것이다.

<svg viewBox="0 0 420 212" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="Recorder를 푸시하면 요약 화면의 onDisappear가 돌아 스택이 비워지는 과정" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="na" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
  </defs>

  <rect x="0" y="28" width="118" height="34" rx="6" fill="currentColor" opacity=".08"/>
  <text x="59" y="49" font-size="11" fill="currentColor" opacity=".8"
        font-family="monospace" text-anchor="middle">Recorder 푸시</text>

  <path d="M118 45 L164 45" stroke="currentColor" stroke-opacity=".4" stroke-width="1.2" marker-end="url(#na)"/>

  <rect x="168" y="28" width="168" height="34" rx="6" fill="currentColor" opacity=".08"/>
  <text x="252" y="49" font-size="11" fill="currentColor" opacity=".8"
        font-family="monospace" text-anchor="middle">요약의 onDisappear</text>

  <path d="M252 62 L252 98" stroke="currentColor" stroke-opacity=".4" stroke-width="1.2" marker-end="url(#na)"/>

  <rect x="168" y="102" width="168" height="34" rx="6" fill="currentColor" opacity=".08"/>
  <text x="252" y="123" font-size="11" fill="currentColor" opacity=".8"
        font-family="monospace" text-anchor="middle">resetState()</text>

  <path d="M252 136 L252 172" stroke="currentColor" stroke-opacity=".4" stroke-width="1.2" marker-end="url(#na)"/>

  <rect x="168" y="176" width="168" height="34" rx="6" fill="currentColor" opacity=".08"/>
  <text x="252" y="197" font-size="11" fill="currentColor" opacity=".8"
        font-family="monospace" text-anchor="middle">navigationPath = []</text>

  <text x="348" y="197" font-size="10.5" fill="currentColor" opacity=".55" font-family="monospace">홈으로</text>
</svg>

`NavigationLink`는 푸시 여부를 알려주지 않는다. 그래서 뷰가 들고 있는 상태로 직접 띄우고, 그 값으로 리셋을 건너뛰게 했다.

```swift
/// Flight Data Recorder 를 띄웠는지 여부.
///
/// `NavigationLink` 대신 이 값으로 직접 띄운다. `onDisappear`는 사용자가 화면을 떠난
/// 것과 위에 다른 화면이 덮인 것을 구별하지 못해서, 그냥 두면 Recorder 로 들어가는 순간
/// 아래 `resetState()`가 돌아 `navigationPath`가 비워지고 홈까지 튕겨 나간다.
@State private var isShowingRecorder = false
```

```swift
Button {
    isShowingRecorder = true
} label: {
    // 생략
}
.navigationDestination(isPresented: $isShowingRecorder) {
    FlightDataRecorderView(flight: flight)
}
```

```swift
.onDisappear {
    guard isPostRun, !isShowingRecorder else { return }
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

![러닝 직후 요약 화면에서 버튼을 눌러 Flight Data Recorder 로 들어가는 모습](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_from_summary.gif)

`onDisappear`로 상태를 정리하다 걸린 게 이번이 처음이 아니다. 1.3.2에서 워치의 착륙 화면이 PFD에 덮였을 때도 같은 일이 있었다. 화면이 사라지는 것과 사용자가 떠나는 것은 다른 사건인데, SwiftUI는 둘을 같은 콜백으로 알려준다.

---

## 시뮬레이터에서 안 들어오는 고도와 케이던스

만드는 내내 시뮬레이터로 확인했는데, 여기서 보이는 것과 안 보이는 것이 갈린다.

워치 시뮬레이터를 페어링하면 심박은 들어온다. 그래서 PACE와 BPM 두 줄은 그려진다. 반면 고도는 시뮬레이터에 기압계가 없어서 `CMAltimeter.isRelativeAltitudeAvailable()`가 false고, 케이던스도 값이 들어오지 않는다.

그래서 만드는 동안에는 네 줄이 전부 채워진 모습을 볼 수가 없었다. 값을 직접 만들어 넣는 수밖에 없었다. 프리뷰를 두 개 뒀다. 하나는 5초 간격 324개(27분)를 사인파로 만들어 넣어 네 줄이 다 그려진 모습을 보는 것이고, 다른 하나는 표본이 없는 기록이다.

```swift
#Preview("표본 있음") {
    let container = previewContainer()
    let flight = SwiftDataFlight(
        mode: "modeA", distance: 5.2, time: 1620, pace: 5.19,
        heartRate: 152, cadence: 172, fuel: 341, date: .now,
        missionTarget: ModeATarget.pace.rawValue,
        missionTargetPace: 5.25, missionPaceDeviation: 15, missionTargetDistance: 5
    )
    container.mainContext.insert(flight)
    fillPreviewSamples(flight)
    return NavigationStack { FlightDataRecorderView(flight: flight) }
        .modelContainer(container)
}
```

프리뷰에서 컨테이너를 쓰는 이유가 있다. `@Model` 객체를 컨테이너에 넣지 않은 채로 관계 프로퍼티를 다루면 SwiftData가 버전에 따라 터진다. 그래서 먼저 넣고 나서 표본을 채운다.

---

## 1.4 이전 기록의 한계

표본은 러닝 중에 담는 값이라 지난 기록에는 채울 방법이 없다. 스플릿으로 역산할 수도 없고 좌표로 만들 수도 없다는 게 이 글 처음에 적은 내용 그대로다.

그래서 표본이 없는 기록은 안내 문구를 띄운다. 숨기거나 빈 화면을 보여주는 것보다, 왜 없는지와 언제부터 생기는지를 말해주는 쪽이 낫다고 봤다.

![표본이 없는 지난 기록에 되감기 대신 안내 문구가 뜬 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-02-RunningProject-46/runway14_fdr_no_samples.webp)

---

## 정리

데이터를 하나 추가하는 일이라고 생각했는데, 실제로 시간이 간 건 **이미 있는 데이터로 되는지 아닌지를 가리는 판단**이었다.

솎아낸 좌표로는 계기 값을 되살릴 수 없다는 건 맞았다. 솎아내기가 보장하는 건 모양이지 그 자리의 심박이 아니기 때문이다. 그런데 같은 이유로 "좌표는 못 쓴다"고 단정해서 위치까지 중복 저장했던 건 틀렸다. 솎아내기가 보장하는 게 모양이라면, **위치를 구하는 데는 그 보장이 그대로 쓸 수 있는 보장**이었다.

한쪽으로는 못 쓰고 다른 쪽으로는 쓸 수 있는데, 같은 문장으로 묶어두니 구별이 안 됐다. 알고리즘이 무엇을 보장하는지를 한 번 더 정확히 읽었으면 저장 경로 네 군데를 두 번 고치지 않아도 됐다.
