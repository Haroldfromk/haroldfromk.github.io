---
title: RunWay (27) App Store 리젝 대응하기
writer: Harold
date: 2026-07-15 20:10:00 +0900
categories: [RunWay]
tags: [App Store, HealthKit, WeatherKit, SwiftData]

toc: true
toc_sticky: true
published: true
---

26번 글에서 미러링 범위를 축소하고 재제출 준비까지 마쳤는데, 이번엔 다른 사유로 리젝을 받았다.

---

## 리젝 사유 - Guideline 2.1 Information Needed

버그가 아니라 "정보가 부족해서 심사를 계속할 수 없다"는 사유였다.

> **Guideline 2.1 - Information Needed - New App Submission**
>
> We need additional information to continue the review of this new app. To help us fully understand the app and conduct a complete review, app submissions should include relevant details in the App Review Information section in App Store Connect.
>
> **Next Steps**
>
> Reply in App Store Connect with all of the following information:
>
> 1. A screen recording captured on a physical device, running the latest operating system, demonstrating the app's functionality. The recording must begin with launching the app and show the typical user flow through its core features. If the app has any of the following, include them in the recording:
>    - Account registration, login, and account deletion flows
>    - Accessing paid content or features within the app, including any purchase or subscription flows
>    - User-generated content, including content reporting and blocking mechanisms
>    - Any prompts requesting access to sensitive data or device capabilities (for example, location, contacts, camera, or App Tracking Transparency)
> 2. A list of the device models and operating systems the app was tested on before submitting for review
> 3. A description of the app's purpose and target audience, including the problem it solves and the value it provides
> 4. Instructions for setting up and accessing the app's main features, including any required login credentials or sample files
> 5. A list of the external services, tools, or platforms the app uses to deliver its core functionality (for example, data providers, authentication services, payment processors, or AI services)
> 6. Describe any regional differences in the app's features or content, or confirm that the app functions consistently across all regions
> 7. If the app operates in a highly regulated industry or includes protected third-party material, provide any relevant documentation or credentials to demonstrate you are authorized to provide these services or protected material
>
> Include this information in the Notes field of the App Review Information section in App Store Connect for future submissions.

RunWay는 로그인 자체가 없는 앱이라, App Store Connect의 App Review Information "Notes" 필드가 비어있었다. 심사팀 입장에서는 "이 앱을 어떻게 써야 하는지" 알 방법이 없었던 거다. 계정 기반 앱이 아니어도 이 필드는 채워야 한다는 걸 이번에 배웠다.

---

## Notes 필드 채우기

2~7번은 이미 25번 글에서 App Store 리젝 위험 요소를 점검하며 정리해뒀던 내용(의료기기 아님, 서드파티 SDK 없음 등)을 그대로 재사용할 수 있었다. 새로 정리한 건:

- **앱 목적**: 항공정비사 배경 + "Turn Every Run Into A Flight" 컨셉, Mission Flight/Free Flight 두 모드
- **설정 방법**: 계정 없음, 온보딩 후 위치/HealthKit 권한만 승인하면 바로 사용 가능
- **외부 서비스**: HealthKit, CoreLocation, WeatherKit, WatchConnectivity, ActivityKit/WidgetKit, SwiftData - 전부 Apple 프레임워크, 서드파티 SDK 없음
- **테스트 기기**: iPhone 14 Pro Max (iOS 26.5), Apple Watch SE 2세대 GPS (watchOS 26.5)

처음 정리했을 때 4280자였는데 Notes 필드 제한(4000자)을 넘겨서, 중복 설명을 줄이고 문장을 압축해 3900자대로 맞췄다.

---

## 화면 녹화하다가 겪은 문제들

### 1. Apple Watch는 화면 녹화 버튼이 없다

iPhone은 컨트롤 센터에 화면 녹화가 있는데 watchOS엔 그런 게 없다. 정식 방법은 Mac의 Xcode → Window → Devices and Simulators에서 페어링된 실기기 Watch를 선택하면 녹화 버튼이 뜨는 거였다 (Watch에서 개발자 모드를 먼저 켜야 함).

---

### 2. 위치 권한 팝업이 녹화에 안 잡힌다

iOS 기본 화면 녹화(ReplayKit 기반)는 시스템이 앱보다 높은 권한으로 띄우는 위치 권한 팝업 같은 걸 못 찍는다. 결국 그 순간만 다른 폰 카메라로 따로 촬영해서 별도 파일로 첨부하기로 했다.

---

### 3. 권한 프롬프트를 다시 띄우려면

지금까지 계속 테스트하면서 권한을 이미 다 승인해놔서, 그냥 재실행해서는 프롬프트가 다시 안 뜬다. 앱을 삭제하면 위치 권한은 자동으로 초기화되는데, **HealthKit은 앱 삭제만으로는 초기화가 안 될 때가 있어서** 설정 → 개인정보 보호 및 보안 → 건강 → RunWay에서 따로 접근을 꺼줘야 확실했다.

