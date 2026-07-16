---
title: RunWay (25) App Store 배포 준비
writer: Harold
date: 2026-07-13 09:33:00 +0900
categories: [RunWay]
tags: [App Store, Xcode]

toc: true
toc_sticky: true
published: true
---

드디어 App Store Connect에 앱을 올려서 배포를 해보도록 한다.

---

## 스크린샷 만들기

시뮬레이터에서 찍은 스크린샷을 그냥 올리기엔 밋밋해서, 캡션이랑 어두운 배경을 얹은 마케팅용 스크린샷을 따로 만들었다.

AI한테 부탁해서 적당한 멘트를 추천받아 만들었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-screenshot-sample.png){: width="45%" height="45%"}

어플의 테마색을 유지하면서 만들었다.

---

## 사이즈 에러

다 만들어서 올렸더니 이런 에러가 떴다.

> 스크린샷 크기는 1242 × 2688px, 2688 × 1242px, 1284 × 2778px 또는 2778 × 1284px이어야 합니다.

그래서 다시 ai에게 사이즈 조정을 해달라고 했다.

---

## 최종 점검

업로드하기 전에 리젝될만한 요소가 있는지 AI한테 프로젝트 전체를 훑어봐 달라고 했다.

전반적으로는 깨끗했다. 쓰고 있는 API(HealthKit, CoreLocation, WeatherKit)에 대응하는 권한 문구는 다 있었고 실제 코드 사용과도 일치했다. 로그인 시스템 자체가 없어서 Sign in with Apple 요구사항 대상도 아니었고, 서드파티 광고/분석 SDK도 전혀 없었다. 다만 세 가지가 걸렸다.

**1. 안 쓰는 Always 위치 권한 문구**

`NSLocationAlwaysAndWhenInUseUsageDescription`이 Info.plist에 선언은 되어 있는데, 코드 어디에도 `requestAlwaysAuthorization()` 호출이 없었다. `requestWhenInUseAuthorization()`만 쓰고 있었다.

백그라운드 러닝 추적이 이것 때문에 되고 있는 건가 싶어서 다시 찾아봤는데 아니었다. `allowsBackgroundLocationUpdates`는 When In Use 권한과 `UIBackgroundModes: location` 조합만으로도, 이미 포그라운드에서 시작된 추적을 백그라운드까지 이어갈 수 있다. Always 권한이 진짜 필요한 건 앱이 아예 꺼진 상태에서 위치 이벤트로 시스템이 앱을 대신 깨워야 하는 경우(지오펜싱 등)뿐이다. 러닝 앱은 사용자가 직접 앱을 열고 시작 버튼을 눌러야 추적이 시작되는 구조라 여기에 해당하지 않는다.

```xml
<!-- before -->
<key>NSHealthUpdateUsageDescription</key>
<string>러닝 운동 기록을 건강 앱에 저장하기 위해 건강 정보 쓰기 권한이 필요합니다.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>러닝 중 백그라운드에서 위치를 추적하기 위해 사용합니다.</string>
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
```

써야 할 문구가 아니었으니 지웠다. `InfoPlist.xcstrings`에 있던 같은 키의 번역 항목도 같이 지웠다.

**2. 안 쓰는 HealthKit background-delivery entitlement**

`com.apple.developer.healthkit.background-delivery`가 iPhone/Watch 양쪽 entitlements에 다 선언되어 있었는데, `enableBackgroundDelivery`나 `HKObserverQuery` 관련 코드는 어디에도 없었다. 안 쓰는 걸 확인하고 둘 다 체크 해제 했다. (앱, 워치)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/target.png){: width="50%" height="50%"}


**3. 암호화 수출 규정 플래그 없음**

`ITSAppUsesNonExemptEncryption` 키가 없어서, 빌드를 올릴 때마다 App Store Connect에서 암호화 사용 여부를 매번 수동으로 물어보고 있었다. 표준 HTTPS 통신만 쓰고 별도 암호화 로직은 없어서 `false`로 미리 넣어뒀다.

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

세 가지 다 반영하고 빌드까지 확인한 다음 다시 올렸다.

---

## 배포 준비

이전에 TestFlight 만들때처럼 Archive를 하되

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/connect.png){: width="50%" height="50%"}

이젠 App Store Connect를 선택해준다.

그리고 업로드를 하고 기다리면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/distribute.png){: width="50%" height="50%"}

이렇게 업로드가 되었다는 메일이 온다.

---

## 빌드 추가 하여 배포

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/build.png){: width="50%" height="50%"}

이제 이렇게 업로드한 빌드에 대해 배포를 하려고 추가할때 목록이 뜬다.

여기서 가장 최근에 빌드한것을 추가 하면 된다.

이때 빌드 2 를 보면 수출관련 문서 누락이라고 되어있는데, 이것을 위에서 `ITSAppUsesNonExemptEncryption`를 통해 No로 하면서 해결을 한 것이다.

---

심사에 추가 버튼을 누르니

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/error.png){: width="50%" height="50%"}

이렇게 에러가 뜬다.

그래서 이부분을 해결해보려고 한다.

---

### 1. 콘텐츠 권한 정보

