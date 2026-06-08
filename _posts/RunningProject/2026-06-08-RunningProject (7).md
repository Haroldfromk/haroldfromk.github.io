---
title: RunWay (7) GPWS 실제 데이터 연동
writer: Harold
date: 2026-06-08 08:33:00 +0900
# last_modified_at: 2026-06-07 08:33:00 +0800
categories: [RunWay]
tags: [SwiftData, Combine, CoreLocation, SwiftUI]

toc: true
toc_sticky: true
published: true
---

## ModeAView 설정하기

ModeA는 가칭이지만 기능적으로는 목표 기반 러닝 모드다. 유저가 목표 페이스, 허용 오차(`paceDeviation`), 목표 거리를 설정하고 러닝을 시작하면 GPWS가 실시간으로 페이스를 감시한다.

이 값들이 있어야 SINK RATE, OVERSPEED, MINIMUMS 로직이 동작하기 때문에 GPWS 구현 전에 먼저 연결해야 한다.

---

### 모델링 손보기

ModeAView를 하기전에 먼저 모델링을 손보도록한다.

```swift
struct ModeA {
    
    var id = UUID()
    let targetPace: Double 
    let paceDeviation: Int
    let targetDistance: Double
     
}
```

이전에 페이스와 허용오차만 해두었는데, 당시에 미처 추가하지 못한 `targetDistance`를 추가한다.

다만 `FlightData`와 달리 초기값을 두지 않았다. 유저가 직접 설정하는 값이라 기본값이 의미가 없고, 설정하지 않으면 생성 자체가 안 되는 구조가 더 명확하기 때문이다. 

또한 `ModeA`에서만 사용되는 값이라 Free Flight에서는 아예 생성할 필요가 없다.

---

### ModeAView 데이터 연결

이제 ModeAView에서 설정한 값들을 연결한다. 유저가 설정한 `targetPace`, `paceDeviation`, `targetDistance`는 최종적으로 `RunningCentor`에 전달되어 GPWS 판단 기준으로 사용된다.

그전에 어디로 해당값을 전달할지를 먼저 고민해보자.

View에서 Actor에 직접 접근하는 것도 기술적으로 가능하지만, View가 너무 많은 걸 알게 되는 구조가 된다. View는 ViewModel만 알고, Actor는 ViewModel만 바라보는 구조가 역할이 명확하게 분리된다.

결론은 ViewModel을 징검다리로 두는 것이다. **View → ViewModel → Actor** 단방향 흐름을 유지한다.

---

현재 구조가 버튼이 아닌 Navigation Link를 통해 다음 View로 넘어가는 구조로 되어있다.

```swift
NavigationLink(destination: TakeoffView()) {
    HStack(spacing: 8) {
        Image(systemName: "checklist")
            .font(.system(size: 13, weight: .semibold))
        Text("PRE-FLIGHT CHECK")
            .font(.orbitron(13, weight: .bold))
            .kerning(1)
    }
    .foregroundColor(.rwBg)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Color.rwGreen)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .onTapGesture {
        
    }
}
.padding(.horizontal, 16)
```

우선은 `onTapGesture`를 통해 전달을 해보려한다.

하지만 아직 VM에 전달할 기능을 만들지 않았으므로 VM에게 전달하는 코드를 작성해본다.

---

#### ViewModel 수정

```swift
func getModeData(_ data: ModeA) {
    print(data)
}
```

우선은 제대로 받아오는지 확인하기 위해 간단하게 적어둔다.

그리고 다시 ModeAView로가서

```swift
.onTapGesture {
    let pace = Double(targetPaceMin * 60 + targetPaceSec) / 60.0
    let modeAData = ModeA(targetPace: pace, paceDeviation: paceDeviation, targetDistance: targetDistance)
        
    runViewModel.getModeData(modeAData)
}
```

이렇게 연결을 해주었다. 이제 확인을 해보면된다.

```text
ModeA(id: 72621435-7B62-4C87-81EE-4C6DDEB19A82, targetPace: 5.0, paceDeviation: 20, targetDistance: 10.0)
```

#### 문제 해결

출력은 되지만 다음으로 넘어가지 않는 문제가 생겼다.

