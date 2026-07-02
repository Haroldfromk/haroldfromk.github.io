---
title: RunWay (20) App Store 출시 준비하기
writer: Harold
date: 2026-07-02 11:33:00 +0900
last_modified_at: 2026-07-03 04:33:00 +0900
categories: [RunWay]
tags: [TestFlight, AppStoreConnect, Fastlane]

toc: true
toc_sticky: true
published: true
---

TestFlight 베타 심사가 진행 중이다. 심사 결과를 기다리는 동안 손 놓고 있을 수는 없어서, App Store 정식 출시에 필요한 것들을 미리 정리해보기로 했다.

정식 출시를 위해 필요한 항목은 크게 이렇다.

- 스크린샷 (iPhone, Watch)
- 앱 설명 (짧은 설명 / 긴 설명)
- 키워드
- 카테고리
- 연령 등급
- 개인정보 처리방침 URL

하나씩 순서대로 정리한다.
다만 설명같은건 글 재주가 부족해서 AI의 도움을 받기로 했다.

## TestFlight 심사 대기, 그다음은?

현재 TestFlight 베타 심사가 진행 중이다. 심사를 통과하면 지인들에게 먼저 배포해서 실사용 피드백을 받을 계획이다.

즉시 고칠 수 있는 버그나 사용성 문제는 바로 반영하고, 좋은 아이디어나 기능 제안은 따로 모아뒀다가 1.1 버전에서 검토할 예정이다. 

정식 출시 전에 한 번이라도 더 실제 사용자 관점에서 걸러내는 게 낫다고 판단했다.

---

## 스크린샷 준비하기

App Store 스크린샷은 그냥 캡처한 화면을 올리는 게 아니라, 디바이스 프레임과 텍스트 오버레이를 입힌 마케팅용 이미지로 준비하는 게 일반적이다.

**후보로 검토한 도구**

- Figma + 디바이스 목업 플러그인 - 커스텀 자유도가 가장 높음. RunWay 항공 테마 컬러를 그대로 활용 가능
- Previewed / AppLaunchpad 계열 - 템플릿 기반, 빠르게 작업 가능
- Fastlane snapshot - 시뮬레이터 자동 캡처 도구. 꾸미기는 별도 필요

(어떤 도구로 결정했는지, 이유)

**필요한 사이즈/장수**

| 디바이스 | 필수 여부 | 사이즈 | 장수 |
|---|---|---|---|
| iPhone 6.9" | 필수 | 1320x2868 | 6장 |
| Apple Watch | 필수 | 410x502 | 3장 |

최근에는 6.9인치 세트만 있으면 나머지 사이즈는 App Store Connect가 자동 스케일링해주는 경우가 많아서, 최소한으로는 iPhone 6.9"와 Watch 하나씩만 확실히 준비하면 된다.

**실제 캡처 순서 - iPhone (6장, 스토리텔링 구성)**

1. Home - 앱 첫인상, RUNWAY 브랜드 + Mission/Free Flight 선택
2. Takeoff - Pre-flight check, 앱만의 독특한 시작 시퀀스
3. PFD Mission Flight - 핵심 기능, 목표 페이스 대비 진행 상황
4. Dynamic Island - 다른 앱엔 없는 차별점, 락스크린에서도 보이는 정보
5. Flight Summary - 실제 GPS 경로 지도, 결과물
6. Flight Calendar - 히트맵, 꾸준함/기록 관리 매력

**실제 캡처 순서 - Apple Watch (3장)**

1. Home - Mission/Free Flight 선택, iPhone과 동일한 브랜드 경험
2. Running (PFD) - 페이스/GPWS/심박/케이던스, 손목에서도 유지되는 계기판 룩
3. Summary - MISSION COMPLETE, 결과 확인 후 RETURN TO BASE

---

## 앱 설명 작성하기

**짧은 설명 (서브타이틀, 30자)**

항공 테마 러닝 트래커

**긴 설명 (4000자)**

