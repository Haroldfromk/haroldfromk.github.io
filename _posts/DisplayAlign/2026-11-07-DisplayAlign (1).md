---
title: DisplayAlign (1) 모니터를 정확한 가운데에 맞추는 메뉴 막대 앱
writer: Harold
date: 2026-11-07 00:30:00 +0900
categories: [DisplayAlign]
tags: [CoreGraphics, MenuBarExtra, SwiftUI]

toc: true
toc_sticky: true
published: true
---

> 이 시리즈는 내가 직접 쓴 개발기가 아니다. 무엇을 만들지 정해 Claude Code 에게 앱을 만들게 했고, 만든 과정과 쓰인 기술은 Claude Code 가 정리했다. 나는 방향을 정하고, 실기기에서 써 보며 고칠 곳을 찾아 다시 맡겼다. 그래도 글로 남기는 건 공부 때문이다. 아직 내가 아는 프레임워크가 몇 개 없어서, 이 앱에 쓰인 여러 프레임워크를 정리해 두고 나중에 하나씩 찾아보며 익히려고 한다.
{: .prompt-info }

맥북 위에 모니터를 올려 두고 쓴다. macOS 설정의 화면 배치는 마우스로 끌어서 맞추는 방식이라 정확한 가운데를 맞출 수 없다. 게다가 어떤 날은 맥북에 모니터 하나, 어떤 날은 둘을 연결해서 상황마다 조합이 달라지니, 배치를 저장해 둘 방법도 필요했다.

그래서 모니터를 끌어 놓으면 이웃에 붙고 가운데로 달라붙는 편집 창과, 눌러서 적용하는 프리셋(저장해 둔 배치)을 가진 메뉴 막대 앱 DisplayAlign을 만들었다. 이번 글은 이 앱의 핵심인 위치 계산과 macOS에 적용하는 부분, 그리고 만들면서 코드 리뷰에서 걸린 문제들을 정리한다.

---

## 마우스로는 못 맞추는 14 pt

먼저 지금 내 화면 배치가 얼마나 어긋나 있는지 재 봤다. macOS가 알려 주는 각 모니터의 위치와 크기를 읽어 본 값이다.

| 모니터 | 시점 | 왼쪽 위 (x, y) | 크기 | 중심 x | 어긋남 |
|---|---|---|---|---|---|
| 맥북 내장 | 기준 | (0, 0) | 1512 × 982 | 756 | 기준 |
| 외장 모니터 | 앱 쓰기 전 | (-218, -1080) | 1920 × 1080 | 742 | 14 pt |
| 외장 모니터 | 가운데 맞춤 후 | (-204, -1080) | 1920 × 1080 | 756 | 0 |
| 외장 모니터 | 왼쪽 맞춤 후 | x 0 (y는 재지 않음) | 1920 × 1080 | 960 | 204 pt |

외장 모니터의 중심은 맥북 중심(756)보다 14 pt 왼쪽인 742에 있었다. 마우스로 끌어 놓다 보니 생긴 어긋남으로 보인다. 14 pt는 모니터 폭의 1퍼센트도 안 돼서 눈으로는 가운데처럼 보인다.

![두 모니터의 중심선 사이는 14 pt이고, 모니터 폭에 비하면 실제 비율로는 거의 붙어 보일 만큼 작다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-07-DisplayAlign-1/displayalign-offset-2.png)

가운데를 맞추려면 맥북 폭과 모니터 폭의 차이를 반으로 나눠 (1512 - 1920) / 2 = -204 에 놓으면 된다. 앱이 맞춘 값이 바로 x -204였다.

---

### 전역 좌표계와 논리 픽셀이란?

전역 좌표계는 연결된 모니터 전체를 올려놓는 큰 도화지다. 왼쪽 위가 기준이고, 오른쪽으로 갈수록 x가 커지고 아래로 갈수록 y가 커진다. 이 도화지의 (0, 0)은 주 모니터의 왼쪽 위다. 그래서 맥북 위에 놓인 모니터는 y가 음수이고, 위의 외장 모니터가 -1080이었다.

논리 픽셀은 macOS가 화면 크기를 세는 단위다. 실제 화면의 점 여러 개를 1로 묶어 세기도 해서, 모니터의 진짜 점 개수와는 다를 수 있다. 이 글에서 pt라고 쓰는 것이 이 단위다.

![주 모니터 왼쪽 위가 (0, 0)이고 그 위쪽은 y가 음수라서, 맥북 위의 외장 모니터는 y -1080에서 시작한다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-07-DisplayAlign-1/displayalign-coordinate-2.png)

---

### 모니터 목록과 위치 읽기

위치는 `CGDisplayBounds`로 읽는다. 연결된 모니터 목록을 얻고, 모니터마다 위치와 이름을 모아 `Monitor` 값으로 만든다.

```swift
/// 거울 모드로 따라가는 모니터는 뺀 연결 목록.
private static func activeDisplays() -> [(id: CGDirectDisplayID, uuid: String)] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    return ids.prefix(Int(count)).compactMap { id in
        guard CGDisplayMirrorsDisplay(id) == 0,
              let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let uuid = CFUUIDCreateString(nil, cfUUID) as String? else { return nil }
        return (id, uuid)
    }
}

@MainActor
public static func readMonitors() -> [Monitor] {
    var names: [CGDirectDisplayID: String] = [:]
    for screen in NSScreen.screens {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            names[number.uint32Value] = screen.localizedName
        }
    }
    return activeDisplays().map { d in
        let b = CGDisplayBounds(d.id)
        return Monitor(id: d.uuid, name: names[d.id] ?? "모니터",
                       x: Int(b.origin.x), y: Int(b.origin.y),
                       width: Int(b.width), height: Int(b.height),
                       isMain: CGDisplayIsMain(d.id) != 0)
    }
}
```

#### CGDisplayBounds로 모니터 위치 읽기

