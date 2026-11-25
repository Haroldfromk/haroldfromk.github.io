---
title: RunWay 1.4.1 좀비 세션 결함 보고서
writer: Harold
date: 2026-11-23 06:20:00 +0900
last_modified_at: 2026-11-23 07:20:00 +0900
categories: [RunWay, SwiftUI]
tags: [SwiftUI, HealthKit, WatchConnectivity, OSLog, watchOS]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

RunWay 에는 출시 전부터 따라다닌 결함이 하나 있다. 러닝 중에 앱을 강제종료하면 운동 세션이 끝나지 않고 남는다. 이걸 좀비 세션이라고 불러 왔다. 6월 말에 세 번 고치려다 실패했고, 9월에 한 번 더 들여다봤고, 그 사이에 앱 구조가 바뀌면서 증상의 모양도 바뀌었다.

그때마다 적어 둔 글이 두 편 있는데 둘 다 공개하지 않았다. 이번에 그 두 편을 다시 읽고, 배포판(v1.4.1) 코드와 한 줄씩 맞춰 봤다. 이 글은 그 결과를 결함 보고서 형식으로 정리한 것이다. 코드는 한 줄도 고치지 않았다.

글에 나오는 주장은 세 가지로 나눠 적는다.

| 표시 | 뜻 |
|---|---|
| <span style="color:#2e9e4f">확인</span> | 코드, 커밋, 당시 로그, 애플 문서나 SDK 헤더에서 직접 본 것 |
| <span style="color:#d29922">추론</span> | 본 것들을 이어 붙여 내린 판단. 틀릴 수 있다 |
| <span style="color:#e5534b">미확인</span> | 실기기로 봐야 알 수 있는데 아직 확인 못 한 것 |

---

## 결함 개요

한 장으로 줄이면 이렇다.

| 항목 | 내용 |
|---|---|
| 결함 이름 | 강제종료 뒤에 남는 운동 세션 (좀비 세션) |
| 처음 발견 | 2026년 6월 말, v1.0 출시 전 |
| 발생 조건 | 러닝 중에 앱을 앱 스위처에서 밀어 강제종료 |
| 예전 증상 | 아이폰 앱을 다시 켜면 끝난 러닝의 PFD 화면으로 바로 들어감 |
| 지금 증상 | PFD 직행은 없음. 대신 끝나지 않은 세션이 기기에 남고, 워치는 PFD 화면에 그대로 남은 채 숫자가 더 바뀌지 않고, 건강 앱에 버린 러닝이 저장됨 |
| 과거 조치 | 세 번 시도, 세 번 모두 실패 (v1.0 에서는 알려진 한계로 문서에만 적음) |
| 현재 판정 | 가장 눈에 띄던 증상은 구조 변경으로 사라짐. 세션이 남는 것 자체는 그대로 |
| 조치 | 1.4.1 에서는 알려진 한계로 둠. 결과는 무겁지만 조건이 좁음 |
| 조사 대상 | 배포판 태그 v1.4.1, 예전 구조는 커밋 `39e1feb` |

여기서 가장 중요한 줄은 "현재 판정"이다. **증상은 막혔지만 원인은 그대로다.** 이 둘을 섞어서 "좀비 세션은 해결됐다"거나 "앱으로는 못 막는다"고 말하면 둘 다 절반만 맞다.

---

### 운동 세션이란?

