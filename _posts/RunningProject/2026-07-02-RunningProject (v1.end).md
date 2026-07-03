---
title: RunWay 개발 회고 - GitHub Issue로 돌아보는 5주
writer: Harold
date: 2026-07-02 04:00:00 +0900
categories: [RunWay]
tags: [회고, Retrospective]
last_modified_at: 2026-07-03 18:33:00 +0900

toc: true
toc_sticky: true
published: true
---

RunWay를 만들면서 매일 GitHub Issue에 그날 겪은 문제와 해결 과정을 댓글로 남겼다. 이슈만 23개, 댓글은 그보다 훨씬 많다. App Store 심사 제출을 앞둔 지금, 이 기록들을 Week 단위로 압축해서 5주 전체를 한 번에 돌아본다.

세세한 코드 diff는 각 Day별 포스트나 [README](https://github.com/Haroldfromk/RunWay)에 있으니, 여기서는 "무슨 일이 있었고 어떻게 풀었는가"에 집중한다.

---

## Week 1 - Engine Installation

SwiftData 모델 3개(Flight, Gear, User)로 시작했지만 설계를 다듬으며 Gear와 User를 걷어냈다. MVP엔 불필요했고, User는 온보딩 구현 시점으로 미뤘다.

CoreLocation 서비스를 붙이는 과정에서 예상 못 한 곳에서 막혔다. Info.plist에 Dictionary 타입 키(`NSLocationTemporaryUsageDescriptionDictionary`)를 Xcode Target 설정 UI로 편집하려 하면 Xcode 자체가 죽었다. 버전을 낮춰봐도 소용없었고, 결국 `Info.plist Generate`를 끄고 파일을 수동으로 관리하는 쪽으로 방향을 틀었다. Capabilities 설정할 때 튕기던 문제도 이 김에 같이 해결됐다.

Week 1의 진짜 핵심은 마지막 날 발견한 구조적 문제였다. 각 View가 `LocationService`, `HealthKitService`를 따로 생성하고 있어서 같은 인스턴스를 공유하지 못했다. `RunWayApp.swift`에서 단일 인스턴스를 만들어 environment로 내려보내는 구조로 정리했는데, 이게 나중에 RunningCenter Actor로 가는 길목이 됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-03-RunningProject-21/1week.png){: width="50%" height="50%"}

---

## Week 2 - Cockpit & Take-off

Week 2는 지금 돌아보면 나중에 반복해서 마주칠 문제들의 "최초 발견" 지점이 몰려있는 주였다.

**RunningCenter Actor를 도입한 이유**부터가 명확했다. 위치 업데이트가 자동으로 Actor에 전달되는 구조가 없어서 실시간 거리 계산이 아예 안 됐다. Combine `PassthroughSubject`로 위치 데이터를 흘려보내고 Actor가 구독하는 구조로 바꾸면서, `CoreLocation/HealthKit/WatchConnectivity(Publisher) -> RunningCenter(Actor) -> AsyncStream -> ViewModel -> SwiftUI`라는 지금의 데이터 흐름이 이때 확정됐다.

여기서 AsyncStream을 잘못 쓰고 있다는 것도 처음 발견했다. `streamFlightData`를 위치 업데이트마다 호출하니 매번 새 스트림과 새 Task가 생겼다. Instruments로 확인하고서야 심각성을 깨달았고, continuation을 Actor 프로퍼티로 저장해 스트림을 한 번만 여는 구조로 고쳤다.

`elapsedTime`을 어디서 관리할지 고민하다 ViewModel Timer로 정했는데 - 이 결정이 나중에 Timer 재시작 버그의 씨앗이 됐다. `connect()`가 1회성이라는 걸 몰랐던 게 원인이었고, 정지 후 재시작하면 타이머가 죽는 문제를 겪고 나서야 `autoconnect()` + `sink` 패턴으로 바꿨다.

GPWS 로직을 붙이면서는 `simultaneousGesture`를 NavigationLink 안에 넣었더니 실기기에서 long press로만 반응하는 버그를 만났다(이건 Week 3에서 위치를 바깥으로 옮겨야 진짜로 해결됐다). 러닝 시작 직후 무효한 페이스로 GPWS가 즉시 트리거되는 문제도 발견해서 `isReachedPace` 플래그로 막았다.

