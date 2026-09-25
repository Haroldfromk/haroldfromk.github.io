---
title: (Deep Dive) actor인데 왜 상태가 꼬이나
writer: Harold
date: 2026-09-24 09:00
last_modified_at: 2026-09-25 21:11:00
categories: [Deep Dive]
tags: [Myself]
published: true
toc: true
toc_sticky: true
---

---

## 시작하게 된 이유

[이전글](https://haroldfromk.github.io/posts/(Deep-Dive)-Sendable%EC%9D%B4-%EC%95%84%EB%8B%8C-%EA%B0%92%EC%9D%80-%EC%96%B8%EC%A0%9C-%EB%84%98%EA%B8%B8-%EC%88%98-%EC%9E%88%EB%82%98/){:target="_blank"} 끝에서 `Task`와 `await`의 역할을 정리했다. `Task`는 기다릴 수 있는 공간을 만들고, `await`는 그 공간에서 actor에 들어갈 차례를 기다린다. actor는 한 번에 하나씩만 들어오게 해주니까, 차례를 지켜서 들어가면 안전하다고 생각했다.

그런데 다음 주제를 고르다가 "actor인데 상태가 꼬인다"는 말이 나왔다. 한 번에 하나씩만 들어오는데 어떻게 꼬인다는 건지 감이 안 왔다. 그러다 떠오른 게 [이전글](https://haroldfromk.github.io/posts/RunningProject-(10)/){:target="_blank"}의 리셋 문제였다. 러닝을 끝내고 바로 다시 시작하면, 리셋이 끝나기 전에 위치 처리가 먼저 actor에 들어가서 이전 러닝의 거리가 이어지던 문제다. 비슷해 보여서 파고들어 보니 이름이 있었다. actor reentrancy다. 다만 리셋 문제는 엄밀히 보면 조금 다른 문제였는데, 그 차이도 이 글에서 정리한다.

이번에도 AI와 계속 대화하면서 정리했다. 이전글들처럼 AI가 하는 말을 그대로 받아 적지 않고, 애매하면 다시 묻고, 공식 문서와 대조하고, 직접 돌려서 확인하는 식으로 진행했다. 그러다 보니 이번에도 정정할 일이 생겼다. 계산대 비유를 그림으로 옮기다가, 기다리는 사이에 사실이 아니게 된 건 A가 아니라 B가 확인한 재고였다는 걸 알고 고쳤다. 나는 처음에 재진입을 `await`가 기다리는 시간을 파고드는 문제로 봤는데, 기다리는 시간이 아주 짧아도 끼어드는 걸 보고 "틈의 길이가 아니라 틈이 생긴다는 것 자체가 문제"로 정리했다.

글의 모양도 대화하면서 많이 바뀌었다. "재고 1개 가게에서 `async let`으로 사면 어떻게 되나", "네트워크 이슈가 생기면 어느 방법이 더 흔들리나" 같은 질문을 이어가다 보니 예시가 계속 늘었고, 경우마다 헤더를 나누는 대신 예시 하나와 표로 한눈에 보는 쪽으로 합쳤다. 지갑 시뮬레이터도 처음엔 눌러야 할 게 너무 많아서 타임라인으로 다시 만들었다. AI가 제안서에서 그대로 가져온 어려운 말들도 읽으면서 쉬운 말로 바꿨다. 이번에도 AI가 꼬리질문 후보를 따로 적어뒀다가 마지막에 꺼냈고, 그중 확인해서 필요한 것만 추가했다.

---

## 1. actor reentrancy???

actor를 처음 들여온 [SE-0306](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md){:target="_blank"}("Actors", Swift 5.5에서 구현)에 처음부터 들어있던 규칙이다. 제안서의 "Actor reentrancy" 섹션은 이렇게 시작한다.

> Actor-isolated functions are reentrant.

reentrant는 "다시 들어올 수 있다"는 뜻이다. 제안서 설명을 풀면 이렇다. actor 메서드가 `await`에서 멈추면, 그 메서드가 다시 이어지기 전에 다른 작업이 같은 actor에서 먼저 실행될 수 있다. 앞 작업이 아직 안 끝났는데 다른 작업이 actor에 또 들어오는 것이다. 제안서는 이렇게 번갈아 실행되는 걸 interleaving(끼어들기)이라고 부른다.

그럼 actor가 지켜주는 건 어디까지일까. [The Swift Programming Language Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors){:target="_blank"}의 Actors 섹션에 `TemperatureLogger` 예제가 있다. 측정값을 배열에 넣고 최댓값을 갱신하는 `update(with:)` 메서드인데, 배열에 넣은 직후와 최댓값을 갱신하기 전 사이에는 두 값이 잠깐 안 맞는 상태가 된다. 문서는 이 메서드에 멈추는 지점이 없어서 업데이트 도중에 다른 코드가 끼어들 수 없다고 설명한다. 뒤집어 말하면, 멈추는 지점(`await`)이 있으면 그 사이에 다른 코드가 들어올 수 있다.

SE-0306도 같은 얘기를 한다. 한 actor에서 두 메서드가 동시에 실행되는 일은 절대 없다. 대신 멈추는 지점에서 번갈아 실행될 수는 있다. 그래서 actor는 여러 스레드가 동시에 값을 건드리는 건 막아주지만, `await` 앞에서 확인한 상태가 `await` 뒤에도 그대로라는 것까지 지켜주지는 않는다.

이전글에서 본 문제들은 "두 곳이 같은 값을 동시에 건드릴 수 있는가"였고, 컴파일러가 빌드할 때 막아줬다. 재진입은 다르다. 한 번에 하나씩 차례로 건드리는데, 그 차례 사이에 상태가 바뀌는 문제다.

이전글 이미지의 매장 비유로 이어가면 이렇다. 계산대(actor)는 한 번에 손님 한 명만 받는다. 손님 A가 재고가 1개 남은 걸 확인하고 카드 승인을 기다린다(`await`). 계산대는 기다리는 A를 옆으로 비켜 세우고 다음 손님 B를 받는다. B도 재고 1개를 확인하고 승인을 기다린다. A가 먼저 돌아와서 마지막 1개를 사 간다. 계산대 앞에는 늘 한 명뿐이었지만, B가 확인한 "재고 1개"는 B가 돌아왔을 때 이미 사실이 아니다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-actor인데-왜-상태가-꼬이나/reentrancy_counter.png)

왜 이렇게 만들었는지도 제안서에 나온다. 재진입을 막으면, 서로를 기다리는 두 actor가 영원히 멈춰버리는 상황이 생길 수 있다. 또 파일 다운로드처럼 오래 걸리는 작업 하나 때문에 actor 전체가 멈춰 있게 된다. 그래서 Swift는 재진입을 기본으로 두고, 대신 멈출 수 있는 곳마다 `await`를 반드시 적게 했다. 제안서는 `await`를 적게 하는 가장 큰 이유가 바로 이 끼어들기라고 설명한다. `await`는 "여기서 상태가 바뀔 수 있다"는 표시이기도 한 것이다.

---

### data race가 아니라 race condition이다

data race를 막으려고 actor를 쓰는데, actor 안에서 비슷한 문제가 또 생긴다는 게 처음엔 신기했다. 그런데 둘은 이름부터 다른 문제다.

| | data race | race condition |
|---|---|---|
| 무슨 문제 | 두 곳이 같은 값을 정확히 같은 순간에 건드림 | 결과가 실행 순서에 따라 달라짐 |
| 어떻게 깨지나 | 값이 반쯤 쓰인 채로 읽히거나 앱이 죽음 | 값 하나하나는 멀쩡한데 로직이 틀림 |
| 누가 막나 | actor와 Swift 6 컴파일러 | 개발자가 직접 |

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-actor인데-왜-상태가-꼬이나/race_condition_vs_data_race.png)