운동 세션은 "지금 운동 중이다"라고 시스템에 알려 두는 표식이다. 코드에서는 [`HKWorkoutSession`](https://developer.apple.com/documentation/healthkit/hkworkoutsession){:target="_blank"}이 이 역할을 한다. 세션이 켜져 있는 동안 시스템은 앱이 뒤로 가도 재우지 않고, 심박수 같은 값을 더 자주 잰다.

헬스장 입장 기록에 빗대면 쉽다. 들어갈 때 데스크에 이름을 적고(세션 시작), 나갈 때 지운다(세션 종료). 이 장부를 관리하는 건 회원(앱)이 아니라 데스크(시스템)다. iOS 와 watchOS 에서는 `healthd` 라는 시스템 프로세스가 데스크 역할을 한다.

그래서 앱이 죽어도 세션은 같이 죽지 않는다. 회원이 인사 없이 뒷문으로 나가도 장부에는 이름이 남는 것과 같다. **좀비 세션은 이 "지워지지 않은 이름"이다.**

---

### 미러링 세션이란?

미러링은 워치에서 돌고 있는 운동 세션을 아이폰에 비춰 주는 기능이다. 워치가 [`startMirroringToCompanionDevice`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/startmirroringtocompaniondevice%28completion:%29){:target="_blank"}를 부르면 아이폰 앱이 뒤에서 깨어나고, 아이폰은 그 세션을 비춘 미러링 세션을 건네받는다.

SDK 헤더는 세션을 두 종류로 나눈다. 직접 만든 세션은 primary, 건네받은 세션은 mirrored 다.

```objc
// HKWorkoutSession.h
typedef NS_ENUM(NSInteger, HKWorkoutSessionType) {
    HKWorkoutSessionTypePrimary = 0,   // 이 기기에서 직접 도는 세션
    HKWorkoutSessionTypeMirrored,      // 다른 기기의 세션을 비춘 것
} API_AVAILABLE(ios(17.0), watchos(10.0));
```

거울에 빗대면 이렇다. 거울에 비친 모습은 나를 따라 움직이지만 내가 아니다. 미러링 세션도 워치 세션을 따라 움직이지만, 운동을 재고 기록하는 원래 세션은 워치에 있다. 이 글에서는 워치가 만든 primary 쪽을 "워치의 원래 세션", 아이폰이 건네받은 mirrored 쪽을 "미러링 세션"이라고 부른다. 이 차이가 6월의 세 번의 실패를 전부 설명한다.

---

## 발생 조건과 재현 순서

지금 구조에서 아이폰 주도 러닝 중에 아이폰 앱을 강제종료하면 벌어지는 일을 시간 순서로 그렸다.

![아이폰 앱을 강제종료한 뒤 아이폰 세션은 끝나지 않은 채 남고 워치 세션은 계속 돌며 워치는 PFD 화면에 남아 숫자만 멈춘다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-23-RunningProject-60/runway-60-forcequit-timeline.png)

재현 순서는 다음과 같다.

1. 아이폰에서 러닝을 시작한다. 워치 앱이 따라 켜지고 양쪽에 세션이 하나씩 생긴다.
2. 러닝 도중 아이폰 앱 스위처에서 RunWay 를 밀어 올려 종료한다.
3. 워치를 본다. PFD 화면이 그대로 떠 있고 숫자는 마지막 값에서 더 바뀌지 않는다.
4. 아이폰 앱을 다시 켠다. HOME 화면이 뜬다.

누가 러닝을 시작했느냐에 따라 남는 것이 다르다.

| | 아이폰에서 시작한 러닝 | 워치에서 시작한 러닝 |
|---|---|---|
| 세션이 생기는 곳 | 아이폰과 워치 양쪽 | 워치만 |
| 아이폰 앱 강제종료 | 아이폰 세션이 남음. 워치 세션은 계속 돎 | 아이폰에는 세션이 없어서 남을 것이 없음 |
| 워치 앱이 죽음 | 워치 세션이 남음 | 워치 세션이 남음 |
| 근거 | <span style="color:#2e9e4f">확인</span> `HealthKitService.swift:121`, `:133` | <span style="color:#2e9e4f">확인</span> `RunViewModel.swift:454` 주석 |

워치 앱이 죽었을 때 남은 세션이 어떻게 되는지는 <span style="color:#e5534b">미확인</span>이다. 되찾는 코드가 워치 쪽에 없다는 것만 확인했다.

---

## 예전 구조에서 보이던 증상

v1.0 을 준비하던 6월의 구조에서는 아이폰이 워치가 보낸 미러링 세션을 받아 자기 세션 자리에 넣었다. 커밋 `39e1feb` 의 코드다.

```swift
// RunWay/Services/HealthKitService+iOS.swift (39e1feb)
func retrieveRemoteSession() {
    store.workoutSessionMirroringStartHandler = { mirroredSession in
        Task { @MainActor in
            self.session = mirroredSession
            self.session?.delegate = self
            self.runningMode = .mirrored
            self.startOrigin = .remote

            if mirroredSession.state == .running {
                self.handleiOSStateChange(.running)
            }
        }
    }
}
```

미러링 세션이 들어오면 아이폰은 "워치가 러닝을 시작했구나"라고 받아들이고 PFD 화면으로 넘어간다. 정상 흐름에서는 이게 맞는 동작이다.

#### workoutSessionMirroringStartHandler로 미러링 세션 받기

[`workoutSessionMirroringStartHandler`](https://developer.apple.com/documentation/healthkit/hkhealthstore/workoutsessionmirroringstarthandler){:target="_blank"}는 워치가 미러링을 시작했을 때 아이폰 쪽에서 불리는 블록이다.

| 성질 | 내용 | 출처 |
|---|---|---|
| 등록 시점 | 앱이 켜지면 곧바로 등록해 두라고 권한다 | SDK 헤더 |
| 앱이 꺼져 있을 때 | 시스템이 아이폰 앱을 뒤에서 깨운다 | SDK 헤더 |
| 건네받는 것 | mirrored 종류의 세션 객체 | SDK 헤더 |
| 불리는 횟수 | 여러 번 불릴 수 있고, 그때마다 새 세션 객체를 건넨다 | 애플 문서 |

마지막 줄이 문제의 출발점이다. 부르는 쪽은 시스템이라서 **언제 몇 번 불릴지를 앱이 정하지 못한다.**

---

### 로그에 찍힌 재실행 직후

당시에는 러닝 도중 아이폰 앱만 강제종료한 뒤 다시 켜는 순서로 재현했다. 워치 앱은 건드리지 않았고, 워치는 PFD 화면에 그대로 남아 있었다. 재실행 직후 통합 로그에는 이렇게 찍혔다.

```
15:29:31.536163  retrieveRemoteSession fired, mirroredSession state: 2
15:29:31.536207  RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
15:29:41.958224  retrieveRemoteSession fired, mirroredSession state: 2
15:29:41.999140  RunViewModel received state=running, startOrigin=Optional(RunWay.StartOrigin.remote), stopOrigin=nil
```

`state: 2` 는 `.running` 이다. 앱을 다시 켰을 뿐인데 시스템이 "돌고 있는 세션이 있다"며 미러링 세션을 다시 건넸고, 아이폰은 평소처럼 PFD 로 넘어갔다. 사용자가 보기에는 **끝낸 적 없는 러닝 화면이 앱을 켜자마자 뜨는 것**이다.

여기까지가 <span style="color:#2e9e4f">확인</span>이다. 워치 앱도 죽어 있었는데 왜 세션이 `.running` 으로 남아 있었는지는 운동 세션의 성질 그대로다. 장부를 쥔 건 시스템이고, 워치 앱은 이름을 지우지 못하고 나갔다.

---

## 세 번의 조치와 실패 원인

6월 말부터 7월 초까지 세 가지를 시도했다. 이 코드들은 저장소에 남아 있지 않고(커밋 `27e3ee1` 은 README 만 고쳤다), 당시 글에 코드와 로그가 남아 있다.

| 시도 | 방법 | 결과 | 막힌 지점 |
|---|---|---|---|
| 1 | 시작한 지 5초가 넘은 미러링 세션이 들어오면 `session = nil` 로 무시 | <span style="color:#e5534b">실패</span> | PFD 가 그대로 뜸 |
| 2 | "직전에 러닝 중이었다"는 표시를 저장해 두고, 재실행 때 들어온 미러링 세션에 `end()` | <span style="color:#e5534b">실패</span> | 표시가 다음 재실행에서 덮여 HOME 과 PFD 를 번갈아 감. `end()` 뒤에 핸들러가 연달아 다시 불림 |
| 3 | 앱이 켜진 시각과 세션 시작 시각을 비교해 옛 세션을 가려냄 | <span style="color:#d29922">판별만 성공</span> | 가려낸 뒤에 할 수 있는 일이 없음 |

시도 3 의 판별은 정확했다. 로그에서 세션 시작 시각이 앱 실행 시각보다 12초 앞선 것으로 찍혔다.

```
09:53:31.268125  zombie check: sessionStart=1782780799.559969, appLaunchTime=1782780811.202153, isNewSession=false
```

문제는 그다음이었다.

![지난 러닝의 미러링 세션을 무시하면 새 미러링이 오지 않고 end 를 부르면 워치 세션이 끝나거나 핸들러가 연달아 다시 불린다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-23-RunningProject-60/runway-60-zombie-dilemma.png)

`end()` 를 불렀을 때의 로그다. 11밀리초, 5밀리초 간격으로 같은 일이 되풀이된다.

```
09:58:22.322114  retrieveRemoteSession: wasZombieSuspected=true, state=2
09:58:22.322266  zombie session detected - ending it
09:58:22.333930  retrieveRemoteSession: wasZombieSuspected=true, state=2
09:58:22.333962  zombie session detected - ending it
09:58:22.338567  retrieveRemoteSession: wasZombieSuspected=true, state=2
09:58:22.338675  zombie session detected - ending it
```

반대로 무시하면 화면은 HOME 에 머물지만, 그 뒤 워치에서 새 러닝을 시작해도 핸들러가 불리지 않았다. 둘 다 당시 로그와 실기기에서 <span style="color:#2e9e4f">확인</span>한 관찰이다.

---

### 판별이 아니라 권한의 문제

세 시도는 방법이 달랐지만 같은 벽에 부딪혔다. **아이폰이 쥔 것은 미러링 세션이고, 끝내려던 원래 세션은 워치에 있었다.**

SDK 헤더에는 이 관계를 짐작하게 하는 문장이 두 군데 있다.

```objc
// HKWorkoutSession.h
// stopMirroringToCompanionDevice 설명
// "When a workout session is ended, mirroring is automatically stopped."

// workoutSession:didDisconnectFromRemoteDeviceWithError: 설명
// "After this method is called for a mirrored workout session, it is no longer considered valid."
```

세션이 끝나면 미러링이 멈추고, 연결이 끊긴 미러링 세션은 더 이상 유효하지 않다. 애플 문서는 연결이 끊기면 워치가 다시 연결을 시도한다고도 적는다. 이걸 이으면 로그의 연속 호출은 "아이폰이 미러링 세션을 끝냄, 워치의 원래 세션은 여전히 돌고 있음, 다시 연결, 새 미러링 세션이 들어옴"의 되풀이로 읽힌다. 이 해석은 <span style="color:#d29922">추론</span>이다. 미러링 세션에 `end()` 를 부르면 워치의 원래 세션이 어떻게 되는지는 애플 문서에 적혀 있지 않다. [`end()`](https://developer.apple.com/documentation/healthkit/hkworkoutsession/end%28%29){:target="_blank"} 문서는 "Ends the workout session." 한 줄이 전부다.

정리하면 6월의 접근은 옛 세션을 얼마나 정확히 가려내느냐에 힘을 썼는데, 정확히 가려내도 소용이 없었다. 남의 장부에 적힌 이름을 내가 지울 수 없었던 것이다.

---

## 구조 변경으로 사라진 증상

그 뒤로 RunWay 는 세션을 주고받는 방식 자체를 바꿨다.

![예전에는 아이폰이 워치의 미러링 세션을 쥐었고 지금은 아이폰과 워치가 각자 자기 세션을 가진다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-23-RunningProject-60/runway-60-session-owner.png)

| 시점 | 커밋 | 바뀐 것 |
|---|---|---|
| 2026-09-06 (v1.3.2) | `122bcff` | 미러링 러닝이면 아이폰 쪽 기록을 버리도록 `discardWorkout()` 추가 |
| 2026-10-01 (v1.4) | `62c476a` | 아이폰이 미러링 세션을 받는 함수와 그 등록 호출을 삭제 |
| 2026-10-18 (v1.4.1) | 태그 `0a23f5b` | 위 두 가지가 들어간 배포판 |

지금 아이폰은 미러링 세션을 받지 않는다. 자기 세션을 직접 만들고, 끝낼 때도 자기 세션만 끝낸다.

```swift
// RunWay/Services/HealthKitService+iOS.swift (v1.4.1)
if toState == .stopped {
    // 미러링 중이면 Apple Health 저장은 Watch의 builder가 한다. iPhone의 builder를
    // 그대로 두면 시스템이 이것까지 마감해 저장해서, 같은 러닝이 건강 앱에 두 번 남는다.
    if runningMode == .mirrored {
        builder?.discardWorkout()
    }
    session?.end()
    // 생략
}
```

#### discardWorkout으로 아이폰 기록 버리기

[`discardWorkout()`](https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/discardworkout%28%29){:target="_blank"}은 모으던 데이터를 저장하지 않고 버린다.

| 호출 | 하는 일 | RunWay 에서 부르는 쪽 |
|---|---|---|
| `discardWorkout()` | 수집을 멈추고 결과를 저장 없이 버림 | 아이폰 (워치와 함께 뛴 러닝일 때) |
| `finishWorkout()` | 모은 데이터를 운동 기록으로 저장 | 워치 |
| `end()` | 세션을 끝냄. 끝난 세션은 다시 쓸 수 없음 | 양쪽 각자 |

양쪽은 이제 WatchConnectivity 로 "끝났다"는 신호만 주고받는다. 재실행 때 미러링 세션이 들어올 통로가 없으니 **PFD 직행은 일어날 수 없다.** 이건 <span style="color:#2e9e4f">확인</span>이다. v1.4.1 과 지금 작업 중인 브랜치 어디에도 `workoutSessionMirroringStartHandler` 를 등록하는 코드가 없다.

한 가지 남은 흔적이 있다. 아이폰이 시작한 러닝에서 워치는 여전히 미러링을 시작한다(`HealthKitService.swift:139`). 받는 쪽이 없는 미러링이 무슨 일을 하는지는 <span style="color:#e5534b">미확인</span>이다.

---

## 지금도 남는 것

증상 하나가 사라졌을 뿐 세션이 남는 일은 그대로다. 강제종료된 앱은 아무 코드도 실행하지 못하므로 `end()` 를 부를 기회가 없다. 남는 것은 네 가지다.

| 남는 것 | 내용 | 근거 |
|---|---|---|
| 아이폰의 끝나지 않은 세션 | 시스템이 나중에 마감해서 건강 앱에 운동 기록으로 저장한다. 30m 만 가다 버린 러닝도 저장됐다 | <span style="color:#2e9e4f">확인</span> 실기기 (워치를 끄고 아이폰만으로 뛴 러닝) |
| 워치의 멈춘 숫자 | 아이폰이 보내던 값이 끊겨 마지막 숫자에서 멈춘다. 세션은 계속 돈다 | <span style="color:#2e9e4f">확인</span> 코드. 실기기로는 <span style="color:#e5534b">미확인</span> |
| 부풀어 오른 워치 기록 | 워치에서 뒤늦게 끝내면 방치한 시간까지 운동 시간에 들어간다 | <span style="color:#2e9e4f">확인</span> 코드 |
| 같은 러닝의 기록 두 건 | 아이폰 쪽 `discardWorkout()` 을 못 부르고 죽었으니 양쪽이 각각 저장될 수 있다 | <span style="color:#e5534b">미확인</span> |

워치가 PFD 화면에 남은 채 숫자만 멈추는 이유는 아이폰 주도 러닝에서 워치가 표시 장치로만 움직이기 때문이다. 워치의 타이머와 15초 무소식 감시는 `start()` 안에 있는데, 이 함수는 워치에서 직접 이륙할 때만 불린다(`WatchTakeoffView.swift:165`). 아이폰이 시작한 러닝에서는 워치 쪽에 감시가 아예 없다.

반대 방향의 감시는 그 사이에 생겼다. 아이폰은 워치에서 오던 건강 데이터가 끊기면 러닝이 끝난 것인지 묻는다(`RunViewModel.swift:426-440`). 묻기만 하고 자동으로 끝내지는 않는다.

---

### 다음 러닝이 옛 세션을 덮는 경로

남은 워치 세션 위에서 아이폰으로 새 러닝을 시작하면 어떻게 되는지도 봤다. 워치는 아이폰의 시작 요청을 이렇게 받는다.

```swift
// RunWayWatch Watch App/Services/AppDelegate.swift (v1.4.1)
func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task {
        do {
            HealthKitService.shared.startOrigin = .remote
            try await HealthKitService.shared.startWorkout(workoutConfiguration: workoutConfiguration)
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.workoutSessionFailed)
        }
    }
}
```

돌고 있는 세션이 있는지 보지 않고 새 세션을 만든다. `startWorkout` 은 `session` 변수에 새 세션을 그대로 덮어쓴다(`HealthKitService.swift:121`). 옛 세션은 `end()` 도 `finishWorkout()` 도 받지 못한 채 앱의 손을 떠난다.

애플 문서는 이 상황을 이렇게 적는다.

> "Apple Watch runs one workout session at a time."
>
> [HKWorkoutSession](https://developer.apple.com/documentation/healthkit/hkworkoutsession){:target="_blank"}, Apple Developer Documentation

두 번째 운동이 시작되면 먼저 돌던 세션은 오류를 받고 끝난다고 이어서 설명한다. 그러니 옛 세션은 시스템이 끝내 줄 것으로 보인다. 다만 그 오류는 RunWay 의 `didFailWithError` 로 들어오고, 이 함수는 "Workout Session Error" 알림을 띄운다. 새 러닝을 막 시작한 화면에 오류 알림이 뜰 수 있다는 뜻이다. 이 흐름은 <span style="color:#d29922">추론</span>이고 실기기에서는 <span style="color:#e5534b">미확인</span>이다.

---

## 옛 글 두 편과 달라진 점

공개하지 않은 두 글의 서술을 지금 코드에 대 보니 맞는 것과 낡은 것이 섞여 있었다.

| 옛 글의 서술 | 지금 코드 | 판정 |
|---|---|---|
| 세 시도가 막힌 건 남의 세션을 정리하려 했기 때문이다 | SDK 헤더의 primary 와 mirrored 구분, 끊긴 미러링 세션은 유효하지 않다는 문장이 이 설명을 받쳐 준다 | <span style="color:#2e9e4f">유효</span> |
| 구조가 바뀌면서 남는 세션의 주인이 워치에서 아이폰으로 바뀌었다 | 아이폰이 자기 세션을 만든다 (`HealthKitService.swift:121`) | <span style="color:#2e9e4f">유효</span> |
| 아이폰 주도 러닝에서 워치는 표시 장치다 | `start()` 호출은 지금도 `WatchTakeoffView.swift:165` 한 곳 | <span style="color:#2e9e4f">유효</span> |
| 워치의 마감 순서는 `endCollection`, `finishWorkout`, `end` | 9월 30일 커밋 `2614402` 에서 `end` 가 맨 앞으로 옴 | <span style="color:#e5534b">낡음</span> |
| Live Activity 정리 코드는 필요 없었다. 재실행하면 시스템이 정리한다 | 앱이 켜질 때 남은 Live Activity 를 전부 끝내는 코드가 있다 (`RunViewModel.swift:255-259`) | <span style="color:#e5534b">코드와 어긋남</span> |
| 재현 순서에 "워치 앱과 아이폰 앱을 둘 다 강제종료"라고 적었다 | 실제로는 아이폰 앱만 종료했다. 같은 글의 증상 요약과 README 도 아이폰만 종료하는 경우를 적는다 | <span style="color:#e5534b">잘못 적음</span> |
| 제안: 워치에 신호 끊김 안내, 마감 시각 보정, 아이폰 저장 조건 완화 | 셋 다 코드에 없다. 반대 방향인 아이폰 쪽 질문만 생겼다 | <span style="color:#d29922">미적용</span> |
| 제안: 앱 실행 때 남은 세션을 되찾아 정리 | `recoverActiveWorkoutSession` 을 부르는 곳이 없다 | <span style="color:#d29922">미적용</span> |

Live Activity 줄은 따로 적어 둘 만하다. 글과 README 는 "시스템이 정리해 준다"고 하는데 코드는 직접 정리한다. 둘 중 어느 쪽이 실제로 일하고 있는지는 그 코드를 빼고 돌려 봐야 안다. 지금은 <span style="color:#e5534b">미확인</span>이다.

당시 로그를 찍으려고 만든 `ZombieSessionLogger` 도 저장소에 남아 있는데, 부르는 곳이 하나도 없다.

---

## 심각도와 우선순위

결과만 보면 RunWay 에 남아 있는 문제 중 가장 무겁다. 러닝 기록이 앱에는 안 남고 건강 앱에만 남으며, 워치는 사용자가 직접 끝낼 때까지 세션을 붙들고 있다.

그런데 조건이 좁다. 아이폰에서 시작한 러닝 도중에 아이폰 앱이 죽어야 한다. 뛰는 중에 앱 스위처를 열어 앱을 밀어 올리는 사람은 거의 없다. 그래서 1.4.1 에서는 고치지 않고 알려진 한계로 둔다.

다만 사용자가 일부러 끄는 경우만 있는 건 아니다. 앱이 충돌해도 같은 상태가 된다(<span style="color:#d29922">추론</span>, 실기기로 본 것은 아니다). 그래서 "일어나지 않는다"가 아니라 "드물다"로 적는다.

고칠지, 어디까지 고칠지는 아래 실기기 점검 결과를 보고 정한다.

---

## 조치 방안 비교

"앱 코드로는 못 막는다"는 6월의 결론은 아이폰이 미러링 세션을 받던 구조에서는 맞았다. 지금은 남는 세션이 자기 세션이라 사정이 다르다. 손댈 수 있는 자리가 다섯 군데 보인다.

| 방안 | 하는 일 | 좋은 점 | 걸리는 점 |
|---|---|---|---|
| 가 | 아이폰 앱이 켜질 때 남은 세션을 되찾아 버린다 | 버린 러닝이 건강 앱에 쌓이지 않는다 | 실기기 확인이 먼저다. 아이폰만으로 뛴 러닝 기록까지 버릴 수 있다 |
| 나 | 워치가 아이폰 신호가 끊긴 걸 알아채고 사용자에게 묻는다 | 숫자가 왜 멈췄는지 사용자가 알 수 있다 | 주머니 속에서 잠깐 끊긴 것과 구분이 안 된다. 묻기만 해야 한다 |
| 다 | 워치가 새 러닝 요청을 받으면 돌던 세션부터 마감한다 | 덮어쓰기와 오류 알림 가능성을 없앤다. 범위가 작다 | 마감에 걸리는 시간만큼 시작이 늦어진다 |
| 라 | 워치 앱이 켜질 때 남은 세션을 되찾는다 | 워치 앱이 죽은 경우를 덮는다 | 되찾은 뒤 이어 갈지 끝낼지 정해야 한다 |
| 마 | 코드는 두고 문서만 지금 상태에 맞게 고친다 | 위험이 없다 | 증상은 그대로다 |

방안 가와 라가 쓰는 것이 [`recoverActiveWorkoutSession(completion:)`](https://developer.apple.com/documentation/healthkit/hkhealthstore/recoveractiveworkoutsession%28completion:%29){:target="_blank"}이다.

```objc
// HKHealthStore.h
// "Recovers an active workout session after a client crash. If no session is available
//  to be re-attached, nil will be returned."
- (void)recoverActiveWorkoutSessionWithCompletion:(...)completion
    API_AVAILABLE(ios(26.0), watchos(5.0));
```

#### recoverActiveWorkoutSession으로 남은 세션 되찾기

| 성질 | 내용 | 근거 |
|---|---|---|
| 지원 버전 | watchOS 5.0, iOS 26.0 | <span style="color:#2e9e4f">확인</span> SDK 헤더 |
| 문서가 말하는 상황 | 앱이 충돌한 뒤 다음 실행 | <span style="color:#2e9e4f">확인</span> 애플 문서 |
| 되찾은 뒤 할 일 | builder 를 다시 얻고 data source 와 delegate 를 다시 붙인다 | <span style="color:#2e9e4f">확인</span> 애플 문서 |
| 사용자가 강제종료한 경우 | 문서에 없다 | <span style="color:#e5534b">미확인</span> |
| 아이폰에서의 사용법 | 문서 본문은 워치 기준으로만 설명한다 | <span style="color:#e5534b">미확인</span> |

헤더가 "client crash" 라고 적은 것이 걸린다. 충돌과 사용자의 강제종료를 시스템이 같게 다루는지는 문서로는 알 수 없다. 그래서 방안 가는 코드보다 실기기 확인이 먼저다.

지금 판단으로 권하는 순서는 **다, 나, 가**다. 다는 범위가 가장 작고 되돌리기 쉽다. 나는 사용자가 실제로 겪는 혼란(숫자가 멈춘 PFD 화면)을 줄인다. 가는 효과가 가장 크지만 확인할 것이 가장 많다.

---

## 아직 확인 못 한 것

실기기로 봐야 닫히는 항목만 모았다.

| # | 확인할 것 | 보는 방법 |
|---|---|---|
| 1 | 아이폰 주도 러닝 중 아이폰 앱을 강제종료하면 건강 앱에 기록이 두 건 남는가 | 강제종료 뒤 워치에서 끝내고, 건강 앱에서 기기별 기록 수를 센다 |
| 2 | 남은 워치 세션 위에서 새 러닝을 시작하면 오류 알림이 뜨는가 | 1번 상태에서 워치를 끝내지 않고 아이폰에서 새 러닝을 시작한다 |
| 3 | 워치 앱이 러닝 중에 죽으면 세션이 얼마나 남는가 | 워치 앱을 강제종료하고 건강 앱에 기록이 추가되는 시각을 본다 |
| 4 | 강제종료 뒤에도 `recoverActiveWorkoutSession` 이 세션을 돌려주는가 | 실행 직후 한 번 불러 결과를 로그로 남긴다 (코드 추가 필요) |
| 5 | 받는 쪽 없는 워치의 미러링 시작이 성공하는가, 실패하는가 | 워치 쪽 `mirroring failed` 로그가 찍히는지 본다 |
| 6 | Live Activity 는 앱의 정리 코드 없이도 사라지는가 | 정리 코드를 잠시 빼고 강제종료와 재실행을 해 본다 |
| 7 | 아이폰 앱을 강제종료한 뒤 워치 PFD 의 시간과 거리가 실제로 멈추는가 | 강제종료 뒤 워치 화면의 경과 시간이 계속 올라가는지 본다 |

1번부터 3번까지와 7번은 코드를 건드리지 않고 볼 수 있다. 앞의 조치 방안 중 무엇을 고를지는 이 세 가지 결과에 달려 있다. 두 건이 남지 않고 오류 알림도 뜨지 않는다면 방안 마(문서만 고치기)로도 충분하다.

워치 러닝이 몇 초 만에 끝나 버리는 건과는 방향이 반대다. 그쪽은 세션이 너무 일찍 없어지고, 이쪽은 세션이 너무 오래 남는다. 다만 이쪽이 그쪽의 재료가 될 수는 있다. 강제종료 상황에서는 종료 신호가 제때 가지 못하고 뒤늦게 도착하는데, 늦게 도착한 종료 신호는 그 건의 둘째 용의자였다. 이 연결도 <span style="color:#d29922">추론</span>이다.
