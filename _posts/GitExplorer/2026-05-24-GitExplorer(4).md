---
title: GitExplorer (4)
writer: Harold
date: 2026-05-24 08:06
categories: [Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

## Day 4: 자동 갱신 & 브릿지
### 미션 (Task)

1. **자동으로 새로고침하기**
   - 사용자가 직접 새로고침을 누르지 않아도 **정해진 주기에 맞춰 스스로 최신 상태 데이터를 다시 불러오는** 심장 박동 같은 백그라운드 스트림을 구축할 것

2. **연타 방지하기**
   - 유저가 수동 새로고침을 연타할 경우를 대비하여, 무수한 시도에도 **일정 시간 내에는 단 한 번의 요청만 서버로 넘어가도록** 입력 폭주를 제어할 것

3. **모아서 한번에 저장하기**
   - 갱신 주기에 따라 들어오는 데이터를 그때그때 저장하지 않고, 일정 시간 동안 모인 데이터들을 하나의 덩어리로 묶어 **한 번에 일괄 저장**하여 자원 낭비를 막을 것

4. **async/await 연결하기**
   - 반응형 스트림 기반의 비동기 코드 결과를 최신 비동기 동시성 구조(`async/await`)로 안전하게 포장하여 **두 기술 간의 데이터 호환성**을 확보할 것

5. **화면 종료 시 정리하기**
   - 화면이 종료되거나 메모리에서 해제될 때 뒤에서 돌아가고 있는 타이머나 네트워크 대기열 등의 모든 연결선을 확실하게 절단하여 **메모리 누수를 완벽하게 차단**할 것

---

### 1. 자동으로 새로고침하기

지금 `FavoritesView`에는 "자동 갱신 중", "다음 갱신까지 N초" UI가 있는데 실제로는 아무것도 안 하고 있다.

자동 갱신의 의미는 `UserDefaults`에 저장된 `login` 배열을 가져와서, 각 `login`으로 `/users/{login}` API를 호출해 최신 `publicRepos`, `followers` 정보를 업데이트하는 것이다.

우선 크게 2개로 나눠보면

1. api요청
2. x초마다 refresh

이렇게 나눌 수 있을듯하다.

---

#### 1. api 요청
##### ViewModel 작성

FavoriteViewModel 에서 해당 내용을 만들면 될 것 같다.

핵심은 내부저장소(UserDefaults)에 저장된 값을 View에 사용하기위해 `names`라는 배열에 저장하는데, 이 names 배열값에 있는 유저의 아이디를 통해 API요청을 하면 된다.

사실 api의 요청의경우 이미 이전에 `GitHubNetworkService`에서 `fetchGitUser`를 살려뒀기에 이걸 사용하면 된다.

[이전글](https://haroldfromk.github.io/posts/Final-(8)/){:target="_blank"}에서 한번 써본적이 있어서 이걸 기억으로 해보았다.

---

###### Publisher 배열 만들기

`names.map`으로 각 `login`마다 `fetchGitUser`를 호출해서 Publisher를 만들었다. 이 시점엔 아직 실행된 게 아니라 "이런 Publisher들이 있다"는 배열 상태다.

```swift
let publisher = names.map { name in
    self.service.fetchGitUser(user: name)
        .replaceError(with: [])
}
// publisher의 타입: [AnyPublisher<[GithubUser], Never>]
```

---

###### Merge vs MergeMany

`Publishers.Merge`는 2개 Publisher를 합칠 때 쓴다.

```swift
Publishers.Merge(publisherA, publisherB)
```

`Publishers.MergeMany`는 배열처럼 개수가 정해지지 않은 여러 Publisher를 합칠 때 쓴다.

```swift
Publishers.MergeMany(publisher)  // [Publisher] 배열을 받음
```

지금처럼 즐겨찾기 목록이 몇 명인지 모르는 상황에서는 `MergeMany`가 맞다.

`collect()`는 `MergeMany`로 합쳐진 스트림에서 방출되는 값들을 전부 모아서 한 번에 배열로 내보낸다. 그래서 최종 타입이 `[[GithubUser]]`가 되는 것이다.

에러가 발생하면 `replaceError(with: [])`로 빈 배열로 대체되기 때문에 최종 결과가 `[[], [GithubUser], []]` 이런 식으로 나올 수 있다. 특정 유저 요청만 실패해도 나머지 결과는 정상적으로 가져온다.

```swift
func fetchFavoriteData() -> AnyPublisher<[[GithubUser]], Never>{
    let publisher = names.map { name in
        self.service.fetchGitUser(user: name)
            .replaceError(with: [])
    }
    return Publishers.MergeMany(publisher)
        .collect()
        .eraseToAnyPublisher()
}
```

---

###### 타입 에러

처음엔 반환 타입을 `AnyPublisher<[GithubUser], Never>`로 했는데 타입 에러가 발생했다.

```swift
Cannot convert return expression of type 'AnyPublisher<Publishers.Collect<Publishers.MergeMany<AnyPublisher<[GithubUser], any Error>>>.Output, ...>' to return type 'AnyPublisher<[GithubUser], Never>'
```

`collect()`가 각 유저 결과를 배열로 묶어서 `[[GithubUser]]`가 되는데, 반환 타입을 `[GithubUser]`로 선언했으니 타입이 안 맞는 거였다. `AnyPublisher<[[GithubUser]], Never>`로 바꿔주니 해결됐다.

---

###### 구독 연결

구독은 View에서 직접 하지 않고 ViewModel에서 처리하도록 했다.

MVVM에서 View는 ViewModel이 하는 일을 몰라야 하는 관계라서, 굳이 View에서 구독을 형성하면서 ViewModel이 해야 하는 기능을 가져올 필요가 없기 때문이다.
즉  관심사의 분리(Separation of Concerns)를 하는것
(View는 UI 렌더링, ViewModel은 비즈니스 로직, 이렇게 역할을 분리하는 원칙.)

```swift
func getData() {
    fetchFavoriteData().sink { completion in
        if case .failure(let error) = completion {
            print(error)
        }
    } receiveValue: { result in
        self.user = result
        print(self.user)
    }.store(in: &cancellables)
}
```

기능 확인을 위해 툴바 버튼에 연결했다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            viewModel.getData()
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }
}
```

값을 가져오는 것을 확인했다.

---

###### 2중 배열의 평탄화 작업

일단은 함수를 구현하기위해서 [[]] 이런식으로 이중배열의 구조를 하고있는데, 이걸 평탄화하여 [] 이렇게 1차원 배열로 바꾸는 과정을 적어본다.

이건 `평탄화`단어에 포커스를 둔다면 어떤 Operator가 필요한지 바로 감이온다.

바로 `FlatMap`이다.

[이전글](https://haroldfromk.github.io/posts/High-order-function/){:target="_blank"}에서도 간단하게 언급을 한적이 있다.

핵심은 `receiveValue`에서 받는 `result`가 `[[GithubUser]]` 타입이라는 것이다. View에 보여줄 `users`는 `[GithubUser]`여야 하니까, `result` 안에서 2차원 배열을 1차원으로 평탄화해야 한다.

처음엔 이렇게 시도했다.

```swift
func getData() {
   fetchFavoriteData()
      .receive(on: DispatchQueue.main)
      .sink { completion in
            if case .failure(let error) = completion {
               print(error)
            }
      } receiveValue: { [weak self] result in
            result.flatMap { user in
               self.users.append(contentsOf: user)
            }
      }.store(in: &cancellables)
}
```

근데 `flatMap`에 반환값이 없는 클로저를 넣으면 deprecated 경고가 뜬다. `flatMap`은 각 요소를 변환해서 새로운 값을 반환하는 함수인데, `append`는 배열에 추가만 하고 `Void`를 반환하니까 `flatMap`의 용도와 맞지 않아서 경고가 뜨는 것이다.

그러면 `forEach`를 쓰면 되지 않나 싶어서 생각해봤는데

```swift
result.forEach { user in
    self.users.append(contentsOf: user)
}
```

이건 동작은 하지만 반복문으로 배열을 순회하면서 하나씩 추가하는 방식이라 Combine스럽지 않다.

결국 `flatMap`의 본래 목적인 평탄화를 활용하면 한 줄로 해결된다.

```swift
self.users = result.flatMap { $0 }
```

`append`로 하나씩 넣는 과정 없이, `[[GithubUser]]`가 `[GithubUser]`로 평탄화된 배열 자체가 바로 `users`에 들어간다.

즉, 
`result.flatMap { $0 }`의 결과로
`[[GithubUser]]` → `[GithubUser]` 이렇게 되는 것.

실제로 `print`로 결과를 확인해보니 `names` 배열의 순서와 다르게 출력되는 걸 확인했다.

`MergeMany`는 API 응답이 먼저 오는 순서대로 방출하기 때문에 입력 순서가 보장되지 않는다. 지금은 즐겨찾기 목록 갱신이 목적이라 순서보다 값 자체가 중요하니 그냥 두기로 했다.

---

###### replaceError와 Never의 관계

처음엔 별 생각 없이 `replaceError`를 붙이고, `sink`의 `completion`에서 에러를 출력하는 코드를 같이 작성했다.

```swift
let publisher = names.map { name in
    self.service.fetchGitUser(user: name)
        .replaceError(with: [])  // 에러를 빈 배열로 대체
}

