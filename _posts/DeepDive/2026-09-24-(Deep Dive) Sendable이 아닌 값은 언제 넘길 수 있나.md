---
title: (Deep Dive) Sendable이 아닌 값은 언제 넘길 수 있나
writer: Harold
date: 2026-09-24 08:00
categories: [Deep Dive]
tags: [Myself]
published: true
toc: true
toc_sticky: true
---

---

## 시작하게 된 이유

[이전글](https://haroldfromk.github.io/posts/(Deep-Dive)-nonisolated%EB%8A%94-%EC%99%9C-%ED%95%84%EC%9A%94%ED%95%9C%EA%B0%80/){:target="_blank"}에서 `Task`에 Sendable이 아닌 값을 넘기는 실험을 했다. 함수 안에서 새로 만든 값은 넘어갔고, 넘긴 뒤에 또 쓰거나 파라미터로 받은 값은 `sending ... risks causing data races` 에러로 막혔다. 같은 타입인데 결과가 갈렸다.

그때는 결과만 적고 넘어갔는데, 이렇게 "타입이 아니라 값을 어떻게 썼는지"를 보고 판단하는 규칙에 이름이 있었다. region isolation이다. 처음 듣는 이름이라 정의부터 확인하고, 예시 코드로 직접 돌려봤다.

이번에도 AI와 계속 대화하면서 정리했다. 이전글처럼 AI가 하는 말을 그대로 받아 적지 않고, 애매하면 다시 묻고, 공식 문서와 대조하고, 직접 빌드해서 확인하는 식으로 진행했다. 그러다 보니 정정할 일이 계속 생겼다. 이번 글을 준비하다가 이전글에 "`Task`의 클로저는 `@Sendable`"이라고 적은 게 틀렸다는 걸 알게 돼서 `sending`으로 고쳤다. AI가 "`: Sendable`을 직접 적어두면 `public`을 붙여도 선언한 자리에서 에러가 난다"고 설명한 것도 빌드해보니 절반만 맞았다. 반대로 내가 `@unchecked`와 `where`의 순서를 거꾸로 이해한 것도 실험으로 바로잡았다.

글의 흐름도 대화하면서 많이 바뀌었다. 공장과 브랜드 로고 비유를 떠올리고 "같은 제품이면 여러 브랜드에 납품할 수 있지 않나", "로고가 한 번 찍히면 거절되나" 같은 질문을 이어가다 보니, 처음에 계획한 정의와 예시보다 한 단계 더 들어가게 됐다. 이번엔 AI가 꼬리질문 후보를 따로 적어두게 하고, 내가 먼저 질문을 떠올려본 다음 마지막에 비교해서 필요한 것만 추가했다.

---

## 1. region isolation???

[SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md){:target="_blank"}("Region based Isolation", Swift 6.0에서 구현)에서 생긴 규칙이다.

원래 규칙은 단순했다. Sendable이 아닌 값은 격리 경계(actor나 `Task` 사이)를 아예 못 넘는다. SE-0414는 이게 너무 빡빡하다고 지적한다. 제안서에 나온 예시가 이렇다.

```swift
// Not Sendable
class Client {
  init(name: String, initialBalance: Double) { ... }
}

actor ClientStore {
  var clients: [Client] = []

  static let shared = ClientStore()

  func addClient(_ c: Client) {
    clients.append(c)
  }
}

func openNewAccount(name: String, initialBalance: Double) async {
  let client = Client(name: name, initialBalance: initialBalance)
  await ClientStore.shared.addClient(client) // Error! 'Client' is non-`Sendable`!
}
```

`client`는 방금 만들었고, actor에 넘긴 뒤로는 아무도 안 쓴다. 누가 동시에 건드릴 방법이 없으니 안전한 코드인데, 예전 규칙으로는 `Client`가 Sendable이 아니라는 이유만으로 막혔다.

그래서 SE-0414는 타입만 보지 않고 값의 흐름을 보자고 한다. 그때 쓰는 개념이 isolation region이다.

> An isolation region is a set of values that can only ever be referenced through other values within that set.

isolation region은 "그 안의 값들끼리만 서로 가리킬 수 있는 값들의 묶음"이라는 뜻이다. 제안서는 두 값이 같은 region에 있는 조건을 두 가지로 정의하는데, 풀어 쓰면 둘 중 하나다.

- 두 변수가 같은 인스턴스를 가리킬 수 있다
- 한쪽의 프로퍼티를 따라가다 보면 다른 쪽에 닿을 수 있다

즉 region은 "서로 이어져 있어서, 하나를 건드리면 다른 쪽에도 영향이 갈 수 있는 값들의 묶음"이다. 컴파일러는 Sendable이 아닌 값을 넘길 때 이 묶음을 통째로 넘기는 걸로 보고, 넘긴 뒤에 그 묶음에 속한 값을 원래 쪽에서 또 쓰면 막는다. 반대로 묶음이 다르면 서로 영향을 줄 수 없으니 따로따로 써도 된다.

SE-0414는 region을 "어디 소속이냐"에 따라 네 가지로 나누는데, 이 글에 나오는 건 세 가지다.

- disconnected region: 아직 어디에도 소속되지 않은 region. 다른 곳으로 넘길 수 있다
- actor-isolated region: 어떤 actor(MainActor 포함)에 소속된 region. 다른 곳으로 못 넘긴다
- task-isolated region: 지금 실행 중인 함수, 즉 이 함수를 부른 쪽에 소속된 region. 파라미터가 여기 속하고, 역시 다른 곳으로 못 넘긴다

공장으로 비유하면 이해가 쉬웠다. 같은 설계로 찍어낸 제품이라도, 공장에서 갓 찍어낸 제품은 아직 어느 브랜드 로고도 없어서 어느 매장에든 납품할 수 있다. 한 개는 A 브랜드에, 다른 한 개는 B 브랜드에 납품하는 식이다. 대신 납품하는 순간 그 브랜드 로고가 찍히고, 그 뒤로는 다른 곳에 못 간다.

여기서 제품 설계가 타입, 제품 한 개가 값, 브랜드가 소속(actor, MainActor, 부른 쪽 함수)이다. 위 세 가지 region에 대 보면, 로고 없는 제품이 disconnected, 매장 로고가 찍힌 제품이 actor-isolated, 부른 쪽 로고가 찍힌 제품이 task-isolated다. Sendable 검사가 제품 설계를 보고 판단했다면, region isolation은 제품 한 개 한 개에 로고가 있는지를 본다.

---

## 2. 예시 코드로 확인하기

SE-0414의 `Client` 예제를 직접 빌드할 수 있게 만들어서 경우를 나눠 돌려봤다. Swift 6 모드, Swift 6.3.3이다.

```swift
// Sendable 아님
final class Client {
    let name: String
    var balance: Double
    var friend: Client?

    init(name: String, balance: Double) {
        self.name = name
        self.balance = balance
    }

    func log() { print("\(name): \(balance)") }
}

actor ClientStore {
    var clients: [Client] = []

    func addClient(_ c: Client) {
        clients.append(c)
    }
}
```

아래 예시 함수들은 Playground에서 돌리듯 파일 맨 바깥에 바로 적었다. `Client` 클래스 안도, `ClientStore` actor 안도 아니다. actor 안의 코드는 `addClient` 하나뿐이고, 아래 함수들은 전부 actor 밖에서 `Client`를 만들거나 받아서 `await store.addClient(...)`로 actor 안에 넘기는 쪽이다. 검사는 이 경계를 넘는 줄에서 일어난다.

실제 앱이라면 이 함수들은 보통 뷰모델 같은 클래스의 메서드로 들어간다. 그래서 같은 함수들을 `AccountViewModel`의 메서드로 옮겨서도 돌려봤다.

```swift
@MainActor   // 붙인 경우와 안 붙인 경우 둘 다 확인
final class AccountViewModel {
    let store = ClientStore()

    func openNewAccount() async {
        let client = Client(name: "John", balance: 0)
        await store.addClient(client)
    }

    // 생략
}
```

평범한 클래스든 `@MainActor` 클래스든, 아래의 새로 만든 값, 넘긴 뒤 또 쓰기, 이어진 두 값, 파라미터 경우의 통과와 에러는 전역 함수로 돌렸을 때와 똑같았다. 달라진 건 note 문구뿐이다. `@MainActor` 클래스에서는 값이 원래 있던 쪽을 `nonisolated`나 `task-isolated` 대신 `main actor-isolated`라고 알려준다.

그래서 예시는 가장 단순하게 전역 함수로 적었다. 참고로 이 글의 실험은 전부 Xcode의 Default Actor Isolation 같은 빌드 설정을 바꾸지 않은 기본 상태에서 돌렸다. 내 프로젝트처럼 기본 격리가 MainActor인 경우는 결과가 달라서 이 섹션 끝에서 따로 봤다.

---

### 새로 만든 값은 넘길 수 있다

```swift
func openNewAccount(store: ClientStore) async {    // actor 밖의 함수
    let client = Client(name: "John", balance: 0)   // actor 밖에서 새로 만든 값
    await store.addClient(client)                   // 여기서 actor 안으로 넘김
}
```

에러 없이 통과했다. `client`는 이 함수 안에서 새로 만들었으니 다른 누구와도 이어져 있지 않다. 앞에서 본 disconnected region, 공장 비유로는 갓 찍어낸 로고 없는 제품이다. 이런 값은 통째로 actor에 넘겨도 안전하다.

---

### 넘긴 뒤에 또 쓰면 막힌다

```swift
func openNewAccountThenLog(store: ClientStore) async {
    let client = Client(name: "John", balance: 0)
    await store.addClient(client)
    client.log()   // 넘긴 뒤에 또 씀
}
```

```text
error: sending 'client' risks causing data races [#SendingRisksDataRace]
note: sending 'client' to actor-isolated instance method 'addClient' risks causing data races between actor-isolated and local nonisolated uses
note: access can happen concurrently
```

`client`는 이미 actor 쪽으로 넘어갔다. 그런데 원래 함수에서 또 쓰면, actor 안에서 `client`를 쓰는 코드와 동시에 실행될 수 있다. 에러가 `addClient` 줄에 나고, 두 번째 note가 `client.log()` 줄을 가리킨다.

---

### 같은 타입이라도 값마다 갈 곳이 다르다

공장 비유대로라면, 같은 `Client` 타입이라도 한 개는 이 actor에, 다른 한 개는 저 actor에 갈 수 있어야 한다. `ClientStore`를 두 개 만들어서 확인해봤다.

```swift
func openAtTwoStores(storeA: ClientStore, storeB: ClientStore) async {
    let john = Client(name: "John", balance: 0)
    let joanna = Client(name: "Joanna", balance: 0)
    await storeA.addClient(john)     // john은 A로
    await storeB.addClient(joanna)   // joanna는 B로
}
```

통과했다. `john`과 `joanna`는 같은 타입이지만 각자 로고 없는 제품이라 서로 다른 actor로 갈 수 있다.

그럼 같은 한 개를 두 곳에 납품하면 어떨까.

```swift
func openSameAtTwoStores(storeA: ClientStore, storeB: ClientStore) async {
    let john = Client(name: "John", balance: 0)
    await storeA.addClient(john)
    await storeB.addClient(john)     // 같은 john을 B에도
}
```

```text
error: sending 'john' risks causing data races [#SendingRisksDataRace]
note: sending 'john' to actor-isolated instance method 'addClient' risks causing data races between actor-isolated and local nonisolated uses
note: access can happen concurrently
```

막혔다. `storeA`에 넘기는 순간 `john`은 A 소속이 됐다. 그 뒤에 B에 또 넘기면 A와 B가 같은 `john`을 동시에 만질 수 있다. 에러는 `storeA`에 넘기는 줄에 나고, note가 `storeB` 줄을 가리킨다. 앞의 "넘긴 뒤에 또 쓰면 막힌다"와 같은 이유다.

---

### 서로 이어진 값은 같이 움직인다

상관없는 두 값을 차례로 넘기면 통과한다.

```swift
func openTwoAccounts(store: ClientStore) async {
    let john = Client(name: "John", balance: 0)
    let joanna = Client(name: "Joanna", balance: 0)
    await store.addClient(john)
    await store.addClient(joanna)
}
```

`john`과 `joanna`는 서로를 가리키지 않으니 다른 region이다. `john`을 넘긴 뒤에 `joanna`를 써도 `john`에는 영향이 없다.

그런데 한 줄만 추가해서 `john`이 `joanna`를 가리키게 만들면 막힌다.

```swift
func openFriends(store: ClientStore) async {
    let john = Client(name: "John", balance: 0)
    let joanna = Client(name: "Joanna", balance: 0)
    john.friend = joanna   // 이제 john을 따라가면 joanna에 닿는다
    await store.addClient(john)
    await store.addClient(joanna)
}
```

```text
error: sending 'john' risks causing data races [#SendingRisksDataRace]
note: sending 'john' to actor-isolated instance method 'addClient' risks causing data races between actor-isolated and local nonisolated uses
note: access can happen concurrently
```

`john.friend = joanna` 이후로 둘은 같은 region이다. `john`을 넘기는 순간 `joanna`도 같이 넘어간 셈이라, 그 뒤에 `joanna`를 쓰는 게 문제가 된다. 에러는 `john`을 넘기는 줄에 나고, note가 다음 줄의 `joanna`를 가리킨다.

---

### 컴파일러가 놓치는 경우도 있다

"이어진 값은 같이 움직인다"를 확인하다가 이상한 경우를 하나 발견했다. 넘기기 전에 다른 곳에 참조를 남겨두고, 넘긴 뒤에 그 참조로 값을 바꿔봤다. 참조를 어디에 남기느냐만 바꿨다.

```swift
final class Config {                 // Sendable 아님
    var timeout = 0
}

actor Loader {
    private var config: Config?
    func apply(_ c: Config) { config = c }
}

func passShared(loader: Loader) async {
    let shared = Config()
    let box = [shared]               // 여기를 바꿔가며 빌드
    await loader.apply(shared)
    box[0].timeout = 1               // 넘긴 뒤에 남겨둔 참조로 바꿈
}
```

| 참조를 남긴 곳 | 결과 |
|---|---|
| 배열 리터럴 `let box = [shared]` | <span style="color:#2e9e4f">통과 (컴파일러가 놓침)</span> |
| 빈 배열에 `append(shared)` | <span style="color:#e5534b">`sending` 에러</span> |
| 튜플 `let pair = (shared, 1)` | <span style="color:#e5534b">`sending` 에러</span> |
| 옵셔널 `let opt: Config? = shared` | <span style="color:#e5534b">`sending` 에러</span> |
| 다른 클래스의 프로퍼티 `holder.c = shared` | <span style="color:#e5534b">`sending` 에러</span> |

배열 리터럴로 담았을 때만 통과했다. 나머지는 전부 "넘긴 뒤에 또 쓴다"로 막혔는데, 배열 리터럴은 `shared`와 `box`가 이어져 있다는 걸 컴파일러가 놓친 것 같다.

정말 위험한 코드인지 확인하려고, actor 안에서 10만 번, 밖에서 `box[0]`으로 10만 번 같은 값을 동시에 올려봤다.

```text
예상 200000, 실제 197821
예상 200000, 실제 198266
예상 200000, 실제 197171
예상 200000, 실제 199707
예상 200000, 실제 198982
```

빌드는 경고 하나 없이 통과했는데, 실행하면 다섯 번 모두 값이 깨졌다. Swift 저장소의 region isolation 관련 이슈를 찾아봤지만 같은 사례는 찾지 못했다. Swift 6.3.3 기준이고, 알려진 버그인지는 아직 모른다. region 검사도 컴파일러가 하는 일이라 빈틈이 있을 수 있다는 정도로 기억해두려 한다.

---

### 파라미터로 받은 값은 못 넘긴다

```swift
func addExisting(store: ClientStore, client: Client) async {
    await store.addClient(client)
}
```

```text
error: sending 'client' risks causing data races [#SendingRisksDataRace]
note: sending task-isolated 'client' to actor-isolated instance method 'addClient' risks causing data races between actor-isolated and task-isolated uses
```

이 함수 안에서는 넘긴 뒤에 `client`를 안 쓰는데도 막혔다. note에 이유가 나온다. `client`는 "task-isolated", 즉 이 함수를 부른 쪽과 이어져 있는 값이다. 이 함수를 부른 쪽이 `client`를 계속 들고 있을 수 있으니, 이 함수가 마음대로 actor에 넘길 수 없다.

이전글에서 `Task`에 파라미터로 받은 값을 넘기면 막혔던 것도 같은 이유다.

---

### 파라미터에 sending을 붙이면

그럼 파라미터로 받은 값을 actor에 넘기고 싶으면 어떻게 해야 할까. 이전글에서 본 `Task.init`의 `sending`을 파라미터에 직접 붙일 수 있다. [SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md){:target="_blank"}("`sending` parameter and result values", Swift 6.0에서 구현)에서 생긴 표시다.

> A function parameter or result that is annotated with `sending` is required to be disconnected at the function boundary and thus possesses the capability of being safely sent across an isolation domain or merged into an actor-isolated region in the function's body or the function's caller respectively.

`sending`이 붙은 파라미터나 반환값은 함수 경계에서 disconnected여야 하고, 그래서 다른 격리 영역으로 안전하게 보낼 수 있다는 뜻이다. 공장 비유로 하면 "로고 없는 제품만 받겠다"고 미리 적어두는 것이다.

```swift
func addExisting(store: ClientStore, client: sending Client) async {
    await store.addClient(client)
}
```

이 함수는 통과했다. 대신 검사가 부르는 쪽으로 옮겨갔다.

```swift
// 1) 새로 만들어서 넘김
let client = Client(name: "John", balance: 0)
await addExisting(store: store, client: client)

// 2) 새로 만들어서 넘기고, 또 씀
let client = Client(name: "John", balance: 0)
await addExisting(store: store, client: client)
client.log()

// 3) 부르는 쪽도 파라미터로 받은 값을 넘김
func caller(store: ClientStore, client: Client) async {
    await addExisting(store: store, client: client)
}
```

| 부르는 쪽 | 결과 |
|---|---|
| 1) 새로 만들어서 넘김 | <span style="color:#2e9e4f">통과</span> |
| 2) 넘긴 뒤 또 씀 | <span style="color:#e5534b">에러: `'client' used after being passed as a 'sending' parameter`</span> |
| 3) 부르는 쪽도 파라미터로 받은 값 | <span style="color:#e5534b">에러: `task-isolated 'client' is passed as a 'sending' parameter`</span> |

