---
title: GitExplorer (2)
writer: Harold
date: 2026-05-22 08:06
categories: [GitExplorer]
tags: [Combine]

toc: true
toc_sticky: true
---

## Day 2: 프로필 화면 만들기
### 미션 (Task)

1. **화면 상태 나누기**
   - 유저를 선택하여 프로필 상세 화면으로 이동 시, 화면의 현재 상태를 **로딩 중, 성공, 실패**로 명확히 분리할 것
   - 데이터 상태에 따라 UI가 즉각적으로 변화하는 반응형 환경을 구축할 것

2. **여러 API 한번에 불러오기**
   - 프로필 정보, 레포지토리 목록, 팔로워 목록을 가져오는 **3개의 독립적인 네트워크 요청을 동시에 출발**시킬 것
   - 세 가지 데이터가 모두 안전하게 도착한 시점을 포착하여, 하나의 완전한 '프로필 화면 통합 데이터 모델'로 조립해 낼 것

3. **에러 한 곳에서 처리하기**
   - 프로필과 레포지토리 에러처럼 출처가 다른 에러들을 유저 관점에서 하나의 화면 문제로 통일할 것
   - 흩어져 있는 **여러 에러 발생지들을 단일 파이프라인으로 묶어**, 단 하나의 경고창 시스템으로 일관성 있게 처리할 것

---

### 1. 화면 상태 나누기

1. 유저를 선택하여 프로필 상세 화면으로 이동 시, 화면의 현재 상태를 **로딩 중, 성공, 실패**로 명확히 분리할 것
2. 데이터 상태에 따라 UI가 즉각적으로 변화하는 반응형 환경을 구축할 것

---

일단은 검색결과에 대해서 UI표시가 되어야 한다.

#### 1. GitHubNetworkService, ViewModel 수정

현재 Service의 경우 한유져에 대해서 검색을 하는게 아니라 검색결과를 포함하는 유져에 대해서 검색하므로 코드 수정이 필요하다.

우선 이젠 한명의 유저에 대해서 가져오기에 url을 수정할뿐만아니라 모델링도 같이 손본다.

모델링의 경우 기존의 `GithubResult`를 삭제해준다.

Service 수정은 크게 어렵지 않아서 pass

---

다만 ViewModel 의 경우

```swift
init() {
      $searchText
      .debounce(for: .seconds(2.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .map { text in
            self.service.fetchGitUser(user: text)
                  .retry(2)
                  .catch { error -> Just<GithubUser> in
                  print(error)
                  return Just(GithubUser.init(id: 0, login: "", avatarUrl: "", htmlUrl: ""))
                  }
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] value in
            self?.users.append(value)
      })
      .store(in: &cancellables)
}
// ----
init() {
      $searchText
      .debounce(for: .seconds(2.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .map { text in
            self.service.fetchGitUser(user: text)
                  .retry(2)
                  .catch { error -> Just<[GithubUser]> in
                  print(error)
                  return Just([])
                  }
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] value in
            self?.users = value
      })
      .store(in: &cancellables)
}
```

이렇게 2가지 방법이 존재한데, 아래방법이 더 깔끔하다

왜냐면 에러 발생시 `GithubUser`를 굳이 init해서 빈껍데기 모델을 만들필요가 없기 때문.

#### 2. View 수정

지금까지 MockData로 보여지던 View를 api 호출로 가져오는 값을 view에 보여주도록 한다.

근데? ProfileView에 추가로 가져와야할 데이터가있어서 Model에 추가를 한다.
(publicRepos, followers, following, bio 추가)

기존 MockData에서 현재 모델링을 한걸 대입해주는거라 크게 어려운 부분은 없다.

다만 AvatarImage를 사용하는 AvatarView에서 기존에는 그냥 원에 H 하나만 있었는데

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/ea988caa-f3a0-4aa3-9835-04a6a46a2a29" />

```swift
// Before
ZStack {
      Circle().fill(color(for: login))
      Text(String(login.prefix(1)).uppercased())
      // 생략
}
// After
ZStack {
      AsyncImage(url: URL(string: url)) { image in
            image
                  .resizable()
                  .scaledToFill()
      } placeholder: {
            ProgressView()
      }
      .clipShape(Circle())
}
.frame(width: size, height: size)
```

이렇게 `AsyncImage`를 사용해서 바꿔주었다.

