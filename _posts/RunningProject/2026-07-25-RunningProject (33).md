---
title: RunWay 1.2 (2) km 스플릿, 상대고도 추가
writer: Harold
date: 2026-07-25 20:40:00 +0900
categories: [RunWay]
tags: [SwiftData, CoreMotion, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

[이전글](https://haroldfromk.github.io/posts/RunningProject-(32)/){:target="_blank"}에서 심박 미션 버그를 다 잡고, 이번엔 다음 순서였던 km 단위 스플릿 기능으로 넘어왔다. 러닝 하나를 1km마다 끊어서 그 구간 페이스/심박/케이던스를 따로 기록하는 기능이다.

---

## 케이던스도 심박처럼 받아두기

`HealthCenter`가 지금까지 심박만 들고 있었는데, 스플릿엔 케이던스도 필요해서 똑같은 방식으로 하나 더 추가했다.

```swift
actor HealthCenter {
    private(set) var currentHeartRate: Double = 0
    private(set) var currentCadence: Double = 0

    func processHeartRate(_ raw: Double) {
        currentHeartRate = raw
    }

    func processCadence(_ raw: Double) {
        currentCadence = raw
    }
}
```

아이폰/워치 양쪽에서 심박 받는 자리마다 케이던스도 같이 넘겨주게 한 줄씩 추가했다.

---

## GPS 타임스탬프로 스플릿 끊기

`RunningCenter`가 GPS 위치를 받을 때마다 누적 거리가 1km를 넘는지 확인하고, 넘으면 그 구간의 평균 페이스/심박/케이던스를 계산해서 내보내게 했다. 경과 시간은 따로 타이머를 두지 않고 `CLLocation.timestamp`끼리 빼서 구했다.

이 함수는 GPS 위치가 들어올 때마다 매번 두 가지 일을 한다. 하나는 지금 진행 중인 구간에 심박/케이던스 샘플을 계속 쌓아두는 거고, 다른 하나는 그러다 누적 거리가 1km 경계를 넘었는지 확인해서 넘었으면 그 구간을 스플릿으로 확정하는 거다.

코드에 나오는 `split`으로 시작하는 이름들은 전부 지역 변수가 아니라 `RunningCenter`가 계속 들고 있는 상태값이다. 함수가 끝나도 사라지지 않고, 다음 GPS 업데이트가 들어올 때도 그대로 남아있다.

- `splitIndex`: 지금까지 몇 번째 스플릿을 만들었는지 세는 카운터. 스플릿을 하나 만들 때마다 1씩 늘어나고, 그대로 `Split`의 `order`가 된다.
- `splitStartDistance`: 지금 진행 중인 구간이 시작된 누적 거리. 다음 1km 경계가 어디인지 이 값 기준으로 계산한다.
- `splitHeartRateSum`/`splitHeartRateCount`, `splitCadenceSum`/`splitCadenceCount`: 지금 구간에 들어온 심박/케이던스 샘플의 합과 개수. 구간이 끝나는 시점에 나눠서 평균을 낸다.
- `previousSplitElapsedTime`: 직전 스플릿이 끝난 시점까지의 누적 경과 시간. 이번 구간만의 소요 시간을 구할 때 뺄셈 기준이 된다.
- `runStartTime`: 러닝이 시작된 시각. 경과 시간을 계산하는 기준점이다.

```swift
// RunningCenter

private func recordSplitSample(at timestamp: Date) async {
    let heartRate = await healthCenter.currentHeartRate
    let cadence = await healthCenter.currentCadence

    if heartRate > 0 {
        splitHeartRateSum += heartRate
        splitHeartRateCount += 1
    }
    if cadence > 0 {
        splitCadenceSum += cadence
        splitCadenceCount += 1
    }

    while totalDistance - splitStartDistance >= 1000 {
        splitIndex += 1
        let elapsedTime = runStartTime.map { Int(timestamp.timeIntervalSince($0)) } ?? 0
        let splitDuration = elapsedTime - previousSplitElapsedTime
        let splitPace = splitDuration > 0 ? Double(splitDuration) / 60.0 : 0
        let avgHeartRate = splitHeartRateCount > 0 ? Int(splitHeartRateSum / Double(splitHeartRateCount)) : 0
        let avgCadence = splitCadenceCount > 0 ? Int(splitCadenceSum / Double(splitCadenceCount)) : 0

        let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime)
        splitContinuation?.yield(split)

        splitStartDistance += 1000
        previousSplitElapsedTime = elapsedTime
        splitHeartRateSum = 0
        splitHeartRateCount = 0
        splitCadenceSum = 0
        splitCadenceCount = 0
    }
}
```

---

### 평균을 왜 마지막에 한 번만 내는가

심박/케이던스 평균은 그때그때 나눠서 계산하지 않고, 합(`splitHeartRateSum`)과 개수(`splitHeartRateCount`)만 계속 쌓아뒀다가 구간이 끝나는 순간에 딱 한 번 나눈다. 

`count`가 따로 필요한 이유는, `sum`만 쌓아두면 나중에 그걸 몇 개로 나눠야 진짜 평균인지 알 방법이 없기 때문이다. `recordSplitSample`은 GPS 위치가 들어올 때마다 `currentHeartRate`를 한 번씩 관찰하는 셈인데, 이 관찰 하나하나를 똑같은 무게로 쳐서 평균에 반영하는 방식이라 유효한 관찰이 들어올 때마다 `sum`엔 값을 더하고 `count`는 1 늘린다. 

값이 0이면(워치 연결이 아직 안 됐거나 순간적으로 끊겼거나) 아예 `count`에도 안 넣어서, 0값이 평균을 실제보다 낮게 끌어내리는 일이 없게 했다.

---

### if가 아니라 while을 쓴 이유

`if`가 아니라 `while`을 쓴 이유는 GPS 업데이트 한 번에 1km를 훌쩍 넘겨버리는 경우 때문이다. 

예를 들어 신호가 잠깐 끊겼다가 몇 초 뒤에 다시 들어오면, 그 사이 실제로는 1.3km를 이동했는데 위치 업데이트는 한 번만 오는 상황이 생길 수 있다. 

`if`로 짜면 이런 경우 스플릿 하나를 통째로 놓치는데, `while`로 돌리면 이 한 번의 업데이트 안에서도 경계를 넘을 때마다 스플릿을 하나씩 만들어서 빠짐없이 챙긴다. `splitStartDistance`는 항상 "다음 스플릿이 시작되는 지점"을 가리키는데, 스플릿을 하나 만들 때마다 여기에 1000을 더해서 `while` 조건이 다음 1km 경계를 기준으로 다시 평가되게 한다.

---

### 경과 시간을 GPS 시각으로 재는 이유

경과 시간을 별도 타이머로 재지 않고 `CLLocation.timestamp`끼리 뺀 이유는, `RunViewModel`/`WatchViewModel`에 이미 있는 1초 타이머는 화면 갱신용이라 GPS 업데이트 시점과 정확히 맞아떨어지지 않기 때문이다. GPS 위치 자체에 찍혀 있는 시각을 그대로 쓰면 스플릿 시각이 항상 실제 위치 데이터와 동기화된 채로 남는다.

`runStartTime.map { }`의 `map`은 배열의 `map`이 아니라 Optional의 `map`이다. `runStartTime`은 `Date?` 타입이라, 값이 있으면 그 값을 꺼내서 변환하고 없으면 그냥 `nil`을 돌려준다.

```swift
// 아래 두 코드는 같다
let elapsedTime = runStartTime.map { Int(timestamp.timeIntervalSince($0)) } ?? 0

let elapsedTime: Int
if let start = runStartTime {
    elapsedTime = Int(timestamp.timeIntervalSince(start))
} else {
    elapsedTime = 0
}
```

`runStartTime`이 세팅 안 됐을 상황을 대비해 `?? 0`을 붙여뒀을 뿐, `elapsedTime`은 그냥 초 단위 정수 하나다.

첫 번째 스플릿에서는 `previousSplitElapsedTime`이 `reset()`에서 세팅한 0 그대로라 `splitDuration = elapsedTime - 0`이 되는데, 이것도 의도한 동작이다. 0을 "직전 스플릿이 없을 때의 기준점"으로 쓴 거라, 첫 스플릿의 소요 시간은 자연스럽게 "러닝 시작부터 지금까지 걸린 시간 전체"가 된다.

`streamFlightData()`/`streamPhaseData()`랑 같은 패턴으로 `streamSplitData()`를 하나 더 만들어서 아이폰/워치 양쪽 ViewModel이 구독하게 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/while.png){: width="50%" height="50%"}

한 번만 검사하는 것과 넘긴 만큼 반복하는 것이 실제로 얼마나 다른지 돌려볼 수 있게 만들었다. 중간에 회색으로 칠한 구간이 신호가 끊겼다 돌아오는 지점이다.

<iframe
  src="/assets/demo/split_boundary_simulator.html"
  width="100%"
  height="530px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

`if`로 두고 끝까지 돌리면 4.35km를 뛰었는데 스플릿이 3개만 나온다. 더 나쁜 건 개수가 하나 모자란 것으로 끝나지 않는다는 점이다. 놓친 경계 이후로 **3번 스플릿이 실제로는 4km 지점에 찍혀 있다.** 한 번 어긋난 기준이 러닝이 끝날 때까지 그대로 밀린 채로 간다. `while`로 바꾸면 같은 데이터에서 4개가 다 나오고 번호도 실제 km와 맞는다.

---

## SwiftDataSplit 모델링

새 모델이라 이번엔 아예 처음부터 모든 프로퍼티에 선언부 기본값을 넣었다. 지난 글에서 겪은 마이그레이션 문제를 두 번 겪고 싶지 않았다.

```swift
@Model
class SwiftDataSplit {
    var order: Int = 0
    var pace: Double = 0
    var heartRate: Int = 0
    var cadence: Int = 0
    var elapsedTime: Int = 0

    init(order: Int = 0, pace: Double = 0, heartRate: Int = 0, cadence: Int = 0, elapsedTime: Int = 0) {
        self.order = order
        self.pace = pace
        self.heartRate = heartRate
        self.cadence = cadence
        self.elapsedTime = elapsedTime
    }
}
```

`SwiftDataFlight`에도 `splits` 관계를 하나 추가했다.

```swift
@Relationship(deleteRule: .cascade) var splits: [SwiftDataSplit] = []
```

---

## Split UI 구현

첫 버전은 막대 그래프로 만들었다. 막대 높이가 그 구간 페이스에 비례하고, 제일 빠른 구간은 초록, 제일 느린 구간은 빨강으로 표시된다.

```swift
struct SplitsChartView: View {
    let splits: [SwiftDataSplit]

    private let maxBarHeight: CGFloat = 90
    private let minBarHeight: CGFloat = 16

    private var sortedSplits: [SwiftDataSplit] {
        splits.sorted { $0.order < $1.order }
    }
    private var validPaces: [Double] {
        sortedSplits.map { $0.pace }.filter { $0 > 0 }
    }
    private var maxPace: Double { validPaces.max() ?? 0 }
    private var minPace: Double { validPaces.min() ?? 0 }

    private func barHeight(for pace: Double) -> CGFloat {
        guard maxPace > 0, pace > 0 else { return minBarHeight }
        let ratio = pace / maxPace
        return minBarHeight + (maxBarHeight - minBarHeight) * CGFloat(ratio)
    }

    private func barColor(for pace: Double) -> Color {
        guard pace > 0 else { return .rwMuted.opacity(0.3) }
        if pace == minPace { return .rwGreen }
        if pace == maxPace { return .rwRed }
        return .rwAmber
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.rwGreen)
                    .font(.system(size: 10))
                Text("SPLITS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.rwMuted)
                    .kerning(1.5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(sortedSplits, id: \.order) { split in
                        VStack(spacing: 4) {
                            Text(split.pace > 0 ? PaceFormatter.format(split.pace) : "--")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.rwMuted)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor(for: split.pace))
                                .frame(width: 14, height: barHeight(for: split.pace))
                            Text("\(split.order)")
                                .font(.system(size: 8))
                                .foregroundColor(.rwMuted)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)
            }
            .frame(height: maxBarHeight + 36)
        }
        .padding(14)
        .background(Color.rwPanel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splits_chart_crop.png)

1km마다 페이스가 다르게(0:34, 0:45, 1:06) 나오고, 제일 빠른 구간은 초록, 제일 느린 구간은 빨강으로 구분되는 것까지 의도한 대로 나왔다.

---

## Split UI 보완

화면을 보고 나니 막대 높이로만 페이스를 비교하는 방식이 오히려 헷갈렸다. 단위도 안 붙어 있었고, 무엇보다 심박/케이던스는 이미 `SwiftDataSplit`에 다 모아두고서 화면엔 하나도 안 쓰고 있었다. 나이키 런클럽처럼 km마다 페이스/심박/케이던스를 한 줄에 같이 보여주는 리스트로 바꿨다.

```swift
struct SplitRow: View {
    let split: SwiftDataSplit
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Text("\(split.order)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            // PACE / BPM / SPM 세 칸, 각각 값 + 라벨
        }
    }
}
```

헤더에도 "(min:sec / km)" 단위를 붙이고, 색이 뭘 뜻하는지 바로 보이게 최고/최저 범례 점 두 개를 오른쪽에 추가했다. 맨 왼쪽 번호 배지도 그냥 숫자만 있으니 뭘 세는 건지 안 보여서, PACE/BPM/SPM처럼 아래에 "KM" 라벨을 붙였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splits_chart_crop2.png)

이번 테스트 러닝은 심박/케이던스 데이터가 없어서 BPM/SPM 칸은 "--"로 뜨는데, 이것도 값이 없을 때 정직하게 "--"를 보여주는 다른 화면들이랑 같은 방식이라 의도한 동작이다.

돌아보니 원래 있던 "로그북이 제한적"이라는 피드백도 사실 이 FlightSummaryView 얘기였다. 로그북 목록 화면 자체는 따로 손볼 게 없어서, 이제 남은 건 실제로 뛰어보는 실기기 테스트뿐이다.

---

## 자투리 구간도 스플릿으로 남기기

실기기 테스트 나가기 전에 다시 살펴보다가 애매한 지점을 하나 발견했다. 지금 스플릿은 정확히 1키로 단위로만 끊기는데, 1.7키로를 뛰면 1키로짜리 스플릿 하나만 나오고 나머지 0.7키로는 그냥 사라진다. 뛴 거리를 다 보여주는 게 맞겠다 싶어서 손봤다.

`RunningCenter`에 러닝이 끝나는 시점에 한 번 더 불러주는 함수를 하나 추가했다. 

남은 거리가 100m 이상이면 그 실제 거리로 페이스를 계산해서 마지막 스플릿을 하나 더 만들고, 100m 미만이면 그냥 버린다. 몇십 미터 정도는 페이스를 계산해봐야 오차만 커서 의미가 없다고 판단했다. `RunningCenter` 내부는 거리를 전부 미터 단위로 들고 있어서, 여기 기준값도 100(m)이다.

```swift
func finalizePendingSplit(at timestamp: Date = Date()) -> Split? {
    let remainingMeters = totalDistance - splitStartDistance
    guard remainingMeters >= 100 else { return nil }

    splitIndex += 1
    let elapsedTime = runStartTime.map { Int(timestamp.timeIntervalSince($0)) } ?? 0
    let splitDuration = elapsedTime - previousSplitElapsedTime
    let distanceKm = remainingMeters / 1000
    let splitPace = (splitDuration > 0 && distanceKm > 0) ? (Double(splitDuration) / 60.0) / distanceKm : 0
    let avgHeartRate = splitHeartRateCount > 0 ? Int(splitHeartRateSum / Double(splitHeartRateCount)) : 0
    let avgCadence = splitCadenceCount > 0 ? Int(splitCadenceSum / Double(splitCadenceCount)) : 0
    return Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime, distance: distanceKm)
}
```

`avgHeartRate`/`avgCadence`는 `recordSplitSample(at:)`에서 쓴 것과 똑같은 계산이다. 지금까지 쌓인 `splitHeartRateSum`/`splitHeartRateCount`, `splitCadenceSum`/`splitCadenceCount`를 여기서도 한 번 더 나눠서 평균을 낸다. 다른 함수라고 새로 계산하는 게 아니라, 같은 상태값을 그대로 재사용하는 것뿐이다.

이걸 위해 `Split`과 `SwiftDataSplit`에 `distance` 필드를 하나씩 추가했다. 1km마다 자동으로 끊기는 기존 스플릿들은 어차피 항상 정확히 1.0이라 굳이 저장 안 해도 됐지만, 이 마지막 자투리 스플릿은 매번 실제 거리가 달라지니 꼭 있어야 했다.

---

### 자투리 스플릿만 다르게 표시하기

화면에 보여줄 때도 이 자투리 스플릿만 다르게 표시해야 했다. 나머지 스플릿은 다 "KM"이라고 붙어 있는데, 이 마지막 스플릿에까지 "KM"이라고 써버리면 실제로는 700m만 뛰고도 1키로를 채운 것처럼 보인다. 그래서 1키로에 못 미치면 실제 거리를 미터 단위 그대로 보여주게 했다.

```swift
private var distanceLabel: String {
    split.distance >= 0.95 ? "KM" : "\(Int(split.distance * 1000))M"
}
```

---

### 스플릿이 하나도 안 뜨던 버그

구현해두고 시뮬레이터에서 확인하다가 진짜 버그를 하나 발견했다. 위치를 빠르게 이동시켜서 1.06km짜리 러닝을 만들어봤는데, 요약 화면에 스플릿이 하나도 안 뜨는 거였다. 1km는 이미 넘겼으니 최소한 1번 스플릿은 나와야 하는데 그것마저 없었다.

원인은 1km를 지날 때마다 만든 스플릿을 처리하는 방식에 있었다. 원래는 `RunningCenter`가 스플릿을 `AsyncStream`으로 내보내고, `RunViewModel`의 별도 `Task`가 그걸 받아서 배열에 쌓아뒀다가 저장 시점에 그 배열을 읽는 구조였다.

```swift
// Before
Task {
    for await split in await runningCenter.streamSplitData() {
        self.tempSplitArray.append(SwiftDataSplit(order: split.order, pace: split.pace, heartRate: split.heartRate, cadence: split.cadence, elapsedTime: split.elapsedTime))
    }
}
```

문제는 1km를 막 넘긴 직후에 바로 러닝을 끝내면, 방금 만든 스플릿이 스트림에 올라가고 그걸 받는 `Task`가 배열에 반영하기도 전에 `saveRunningData()`가 먼저 실행돼버릴 수 있다는 거였다. 빠르게 이동하는 테스트에서 딱 이 타이밍이 걸린 거였다. `Task`가 배열에 값을 넣는 시점과 저장 함수가 그 배열을 읽는 시점 사이에 아무 보장이 없으니, 둘 중 뭐가 먼저 실행될지는 그때그때 달랐던 셈이다.

`tempSplitArray`가 하는 일은 어차피 저장 직전에 한 번 읽히는 게 전부라, 스트림으로 흘려보낼 이유가 없었다. `RunningCenter`가 확정된 스플릿을 자기 안에 배열로 그냥 들고 있게 하고, 저장 시점에 그 배열을 직접 동기적으로 읽어오는 방식으로 바꿨다.

```swift
// After
private var completedSplits: [Split] = []

