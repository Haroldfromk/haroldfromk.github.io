---
title: RunWay (19) TestFlight 배포 준비
writer: Harold
date: 2026-07-01 11:33:00 +0900
#last_modified_at: 2026-07-01 08:33:00 +0900
categories: [RunWay]
tags: [TestFlight, AppStoreConnect, Xcode]

toc: true
toc_sticky: true
published: true
---

이제 배포전 TestFlight를 준비한다.

---

## 앱 아이콘

앱아이콘은 워치 둘다 만들어 둔 상태이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/appicon.png){: width="50%" height="50%"}

워치도 아이콘은 같아서 이미지는 패스

---

## 버전 / 빌드 넘버

버전 / 빌드 역시 초기값 그대로 해둔 상태이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/versionbuild.png){: width="50%" height="50%"}

Xcode에서 프로젝트 타겟을 선택하고 General 탭의 Identity 섹션에서 설정한다. Version은 사용자에게 보이는 버전 번호(1.0)이고, Build는 App Store Connect에서 빌드를 구분하는 내부 번호다. TestFlight에 같은 버전으로 여러 번 올릴 경우 Build 번호를 올려야 한다.

---

## Privacy 문구 (Info.plist)

HealthKit과 위치 권한을 사용하기 때문에 Info.plist에 권한 요청 문구가 반드시 있어야 한다. 없으면 App Store 심사에서 리젝된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/plist.png){: width="70%" height="70%"}

iPhone과 Watch 타겟 양쪽 다 세팅해두었다. 위치는 `When In Use`와 `Always and When In Use` 두 가지, HealthKit은 `Share`와 `Update` 두 가지를 각각 추가했다.

---

## App Store Connect 등록

[App Store Connect](https://appstoreconnect.apple.com)에서 새 앱을 등록한다. Apps → + 버튼 → 신규 앱으로 생성하면 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/appstoreconnect_new.png){: width="70%" height="70%"}

- 플랫폼: iOS
- 이름: RunWay
- 기본 언어: 영어(미국)
- 번들 ID: Xcode 프로젝트의 번들 ID와 동일하게 선택
- SKU: 내부 식별용 코드로 App Store에 표시되지 않는다. 번들 ID 기반으로 작성했다.
- 사용자 액세스 권한: 전체 액세스 (외부 테스터 초대 예정)

생성 버튼을 누르면 App Store Connect에 앱이 등록된다.

다만 앱이름인 RunWay가 중복이라 RunWay: Every Run Is A Flight로 해주었다.

---

## Signing & Capabilities

Xcode에서 프로젝트 타겟 → Signing & Capabilities 탭에서 설정한다. iPhone과 Watch 타겟 양쪽 다 확인해야 한다.

- **Team**: Apple Developer 계정 선택
- **Bundle Identifier**: 각 타겟에 맞게 설정
- **Automatically manage signing**: 체크하면 Xcode가 프로비저닝 프로파일을 자동으로 관리해준다.

Capabilities에서 HealthKit, Background Modes(Location updates, Workout processing)가 추가되어 있는지 확인한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/signing.png){: width="70%" height="70%"}

---

## 아카이브 & 업로드

Xcode에서 실기기 또는 `Any iOS Device (arm64)`를 선택한 후 Product → Archive로 아카이브를 생성한다. 시뮬레이터가 선택된 상태에서는 Archive 메뉴가 비활성화되니 주의. Watch 앱은 따로 아카이브할 필요 없이 iPhone 타겟 아카이브에 자동으로 번들링된다.

아카이브가 완료되면 Xcode Organizer가 자동으로 열린다. 생성된 아카이브를 선택하고 Distribute App을 누르면 배포 방식을 선택할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/archive.png){: width="70%" height="70%"}

외부 테스터도 초대할 예정이라 **App Store Connect**를 선택했다. `TestFlight Internal Only`는 팀 내부 멤버만 테스트 가능하고, App Store Connect를 선택해야 외부 테스터 초대가 가능하다.

업로드가 완료된 후 App Store Connect → TestFlight에서 빌드가 처리되기까지 어느 정도 시간이 걸린다. Watch 앱이 포함된 빌드는 HealthKit 같은 민감한 프레임워크 검증이 추가로 들어가서 30분 이상 걸리는 경우도 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/upload.png){: width="50%" height="50%"}

업로드는 완료됐지만 처리가 끝날 때까지 기다려야 한다. 실제로 이번엔 약 1시간 정도 걸렸다.

빌드 처리가 완료되면 아래와 같이 TestFlight에 빌드가 등록된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/upload1.png){: width="50%" height="50%"}

이때 수출 규정 관리 문서 관련 질문이 나오는데, RunWay는 자체 암호화 알고리즘을 구현하지 않으므로 "위에 언급된 알고리즘에 모두 해당하지 않음"을 선택했다.

이후 외부 테스팅 그룹을 생성하고 빌드를 추가한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/testing.png){: width="50%" height="50%"}

테스터 초대 방식은 공개 링크를 선택했다. 이메일 초대는 한 명씩 추가해야 해서 번거롭고, 공개 링크는 링크 하나만 공유하면 누구나 TestFlight에서 바로 설치할 수 있다. 다만 공개 링크는 외부 베타 앱 심사를 먼저 통과해야 활성화된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/link.png){: width="50%" height="50%"}

그런데 연락을 받았는데 이렇게 사진을 보내주었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/testerror.png){: width="50%" height="50%"}

공개 링크로 접속했는데 "현재 베타 앱에 새로운 테스터를 추가할 수 없습니다"라는 에러가 떴다. 확인해보니 외부 테스팅 그룹에 빌드가 추가되어 있지 않았다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/testbuild.png){: width="50%" height="50%"}

빌드를 추가할 때 테스트 내용도 작성해야 한다. 기본 언어가 영어(미국)로 설정되어 있어서 영어로 작성했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/engmessage.png){: width="50%" height="50%"}

빌드를 추가하면 외부 베타 앱 심사가 시작된다. 심사 중에는 공개 링크가 활성화되지 않는다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-01-RunningProject-19/wating.png){: width="50%" height="50%"}

심사가 완료되면 공개 링크가 활성화되고 테스트가 가능해진다.