SwiftData 모델도 이 주에 구조가 잡혔다. `Flight` struct는 `@Model`이 class만 지원해서 `SwiftDataFlight` class로 분리했고, 좌표는 튜플 배열을 직접 저장할 수 없어서 `SwiftDataCoordinate`로 따로 뺐다. Actor에서 ModelContext에 직접 접근하려니 `@MainActor` 격리 문제가 나서, 저장은 View 레벨에서 처리하는 걸로 정리했다.

실기기 테스트에서 한 번에 8개 이슈가 쏟아졌다 - 버튼 먹통, 거리 누적, GPWS 연속 발생, 페이스가 100분대로 튐, MINIMUMS 오작동, 신호 대기 시 일시정지 없음, GPS 보정 부재. 마지막 것(GPS raw data 보정 없음)이 근본 원인으로 지목됐고, 이게 Week 3 전체의 주제가 됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-03-RunningProject-21/2week.png){: width="50%" height="50%"}

---

## Week 3 - Avionics

Week 3는 "페이스 흔들림을 잡는 것"과 "미러링을 만드는 것" 두 축으로 진행됐다.

### 페이스 smoothing, 세 번 갈아엎기

1차: GPS raw data에 timestamp/horizontalAccuracy 필터를 걸었다. `distanceFilter`도 5에서 10으로, IIR 필터(β=0.15)도 처음 적용했다.

2차 실기기 테스트에서 여전히 페이스가 튀었다. β를 0.25로 올렸지만 초반 30초 수렴 지연은 그대로였다. 원인은 `location.speed` 초기값이 0이라 IIR이 수렴하는 데 시간이 걸리는 구조적 문제였고, 여기에 음수 speed 미보정까지 겹쳐 있었다. 두 AI의 의견을 교차 검증해서 `max(speed, 0)` 보정과 "초기값이 0이고 유효한 speed가 들어왔을 때만 초기화"하는 조건으로 정리했다.

PAUSE(자동 일시정지)는 아예 감지 방식 자체를 바꿨다. 거리 기반(`detectPause`, Actor 경유)으로는 `distanceFilter=5` 환경에서 정지 시 GPS 업데이트 자체가 안 와서 감지가 불가능했다. ViewModel 타이머 콜백에서 `lastReceivedTime`을 직접 체크하는 시간 기반(5초 타임아웃)으로 바꾸고 나서야 정상 작동했다.

3차 테스트에서 두 문제 다 해결을 확인했다.

### FlightPhase 5단계 복원, 그리고 홈 버튼 먹통을 두 번 고친 이야기

`takeoff`, `approach` 케이스를 추가해 5단계 FlightPhase를 복원했다. Dynamic Island가 이 5단계를 다 참조하고 있어서 필요했던 작업이다.

HomeView 버튼이 안 눌리는 문제는 두 번 손봤다. 1차로 `.id`를 NavigationStack이 아니라 TabView에 붙여서 해결했다고 생각했는데, navigationDestination 경고가 계속 남았다. 결국 `AppState.sessionID` 방식 자체를 걷어내고 `[FlightDestination]` 배열 기반 단일 네비게이션 파이프라인으로 다시 짰다. 지금 구조의 근간이 이때 잡혔다.

### 미러링, 처음 만들다

Watch → iPhone 단방향으로 시작했다. `SharedModels.swift`로 FlightPhase, GPWSState 등을 iPhone/Watch/Widget 타겟에 공유하는 구조를 잡았는데, 이게 한 번에 끝나지 않고 FlightData, ModeA까지 추가로 옮기면서 두 번 정리해야 했다.

`transferUserInfo`로 Watch 단독 러닝 결과를 iPhone에 넘기는 것도 이때 붙였는데, 실기기 테스트에서 좌표 배열이 아예 전송이 안 되는 걸 발견했다. `CLLocationCoordinate2D` 배열을 직접 전달할 수 없어서 `[[Double]]`로 직렬화해야 하는데 그 처리 자체가 빠져 있었다.

Week 3 막바지, 미러링 관련 이슈가 한 번에 7개 터졌다 - PFD 자동 전환 간헐적 실패, 데이터 수신 실패, 거리 단위 오류, 좌표 미전송, 표시값 불일치, 종료 동기화 미작동. 이 무더기가 Week 4를 미러링 아키텍처 재설계로 몰아넣은 배경이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-03-RunningProject-21/3week.png){: width="50%" height="50%"}

---

## Week 4 - Analysis & Stability

Week 4는 세 개의 큰 이야기로 이뤄져 있다.

### 미러링 아키텍처, 다시 설계하다