그리고 List에 사용하기 위해서 `Identifiable, Hashable` 프로토콜을 적용해주었다.

---

#### 3. 상태 구분하기

1. 성공: 결과 화면
2. 실패: `ContentUnavailableView`
3. 로드중: `ProgressView`

이렇게 구분해야한다

처음에 아무생각없이 SearchView의

```swift
.overlay {
      if viewModel.users.isEmpty && !viewModel.searchText.isEmpty {
            ProgressView()
      } else if viewModel.users.isEmpty  {
            ContentUnavailableView.search(text: viewModel.searchText)
      }
}
```

이부분을 if로 만지작 거리려다가. 결국 안된다는걸 알았다.

---

##### Status 정의

처음엔 `users.isEmpty`랑 `searchText`로 상태를 추론하려 했는데, 로딩인지 결과없음인지 구분이 안 되는 문제가 있었다.

그래서 상태를 enum으로 명확하게 분리했다.

```swift
enum Status: Equatable {
    case idle       // 검색어 없는 초기 상태
    case loading    // 검색 중
    case success([GithubUser])  // 결과 있음
    case failure    // 에러 or 결과 없음
}
```

처음에는 idle없이 loading, success, failure로 했는데 3개로 했을때 초기값을 그냥 아무거나 했는데

그게 앱 시작 화면에 영향이 갈줄은 몰랐다.

처음엔 별 생각 없이 `var status: Status = .loading`으로 했는데,
앱 시작하자마자 ProgressView가 뜨는 문제가 생겼다. 그래서 `.idle`을 새로 추가하고 초기값으로 잡았다.

---

##### loading 상태 처리

파이프라인 중간에 `.loading`을 넣으려 하면 `switchToLatest` 때문에 타입 에러가 발생한다.

처음엔 `.map` 안에서 `self?.status = .loading`을 넣으려 했는데, `.map`은 값을 변환해서 반환해야 하는 오퍼레이터라 상태만 바꾸고 값은 그대로 흘려보내는 동작을 넣기가 어렵다.

그래서 `.handleEvents`를 사용했다.

`.handleEvents`는 파이프라인의 값 흐름에는 영향을 주지 않으면서, 특정 시점에 추가 작업을 끼워 넣을 수 있다. 값은 그대로 다음 오퍼레이터로 통과시키면서 중간에 상태 변경 같은 작업을 할 수 있는 것이다.

`receiveOutput`은 값이 통과할 때 실행되는 클로저다.

```swift
.handleEvents(receiveOutput: { [weak self] _ in
    self?.status = .loading
})
```

이걸 `debounce` 다음에 넣으면, 검색어가 통과되는 순간 `.loading` 상태로 바꾸고 이후 파이프라인은 그대로 흘러간다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/bf3e8d18-5566-4696-814f-198daaa455fc" />

---

##### catch 안에서 상태 변경 시 메인 스레드 경고

처음엔 `catch` 안에서 `self.status = .failure`를 직접 했는데 메인 스레드 경고가 발생했다.

```swift
.map { text in
      self.service.fetchGitUser(user: text)
            .retry(2)
            .catch { error -> Just<[GithubUser]> in
                  self.status = .failure // Main thread warning
                  print(error)
                  return Just([])
            }
}
```

그래서 생각했던게,


```swift
.map { text in
      self.service.fetchGitUser(user: text)
            .retry(2)
            .receive(on: DispatchQueue.main)
            .catch { error -> Just<[GithubUser]> in
                  print(error)
                  self.status = .failure
                  return Just([])
            }
}
```

내부에 `.receive(on: DispatchQueue.main)`를 하나 더 달아주는 것 이었는데, 생각해보니 그렇게되면 receive가 무분별하게 두번 쓰이는 상황이 발생.

그래서 `catch`에서는 기존의 방식대로 빈 배열만 반환하고, `sink`에서 빈 배열 여부로 상태를 판단하는 방식으로 바꿨다.

```swift
.sink(receiveValue: { [weak self] value in
      if value.isEmpty {
            self?.status = .failure
      } else {
            self?.status = .success(value)
      }
      self?.users = value
})
```

##### enum에 맞는 view 조건 세분화

기존 if에서 각 case에 맞게 view를 세분화 해주었다.