뒤에서 볼 지갑 예시에서 `balance`를 읽고 쓰는 순간은 늘 한 번에 하나씩이었다. data race는 없었다. 문제는 "잔액 확인 → 승인 기다리기 → 차감"이 `await`로 끊겼다는 데 있다. 멈춘 틈에 다른 결제가 들어와서 같은 잔액을 먼저 확인하느냐에 따라 결과가 갈렸다. 이게 race condition이다. SE-0306도 재진입 actor는 스레드 문제로부터는 안전하지만 "not automatically protecting from the "high level" kinds of races"라고 적어두었다.

결국 재진입은 `await`가 만드는 틈에서 생기는 허점이다. 문제는 틈의 길이가 아니라 틈이 생긴다는 것 자체다. 뒤의 예시에서 보듯, 다른 actor에서 값 하나 읽어오는 짧은 `await`에서도 끼어들었다. 틈이 짧으면 아주 가끔만 터지니 오히려 찾기가 더 어렵다.

스레드 하나에서도 생긴다는 점도 다르다. 뒤의 예시에서 지갑을 `@MainActor` 클래스로 바꿔 돌렸을 때는 모든 코드가 메인 스레드 하나에서 돌았다. 스레드가 하나뿐이니 data race는 생길 수가 없는데, 잔액은 똑같이 -60이 됐다.

