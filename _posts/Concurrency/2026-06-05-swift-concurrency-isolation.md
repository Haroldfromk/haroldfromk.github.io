---
title: Swift Concurrency & 격리(Isolation) 핵심 개념 정리
writer: Harold
date: 2026-06-05 08:25 +0800
categories: [Concurrency]
tags: [Swift, Concurrency, Isolation, Actor, Sendable, MainActor, DataRace, Swift6]

toc: true
toc_sticky: true
---

## Swift Concurrency & 격리(Isolation) 핵심 개념 정리

> Matt Massicotte의 강연을 바탕으로 정리한 Swift Concurrency 가이드.  
> 단순한 문법 습득을 넘어, **왜** 이렇게 설계되었는지를 이해하는 것을 목표로 한다.

---

## 1. 왜 Swift Concurrency인가?

### 관습(Convention)에서 강제(Enforcement)로

기존 GCD 시절에는 "UI 업데이트는 메인 스레드에서 해야 한다"는 규칙이 개발자들 사이의 **관습**이었다. 관습은 망각하기 쉽고, 실수는 런타임 오류로 이어진다.

Swift Concurrency는 이 안전 규칙을 **타입 시스템**에 편입시켜 컴파일러가 데이터 레이스를 방지하도록 설계되었다.

> **핵심:** 데이터 레이스 방지는 이제 개발자의 몫이 아닌 컴파일러의 책임이다.

### 데이터 레이스는 생각보다 훨씬 위험하다

단순히 크래시를 유발하는 것이 아니다.

- **잠복성 오염:** 메모리를 조용히 오염시킨 후, 한참 뒤 엉뚱한 곳에서 터진다. 크래시 리포트는 원인이 아닌 **피해 지점**만 보여준다.
- **재현 불가:** 데이터 레이스는 수 시간 전에 발생한 오염이 나중에 설정 화면을 열 때 크래시를 일으키는 식으로 작동하기 때문에 결정적(Deterministic)인 재현과 디버깅이 거의 불가능하다.

### 격리(Isolation) — 하나의 추상화

스레드, 락(Lock), 큐(Queue) 같은 저수준 도구들을 **격리(Isolation)** 라는 단일 개념으로 추상화했다. 개발자는 "어떤 락을 쓸 것인가"를 고민하는 대신, **"이 데이터가 어떤 보호 영역에 속해 있는가"** 에 집중하면 된다.

### 🛠 시뮬레이션으로 확인하기 — 데이터 레이스 시뮬레이터

> **목적:** 동일한 공유 데이터에 여러 스레드가 동시에 접근할 때 발생하는 데이터 레이스 실증  
> 100개의 ATM이 동시에 같은 계좌에서 인출을 시도할 때, GCD 환경에서는 잔고가 오염되고 Swift 6에서는 컴파일러가 빌드 단계에서 원천 차단한다. 
> 실행할 때마다 오염 결과가 달라지는 것이 데이터 레이스의 비결정적 특성이다.

<iframe 
    src="/assets/demo/atm-concurrency-simulator.html" 
    width="100%" 
    height="780" 
    style="border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>

---

## 2. 격리의 두 가지 유형

| 구분 | 정적 격리 (Static Isolation) | 동적 격리 (Dynamic Isolation) |
|------|------------------------------|-------------------------------|
| 확인 시점 | 컴파일 타임 | 런타임 |
| 메커니즘 | 타입 시스템 / 컴파일러 추론 | 개발자의 명시적 보증 |
| 주요 도구 | `@MainActor`, `actor` | `assumeIsolated`, `nonisolated(unsafe)` |
| 주 사용 시점 | 일반적인 코드 작성 | 마이그레이션 과도기 |

### 정적 격리 예시

```swift
// @MainActor로 타입 전체를 메인 액터에 격리
@MainActor
class ViewModel: ObservableObject {
    var title: String = ""

    func updateTitle(_ newTitle: String) {
        // 컴파일러가 이 함수가 항상 메인에서 실행됨을 보장
        self.title = newTitle
    }
}
```

### 동적 격리 예시 (주의해서 사용할 것)

```swift
// assumeIsolated: "나는 지금 메인 액터 위에 있다"고 컴파일러에게 약속
// 약속이 틀리면 런타임 크래시 발생
MainActor.assumeIsolated {
    updateUI()
}

// nonisolated(unsafe): 격리 검사를 완전히 무시
// 마이그레이션 중 임시방편으로만 사용할 것
nonisolated(unsafe) var legacyCache: [String: Any] = [:]
```

> ⚠️ 동적 격리는 컴파일러의 보호를 받지 못한다. 마이그레이션 과도기의 임시 수단으로만 쓰고, 가능하면 정적 격리로 대체하라.