.sink { completion in
    if case .failure(let error) = completion {  // 에러 출력 시도
        print(error)
    }
}
```

근데 이게 잘못된 코드였다.

`replaceError(with: [])`를 쓰는 순간 publisher의 Failure 타입이 `Error`에서 `Never`로 바뀐다. 즉 "절대 실패하지 않는 상태"가 된 거다.

```
AnyPublisher<[GithubUser], Error>
↓ .replaceError(with: [])
AnyPublisher<[GithubUser], Never>
```

그러면서 반환 타입을 `AnyPublisher<[[GithubUser]], Error>`로 선언했을 때 이런 에러가 났다.

```
Cannot convert return expression of type 'AnyPublisher<Array<Array<GithubUser>>, Never>'
to return type 'AnyPublisher<[[GithubUser]], any Error>'
```

`replaceError`로 이미 에러를 처리했는데 반환 타입에 `Error`를 쓰니까 충돌이 난 거였다. `Never`로 바꾸니 해결됐다.

결론적으로 `replaceError`를 쓰면 에러가 이미 처리된 상태라 `sink`의 `completion`에서 `.failure`를 잡으려 해도 절대 오지 않는다.

---

###### 코드 일부 수정 (평탄화 위치 변경)

```swift
// before
func fetchFavoriteData() -> AnyPublisher<[[GithubUser]], Error>{
      let publisher = names.map { name in
         self.service.fetchGitUser(user: name)
      }
      return Publishers.MergeMany(publisher)
         .collect()
         .eraseToAnyPublisher()
   }
   
   func getData() {
      fetchFavoriteData()
         .receive(on: DispatchQueue.main)
         .sink { completion in
               if case .failure(let error) = completion {
                  print(error)
               }
         } receiveValue: { [weak self] result in
               self?.users = result.flatMap { $0 }
         }.store(in: &cancellables)
   }