`sending`을 붙인다고 검사가 사라지는 게 아니다. "로고 없는 값만 받겠다"는 조건을 함수 선언에 드러내서, 그 조건을 지켰는지를 부르는 쪽에서 확인하게 만드는 것이다. 3번처럼 부르는 쪽도 파라미터로 받은 값이라면, 그 위로 계속 `sending`을 붙여 올라가야 한다.

---

### 한 번 소속되면 풀리지 않는다

파라미터는 처음부터 부른 쪽 소속이었다. 그럼 새로 만든 값이 중간에 어딘가에 소속되면 어떻게 될까. 실제 앱에서 흔한 모양으로, `@MainActor` 뷰모델의 프로퍼티에 한 번 담았다가 actor에 넘겨봤다.

```swift
@MainActor
final class AccountViewModel {
    let store = ClientStore()
    var recent: Client?

    func openAndRemember() async {
        let client = Client(name: "John", balance: 0)
        recent = client                  // MainActor 프로퍼티에 한 번 담음
        await store.addClient(client)
    }
}
```

```text
error: sending 'client' risks causing data races [#SendingRisksDataRace]
note: sending main actor-isolated 'client' to actor-isolated instance method 'addClient' risks causing data races between actor-isolated and main actor-isolated uses
```

막혔다. note를 보면 `client`가 "main actor-isolated"라고 나온다. 방금 만든 값이었는데, MainActor 소속인 `recent`에 담기는 순간 MainActor 소속이 된 것이다.

