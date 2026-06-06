---
title: GitExplorer (5)
writer: Harold
date: 2026-05-28 08:06
categories: [GitExplorer]
tags: [WatchOS]

toc: true
toc_sticky: true
---

## WatchOS 연동하기

기존에 Udemy강의에서 WatchOS 앱만들기를 했었는데 안타깝게도 기존 iOS App과의 연동은 없었다.

그래서 Docs를 보면서 연동을 직접 부딪혀가며 해보려 한다.

### 1. WathOS App 추가하기

기존에는 그냥 새로운 `프로젝트`로 만들었다면.

iOS App이 있다면 만드는 방법이 달라진다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/c80af5b0-aacb-42c1-87ff-fef8a309b481.png" />

이렇게 2가지 방법으로 추가를 하는데, **핵심은 `Target`을 추가한다.** 이다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/226e938c-d109-4b16-98b0-8227e9e6060c.png" />

이렇게 추가하면 전과 달리 기존 앱과 연동할수있게 선택하는 부분이 나온다. 이걸 체크해주면 된다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/981852b7-19c5-4c39-9fc7-ae6d9456ec28.png" />

Target을 추가하면 늘 뜨는 Scheme추가. 이번에도 해준다.

이제 기본적인 준비는 끝났다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/fb1ee57c-d868-4789-87e6-c67cecbe696d.png" />

---

### 2. iOS → Watch 데이터 전송

[Transferring data with Watch Connectivity Docs](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity){:target="_blank"}를 참고하여 만들어 보도록 한다.

iOS App과 WatchOS App의 데이터를 주고받는 대표적인 방법이 바로 **Watch Connectivity** 다.

---

#### [[Watch Connectivity Docs](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity){:target="_blank"} 요약]

* **개념:** iOS 앱과 watchOS 앱 사이에서 데이터를 주고받기 위한 Apple 전용 통신 프레임워크다.

* **전제 조건:** 데이터를 주고받기 전에 양쪽 앱 모두에서 세션을 초기화하고 활성화해야 한다.

```swift
import WatchConnectivity

if WCSession.isSupported() {
    let session = WCSession.default
    session.delegate = self // WCSessionDelegate 프로토콜 구현 필수
    session.activate()
}
```

---

##### 1. 실시간 메시지 (Interactive Messaging)

* **사용 메서드:** `sendMessage(_:replyHandler:errorHandler:)`
* **특징:** 두 앱이 동시에 켜져 있을 때만 동작한다. 딕셔너리를 전송하면 `replyHandler`로 상대 앱의 응답을 바로 받을 수 있다.

```swift
let message = ["request": "updateData"]
WCSession.default.sendMessage(message, replyHandler: { response in
    print("응답 수신: \(response)")
}, errorHandler: { error in
    print("전송 실패: \(error.localizedDescription)")
})
```

---

##### 2. 백그라운드 데이터 전송 (Background Transfers)

상대 앱이 꺼져 있어도 시스템이 적절한 타이밍에 전송해준다. 3가지 방식이 있다.

---

###### A. Application Context
* **사용 메서드:** `updateApplicationContext(_:)`
* **특징:** 딕셔너리를 여러 번 보내면 마지막 것만 전달된다. 최신 상태 하나만 유지하면 되는 경우에 사용한다. (예: 다크모드 설정, 프로필 상태 등)

```swift
do {
    try WCSession.default.updateApplicationContext(["theme": "dark"])
} catch {
    print("컨텍스트 업데이트 실패")
}
```

---

###### B. User Info
* **사용 메서드:** `transferUserInfo(_:)`
* **특징:** 보낸 순서대로 유실 없이 전달된다. 나중에 앱이 켜져도 밀린 데이터를 순서대로 다 받는다. (예: 운동 로그 등)

```swift
let userInfo = ["logId": 102, "steps": 5000]
WCSession.default.transferUserInfo(userInfo)
```

---

###### C. File Transfer
* **사용 메서드:** `transferFile(_:metadata:)`
* **특징:** 이미지나 대용량 파일을 백그라운드에서 전송할 때 사용한다. 메타데이터를 함께 보낼 수 있다.

```swift
let fileURL = URL(fileURLWithPath: "path/to/image.png")
WCSession.default.transferFile(fileURL, metadata: ["contentType": "avatar"])
```

---

#### [[WCSession Docs](https://developer.apple.com/documentation/watchconnectivity/wcsession){:target="_blank"} 요약]

* **개념:** Watch Connectivity 통신을 담당하는 핵심 객체다. 싱글톤이라 항상 `WCSession.default`로 접근한다.

---