// after
func fetchFavoriteData() -> AnyPublisher<[GithubUser], Error>{
   let publisher = names.map { name in
      self.service.fetchGitUser(user: name)
   }
   return Publishers.MergeMany(publisher)
      .collect()
      .map({ result in
            result.flatMap { $0 }
      })
      .eraseToAnyPublisher()
}

func getData() {
   fetchFavoriteData()
      .receive(on: DispatchQueue.main)
      .sink { completion in
            if case .failure(let error) = completion {
               print(error)
            }
      } receiveValue: { [weak self] result in
            self?.users = result
      }.store(in: &cancellables)
}
```

`fetchGitUser`가 `AnyPublisher<[GithubUser], Error>`로 1차원 배열을 반환하는데, `fetchFavoriteData`만 `[[GithubUser]]`로 반환하면 타입이 맞지 않아서 어색하다.

그래서 평탄화 과정을 `getData`에서 처리하는 게 아니라 `fetchFavoriteData` 내부에서 처리해서 반환 타입을 `[GithubUser]`로 통일했다. 이렇게 하면 `getData`에서 받을 때 그냥 `self?.users = result` 한 줄로 끝난다.

---

#### 2. x초마다 refresh 하기.

사실 이건 `Timer`를 사용하면된다.

즉, 위에서 만든 `getData()`를 Timer를 이용해 지정된 시간마다 호출하는 개념으로 사용하면 된다는것.

---

##### 1. ViewModel 작성

```swift
func refreshData() {
   Timer.publish(every: 15.0, on: .main, in: .default)
      .autoconnect()
      .print()
      .sink { _ in
            self.getData()
      }.store(in: &cancellables)
}
```

우선은 이렇게 작성을 하고

onAppear에 해당 메서드를 실행하게 해서 작동확인을 해본다.

```swift
receive value: (2026-05-26 16:25:21 +0000)
receive value: (2026-05-26 16:25:36 +0000)
receive value: (2026-05-26 16:25:51 +0000)
```

이렇게 15초마다 값을 가져온다는걸 확인했다.

---

###### 구독 중첩 문제 해결하기

하지만 view를 다른걸 보고 다시 FavoriteView로 들어가면

새롭게 구독이 생성되는걸 확인했다.

즉 다른 view로 넘어가게 되면 구독이 끊겨야 하는데 계속 구독이 중첩되어 생겨난다는 것.

이렇게되면 api 호출이 과도하게 발생하기 때문에 네트워크 문제도 발생할수있고 ui가 갑자기 여러번 바뀌는 문제가 생길 수 있다.

우선은 아래와 같이 코드를 작성해 보았다.

```swift
func refreshData(isRefresh: Bool) {
   let timer = Timer.publish(every: 10.0, on: .main, in: .default).autoconnect()
   if isRefresh {
      timer
            .print()
            .sink { _ in
               self.getData()
            }.store(in: &cancellables)
   } else {
      timer.upstream.connect().cancel()
   }
}
```

하지만 

`timer.upstream.connect().cancel()`이 작동을 하지 않는지

구독이 계속 유지되는걸 확인했다.

---

우선 타이머가 멈추지 않았던 근본적인 원인은

바로 타이머를 함수안에서 생성하기 때문이다.

그래서 함수밖에서 애초에 viewmodel이 생성이 될때 타이머를 만들도록 밖을 로 빼주었다.

```swift
func refreshData(isRefresh: Bool) {
   if isRefresh {
      timer
            .print()
            .sink { _ in
               self.getData()
            }
            .store(in: &cancellables)
   } else {
      timer.upstream.connect().cancel()
   }
}
```
그렇게 해서 실행을 하니 타이머 자체는 작동이 잘되었다.

---

하지만 타이머가 작동이 잘되어 기능상으로는 괜찮은걸로 보여도.

`onappear`를 통해 계속해서 FavoriteView로 접근시엔 sink가 계속 실행되어 구독이 계속해서 생기는 문제가 있다.

즉

```
timer (1개)
    ↓