결국 최종적으로 iPhone 권한 프롬프트(`appauth`), Watch 권한 프롬프트(`watchauth`), 실제 100m 정도 야외 러닝 녹화(`apprunning`) 이렇게 세 파일로 나눠서 제출하기로 했다. iPhone과 Watch가 동시에 돌아가는 미러링 특성상 두 기기 화면을 동시에 녹화할 방법이 없어서, 왜 파일이 세 개로 나뉘어 있는지는 별도로 설명을 적었다.

---

## Notes 필드와 Resolution Center 회신은 다른 자리다

다 정리하고 나서 헷갈렸던 부분. Apple 메시지 마지막 줄에 "Include this information in the Notes field... **for future submissions**"라고 적혀있는데, 이건 두 가지를 구분해야 한다는 뜻이었다.

- **Resolution Center 회신**: 이번 리젝에 대한 답장. 영상 3개 첨부하고, 왜 파일이 세 개로 나뉘었는지 같은 이번 건에만 해당하는 설명을 적는 곳.
- **App Review Information의 Notes 필드**: 다음 버전들에서도 계속 유효할 상시 정보(앱 목적, 설정 방법, 외부 서비스, 지역 차이, 테스트 기기 등). 회신에만 넣고 여기를 비워두면, 다음 심사 때 또 같은 사유로 걸릴 수 있다.

그래서 영상 파일 설명 문단은 Resolution Center 회신에만 넣고, Notes 필드에는 6개 항목(테스트 기기, 앱 목적, 설정 방법, 외부 서비스, 지역 차이, 규제 산업 여부)만 남겼다. Notes 필드를 채우려니 연락처 정보(이름/전화/이메일)도 다시 확인하라고 떴는데, 이건 원래 제출 자체를 막는 필수 항목이라 이번 리젝이랑은 상관없는 것이었다. 이미 여러 번 제출까지 갔었으니 처음부터 채워져 있었을 거였다.

그리고 이번 리젝은 "제출" 버튼을 다시 누르는 게 아니라, Resolution Center 스레드에서 **Reply**로 정보/영상을 회신하는 것 자체가 재심사 요청이었다. 완전히 리젝된 게 아니라 "정보 주면 이어서 볼게"라는 유형이라 새 빌드가 필요 없었다.

---

## 녹화 준비하다가 찾은 버그

준비하는 김에 PFDView SpeedTape 숫자가 두 자리일 때 레이아웃 깨지던 것도 폰트 크기(`.font(.orbitron(9, weight: .bold))`)를 줄여서 같이 고쳤다. 이건 사소한 거고, 더 흥미로운 건 따로 있었다.

### 정상 종료할 때마다 "Workout Session Error"가 뜸

며칠 전 doc comment를 정리하다가, `HealthKitService`의 `workoutSession(_:didFailWithError:)`가 자기 자신과 같은 이름의 함수를 내부에 중첩 선언하고 있어서 실제로는 절대 실행되지 않는 죽은 코드라는 걸 발견하고 고쳤었다. 그런데 그 함수를 고치자마자, 지금까지 조용히 씹히고 있던 진짜 버그가 눈에 보이기 시작했다.

원인은 `session?.end()`가 정상 종료 흐름에서 **두 번** 호출되고 있었던 거였다.

TOUCHDOWN을 누르면 `stopWorkout()`이 세션을 `.stopped`로 전환시키고, 그 상태 변화를 받는 델리게이트에서 첫 번째 `end()`가 호출된다.

```swift
// HealthKitService+iOS.swift
func handleiOSStateChange(_ toState: HKWorkoutSessionState) {
    ...
    if toState == .stopped {
        session?.end()   // 1번째 호출
        let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin, startOrigin: nil)
        updateAndSendState(event)
    }
    ...
}
```

그런데 Summary 화면을 지나서 `resetState()`가 호출될 때, `resetWorkout()`이 조건 없이 `end()`를 한 번 더 부르고 있었다.

```swift
// HealthKitService+iOS.swift (수정 전)
func resetWorkout() {
    session?.end()   // 2번째 호출 - 이미 .ended 상태인 세션에 또 호출
    builder = nil
    workout = nil
    session = nil
    startOrigin = nil
    stopOrigin = nil
}
```

이미 종료된 세션에 `.end()`를 한 번 더 호출하면 HealthKit이 에러를 던지는데, 그동안은 그 에러를 받는 델리게이트가 죽은 코드였으니 아무 일도 없었던 것처럼 보였을 뿐이다. 죽은 코드를 고친 게 오히려 숨어있던 버그를 드러낸 셈이다.

