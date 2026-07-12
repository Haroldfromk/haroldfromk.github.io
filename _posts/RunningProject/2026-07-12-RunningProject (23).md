---
title: RunWay (23) 언어 설정
writer: Harold
date: 2026-07-12 11:33:00 +0900
categories: [RunWay]
tags: [SwiftUI, Localization, Xcode]

toc: true
toc_sticky: true
published: true
---

프로젝트를 만들고 일주일 정도 쉬면서 이것저것 생각해보다가, 3개국 언어를 지원하면 좋겠다는 생각이 들었다.

한/영/일 지원 범위를 정해야 했는데, 온보딩 마지막 페이지(개인정보 처리방침)는 이미 자체 언어 선택 로직이 있었지만 나머지 화면은 전부 한국어 하드코딩이었다.

앱 전체를 다 바꾸긴 부담이 커서 범위를 좁혔다. GPWS, SINK RATE, ROTATE, RUNWAY 같은 항공 용어는 컨셉상 영어로 남기고, 에러 다이얼로그와 빈 상태 문구 같은 일반 UI 텍스트만 옮기기로 했다.

온보딩 첫 페이지 기준으로 한국어/일본어가 이렇게 나뉜다. RUNWAY 브랜드명과 아이콘은 그대로 두고, 설명 문구와 SKIP/NEXT 버튼만 언어별로 바뀐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/runway23-onboarding-ko.png){: width="45%" height="45%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/runway23-onboarding-ja.png){: width="45%" height="45%"}

---

## 프로젝트 언어 설정

먼저 프로젝트에 언어를 추가한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/langadd.png){: width="50%" height="50%"}

영어만 있는 목록에서 +를 눌러 한국어와 일본어를 추가했다.

---

## xcstrings 파일 만들기

Command + N으로 템플릿 파일을 추가할 때 `string`으로 검색하면 String Catalog가 나온다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/string.png){: width="50%" height="50%"}

근데 파일을 만들어 놓기만 하면 목록이 비어있다. 빌드를 한 번 돌려야 코드 안에서 `Text("문자열")`처럼 리터럴로 쓰인 문자열들을 Xcode가 스캔해서 카탈로그에 채워준다. 그렇게 채워진 목록에서 언어별 칸에 번역만 입력해주면 끝이다.

[Localizing and varying text with a string catalog Docs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog){:target="_blank"}

Info.plist 권한 문구는 이 파일이랑은 따로 관리해야 했다. 방법이 두 가지였는데, `Info.plist`를 선택하고 File Inspector에서 **Localize...** 를 누르거나, String Catalog를 새로 만들 때 파일 이름을 `InfoPlist`로 지정하는 거였다. 이름을 굳이 `InfoPlist`로 맞춰야 Xcode 빌드 시스템이 이걸 Info.plist 키 로컬라이즈용으로 알아본다.

번역 내용은 AI에 맡겼고, xcstrings 포맷으로 변환해달라고 해서 source code로 바꿔 내용을 채웠다.

이렇게 두 파일(Localizable, InfoPlist)을 추가하면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/complete.png){: width="50%" height="50%"}

Resources에 2개로 바뀐 걸 확인할 수 있다.

---

## String Catalog와 LocalizedStringKey

Xcode 15부터는 `Localizable.strings` 대신 `.xcstrings` 포맷의 String Catalog를 쓴다. `Text("문자열")`을 코드에 그대로 두면 Xcode가 자동으로 추출해서 번역 테이블을 만들어주는 방식이라, 화면에 직접 박혀있는 리터럴 문자열은 카탈로그에 항목만 채워두면 별도 코드 수정 없이 로컬라이즈된다.

문제는 `AlertItem`처럼 런타임에 값이 흘러 다니는 경우였다.

```swift
struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
```

