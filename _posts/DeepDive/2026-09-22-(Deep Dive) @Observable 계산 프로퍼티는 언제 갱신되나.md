---
title: (Deep Dive) @Observable에서 계산 프로퍼티는 언제 화면을 다시 그리나
writer: Harold
date: 2026-09-22 00:00
categories: [Deep Dive]
tags: [Myself, SwiftUI]
published: false
toc: true
toc_sticky: true
---

RunWay 1.3.2에서 Pre-flight Check의 APPLE WATCH 항목을 고쳤다. 고치는 과정에서 AI와 이야기하다가 서로 말이 계속 엇갈렸다. 나중에 정리해보니 **질문 자체가 틀려 있었다.**

내가 물은 건 이거였다.

> `watchStatus`는 `@ObservationIgnored`가 안 붙었으니까 값이 바뀌면 계속 받을 수 있는 것 아닌가

대화가 길어진 이유가 여기 있었다. `@ObservationIgnored`가 붙었느냐 안 붙었느냐를 보고 있었는데, **그게 판단 기준이 아니었다.**

이 글에서 정리할 건 하나다. **계산 프로퍼티를 화면에서 읽었을 때, 그 값이 바뀌면 화면이 다시 그려지는지 어떻게 아는가.**

---

## 문제가 된 코드

```swift
@Observable
final class RunViewModel {
    @ObservationIgnored private var watchConnectivityService = WatchConnectivityService()

    // 화면(TakeoffView)이 이걸 읽는다
    var watchStatus: (label: String, ok: Bool) {
        guard watchConnectivityService.isWatchPaired else { return ("NOT PAIRED", false) }
        // 생략
        return ("READY", true)
    }
}
```

`RunViewModel`은 `@Observable`이고, `watchStatus`에는 아무것도 안 붙어 있다. 그래서 나는 이게 추적되는 값이라고 생각했다.

---

## @Observable이 실제로 하는 일

`@Observable`은 클래스 안의 **저장 프로퍼티**에 읽기/쓰기 표시를 붙여준다. 값을 읽을 때 "누가 이걸 봤다"고 기록하고, 값을 바꿀 때 "봤던 사람들에게 알려라"를 실행한다.

```swift
@Observable
final class Example {
    var stored = 0        // 값을 담고 있다 -> 붙는다
    var doubled: Int { stored * 2 }   // 담은 게 없다 -> 붙을 자리가 없다
}
```

`doubled`는 **값을 담고 있는 게 아니라 계산하는 방법만 적어둔 것**이다. 담은 게 없으니 "바뀌었다"고 알릴 내용도 없다. 붙이고 말고의 문제가 아니라 **붙일 대상이 아니다.**

그래서 `@ObservationIgnored`가 안 붙었다는 건 아무 의미가 없다. 그건 저장 프로퍼티에게 "너는 빼라"고 말하는 표시인데, 계산 프로퍼티는 애초에 명단에 없다.

---

## 계산 프로퍼티는 재료를 따라간다

그럼 `doubled`를 화면에서 읽으면 갱신이 될까. **된다.**

계산 프로퍼티는 자기가 추적되는 게 아니라, **읽는 순간 자기 안의 코드가 그대로 실행된다.** 그 안에서 `stored`를 읽으면, 화면이 `stored`를 직접 읽은 것과 똑같아진다. 그래서 `stored`가 바뀌면 화면이 다시 그려진다.

**계산 프로퍼티는 통로다.** 통로 자체는 아무것도 아니고, **끝에 뭐가 있느냐**가 전부다.

그러니 질문을 이렇게 바꿔야 했다.

> 이 계산 프로퍼티를 끝까지 따라가면 **@Observable의 저장 프로퍼티가 나오는가**

---

## 끝까지 따라가보기