정리하면 actor는 data race를 막아주지만, race condition까지 막아주지는 않는다.

---

## 2. 예시 코드로 확인하기

잔액이 100원인 지갑 actor에 80원 결제가 동시에 두 번 들어오는 상황을 만들었다. Swift 6 모드, Swift 6.3.3이고 빌드 설정은 바꾸지 않은 기본 상태다.

```swift
actor Wallet {
    var balance = 100

    func pay(_ amount: Int, name: String) async {
        guard balance >= amount else {
            print("\(name): 잔액 부족으로 거절")
            return
        }
        print("\(name): 잔액 \(balance) 확인, 승인 요청 보냄")
        try? await Task.sleep(for: .milliseconds(100))   // 카드사 승인 기다리는 척
        balance -= amount
        print("\(name): 결제 완료, 남은 잔액 \(balance)")
    }
}

@main struct Main {
    static func main() async {
        let wallet = Wallet()
        async let a: () = wallet.pay(80, name: "결제A")
        async let b: () = wallet.pay(80, name: "결제B")
        _ = await (a, b)
        print("최종 잔액:", await wallet.balance)
    }
}
```

`async let` 두 줄은 두 결제를 동시에 출발시키는 부분이다. `Task { }` 두 개를 만드는 것과 비슷하다고 보면 된다.

```text
결제A: 잔액 100 확인, 승인 요청 보냄
결제B: 잔액 100 확인, 승인 요청 보냄
결제A: 결제 완료, 남은 잔액 20
결제B: 결제 완료, 남은 잔액 -60
최종 잔액: -60
```

잔액이 100원인데 160원이 결제됐다. 순서대로 따라가면 이렇다.

1. 결제A가 actor에 들어와서 잔액 100을 확인하고, `await`에서 승인을 기다리며 멈춘다.
2. A가 멈춘 사이에 결제B가 들어온다. 잔액은 아직 100이라 B도 확인을 통과하고, `await`에서 멈춘다.
3. A가 이어서 80을 뺀다. 잔액은 20이 된다.
4. B가 이어서 또 80을 뺀다. 잔액은 -60이 된다.

B가 확인한 "잔액 100"은 B가 돌아왔을 때 이미 사실이 아니었다. 그런데 빌드는 Swift 6 모드에서도 에러와 경고 없이 통과했다. 값을 동시에 건드린 게 아니라서 컴파일러가 잡아줄 방법이 없다.

이 예시를 바꿔가며 돌려봤다. 경우마다 10번씩 돌렸고, 짧은 `await`는 1000번씩 5회, 자기 메서드를 부르는 경우는 1000번씩 3회 돌렸다.

| 경우 | 결과 | 왜 |
|---|---|---|
| 기본 (확인과 차감 사이에 `await`) | <span style="color:#e5534b">잔액 -60 (10번 모두)</span> | 멈춘 틈에 두 번째 결제가 같은 잔액을 확인 |
| 중간의 `await`를 뺌 | <span style="color:#2e9e4f">잔액 20, 두 번째 거절</span> | 멈추는 곳이 없어서 아무도 못 끼어듦 |
| `await`를 잔액 확인 앞으로 옮김 | <span style="color:#2e9e4f">잔액 20, 두 번째 거절</span> | 돌아온 뒤 확인과 차감이 틈 없이 한 번에 끝남 |
| `async let` 대신 `Task` 두 개 | <span style="color:#e5534b">잔액 -60</span> | 부르는 방식과 상관없이, 동시에 진행 중이면 꼬임 |
| 한 명씩 차례로 `await` | <span style="color:#2e9e4f">잔액 20, 두 번째 거절</span> | 동시에 진행 중이 아님 |
| 짧은 `await` (다른 actor에서 값 하나 읽기) | <span style="color:#e5534b">1000번 중 0~8번 꼬임</span> | 아주 짧은 틈에도 들어올 수 있음 |
| 자기 actor의 async 메서드를 `await` (안에서 멈추는 곳 없음) | <span style="color:#2e9e4f">1000번 중 0번 꼬임</span> | `await`라고 적혀 있어도 실제로는 멈추지 않아서 틈이 없음 |
| 자기 actor의 async 메서드를 `await` (안에서 `Task.sleep`) | <span style="color:#e5534b">1000번 모두 꼬임</span> | 안에서 멈추면 그대로 틈이 됨 |
| `@MainActor` 클래스로 바꿈 | <span style="color:#e5534b">잔액 -60</span> | MainActor도 actor라 같은 규칙. 스레드가 하나여도 꼬임 |
| 확인 없이 `await` 앞에서 읽어둔 잔액으로 계산 (30원씩 두 번) | <span style="color:#e5534b">잔액 70 (40이어야 함)</span> | 나중에 저장한 쪽이 먼저 한 차감을 덮어씀 |