콘텐츠 권한 정보(Content Rights)는 앱에 제3자가 만든 콘텐츠(라이선스 음악, 외부 브랜드 콘텐츠, 다른 서비스에서 가져온 사용자 생성 콘텐츠 등)가 들어있는지 묻는 항목이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/contentinfo.png){: width="50%" height="50%"}

이 앱의 경우, 표시되는 데이터(심박수, 걸음 수, 날씨, GPS)가 전부 Apple 프레임워크(HealthKit, WeatherKit, CoreLocation)에서 오는 기능적 데이터지, 제3자가 만든 저작물이 아니다.

외부에서 가져온 이미지, 음악, 텍스트, 다른 사용자의 콘텐츠 같은 것도 전혀 없다.(AI를 통해 만들었기 때문)
그러니 "아니요"로 답하면 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/contentno.png){: width="50%" height="50%"}

---

### 2. 가격 등급 선택

이제 앱 가격을 설정해야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/price.png){: width="50%" height="50%"}

지금 앱에는 인앱결제나 구독 로직이 전혀 없다. 나중에 버전을 올리면서 추가할 수도 있겠지만 아직 거기까진 생각 안 하고 있어서, 일단은 무료앱으로 등록하기로 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/pricezero.png){: width="50%" height="50%"}

0달러로 해주면 된다. 나중에 인앱결제를 붙이고 싶어지면 그때 가서 유료 앱 계약이나 상품 등록을 새로 하면 되는 거라, 지금 무료로 시작한다고 나중에 발목 잡힐 일은 없다.

앱 사용 가능 여부는 모든 국가로 해주었다. 지금 지원 언어가 한/영/일 세 개뿐이긴 한데, 이건 UI 언어 얘기고 배포 국가랑은 별개다. 영어만 봐도 어디서든 어느 정도는 쓸 수 있으니, 굳이 국가를 제한할 이유가 없어서 175개국 전부 열어뒀다.

---

### 3. 규제 대상 의료 기기 신고

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/euiro.png){: width="50%" height="50%"}

이건 앱이 질병을 진단·치료·예방한다는 주장을 하는지가 기준이다. 

RunWay가 GPWS 알림으로 심박수나 페이스를 보여주긴 하지만, 그건 "목표 페이스에서 벗어났다"는 운동 성과 피드백일 뿐이지 의료적 진단이 아니다. 

이런 식으로 운동 기록만 추적하고 의료적 주장을 안 하는 앱은 일반 웰니스(General Wellness) 카테고리로 분류돼서 의료기기 신고 대상에서 빠진다. 

Strava나 Nike Run Club 같은 러닝 앱들도 다 이 카테고리라, 우리도 의료기기가 아니므로 아니오로 해준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/singo.png){: width="50%" height="50%"}

---

### 4. 소셜 미디어 관련 연령 등급 응답 업데이트

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/social.png){: width="50%" height="50%"}

어디서 이부분을 설정해야하나 구글링을 해보니

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/age.png){: width="50%" height="50%"}

여기서 해야한다고 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/age1.png){: width="50%" height="50%"}

보면 새롭게 2 항목이 추가된걸 알 수 있다.

**소셜 미디어** - 소셜 피드나 비슷한 방식으로 사용자 생성 콘텐츠(UGC)를 재배포·확산시키는 기능이 있는지 묻는 항목이다. RunWay는 러닝 기록이 전부 기기 로컬에만 저장되고, 다른 사용자와 공유하거나 피드로 노출하는 기능 자체가 없어서 아니오로 답했다.

**13세 미만 사용자의 소셜 미디어 비활성화** - 소셜 미디어 기능이 있는 앱한테 묻는 후속 질문이라, 애초에 소셜 미디어 기능이 없다고 답한 이상 이것도 해당 없음으로 아니오로 해주었다.

---

### 5. 저작권

이거는 Apple Developer 계정에 등록된 이름이랑 맞춰서 적어야 한다고 해서, 연도 + 실제 이름 조합으로 적었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/copyright.png){: width="50%" height="50%"}

형식 자체는 어렵지 않은데, 계정에 등록된 이름이랑 다르게 적으면 나중에 문제가 될 수 있다고 해서 Membership 페이지에서 등록된 이름을 다시 한번 확인하고 그대로 썼다.

---

다섯 가지 다 채우고 나니 남아있던 에러가 없어졌다. 심사 제출을 하고 이제 결과를 기다리면 된다.

---

## 배포 취소 - 실기기 테스트 중 발견된 문제

심사 결과를 기다리는 동안 그냥 손 놓고 있기는 그래서, 간단하게 3km 정도 미러링으로 테스트를 해보고 왔다.

그런데 뛰고 와서 확인해보니 심각한 문제가 세 개나 나왔다.

1. iPhone이 미러링을 주도한 상태에서 Watch에서 러닝을 종료하면, Summary에 지도가 안 나온다.
2. Watch가 미러링을 주도하면 페이스나 거리 정보가 Watch, iPhone 양쪽 다 제대로 안 보인다.
3. 거리가 0인 기록이 로그북에 그대로 저장된다.

문제는 이 세 개 다 예전에 블로그에 "해결했다"고 적어뒀던 것들이라는 거다. 이상해서 다시 코드를 뜯어봤다.