`AlertContext.unableToGetLocations` 같은 static 값을 만들 때는 문자열 리터럴을 쓰지만, 실제로 화면에 뜰 때는 `runViewModel.alertItem?.title` 같은 변수를 거쳐서 `.alert(...)`에 전달된다. SwiftUI의 자동 로컬라이즈는 소스 코드에 리터럴이 직접 있을 때만 걸리고, 변수를 한 번이라도 거치면 그냥 verbatim 텍스트로 취급한다. 카탈로그에 번역을 다 채워놔도 안 먹히는 이유가 이거였다.

해결은 타입을 바꾸는 것이었다.

```swift
struct AlertItem: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
}
```

찾아보니 `LocalizedStringKey`가 `ExpressibleByStringLiteral`을 채택하고 있어서 그런 거였다. `AlertContext`에서 `title: "Location Error"`처럼 리터럴을 대입하는 순간 자동으로 `LocalizedStringKey`로 추론되고, 이 값이 변수를 타고 흘러가도 타입 자체가 "로컬라이즈 대상"이라는 정보를 갖고 있으니 `Text(item.message)`나 `.alert(item.title, ...)`에서도 테이블을 제대로 조회하는 것이었다.

[LocalizedStringKey Docs](https://developer.apple.com/documentation/swiftui/localizedstringkey){:target="_blank"}
[ExpressibleByStringLiteral Docs](https://developer.apple.com/documentation/swift/expressiblebystringliteral){:target="_blank"}

같은 문제가 `OnboardingScaffold`의 `title`, `subtitle`, `buttonLabel`에도 있었다. 온보딩 5개 페이지가 전부 이 컴포넌트 하나를 공유하고 있어서, 여기 한 곳만 고치면 전부 적용됐다.

```swift
// before
struct OnboardingScaffold<Mockup: View>: View {
    let title: String
    let subtitle: String
    // 생략
}

private var buttonLabel: String {
    if !isLastPage { return "NEXT" }
    return hasAgreedToPrivacyPolicy ? "START" : "AGREE TO CONTINUE"
}

// after
struct OnboardingScaffold<Mockup: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    // 생략
}

private var buttonLabel: LocalizedStringKey {
    if !isLastPage { return "NEXT" }
    return hasAgreedToPrivacyPolicy ? "START" : "AGREE TO CONTINUE"
}
```

타입만 바꿨을 뿐, 각 페이지에서 `title: "RUNWAY"`, `subtitle: "A320 운항 절차와..."` 처럼 호출하는 코드는 한 글자도 안 건드렸다. 리터럴이 어떤 타입으로 추론되는지만 바뀐 거라 호출부는 그대로 컴파일된다.

---

## 일부러 번역하지 않은 문구

Home 화면의 "Good Day, Crew."와 "Ready for your next flight?"는 처음엔 다른 문구들처럼 한/영/일 전부 채워 넣었다. 그런데 다시 보니 에러 메시지나 안내 문구랑 성격이 달랐다. 앱의 톤을 만드는 인사말이라, RUNWAY라는 브랜드명처럼 항상 영어로 남기는 게 더 자연스러웠다.

```swift
Text("Good Day, Crew.")
Text("Ready for your next flight?")
```

---

## Info.plist 권한 문구

`NSLocationWhenInUseUsageDescription` 같은 권한 설명 문구들은 처음부터 한국어로 하드코딩되어 있었다. 사용자가 권한을 허용할지 말지 판단하는 순간에 보여주는 문구라 이해가 안 되면 바로 거부로 이어질 수 있어서 제대로 다국어 처리가 필요했다.

앞서 말했듯 Info.plist 문자열은 `Localizable.xcstrings`가 아니라 `InfoPlist.xcstrings`라는 별도 이름의 카탈로그로 관리해야 했다. 파일명만 다르고 만드는 방식은 똑같다. Info.plist에 있던 원래 값은 지우지 않고 그대로 남겨뒀는데, 카탈로그에 없는 언어로 접근했을 때 fallback으로 쓰이기 때문이다.

```json
"NSLocationWhenInUseUsageDescription" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Location access is needed to track your GPS route while running." } },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "ランニング中のGPSルート追跡のため、位置情報が必要です。" } },
    "ko" : { "stringUnit" : { "state" : "translated", "value" : "러닝 중 GPS 경로 추적을 위해 위치 정보가 필요합니다." } }
  }
}
```

빌드 후 앱 번들 안의 `ko.lproj`/`en.lproj`/`ja.lproj`에 `InfoPlist.strings`가 제대로 생성된 것까지 확인했는데, 정작 시뮬레이터에서 권한 팝업을 띄워보니 시스템 언어를 일본어로 바꿔도 설명 문구만 한국어로 나왔다.

원인은 두 가지가 겹쳐 있었다. 하나는 권한 팝업이 앱이 아니라 OS가 직접 그리는 화면이라 `-AppleLanguages` 같은 앱 실행 인자로는 안 바뀌고, 시뮬레이터 자체의 시스템 언어를 바꿔야 한다는 점. 다른 하나는 훨씬 단순한 실수였다. `InfoPlist.xcstrings`를 추가하고 재빌드까지 했는데, 시뮬레이터에 새 빌드를 재설치하는 걸 깜빡했다.

앱을 지우고 새 빌드로 다시 설치하고 나서야 권한 팝업 문구가 일본어로 나왔다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/runway23-permission-ja.png){: width="50%" height="50%"}

---

## 개인정보 처리방침 화면에 남아있던 문구

온보딩을 다시 훑어보다가 마지막 페이지(개인정보 처리방침)에 아직 한국어로 고정된 문구가 몇 개 남아있는 걸 발견했다. 체크박스 옆 "개인정보 처리방침에 동의합니다"랑, 동의를 안 했을 때 뜨는 "동의하지 않으면 앱을 사용할 수 없습니다.\n앱을 종료해주세요." 두 개.

이 화면은 원래부터 `selectedLanguage`라는 자체 세그먼트 피커(한국어/English/日本語)로 정책 본문을 전환하고 있었다. 그런데 체크박스 문구랑 경고 문구는 그 스위치에 안 걸리고 그냥 한국어 리터럴로 박혀 있었던 거다.

```swift
Text("개인정보 처리방침에 동의합니다")
// ...
Text("동의하지 않으면 앱을 사용할 수 없습니다.\n앱을 종료해주세요.")
```

여기는 오히려 `Localizable.xcstrings` 카탈로그로 옮기는 게 안 맞는 케이스였다. 카탈로그는 시스템 언어를 따라가는데, 이 화면은 시스템 언어랑 무관하게 자체 피커로 언어를 고르는 구조다. 시스템은 일본어인데 화면 안에서 한국어 탭을 눌렀다면, 본문은 한국어인데 체크박스만 일본어로 나오는 식으로 어긋날 수 있다.

그래서 본문(`koreanPolicy`/`englishPolicy`/`japanesePolicy`)이랑 똑같이, `selectedLanguage` 값을 보고 분기하는 computed property를 추가하는 쪽으로 갔다.

```swift
private var agreeCheckboxLabel: String {
    switch selectedLanguage {
    case 1: return "I agree to the Privacy Policy"
    case 2: return "プライバシーポリシーに同意します"
    default: return "개인정보 처리방침에 동의합니다"
    }
}

private var mustAgreeWarning: String {
    switch selectedLanguage {
    case 1: return "You must agree to use the app.\nPlease close the app."
    case 2: return "同意しない場合、アプリをご利用いただけません。\nアプリを終了してください。"
    default: return "동의하지 않으면 앱을 사용할 수 없습니다.\n앱을 종료해주세요."
    }
}
```

상단의 "아래 내용을 확인 후 동의해주세요"도 같은 문제라 `consentSubtitle`이라는 이름으로 하나 더 추가했다. 세 개 다 `Text(agreeCheckboxLabel)`처럼 리터럴 자리에 변수만 끼워 넣으면 끝이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-23/lang.gif){: width="50%" height="50%"}