<svg viewBox="0 0 420 372" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="계산 프로퍼티를 따라갔을 때 추적되는 경우와 안 되는 경우 비교" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="oa" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
  </defs>

  <text x="0" y="12" font-size="11" fill="#2fa37c" font-family="monospace">추적된다</text>
  <text x="224" y="12" font-size="11" fill="#e05c4f" font-family="monospace">추적되지 않는다</text>

  <rect x="0" y="22" width="196" height="52" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="14" y="41" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">계산 프로퍼티</text>
  <text x="14" y="61" font-size="12.5" fill="currentColor" font-weight="600">gpsSignalStatus</text>

  <rect x="224" y="22" width="196" height="52" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="238" y="41" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">계산 프로퍼티</text>
  <text x="238" y="61" font-size="12.5" fill="currentColor" font-weight="600">watchStatus</text>

  <line x1="98" y1="74" x2="98" y2="90" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>
  <line x1="322" y1="74" x2="322" y2="90" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>

  <rect x="0" y="94" width="196" height="52" rx="8" fill="none" stroke="#2fa37c" stroke-width="1.4"/>
  <text x="14" y="113" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">@Observable 저장</text>
  <text x="14" y="133" font-size="12.5" fill="#2fa37c" font-weight="600">accuracy</text>

  <rect x="224" y="94" width="196" height="52" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="238" y="113" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">@ObservationIgnored</text>
  <text x="238" y="133" font-size="11.5" fill="currentColor" font-weight="600">watchConnectivityService</text>

  <line x1="98" y1="146" x2="98" y2="162" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>
  <line x1="322" y1="146" x2="322" y2="162" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>

  <rect x="0" y="166" width="196" height="44" rx="8" fill="none" stroke="#2fa37c" stroke-width="1.4"/>
  <text x="14" y="194" font-size="13" fill="#2fa37c" font-weight="700">화면을 다시 그린다</text>

  <rect x="224" y="166" width="196" height="52" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="238" y="185" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">계산 프로퍼티</text>
  <text x="238" y="205" font-size="12.5" fill="currentColor" font-weight="600">isWatchPaired</text>

  <line x1="322" y1="218" x2="322" y2="234" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>

  <rect x="224" y="238" width="196" height="52" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="238" y="257" font-size="10" fill="currentColor" opacity=".5" font-family="monospace">시스템 값</text>
  <text x="238" y="277" font-size="12.5" fill="#e05c4f" font-weight="600">WCSession.isPaired</text>

  <line x1="322" y1="290" x2="322" y2="306" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#oa)"/>

  <rect x="224" y="310" width="196" height="44" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.4"/>
  <text x="238" y="338" font-size="13" fill="#e05c4f" font-weight="700">아무도 알려주지 않는다</text>
</svg>

왼쪽은 두 칸 만에 `@Observable`의 저장 프로퍼티가 나온다. 거기서 끝이다.

오른쪽은 네 칸을 가도 저장 프로퍼티가 안 나온다. 중간에 낀 `WatchConnectivityService`가 **`@Observable`이 아닌 평범한 클래스**라, 그 안에서 뭐가 바뀌어도 알려줄 방법이 없다. 그리고 그 끝은 `WCSession`이다. 애플이 만든 시스템 값이라 애초에 알림 기능이 없다.

---

## @ObservationIgnored를 떼면 되는 거 아닌가

내가 제일 헷갈렸던 부분이다. 떼봐도 안 된다.

```swift
// @ObservationIgnored 를 떼면 이건 감지된다
watchConnectivityService = WatchConnectivityService()

// 이건 여전히 감지 안 된다
// (watchConnectivityService 안의 값이 달라지는 것)
```

저장 프로퍼티가 참조 타입을 담고 있을 때, 추적되는 건 **그 변수가 가리키는 대상이 통째로 바뀌는 순간**이다. **상자를 갈아끼우는 건 알아채지만, 상자 안의 내용이 달라지는 건 모른다.**

안쪽까지 알려면 그 클래스도 `@Observable`이어야 한다. `WatchConnectivityService`는 아니다.

---

## 재현해보기

말로만 보면 헷갈려서 최소한의 코드로 만들어봤다. RunWay 코드를 그대로 가져올 필요는 없고, **@Observable이 아닌 클래스를 하나 들고 있는 상황**만 만들면 된다.

```swift
import SwiftUI

// @Observable 이 아닌 평범한 클래스. RunWay 의 WatchConnectivityService 자리다.
final class PlainBox {
    var number = 0
}

@Observable
final class ObservationDemoViewModel {
    // 1. 저장 프로퍼티
    var storedNumber = 0

    // 2. 저장 프로퍼티를 읽는 계산 프로퍼티
    var doubledStored: Int { storedNumber * 2 }

    // 3. @Observable 이 아닌 클래스
    let box = PlainBox()

    // 4. 그 안을 읽는 계산 프로퍼티
    var boxNumber: Int { box.number }

    func bumpStored() { storedNumber += 1 }
    func bumpBox() { box.number += 1 }
}
```

**두 화면으로 나눠서 봐야 한다.** 한 화면에 다 넣으면 결과가 섞여서 엉뚱한 결론이 나온다(이유는 바로 아래에 적는다).

```swift
// 화면 A - box 만 본다
struct BoxOnlyView: View {
    let viewModel: ObservationDemoViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("boxNumber: \(viewModel.boxNumber)")
            Button("box 값 올리기") { viewModel.bumpBox() }
        }
    }
}

// 화면 B - 둘 다 본다
struct BothView: View {
    let viewModel: ObservationDemoViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("storedNumber: \(viewModel.storedNumber)")
            Text("boxNumber: \(viewModel.boxNumber)")
            Button("stored 값 올리기") { viewModel.bumpStored() }
            Button("box 값 올리기") { viewModel.bumpBox() }
        }
    }
}
```

