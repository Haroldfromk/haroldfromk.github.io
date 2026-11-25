---
title: RunWay 1.5 (1) 달린 거리가 계급이 되는 기장 면허증
writer: Harold
date: 2026-11-05 04:30:00 +0900
categories: [RunWay, SwiftUI]
tags: [SwiftUI, SwiftData, AppStorage, Concurrency, SwiftTesting]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

지금까지 RunWay 는 기능 중심이었다. 뛰고, 기록하고, 되돌아보는 화면은 있는데 뛰어도 쌓이는 게 보이지 않았다. 로그북은 기록 목록이고 디브리핑은 러닝 분석을 모아 보는 화면이라, 쌓인 거리와 계급으로 "지금까지의 나"를 말해 주는 곳이 없었다.

그래서 프로필 화면을 만들었다. 수치를 늘어놓는 대시보드 대신 **누적 거리로 계급이 오르고, 오르는 순간을 축하하는 면허증**이다. 앱이 처음부터 항공 용어로 일관되어 있어서 계급도 조종사 계급으로 정했다. 훈련생에서 시작해 부기장, 기장을 지나 교관까지 일곱 단계다. 화면에는 한글 이름 없이 영문 이름 한 줄만 보여 준다.

![누적 290.9 KM 로 SECOND OFFICER 계급인 면허증 화면. 면허번호와 발급일, 비행 횟수, 최고 기록, 최근 비행이 한 화면에 들어간다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-05-RunningProject-58/runway-profile-screen.png)

이 글은 v1.5 의 첫 작업인 프로필 화면을 다룬다. 계급을 정하는 계산, 이미지 없이 도형으로 그린 견장(어깨에 다는 계급장), 계급이 오를 때 줄이 꽂히는 장면, 그리고 그 장면을 만들다가 만난 취소 문제까지 적는다.

---

## 탭 다섯 개에서 네 개로

프로필을 넣으려면 탭 자리가 필요했다. 아이폰은 탭이 다섯 개를 넘으면 "더 보기"로 접어 버린다. 기존 탭은 Deck, Logbook, Alerts, Debrief, Settings 다섯 개였다.

```swift
TabView {
    // 생략 (Deck)
    NavigationStack { LogbookView() }
        .tabItem { Label("Logbook", systemImage: "list.bullet.clipboard") }
    DebriefView()
        .tabItem { Label("Debrief", systemImage: "chart.line.uptrend.xyaxis") }
    NavigationStack { ProfileView() }
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
}
.tint(.rwGreen)
```

#### TabView와 tabItem으로 탭 만들기