심사가 진행 중인 상태였지만, 이 정도면 심사에서 걸리든 안 걸리든 사용자 경험상 치명적이라고 판단해서 일단 App Store Connect에서 제출을 취소하고 원인부터 다시 파봤다.

이번엔 AI한테 코드를 같이 훑어보게 하면서 같이 원인을 찾고 고치는 식으로 진행했다. 아래 문제들은 전부 그렇게 같이 찾은 것들이다.

---

### 1. iPhone 주도 + Watch 종료 - 지도가 안 나옴

#### 문제

`RunViewModel`에서 Watch발 종료 신호(`stopOrigin == .remote`)를 처리하는 부분을 다시 봤다.

```swift
if result.stopOrigin == .remote {
    Task {
        await self.flightActivityService.endActivity()
        await self.resetState()
    }
}
```

저장 호출이 어디에도 없다. 바로 `resetState()`로 가는데, 그 안에서 `runningCenter.reset()`이 호출되고

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
    modeAData = nil
}
```

여기서 `coordinateArray`가 통째로 비워진다. 좌표가 포함된 저장은 PFDView의 TOUCHDOWN 버튼을 눌렀을 때만 실행되는 `saveRunningData()`에서 일어나는데, Watch가 종료를 주도하면 이 버튼을 아예 안 거치니까 이 저장 자체가 실행되지 않는다.

더 골치 아픈 건, Watch 쪽 `saveRunningData()`는 그대로 실행된다는 거다. Watch는 미러링만 하던 입장이라 자기 `coordinateArray`가 애초에 비어있는데, 이 빈 좌표 기록이 iPhone으로 전달돼서 저장까지 된다. 그러니까 iPhone의 진짜 경로는 버려지고, 좌표가 없는 Watch발 기록이 대신 남는 셈이다.

---

#### 해결

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug1-before.png){: width="55%" height="55%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug1-after.png){: width="55%" height="55%"}

두 군데를 고쳤다.

먼저 `saveRunningData()`가 `PFDView`에만 있다는 게 문제였다. Watch발 종료는 `PFDView`의 TOUCHDOWN 버튼을 거치지 않으니, 저장 로직 자체가 View가 아니라 `RunViewModel`에 있어야 어디서든 호출할 수 있다. 그런데 `RunViewModel`은 `@Observable` 클래스라 `@Environment(\.modelContext)`에 접근이 안 된다. 그래서 `RunViewModel`에 `modelContext`를 저장할 프로퍼티를 하나 추가하고, 앱의 루트인 `HomeView`가 자기 `modelContext`를 주입해주도록 했다.

```swift
// RunViewModel.swift
@ObservationIgnored var modelContext: ModelContext?

