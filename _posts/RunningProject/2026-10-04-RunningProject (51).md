---
title: RunWay 1.4 (8) 멈춰 있는 동안에도 가고 있던 시계
writer: Harold
date: 2026-10-04 18:00:00 +0900
categories: [RunWay]
tags: [CoreLocation, SwiftUI]

toc: true
toc_sticky: true
published: true
---

고친 빌드를 깔고 짧게 나갔다. 3분쯤 걷고, 중간에 1분 정도 그냥 서 있었다. 거리로는 250m밖에 안 되는 기록이다.

끝내고 요약 화면과 FLIGHT DATA RECORDER를 나란히 봤는데 **두 화면이 서로 다른 시간을 말하고 있었다.**

---

## 3분 러닝인데 4분이라고 나온 기록

![요약 화면의 TIME과 스플릿 페이스, 그리고 FLIGHT DATA RECORDER의 T+ 를 한 화면에 모은 것](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-07-RunningProject-51/runway14_pause_clock.webp)

| 어디 | 값 |
| --- | --- |
| FLIGHT SUMMARY · TIME | 00:03:01 |
| FLIGHT DATA RECORDER · 마지막 T+ | 00:04:00 |

차이가 59초다. 내가 서 있던 그 1분이다. 그동안 앱은 멀쩡히 일시정지 상태였고 화면에도 그렇게 떠 있었다.

시간만 틀린 게 아니었다.

```
요약 평균 페이스   11:58 /km
스플릿 1 페이스    16:00 /km
```

**구간이 하나뿐인 러닝에서 페이스가 두 개 나왔다.** 250m를 한 번 움직인 게 전부인데 그 한 구간의 페이스가 화면마다 다르다.

나눠보면 어디서 갈렸는지 바로 보인다.

```
181초 ÷ 0.252km = 718초 = 11:58   <- 멈춘 시간 뺀 것
240초 ÷ 0.250km = 960초 = 16:00   <- 멈춘 시간 포함한 것
```

---

## 따로 돌던 시계 두 개

러닝 하나에 시간을 재는 자리가 두 군데 있었다.

```swift
// RunViewModel - 1초마다 올리는 타이머. 멈추면 안 센다.
if !isPaused {
    elapsedTime += 1
}
```

```swift
// RunningCenter - GPS 타임스탬프. 멈춰도 계속 간다.
let elapsed = Int(location.timestamp.timeIntervalSince(runStartTime))
```

요약의 TIME과 평균 페이스만 위를 쓴다. **아래를 쓰는 쪽이 훨씬 많았다.** 좌표의 시각, 표본의 시각, 그리고 스플릿 페이스.

아래쪽 코드에 달려 있던 주석이 왜 이렇게 됐는지 그대로 적어두고 있었다.

> 별도 타이머 없이도 ... 정확한 스플릿 시각을 남긴다

1초 타이머는 틱이 밀리면 오차가 쌓인다. 10분 뛰면 몇 초씩 어긋난다. 그게 싫어서 GPS가 찍어주는 시각을 쓰기로 한 거다. 그 판단 자체는 맞다.

**다만 GPS 타임스탬프는 일시정지를 모른다.** 멈춰 서 있어도 위치 갱신은 계속 들어오고, 그때마다 시작 시각과의 차이는 계속 벌어진다. 오차는 피했는데 일시정지도 같이 피해버렸다.

---

## 멈춘 만큼을 빼는 자리

정지 판단은 이미 `RunningCenter`가 하고 있다. 자기가 아는 값이니 자기가 세면 된다.

```swift
if let lastTimestamp = lastLocationTimestamp, isStationary {
    pausedDuration += location.timestamp.timeIntervalSince(lastTimestamp)
}
lastLocationTimestamp = location.timestamp
```

그리고 경과 시간을 물어보는 자리를 한 곳으로 모았다.

```swift
private func movingElapsed(at timestamp: Date) -> Int {
    guard let runStartTime else { return 0 }
    return max(0, Int(timestamp.timeIntervalSince(runStartTime) - pausedDuration))
}
```

좌표, 표본, 스플릿이 전부 이걸 쓴다.

같은 상황을 그대로 돌려봤다. 240초 중 120초부터 179초까지 서 있는 러닝이다.