private func recordSplitSample(at timestamp: Date) async {
    // 생략
    while totalDistance - splitStartDistance >= 1000 {
        // 생략
        let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime, distance: 1)
        completedSplits.append(split)
        // 생략
    }
}

func allSplits(at timestamp: Date = Date()) -> [Split] {
    var result = completedSplits
    if let tail = finalizePendingSplit(at: timestamp) {
        result.append(tail)
    }
    return result
}
```

`saveRunningData()`에서는 더 이상 배열을 따로 들고 있을 필요가 없어져서, 저장 시점에 `allSplits()`를 한 번 호출해 그대로 쓰면 된다.

```swift
let splits = await runningCenter.allSplits()
runningData.splits.append(contentsOf: splits.map {
    SwiftDataSplit(order: $0.order, pace: $0.pace, heartRate: $0.heartRate, cadence: $0.cadence, elapsedTime: $0.elapsedTime, distance: $0.distance)
})
```

---

### 기준값이 서로 안 맞던 것

그런데 100m 기준을 정해놓고 보니, 정작 러닝 전체를 저장할지 말지 가르는 기준은 예전부터 50m로 따로 있었다. 러닝은 50m부터 기록되는데 스플릿은 100m부터 기록되면 기준이 서로 안 맞는 셈이라, 이번 참에 러닝 저장 기준도 100m로 같이 올렸다.

```swift
let minimumValidDistance = 0.1
guard totalDistance >= minimumValidDistance else { return }
```

버려지는 자투리 구간이 있다는 것도 화면에서 알 수 있으면 좋겠다 싶어서, 러닝 전체가 너무 짧아 저장 안 됐을 때 뜨는 "NOT RECORDED - TOO SHORT" 배지와 같은 톤으로 스플릿 카드 아래에 작은 안내를 하나 더 붙였다. 이 값을 위해 따로 저장하는 필드는 없고, 총 거리에서 기록된 스플릿 거리의 합을 빼서 그 자리에서 계산한다.

```swift
private var droppedTailMeters: Int {
    let recorded = sortedSplits.reduce(0) { $0 + $1.distance }
    let leftoverKm = totalDistance - recorded
    return Int((leftoverKm * 1000).rounded())
}
```

고쳐두고 다시 시뮬레이터로 확인했다. 1.05km 러닝은 1번 스플릿이 정상적으로 뜨고, 그 아래 "마지막 50M 구간 - TOO SHORT" 안내도 의도한 대로 나왔다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splitshort.png){: width="50%" height="50%"}

1.84km 러닝은 1번(1km)과 2번(842m) 스플릿이 둘 다 뜨는데, 자투리가 100m를 넘겨서 버려지지 않고 실제 거리 그대로 스플릿이 됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splitdetail.png){: width="50%" height="50%"}

---

## ALT 스무딩 자료 조사

다음 순서를 오디오 콜아웃(#36)으로 할지 고도 추적(ALT, #37)으로 할지 고민하다가, 스플릿에 고도 정보도 나중에 들어갈 수 있으니 ALT를 먼저 하기로 했다. 상대 고도(`CMAltimeter.relativeAltitude`)를 쓰기로는 이미 정했는데, 스무딩을 어떻게 할지가 남아서 자료를 찾아봤다.

먼저 마스터플랜에 적어뒀던 "일시정지 중 오프셋이 튀는 버그"부터 확인했다. RunWay만 겪는 문제가 아니라 [애플 자체의 알려진 버그](https://developer.apple.com/forums/thread/654116){:target="_blank"}였다. `HKWorkoutSession`이 일시정지되면 그 순간 `relativeAltitude` 값이 튀어버리는데, 2020년부터 계속 보고되고 있고 아직 안 고쳐졌다. 우회 방법은 두 가지였다.

- 이전 값과 비교해서 짧은 시간에 물리적으로 말이 안 되는 변화량이면 그 샘플을 버리는 방식
- `relativeAltitude` 대신 원시 기압값을 직접 고도로 환산하는 방식 (버그는 relativeAltitude에만 있고 원시 기압값은 영향 안 받음)

스무딩은 페이스 스무딩할 때 쓴 더블 EMA를 그대로 재사용하기로 했다. 기압 센서로 사람 움직임을 추적하는 연구에서도 이 방식을 노이즈 제거용으로 쓰고 있어서, 이미 검증된 방법을 고도에도 그대로 가져다 쓰면 되겠다고 판단했다.

정리한 순서는 이렇다.

1. 이전 값과 비교해서 짧은 시간에 말이 안 되는 변화량(초당 3m 이상)이면 그 샘플부터 버린다 (일시정지 버그 대응)
2. 통과한 값만 더블 EMA로 스무딩한다 (평소 잔노이즈 대응)
3. 일단 `relativeAltitude`로 시작하고, 실기기 테스트해서 안 되면 그때 원시 기압값 환산으로 갈아탄다

---

## ALT 구현

이전에 잠시 빼둔 `AltTapeView.swift`를 이제서야 사용한다.

SPD 테이프랑 똑같은 모양으로 만들어뒀는데, 눈금도 `["100", "80", "60", "42", "20", "0"]`으로 하드코딩돼 있고 단위도 "km"로 잘못 적혀 있었다(고도는 m 단위).

먼저 `CMAltimeter`를 감싸는 `AltimeterService`를 `LocationService`랑 같은 구조로 만들었다.

```swift
final class AltimeterService {
    private let altimeter = CMAltimeter()
    var altitudePublisher = PassthroughSubject<CMAltitudeData, Never>()