그럼 담았다가 바로 비우면 풀릴까 싶어서 `recent = nil`을 한 줄 넣어봤다.

```swift
    // 위와 같은 AccountViewModel 안의 메서드
    func openAndForget() async {
        let client = Client(name: "John", balance: 0)
        recent = client
        recent = nil                     // 바로 비움
        await store.addClient(client)
    }
```

똑같은 에러가 났다. 한 번 소속된 값은 비워도 풀리지 않는다. SE-0414에도 actor 소속이 된 값을 다시 떼어내는 기능은 이 제안의 범위가 아니라고 적혀있다.

> An operation to disconnect a value from an actor region in order to transfer it to another isolation domain is out of the scope of this proposal.

공장 비유로 하면, 로고는 한 번 찍히면 지워지지 않는다.

---

### 소속 있는 값이 섞이면 세트 전체가 그 소속이 된다

"서로 이어진 값은 같이 움직인다"에서는 방금 만든 값끼리 이었다. 그럼 방금 만든 값과 소속 있는 값을 한 세트로 묶으면 어떻게 될까. 세트로 담을 `Holder` 클래스와, 세트째로 받는 `addHolder`를 하나 추가해서 확인했다.

```swift
final class Holder {             // Sendable 아님
    var client: Client?
}

actor ClientStore {
    // 생략
    func addHolder(_ h: Holder) {
        if let c = h.client { clients.append(c) }
    }
}
```

둘 다 방금 만든 값이면 세트째로 넘어간다.

```swift
func openWithHolder(store: ClientStore) async {
    let holder = Holder()
    holder.client = Client(name: "John", balance: 0)
    await store.addHolder(holder)
}
```

통과했다. 그런데 `holder`는 방금 만들었어도, 안에 파라미터로 받은 `client`를 담으면 막힌다.

```swift
func openWithExisting(store: ClientStore, client: Client) async {
    let holder = Holder()             // 방금 만든 값
    holder.client = client            // 부른 쪽 소속인 값을 담음
    await store.addHolder(holder)
}
```

```text
error: sending 'holder' risks causing data races [#SendingRisksDataRace]
note: sending task-isolated 'holder' to actor-isolated instance method 'addHolder' risks causing data races between actor-isolated and task-isolated uses
```

note에 `holder`가 "task-isolated"라고 나온다. 방금 만든 `holder`였는데, 부른 쪽 소속인 `client`와 이어지는 순간 `holder`까지 부른 쪽 소속이 됐다. `@MainActor` 프로퍼티에 있던 값을 담아도 마찬가지로 `holder`가 "main actor-isolated"가 되면서 막혔다.

로고 없는 제품끼리 세트로 묶는 건 괜찮다. 하지만 로고 있는 제품이 하나라도 섞이면, 세트 전체에 그 로고가 찍힌다.

---

### 기본 격리가 MainActor인 프로젝트에서는

위 실험들은 전부 빌드 설정을 바꾸지 않은 기본 상태였다. 그런데 RunWay와 GitExplorer처럼 Xcode의 Default Actor Isolation이 MainActor인 프로젝트에서 같은 코드를 빌드하면 결과가 다르다. `-default-isolation MainActor`로 빌드해봤다.

| 경우 | 기본 설정 | 기본 격리 MainActor |
|---|---|---|
| 새로 만든 값 | <span style="color:#2e9e4f">통과</span> | <span style="color:#2e9e4f">통과</span> |
| 넘긴 뒤 또 씀 | <span style="color:#e5534b">`sending` 에러</span> | <span style="color:#2e9e4f">통과</span> |
| 이어진 두 값 | <span style="color:#e5534b">`sending` 에러</span> | <span style="color:#2e9e4f">통과</span> |
| 파라미터로 받은 값 | <span style="color:#e5534b">`sending` 에러</span> | <span style="color:#2e9e4f">통과</span> |

기본 격리가 MainActor면 에러가 전부 사라졌다. 아무것도 안 붙인 `Client` 클래스가 이 설정 때문에 `@MainActor` 클래스가 되고, `@MainActor` 클래스는 원래 Sendable이다. Sendable이면 region을 따질 필요가 없으니 검사 자체가 일어나지 않는다.

`Client`를 `nonisolated final class Client`로 선언해서 기본 격리에서 빼면, 위 표의 에러가 그대로 다시 났다.

그러니 내 프로젝트에서 이 글의 예시를 따라 하면 에러가 안 날 수 있다. 에러가 안 나는 건 region 규칙이 없어져서가 아니라, 넘기는 값이 애초에 MainActor 소속이라 Sendable이었기 때문이다.

---

### 정리하면

| 경우 | 결과 | 비고 |
|---|---|---|
| 새로 만들고, 넘긴 뒤 다시 안 씀 | <span style="color:#2e9e4f">통과</span> | 상관없는 두 값을 차례로 넘기거나, 서로 다른 actor에 하나씩 넘겨도 같다 |
| 새로 만들었지만, 넘긴 뒤 또 씀 | <span style="color:#e5534b">`sending` 에러</span> | 이미 넘어간 값을 원래 쪽에서 또 건드린다. 같은 값을 다른 actor에 또 넘기는 것도 여기 해당한다 |
| 이어진 두 값 중 하나를 넘기고 다른 하나를 씀 | <span style="color:#e5534b">`sending` 에러</span> | 같은 region이라 하나를 넘기면 둘 다 넘어간 셈이다 |
| 파라미터로 받은 값을 넘김 | <span style="color:#e5534b">`sending` 에러</span> | 부른 쪽 소속(task-isolated)이라, 부른 쪽이 아직 그 값을 들고 있을 수 있다 |
| `@MainActor` 프로퍼티에 한 번 담았던 값을 넘김 | <span style="color:#e5534b">`sending` 에러</span> | MainActor 소속이 된다. `nil`로 비워도 풀리지 않는다 |
| 소속 있는 값을 새 값과 세트로 묶어서 넘김 | <span style="color:#e5534b">`sending` 에러</span> | 세트 전체가 그 소속이 된다 |
| 파라미터에 `sending`을 붙임 | <span style="color:#2e9e4f">통과</span> | 대신 부르는 쪽에서 "로고 없는 값"을 넘겼는지 검사한다 |
| 배열 리터럴로 참조를 남기고 넘김 | <span style="color:#2e9e4f">빌드 통과</span>, <span style="color:#e5534b">실행하면 값이 깨짐</span> | 컴파일러가 이어져 있다는 걸 놓쳤다 (Swift 6.3.3) |
| 기본 격리가 MainActor인 프로젝트 | <span style="color:#2e9e4f">전부 통과</span> | 값이 MainActor 소속이라 Sendable이다. region 검사 자체가 안 일어난다 |

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-Sendable이-아닌-값은-언제-넘길-수-있나/sendablebox.png)