sink #1
sink #2
sink #3
```

이런식으로 되는 것.

그래서 고민을 하다가 별도의 `timerCancellables`를 만들어서 Timer만 구독관리를 하도록 했다.

`cancellables`에 같이 넣으면 즐겨찾기 추가/삭제 구독까지 같이 끊겨버리기 때문에 분리하는 게 맞다고 판단했다.

```swift
func refreshData(isRefresh: Bool) {
    if isRefresh {
        timer
            .sink { _ in
                self.getData()
            }
            .store(in: &timerCancellables)
    } else {
        timerCancellables.removeAll()
    }
}
```

이렇게 하면

```swift
receive subscription: // 생략
request unlimited
receive value: (2026-05-24 08:24:37 +0000)
receive cancel
```

이렇게 구독이 형성되고 끊기는걸 알 수 있다.

다른 방법으로는 `Set` 대신 `AnyCancellable?` 단일 변수로 관리하는 방법도 있다.

```swift
private var timerCancellable: AnyCancellable?

func refreshData(isRefresh: Bool) {
   if isRefresh {
      timerCancellable = timer
         .sink { [weak self] _ in
            self?.getData()
         }
   } else {
      timerCancellable?.cancel()
      timerCancellable = nil
   }
}
```

새 값을 할당하면 이전 구독이 자동으로 해제되는 방식이라, `removeAll()` 없이도 중첩이 생기지 않는다. 취향에 따라 선택하면 된다.

다만 지금은 구독 하나만 관리하므로 `AnyCancellable`을 사용해주었다.

그리고 혹시 모를 중복 구독을 방지하기 위해 `guard`를 추가했다.

```swift
if isRefresh {
   guard timerCancellable == nil else { return }
   //생략
}
```

예를 들어 빠르게 탭을 여러 번 전환하거나, 예상치 못한 경로로 `refreshData(isRefresh: true)`가 연속으로 호출되는 상황에서 이미 구독이 살아있으면 새로 만들지 않고 바로 리턴한다. `timerCancellable`이 `nil`일 때만 구독을 생성하니까 중첩이 생길 여지가 없다.

---

### 2. 연타 방지하기

- 유저가 수동 새로고침을 연타할 경우를 대비하여, 무수한 시도에도 **일정 시간 내에는 단 한 번의 요청만 서버로 넘어가도록** 입력 폭주를 제어할 것

---

이건 throttle을 사용해서 컨트롤 하라는 것.

우선

```swift
var throttleSubject = PassthroughSubject<Void, Never>()

init () {
   // 생략
   
   throttleSubject
      .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: false)
      .print()
      .sink { _ in
      }.store(in: &cancellables)
}

func refreshDataThrottled() {
   throttleSubject.send(getData())
}
```

이렇게 해서 테스트를 했더니

throttle이 안먹는걸 확인했다.

throttle은 sink 내부에서 설정한것을 10초동안 block을 하는것이므로

getdata를 무자비하게 send를 하면 무자비하게 누른만큼 값을 받게 된다.

그래서 해법은

```swift
throttleSubject
   .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: false)
   .print()
   .sink { _ in
         self.getData()
   }.store(in: &cancellables)

func refreshDataThrottled() {
   throttleSubject.send()
}
```

이렇게 해주면 된다.

하지만 여러번 누르면 10초뒤에 한번 더 값을 출력하기에 뭔가 이상해서 플레이그라운드로 테스트를 해보았다.

```swift
시작 시간: 2026-05-24 19:33:19 +0000

🟢 [latest: true]  방출: 1 (시간: 2026-05-24 09:33:19 +0000)
🔴 [latest: false] 방출: 1 (시간: 2026-05-24 09:33:19 +0000)
[0.5초] 값 10 주입
[1.0초] 값 20 주입
[1.5초] 값 30 주입 (연타 끝)
🟢 [latest: true]  방출: 30 (시간: 2026-05-24 09:33:21 +0000)
🔴 [latest: false] 방출: 10 (시간: 2026-05-24 09:33:21 +0000)
```

이렇게 되는걸 확인했다.

결론은

- latest: false — 구간 안에서 첫 번째 값 방출
- latest: true — 구간 안에서 마지막 값 방출

이거였다.

아래 시뮬레이터를 통해 확인을 해보면 좋을 듯.

<iframe 
    src="/assets/demo/throttle-simulator.html" 
    width="100%" 
    height="360" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>

---

### 3. 모아서 한번에 저장하기

- 갱신 주기에 따라 들어오는 데이터를 그때그때 저장하지 않고, 일정 시간 동안 모인 데이터들을 하나의 덩어리로 묶어 **한 번에 일괄 저장**하여 자원 낭비를 막을 것

---

지금 구조에서는 `MergeMany`로 전체 즐겨찾기 유저를 한 번에 가져와서 배열로 묶기 때문에, 데이터가 하나씩 순서대로 방출되는 구조가 아니다. 그래서 "모아서 저장"이라는 개념을 자연스럽게 끼워넣기가 어렵다.

만약 유저를 하나씩 순차적으로 방출하는 구조였다면 `collect(.byTime:)`으로 일정 시간 동안 모아서 한 번에 저장하는 게 가능했을 것이다.

아래 코드는 `fetchFavoriteData`를 5초 동안 결과 값을 모아서 방출하는 내용이다.

```swift
let nameSubject = PassthroughSubject<String, Never>()
var cancellables = Set<AnyCancellable>()