### 🛠 시뮬레이션으로 확인하기 — 정적 격리 vs 동적 격리 시뮬레이터

> **목적:** 동일한 위험 코드를 두 가지 방식으로 보호했을 때 컴파일러와 런타임이 어떻게 다르게 반응하는지 체감  
> 정적 격리: 컴파일러가 위반 코드를 빌드 단계에서 차단하고 올바른 수정을 강제한다.  
> 동적 격리: 컴파일러를 통과했지만 런타임에서 약속이 깨지는 순간 앱이 즉사한다.

<iframe 
    src="/assets/demo/static-vs-dynamic-isolation-final.html" 
    width="100%" 
    height="780" 
    style="border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>
---

## 3. 격리 추론(Inference) vs 격리 상속(Inheritance)

헷갈리기 쉬운 두 개념을 구분하는 것이 중요하다.

| 구분 | 격리 추론 (Inference) | 격리 상속 (Inheritance) |
|------|----------------------|------------------------|
| 언제 결정되나 | 컴파일 타임 (정적) | 런타임 실행 흐름 |
| 무엇에 관한 것인가 | 함수가 어떤 격리에 속하는가 | 동기 함수 호출 시 호출자의 격리가 이어지는가 |

```swift
@MainActor
class MyViewController: UIViewController {

    // updateLabel은 @MainActor를 명시하지 않았지만,
    // 클래스 선언을 보고 컴파일러가 "이건 메인 액터 소속"이라고 추론(Inference)
    func updateLabel() {
        label.text = "Updated"
    }

    func fetchData() async {
        let result = await networkCall()
        // await 이후에도 여전히 @MainActor 위에 있음
        // → updateLabel()은 호출자(fetchData)의 격리를 상속(Inheritance)
        updateLabel()
    }
}
```

### 🛠 시뮬레이션으로 확인하기 — 격리 추론 & 상속 시뮬레이터

> **목적:** 격리가 명시되지 않았을 때 컴파일러가 어떻게 안전성을 보장하는지 체감  
> 시나리오 1 (추론): `@MainActor` 클래스 선언 하나만으로 내부 함수 전체가 메인 격리로 자동 추론되는 과정을 확인한다.  
> 시나리오 2 (상속): `await` 이후 물리적 스레드가 바뀌어도 호출자의 격리 컨텍스트가 그대로 상속되어 복귀하는 흐름을 확인한다.

<iframe 
    src="/assets/demo/inference-vs-inheritance-final-fixed.html" 
    width="100%" 
    height="690" 
    style="border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>

---

## 4. 액터(Actor) — 격리의 런타임 구현체

액터는 격리를 실제로 구현하는 실체다. Matt Massicotte는 **네트워크 서비스 요청**에 비유한다.

> 액터와 통신하는 것 = 외부 서버에 요청을 보내는 것  
> 1. 데이터를 패키징(Encoding)  
> 2. 요청을 보내고 응답을 기다림(`await`)  
> 3. 결과를 해석(Decoding)

### 글로벌 액터 vs 커스텀 액터

```swift
// 글로벌 액터: 여러 타입이 공유하는 하나의 보호 영역
// MainActor가 대표적인 예
@MainActor
class ProfileViewModel { ... }

@MainActor
class SettingsViewModel { ... }
// 둘 다 같은 "메인 액터 버블" 안에 있으므로 서로 동기 호출 가능


// 커스텀 액터: 자신만의 독립적인 보호 영역 생성
// 아래 액터가 왜 필요한지 반드시 주석으로 설명할 것
/// GPS 데이터는 백그라운드 스레드에서 지속적으로 업데이트되므로
/// 메인 액터와 분리된 보호 영역이 필요하다.
actor GPSDataStore {
    private var locations: [CLLocation] = []

    func append(_ location: CLLocation) {
        locations.append(location)
    }

    func getAll() -> [CLLocation] {
        return locations
    }
}
```

### ⚠️ 액터의 전염성(Viral Nature) — 가장 중요한 경고

액터를 하나 도입하면 연쇄 반응이 시작된다.

```swift
actor DataStore {
    var records: [Record] = []  // Record가 Sendable이어야 함
}

// Record가 class라면 Sendable 채택이 필요
// → Record가 참조하는 모든 타입도 Sendable이어야 함
// → 프로젝트 전체에 Sendable 제약이 퍼져나감
struct Record: Sendable {
    let id: UUID
    let value: String  // String은 이미 Sendable
}
```

> **액터 도입 전 반드시 자문하라:**
> 1. 이것이 정말 액터여야 하는가?
> 2. `@MainActor`로 해결할 수 없는가?
> 3. 단순히 컴파일러 경고를 없애려고 만드는 건 아닌가?