Sendable 검사는 "이 타입이 넘어가도 안전한가"를 봤다. region isolation은 거기서 한 걸음 더 들어가서, 타입이 안전하지 않아도 값 하나하나를 본다. "이 값이 아직 어디에도 소속되지 않았고, 넘긴 뒤에 원래 쪽에서 더 이상 건드리지 않는가"다. 둘 중 하나라도 아니면 빌드할 때 막힌다.

---

## 3. actor 안의 값을 밖으로 꺼낼 때

앞의 "예시 코드로 확인하기"는 actor 밖에서 만든 값을 actor 안으로 넘기는 방향이었다. 반대로 actor 안에 있는 값을 밖으로 꺼내는 건 어떨까. RunWay를 만들 때 실제로 이 방향에서 막힌 적이 있다.

---

### RunWay에서 막혔던 코드

[이전글](https://haroldfromk.github.io/posts/RunningProject-(11)/){:target="_blank"}에서 러닝 상태(`FlightPhase`)를 뷰모델로 실시간 전달하려고, `RunningCenter` actor 안에 Combine의 `PassthroughSubject`를 두고 밖에서 구독하려 했다. 같은 모양으로 최소 코드를 만들었다.

```swift
import Combine

enum FlightPhase: Sendable { case preflight, takeoff, cruise }

actor RunningCenter {
    var phasePublisher = PassthroughSubject<FlightPhase, Never>()
}

@MainActor
final class RunningViewModel {
    let runningCenter = RunningCenter()
    var currentPhase: FlightPhase = .preflight
    var cancellables = Set<AnyCancellable>()

    func bind() async {
        let publisher = await runningCenter.phasePublisher   // actor 안의 값을 밖으로 꺼냄
        publisher
            .sink { [weak self] phase in self?.currentPhase = phase }
            .store(in: &cancellables)
    }
}
```

```text
error: non-Sendable type 'PassthroughSubject<FlightPhase, Never>' of property 'phasePublisher' cannot exit actor-isolated context
```

RunWay 때와 같은 에러다. `var` 대신 `let`으로 바꿔도 똑같이 막혔다. `let`은 프로퍼티가 다른 인스턴스로 바뀌지 않는다는 뜻일 뿐, 참조 타입이라 꺼낸 쪽과 actor 안이 같은 인스턴스를 가리키는 건 그대로다.

그때는 "`PassthroughSubject`가 Sendable이 아니라서"라고 정리하고 넘어갔다. 틀린 말은 아닌데, region으로 보면 한 단계 더 설명이 된다.

---

### actor 안의 값은 actor 소속이다

앞에서 본 region 종류 중 actor-isolated region이 바로 이 경우다. SE-0414는 이렇게 적고 있다.

> Since the region is tied to an actor's isolation domain, the values of the region can *never* be transferred into another isolation domain since that would cause the non-`Sendable` value to be used by code both inside and outside the actor's isolation domain allowing for races

actor 소속 region에 있는 값은 절대 다른 곳으로 넘어갈 수 없다는 뜻이다. 넘어가면 actor 안의 코드와 밖의 코드가 같은 값을 동시에 쓸 수 있기 때문이다. `phasePublisher`는 actor의 프로퍼티라 처음부터 actor 소속이다. 그러니 `await`로 꺼내려는 순간 막힌다.

공장 비유로 하면, 이미 A 매장 진열대에 올라가 A 로고가 찍힌 제품을 매장 밖으로 들고 나오려는 것이다. 앞의 "한 번 소속되면 풀리지 않는다"와 같은 이야기다.

---

### Combine이 아니어도 막힌다

Combine만의 문제인지 궁금해서, `PassthroughSubject` 대신 평범한 클래스로 바꿔봤다.

```swift
final class PhaseBox {               // Sendable 아닌 평범한 클래스
    var phase: FlightPhase = .preflight
}

actor RunningCenter {
    let phaseBox = PhaseBox()        // Combine 아님
}
```

```text
error: non-Sendable type 'PhaseBox' of property 'phaseBox' cannot exit actor-isolated context
```

똑같이 막혔다. Combine이라서 생긴 문제가 아니라, Sendable이 아닌 값이 actor 소속이라서 생긴 문제다.

---

### AsyncStream은 왜 됐나

RunWay에서는 `PassthroughSubject` 대신 `AsyncStream`으로 바꿔서 해결했다. 같은 모양으로 만들어봤다.

```swift
actor RunningCenter {
    var phaseContinuation: AsyncStream<FlightPhase>.Continuation?

    func streamPhaseData() -> AsyncStream<FlightPhase> {
        AsyncStream<FlightPhase> { continuation in
            self.phaseContinuation = continuation
        }
    }
}

// RunningViewModel 안
func bind() async {
    for await phase in await runningCenter.streamPhaseData() {
        currentPhase = phase
    }
}
```

에러 없이 통과했다. 이유는 `AsyncStream` 선언에 있다. 현재 SDK의 Concurrency 모듈에 이렇게 적혀있다.

```swift
extension AsyncStream : @unchecked Sendable where Element : Sendable
```

`AsyncStream`은 흘려보내는 값(`Element`)이 Sendable일 때만 Sendable이다. 선언에 붙은 `@unchecked`는 아래에서 따로 본다. `FlightPhase`는 Sendable인 enum이라 `AsyncStream<FlightPhase>`도 Sendable이 되고, Sendable인 값은 region과 상관없이 actor 밖으로 나갈 수 있다.

정말 이 조건 때문인지, 흘려보내는 값을 Sendable이 아닌 `PhaseBox`로 바꿔서 확인했다.

```swift
actor RunningCenter {
    var continuation: AsyncStream<PhaseBox>.Continuation?

    func streamBoxes() -> AsyncStream<PhaseBox> {   // 흘려보내는 값이 Sendable 아님
        AsyncStream<PhaseBox> { continuation in
            self.continuation = continuation
        }
    }
}
```

```text
error: non-Sendable 'AsyncStream<PhaseBox>'-typed result can not be returned from actor-isolated instance method 'streamBoxes()' to main actor-isolated context
```

막혔다. `AsyncStream`이라서 된 게 아니라, 흘려보내는 값이 Sendable이라서 된 것이다. 공장 비유로 하면, 매장 진열대의 제품(`PassthroughSubject`)을 들고 나오는 대신, 어디로 보내도 안전한 소식(`FlightPhase`)만 흘려보내는 통로를 새로 연 셈이다.

그럼 `FlightPhase`에서 `: Sendable`을 지우면 `AsyncStream` 쪽에서 막힐까. 선언만 바꿔가며 빌드해봤다.

| `FlightPhase` 선언 | `AsyncStream<FlightPhase>`를 밖으로 꺼내면 |
|---|---|
| `enum FlightPhase: Sendable { ... }` | <span style="color:#2e9e4f">통과</span> |
| `enum FlightPhase { ... }` (`Sendable`만 지움) | <span style="color:#2e9e4f">통과</span> |
| `public enum FlightPhase { ... }` | <span style="color:#e5534b">에러</span> |
| `enum FlightPhase { case preflight, custom(PhaseBox) }` | <span style="color:#e5534b">에러</span> |

`: Sendable`을 지워도 통과했다. [Sendable Docs](https://developer.apple.com/documentation/swift/sendable#Sendable-Structures-and-Enumerations){:target="_blank"}의 "Sendable Structures and Enumerations"에 이유가 있다.

> To satisfy the requirements of the `Sendable` protocol, an enumeration or structure must have only sendable members and associated values. In some cases, structures and enumerations that satisfy the requirements implicitly conform to `Sendable`:
>
> * Frozen structures and enumerations
> * Structures and enumerations that aren’t public and aren’t marked `@usableFromInline`.
>
> Otherwise, you need to declare conformance to `Sendable` explicitly.

풀어 쓰면 이렇다.

- **전제 조건**: struct나 enum이 Sendable이 되려면, 안에 든 값과 연관값이 전부 Sendable이어야 한다
- **자동으로 되는 경우**: 이 조건을 만족하면서, `@frozen`으로 선언했거나 `public`이 아닌 struct와 enum은 따로 적지 않아도 Sendable이 된다. `@frozen`은 주로 라이브러리를 만들 때 쓰는 표시라, 앱 코드에서는 "`public`이 아니면 자동"으로 보면 된다
- **그 밖에는**: 직접 `: Sendable`을 적어야 한다

표에 대 보면 두 번째 경우(`Sendable`만 지움)는 전제 조건을 만족하고 `public`도 아니라 자동으로 Sendable이 됐다. 세 번째 경우는 `public`이라 자동 적용이 빠져서 막혔다. 네 번째 경우는 연관값 `PhaseBox`가 Sendable이 아니라 전제 조건부터 깨져서 막혔다. 에러는 둘 다 위의 `AsyncStream<PhaseBox>` 때와 같은 `non-Sendable 'AsyncStream<FlightPhase>'-typed result can not be returned` 에러였다.

RunWay의 실제 `FlightPhase`는 `enum FlightPhase: String, Codable, Sendable, Hashable`처럼 `Sendable`을 직접 적어두고 있다. 자동으로 되는 경우라도 직접 적어두면 차이가 있다. `public`을 붙여도 계속 Sendable로 남고, Sendable이 아닌 연관값을 추가하면 멀리 떨어진 `AsyncStream` 쪽이 아니라 enum을 선언한 자리에서 바로 에러가 난다.

```text
error: associated value 'custom' of 'Sendable'-conforming enum 'FlightPhase' has non-Sendable type 'PhaseBox'
```

---

#### @unchecked Sendable은 검사를 끈다

위에서 인용한 Sendable Docs 문단은 이렇게 끝난다.

> Structures that have nonsendable stored properties and enumerations that have nonsendable associated values can be marked as `@unchecked Sendable`, disabling compile-time correctness checks, after you manually verify that they satisfy the `Sendable` protocol’s semantic requirements.

Sendable이 아닌 값을 품은 struct나 enum도 `@unchecked Sendable`로 표시할 수 있다는 뜻이다. 대신 컴파일러가 하던 검사가 꺼지고, 정말 안전한지는 개발자가 직접 확인해야 한다.

정확히 말하면 검사를 건너뛰는 곳은 선언한 자리 한 곳이다. 안에 든 값이나 연관값이 전부 Sendable인지 확인하지 않을 뿐, 그 밖의 모든 곳에서는 진짜 Sendable로 취급된다.

---

##### 붙이면 무슨 일이 생기나

위에서 에러가 났던 enum(`custom(PhaseBox)`)에 `@unchecked`만 붙여봤다. 그리고 이 enum이 품은 `PhaseBox`를 두 작업이 동시에 바꾸게 만들었다.

```swift
final class PhaseBox {               // Sendable 아님, 잠금 장치도 없음
    var count = 0
}

enum FlightPhase: @unchecked Sendable {
    case preflight
    case custom(PhaseBox)
}

func race() async -> Int {
    let box = PhaseBox()
    let phase = FlightPhase.custom(box)
    async let a: Void = Task.detached {
        if case .custom(let b) = phase { for _ in 0..<100_000 { b.count += 1 } }
    }.value
    async let b: Void = Task.detached {
        if case .custom(let b) = phase { for _ in 0..<100_000 { b.count += 1 } }
    }.value
    _ = await (a, b)
    return box.count
}
```

빌드는 에러도 경고도 없이 통과했다. `AsyncStream<FlightPhase>`로 actor 밖으로 꺼내는 것도 통과했다. 그런데 `race()`를 다섯 번 돌려보니 결과가 이랬다.

```text
예상 200000, 실제 171242
예상 200000, 실제 161744
예상 200000, 실제 177744
예상 200000, 실제 170096
예상 200000, 실제 172265
```

다섯 번 모두 값이 깨졌다. 컴파일러는 `@unchecked`를 믿고 아무것도 확인하지 않았고, 실제로는 두 작업이 같은 `PhaseBox`를 동시에 건드렸다. 공장 비유로 하면, 검수를 거치지 않고 "어디로 보내도 안전함" 스티커를 직접 붙인 셈이다.

이전글의 `@preconcurrency`와 비교하면 차이가 분명하다. 프로토콜 이름 앞의 `@preconcurrency`는 빌드할 때 에러를 지워도, 실행 중에 확인하는 코드가 남아서 크래시로라도 알려줬다. `@unchecked Sendable`은 그런 확인 코드도 없다. 그래서 위 결과처럼 아무 말 없이 값만 깨진다.

---

##### AsyncStream은 왜 @unchecked를 썼나

위에서 본 `AsyncStream` 선언에도 `@unchecked`가 있었다. 왜 표준 라이브러리가 직접 `@unchecked`를 붙였는지 궁금해서 소스([AsyncStream.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/AsyncStream.swift){:target="_blank"})의 설명 주석부터 봤다.

> In particular, an asynchronous stream is well-suited to adapt callback- or delegation-based APIs to participate with `async`-`await`.

> The continuation conforms to `Sendable`, which permits calling it from concurrent contexts external to the iteration of the `AsyncStream`.

`AsyncStream`은 콜백이나 델리게이트 기반 API를 async/await로 옮기는 데 알맞게 만들어졌고, 값을 넣는 쪽인 `Continuation`은 Sendable이라서 스트림을 읽는 곳 바깥의 동시 실행 환경에서도 부를 수 있다는 뜻이다. 실제로 값을 넣는 `yield(_:)`는 `async`가 아닌 동기 함수라서, `await` 없이 어느 스레드의 델리게이트 콜백에서든 바로 부를 수 있다.

예를 들어 위치 델리게이트가 아무 스레드에서 `yield`로 값을 넣고, 동시에 뷰모델은 MainActor에서 `for await`로 값을 꺼낸다. 두 쪽이 같은 버퍼를 동시에 건드리니 보호가 반드시 필요하다. RunWay의 `RunningCenter`가 위치 데이터를 `AsyncStream`으로 뷰모델에 흘려보낸 것도 이 모양이다. 여기서부터는 추론인데, `yield`가 `await` 없이 어디서나 불려야 하니 actor로 보호할 수는 없고, 그래서 잠금을 쓴 것으로 읽힌다.

그러니 `@unchecked`는 "안전하니까 검사가 필요 없다"는 뜻이 아니다. 안전은 잠금으로 직접 만들어두고, 그걸 컴파일러가 확인할 수 없으니 "우리가 보장한다"고 표시한 것이다.

선언을 다시 보자.

```swift
extension AsyncStream : @unchecked Sendable where Element : Sendable
```

이 한 줄에는 서로 다른 책임 두 개가 들어있다.

| 부분 | 무엇을 책임지나 | 누가 확인하나 |
|---|---|---|
| `@unchecked Sendable` | 스트림 자기 안쪽(쌓아둔 값, 기다리는 쪽 목록) | 표준 라이브러리 개발자가 잠금으로 직접 |
| `where Element : Sendable` | 스트림을 통해 흘러가는 값 | 컴파일러 |

Swift 표준 라이브러리 소스([AsyncStreamBuffer.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/AsyncStreamBuffer.swift){:target="_blank"})를 보면 `AsyncStream` 안에 `_Storage`라는 클래스가 있다. 쌓아둔 값(`pending`)과 기다리는 쪽 목록(`continuations`)을 `var`로 들고 있는, 바뀌는 상태를 가진 클래스다.

```swift
// 소스에서 필요한 부분만 줄여서 옮겼다
internal final class _Storage: @unchecked Sendable {
    // 생략
    private func lock() { ... }
    private func unlock() { ... }

    func getOnTermination() -> TerminationHandler? {
        lock()
        let handler = state.onTermination
        unlock()
        return handler
    }
    // 생략
}
```

모든 접근을 `lock()`과 `unlock()`으로 감싸고 `@unchecked Sendable`을 붙였다. 바뀌는 상태를 가진 클래스라 컴파일러는 안전하다고 증명할 수 없으니, 잠금으로 직접 지키고 "이건 우리가 책임진다"고 표시한 것이다.

그런데 잠금이 지켜주는 건 스트림의 버퍼까지다. 흘려보낸 값 자체는 보내는 쪽(actor)과 받는 쪽(MainActor)이 둘 다 들고 있게 된다. 그 값이 바뀔 수 있는 클래스라면 잠금과 상관없이 양쪽이 동시에 만질 수 있다. 그래서 흘려보내는 값은 `where Element : Sendable`로 따로 Sendable이어야 한다고 걸어둔 것이다. 이쪽은 컴파일러가 검사한다.

위 실험에서 값이 깨진 게 정확히 이 틈이다. `FlightPhase`에 `@unchecked Sendable`을 붙여서 "Sendable이다"라고 선언하니, `where` 조건은 그 말을 믿고 통과시켰다. 스트림 안쪽은 잠금이 지켰지만, 흘려보낸 값 안의 `PhaseBox`는 아무도 지키지 않았다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-Sendable이-아닌-값은-언제-넘길-수-있나/asyncstream_unchecked_diagram.png)

---

##### @unchecked가 먼저, where는 그다음

처음엔 "`where`로 Sendable인 값만 받으니까 `@unchecked`를 쓸 수 있었던 것"이라고 반대로 이해했다. 그래서 `AsyncStream`과 같은 구조의 `Channel`을 만들어서, `@unchecked`와 `where`를 하나씩 빼봤다.

```swift
// AsyncStream의 _Storage처럼 바뀌는 상태를 잠금으로 보호하는 클래스
final class Storage<Element> {
    private let lock = NSLock()     // Foundation의 잠금. withLock 안은 한 번에 한 곳만 들어갈 수 있다
    private var items: [Element] = []
    func push(_ e: Element) { lock.withLock { items.append(e) } }
}

struct Channel<Element> {
    let storage = Storage<Element>()
}

extension Channel: @unchecked Sendable where Element: Sendable {}   // 여기만 바꿔가며 빌드
```

| 선언 | `Channel<FlightPhase>` | `Channel<PhaseBox>` |
|---|---|---|
| `@unchecked Sendable where Element: Sendable` (AsyncStream과 같은 모양) | <span style="color:#2e9e4f">통과</span> | <span style="color:#e5534b">에러</span> |
| `@unchecked Sendable` (`where` 없음) | <span style="color:#2e9e4f">통과</span> | <span style="color:#2e9e4f">통과</span> |
| `Sendable where Element: Sendable` (`@unchecked` 없음) | <span style="color:#e5534b">선언한 자리에서 에러</span> | <span style="color:#e5534b">선언한 자리에서 에러</span> |

세 번째 경우의 에러가 순서를 알려준다.

```text
error: stored property 'storage' of 'Sendable'-conforming generic struct 'Channel' has non-Sendable type 'Storage<Element>'
```

`where`를 붙여도 `@unchecked`를 빼면, 안에 든 `Storage` 때문에 Sendable이 될 수 없다. 잠금으로 지키고 있다는 건 컴파일러가 확인할 방법이 없으니 `@unchecked`가 먼저 필요하다. 그런데 두 번째 경우처럼 `@unchecked`만 붙이면 `Channel<PhaseBox>`까지 통과해버린다. 잠금은 저장소만 지키고 흘려보낸 `PhaseBox` 안쪽은 못 지키니, "안전하다"는 약속이 거짓이 된다.

즉 순서는 이렇다. 잠금으로 지키는 저장소 때문에 `@unchecked`가 필요했고, 그 약속이 흘려보내는 값까지 참이 되도록 `where`로 범위를 좁혔다.

---

##### 왜 Sendable에만 @unchecked가 있나

`@unchecked`가 Sendable 말고 다른 프로토콜에도 붙는지 궁금해서 `Hashable`에 붙여봤다.

```swift
struct Point: @unchecked Hashable {
    var x = 0
}
```

```text
warning: '@unchecked' conformance to 'Hashable' has no meaning
```

에러는 아니지만 "의미가 없다"는 경고가 떴다. `@unchecked`가 뜻을 갖는 건 Sendable뿐이다. 두 프로토콜을 검사하는 방식이 달라서다.

| | `Hashable` 같은 보통 프로토콜 | `Sendable` |
|---|---|---|
| 요구하는 것 | `hash(into:)`, `==` 같은 메서드 | 메서드 없음 |
| 컴파일러가 보는 것 | 필요한 메서드가 있는가 | 안에 든 값의 타입이 전부 Sendable인가 (클래스라면 바뀌는 `var`가 없는가) |
| 판단 | 있거나 없거나, 항상 정확히 판단된다 | 실제로 안전해도 모양이 규칙에 안 맞으면 탈락한다 |

컴파일러는 타입과 선언에 드러난 모양은 검사하지만, 메서드 안에서 실제로 무슨 일을 하는지는 검사하지 않는다. `Hashable`도 `==`가 있는지만 보고, `==`를 엉터리로 구현해도 잡지 못한다. 다만 `Hashable`은 "메서드가 있는가"만 보면 되니 검사를 끌 이유가 없다.

`Sendable`이 진짜로 뜻하는 건 "여러 곳에서 동시에 써도 안전하다"인데, 컴파일러는 이걸 직접 증명할 수 없다. 그래서 "안에 든 게 전부 Sendable이고, 클래스라면 바뀌는 `var`도 없으면 안전하다" 같은 모양 규칙으로 대신 판단한다. 클래스에 `var`를 넣고 `Sendable`을 붙이면 `stored property 'count' of 'Sendable'-conforming class 'C' is mutable` 에러가 난다. 여러 곳이 같은 인스턴스를 가리키는 클래스라서다. 이전글에서 본 것처럼 Sendable은 메서드 없이 이름표만 있는 프로토콜이라, 그 이름표를 붙일 자격을 모양으로만 판단하는 셈이다. 그런데 `_Storage`처럼 `var`가 있어도 메서드 안에서 잠금으로 제대로 지키면 실제로는 안전하다. 잠금을 빠짐없이 쓰는지는 메서드 안의 동작이라 모양 규칙으로는 알 수 없다. 그래서 "모양은 규칙에 안 맞지만 내가 보장한다"고 말할 방법이 Sendable에만 필요했다.

Sendable을 만든 [SE-0302](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md){:target="_blank"}("Sendable and @Sendable closures", Swift 5.7에서 구현)에도 같은 이유가 적혀있다.

> This is appropriate for classes that use access control and internal synchronization to provide memory safety

> these mechanisms cannot generally be checked by the compiler.

접근 제어나 내부 잠금으로 안전을 지키는 클래스에 쓰라는 것이고, 그런 방법은 컴파일러가 일반적으로 확인할 수 없다는 뜻이다.

실제로 앱 코드에서는 볼 일이 거의 없었다. RunWay와 GitExplorer를 통틀어 `@unchecked`는 한 곳뿐이었다. 반대로 지금 SDK의 선언 파일에는 Concurrency 모듈에만 26곳, Foundation에 10곳이 있었다. 라이브러리를 만드는 쪽이 안을 직접 보호하고 붙이는 표시라, 앱 코드에서 직접 쓰기보다는 Option 키를 누르고 클릭해서 정의를 볼 때 주로 만나게 된다.

---

### 새로 만든 값은 sending으로 꺼낼 수 있다

actor 프로퍼티는 절대 밖으로 못 나갔다. 그럼 actor 메서드가 새로 만든 값을 돌려주는 건 어떨까. 앞에서 본 `sending`은 반환값에도 붙일 수 있다.

```swift
actor RunningCenter {
    var stored = PhaseBox()

    func makeBox() -> PhaseBox {            // 새로 만들어서 반환
        PhaseBox()
    }
}

@MainActor
func use(center: RunningCenter) async {
    let box = await center.makeBox()
    box.count += 1
}
```

| 반환 | 결과 |
|---|---|
| `func makeBox() -> PhaseBox { PhaseBox() }` | <span style="color:#e5534b">에러: `non-Sendable 'PhaseBox'-typed result can not be returned`</span> |
| `func makeBox() -> sending PhaseBox { PhaseBox() }` | <span style="color:#2e9e4f">통과</span> |
| `func makeBox() -> sending PhaseBox { stored }` | <span style="color:#e5534b">에러: `'self'-isolated 'self.stored' cannot be a 'sending' result`</span> |

새로 만든 값이라도 그냥 반환하면 막혔다. actor 메서드의 반환값은 기본적으로 actor 소속으로 보기 때문이다. `sending`을 붙이면 "이건 actor와 이어지지 않은 새 값"이라는 약속이 되고, 밖으로 나갈 수 있었다.

대신 actor 프로퍼티(`stored`)를 `sending`으로 돌려주려 하면 막혔다. 이미 A 로고가 찍힌 제품에 "로고 없음" 스티커를 붙일 수는 없는 셈이다. 앞의 "actor 안의 값은 actor 소속이다"가 `sending`으로도 뒤집히지 않는다.

---

### 정리하면

| 경우 | 결과 | 비고 |
|---|---|---|
| actor 프로퍼티(`PassthroughSubject`)를 밖에서 꺼냄 | <span style="color:#e5534b">`cannot exit actor-isolated context` 에러</span> | actor 소속 region은 절대 밖으로 못 나간다. `let`이어도 같다 |
| Combine 대신 평범한 클래스 | <span style="color:#e5534b">같은 에러</span> | Combine 문제가 아니라 Sendable이 아닌 값이 actor 소속이라서다 |
| `AsyncStream<FlightPhase>`로 바꿈 | <span style="color:#2e9e4f">통과</span> | 흘려보내는 값이 Sendable이라 스트림도 Sendable이다 |
| `AsyncStream<PhaseBox>` | <span style="color:#e5534b">에러</span> | 흘려보내는 값이 Sendable이 아니면 스트림도 Sendable이 아니다 |
| Sendable 아닌 연관값을 품은 enum에 `@unchecked Sendable` | <span style="color:#2e9e4f">빌드 통과</span>, <span style="color:#e5534b">실행하면 값이 깨짐</span> | 검사를 끌 뿐 안전하게 만들지는 않는다 |
| actor 메서드가 새로 만든 값을 `sending`으로 반환 | <span style="color:#2e9e4f">통과</span> | actor와 이어지지 않은 새 값이라는 약속이 된다 |
| actor 프로퍼티를 `sending`으로 반환 | <span style="color:#e5534b">에러</span> | 이미 actor 소속이라 `sending`으로도 못 꺼낸다 |

---

## 4. onTermination 클로저로 다시 보기

RunWay와 GitExplorer를 만들 때 `AsyncStream`의 `onTermination` 클로저에서 둘 다 막힌 적이 있다. 그때마다 `Task`로 감싸서 해결했고, RunWay [이전글](https://haroldfromk.github.io/posts/RunningProject-(5)/){:target="_blank"}에서는 격리 관점으로 이유도 정리했다. 이번엔 region 관점에서 다시 보니, 그 해결이 왜 통했는지가 하나 더 보였다.

---

### onTermination은 @Sendable 클로저다

RunWay 때 Option 키를 누르고 클릭해봤을 때는 안 보였고, [onTermination Docs](https://developer.apple.com/documentation/swift/asyncstream/continuation/ontermination){:target="_blank"}에서 `@Sendable`인 걸 확인했었다. 지금 SDK 선언에도 그대로 적혀있다.

```swift
public var onTermination: (@Sendable (Termination) -> Void)?
```

`Task`의 클로저는 `sending`이었지만, `onTermination`은 `@Sendable`이다. 이전글에서 확인한 대로 둘은 기준이 다르다. `sending`은 region을 보고 "넘긴 뒤 다시 안 쓰면" 허락했지만, `@Sendable`은 캡처하는 값이 전부 Sendable이어야 한다. 방금 만든 값으로 직접 비교해봤다.

```swift
struct CollectedData: Sendable { var heartRate = 0 }

final class Logger {                 // Sendable 아님
    var lines: [String] = []
    func log(_ s: String) { lines.append(s) }
}

// Task: 방금 만든 logger를 넘기고 다시 안 씀
func makeStreamWithTask() -> AsyncStream<CollectedData> {
    let logger = Logger()
    Task {
        logger.log("시작")
    }
    return AsyncStream { _ in }
}

// onTermination: 방금 만든 logger를 캡처하고 다시 안 씀
func makeStreamWithTermination() -> AsyncStream<CollectedData> {
    let logger = Logger()
    return AsyncStream { continuation in
        continuation.onTermination = { _ in
            logger.log("종료")
        }
    }
}
```

| 어디에 캡처하나 | 결과 |
|---|---|
| `Task { }` (`sending`) | <span style="color:#2e9e4f">통과</span> |
| `onTermination` (`@Sendable`) | <span style="color:#e5534b">`capture of 'logger' with non-Sendable type 'Logger' in a '@Sendable' closure` 에러</span> |

같은 "방금 만든 값을 넘기고 다시 안 쓰는" 경우인데 `onTermination`에서는 막혔다. "예시 코드로 확인하기"에서 본 region 규칙은 `sending`에만 적용되고, `@Sendable` 클로저에서는 도움이 안 된다. 공장 비유로 하면, `Task`는 로고 없는 제품이면 받아주는 매장이고, `onTermination`은 "어디로 보내도 안전함" 인증(Sendable)이 있는 제품만 받는 창구다.

---

### 그동안 Task로 감싸서 통했던 이유

RunWay에서는 actor 안에서 `onTermination`으로 actor 프로퍼티를 직접 바꾸려다 막혔다.

```swift
actor RunningCenter {
    var continuation: AsyncStream<CollectedData>.Continuation?

    func stream() -> AsyncStream<CollectedData> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { _ in
                self.continuation = nil      // actor 프로퍼티를 직접 바꿈
            }
        }
    }
}
```

```text
error: actor-isolated property 'continuation' can not be mutated from a Sendable closure
```

해결은 actor 메서드를 따로 만들고 `Task`로 감싸서 부르는 것이었다.

```swift
continuation.onTermination = { [weak self] _ in
    Task { await self?.clearContinuation() }
}
```

GitExplorer [Actor 미니 프로젝트](https://haroldfromk.github.io/posts/Actor-%EB%AF%B8%EB%8B%88-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8(1)/){:target="_blank"}에서도 비슷했다. `SimulatorTask`는 `final class`였지만, Xcode의 기본 격리 설정 때문에 `@MainActor` 클래스가 되어 있었다. 그래서 `onTermination`에서 `stop()`을 바로 부르면 막혔고, `Task { @MainActor in }`로 감싸서 해결했다.

```swift
continuation.onTermination = { [weak self] _ in
    Task { @MainActor in self?.stop() }
}
```

둘 다 통과했다. 그런데 region 관점에서 보면 두 해결에는 공통점이 있다. `onTermination`이 `@Sendable`인데도 `self`를 캡처할 수 있었던 건, `self`가 원래 Sendable이었기 때문이다. RunWay의 `self`는 actor였고, GitExplorer의 `self`는 `@MainActor` 클래스였다. 이전글에서 본 Sendable Docs 그대로 actor와 `@MainActor` 클래스는 자동으로 Sendable이다.

그럼 `SimulatorTask`가 기본 격리 설정 없이 그냥 평범한 클래스였다면 어땠을까.

```swift
final class SimulatorTask {          // 격리 없는 평범한 클래스
    func start() -> AsyncStream<CollectedData> {
        AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { self?.stop() }
            }
        }
    }
    func stop() {}
}
```

```text
error: capture of 'self' with non-Sendable type 'SimulatorTask?' in a '@Sendable' closure [#SendableClosureCaptures]
```

`Task`로 감싸도 막혔다. `Task` 안으로 들어가기 전에, 바깥의 `onTermination` 클로저가 `self`를 캡처하는 순간 이미 막힌다. `Task`로 감싸는 방법이 통했던 건 `Task`가 뭔가를 해결해줘서가 아니라, 애초에 `self`가 Sendable이라 `onTermination`에 들어갈 수 있었기 때문이다. `Task`는 그 뒤에 격리된 메서드를 `await`로 부르는 역할만 했다. 이 에러는 표시가 `Task` 블록 안쪽 줄에 떠서, 예전에는 `Task`의 클로저가 `@Sendable`인 줄로 잘못 이해했었다. 문구가 말하는 `@Sendable` 클로저는 바깥의 `onTermination`이다.

---

#### Task와 await는 각자 무엇을 하나

그럼 왜 `Task`와 `await`를 꼭 같이 썼을까. 그리고 GitExplorer는 `Task { @MainActor in }`이라 `await`가 없는데 왜 통했을까. 하나씩 빼봤다.

```swift
// RunWay (actor)
continuation.onTermination = { [weak self] _ in
    await self?.clearContinuation()            // 1) Task 없이 await만
}
continuation.onTermination = { [weak self] _ in
    Task { self?.clearContinuation() }         // 2) Task는 있는데 await 없음
}
continuation.onTermination = { [weak self] _ in
    Task { await self?.clearContinuation() }   // 3) RunWay 해결
}

// GitExplorer (@MainActor 클래스)
continuation.onTermination = { [weak self] _ in
    Task { self?.stop() }                      // 4) @MainActor in도 await도 없음
}
continuation.onTermination = { [weak self] _ in
    Task { await self?.stop() }                // 5) @MainActor in 없이 await
}
continuation.onTermination = { [weak self] _ in
    Task { @MainActor in self?.stop() }        // 6) GitExplorer 해결
}
```

| 경우 | 결과 |
|---|---|
| 1) `Task` 없이 `await`만 | <span style="color:#e5534b">에러: `invalid conversion from 'async' function ... to synchronous function type`</span> |
| 2) `Task`는 있는데 `await` 없음 | <span style="color:#e5534b">에러: `actor-isolated instance method 'clearContinuation()' cannot be called from outside of the actor`</span> |
| 3) `Task { await ... }` | <span style="color:#2e9e4f">통과</span> |
| 4) `Task { self?.stop() }` | <span style="color:#e5534b">에러: `main actor-isolated instance method 'stop()' cannot be called from outside of the actor`</span> |
| 5) `Task { await self?.stop() }` | <span style="color:#2e9e4f">통과</span> |
| 6) `Task { @MainActor in self?.stop() }` | <span style="color:#2e9e4f">통과</span> |