func setupBatchSubscriber() {
   nameSubject
      .flatMap { name in
         self.service.fetchGitUser(user: name)
               .catch { _ in Just([]) }
      }
      .collect(.byTime(DispatchQueue.main, .seconds(5)))
      .map { $0.flatMap { $0 } }
      .sink { [weak self] combinedUsers in
         if !combinedUsers.isEmpty {
               self?.saveToLocalDatabase(users: combinedUsers)
         }
      }
      .store(in: &cancellables)
}

func triggerBatchProcessing() {
    let names = ["google", "apple", "kakao", "naver"]
    
    for name in names {
        nameSubject.send(name)
    }
}
```

아무래도 여기선 어거지로 구현하다보니 send 부분이 그렇게 자연스럽지 않다.

무튼 핵심을 보면

`collect(.byTime:)`은 지정한 시간 동안 방출된 값들을 배열로 묶어서 한 번에 내보내는 오퍼레이터다.

매번 저장하지 않고 일정 시간 단위로 묶어서 처리하기 때문에 저장 횟수 자체를 줄일 수 있다.

지금 구조에서는 개념 이해 차원에서만 짚고 넘어가도록 한다.

`collect(.byTime)` vs `collect(count)` 시뮬레이터 참고.

`bytime`과 `count`의 차이는 방출기준을 시간으로 할건지, 개수로 할건지의 차이다.

<iframe 
    src="/assets/demo/combine-collect-bytime.html" 
    width="100%" 
    height="380" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>

---

### 4. async/await 연결하기

- 반응형 스트림 기반의 비동기 코드 결과를 최신 비동기 동시성 구조(`async/await`)로 안전하게 포장하여 **두 기술 간의 데이터 호환성**을 확보할 것

---

지금까지 Combine Publisher로 비동기 처리를 해왔는데, 이 흐름 자체가 `async/await`와 개념적으로 같은 문제를 푸는 방식이다.

Combine Publisher를 `async/await`로 브릿지하면 같은 로직을 다른 방식으로 표현할 수 있다. `fetchGitUser`가 Combine Publisher를 반환하는데, 이걸 `async` 함수로 감싸면 `await`로 결과를 기다리는 구조로 바꿀 수 있다.

#### fetchGitUser를 async/await로 바꾸기

[이전글](https://haroldfromk.github.io/posts/Async_await-(6)/){:target="_blank"}을 참고해서 바꿔주었다.

이때 특이점이라면 async/await를 사용하기에 더이상 Return Type에 Publisher가 들어가지 않는다는 것

```swift
func asyncFetchGitUser(user: String) async throws -> [GithubUser] {
    let url = URL(string: "https://api.github.com/users/\(user)")!
    let header = ["Authorization" : "\(Constants.token)"]
    
    var request = URLRequest(url: url)
    request.allHTTPHeaderFields = header
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    let decodedData = try? JSONDecoder().decode(GithubUser.self, from: data)
    
    guard let user = decodedData else { return [] }
    
    return [user]
}
```

일단은 이렇게 했는데, `try?`는 에러가 발생하면 예외를 던지는 대신 결과를 `nil`로 만든다.

즉 디코딩에 실패하면 `decodedData`가 `nil`이 되고, 어떤 에러가 발생했는지는 알 수 없다. 
그래서 `guard let`으로 옵셔널 바인딩을 해서, `nil`이면 빈 배열을 반환하고 값이 있으면 안전하게 꺼내 쓰는 구조로 작성했다.

그래서 아래 방식으로 바꾸면 디코딩 에러도 `catch`에서 잡아서 확인할 수 있다.

```swift
func asyncFetchGitUser(user: String) async throws -> [GithubUser] {
    let url = URL(string: "https://api.github.com/users/\(user)")!
    let header = ["Authorization" : "\(Constants.token)"]
    
    var request = URLRequest(url: url)
    request.allHTTPHeaderFields = header
    
    let (data, _) = try await URLSession.shared.data(for: request)
    
    do {
        let decodedData = try JSONDecoder().decode(GithubUser.self, from: data)
        return [decodedData]
    } catch {
        print(error)
        return []
    }
}
```

네트워크 에러는 `try await URLSession`에서 던져지고, 디코딩 에러는 내부 `do catch`에서 잡는 구조다.

그리고 이때 `throws`를 빼면 `try await URLSession.shared.data(for:)` 에서 컴파일 에러가 난다. `try`는 에러를 던질 수 있는 함수 앞에 붙이는 키워드인데, 에러를 던지려면 함수 자체가 `throws`로 선언되어 있어야 한다. `throws` 없이 `try`를 쓰면 "이 에러를 어디로 던질 거야?"라고 컴파일러가 물어보는 셈이다.

---

#### fetchFavoriteData에 적용하기


```swift
func asyncFetchFavoriteData() async throws {
   var result = [GithubUser]()
   for name in names {
      let data = try await service.asyncFetchGitUser(user: name)
      result.append(contentsOf: data)
   }
   users = result
}
```

`throws`가 선언되어 있어서 내부에서 에러가 발생하면 잡지 않고 호출한 쪽으로 던진다.

의도는 최종적으로는 `asyncFetchFavoriteData`를 호출하는 쪽에서 에러를 담당하기 위함이다.

그리고 `append(contentsOf:)`를 쓰면 `[GithubUser]`를 배열에 펼쳐서 하나씩 추가하기 때문에 별도의 평탄화 없이 바로 `[GithubUser]`로 쌓인다. 만약 `append`를 쓰면 `[[GithubUser]]`가 되어서 평탄화가 필요했을 것이다.

---

#### view에 적용하기

왜 `asyncGetData`는 없냐고 생각할 수 있는데, 이미 저 함수를 통해 최종값을 담아내기 때문이다.

`getData`를 사용했던 이유는 그전에 `fetchFavoriteData`의 리턴타입이 `AnyPublisher<[GithubUser], Error>`였기 때문에 이걸 최종적으로 걸러내는 작업을 해준것.

```swift
Button {
   Task {
         do {
            try await viewModel.asyncFetchFavoriteData()
         } catch {
            print(error)
         }
   }
}
```

print(users)를 통해 확인했는데 출력이 잘 되는걸 알 수 있다.

SwiftUI의 버튼은 동기 컨텍스트라 `async throws` 함수를 바로 호출할 수 없다. `Task { }`로 감싸서 비동기 컨텍스트를 만들어주고, `throws` 함수를 호출할 때는 `try`가 필요하기 때문에 `do catch`로 에러를 처리했다.

그리고 `MergeMany`와 달리 `for` 루프로 하나씩 순서대로 기다리기 때문에 결과가 `names` 배열 순서대로 담긴다.

이건 우리가 의도한 비동기 작업이 아닌 serial queue이다.

---

#### 비동기 작업으로 전환하기

이부분을 해결하기 위해서 [이전글](https://haroldfromk.github.io/posts/Async_await-(7)/#4-group-tasks){:target="_blank"}을 참고해서 바꿔본다.

`withThrowingTaskGroup`을 사용해서 `for` 루프처럼 순서대로 기다리는 게 아니라, 여러 작업을 동시에 실행하고 완료되는 순서대로 결과를 받는 구조로 바꾼다.

---

##### 1. 코드 작성

```swift
func asyncFetchFavoriteData() async throws {
    var result = [GithubUser]()
    
    try await withThrowingTaskGroup(of: GithubUser.self) { group in
        for name in names {
            group.addTask {
                return try await self.service.asyncFetchGitUser(user: name)
            }
        }
        
        for try await user in group {
            result.append(user)
        }
    }
    
    users = result
    print(users)
}
```

---

##### 2. 에러 발생

`return try await self.service.asyncFetchGitUser(user: name)` 여기서 아래와 같은 에러가 발생했다.

```
Cannot convert value of type '[GithubUser]' to closure result type 'GithubUser'
```

생각해보니 `asyncFetchGitUser`의 리턴타입을 Publisher 때와 그대로 `[GithubUser]`로 두었던 것이다.

사실 이전에 `[GithubUser]`를 리턴했던 건, JSON 출력 결과가 배열에 감싸진 걸로 잘못 보고 한 것 같다.
(근데 덕분에 `flatMap`을 사용했으니 다행일지도?)

리턴타입을 배열로 할 필요가 없어서 `GithubUser` 하나만 반환하도록 수정했다.

```swift
func asyncFetchGitUser(user: String) async throws -> GithubUser {
    // 생략
    return decodedData
}
```

---

##### 3. 구조 이해

구조를 하나씩 뜯어보면:

**`withThrowingTaskGroup(of: GithubUser.self)`**

`of`에는 각 태스크가 반환하는 타입을 적는다. `asyncFetchGitUser`가 `GithubUser`를 반환하니까 `GithubUser.self`가 된다.

**첫 번째 `for` — 태스크 등록**

```swift
for name in names {
    group.addTask {
        return try await self.service.asyncFetchGitUser(user: name)
    }
}
```

`names` 배열을 순회하면서 각 이름마다 태스크를 그룹에 등록한다. 이 시점에 태스크들이 동시에 실행되기 시작한다. 순서대로 기다리는 게 아니라 전부 한꺼번에 출발하는 것이다.

**두 번째 `for` — 결과 수집**

```swift
for try await user in group {
    result.append(user)
}
```

`group`을 순회하면 각 태스크가 반환한 값이 완료되는 순서대로 `user`에 들어온다. 첫 번째 `for`에서 `return`으로 반환한 값이 여기서 자동으로 매핑되는 것이다. 별도로 변수에 담을 필요 없이 `group`을 순회하면 결과가 하나씩 나온다.

이 구조 덕분에 이전의 `for` 루프 방식처럼 순서대로 기다리는 게 아니라 병렬로 실행되면서 `MergeMany`처럼 응답이 먼저 오는 순서대로 `result`에 쌓인다.

---

#### 결론

##### 세 가지 방식 비교

* **Combine (MergeMany)**
  * **실행 방식**: 병렬 (모든 네트워크 요청을 동시에 보냄)
  * **순서 보장**: ❌ (먼저 응답이 오는 순서대로 배열에 들어감)
  * **코드 가독성**: 반응형 스트림 구조라 연산자 체이닝(`collect`, `flatMap`)에 대한 이해가 필요함

* **async/await (순차 / for-in 루프)**
  * **실행 방식**: 직렬 (하나의 요청이 완전히 끝날 때까지 다음 루프가 대기함)
  * **순서 보장**: ✅ (원본 `names` 배열의 인덱스 순서대로 차례차례 담김)
  * **코드 가독성**: 비동기 코드를 단순한 동기식 반복문처럼 위에서 아래로 깔끔하게 읽을 수 있음

* **async/await (TaskGroup)**
  * **실행 방식**: 병렬 (그룹 내에 등록된 모든 자식 Task들이 동시에 실행됨)
  * **순서 보장**: ❌ (Combine `MergeMany`와 마찬가지로 먼저 완료된 자식 Task의 결과부터 배열에 쌓임)
  * **코드 가독성**: 병렬 처리를 수행하면서도 Combine의 복잡한 체이닝 없이 루프 안에서 직관적으로 명확하게 관리됨

---

| | Combine (MergeMany) | async/await (순차) | async/await (TaskGroup) |
|---|---|---|---|
| 실행 방식 | 병렬 | 직렬 | 병렬 |
| 순서 보장 | ❌ | ✅ | ❌ |
| 코드 가독성 | 파이프라인 체이닝 | 동기 코드처럼 읽힘 | 동기 코드처럼 읽힘 |
| 에러 처리 | catch / replaceError | do catch / throws | do catch / throws |



세 방식 모두 최종적으로 즐겨찾기 유저 정보가 `users`에 담긴다는 결과는 같다.

`Combine MergeMany`와 `TaskGroup`은 병렬로 실행되어 응답 순서대로 쌓이고, `async/await` 순차 방식은 `for` 루프로 하나씩 기다리기 때문에 순서가 보장된다.

`async/await`는 비동기 코드를 위에서 아래로 읽히는 동기 코드처럼 작성할 수 있어서 가독성이 높다. Combine 파이프라인에 익숙하지 않은 사람도 흐름을 바로 이해할 수 있다는 장점이 있다.

---

<iframe 
    src="/assets/demo/combine-async-comparison.html" 
    width="100%" 
    height="500" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>


---

#### 주의사항
`Task` 안에서 `try`만 쓰면 에러가 발생해도 컴파일 에러 없이 조용히 사라진다.

```swift
// ❌ 에러가 발생해도 아무 로그도 안 찍힘
Task {
    try await viewModel.asyncFetchFavoriteData()
}