### 🛠 시뮬레이션으로 확인하기 — 액터 직렬 큐 & 격리 전염성 시뮬레이터

> **목적:** 액터의 상호 배제 원리와 도입 시 발생하는 Sendable 파급 효과 체감  
> 시나리오 1: 여러 태스크가 동시에 액터에 접근할 때 순차 처리되는 흐름을 확인한다.  
> 시나리오 2: 격리 전염성은 Swift 5 → 6 마이그레이션 중 흔히 겪는 바로 그 상황이다. `DataStore` 하나를 `actor`로 바꾼 팀원의 커밋을 `git pull` 하는 순간, 내 코드는 단 한 줄도 건드리지 않았는데 `NetworkLayer`, `ViewModel`에 컴파일 에러가 연쇄 발생한다. 실제로 GitExplorer 프로젝트에서 `nonisolated` 키워드 하나를 추가한 순간 관련 파일 전체에 컴파일 에러가 터진 것이 바로 이 현상이다.

<iframe 
    src="/assets/demo/actor-queue-and-contagion-ultimate.html" 
    width="100%" 
    height="660" 
    style="border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>

---

## 5. Sendable — 격리 경계를 넘는 데이터의 조건

`Sendable`은 데이터가 한 격리 영역에서 다른 영역으로 **안전하게 전달될 수 있음**을 의미한다.

| 분류 | 특징 | 예시 |
|------|------|------|
| 내재적으로 안전 | 값 타입이거나 불변 → 보호 불필요 | `Int`, `String`, `struct`(값 타입만 포함) |
| 보호가 필요 | 참조 타입 + 가변 상태 → 격리 필요 | `class` (Non-Sendable) |

```swift
// ✅ 값 타입 struct는 자동으로 Sendable
struct RunSegment: Sendable {
    let distance: Double
    let duration: TimeInterval
}

// ✅ 불변 class는 명시적으로 Sendable 선언 가능
final class ImmutableConfig: Sendable {
    let maxSpeed: Double = 100.0
    // let만 사용 → 불변 → Sendable 안전
}

// ❌ 가변 class는 Sendable이 될 수 없음
class MutableState {  // Non-Sendable
    var count: Int = 0
    // var 존재 → 데이터 레이스 가능성 → 격리로 보호해야 함
}

// 격리 경계를 넘을 때 Sendable 위반 감지
actor MyActor {
    func process(_ state: MutableState) {  // ❌ 컴파일 에러
        // MutableState는 Non-Sendable이므로 액터로 전달 불가
    }

    func process(_ segment: RunSegment) {  // ✅ OK
        // RunSegment는 Sendable
    }
}
```

> **핵심 통찰:** 모든 데이터가 Sendable이라면 격리는 필요 없다. 격리가 존재하는 유일한 이유는 **Sendable하지 않은 데이터를 안전하게 보호하기 위해서**다.

---

## 6. sending 키워드 (Swift 6)

Swift 6에서 추가된 `sending`은 Sendable보다 유연한 전달 방식을 제공한다.

```swift
// sending: "이 값을 전달하는 시점에 호출자는 더 이상 접근하지 않겠다"는 약속
// Sendable을 채택하지 않아도 격리 경계를 넘길 수 있음
func process(data: sending MutableState) async {
    // data의 소유권이 이 함수로 이전됨
    // 호출자는 더 이상 data에 접근하지 않아야 함
}

// 실제 활용 예
actor Processor {
    func handle(_ item: sending LargeObject) {
        // LargeObject가 Sendable이 아니어도 sending이면 전달 가능
    }
}
```

---

## 7. 성능에 대한 오해 — "메인 스레드 회피"의 함정

많은 개발자가 성능을 위해 무조건 작업을 메인 스레드 밖으로 밀어내려 한다. 이는 종종 역효과다.

```swift
// ❌ 불필요한 백그라운드 전환 — 오히려 느릴 수 있음
func updateTitle(_ title: String) async {
    await Task.detached(priority: .background) {
        // 아주 간단한 문자열 처리...
        let processed = title.trimmingCharacters(in: .whitespaces)
        await MainActor.run {
            self.label.text = processed  // 다시 메인으로 hop
        }
    }.value
    // 컨텍스트 스위칭 비용 > 실제 작업 비용
}

// ✅ 메인에서 처리하는 것이 더 단순하고 빠를 수 있음
@MainActor
func updateTitle(_ title: String) {
    label.text = title.trimmingCharacters(in: .whitespaces)
}
```

### Swift Concurrency의 성능 장점