    func startTracking() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            self.altitudePublisher.send(data)
        }
    }

    func stopTracking() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}
```

`RunningCenter`에는 위에서 정리한 순서(가드 → 더블 EMA) 그대로 옮겼다.

```swift
func processAltitude(_ rawAltitude: Double, timestamp: TimeInterval) {
    if let last = lastAltitudeSample {
        let dt = timestamp - last.timestamp
        let delta = abs(rawAltitude - last.value)
        if dt > 0, delta / dt > 3.0 {
            return
        }
    }
    lastAltitudeSample = (rawAltitude, timestamp)

    if !isAltitudeInitialized {
        smoothingAltitudeFirst = rawAltitude
        smoothingAltitudeSecond = rawAltitude
        isAltitudeInitialized = true
    }

    smoothingAltitudeFirst = 0.8 * smoothingAltitudeFirst + 0.2 * rawAltitude
    smoothingAltitudeSecond = 0.8 * smoothingAltitudeSecond + 0.2 * smoothingAltitudeFirst
    currentAltitude = smoothingAltitudeSecond
}
```

[이전글](https://haroldfromk.github.io/posts/RunningProject-(10)/){:target="_blank"}에서 만든 페이스 스무딩은 `smoothingSpeedFirst == 0`을 "아직 초기화 전"으로 판단했는데, 고도는 0에서 시작하는 게 정상이라 이 방식을 못 썼다. 속도는 0이 "아직 안 뛰기 시작함"이라는 뜻으로 자연스럽게 쓰이지만, 상대고도는 0이 "출발점과 같은 높이"라는 멀쩡한 실제 값일 수 있어서, 값 자체만 보고는 초기화 여부를 구분할 수가 없다. 

그래서 `isAltitudeInitialized`라는 별도 플래그를 하나 더 둬서, 첫 샘플이 들어오는 순간에만 `smoothingAltitudeFirst`/`Second`를 그 raw 값으로 시드(seed)하고 그 뒤로는 정상적인 EMA 계산을 타게 만들었다. 

참고로 이 플래그는 고도계를 껐다 켰다 하는 것과는 무관하다. 그건 `AltimeterService.startTracking()`/`stopTracking()`이 따로 담당하고, `isAltitudeInitialized`는 순전히 `RunningCenter` 안에서 스무딩 값을 언제 시드할지만 판단하는 상태다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/init.png){: width="50%" height="50%"}

두 스무딩을 나란히 놓고 보면 공식 자체는 완전히 같고, "첫 샘플을 언제 시드할지" 판단하는 방법만 다르다는 게 더 잘 보인다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/smoothing_init_compare.svg){: width="700" height="373"}

가드와 스무딩이 실제로 뭘 걸러내는지도 돌려볼 수 있게 만들었다. 언덕을 하나 올라갔다 내려온 뒤 조금 더 오르는 코스인데, 중간에 일시정지가 걸려서 값이 통째로 튀는 상황이다.

<iframe
  src="/assets/demo/altitude_guard_simulator.html"
  width="100%"
  height="660px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

가드를 끄면 튄 값이 그대로 흘러 들어가서, 값이 제자리로 돌아온 뒤에도 흔적이 남는다. 가드를 켜면 그 구간 샘플 11개를 통째로 버리고 다듬은 값은 직전 상태에 머문다.

여기서 한 가지가 더 보인다. 마지막에 다듬은 값은 +4m대인데 이 글 뒤쪽에서 만들 상승고도는 +9m대가 나온다. 언덕을 올라갔다 내려온 몫이 **지금 높이에서는 상쇄되지만 올라간 총량에는 그대로 남기** 때문이다. 이 차이가 나중에 스플릿 지표를 구간 차이에서 상승고도로 바꾸게 되는 이유가 된다.

원래 `FlightData.altitude`는 GPS 절대 고도(`location.altitude`)를 그대로 담고 있었는데, 아무 화면에서도 안 쓰고 있어서 이번에 스무딩된 상대 고도로 바꿔치기했다.

`AltTapeView`는 하드코딩된 값을 지우고 `SpeedTapeView`처럼 현재 고도 기준으로 -2~+2칸을 동적으로 그리게 바꿨다. 단위도 "km"에서 "m"으로 고쳤다.

```swift
private var dynamicAlts: [Int] {
    let step = 10.0
    let center = (currentAltitude / step).rounded()
    return [-2, -1, 0, 1, 2].map { Int((center + Double($0)) * step) }.reversed()
}
```

`PFDView`의 SpeedTapeView + NavDisplay 옆에 붙였다.

```swift
HStack(spacing: 0) {
    SpeedTapeView().frame(width: 62)
    NavDisplayCanvas(...)
    AltTapeView().frame(width: 62)
}
```

붙여놓고 보니 SPD는 배경이 `Color.black.opacity(0.6)`인데 ALT는 예전 mock 파일에 있던 `Color.rwPanel.opacity(0.9)`가 그대로 남아 있어서 톤이 서로 달랐다. SPD 쪽 값으로 맞췄다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/alt.png){: width="50%" height="50%"}

고도가 계속 0으로 뜨길래 혹시나 해서 "ALT" 라벨 자리에 `CMAltimeter.isRelativeAltitudeAvailable()` 값을 잠깐 찍어봤더니 실제로 false가 나왔다. 시뮬레이터엔 진짜 기압계가 없어서 아예 값을 안 주는 거였다. 심박 때와 같은 이유다. 레이아웃과 배선은 이걸로 확인이 끝났고, 실제 값 확인은 실기기로 계단이나 언덕을 오르내리며 해봐야 한다.

---

## 워치에도 ALT 탭 추가


```swift
enum PFDTab: Int, CaseIterable {
    case pfd
    case pace
    case heartRate
    case cadence
    case alt
}
```

```swift
WatchFocusTab(
    label: "ALTITUDE",
    value: "\(Int(viewModel.flightData.altitude))",
    unit: "M",
    color: .rwGreen,
    icon: "mountain.2.fill"
)
.tag(PFDTab.alt)
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/watchalt.png){: width="50%" height="50%"}

