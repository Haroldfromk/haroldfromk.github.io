---
title: GitExplorer (심화 2)
writer: Harold
date: 2026-06-01 08:06
#last_modified_at: 2026-05-31 21:30
categories: [GitExplorer]
tags: [Combine]

toc: true
toc_sticky: true
published: false
---

iOS 앱 전체를 끝낸것도아니고 위의 항목 하나를 끝내는데 글의 분량이 너무 많아져서 새롭게 글을 작성한다

## 보완해야 할 점

### iOS 앱
- [x] `ObservableObject` + `@Published` → `@Observable` 마이그레이션 [심화 1](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/){:target="_blank"}
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

## iOS

### 1. ProfileViewModel 로딩/성공/실패 상태 관리 추가

[이전글](https://haroldfromk.github.io/posts/GitExplorer(2)/){:target="_blank"}에서 이미 해봤기 때문에, 틀은 비슷하게 가져가되, 여기에 맞게 해주기만 하면 된다.

이렇게 관리를 하게 되면 이후에 있을 에러스트림을 다룰때도 도움이 되기 때문에 순서를 위로 올렸다.

#### enum을 통한 상태 관리

```swift
enum ProfileStatus {    
    case idle
    case loading
    case success(TotalProfile)
    case failure(Error)
}

final class ProfileViewModel {
   var status: ProfileStatus = .idle
   // 생략
}
```

이렇게 만들어 주었다.

---

이제 ViewModel을 보게되면

```swift
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
   .receive(on: DispatchQueue.main)
   .sink { [weak self] repos, followers, followings in
      self?.totalProfile = TotalProfile(repos: repos,
                                          followers: followers,
                                          followings: followings)
   }.store(in: &cancellables)
}
```

이렇게 CombineLastest3을 사용해서 값을 얻어서 totalProfile에 넣고 있는 구조이다.

우선은 이렇게 바꿔주었다.

```swift
init(requestUser: GithubUser) {
      Publishers.CombineLatest3(service.fetchGitData(requestType: .repo(requestUser.login))
         .catch { error -> Just<[GithubRepo]> in
               self.profileStatus = .failure(error)
               return Just([])
         }, service.fetchGitData(requestType: .follower(requestUser.login))
         .catch { error -> Just<[GithubUser]> in
               self.profileStatus = .failure(error)
               return Just([])
         }, service.fetchGitData(requestType: .following(requestUser.login))
         .catch { error -> Just<[GithubUser]> in
               self.profileStatus = .failure(error)
               return Just([])
         })
      .receive(on: DispatchQueue.main)
      .sink { [weak self] repos, followers, followings in
         self?.profileStatus = .loading
         self?.totalProfile = TotalProfile(repos: repos,
                                             followers: followers,
                                             followings: followings)
         self?.profileStatus = .success(self!.totalProfile)
      }.store(in: &cancellables)
   }
```

---

```swift
List {
   // 생략
}
.listStyle(.insetGrouped)
.overlay {
   switch viewModel.profileStatus {
   case .idle:
         EmptyView()
   case .loading:
         ProgressView()
   case .failure(let error):
         Text("\(error.localizedDescription)\n에러가 발생했습니다.")
            .foregroundStyle(.secondary)
   case .success:
         EmptyView()
   }
}
```

이렇게 ProfileView로 하고 실행했으나

원하는 결과가 나오지 않았다.

---


일단 

```swift
self?.profileStatus = .loading
self?.totalProfile = TotalProfile(repos: repos,
                        followers: followers,
                        followings: followings)
self?.profileStatus = .success(self!.totalProfile)
```

ProgressView가 안보이는 이유는 너무 빨리 지나가서 그렇다.

생각해보니 `handleEvents`가 있었는데 쓰질 않았다.

```swift
service.fetchGitData(requestType: .follower(requestUser.avatarUrl))
   .receive(on: DispatchQueue.main)
   .handleEvents(receiveOutput: { [weak self] _ in
         guard let self else { return }
         self.profileStatus = .loading
   })
   .catch { error -> Just<[GithubUser]> in
         print(error)
         self.profileStatus = .failure(error)
         return Just([])
   }
```

그래서 이런식으로 해주었다. 이때 `profileStatus` 변경은 mainThread에서 이루어져야 하므로 `.receive(on: DispatchQueue.main)`을 사용해 주었다.

`@MainActor`를 적용했다고 해서 Combine 체인까지 자동으로 Main Thread에서 실행되는 것은 아니다.

이 부분은 [심화 1](https://haroldfromk.github.io/posts/GitExplorer(%EC%8B%AC%ED%99%94-1)/){:target="_blank"}에서도 겪었던 문제이므로, 이번에도 동일하게 처리해주었다.

#### 상태가 덮어써지는 문제 발생

실행해보기 위해 일부러 `requestUser.login` 대신 `requestUser.avatarUrl`을 전달해보았다.

<img width="430" height="874" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-01-GitExplorer심화-2/a0e49bab-3a62-4d4d-b4e6-d885c35a5dff.png" />

분명 에러가 발생했는데도 화면은 정상적으로 표시된다.

하지만 Console에서는 

```
typeMismatch(Swift.Array<Any>, Swift.DecodingError.Context(codingPath: [], debugDescription: "Expected to decode Array<Any> but found a dictionary instead.", underlyingError: nil))
```

이렇게 에러가 발생했다.

문제의 원인은 `.catch`에 있었다.

```swift
.catch { error -> Just<[GithubUser]> in
    self.profileStatus = .failure(error)
    return Just([])
}
```

지금의 구조에서는 에러가 발생을 하더라도 `.catch`가 에러를 삼키고 빈 배열을 반환하기 때문에, `sink`는 항상 값을 받아 `.success`로 전환된다는 것이다.

즉 `failure` 상태가 세팅되더라도 이후에 `sink`가 실행되면서 바로 `.success`로 덮어버린다.

이 문제를 해결하려면 위의 보완 항목에 적어둔 **에러 스트림 통합** 작업을 먼저 진행해야 한다.

결국 상태 관리와 에러 처리는 따로 볼 수 있는 문제가 아니라 하나의 흐름으로 관리되어야 했기 때문이다.

그래서 다음 단계에서는 에러 스트림을 통합하는 구조로 변경해보려고 한다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-01-GitExplorer심화-2/58c1c494-d059-498e-af72-040460a84e2d.png" />

현재 상황을 대변해주는 만화를 만들어 봤다...

---

### 2. 에러 스트림 통합하기