1. [`CGGetActiveDisplayList`](https://developer.apple.com/documentation/coregraphics/cggetactivedisplaylist%28%5F:%5F:%5F:%29){:target="_blank"}는 지금 켜져 있는 모니터의 번호(`CGDirectDisplayID`) 목록을 준다. 몇 개인지 모르니 두 번 부른다. 처음에는 최대 개수를 0, 목록 자리를 nil로 넘겨 `count`에 개수만 받는다. 그 개수만큼 배열을 만든 뒤 다시 불러 번호를 채운다. [`prefix(_:)`](https://developer.apple.com/documentation/swift/array/prefix%28%5F:%29){:target="_blank"}로 실제 개수만큼만 잘라 쓴다.
2. [`CGDisplayMirrorsDisplay`](https://developer.apple.com/documentation/coregraphics/cgdisplaymirrorsdisplay%28%5F:%29){:target="_blank"}는 이 모니터가 다른 모니터 화면을 그대로 비추는 거울 모드이면 그 대상의 번호를, 아니면 0을 돌려준다. 0인 것만 남겨서 거울로 따라가는 모니터는 배치 대상에서 뺐다. `guard`는 조건이 맞지 않으면 바로 빠져나가는 문법이다. 여기서는 `nil`을 돌려서, [`compactMap(_:)`](https://developer.apple.com/documentation/swift/sequence/compactmap%28%5F:%29){:target="_blank"}이 그 모니터를 결과에서 빼게 한다.
3. [`CGDisplayCreateUUIDFromDisplayID`](https://developer.apple.com/documentation/colorsync/cgdisplaycreateuuidfromdisplayid%28%5F:%29){:target="_blank"}는 모니터 번호로 UUID를 만든다. [`CGDirectDisplayID`](https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid){:target="_blank"} 문서에 따르면 모니터 번호는 보통 재시작 전까지만 그대로라서, 프리셋에 저장할 이름표로는 UUID를 썼다. Core Foundation(Apple의 C 기반 기본 라이브러리)에는 이름에 `Create`가 들어간 함수가 돌려준 값은 받은 쪽이 메모리를 책임진다는 [Create Rule](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html){:target="_blank"}이 있다. 이 함수는 Swift에서 메모리 관리 정보 없이 [`Unmanaged`](https://developer.apple.com/documentation/swift/unmanaged){:target="_blank"}로 포장되어 오기 때문에([Core Foundation 타입 문서](https://developer.apple.com/documentation/swift/working-with-core-foundation-types){:target="_blank"}), [`takeRetainedValue()`](https://developer.apple.com/documentation/swift/unmanaged/takeretainedvalue%28%29){:target="_blank"}로 꺼내 관리를 Swift에게 넘긴다. [`CFUUIDCreateString`](https://developer.apple.com/documentation/corefoundation/cfuuidcreatestring%28%5F:%5F:%29){:target="_blank"}은 이름에 `Create`가 있어도 `CFString`을 바로 돌려주므로 꺼내는 단계가 없다. 이 문자열을 `Monitor.id`에 넣었다.
4. [`CGDisplayBounds`](https://developer.apple.com/documentation/coregraphics/cgdisplaybounds%28%5F:%29){:target="_blank"}는 전역 좌표계에서 그 모니터가 차지한 사각형(왼쪽 위 `origin`과 `width`, `height`)을 돌려준다. 정수로 바꿔 저장했다.
5. [`CGDisplayIsMain`](https://developer.apple.com/documentation/coregraphics/cgdisplayismain%28%5F:%29){:target="_blank"}은 주 모니터이면 0이 아닌 값을 준다.
6. 이름은 AppKit 쪽에 있다. [`NSScreen.screens`](https://developer.apple.com/documentation/appkit/nsscreen/screens){:target="_blank"}를 돌며 [`deviceDescription`](https://developer.apple.com/documentation/appkit/nsscreen/devicedescription){:target="_blank"}의 `NSScreenNumber`(CoreGraphics의 모니터 번호와 같은 값)를 열쇠로 삼아 [`localizedName`](https://developer.apple.com/documentation/appkit/nsscreen/localizedname){:target="_blank"}을 모은다. [`NSDeviceDescriptionKey`](https://developer.apple.com/documentation/appkit/nsdevicedescriptionkey){:target="_blank"}는 이 사전의 열쇠 타입이고, `uint32Value`로 꺼내면 모니터 번호와 같은 숫자 타입이 된다. [`@MainActor`](https://developer.apple.com/documentation/swift/mainactor){:target="_blank"}는 이 함수가 화면 작업을 맡는 메인 스레드(앱의 화면을 그리고 입력을 받는 작업 줄)에서만 돌게 하는 표시다. AppKit 화면 정보를 다른 화면 작업과 같은 줄에서 읽으려고 붙였다.

---

## BetterDisplay 명령 대신 공식 함수

처음에는 이미 쓰던 BetterDisplay(모니터 설정을 바꿔 주는 맥 앱)의 명령으로 모니터 위치를 바꿔 보려 했다. `BetterDisplay set -tagID=<id> -targetTagID=<id> -moveTo=top`은 `Failed.`만 출력했다. 도움말에 Pro 기능으로 표시돼 있었는데, 라이선스 때문인지 사용법이 틀린 건지는 확인하지 못했다.

`BetterDisplay set -tagID=<id> -placement=<X>x<Y>`는 성공했다. 그런데 이 명령은 좌표를 내가 직접 계산해서 넣어야 한다. 게다가 업데이트하면 다시 구매해야 해서 3.5.6 버전에 머물러 있는 앱에 이 기능을 묶어 두게 된다. 그래서 macOS가 공식으로 제공하는 CoreGraphics(macOS의 화면과 그래픽을 다루는 Apple 프레임워크) 함수로 직접 구현했다.

---

## 계산과 화면을 나눈 구성

코드는 세 덩어리로 나눴다.

```text
DisplayAlign/
  Packages/LayoutCore/
    Sources/LayoutCore/        Foundation만 씀. 위치 계산과 프리셋 저장
    Sources/DisplaySystem/     CoreGraphics와 AppKit. 모니터 읽기와 적용
  App/                         SwiftUI. 메뉴 막대, 편집 창, 캔버스
```

Foundation은 문자열과 파일 같은 기본 도구, AppKit은 macOS 전통 화면 도구, SwiftUI는 화면을 선언해서 그리는 도구다.

계산을 `LayoutCore`로 분리한 이유는 실제 모니터 없이 시험하려는 것이다. 모니터를 몇 개씩 연결하지 않아도 숫자만 넣어서 시험 실행 명령 `swift test`의 25개 시험으로 계산을 확인할 수 있다. 계산 쪽은 모니터를 이 구조체 하나로 표현한다.

```swift
public struct Monitor: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var x, y, width, height: Int
    public var isMain: Bool

    // 생략 (init)
}
```

#### Codable로 모니터 저장 가능하게 만들기

| 프로토콜 | 하는 일 |
|---|---|
| [`Identifiable`](https://developer.apple.com/documentation/swift/identifiable){:target="_blank"} | `id`로 하나씩 구별한다. SwiftUI의 `ForEach`가 이걸 보고 모니터마다 그림을 그린다 |
| [`Codable`](https://developer.apple.com/documentation/swift/codable){:target="_blank"} | JSON 같은 파일 형식으로 바꾸고 다시 읽을 수 있다. 프리셋 저장에 썼다 |
| [`Equatable`](https://developer.apple.com/documentation/swift/equatable){:target="_blank"} | 두 값이 같은지 `==`로 비교한다 |
| [`Sendable`](https://developer.apple.com/documentation/swift/sendable){:target="_blank"} | 여러 곳에서 동시에 넘겨 써도 안전한 값이라고 표시한다 |

`id`에는 앞에서 만든 UUID 문자열이 들어간다. 프리셋은 `Preset`이라는 구조체에 이름과 모니터 배열을 담아 같은 방식으로 저장한다.

---

## 반 픽셀을 잃지 않는 어긋남 계산

이웃은 변이 맞닿은 모니터다. `neighbor(of:in:)`가 위아래 이웃을 먼저 찾고, 없으면 좌우 이웃을 찾는다. 결과인 `Neighbor`에는 그 모니터(`monitor`)와 어느 방향 중심을 비교할지(`axis`)가 들어 있다. 위아래 이웃이면 `.x`, 좌우 이웃이면 `.y`다.

가운데를 맞추는 계산에는 함정이 하나 있었다. 이웃 모니터와 내 폭의 홀짝이 다르면 정수 좌표로는 어긋남을 0으로 만들 수 없다.

작은 칸으로 줄여서 보면 이렇다. 이웃 폭이 6칸이고 모니터 폭이 5칸이면, 모니터를 어느 칸에 놓아도 두 중심선이 일치하지 않고, 가장 가까운 자리에서도 반 칸이 남는다. 이 값은 설명을 위한 예시다.

![이웃 폭 6칸, 모니터 폭 5칸 예시에서 가장 가깝게 놓아도 두 중심선 차이가 0.5칸 남는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-07-DisplayAlign-1/displayalign-half-pixel.png)

그래서 중심의 차이를 반으로 나누지 않고 2배 값 그대로 비교했다. 반으로 나누면 소수점이 생기는데 좌표는 정수만 쓰기 때문이다.

```swift
/// 이웃과의 중심 차이의 2배 값. 반 픽셀을 잃지 않으려고 2배로 계산한다.
public static func offsetTwice(of d: Monitor, from n: Neighbor) -> Int {
    let o = n.monitor
    switch n.axis {
    case .x: return (2 * d.x + d.width) - (2 * o.x + o.width)
    case .y: return (2 * d.y + d.height) - (2 * o.y + o.height)
    }
}

/// 표시용 어긋남(2배 값의 절반)
public static func offset(of d: Monitor, from n: Neighbor) -> Double {
    Double(offsetTwice(of: d, from: n)) / 2
}

/// 폭의 홀짝이 달라 0을 만들 수 없는 경우까지 "정확히 가운데"로 친다.
public static func isCentered(_ d: Monitor, with n: Neighbor) -> Bool {
    abs(offsetTwice(of: d, from: n)) <= 1
}
```

`2 * d.x + d.width`는 모니터 중심 x의 2배다. 맨 처음 실측값을 넣어 보면 (2 × (-218) + 1920) - (2 × 0 + 1512) = -28이고, 절반이면 -14다. 표의 어긋남 14 pt와 같다.

폭의 홀짝이 다르면 2배 값은 홀수가 되어 0이 될 수 없고 가장 작아도 1이다. 예를 들어 맥북 폭이 1512이고 모니터 폭이 1921이라면(예시 값) x = -205에서 2배 어긋남은 -1, x = -204에서는 +1이다. 어느 쪽도 0이 아니다. 그래서 절댓값이 1 이하이면 정확히 가운데로 본다.

#### abs로 절댓값 비교하기

[`abs`](https://developer.apple.com/documentation/swift/abs%28%5F:%29){:target="_blank"}는 숫자의 부호를 떼고 크기만 돌려준다. -1이든 +1이든 1로 보고 `<= 1`이면 "정확히 가운데"로 판정했다.

---

### 가운데 좌표 구하기

가운데에 놓을 좌표는 이렇게 구한다.

```swift
private static func centerCoordinate(_ d: Monitor, _ n: Neighbor) -> Int {
    let o = n.monitor
    switch n.axis {
    case .x: return o.x + floorDiv(o.width - d.width, 2)
    case .y: return o.y + floorDiv(o.height - d.height, 2)
    }
}

private static func floorDiv(_ a: Int, _ b: Int) -> Int {
    Int((Double(a) / Double(b)).rounded(.down))
}
```

맥북과 외장 모니터면 0 + floor(내림)((1512 - 1920) / 2) = -204로 실측값과 같다.

#### rounded로 음수에서도 내림하기

Swift의 `Int` 나눗셈은 0 쪽으로 잘라서, 음수는 내림이 아니라 올림처럼 계산된다. 예를 들어 -409 / 2는 -204가 나오는데 내림은 -205다. 폭 차이가 음수일 때도 양수일 때와 같은 규칙(작은 쪽 칸)으로 맞추려고 `Double`로 바꾼 뒤 [`rounded(_:)`](https://developer.apple.com/documentation/swift/double/rounded%28%5F:%29){:target="_blank"}에 [`.down`](https://developer.apple.com/documentation/swift/floatingpointroundingrule/down){:target="_blank"}을 줬다. `.down`은 항상 작은 쪽 정수로 내리는 반올림 규칙이다.

---

## 끌어 놓으면 붙고 가운데로 달라붙는 계산

편집 창에서 모니터를 끌어 놓으면 두 단계로 정리한다. 먼저 다른 모니터의 위, 아래, 왼쪽, 오른쪽 자리를 후보로 만든다. 맞닿는 길이가 최소 100(`minContact`)이 되게 하고, 다른 모니터와 겹치는 후보는 버린다. 남은 후보 중 가로세로 이동 거리의 합이 가장 짧은 곳으로 붙는다. 그 뒤 이웃과 가운데까지 거리가 60(`snapDistance`) 이내이면 가운데로 더 달라붙는다.

```swift
public static func snap(_ id: String, in monitors: [Monitor]) -> [Monitor] {
    guard var d = monitors.first(where: { $0.id == id }) else { return monitors }
    var best: (x: Int, y: Int, dist: Int)?
    for o in monitors where o.id != id {
        let cx = min(max(d.x, o.x - d.width + minContact), o.x + o.width - minContact)
        let cy = min(max(d.y, o.y - d.height + minContact), o.y + o.height - minContact)
        for c in [(cx, o.y - d.height), (cx, o.y + o.height), (o.x - d.width, cy), (o.x + o.width, cy)] {
            var t = d; t.x = c.0; t.y = c.1
            if collides(t, in: monitors) { continue }
            let dist = abs(c.0 - d.x) + abs(c.1 - d.y)
            if best == nil || dist < best!.dist { best = (c.0, c.1, dist) }
        }
    }
    if let b = best { d.x = b.x; d.y = b.y }
    var result = monitors.map { $0.id == id ? d : $0 }
    if let n = neighbor(of: d, in: result) {
        var t = d
        let target = centerCoordinate(d, n)
        if n.axis == .x { t.x = target } else { t.y = target }
        let gap = n.axis == .x ? abs(d.x - target) : abs(d.y - target)
        if gap <= snapDistance && !collides(t, in: result) {
            let moved = result.map { $0.id == id ? t : $0 }
            // 놓은 직후 배치가 이어져 있었다면, 옮긴 뒤에도 이어져 있을 때만 옮긴다.
            if !isValid(result) || isValid(moved) { result = moved }
        }
    }
    return result
}
```

#### min과 max로 맞닿는 범위 안으로 끌어오기

[`max`](https://developer.apple.com/documentation/swift/max%28%5F:%5F:%29){:target="_blank"}와 [`min`](https://developer.apple.com/documentation/swift/min%28%5F:%5F:%29){:target="_blank"}를 겹쳐 쓰면 값을 범위 안에 가두는 계산이 된다. `cx`는 끌어 놓은 x를 `o.x - d.width + 100`과 `o.x + o.width - 100` 사이로 가둔 값이다. 이 범위 안이면 위아래로 붙였을 때 두 모니터가 가로로 겹치는 길이가 최소 100이 된다. `cy`는 같은 계산을 세로로 한 것이다.

후보 네 개는 순서대로 `o`의 위쪽, 아래쪽, 왼쪽, 오른쪽에 붙은 자리다. 후보마다 겹치는지 보고, 안 겹치면 지금 자리에서 얼마나 옮겨야 하는지(`dist`)를 재서 가장 작은 것을 `best`에 둔다. `abs`는 앞에서 설명한 것과 같다. [`first(where:)`](https://developer.apple.com/documentation/swift/sequence/first%28where:%29){:target="_blank"}는 조건에 맞는 첫 원소를 돌려준다. `map`은 각 원소를 바꾼 새 배열을 만들고, `$0`은 클로저가 받은 첫 번째 값이다.

---

### 달라붙기가 모니터 3개의 이어짐을 끊는 경우

위 코드에서 마지막 `if !isValid(result) || isValid(moved)` 줄은 코드 리뷰에서 문제가 나온 뒤에 넣었다. 모니터가 3개일 때 가운데로 달라붙는 것이 다른 모니터와의 이어짐을 끊을 수 있었다.

시험에 쓴 값은 이렇다. top은 (0, 0)에 1000 × 800, side는 (1040, 800)에 800 × 600, d는 (40, 800)에 1000 × 600이다. d는 top 아래에 붙어 있고, side는 d와만 맞닿아 있다. top을 기준으로 한 d의 가운데 좌표는 x = 0이고, 지금 위치와 거리는 40이라 달라붙기 범위(60) 안이다. 그런데 d가 x = 0으로 가면 오른쪽 끝이 1000이 되어 side(1040)와 40 벌어지고, side가 어디와도 맞닿지 않게 된다.

![d가 가운데(x 0)로 달라붙으면 오른쪽 끝이 1000이 되어 side와 40 벌어지고 side가 떨어져 나간다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-07-DisplayAlign-1/displayalign-snap-gap.png)

"이어져 있다"는 `isValid`가 판단한다. 겹치는 모니터가 없고, 모든 모니터가 맞닿음을 따라 하나로 이어져 있으면 유효하다.

이어져 있어야 하는 이유는 적용 단계에 있다. `CGConfigureDisplayOrigin` 문서에는 macOS가 요청한 위치에서 가장 가까운 자리로, 모니터 사이에 겹침이나 틈이 없게 옮긴다고 적혀 있다. 벌어진 배치를 넘기면 내가 놓은 곳과 다른 곳에 놓일 수 있다. 그래서 `apply`도 첫 줄에서 유효한 배치만 통과시킨다.

```swift
public static func isValid(_ monitors: [Monitor]) -> Bool {
    guard !monitors.isEmpty else { return false }
    for (i, a) in monitors.enumerated() {
        for b in monitors[(i + 1)...] where overlaps(a, b) { return false }
    }
    var seen: Set<String> = [monitors[0].id]
    var queue = [monitors[0]]
    while let cur = queue.popLast() {
        for o in monitors where !seen.contains(o.id) && neighbor(of: cur, in: [cur, o]) != nil {
            seen.insert(o.id)
            queue.append(o)
        }
    }
    return seen.count == monitors.count
}
```

#### Set과 popLast로 이어짐 확인하기

1. [`enumerated()`](https://developer.apple.com/documentation/swift/sequence/enumerated%28%29){:target="_blank"}로 번호와 모니터를 같이 꺼내, 모든 쌍을 한 번씩 비교해 겹치는 쌍이 있으면 바로 `false`를 돌려준다.
2. [`Set`](https://developer.apple.com/documentation/swift/set){:target="_blank"}은 중복 없이 모아 두는 상자다. `seen`에 첫 모니터를 넣고 출발한다.
3. [`popLast()`](https://developer.apple.com/documentation/swift/array/poplast%28%29){:target="_blank"}로 대기열 맨 뒤의 모니터를 하나 꺼내고, 그 모니터와 맞닿은 아직 안 본 모니터를 `seen`과 대기열에 넣는다. 물감이 번지듯 맞닿은 쪽으로 퍼져 나간다. `neighbor(of: cur, in: [cur, o])`는 두 모니터만 넘겨서, 둘이 맞닿았는지 묻는 용도로 썼다.
4. 다 퍼진 뒤 `seen`의 개수가 전체 모니터 수와 같으면 모두 이어진 것이다.

---

### 고친 조건과 시험

고친 조건은 이렇다. 놓은 직후 배치(`result`)가 이어져 있었다면, 가운데로 옮긴 배치(`moved`)도 이어져 있을 때만 옮긴다. 처음부터 이어져 있지 않던 배치는 옮겨도 더 나빠질 게 없어서 그대로 옮긴다. 시험도 같이 넣었다.

```swift
@Test func 가운데로_옮기면_이어짐이_끊기는_경우는_옮기지_않는다() {
    let top = mon("top", 1000, 800, 0, 0, main: true)
    let side = mon("side", 800, 600, 1040, 800)
    let d = mon("d", 1000, 600, 40, 800)
    let r = Layout.snap("d", in: [top, side, d])
    #expect(r.first { $0.id == "d" }?.x == 40)
    #expect(Layout.isValid(r))
}
```

#### #expect로 옮기지 않았는지 확인하기

[`@Test`](https://developer.apple.com/documentation/testing/test%28%5F:%5F:%29){:target="_blank"}를 붙인 함수는 Swift Testing(Swift 공식 시험 도구)이 시험으로 돌린다. [`#expect`](https://developer.apple.com/documentation/testing/expect%28%5F:%5F:sourcelocation:%29){:target="_blank"}는 괄호 안 조건이 참인지 확인하고, 거짓이면 그 줄의 값을 보여 주며 시험을 실패시킨다. 여기서는 d의 x가 40 그대로이고, 결과 배치도 유효한지 본다. `mon`은 시험 파일에 둔 도우미로 (이름, 폭, 높이, x, y)를 받아 `Monitor`를 만든다.

---

## 여러 모니터 위치를 한 번에 바꾸는 CoreGraphics 설정

계산이 끝난 배치를 macOS에 넘기는 부분이다. 모니터 위치를 바꾸는 함수는 하나씩 부르는 방식이 아니라, 여러 변경을 모아서 한 번에 적용하는 방식으로 되어 있다.

---

### 디스플레이 설정 묶음이란?

장바구니에 물건을 담고 한 번에 결제하는 것과 비슷하다. `Begin`으로 빈 묶음을 열고, `Configure`로 모니터마다 바꿀 위치를 담고, `Complete`로 한꺼번에 적용한다. 문서는 이 적용이 atomic transaction이라고 설명한다. 전부 되거나 전부 안 되는 한 덩어리라는 뜻이다.

`CGConfigureDisplayOrigin`은 첫 인자로 묶음을 받는 함수라서, 모니터 하나를 바로 옮기는 길이 따로 없다. 실제 적용은 `Complete` 한 번에 일어나고, `CGDisplayConfiguration.h` 주석에 따르면 macOS는 요청받은 배치에서 틈과 겹침을 없애 결과 배치를 만든다. 그래서 앱은 모든 모니터의 최종 좌표를 담은 뒤 한 번만 적용한다.

```swift
/// 검사와 원점 정리, 끊긴 모니터 확인은 macOS 설정을 열기 전에 끝낸다.
public static func apply(_ monitors: [Monitor]) throws {
    guard Layout.isValid(monitors) else { throw DisplayError.invalidLayout }
    guard monitors.contains(where: \.isMain) else { throw DisplayError.noMainMonitor }
    let ids = Dictionary(activeDisplays().map { ($0.uuid, $0.id) }, uniquingKeysWith: { a, _ in a })
    let targets = try Layout.normalized(monitors).map { m -> (CGDirectDisplayID, Monitor) in
        guard let id = ids[m.id] else { throw DisplayError.monitorMissing(m.name) }
        return (id, m)
    }

    var config: CGDisplayConfigRef?
    try check(CGBeginDisplayConfiguration(&config), "설정 시작", config)
    for (id, m) in targets {
        try check(CGConfigureDisplayOrigin(config, id, Int32(m.x), Int32(m.y)), "위치 지정", config)
    }
    // Complete가 돌아오면 설정은 이미 무효라서 취소하지 않는다.
    let done = CGCompleteDisplayConfiguration(config, .permanently)
    guard done == .success else { throw DisplayError.systemFailure("설정 저장", done.rawValue) }
}

private static func check(_ error: CGError, _ step: String, _ config: CGDisplayConfigRef?) throws {
    guard error != .success else { return }
    CGCancelDisplayConfiguration(config)
    throw DisplayError.systemFailure(step, error.rawValue)
}
```

#### CGBeginDisplayConfiguration으로 위치 바꾸기

1. 설정을 열기 전에 먼저 검사한다. 배치가 유효한지, 주 모니터가 있는지 보고, 현재 연결된 모니터의 UUID와 번호를 [`Dictionary(_:uniquingKeysWith:)`](https://developer.apple.com/documentation/swift/dictionary/init%28%5F:uniquingkeyswith:%29){:target="_blank"}로 짝지어 둔다. 같은 열쇠가 두 번 나오면 앞의 값을 남기라는 뜻의 `{ a, _ in a }`를 넘겼다. 저장된 모니터가 연결 목록에 없으면 여기서 에러를 던져 macOS 설정을 건드리기 전에 멈춘다. [`contains(where:)`](https://developer.apple.com/documentation/swift/sequence/contains%28where:%29){:target="_blank"}는 조건에 맞는 원소가 하나라도 있으면 `true`를 준다. `\.isMain`은 각 모니터의 `isMain` 값을 조건으로 쓰는 줄임 표현이다.
2. [`CGBeginDisplayConfiguration`](https://developer.apple.com/documentation/coregraphics/cgbegindisplayconfiguration%28%5F:%29){:target="_blank"}은 빈 묶음을 만들어 `config`(`CGDisplayConfigRef`)에 담아 준다. 결과는 `CGError`이고 `.success`가 아니면 실패다.
3. [`CGConfigureDisplayOrigin`](https://developer.apple.com/documentation/coregraphics/cgconfiguredisplayorigin%28%5F:%5F:%5F:%5F:%29){:target="_blank"}은 묶음에 모니터 하나의 새 왼쪽 위 좌표를 담는다. 문서에 따르면 요청한 위치에 가장 가깝게, 겹침이나 틈 없이 놓는다. 모니터마다 한 번씩 부른다.
4. [`CGCompleteDisplayConfiguration`](https://developer.apple.com/documentation/coregraphics/cgcompletedisplayconfiguration%28%5F:%5F:%29){:target="_blank"}이 묶음을 한꺼번에 적용한다. 두 번째 인자 [`CGConfigureOption`](https://developer.apple.com/documentation/coregraphics/cgconfigureoption){:target="_blank"}은 변경이 얼마나 오래 가는지를 정한다. `.permanently`는 다음 로그인 뒤에도 유지하고, `.forSession`은 지금 로그인 세션 동안만, `.forAppOnly`는 이 앱이 켜져 있는 동안만이다.
5. [`CGCancelDisplayConfiguration`](https://developer.apple.com/documentation/coregraphics/cgcanceldisplayconfiguration%28%5F:%29){:target="_blank"}은 담아 둔 묶음을 버린다. 시작이나 위치 지정이 실패했을 때 `check` 함수에서 부른다.

---

### Complete가 실패해도 Cancel을 부르지 않는 이유

처음 코드는 `Complete`가 실패해도 `Cancel`을 불렀다. 코드 리뷰에서 그러면 안 된다는 지적이 나왔다. 근거는 CoreGraphics 헤더(함수 선언과 설명 주석을 모아 둔 파일) `CGDisplayConfiguration.h`의 `CGCompleteDisplayConfiguration` 주석이다.

> On return, the configuration is no longer valid.

이 함수가 돌아온 순간 성공이든 실패든 묶음은 이미 쓸 수 없는 상태다. 거기에 `Cancel`을 부르면 이미 사라진 것을 또 취소하는 셈이 된다. 그래서 시작과 위치 지정이 실패했을 때만 `check`에서 취소하고, 완료가 실패하면 취소 없이 에러만 던진다.

![Begin과 Configure가 실패하면 점선을 따라 Cancel로 가지만, Complete가 실패하면 묶음이 이미 무효라서 Cancel 없이 에러만 던진다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-07-DisplayAlign-1/displayalign-config-flow.png)

---

### 주 모니터를 (0, 0)에 두는 원점 정리

`CGConfigureDisplayOrigin` 문서에서 주 모니터의 origin은 (0, 0)이다. 앱 편집 창에서 주 모니터를 끌어 옮기면 그 좌표가 (0, 0)에서 벗어나므로, 적용 직전에 `normalized`로 전체를 같은 만큼 옮긴다.

```swift
public static func normalized(_ monitors: [Monitor]) -> [Monitor] {
    guard let main = monitors.first(where: { $0.isMain }) else { return monitors }
    return monitors.map { m in
        var c = m
        c.x -= main.x
        c.y -= main.y
        return c
    }
}
```

#### first(where:)로 주 모니터를 기준 삼아 옮기기

주 모니터가 없으면 그대로 돌려주고, 있으면 그 x, y를 모든 모니터에서 똑같이 빼 준다. 전체가 같은 만큼 움직이니 모니터 사이의 상대 위치는 변하지 않는다. 앞의 `apply`에서 `Layout.normalized(monitors)`로 부르는 것이 이 함수다.

---

### 적용 후 다시 읽기

macOS가 요청과 다른 자리에 놓을 수도 있어서, 적용한 뒤 300ms를 기다렸다가 모니터 위치를 다시 읽어 요청과 비교한다.

```swift
/// 적용하고 다시 읽어서 요청과 같은지 확인한다. 같을 때만 true.
private func apply(_ layout: [Monitor]) async -> Bool {
    guard !applying else { return false }
    applying = true
    defer { applying = false }
    do {
        try DisplaySystem.apply(layout)
    } catch {
        resultMessage = error.localizedDescription
        return false
    }
    try? await Task.sleep(for: .milliseconds(300))
    let now = DisplaySystem.readMonitors()
    connected = now
    draft = now
    let wanted = Set(Layout.normalized(layout).map { "\($0.id) \($0.x) \($0.y)" })
    let actual = Set(now.map { "\($0.id) \($0.x) \($0.y)" })
    let exact = wanted == actual
    resultMessage = exact ? "적용했어요." : "macOS가 위치를 조금 바꿔 놓았어요. 지금 배치를 확인해 주세요."
    // 기록 저장이 실패하면 그 문구가 위 문구를 대신한다.
    markKnown(layout.map(\.id))
    return exact
}
```

#### Task.sleep으로 기다렸다 다시 읽기

[`Task.sleep(for:)`](https://developer.apple.com/documentation/swift/task/sleep%28for:tolerance:clock:%29){:target="_blank"}는 지정한 [`Duration`](https://developer.apple.com/documentation/swift/duration){:target="_blank"}만큼 기다린다. 화면을 멈추지 않고 `await`로 기다리는 것이라 그동안 앱은 계속 반응한다. 적용 직후에는 macOS가 아직 위치를 정리하는 중일 수 있어서 300ms를 두었다. 기다림이 취소되면 에러가 나는데 `try?`로 무시하고 그냥 다음 줄로 간다.

요청한 배치와 지금 읽은 배치를 "모니터 id, x, y" 문자열의 `Set`으로 만들어 같은지 비교한다. 같으면 "적용했어요."이고, 다르면 macOS가 위치를 바꿨다는 문구를 보여 준다.

`applying`은 적용 중에 또 눌려도 겹쳐 돌지 않게 막는 표시이고, `defer`는 함수가 어떻게 끝나든 마지막에 실행하라는 문법이다. `connected`는 실제 연결 상태, `draft`는 편집 창에서 고치는 중인 배치다. `markKnown`은 이 모니터들을 이미 본 모니터로 기록하는데, 기록 저장이 실패하면 그 실패 문구가 결과 문구를 대신한다.

---

## 눌러서 적용하는 프리셋

프리셋을 모니터를 꽂을 때 자동으로 적용할지, 내가 눌러서 적용할지 정해야 했다. 눌러서 적용하기로 했다. 모니터를 꽂거나 뽑아도 배치가 저절로 바뀌지 않는다. 처음 보는 모니터가 연결되면 편집 창을 열어 알려 주기만 한다. 연결이 바뀌었다는 신호는 이렇게 받는다.

```swift
// 생략 (init 앞부분)
connected = DisplaySystem.readMonitors()
draft = connected
if loaded && knownIDs.isEmpty {
    knownIDs = connected.map(\.id)
    persist()
}
detectNewMonitors()
Task { [weak self] in
    for await _ in NotificationCenter.default.notifications(
        named: NSApplication.didChangeScreenParametersNotification) {
        self?.refresh()
    }
}
```

#### notifications로 모니터 연결 변화 알아채기

[`NSApplication.didChangeScreenParametersNotification`](https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification){:target="_blank"}은 모니터가 연결되거나 빠지거나 해상도, 배치가 바뀔 때 macOS가 보내는 알림이다. [`NotificationCenter.notifications(named:)`](https://developer.apple.com/documentation/foundation/notificationcenter/notifications%28named:object:%29){:target="_blank"}는 이 알림을 `for await`로 하나씩 받을 수 있게 해 준다. 알림이 올 때마다 `refresh()`로 연결 목록과 편집 중인 배치를 다시 맞추고, 처음 보는 모니터가 있으면 편집 창을 연다. 저장된 프리셋을 적용하는 코드는 여기 없다.

아는 모니터 기록이 비어 있는 처음 실행이면 연결된 모니터를 전부 아는 모니터로 저장한다(`persist()`). 그래서 처음 켰을 때는 창이 뜨지 않는다. [`Task`](https://developer.apple.com/documentation/swift/task){:target="_blank"}는 뒤에서 도는 비동기 작업을 만들고, `[weak self]`는 이 끝나지 않는 반복이 `AppModel`을 붙잡아 두지 않게 하는 표시다.

---

### 프리셋의 세 가지 상태

프리셋은 저장 당시의 모니터 구성과 맞는지에 따라 세 가지 상태가 된다.

```swift
public static func status(of preset: Preset, connected: [Monitor]) -> PresetStatus {
    let saved = Dictionary(preset.monitors.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let now = Dictionary(connected.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    guard Set(saved.keys) == Set(now.keys) else { return .monitorsMissing }
    let same = saved.allSatisfy { id, m in
        now[id]!.width == m.width && now[id]!.height == m.height
    }
    return same ? .ready : .sizeChanged
}
```

| 상태 | 뜻 |
|---|---|
| `ready` | 같은 모니터가 모두 연결되어 있고 크기도 같다. 적용할 수 있다 |
| `sizeChanged` | 모니터는 같은데 해상도가 달라졌다. 적용을 막는다 |
| `monitorsMissing` | 저장 때와 연결된 모니터 구성이 다르다. 적용을 막는다 |

크기가 달라지면 막는 이유는 저장한 좌표가 옛 크기 기준이라서다. 해상도가 바뀐 모니터에 옛 좌표를 그대로 넣으면 맞닿음과 가운데가 틀어진다.

#### allSatisfy로 크기가 같은지 확인하기

[`allSatisfy(_:)`](https://developer.apple.com/documentation/swift/sequence/allsatisfy%28%5F:%29){:target="_blank"}는 모든 원소가 조건을 만족할 때만 `true`를 준다. 저장된 모니터 전부에 대해 지금 폭과 높이가 같은지 본다. 앞의 `guard`에서 두 쪽의 모니터 id 집합이 같다는 것을 이미 확인해서 `now[id]!`로 꺼낸다.

---

## 메뉴 막대 앱이란?

Dock에 아이콘이 없고 화면 위쪽 메뉴 막대에만 아이콘이 있는 앱이다. 모니터 배치는 가끔 바꾸는 일이라 늘 떠 있는 창이 필요 없고, 메뉴 막대에서 프리셋을 누르거나 편집 창을 여는 정도면 충분해서 이 형태로 만들었다. 앱 구조는 이렇다.

```swift
@main
struct DisplayAlignApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }

        Window("DisplayAlign", id: "editor") {
            EditorView().environment(model)
        }
    }
}
```

```swift
// MenuContent 안
@Environment(\.openWindow) private var openWindow
// 생략
Button("배치 편집…") {
    openWindow(id: "editor")
    NSApp.activate()
}
```

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
```

#### MenuBarExtra와 Window로 메뉴 막대 앱 만들기

1. [`@State`](https://developer.apple.com/documentation/swiftui/state){:target="_blank"}로 `AppModel`을 앱 전체에서 하나만 쥐고, [`.environment(_:)`](https://developer.apple.com/documentation/swiftui/view/environment%28%5F:%29){:target="_blank"}로 메뉴와 창에 내려보낸다. 안쪽 view에서는 [`@Environment`](https://developer.apple.com/documentation/swiftui/environment){:target="_blank"}로 꺼내 쓴다.
2. [`MenuBarExtra`](https://developer.apple.com/documentation/swiftui/menubarextra){:target="_blank"}는 메뉴 막대에 아이콘을 만든다. 첫 번째 클로저(중괄호로 묶어 넘기는 코드 덩어리, `content`)가 눌렀을 때 나오는 메뉴이고, `label`이 막대에 보이는 아이콘이다. 메뉴 안에는 프리셋마다 [`Button`](https://developer.apple.com/documentation/swiftui/button){:target="_blank"}을 두었다.
3. [`Window`](https://developer.apple.com/documentation/swiftui/window){:target="_blank"}는 창 하나를 선언한다. 첫 인자가 창 제목이고 `id`가 이 창의 이름표다. 같은 이름의 창은 하나만 뜬다.
4. [`openWindow`](https://developer.apple.com/documentation/swiftui/environmentvalues/openwindow){:target="_blank"}는 `id`로 창을 여는 함수다. 환경에서 꺼내 `openWindow(id: "editor")`처럼 부른다.
5. [`NSApp.activate()`](https://developer.apple.com/documentation/appkit/nsapplication/activate%28%29){:target="_blank"}는 앱을 맨 앞으로 가져온다. 메뉴 막대 앱은 창을 열어도 다른 앱 뒤에 있는 채로 남을 수 있어서 같이 불렀다.
6. `Info.plist`의 [`LSUIElement`](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement){:target="_blank"}를 `true`로 하면 앱이 Dock에 나타나지 않는다. 이 키가 없으면 메뉴 막대 아이콘에 더해 Dock에도 아이콘이 생긴다.

---

## 끌기가 취소돼도 굳지 않는 상태

모니터를 끌 때 앱은 몇 가지 값을 잠시 쥐고 있다. 어디서 끌기 시작했는지(`dragStart`), 끄는 동안 고정해 둔 축척(`frozen`)이 그렇다. 끌기가 정상적으로 끝나면 `onEnded`에서 이 값들을 비운다. 그런데 끌기가 중간에 취소되면 `onEnded`가 불리지 않아서 값이 남는다. 그러면 다음 끌기가 새 시작점을 저장하지 않고 옛 시작점과 옛 축척을 그대로 쓴다.

---

### @GestureState란?

제스처가 진행되는 동안만 값을 갖는 상태다. 제스처가 끝나거나 취소되면 값을 처음 값으로 되돌려 놓는다. 그래서 끝나는 방식에 관계없이 "지금 끄는 중인가?"를 알려 주는 믿을 만한 표시가 된다. 이걸 `onChange`로 지켜보다가, 끄는 중이 아니게 되는 순간 상태를 비운다.

```swift
struct CanvasView: View {
    // 생략
    /// 끄는 동안 축척을 고정한다.
    @State private var frozen: ViewTransform?
    @State private var dragStart: Monitor?
    @State private var moved = false
    @GestureState private var gestureActive = false

    var body: some View {
        GeometryReader { geo in
            // 생략
            ZStack(alignment: .topLeading) {
                // 생략
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(name: "canvas")
        }
        .clipped()
        .onChange(of: gestureActive) { _, active in
            // 드래그가 취소되어 onEnded가 불리지 않아도 상태가 굳지 않게 한다.
            guard !active, let start = dragStart else { return }
            if moved { model.drop(start.id) }
            dragStart = nil
            moved = false
            frozen = nil
        }
        // 생략
    }
}
```

#### onChange로 제스처가 끝난 순간 알아채기

1. [`@GestureState`](https://developer.apple.com/documentation/swiftui/gesturestate){:target="_blank"}는 위에서 설명한 대로 제스처가 끝나면 `false`로 돌아온다.
2. [`onChange(of:initial:_:)`](https://developer.apple.com/documentation/swiftui/view/onchange%28of:initial:%5F:%29){:target="_blank"}는 지켜보는 값이 바뀔 때마다 클로저를 부른다. 클로저는 바뀌기 전 값과 바뀐 값 두 개를 받는다. 여기서는 바뀐 값(`active`)이 `false`가 된 순간이 끌기가 끝났거나 취소된 순간이다.
3. 그때 끌던 모니터가 있고 실제로 움직였으면 `drop`으로 자리를 확정하고, 상태는 모두 비운다. `onEnded`가 이미 같은 일을 했다면 `dragStart`가 `nil`이라 `guard`에서 걸려 두 번 하지 않는다.
4. [`GeometryReader`](https://developer.apple.com/documentation/swiftui/geometryreader){:target="_blank"}는 주어진 공간의 크기(`geo.size`)를 알려 주고, [`coordinateSpace(name:)`](https://developer.apple.com/documentation/swiftui/view/coordinatespace%28name:%29){:target="_blank"}는 그 영역에 "canvas"라는 이름의 좌표 공간을 만든다. [`clipped()`](https://developer.apple.com/documentation/swiftui/view/clipped%28antialiased:%29){:target="_blank"}는 영역 밖으로 삐져나온 것을 잘라 낸다.

---

### 끌기 제스처

끌기 동작 자체는 이렇다.

```swift
private func drag(_ m: Monitor, _ t: ViewTransform) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
        .updating($gestureActive) { _, state, _ in state = true }
        .onChanged { value in
            if dragStart == nil {
                dragStart = m
                frozen = t
                model.press(m.id)
            }
            guard let start = dragStart, let scale = frozen?.scale else { return }
            // 화면 3pt 이상 움직였을 때부터 끄는 것으로 본다.
            if !moved && hypot(value.translation.width, value.translation.height) >= 3 {
                moved = true
                model.isDragging = true
            }
            guard moved else { return }
            model.move(m.id,
                       x: start.x + Int((value.translation.width / scale).rounded()),
                       y: start.y + Int((value.translation.height / scale).rounded()))
        }
        .onEnded { _ in
            // 누르기만 하고 놓은 경우는 고르기만 하고 배치는 건드리지 않는다.
            if moved { model.drop(m.id) }
            dragStart = nil
            moved = false
            frozen = nil
        }
}
```

#### DragGesture와 updating으로 끌기 상태 관리하기

1. [`DragGesture(minimumDistance:coordinateSpace:)`](https://developer.apple.com/documentation/swiftui/draggesture/init%28minimumdistance:coordinatespace:%29){:target="_blank"}는 끌기 제스처를 만든다. `minimumDistance`를 0으로 줘서 누르는 순간부터 반응하게 했다. `coordinateSpace`에 앞에서 이름을 붙인 "canvas"를 줘서, 모니터 자신이 움직여도 흔들리지 않는 캔버스 기준의 위치로 `translation`(시작점에서 얼마나 움직였는지)을 받는다.
2. [`updating(_:body:)`](https://developer.apple.com/documentation/swiftui/gesture/updating%28%5F:body:%29){:target="_blank"}는 제스처가 진행되는 동안 `@GestureState` 값을 바꾼다. 여기서는 `state = true`로 "끄는 중"을 켠다. 클로저는 제스처의 현재 값, 바꿀 상태, 화면 변경 정보(transaction) 세 개를 받는다. 여기서는 가운데 상태만 쓰고 나머지는 `_`로 버린다. `$gestureActive`의 `$`는 값이 아니라 값을 바꿀 수 있는 연결(binding)을 넘긴다는 표시다.
3. [`onChanged`](https://developer.apple.com/documentation/swiftui/gesture/onchanged%28%5F:%29){:target="_blank"}는 움직일 때마다 불린다. 처음 불릴 때 시작 모니터와 축척을 저장한다. 마우스가 3pt 이상 움직이면 그때부터 끄는 것으로 보고, 움직인 거리를 축척으로 나눠 실제 좌표로 바꿔 `model.move`에 넘긴다. 거리 계산에 쓴 `hypot`은 가로세로 이동량으로 대각선 길이를 구하는 C 수학 함수다.
4. [`onEnded`](https://developer.apple.com/documentation/swiftui/gesture/onended%28%5F:%29){:target="_blank"}는 마우스 버튼을 정상적으로 뗐을 때 불린다. 움직이지 않고 누르기만 했다면 모니터를 고르기만 하고 배치는 건드리지 않는다.

끄는 동안 축척을 `frozen`에 고정하는 이유가 있다. 놓으면 화면 크기에 맞게 축척을 다시 맞추는데, 끄는 중에 축척이 바뀌면 마우스 포인터 위치와 모니터가 어긋나 버린다.

---

### 수식어 순서와 position

SwiftUI의 modifier(view 뒤에 점으로 이어 붙여 모양과 동작을 바꾸는 함수)는 앞의 view를 감싼 새 view를 돌려주기 때문에 위에서 아래로 쌓인다. `.position`은 모니터 사각형을 원하는 자리로 옮기면서, 자기 자신은 부모가 준 공간 전체를 차지한다. 여기서는 부모가 캔버스 전체라서 `.position`이 돌려주는 view의 크기가 캔버스 전체가 된다. 그 뒤에 수식어를 붙이면 모니터 사각형이 아니라 캔버스 전체 크기의 view에 붙게 된다.

처음 코드는 `.position` 뒤에 `.gesture`와 접근성 수식어가 있었다.

```swift
return RoundedRectangle(cornerRadius: 5)
    // 생략 (fill, overlay)
    .frame(width: w, height: h)
    .zIndex(isSelected ? 1 : 0)
    .position(x: origin.x + w / 2, y: origin.y + h / 2)
    .gesture(drag(m, t))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(m.name)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { model.selectedID = m.id }
    .accessibilityIdentifier("monitor-\(m.name)")
```

코드 리뷰에서는 빈 곳은 마우스 입력을 받는 영역이 아니라서, SwiftUI의 일반 동작으로는 끌기 영역이 실제로 넓어지지는 않을 것으로 봤다. 다만 실행해서 확인한 것은 아니다. 접근성 쪽은 영역이 캔버스 전체가 될 가능성이 있었다. 그래서 `.position`과 `.zIndex`를 `.gesture`와 접근성 수식어 뒤로 옮겨, 그런 의문이 생길 자리 자체를 없앴다.

```swift
return RoundedRectangle(cornerRadius: 5)
    // 생략 (fill, overlay)
    .frame(width: w, height: h)
    .gesture(drag(m, t))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(m.name)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { model.selectedID = m.id }
    .accessibilityIdentifier("monitor-\(m.name)")
    .position(x: origin.x + w / 2, y: origin.y + h / 2)
    .zIndex(isSelected ? 1 : 0)
```

#### position으로 모니터 사각형 자리 잡기

| 수식어 | 하는 일 |
|---|---|
| [`frame(width:height:alignment:)`](https://developer.apple.com/documentation/swiftui/view/frame%28width:height:alignment:%29){:target="_blank"} | 모니터 사각형의 크기를 화면 축척에 맞춰 정한다 |
| [`gesture(_:including:)`](https://developer.apple.com/documentation/swiftui/view/gesture%28%5F:including:%29){:target="_blank"} | 위의 끌기 제스처를 이 사각형에 붙인다 |
| [`accessibilityElement(children:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityelement%28children:%29){:target="_blank"} | `.ignore`로 안쪽 글자들을 따로 읽지 않고 사각형 하나를 접근성 요소 하나로 만든다 |
| [`accessibilityLabel`](https://developer.apple.com/documentation/swiftui/view/accessibilitylabel%28%5F:%29){:target="_blank"} | 화면 읽기에서 부를 이름으로 모니터 이름을 준다 |
| [`accessibilityAddTraits`](https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits%28%5F:%29){:target="_blank"} | `.isButton`으로 누를 수 있는 것이라고 알린다 |
| [`accessibilityAction`](https://developer.apple.com/documentation/swiftui/view/accessibilityaction%28%5F:%5F:%29){:target="_blank"} | 접근성 기능으로 누르면 이 모니터를 고르게 한다 |
| [`accessibilityIdentifier`](https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier%28%5F:%29){:target="_blank"} | 자동 조작에서 이 사각형을 찾을 수 있는 이름을 준다 |
| [`position(x:y:)`](https://developer.apple.com/documentation/swiftui/view/position%28x:y:%29){:target="_blank"} | view의 중심을 부모 안의 이 좌표에 놓는다. 부모가 준 공간 전체를 차지한다 |
| [`zIndex`](https://developer.apple.com/documentation/swiftui/view/zindex%28%5F:%29){:target="_blank"} | 겹칠 때 어느 것이 위에 그려질지 정한다. 고른 모니터를 위로 올린다 |

`.position`의 x, y는 사각형의 왼쪽 위가 아니라 중심이라서 `origin`에 폭과 높이의 절반을 더했다. 이 수식어를 `.gesture`와 접근성 수식어 뒤에 두었으니 앞의 `.gesture`와 접근성 수식어는 모두 모니터 사각형 크기의 view에 붙는다.

---

## 확인한 것

| 항목 | 결과 |
|---|---|
| `swift test` 25개 | <span style="color:#2e9e4f">**통과**</span> |
| 실제 화면 이동과 복구 (`DISPLAYALIGN_LIVE_TEST=1`) | <span style="color:#2e9e4f">**통과**</span> (1 pt 옮겨 읽어 확인한 뒤 원래 자리로 되돌림) |
| 접근성 요소로 모니터 조작 | <span style="color:#2e9e4f">**통과**</span> |
| 외장 모니터 가운데 맞춤 실측 | <span style="color:#2e9e4f">**통과**</span> (x -204, 어긋남 0) |
| 마우스로 직접 끌기 | <span style="color:#d29922">**아직 확인 못 함**</span> |
| 맥북까지 모니터 3개를 쓰는 조합 | <span style="color:#d29922">**아직 확인 못 함**</span> |

실제 화면을 움직이는 시험은 환경 변수를 켠 때만 돌아서, 평소 `swift test`에서는 건너뛴다. 마우스 끌기와 3개 조합은 직접 확인할 점검 목록을 만들어 두었고 아직 해 보지 않았다.

---

## 참고자료

- [Quartz Display Services (Apple)](https://developer.apple.com/documentation/coregraphics/quartz-display-services){:target="_blank"}