`WatchFocusTab`이 라벨/값/단위/색/아이콘만 받는 재사용 컴포넌트라 다른 탭들처럼 그대로 끼워 넣기만 하면 됐다. `flightData.altitude`는 워치가 직접 뛰든 아이폰 미러링을 받든 이미 같은 경로로 들어오고 있어서 따로 손댈 것도 없었다.

넘겨봐야 나오는 탭 말고, 페이지 넘길 필요 없는 첫 화면(`WatchFlightPaceTab`)에도 있으면 좋겠다는 얘기가 나와서, 아래쪽 DIST/HR/CAD 세 칸 그리드에 ALT 칸 하나를 더 얹었다.

```swift
Divider().frame(height: 36).background(Color.rwBorder)
WatchStatMini(label: "HR", value: "\(hr)", unit: "BPM", color: .rwRed)
Divider().frame(height: 36).background(Color.rwBorder)
WatchStatMini(label: "CAD", value: "\(cadence)", unit: "SPM")
Divider().frame(height: 36).background(Color.rwBorder)
WatchStatMini(label: "ALT", value: "\(altitude)", unit: "M")
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/watch_pfd_alt.png){: width="50%" height="50%"}

4칸이 되니 좀 빡빡해 보이려나 걱정했는데, `WatchStatMini`가 원래 숫자 몇 자리 정도만 보여주는 용도라 막상 넣어보니 괜찮았다.

---

## 스플릿에도 고도 변화 넣기

ALT를 km 스플릿보다 먼저 한 이유가 애초에 "스플릿에 고도 정보도 나중에 들어갈 수 있어서"였다. ALT 구현이 끝났으니 이제 그걸 실제로 붙일 차례였다.

평균 고도값 자체보다는 그 구간에서 얼마나 오르내렸는지가 트레일/언덕 코스에서 의미가 있다고 판단해서, `Split`과 `SwiftDataSplit`에 `elevationChange` 필드를 추가했다. 양수면 오르막, 음수면 내리막이다.

`RunningCenter`가 각 스플릿 구간이 시작되는 시점의 고도를 따로 기억해뒀다가, 구간이 끝나는 시점의 현재 고도와 비교해서 차이를 구한다. 1km마다 자동으로 끊기는 구간과, 러닝 종료 시 자투리 구간을 만드는 `finalizePendingSplit()` 둘 다 같은 방식이다.

```swift
while totalDistance - splitStartDistance >= 1000 {
    // 생략
    let elevationChange = currentAltitude - splitStartAltitude
    let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime, distance: 1, elevationChange: elevationChange)
    completedSplits.append(split)

    splitStartDistance += 1000
    splitStartAltitude = currentAltitude
    // 생략
}
```

화면에는 파란색으로 네 번째 칸을 추가했다. 부호를 그대로 보여줘야 오르막/내리막이 구분되니, 양수일 때만 "+"를 붙였다.

```swift
private var elevationLabel: String {
    let rounded = Int(split.elevationChange.rounded())
    return rounded > 0 ? "+\(rounded)" : "\(rounded)"
}
```

PACE/BPM/SPM 세 칸이 있던 자리에 ALT 칸 하나를 더 얹었는데, 시뮬레이터로 확인해보니 네 칸이 되어도 레이아웃이 깨지지 않고 잘 들어갔다. 다만 시뮬레이터엔 기압계가 없어서 고도 값 자체는 계속 0으로 뜬다. 실제 오르막/내리막 값이 맞게 나오는지는 ALT 때와 마찬가지로 실기기에서 언덕이나 계단을 오르내리며 확인해야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/summaryalt.png){: width="50%" height="50%"}

고도 관련 값은 `SwiftDataSplit`에만 넣었고, GPS 좌표(`SwiftDataCoordinate`)처럼 지점마다 저장하지는 않았다. `SwiftDataCoordinate`는 위도/경도를 지점마다 다 저장하는데, 이건 `MapPolyline`으로 정확한 경로를 그려야 하니 전체 해상도가 필요해서다. 반면 고도는 지금 러닝 중 PFDView의 ALT 테이프(그 순간 값 하나)랑 러닝 후 스플릿/전체 상승고도(구간 단위 집계값) 두 군데에서만 쓰는데, 둘 다 지점마다의 정확한 고도 곡선까지는 필요 없다. 나중에 Strava처럼 구간 고도 그래프를 보여주는 화면이 생기면 그때 좌표처럼 지점마다 저장하면 되고, 지금은 안 쓰이는 데이터를 미리 저장해둘 이유가 없었다.

---

## info.plist 설정

시뮬레이터에서는 멀쩡했는데, 실기기로 넘어가자마자 Free Flight를 시작하는 순간 바로 팅겼다.

```
Thread 12: abort with payload or reason
RunWay crashed because it attempted to access privacy sensitive data without a usage description.
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/altalert.png){: width="70%" height="70%"}