1번 에러가 `Task`가 필요한 이유다. `onTermination`의 타입은 `@Sendable (Termination) -> Void`로, `async`가 아닌 동기 함수 자리다. 그 안에서 `await`를 쓰면 클로저가 `async`가 되어버려서 자리에 맞지 않는다.

`await`를 아무 데서나 쓸 수 없다는 건 The Swift Programming Language의 [Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Defining-and-Calling-Asynchronous-Functions){:target="_blank"} 장에 정해져 있다.

> Because code with `await` needs to be able to suspend execution, only certain places in your program can call asynchronous functions or methods:
>
> - Code in the body of an asynchronous function, method, or property.
> - Code in the static `main()` method of a structure, class, or enumeration that's marked with `@main`.
> - Code in an unstructured child task

`await`는 실행을 잠시 멈출 수 있어야 해서, 세 곳에서만 쓸 수 있다는 뜻이다. `async` 함수 안, `@main` 타입의 `static main()` 안, 그리고 `Task { }`로 만드는 작업(unstructured task) 안이다. `onTermination` 클로저는 셋 중 어디에도 해당하지 않으니, `Task { }`로 세 번째 자리를 새로 만들어서 그 안에서 `await`를 쓴 것이다.

반대로 `async` 함수 안이라면 `Task` 없이 `await`를 바로 쓸 수 있다. 같은 actor 메서드를 불러서 비교해봤다.