Week 3에서 터진 7개 이슈를 하나씩 고치다 보니, 근본 원인이 하나로 모아졌다. 미러링 중에도 iPhone과 Watch가 각자 독립적으로 GPS를 수집하고 계산하는 구조 자체가 문제였다. Watch가 먼저 시작해도 iPhone이 GPS 락을 새로 잡느라 화면 전환이 늦었다.

시작 주체 구분용으로 쓰던 `startOrigin`을 위치 추적 활성화 기준으로 확장했다. 주도 기기(`.local`)만 GPS를 켜고 계산해서 상대에게 전송, 미러링 기기(`.remote`)는 받아서 표시만 하는 구조로 바꿨다. 이 과정에서 `sendFlightData()`가 iOS 쪽에만 구현돼 있어 Watch 주도 미러링에서 Watch가 계산한 데이터를 iPhone에 보낼 경로 자체가 없었다는 숨은 허점도 발견했다.

### iPhone 주도 미러링을 만들면서 겪은 연쇄 문제

iOS 26부터 `HKLiveWorkoutBuilder`가 지원되면서 iPhone도 직접 워크아웃 세션을 만들 수 있게 됐다. Deployment Target을 18.5에서 26으로 올리는 결정을 이때 내렸다.

iPhone 주도 미러링을 실제로 붙이면서 여러 문제가 연쇄적으로 터졌다.

- `@WKApplicationDelegateAdaptor`가 자체적으로 `HealthKitService` 인스턴스를 새로 만들어서, 기존 DI 방식으로는 인스턴스가 어긋났다. Apple 샘플처럼 싱글톤으로 전환하면서, 이참에 iPhone/Watch에 따로 있던 `HealthKitService`를 하나로 합치고 공통/+iOS/+watchOS 파일로 나눴다.
- `NavigationViewModel` 분리를 롤백했다. 애초에 watchOS NavigationStack 경고를 잡으려고 분리했던 건데, 경고 자체는 안 잡히고 구조만 복잡해져서, `WatchViewModel`이 다시 `navigationPath`를 직접 갖는 구조로 되돌렸다.
- iOS 26으로 올리고 나니 iPhone이 직접 워크아웃을 시작해도 Watch에 운동 링이 자동으로 뜨는 시스템 동작이 새로 생겼다. 기존 `isRemoted` 플래그가 신호의 출처(Watch 미러링인지 iPhone 직접 시작인지)를 구분 못 해서, iPhone 단독 러닝에서도 종료 시 자동으로 홈으로 튕기는 문제가 생겼다.

여기서 `SessionStateEvent`, `RunningMode`, `StartOrigin`, `StopOrigin` 모델링이 나왔다. `HKWorkoutSessionState`를 도메인 모델로 추상화해 HealthKit 의존성을 분리하고, 시작 주체와 종료 주체를 별도 값으로 나눴다. iPhone과 Watch가 실제로는 독립된 두 개의 `HKWorkoutSession`이라는 걸 확인하고, `sendMessage()` 기반 명시적 종료 신호로 동기화하는 방향을 잡았다.

이 과정에서 `nonisolated` 누락으로 인한 실기기 전용 크래시도 2건 나왔다. 클래스는 `nonisolated`로 선언했는데 extension 안 delegate 메서드 각각에는 명시를 안 해서, Xcode 26의 기본 액터 격리 설정 때문에 다시 `@MainActor`로 추론되는 문제였다.

### 좀비 세션, 그리고 못 푼 문제를 인정하기까지

미러링 중 iPhone을 강제종료하면 Watch는 정상적으로 홈에 복귀하지만, iPhone을 재실행하면 PFD 화면이 그대로 남아있고 GPS가 다시 시작되는 문제를 처음 발견한 게 Day 17이었다.

`startDate` 기반 5초 경과 판별을 처음 시도했는데, `.end()`로 좀비 세션을 종료시키니 Watch 쪽 진짜 세션까지 같이 끊기는 부작용이 났다. `.end()` 없이 무시만 해봐도 여전히 PFD가 남았다. 디버거가 강제종료 직후 끊긴다는 근본적인 제약 때문에 검증 자체가 막혔다.

Day 19에 `os_log`/Console.app으로 재도전했다. `healthd`가 앱 재실행 시점에 `workoutSessionMirroringStartHandler`를 재트리거하면서 살아있는 세션을 다시 `.running`으로 전달한다는 걸 확정했다. `UserDefaults` 플래그로 판별을 시도했지만 `healthd`가 추가로 발행하는 `.stopped` 이벤트에 플래그가 덮어써졌다. `appLaunchTime` 비교로 정밀 판별에는 성공했지만, 좀비를 무시하면 Watch에서 새 미러링 자체가 안 되고, `.end()`로 정리하면 부작용이 재발하는 딜레마에 부딪혔다.