`AltimeterService.startTracking()`을 다시 보니 원인이 바로 보였다.

```swift
func startTracking() {
    guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
    altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
        guard let self, let data, error == nil else { return }
        self.altitudePublisher.send(data)
    }
}
```

시뮬레이터에는 기압계가 없어서 `isRelativeAltitudeAvailable()`이 항상 `false`를 반환하고, 그래서 `startRelativeAltitudeUpdates(...)` 자체가 한 번도 실제로 호출된 적이 없었다. 실기기는 기압계가 있으니 이 가드를 통과하는데, `CMAltimeter`가 실제로 값을 받기 시작하는 API를 처음 호출하는 순간 iOS가 `Info.plist`에서 `NSMotionUsageDescription`을 찾다가 없으니 바로 앱을 죽여버렸다. Mission Flight든 Free Flight든 러닝을 시작하면 (`prepareTracking()`에서) 이 코드가 똑같이 불리니, 어느 모드로 테스트했어도 똑같이 크래시가 났을 거다.

아이폰 쪽 `Info.plist`엔 그냥 키를 하나 추가하면 됐다.

```
<key>NSMotionUsageDescription</key>
<string>러닝 중 고도 변화를 측정하기 위해 동작 및 피트니스 데이터가 필요합니다.</string>
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/fitness.png){: width="50%" height="50%"}

워치 앱은 `Info.plist` 파일이 따로 없기에, Project Target에서 값을 추가해주었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/watchfitness.png){: width="50%" height="50%"}

시뮬레이터의 하드웨어 가용성 체크가 오히려 이 크래시를 계속 가려주고 있었던 셈이다. 심박 미션 크래시도 그렇고, 이번 것도 그렇고, 실기기에서만 드러나는 종류의 문제는 결국 실기기로 가봐야 안다.

실기기를 테스트 해보니

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/IMG_4101.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/IMG_4102.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/IMG_4103.png){: width="50%" height="50%"}

---

## 고도계는 GPS보다 일찍 켜면 안 된다

크래시를 고치고 실기기로 뛰어보니 값 자체는 잘 나왔다. 루프 코스로 뛰어서 출발점 근처로 돌아오면 스플릿 ALT가 0에 가깝게, 오르막/내리막이 있으면 그만큼 양수/음수로 정확히 나왔다.

그런데 워치로 정지했다가 바로 다시 시작했을 때, 시작하자마자 상대 고도가 -4로 찍혀 있는 걸 봤다. 안 움직였는데 벌써 4m 아래로 내려가 있는 셈이니 이상했다.

원인은 `altimeterService.startTracking()`을 부르는 위치에 있었다. GPS와 똑같이 `prepareTracking()`(테이크오프 화면 진입, 카운트다운 시작 전)에서 미리 불렀었는데, 이게 GPS를 따라 한 결정이었다.

```swift
// Before
func prepareTracking() {
    locationService.startTracking()
    altimeterService.startTracking()
}
```

GPS는 위성 신호를 잡는 데 몇 초씩 걸리니까 카운트다운 전부터 미리 켜두는 게 맞다. 근데 기압계는 그럴 이유가 없다. `CMAltimeter`는 `startRelativeAltitudeUpdates`를 부르는 바로 그 순간을 0으로 잡고 시작하는데, 이걸 카운트다운 시작 전에 미리 불러버리면 그 뒤로 카운트다운 동안 자세를 고치거나 몸을 움직이는 것까지 전부 "0 기준점"에 섞여 들어간다. 그래서 정작 러닝이 시작되는 시점엔 이미 몇 미터 어긋난 채로 시작되는 거였다.

고도계 시작 시점을 `prepareTracking()`에서 `start()`(러닝이 실제로 시작되는 시점)로 옮겼다.

```swift
// After
func prepareTracking() {
    locationService.startTracking()
}