func saveRunningData() async {
    guard let modelContext else { return }
    let totalDistance = flightData.distance / 1000
    let totalTime = elapsedTime
    let minimumValidDistance = 0.05
    let rawPace = (Double(totalTime) / 60) / totalDistance
    let totalPace = (rawPace.isFinite && totalDistance >= minimumValidDistance) ? rawPace : 0
    let coords = await getCoordinates()
    let avgHR = heartRateBuffer.isEmpty ? 0 : Int(heartRateBuffer.reduce(0, +) / Double(heartRateBuffer.count))
    let avgCad = cadenceBuffer.isEmpty ? 0 : Int(cadenceBuffer.reduce(0, +) / Double(cadenceBuffer.count))
    let runningData = SwiftDataFlight(
        mode: isModeA ? "modeA" : "modeB",
        distance: totalDistance, time: totalTime, pace: totalPace,
        heartRate: avgHR, cadence: avgCad,
        fuel: Int(healthData.activeEnergy), date: .now
    )
    for (i, coord) in coords.enumerated() {
        runningData.coordinates.append(SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: i))
    }
    runningData.alerts.append(contentsOf: tempAlertArray)
    modelContext.insert(runningData)
}
```

```swift
// HomeView.swift
.onAppear {
    runViewModel.modelContext = modelContext
}
```

원래 `PFDView`에 있던 저장 로직은 그대로 복붙해서 두 벌 유지하는 대신, `RunViewModel` 쪽 하나로 합치고 `PFDView`의 TOUCHDOWN 버튼은 `runViewModel.saveRunningData()`를 호출하도록 바꿨다.

그리고 Watch발 종료 신호(`stopOrigin == .remote`)를 받는 지점에서, `resetState()`로 좌표를 날려버리기 전에 저장을 끼워 넣었다. 단, iPhone이 실제로 주도한 경우(`startOrigin == .local`)에만 저장하도록 조건을 걸었다.

애초에 iPhone도 미러링만 하던 상황이면 저장할 실제 데이터가 없기 때문이다.

```swift
if result.stopOrigin == .remote {
    Task {
        await self.flightActivityService.endActivity()
        if HealthKitService.shared.startOrigin == .local {
            await self.saveRunningData()
        }
        await self.resetState()
    }
}
```

두 번째로, Watch 쪽 `saveRunningData()`도 손을 봤다. Watch가 미러링만 하던 경우엔 자기가 가진 좌표가 어차피 비어있으니, 그 빈 기록을 iPhone으로 보내서 iPhone의 진짜 기록을 덮어쓰는 일이 없도록 아예 저장 자체를 막았다.

```swift
// WatchPFDView.swift
func saveRunningData() async {
    guard HealthKitService.shared.startOrigin == .local else { return }
    // ... 기존 로직
}
```

이제 어느 쪽이 종료를 주도하든, 실제로 러닝을 이끈 기기의 좌표만 저장되고 Summary에 지도도 정상적으로 뜬다.

---

### 2. Watch 주도 미러링 - 페이스/거리가 안 보임

#### 문제

이건 두 가지가 겹쳐 있었다.

**첫 번째**, `sendHealthData()`와 `sendFlightData()`가 `lastSentTime`이라는 타임스탬프 하나를 같이 쓰고 있었다.

```swift
// sendFlightData
let now = Date()
guard now.timeIntervalSince(lastSentTime) >= 3.0 else { return }
lastSentTime = now
guard session.isReachable else { return }
```

Watch가 주도할 땐 심박수 전송(`sendHealthData`)도 계속 같이 돌고 있는데, 이게 같은 `lastSentTime`을 계속 갱신해버린다. 그러니 정작 페이스/거리를 보내는 `sendFlightData`는 3초 쓰로틀 조건을 거의 통과 못 한다.

**두 번째**, `startStream()` 안에 있는 조건 하나가 레이스에 걸려있었다.

```swift
if HealthKitService.shared.startOrigin == .local  {
    Task {
        for await data in await runningCenter.streamFlightData() {
            self.flightData = data
            lastReceivedTime = .now
            isPaused = false
            watchConnectivityService.sendFlightData(data)
            // 생략
        }
    }
}
```

`startOrigin`은 `updatePhase(.cruise)` 안의 `Task {}`에서 비동기로 세팅되는 값인데, `startStream()`이 그 `Task`보다 먼저 실행되면 이 조건이 `false`로 읽혀서 블록 전체가 스킵된다.

여기서 중요한 건 이 `if` 블록 안에 `self.flightData = data`(Watch 자기 화면에 페이스/거리를 찍는 값)와 `sendFlightData(data)`(iPhone 전송)가 **같이** 들어있다는 거다. 그러니까 이 조건이 스킵되는 순간엔 iPhone에 값이 안 가는 정도가 아니라, `runningCenter.streamFlightData()` 구독 자체가 시작을 안 해서 **Watch 자기 화면도 페이스/거리가 안 뜬다.**

반면 첫 번째 원인(`lastSentTime` 공유)은 이 `if` 블록이 정상적으로 진입한 다음 얘기다. `self.flightData = data`는 매번 잘 갱신되니까 Watch 화면은 멀쩡한데, 뒤이어 호출되는 `sendFlightData(data)` **내부의** `guard` 문에서 조용히 `return`돼버리는 거라 iPhone 쪽에만 영향을 준다. 정리하면 두 원인이 망가뜨리는 범위가 다르다. 하나는 "화면 + 전송"을 통째로 죽이고, 다른 하나는 "전송"만 죽인다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug2-anatomy.png){: width="70%" height="70%"}

사실 이거랑 똑같은 레이스를 예전에 `start()` 안에서 한 번 겪은 적이 있다. `locationService.startTracking()`이 안 불려서 GPS 자체가 안 켜지던 문제였고, 그때 `prepareTracking()`으로 분리해서 해결했었다. 근데 그건 GPS 시작 지점만 고친 거였고, `startStream()`에 있는 이 조건은 그때 안 건드렸다. 같은 병이 다른 자리에 그대로 남아있었던 셈이다.

두 원인 다 "항상 100% 실패"가 아니라 "타이밍이 나쁘게 걸리면 실패"하는 레이스라서, 코드를 전혀 안 건드려도 어떤 날은 되고 어떤 날은 안 될 수 있다. 실제로 [이전글](https://haroldfromk.github.io/posts/RunningProject-(22)/){:target="_blank"}의 "빌드 후 (코드 수정 없음)" 챕터에서도 코드를 하나도 안 바꾸고 재빌드만 했는데 증상이 반대 방향으로 옮겨간 적이 있다.

그때도 원인은 지금과 같은 종류의 레이스였다.

---

#### 해결

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug2-before.png){: width="55%" height="55%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug2-after.png){: width="55%" height="55%"}

첫 번째 문제는 타임스탬프를 분리하는 걸로 끝났다. `sendHealthData()`용 `lastHealthSentTime`을 따로 만들어서 `sendFlightData()`의 `lastSentTime`과 서로 갱신을 방해하지 않게 했다.

```swift
// WatchConnectivityService.swift
var lastSentTime: Date = .distantPast
var lastHealthSentTime: Date = .distantPast
```

```swift
// sendHealthData
let now = Date()
guard now.timeIntervalSince(lastHealthSentTime) >= 3.0 else { return }
lastHealthSentTime = now
```

두 번째 문제는 `startOrigin = .local` 대입을 `Task {}` 밖으로 꺼내는 걸로 고쳤다. 워크아웃 세션을 실제로 시작하는 `startWorkout()`은 비동기라 `Task`가 필요하지만, `startOrigin` 대입 자체는 동기 코드라 굳이 그 안에 있을 이유가 없었다.

```swift
// WatchViewModel.swift / RunViewModel.swift, updatePhase(_:)
case .cruise:
    HealthKitService.shared.startOrigin = .local
    Task {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            try await HealthKitService.shared.startWorkout(workoutConfiguration: config)
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.workoutSessionFailed)
        }
    }