```swift
// HealthKitService+iOS.swift (수정 후)
func resetWorkout() {
    if let session, session.state != .ended {
        session.end()
    }
    builder = nil
    workout = nil
    session = nil
    startOrigin = nil
    stopOrigin = nil
}
```

세션 상태를 확인해서 이미 끝난 세션이면 다시 끝내지 않도록 가드를 추가했다.

---

### 미러링 중 워치가 데이터를 못 받는 현상 (재확인)

테스트하다가 미러링 중 갑자기 Watch가 iPhone 데이터를 못 받는 증상이 다시 나왔다. 앱을 지웠다 재설치하면 고쳐지긴 하는데, 재설치 직후에도 몇 번 더 재현된 걸 보면 앱 로컬 상태 문제가 아니라 `HKWorkoutSession`이 `healthd` 데몬 레벨에 남기는 상태 쪽 문제일 가능성이 크다. 이미 v1.0 초반에 "좀비 세션" 이슈로 깊게 파봤다가 앱 레벨에서는 완전히 제어할 수 없다고 결론 낸 것과 같은 종류라, 이번엔 더 파고들지 않고 known limitation으로 남겨뒀다. 위 중복 `end()` 호출 버그가 반복 테스트 중 `healthd` 상태를 더 꼬이게 만들었을 가능성은 있어서, 이번 수정으로 빈도는 줄어들 것 같다.

덤으로 `WCSession`의 `sessionReachabilityDidChange(_:)` 델리게이트가 아예 구현되어 있지 않다는 것도 발견했다. 연결이 반짝 끊겼다 돌아왔을 때 대응할 방법이 없다는 뜻인데, 이건 근본 원인은 아니라서 1.1 때 좀비 세션 이슈랑 같이 다시 보기로 했다.

---

정리하면, Notes 필드엔 상시 정보를 채우고 Resolution Center엔 영상 세 개(권한 프롬프트 2개 + 실제 러닝 1개)와 그 설명을 회신해서 재심사를 요청했다. 버그 두 개는 녹화 준비하다가 덤으로 잡았고, 미러링 중 데이터 유실 현상은 이미 알고 있던 한계로 재확인만 했다.

회신하고 나서 상태가 "심사 중"으로 바뀌길래 기다렸는데, 얼마 안 가 이번엔 완전히 다른 사유로 또 걸렸다.

---

## 두 번째 리젝 - Guideline 5.2.5 WeatherKit 어트리뷰션

> **Guideline 5.2.5 - Legal - Intellectual Property - Apple Products**
>
> The app appears to support WeatherKit but we need to confirm if the app follows the WeatherKit attribution requirements. WeatherKit apps must clearly display the Apple Weather trademark ( Weather) and the legal source link, so users know the source of the weather information.

코드를 확인해보니 진짜로 없었다. WeatherKit을 붙일 때(21번 글) 데이터 가져오는 것만 신경 썼지, Apple이 요구하는 저작권 표시(마크 이미지 + 법적 출처 링크)는 애초에 넣은 적이 없었다.

---

### 구현

`WeatherAttribution` API로 마크 이미지 URL과 법적 고지 페이지 URL을 가져와서, `TakeoffView`의 WEATHER 체크리스트 항목 바로 아래에 탭 가능한 마크로 표시했다.

```swift
// WeatherKitService.swift
func fetchAttribution() async -> WeatherAttribution? {
    try? await service.attribution
}
```

```swift
// TakeoffView.swift
if let attribution = runViewModel.weatherAttribution {
    Link(destination: attribution.legalPageURL) {
        HStack(spacing: 6) {
            AsyncImage(url: attribution.combinedMarkDarkURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(height: 14)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.rwMuted)
        }
    }
}
```

앱이 항상 어두운 배경(`Color.rwBg`)에서 렌더링되는 구조라, 시스템 `colorScheme`을 보는 대신 어두운 배경용 마크(`combinedMarkDarkURL`)를 그냥 고정해서 썼다. 링크 URL도 하드코딩하지 않고 `attribution.legalPageURL`로 그때그때 받아오게 했다.

실제로 탭해보면 `developer.apple.com/weatherkit/data-source-attribution/`으로 연결되는데, 이것도 Apple 서버 응답을 그대로 쓴 거라 나중에 Apple이 페이지를 바꿔도 코드를 안 건드려도 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-15-RunningProject-27/before.gif){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-15-RunningProject-27/weather.gif){: width="50%" height="50%"}

### 회신

이번엔 리젝 사유가 명확해서 Notes 필드는 짧게 한 줄만 추가하고, Resolution Center 회신에 실기기로 WEATHER 항목과 새로 생긴 어트리뷰션 마크가 보이는 화면을 녹화해서 첨부하는 데 집중했다.