// ✅ do catch로 감싸야 에러를 볼 수 있음
Task {
    do {
        try await viewModel.asyncFetchFavoriteData()
    } catch {
        print(error)
    }
}
```

Swift에서 `Task` 클로저 안에서 던진 에러는 외부로 전파되지 않고 내부에서 삼켜진다. 컴파일러가 경고조차 주지 않기 때문에 실수하기 쉬운 부분이다. `async throws` 함수를 `Task` 안에서 호출할 때는 반드시 `do catch`로 감싸주도록 하자.

---

### 5. 화면 종료 시 정리하기
- 화면이 종료되거나 메모리에서 해제될 때 뒤에서 돌아가고 있는 타이머나 네트워크 대기열 등의 모든 연결선을 확실하게 절단하여 **메모리 누수를 완벽하게 차단**할 것

이건 기존에 형성된 구독을 전부 끊어주라는 것으로

현재 구독 형성은 ViewModel에서 하고 있다.

즉 ViewModel에

```swift
deinit {
   cancellables.removeAll()
}
```

탭뷰 구조라서 `deinit` 직접 확인은 어렵지만, `AnyCancellable`은 메모리에서 해제될 때 자동으로 cancel()을 호출하기 때문에 별도로 removeAll()을 호출하지 않아도 구독이 정리된다.

---

### 6. FavoritesView UI 고도화

1. 카운트다운 타이머 실제 연동
2. `FavoriteRow`에 아바타, repos, followers 표시

---

#### 1. 카운트다운 타이머 연동하기

```swift
@Published var countdown = 30
var timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()


