---
title: RunWay 1.2 (1) - 심박 미러링 실기기 테스트
writer: Harold
date: 2026-07-22 11:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, ActivityKit]

toc: true
toc_sticky: true
published: true
---

[이전글](https://haroldfromk.github.io/posts/RunningProject-(31)/){:target="_blank"}에서 1.1 핫픽스가 승인나고, 다시 심박 기능 브랜치로 돌아왔다. 

버전을 1.2로 올리고(핫픽스가 이미 1.1을 써버려서), 핫픽스에서 고친 내용도 이 브랜치에 옮겨왔다.
그러고 나서 지금까지 한 번도 안 해본 조합으로 테스트를 해봤다. 아이폰이 주도하고 워치가 미러링하는 상태로, 심박 기준 Mission Flight를 뛰어본 거다. 여기서 문제가 여럿 나왔다.

---

## 워치가 계속 Free Flight로 보임

아이폰에서 ModeAView로 심박 기준 미션을 설정했는데, 워치 화면은 계속 FREE로만 떴다.

원인을 보니 이 경로 자체가 없었다. `RunViewModel.getModeData()`는 로컬 상태(`modeAData`)만 세팅할 뿐, 그 값을 워치로 보내는 코드가 어디에도 없었다.

```swift
func getModeData(_ data: ModeA) {
    isModeA = true
    modeAData = data
    Task {
        await runningCenter.setModeAData(data)
    }
}
```

워치 쪽에서 미션을 설정할 때는 `sendModeData()`로 아이폰에 보내주는 코드가 있는데, 반대 방향(아이폰 → 워치)은 아예 빠져 있었다. 아이폰 주도 미러링에서는 워치가 지금 무슨 미션을 뛰고 있는지 알 방법이 없었던 거다.

토글로 켜고 꺼보면서 어디서 끊기는지 확인해볼 수 있게 만들어봤다.

<iframe
  src="/assets/demo/modedata_sync_simulator.html"
  width="100%"
  height="650px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

---

### RunViewModel 수정

`RunViewModel`에 `setModeData()`를 새로 만들어서, `ModeAView`에서는 이걸 쓰게 했다.

```swift
func setModeData(_ data: ModeA) {
    getModeData(data)
    watchConnectivityService.sendModeData(data)
}
```

`getModeData()`는 그대로 남겨뒀다. 워치에서 받은 설정을 처리할 때도 이 함수를 쓰는데, 여기서 다시 워치로 전송해버리면 서로 주고받으면서 무한 핑퐁이 생기기 때문이다.

그리고 워치 쪽 `didReceiveMessage`에는 애초에 "modeData" 케이스 자체가 없었다. 보낼 줄만 알고 받을 줄은 몰랐던 거라, 이것도 새로 추가했다.

```swift
// didReceiveMessage
if type == "modeData" {
    let target = ModeATarget(rawValue: message["target"] as? String ?? "") ?? .pace
    let targetPace = message["targetPace"] as? Double ?? 0
    let paceDeviation = message["paceDeviation"] as? Int ?? 0
    let targetHeartRate = message["targetHeartRate"] as? Double ?? 0
    let heartRateDeviation = message["heartRateDeviation"] as? Int ?? 0
    let targetDistance = message["targetDistance"] as? Double ?? 0
    let modeA = ModeA(target: target, targetPace: targetPace, paceDeviation: paceDeviation, targetHeartRate: targetHeartRate, heartRateDeviation: heartRateDeviation, targetDistance: targetDistance)
    Task { @MainActor in
        viewModel?.getModeData(modeA)
    }
}
```

---

## 편차도 항상 +0sec으로 나옴

같은 원인이었다. 워치의 `modeAData`가 계속 `nil`이었으니, `gpwsDeviation`도 항상 guard에 걸려서 0만 나오고 있었다. 단위도 심박(bpm) 대신 sec으로 나오고 있었는데, 이것도 `modeAData`가 없어서 `target`을 확인할 방법이 없었던 거였다. 위 수정으로 같이 해결됐다.

---

## 다이나믹 아일랜드 심박이 0으로 뜸

이건 원인이 훨씬 단순했다. `RunViewModel.startStream()`에서 Live Activity를 갱신하는 코드를 보니

```swift
await flightActivityService.updateCruise(
    pace: PaceFormatter.format(data.pace),
    distance: data.distance / 1000,
    heartRate: 0
)
```

`heartRate` 자리에 그냥 0이 박혀 있었다. 실시간 심박값(`healthData.heartRate`)은 이미 받아오고 있었는데, 여기 연결을 안 해둔 채로 넘어갔던 것 같다.

```swift
heartRate: Int(healthData.heartRate)
```

이렇게 바꿔서 해결했다.

---

## 남은 문제 두 개

- 러닝 종료 시 아이폰에 SwiftData 저장이 안 되는 문제
- 워치도 폰이랑 붙어있었는데 종료 시 뭔가 전달이 안 된 문제

이 둘은 코드만 봐서는 바로 원인이 안 잡혀서, 정확히 어떤 상황이었는지 다시 확인하고 넘어가기로 했다.

---

## 다시 테스트해도 STATUS는 여전히 FREE

다이나믹 아일랜드 고치고 다시 실기기로 테스트해봤다. 심박수는 이제 제대로 뜨는데, 워치 STATUS는 여전히 FREE였다.

`sendMessage`는 그 순간 워치가 reachable해야 하는데, `ModeAView`에서 미션을 설정하는 시점엔 워치 앱이 아직 안 켜져 있을 수 있다는 걸 그제서야 깨달았다. `errorHandler`도 없어서 전송이 실패해도 아무 표시가 안 남는 구조였다.

```swift
session.sendMessage(message, replyHandler: nil, errorHandler: { error in
    print("전송 실패: \(error.localizedDescription)")
})
```

에러 핸들러를 추가하고, 미러링이 실제로 시작되는 시점(`updatePhase(.cruise)`, HealthKit 워크아웃 시작 직후)에도 한 번 더 보내도록 재전송을 넣었다. 이 시점엔 워치 앱이 네이티브 미러링으로 이미 켜져 있을 확률이 훨씬 높다.

```swift
try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
if isModeA, let modeAData {
    watchConnectivityService.sendModeData(modeAData)
}
```

다시 테스트해보니 워치에 HEART RATE가 제대로 떴다.

---

## DIFF 칸에 이상한 음수

워치는 고쳤는데, 아이폰 PFDView의 `MissionHUDBar`에서 DIFF 칸에 러닝 시작 직후 "-150" 같은 큰 음수가 떴다.

```swift
private var devText: String {
    let sign = deviation >= 0 ? "+" : ""
    if target == .pace {
        guard pace > 0 && pace.isFinite else { return "--" }
        return sign + PaceFormatter.format(abs(deviation))
    } else {
        return "\(sign)\(Int(deviation))"
    }
}
```

페이스 쪽엔 `pace > 0` 가드가 있는데 심박 쪽엔 이 가드가 없었다. 아직 심박수를 못 받은 시점(`heartRate == 0`)에 `deviation = 0 - targetHeartRate`가 그대로 계산돼서 큰 음수가 나온 거였다.

```swift
guard heartRate > 0 else { return "--" }
return "\(sign)\(Int(deviation))"
```

페이스 쪽이랑 똑같은 방식으로 가드를 추가해서 해결했다.

---

## GPWS 편차가 다시 +0sec으로

STATUS는 잡았는데, 심박 기준 미션에서 GPWS 경고가 뜨자마자 "+0sec"으로 표시되는 문제가 남아있었다. 단위도 심박(bpm) 대신 초(sec)로 나왔다.

`gpwsDeviationUnit`이랑 `gpwsDeviation` 둘 다 워치의 `modeAData?.target`을 보고 판단하는데, STATUS는 나중엔 제대로 뜨는 걸 보면 이것도 같은 타이밍 문제였다. 심박 기준 GPWS는 페이스 쪽(`isReachedPace`)과 달리 "한 번이라도 목표 구간에 도달해야 판정 시작" 같은 유예 구간이 없어서, 러닝 시작하자마자 거의 바로 판정이 시작된다. `sendModeData()`가 아직 도착하기 전에 GPWS부터 계산되면서 비어있거나 오래된 `modeAData`를 참조한 거였다.

`sendModeData()`를 한두 번 더 보내는 식으로는 이 타이밍 문제를 근본적으로 없앨 수 없다고 봤다. 그래서 이미 3초마다 계속 보내고 있는 `flightData` 메시지에 목표 정보를 같이 실어서, 워치가 그걸 받을 때마다 `modeAData`를 스스로 다시 맞추게 만들었다.

```swift
if let modeA = viewModel?.modeAData {
    message["modeATarget"] = modeA.target.rawValue
    message["modeATargetPace"] = modeA.targetPace
    message["modeAPaceDeviation"] = modeA.paceDeviation
    message["modeATargetHeartRate"] = modeA.targetHeartRate
    message["modeAHeartRateDeviation"] = modeA.heartRateDeviation
    message["modeATargetDistance"] = modeA.targetDistance
}
```

워치 쪽 `flightData` 수신 처리에서도 이 값이 있으면 `getModeData()`로 다시 반영하도록 했다. `sendModeData()` 전송이 어쩌다 씹혀도, 3초 안에 오는 다음 `flightData`가 스스로 고쳐주는 구조가 됐다.

---

## 스키마 마이그레이션 위험

여기까지 고치고 나서 문득 걱정이 됐다. 지금까지는 계속 앱을 지우고 새로 설치하면서 테스트하고 있었는데, 실제 유저는 그냥 업데이트만 할 텐데 괜찮을까 싶었다.

`SwiftDataAlert`에 이번에 `target`/`heartRate` 필드를 추가했는데, 기본값이 `init()` 파라미터에만 있고 프로퍼티 선언 자체에는 없었다.

```swift
var target: String
var heartRate: Double
...
init(..., target: String = ModeATarget.pace.rawValue, ..., heartRate: Double = 0, ...) { ... }
```

SwiftData의 자동 라이트웨이트 마이그레이션은 기존 레코드에 새 필드 값을 채울 때 프로퍼티 선언부의 기본값을 보는데, init 파라미터에 있는 기본값은 여기서 안 보인다. 이 필드가 없던 버전(v1.1)을 쓰던 유저가 이 빌드로 업데이트하면 마이그레이션이 실패하거나 크래시할 수 있는 구조였다. 계속 삭제 후 재설치로만 테스트해서 이 문제가 한 번도 드러나지 않았던 거다.

```swift
var target: String = ModeATarget.pace.rawValue
var heartRate: Double = 0
```

선언부에 기본값을 직접 넣어서 고쳤다.

이 정도 고치고 나니 혹시 다른 사람들도 이런 문제를 겪었는지 궁금해서, AI한테 SwiftData 라이트웨이트 마이그레이션에서 프로퍼티 선언부 기본값과 init 파라미터 기본값이 왜 다르게 취급되는지 자료를 찾아서 요약해달라고 시켰다.

찾아보니 정확히 같은 패턴으로 고생한 사례가 여럿 있었다. 새 프로퍼티에 기본값을 달아놨는데도 "nil value passed for a non-optional keyPath" 에러가 나서 크래시하는 경우가 흔했고, 원인은 우리가 겪은 것과 같았다. SwiftData가 기존 레코드에 새 필드 값을 채울 때 보는 건 프로퍼티 선언부의 기본값이지, init 파라미터의 기본값이 아니라는 것.

더 흥미로웠던 건, 프로퍼티 선언부에 기본값을 넣어도(우리가 방금 한 것처럼) 여전히 크래시가 나는 사례들이 있다는 거였다. Apple 포럼에서는 이걸 "의도된 동작"이라고 밝혔고, 완전히 안전하게 하려면 `VersionedSchema`로 일단 새 필드를 옵셔널로 만들어 마이그레이션한 다음, 두 번째 단계에서 필수값으로 바꾸는 멀티스테이지 마이그레이션이 필요하다고 한다.

- [SwiftData Migration: Keeps failing…](https://developer.apple.com/forums/thread/769427){:target="_blank"}
- [Added new field to swiftdata model, now crashes](https://developer.apple.com/forums/thread/740243){:target="_blank"}
- [Swift Data Lightweight Migrations](https://medium.com/@pranav1160ly/swift-data-lightweight-migrations-a1703319f4da){:target="_blank"}

지금 한 수정(프로퍼티 선언부 기본값)은 맞는 방향이고 대부분의 경우엔 통하지만, 100% 확실한 건 아니라는 뜻이다. 나중에 실제로 v1.1 빌드로 기록을 남기고 그 위에 이 빌드를 덮어씌워서 마이그레이션이 정말 안전한지 한 번 더 확인해볼 생각이다.

---

## 심박 GPWS 유예 구간 누락

이건 실기기 테스트하다가 발견했다. 페이스 기준 미션은 목표 페이스 구간에 한 번이라도 들어와야 GPWS 판정이 시작되는데, 심박 기준은 이런 유예 구간이 없어서 러닝을 시작하자마자 곧바로 SINK RATE 경고가 울렸다. 안정 심박수가 아직 목표 구간에 못 미친 게 당연한데, 시작하자마자 알람부터 울리니 이상했다.

코드를 보니 실제로 페이스 쪽에만 `isReachedPace`라는 유예 플래그가 있었다.

```swift
switch modeA.target {
case .pace:
    guard isReachedPace else { return .normal }
    return calculateGPWSStatus(pace)
case .heartRate:
    let heartRate = await healthCenter.currentHeartRate
    return calculateHeartRateGPWSStatus(heartRate)
}
```

심박 쪽에도 똑같은 개념의 `isReachedHeartRate`를 추가했다. 목표 심박 허용 범위 안에 한 번이라도 들어와야 그 뒤로 GPWS 판정을 시작하고, 그 전까진 무조건 NORMAL이다.

```swift
case .heartRate:
    let heartRate = await healthCenter.currentHeartRate
    if !isReachedHeartRate, heartRate > 0 {
        let deviation = Double(modeA.heartRateDeviation)
        if heartRate >= modeA.targetHeartRate - deviation && heartRate <= modeA.targetHeartRate + deviation {
            isReachedHeartRate = true
        }
    }
    guard isReachedHeartRate else { return .normal }
    return calculateHeartRateGPWSStatus(heartRate)
```

토글로 켜고 꺼보면서 심박수가 오르는 동안 GPWS가 어떻게 달라지는지 볼 수 있게 만들어봤다.

<iframe
  src="/assets/demo/heartrate_gate_simulator.html"
  width="100%"
  height="770px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"    
  loading="lazy"
></iframe>

`RunningCenter`가 아이폰/워치 공용 파일이라 이 수정 하나로 양쪽 다 적용됐다.

---

## 드디어 잡힌 저장 문제

앱을 완전히 지우고 새로 설치해서 다시 실기기로 테스트해보니, 이번엔 저장이 정상적으로 됐다. 앱/워치 양쪽 다.

돌아보니 이 프로젝트에서 "삭제 후 재설치하면 고쳐진다"는 패턴이 처음이 아니다. [이전글](https://haroldfromk.github.io/posts/RunningProject-(27)/){:target="_blank"}에서도 미러링 중 워치가 데이터를 못 받는 현상이 재설치하면 없어지는 걸 보고, `HKWorkoutSession`이 `healthd` 데몬 레벨에 남기는 상태 때문일 거라고 결론 낸 적이 있었다. 코드를 안 건드렸는데 재설치만으로 고쳐진다는 건, 앱 로직이 아니라 기기에 남아있던 뭔가가 문제였다는 뜻이다.

이번엔 그 상태가 HealthKit 세션이 아니라 SwiftData 로컬 스토어였다. 앞서 찾아본 사례들([SwiftData Migration: Keeps failing…](https://developer.apple.com/forums/thread/769427){:target="_blank"}, [Added new field to swiftdata model, now crashes](https://developer.apple.com/forums/thread/740243){:target="_blank"})은 다들 크래시가 났다는 얘기였는데, 우리는 크래시도 안 나고 그냥 `insert()`가 조용히 안 되는 쪽이었다. 검색해서 찾은 사례들이랑은 좀 다른 모습이었다.

정확히 뭐가 결정적이었는지는 사실 확실하지 않다. 프로퍼티 선언부 기본값을 고친 게 진짜로 마이그레이션 실패를 막은 건지, 아니면 그냥 앱을 지워서 마이그레이션 자체가 필요 없어진 건지 구분이 안 된다. 근데 둘 다 해뒀으니 이제는 안전할 거라고 본다. 결과적으로 4번/5번 문제 모두 스키마 마이그레이션 실패가 진짜 원인이었을 가능성이 크다.

`saveRunningData()`/`sendRunningData()`/`didReceiveUserInfo()`/`drainPendingWatchData()`에 로그를 심어서 추적해보려 했던 건 결과적으로 별 도움이 안 됐다. 시뮬레이터에선 애초에 재현이 안 됐고, 실기기에서는 재설치와 스키마 수정을 같이 하고 나서야 풀려서 어느 로그에서도 결정적인 단서는 안 나왔다. 오히려 이 프로젝트에서 반복돼온 "재설치하면 고쳐진다" 패턴을 떠올린 게 더 결정적이었다.

---

## 에러 핸들러 안에 코드가 있으면 크래시

errorHandler 자리에 클로저를 넣고 그 안에 뭔가 실행되게 하면 무슨 일이 생기는지, 이번에 직접 겪어봤다.

`sendModeData()` 전송이 실패하면 로그라도 남기려고 클로저 안에 print를 넣어뒀는데, 워치 없이 아이폰 혼자서 미션 플라이트를 뛰어보니 앱이 튕겼다.

Xcode로 잡아보니 크래시 지점이 딱 그 클로저 안이었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-22-RunningProject-32/CleanShot_22-21.50.png){: width="50%" height="50%"}

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-22-RunningProject-32/CleanShot_22-21.51.png){: width="50%" height="50%"}

```swift
// Before
session.sendMessage(message, replyHandler: nil, errorHandler: { error in
    print("전송 실패: \(error.localizedDescription)")
})

// After
session.sendMessage(message, replyHandler: nil, errorHandler: nil)
```

이 에러 핸들러는 전송이 실패했을 때만 실행되는데, 지금까지는 테스트할 때마다 워치가 켜져 있어서 전송이 항상 성공했다. 그래서 이 클로저가 실행된 적이 한 번도 없었다. 워치 없이 앱만 켜니 워치를 못 찾아서 전송이 처음으로 실패했고, 그 순간 이 클로저가 처음 실행되면서 크래시가 났다.

왜 하필 실행되는 순간 크래시가 나는지 찾아보니, WCSession 문서에 `replyHandler`/`errorHandler`는 원래 백그라운드 스레드에서 실행된다고 나와 있었다. 근데 우리 코드 쪽은 Swift 동시성 체크가 걸려 있어서, 클로저가 실제로 실행되는 스레드가 코드가 기대하는 것과 다르면 그 자리에서 바로 크래시로 처리해버린다. 애플 개발자 포럼에도 똑같은 원인으로 크래시가 난 사례가 있었다. 거기서 나온 해결책은 클로저에 `@Sendable`을 붙여서 "이 클로저는 어느 스레드에서 실행돼도 안전하다"고 컴파일러에 알려주는 방식이었다.

- [WatchConnectivity Swift 6 - Incorrect actor executor assumption Docs](https://developer.apple.com/forums/thread/771525){:target="_blank"}

근데 우리 쪽은 이 클로저가 원래 로그 하나 남기는 용도였을 뿐이라, `@Sendable`을 붙여 고치기보다 그냥 에러 핸들러 자체를 없애는 쪽을 택했다. 같은 파일에 있는 `sendFlightData()`, `sendPauseData()`, `sendElapsedTime()`도 전부 에러 핸들러 자리에 `nil`을 넣고 있었고 여태 이런 문제가 없었으니, `sendModeData()`도 원래대로 `nil`로 되돌렸다.

전송이 실패해도 이제 조용히 넘어간다. `sendModeData()` 하나가 실패해도, 3초마다 도는 `flightData`에 목표 정보가 같이 실려 있어서 다음 틱에서 그대로 맞춰진다.

<iframe
  src="/assets/demo/sendmodedata_recovery_simulator.html"
  width="100%"
  height="700px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>