func start() async {
    // 생략
    await runningCenter.reset()
    altimeterService.startTracking()
    // 생략
}
```

GPS는 "미리 켜서 락을 기다린다"가 맞는 전략이고, 기압계는 "러닝이 시작되는 순간 최대한 신선하게 0을 잡는다"가 맞는 전략이다. 같은 "미리 켜두면 좋겠지"라는 생각으로 두 센서를 똑같이 다뤘던 게 문제였다.

---

## 권한 팝업 요청 수정

고치고 나니 이번엔 다른 게 눈에 띄었다. 동작 및 피트니스 권한 팝업이 첫 러닝을 시작하는 순간(`start()`)에 뜬다는 거였다. HealthKit 권한은 온보딩 마지막 페이지에서 이미 미리 받아두고 있는데, 고도계만 러닝 도중 뜬금없이 팝업이 뜨는 셈이었다.

```swift
private func complete() {
    guard hasAgreedToPrivacyPolicy else { return }
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

문제는 `CMAltimeter`가 `CLLocationManager`의 `requestWhenInUseAuthorization()` 같은 별도 권한 요청 API가 없다는 거였다. 실제로 업데이트를 한 번 시작해야만 그 순간 시스템이 팝업을 띄운다. 그렇다고 온보딩 시점에 진짜로 추적을 계속 켜둘 수는 없으니, `AltimeterService`에 시작하자마자 첫 콜백에서 바로 멈추는 함수를 하나 더 만들었다.

```swift
func requestAuthorization() {
    guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
    altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] _, _ in
        self?.altimeter.stopRelativeAltitudeUpdates()
    }
}
```

이건 실제로 추적을 이어가는 게 아니라 권한 팝업만 띄우고 바로 끄는 거라, 앞에서 얘기한 "카운트다운 동안 기준점이 오염되는" 문제와는 무관하다. `OnboardingView.complete()`에서 HealthKit 요청 옆에 이것도 같이 불러주면 끝이다.

```swift
runViewModel.requestAltitudeAuthorization()
```

이제 온보딩이 끝나는 시점에 HealthKit과 고도계 권한 팝업이 같이 뜨고, 러닝 도중에 갑자기 시스템 팝업이 끼어드는 일은 없다.

---

## 고도 지표를 상승고도로 바꾸고 전체 합계도 보여주기

스플릿 ALT 칸을 구간 시작-끝의 차이로 만들어뒀는데, 다시 보니 애매했다. 

언덕 하나를 넘었다가 거의 원위치로 내려온 구간이면 차이는 거의 0으로 나오는데, 실제로는 그 구간에서 꽤 올라갔다 내려온 거라 이 정보가 사라진다. 나이키 런클럽도 이 값을 델타가 아니라 "상승고도(elevation gain)"로 보여주고 있길래, 같은 방식으로 바꿨다.

`RunningCenter.processAltitude()`가 매 샘플마다 스무딩된 고도가 직전 값보다 오른 만큼만 계속 더하고, 내려간 건 무시하게 했다. 리셋 직후 첫 샘플은 기준점일 뿐이라 누적에서 제외했다.

```swift
let wasInitialized = isAltitudeInitialized
if !isAltitudeInitialized {
    smoothingAltitudeFirst = rawAltitude
    smoothingAltitudeSecond = rawAltitude
    isAltitudeInitialized = true
}

let previousAltitude = currentAltitude
smoothingAltitudeFirst = 0.8 * smoothingAltitudeFirst + 0.2 * rawAltitude
smoothingAltitudeSecond = 0.8 * smoothingAltitudeSecond + 0.2 * smoothingAltitudeFirst
currentAltitude = smoothingAltitudeSecond

if wasInitialized {
    let delta = currentAltitude - previousAltitude
    if delta > 0 {
        splitElevationGain += delta
    }
}
```

구간이 끝날 때 이 누적값을 스플릿에 담고 다음 구간을 위해 0으로 리셋한다. 필드 이름도 의미에 맞게 `elevationChange`에서 `elevationGain`으로 바꿨다(`Split`, `SwiftDataSplit`, 워치-아이폰 전송 dict 키까지 전부). 값이 항상 0 이상이라 화면 표시도 "+15"/"0"만 나오면 되게 단순해졌다.

```swift
private var elevationLabel: String {
    let rounded = Int(split.elevationGain.rounded())
    return rounded > 0 ? "+\(rounded)" : "0"
}
```

그런데 정작 요약 화면 위쪽(AVG HR/CADENCE 자리)에는 고도 정보가 하나도 없었다. 스플릿마다 상승고도를 갖고 있으니, 러닝 전체의 총 상승고도는 그걸 다 더하기만 하면 됐다. `SwiftDataFlight`에 별도 필드를 또 만들지는 않았다.

상승고도는 더하기만 하면 되는(additive) 값이라, 구간별로 쌓인 값을 다 더하면 항상 정확히 전체 러닝의 총합이 나온다. 굳이 필드를 하나 더 만들어서 저장해봐야 "스플릿 데이터랑 안 맞으면 어떡하지" 하는 동기화 문제만 늘어날 뿐이다. 반대로 `SwiftDataFlight.heartRate`/`cadence`(평균 심박/케이던스)는 스플릿이 생기기 훨씬 전부터 있던 필드라 `heartRateBuffer`/`cadenceBuffer`로 러닝 전체 샘플을 따로 모아 계산하는 기존 방식을 그대로 쓴다. 평균은 상승고도처럼 단순히 더할 수 있는 값이 아니라서(구간마다 샘플 개수가 다르면 "구간 평균들의 평균"이 "전체 평균"과 어긋날 수 있다), 이쪽은 굳이 건드리지 않았다.

```swift
var totalElevationGain: String {
    guard !splits.isEmpty else { return "--" }
    let total = splits.reduce(0.0) { $0 + $1.elevationGain }
    return "\(Int(total.rounded()))"
}
```

AVG HR/CADENCE 두 칸짜리 그리드를 세 칸으로 늘려서 ELEV GAIN을 나란히 붙였다.

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
    SummaryStatBox(label: "AVG HR", value: avgHeartRate, unit: "bpm", color: .rwRed)
    SummaryStatBox(label: "CADENCE", value: avgCadence, unit: "spm", color: .rwGreen)
    SummaryStatBox(label: "ELEV GAIN", value: totalElevationGain, unit: "m", color: .rwBlue)
}
```

이제 스플릿 한 줄 한 줄에도, 러닝 전체 요약에도 상승고도가 같이 나온다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/patch.png){: width="50%" height="50%"}

---

## 뛰지 않고 걸으면 퍼즈되는 문제

실기기 테스트 중에 뛰다가 잠깐 걸으면 러닝이 자동으로 일시정지되는 걸 봤다. GPS가 끊긴 것도 아닌데 걷기만 해도 퍼즈가 걸리는 게 이상했다.

원인은 GPS 신호 부재를 감지하는 기존 로직에 있었다. `lastReceivedTime`(마지막으로 위치를 받은 시각)을 기준으로, 8초로 바꾸기 전엔 5초 이상 새 위치가 안 들어오면 자동으로 `isPaused = true`가 되는 구조다.

```swift
if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 5 {
    timerCancellable.removeAll()
    isPaused = true
    watchConnectivityService.sendPauseData(isPaused)
}
```

`CLLocationManager`가 `distanceFilter` 단위로만 위치를 주는데(일정 거리 이상 움직여야 새 위치가 들어옴), 뛸 때는 그 거리를 금방 채우지만 걸을 때는 속도가 느려서 같은 거리를 채우는 데 시간이 더 걸린다. GPS가 멀쩡한데도 "느리게 움직여서 업데이트가 뜸해진 것"을 "신호가 끊긴 것"으로 오인하는 셈이었다.

[이전글](https://haroldfromk.github.io/posts/RunningProject-(11)/){:target="_blank"}을 보면 원래 이 로직을 속도(`location.speed`) 기반으로 만들 수도 있었는데, 그때 이미 한 번 검토하고 접은 방향이었다. `guard location.speed > 0`으로 스트림 자체를 막아버리면 걷거나 잠깐 멈출 때 FlightData 스트림이 끊겨서 GPWS가 오작동할 수 있다는 이유였다. 그래서 스트림은 그대로 흘려보내고, 일시정지 판단만 `lastReceivedTime` 타임아웃으로 분리해뒀던 거다.

이번에도 같은 이유로 속도 기반으로 다시 갈아엎진 않았다. 대신 숫자만 조정했다. `distanceFilter`가 5m라고 하면, 걷는 속도(1.2~1.4m/s) 기준으로 5m를 가는 데 3.5~4초가 걸린다. 5초 타임아웃은 이 여유가 너무 빠듯했던 거고, 8초로 늘리면 걷는 속도에 GPS 지연이 조금 더해져도 오작동할 여지가 줄어든다.

```swift
if isRunning && Date().timeIntervalSince(lastReceivedTime) >= 8 {
    timerCancellable.removeAll()
    isPaused = true
    watchConnectivityService.sendPauseData(isPaused)
}
```

물론 진짜로 멈췄을 때 퍼즈 감지가 3초 늦어지는 트레이드오프는 있다. 그래도 뛰다가 걷기만 해도 계속 끊기는 것보단 나은 선택이라고 판단했다.

---

## 평지를 걸어도 상대고도 값이 변하는 문제

평지를 그대로 지나가는데도 ALT 값이 -1, -2로 슬금슬금 내려가는 걸 봤다. 검색해보니 버그가 아니라 기압계 자체의 한계였다.

`CMAltimeter`는 대기압 변화만 보고 고도를 계산한다. 날씨나 바람, 문이 여닫히는 것만으로도 대기압이 미세하게 흔들리는데, 이게 그대로 몇 미터 오차로 나타난다. 지금 쓰는 스무딩은 원래 페이스용으로 만든 거라 이런 흔들림까지는 못 걸러낸다.

실제로 2021년 독일에서 날씨가 갑자기 나빠졌을 때 Apple Watch 고도계가 실제보다 200~300m 높게 표시된 적이 있다. [MacRumors 기사](https://www.macrumors.com/2021/01/07/apple-watch-incorrect-altitude-readings/){:target="_blank"}에 따르면 "날씨 때문에 기압식 고도계 값이 흔들리는 건 정상"이라고 한다. 우리가 겪은 -1, -2m 정도는 이 사례의 훨씬 작은 버전인 셈이다. 가만히 있어도 기압 센서 자체가 20cm 정도씩 흔들린다는 [실측 사례](https://www.devfright.com/how-to-access-the-iphone-barometer-with-cmaltimeter/){:target="_blank"}도 있어서, 센서 자체 흔들림과 날씨 영향이 같이 섞여 들어오는 것으로 보인다.

이걸 완전히 없애려면 손볼 게 많아서 이번엔 그냥 한계로 받아들이기로 했다. ALT 값은 몇 미터 오차가 있을 수 있다는 전제로 참고만 하면 되고, 나중에 필요하면 더 세게 다듬는 정도로 개선할 여지는 남겨뒀다.

---

## 스플릿 목록을 스크롤뷰로 감싸기

스플릿 카드가 그냥 `VStack`으로 한 줄 한 줄 쌓는 구조라, km이 많이 쌓이는 러닝이면 카드가 끝없이 늘어나는 문제가 있었다. 목록만 따로 세로 `ScrollView`로 감싸고 최대 높이를 정해줬다.

```swift
ScrollView(showsIndicators: false) {
    VStack(spacing: 6) {
        ForEach(sortedSplits, id: \.order) { split in
            SplitRow(split: split, color: rowColor(for: split.pace))
        }
    }
}
.frame(maxHeight: 260)
```

그런데 실기기로 10km를 걸어보니 스플릿이 5, 6개까지만 보이고 그 밑으로는 아예 안 내려가지는 문제가 있었다. 원인은 `FlightSummaryView` 전체를 감싸는 바깥쪽 `ScrollView`에 `.scrollDisabled(true)`가 걸려 있던 거였다. 스플릿이 없던 예전엔 화면 전체 내용(지도, 통계, 버튼)이 한 화면에 다 들어가서 스크롤 자체가 필요 없었는데, 스플릿이 길어지면서 화면 전체 높이가 한 화면을 넘는데도 바깥 스크롤이 막혀 있으니 넘친 부분(카드 아랫부분, GO TO DECK 버튼)에 아예 손이 안 닿는 상태였다.

처음엔 그냥 `.scrollDisabled(true)`를 지우려고 했는데, 이게 원래 일부러 걸어둔 거였다. 콘텐츠가 화면에 다 들어가고도 남는 상황에서 스크롤이 살아있으면, 화면을 당길 때 불필요하게 통통 튕기는(bounce) 느낌이 나서 그걸 막으려고 껐던 거였다. 그냥 지워버리면 이 bounce 문제가 다시 돌아온다.

그래서 콘텐츠가 화면을 실제로 넘칠 때만 스크롤을 켜는 쪽으로 갔다. `GeometryReader`로 화면 높이를, `PreferenceKey`로 콘텐츠 실제 높이를 재서 비교한다.

```swift
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@State private var contentHeight: CGFloat = 0