| 코드 | 결과 |
|---|---|
| `async` 함수 안에서 `await center.clearContinuation()` | <span style="color:#2e9e4f">통과</span> |
| 동기 함수 안에서 `await center.clearContinuation()` | <span style="color:#e5534b">에러: `'await' in a function that does not support concurrency`</span> |
| 동기 함수 안에서 `Task { await center.clearContinuation() }` | <span style="color:#2e9e4f">통과</span> |

`Task`가 빠질 수 없는 건 `async` 함수가 아니라 동기 함수 안이다. `Task`는 동기 함수와 비동기 코드를 잇는 다리인 셈이다.

2번 에러가 `await`가 필요한 이유다. `Task` 안으로 들어왔지만 거기는 여전히 actor 밖이다. 같은 문서의 [Unstructured Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Unstructured-Concurrency){:target="_blank"}에 이렇게 적혀있다.

> The new task defaults to running with the same actor isolation, priority, and task-local state as the current task.

`Task`로 만든 작업은 기본적으로 만든 곳과 같은 actor 격리를 따라간다는 뜻이다. `Task`를 만든 곳이 actor 밖인 `onTermination` 클로저이니, `Task` 안도 actor 밖이다. 그래서 actor 메서드를 부르려면 `await`로 actor에 들어갈 차례를 기다려야 한다.

