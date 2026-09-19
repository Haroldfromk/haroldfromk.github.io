---
title: (Deep Dive) Sendable 클로저는 왜 actor 상태를 못 만지나 (2)
writer: Harold
date: 2026-09-10 00:00
categories: [Deep Dive]
tags: [Myself]
published: false
toc: true
toc_sticky: true
---

<!--
발행 전 체크리스트
- [ ] TODO를 실제로 돌려서 나온 값으로 다 바꿨는가
- [ ] 가설이 틀렸으면 틀렸다고 그대로 썼는가
- [ ] 남은 질문을 채웠는가
-->

---

## 시작하게 된 이유

RunWay와 GitExplorer 둘 다 만들면서 `AsyncStream`의 `onTermination` 클로저 안에서 actor/MainActor 상태를 직접 건드리려다 막힌 적이 있다. 그때마다 `Task { @MainActor in ... }`로 감싸서 넘어갔는데, "왜 직접 부르면 안 되고 Task로 감싸면 되는지"는 제대로 설명 못 한다.

---

## 문제 상황

GitExplorer Actor 미니프로젝트에서 이런 코드를 짰었다.

```swift
continuation.onTermination = { [weak self] _ in
    self?.stop()   // MainActor에 격리된 메서드
}
```

이렇게 직접 호출하면 에러가 났다.

```text
Call to main actor-isolated instance method 'stop()' in a synchronous nonisolated context
```

RunWay에서도 같은 패턴에서 비슷한 에러를 만났다.

```text
Actor-isolated property 'continuation' can not be mutated from a Sendable closure
```

둘 다 `Task { @MainActor in self?.stop() }` 또는 `Task { await ... }`로 감싸서 해결했다.

---

## 재현해보기

`ConcurrencyPlayground`에 GitExplorer의 `SimulatorTask` 패턴을 그대로 옮긴 데모를 만들었다. 전체 코드는 이렇다.

```swift
import SwiftUI

// GitExplorer Actor 미니프로젝트의 SimulatorTask 패턴을 재현한다.
// onTermination 클로저 안에서 MainActor 메서드를 직접 부르면 에러가 나는지,
// Task { @MainActor in } 로 감싸야 통과하는지 확인하는 것이 실험 포인트.
final class TickEmitter {
    private var task: Task<Void, Never>?

    func start() -> AsyncStream<Int> {
        AsyncStream { continuation in
            var tick = 0
            task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    tick += 1
                    continuation.yield(tick)
                }
            }
            continuation.onTermination = { [weak self] _ in
                // 실험: 아래 줄로 바꿔서 직접 호출하면 컴파일 에러가 나는지 확인
                // self?.stop()
                Task { @MainActor in
                    self?.stop()
                }
            }
        }
    }

    @MainActor
    func stop() {
        task?.cancel()
        task = nil
    }
}

@Observable
@MainActor
final class StreamTerminationViewModel {
    private(set) var log: [String] = []
    private(set) var isRunning = false
    private let emitter = TickEmitter()
    private var task: Task<Void, Never>?

    func start() {
        isRunning = true
        log.append("시작")
        task = Task {
            for await tick in emitter.start() {
                log.append("tick \(tick)")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
        log.append("중지 요청 (onTermination이 이어서 처리)")
    }
}

struct StreamTerminationView: View {
    @State private var viewModel = StreamTerminationViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("가설: onTermination 클로저 안에서 MainActor 메서드를 직접 부르면 에러가 나고, Task { @MainActor in } 로 감싸야 통과한다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(viewModel.isRunning ? "중지" : "시작") {
                if viewModel.isRunning {
                    viewModel.stop()
                } else {
                    viewModel.start()
                }
            }
            .buttonStyle(.bordered)

            List(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .navigationTitle("onTermination & Task 밴드에이드")
    }
}
```

`onTermination` 클로저 안에 직접 호출하는 줄(주석 처리됨)과 `Task { @MainActor in }`로 감싼 줄을 바꿔가며 컴파일 결과를 비교하도록 만들어뒀다.

<!-- TODO: 앱을 실제로 돌려서 나온 진단/로그를 그대로 붙여넣기 -->
`[TODO: 직접 호출했을 때의 컴파일 에러 원문]`

`[TODO: Task로 감쌌을 때 실제 실행 로그]`

---

## 왜 그런가

`onTermination`은 스트림이 어느 스레드에서든 종료될 수 있기 때문에 암묵적으로 `@Sendable` 클로저다. `@Sendable` 클로저는 "나는 어떤 격리 컨텍스트에서 실행될지 컴파일러가 보장할 수 없다"는 뜻이고, MainActor/actor가 보호하는 상태는 정확히 그 반대(정해진 컨텍스트에서만 접근 가능)를 요구한다. 그래서 `@Sendable` 클로저 안에서 격리된 멤버를 직접 만지면 그 보장이 깨진다.

`Task { @MainActor in ... }`로 감싸면, 클로저 자체는 여전히 아무 스레드에서나 실행되지만 그 안에서 만든 새 `Task`가 MainActor에 진입할 차례를 기다렸다가 안전하게 처리한다.

<!-- TODO: 재현 결과로 이 설명이 맞는지 검증 -->

---

## 조건 바꿔보기

- `Task { @MainActor in }` 없이 직접 호출 → 진단 원문 확인
- `Task { await ... }`(actor)와 `Task { @MainActor in }`(MainActor)를 각각 확인 - 둘이 같은 이유로 막히는지
- `onTermination`을 `@Sendable`이 아니게 만들 방법이 있는지 (아마 없음 - API 시그니처 자체가 그렇게 되어 있을 것)

---

## 정리

<!-- TODO -->

---

## 남은 질문

<!-- TODO -->