항공 정비사 출신 개발자가 만든, 항공 계기판 컨셉의 러닝 트래커입니다.

RunWay는 단순히 페이스와 거리를 기록하는 앱이 아닙니다. 러닝을 하나의 비행으로 재해석해, 항공기 조종석의 계기판(PFD)에서 영감을 받은 화면으로 당신의 러닝 데이터를 보여줍니다.

**주요 기능**

- PFD 스타일 러닝 화면 - 항공기 계기판에서 영감을 받은 디자인으로 페이스, 거리, 시간을 한눈에
- GPWS 알림 시스템 - 항공기 경보 시스템의 이름을 빌려온 알림으로 페이스 이탈을 알려줍니다 (SINK RATE, OVERSPEED 등)
- Mission Flight / Free Flight 두 가지 모드 - 목표 페이스와 거리를 설정하는 미션 모드, 자유롭게 달리는 프리 모드
- Apple Watch 연동 - 손목에서도 PFD 스타일 화면으로 러닝 확인
- Flight Summary - 실제 GPS 경로를 지도에 기록하고 다시 확인
- Flight Calendar - 러닝 기록을 월간 히트맵으로 한눈에

**이런 분들께 추천합니다**

- 러닝을 게임처럼, 미션처럼 즐기고 싶은 분
- 항공, 비행에 관심 있는 분
- 단순한 숫자 나열이 아닌 몰입감 있는 러닝 앱을 찾는 분

지금 이륙 준비를 하세요. RunWay와 함께라면, 매일의 러닝이 하나의 비행이 됩니다.

---

## 키워드 설정하기

100자 제한, 콤마로 구분하고 공백 없이 작성한다. 앱 이름/카테고리에 이미 들어간 단어는 중복해서 넣지 않는다.