즉 `Task`는 "기다릴 수 있는 공간"을 만들고, `await`는 그 공간에서 "actor 안으로 들어갈 차례를 기다리는" 일을 한다. 하나라도 빠지면 막힌다.

<!-- 이미지 자리: Task와 await의 역할 (해롤드가 넣을 이미지, 프롬프트는 대화에 있음) -->
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-Sendable이-아닌-값은-언제-넘길-수-있나/task.png)

GitExplorer의 6번이 `await` 없이 통과한 건 `@MainActor in` 때문이다. 이건 `Task` 안의 코드를 처음부터 MainActor에서 돌리라는 표시라, `stop()`을 부를 때 이미 MainActor 안에 있다. 들어갈 필요가 없으니 기다릴 것도 없다. 5번처럼 `@MainActor in` 없이 `await`로 들어가도 똑같이 통과한다. 둘은 "처음부터 안에서 시작하느냐, 밖에서 시작해서 들어가느냐"의 차이다.

---

### 정리하면

| 경우 | 결과 | 비고 |
|---|---|---|
| `onTermination`에 방금 만든 Sendable 아닌 값을 캡처 | <span style="color:#e5534b">에러</span> | `@Sendable`이라 region 규칙이 적용되지 않는다 |
| 같은 값을 `Task`에 캡처하고 다시 안 씀 | <span style="color:#2e9e4f">통과</span> | `Task`는 `sending`이라 region을 본다 |
| RunWay: actor에서 `onTermination`으로 프로퍼티를 직접 바꿈 | <span style="color:#e5534b">에러</span> | `@Sendable` 클로저는 actor 격리 밖이다 |
| RunWay: `Task { await self?.clearContinuation() }` | <span style="color:#2e9e4f">통과</span> | `self`(actor)가 Sendable이라 캡처할 수 있다 |
| GitExplorer: `Task { @MainActor in self?.stop() }` | <span style="color:#2e9e4f">통과</span> | `self`(`@MainActor` 클래스)가 Sendable이라 캡처할 수 있다 |
| 평범한 클래스에서 `Task`로 감쌈 | <span style="color:#e5534b">에러</span> | 바깥 `onTermination`이 Sendable 아닌 `self`를 캡처하는 순간 막힌다 |
| `onTermination` 안에서 `Task` 없이 `await`만 | <span style="color:#e5534b">에러</span> | 동기 함수 자리라 `await`를 쓸 수 없다 |
| `Task`는 있는데 `await` 없이 actor 메서드 호출 | <span style="color:#e5534b">에러</span> | `Task`는 만든 곳(actor 밖)의 격리를 따라간다 |