[`TabView`](https://developer.apple.com/documentation/swiftui/tabview){:target="_blank"}는 아래쪽에 탭 바를 만들고 탭마다 화면 하나를 연결하는 틀이다. 안에 넣은 화면이 탭 하나가 된다. 각 화면 뒤에 붙인 [`tabItem(\_:)`](https://developer.apple.com/documentation/swiftui/view/tabitem%28%5F%3A%29){:target="_blank"}이 탭 바에 보일 모양을 정한다. 모양은 글자와 아이콘을 한 쌍으로 묶는 [`Label`](https://developer.apple.com/documentation/swiftui/label){:target="_blank"}로 만들고, 아이콘은 `systemImage` 에 Apple 이 기본으로 주는 SF Symbols 이름을 넣는다. 코드 끝의 `.tint(.rwGreen)` 은 [`tint(\_:)`](https://developer.apple.com/documentation/swiftui/view/tint%28%5F%3A%29){:target="_blank"}으로 탭 바의 강조색을 정한다.

[`NavigationStack`](https://developer.apple.com/documentation/swiftui/navigationstack){:target="_blank"}은 화면을 위로 쌓아 올리고 뒤로 가기를 만들어 주는 틀이다. 탭 하나가 자기만의 쌓기 흐름을 갖도록 Logbook 과 Profile 은 각각 감쌌다.

빠진 것은 Alerts 와 Settings 다. Alerts 는 탭 바에서만 뺐다. `AlertsView` 와 경고를 모으는 코드는 그대로 두었다. 지금은 누적 경고 이력을 볼 길이 없어졌지만, 되돌리는 게 `TabView` 안의 몇 줄이라 그렇게 했다. 개별 기록 안의 경고는 요약 화면에 그대로 남아 있다.

Settings 는 탭이 아니라 프로필 오른쪽 위 톱니 버튼으로 들어가는 화면이 됐다.

```swift
.customNavHeader("PROFILE", showsBackButton: false) {
    NavigationLink {
        SettingsView()
    } label: {
        Image(systemName: "gearshape")
            // 생략
    }
}
```

#### NavigationLink로 톱니 버튼에서 설정 화면 열기

[`NavigationLink`](https://developer.apple.com/documentation/swiftui/navigationlink){:target="_blank"}는 눌렀을 때 다른 화면을 쌓아 올리는 버튼이다. 뒤의 중괄호가 도착할 화면(`SettingsView()`)이고, `label` 쪽이 버튼 모양이다. [`Image(systemName:)`](https://developer.apple.com/documentation/swiftui/image/init%28systemname%3A%29){:target="_blank"}은 SF Symbols 이름으로 아이콘을 만든다. 여기서는 톱니 모양 `gearshape` 를 썼다. `customNavHeader` 는 앱이 직접 만든 상단 막대이고, 오른쪽 위에 붙일 뷰를 마지막 중괄호로 받는다.

설정 화면 쪽에서 바뀐 것은 두 가지다. 상단 막대를 부르는 줄에서 `showsBackButton: false` 를 뺐다. 탭의 맨 앞 화면이던 시절에는 뒤로 가기가 없어야 했지만, 이제는 프로필에서 들어오는 화면이라 뒤로 가기가 있어야 한다. 나머지는 주석 문구뿐이다.

---

## 누적 거리로 정하는 계급

계급은 **지금까지 기록한 거리를 모두 더한 값**으로 정한다. 기록은 SwiftData(앱의 기록을 기기에 저장하는 Apple 프레임워크)에서 [`@Query`](https://developer.apple.com/documentation/swiftdata/query){:target="_blank"}(저장된 기록을 읽어 오고 바뀌면 화면을 다시 그리는 표시)로 읽어 오고, 일곱 단계다.

| 계급 | 뜻 | 견장 | 누적 거리(km) |
|---|---|---|---|
| STUDENT PILOT | 훈련생 | 줄 없음 | 0 |
| CADET | 훈련 조종사 | 1줄 | 30 |
| SECOND OFFICER | 부조종사 | 2줄 | 100 |
| FIRST OFFICER | 부기장 | 3줄 | 300 |
| CAPTAIN | 기장 | 4줄 | 1,000 |
| SENIOR CAPTAIN | 선임기장 | 4줄과 별 1개 | 2,500 |
| CHECK AIRMAN | 교관 | 4줄과 별 2개 | 5,000 |

뜻 칸은 이 글에서 설명하려고 적은 것이고 앱 화면에는 나오지 않는다. 앱은 영어, 일본어, 한국어를 지원하는데 계급 이름은 세 언어 모두 영문으로 똑같이 보인다. 번역할 게 없으니 계급 이름 때문에 언어마다 카드 높이가 달라질 일은 없다.

실제 민항 견장은 4줄이 최대라서 그 위는 별로 올라가게 했다. 끝 계급은 5,000km 라서 몇 년을 뛰어야 닿는다. 몇 번 뛰고 최고 계급이 되면 계급이 의미를 잃기 때문이다.

```swift
enum PilotRank: Int, CaseIterable, Comparable {
    case studentPilot = 0, cadet, secondOfficer, firstOfficer, captain, seniorCaptain, checkAirman

    /// 소수 오차 허용치(km). 계급 판정과 표시 올림/내림이 같은 값을 쓴다.
    fileprivate static let tolerance = 1e-9

    static func < (lhs: PilotRank, rhs: PilotRank) -> Bool { lhs.rawValue < rhs.rawValue }

    var minimumDistance: Double {
        switch self {
        case .studentPilot: 0
        case .cadet: 30
        case .secondOfficer: 100
        case .firstOfficer: 300
        case .captain: 1000
        case .seniorCaptain: 2500
        case .checkAirman: 5000
        }
    }

    // 생략 (title, stripes, stars)

    var next: PilotRank? { PilotRank(rawValue: rawValue + 1) }

    init(totalDistance km: Double) {
        self = Self.allCases.last { km + Self.tolerance >= $0.minimumDistance } ?? .studentPilot
    }
}
```

#### CaseIterable과 Comparable로 계급 순서 다루기

`enum` 은 "여러 경우 중 하나"를 뜻하는 타입이다. 계급은 일곱 경우 중 하나이므로 `enum` 이 맞다. `: Int` 를 붙이면 각 경우가 0부터 번호(`rawValue`)를 갖고, `PilotRank(rawValue: 3)` 처럼 번호로 경우를 만들 수 있다. 번호가 맞는 경우가 없으면 `nil`(값이 없음)이 나온다. `next` 가 `Optional`(값이 없을 수도 있는 타입)인 이유다. 맨 위 계급은 다음이 없다.

- [`CaseIterable`](https://developer.apple.com/documentation/swift/caseiterable){:target="_blank"}을 따르면 모든 경우가 선언한 순서대로 담긴 배열 [`allCases`](https://developer.apple.com/documentation/swift/caseiterable/allcases-swift.type.property){:target="_blank"}를 공짜로 얻는다.
- [`Comparable`](https://developer.apple.com/documentation/swift/comparable){:target="_blank"}을 따르면 `<`, `<=` 로 크기를 비교할 수 있다. 직접 `<` 를 만들어 번호로 비교하게 했고, 나머지 비교 연산은 이 하나에서 자동으로 나온다. 그래서 뒤에서 `$0 <= current` 같은 비교를 쓸 수 있다.
- [`last(where:)`](https://developer.apple.com/documentation/swift/bidirectionalcollection/last%28where%3A%29){:target="_blank"}는 배열을 뒤에서부터 보며 조건에 맞는 첫 원소를 돌려준다. 누적 거리가 기준 이상인 계급 중 **가장 높은 것**이 지금 계급이라서 뒤에서부터 찾는다. 하나도 없으면 `nil` 이라 `?? .studentPilot` 으로 막았다.

거리를 더하는 쪽도 있다.

```swift
enum PilotStats {
    /// 손상된 값(NaN, 무한대, 음수)은 더하지 않는다.
    static func totalDistance(of flights: [SwiftDataFlight]) -> Double {
        flights.reduce(0) { $1.distance.isFinite && $1.distance >= 0 ? $0 + $1.distance : $0 }
    }
}
```

#### reduce와 isFinite로 안전하게 거리 더하기

[`reduce(\_:\_:)`](https://developer.apple.com/documentation/swift/sequence/reduce%28%5F%3A%5F%3A%29){:target="_blank"}는 배열을 앞에서부터 돌며 하나의 값으로 합치는 함수다. 첫 인자 `0` 이 시작값이고, 중괄호 안에서 `$0` 은 지금까지 합친 값, `$1` 은 이번 원소다. 이번 비행의 거리가 정상이면 더하고, 아니면 합을 그대로 둔다. [`isFinite`](https://developer.apple.com/documentation/swift/double/isfinite){:target="_blank"}는 숫자가 `NaN`(숫자가 아님)도 무한대도 아닐 때 `true` 다. 기록 하나가 망가져도 계급 전체가 망가지지 않게 `NaN`, 무한대, 음수는 더하지 않는다.

---

### 부동소수 오차란?

위 코드의 `tolerance` 는 **부동소수 오차** 때문에 둔 값이다. 컴퓨터는 소수를 정확히 저장하지 못하는 경우가 많고 아주 가까운 값으로 저장한다. 0.1 을 열 번 더하면 1 이 아니라 0.9999999999999999 가 나오는 식이다. 눈금자로 1 의 3분의 1 을 재서 세 번 이으면 끝이 살짝 모자랄 수 있는 것과 같다.

문제는 이 오차가 계급 경계에서 나타날 때다. 실제로는 정확히 30km 를 뛰었는데 거리 합이 29.99999999999998 로 나오면, 그냥 `>= 30` 으로 비교했을 때 거짓이 되어 CADET 이 되지 못한다. 계급 시험에서 0.00000000000002km 때문에 떨어지는 셈이다.

그래서 비교할 때 `1e-9`(0.000000001km, 1밀리미터의 천분의 일 정도)만큼 봐준다. 경계에 걸린 값(29.99999999999998)은 테스트에도 그대로 있다.

```swift
@Test func 소수_오차로_경계에_못_미쳐도_같은_계급이다() {
    #expect(PilotRank(totalDistance: 29.99999999999998) == .cadet)
    #expect(DistanceText.total(29.99999999999998) == "30.0")
    #expect(RankProgress(totalDistance: 29.99999999999998).fraction == 0)
}
```

#### @Test와 #expect로 계산 확인하기

[`@Test`](https://developer.apple.com/documentation/testing/test%28%5F%3A%5F%3A%29){:target="_blank"}는 이 함수가 테스트라고 표시하고, [`#expect`](https://developer.apple.com/documentation/testing/expectations){:target="_blank"}는 괄호 안의 조건이 참인지 확인해 거짓이면 실패로 기록한다. `RankProgress` 는 지금 계급 구간에서 다음 계급까지 얼마나 왔는지 계산하는 타입이고 `fraction` 이 그 비율(0에서 1)이다.

계급만 봐주면 끝이 아니다. 화면에 찍는 숫자가 계급과 어긋나면 안 된다. "299.96km" 를 반올림해 "300.0km" 로 보여 주면서 계급은 아직 SECOND OFFICER 인 화면이 나올 수 있다. 그래서 누적 거리는 **내림**, 다음 계급까지 남은 거리는 **올림**으로 찍는다.

```swift
enum DistanceText {
    static func total(_ km: Double) -> String {
        String(format: "%.1f", floor((km + PilotRank.tolerance) * 10) / 10)
    }

    static func remaining(_ km: Double) -> String {
        String(format: "%.1f", ceil((km - PilotRank.tolerance) * 10) / 10)
    }
}
```

#### String(format:)와 floor, ceil로 소수 첫째 자리 만들기

[`String(format:\_:)`](https://developer.apple.com/documentation/foundation/nsstring/init%28format%3A%5F%3A%29){:target="_blank"}은 C 언어식 서식 문자열로 문자열을 만든다. `%.1f` 는 "소수 첫째 자리까지 쓴 실수"라는 뜻이다. 이 서식은 반올림하므로 먼저 `floor`(내림)나 `ceil`(올림)로 값을 소수 첫째 자리에 맞춰 둔다. 10 을 곱해 정수 자리에서 내림이나 올림을 하고 다시 10 으로 나누면 소수 첫째 자리가 된다. `floor` 는 소수점 아래를 버려 작은 쪽 정수로, `ceil` 은 올려 큰 쪽 정수로 맞춘다. 예를 들어 `floor(2.9)` 는 2, `ceil(2.1)` 은 3 이다.

테스트에 실제로 있는 값은 이렇다.

| 입력(km) | 누적 표시 | 남은 거리 표시 | 이유 |
|---|---|---|---|
| 299.96 | 299.9 | 0.1 | 아직 FIRST OFFICER 가 아니라 "300.0" 도 "0.0 남음" 도 나오면 안 된다 |
| 291.4 | 291.4 | 8.6 | 정확히 떨어지는 값은 그대로 나온다 |
| 29.99999999999998 | 30.0 | 테스트 없음 | 계급이 CADET 이 되므로 30.0 으로 찍는다 |

기록을 전부 지우면 계급이 내려가고, 백업에서 복원하면 다시 오른다. 계급을 따로 저장하지 않고 기록에서 매번 계산하기 때문이다. 저장하는 값이 없으니 기록과 계급이 어긋날 일이 없다.

---

## 첫 비행에서 나오는 면허번호

면허증에는 기수(`26-B`)와 면허번호(`RW-2606-0042`)가 찍힌다. 둘 다 **저장하지 않고 첫 비행 날짜에서 매번 계산한다.** 난수를 만들어 저장하는 방식은 쓰지 않았다. 같은 기록을 백업에서 복원하면 같은 번호가 나와야 하기 때문이다.

```swift
enum LicenseText {
    /// 기기 달력 설정(불기, 연호 등)과 상관없이 그레고리력으로 계산한다.
    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// 예: 26-B (연도 뒤 두 자리 + 분기 A/B/C/D)
    static func cohort(firstFlight: Date, timeZone: TimeZone = .current) -> String {
        let parts = calendar(in: timeZone).dateComponents([.year, .month], from: firstFlight)
        let quarter = ["A", "B", "C", "D"][((parts.month ?? 1) - 1) / 3]
        return String(format: "%02d-%@", (parts.year ?? 0) % 100, quarter)
    }

    /// 예: RW-2606-0042 (뒤 네 자리는 첫 비행 시각의 초 단위 값에서 나온다)
    static func number(firstFlight: Date, timeZone: TimeZone = .current) -> String {
        let parts = calendar(in: timeZone).dateComponents([.year, .month], from: firstFlight)
        let last4 = Int(firstFlight.timeIntervalSince1970) % 10000
        return String(format: "RW-%02d%02d-%04d", (parts.year ?? 0) % 100, parts.month ?? 0, last4)
    }

    // 생략 (issued, flightDay)
}
```

#### Calendar와 dateComponents로 날짜에서 연도와 월 뽑기

1. [`Calendar`](https://developer.apple.com/documentation/foundation/calendar){:target="_blank"}는 시각을 연, 월, 일로 읽어 주는 달력이다. `Calendar(identifier: .gregorian)` 으로 달력의 종류를 직접 골랐다. 기기를 불기(태국 달력)나 일본 연호로 설정한 사람도 같은 `26-B` 가 나오게 하려는 것이다.
2. `calendar.timeZone` 에 [`TimeZone`](https://developer.apple.com/documentation/foundation/timezone){:target="_blank"}을 넣어 어느 지역의 시각으로 읽을지 정한다. 같은 순간이라도 서울과 UTC(세계 표준시)에서는 날짜가 다를 수 있다. 테스트에서 2027년 1월 1일 0시(서울)는 서울 기준으로는 `27-A`, UTC 기준으로는 `26-D` 가 나온다. 기본값을 `.current`(기기의 시간대)로 두고 인자로 받게 한 이유는 테스트에서 시간대를 고정하려는 것이다. 기기의 시간대로만 돌면 테스트 결과가 돌리는 곳에 따라 달라진다.
3. [`dateComponents(\_:from:)`](https://developer.apple.com/documentation/foundation/calendar/datecomponents%28%5F%3Afrom%3A%29){:target="_blank"}는 `Date` 에서 `.year`, `.month` 같은 요소를 꺼내 준다. 값은 모두 `Int?` 라서 `??` 로 기본값을 줬다. 기수의 월은 `?? 1` 이다.
4. 분기는 `(월 - 1) / 3` 으로 0 에서 3 까지의 번호를 만들어 `["A", "B", "C", "D"]` 에서 고른다. 1월에서 3월은 A, 4월에서 6월은 B 다. 정수끼리 나누면 소수점 아래가 버려져서 쓸 수 있는 계산이다.
5. 문자열을 만드는 `String(format:)` 의 `%02d` 는 두 자리가 되도록 0 을 앞에 채운 정수이고 `%@` 는 문자열이다. 그래서 26년 6월이 `2606` 이 된다.
6. 면허번호 뒤 네 자리는 [`timeIntervalSince1970`](https://developer.apple.com/documentation/foundation/date/timeintervalsince1970){:target="_blank"}(1970년 1월 1일부터 지난 초)를 `Int` 로 바꿔 10000 으로 나눈 나머지다. 소수점 아래 초는 버려지므로 같은 초 안의 차이로는 번호가 바뀌지 않는다. 테스트는 정수 초 시각과 그 0.4초 뒤가 같은 번호인지 확인한다.

연도와 월은 시간대의 영향을 받지만 뒤 네 자리는 받지 않는다. 같은 순간에서 나온 초 단위 값은 어디서나 같기 때문이다.

이름은 저장하기 전에 다듬는다.

```swift
enum PilotName {
    static let maxLength = 24

    static func normalized(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }

    static func display(_ stored: String) -> String {
        stored.isEmpty ? "PILOT" : stored.uppercased()
    }
}
```

#### trimmingCharacters와 prefix로 이름 다듬기

[`trimmingCharacters(in:)`](https://developer.apple.com/documentation/foundation/nsstring/trimmingcharacters%28in%3A%29){:target="_blank"}은 문자열 양쪽 끝에서 지정한 문자를 걷어 낸다. [`.whitespacesAndNewlines`](https://developer.apple.com/documentation/foundation/characterset/whitespacesandnewlines){:target="_blank"}는 공백과 줄바꿈을 모은 묶음이다. [`prefix(\_:)`](https://developer.apple.com/documentation/swift/collection/prefix%28%5F%3A%29){:target="_blank"}는 앞에서 지정한 개수만큼만 남긴다. 그래서 이름은 앞뒤 공백을 걷어 내고 24자까지만 남는다. 이름이 비면 면허증에는 `PILOT` 이 찍히고, 이름은 대문자로 보여 준다(한글은 그대로다).

---

## 짧은 전력질주가 차지하지 못하는 최고 기록

프로필에는 최장 거리, 최장 시간, 최고 페이스(가장 빠른 평균 페이스) 세 칸이 있다. 여기서 피하고 싶었던 것은 **200m 를 전력으로 뛴 기록이 최고 페이스 칸을 영구히 차지하는 일**이다. 한 번 그렇게 박히면 그 칸은 영영 의미가 없어진다.

기준을 새로 만들지 않고 이미 있는 것을 썼다. 디브리핑이 "분석할 만한 러닝인가"를 가를 때 쓰는 `isAnalysisEligible` 이 거리 3km 이상이다(`RunAnalysis.swift`). 최고 기록도 3km 이상인 기록만 후보로 센다.

```swift
extension BestRecords {
    init(flights: [SwiftDataFlight]) {
        let candidates = flights.filter { $0.isAnalysisEligible && $0.distance.isFinite }
        longestDistance = candidates.map(\.distance).max()
        longestTime = candidates.map(\.time).max()
        bestPace = candidates.map(\.pace).filter { $0.isFinite && $0 > 0 }.min()
    }
}
```

#### filter, map, max, min으로 후보에서 최고 기록 고르기

1. [`filter(\_:)`](https://developer.apple.com/documentation/swift/sequence/filter%28%5F%3A%29-3gbw){:target="_blank"}로 조건에 맞는 기록만 남긴다. 3km 이상이고 거리가 정상 숫자인 것이 후보다.
2. [`map(\_:)`](https://developer.apple.com/documentation/swift/sequence/map%28%5F%3A%29){:target="_blank"}은 원소마다 값 하나를 뽑아 새 배열을 만든다. `\.distance` 는 "각 원소의 `distance`" 를 뜻하는 줄임 표기다.
3. [`max()`](https://developer.apple.com/documentation/swift/sequence/max%28%29){:target="_blank"}와 [`min()`](https://developer.apple.com/documentation/swift/sequence/min%28%29){:target="_blank"}은 배열에서 가장 큰 값과 가장 작은 값을 돌려준다. 빈 배열이면 `nil` 이라 후보가 없는 사람은 세 칸이 모두 `nil` 이 되고 화면에는 `--` 가 나온다.

페이스는 숫자가 작을수록 빠르므로 `max` 가 아니라 `min` 이다. 페이스가 0 이거나 음수이거나 NaN(숫자가 아님)이거나 무한대인 손상된 값은 한 번 더 걸러서 최고 페이스가 되지 못하게 했다.

---

## 이미지 없이 그린 견장

계급마다 견장 PNG 를 만들면 관리할 이미지가 일곱 배로 는다. 그래서 이미지 파일을 하나도 만들지 않고 SwiftUI 도형으로 그렸다. 해상도를 걱정할 일이 없고, 줄 하나가 늘어나는 모습을 애니메이션으로 보여 줄 수 있다.

```swift
var body: some View {
    ZStack {
        RoundedRectangle(cornerRadius: 9)
            .fill(Self.cloth)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Self.clothBorder, lineWidth: 1.5))
            .frame(width: 76, height: 154)
            .position(x: 60, y: 85)

        // 생략 (윙 마크 원 두 개)

        ForEach(0..<rank.stripes, id: \.self) { index in
            let isTop = rank.stars == 0 && index == rank.stripes - 1
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isTop ? topColor : Self.stripe)
                .frame(width: 60, height: 10)
                .modifier(TopElementState(isTop: isTop, landing: landing, radius: 1.5))
                .position(x: 60, y: CGFloat(134 - 18 * index) + 5)
        }

        // 생략 (별)
    }
    .frame(width: 120, height: 170)
    .scaleEffect(height / 170)
    .frame(width: height * 120 / 170, height: height)
}
```

#### position, scaleEffect, frame으로 도형을 찍고 크기 맞추기

1. [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack){:target="_blank"}은 안의 뷰를 앞뒤로 겹쳐 쌓는다. 천, 윙 마크, 줄을 한 장에 겹쳐 그리는 데 썼다.
2. [`position(x:y:)`](https://developer.apple.com/documentation/swiftui/view/position%28x%3Ay%3A%29){:target="_blank"}은 뷰의 **중심**을 부모 안의 좌표에 찍는다. 견장의 기준 좌표는 가로 120, 세로 170 이다. 줄은 `134 - 18 * index` 로 아래에서 위로 18 간격으로 쌓인다.
3. [`frame(width:height:alignment:)`](https://developer.apple.com/documentation/swiftui/view/frame%28width%3Aheight%3Aalignment%3A%29){:target="_blank"}으로 그림판의 크기를 120 x 170 으로 고정한다.
4. [`scaleEffect(\_:anchor:)`](https://developer.apple.com/documentation/swiftui/view/scaleeffect%28%5F%3Aanchor%3A%29){:target="_blank"}은 그려지는 크기만 키우거나 줄인다. **차지하는 자리는 바꾸지 않는다.** 그냥 두면 그림은 작아졌는데 화면 배치는 120 x 170 자리를 그대로 차지한다. 그래서 뒤에 한 번 더 `frame` 을 붙여 원하는 크기(`height` 에 비례한 폭)로 자리를 맞췄다. 이 두 줄이 한 쌍이라서 어떤 크기로 불러도 같은 모양이 나온다.

[`RoundedRectangle`](https://developer.apple.com/documentation/swiftui/roundedrectangle){:target="_blank"}과 [`Circle`](https://developer.apple.com/documentation/swiftui/circle){:target="_blank"}은 모서리가 둥근 사각형과 원이고, `fill` 은 안쪽을, `stroke` 는 테두리를 칠한다. [`ForEach`](https://developer.apple.com/documentation/swiftui/foreach){:target="_blank"}는 `0..<rank.stripes` 처럼 범위를 돌며 줄을 하나씩 그린다. `CGFloat` 는 화면 좌표에 쓰는 실수 타입이다.

맨 위 줄이나 마지막 별만 새로 꽂히는 요소다. 그것만 따로 움직이게 하는 장치가 아래다.

```swift
/// 맨 위 요소(마지막 별 또는 맨 위 줄)의 상태. 움직임은 부르는 쪽의 withAnimation 이 만든다.
enum EpauletteLanding {
    case none, raised, landed, flashing
}

// 생략

private struct TopElementState: ViewModifier {
    let isTop: Bool
    let landing: EpauletteLanding
    let radius: CGFloat

    func body(content: Content) -> some View {
        let raised = isTop && landing == .raised
        content
            .padding(5)
            .overlay {
                if isTop && landing == .flashing {
                    RoundedRectangle(cornerRadius: radius + 5)
                        .stroke(Color(hex: "#FFD77A"), lineWidth: 2)
                }
            }
            .padding(-5)
            .scaleEffect(x: raised ? 1.6 : 1, y: 1)
            .offset(y: raised ? -63 : 0)
            .opacity(raised ? 0 : 1)
    }
}
```

#### ViewModifier로 맨 위 요소에만 상태 입히기

[`ViewModifier`](https://developer.apple.com/documentation/swiftui/viewmodifier){:target="_blank"}는 뷰에 입힐 꾸밈을 묶어 두는 틀이다. `.modifier(TopElementState(...))` 로 줄 하나에 붙이면 `body(content:)` 가 그 줄을 받아 꾸민 뷰를 돌려준다.

상태는 `EpauletteLanding` 네 가지 중 하나다. `none` 은 평소, `raised` 는 줄이 위로 들려 보이지 않는 상태, `landed` 는 꽂힌 상태, `flashing` 은 꽂히는 순간 테두리가 번쩍이는 상태다. 맨 위 요소가 아닌 줄은 `isTop` 이 거짓이라 어느 상태에서도 그대로다. `none` 이 아닌 동안 맨 위 요소는 밝은 금색(`topColor`)이고, `none` 으로 돌아와야 다른 줄과 같은 색이 된다.

- `raised` 일 때: [`scaleEffect(x:y:anchor:)`](https://developer.apple.com/documentation/swiftui/view/scaleeffect%28x%3Ay%3Aanchor%3A%29){:target="_blank"}로 가로를 1.6 배로 늘리고, [`offset(x:y:)`](https://developer.apple.com/documentation/swiftui/view/offset%28x%3Ay%3A%29){:target="_blank"}으로 위로 63 올리고, [`opacity(\_:)`](https://developer.apple.com/documentation/swiftui/view/opacity%28%5F%3A%29){:target="_blank"}로 투명하게 만든다. 들려서 안 보이는 상태다.
- `flashing` 일 때: [`overlay(alignment:content:)`](https://developer.apple.com/documentation/swiftui/view/overlay%28alignment%3Acontent%3A%29){:target="_blank"}로 줄 위에 금색 테두리를 얹는다. 테두리가 줄 모양보다 5 크게 나가야 번쩍임으로 보여서 [`padding(\_:\_:)`](https://developer.apple.com/documentation/swiftui/view/padding%28%5F%3A%5F%3A%29){:target="_blank"}을 5 줬다가 `-5` 로 되돌려 차지하는 자리는 원래대로 둔다.

이 코드에는 애니메이션이 없다. 상태만 바꿀 뿐이고, 움직임은 상태를 바꾸는 쪽에서 `withAnimation` 으로 감싸야 생긴다.

---

## 프로필을 열 때 꽂히는 줄

승급 축하는 **프로필 화면을 열 때만** 한다. 러닝이 끝나는 화면에서 하면 좋을 것 같지만 워치의 러닝 종료 화면에서는 그럴 수 없다. 워치 앱에는 `ModelContainer`(기록을 담은 저장소)가 없어서, 워치는 기록을 폰에 넘기기만 할 뿐 승급을 판단할 수 없다. 폰의 러닝 종료 흐름이나 알림에 끼어드는 것도 피했다. 승급은 평생 여섯 번뿐인데 매번 방해가 되면 안 된다.

한 계급이 오르는 장면은 이렇게 흘러간다.

![한 계급이 오르는 2초 동안의 시간 순서를 그린 그림. 0초에 줄이 들려 있고, 0.35초에 내려오기 시작하고, 1.1초에 꽂히며 진동과 저장이 일어나고, 1.3초에 번쩍이고, 2.0초에 끝난다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-05-RunningProject-58/runway-profile-timeline.png)

이 장면에서 중요한 성질은 하나다. **저장은 줄이 꽂히는 1.1초 순간에 한다.** 줄이 보이기도 전에 저장하면 장면을 못 본 채 축하가 끝난 것으로 기록되고, 장면이 다 끝난 뒤에 저장하면 그 사이에 탭을 떠난 사람은 같은 축하를 또 본다.

```swift
private func startCelebration() {
    guard celebration == nil,
          let plan = PromotionPlan.make(celebrated: celebratedRank, current: currentRank) else { return }
    celebration = Task { @MainActor in
        for step in plan.steps {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                shownRank = step
                landing = .raised
            }
            guard await pause(0.35) else { return }
            withAnimation(.timingCurve(0.3, 1.4, 0.5, 1, duration: 0.75)) { landing = .landed }
            guard await pause(0.75) else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            celebratedRank = step.rawValue
            guard await pause(0.2) else { return }
            landing = .flashing
            // 화면이 .flashing 을 한 번 그린 뒤에 번쩍임을 풀어야 보인다.
            guard await pause(0.03) else { return }
            withAnimation(.easeOut(duration: 0.6)) { landing = .landed }
            guard await pause(0.02) else { return }
            withAnimation(.easeOut(duration: 0.45)) { shownTitleRank = step }
            guard await pause(0.65) else { return }
        }
        shownRank = nil
        shownTitleRank = nil
        withAnimation(.easeOut(duration: 0.3)) { landing = .none }
        celebration = nil
    }
}
```

#### Task와 withAnimation으로 승급 장면 이어 붙이기

1. [`Task`](https://developer.apple.com/documentation/swift/task){:target="_blank"}는 화면과 별개로 "기다리면서 진행하는 작업"을 시작한다. 안에서 `await` 를 쓰면 기다리는 동안 앱이 멈추지 않는다. [`@MainActor`](https://developer.apple.com/documentation/swift/mainactor){:target="_blank"}는 이 작업이 메인 스레드(화면을 그리고 터치를 처리하는, 앱의 대표 일꾼 하나)에서 돌게 하는 표시다. 이 작업은 뷰의 상태를 바꾸고 진동을 울리므로 메인에서 돌게 했다. 만든 `Task` 를 `celebration` 에 담아 두면 나중에 취소할 수 있다.
2. 코드 맨 앞의 `guard celebration == nil, ...` 는 조건이 맞지 않으면 `else` 쪽으로 빠져 함수를 끝내는 문장이다. 이미 장면이 돌고 있거나 축하할 계급이 없으면 시작하지 않는다. `plan.steps` 는 축하할 계급 목록이다. 여러 계급을 한꺼번에 오른 사람은 `for` 로 한 계급씩 2초짜리 장면을 반복한다.
3. [`Transaction`](https://developer.apple.com/documentation/swiftui/transaction){:target="_blank"}은 "이번 화면 변경에 어떤 애니메이션을 적용할까"를 담은 꾸러미다. [`disablesAnimations`](https://developer.apple.com/documentation/swiftui/transaction/disablesanimations){:target="_blank"}를 `true` 로 두고 [`withTransaction(\_:\_:)`](https://developer.apple.com/documentation/swiftui/withtransaction%28%5F%3A%5F%3A%29){:target="_blank"}에 넘기면 그 안의 변경은 애니메이션 없이 즉시 바뀐다. 줄을 위로 들어 올리는 것은 준비 동작이라 눈에 보이면 안 된다. 지금 이 화면에는 `.animation` 수식어가 없어서 그냥 대입해도 애니메이션은 생기지 않는다. 그래도 이 변경은 언제나 즉시 바뀌어야 해서, 나중에 `.animation` 이 붙어도 끼어들지 못하게 명시해 두었다.
4. [`withAnimation(\_:\_:)`](https://developer.apple.com/documentation/swiftui/withanimation%28%5F%3A%5F%3A%29){:target="_blank"}은 중괄호 안의 상태 변경을 애니메이션으로 만든다. 줄이 내려오는 데 쓴 [`timingCurve(\_:\_:\_:\_:duration:)`](https://developer.apple.com/documentation/swiftui/animation/timingcurve%28%5F%3A%5F%3A%5F%3A%5F%3Aduration%3A%29){:target="_blank"}는 속도 변화를 곡선(앞의 네 숫자)으로 직접 정한다. 두 번째 숫자가 1 보다 큰 1.4 라서 목표를 살짝 지나쳤다가 돌아오며, 꽂히는 느낌을 내려는 값이다. 나머지는 빠르게 시작해 천천히 멈추는 [`easeOut(duration:)`](https://developer.apple.com/documentation/swiftui/animation/easeout%28duration%3A%29){:target="_blank"}이다.
5. [`UIImpactFeedbackGenerator`](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator){:target="_blank"}는 아이폰에 진동 한 번을 준다. `style: .heavy` 가 묵직한 진동이고 [`impactOccurred()`](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/impactoccurred%28%29){:target="_blank"}가 실제로 울린다. 바로 다음 줄에서 `celebratedRank` 를 저장한다. 진동과 저장이 같은 순간이다.

`shownRank` 는 장면 동안 견장에 대신 보여 줄 계급이고 `shownTitleRank` 는 계급 이름에 대신 보여 줄 계급이다. 둘 다 `nil` 이면 실제 계급이 보인다.

`pause` 는 장면 사이를 기다리는 도우미 함수다. 아래 "취소됐는데 true 를 돌려주던 pause" 에서 자세히 본다. 위 코드의 시간표는 그림 그대로다. 0.35 에 내려오기 시작해 1.1(0.35 + 0.75)에 꽂히고, 1.3(1.1 + 0.2)에 번쩍인다. 1.33 부터 번쩍임이 0.6초 동안 사라지기 시작하고, 1.35 에 계급 이름이 바뀌며, 2.0 에 끝난다.

---

### 같은 순간의 상태 변경이 한 번만 그려지는 이유

번쩍임을 만드는 부분이 이상하게 보일 수 있다. `landing = .flashing` 다음에 0.03초를 쉬고 나서야 `landed` 로 되돌린다. 바로 되돌리면 번쩍임이 화면에 나오지 않는다.

SwiftUI 는 상태가 바뀔 때마다 그리지 않고, 한 번의 처리 안에서 일어난 변경을 모아 마지막 결과만 한 번 그린다. `flashing` 으로 바꾸고 곧바로 `landed` 로 되돌리면 "`flashing` 이 있었다"는 사실이 그려지기 전에 사라진다. 카메라가 셔터를 누르기 전에 장면이 바뀐 것과 같다. 찍힌 적이 없으니 없던 일이 된다.

그래서 0.03초를 양보한다. 보통 화면 한 번 그리는 시간(60Hz 기준 약 0.017초)보다 길어서 그 사이에 `flashing` 이 그려지기를 기대한 값이다. 메인 스레드가 바쁘면 보장되지는 않는다. 반대로 줄을 들어 올리는 변경은 `withTransaction` 으로 애니메이션이 붙지 않게 못 박아 둔다. 이번에는 거꾸로, 화면에 나오지 말아야 할 변화이기 때문이다. 들어 올리는 건 내려오는 장면을 위한 준비라서, 부드럽게 바뀌는 중간 모습이 보이면 안 되고 "들려 있는 상태"로 즉시 바뀌어 있어야 한다.

---

## 취소됐는데 true 를 돌려주던 pause

위의 `pause` 는 처음에 이렇게 썼다.

```swift
private func pause(_ seconds: Double) async -> Bool {
    (try? await Task.sleep(for: .seconds(seconds))) != nil
}
```

의도는 단순하다. 정해진 초만큼 쉬고, 쉬는 도중 작업이 취소되면 `false` 를 돌려줘서 호출한 쪽이 `guard ... else { return }` 으로 끝내게 한다. 프로필 탭을 떠나면 `onDisappear` 가 작업을 취소하므로, 떠난 뒤에는 화면 상태를 건드리지 말아야 한다.

문제는 이 코드가 **취소됐는데도 `true` 를 돌려주는 경우가 있다**는 점이다.

#### Task.sleep으로 기다리고 try?로 결과 보기

[`Task.sleep(for:)`](https://developer.apple.com/documentation/swift/task/sleep%28for%3Atolerance%3Aclock%3A%29){:target="_blank"}은 지정한 시간만큼 작업을 재운다. 재우는 동안 메인 스레드는 쉬지 않고 다른 일을 한다. 인자에 [`.seconds(\_:)`](https://developer.apple.com/documentation/swift/duration){:target="_blank"} 같은 시간 값을 넣는다. 재우는 도중 작업이 취소되면 에러를 던진다(`throw`). 에러가 났다는 뜻이다. `try?` 는 그 에러를 `nil` 로 바꿔 준다. 그래서 `(try? await ...) != nil` 은 "에러 없이 끝까지 잤다"는 뜻의 `true` 가 된다.

여기서 빠진 가정이 있다. 에러가 나는 경우는 **타이머가 끝나기 전에 취소됐을 때**뿐이다. 타이머가 먼저 끝났는데 메인 스레드가 다른 일로 바빠서 깨어나기까지 기다리는 사이에 취소가 도착하면 `sleep` 은 이미 성공한 상태다.

---

### Task 취소란?

취소는 **작업을 강제로 끝내는 게 아니다.** 작업에 "취소됨" 표시를 하나 붙일 뿐이다. 표시가 붙은 뒤에도 작업은 계속 돌고, 작업이 스스로 표시를 확인하고 멈춰야 한다. 학교에서 선생님이 "그만"이라고 써서 칠판에 붙여 놓는 것과 같다. 학생이 칠판을 보지 않으면 계속 푼다.

`Task.sleep` 은 칠판을 알아서 보는 함수다. 재우는 도중에 표시가 붙으면 바로 깨어나 에러를 던진다. 하지만 타이머가 이미 끝난 뒤에 표시가 붙으면 `sleep` 은 그 표시를 볼 기회가 없다. 그럴 때는 코드가 직접 [`Task.isCancelled`](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property){:target="_blank"}를 확인해야 한다. 이 값은 지금 돌고 있는 작업에 취소 표시가 붙었는지 알려 준다. 표시를 붙이는 쪽은 [`cancel()`](https://developer.apple.com/documentation/swift/task/cancel%28%29){:target="_blank"}이다.

![작업이 멈추는 두 순서를 위아래로 나란히 그린 그림. 위쪽은 취소 표시가 먼저 붙어 sleep 이 에러를 던지고 pause 가 false 를 돌려줘 작업이 멈춘다. 아래쪽은 타이머가 먼저 끝나고 그다음 취소 표시가 붙어 sleep 은 성공으로 돌아오고, 확인이 없으면 true 를 돌려줘 다음 줄이 실행된다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-05-RunningProject-58/runway-profile-cancel.png)

이 순서를 작은 코드로 재현해 봤다. 처음 `pause` 와 같은 모양이다. 파일 하나(`main.swift`)로 저장해 `swiftc main.swift -o check` 로 실행 파일을 만들어 돌렸다.

```swift
import Foundation
@MainActor func pause(_ s: Double) async -> Bool { (try? await Task.sleep(for: .seconds(s))) != nil }
@MainActor func run() async {
    let t = Task { @MainActor in
        let r = await pause(0.01)
        print("first pause returned", r, "isCancelled", Task.isCancelled)
        let r2 = await pause(0.01)
        print("second pause returned", r2)
    }
    await Task.yield()
    Thread.sleep(forTimeInterval: 0.05) // main busy, timer fires meanwhile
    t.cancel()
    await t.value
}
await run()
```

#### Task.yield와 Thread.sleep으로 메인이 바쁜 상황 만들기

1. `Task { ... }` 로 `pause(0.01)` 을 부르는 작업을 시작한다. 0.01초만 자는 짧은 타이머다.
2. [`Task.yield()`](https://developer.apple.com/documentation/swift/task/yield%28%29){:target="_blank"}는 지금 실행 순서를 양보한다. 방금 만든 작업이 시작해서 `sleep` 에 들어가도록 한 번 기회를 준다.
3. [`Thread.sleep(forTimeInterval:)`](https://developer.apple.com/documentation/foundation/thread/sleep%28fortimeinterval%3A%29){:target="_blank"}은 메인 스레드를 0.05초 동안 통째로 막는다. 그 사이 0.01초 타이머는 끝나지만 작업은 메인이 풀릴 때까지 깨어나지 못한다. "메인이 바쁜 순간"을 일부러 만든 것이다. 앱에서는 탭을 전환하며 화면을 그리는 때가 그럴 수 있다.
4. 막힌 사이 타이머가 끝난 뒤에 `t.cancel()` 로 취소 표시를 붙인다.
5. [`await t.value`](https://developer.apple.com/documentation/swift/task/value-60t02){:target="_blank"}로 작업이 끝날 때까지 기다린다.

실제 실행 결과다.

```
first pause returned true isCancelled true
second pause returned false
```

첫 번째 `pause` 는 이미 취소 표시가 붙은 뒤인데도 `true` 를 돌려줬다. `isCancelled` 가 `true` 인데 `pause` 가 `true`(취소 안 됨)라고 한 것이다. 두 번째 `pause` 는 작업에 취소 표시가 붙은 채로 `sleep` 을 시작하니 바로 에러가 나 `false` 가 됐다. 같은 코드가 타이밍에 따라 반대로 답한다.

앱에서는 이렇게 이어진다. 프로필 탭을 떠나는 순간 취소가 도착했는데 `pause` 가 `true` 를 돌려주면 작업은 다음 줄로 넘어가 상태를 한 번 더 쓴다. 그 한 줄이 `landing = .flashing` 이거나 `.landed` 라면, 이미 `onDisappear` 가 `.none` 으로 정리한 뒤에 다시 써 버리는 것이다. 맨 위 줄의 색이 돌아오지 않을 수 있다.

같은 일이 `pause(0.75)` 에서 생기면 탭을 떠난 뒤에도 진동이 울리고 `celebratedRank` 가 저장되어, 보지 못한 축하가 끝난 것으로 기록된다.

고친 코드는 이렇다.

```swift
/// 취소되면 false. 취소된 뒤에는 상태를 건드리지 않는다.
private func pause(_ seconds: Double) async -> Bool {
    guard (try? await Task.sleep(for: .seconds(seconds))) != nil else { return false }
    return !Task.isCancelled
}
```

`sleep` 이 에러를 던졌으면 `false`. 에러 없이 끝났어도 그 순간 취소 표시가 붙어 있으면 `false`. 둘 다 아닐 때만 `true` 다. 칠판을 알아서 보는 함수에만 맡기지 않고 우리도 직접 한 번 더 본 것이다.

---

## 내려갔다 돌아온 계급은 축하하지 않기

"마지막으로 본 계급"을 저장해 두고 지금 계급과 다르면 축하하는 방식은 처음에 떠올렸다가 버렸다. 기록을 지워서 계급이 내려갔다가 백업으로 복원하면 같은 계급이 돌아온다. 이때 "계급이 달라졌다"고 축하하면 이미 한 축하를 또 하게 된다.

그래서 저장하는 값은 **지금까지 축하한 가장 높은 계급**이다. 지금 계급이 그보다 높을 때만 축하하고 값을 올린다.

```swift
/// 프로필을 열 때 축하할 승급 순서. 저장값은 지금까지 축하한 가장 높은 계급의 rawValue(없으면 0).
struct PromotionPlan: Equatable {
    let start: PilotRank
    let steps: [PilotRank]

    static func make(celebrated: Int, current: PilotRank) -> PromotionPlan? {
        let steps = PilotRank.allCases.filter { $0.rawValue > celebrated && $0 <= current }
        guard let first = steps.first, let start = PilotRank(rawValue: first.rawValue - 1) else { return nil }
        return PromotionPlan(start: start, steps: steps)
    }
}
```

#### Equatable과 first로 축하할 계급 고르기

`PilotRank.allCases` 에서 "저장값보다 높고 지금 계급 이하인 것"만 남긴다. 남은 것이 축하할 계급들이고, 첫 계급 바로 아래가 장면의 출발점(`start`)이다. 남은 게 없으면 `nil` 이라 축하하지 않는다. 여기서 쓴 [`first`](https://developer.apple.com/documentation/swift/collection/first){:target="_blank"}는 배열의 첫 원소를 돌려주고, 비어 있으면 `nil` 이다. 코드의 `guard let first = steps.first` 는 첫 원소가 있을 때만 다음으로 넘어가고, 없으면 `nil` 을 돌려주고 끝낸다. 그 밖에 앞에서 본 `filter` 와 `allCases` 를 다시 썼다.

[`Equatable`](https://developer.apple.com/documentation/swift/equatable){:target="_blank"}을 따르면 `==` 로 두 값을 비교할 수 있어서, 테스트에서 `PromotionPlan` 을 통째로 비교한다.

테스트에는 이 성질이 그대로 들어 있다.

```swift
@Test func 축하는_저장값_다음부터_지금_계급까지_차례로다() {
    #expect(PromotionPlan.make(celebrated: 0, current: .secondOfficer) == PromotionPlan(start: .studentPilot, steps: [.cadet, .secondOfficer]))
    #expect(PromotionPlan.make(celebrated: 2, current: .firstOfficer) == PromotionPlan(start: .secondOfficer, steps: [.firstOfficer]))
    #expect(PromotionPlan.make(celebrated: 1, current: .checkAirman)?.steps == [.secondOfficer, .firstOfficer, .captain, .seniorCaptain, .checkAirman])
}
@Test func 강등과_복원과_빈_기록에서는_축하하지_않는다() {
    #expect(PromotionPlan.make(celebrated: 3, current: .cadet) == nil)
    #expect(PromotionPlan.make(celebrated: 3, current: .firstOfficer) == nil)
    #expect(PromotionPlan.make(celebrated: 0, current: .studentPilot) == nil)
}
```

저장값이 3(FIRST OFFICER)인 사람이 기록을 지워 CADET 이 되어도, 복원해서 FIRST OFFICER 로 돌아와도 `nil` 이다. 견장만 조용히 돌아온다.

![시간에 따라 실제 계급과 축하한 가장 높은 계급이 어떻게 움직이는지 그린 그림. 예시 값이다. 실제 계급이 FIRST OFFICER 까지 올랐다가 기록 삭제로 CADET 까지 내려오고 복원돼 FIRST OFFICER 로 돌아와도 축하한 가장 높은 계급은 FIRST OFFICER 로 그대로이고, 복원 뒤에는 그보다 높은 CAPTAIN 에 닿을 때 비로소 축하가 돈다.](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-05-RunningProject-58/runway-profile-celebrated.png)

저장을 한 계급씩 하는 것도 같은 이유다. 한 번에 두 계급을 올라야 하는 사람이 첫 줄이 꽂힌 뒤 탭을 떠나면 첫 계급은 저장됐고 남은 줄만 이어서 돈다. 1.1초 전에 떠나면 아직 저장 전이라 그 줄이 다시 돈다.

---

### 업데이트 뒤 처음 열 때

이미 기록이 많은 사람이 업데이트하고 처음 프로필을 열면 저장값이 없다(기본 0). 이때는 줄 없는 견장에서 시작해 이미 가진 계급을 낮은 순서대로 축하한다. 2줄이면 줄이 두 번 꽂힌다. 따로 만든 장면은 없고 같은 움직임을 반복한다.

그 전에 **이름을 먼저 묻는다.** 축하가 이름이 박힌 면허증 위에서 일어나야 하기 때문이다.

![이름을 묻는 알림이 떠 있는 동안 면허증은 PILOT 과 STUDENT PILOT 인 시작 계급 그대로 멈춰 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-05-RunningProject-58/runway-profile-name-ask.png)

```swift
.alert("이름을 적어 주세요", isPresented: $showsNameAlert) {
    TextField("이름", text: $nameDraft)
    Button("취소", role: .cancel) { finishNameAsk() }
    Button("확인") {
        pilotName = PilotName.normalized(nameDraft)
        finishNameAsk()
    }
} message: {
    Text("면허증에 들어갈 이름이에요.")
}
.onAppear {
    if let plan = PromotionPlan.make(celebrated: celebratedRank, current: currentRank) {
        shownRank = plan.start
        shownTitleRank = plan.start
    }
    if hasAskedPilotName {
        startCelebration()
    } else {
        showsNameAlert = true
    }
}
.onDisappear {
    celebration?.cancel()
    celebration = nil
    shownRank = nil
    shownTitleRank = nil
    landing = .none
}

// 생략
private func finishNameAsk() {
    let isFirstAsk = !hasAskedPilotName
    hasAskedPilotName = true
    if isFirstAsk { startCelebration() }
}
```

#### alert, AppStorage, onAppear로 이름 묻고 축하 시작하기

1. [`alert(\_:isPresented:actions:message:)`](https://developer.apple.com/documentation/swiftui/view/alert%28%5F%3Aispresented%3Aactions%3Amessage%3A%29){:target="_blank"}는 `isPresented` 가 `true` 가 되면 알림을 띄운다. 중괄호 안의 [`TextField`](https://developer.apple.com/documentation/swiftui/textfield){:target="_blank"}가 이름 입력칸이 되고, [`Button`](https://developer.apple.com/documentation/swiftui/button){:target="_blank"}은 누르면 중괄호 안 코드를 실행하는 버튼이다. `role: .cancel` 은 [`ButtonRole`](https://developer.apple.com/documentation/swiftui/buttonrole){:target="_blank"}로 취소 버튼 자리와 모양을 정한다. 확인과 취소 모두 `finishNameAsk()` 를 부르므로 **이름은 딱 한 번만 묻는다.** 취소하면 다음에는 묻지 않고, 이후에는 면허증의 연필 버튼으로만 고친다. 매번 묻는 건 방해가 되기 때문이다.
2. [`@AppStorage`](https://developer.apple.com/documentation/swiftui/appstorage){:target="_blank"}는 값을 기기의 `UserDefaults`(작게 저장하는 칸)에 저장하고 읽는 속성이다. `pilotName`, `hasAskedPilotName`, `celebratedRank` 세 값이 여기에 담기고 앱을 껐다 켜도 남는다. 값을 바꾸면 화면도 같이 새로 그려진다.
3. [`onAppear(perform:)`](https://developer.apple.com/documentation/swiftui/view/onappear%28perform%3A%29){:target="_blank"}는 화면이 나타날 때, [`onDisappear(perform:)`](https://developer.apple.com/documentation/swiftui/view/ondisappear%28perform%3A%29){:target="_blank"}는 사라질 때 실행된다. 처음 열면 `plan.start` 를 먼저 `shownRank` 에 넣어 줄이 비어 있는 견장을 보여 두고, 이름을 이미 물었으면 바로 축하하고 아니면 알림을 띄운다. 알림이 닫히면 `finishNameAsk` 가 첫 물음이었을 때만 축하를 시작한다. 떠날 때는 진행 중인 작업을 취소하고 화면 상태를 돌려놓는다. 앞에서 본 `pause` 문제가 생기는 자리가 여기다.

---

## 테스트로 지킨 것과 아직 확인하지 못한 것

테스트는 Swift Testing 으로 **순수 계산**만 붙였다. 화면은 대상이 아니다. 입력이 같으면 결과가 같은 계산이라 화면을 직접 띄워 보지 않아도 결과를 확인할 수 있다.

- `PilotRankTests`: 10개. 계급 경계, 부동소수 오차, 표시 올림과 내림, 진행 비율, 손상된 거리, 축하 순서
- `PilotLicenseTests`: 10개. 기수와 면허번호, 시간대에 따른 분기 경계, 이름 다듬기, 최고 기록의 3km 기준과 손상된 값

테스트 모양은 [앞 글](https://haroldfromk.github.io/posts/RunningProject-(57)/)에서 다룬 것과 같다. 위의 `PromotionPlan` 테스트가 그 예다.

아직 확인하지 못한 것도 있다. 이 글을 쓰는 시점에 실기기에서 보지 못했다.

- 줄이 내려오는 애니메이션의 느낌
- 진동이 울리는 타이밍
- 영어와 일본어에서 프로필 화면의 줄바꿈
- 번쩍임이 실제로 보이는지

위에서 적은 시간과 곡선 값은 코드에 있는 값이고, 그것이 실제로 어떻게 느껴지는지는 보지 못했다.

---

## 참고자료

- [Concurrency (The Swift Programming Language)](https://docs.swift.org/latest/documentation/the-swift-programming-language/concurrency/){:target="_blank"}