func refreshData(isRefresh: Bool) {
   if isRefresh {
      guard timerCancellable == nil else { return }
      
      timerCancellable = timer
            .sink { [weak self] _ in
               self?.countdown -= 1
               if self!.countdown <= 0 {
                  self?.getData()
                  self?.countdown = 30
               }
            }
   } else {
      timerCancellable?.cancel()
      timerCancellable = nil
      countdown = 30
   }
}
```

이렇게 해주면된다.

30초마다 작동하던 타이머를 1초로 바꾼뒤

우리가 별도의 카운트를 셀 변수를 만들어서 0이 되었을때마다 값을 호출하는 구조이다.

이때 self쪽 `?, !` 가 거슬린다면

```swift
.sink { [weak self] _ in
   guard let self else { return }
   countdown -= 1
   if countdown <= 0 {
      getData()
      countdown = 30
   }
}
```

이렇게 해주면 된다.

그런데 이방법이 더 안전하긴 하다.

self!는 self가 nil이면 크래시가 나기 때문에 위험하고, guard let self로 바꾸면 nil일 때 그냥 리턴하기때문.

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/97e4b119-c9fc-4078-b996-79003f1ad644" />{: width="50%" height="50%"}

---

#### 2. avatar, repos, followers 표시

```swift
struct FavoriteRow: View {
    let user: GithubUser

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatarUrl, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.login)
                    .font(.subheadline).fontWeight(.semibold)
                Text("\(user.publicRepos ?? 0) repos · \(user.followers ?? 0) followers")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
        }
        .padding(.vertical, 2)
    }
}
```

우선 기존의 Row에서 이렇게 ui를 바꾸고 적용하면

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/bc38a33b-ec47-4d5e-84bc-66bf421883b8" />{: width="50%" height="50%"}

현재 처음에 userdefault의 배열에서 즐겨찾기 추가한 유져의 아이디만 가져오는 구조로 되어있다.

```swift
func reloadData() {
   if let savedArray = UserDefaults.standard.array(forKey: "FavoriteNames") as? [String] {
      names = savedArray
   }
}
```

이걸 바꿔주도록 한다.

```swift
func reloadData() async throws {
   if let savedArray = UserDefaults.standard.array(forKey: "FavoriteNames") as? [String] {
      names = savedArray
   }
   
   try await asyncFetchFavoriteData()
}   
```

그리고 view에서는

onAppear 대신 task를 썼다.

```swift
.task {
   do {
      try await viewModel.reloadData()
   } catch {
      print(error)
   }
   isRefresh = true
   viewModel.refreshData(isRefresh: true)
}
```

물론 이렇게 해도 되고

```swift
func reloadData() {
   if let savedArray = UserDefaults.standard.array(forKey: "FavoriteNames") as? [String] {
      names = savedArray
   }
   
   getData()
}