자기 actor의 async 메서드를 부르는 두 줄이 눈에 띈다. `await`는 "여기서 멈출 수도 있다"는 표시라, 같은 actor 안에서 부르고 안에서도 멈추지 않으면 실제로는 멈추지 않았다. 대신 그 메서드 안에 `await`가 하나라도 생기면 바로 틈이 된다. 그래서 `await`가 적힌 곳은 틈으로 보고 짜는 게 안전하다.

값을 계산하지 않는 `await`도 돌려봤다.

| 경우 | 결과 | 왜 |
|---|---|---|
| 캐시에 없으면 다운로드, 같은 이미지를 동시에 두 번 요청 | <span style="color:#e5534b">다운로드 2번</span> | 둘 다 `await` 전에 "캐시에 없다"를 확인 |
| 검색창에 'a' 입력 후 바로 'ab', 'a' 응답이 더 늦게 옴 | <span style="color:#e5534b">화면에 'a' 결과가 남음</span> | 읽어둔 값은 없지만 "내 응답이 최신"이라고 가정 |
| 로그 두 줄을 동시에 기록 | <span style="color:#2e9e4f">두 줄 다 남음 (순서만 10번 중 4번 바뀜)</span> | 뒤의 코드가 아무것도 가정하지 않음 |

다운로드가 두 번 되는 건 SE-0306도 같은 예시를 들면서, 최악이라도 같은 일을 두 번 하는 정도라고 설명한다. 하지만 그 일이 결제 요청이나 저장이라면 얘기가 다르다.

---

### 정리하면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-actor인데-왜-상태가-꼬이나/await_gap_assumptions.png)

표를 보면 `await`가 있다고 무조건 꼬이는 것도, `async let` 때문에 꼬이는 것도 아니다. 꼬인 경우는 모두 `await` 뒤의 코드가 기다리기 전과 세상이 그대로라고 가정했다. 그 가정은 확인한 잔액일 수도, 변수에 담아둔 값일 수도, "캐시에 없었다"나 "내 응답이 최신이다" 같은 믿음일 수도 있다. 결과도 값이 틀어지거나, 같은 일이 두 번 되거나, 옛날 결과가 남는 식으로 달랐다. 모양은 달라도 모두 앞에서 본 race condition이다.

그리고 전부 빌드는 에러와 경고 없이 통과했고, 틈이 짧으면 1000번 중 몇 번만 터졌다. 컴파일러도 못 잡고 몇 번 실행해봐서는 잘 안 보인다. 여러 스레드가 같은 값을 동시에 건드리는지 실행 중에 찾아주는 Xcode의 Thread Sanitizer를 켜고 돌려도, 잔액은 -60이 됐는데 경고는 하나도 없었다. data race가 아니라 순서 문제라서 이 도구가 찾는 대상이 아니다. 그래서 `await`를 적을 때마다 그 뒤의 코드가 무엇을 믿고 있는지 직접 봐야 한다.

---

## 3. 어떻게 막나

앞에서 꼬인 경우는 모두 `await` 뒤의 코드가 기다리기 전과 세상이 그대로라고 가정했다. 그러니 막는 방법도 이 가정을 없애는 쪽이다.

SE-0306은 가장 쉬운 방법으로 상태를 바꾸는 코드를 `await`가 없는 코드 안에 몰아두라고 한다. `await`가 없는 구간은 아무도 끼어들 수 없고, `await`가 그 구간을 끊는다는 것이다. [WWDC21 Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/){:target="_blank"}도 같은 두 가지를 권한다. 상태는 `await`가 없는 코드에서 바꾸고, `await` 뒤에는 기다리기 전에 세운 가정이 아직 맞는지 확인하라는 것이다.

지갑 예시에 이 방향으로 세 가지 방법을 넣어봤다.