##### 1. 주요 프로퍼티

* **`isSupported()`** - 현재 기기에서 Watch Connectivity 사용 가능 여부를 확인한다. iOS에서는 반드시 `true`일 때만 세션을 설정해야 한다. (watchOS는 항상 `true`)

* **`activationState`** - 세션 활성화 상태를 나타낸다. `.notActivated` → `.activating` → `.activated` 순이며, 데이터 전송은 `.activated` 상태에서만 가능하다.

* **`isReachable`** - 실시간 메시지(`sendMessage`) 전송 가능 여부를 확인한다. 양쪽 앱이 포그라운드 혹은 백그라운드에서 실행 중일 때 `true`가 된다.

---

##### 2. iOS 전용 프로퍼티

iPhone은 여러 Apple Watch와 연결될 수 있어서 iOS 앱에서는 현재 연결된 Watch 상태를 추가로 확인해야 한다.

* **`isPaired`** - Apple Watch가 페어링되어 있는지 확인한다.

* **`isWatchAppInstalled`** - 연결된 Watch에 내 앱이 설치되어 있는지 확인한다. 설치가 안 되어 있으면 데이터를 보낼 수 없다.

* **`remainingComplicationUserInfoTransfers`** - 당일 남은 컴플리케이션 데이터 전송 가능 횟수를 반환한다.

---

##### 3. 세션 활성화

```swift
if WCSession.isSupported() {
    let session = WCSession.default
    session.delegate = self // WCSessionDelegate 구현 필수
    session.activate()
}
```

`activate()`는 비동기로 동작하며, 활성화가 완료되면 `WCSessionDelegate`를 통해 결과를 받는다.

---

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/11eb1c51-e940-41ef-96d1-3eb68b0402a5.png" />

이건 정리사진

---

#### 직접 해보기

