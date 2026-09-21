---
title: (Deep Dive) nonisolated??
writer: Harold
date: 2026-09-09 00:00
categories: [Deep Dive]
tags: [Myself]
published: false
toc: true
toc_sticky: true
---

RunWay를 만들면서 `CLLocationManager` delegate를 `nonisolated`로 선언한 적이 있다. 당연히 백그라운드 스레드에서 호출될 거라 생각했는데, 실기기에서 확인해보니 아니었다. 그때는 일단 되니까 넘어갔는데, 왜 그런지는 제대로 파고들지 않았다.

Async/Await 시리즈랑 Concurrency 격리 정리글에서 actor, Sendable, MainActor 개념은 이미 짚었으니 여기서 다시 설명하지 않는다. 대신 그때 겪었던 상황을 최소한의 코드로 다시 만들어서, 진짜로 왜 그런 결과가 나왔는지 확인해본다.

---

## 재현해보기

CLLocationManager까지 그대로 가져올 필요는 없었다. 위치 권한이나 실기기 GPS 없이도, `nonisolated` 함수 하나를 서로 다른 곳에서 불러보면 같은 걸 확인할 수 있다. 외부 프레임워크가 임의의 스레드에서 delegate를 부르는 상황은 `DispatchQueue.global()`에서 직접 호출하는 걸로 흉내낸다.

전체 코드는 이렇다.

```swift
import SwiftUI

// CLLocationManager delegate처럼 외부 프레임워크가 임의의 스레드에서 부르는 상황을
// DispatchQueue.global()에서 직접 호출하는 것으로 흉내낸다.
nonisolated func describeCurrentThread() -> String {
    Thread.isMainThread ? "Main Thread" : "Background Thread: \(Thread.current)"
}

@Observable
@MainActor
final class NonisolatedThreadViewModel {
    private(set) var log: [String] = []

    func checkFromMainActor() {
        log.append("MainActor에서 직접 호출 → \(describeCurrentThread())")
    }

    func checkFromBackgroundQueue() {
        DispatchQueue.global().async { [weak self] in
            let result = describeCurrentThread()
            Task { @MainActor in
                self?.log.append("DispatchQueue.global에서 호출 → \(result)")
            }
        }
    }

    func clear() {
        log.removeAll()
    }
}

struct NonisolatedThreadView: View {
    @State private var viewModel = NonisolatedThreadViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("가설: nonisolated로 선언했으니 이 함수는 항상 백그라운드 스레드에서 실행될 것이다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("MainActor에서 호출", action: viewModel.checkFromMainActor)
                Button("백그라운드 큐에서 호출", action: viewModel.checkFromBackgroundQueue)
                Button("로그 지우기", action: viewModel.clear)
            }
            .buttonStyle(.bordered)

            List(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .navigationTitle("nonisolated vs Thread")
    }
}
```

같은 `describeCurrentThread()` 하나를 MainActor 버튼에서 직접 부르는 경우와, `DispatchQueue.global()`로 던져서 부르는 경우 두 가지로 관찰한다.

가설은 그때와 같다. `nonisolated`니까 이 함수는 항상 백그라운드 스레드에서 실행될 것이다.

<!-- TODO: 앱을 실제로 돌려서 나온 두 로그를 그대로 붙여넣기. 요약하거나 번역하지 말 것 -->
`[TODO: MainActor에서 호출했을 때 결과]`
`[TODO: DispatchQueue.global에서 호출했을 때 결과]`

---

## 왜 그런가

<!-- TODO: 재현 결과를 확인한 뒤 이 섹션을 마무리할 것. 결과가 다르면 아래 설명부터 다시 쓴다 -->

RunningProject를 만들 때 내렸던 결론은 이랬다. `nonisolated`와 실행 스레드는 서로 다른 질문에 대한 답이다. `nonisolated`가 답하는 건 "누가 이 값을 만져도 되는가"이고, 스레드는 "실제로 어느 실행 자원이 이 코드를 도는가"다. 즉 `nonisolated`는 스레드를 정하는 게 아니라 그냥 "어디서 불러도 격리 위반이 아니다"라고 허가만 하는 것이고, 실제 스레드는 호출하는 쪽이 결정한다. [Core Location 문서](https://developer.apple.com/documentation/corelocation/cllocationmanager){:target="_blank"}에도 delegate 콜백은 `CLLocationManager`가 생성된 스레드의 RunLoop에서 호출된다고 나와있는데, 이것도 결국 "호출하는 쪽(CoreLocation)이 스레드를 정한다"는 같은 원리다.

이번에 재현한 결과가 이 설명과 일치하는지 확인하고, 일치하면 다시 검증되는 거고, 다르면 그때 가서 원인을 새로 찾아야 한다.

---

## 조건 바꿔보기

여기서부터는 조건을 하나씩 바꿔가며 확인한다.

### nonisolated를 지우면?

<!-- 가설을 먼저 쓸 것 -->
가설:

결과:
```

```

관찰:

### [추가 조건 - 진행하며 채우기]

---

## 정리

<!-- nonisolated를 쓸 때 실행 스레드에 대해 뭘 가정해도 되고 안 되는지 -->

---

## 남은 질문

<!-- 반드시 채운다 -->