```swift
import Foundation

let start = Date(timeIntervalSince1970: 0)
let stopFrom = 120.0, stopTo = 179.0
let total = 240.0

var pausedDuration: TimeInterval = 0
var lastTimestamp: Date?

func movingElapsed(at t: Date) -> Int {
    max(0, Int(t.timeIntervalSince(start) - pausedDuration))
}

var wallLast = 0, movingLast = 0
for second in 0...Int(total) {
    let t = start.addingTimeInterval(Double(second))
    let isStationary = Double(second) >= stopFrom && Double(second) < stopTo

    if let last = lastTimestamp, isStationary {
        pausedDuration += t.timeIntervalSince(last)
    }
    lastTimestamp = t

    wallLast = Int(t.timeIntervalSince(start))
    movingLast = movingElapsed(at: t)
}

let distanceKm = 0.25
func pace(_ seconds: Int) -> String {
    let perKm = Double(seconds) / distanceKm
    return String(format: "%d:%02d", Int(perKm) / 60, Int(perKm) % 60)
}

print("멈춘 시간          \(Int(pausedDuration))초")
print("벽시계 경과        \(wallLast)초 -> 페이스 \(pace(wallLast))/km")
print("움직인 시간 경과   \(movingLast)초 -> 페이스 \(pace(movingLast))/km")
```

```
멈춘 시간          59초
벽시계 경과        240초 -> 페이스 16:00/km
움직인 시간 경과   181초 -> 페이스 12:04/km
```

화면에서 본 16:00이 그대로 나온다. 고친 쪽은 12:04인데, 요약의 11:58과 6초 차이는 거리를 0.25km로 반올림해서 쓴 탓이다.

실기기에도 깔고 200m만 걸어봤다. 100m 걷고, 제자리에 1분 서 있고, 다시 100m 걷는 식이다.

![멈춰 있던 구간을 짚은 FLIGHT DATA RECORDER 화면. PACE 가 비어 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-07-RunningProject-51/runway14_pause_fixed.webp)

세로선이 서 있던 구간 한가운데에 있다. PACE 가 `--:--` 이고 줄도 그 자리에서 끊겨 있다. **멈춘 구간이 그래프에서 사라지지는 않았다.**

| | 고치기 전이면 | 실제로 나온 값 |
| --- | --- | --- |
| 요약 TIME | 1:56 | 1:56 |
| 끝 T+ | 2:56 | **1:51** |

1분이 5초로 줄었다. 그 5초는 성격이 다른 값이라 아래에 따로 적었다.

---

## 일부러 벽시계로 남겨둔 한 군데

전부 바꾸면 안 되는 자리가 하나 있었다. 표본을 **얼마나 자주 담을지** 재는 곳이다.

```swift
let wallElapsed = max(0, Int(timestamp.timeIntervalSince(runStartTime)))
if let last = lastSampleElapsedTime, wallElapsed - last < sampleInterval { return }
```

여기까지 움직인 시간으로 바꾸면 멈춰 있는 동안 간격이 안 늘어난다. 5초가 영영 안 지나가니 **표본이 하나도 안 쌓인다.** 그러면 쉰 구간이 그래프에서 통째로 사라진다.

그건 고친 게 아니다. 멈춰 있었다는 사실은 남아야 한다. 지금은 쉰 구간에도 표본이 5초마다 쌓이고, 그 표본들의 페이스가 0이라 **줄 끊김으로 그대로 보인다.** 다만 그 표본들이 달고 있는 시각은 전부 같은 값이다. 멈춰 있었으니 움직인 시간이 안 늘어난 게 맞다.

담는 간격은 실제로 흐른 시간으로, 담은 값의 시각은 움직인 시간으로. 같은 함수 안에서 두 시계를 쓰는 셈이지만 재는 대상이 다르다.

---

## 아직 안 맞는 자리

GPS가 완전히 끊기면 `RunViewModel`이 15초 뒤에 일시정지를 건다. 그동안은 위치 갱신 자체가 안 들어와서 `RunningCenter`는 멈춘 줄 모른다. 신호가 돌아오면 그 공백이 통째로 움직인 시간으로 들어간다.