[Kodeco Watch Connectivity](https://www.kodeco.com/books/watchos-with-swiftui-by-tutorials/v1.0/chapters/4-watch-connectivity){:target="_blank"}[Medium Integrating WatchConnectivity in a SwiftUI App: A Step-by-Step Guide](https://medium.com/@shahadmal/integrating-watchconnectivity-in-a-swiftui-app-a-step-by-step-guide-4a99008d690e){:target="_blank"}글이 상당히 정리가 잘되어있어서 이걸 참고해서 연동을 해본다.

---

##### 1. iOS App

###### 1. WCSession 세팅

여러 자료를 찾아본 결과 `WCSession`은 iOS와 WatchOS의 소통 창구라고 봐야한다고 생각했다.

```
WatchOS  ⇄  WCSession  ⇄  iOS App
```
즉 이런 사이

이때 서로 소통을 하기 위해선 양쪽에 `WCSession`을 만들어 줘야 한다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/57e06db6-a0a5-419b-918f-12b10ec958a9.png" />

이때 중요한건 반드시 **Target**을 확인해줘야 한다.

```swift
GitExploereApp(iOS) → GitExplorer
GitExploereWatchApp(WatchOS) → GitExploereWatch Watch App
```

그리고 만들고나서 GitExplorer와 버전을 맞춰주기위해
WatchOS 버전을 11.5로 해주었다.

```
GitExplorer: 18.5
GitExplorerWatchApp: 11.5
```

---

이때

```
WatchConnectivityService
    ↙            ↘
GitExplorer   GitExplorerWatch
(iOS)            (watchOS)
```

이런식으로 해서 애초에 만들때 target 2개를 전부 체크하는 경우도 있긴 하다.

하지만 나는 iOS / watchOS 파일을 분리해서 관리할 예정이다. 혼동을 방지하고 코드 관리를 명확하게 하기 위해서다.

1개일때는 

보통 

```swift
override init() {
    super.init()
    #if !os(watchOS)
    guard WCSession.isSupported() else { return }
    #endif
    session.delegate = self
    session.activate()
}
```

뭐 이런식으로 하는데 지금은 pass

이제 진짜 GitExplorer 앱에 적용을 해본다.

WCSession을 사용하려면 기본적으로 해야하는 4가지 작업이 있다.

1. Create a session
2. Initialize the session
3. Assign its delegate to the class
4. Activate the session

```swift
// 1, 2. Create a session and Initialize
private var session = WCSession.default
    
override init() {
    super.init()
    if WCSession.isSupported() {
        // 3. Assign its delegate to the class
        session.delegate = self
        // 4. Activate the session
        session.activate()
    }
}
```

이게 바로 그 4가지 작업이다.

그전에 `if WCSession.isSupported()` 를 사용해서 혹시라도 WCSession을 지원하지 않는 기종이 WCSession을 사용했을때 발생하는 문제를 미리 사전에 방지하기위해 위의 조건을 걸어주었다.

지금은 이렇게 session을 만들면서 초기화를 해주었는데

`var session: WCSession` 이렇게 만들고 init 내부에서 해주는 방법도 있다.

무튼 이렇게 해주면

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/9d7e5fd8-7584-40e5-8903-179570aee321.png" />

이렇게 WCSessionDelegate 사용시 필요한 함수가 없다고 에러가 뜬다.

apply 해주면된다.

```swift
// iPhone ↔ Watch 간 WCSession 활성화가 완료되었을 때 호출
// 즉, WatchConnectivity 통신을 시작할 준비가 끝난 시점
func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
) { }
```

```swift
// 기존 WCSession이 비활성 상태로 전환될 때 호출
// 주로 Apple Watch 변경 또는 새로운 세션 전환 직전에 호출된다.
func sessionDidBecomeInactive(_ session: WCSession) { }
```

```swift
// 기존 WCSession 연결이 완전히 종료되었을 때 호출
// 보통 이 시점에서 다시 session.activate()를 호출해 새로운 세션을 활성화한다.
func sessionDidDeactivate(_ session: WCSession) { 
    self.session.activate()
}
```

이렇게 총 3개의 함수가 생긴다.

그리고 이때 `NSObject`이 필수인 이유는 `WCSessionDelegate`가 `NSObjectProtocol`을 요구하기 때문이다. 

**즉 NSObject를 상속하지 않으면 델리게이트 채택 자체가 안 된다.**

---

###### 2. 모델링

앱의 초기 단계라면 모델링은 당연한 순서이다.

우리는 이미 해둔 상태이므로 pass

[GitExplorer Modeling](https://haroldfromk.github.io/posts/GitExplorer(2)/){:target="_blank"}은 여기.

---

###### 3. 데이터 전송 함수 만들기

이제 필요한건 데이터 전송이다.

먼저 생각을 해보면 

**앱 시점**

1. 앱에서 즐겨찾기한 유져의 정보를 보낸다.
2. Watch에서 그 정보를 받아서 워치내 View로 보여준다.

---

**Watch 시점**

1. Watch에서 즐겨찾기 목록을 삭제를 하고 그 정보가 앱으로 전달된다.
2. 앱에선 그 정보를 받아 즐겨찾기 목록을 업데이트한다.

이렇게 된다.

굳이 watch 시점 까지 적은 이유는 즐겨찾기 목록을 삭제하면 앱에서 그 정보를 받아야 하기 때문이다.

즉 지금 하고자하는건

```swift
❌ iOS App → WatchOS 
✅ iOS App ⇄ WatchOS 
```

이런 방식이다.

---

보낼때는 2가지 방법이 있다.
1. sendMessage
2. sendMessageData

지금은 즐겨찾기 유저를 전달해야하므로 Data로 한다.

**이때 우리가 원하는 데이터 타입으로 보내는게 아니라 Data Type으로 인코딩을 해서 보내야한다.**

```swift
func sendFavoriteUsers(_ users: [GithubUser]) {
    guard WCSession.default.activationState == .activated else { return }
    guard let data = try? JSONEncoder().encode(users) else {
        return
    }
    self.session.sendMessageData(data, replyHandler: nil)
}
```

이때 Kodeco에서 언급한 내용을 보면 아래 사항을 반드시 확인해야 한다고 한다.

- `activationState`가 `.activated`가 아니면 전송 자체가 불가능하다. 
    - 배터리가 방전되거나 워치를 교체하는 중일 때 `.activated`가 아닐 수 있다.
- iOS와 watchOS에서 companion 앱 확인 메서드 이름이 다르다. 
    - watchOS에서는 `isCompanionAppInstalled`
    - iOS에서는 `isWatchAppInstalled`다. 레거시 코드 때문에 Apple이 따로 만들었다고 한다.

그래서 State를 activated로 해주었다.

---

###### 4. FavoriteViewModel에서 전달하기

`FavoriteViewModel`에 `WatchConnectivityService` 인스턴스를 추가했다.

```swift
private let watchConnectivity = WatchConnectivityService()
```

처음엔 `asyncFetchFavoriteDataBefore`가 끝나는 시점에 `sendFavoriteUsers`를 호출하려고 했다.

이 함수가 즐겨찾기 유저 목록을 순서대로 담아주는 역할을 하기 때문이다.

근데 문제가 있었다.

즐겨찾기 추가/삭제/갱신 각각의 시점마다 전송 코드를 따로 넣어야 했고, 추가할 때는 `asyncFetchFavoriteDataBefore`를 호출하지 않아서 Watch에 전송이 안 되는 케이스가 생겼다.

별도의 Subject를 만드는 것도 고려했는데, Watch 전용 Subject를 추가/삭제 2개 만들어야 해서 오히려 복잡해졌다.

결국 `$users`를 구독하는 방식으로 해결했다.

```swift
$users
    .dropFirst()
    .sink { [weak self] users in
        self?.watchConnectivity.sendFavoriteUsers(users)
    }
    .store(in: &cancellables)
```

`users`가 바뀌는 시점은 추가/삭제/갱신 모두 포함하기 때문에 한 곳에서 전부 커버된다.

`dropFirst()`는 초기값인 빈 배열이 Watch로 전송되는 걸 막기 위해서다.

조금 더 설명을 하자면

`users`는 선언 시점에 빈 배열로 초기화되고, 실제 데이터는 `reloadData()`가 끝난 후에 채워진다.

`$users`는 선언 시점부터 구독이 시작되기 때문에 `dropFirst()`가 없으면 앱 시작 시 빈 배열이 Watch로 전송된다.

네트워크 응답 전에 빈 데이터가 날아가는 셈이라 Watch 입장에서는 목록이 비어있는 것처럼 보일 수 있기에 `dropFirst()`를 써준다.

---

##### 2. WatchOS App
###### 1. WCSession 세팅

```swift
import WatchConnectivity

final class WatchConnectivityService: NSObject, WCSessionDelegate {
    
    private var session = WCSession.default
    
    override init() {
        super.init()
            session.delegate = self
            session.activate()
    }
    
}
```

일단 기본 뼈대는 같다.

다만 WatchOS의 경우 세션을 항상 지원하기에 위에서 언급한 조건은 없다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/61e4b874-f1ea-41c6-874d-56bf4dd1e66a.png" />

다만 역시나 Watch쪽에서도 Delegate 사용시 기본적으로 사용해야할 함수가 있으므로 Apply를 해주자.

그러면 `activationDidCompleteWith`이게 나온다.

위에걸 그대로 복사해주었다.

```swift
func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
    if let error = error {
        print(error.localizedDescription)
    } else {
        print("The session has completed activation.")
    }
}
```

다만 iOS와 다르게 watchOS는 `sessionDidBecomeInactive`, `sessionDidDeactivate` 가 없다.

iOS는 여러 대의 Apple Watch와 연결될 수 있어서 기기 교체 시 세션 비활성화/재활성화 처리가 필요하지만, watchOS는 항상 하나의 iPhone과만 연결되기 때문에 해당 메서드가 존재하지 않는다.

---

###### 2. 데이터 수신 함수 만들기

App에서 보냈으니 이젠 Watch에서 받으면 된다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/d5beef1d-2996-429b-9310-57b8d2e1c26f.png" />

이건 Delegate가 지원해주는 함수를 사용해주면 된다.

그리고 굳이 여기서 디코딩 관련해서 `Manager나 Service`를 만들 필요는 없다.

```swift
@Published var users: [GithubUser] = []

func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let userData = try? JSONDecoder().decode([GithubUser].self, from: messageData) else { return }
        users = userData
    }
}
```

ui는 Main Thread에서 행해져야 하므로 `DispatchQueue`를 사용해주었다.

---

###### 3. 데이터 통신 확인하기.

이제 WatchOS에 view에 적용하면 된다.

```swift
import SwiftUI

@main
struct GitExplorerWatch_Watch_AppApp: App {
    
    @StateObject private var watchConnectivity = WatchConnectivityService()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack{
                FavoritesListView(favorites: watchConnectivity.users)
            }
        }
    }
}
```

이미 view들을 만들어 뒀기에, ContentView를 빼고 `FavoritesListView`를 사용해주었다.

이제 실행을 해볼 차례다

실행할때 

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/4cca86ef-3ed9-4ad7-a126-2e9af1bd95c5.png" />

여기 리스트에 있는걸 해줘야 같이 실행이 된다.

만약 나만의 시뮬레이터 조합을 하고 싶다면?

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/a0f327e5-37f9-4c3d-beea-43f850039f46.png" />

여기서 만들어주면 된다.

---

일단 실행하면 이렇게 첫화면이 나온다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/563b2ca3-87d2-4a24-b0ee-f3b4380a9a9a.png" />

이제 앱에서 즐겨찾기를 추가해서 확인해보도록 한다.

<img width="442" height="546" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/2dea28fd-c4a4-435c-9952-d276e04feaec.png" />

잘되는걸 알 수 있다.

다만 지금은 즐겨찾기 화면에 가야만 데이터를 받아오는 문제가 있다.

---

###### 4. 문제 수정하기

처음에 앱이 실행되었을때는 값을 가져오지 않기때문에 이부분을 좀 해결하려고한다.

일단은 의존성주입을 한다.

```swift
struct GitExplorerApp: App {
    @StateObject private var favoriteViewModel = FavoriteViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favoriteViewModel)
        }
    }
}
```

이후 `FavoriteViewModel()`을 사용하는 `ProfileView, FavoriteView`에서 썼던

```swift
// Before
@StateObject private var favoriteViewModel = FavoriteViewModel()
// After
@EnvironmentObject var viewModel: FavoriteViewModel
```

이렇게 바꿔주면 된다.

그리고 `ContentView`에서 앱 시작 시점에 바로 데이터를 불러오도록 했다.

```swift
struct ContentView: View {
    
    @EnvironmentObject var viewModel: FavoriteViewModel
    
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            FavoriteView()
                .tabItem {
                    Label("Favorites", systemImage: "star")
                }
        }
        .task {
            do {
                try await viewModel.reloadData()
            } catch {
                print(error)
            }
        }
    }
}
```

이러면 실행하자마자 값을 가져오게 된다.

---

그리고 기존 `FavoriteView`의 `.task`에서 `reloadData()`와 `refreshData(isRefresh: true)` 를 같이 호출하고 있었다.

`reloadData()`는 `ContentView`로 옮겼기 때문에, `FavoriteView`의 `.task`에는 타이머 관련 코드만 남게 되었다.

`.task`는 뷰가 나타날 때 한 번 실행되는 건 `onAppear`와 같지만, 비동기 작업을 위한 것이라 타이머 시작처럼 동기 작업만 남은 상황에서는 `.onAppear`가 더 적합하다.

그래서 `.task` 대신 `.onAppear`로 교체했다.

```swift
// Before
.task {
    do {
        try await viewModel.reloadData()
    } catch {
        print(error)
    }
    isRefresh = true
    viewModel.refreshData(isRefresh: true)
}

// After
.onAppear {
    viewModel.refreshData(isRefresh: true)
}
```

---

다만 한 가지 치명적인 문제가 있었다.

처음에는 `sendMessageData`와 `didReceiveMessageData` 조합으로 구현했다.

```swift
// iOS - 전송
func sendFavoriteUsers(_ users: [GithubUser]) {
    guard WCSession.default.activationState == .activated else { return }
    guard let data = try? JSONEncoder().encode(users) else { return }
    self.session.sendMessageData(data, replyHandler: nil)
}

// Watch - 수신
func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let userData = try? JSONDecoder().decode([GithubUser].self, from: messageData) else { return }
        users = userData
    }
}
```

Watch 타겟으로 빌드하면 iOS 시뮬레이터가 홈 화면으로 넘어간다.

이 상태에서 iOS 앱을 직접 실행해서 테스트해야 하는 구조인데, iOS 타겟으로만 실행하면 Watch 쪽에서 아래 에러가 발생했다.

```
WCSession is not reachable
-[WCSession _onqueue_notifyOfMessageError:messageID:withErrorHandler:] (null) errorHandler: NO with WCErrorCodeNotReachable
```

`sendMessageData`는 양쪽 앱이 동시에 foreground + reachable 상태여야 동작한다.

시뮬레이터 환경에서는 이 조건이 불안정해서 됐다 안됐다 하는 문제가 있었다.

그래서 `updateApplicationContext`로 변경했다.

```swift
// iOS - 전송
func sendFavoriteUsers(_ users: [GithubUser]) {
    guard WCSession.default.activationState == .activated else { return }
    guard let data = try? JSONEncoder().encode(users) else { return }
    try? session.updateApplicationContext(["users": data])
}

// Watch - 수신
func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    guard let data = applicationContext["users"] as? Data else { return }
    guard let userData = try? JSONDecoder().decode([GithubUser].self, from: data) else { return }
    DispatchQueue.main.async {
        self.users = userData
    }
}
```

`updateApplicationContext`는 백그라운드에서도 동작하기 때문에 시뮬레이터에서도 안정적으로 동작한다.

실기기에서는 `sendMessageData`도 동작하지만, 시뮬레이터 테스트 환경에서는 `updateApplicationContext`를 사용하는 것이 낫다.

결국 시뮬레이터 환경에서 `sendMessageData`는 됐다 안됐다 하는 불안정한 동작을 보여서, 최종적으로는 `sendMessageData`를 유지하되 시뮬레이터 테스트 시에는 `updateApplicationContext`로 교체해서 쓰는 방식으로 결론을 냈다.

---

둘을 비교해보면

| | `sendMessageData` | `updateApplicationContext` |
|---|---|---|
| 전송 방식 | 실시간 (Interactive Messaging) | 상태 동기화 (State Synchronization) |
| 동작 조건 | `isReachable == true` 필요 | 상대 앱이 비활성 상태여도 가능 |
| 데이터 처리 방식 | 즉시 전달 시도 (실패 시 유실 가능) | 최신 상태만 유지 |
| 시뮬레이터 | 불안정한 편 | 비교적 안정적 |
| 실기기 | 정상 동작 | 정상 동작 |
| 적합한 상황 | 즉각적인 요청/응답 | 최신 상태 공유 |

---

그리고 테스트를 하다 또 문제점을 발견햇는데 기존에는 `FavoriteView`의 `.task`에서 `reloadData()`를 호출하는 구조였다.

즉 `FavoriteView`에 진입할 때마다 자동으로 데이터를 갱신했다.

하지만 `ContentView`에서 앱 시작 시점에 `reloadData()`를 호출하는 구조로 바꾸면서 문제가 생겼다.

`FavoriteView`에 진입해도 더 이상 갱신이 일어나지 않기 때문에, 즐겨찾기를 추가해도 목록에 반영이 안 되는 문제가 발생했다.

그래서 `addSubject` sink에도 `asyncFetchFavoriteDataBefore()`를 추가해서 추가/삭제 시점에 직접 데이터를 갱신하도록 수정했다.

```swift
addSubject
    .receive(on: DispatchQueue.main)
    .sink { [weak self] id in
        self?.names.append(id)
        UserDefaults.standard.set(self?.names, forKey: Constants.favoritesKey)
        Task {
            try? await self?.asyncFetchFavoriteDataBefore()
        }
    }.store(in: &cancellables)
```

<img width="460" height="548" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/19af2e0e-1f90-4733-95a7-b9098fc3da7c.png" />

최종적으로 테스트를 한 결과이다.

잘 되는걸 알 수 있다.

---

### 3. Watch → iOS 데이터 전송

이제는 WatchOS에서 삭제를 하면 그게 iOS로 전달되어 iOS에서도 즐겨찾기 삭제가 연동되도록 해보려 한다.

---

#### 1. WatchOS에서 삭제 기능 추가
##### 1. View 수정
우선 view에 `onDelete` Modifier를 추가해야한다.

```swift
// Before
List(favorites) { user in
    NavigationLink(destination: ProfileDetailView(user: user)) {
        HStack(spacing: 10) {
            AvatarView(url: user.avatarUrl, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.login)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(user.publicRepos ?? 0) repos · \(user.followers ?? 0) followers")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    .listRowBackground(Color(white: 0.15))
}
// After
List {
    ForEach(favorites) { user in
        NavigationLink(destination: ProfileDetailView(user: user)) {
            HStack(spacing: 10) {
                AvatarView(url: user.avatarUrl, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.login)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(user.publicRepos ?? 0) repos · \(user.followers ?? 0) followers")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color(white: 0.15))
    }
    .onDelete { indexSet in
        if let index = indexSet.first {
            
        }
    }
}
```

이렇게 해주었다. List에 바로 `.onDelete`를 달 수 없기에, Foreach를 사용해주었다.

---

##### 2. WatchConnectivityService 함수 추가

```swift
func sendDeleteMessage(_ user: String) {
    guard session.activationState == .activated else { return }
    guard session.isReachable else { return }
    let message = ["delete": user]
    session.sendMessage(message, replyHandler: nil)
}
```

여기도 위에서와 같이 `activated`일때만 가능하므로 위에 먼저 명시를 해주었다.

`sendMessage`는 `isReachable`이 `true`일 때만 동작하기 때문에 체크를 추가해주었다.

그리고 여기선 굳이 Data형식으로 보내는게 아니라 나는 즐겨찾기에서 삭제할 유저 아이디만 iOS 너에게 보낼게 라는 느낌으로 `sendMessage`를 써주었다.

근데 이때 message는 Dictionary type이다.

---

그리고 다시 view로 돌아가서

```swift
.onDelete { indexSet in
    if let index = indexSet.first {
        let user = favorites[index].login
        watchConnectivity.users.remove(at: index)
        watchConnectivity.sendDeleteMessage(user)
    }
}
```

이렇게 삭제 부분을 작성해준다.

#### 2. 받은 데이터를 iOS에서 처리하기

순서는 이렇다

1. watch에서 즐겨찾기 삭제한 유저의 id를 전송
2. ios에서 그걸 수신하여 목록에서 삭제
3. uiupdate

---

##### 1. iOS App에서 수신하기.

이것도 Delegate가 제공하는 `didReceiveMessage` 가 있기에 이걸 사용해주면 된다.

---

###### 1. 기본 수신 구조

```swift
func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let user = message["delete"] as? String else { return }
        
    }
}
```

`message`가 `[String: Any]` 딕셔너리인 이유는 Watch에서 `sendMessage`로 보낼 때 딕셔너리 형식으로 보냈기 때문이다.

```swift
// Watch에서 보낸 코드
let message = ["delete": user]
// 여기서 user는 즐겨찾기 삭제한 유져의 id정보
```

딕셔너리는 `key: value` 구조로 이루어져 있다. 우리가 필요한 건 삭제할 유저의 id값 이므로, Watch에서 보낼 때 key를 `"delete"`로 지정했다. 

따라서 수신 측에서도 동일한 key인 `"delete"`로 값을 꺼내야 한다.

`as? String` 타입캐스팅이 필요한 이유는 딕셔너리의 값 타입이 `Any`라서 실제로 꺼낼 때 어떤 타입인지 명시해줘야 하기 때문이다. 

login은 `String`이므로 `as? String`으로 캐스팅해준다.

---

###### 2. ViewModel 연결 문제

여기서 viewModel을 가져와서 삭제 로직을 작성해야 한다.

나머지는 `FavoriteViewModel`에 대해 App에서 객체를 만들어서 의존성 주입을 하고 있는데, `WatchConnectivityService`는 `@EnvironmentObject`를 쓸 수 없다.

`@EnvironmentObject`는 SwiftUI View 계층에서만 동작하는 Property Wrapper이기 때문이다. SwiftUI가 View Tree를 생성하면서 Environment를 주입해주는 구조라서, `NSObject` 기반의 클래스에서는 사용할 수 없다.

```swift
final class WatchConnectivityService: NSObject {
    @EnvironmentObject var viewModel: FavoriteViewModel // ❌ 불가능
}

struct ContentView: View {
    @EnvironmentObject var viewModel: FavoriteViewModel // ✅ 가능
}
```

---

###### 3. 연결 방식 비교

그래서 Service ↔ ViewModel 연결은 아래 방식으로 처리해야 한다.

```swift
// 1. 생성자 주입 - 초기화 시점에 의존성을 확정, 이후 변경 불가
final class WatchConnectivityService: NSObject {
    private let viewModel: FavoriteViewModel
    init(viewModel: FavoriteViewModel) {
        self.viewModel = viewModel
    }
}

// 2. 속성 주입 - 초기화 이후에도 주입 가능, 선택적 의존성에 적합
final class WatchConnectivityService: NSObject {
    weak var favoriteViewModel: FavoriteViewModel?
}

// 3. Delegate - 프로토콜로 규칙을 정의하고 채택하는 방식, 규모가 클수록 유리
protocol WatchConnectivityDelegate: AnyObject {
    func didReceiveDeleteRequest(login: String)
}

final class WatchConnectivityService: NSObject {
    weak var delegate: WatchConnectivityDelegate?
}

// FavoriteViewModel에서 채택
extension FavoriteViewModel: WatchConnectivityDelegate {
    func didReceiveDeleteRequest(login: String) {
        removeToFavorite(id: login)
    }
}
```

생성자 주입은 초기화 시점에 의존성이 확정되기 때문에 이후 변경이 불가능하다. 반드시 필요한 의존성에 적합하다.

속성 주입은 초기화 이후에도 주입이 가능하다. 선택적인 의존성이거나 나중에 연결해야 하는 경우에 적합하다. 다만 주입 전에 접근하면 `nil`이 될 수 있다.

---

###### 4. ViewModel 적용하기

```swift
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    
    private var session = WCSession.default
    weak var viewModel: FavoriteViewModel?
    // 생략
}

struct GitExplorerApp: App {
    @StateObject private var favoriteViewModel = FavoriteViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(favoriteViewModel)
                .onAppear {
                    favoriteViewModel.watchConnectivity.favoriteViewModel = favoriteViewModel
                }
        }
    }
}
```

이렇게 속성 주입 방식으로 연결해주었다.

--- 

###### 5. 순환 참조?

이때 `WatchConnectivityService`에서 `weak var`로 선언해야 순환 참조를 방지할 수 있다.

```swift
favoriteViewModel.watchConnectivity.viewModel = favoriteViewModel
```

이 부분을 자세히 보면 favoriteViewModel이 결국 자기 자신에 대해 주입을 하는? 이상한 느낌의 코드로 될 수 있다.

즉 

```swift
FavoriteViewModel ◀────────────────────────┐
        │                                  │
        │ strong reference                 │
        ▼                                  │
WatchConnectivityService                   │
        │                                  │
        │ strong reference (var)           │
        ▼                                  │
FavoriteViewModel ─────────────────────────┘
```

이렇게 자기 자신을 가리키는 구조가 되기때문에

`var viewModel: FavoriteViewModel?` 대신 `weak var viewModel: FavoriteViewModel?` 를 꼭 써줘야 한다.

사진으로 정리하면 다음과 같다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/4b412434-a4ca-4c5e-8f48-502175585f72.png" />

이렇게 한쪽을 약한 참조로 끊어줘야 메모리에서 정상적으로 해제된다.

---

###### 6. 수신 및 삭제 처리

이제 ViewModel도 연결됐으니 수신한 user를 바탕으로 삭제 처리를 해주면 된다.

```swift
func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let user = message["delete"] as? String else { return }
        viewModel?.removeToFavorite(id: user)
    }
}
```

Watch에서 보낸 `"delete"` 키의 값을 꺼내서 `removeToFavorite`에 넘겨주면 iOS 즐겨찾기 목록에서도 삭제된다.

`viewModel`이 `weak var`라 옵셔널 체이닝(`?.`)으로 접근해야 한다.

---

실행하면?

<img width="460" height="548" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/66db8016-4953-4955-b773-e1637fb2cbce.png" />{: width="50%" height="50%"}

삭제는 잘 된다.

---

##### 2. 문제해결: EnvironmentObject 연결

다만 지금 삭제시 iOS App에서 업데이트를 못하고 있다.

`FavoritesListView`에서 `onDelete` 처리를 하려면 `WatchConnectivityService`에 접근해야 한다.

처음엔 `FavoritesListView` 안에서 직접 인스턴스를 만들었는데 문제가 있었다.

```swift
// ❌ 이렇게 하면 GitExplorerWatchApp의 인스턴스와 다른 객체
private let watchConnectivity = WatchConnectivityService()
```

`GitExplorerWatchApp`에서 만든 인스턴스와 다른 객체라서 삭제해도 뷰에 반영이 안 된다.

그래서 `environmentObject`로 같은 인스턴스를 공유하도록 수정했다.

```swift
// GitExplorerWatchApp
@main
struct GitExplorerWatch_Watch_AppApp: App {
    
    @StateObject private var watchConnectivity = WatchConnectivityService()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                FavoritesListView(favorites: watchConnectivity.users)
            }
            .environmentObject(watchConnectivity)
        }
    }
}
```

```swift
// FavoritesListView
@EnvironmentObject var watchConnectivity: WatchConnectivityService
```

이렇게 하면 같은 인스턴스를 공유하기 때문에 `onDelete`에서 삭제해도 뷰에 바로 반영된다.

---

실행하니 잘 된다.

다만 테스트할때 iOS Simulator와 WatchOS Simulator 간 페어링이 잘 안되는 문제가 꽤나 심각하다.

이건 실기기로 테스트를 하는게 제일 베스트인것같다.

<img width="460" height="548" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/1c7cf3f1-110b-40e0-a6cd-b7396488d7fc.png" />{: width="50%" height="50%"}

---

##### 3. 추가 보완

Watch에서 즐겨찾기를 삭제하면 iOS의 `ProfileView`에서 별표가 바뀌지 않는 문제가 있었다.

<img width="460" height="548" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/2b4eb029-cd7b-4966-82eb-a3b1e24a8fa6.png" />

`isFavorite`이 `onAppear`에서 한 번만 체크하는 구조라서 이후 변경을 감지하지 못하기 때문이다.

`favoriteViewModel.$names`를 구독해서 변경될 때마다 `isFavorite`을 업데이트하도록 수정했다.

```swift
.onReceive(favoriteViewModel.$names) { names in
    isFavorite = names.contains(user.login)
}
```

<img width="460" height="548" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-28-GitExplorer5/f2204377-785c-4281-bba5-f76f1320d747.png" />

---

이렇게 WatchOS 연동도 해보았다.

---

## 내용 추가 (5.30)

다시 실행하던중 iOS 시뮬레이터만 뜨고 WatchOS가 실행이 안되는 문제 발생

Simulator를 다시만들어도 안되고 terminal로도 여러 명령어를 쳐봤지만 전혀 효력이 없었다.

결국 WatchOS Target을 새로 만들었다. (즉 WatchOS 앱을 새로 만들었다는 것)

그랬더니 문제가 해결되었다.