```swift
actor Wallet {
    var balance = 100
    var isPaying = false

    // 1) 먼저 빼두기: await 전에 차감하고, 승인이 실패하면 되돌린다
    func payReserve(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        guard await approve() else {
            balance += amount
            return false
        }
        return true
    }

    // 2) 다시 확인하기: await 뒤에 잔액을 한 번 더 확인한다
    func payRecheck(_ amount: Int) async -> Bool {
        guard balance >= amount else { return false }
        guard await approve() else { return false }
        guard balance >= amount else { return false }   // 돌아와서 다시 확인
        balance -= amount
        return true
    }

    // 3) 진행 중 표시: 결제 중이면 다음 결제를 바로 거절한다
    func payGuarded(_ amount: Int) async -> Bool {
        guard !isPaying else { return false }
        isPaying = true
        defer { isPaying = false }
        guard balance >= amount else { return false }
        guard await approve() else { return false }
        balance -= amount
        return true
    }

    private func approve() async -> Bool {
        // 생략 (100ms 기다린 뒤 카드사 승인 결과를 돌려준다)
    }
}
```

세 방법 모두 확인과 변경 사이에 `await`가 없다. 먼저 빼두기는 확인과 차감을 `await` 앞에서 한 번에 끝내서 틈 너머로 들고 가는 게 없다. 다시 확인하기는 틈 너머로 들고 간 확인을 믿지 않고, 돌아와서 다시 확인한 뒤 바로 뺀다. 진행 중 표시는 `await` 전에 `isPaying`을 세워서 틈에 다른 결제가 아예 못 들어오게 한다.

A를 먼저 보내고 B를 10ms 뒤에 보냈다. `async let` 두 줄로 동시에 보내면 누가 먼저 들어갈지 정해져 있지 않아서, 표를 읽기 쉽게 순서를 고정했다. 200번 돌려서 결과는 매번 같았다.

| 방법 | 80원 두 번 | 30원 두 번 | 80원 두 번, A 승인 실패 |
|---|---|---|---|
| 먼저 빼두기 | <span style="color:#2e9e4f">잔액 20, B 거절</span> | <span style="color:#2e9e4f">잔액 40, 둘 다 완료</span> | <span style="color:#d29922">잔액 100, A 되돌림, B 거절</span> |
| 다시 확인하기 | <span style="color:#d29922">잔액 20, B는 승인 받은 뒤 거절</span> | <span style="color:#2e9e4f">잔액 40, 둘 다 완료</span> | <span style="color:#2e9e4f">잔액 20, B 완료</span> |
| 진행 중 표시 | <span style="color:#2e9e4f">잔액 20, B 거절</span> | <span style="color:#d29922">잔액 70, B는 진행 중이라 거절</span> | <span style="color:#d29922">잔액 100, B는 진행 중이라 거절</span> |

세 방법 모두 잔액이 음수가 되는 건 막았다. 대신 노란 칸처럼 각자 단점이 있다.

- 먼저 빼두기: 승인이 끝나기 전부터 잔액이 빠져 있다. 그래서 결국 실패할 A 때문에 B가 거절됐다. A가 되돌린 뒤의 잔액 100이면 B도 결제할 수 있었다.
- 다시 확인하기: 거절이 승인 뒤에 일어난다. B는 카드사 승인까지 받아놓고 거절됐다. 실제 결제라면 받아둔 승인을 취소하는 처리가 따로 필요하다.
- 진행 중 표시: 가장 단순하지만, 잔액이 충분한 결제도 진행 중이면 튕긴다. 30원 두 번이면 둘 다 결제할 수 있었는데 B가 거절됐다.

시간 순서로 놓고 보면 더 잘 보여서 80원 두 번 상황을 타임라인으로 만들었다. 네 경우 모두 B는 A의 `await` 틈에 들어온다. 방법에 따라 달라지는 건 B가 들어와서 무엇을 보느냐다.

<iframe
  src="/assets/demo/wallet_reentrancy_simulator.html"
  width="100%"
  height="450px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

어느 쪽이 정답이라기보다, 두 번째 요청을 어떻게 다뤄야 하는지에 따라 고른다. 진행 중 표시는 두 번째 요청을 버려도 되는 일, 예를 들어 한 번만 실행돼야 하는 종료 처리나 저장에 잘 맞는다.

값을 계산하지 않는 경우도 같은 방향으로 막았다.

