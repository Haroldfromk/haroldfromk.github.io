---
title: RunWay (25) App Store 배포
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