[StackOverflow](https://stackoverflow.com/questions/59040566/navigationlink-ontapgesture-and-navigation-not-firing-consistently){:target="_blank"}에 비슷한 상황이 있었고

제시한 답은 `simultaneousGesture`의 사용이었다.


```swift
.simultaneousGesture(TapGesture().onEnded({ _ in
    let pace = Double(targetPaceMin * 60 + targetPaceSec) / 60.0
    let modeAData = ModeA(targetPace: pace, paceDeviation: paceDeviation, targetDistance: targetDistance)
        
    runViewModel.getModeData(modeAData)
}))
```

그래서 이렇게 바꿔주었다.

이제는 출력도 되고 화면도 넘어가졌다.

그렇다면 둘의 차이가 무엇이고 왜 작동하지 않은걸까? 라는 생각이 들기 시작했다.

---

`onTapGesture`는 제스처를 가로채는 방식이라 NavigationLink의 탭 이벤트가 막혀버린다. [Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/how-to-use-gestures-in-swiftui){:target="_blank"}에서는 "SwiftUI will always give the child's gesture priority"라고 설명한다. 

여기서 자식 뷰는 `onTapGesture`가 붙은 `HStack`이고, NavigationLink의 탭보다 우선순위를 가져가버리는 것이다.

반면 [simultaneousGesture Docs](https://developer.apple.com/documentation/swiftui/simultaneousgesture){:target="_blank"}를 보면 "두 제스처가 어느 쪽도 선행하지 않고 동시에 발생할 수 있는 제스처"라고 나와있다. [Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-make-two-gestures-recognize-at-the-same-time-using-simultaneousgesture){:target="_blank"}에서도 "override this behavior to make two gestures trigger at once"라고 설명한다.

NavigationLink의 탭과 데이터 전달이 충돌 없이 함께 처리되는 이유가 여기에 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/gesture.png){: width="50%" height="50%"}

---

## GPWS 구현

사실 GPWS가 항공에 관심있는 사람이 아니면 이게 뭔지도 모르기에 간단하게 설명을 해본다.

GPWS(Ground Proximity Warning System)는 항공기가 지형이나 장애물에 너무 가깝게 접근할 때 조종사에게 경고를 주는 시스템이다. 

RunWay에서는 이 개념을 러닝에 적용했다. 목표 페이스에서 너무 느려지면 SINK RATE, 너무 빨라지면 OVERSPEED, 허용 오차 안으로 돌아오면 GLIDE PATH, 목표 거리 50m 전에는 MINIMUMS를 트리거한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/gpws.png){: width="50%" height="50%"}

---

### SINK RATE

설정한 페이스를 기준으로 허용오차 범위내에 현재 페이스가 들어오는지를 확인하고 너무 느리다면 SINK RATE를 발생하면된다.

이 기능을 구현하기위해 먼저 `RunningCentor`에 `ModeA` 설정값을 전달할 수 있도록 프로퍼티를 추가한다. 이후 `processLocation`에서 현재 페이스와 목표 페이스를 비교하여 GPWS 상태를 결정한다.

```text
View(ModeAView) → ViewModel → Actor (설정값 전달)
Actor → ViewModel → View(PFDView) (GPWS 상태 반환)
```

---

#### RunningCenter 수정

우선 VM에서 Actor로 전달을 한다.

이건 위에서 만든 getModeData에서 바로 전달을 해주면 된다.

그러기 위해선 RunningCenter에도 수정이 필요하다

다만 여기서는 그냥 값을 주입하는식으로는 되지않는다 RunningCenter는 Actor라서 MainActor와는 다르기 때문

```swift
// ❌
actor RunningCentor {
    var modeAData: ModeA?
}

@MainActor @Observable
final class RunViewModel {
    func getModeData(_ data: ModeA) {
            runningCenter.modeAData = data
        }
}

// Error
Actor-isolated property 'modeAData' can not be mutated from the main actor
```

---