```swift
actor ImageLoader {
    var cache: [String: String] = [:]
    var inFlight: [String: Task<String, Never>] = [:]

    func image(_ url: String) async -> String {
        if let cached = cache[url] { return cached }
        if let running = inFlight[url] { return await running.value }   // 이미 받는 중이면 그걸 기다림

        let task = Task { await download(url) }
        inFlight[url] = task                                            // await 전에 "받는 중" 기록
        let image = await task.value
        cache[url] = image
        inFlight[url] = nil
        return image
    }
}

@MainActor
final class SearchViewModel {
    var results = ""
    var latestQuery = ""

    func search(_ query: String) async {
        latestQuery = query                                  // await 전에 "내가 최신" 기록
        let found = await fetch(query)
        guard query == latestQuery else { return }           // 돌아와서 아직 최신인지 확인
        results = found
    }
}
```

| 경우 | 막기 전 | 막은 뒤 |
|---|---|---|
| 같은 이미지를 동시에 두 번 요청 | <span style="color:#e5534b">다운로드 2번</span> | <span style="color:#2e9e4f">다운로드 1번, 두 요청이 같은 결과를 받음</span> |
| 'a' 입력 후 바로 'ab', 'a' 응답이 더 늦게 옴 | <span style="color:#e5534b">화면에 'a' 결과가 남음</span> | <span style="color:#2e9e4f">화면에 'ab' 결과</span> |

진행 중인 `Task`를 저장해두는 방법은 WWDC21 세션의 `ImageDownloader`와 같은 모양이다. 거기서는 캐시에 "받는 중"(`inProgress(Task)`)과 "받음"(`ready(Image)`)을 같이 넣는다. 20번 돌려서 두 경우 모두 매번 같았다.

---

### 네트워크 이슈가 생긴다면?

실제 결제라면 승인은 네트워크를 탄다. 네트워크 이슈로 승인이 늦어지면 `await` 틈도 그만큼 길어진다. 그래서 승인 시간을 50, 200, 800ms로 바꿔가며 AI를 통해 테스트해봤다. 잔액 300원에 80원 결제 10건이 1초 동안 무작위로 들어오고, 승인 실패율은 20%다. 같은 도착 순서 20세트를 세 방법에 똑같이 돌린 합계다.

| 방법 | 늘어나는 문제 | 50ms | 200ms | 800ms |
|---|---|---|---|---|
| 먼저 빼두기 | 결제될 수 있었는데 거절됨 | 3 | 19 | <span style="color:#d29922">70</span> |
| 다시 확인하기 | 승인 후 거절 (취소 필요) | 16 | 37 | <span style="color:#e5534b">98</span> |
| 진행 중 표시 | 잔액이 충분한데 튕김 | 46 | 130 | <span style="color:#e5534b">168</span> |

세 방법 모두 잔액이 음수가 되지는 않았지만, 틈이 길어질수록 각자의 단점이 커졌다. 다시 확인하기는 결제 건수는 끝까지 지켰지만 승인 후 거절이 가장 많이 늘었다. 실제라면 이 건마다 승인 취소 요청을 또 보내야 하고, 그 요청도 네트워크를 타니 실패할 수 있다. 진행 중 표시는 완료된 결제가 50ms에서는 60건이었는데 800ms에서는 26건까지 줄었다. 먼저 빼두기는 결제될 수 있었는데 거절되는 경우가 늘었지만, 되돌리는 게 지갑 안에서 끝나서 가장 무난했다.

---

### 정리하면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-actor인데-왜-상태가-꼬이나/reentrancy_fixes.png)

막는 방법은 모두 "틈 너머로 가정을 들고 가지 않는다"는 한 가지로 모인다.

- 틈 앞에서 끝내기: 확인과 변경을 `await` 전에 한 번에 끝낸다 (먼저 빼두기)
- 틈 뒤에서 다시 보기: 돌아와서 가정이 아직 맞는지 확인한다 (다시 확인하기, 최신 요청 확인)
- 틈에 못 들어오게 하기: `await` 전에 "진행 중"을 기록해서 두 번째 요청을 막거나 기다리게 한다 (진행 중 표시, 진행 중인 `Task` 기다리기)

어느 방법이든 확인과 변경은 `await` 없이 붙어 있어야 하고, "진행 중"이나 "최신" 같은 기록은 `await` 전에 남겨야 한다. 기록을 `await` 뒤에 남기면 그 사이가 또 틈이 된다. 진행 중 표시를 세우기 전에 `await`를 하나 넣어봤더니, 두 결제가 둘 다 확인을 통과해서 잔액이 다시 -60이 됐다(10번 모두). 그리고 두 번째 요청을 거절할지, 기다리게 할지, 나중에 다시 확인할지에 따라 단점이 달라진다.