```swift
.overlay {
      switch viewModel.status {
      case .idle:
            ContentUnavailableView.search(text: viewModel.searchText)
      case .loading:
            ProgressView()
      case .failure:
            ContentUnavailableView.search(text: viewModel.searchText)
      case .success:
            EmptyView()
      }
}
```

이때 EmptyView()를 사용하는 이유는 아무것도 보이지않게해서 호출의 결과인 list만 보이게 하겠다는 것 

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/fcf3426d-ef8a-4237-a0ca-c76c756733b3" />{: width="50%" height="50%"}

실행하면 이렇게 상태에 따라 다르게 나오는걸 알 수 있다.

#### 2. API 한번에 불러오기

1. 프로필 정보, 레포지토리 목록, 팔로워 목록을 가져오는 **3개의 독립적인 네트워크 요청을 동시에 출발**시킬 것
2. 세 가지 데이터가 모두 안전하게 도착한 시점을 포착하여, 하나의 완전한 '프로필 화면 통합 데이터 모델'로 조립해 낼 것

```
1. 프로필: https://api.github.com/users/{login}
2. 레포: https://api.github.com/users/{login}/repos
3. 팔로워: https://api.github.com/users/{login}/followers
```

##### 모델링

프로필은 되어있으나? Repo, Followers에 대해 모델링을 해야한다.

UI에 대해 언급은 잘 안했지만, 여기의 경우

```swift
Section {
      Picker("", selection: $selectedSegment) {
            Text("Repos").tag(0)
            Text("Followers").tag(1)
            Text("Following").tag(2)
      }
      .pickerStyle(.segmented)
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
}

if selectedSegment == 0 {
      ForEach(MockData.repos) { repo in
            RepoRow(repo: repo)
      }
} else if selectedSegment == 1 {
      ForEach(MockData.followers) { follower in
            UserRow(user: follower)
      }
} else {
      ForEach(MockData.following) { following in
            UserRow(user: following)
      }
}
```

이런식으로 segment를 사용해서 해둔상태

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/ce590d96-0325-4dde-9ac3-8f90b69f72d4" />

---

Repo의 경우 우리는

id, Repo이름, repo설명, 언어, star, fork, html_url 이렇게만 있으면 충분할것같다.

실제로 `https://api.github.com/users/octocat/repos` 을 조회하면 json이 엄청나게 많이 나온다.

```swift
struct GitHubRepo: Codable {
    let id: Int
    let name: String
    let htmlURL: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let forksCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case htmlURL = "html_url"
        case description
        case stargazersCount = "stargazers_count"
        case language
        case forksCount = "forks_count"
    }
}
```

우선은 이렇게 결정했다.

---

Followers, Following은 같은 구조라 별도 모델을 만들려 했는데, 생각해보니 기존 `GithubUser`로 그냥 처리할 수 있다.

왜냐면 

```swift
let login: String
let id: Int
let avatarURL, htmlURL: String
```

이부분이 필요했기 때문

그리고 `Codable`은 JSON에 있는 필드 중 모델에 선언된 것만 디코딩하고 나머지는 무시한다. 그리고 모델에 선언된 필드가 JSON에 없어도 옵셔널(`?`)로 선언되어 있으면 `nil`로 처리하고 넘어간다.

즉 `GithubUser`의 `publicRepos`, `bio` 같은 옵셔널 필드들이 follower/following API 응답에 없어도 에러 없이 디코딩된다. 그래서 굳이 `GithubFollower` 모델을 따로 만들 필요가 없었다.

---

##### 제네릭 + enum 조합으로 NetworkService 리팩토링

원래는 각각을 함수로해서 나누서 만들어도 되긴한데 갑자기 제네릭이 생각나서 구현을 해보려고한다.

우선 NetworkService를 수정해야한다.

일단 위에서 enum을 썼는데 이번에도 그게 좋을듯 해서 enum을 넣는다.

```swift
enum GitHubRequest {
    case profile(String)
    case repo(String)
    case follower(String)
    case following(String)
    
    var url: URL {
        switch self {
        case .profile(let user):
            return URL(string: "https://api.github.com/users/\(user)")!
        case .repo(let user):
            return URL(string: "https://api.github.com/users/\(user)/repos")!
        case .follower(let user):
            return URL(string: "https://api.github.com/users/\(user)/followers")!
        case .following(let user):
            return URL(string: "https://api.github.com/users/\(user)/following")!
        }
    }
}
```

