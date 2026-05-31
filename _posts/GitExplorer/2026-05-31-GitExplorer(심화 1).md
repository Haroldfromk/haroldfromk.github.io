---
title: GitExplorer (심화 1)
writer: Harold
date: 2026-05-31 08:06
categories: [GitExplorer]
tags: [Combine]

toc: true
toc_sticky: true
published: true
---

우선 ReadMe에 아래와 같이 보완사항에 대해서 리스트를 적었었다.

## 보완해야 할 점

### iOS 앱
- `ObservableObject` + `@Published` → `@Observable` 마이그레이션
- `ProfileViewModel` 로딩/성공/실패 상태 관리 추가
- `FavoriteViewModel` → `scan` 으로 리팩토링
- `FavoritesView` → SwiftData 연결 (UserDefaults 제거)
- 에러 스트림 `merge`로 통합하여 Alert 띄우는 구조 추가
- 에러 스트림을 Subject로 외부에 전달하는 구조 개선

### Apple Watch
- `ProfileDetailView` 레포 목록 API 연결

### Widget
- App Intent 적용 (유저 선택 커스터마이징)
- WatchOS Widget 추가
- 즐겨찾기 목록 변경 시 위젯 미업데이트 버그 수정

---

이제 하나씩 고쳐가면서 또 글을 써보려고 한다.

아마 내용이 길어지면 분리해서 글을 쓸 예정

---

## iOS

### 1. @Observable 마이그레이션

현재 ViewModel의 경우 `ObservableObject` 프로토콜을 준수하고 있는데 iOS17 이후부터는 `@Observable`을 지원한다. (단, `import Observation`가 필요)

그래서 이부분을 고쳐보도록 한다.