var body: some View {
    ZStack {
        Color.rwBg.ignoresSafeArea()

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
    }
}
```

콘텐츠가 짧으면(스플릿 없거나 몇 개 안 되면) 예전처럼 스크롤이 꺼져서 bounce가 안 생기고, 스플릿이 많아서 화면을 넘치면 자동으로 스크롤이 켜진다.

---

## 최고/최저 색이 BPM/SPM 색이랑 겹치는 문제

실기기 스크린샷을 보다가, 스플릿 헤더의 "최고(초록)/최저(빨강)" 범례랑 BPM(빨강)/SPM(초록) 색이 완전히 겹친다는 걸 발견했다. PACE 칸의 페이스 랭킹(제일 빠른 구간은 초록, 제일 느린 구간은 빨강)을 넣을 때, "초록=좋음/빨강=나쁨"이라는 흔한 관용색만 생각하고 같은 줄에 BPM=빨강/SPM=초록이 고정색으로 이미 자리 잡고 있다는 걸 서로 안 맞춰본 채로 넣어버린 거였다. 의도한 설계가 아니라 그냥 놓친 실수였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splitbefore.png){: width="50%" height="50%"}

처음엔 랭킹 색을 아예 새 색(gold/slate)으로 바꾸는 걸 시도했는데, "새 색을 추가하는 것 자체가 필요한가" 싶어서 다시 생각해보니 더 간단한 방법이 있었다. 색으로 랭킹을 표시하지 않고, 값 옆에 작은 화살표 아이콘만 무채색으로 얹는 것이다.

처음엔 이 아이콘을 순번 배지(km 번호 동그라미)에 얹으려고 했는데, 그러면 "이 km 전체가 최고/최저"라는 뜻이 되어버려서 어색했다. 페이스만 최고인 건지, 심박도 같이 최고인 건지 배지 하나로는 구분이 안 됐다. 그래서 PACE/BPM/SPM 세 칸에 각각 독립적으로 화살표를 붙이는 쪽으로 바꿨다. ALT는 오르막/내리막 자체가 이미 방향 정보라 따로 랭킹을 안 매겼다.

```swift
private func isPaceFastest(_ pace: Double) -> Bool {
    sortedSplits.count >= 2 && pace > 0 && pace == minPace
}
private func isPaceSlowest(_ pace: Double) -> Bool {
    sortedSplits.count >= 2 && pace > 0 && pace == maxPace
}
private func isHeartRateHighest(_ heartRate: Int) -> Bool {
    sortedSplits.count >= 2 && heartRate > 0 && heartRate == maxHeartRate
}
private func isHeartRateLowest(_ heartRate: Int) -> Bool {
    sortedSplits.count >= 2 && heartRate > 0 && heartRate == minHeartRate
}
private func isCadenceHighest(_ cadence: Int) -> Bool {
    sortedSplits.count >= 2 && cadence > 0 && cadence == maxCadence
}
private func isCadenceLowest(_ cadence: Int) -> Bool {
    sortedSplits.count >= 2 && cadence > 0 && cadence == minCadence
}
```

화살표도 처음엔 `chevron.up.circle.fill`처럼 원 배경이 있는 아이콘을 썼는데, 값 옆에 붙이니 원이 하나 더 겹쳐 보여서 답답했다. 그냥 화살표만 남기고 원 배경은 뺐다.

```swift
@ViewBuilder
private func rankIcon(up: Bool) -> some View {
    Image(systemName: up ? "chevron.up" : "chevron.down")
        .font(.system(size: 8, weight: .bold))
        .foregroundColor(.rwMuted)
}
```

```swift
HStack(spacing: 2) {
    if isPaceFastest { rankIcon(up: true) }
    if isPaceSlowest { rankIcon(up: false) }
    Text(split.pace > 0 ? PaceFormatter.format(split.pace) : "--")
        .foregroundColor(.rwAmber)
}
```

PACE/BPM/SPM 텍스트는 이제 랭킹과 무관하게 항상 고정색(amber/빨강/초록)이고, "이 구간이 제일 빠르다/심박이 제일 높다/케이던스가 제일 낮다" 같은 정보는 값 옆의 작은 회색 화살표로만 따로 떼어냈다. 색을 하나도 새로 안 만들어도 되고, 어느 칸을 보든 그 칸 고유색은 항상 같은 뜻이라 헷갈릴 일이 없어졌다.

`sortedSplits.count >= 2` 가드를 넣은 이유는, 스플릿이 딱 하나뿐인 러닝을 실기기로 확인하다가 발견했다. 스플릿이 하나면 그 지표의 최댓값도 최솟값도 자기 자신이라, 자기 혼자 최고이자 동시에 최저가 되어버린다. 비교할 대상이 없는데 화살표를 붙이는 게 의미가 없어서, 스플릿이 2개 이상일 때만 뜨게 막았다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/splitafter.png){: width="50%" height="50%"}

---

## 홈 화면 주간 차트 막대가 카드 밖으로 넘치는 문제

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/chartbefore.png){: width="50%" height="50%"}

실기기로 하루에 10km 넘게 걸었더니, 홈 화면의 WEEKLY FLIGHT HOURS 막대 그래프에서 그날 막대가 카드 위쪽 경계를 뚫고 넘쳐버렸다.

```swift
// Before
.frame(height: max(6, km / 10 * 60))
```

"하루 10km면 60pt"라는 고정 공식이었는데, 이 계산은 요일 라벨 텍스트가 들어갈 공간까지 고려하면 애초에 10km만 돼도 빠듯했다. 그보다 더 뛴 날은 그대로 카드 밖으로 넘칠 수밖에 없는 구조였다.

그 주 실제 최댓값을 기준으로 다시 스케일하도록 고쳤다.

```swift
// After
private var maxWeeklyDistance: Double {
    max(weeklyDistances.max() ?? 0, 1)
}
```

```swift
.frame(height: max(6, km / maxWeeklyDistance * 44))
```

이제 그 주에 제일 많이 뛴 요일이 항상 딱 맞는 높이(44pt)로 채워지고, 나머지 요일은 그에 비례한 높이로 나온다. 하루에 몇 km를 뛰든 카드 밖으로 넘칠 일이 없다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/chartafter.png){: width="50%" height="50%"}

---

## 워치 GPWS 경고 화면에서 배경 길게 누르면 PFD 잠깐 보기

`WatchGPWSView`는 SINK RATE/OVERSPEED 같은 경고가 뜨면 화면 전체를 덮어버린다. 그래서 경고가 떠 있는 동안엔 실제 페이스/거리 같은 숫자를 확인할 방법이 END FLIGHT로 러닝을 끝내는 것 말고는 없었다. 배경을 길게 누르고 있는 동안만 잠깐 실제 PFD 화면이 비쳐 보이고, 손을 떼면 다시 경고로 돌아오는 기능을 추가했다.

`WatchPFDView`의 ZStack 구조를 보면 `WatchGPWSView`는 `TabView`(PFD 화면) 위에 얹히는 오버레이일 뿐이라, PFD 화면은 이미 그 밑에 계속 그려지고 있다. 그래서 `WatchGPWSView` 자신을 투명하게 만들기만 하면 아래 있는 PFD가 그대로 드러난다.

```swift
@State private var isPeeking = false