이때 enum에는 computedproperty만 사용 가능한데, 각 case에 따라 url을 다르게 접목하도록 했다.

---

함수의 경우 제네릭을 통해 우리가 만든 모델만 호출쪽에서 입력하면 편하기에 그렇게 했다.

```swift
func fetchGitData<T: Codable>(requestType: GitHubRequest) -> AnyPublisher<T, Error> {
      
      let url = requestType.url
      
      let header = ["Authorization" : "\(Constants.token)"]
      
      var request = URLRequest(url: url)
      request.allHTTPHeaderFields = header
      
      let session = URLSession(configuration: .default)
      
      return session.dataTaskPublisher(for: request)
      .map(\.data)
      .decode(type: T.self, decoder: JSONDecoder())
      .eraseToAnyPublisher()
}
```

일단 테스트를 통해 제대로 호출하는지를 확인해본다.

제네릭을 쓰면서 몇 가지 시행착오가 있었다.

---

**1. 타입 추론 문제**

제네릭 함수를 처음 연결할 때 아무 타입 명시 없이 쓰면 컴파일러가 `T`를 추론하지 못해서 에러가 난다.

```swift
// ❌ T를 추론 못함
.catch { error in
    return Just([])
}

// ✅ 타입 명시
.catch { error -> Just<[GithubUser]> in
    return Just([])
}
```

`.catch`의 반환 타입을 명시해줘야 Swift가 `T`가 뭔지 알 수 있다.

---

**2. `users` 타입 불일치**

repo로 테스트하려고 타입을 `[GithubRepo]`로 바꿨더니 에러가 발생했다.

```swift
@Published var users = [GithubUser]()  // [GithubUser]로 고정

// ❌ [GithubRepo]로 바꾸면
.catch { error -> Just<[GithubRepo]> in
    return Just([])
}
.sink(receiveValue: { [weak self] value in
    if value.isEmpty {
        self?.status = .failure
    } else {
        self?.status = .success(value)  // success([GithubUser])인데 [GithubRepo]가 들어오니 에러
    }
    self?.users = value  // Cannot convert value of type '[GithubRepo]' to expected argument type '[GithubUser]'
})
```

`users`가 `[GithubUser]`로 고정되어 있고, `Status`의 `success([GithubUser])`도 마찬가지라 두 군데에서 동시에 충돌이 난다.

그래서 

```swift
case success([GithubRepo])
@Published var repos = [GithubRepo]()
self?.repos = value
```

이렇게 코드를 수정하고 repos 변수는 추가해서 테스트를 했다.

지금은 `[GithubUser]`를 반환하는 `following`으로 테스트해서 확인했다. `Status` enum은 `ProfileViewModel`을 만들 때 따로 고민해야 할 부분이다.

무튼 Generic으로 바꾼 코드는 제대로 작동이 잘되는걸 확인했다.

---

##### ProfileViewModel에 적용

처음엔 `SearchViewModel`에서 검색할 때 프로필 정보도 같이 불러올까 생각했는데, 검색 결과만 보고 탭을 하지 않으면 굳이 API를 호출할 필요가 없다고 생각했다.

그래서 `ProfileViewModel`을 별도로 만들고, 거기서 repos, followers, followings 3개를 동시에 호출하는 구조로 결정했다.

`CombineLatest3`을 쓰는 건 당연한데, 가장 큰 문제는 제네릭이라서 어떻게 타입을 추론하느냐였다. `SearchViewModel`에서 `.catch` 쪽에 반환 타입을 명시해서 `T`를 추론한 방식을 그대로 적용했다.

```swift
private let service = GitHubNetworkService()
private var cancellables: Set<AnyCancellable> = []

@Published var repos = [GithubRepo]()
@Published var followers = [GithubUser]()
@Published var followings = [GithubUser]()

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
        self?.repos = repos
        self?.followers = followers
        self?.followings = followings
    }.store(in: &cancellables)
}
```

에러 없이 동작하는 것을 확인했다.

---

##### ProfileView에 적용

```swift
@StateObject var viewModel = ProfileViewModel(requestUser: user)
```

이렇게 쓰면 바로 에러가 뜬다.

```
Cannot use instance member 'user' within property initializer; property initializers run before 'self' is available
```