---

## 4. RunWay 사례로 다시 보기

이 글을 시작하게 한 RunWay 사례들을 이 글의 기준으로 다시 봤다.

---

### 리셋 문제는 재진입이 아니었다

[이전글](https://haroldfromk.github.io/posts/RunningProject-(10)/){:target="_blank"}의 리셋 문제는 이랬다. 러닝을 끝내면 `resetState()`가 actor의 `reset()`을 `Task`로 띄우고 바로 돌아왔다.

```swift
func resetState() {
    // 생략
    Task {  // 완료를 기다리지 않음
        await runningCenter.reset()
    }
}
```

빠르게 다시 시작하면 `reset()`보다 `processLocation()`이 먼저 actor에 들어가서, 이전 러닝의 `lastLocation`으로 거리가 튀었다. 그때는 `resetState()`를 `async`로 바꾸고 `await runningCenter.reset()`으로 끝날 때까지 기다리게 해서 고쳤다.

비슷해 보여서 이 글을 시작했지만, 따져보면 재진입은 아니다. `reset()`은 안에 `await`가 없는 메서드라 도중에 누가 끼어들 틈이 없다. 꼬인 곳은 actor 안이 아니라 부르는 쪽이다. `Task { }`는 리셋을 시작만 시켜두고 바로 돌아오기 때문에, 그 뒤의 코드가 리셋보다 먼저 actor에 들어갈 수 있다.

모양을 줄여서 돌려봤다. MainActor인 뷰모델에서 리셋을 부르고 바로 위치 처리를 부르는 경우다. 500번씩 두 번 돌려서 결과는 매번 같았다.

| 부르는 방식 | 먼저 actor에 들어간 쪽 |
|---|---|
| `Task { await reset() }` 뒤에 바로 `await processLocation()` | <span style="color:#e5534b">processLocation, 이전 값이 남은 채로 (500번 모두)</span> |
| `await reset()` 뒤에 `await processLocation()` (고친 방법) | <span style="color:#2e9e4f">reset (500번 모두)</span> |

`Task`로 띄운 리셋은 지금 실행 중인 흐름이 한 번 멈춘 뒤에야 시작된다. 그 사이에 바로 이어서 부른 `processLocation()`이 먼저 들어간 것이다.

재진입과 나란히 놓으면 차이가 보인다.

| | 재진입 | RunWay 리셋 |
|---|---|---|
| 꼬인 곳 | actor 메서드 안의 `await` 틈 | 부르는 쪽 (기다리지 않고 넘어감) |
| 믿은 것 | 기다리기 전과 세상이 그대로다 | 리셋이 이미 끝났다 |
| 해결 | 확인과 변경을 `await` 없이 붙이기 등 | `await`로 끝날 때까지 기다리기 |

꼬인 자리는 달라도, 둘 다 사실이 아닌 걸 믿고 다음 코드를 실행했다는 점은 같다. 그래서 비슷하게 느껴졌던 것이다.

---

### 진행 중 표시는 이미 쓰고 있었다

[이전글](https://haroldfromk.github.io/posts/RunningProject-(25)/){:target="_blank"}에서는 워치와 아이폰이 같이 달릴 때 원격 종료 이벤트가 두 번 들어올 수 있는 구조를 찾았다. 그대로 두면 저장과 리셋이 두 번 실행될 수 있어서 가드를 하나 추가했다.

```swift
if result.stopOrigin == .remote {
    guard !self.isHandlingRemoteStop else { return }
    self.isHandlingRemoteStop = true
    Task {
        await self.flightActivityService.endActivity()
        await self.saveRunningData()
        await self.resetState()
        self.isHandlingRemoteStop = false
    }
}
```

`RunViewModel`은 `@MainActor`다. 앞의 예시 코드로 확인하기에서 본 것처럼 MainActor에서도 `await` 틈에 두 번째 이벤트 처리가 끼어들 수 있다. 가드가 없으면 첫 번째 이벤트가 `endActivity()`나 `saveRunningData()`를 기다리는 사이에 두 번째 이벤트가 들어와서, 저장과 리셋이 두 번 실행될 수 있다.

이 가드는 3번 섹션의 진행 중 표시와 같은 모양이다. 표시를 `Task` 안의 `await`보다 먼저 세웠으니, 두 번째 이벤트는 틈에 들어와도 표시를 보고 바로 돌아간다. 진행 중 표시의 단점은 두 번째 요청을 버린다는 것이었는데, 여기서는 그게 원하는 동작이다. 종료는 한 번만 처리하면 되기 때문이다.

---

### await에서 actor를 비워주니 멈춰버리지 않았다

[이전글](https://haroldfromk.github.io/posts/RunningProject-(11)/){:target="_blank"}에서 일시정지 감지 방법을 두고 두 AI의 의견이 갈렸다. 한쪽은 뷰모델 타이머에서 매초 `await runningCenter.checkPauseTimeout()`을 부르면 actor가 붙잡혀 있어서 서로 기다리다 멈춰버릴 수 있다고 했고, 다른 쪽은 `await`를 만날 때마다 actor를 비워주기 때문에 그럴 일이 없다고 반박했다.

반박한 쪽이 말한 게 바로 재진입이다. 1번 섹션에서 본 것처럼 Swift가 재진입을 기본으로 둔 이유가 서로 기다리다 멈춰버리는 걸 막기 위해서였다. 대신 그 틈으로 이 글에서 본 끼어들기가 생긴다. 그때는 결국 actor를 매초 부르지 않고, 뷰모델이 마지막으로 데이터를 받은 시각을 직접 기록하는 방식으로 정리했다.

---

### 정리하면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-24-Deep-Dive-actor인데-왜-상태가-꼬이나/reentrancy_runway_cases.png)

| RunWay 사례 | 이 글로 다시 보면 |
|---|---|
| 리셋이 늦게 돼서 거리가 튐 | 재진입이 아니라, 부르는 쪽이 기다리지 않아서 생긴 순서 문제 |
| 원격 종료 이벤트가 두 번 들어옴 | MainActor에서 생길 수 있는 재진입을 진행 중 표시로 막은 사례 |
| 매초 actor를 부르면 멈춰버리나 | 재진입 덕분에 멈추지 않는다. 대신 끼어들기를 조심해야 한다 |

---

## 정리

- actor 재진입은 [SE-0306](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md){:target="_blank"}에 actor가 처음 들어올 때부터 있던 규칙이다. actor 메서드가 `await`에서 멈추면, 그 메서드가 끝나기 전에 다른 작업이 같은 actor에 먼저 들어올 수 있다
- actor는 두 곳이 같은 값을 동시에 건드리는 data race는 막아주지만, 순서에 따라 결과가 달라지는 race condition까지 막아주지는 않는다. 스레드가 하나뿐인 MainActor에서도 똑같이 생기고, 빌드는 에러도 경고도 없이 통과한다
- 문제는 틈의 길이가 아니라 틈이 생긴다는 것 자체다. 다른 actor에서 값 하나 읽어오는 짧은 `await`에서도 1000번 중 몇 번씩 끼어들었고, 가끔만 터지니 찾기가 더 어렵다
- 꼬이는 조건은 `await`가 있느냐가 아니라, `await` 뒤의 코드가 기다리기 전과 세상이 그대로라고 믿느냐다. 확인한 잔액, 변수에 담아둔 값, "캐시에 없었다", "내 응답이 최신이다"가 모두 그런 믿음이었다
- 막는 방법은 확인과 변경을 `await` 없이 붙여두는 것이다. 먼저 빼두기, 다시 확인하기, 진행 중 표시 모두 잔액이 음수가 되는 건 막았지만, 두 번째 요청을 어떻게 다루느냐에 따라 단점이 달랐다
- "진행 중"이나 "최신" 같은 기록은 `await` 전에 남겨야 한다. `await` 뒤에 남기면 그 사이가 또 틈이 된다
- 네트워크 이슈로 승인이 늦어지면 틈도 길어져서 단점이 커진다. 다시 확인하기는 승인 후 거절이, 진행 중 표시는 튕기는 결제가 크게 늘었고, 먼저 빼두기가 가장 무난했다
- Swift가 재진입을 허용한 건 actor끼리 서로 기다리다 멈춰버리는 걸 막기 위해서다. 대신 그 틈으로 끼어들기가 생긴다
- RunWay의 리셋 문제는 재진입이 아니라, `Task`로 띄우고 기다리지 않아서 생긴 순서 문제였다. 원격 종료 이벤트를 막은 `isHandlingRemoteStop`은 MainActor에서 생길 수 있는 재진입을 진행 중 표시로 막은 사례였다