---

## 스크린샷 다시 찍다가 찾은 진짜 버그

TAKEOFF 화면 App Store 스크린샷을 어트리뷰션 마크 포함해서 다시 찍으려고 실기기로 짧게 몇 번 테스트하다가, 완전히 별개의 버그를 하나 더 발견했다.

---

### 문제

50m 미만이라 저장 조건에 안 걸리는 짧은 러닝을 종료했더니, Summary 화면에 방금 뛴 기록이 아니라 **이전에 저장했던 러닝 기록**이 그대로 떴다. 로그북에 중복 저장되는 건 아니었지만(가드는 정상 동작), 화면에 엉뚱한 기록이 보이는 게 이상했다.

원인을 보니 `FlightSummaryView`가 러닝 직후 화면에서 항상 `selectedFlight: nil`로 열리고, 내부적으로 SwiftData에서 "가장 최근 기록"을 쿼리해서 대신 보여주는 구조였다.

```swift
// FlightSummaryView.swift
@Query(sort: \SwiftDataFlight.date, order: .reverse) private var flights: [SwiftDataFlight]
var lastestFlight: SwiftDataFlight? { flights.first }
var displayFlight: SwiftDataFlight? { selectedFlight ?? lastestFlight }
```

평소엔 방금 끝난 러닝이 항상 저장되니까 "가장 최근 기록 = 방금 끝낸 러닝"이 우연히 맞아떨어졌던 거다. 근데 25번 글에서 "50m 미만이면 저장 안 함" 가드를 추가하면서 이 전제가 깨졌다.

짧은 러닝은 저장이 안 되니, 그 이전에 저장됐던 진짜 기록이 대신 뜨는 거였다.

---

### 해결

`saveRunningData()`가 저장 성공 시 그 기록을, 실패 시 `nil`을 `RunViewModel.lastSavedFlight`에 남기게 하고, `FlightSummaryView`는 더 이상 "가장 최근 기록"으로 대체하지 않고 전달받은 값을 그대로 보여주도록 바꿨다.

```swift
// RunViewModel.swift
func saveRunningData() async {
    lastSavedFlight = nil
    guard let modelContext else { return }
    guard HealthKitService.shared.startOrigin == .local else { return }
    // ... 거리 가드 등 기존 로직
    modelContext.insert(runningData)
    lastSavedFlight = runningData
}
```

문제는 `selectedFlight == nil`이 지금까지 "러닝 직후 화면인지"를 판단하는 용도로도 같이 쓰이고 있었다는 거다(GO TO DECK 버튼 표시, 화면 이탈 시 리셋). 저장이 안 된 정상적인 케이스에서도 `selectedFlight`가 `nil`이 될 수 있게 되면서 이 판단 로직이 깨질 뻔했다. `isPostRun`이라는 별도 플래그를 추가해서 "화면 출처"와 "표시할 데이터 유무"를 분리했다.

```swift
// HomeView.swift
case .summary:
    FlightSummaryView(selectedFlight: runViewModel.lastSavedFlight, isPostRun: true)
```

저장이 안 된 경우엔 "MISSION COMPLETE" 배지 대신 "NOT RECORDED - TOO SHORT"가 뜨도록 추가해서, 짧은 러닝이었다는 걸 명확히 알 수 있게 했다.

Watch 쪽(`WatchSummaryView`)은 애초에 이런 "가장 최근 기록 쿼리" 패턴 자체가 없어서 `pendingFlightData`를 직접 전달받는 구조라 같은 버그가 없었다. 

그래서 이번 수정은 iPhone 쪽에만 적용했다.

---

## 배포 성공

심사가 시작되고 약 10분정도 지났을때

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-15-RunningProject-27/result.png){: width="50%" height="50%"}

이렇게 준비한 앱이 배포가 되었다.

리젝 두 번 겪고 나니 오히려 마음이 편했다.

둘 다 버그가 아니라 "정보를 어떻게 전달하느냐"의 문제였고, 그 과정에서 진짜 버그(중복 세션 종료, Summary 재기록)까지 덤으로 잡았다. 결과적으로는 더 탄탄해진 채로 심사를 통과한 셈이다. `main`에 머지하고 `v1.0` 태그도 남겼다.

---

## 다음은 1.1

일단 v1.0은 여기서 마무리하고, 다음은 1.1 준비다.

크게 두 갈래로 생각하고 있다. 백엔드 없이 지금 구조 위에서 바로 얹을 수 있는 가벼운 기능들부터 정리하고, 그다음 좀 더 스코프가 큰 것들(로그북 고도화나 심박 기반 러닝 모드 같은)로 넘어가는 순서다. 자세한 건 착수하면서 하나씩 글로 남길 예정이다.