.onAppear {
      viewModel.reloadData()
      isRefresh = true
      viewModel.refreshData(isRefresh: true)
}
```

이렇게 해도 된다.

단지 취향차이.

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/b4c7d16f-e60c-4ce5-8648-84e23c99d2af" />{: width="50%" height="50%"}<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/c33e7f21-06c1-4250-abec-fd481dfdda4e" />{: width="50%" height="50%"}

이렇게 잘 되는걸 알 수 있다.


---

#### 3. GitHub 링크 연결하기

추가 아이디어인데 이것도 구현하면 좋을듯 해서 넣는다.

`htmlUrl`을 가져온 이유가 있었는데, 레포나 유저 프로필을 Safari에서 바로 열 수 있게 링크를 연결하려는 것이었다.

```swift
if selectedSegment == 0 {
      if viewModel.totalProfile.repos.isEmpty {
         EmptyView()
      } else {
         ForEach(viewModel.totalProfile.repos) { repo in
            Link(destination: URL(string: repo.htmlURL)!) {
                  RepoRow(repo: repo)
            }
         }
      }
} else if selectedSegment == 1 {
      ForEach(viewModel.totalProfile.followers) { follower in
         Link(destination: URL(string: follower.htmlUrl)!) {
            UserRow(user: follower)
         }
      }
} else {
      ForEach(viewModel.totalProfile.followings) { following in
         Link(destination: URL(string: following.htmlUrl)!) {
            UserRow(user: following)
         }
      }
}
```

이렇게 Link를 사용해서 연결해주었다.

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/442d9157-5bf6-4c23-aaea-4c0a128c580d" />{: width="50%" height="50%"}

잘 되는걸 알 수있다.

참고로 follow 버튼은 지금은 빼두었다.
(로그인 기능도 넣고 해야할게 많으므로)

---

이렇게 Day 4 도 끝나면서 Git Explorer 앱 만들기도 끝이 났다.

각 일차별로 간단하게 정리해보면:

- **Day 1**: `debounce`, `switchToLatest`, `handleEvents` 등으로 실시간 검색 파이프라인 완성
- **Day 2**: 제네릭 + enum 조합으로 NetworkService 리팩토링, `CombineLatest3`으로 3개 API 동시 호출
- **Day 3**: `PassthroughSubject`로 즐겨찾기 추가/삭제 스트림 처리, `UserDefaults` 연동
- **Day 4**: `MergeMany`로 병렬 API 호출, 타이머 구독 관리, `async/await` 브릿지

처음엔 간단하게 Combine을 좀 숙달하려고 라이트하게 해볼 생각이었는데, 코드를 쓰다보니 이게 생각보다 라이트하지 않다는걸 느꼈다. 그래도 오랜시간 고민하다가 안되면 찾아보고 하면서 완성했는데, 만들고나니 Combine 해동이 잘되고 있다는걸 느낀다.