Swift에서 프로퍼티는 `self`가 완전히 만들어지기 전에 초기화되기 때문에, 이 시점엔 같은 타입의 다른 프로퍼티인 `user`에 접근할 수 없다.

---

초기화를 늦추면 되겠다 싶어서 `lazy`를 붙여봤는데,

```swift
@StateObject lazy var viewModel = ProfileViewModel(requestUser: user)
```

```
Property 'viewModel' with a wrapper cannot also be lazy
```

Property Wrapper와 함께 쓰는 변수에는 `lazy`를 붙일 수 없다고 한다.

---

[참고글1](https://sarunw.com/posts/how-to-initialize-stateobject-with-parameters-in-swiftui/){:target="_blank"}, [참고글2](https://www.swiftwithvincent.com/blog/bad-practice-creating-a-stateobject-wrapper){:target="_blank"}, [StateObject Docs](https://developer.apple.com/documentation/swiftui/stateobject){:target="_blank"}를 참고해서 `init`에서 직접 초기화하는 방법을 찾았다.

물론 [이전글](https://haroldfromk.github.io/posts/ObjectTest/){:target="_blank"}에서도 한번 언급한 적이 있긴하다..

`_viewModel`에서 `_`는 Property Wrapper에 직접 접근하는 방식이다.

`@StateObject var viewModel: ProfileViewModel`을 양파라고 하면, 양파 껍질이 `@StateObject`, 속 알맹이가 `ProfileViewModel`이다.

평소에 `viewModel`로 접근하는 건 속 알맹이(실제 값)에 접근하는 것이고, `_viewModel`로 접근하는 건 양파 껍질(`@StateObject` 인스턴스 자체)에 접근하는 것이다.

`init`에서 초기화할 때는 껍질째로 직접 교체해야 하기 때문에 `_`가 필요하다.

```swift
@StateObject var viewModel: ProfileViewModel

init(user: GithubUser) {
    _viewModel = StateObject(wrappedValue: ProfileViewModel(requestUser: user))
}
```

그랬더니

```
Return from initializer without initializing all stored properties
self.user not initialized
```

`ProfileView`가 `let user: GithubUser`를 프로퍼티로 갖고 있는데, `init`을 직접 정의하면 Swift가 모든 저장 프로퍼티를 초기화하도록 요구한다. `user`도 `init`에서 초기화해줘야 에러가 사라진다.

```swift
init(user: GithubUser) {
    self.user = user
    _viewModel = StateObject(wrappedValue: ProfileViewModel(requestUser: user))
}
```

이렇게 최종적으로 마무리했다.

실행하니 모든 결과값을 가져오는걸 확인했다.

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/0bffe480-d3e1-4a95-96c2-eb7bc7dfa739" />{: width="50%" height="50%"}

##### 통합 모델로 만들기

지금은 세 가지 데이터가 도착하면 각각 repos, followers, followings 변수에 따로 담는 구조이다.

```swift
// profileVM
.sink { [weak self] repos, followers, followings in
            self?.repos = repos
            self?.followers = followers
            self?.followings = followings
        }
```

그래서 

```swift
struct TotalProfile {
    let repos: [GithubRepo]
    let followers: [GithubUser]
    let followings: [GithubUser]
}
```

새롭게 하나를 만들어 주었다.

그리고 profileVM으로 가서

```swift
@Published var totalProfile = TotalProfile(
      repos: [],
      followers: [],
      followings: []
)

.sink { [weak self] repos, followers, followings in
self?.totalProfile = TotalProfile(repos: repos,
                                    followers: followers,
                                    followings: followings)
}
```

이렇게 적용해주었다.

profileview에서 viewModel.repos 이런식으로 되던 부분을 viewModel.totalProfile.repos 이런식으로 고치면 끝

---

### 3. 에러 한 곳에서 처리하기

`CombineLatest3`으로 세 API를 동시에 호출하면서 각각 `catch`로 에러를 처리했다. 에러가 발생하면 빈 배열로 대체해서 앱이 죽지 않도록 했다.

별도로 에러 스트림을 합치는 작업은 하지 않았다. 어차피 에러가 나도 빈 배열로 대체되니 사용자 입장에선 그냥 데이터가 없는 것처럼 보이고, 앱은 계속 동작한다.

일단은 코드+글 작성때문에 진도가 느려저서 이건 Day 5에서 해보는걸로 하고 다음 미션으로 넘어가도록 한다.