드물게 생기는 경로라 이번엔 안 건드렸다. 아직 확인 못 했다.

---

## 남겨두기로 한 5초

실기기에서 재보니 TIME 은 1분 56초인데 FDR 의 끝 T+ 는 1분 51초였다. 5초가 비었다.

멈춘 시간과는 상관없는 차이다. 표본을 5초마다 담기 때문이다.

```swift
private let sampleInterval = 5
if let last = lastSampleElapsedTime, wallElapsed - last < sampleInterval { return }
```

러닝은 아무 때나 끝난다. 마지막 표본을 담고 4초 뒤에 종료를 누르면 그 4초는 표본이 없다. **빨리 눌러서가 아니라 언제 눌러도 생기고, 상한이 정확히 5초다.**

없앨 수는 있다. 종료할 때 표본을 하나 더 담으면 된다. 스플릿은 이미 그렇게 한다.

그런데 그 표본에 넣을 값이 없다. 종료 순간에 새로 측정되는 건 없으니 **마지막으로 받은 값을 그대로 복사**해야 한다. 그리고 러닝은 보통 멈춰 서서 끝낸다. 멈춘 자리의 페이스는 튄 값이거나 0이다. **그걸 한 점 더 찍어 넣으면 시계를 맞추려고 그래프를 더럽히는 꼴이다.**

그래서 안 채우고 ⓘ 에 적었다.

```
표본은 5초마다 담아서, 마지막 표본 뒤에 끝낸 몇 초는 안 들어가요.
그래서 맨 오른쪽 T+ 가 요약 화면의 TIME 보다 최대 5초 짧아요.
종료 순간의 값을 지어내서 채우지는 않거든요.
```

숫자를 맞추는 것과 숫자가 뭘 뜻하는지 적어두는 것 중에 뒤를 골랐다. T+ 는 "마지막으로 담은 표본의 시각"이고 TIME 은 "실제로 뛴 시간"이라, 애초에 같은 값이어야 할 이유가 없다.

---

## 선 하나를 설명하는 두 가지 방법

Free Flight 기록에는 PACE 줄에 가로선이 하나 그어진다. 그 러닝에서 실제로 움직인 구간들의 평균 페이스다.

그런데 Mission Flight 의 목표선과 **생김새가 똑같다.** 둘 다 같은 색 실선 한 줄이다. 목표선은 위아래 점선과 옅은 띠가 같이 있어서 구분이 되는데, 평균선은 선 하나뿐이라 뭘 기준으로 그은 선인지 알 방법이 없었다.

선 옆에 작게 `AVG` 라고 적어봤다. 그리고 지웠다.

### 그래프를 가린 글자

처음엔 글자가 그래프에 **덮여서** 안 보였다. 위치 문제가 아니라 그리는 순서 문제였다. 목표 띠를 그리는 함수에 처음부터 이렇게 적혀 있었다.

> 목표 띠를 그린다. 값 선보다 먼저 그려서 값이 위에 오게 한다.

띠는 배경이니까 값 선에 덮이는 게 맞다. 글자를 같은 함수에 넣었으니 글자도 같이 덮였다.

그래서 글자만 떼서 맨 마지막으로 옮기고, 선이 지나가는 자리라 바탕도 깔았다. **이번엔 반대가 됐다.** 글자가 그래프를 가렸다.

### 안 적는 쪽이 나은 이유

줄 하나의 세로 폭이 46에서 90 사이다. 거기에 7pt 글자와 바탕을 얹으면 그 자리의 선은 안 보인다. 선이 어떻게 생겼는지 보려고 들어온 화면에서 선을 가리는 건 **원래 풀려던 문제보다 큰 손해다.**

애초에 이 그림에는 글자를 놓을 빈 자리가 없다. 네 줄이 좁은 높이를 나눠 쓰고 가로는 전부 시간축이라, 어디에 적어도 값 위다.

### 설명이 있어야 할 자리

대신 오른쪽 위 ⓘ 안에 있는 설명을 고쳤다. 원래도 이 선을 설명하고 있었는데 **무슨 모드에서 나오는 선인지를 안 적고 있었다.**