GCD와 달리 Swift Concurrency는 **협력적 멀티태스킹** 방식으로 액터 간 전환 시 컨텍스트 스위치를 최소화한다. 다만 이 장점은 무분별한 백그라운드 전환을 정당화하지 않는다.

> **자문 순서:**
> 1. 이 작업을 동시성 없이 처리할 수 있는가?
> 2. 메인 액터에서 처리할 수 있는가?
> 3. 그래도 안 된다면 → 커스텀 액터 고려

### 🛠 시뮬레이션으로 확인하기 — 스레드 호핑(Thread Hopping) 비용 시뮬레이터

> **목적:** 무분별한 백그라운드 태스크 분리가 유발하는 성능 저하 실증  
> A플랜에서 갤러리 이미지가 뒤죽박죽 순서로 뚝뚝 끊기며 로드되는 것이 보일 것이다. 이것이 스레드 순서가 보장되지 않는 호핑의 부작용이다. 
> B플랜은 동일한 연산을 메인 액터에서 직행하여 순식간에 순서대로 완료된다. 
> 단, 이 시뮬레이터는 극단적인 케이스를 과장한 것이므로 실제 성능 판단은 항상 Instruments로 측정 후 결정하라.

<iframe 
    src="/assets/demo/thread-hopping-gallery-simulator-v6.html" 
    width="100%" 
    height="780" 
    style="border: 1px solid #e2e8f0; border-radius: 16px; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.05);" 
    allow="autoplay; clipboard-write;" 
    loading="lazy">
</iframe>

---

## 8. Approachable Concurrency — 직관과 코드의 일치

Xcode의 **"Nonisolated non-sending by default"** 설정은 컴파일러의 동작을 개발자의 직관에 맞춘다.

```swift
@MainActor
class MyViewModel {

    // 개발자의 직관: "메인에서 호출했으니 이 함수도 메인에서 실행되겠지"
    // 기존: nonisolated 함수는 격리 없이 실행 → 직관과 다름
    // Approachable Concurrency: 호출자의 격리를 상속 → 직관과 일치

    func helperFunction() {
        // "Nonisolated non-sending by default" 설정 시
        // → 호출자(@MainActor)의 격리를 자동 상속
        // → 메인에서 안전하게 실행
    }
}
```

---

## 9. 실무 마이그레이션 전략

### 단계별 접근

1. **UI 레이어부터 시작** — 가장 이해하기 쉬운 `@MainActor` 영역부터 Swift 6 모드 적용
2. **모듈 단위로 진행** — 모노리스 전체를 한 번에 수정하지 말 것
3. **`MainActor by default` 신중히 도입** — 신규 프로젝트에는 편리하지만, 복잡한 프로젝트에서는 관리가 어려워질 수 있음

### 마이그레이션 중 임시 도구들

```swift
// 1. @preconcurrency — 레거시 모듈의 경고를 임시로 억제
@preconcurrency import LegacyFramework

// 2. nonisolated(unsafe) — 격리 검사를 무시 (임시방편)
nonisolated(unsafe) var globalCache: [String: Any] = [:]

// 3. @unchecked Sendable — 개발자가 직접 안전을 보증
// (실제로 안전함을 확인한 경우에만)
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: Any] = [:]

    func get(_ key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }
}
```

> ⚠️ 위 도구들은 **과도기적 수단**이다. 마이그레이션이 완료되면 제거하고 올바른 정적 격리로 대체하라.

---

## 10. 핵심 원칙 요약

### 이해하지 못하는 키워드는 사용하지 마라

`nonisolated`, `@unchecked Sendable`, `assumeIsolated` 등을 **컴파일러 경고를 없애기 위해** 무분별하게 사용하지 마라. 15분이라도 투자해서 그 의미를 파악하라.

```swift
// ❌ 경고 무시용 키워드 남발
nonisolated(unsafe) var x = 0     // 왜?
@unchecked Sendable                // 정말 안전한가?
MainActor.assumeIsolated { ... }  // 확실한가?

// ✅ 의도가 명확한 코드
@MainActor var x = 0  // 메인 액터에서만 접근
```

### 단순함을 유지하라

```
복잡한 커스텀 액터 < @MainActor < 동시성 없음
```

액터는 **최후의 수단**으로 사용할 때 가장 강력하다.

### 시니어의 역할

시니어 엔지니어는 팀 전체가 **잘못된 가설** — 예를 들어 "모든 작업은 백그라운드에서 처리해야 한다" — 위에 시스템을 설계하지 않도록 가이드해야 한다.

---

## 참고

- 원본 강연: Matt Massicotte — Swift Concurrency & Isolation
- Swift Evolution: SE-0302 (Sendable), SE-0306 (Actors), SE-0430 (sending)
- [Swift Concurrency 공식 문서](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