`HKWorkoutSession`이 시스템 데몬 레벨 자원이라 앱 코드로는 완전한 제어가 불가능하다는 결론을 내렸다. 관련 코드를 전부 롤백하고 known limitation으로 남겼다. 로깅 인프라(`ZombieSessionLogger`)만 향후를 위해 남겨뒀다.

### 전체 실기기 테스트

미러링 아키텍처를 다 갈아엎은 뒤 전체 테스트를 돌리니 마무리 버그들이 나왔다. 일시정지 상태가 미러링 기기에 전달되지 않던 문제, `resetWorkout()`에서 `startOrigin`/`stopOrigin` 초기화가 빠져서 특정 순서로 미러링을 반복하면 다음 미러링이 안 되던 문제, 탭바로 갑자기 이탈해도 상태가 정리 안 되던 문제까지 - `.onDisappear` + boolean 플래그 패턴을 5개 View에 동일하게 적용해서 정리했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-03-RunningProject-21/4week.png){: width="50%" height="50%"}

---

## Week 5 - Release

App Store 출시 준비. 스크린샷 캡처(iPhone 6장, Watch 3장), 앱 설명/키워드/연령 등급 작성, 온보딩에 개인정보 처리방침 동의 페이지 추가(한/영/일 언어 전환 지원), 포트폴리오 사이트 배포까지 끝냈다. TestFlight 외부 베타도 배포를 마쳐 공개 링크로 나가 있고, App Store Connect 등록(연령 등급, 개인정보 처리방침 URL, 한/영/일 지역화)도 완료했다.

가장 마지막에 손댄 건 `TakeoffView`였다. Pre-flight Check 체크리스트 4개 항목이 그동안 더미 값이었는데, 이걸 전부 실기기 센서로 교체했다. (07.03)

| 항목 | 소스 | 판정 기준 |
|---|---|---|
| GPS SIGNAL | `locationService.accuracy` | STRONG(10m 미만) / GOOD(30m 미만) / WEAK |
| APPLE WATCH | `WCSession.isReachable` | CONNECTED / NOT CONNECTED |
| BATTERY | `UIDevice.batteryLevel` | 20% 미만이면 경고 |
| WEATHER | 신규 `WeatherKitService` | GOOD/CLOUDY는 정상, RAIN/SNOW는 경고 |

GPS는 카운트다운 시작 전부터 락을 잡아둬야 해서 `start()`와 분리한 `prepareTracking()`을 `.task`에서 미리 호출하도록 했다. WeatherKit은 Apple Developer 포털에서 Capabilities와 App Services 탭 양쪽에 다 켜야 entitlement가 정상 동작한다는 걸 이번에 처음 알았다.

이걸로 Master Plan에 적어둔 항목은 다 끝났다. 남은 건 App Store 심사 제출뿐이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-v1.end/finalcut.png){: width="50%" height="50%"}

---

## 돌아보며

5주를 다시 훑어보니 몇 가지 패턴이 보인다.

**같은 문제를 두 번, 세 번 풀어야 했던 경우가 많았다.** 페이스 smoothing은 세 번, 홈 버튼 먹통은 두 번, 미러링 관련 타겟 공유도 두 번 손봤다. 처음부터 완벽한 구조를 잡기보다, 실기기에서 부딪혀보고 다시 설계하는 쪽이 더 빨랐다.

**Actor/AsyncStream 관련 실수는 전부 Week 2에서 처음 나왔다.** continuation 관리, Timer 재시작, 상태 초기화 - 이후 Week 4의 미러링 재설계에서 다시 마주친 문제들도 사실 이때 이미 한 번씩 겪은 패턴의 변주였다.

**못 푼 문제를 인정하는 것도 결정이었다.** 좀비 세션은 세 번의 시도 끝에 "이건 앱 레벨에서 해결 불가능한 구조적 문제"라고 결론 내리고 known limitation으로 남겼다. 계속 붙잡고 있는 것보다, 원인을 정확히 규명하고 다음으로 넘어가는 게 맞는 판단이었다고 생각한다.

트러블슈팅 각각의 상세한 코드와 다이어그램은 [포트폴리오 사이트](https://runway-project.vercel.app/)에 정리해뒀다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-03-RunningProject-21/Retrospective.png){: width="50%" height="50%"}