var body: some View {
    ZStack {
        type.bgColor.ignoresSafeArea()
            .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 50, pressing: { pressing in
                isPeeking = pressing
            }, perform: {})

        VStack(spacing: 8) {
            // 생략
            EndFlightHoldButton(onEndFlight: onEndFlight)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }
    .opacity(isPeeking ? 0 : 1)
    .animation(.easeOut(duration: 0.15), value: isPeeking)
}
```

`WatchGPWSView`엔 이미 러닝 종료용 2초 홀드 버튼(`EndFlightHoldButton`)이 있어서, 새 롱프레스 제스처가 그 버튼이랑 겹치면 안 됐다. 그런데 제스처를 배경(`type.bgColor.ignoresSafeArea()`) 하나에만 걸어두면 따로 영역을 계산할 필요가 없다. SwiftUI가 터치가 들어온 지점의 가장 구체적인 뷰한테 먼저 넘겨주기 때문에, 버튼 위를 누르면 버튼이 받고 그 바깥(배경)을 누르면 이 제스처가 받는다.

`.opacity(...)`는 `ZStack` 전체 바깥에 붙였다. 배경에만 붙이면 텍스트/버튼은 그대로 남아있고 배경만 투명해지는 식이 되어서, 배경과 내용물이 같이 사라지게 하려면 이렇게 바깥에서 한 번에 걸어야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-25-RunningProject-33/gpws.gif)