---

## 정리

- region isolation([SE-0414](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md){:target="_blank"}, Swift 6.0)은 Sendable이 아닌 값도 넘길 수 있게 해주는 규칙이다. Sendable 검사가 타입(제품 설계)을 봤다면, region isolation은 값 하나하나(제품 한 개)를 본다
- region은 서로 이어져 있어서 하나를 건드리면 다른 쪽에도 영향이 갈 수 있는 값들의 묶음이다. 넘길 때는 묶음 통째로 넘어간다
- 넘길 수 있는 건 아직 어디에도 소속되지 않은(disconnected) 값이고, 넘긴 뒤에 원래 쪽에서 다시 건드리지 않아야 한다. 같은 타입이라도 값마다 다른 actor로 갈 수 있지만, 한 값은 한 곳으로만 간다
- 소속은 번지고 풀리지 않는다. 이어진 값은 같이 넘어가고, 소속 있는 값과 묶이면 새 값도 그 소속이 되고, `@MainActor` 프로퍼티에 한 번 담은 값은 `nil`로 비워도 MainActor 소속으로 남는다
- 파라미터는 부른 쪽 소속(task-isolated)이라 그냥은 못 넘긴다. `sending`([SE-0430](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md){:target="_blank"})을 붙이면 "로고 없는 값만 받겠다"는 조건이 되고, 검사는 부르는 쪽으로 옮겨간다
- actor 안의 값(actor-isolated)은 절대 밖으로 못 나간다. `let`이어도, Combine이 아니어도 같다. actor 메서드가 새로 만든 값은 `sending` 반환으로 꺼낼 수 있지만, actor 프로퍼티는 `sending`으로도 못 꺼낸다
- `AsyncStream`이 actor 밖으로 나갈 수 있었던 건 흘려보내는 값이 Sendable이라서다. `public`이 아니고 안에 든 게 전부 Sendable인 struct와 enum은 따로 적지 않아도 Sendable이 된다
- `@unchecked Sendable`은 선언한 자리의 검사를 끌 뿐, 안전하게 만들어주지 않는다. 실행 중에 확인하는 코드도 없어서 아무 말 없이 값만 깨진다. 컴파일러가 확인할 수 없는 방법(잠금)으로 직접 안전을 보장했을 때 쓰는 표시라, 앱 코드보다 라이브러리 선언에서 주로 보인다
- `AsyncStream`의 선언은 잠금으로 지키는 저장소 때문에 `@unchecked`가 먼저 필요했고, 그 약속이 흘려보내는 값까지 참이 되도록 `where Element : Sendable`로 범위를 좁혔다
- `onTermination`은 `@Sendable` 클로저라 region 규칙이 적용되지 않는다. 그동안 `Task`로 감싸서 통했던 건 캡처한 `self`가 원래 Sendable(actor, `@MainActor` 클래스)이었기 때문이다
- `Task`는 동기 함수 안에 기다릴 수 있는 공간을 만들고, `await`는 그 공간에서 actor에 들어갈 차례를 기다린다. `async` 함수 안이라면 `Task` 없이 `await`를 바로 쓸 수 있다
- 기본 격리가 MainActor인 프로젝트(RunWay, GitExplorer)에서는 이 글의 예시가 에러 없이 통과한다. region 규칙이 없어진 게 아니라, 넘기는 값이 MainActor 소속이라 Sendable이기 때문이다
- region 검사도 컴파일러가 하는 일이라 빈틈이 있을 수 있다. Swift 6.3.3에서는 참조를 배열 리터럴로 남기면 놓치고, 실행하면 실제로 값이 깨졌다