여기서의 포인트는 [이전글](https://haroldfromk.github.io/posts/MapKit-(32)/){:target="_blank"}에서 언급했지만 `@Published` Wrapper를 더이상 사용하지 않는 대신 내가 만들어둔 변수들이 `ObservationTracked`가 되기때문에 필요없을땐 반드시 `ObservationIgnored`를 명시해줘야한다.

----

#### 1. ViewModel

```swift
final class FavoriteViewModel: ObservableObject {
    
    @Published var names: [String] = []
    @Published var countdown = 30
    @Published var users = [GithubUser]()

    private var addSubject = PassthroughSubject<String, Never>()
    // 생략
}
```

현재 이런식으로 되어있다.

포인트는 `ObservableObject`을 지워주고 `@Observable` Wrapper를 Class 전체에 씌워주는 형식으로 진행하면서 위에 언급한대로 `@ObservationIgnored`이 필요한 부분에는 이걸 별도로 적어주면 된다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/acf9aa86-ce83-4595-8cd6-494d1f3829b3" />


```swift
@Observable
final class FavoriteViewModel {
    
    var names: [String] = []
    var countdown = 30
    var users = [GithubUser]()
    
    @ObservationIgnored private var addSubject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var removeSubject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var throttleSubject = PassthroughSubject<Void, Never>()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    @ObservationIgnored private var timerCancellable: AnyCancellable?
    @ObservationIgnored private let service = GitHubNetworkService()
    
    // 생략
}
```

이렇게 되면 `users`에서 에러가 발생하게 된다.

이전에는`@Published` 덕분에 users가 Publisher의 기능을 사용할 수 있었는데, 이젠 그 기능이 빠져버린것.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/3ef21370-3b12-42b5-acbc-79363e52b312" />

---

##### SubjectPublisher & didSet

기존에는 `@Published var users = [GithubUser]()`이 모든걸 담당했지만, 이제는 각각을 분리시켜서 조금 더 세분화 해준다고 생각하면된다.

일단, 확실한건 Publisher가 반드시 필요하다는 것

그래서

```swift
@ObservationIgnored private let usersSubject = PassthroughSubject<[GithubUser], Never>()
```

SubjectPublisher를 하나 만들어 주었다. 그리고 기존에 작성해둔

```swift
// Before
$users
   .dropFirst()
   .sink { [weak self] users in
         self?.watchConnectivity.sendFavoriteUsers(users)
   }
   .store(in: &cancellables)

// After
usersSubject
   .dropFirst()
   .sink { [weak self] users in
         self?.watchConnectivity.sendFavoriteUsers(users)
   }
   .store(in: &cancellables)
```

이부분을 subject로 고쳐준다.

---

이제 남은건 하나 `subjectPublisher`의 `sink`가 작동하려면 누군가가 users배열에 값이 들어온걸 반응해서 `usersSubject`에 값을 보내줘야한다.

이제 답이 나왔다. 

그래도 감이 안잡혔다면 `값이 들어온걸 반응해서` 이게 포인트이다.

즉 `didSet`을 쓰면 된다는것.

그래서 users에 값을 그대로 값을 저장하되 didSet을 통해 `userSubject.send(users)`를 하면 된다.

```swift
var users: [GithubUser] = [] {
   didSet {
      usersSubject.send(users)
   }
}
```

바로 이렇게 작성하면 된다.

그리고 이제 초기값을 애초에 빈배열로 해두고 그 다음 부터 값이 들어오기 때문에 이젠 `.dropFirst()`를 지워주면된다.

```swift
usersSubject
   .sink { [weak self] users in
         self?.watchConnectivity.sendFavoriteUsers(users)
   }
   .store(in: &cancellables)
```

이렇게하니 

```swift
// ProfileView
.onReceive(favoriteViewModel.$names) { names in
   isFavorite = names.contains(user.login)
}
```

ProfileView에서 에러가 발생한다.

생각을 해보면?

우선 `@Observable`을 사용함으로써, users는 자연스레 `@ObservationTracked`가 설정되기 때문에 우리가 별도로 값의 변화에 따른 로직을 할 필요가 없어진다.

즉, 변화를 감지하던 `onReceive`가 필요가 없어진다.

`@Observable`을 사용하면 `names`는 자동으로 Observation 대상(`@ObservationTracked`)이 된다.

View에서 `names`를 읽고 있다면 값이 변경될 때 자동으로 재렌더링되므로, 이전처럼 `onReceive`로 변화를 감지할 필요가 없어진다.

그렇다면 `isFavorite`를 `@State`로 별도 관리할 필요도 없어진다.

`isFavorite`는 결국 `favoriteViewModel.names`에 `user.login`이 포함되어 있는지 여부를 나타내는 값이므로, Computed Property로 바꾸면 `names`가 바뀔 때마다 자동으로 재계산된다.

```swift
private var isFavorite: Bool {
    favoriteViewModel.names.contains(user.login)
}
```

`@State`와 `onReceive`로 관리하던 상태를 제거하고 View 렌더링 자체에 맡기는 구조로 바뀐 것이다.

그리고 기존의 `onAppear`에서 `isFavorite = true`를 세팅하던 부분과 버튼의 `isFavorite.toggle()`도 필요 없어진다.

버튼 로직도 삼항 연산자로 정리해주었다.

```swift
// Before
Button {
    if isFavorite {
        favoriteViewModel.removeToFavorite(id: user.login)
    } else {
        favoriteViewModel.addToFavorite(id: user.login)
    }
}

// After
Button {
    isFavorite
        ? favoriteViewModel.removeToFavorite(id: user.login)
        : favoriteViewModel.addToFavorite(id: user.login)
}
```

이제 즐겨찾기 추가/삭제 시 names가 변경되고, Observation이 이를 감지하여 View를 다시 렌더링한다. 이후 isFavorite가 재계산되면서 별 아이콘도 자동으로 변경된다.

---

##### Property Wrapper 변경

이제 [이전글](https://haroldfromk.github.io/posts/GitExplorer(5)/){:target="_blank"}에서 의존성 주입을 하면서 생긴 관련 에러가 발생한다

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/206762d2-82f1-47e8-aced-c23e99cafa9e" />

이부분은 사실 [Docs](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro){:target="_blank"}만 봐도 해결이 가능하다.

핵심은 기존에 `Object`가 붙어있던 Property Wrapper에서 `Object`를 빼면 된다.

- `@StateObject` → `@State`
- `@ObservedObject` → 제거 (그냥 일반 프로퍼티)
- `@EnvironmentObject` → `@Environment`

먼저 favoriteViewModel를 해본다.

```swift
// Before
struct GitExplorerApp: App {
   @StateObject private var favoriteViewModel = FavoriteViewModel()
   // 생략
   .environmentObject(favoriteViewModel)
}
struct FavoriteView: View {
   @EnvironmentObject var viewModel: FavoriteViewModel
   // 생략
}
struct ContentView: View {
   @EnvironmentObject var viewModel: FavoriteViewModel
   // 생략
}
struct ProfileView: View {
   @EnvironmentObject var favoriteViewModel: FavoriteViewModel
   // 생략
}


// After
struct GitExplorerApp: App {
   @State private var favoriteViewModel = FavoriteViewModel()
   // 생략
   .environment(favoriteViewModel)
}
struct FavoriteView: View {
   @Environment(FavoriteViewModel.self) var viewModel
   // 생략
}
struct ContentView: View {
   @Environment(FavoriteViewModel.self) private var viewModel 
   // 생략
}
struct ProfileView: View {
   @Environment(FavoriteViewModel.self) private var favoriteViewModel
   // 생략
}
```

우선 여기까지 테스트를 했을때 작동이 잘 되는걸 확인했다.

---

##### @MainActor 사용하기

`@MainActor`를 적용하는 이유는 단순하다.

현재 `addSubject`, `removeSubject`의 sink 클로저에서 `receive(on: DispatchQueue.main)`을 명시적으로 호출하고 있는데, ViewModel이 UI 상태를 관리하는 이상 어차피 메인 스레드에서 동작해야 한다. 

~~매번 `.receive(on: DispatchQueue.main)`을 붙이는 건 반복적인 보일러플레이트에 불과하다.~~ (5.31 수정)

`@MainActor`를 클래스 레벨에 선언하면 컴파일러가 해당 타입의 모든 프로퍼티와 메서드가 메인 스레드에서 실행됨을 보장해주기 때문에, 이런 반복적인 코드를 제거할 수 있다.

```swift
@Observable
@MainActor
final class FavoriteViewModel {
    // receive(on: DispatchQueue.main) 없이도 메인 스레드 보장
}
```

`DispatchQueue.main`은 익숙하고 널리 쓰이는 방식이지만, `@MainActor`는 그 의도를 타입 레벨에서 선언적으로 표현한다. 코드가 줄어드는 것뿐만 아니라, "이 ViewModel은 항상 메인에서 동작한다"는 설계 의도가 명확해진다는 점에서 더 나은 접근이라고 볼 수 있다.

다만 `@MainActor`를 클래스 전체에 적용하면 네트워크 호출처럼 백그라운드에서 실행되어야 할 작업도 메인 스레드에서 실행될 수 있다. 

그래서 해당 메서드에 `nonisolated`를 붙이거나 `Task.detached`를 활용해 메인 스레드에서 분리해주는 작업이 필요하다.

---

우선 이제는 MainThread에 실행이 되기에
~~init에 있는 `.receive(on: DispatchQueue.main)` 이부분을 전부 지워주도록 한다.~~ (5.31 수정)

```swift
// before
addSubject
   .receive(on: DispatchQueue.main)
   .sink { [weak self] id in
         self?.names.append(id)
         UserDefaults.shared.set(self?.names, forKey: Constants.favoritesKey)
         Task {
            try? await self?.asyncFetchFavoriteDataBefore()
         }
   }.store(in: &cancellables)

// after
addSubject
   .sink { [weak self] id in
         self?.names.append(id)
         UserDefaults.shared.set(self?.names, forKey: Constants.favoritesKey)
         Task {
            try? await self?.asyncFetchFavoriteDataBefore()
         }
   }.store(in: &cancellables)
```

단, `.throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: false)` 이건 Scheduler에서 담당하는거라 그대로 두도록 한다. (MainActor와는 별개다.)

---

###### 백그라운드 작업 분리하기

`@MainActor`를 클래스 전체에 적용하면 모든 메서드가 메인 스레드에서 실행된다.

UI 업데이트는 메인 스레드에서 실행되어야 하므로 문제가 없지만, 네트워크 호출처럼 시간이 걸리는 작업이 메인 스레드를 점유하면 UI가 멈추는 문제가 생길 수 있다.

따라서 네트워크 호출 부분은 메인 스레드에서 분리해줄 필요가 있다.

---

###### 정말 Main Thread에서 실행되는가?

현재 `reloadData`를 보면 UI 업데이트(`names = savedArray`)와 네트워크 호출(`asyncFetchFavoriteDataBefore`)이 같은 함수 안에 섞여 있다.

`async/await`가 내부적으로 스레드 전환을 처리해주기 때문에 눈에 띄는 문제가 발생하지 않지만, `@MainActor`를 클래스 전체에 선언한 이상 네트워크 호출도 메인 스레드에서 시작되는 구조가 된다.

```swift
func asyncFetchFavoriteDataBefore() async throws {
    var result = [GithubUser]()
    for name in names {
        let data = try await service.asyncFetchGitUser(user: name)
        result.append(data)
    }
    users = result
}
```

`let data` 줄에 Break Point를 걸어보면

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/28f1fb04-6306-4c99-bff8-9cd8f7af0a71" />

`Task 1`이 표시되는데 이는 Main Thread를 의미한다.

더 확실하게 확인하려면 `print`로 직접 찍어볼 수 있다.

```swift
for name in names {
    print("isMainThread: \(Thread.isMainThread)")
    print("current thread: \(Thread.current)")
    let data = try await service.asyncFetchGitUser(user: name)
    result.append(data)
}
```

결과는 `true`. 즉 네트워크 호출이 Main Thread에서 시작되고 있다는 것이 확인된다.

```
isMainThread: true
current thread: <_NSMainThread: 0x600001704040>{number = 1, name = main}
```

---

###### 해결책은?

Main Thread에서 네트워크 호출이 시작되는 문제를 해결하려면, 해당 함수를 `@MainActor` 격리에서 제외시켜야 한다.

Actor란 Race Condition을 방지하기 위해 내부 상태에 대한 접근을 직렬화하는 참조 타입이다. 자세한 내용은 [이전글](https://haroldfromk.github.io/posts/Async_await-(12)/#actor){:target="_blank"}을 참고.

---

이해를 돕기위해 시뮬레이터도 추가한다.

<iframe 
    src="/assets/demo/actor-visual-simulator.html" 
    width="100%" 
    height="520" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>


---

`@MainActor`도 Actor의 한 종류이기 때문에 `nonisolated` 사용이 가능하다. `nonisolated`는 Actor의 격리에서 제외시키는 키워드로, Actor 내부 상태에 의존하지 않는 메서드에 붙여 백그라운드에서 실행되도록 해준다.

흥미로운 점은 이번 해결책의 방향이 [이전글](https://haroldfromk.github.io/posts/GitExplorer(4)/){:target="_blank"}과 정반대라는 것이다.

이전에는 `MergeMany`로 동시에 요청을 쏘다 보니 응답이 오는 순서대로 쌓여서 순서가 뒤섞였고, 이를 `async/await`의 `for` 루프로 해결했다. `for` 루프는 하나씩 순차적으로 처리하기 때문에 순서가 보장됐다.

그런데 이번엔 반대로 그 순차적인 `for` 루프가 메인 스레드를 점유하는 문제가 되었다. 즉 순서를 보장하기 위해 직렬로 처리했던 방식이, 이번엔 분리해야 할 대상이 된 것이다.

---

본격적으로 분리를 해보도록 한다.

우선은 네트워크와 관련된 함수부터 식별후 분리 작업을 한다.

현재 FavoriteViewModel의 함수를 역할별로 분류하면

**순수 네트워크 호출 (분리 대상)**
- `fetchFavoriteData` - Combine Publisher 반환, UI 비관여

**네트워크 호출 + UI 업데이트 혼합**
- `asyncFetchFavoriteDataBefore` - 순차 호출 후 `users`에 직접 담음
- `asyncFetchFavoriteData` - 병렬 호출 후 `users`에 직접 담음
- `reloadData` - UserDefaults 읽기 + 네트워크 호출
- `getData` - Combine 파이프라인 실행 후 `users`에 담음
- `refreshData` - 타이머 제어

이렇게 된다.

---

우선 `fetchFavoriteData`는 Actor의 영향에서 벗어나도록 `nonisolated`를 붙여준다.

```swift
nonisolated func fetchFavoriteData() -> AnyPublisher<[GithubUser], Error>{
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
```

바로 에러가 발생한다.

```
Main actor-isolated property 'names' can not be referenced from a nonisolated context
```

`names`는 `@MainActor`에 격리된 프로퍼티라 `nonisolated` 컨텍스트에서 접근할 수 없다는 것이다.

그래서 `names`를 파라미터로 받는 방식으로 변경했다.

```swift
nonisolated func fetchFavoriteData(_ names: [String]) -> AnyPublisher<[GithubUser], Error>{
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
```

그리고 에러를 명확하게 확인하기 위해 Swift 언어 버전을 6으로 올렸다. Swift 5에서는 경고로만 표시되던 것들이 Swift 6에서는 컴파일 에러로 바뀐다.

그랬더니 아래와 같은 에러가 발생한다. (Swift 5에선 단순 경고였다.)

```
Call to main actor-isolated instance method 'fetchGitUser(user:)' in a synchronous nonisolated context
```

`fetchGitUser`도 `@MainActor`에 묶여있어서 `nonisolated` 컨텍스트에서 호출이 안 된다는 것이다.

그런데 `GitHubNetworkService`에는 `@MainActor`를 명시한 적이 없다. 왜 묶여있는 걸까?

Xcode 26부터 `Default Actor Isolation`이 `MainActor`로 기본값이 변경되었기 때문이다.

<img width="1458" height="244" alt="Image" src="https://github.com/user-attachments/assets/634ede87-c90a-463a-86ad-7308f40802c0" />

즉 `@MainActor`를 명시하지 않아도 프로젝트 내 모든 타입이 기본적으로 `@MainActor`에 격리되는 구조가 된 것이다. 자세한 내용은 [이 글](https://fatbobman.com/en/posts/default-actor-isolation/){:target="_blank"}을 참고.

결국 `nonisolated`로 분리하면 그 안에서 호출하는 메서드들도 연쇄적으로 분리가 필요해진다. 이건 코드 설계의 문제가 아니라 `@MainActor`의 특성상 원래 이렇게 퍼지는 구조다.

여기서 Xcode AI에게 연쇄적으로 분리하는 방식이 맞는지 물어봤다.

> "If you're seeing this error in many places, the real question is the project-wide setting. Your project likely has SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor — a network layer has no business being main-actor-isolated. For GitHubNetworkService, marking it as nonisolated is more architecturally honest."

핵심은 네트워크 레이어인 `GitHubNetworkService`가 애초에 `@MainActor`에 묶여있을 이유가 없다는 것이다.

그래서 `GitHubNetworkService` 자체를 `nonisolated`로 선언해주었다.

```swift
nonisolated final class GitHubNetworkService {
    // ...
}
```

이렇게 하면 `fetchGitUser`를 비롯한 내부 메서드들이 자동으로 `nonisolated` 컨텍스트가 되어 연쇄 에러가 해결된다.

하지만 `fetchGitUser`에 `nonisolated`를 붙이니 이번엔 `Constants`에서 에러가 발생했다.

```
Main actor-isolated static property 'token' can not be referenced from a nonisolated context
```

`Constants`의 프로퍼티도 `nonisolated` 컨텍스트에서 접근하려면 동일하게 처리해줘야 한다.

```swift
enum Constants {
    nonisolated static let token = "" // token here
    nonisolated static let favoritesKey = "FavoriteNames"
}
```

다만 `Constants`는 불변 값(`let`)이라 동시성 문제가 없어서 `nonisolated`를 붙이는 게 안전하다.

---

Xcode AI에게 이 방향성에 대해 물어봤는데, 아래와 같이 3가지를 제시했다.

1. **Per-property nonisolated** - 에러가 발생하는 곳마다 `nonisolated`를 붙이는 방식
2. **Per-type nonisolated** - 클래스 자체를 `nonisolated`로 선언하는 방식
3. **프로젝트 기본값 변경** - `Default Actor Isolation`을 `nonisolated`로 바꾸고 필요한 곳만 `@MainActor` 명시

지금 구조에서는 1번과 2번을 혼합해서 사용하는 것이 적합하다.

`FavoriteViewModel`은 `@MainActor`로 전체 선언되어 있어서 내부에서 호출하는 `names`, `Constants` 같은 프로퍼티들이 연쇄적으로 `nonisolated`가 필요하다. 이 경우엔 **1번** 방식으로 처리한다.

반면 `GitHubNetworkService`는 UI와 전혀 관계없는 네트워크 레이어다. 메서드마다 `nonisolated`를 붙이는 것보다 클래스 자체를 `nonisolated`로 선언하는 **2번** 방식이 더 깔끔하고 설계 의도에도 맞다.

```swift
nonisolated final class GitHubNetworkService {
    // 메서드에 별도로 nonisolated 불필요
}
```

이건 nonisolated의 이해를 도울 시뮬레이터

<iframe 
    src="/assets/demo/mainactor-nonisolated.html" 
    width="100%" 
    height="540" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>


---

### nonisolated로 백그라운드 작업 분리하기

`GitHubNetworkService`를 `nonisolated`로 바꾸면 연쇄적으로 처리해야 할 것들이 생긴다.

#### 1. Sendable 추가

`nonisolated` 컨텍스트에서 `@MainActor` VM으로 값을 전달할 때 해당 타입이 `Sendable`을 만족해야 한다.

[Sendable Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Sendable-Types){:target="_blank"}를 보면

`Sendable`이란 서로 다른 동시성 도메인(concurrency domain) 간에 안전하게 전달될 수 있는 타입을 말한다. 

`struct`처럼 값 타입이고 내부 프로퍼티도 모두 `Sendable`이라면 암묵적으로 `Sendable`을 만족하지만, Swift 6 동시성 환경에서는 명시적으로 선언해주는 것이 안전하다.

```swift
struct GithubUser: Codable, Identifiable, Hashable, Sendable {
   // 생략
}
```

`TotalProfile`도 동일하게 처리해줘야 한다.


그리고 위에서

```swift
@ObservationIgnored nonisolated private let service = GitHubNetworkService()
```

이렇게 해서 변수에 별도로 했던 부분에서

```
'nonisolated' can not be applied to variable with non-'Sendable' type 'GitHubNetworkService'
```

이렇게 에러가 나는데 `GitHubNetworkService`에도 Sendable을 준수하도록 해준다.

```swift
nonisolated final class GitHubNetworkService: ObservableObject, Sendable { 
   // 생략
}
```

이때 중요한점이라면 Sendable 프로토콜을 따르는 class는 반드시 `final class`이어야 한다고 Docs에 명시되어있다.

---

#### 2. deinit 에러

[당시](https://haroldfromk.github.io/posts/GitExplorer(4)/){:target="_blank"}에 화면 종료시 정리하기에 따라 deinit을 명시하고 모든 구독에 대해 취소하기 위해서 아래와 같은 코드를 사용했다.

```swift
deinit {
   cancellables.removeAll()
}      
```

이젠 아래와 같은 에러가 발생한다.

```
Cannot access property 'cancellables' with a non-Sendable type 'Set<AnyCancellable>' from nonisolated deinit
```

`deinit`은 기본적으로 `nonisolated` 컨텍스트에서 실행된다. 
그런데 `cancellables`는 `@MainActor`에 격리된 프로퍼티라 `nonisolated` 영역에서 접근할 수 없다는 에러다.

사실 deinit을 굳이 명시한건 혹시라도 강한 참조가 발생하여 구독이 살아있을까봐 한건데

일반적으론 [AnyCancellable Docs](https://developer.apple.com/documentation/combine/anycancellable){:target="_blank"}에서도 언급하지만 deinitialize 될때 알아서 cancel을 호출한다.

그래서 이부분은 지워주도록 한다.

#### 3. GitHubNetworkService 에러

이제는

```swift
func asyncFetchGitUser(user: String) async throws -> GithubUser {
   // 생략
   
   let decodedData = try JSONDecoder().decode(GithubUser.self, from: data)

   // 생략
}
// Error
Main actor-isolated conformance of 'GithubUser' to 'Decodable' cannot be used in caller isolation inheriting-isolated context


func fetchGitData<T: Codable>(requestType: GitHubRequest) -> AnyPublisher<T, Error> {
   
   let url = requestType.url
   
   // 생략
}
// Main actor-isolated property 'url' can not be referenced from a nonisolated context
```

이렇게 코드를 남긴 부분에서 에러가 발생한다.

이것 역시도 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`가 적용되어서 발생한 에러이다.

그래서 관련된 부분에 전부 `nonisolated`를 추가해주면 된다.

```swift
nonisolated struct GithubUser: Codable, Identifiable, Hashable, Sendable {
    // 생략
}

// MARK: - RepoModel
nonisolated struct GithubRepo: Codable, Identifiable, Sendable {
    // 생략
}

nonisolated enum GitHubRequest {
   // 생략
}
```
---

#### 4. App Crash 발생

빌드 후 에러가 해결된거 같아 실행을 해보니

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/a1576fbe-2cb4-4136-8bec-50cda746952f" />

이렇게 실행이 안된다.

일단은 print를 찍어서 확인해본 결과

```swift
FavoriteViewModel init
before userdefaults
// 여기서 멈춤
```

`UserDefaults` 접근 시점에서 멈추는 걸 확인했다. 처음엔 당연히 `UserDefaults` 문제라고 생각했다.

`UserDefaults(suiteName:)` 대신 `UserDefaults.standard`로 바꿔보고, `Task { @MainActor in }`으로 감싸보고, `Constants`도 의심해봤지만 전부 소용없었다.

---

한참을 삽질하다가 워치 시뮬레이터랑 같이 실행해보니 크래시 리포트가 떴다.

```
Thread 4 Crashed:
0  _dispatch_assert_queue_fail
...
5  @objc WatchConnectivityService.session(_:activationDidCompleteWith:error:)
```

`FavoriteViewModel`이 아니라 `WatchConnectivityService`가 범인이었다.

사실 처음부터 `WatchConnectivityService` 쪽을 의심하지 못했던 데는 이유가 있다.

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 설정이 켜져 있으면 `nonisolated`를 명시하지 않은 모든 메서드가 암묵적으로 `@MainActor`가 된다. 

Swift 6 이전이었다면 그냥 넘어갔을 코드인데, 이 설정 때문에 `WatchConnectivityService`의 델리게이트 메서드들도 조용히 `@MainActor`가 붙어버린 것이다.

에러 메시지도 `FavoriteViewModel` 쪽에서 멈추는 것처럼 보였으니 당연히 거기서 원인을 찾게 된다. 워치 시뮬레이터랑 같이 실행해서 크래시 리포트를 보기 전까진 전혀 몰랐다.

---

그런데 WCSession은 워치와 통신이 완료되거나 상태가 바뀔 때 그 결과를 알려주는 메서드들을 백그라운드 스레드에서 호출한다.

`@MainActor`가 붙은 메서드는 메인 스레드에서만 실행되어야 하는데, 백그라운드 스레드에서 호출되니 Swift 런타임이 "이거 잘못됐다" 하고 강제로 앱을 종료시킨 것이다.

해결 방법은 간단했다. `WatchConnectivityService` 클래스 앞에 `nonisolated`를 붙여주면 끝이었다.

```swift
nonisolated final class WatchConnectivityService: NSObject, WCSessionDelegate {
    // ...
}
```

---

그리고 `didReceiveMessage`에서 추가로 경고가 떴다.

기존 코드는 이랬다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let user = message["delete"] as? String else { return }
        viewModel?.removeToFavorite(id: user)
    }
}
```

```
Sending 'self' risks causing data races
Sending 'message' risks causing data races
```

`nonisolated` 컨텍스트에서 `self`와 `message` 전체를 `DispatchQueue.main.async`로 넘기면 발생하는 경고다.

`self`는 `WatchConnectivityService` 인스턴스 전체를 가리키는데, 이 객체가 백그라운드 스레드와 메인 스레드에서 동시에 접근될 수 있다.

Swift는 이걸 보고 "두 스레드가 같은 객체를 동시에 건드릴 수 있어서 위험하다"고 경고를 띄운 것이다. `message` 역시 딕셔너리 전체를 넘기면 동일한 문제가 생긴다.

해결 방법은 필요한 값인 `user`(String)만 미리 꺼내고, `viewModel`도 따로 캡처해서 넘기는 것이다.

`String`은 `Sendable`을 준수하기 때문에 스레드 간에 안전하게 전달할 수 있고, `self` 전체를 넘기지 않으니 경고도 사라진다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    guard let user = message["delete"] as? String else { return }
    let viewModel = viewModel
    DispatchQueue.main.async {
        viewModel?.removeToFavorite(id: user)
    }
}
```

---

결국 `UserDefaults`는 아무 문제가 없었고, `WatchConnectivityService`에 `nonisolated`를 누락한 게 원인이었다.

엉뚱한 곳만 한참 팠지만, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 설정이 WCSession 같은 외부 프레임워크 델리게이트에도 영향을 준다는 걸 몸으로 배웠다.

---

### FavoriteViewModel 이어서 수정하기

위에서 적었는데 내용이 너무 길어져서 여기에 다시 써보면

**순수 네트워크 호출 (분리 대상)**
- ✅ `fetchFavoriteData` - Combine Publisher 반환, UI 비관여 

**네트워크 호출 + UI 업데이트 혼합**
- `asyncFetchFavoriteDataBefore` - 순차 호출 후 `users`에 직접 담음
- `asyncFetchFavoriteData` - 병렬 호출 후 `users`에 직접 담음
- `reloadData` - UserDefaults 읽기 + 네트워크 호출
- `getData` - Combine 파이프라인 실행 후 `users`에 담음
- `refreshData` - 타이머 제어

이제 1개 했는데, 내용이 엄청 길어졌었다... 그만큼 꼬리에 꼬리를 무는 에러가 많았다.

이제는 크게 에러가 발생할 부분이 없을것 같아서 빠르게 진행해본다.

여기는 적은대로 `네트워크 호출 / UI 업데이트`를 분리하면 된다.

---

#### 1. asyncFetchFavoriteDataBefore

순서대로 asyncFetchFavoriteDataBefore 부터 가본다.

```swift
func asyncFetchFavoriteDataBefore() async throws {
   var result = [GithubUser]()
   for name in names {
      let data = try await service.asyncFetchGitUser(user: name)
      result.append(data)
   }
   users = result
}
```

여기를 보면 let data 부분에서 `asyncFetchGitUser`를 호출 부분과

그 결과를 `users = result`에 담는 UI 업데이트로 나뉘어진다.

그래서 우선 네트워크 부분을

```swift
nonisolated func asyncFetchFavoriteDataBefore() async throws -> [GithubUser]{
   var result = [GithubUser]()
   for name in names {
      let data = try await service.asyncFetchGitUser(user: name)
      result.append(data)
   }
   return result
}
```

이렇게 값을 리턴하도록 만들어 주었다.

그랬더니

```swift
Main actor-isolated property 'names' cannot be accessed from outside of the actor
```

for loop에서 위와 같은 에러 메세지가 떴다. 그러면서 await를 추가하라고 한다.

##### await?

[Swift Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Isolation){:target="_blank"}에서 

아래와 같이 나와있다.

```
When you access a property or method of an actor, you use await to mark the potential suspension point.
// 생략
Accessing logger.max without writing await fails because the properties of an actor are part of that actor's isolated local state. The code to access this property needs to run as part of the actor, which is an asynchronous operation and requires writing await
```

이 말을 번역하면 **"액터의 프로퍼티나 메서드에 접근할 때는 `await`를 사용해 잠재적인 일시 중단 지점을 표시해야 한다."** 정도가 된다.

`logger.max`에 `await` 없이 접근하면 에러가 발생하는데, 이는 액터의 프로퍼티가 해당 액터의 격리된 로컬 상태(isolated local state)의 일부이기 때문이다.

이 프로퍼티에 접근하려면 액터의 실행 컨텍스트 안에서 코드가 실행되어야 한다. 쉽게 말하면 `names`는 `@MainActor`의 소유이기 때문에 값을 읽으려면 잠시 MainActor의 실행 컨텍스트 안으로 들어가야 한다는 뜻이다.

따라서 `names`는 `@MainActor`에 의해 보호되는 상태이므로 `nonisolated` 메서드에서는 직접 접근할 수 없다.

값을 읽기 위해서는 잠시 MainActor로 이동해야 하며, 이 과정에서 현재 작업이 일시 중단(suspend)될 가능성이 있다.

Swift는 이러한 잠재적인 suspension point를 명시적으로 표현하도록 강제하기 때문에 `await names`와 같이 작성해야 한다.

중요한 점은 `await`가 항상 실제 대기를 의미하는 것은 아니라는 것이다. 단지 MainActor로 이동하는 과정에서 일시 중단이 발생할 가능성이 있음을 나타낸다.

[Await Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/expressions/?utm_source=chatgpt.com#Await-Operator){:target="_blank"}에도 대기보단 잠재적인 일시 중단 지점이라고 되어있다.

이해를 돕기위해 이미지로 만들어보면

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/077637a0-c1a8-488a-92f5-26885e60ed14" />

`await`는 "기다림"이라기보다 현재 Task가 잠시 중단될 수 있음을 표시하는 문법이다. 
다만 Task가 중단된 동안에도 시스템은 다른 작업을 계속 실행할 수 있다. (여기선 네트워크 요청)

<iframe 
    src="/assets/demo/concurrency-timeline.html" 
    width="100%" 
    height="580" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>

요약하자면

위 시뮬레이터에서 본 것처럼 `await`는 스레드가 드러눕는 "기다림(Blocking)"이 아니다.

`Task 1`은 `await`를 만나는 순간 **"나 여기서 잠시 멈출 수도 있음(Potential Suspension Point)"** 이라는 책갈피를 꽂아두고 잠시 보류실(Suspension 상태)로 들어간다.

하지만 Task가 쉬고 있다고 해서 세상이 멈추는 건 아니다.

이미 출발한 네트워크 요청은 시스템의 네트워크 스택을 통해 계속 진행되고, 방금까지 사용하던 스레드는 즉시 시스템에 반납되어 다른 작업을 처리하러 떠난다.

즉, `await`가 발생한 순간에도:

* **Task** 는 잠시 보류된다.
* **네트워크 요청** 은 계속 진행된다.
* **스레드** 는 다른 일을 처리하러 간다.

이 세 가지가 동시에 일어난다.

그래서 `await` 이후의 세상은 우리가 흔히 생각하는 "가만히 기다리는 상태"가 아니다.

오히려 Swift는

**"이 작업은 여기서 잠시 멈출 수 있으니, 그동안 다른 일부터 처리하세요."**

라고 시스템에 알려주는 셈에 가깝다.

결국 Swift Concurrency의 핵심은 스레드를 무작정 늘리는 것이 아니라, 가벼운 Task들을 필요할 때 잠시 보류하고 다시 깨우면서 한정된 스레드를 최대한 효율적으로 활용하는 데 있다.

그래서 `await`의 본질은 기다림(Waiting)이 아니라 **잠재적인 일시 중단 지점(Potential Suspension Point)** 이라고 이해하는 편이 더 정확하다.

---

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/6c9be3e3-afe9-4d51-9f9a-344015607f04" />

`names`는 `MainActor`의 격리된 상태이므로 `nonisolated` 함수에서는 직접 접근할 수 없다. 

이때 `await names`는 `MainActor`로부터 값을 받아오는 과정에서 잠재적인 일시 중단(Potential Suspension Point)이 발생할 수 있음을 나타낸다.

<iframe 
    src="/assets/demo/await-suspension-simulator.html" 
    width="100%" 
    height="500" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>


요약하자면

위 시뮬레이터에서 본 것처럼 `await`는 스레드를 멈춰 세우는(Blocking) 문법이 아니다.
`nonisolated` 마당에서 자유롭게 놀던 Task가, `@MainActor`가 소유한 `names`를 안전하게 읽어오기 위해 잠시 메인 스레드 진입로 앞에서 줄을 서며 **"나 잠시 멈출 수 있음(Suspension Point)"**이라고 책갈피를 꽂아두는 문법적 선언일 뿐이다.

중요한 건 줄을 서서 멈춰 있는 동안에도 내가 원래 타고 있던 스레드는 시스템에 즉시 반환되어 다른 비동기 작업을 하러 떠난다는 점이다.

- **`await` 전**: nonisolated 컨텍스트에서 실행
- **`await` 지점**: 잠재적 일시 중단 (현재 스레드를 즉시 양보)
- **`await` 진입**: MainActor가 소유한 `names` 값을 안전하게 읽어옴
- **`await` 이후**: 다시 nonisolated 컨텍스트에서 남은 코드 실행

결국 `await`는 기다림이 아니라, Task와 스레드가 효율적으로 협력하기 위한 약속이다.

---

무튼 그래서 다시 돌아오면

방법은 2가지가 있다.

1. await 사용하기 

```swift
nonisolated func asyncFetchFavoriteDataBefore() async throws -> [GithubUser]{
   var result = [GithubUser]()
   for name in await names {
      let data = try await service.asyncFetchGitUser(user: name)
      result.append(data)
   }
   return result
}
```

2. names를 파라미터로 해서 받아서 사용하기

```swift
nonisolated func asyncFetchFavoriteDataBefore(_ names: [String]) async throws -> [GithubUser] {
   var result = [GithubUser]()
   for name in names {
      let data = try await service.asyncFetchGitUser(user: name)
      result.append(data)
   }
   return result
}
```

2번처럼 필요한 값을 파라미터로 넘기는 방법도 있지만, 이번 글에서는 Actor 격리와 await의 동작을 이해하는 것이 목적이므로 1번 방식을 사용하려고 한다.

---

#### 2. reloadData

1번의 코드를 사용하니 

```swift
func reloadData() async throws {     
   if let savedArray = UserDefaults.shared.array(forKey: Constants.favoritesKey) as? [String] {
      names = savedArray
   }
   try await asyncFetchFavoriteDataBefore()
}
```

기존에는 users를 함수 내부에서 직접 갱신했지만, nonisolated로 분리하면서 결과를 반환하도록 변경했다. 따라서 반환된 [GithubUser]를 사용하지 않으면 컴파일러가 경고를 표시한다.

그래서 `users = try await asyncFetchFavoriteDataBefore()`로 해주었다.

```swift
func reloadData() async throws {
   if let savedArray = UserDefaults.shared.array(forKey: Constants.favoritesKey) as? [String] {
      names = savedArray
   }
   
   users = try await asyncFetchFavoriteDataBefore()
}
```

`reloadData`는 별도의 수정이 필요 없다. `asyncFetchFavoriteDataBefore`는 `nonisolated`로 분리되어 `MainActor`의 격리 영역 밖에서 실행되고, 최종 결과만 `@MainActor` 컨텍스트인 `reloadData`에서 `users`에 반영하는 구조이기 때문이다.


---

#### 3. asyncFetchFavoriteData

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
}
```

코드를 보면 역시나 네트워크 호출과 그 결과를 users에 넣는 UI 업데이트로 나눠져 있다.

우선 이 함수도 `asyncFetchFavoriteDataBefore` 처럼 값을 리턴하게 바꾼다.

그리고 nonisolated를 붙이면 또 역시나 await를 쓰라고 나온다. 위에 엄청 길게 설명했으니 여기선 생략하도록 한다.

```swift
nonisolated func asyncFetchFavoriteData() async throws -> [GithubUser] {
   var result = [GithubUser]()
   
   try await withThrowingTaskGroup(of: GithubUser.self) { group in
      for name in await names {
            group.addTask {
               return try await self.service.asyncFetchGitUser(user: name)
            }
      }
      
      for try await user in group {
            result.append(user)
      }
   }
   
   return result
}
```

---

#### 4. getData

```swift
func getData() {
   fetchFavoriteData(names)
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

`fetchFavoriteData`는 이미 MainActor와 분리되어 있으므로 로직 자체는 수정할 필요가 없다.

~~다만 `@MainActor`가 클래스 전체에 붙어있으므로 `.receive(on: DispatchQueue.main)` 여기만 제거해주었다.~~ (5.31 수정)

```swift
func getData() {
   fetchFavoriteData(names)
      .sink { completion in
            if case .failure(let error) = completion {
               print(error)
            }
      } receiveValue: { [weak self] result in
            self?.users = result
      }.store(in: &cancellables)
}
```

---

#### 5. refreshData

```swift
func refreshData(isRefresh: Bool) {
   if isRefresh {
      guard timerCancellable == nil else { return }
      
      timerCancellable = timer
            .sink { [weak self] _ in
               guard let self else { return }
               countdown -= 1
               if countdown <= 0 {
                  Task {
                        try? await self.asyncFetchFavoriteDataBefore()
                  }
                  countdown = 30
               }
            }
   } else {
      timerCancellable?.cancel()
      timerCancellable = nil
      countdown = 30
   }
}
```

앞에서 `asyncFetchFavoriteDataBefore()`가 [GithubUser]를 반환하도록 변경했기 때문에, 여기서도 반환된 결과를 users에 반영하도록 수정해준다.

```swift
func refreshData(isRefresh: Bool) {
   if isRefresh {
      guard timerCancellable == nil else { return }
      
      timerCancellable = timer
            .sink { [weak self] _ in
               guard let self else { return }
               countdown -= 1
               if countdown <= 0 {
                  Task {
                        users = try await self.asyncFetchFavoriteDataBefore()
                  }
                  countdown = 30
               }
            }
   } else {
      timerCancellable?.cancel()
      timerCancellable = nil
      countdown = 30
   }
}
```

참고로 Task 내부에서 async throws 함수를 호출할 경우 에러가 외부로 전파되지 않는다.

따라서 실제 프로젝트에서는 아래처럼 do-catch로 처리하는 것이 안전하다.

이 내용은 [이전글](https://haroldfromk.github.io/posts/GitExplorer(4)/){:target="_blank"}에서 자세히 다루었으므로 여기서는 넘어가도록 하겠다.

----

### 문제 수정하기

<img width="270" height="550" alt="Image" src="https://github.com/user-attachments/assets/be33de82-4ace-4885-a575-eb7bcdc230bc" />

위 사진처럼 실행해보니 즐겨찾기는 정상적으로 저장되지만 UI가 갱신되지 않았다.

처음에는 `@MainActor` 적용 과정에서 Main Thread 관련 문제가 생긴 건가 싶었다.

혹시 몰라 `.receive(on: DispatchQueue.main)`을 다시 복구하고 실행해봤지만 결과는 동일했다.

생각해보니

```swift
addSubject
   .sink { [weak self] id in
         self?.names.append(id)
         UserDefaults.shared.set(self?.names, forKey: Constants.favoritesKey)
         Task {
            try? await self?.asyncFetchFavoriteDataBefore()
         }
   }.store(in: &cancellables)
```

`asyncFetchFavoriteDataBefore`를 사용하는데 위에서 수정한 방식을 사용하지않고 그대로 둬서 users에 값이 들어가지 않아 반영이 안된 것.

```swift
addSubject
   .sink { [weak self] id in
         self?.names.append(id)
         UserDefaults.shared.set(self?.names, forKey: Constants.favoritesKey)
         Task {
            users = try await self?.asyncFetchFavoriteDataBefore()
         }
   }.store(in: &cancellables)
```

이렇게 하면 옵셔널 에러가 나는데 괜히 apply만 누르면 꼬인다.

여기선 옵셔널 바인딩을 확실하게 해주고 넘어가는게 좋다.

```swift
addSubject
   .sink { [weak self] id in
         guard let self else { return }
         self.names.append(id)
         UserDefaults.shared.set(self.names, forKey: Constants.favoritesKey)
         Task {
            users = try await self.asyncFetchFavoriteDataBefore()
         }
   }.store(in: &cancellables)
```

이제 잘 되는걸 알 수 있다.

<img width="270" height="550" alt="Image" src="https://github.com/user-attachments/assets/64e02773-6813-4b09-80b9-b3176ce9daa1" />

---

이제 `FavoriteViewModel` 수정은 모두 끝났다.

사실 원리는 모두 동일하다.

지금까지 했던 것처럼 네트워크 작업은 `nonisolated`로 분리하고, 최종 UI 상태 변경만 `@MainActor`에서 수행하도록 역할을 나눠주면 된다.

따라서 `ProfileViewModel`, `SearchViewModel`도 동일한 방식으로 적용해주면 된다.

---

### 2. @Observable 마이그레이션 이어서 끝내기
#### 1. ProfileViewModel

```swift
@Observable @MainActor
final class ProfileViewModel {
    
    var totalProfile = TotalProfile(
        repos: [],
        followers: [],
        followings: []
    )
    
    @ObservationIgnored private let service = GitHubNetworkService()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    init(requestUser: GithubUser) {
        Publishers.CombineLatest3(service.fetchGitData(requestType: .repo(requestUser.login))
            .catch { error -> Just<[GithubRepo]> in
                print(error)
                return Just([])
            }, service.fetchGitData(requestType: .follower(requestUser.login))
            .catch { error -> Just<[GithubUser]> in
                print(error)
                return Just([])
            }, service.fetchGitData(requestType: .following(requestUser.login))
            .catch { error -> Just<[GithubUser]> in
                print(error)
                return Just([])
            })
        .sink { [weak self] repos, followers, followings in
            self?.totalProfile = TotalProfile(repos: repos,
                                              followers: followers,
                                              followings: followings)
        }.store(in: &cancellables)
    }

}
```

여긴 위에서 설명한대로 하면되기에 크게 어려운 부분이 없다.

Class에서는 `@Observable @MainActor`를 추가하고 `ObservableObject` 프로토콜을 삭제 해주고 내부에서는 `@Published,`삭제, ~~`.receive(on:)`, 삭제~~ 그리고 `@ObservationIgnored`를 추가해주면 된다.

이게 전부이다.

---

이떄 ProfileView 에서 에러가 발생하는데

```swift
struct ProfileView: View {

   @StateObject var viewModel: ProfileViewModel

   // 생략

   init(user: GithubUser) {
      self.user = user
      _viewModel = StateObject(wrappedValue: ProfileViewModel(requestUser: user))
   }
   // 생략
}
```

두군데에서

```swift
Generic struct 'StateObject' requires that 'ProfileViewModel' conform to 'ObservableObject'
```

에러가 발생한다.

이건 object를 빼주면 된다.

`@StateObject`는 `ObservableObject`를 관리하기 위한 프로퍼티 래퍼다.

하지만 `@Observable`은 Observation 프레임워크를 사용하므로 `ObservableObject`를 채택하지 않는다.

따라서 `@StateObject` 대신 `@State`를 사용하면 된다.

```swift
struct ProfileView: View {
    
   @State var viewModel: ProfileViewModel
   // 생략
    
   init(user: GithubUser) {
        self.user = user
        _viewModel = State(wrappedValue: ProfileViewModel(requestUser: user))
   }
   // 생략
}
```

여기서 한 가지 궁금증이 생길 수 있다.

처음 `FavoriteViewModel`처럼 App 레벨에서 생성하면 안 될까?

대답을 먼저 말하면 아니오다.

`ProfileViewModel`은 `FavoriteViewModel`이랑 다르다.

`FavoriteViewModel`은 앱 전체에서 공유되는 글로벌 상태다.
반면 `ProfileViewModel`은 특정 프로필 화면에 진입할 때마다 `requestUser`를 받아 생성되는 화면 전용 상태다.

따라서 App에서 미리 생성하는 것이 아니라 `ProfileView`에서 직접 생성하는 것이 맞다.

---

#### 2. SearchViewModel

```swift
@Observable @MainActor
final class SearchViewModel {
    
    var searchText: String = "" {
        didSet {
            searchSubject.send(searchText)
        }
    }
    
    var users = [GithubUser]()
    var status: Staus = .idle
    
    @ObservationIgnored var searchSubject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private let service = GitHubNetworkService()
    
    init() {
        searchSubject
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] _ in
                guard let self else { return }
                self.status = .loading
            })
            .map { text in
                self.service.fetchGitUser(user: text)
                    .retry(2)
                    .replaceError(with: [])
            }
            .switchToLatest()
            .sink(receiveValue: { [weak self] value in
                guard let self else { return }
                if value.isEmpty {
                    self.status = .failure
                } else {
                    self.status = .success(value)
                }
                self.users = value
            })
            .store(in: &cancellables)
    }
    
}
```

여기는 ProfileViewModel하는것과 과정이 유사하다.

우선 Wrapper 부분은 바로 위에서도 언급했으니 패스하고

여기도 기존에 searchText가 `@Pulbished` Wrapper를 통해 Publisher 역할을 대신 했으나 이젠 그게 가능하지 않기에

```swift
@ObservationIgnored var searchSubject = PassthroughSubject<String, Never>()
```

별도의 subjectPublisher를 만들어 주었다.

그리고 didSet을 통해 자기 자신의 값이 바뀌면 그 값을 send를 통해 전달하게 하였다.

```swift
var searchText: String = "" {
   didSet {
      searchSubject.send(searchText)
   }
}
```

---

역시나 SearchView에서도 ProfileView와 같은 에러가 발생

```swift
Generic struct 'StateObject' requires that 'SearchViewModel' conform to 'ObservableObject'
```

object를 지워주도록 하자.

```swift
@State private var viewModel = SearchViewModel()
```

---

##### 또 App Crash 발생

이번에는 앱 실행 시점이 아니라 검색을 시작하는 순간 크래시가 발생했다.

크래시 로그를 확인해보니 다음과 같았다.

```swift
Thread 8 Crashed:
0  _dispatch_assert_queue_fail
...
4  closure #3 in SearchViewModel.init()
```

또한 Xcode에서도 `SearchViewModel.init()` 내부에서 문제가 발생한 것을 확인할 수 있었다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/635d9594-86b7-4a07-84e6-4707ee629db6" />

`SearchViewModel`은 `@MainActor`로 선언되어 있는데, 크래시 스택에는 `_dispatch_assert_queue_fail`이 찍혀 있었다.

[dispatch_assert_queue Docs](https://developer.apple.com/documentation/dispatch/dispatch_assert_queue){:target="_blank"}에 따르면 이 크래시는 코드가 예상된 Queue가 아닌 곳에서 실행될 때 발생한다.

따라서 `@MainActor` 상태를 변경하는 `sink` 내부를 가장 먼저 의심하게 되었다.

```swift
.sink(receiveValue: { [weak self] value in
    guard let self else { return }

    if value.isEmpty {
        self.status = .failure
    } else {
        self.status = .success(value)
    }

    self.users = value
})
```

위 코드는 `status`, `users`처럼 MainActor로 격리된 상태를 변경하고 있는데, Combine 체인에서 전달되는 값이 반드시 Main Queue에서 실행된다는 보장이 없다.

그래서 제거했던 `.receive(on: DispatchQueue.main)`를 다시 추가해주었다.

```swift
.receive(on: DispatchQueue.main)
```

그러자 SearchView는 정상적으로 동작했지만, 이번에는 `ProfileView`가 렌더링되는 시점에 동일한 크래시가 발생했다.

원인은 같았다.

`ProfileViewModel` 역시 Combine 체인에서 MainActor 상태를 변경하고 있었기 때문에 동일하게 `.receive(on: DispatchQueue.main)`를 복구해주었다.

그러자 모든 화면이 정상적으로 동작했다.

---

이와 비슷한 사례는 [Swift Issue](https://github.com/swiftlang/swift/issues/83339){:target="_blank"}에서도 찾아볼 수 있다.

해당 이슈를 제기한 Antoine van der Lee 역시 본인의 글인 [Combine and Swift Concurrency: A threading risk](https://www.avanderlee.com/concurrency/combine-and-swift-concurrency-a-threading-risk/){:target="_blank"}에서 같은 문제를 다루고 있다.

```
No compile-time feedback for sink closures

A crucial aspect of this crash is that compile-time safety does not apply to sink closures at this point.
```

번역하면 현재 시점에서는 `sink` 클로저에 대해 MainActor 격리 검사가 컴파일 타임에 수행되지 않는다는 의미다.

처음에는 `@MainActor`를 적용했으니 `.receive(on: DispatchQueue.main)`도 필요 없을 것이라고 생각했다.

하지만 Combine의 `sink` 클로저는 MainActor 격리에 대한 컴파일 타임 검사를 제공하지 않으며, 실제 실행 시점에는 다른 Queue에서 호출될 수 있다.

따라서 MainActor 상태를 변경하는 Combine 체인에서는 기존처럼 `.receive(on: DispatchQueue.main)`을 유지하는 것이 안전했다.

즉, `@MainActor`를 붙였다고 해서 Combine의 모든 `sink`가 자동으로 MainActor에서 실행되는 것은 아니었다.

---

##### 여기서 마지막 보완

이렇게 앱크래시 문제를 수정 다했지만 딱 한가지 아쉬워서 마지막으로 적어본다.

현재는 검색 화면에 진입한 뒤 검색창을 탭하기만 해도 검색 요청이 한 번 발생했다.

<img width="252" height="514" alt="Image" src="https://github.com/user-attachments/assets/128e5334-5f64-456b-8a85-232f4eda388c" />

이건 

```swift
var searchText: String = "" {
   didSet {
      searchSubject.send(searchText)
   }
}
```

검색창에 아무것도 입력하지 않았더라도 ""(빈 문자열)이 전달되면서 검색 파이프라인이 실행되고 있었던 것이다.

그래서 Publisher 단계에서 빈 문자열은 아예 전달되지 않도록 필터를 추가했다.

```swift
searchSubject
      .filter { !$0.isEmpty } // new
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
```

이렇게 하면 실제 검색어가 입력된 경우에만 실행이 된다.

<img width="252" height="514" alt="Image" src="https://github.com/user-attachments/assets/1647725c-7763-4182-9244-d71cf866f9a5" />

이제 검색창을 눌러도 불필요한 요청은 발생하지 않고, 사용자가 실제로 검색어를 입력했을 때만 검색이 수행된다.

---

이렇게 긴~~~~~ 작업이 모두 끝이났다.