```

`updatePhase(.cruise)`가 호출된 시점에 `startOrigin`이 바로 세팅되니까, 뒤이어 `navigateTo(.pfd)`로 화면이 전환되고 `startStream()`이 돌 때는 이미 값이 확정된 상태다. 레이스가 아예 성립하지 않는다.

똑같은 패턴이 iPhone 쪽 `RunViewModel.updatePhase()`에도 있어서 거기도 같이 고쳤다. iPhone 주도일 땐 운 좋게 타이밍이 안 겹쳐서 안 드러났을 뿐, 같은 구조라 잠재적으로 똑같이 터질 수 있는 코드였다.

---

### 3. 거리 0인 기록이 로그북에 저장됨

#### 문제

[이전글](https://haroldfromk.github.io/posts/RunningProject-(22)/){:target="_blank"}에서 `inf` 페이스가 월평균을 오염시키던 문제를 고치면서 이런 가드를 넣었었다.

```swift
let minimumValidDistance = 0.05
let rawPace = (Double(totalTime) / 60) / totalDistance
let totalPace = (rawPace.isFinite && totalDistance >= minimumValidDistance) ? rawPace : 0
```

다시 보니 이 가드는 **`pace` 값만 0으로 만들 뿐, `SwiftDataFlight`를 저장할지 말지는 전혀 걸러주지 않는다.** `modelContext.insert(runningData)`는 이 가드랑 상관없이 무조건 실행된다.

`SwiftDataFlight`를 저장하는 곳이 한 군데가 아니라 네 군데였다. iPhone 로컬 종료(`PFDView`), Watch 로컬 종료(`WatchPFDView`), Watch가 만든 기록을 iPhone이 받는 지점(`WatchConnectivityService+iOS`), 그리고 그걸 최종적으로 저장하는 `HomeView`. 네 곳 다 거리 조건 없이 그냥 저장한다.

당시엔 "0으로 저장해두면 나중에 집계에서 걸러내기 쉽다"는 생각으로 일부러 저장은 하되 페이스만 0으로 만드는 방향으로 갔던 거였다. 그리고 실제로 월평균 계산(`FlightCalendarView`)엔 `pace.isFinite && pace > 0` 필터가 있어서 그 부분은 지금도 정상 동작한다. 근데 로그북 리스트 자체엔 이런 필터가 하나도 없어서, 거리 0인 기록도 그냥 다 보이는 거였다.

---

#### 해결

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug3-before.png){: width="55%" height="55%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug3-after.png){: width="55%" height="55%"}

네 군데 중 실제로 `modelContext.insert()`를 호출하는 곳은 두 곳뿐이었다. `WatchPFDView`와 `WatchConnectivityService+iOS`는 `SwiftDataFlight`를 만들기만 하고, 최종 저장은 각각 `RunViewModel`과 `HomeView`로 넘어가서 처리된다. 그러니 이 두 곳에만 거리 가드를 걸면 네 경로 전부를 막을 수 있다.

먼저 `RunViewModel.saveRunningData()`에 이미 있던 `minimumValidDistance` 값을 그대로 가져다 조기 반환 조건으로 썼다.

```swift
// RunViewModel.swift
func saveRunningData() async {
    guard let modelContext else { return }
    let totalDistance = flightData.distance / 1000
    let totalTime = elapsedTime
    let minimumValidDistance = 0.05
    guard totalDistance >= minimumValidDistance else { return }
    // ... 이하 동일
}
```

그리고 Watch가 보낸 기록을 최종적으로 저장하는 `HomeView`에도 같은 기준으로 가드를 추가했다.

```swift
// HomeView.swift
.onChange(of: runViewModel.pendingWatchData) { _, newValue in
    if let flight = newValue {
        if flight.distance >= 0.05 {
            modelContext.insert(flight)
        }
        runViewModel.pendingWatchData = nil
    }
}
```

페이스 계산 가드는 원래 목적(월평균 오염 방지)대로 그대로 두고, 저장 여부만 별도로 걸렀다. 이제 거리가 사실상 0인 기록은 로그북은 물론 SwiftData에 아예 들어가지도 않는다.

---

세 문제 다 원인 파악부터 코드 수정, 빌드 확인까지 끝내고 실기기로 재테스트를 하다가, 네 번째 문제를 하나 더 발견했다.

---

### 4. 워치 주도 + 앱 종료 - 지도가 안 나옴

#### 문제

1번 문제(iPhone 주도 + Watch 종료)를 고치면서 정확히 반대 조합은 손을 안 댔다는 걸 뒤늦게 깨달았다. Watch가 주도하고 iPhone에서 종료하면 똑같이 지도가 안 나왔다.

`WatchViewModel`에서 iPhone발 종료 신호(`stopOrigin == .remote`)를 처리하는 부분을 보니 1번 문제 때 고치기 전의 `RunViewModel`이랑 똑같은 모양이었다.

```swift
if result.stopOrigin == .remote {
    Task {
        await self.resetState()
    }
}
```

저장 호출이 없다. `resetState()` 안에서 `sendRunningData()`를 부르긴 하는데, 이건 `pendingFlightData`가 이미 채워져 있어야 뭔가 보낼 게 있는 함수다.

```swift
func sendRunningData() {
    guard WCSession.default.activationState == .activated else { return }
    guard session.isReachable else { return }
    guard let flight = viewModel?.pendingFlightData else { return }
    ...
}
```

`pendingFlightData`는 Watch가 자기 END FLIGHT 버튼을 눌렀을 때만 채워지는데, 이번엔 iPhone이 종료를 주도했으니 Watch는 그 버튼을 안 거쳤다. 그러니 `pendingFlightData`는 계속 `nil`이고, `sendRunningData()`는 가드에 걸려서 아무것도 안 보낸다. Watch가 갖고 있던 진짜 GPS 경로는 저장 시도조차 못 해보고 그냥 날아간 거다.

반대쪽에서는 iPhone이 자기 TOUCHDOWN 버튼을 눌러서 `saveRunningData()`를 무조건 실행하고 있었다. iPhone은 미러링만 하던 입장이라 자기 `coordinateArray`가 비어있는데, 1번 문제 때 이 가드는 Watch 쪽(`WatchPFDView.saveRunningData()`)에만 넣고 iPhone 쪽(`RunViewModel.saveRunningData()`)에는 안 넣었었다. 그러니 iPhone은 빈 좌표로 기록을 만들어 그대로 저장해버린다.

#### 해결

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug4-before.png){: width="55%" height="55%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug4-after.png){: width="55%" height="55%"}

양쪽에 대칭으로 가드를 채워 넣었다.

`RunViewModel.saveRunningData()`(iOS)에 Watch 쪽과 똑같은 가드를 추가했다.

```swift
// RunViewModel.swift
func saveRunningData() async {
    guard let modelContext else { return }
    guard HealthKitService.shared.startOrigin == .local else { return }
    // ... 이하 동일
}
```

`WatchViewModel`에는 `saveRunningData()`가 아예 없었다. `WatchPFDView`에만 있어서 View 밖에서는 호출할 방법이 없었다. 1번 문제 때 `RunViewModel`에 했던 것과 똑같이, `WatchPFDView`에 있던 저장 로직을 `WatchViewModel`로 옮겨서 어디서든 호출 가능하게 만들었다.

```swift
// WatchViewModel.swift
func saveRunningData() async {
    guard HealthKitService.shared.startOrigin == .local else { return }
    let totalDistance = flightData.distance / 1000
    ...
    pendingFlightData = runningData
}
```

그리고 iPhone발 종료 신호를 받는 지점에서, `resetState()`(→ `sendRunningData()`) 전에 `saveRunningData()`를 먼저 호출하도록 추가했다.

```swift
if result.stopOrigin == .remote {
    Task {
        await self.saveRunningData()
        await self.resetState()
    }
}
```

이제 어느 쪽이 주도하든, 어느 쪽에서 종료하든 실제로 러닝을 이끈 기기의 좌표만 저장된다. 1번 문제를 고칠 때 "iPhone 주도 + Watch 종료"만 보고 반대 조합을 놓쳤던 셈인데, 애초에 두 방향이 완전히 대칭인 구조라 한쪽을 고칠 때 반대쪽도 같이 봤어야 했다.


위 4개의 문제를 고치고 실기기로 재테스트하다가, 다섯 번째로 좀 다른 성격의 문제를 하나 더 발견했다.

---

### 5. 러닝 재시작 시 이전 상태가 남아있음

#### 문제

4번 문제를 겪은 직후 상태에서 새 러닝을 시작해보니, 시간과 거리가 0이 아니라 이전 값에서부터 이어졌다.

`elapsedTime`, `flightData`를 0으로 되돌리는 건 `resetState()`뿐인데, 이 함수는 타이머나 시간 기반으로 자동 호출되는 게 아니라 **화면 전환 이벤트에서만** 호출된다.

```swift
// TouchdownView.swift
.onDisappear {
    if !didNavigateToSummary {
        Task {
            await runViewModel.flightActivityService.endActivity()
            await runViewModel.resetState()
        }
    }
}
```

```swift
// FlightSummaryView.swift
.onDisappear {
    guard selectedFlight == nil else { return }
    Task {
        await runViewModel.flightActivityService.endActivity()
        await runViewModel.resetState()
    }
}
```

즉 리셋이 "Touchdown → Summary → GO TO DECK"로 이어지는 정상적인 화면 전환에 완전히 의존하고 있다. 4번 문제 같은 상황에서 이 흐름이 꼬이면 `resetState()`가 호출될 기회 자체가 없고, 그 상태에서 `start()`를 호출해도 `start()`는 `isRunning`/`isPaused`/`lastReceivedTime`만 건드릴 뿐 `elapsedTime`이나 `flightData`는 손대지 않는다.

```swift
// RunViewModel.swift (기존)
func start() {
    isRunning = true
    isPaused = false
    lastReceivedTime = .now
    timerCancellable.removeAll()
    timerPublisher
        .autoconnect()
        .sink { [weak self] _ in
            guard let self else { return }
            elapsedTime += 1   // 0부터가 아니라 이전 값에 이어서 증가
            ...
        }.store(in: &timerCancellable)
}
```

그러니까 이전 러닝의 잔여값 위에 새 러닝의 값이 계속 누적되는 셈이었다.

---

#### 해결

리셋을 화면 전환에만 의존하지 않도록, 러닝을 실제로 시작하는 시점(`start()`)에서도 방어적으로 한 번 더 초기화하게 만들었다.

```swift
// RunViewModel.swift
func start() async {
    elapsedTime = 0
    flightData = FlightData()
    coordinateBuffer = []
    heartRateBuffer = []
    cadenceBuffer = []
    tempAlertArray = []
    await runningCenter.reset()
    isRunning = true
    isPaused = false
    lastReceivedTime = .now
    timerCancellable.removeAll()
    ...
}
```

`RunningCenter`는 actor라 리셋하려면 `await`가 필요한데, 마침 `start()`를 호출하는 카운트다운 로직이 이미 `Task {}` 안에서 `await`를 쓰고 있어서 `start()`를 `async`로 바꾸고 호출부에 `await`만 붙이면 됐다.

```swift
// TakeoffView.swift
runViewModel.updatePhase(.cruise)
await runViewModel.start()
didStartFlight = true
runViewModel.navigationPath.append(.pfd)
```

Watch 쪽 `WatchViewModel.start()`도 똑같은 방식으로 고쳤다. 이제 이전 화면 전환이 어떻게 꼬였든, 새 러닝은 항상 0부터 시작한다.

---

다섯 문제를 고치고 실기기로 4가지 경우의 수(앱 주도/워치 주도 × 앱 종료/워치 종료)를 코드로 다시 하나씩 따라가다가, 별개로 두 가지를 더 찾았다.

---

### 6. 원격 종료 이벤트가 두 번 발행될 수 있음

#### 문제

이건 실기기 테스트 중에 실제로 겪은 증상은 아니다. 1, 4번을 고치고 나서 AI한테 "미러링 4가지 경우의 수(앱주도/워치주도 × 앱종료/워치종료)를 코드로 전부 다시 분석해봐 달라"고 시켰는데, 그 과정에서 발견된 잠재적 문제다.

`stopOrigin`이 사실 두 군데에서 독립적으로 발행될 수 있는 구조였다.

- **Apple의 네이티브 미러링 전파**: 한쪽이 `session.stopActivity()`를 호출하면, 미러링 중인 `HKWorkoutSession`은 시스템 레벨에서 자동으로 반대쪽 세션도 `.stopped`로 전환시킨다. 이게 `workoutSession(_:didChangeTo:.stopped...)`를 실행시켜서 이벤트를 발행한다.
- **직접 만든 `sendStopSignal()`/`handleStopSignal()`**: WatchConnectivity로 "remoteStopped" 메시지를 따로 보내서 `stopOrigin = .remote`를 명시적으로 세팅하고 또 이벤트를 발행한다.

이 두 이벤트가 도착하는 순서가 타이밍에 따라 달라질 수 있어서, 이론적으로 `saveRunningData()` + `resetState()`가 두 번 실행될 수 있는 구조였다. 우연히 두 번째 호출 시점엔 첫 번째 `resetState()`가 이미 `flightData`를 비웠을 가능성이 높아서 거리 가드에 걸려 조용히 무시되긴 하는데, 완전히 안전하다고 보장할 수 있는 구조는 아니었다.

---

#### 해결

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug6-before.png){: width="55%" height="55%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug6-after.png){: width="55%" height="55%"}

재진입 가드를 하나 추가했다.

```swift
// RunViewModel.swift / WatchViewModel.swift
@ObservationIgnored private var isHandlingRemoteStop = false
```

```swift
if result.stopOrigin == .remote {
    guard !self.isHandlingRemoteStop else { return }
    self.isHandlingRemoteStop = true
    Task {
        await self.flightActivityService.endActivity()
        await self.saveRunningData()
        await self.resetState()
        self.isHandlingRemoteStop = false
    }
}
```

이제 두 이벤트 중 먼저 도착한 것만 처리되고, 나중에 도착한 건 가드에 걸려 무시된다. `start()`에서도 이 플래그를 방어적으로 리셋하도록 해서, 혹시 Task가 중간에 멈추는 일이 있어도 다음 러닝 시작 시엔 다시 풀리게 해뒀다.

---

### 7. 다이나믹 아일랜드가 안 뜸

#### 문제

이건 지금까지와 결이 다른 문제였다. `startActivity()`에 로그를 찍어보니 `Activity.request()`까지 전부 성공하고 있었다. 그런데 화면엔 아무것도 안 떴다.

```
🏝️ startActivity 진입, missionName=FREE FLIGHT
🏝️ areActivitiesEnabled 통과
🏝️ Activity.request 성공, id=9301ABA8-...
```

데이터 요청은 성공했는데 화면에 안 뜬다는 건, 실제 UI를 그리는 쪽(메인 앱이 아니라 `RunWayActivityExtension` 위젯 익스텐션 쪽)에 문제가 있다는 뜻이었다. 위젯 익스텐션은 메인 앱과 **완전히 별도 프로세스**로 돌기 때문에, 여기서 렌더링이 실패해도 메인 앱 Xcode 콘솔엔 어떤 에러도 안 찍힌다. 그래서 지금까지 아무 단서가 없었던 거다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-13-RunningProject-25/runway25-bug7-anatomy.png){: width="70%" height="70%"}

`DynamicIslandWidget.swift`를 뜯어보니 이런 코드가 있었다.

```swift
.background(Color("#161A22"))
...
.foregroundColor(Color("#FF453A"))
...
.foregroundColor(ok ? Color("#64FFDA") : Color("#FF453A"))
```

`Color(_ name: String)`는 hex 파서가 아니라 **Asset Catalog에서 그 이름의 색상 에셋을 찾는 이니셜라이저**다. 근데 위젯 익스텐션의 `Assets.xcassets`엔 `WidgetBackground`, `AccentColor`만 있고 "#161A22"라는 이름의 색상 에셋은 애초에 없었다. 조회가 조용히 실패하니까, 위젯 뷰 자체가 제대로 렌더링을 못 하고 있었던 거다.

진짜 hex 파서인 `Color(hex:)`는 `RunWayTheme.swift`에 있고, 이 파일 자체는 위젯 익스텐션 타겟에 정상적으로 포함돼 있었다(그래서 같은 파일에 있는 `.rwRed`, `.rwGreen` 같은 다른 색상들은 멀쩡히 컴파일됐다). 그러니까 이건 아키텍처 문제가 아니라, `Color(hex: "...")`라고 썼어야 할 자리에 `Color("...")`라고 오타처럼 잘못 쓴 세 줄의 문제였다.

#### 해결

세 곳 다 `Color(hex:)`로 바꿨다.

```swift
.background(Color(hex: "#161A22"))
...
.foregroundColor(Color(hex: "#FF453A"))
...
.foregroundColor(ok ? Color(hex: "#64FFDA") : Color(hex: "#FF453A"))
```

이걸로 다이나믹 아일랜드 자체는 떴는데, 잠금 화면에서는 카드 모서리 쪽에 흰 여백이 남아있었다. `.background()`는 내용물 뷰의 배경만 채우고, Live Activity 카드 전체(둥근 모서리 포함)의 배경은 시스템이 따로 관리하기 때문에 그 사이에 여백이 생기는 거였다. `.activityBackgroundTint(_:)` 모디파이어로 카드 전체 배경색을 지정해주니 해결됐다.

```swift
ActivityConfiguration(for: FlightActivityAttributes.self) { context in
    LockScreenBannerView(context: context)
        .activityBackgroundTint(Color(hex: "#161A22"))
        .activitySystemActionForegroundColor(.white)
} dynamicIsland: { context in
    ...
}
```

---

여섯, 일곱 문제까지 전부 원인 파악부터 코드 수정, 빌드 확인까지 끝났다. 다시 실기기로 미러링 테스트를 해보고 이상 없으면 App Store Connect에 재제출할 예정이다.

---

## 날씨 표시 세분화

버그는 아니고 겸사겸사 개선한 것. `fetchWeather()`가 처음엔 GOOD/CLOUDY/RAIN/SNOW 4개 카테고리 + 나머지 전부 CHECK로 뭉뚱그리고 있었는데, WeatherKit의 `WeatherCondition`을 다시 보니 34개나 되는 케이스가 있었다. 그중 `hot`(폭염), `frigid`(혹한)은 CHECK로 뭉개기엔 너무 명확한 경고 상황이고, 반대로 `breezy`(산들바람), `windy`(바람)는 러닝하기에 딱히 나쁠 게 없는 날씨라 CHECK에 있는 게 어색했다.

```swift
switch condition {
case .clear, .mostlyClear, .partlyCloudy:
    return ("GOOD", true)
case .cloudy, .mostlyCloudy, .sunFlurries, .sunShowers:
    return ("CLOUDY", true)
case .breezy, .windy:
    return ("WINDY", true)
case .hot:
    return ("HOT", false)
case .frigid:
    return ("COLD", false)
case .rain, .drizzle, .heavyRain, .freezingDrizzle, .freezingRain,
     .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
     .hurricane, .tropicalStorm, .hail:
    return ("RAIN", false)
case .snow, .heavySnow, .flurries, .sleet, .blizzard, .blowingSnow, .wintryMix:
    return ("SNOW", false)
case .foggy, .haze, .smoky, .blowingDust:
    return ("CHECK", false)
@unknown default:
    return ("CHECK", false)
}
```

`WINDY`/`HOT`/`COLD` 세 카테고리를 새로 만들어서, GOOD/CLOUDY/WINDY는 초록으로, HOT/COLD/RAIN/SNOW/CHECK는 빨강으로 뜨게 했다. `@unknown default`를 넣어서 나중에 Apple이 케이스를 추가해도 컴파일이 깨지지 않고 CHECK로 안전하게 떨어지도록 했다.