해결방법은 이미 [RunWay(5)](https://haroldfromk.github.io/posts/RunningProject-(5)/){:target="_blank"}에서 다뤘다.

RunningCenter에 값을 바꿔줄 별도의 함수를 만들어주고 VM에서는 그걸 `Task, await`를 통해 전달해주면 된다.

```swift
func setModeAData(_ modeA: ModeA){
    modeAData = modeA
}

func getModeData(_ data: ModeA) {
    Task {
        await runningCenter.setModeAData(data)
    }
}
```

---

이제 `modeAData`가 Actor에 전달됐으니 `processLocation`에서 현재 페이스와 비교해 GPWS 상태를 결정하면 된다.

상태를 관리하기에 딱 맞는 도구가 있다. 바로 `enum`이다.

```swift
enum GPWSState {
    case normal, sinkRate, overspeed, minimums
}
```

이걸 `RunningCentor`에 선언하여 Actor가 직접 상태를 결정하고 `FlightData`에 담아 전달한다.

외부에서 직접 변경하지 못하도록 읽기전용으로 선언한다.

```swift
private(set) var gpwsStatus: GPWSState = .normal
```

---

##### FlightData 모델 수정

GPWS 상태를 View까지 전달하려면 `FlightData`에도 추가가 필요하다. 다만 Free Flight에서는 GPWS가 동작하지 않으므로 옵셔널로 선언한다.

```swift
struct FlightData {
    var distance: Double = 0
    var phase: FlightPhase = .preflight
    var pace: Double = 0
    var altitude: Double = 0
    var heading: Double = 0
    var gpwsStatus: GPWSState? = nil
}
```

---

#### RunningCenter 추가 수정

이제 `processLocation`에서 GPWS 상태를 판단해야 한다.

`GPWSState`가 enum이라 switch-case로 처리하면 모든 케이스를 강제로 다루게 되어 누락이 없다.

다만 현재 `processLocation`에 계속 코드를 추가하면 함수 길이가 길어져 가독성이 떨어진다. GPWS 판단 로직만 담당하는 별도 함수로 분리하여 `processLocation`은 흐름만 담당하도록 한다.

```swift
func calculateGPWSStatus(_ pace: Double) -> GPWSState {
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

`rawPace`는 `1 / (speed * 60 / 1000)`으로 계산한 min/km 단위 값이다. `paceDeviation`은 초 단위이므로 `/60.0`으로 분으로 변환하여 단위를 맞춘다.

예를 들어 목표 페이스가 `5.0 min/km`, 허용 오차가 `30초(0.5분)`라면 `4.5 min/km` 미만은 OVERSPEED, `5.5 min/km` 초과는 SINK RATE다. 

`calculateGPWSStatus` 하나로 두 케이스가 모두 처리된다.

이후

```swift
func processLocation(_ location: CLLocation) {
        // 생략
        gpwsStatus = calculateGPWSStatus(rawPace)
        let flightData = FlightData(distance: totalDistance, phase: phase, pace: rawPace, altitude: rawAltitude, heading: rawHeading, gpwsStatus: gpwsStatus)
        continuation?.yield(flightData)
    }
```

추가를 해주면 된다.

#### View에 적용하기

`gpwsState`를 로컬 `@State`로 관리하던 방식에서 `FlightData`를 통해 Actor에서 전달받는 방식으로 변경한다.

옵셔널로 선언한 이유는 Free Flight에서는 GPWS가 동작하지 않아 `nil`로 두기 위해서다.

```swift
@State private var gpwsState: GPWSState?
```

`FlightData.gpwsStatus`가 변경될 때마다 `triggerGPWS`를 호출해 UI를 업데이트한다.

```swift
.onChange(of: runViewModel.flightData.gpwsStatus) { _, newValue in
    if let status = newValue {
        triggerGPWS(status)
    }
}
```

실행해서 아래와 같이 세팅을 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/simu.png){: width="50%" height="50%"}

그리고 시작을 하면?

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/test.gif){: width="50%" height="50%"}

잘 되는걸 알 수 있다.

#### 문제 해결

다만 러닝 시작하자마자 바로 GPWS가 작동되는 문제가 있다.

러닝 시작 직후에는 속도가 0이라 페이스가 유효하지 않은 상태에서 GPWS가 즉시 트리거되기 때문이다.

이를 해결하기 위해 `RunningCentor`에 `isReachedPace` 플래그를 두고, 현재 페이스가 유효하고 목표 페이스에 한 번이라도 도달한 이후부터 GPWS를 활성화하는 구조로 변경한다. `rawPace.isFinite`, `rawPace > 0` 조건을 먼저 체크하여 시작 직후 무효한 값이 들어오는 경우도 걸러준다.

```swift
private(set) var isReachedPace: Bool = false

func processLocation(_ location: CLLocation) {
    // 생략
    
    if let targetPace = modeAData?.targetPace, rawPace.isFinite, rawPace > 0, rawPace >= targetPace {
        isReachedPace = true
    }
    
    if isReachedPace {
        gpwsStatus = calculateGPWSStatus(rawPace)
    } else {
        gpwsStatus = .normal
    }
    
    let flightData = FlightData(distance: totalDistance, phase: phase, pace: rawPace, altitude: rawAltitude, heading: rawHeading, gpwsStatus: gpwsStatus)
    continuation?.yield(flightData)
}
```

이제 실행해서 확인해보면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/fix.gif)

처음에 바로 확인된 페이스가 4:37이었기에 `true`로 바뀌면서 GPWS가 작동하기 시작한다.

다만 목표 페이스가 4:30인데 4:37에서 바로 활성화된 것을 보면, 현재 조건이 "목표보다 느리거나 같으면" true가 되는 구조라는 걸 알 수 있다. 

엄밀히 말하면 목표 페이스 근처, 즉 허용 오차 범위 안에 한 번이라도 들어왔을 때 활성화하는 게 더 정확하다.

```swift
if let modeA = modeAData, rawPace.isFinite, rawPace > 0 {
    let deviation = Double(modeA.paceDeviation) / 60.0
    if rawPace >= modeA.targetPace - deviation && rawPace <= modeA.targetPace + deviation {
        isReachedPace = true
    }
}
```

그래서 바꿔주었다.

실행 사진은 패스

---

### MINIMUMS

목표 거리 50m 전에 자동으로 트리거된다. `totalDistance`가 `targetDistance - 50m` 이상이면 `.minimums`를 반환하도록 `calculateGPWSStatus`에 조건을 추가했다.

`targetDistance`는 km 단위라 `* 1000`으로 변환하여 비교한다. MINIMUMS는 페이스 판단보다 우선순위가 높으므로 switch-case 앞에 먼저 체크한다.

```swift
func calculateGPWSStatus(_ pace: Double) -> GPWSState {
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
```

`if`를 switch-case 앞에 먼저 체크하기 때문에 MINIMUMS가 페이스 판단보다 우선순위를 가진다. 

예를 들어 목표 거리 50m 앞에서 페이스가 SINK RATE 상태여도 MINIMUMS가 먼저 트리거된다. 또한 `totalDistance < targetDistanceM` 조건으로 목표 거리를 초과한 경우에는 MINIMUMS가 계속 유지되지 않도록 상한선도 함께 체크했다.

실행해보면? (빠른 테스트를 위해 bicycle로 한다)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/mimums.gif){: width="50%" height="50%"}

이렇게 되는걸 알 수 있다.

---

### 햅틱 + 경고음 연동

초기 Mock UI 구현 시 `triggerGPWS`에 햅틱과 시스템 사운드가 이미 포함되어 있어 `onChange`로 GPWS 상태가 바뀌는 순간 자동으로 동작한다.

다만 경고음의 경우 저작권 확인이 필요하며, 항공 느낌에 맞는 커스텀 사운드가 필요하다면 추후 AI로 생성하는 것도 고려 중이다. 햅틱 횟수 역시 상태 변경 시 한 번만 울리는 현재 구조가 적합한지 실기기 테스트 후 조정할 예정이다.

---

## PFDView 정리 및 TakeoffView 연결

AlertsView SwiftData 연동 전에 먼저 정리할 것들이 있다. PFDView에 임시로 넣어뒀던 Start 버튼과 GPWS 테스트 버튼 3개를 제거하고, TakeoffView에서 ROTATE 카운트다운이 끝나는 시점에 러닝이 시작되도록 연결한다.

```swift
func startCountdown() {
    countdownActive = true
    countdownValue = 3
    for i in 0..<5 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
            if i < 3 { countdownValue = 3 - i }
            else if i == 3 {
                countdownValue = 0
            }
            else {
                countdownActive = false
                navigateToPFD = true
                runViewModel.start() // added
            }
        }
    }
}
```

else 가 되는시점에 true가 되면서

```swift
.navigationDestination(isPresented: $navigateToPFD) {
    PFDView()
}
```
이렇게 PFDView()로 전환이 되기에

true가 되는 시점에 start()를 하도록 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/takeoff.gif){: width="50%" height="50%"}

---

## PFDView 문제 수정

현재 네비게이션 우측에 있는 x 버튼을 누르면 러닝 중인데도 뒤로 돌아가는 문제가 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/CleanShot_08-14.33.png){: width="50%" height="50%"}

저걸 누르면 이렇게 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/problem.gif){: width="50%" height="50%"}

이를 해결하기 위해 ViewModel에 `isRunning` 플래그를 추가했다. `start()` 시 `true`, `stop()` 시 `false`로 바뀌며, 러닝 중일 때는 x 버튼을 투명하게 하고 동시에 비활성화했다. 위치를 알고 탭해도 작동하지 않는다.

```swift
// VM
var isRunning: Bool = false

func start() {
    isRunning = true
    // 생략
}

func stop() {
    isRunning = false
    // 생략
}

// View
Button { dismiss() } label: {
    Image(systemName: "xmark")
        .foregroundColor(.rwMuted)
        .font(.system(size: 15))
}
.opacity(runViewModel.isRunning ? 0 : 1)
.disabled(runViewModel.isRunning)
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-08-RunningProject-7/CleanShot_08-14.36.png){: width="50%" height="50%"}

이제는 러닝 중에 x 버튼이 보이지 않는다.

또한 탭바도 러닝 중에 누르면 초기 화면으로 돌아가는 문제가 있어 `.toolbarVisibility(.hidden, for: .tabBar)`를 통해 PFDView에서 숨기려 했으나, 이후 뷰에서도 탭바가 보이지 않는 문제가 생겨 일단 적용하지 않았다.