```
러닝,달리기,조깅,마라톤,페이스,러닝트래커,애플워치,항공,파일럿,비행,계기판,조종석,GPS,운동기록,헬스케어,인터벌,러닝앱,러닝기록,워치앱
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/keyworddone.png){: width="50%" height="50%"}

지금은 한/미/일 언어를 테스트 해보려고 일본어로 추가한 사진이다.

---

## 연령 등급 설정하기

이제 앱스토어의 연령을 추가해보도록 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age.png){: width="50%" height="50%"}

7단계로 구성된 설문이다. 각 항목별로 선택 근거를 정리했다.

**1단계 - 앱 내 제어**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age1.png){: width="50%" height="50%"}

유해 콘텐츠 차단, 나이 확인 모두 **아니요**. 콘텐츠 제한 기능이나 연령 인증 메커니즘이 없다.

**2단계 - 성적 테마**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age2.png){: width="50%" height="50%"}

전부 **없음**. 러닝 트래커라 성적 콘텐츠와 무관하다.

**3단계 - 의료 또는 건강**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age3.png){: width="50%" height="50%"}

의료 또는 치료 정보는 **없음**, 건강 또는 웰빙 주제는 **예**. 러닝 중 심박수, 케이던스 등 건강 데이터를 다루는 앱이라 해당된다.

**4단계 - 성적인 내용 또는 노출**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age4.png){: width="50%" height="50%"}

전부 **없음**. 해당 없다.

**5단계 - 폭력**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age5.png){: width="50%" height="50%"}

전부 **없음**. 해당 없다.

**6단계 - 우연에 기반한 활동**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age6.png){: width="50%" height="50%"}

가상 도박, 도박, 랜덤 박스 전부 **없음/아니요**. 시합 항목은 현재 없지만 추후 러닝 챌린지나 랭킹 기능이 추가될 경우 업데이트가 필요할 수 있다.

**7단계 - 결과**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/age7.png){: width="50%" height="50%"}

RunWay는 폭력, 성인, 도박 등 민감 콘텐츠가 전혀 없어서 설문은 대부분 "없음"으로 체크했다. 건강/웰빙 주제 항목에 "예"를 선택한 영향으로 결과는 **9+** 로 계산됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/agedone.png){: width="50%" height="50%"}

위치 정보 사용 여부는 등급이 아니라 개인정보 관련 섹션에서 별도로 표기한다.

---

## 개인정보 처리방침

App Store Connect에서 "앱이 수집하는 개인정보" 항목을 작성해야 한다. 

RunWay는 위치 데이터와 HealthKit 데이터를 수집하지만 모두 기기 내부(SwiftData)에만 저장되고 외부 서버로 전송되지 않는다. 

외부 분석 툴이나 광고 SDK도 사용하지 않으므로 "아니요, 이 앱에서 데이터를 수집하지 않습니다."를 선택했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/connectprivacy.png){: width="50%" height="50%"}

그러면 아래와 같이 데이터 수집 없음으로 표시된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/connectprivacydone.png){: width="50%" height="50%"}

---

개인정보 처리방침 URL도 App Store Connect 제출 시 필수 항목이다. 별도 서버를 두지 않아 포트폴리오 사이트(Vercel)에 `/privacy` 경로로 페이지를 추가하는 방식으로 해결했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/privacyadd.png){: width="50%" height="50%"}

[privacy link](https://runway-project.vercel.app/ko/privacy){:target="_blank"}

RunWay가 수집하는 데이터:

- 위치 (GPS 경로)
- HealthKit 데이터 (심박수 등)

모든 데이터는 기기 내부(SwiftData)에만 저장되며, 외부 서버로 전송되지 않는다. 분석 툴이나 크래시 리포트도 사용하지 않는다.

포트폴리오 사이트에 `/privacy` 경로로 처리방침 페이지를 추가했다.

[privacy link](https://runway-project.vercel.app/ko/privacy){:target="_blank"}

**온보딩에 동의 절차 추가**

TestFlight 외부 테스트 심사는 Info.plist의 위치/HealthKit usage description 문구만으로도 통과 가능성이 높지만, 정식 출시 심사(Guideline 5.1.1)에서는 사용자가 처리방침을 실제로 확인하고 동의하는 절차가 있는 게 안전하다고 판단했다.

기존 온보딩은 컨셉 소개 5페이지로만 구성되어 있었는데, 마지막에 개인정보 동의 페이지를 하나 추가했다. 스크롤로 전문을 끝까지 내려야 동의 체크박스가 활성화되고, 체크해야만 START 버튼이 눌리는 구조다. 동의하지 않으면 앱을 사용할 수 없다는 안내만 띄우고, 강제 종료 같은 처리는 넣지 않았다.

```swift
private var isStartDisabled: Bool { isLastPage && !hasAgreedToPrivacyPolicy }

private func complete() {
    guard hasAgreedToPrivacyPolicy else { return }
    Task {
        try? await HealthKitService.shared.requestAuthorization()
    }
    hasCompletedOnboarding = true
}
```

SKIP 버튼은 컨셉 소개 페이지들은 건너뛸 수 있게 두되, 누르면 동의 페이지로 바로 이동하도록 했다. 즉 어떤 경로로도 동의 자체는 건너뛸 수 없다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/privacy.gif){: width="50%" height="50%"}

---

## TestFlight 배포 완료 (07.03)

외부 테스트 심사가 통과되었다. 공개 링크가 활성화되어 이제 링크만 공유하면 누구든 TestFlight를 통해 앱을 설치할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/testdone.png){: width="50%" height="50%"}

모바일에선 링크를 누르니 이렇게 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/IMG_3966.PNG){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-02-RunningProject-20/IMG_3967.jpg){: width="50%" height="50%"}

이전에 팀 프로젝트로 배포해본 적은 있지만, 혼자서 기획부터 개발까지 전부 진행한 앱이 외부에 공개된 건 이번이 처음이다. 이제 실제 사용자 피드백을 받으면서 버그를 잡고 App Store 정식 출시를 준비하면 된다.