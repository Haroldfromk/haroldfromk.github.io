---
title: RunWay 1.1 (2) - 심박 기반 러닝 모드
writer: Harold
date: 2026-07-18 11:00:00 +0900
categories: [RunWay]
tags: [HealthKit, WatchConnectivity]

toc: true
toc_sticky: true
published: true
---

이번엔 심박 기반 러닝 모드를 넣어보려고 한다.

지금까지 Mission Flight는 페이스 기준으로만 목표를 설정했는데, 지인이 요즘은 페이스 대신 심박수를 기준으로 훈련하는 방식도 많이 쓴다고 추천해줬다. 페이스는 그날 컨디션이나 날씨, 오르막/내리막 같은 지형에 따라 쉽게 흔들리는데, 심박수는 몸이 실제로 받는 부하를 좀 더 직접적으로 보여준다는 이야기였다.

그래서 Mission Flight 안에 페이스 기준 대신 심박수 기준으로 목표를 설정하는 옵션을 추가해보려고 한다.

---

## isPaired vs isReachable

설계를 고민하다 보니 워치 연결 상태를 나타내는 프로퍼티가 하나가 아니라 여러 개라는 걸 알게 됐다. [WCSession Docs](https://developer.apple.com/documentation/watchconnectivity/wcsession){:target="_blank"}를 찾아보니 각각 의미가 달랐다.

- [`isPaired`](https://developer.apple.com/documentation/watchconnectivity/wcsession/ispaired){:target="_blank"}: 이 아이폰에 페어링된 애플 워치가 있는지만 나타내는 단순한 값. 워치가 지금 근처에 있든 없든, 켜져 있든 아니든 상관없이 "이 계정에 워치가 페어링돼 있다"는 사실만 알려준다.

- [`isWatchAppInstalled`](https://developer.apple.com/documentation/watchconnectivity/wcsession/iswatchappinstalled){:target="_blank"}: 페어링된 워치에 RunWay Watch App이 실제로 설치돼 있는지. 유저가 워치에 설치할 앱을 골라서 설치할 수 있기 때문에, 워치가 페어링돼 있다고 해서 이 앱까지 깔려 있다는 보장은 없다. 그래서 엄밀히는 심박 모드 옵션을 노출할 때 `isPaired`뿐 아니라 `isWatchAppInstalled`도 같이 확인하는 게 더 정확하다.

- [`isReachable`](https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable){:target="_blank"}: 이 값이 `true`가 되려면 양쪽 조건이 다 맞아야 한다. 워치 쪽에서는 WatchKit extension이 포그라운드로 돌고 있거나(운동 세션 중처럼 백그라운드에서도 우선순위 높게 실행되는 경우 포함), 아이폰 쪽에서는 페어링된 워치가 통신 범위 안에 있어야 한다. `sendMessage`/`sendMessageData`는 이 값이 `true`일 때만 쓸 수 있는데, 문서에 "Sending messages to a counterpart that is not reachable results in an error."라고 딱 명시돼 있다. 실시간 심박을 `sendMessage`로 보내는 구조인 이상, 이 프로퍼티를 피해갈 방법이 없다는 뜻이다.

세 프로퍼티 다 공통된 조건이 하나 있는데, 문서에 똑같이 반복되는 문구다. 세션의 `activationState`가 `.activated`일 때만 이 값들을 믿을 수 있고, 세션이 비활성화되면 값 자체를 무시해야 한다.

표로 정리하면:

| 프로퍼티 | 의미 | 언제 바뀌나 |
|---|---|---|
| `isPaired` | 워치가 이 아이폰에 페어링돼 있는가 | 거의 안 바뀜 (페어링/해제할 때만) |
| `isWatchAppInstalled` | 페어링된 워치에 앱이 설치돼 있는가 | 앱 설치/삭제할 때만 |
| `isReachable` | 지금 당장 `sendMessage`로 실시간 통신이 가능한가 | 거리/포그라운드 상태에 따라 계속 바뀜 |

지금 앱에는 `isWatchConnected`라는 프로퍼티가 하나 있는데, 이게 `isReachable`을 그대로 감싼 거였다. `TakeoffView`의 사전 점검 화면은 "지금 당장 뛸 수 있는가"를 확인하는 자리라 `isReachable` 그대로 쓰는 게 맞다. 근데 이번에 심박 모드 옵션을 `ModeAView`에 추가하면서 보니, 이건 설정하는 시점과 실제로 뛰는 시점 사이에 간격이 있는 화면이라 계속 흔들리는 `isReachable`보다 `isPaired`(+ `isWatchAppInstalled`)로 옵션 노출 여부를 판단하는 게 더 맞아 보였다. 같은 "워치 연결"이라는 말이어도 화면마다 원하는 값이 달랐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/reachable.png){: width="50%" height="50%"}

---

## ModeAView UI 설계

지금 `ModeAView`는 패널이 네 개다. TARGET PACE, PACE DEVIATION, TARGET DISTANCE, MISSION BRIEF. 이 구조를 그대로 두고 최소한만 바꾸는 쪽으로 정했다.

- 맨 위에 PACE / HEART RATE 세그먼트 토글을 추가한다. `isPaired && isWatchAppInstalled`일 때만 HEART RATE 탭이 활성화되고, 아니면 비활성 처리한다.
- HEART RATE를 고르면 TARGET PACE 패널이 TARGET HEART RATE(bpm 스테퍼)로, PACE DEVIATION이 HEART RATE DEVIATION(±N bpm)으로 바뀐다. 레이아웃/색상은 그대로 두고 라벨과 단위만 바뀌는 정도.
- TARGET DISTANCE는 페이스든 심박이든 상관없는 목표라 그대로 둔다.
- MISSION BRIEF의 Target/Deviation, SINK RATE/OVERSPEED 임계값도 선택한 모드에 맞춰 표시한다.
- `ModeA`에 `mode`(pace/heartRate), `targetHeartRate`, `heartRateDeviation` 필드를 추가한다.

OVERSPEED/SINK RATE 방향은 페이스랑 같은 결로 가기로 했다. 목표보다 심박이 높으면 OVERSPEED(너무 힘들게 뛰는 중), 낮으면 SINK RATE(효과가 부족하게 뛰는 중). 심박이 페이스보다 높다는 건 실제로도 더 빠르게 뛰고 있다는 뜻과 비슷하니 같은 방향이 맞다.

경고가 뜨는 조건도 페이스 GPWS랑 완전히 같게 간다. 오차 범위를 벗어났을 때만 OVERSPEED/SINK RATE, 그 안이면 normal.

하나 더 확인한 게 있는데, 러닝이 끝나갈 때쯤 심박 경고가 계속 울리는 문제는 걱정 안 해도 됐다. `RunningCenter`의 GPWS 판정 코드를 보니

```swift
if totalDistance >= targetDistanceM - 50 && totalDistance < targetDistanceM {
    gpwsStatus = .minimums
} else if isReachedPace {
    gpwsStatus = calculateGPWSStatus(rawPace)
} else {
    gpwsStatus = .normal
}
```

`if/else if` 구조라 목표 거리 50m 전 구간에 들어가면 무조건 `.minimums`가 먼저 찍히고, 페이스 기반 판정은 그 구간이 아닐 때만 돈다. 이미 있는 우선순위 구조라, 심박 버전도 이 순서만 그대로 따라가면 된다.

---

### 모델링 수정

먼저 `ModeA`에 목표 기준을 나타내는 `enum`과 심박 관련 필드를 추가했다.

```swift
enum ModeATarget {
    case pace
    case heartRate
}

struct ModeA {
    var id = UUID()
    var target: ModeATarget = .pace
    var targetPace: Double = 0
    var paceDeviation: Int = 0
    var targetHeartRate: Double = 0
    var heartRateDeviation: Int = 0
    var targetDistance: Double = 0
}
```

그리고 2개의 case를 구분할 target이라는 프로퍼티를 추가하고, 심박 러닝과 관련된 프로퍼티들도 새로 만들어 주었다.

---

### WatchConnectivityService 수정

`WatchConnectivityService`엔 `isPaired`/`isWatchAppInstalled`를 감싼 프로퍼티를 추가했다. `activationState == .activated`일 때만 값을 믿으라는 문서 내용을 그대로 가드로 넣었다.

```swift
var isWatchPaired: Bool {
    session.activationState == .activated && session.isPaired
}

var isWatchAppInstalled: Bool {
    session.activationState == .activated && session.isWatchAppInstalled
}
```

`&&`는 양쪽 다 `true`일 때만 전체가 `true`가 되는 연산자다. `session.isPaired`가 세션 미활성화 상태에서도 알아서 `false`를 주는 게 아니라서, 이렇게 `activationState == .activated` 조건을 앞에 붙여 직접 가드를 걸었다. 

세션이 아직 활성화 안 됐으면 `isPaired`가 뭘 반환하든 상관없이 전체가 `false`로 된다.

---

### RunViewModel 수정

`RunViewModel`엔 이 둘을 합친 프로퍼티를 하나 추가해서 `ModeAView`가 쓰게 했다.

```swift
var isHeartRateModeAvailable: Bool {
    watchConnectivityService.isWatchPaired && watchConnectivityService.isWatchAppInstalled
}
```

---

### ModeAView 수정

`ModeAView` 맨 위에 PACE/HEART RATE 세그먼트 토글을 넣었다. 

`isHeartRateModeAvailable`이 `false`면 HEART RATE 탭이 눌리지 않고 흐리게 표시된다.

```swift
HStack(spacing: 6) {
    ForEach([ModeATarget.pace, .heartRate], id: \.self) { mode in
        let disabled = mode == .heartRate && !runViewModel.isHeartRateModeAvailable
        Button { if !disabled { target = mode } } label: {
            Text(mode == .pace ? "PACE" : "HEART RATE")
                .foregroundColor(disabled ? .rwMuted.opacity(0.4) : (target == mode ? .rwBg : .rwGreen))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(target == mode && !disabled ? Color.rwGreen : Color.rwGreen.opacity(0.1))
                .clipShape(Capsule())
        }
        .disabled(disabled)
    }
}
```

`ForEach([ModeATarget.pace, .heartRate], id: \.self)`처럼 그냥 배열 두 개를 직접 순회하게 했다. `CaseIterable` 붙이고 `allCases`를 쓰는 방법도 있었는데([이전글](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(5)/){:target="_blank"}), 어차피 둘뿐이고 PACE가 항상 왼쪽에 오는 순서도 고정이라 이게 더 단순했다.

`disabled`는 PACE 버튼이면 항상 `false`, HEART RATE 버튼일 때만 `isHeartRateModeAvailable`을 뒤집어서 넣었다. 이 값을 탭 막기, 글자색, `.disabled()` 세 군데에 그대로 재사용했다.

`.disabled(disabled)`만으로도 탭은 막히는데, `Button` 클로저 안에 `if !disabled`를 한 번 더 넣었다. 접근성 기능 같은 걸로 `.disabled()`가 걸린 버튼의 action이 그래도 호출되는 경우가 있다고 해서, 상태 바꾸는 쪽에도 조건을 한 번 더 걸어뒀다.

---

`target`에 따라 TARGET PACE 패널과 TARGET HEART RATE 패널을 통째로 갈아끼운다. bpm 스테퍼만 예로 들면 이렇다.

```swift
if target == .pace {
    // 기존 TARGET PACE 패널
} else {
    // TARGET HEART RATE
    VStack(spacing: 4) {
        Text("TARGET HEART RATE")
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Button { if targetHeartRate < 200 { targetHeartRate += 5 } } label: {
                    Image(systemName: "chevron.up")
                }
                Text("\(targetHeartRate)")
                Button { if targetHeartRate > 100 { targetHeartRate -= 5 } } label: {
                    Image(systemName: "chevron.down")
                }
            }
            Text("bpm")
        }
    }
}
```

패널을 부분적으로 안 섞고 `if/else`로 통째로 바꾼 이유는, 페이스는 분/초 두 칸이고 심박은 한 칸이라 레이아웃 자체가 달라서다. 하나의 뷰 안에 조건부로 여러 개 끼워 넣는 것보다 통째로 나누는 게 더 깔끔했다. bpm은 100~200 사이에서 5씩 증감하게 가드를 걸었다.

---

MISSION BRIEF의 OVERSPEED/SINK RATE도 모드별로 분기했다. 방향은 위에서 정한 대로다.

```swift
if target == .pace {
    // SINK RATE: 목표보다 느림 / OVERSPEED: 목표보다 빠름
} else {
    VStack(spacing: 2) {
        Text("OVERSPEED")
        Text("> \(targetHeartRate + heartRateDeviation)bpm")
        Divider()
        Text("SINK RATE")
        Text("< \(max(0, targetHeartRate - heartRateDeviation))bpm")
    }
}
```

`targetHeartRate + heartRateDeviation`을 넘으면 OVERSPEED, `targetHeartRate - heartRateDeviation` 밑으로 떨어지면 SINK RATE다. `max(0, ...)`는 오차를 목표치보다 크게 잡았을 때 심박수가 음수로 나오는 걸 막으려고 넣었다.

마지막으로 PRE-FLIGHT CHECK를 누를 때 만드는 `ModeA`에도 심박 필드를 같이 채워 넣었다. 어느 모드를 골랐든 페이스/심박 필드를 둘 다 채워서 넘기고, 실제로 판정에 쓰이는 건 `target` 값에 따라 하나뿐이다.

```swift
let modeAData = ModeA(
    target: target,
    targetPace: pace,
    paceDeviation: paceDeviation,
    targetHeartRate: Double(targetHeartRate),
    heartRateDeviation: heartRateDeviation,
    targetDistance: targetDistance
)
runViewModel.getModeData(modeAData)
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/nopair.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/pair.png){: width="50%" height="50%"}

---

## RunningCenter? or HealthCenter?

심박 러닝 관련 로직을 어디에 둘지 두 가지 시나리오를 그려봤다.

**옵션 A: 완전 분리.** 

`HealthCenter`를 만들어서 심박 기반 GPWS를 자기 스트림으로 독립적으로 내보내는 방식. 

근데 MINIMUMS(목표 거리 50m 전)는 거리 기준이라 `RunningCenter`만 알고, `HealthCenter`는 이걸 모른 채로 판정을 내린다. 

그러면 두 스트림을 어딘가(`RunViewModel`)에서 합쳐야 하는데, GPS 업데이트랑 심박 샘플 도착 주기가 안 맞다 보니 결승선 앞에서 MINIMUMS가 떴다가 뒤늦게 도착한 심박 판정이 그걸 덮어써버리는 레이스가 생길 수 있다.

---

**옵션 B: 스무딩만 분리.**

`HealthCenter`는 노이즈 있는 심박 원시값을 스무딩한 값만 들고 있고, 최종 판정(MINIMUMS 포함)은 그대로 `RunningCenter`가 한다. 

스트림을 합칠 필요 없이 `RunningCenter`가 필요할 때 `HealthCenter`의 현재값만 물어보면 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/healthcenter-split-scenarios.png)

대략 이런 모양이 될 것 같다.

```swift
actor HealthCenter {
    private(set) var currentHeartRate: Double = 0

    func processHeartRate(_ raw: Double) {
        currentHeartRate = raw
    }
}
```

원래 페이스처럼 여기도 스무딩을 넣을까 했는데, 코드로 옮기기 전에 심박도 정말 스무딩이 필요한 값인지 AI에게 물어보고 관련 자료를 찾아보라고 시켰다. [Apple Watch 심박 측정 정확도 연구(NCBI)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6444219/){:target="_blank"}랑 [HealthKit 워크아웃 트래킹 자료](https://www.createwithswift.com/tracking-workouts-with-healthkit-in-ios-apps/){:target="_blank"}를 보니, 애플 워치가 이미 자체적으로 노이즈를 걸러서 값을 내려주는 거였다.

논문 원문도 받아서 읽어봤다. 심장 질환이 있는 환자 40명한테 애플워치를 채우고 사이클 에르고미터로 최대 강도까지 운동시키면서, 심전도(ECG) 값이랑 애플워치 심박값을 비교한 연구였다. 

결과가 좀 의외였는데, 안정 상태(HR1)에서의 정확도(ICC 0.729)보다 최대 강도 운동(HR3)에서의 정확도(ICC 0.958)가 오히려 훨씬 높게 나왔다. 오차율(MAPE)도 안정 상태 10.69%에서 최대 강도 6.33%로, 운동 강도가 올라갈수록 더 정확해졌다. Bland-Altman 분석에서도 심박수는 에너지 소비량과 달리 체계적인 편향 없이 좋은 상관관계를 보였다.

즉 뛰는 동안(고강도 운동 중)이 오히려 애플워치 심박 정확도가 가장 좋은 구간이라는 뜻이다. 그래서 스무딩 없이 받은 값을 그대로 쓰기로 했다.

```swift
// RunningCenter
if let modeA = modeAData, modeA.target == .heartRate {
    let hr = await healthCenter.currentHeartRate
    // MINIMUMS 우선순위는 그대로 두고, hr로 OVERSPEED/SINK RATE만 판정
}
```

옵션 B로 정했다. 판정을 한 곳(`RunningCenter`)에서만 하니까 MINIMUMS 우선순위가 그대로 지켜지고, 스트림을 합칠 필요도 없어진다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/center.png){: width="50%" height="50%"}

---

## HealthCenter가 굳이 actor여야 하는걸까?

막상 만들고 보니 `HealthCenter`가 하는 일이 심박값 하나 들고 있다가 내주는 게 전부였다. 

스무딩도 없고, 나중에 케이던스가 추가돼도 심박이랑 서로 계산이 얽히는 것도 아니라서, 이게 굳이 따로 있어야 하는 존재인지 스스로도 헷갈렸다.

근데 이게 actor인 이유는 로직이 복잡해서가 아니라, 데이터가 들어오는 경로 때문이었다. 심박은 `WatchConnectivityService`의 `session(_:didReceiveMessage:)` 콜백으로 들어오는데, 이건 `WCSessionDelegate` 규약상 백그라운드 큐에서 호출된다. `RunningCenter`가 이 값을 안전하게 읽으려면 결국 격리된 저장소가 필요하고, 이건 `RunningCenter` 자체가 애초에 actor인 이유(GPS 업데이트도 백그라운드에서 들어옴)랑 똑같다.

그러니까 `HealthCenter`의 일이 지금 단순해 보여도, "여러 스레드에서 들어오는 헬스 데이터를 안전하게 보관하고 내준다"는 역할 자체는 충분한 존재 이유다. 다만 이 역할이 코드만 봐서는 잘 안 드러나니까, 프로젝트 documents로 명시해두기로 했다.

```swift
/// 백그라운드 스레드로 들어오는 헬스 데이터(심박 등)를 스레드 안전하게 보관하고 노출한다.
///
/// 판정 로직은 없다. `RunningCenter`가 필요할 때 값을 가져가서 판정한다.
actor HealthCenter {
    private(set) var currentHeartRate: Double = 0

    func processHeartRate(_ raw: Double) {
        currentHeartRate = raw
    }
}
```

나중에 심박 말고 다른 건강 데이터(케이던스 등)가 Mission Flight에 추가되더라도, `HealthCenter`엔 딱 그만큼의 프로퍼티와 함수만 늘어난다. 

`currentCadence`, `processCadence(_:)` 하나씩 추가되는 식이다. 판단 로직은 여기 들어오지 않는다 - 그건 언제나 `RunningCenter`의 몫이다.

---

## actor 없이 하면 왜 위험한지

내용을 정리하다보니 처음부터 다시 짚어야 할 것 같았다. 심박이 들어오는 경로는 플랫폼마다 다르다.

- **iOS**: `WatchConnectivityService`의 `didReceiveMessage` 콜백으로 들어온다.
- **Watch**: 워치 자신이 센서를 갖고 있어서, `HealthKitService+watch.swift`의 `updateForStatistics(_:)`가 `HKLiveWorkoutBuilderDelegate`에서 직접 받는다. `WatchConnectivity`를 아예 거치지 않는다.

경로는 다른데, 둘 다 `RunningCenter`(공유 코드) 바깥에서, GPS 처리랑 다른 타이밍에 값을 밀어 넣는다는 공통점이 있다. actor 없이 그냥 값 하나를 공유하면:

```swift
class UnsafeHolder {
    var heartRate: Double = 0
}
let holder = UnsafeHolder()

// 심박이 도착하는 콜백 (백그라운드 스레드)
DispatchQueue.global().async {
    holder.heartRate = 165
}

// RunningCenter가 GPS 처리하면서 동시에 읽는 시점 (다른 스레드)
DispatchQueue.global().async {
    print(holder.heartRate)
}
```

컴파일은 되는데, 두 스레드가 같은 값을 동시에 읽고 쓸 수 있어서 data race다. 

actor로 감싸면:

```swift
actor HealthCenter {
    private(set) var currentHeartRate: Double = 0

    func processHeartRate(_ raw: Double) {
        currentHeartRate = raw
    }
}
```

쓰는 쪽도 읽는 쪽도 `await`를 거쳐야 하고, actor 안에서는 한 번에 하나의 작업만 실행된다는 걸 Swift가 보장해준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/actor-race-timeline.png)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/actor.png){: width="50%" height="50%"}

---

## actor를 사용하는 결론

정리하면, 심박값은 도착하는 즉시 두 곳으로 나뉘어 간다. `HealthCenter`는 iOS/Watch 양쪽 타겟에 다 들어가는 공유 코드라, 이 구조는 두 플랫폼에 똑같이 적용된다.

- **화면 표시용 VM**(iOS는 `RunViewModel`, Watch는 `WatchViewModel`): PFDView/WatchPFDView에 HEART RATE를 찍고, 러닝 후 평균을 내는 데 쓰인다. 여기서 끝난다.
- **`HealthCenter`(actor)**: 판정용. 플랫폼에 상관없이 똑같은 하나의 타입이고, `RunningCenter`가 `await`로 안전하게 읽어가서 GPWS를 판정하는 데만 쓰인다.

같은 값을 두 군데에 나눠 넣는 이유는 단순히 "iOS에서 RunViewModel을 못 봐서"가 아니다. 

`RunningCenter`는 iOS/Watch 양쪽에서 똑같이 동작해야 하는 공유 코드라, 어느 쪽 화면 표시용 VM 타입도 몰라야 한다. 

`HealthCenter`는 그 중립적인 자리이고, 판단 로직 없이 값만 들고 있는다. 오차 범위/OVERSPEED/SINK RATE 판정은 전부 `RunningCenter`가 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/vm-vs-healthcenter.png)

---

## 3초마다만 갱신되는 심박값

근데 하나 더 걸리는 게 있었다. 워치가 심박을 iPhone으로 보내는 주기를 다시 봤다.

```swift
func sendHealthData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    
    let now = Date()
    guard now.timeIntervalSince(lastHealthSentTime) >= 3.0 else { return }
    lastHealthSentTime = now
    // ...
    session.sendMessage(message, replyHandler: nil, errorHandler: nil)
}
```

`HealthKitService.streamHealthData()`가 새 통계를 줄 때마다 이 함수가 불리긴 하는데, 안에서 3초 지나지 않았으면 그냥 리턴해버린다. 즉 iOS 쪽 `HealthCenter.currentHeartRate`는 GPS(대략 1초 간격)보다 훨씬 느리게, 최대 3초 텀으로만 갱신된다. `RunningCenter.processLocation()`은 GPS 들어올 때마다 도니까, 그 사이 2~3번은 같은 심박값을 재사용하게 된다.

근데 이건 걱정 안 해도 될 것 같다. 앞에서 확인했듯 HealthKit 자체도 심박을 5초 간격으로 내려주는 거였다. 3초 relay throttle이 원본 데이터의 자연스러운 갱신 주기보다 오히려 촘촘한 편이라, 추가로 지연이 생기는 느낌은 아니다. 페이스처럼 매 GPS 업데이트마다 반응하는 값이 아니라 몇 초 단위로 갱신되는 값이라는 특성 자체를 그냥 받아들이기로 했다.

---

## RunningCenter 수정

---

### didReceiveMessage 수정

먼저 심박이 들어오는 지점(`WatchConnectivityService+iOS`의 `didReceiveMessage`)에 `HealthCenter`로 보내는 한 줄을 추가한다. 화면용 `RunViewModel` 배선은 그대로 두고 옆에 얹는 것뿐이다.

```swift
// didReceiveMessage
guard let heartRate = message["heartRate"] as? Double, ... else { return }
Task { @MainActor in
    vm?.healthData.heartRate = heartRate
    vm?.healthData.cadence = cadence
    vm?.healthData.activeEnergy = activeEnergy
    vm?.heartRateBuffer.append(heartRate)
    vm?.cadenceBuffer.append(cadence)

    await vm?.healthCenter.processHeartRate(heartRate)  // add
}
```

---

### processLocation 나누기

그런데 이렇게 붙이고 나니 `processLocation` 하나가 하는 일이 너무 많아졌다. 

위치가 들어올 때마다 거리를 누적하고 페이스를 스무딩하는 함수인데, 거기에 페이스/심박 두 갈래짜리 GPWS 판정 분기까지 얹혀있으니 이름은 위치 처리인데 실제로는 심박까지 들여다보는 함수가 돼버렸다. GPWS 판정 부분만 따로 빼기로 했다.

```swift
private func determineGPWSStatus(pace: Double) async -> GPWSState {
    guard let modeA = modeAData else { return .normal }

    let targetDistanceM = modeA.targetDistance * 1000
    if totalDistance >= targetDistanceM - 50 && totalDistance < targetDistanceM {
        return .minimums
    }

    switch modeA.target {
    case .pace:
        guard isReachedPace else { return .normal }
        return calculateGPWSStatus(pace)
    case .heartRate:
        let heartRate = await healthCenter.currentHeartRate
        return calculateHeartRateGPWSStatus(heartRate)
    }
}
```

분기는 `modeA.target`으로 나눴다. `.pace` 케이스는 원래 있던 `isReachedPace` 가드를 그대로 가져왔다. 한 번이라도 오차 범위 안에 들어온 적이 있어야 판정을 시작하는 조건인데, 심박에는 이런 진입 조건을 딱히 둘 이유가 없어서 `.heartRate` 케이스는 가드 없이 바로 `healthCenter.currentHeartRate`를 가져와서 넘긴다.

`processLocation` 쪽은 이 한 줄만 남는다.

```swift
gpwsStatus = await determineGPWSStatus(pace: rawPace)
```

MINIMUMS 체크를 이쪽으로 모으면서 하나 알게 된 게 있다. 기존 `calculateGPWSStatus(_:)` 안에도 똑같은 MINIMUMS 체크가 한 번 더 들어있었다. `determineGPWSStatus`가 먼저 걸러주니 `calculateGPWSStatus`까지 내려왔을 땐 이미 MINIMUMS 구간이 아닌 게 보장되는데, 그 안쪽 체크는 사실상 실행될 일이 없는 코드였던 거다.

```swift
// before
private func calculateGPWSStatus(_ pace: Double) -> GPWSState {
    guard let modeA = modeAData else { return .normal }
    
    let targetDistanceM = modeA.targetDistance * 1000
    if totalDistance >= targetDistanceM - 50 && totalDistance < targetDistanceM {
        return .minimums
    }
    
    let deviation = Double(modeA.paceDeviation) / 60.0
    
    switch pace {
    case ..<(modeA.targetPace - deviation):
        return .overspeed
    case (modeA.targetPace + deviation)...:
        return .sinkRate
    default:
        return .normal
    }
}

// after
private func calculateGPWSStatus(_ pace: Double) -> GPWSState {
    guard let modeA = modeAData else { return .normal }
    let deviation = Double(modeA.paceDeviation) / 60.0

    switch pace {
    case ..<(modeA.targetPace - deviation):
        return .overspeed
    case (modeA.targetPace + deviation)...:
        return .sinkRate
    default:
        return .normal
    }
}
```

`calculateHeartRateGPWSStatus`는 그대로 둔다.

```swift
/// 현재 심박수를 기반으로 GPWS 상태를 계산한다.
///
/// - OVERSPEED: 목표 심박보다 높음 (너무 힘들게 뛰는 중)
/// - SINK RATE: 목표 심박보다 낮음 (효과 부족)
private func calculateHeartRateGPWSStatus(_ heartRate: Double) -> GPWSState {
    guard let modeA = modeAData else { return .normal }
    let deviation = Double(modeA.heartRateDeviation)

    switch heartRate {
    case (modeA.targetHeartRate + deviation)...:
        return .overspeed
    case ..<(modeA.targetHeartRate - deviation):
        return .sinkRate
    default:
        return .normal
    }
}
```

`switch` 케이스 순서가 페이스 버전이랑 반대인 이유는, 페이스는 숫자가 작을수록 빠른 거라 `..<(target-deviation)`이 OVERSPEED였는데, 심박은 숫자가 클수록 힘든 거라 `(target+deviation)...`이 OVERSPEED로 뒤바뀌기 때문이다.

---

### HealthCenter를 init으로 전달

여기까지 나누고 AI에게 지금까지 내용을 진단해달라고 했다. AI가 짚어준 부분이 하나 있었는데, `determineGPWSStatus`에서 `healthCenter.currentHeartRate`를 읽으려면 `RunningCenter`가 `HealthCenter` 인스턴스를 갖고 있어야 하는데, 지금까지 `RunViewModel`은 `runningCenter`랑 `healthCenter`를 각자 따로 들고 있었을 뿐 둘 사이에 연결이 없었다는 거였다. `RunningCenter`에 생성자를 추가해서 밖에서 넣어주는 방식으로 바꾸라는 조언을 받아들였다.

```swift
private let healthCenter: HealthCenter

init(healthCenter: HealthCenter = HealthCenter()) {
    self.healthCenter = healthCenter
}
```

`RunViewModel`은 자기가 들고 있는 `healthCenter`를 그대로 넘겨서 `runningCenter`를 만든다.

사실 처음엔 `runningCenter`도 `healthCenter`처럼 그냥 선언 줄에 기본값을 넣으려고 했다.

```swift
private var runningCenter = RunningCenter(healthCenter: healthCenter)
var healthCenter = HealthCenter()
```

근데 컴파일이 안 됐다. 스위프트에서는 저장 프로퍼티의 기본값이 `self`가 다 갖춰지기도 전에, 그러니까 다른 프로퍼티보다 먼저 적용된다. 그 시점엔 `healthCenter`가 준비돼 있다는 보장이 없어서, 같은 자리에서 다른 프로퍼티를 끌어다 쓰는 걸 막아둔 거였다. 선언 순서를 바꿔서 `healthCenter`를 위로 올려도 안 됐다. 소스 코드에서 몇 번째 줄에 있느냐가 아니라, 어느 단계에서 실행되느냐의 문제였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/init-timing.png)

그래서 `runningCenter`는 선언 줄에서 타입만 적어두고, 값을 채우는 건 `init()` 본문으로 옮겼다. `init()` 본문이 실행되는 시점엔 `healthCenter`가 이미 자기 기본값으로 채워진 뒤라, 여기서는 갖다 써도 문제가 없다.

```swift
@ObservationIgnored private var runningCenter: RunningCenter
@ObservationIgnored var healthCenter = HealthCenter()

init() {
    runningCenter = RunningCenter(healthCenter: healthCenter)
    ...
}
```

AI가 설명해준 내용을 그림으로 정리하면 이렇다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/healthcenter-init.png)

`init`으로 넘기지 않고 그냥 `RunningCenter()`라고만 썼다면, `healthCenter` 매개변수는 기본값(`= HealthCenter()`)을 타면서 빈 인스턴스를 하나 더 만들어버렸을 거다. 이름은 똑같이 `healthCenter`라서 코드만 보면 헷갈리기 쉬운데, 실제로는 서로 다른 두 객체다. 하나는 심박이 실제로 들어오는 쪽이고, 하나는 `RunningCenter`가 판정할 때 들여다보는 쪽인데, 이 둘이 남남이면 `RunningCenter`는 영원히 0만 보게 되고 심박 GPWS는 계속 SINK RATE로만 뜬다. `RunViewModel`이 만들어질 때 자기 `healthCenter`를 `RunningCenter`한테 그대로 넘겨서, 쓰는 쪽과 읽는 쪽이 같은 인스턴스 하나를 보게 만든 거다.

기본값을 남겨둔 이유는 이 시점엔 아직 워치 쪽에 이 배선이 없었기 때문이다. `healthCenter`를 필수 인자로 만들면 그 순간 워치 빌드가 깨진다. 일단은 빈 `HealthCenter`를 기본값으로 받게 해서 컴파일만 되게 해뒀고, 워치 쪽 연결은 뒤에서 마저 다룬다.

---

### 싱글턴 대신 생성자 주입을 고른 이유

이 부분도 AI한테 한 번 더 물어봤다. `init`으로 넘기는 대신 `HealthCenter`를 그냥 싱글턴으로 만들면 안 됐는지.

actor도 싱글턴이 된다고 했다. 이 프로젝트에 이미 있는 `HealthKitService.shared`랑 똑같은 패턴을 그대로 쓰면 된다는 거였다.

```swift
actor HealthCenter {
    static let shared = HealthCenter()
    private init() {}
    ...
}
```

싱글턴이었으면 애초에 `RunningCenter`가 `healthCenter`를 따로 들고 있을 필요도 없었다. 아무 데서나 `HealthCenter.shared.currentHeartRate`라고 부르면 되니까, 앞서 그림으로 그렸던 "인스턴스가 둘로 나뉘는" 상황 자체가 생길 수가 없다.

나쁘지 않은 대안이었다. 근데 지금 하고 있는, 만들 때 넘겨주는 방식도 결국 의존성 주입이라는 이름이 붙은 패턴 중 하나고, 실제로 많이 쓰인다고 했다. 

다만 나는 이 방식을 그동안 별로 안 써봐서 낯설었다. 싱글턴은 그냥 `.shared`라고 쓰면 끝인데, 이건 왜 굳이 `init`에 매개변수를 넣고 밖에서 넘겨주는 절차를 거치는지 감이 잘 안 왔다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/singleton-vs-injection.png)

싱글턴은 코드 어디서든 이름만 알면 접근이 된다. 반대로 지금 방식은, `RunViewModel`이 `RunningCenter(healthCenter:)`를 호출하면서 직접 건네준 경우에만 `RunningCenter`가 `healthCenter`를 갖게 된다. 그 경로 말고는 접근할 방법이 없고, 그 관계 자체가 `init` 매개변수에 그대로 드러난다.

이 프로젝트에서 실제로 어디까지가 어떤 방식인지도 짚어봤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/environment-boundary.png)

`@Environment`는 `RunViewModel`/`WatchViewModel`을 화면에 넘기는 딱 한 층만 담당한다. 그 밑에서 `runningCenter`, `healthCenter`, `HealthKitService`, `watchConnectivityService`가 서로 연결되는 건 전부 뷰모델 `init()` 안에서 손으로 짜는 영역이다. 그중에서도 `HealthKitService`만 예외적으로 `.shared` 싱글턴이고, 나머지는 다 뷰모델이 만들 때 직접 넘겨주는 방식이다. `RunningCenter` 자체도 뷰모델마다 따로 만들어지는 애라서, `HealthCenter`만 전역으로 튀는 것보다는 지금처럼 넘겨주는 쪽이 이 층의 기존 모양이랑 더 잘 맞았다.

<iframe 
  src="/assets/demo/swift_dependency_simulator.html" 
  width="100%" 
  height="950px" 
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);" 
  scrolling="no" 
  loading="lazy"
></iframe>

---

## 워치 쪽도 실제로 연결하기

미뤄뒀던 워치 쪽을 연결할 차례다. `HealthCenter`는 처음 설계할 때부터 iOS/watchOS 양쪽이 같이 쓰는 걸 염두에 두고 만든 타입이라, 워치도 똑같은 패턴을 한 번 더 적용하면 된다. 다만 워치는 미션 설정 자체를 폰 없이 워치만으로도 끝낼 수 있는 독자적인 화면 흐름을 갖고 있어서, 그쪽도 같이 손봐야 했다.

---

### HealthCenter 연결

`WatchViewModel`도 `RunViewModel`과 똑같은 구조로 맞췄다. `healthCenter`를 들고, `runningCenter`를 만들 때 그걸 넘긴다. 이걸 빼먹으면 앞서 본 것과 똑같은 문제가 워치에서도 그대로 재현된다. `runningCenter`가 `RunningCenter()`의 기본값을 타면서 아무도 채워주지 않는 빈 `healthCenter`를 혼자 들게 되고, 워치에서 심박 미션을 켜도 GPWS 판정은 계속 0을 기준으로 돌아간다.

```swift
@ObservationIgnored private var runningCenter: RunningCenter
@ObservationIgnored var healthCenter = HealthCenter()

init() {
    runningCenter = RunningCenter(healthCenter: healthCenter)
    ...
}
```

`processHeartRate`를 호출하는 지점은 iOS와 다르다. iOS는 워치가 보낸 메시지를 받는 지점(`didReceiveMessage`)에서 호출했는데, 워치는 애초에 그 메시지를 받는 쪽이 아니라 보내는 쪽이다. 워치에서 심박이 실제로 들어오는 지점은 `HealthKitService.shared.streamHealthData()`를 구독하는 `startStream()`이라, 거기에 한 줄을 추가했다.

```swift
Task {
    for await data in HealthKitService.shared.streamHealthData() {
        self.healthData = data
        watchConnectivityService.sendHealthData()
        await healthCenter.processHeartRate(data.heartRate)  // add
    }
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watch-ios-dual-write.png)

두 플랫폼이 심박을 받는 경로 자체는 다르지만(iOS는 워치가 보낸 메시지, 워치는 HealthKit 직접), 받은 다음 화면용과 판정용 두 군데로 나눠 보내는 모양은 똑같다. `HealthCenter`가 두 기기에 동시에 떠 있는 하나의 객체는 아니고, 각자 자기 프로세스 안에서 따로 갖고 있는 별개의 인스턴스라는 점은 짚어둘 만하다. 같은 타입을 양쪽이 각자 한 번씩 쓰는 것뿐이다.

---

### 워치 단독 미션 설정 화면

워치에는 원래 폰 없이도 Mission Flight를 시작할 수 있는 자체 설정 흐름이 있었다. 거리 프리셋을 고르거나 CUSTOM으로 직접 입력하면, 곧바로 페이스 설정 화면으로 넘어가는 식이었다. 여기에 페이스/심박 중 뭘 기준으로 할지 고르는 단계를 끼워 넣어야 했다.

거리를 고르는 두 진입점(`WatchMissionListView`의 프리셋 버튼, `WatchDistanceSettingView`의 NEXT 버튼) 모두 원래는 `.paceSetting(preset:)`으로 바로 넘어갔다. 이걸 새로 만든 `.targetSelection(preset:)`으로 바꿨다.

```swift
// WatchMissionListView, 프리셋 버튼
if preset.distance == 0 {
    viewModel.navigateTo(.distanceSetting)
} else {
    viewModel.navigateTo(.targetSelection(preset: preset))  // 기존엔 .paceSetting(preset: preset)
}
```

```swift
// WatchDistanceSettingView, NEXT 버튼
viewModel.navigateTo(.targetSelection(preset: MissionPreset(
    label: "CUSTOM",
    distance: distance,
    icon: "slider.horizontal.3"
)))
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watch-mission-flow.png)

거리를 정하고 나면 `WatchTargetSelectionView`가 새로 끼어든다. PACE / HEART RATE 두 버튼뿐인 화면이라 코드도 단순하다.

```swift
Button {
    viewModel.navigateTo(.paceSetting(preset: preset))
} label: {
    // "PACE"
}

Button {
    viewModel.navigateTo(.heartRateSetting(preset: preset))
} label: {
    // "HEART RATE"
}
```

PACE를 고르면 원래 있던 흐름(`WatchPaceSettingView` → `WatchPaceDeviationView`) 그대로 가고, HEART RATE를 고르면 새로 만든 `WatchHeartRateSettingView` → `WatchHeartRateDeviationView`로 간다. 두 화면은 크라운으로 값을 조절하는 방식까지 페이스 쪽이랑 똑같이 만들었다. 목표 심박은 100~200bpm을 5bpm 단위로, 허용 오차는 5~30bpm을 5bpm 단위로 돌린다.

화면이 두 개 늘었으니 `WatchDestination`을 실제 화면으로 연결하는 라우터(`WatchHomeView`의 `navigationDestination`)에도 케이스를 추가했다.

```swift
case .targetSelection(let preset):
    WatchTargetSelectionView(preset: preset)
...
case .heartRateSetting(let preset):
    WatchHeartRateSettingView(preset: preset)
case .heartRateDeviation(let preset, let heartRate):
    WatchHeartRateDeviationView(preset: preset, heartRate: heartRate)
```

허용 오차까지 정하고 나면 `WatchHeartRateDeviationView`가 그 값들로 `ModeA`를 만든다.

```swift
Button {
    let modeAData = ModeA(target: .heartRate, targetHeartRate: Double(heartRate), heartRateDeviation: Int(deviation), targetDistance: preset.distance)
    viewModel.getModeData(modeAData)
    viewModel.navigateTo(.missionSummary)
} label: {
    Text("NEXT")
    ...
}
```

여기서 하나 정리한 것도 있다. `WatchDestination.missionSummary`가 원래 `preset`, `paceSeconds`, `deviation` 세 개를 들고 다녔는데, 정작 `WatchMissionSummaryView`는 그 값들을 하나도 안 쓰고 `viewModel.modeAData`만 직접 읽고 있었다. 심박 경로를 추가하면서 이 케이스를 어차피 다 손대야 했던 김에, 안 쓰는 값들을 걷어내고 `case missionSummary`로 단순하게 바꿨다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watchtarget.png){: width="50%" height="50%"}

---

### 미션 요약 화면 분기

`WatchMissionSummaryView`도 `modeAData.target`을 보고 표시를 바꾼다.

```swift
var isHeartRateTarget: Bool { viewModel.modeAData?.target == .heartRate }

...

if isHeartRateTarget {
    SummaryRow(icon: "heart.fill", label: "TARGET HEART RATE", value: heartRateString, color: .rwGreen)
} else {
    SummaryRow(icon: "target", label: "TARGET PACE", value: paceString, color: .rwGreen)
}
```

---

### 워치 ↔ 아이폰 동기화

워치에서 미션을 시작하면 같은 설정을 아이폰에도 보낸다(`sendModeData`). 반대쪽 `didReceiveMessage`는 그 메시지를 받아서 다시 `ModeA`로 조립한다. 둘 다 필드를 하나하나 꺼내 쓰는 구조라서, 심박 관련 필드를 양쪽에 다 추가해줘야 했다. `ModeATarget`은 문자열로 실어 보내기 편하게 `String` raw value를 붙였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-18-RunningProject-30/watch-modea-sync.png)

```swift
// watchOS, sendModeData
let message: [String: Any] = [
    "type": "modeData",
    "target": modeA.target.rawValue,
    "targetPace": modeA.targetPace,
    "paceDeviation": modeA.paceDeviation,
    "targetHeartRate": modeA.targetHeartRate,
    "heartRateDeviation": modeA.heartRateDeviation,
    "targetDistance": modeA.targetDistance
]
```

```swift
// iOS, didReceiveMessage
let target = ModeATarget(rawValue: message["target"] as? String ?? "") ?? .pace
let targetHeartRate = message["targetHeartRate"] as? Double ?? 0
let heartRateDeviation = message["heartRateDeviation"] as? Int ?? 0
let modeA = ModeA(target: target, targetPace: targetPace, paceDeviation: paceDeviation, targetHeartRate: targetHeartRate, heartRateDeviation: heartRateDeviation, targetDistance: targetDistance)
```

이렇게 해서 워치 단독으로 심박 미션을 시작해도, 근처에 아이폰이 있으면 똑같은 설정으로 미러링된다.

---

## PFD 화면도 분기해야 했다

여기까지 하고 나서 짚어봤는데, 설정(`ModeAView`, 워치 미션 설정 화면)이랑 판정(`RunningCenter`)은 심박 모드가 다 들어갔는데 정작 뛰는 도중에 보는 화면은 그대로였다. 심박 미션으로 시작해도 화면엔 여전히 TARGET PACE만 떠 있었던 거다.

### iOS: MissionHUDBar 분기

`PFDView`의 `MissionHUDBar`가 `targetPace`만 받고 있었다. `target`, `heartRate`, `targetHeartRate`를 추가로 받게 하고, 편차 계산이랑 색깔 기준부터 갈랐다.

```swift
private var deviation: Double {
    target == .pace ? pace - targetPace : heartRate - targetHeartRate
}

private var devColor: Color {
    let (redThreshold, amberThreshold): (Double, Double) = target == .pace ? (30, 10) : (15, 5)
    if abs(deviation) > redThreshold { return .rwRed }
    if abs(deviation) > amberThreshold { return .rwAmber }
    return .rwGreen
}
```

페이스 쪽 30초/10초 기준을 심박에도 그대로 쓰진 않았다. 초 단위 숫자랑 bpm 숫자를 같은 30/10으로 비교하는 게 말이 안 돼서, 심박 스케일(15bpm/5bpm)로 따로 뒀다.

TARGET 패널도 라벨과 단위를 통째로 갈아끼웠다.

```swift
Text(target == .pace ? "TARGET PACE" : "TARGET HEART RATE")

if target == .pace {
    Text(PaceFormatter.format(targetPace))
    Text("/km")
} else {
    Text("\(Int(targetHeartRate))")
    Text("bpm")
}
```

---

### 워치: GPWS 오버레이 단위 분기

워치 쪽은 두 군데 더 있었다. `gpwsDeviation`이 `targetPace`만 보고 있던 것부터 갈랐다.

```swift
var gpwsDeviation: Int {
    guard let modeA = viewModel.modeAData else { return 0 }
    switch modeA.target {
    case .pace:
        return abs(Int(viewModel.flightData.pace - modeA.targetPace))
    case .heartRate:
        return abs(Int(viewModel.healthData.heartRate - modeA.targetHeartRate))
    }
}
```

그리고 `WatchGPWSView`가 편차를 표시할 때 단위를 `"sec"`로 하드코딩하고 있었다. 심박 모드에서 SINK RATE가 뜨면 "+18 sec"라고 나왔을 텐데, 실제로는 bpm 차이인데 초 단위인 것처럼 보였을 거다.

```swift
var deviationUnit: String = "sec"

var detailText: String {
    switch type {
    case .sinkRate:  return "+\(deviation) \(deviationUnit)"
    case .overspeed: return "\(deviation) \(deviationUnit)"
    case .minimums:  return ""
    }
}
```

`WatchPFDView`에서 심박 모드일 땐 `"bpm"`을 넘겨준다.

```swift
var gpwsDeviationUnit: String {
    viewModel.modeAData?.target == .heartRate ? "bpm" : "sec"
}
```

전체 계기판 탭의 STATUS 칸도 항상 "PACE"로 고정돼 있던 걸, 실제 미션 기준에 맞게 바꿨다.

```swift
Text(missionTarget == .heartRate ? "HEART RATE" : "PACE")
```

---

### Live Activity 수정

지난번엔 `targetPace` 필드 하나만 보고 "여기도 안 맞을 거다"라고 넘겼는데, 막상 위젯 코드(`DynamicIslandWidget.swift`)를 열어보니 그 짐작이 틀렸다. `targetPace`는 애초에 위젯 어디에도 표시되고 있지 않았다. cruise 단계에서 실제로 보여주는 건 항상 "지금" 값(현재 페이스, 현재 심박)이지 목표값이 아니었다.

진짜 문제는 다른 데 있었다. Expanded 영역에서 왼쪽(leading)엔 항상 PACE가, 오른쪽(trailing)엔 항상 HR이 고정돼 있었다. 심박 미션으로 뛰어도 왼쪽엔 여전히 페이스가 크게 뜨고, 정작 목표로 삼은 심박은 오른쪽 보조 자리에만 있었던 거다.

`FlightActivityAttributes`에 목표 기준을 담을 자리가 없어서, 고정 필드로 하나 추가했다.

```swift
var target: ModeATarget

init(missionName: String, targetPace: String, target: ModeATarget = .pace) {
    self.missionName = missionName
    self.targetPace = targetPace
    self.target = target
}
```

`startActivity`를 호출하는 두 지점(`TakeoffView`, `RunViewModel`)에서 `modeAData?.target`을 같이 넘겨주게 했다.

```swift
let target = runViewModel.modeAData?.target ?? .pace
await runViewModel.flightActivityService.startActivity(missionName: missionName, targetPace: targetPace, target: target)
```

그리고 위젯의 leading/trailing을 목표 기준에 맞춰 스왑했다. 심박 미션이면 왼쪽에 HR이 크게, 오른쪽에 페이스가 보조로. 페이스 미션이면 그대로 둔다.

```swift
// ExpandedLeadingView, cruise
if context.attributes.target == .heartRate {
    // HR 크게
} else {
    // PACE 크게 (기존)
}
```

```swift
// ExpandedTrailingView, cruise
if context.attributes.target == .heartRate {
    // PACE 보조
} else {
    // HR 보조 (기존)
}
```

GPWS 경고(SINK RATE/OVERSPEED) 표시는 손대지 않았다. `gpwsState`가 이미 페이스/심박 어느 쪽이든 `RunningCenter`가 판정해서 넘겨주는 값이라, 위젯은 그 결과만 그대로 보여주면 됐다.

---

## 경고 기록도 심박을 몰랐다

시뮬레이터로 확인하다가 다른 데를 하나 더 놓쳤다는 걸 알았다. `AlertsView`(경고 목록)랑 `FlightSummaryView` 경로 지도의 경고 마커, 둘 다 `SwiftDataAlert.pace`만 보고 있었다. 심박 미션 중에 SINK RATE/OVERSPEED가 떠서 저장돼도, 화면엔 그 순간의 페이스 숫자가 표시됐다. 왜 경고가 떴는지랑 화면에 뜨는 숫자가 아예 다른 얘기였던 거다.

---

### SwiftDataAlert에 필드 추가

`gpwsState`, `pace`만 있던 모델에 `target`(어떤 기준으로 판정된 경고인지)이랑 `heartRate`를 추가했다.

```swift
var target: String
var heartRate: Double
```

경고를 만드는 세 군데, `PFDView`, `WatchPFDView`, 워치가 보낸 데이터를 받는 `WatchConnectivityService+iOS`, 다 이 두 값을 채워 넣게 고쳤다. 워치가 아이폰으로 러닝 기록을 넘길 때(`sendRunningData`)도 `alerts` 배열 안에 `target`/`heartRate`를 실어 보내야 해서, 보내는 쪽/받는 쪽 딕셔너리 키도 같이 맞췄다.

---

### 화면 두 군데 분기

`AlertsView`의 경고 행이랑 `FlightSummaryView` 지도의 경고 마커 callout, 둘 다 `target`을 보고 페이스/심박 중 하나를 고르게 했다.

```swift
if isHeartRateAlert {
    Text("\(Int(alert.heartRate))")
    Text("bpm")
} else {
    Text(PaceFormatter.format(alert.pace))
    Text("/km")
}
```

지도 쪽은 SINK RATE/OVERSPEED 두 케이스가 완전히 똑같은 callout 텍스트 생성 코드를 갖고 있길래, 이 김에 `calloutText(for:)` 하나로 묶었다.

---

## GPWS가 계속 normal로만 뜨는 진짜 원인

지금까지 심박 쪽만 들여다보고 있었는데, 시뮬레이터를 통해 간단하게 테스트를 해보니 심박 러닝에 관해 gpws가 작동하지 않았다.

그래서 문제를 확인해서 관련 부분을 수정해보려 한다.

`determineGPWSStatus`는 맨 처음에 `modeAData`가 없으면 무조건 `.normal`을 반환한다.

```swift
private func determineGPWSStatus(pace: Double) async -> GPWSState {
    guard let modeA = modeAData else { return .normal }
    ...
}
```

`modeAData`는 `ModeAView`에서 PRE-FLIGHT CHECK를 누를 때 `getModeData()`로 `RunningCenter`에 설정된다. 문제는 그 다음이었다. 러닝을 시작하는 `start()`가 방어적으로 `runningCenter.reset()`을 부르는데, 이 `reset()` 안에 `modeAData = nil`이 같이 들어있었다.

순서를 그려보면 이렇다.

1. `ModeAView`에서 PRE-FLIGHT CHECK → `getModeData()` → `modeAData` 설정됨
2. TakeoffView → ROTATE → `start()` → `reset()` → `modeAData`가 다시 nil로
3. PFDView 진입, GPS가 들어오기 시작 → `determineGPWSStatus`는 매번 `modeAData`가 없어서 `.normal`만 반환

미션을 설정한 직후에 러닝이 시작되면서, 방금 설정한 그 미션 데이터를 자기가 지워버리는 구조였다. `reset()`은 러닝 시작 전(`start()`)과 러닝 종료 후(`resetState()`) 양쪽에서 다 호출되는데, `modeAData`를 지워도 되는 시점은 종료 후뿐이었다.

`start()`가 왜 굳이 이런 방어적 리셋을 하나 더 하고 있었는지도 짚이는 게 있다. 예전에 워치가 주도하고 아이폰이 미러링만 하던 시절, 이전 러닝의 거리/좌표 같은 잔여 상태가 새 러닝에 섞여 들어오는 문제가 있었다. 그때 만든 방어 코드일 텐데, 그 대상이 원래는 `totalDistance`, `coordinateArray` 같은 위치 데이터 쪽이었지 미션 설정(`modeAData`)까지 같이 지울 이유는 없었다. 같은 `reset()` 함수 안에 다 같이 들어있다 보니 나중에 심박 모드가 `modeAData`에 의존하게 되면서 이 부분이 드러난 거다.

`reset()`에서 `modeAData = nil`을 빼고, `clearModeAData()`라는 별도 함수로 분리했다.

```swift
func reset() {
    totalDistance = 0
    smoothingSpeedFirst = 0
    smoothingSpeedSecond = 0
    lastLocation = nil
    coordinateArray = []
    gpwsStatus = .normal
    phase = .preflight
    isReachedPace = false
    // modeAData는 여기서 지우지 않는다
}

func clearModeAData() {
    modeAData = nil
}
```

`RunViewModel.resetState()`, `WatchViewModel.resetState()` 양쪽 다 러닝이 완전히 끝난 뒤 `runningCenter.clearModeAData()`를 부르도록 추가했다. `start()` 쪽은 그대로 `reset()`만 부르고, 더 이상 `modeAData`를 건드리지 않는다.