> **확인 예정**: 아래 표는 코드를 읽고 예상한 결과다. 실기기/시뮬레이터로 돌려보고 스크린샷을 붙일 것.

| 화면 | 누른 버튼 | 화면이 바뀌는가 |
|---|---|---|
| A | box 값 올리기 | 안 바뀐다 |
| B | stored 값 올리기 | 바뀐다 |
| B | box 값 올리기 | 안 바뀐다 |
| B | stored 올린 직후 | **box 값도 같이 최신으로 보인다** |

---

## 화면이 갱신되던 건 다른 이유였다

RunWay에서 이 문제를 처음 봤을 때, 나는 워치 항목이 갱신이 안 될 거라고 생각했다. 그런데 실제 화면에서는 갱신되고 있었다. 이유가 저 마지막 줄이다.

```swift
// TakeoffView
var checkItems: [(icon: String, name: String, value: String, ok: Bool)] {
    [
        ("wifi",       "GPS SIGNAL",  runViewModel.gpsSignalStatus.label, ...),
        ("applewatch", "APPLE WATCH", runViewModel.watchStatus.label,     ...),
        // 생략
    ]
}
```

이 배열은 저장된 값이 아니라 **읽을 때마다 처음부터 다시 만들어진다.** GPS 정확도는 추적되는 값이라 1초에 한 번씩 화면을 다시 그리게 만드는데, 그때 배열 전체가 새로 만들어지면서 **워치 항목도 덩달아 새로 계산된다.**

**추적이 되는 게 아니라, 옆에서 계속 화면을 흔들어주고 있었던 것이다.** 결과만 보면 똑같아서 구분이 안 된다.

이게 왜 위험하냐면, 두 값 사이에 아무 관계가 없기 때문이다. 나중에 이 화면에서 GPS를 안 켜게 바꾸거나, 워치 항목을 GPS 없는 다른 화면으로 옮기면 그때 조용히 멈춘다.

**화면이 갱신되는 걸 눈으로 확인했다고 해서 추적되고 있다는 뜻은 아니다.** 이 글을 쓰게 된 진짜 이유가 이거다.

---

## 그래서 어떻게 해야 하나

추적 안 되는 값을 추적되게 만들 방법은 없다. `WCSession`을 우리가 고칠 수 없으니까. 할 수 있는 건 **옮겨 적는 것**이다.

```swift
@Observable
final class RunViewModel {
    // 시스템이 알려주는 시점에 여기에 옮겨 적는다. 저장 프로퍼티라 추적된다.
    var isWatchSessionActivated = false
}

// 시스템이 활성화 완료를 알려주는 유일한 자리
nonisolated func session(_ session: WCSession, activationDidCompleteWith ...) {
    let vm = viewModel
    Task { @MainActor in vm?.isWatchSessionActivated = true }
}
```

**시스템이 알려주는 순간을 붙잡아서, 추적되는 저장 프로퍼티에 옮겨 담는다.** 그러면 화면은 그 저장 프로퍼티를 보고 따라온다.

정리하면 선택지는 셋이다.

1. **그 클래스를 `@Observable`로 만든다** - 내가 만든 클래스일 때만 가능
2. **알림을 받아서 저장 프로퍼티에 옮겨 적는다** - 시스템 값일 때 쓰는 방법
3. **애초에 안 바뀌는 값을 고른다** - RunWay가 실제로 택한 것

RunWay는 3번으로 갔다. `isReachable`은 워치 앱을 켜고 끌 때마다 바뀌는 값이라 계속 따라가야 했지만, `isPaired`는 화면 보는 동안 바뀔 일이 없어서 **한 번 읽으면 그게 맞는 답이다.** 따라갈 필요 자체를 없앤 것이다.

---

## 정리

| 물어봐야 할 것 | 답 |
|---|---|
| `@ObservationIgnored`가 붙었나 | **상관없다.** 계산 프로퍼티는 명단에 없다 |
| 계산 프로퍼티가 추적되나 | 그 자체로는 아니다. **재료를 따라간다** |
| 끝에 `@Observable` 저장 프로퍼티가 있나 | **이게 유일한 기준이다** |
| 화면이 실제로 갱신되던데 | 옆 값이 흔들어준 것일 수 있다. 따로 확인해야 한다 |

내가 처음에 물었던 "`@ObservationIgnored`가 안 붙었으니 받을 수 있는 것 아닌가"는 **붙어 있는 표시를 본 것**이었다. 봐야 했던 건 표시가 아니라 **그 값이 어디서 오는가**였다.