```swift
// 전
"가운데 실선은 움직인 구간의 평균 페이스예요. 멈춰 있던 시간은 빼고 냈어요."

// 후
"목표 없이 뛴 Free Flight라서 가운데 실선이 이 러닝의 평균 페이스예요. 움직인 구간만 모아서 냈고, 멈춰 있던 시간은 빼요."
```

이 설명은 보고 있는 기록에 따라 갈린다. 목표를 정하고 뛴 기록이면 목표선과 허용 오차 설명이 대신 나온다. 그러니까 **지금 이 선이 평균선이라는 건 그 문장이 보인다는 것만으로 이미 정해진다.** 모드 이름을 적어주니 그게 눈에 보이게 됐다.

그림 위에 글자를 얹는 대신 글자가 있어야 할 자리에 적는 쪽으로 갔다. 대신 한 번 눌러야 보인다.

### 말로는 안 그려지던 모양

문구만 고치고 다시 읽어보니 설명이 안 읽혔다. "위아래 점선이 허용 오차고 그 사이가 옅게 칠해져 있어요"를 **글로만 읽고 그 모양을 떠올릴 수 있는 사람은 이미 본 사람뿐이다.**

더 큰 문제가 있다. 이 설명은 보고 있는 기록에 따라 갈린다. Free Flight 기록을 열면 평균선 설명만 나오고 목표 띠 설명은 아예 안 나온다. **기록 하나로는 둘 중 하나만 평생 볼 수 있다.**

그래서 실제 기록에서 PACE 줄을 두 장 잘라서 넣었다.

![Free Flight 의 평균선. 오른쪽에 선이 끊긴 자리가 하나 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-07-RunningProject-51/runway14_lane_free.webp)

실선 하나가 전부다. 글로 "선이 끊긴다"고 적는 것보다 이 한 장이 빠르다.

캡션을 처음엔 "끊긴 자리가 멈춰 서 있던 구간"이라고 적었다가 고쳤다. **이 기록에서는 멈춘 게 아니라 그 사이 속도가 안 들어온 것이었다.** 끊김은 페이스가 기록되지 않았다는 뜻이고, 거기까지가 그림에서 읽을 수 있는 전부다. 어느 쪽인지는 그림이 말해주지 않는다.

둘을 구분해서 적으면 틀린 쪽을 보고도 맞다고 읽게 된다. 그래서 둘 다 적었다.

```
선이 끊긴 자리는 페이스가 기록되지 않은 구간이에요.
멈춰 서 있었거나, 그 사이 속도가 제대로 안 들어온 거예요.
```

![Mission Flight 의 목표 띠. 위로 솟았다 사라지는 자리가 줄 밖으로 나간 값이다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-07-RunningProject-51/runway14_lane_mission.webp)

이쪽은 실선이 목표, 위아래 점선이 허용 오차, 그 사이가 칠해져 있다. 그리고 **위로 솟았다가 사라지는 자리**가 두 군데 보인다. 값이 세로 폭을 벗어나 줄 밖으로 나간 것이다.

이건 지난 글에서 일부러 그렇게 만든 동작이다. 범위 밖 값을 줄 끝에 눌러 붙이면 정상적으로 끝 근처에 있는 값과 모양이 똑같아져서, 한참 벗어난 페이스가 오차선에 걸친 것처럼 보였다. 빠져나가 사라지는 쪽이 "여기서 벗어났다"로 읽힌다.

**그 설명도 글로는 안 읽혔다.** 그림이 들어가니 한 줄로 끝난다.

```swift
private func figure(_ image: String, _ mode: String, _ lines: [LocalizedStringKey]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        // 모드 이름은 앱 안에서도 영문 그대로 쓰므로 번역을 타지 않게 `String`으로 넘긴다.
        Text(mode)
            .font(.orbitron(12, weight: .bold))
            .foregroundColor(.rwGreen)
            .kerning(1)
        Image(image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        // 생략
    }
}
```

설명 그림을 새로 그리지 않고 **내 기록을 그대로 잘라 썼다.** 새로 그리면 실제와 다르게 그릴 위험이 있고, 코드가 바뀌면 그림만 옛날 모양으로 남는다.

---

## 밖에 나가야 아는 것과 안 그래도 되는 것

오늘 고친 두 개가 성격이 완전히 다르다.

멈춘 시간이 안 빠지던 건 **밖에 나가야 알 수 있었다.** 실제로 걷고, 실제로 서 있고, GPS가 그동안 뭘 보내는지 봐야 나온다. 책상에서는 재현할 조건 자체가 없다.

다이얼이 1 작게 나오던 건 아니다. 입력 하나에 출력 하나짜리다.

```swift
Int(439.9999)  // 439
```

이걸 워치 차고 나가서 크라운 돌려보고 사진 찍어서 찾았다.

### 손으로는 못 가는 145번

다이얼은 180초부터 900초까지 5초 간격이다. 고를 수 있는 값이 145개다. 전부 확인하려면 145번 돌려야 한다.

같은 걸 코드로 적으면 이렇다.

```swift
import Testing
@testable import Pace

/// 워치 다이얼은 180초부터 900초까지 5초 간격으로만 고를 수 있다.
/// 고를 수 있는 값 전부가 고른 그대로 보여야 한다.
@Test("다이얼로 고를 수 있는 모든 값이 그대로 표시된다")
func everyDialValueRoundTrips() {
    for totalSeconds in stride(from: 180, through: 900, by: 5) {
        let pace = Double(totalSeconds) / 60.0
        let (m, s) = PaceFormatter.minuteSecond(pace)
        #expect(m * 60 + s == totalSeconds, "\(totalSeconds)초를 골랐는데 \(m)'\(s)\" 로 나왔다")
    }
}
```

고치기 전 코드로 돌려봤다.

```
190초를 골랐는데 3'9
205초를 골랐는데 3'24
220초를 골랐는데 3'39
235초를 골랐는데 3'54
245초를 골랐는데 4'4
260초를 골랐는데 4'19
...
Test run failed after 0.002 seconds with 48 issues.
```

**145개 중 48개가 틀렸다.** 0.002초 걸렸다.

### 왜 이제서야 보였나

저 목록을 보면 답이 있다. 틀리는 건 `190` `205` `220` 이고 `300`(5'00) `420`(7'00) `600`(10'00) 은 멀쩡하다.

**손으로 고를 때는 깔끔한 값을 고른다.** 5분, 7분, 10분. 전부 60으로 나누어떨어지는 값이고 전부 맞게 나온다. 7분 20초를 고른 그날 처음 보인 게 우연이 아니다.

테스트를 덜 해서 늦게 나온 게 아니다. **손으로는 저기까지 못 간다.**

### 넣을 자리와 안 넣을 자리

| | 밖에서만 확인되는 것 | 코드로 확인되는 것 |
| --- | --- | --- |
| | 멈춘 시간이 안 빠짐 | 다이얼 값 왕복 변환 |
| | 걷는 구간 페이스 끊김 | 멈춘 시간 빼는 계산 |
| | 띠가 얇으면 안 보임 | 스플릿 페이스 계산 |
| | 워치 종료 신호 | 좌표 솎아내기 |

왼쪽은 진짜 GPS가 뭘 주는지를 봐야 안다. 오른쪽은 입력과 출력이 전부다.

지금은 둘이 섞여 있어서 **10분 걷고 와서야 `Int()` 버림을 발견한다.** 오른쪽 열을 왼쪽 열 비용으로 치르는 셈이다.

저장소에 자동 테스트가 아직 하나도 없다. 배포가 끝나면 `Shared/` 안의 계산만 보는 테스트 타깃을 붙일 생각이다. GPS나 화면은 넣지 않는다. 거기는 원래 밖에 나가야 하는 자리다.

---

## 정리

| | 전 | 후 |
| --- | --- | --- |
| FDR 마지막 T+ | 04:00 | 03:01 |
| 스플릿 1 페이스 | 16:00 | 12:04 |
| 요약 TIME | 03:01 | 03:01 |

고친 줄은 많지 않은데 **이 버그가 오래 안 보인 이유**는 따로 있는 것 같다. 3km를 쉬지 않고 뛰면 두 시계가 정확히 같은 값을 낸다. 멈춰야만 갈라진다. 그동안 짧게 뛰고 짧게 확인했으니 갈라질 일이 없었다.
