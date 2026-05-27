---
title: GitExplorer (1)
writer: Harold
date: 2026-05-21 08:06
categories: [Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

## Project 시작

Combine을 오랜만에 사용할 겸 간단한 프로젝트를 만든다.

검색을 통해 GitHub 사용자를 찾아서, 해당 유저의 Repository도 보고 Following 기능까지 하는 간단한 앱이지만, Combine을 사용하면서 여러 Data Streaming이 필요한 작업이라 쉬우면서도 쉽지 않을? 그런 프로젝트이다.

4일 계획으로 끝낼 미니 프로젝트지만 Combine의 실전 데이터 흐름 개념은 확실하게 잡을 듯하다.

**UI는 생략**

아마 여기선 생각의 흐름대로 쓰면서 내용을 정리하지 않을까 싶다.
내용이 상당히 길 예정

## Day 1 — 검색 파이프라인 만들기
### 미션 (Task)

1. **입력창 바인딩**
   - 사용자가 검색창에 타이핑하는 글자의 변화를 실시간 데이터 스트림으로 수신할 것

2. **노이즈 및 중복 필터링**
   - 불필요한 네트워크 요청 방지를 위해 **입력이 완전히 멈추고 0.5초가 지났을 때만** 최종 검색어를 통과시킬 것
   - 글자를 지웠다 다시 쳐서 **이전과 완벽히 같은 검색어라면 무시**하여 중복 요청을 차단할 것
   - 서버 부하 방지 및 유의미한 결과 도출을 위해 최소 **2글자 이상**일 때만 다음 단계로 진입시킬 것

3. **이전 요청 취소하기**
   - 새로운 검색어가 통과되면, **이전에 처리 중이던 네트워크 요청은 강제로 즉시 취소**할 것
   - 과거의 검색 결과가 뒤늦게 도착해 화면을 덮어씌우는 현상을 막고, 최신 검색어에 대한 요청으로 스트림을 교체할 것

4. **에러 대처하기**
   - 통신 중 에러 발생 시 **최대 2번까지 자동으로 재요청**을 보낼 것
   - 최종 실패하더라도 에러가 파이프라인 외부로 퍼져 검색창 스트림이 파괴되지 않도록, **안전한 빈 결과(Fallback 데이터)로 대체**하여 전체 파이프라인을 계속 살려둘 것

---

### 1. 입력창 바인딩.

> 사용자가 검색창에 타이핑하는 글자를 실시간 데이터 스트림으로 수신할 것

일단 여기서 키워드는 실시간 데이터 스트림이다.

즉 subject publisher를 사용하여 처리하는게 좋아보인다.

#### ViewModel 만들기

일단 내 생각은 이렇다.

1. 구독 관계 형성 (PassThroughSubject)
2. view에서 searchable(SearchBar)에 값을 입력
3. 값의 변화를 console에 출력

---

##### 기본 개념 복기

일단은 아주 담백하게

```swift
final class SearchViewModel: ObservableObject {
    
    @Published var searchText: String = ""
    
    var textSubject = PassthroughSubject<String, Never>()
    var cancellables: Set<AnyCancellable> = []
    
    func observe() {
        textSubject
            .sink { [weak self] _ in
            print(self?.searchText ?? "")
        }.store(in: &cancellables)
    }
}
.searchable(text: $viewModel.searchText, prompt: "Search GitHub users")
.onSubmit(of: .search, {
      viewModel.textSubject.send(viewModel.searchText)
})
.onAppear {
      viewModel.observe()
}
```

이런식으로 했다.

send로 전해지니 제대로 print가 된다.

하지만 이건 내가 원하는게 아니다. 왜냐면 버튼을 눌러서 일일이 send를 통해 전달했기 때문.

물론

```swift
.onChange(of: viewModel.searchText, { _, _ in
      viewModel.textSubject.send(viewModel.searchText)
})
```

이런식으로 하면 변화에따라 send를 보내긴 하나. subject Publisher를 쓴 의미는 없다.

---

##### 생각 과정

일단 포커스는 이거다. 

`PassthroughSubject`를 사용해서 실시간으로 전달.

```swift
@Published var searchText: String = ""
var textSubject = PassthroughSubject<String, Never>()
```

그렇다면 이둘을 어떻게 연결해서 스트리밍을 할것인가?

근데 도저히 `PassthroughSubject`로는 생각이 떠오르지 않아 결국 방법을 바꾼다.

---

###### `@Published` Wrapper의 특징을 살리자.

그냥 내가 예전에 쓴글을 읽어보다가 `$`를 보았다.

한동안 SwiftUI한다고 바인딩할때만 썼는데 생각해보니 `published도 바인딩이네?`이게 스쳐지나갔다.

```swift
@Published var searchText: String = ""

var cancellables: Set<AnyCancellable> = []

init() {
   $searchText
      .sink { value in
            print(value)
      }.store(in: &cancellables)
}
```

이렇게 바꿔주었다.

역시 출력이 잘된다. 라고하기엔 같은게 2번씩 출력이 되고 있다.

이부분을 체크해야할 필요가 있다.

---

2번씩 출력이 된다? 즉 중복이 있다는것이다.

근거를 몰라서 AI게 물어보니 
[GitHub Discussion](https://github.com/pointfreeco/swift-composable-architecture/discussions/1093){:target="_blank"}을 알려준다.

무튼 이런문제가 있다고하니. 중복을 해결하기 위해 `.removeDuplicates()`를 사용해준다.

### 2. 노이즈 및 중복 필터링

1. 불필요한 네트워크 요청 방지를 위해 **입력이 완전히 멈추고 0.5초가 지났을 때만** 최종 검색어를 통과시킬 것
2. 글자를 지웠다 다시 쳐서 **이전과 완벽히 같은 검색어라면 무시**하여 중복 요청을 차단할 것
3. 서버 부하 방지 및 유의미한 결과 도출을 위해 최소 **2글자 이상**일 때만 다음 단계로 진입시킬 것

---

우선 3개의 조건을 다 충족시켜야 한다.

#### 1. 입력 지연 주기

이건 `debounce`를 쓰라는 것.

```swift
init() {
      $searchText
         .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
         .sink { value in
               print(value)
         }.store(in: &cancellables)
   }
```

`receive`를 지운건 어차피 scheduler에 main이 있기에 중복이라 삭제해주었다.

근데 신기한건 debounce를 쓰자마자 위의 2번 출력 버그는 사라진다.
그래서 .removeDuplicates()를 지워주었다.

#### 2. 불필요한 동일 데이터 재요청 방지하기

아무래도 `.removeDuplicates()`를 사용하라는 것 같다.

```swift
init() {
   $searchText
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .sink { value in
            print(value)
      }.store(in: &cancellables)
}
```

이때 `.removeDuplicates()`의 위치가 중요한데


```swift
init() {
   $searchText
      .removeDuplicates()
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
      .sink { value in
            print(value)
      }.store(in: &cancellables)
}
```
바로 위에 걸어버리면

removeDuplicates를 쓴 의미가 없어지므로 위치를 잘 걸도록하자

즉 debounce가 실행되고 이게 중복값이구나를 인지하는 순서이기 때문.

#### 3. 최소 글자 수 필터링하기 (최종코드)

이건 filter를 사용해주면 된다.

```swift
init() {
   $searchText
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .filter({ value in
            value.count > 1
      })
      .sink { value in
            print(value)
      }.store(in: &cancellables)
}
```

이때 value in으로 하거나 $0 을 쓰는건 본인 취향

```swift
init() {
   $searchText
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .filter({ $0.count > 1 })
      .sink { print($0) }
      .store(in: &cancellables)
}
```

---

### 3. 이전 요청 취소하기

1. 새로운 검색어가 통과되면, **이전에 처리 중이던 네트워크 요청은 강제로 즉시 취소**할 것
2. 과거의 검색 결과가 뒤늦게 도착해 화면을 덮어씌우는 현상을 막고, 최신 검색어에 대한 요청으로 스트림을 교체할 것

---

여기서부턴 실제로 GitHubApi를 통해 Network 통신을 해야할것같아서

GitHubNetworkService라는걸 만들도록 한다.

#### 1. Modeling

우선 API 통신을 하기위해서 모델링을 한다
[GitHub Docs](https://docs.github.com/en/rest/search/search?apiVersion=2026-03-10#search-users){:target="_blank"}에 보면 

```json
{
  "total_count": 12,
  "incomplete_results": false,
  "items": [
    {
      "login": "mojombo",
      "id": 1,
      // 생략
    }
  ]
}
```

이런식으로 나오는걸 알 수 있다.

```swift
struct GithubResult: Codable {
    let items: [GithubUser]
}

struct GithubUser: Codable {
        let id: Int
        let login: String
        let avatarUrl: String
        let htmlUrl: String
        var name: String?
        var bio: String?
        var followers: Int?
        var following: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case name
        case htmlUrl = "html_url"
        case publicRepos = "public_repos"
        case followers, following
        case bio
    }
}
```

그래서 이렇게 모델링을 해주었다.
지금 당장 필요한것만 살려두었다.

#### 2. GitHubNetworkService

이제 본격적으로 GitHub API를 사용하여 통신을 해보도록 한다.

오래간만에 하는거라 아무래도 내가 쓴글을 참고해서 해봐야할듯,

이전에 UIKit을 통해 만들었을땐 Alamofire로 아주 간단하게 했었다.
하지만 이번엔 그런 외부 라이브러리를 쓰지않기에
우선 기본 flow를 기억해보면

url설정(header 기본 세팅 포함) ➡ request에 header 적용 ➡ URLSession을 통해 요청 

이런 느낌이었던것같다.

[Auth Docs](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2026-03-10){:target="_blank"}를 참고해서 어떤게 필요한지 보니

```
curl --request GET \
--url "https://api.github.com/octocat" \
--header "Authorization: Bearer YOUR-TOKEN" \
--header "X-GitHub-Api-Version: 2026-03-10"
```

이렇게 header를 통해서 적용하는걸 알 수가 있다.

Postman 어플로 테스트를 해서 확인을 해보니

;<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/5405ccd3-926b-402c-9afd-ec26a808a47a" />

첫번째를 보면 결과가 출력이 되는걸로봐서 토큰도 적요이 잘 되는것을 알 수 있다.

**주의**: 프로젝트를 깃에 공유할때는 반드시 토큰은 지워주자

기억을 더듬고 이전글을 읽어보면서 이전글에 온전히 의존하지 않고 잠깐 흐름만 보고 코드를 작성하는데,

```swift
func fetchGitUser(user: String) -> AnyPublisher<[GithubUser], Error> {
      Future<[GithubUser], Error> { promise in
      var url = URL(string: "https://api.github.com/search/users?q=\(user)")
      let header = ["Authorization" : "\(Constants.token)"]
      
      var request = URLRequest(url: url!)
      request.allHTTPHeaderFields = header
      
      let session = URLSession(configuration: .default)
      
      return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GithubResult.self, decoder: JSONDecoder())
            .map { $0.items }
      
      
      }
      .eraseToAnyPublisher()
}
```

일단 여기까지 작성을 했다.

```text
Cannot convert value of type 'Publishers.Map<Publishers.Decode<Publishers.MapKeyPath<URLSession.DataTaskPublisher, Data>, GithubResult, JSONDecoder>, [GithubUser]>' to closure result type 'Void'
```

이런 에러가 발생

---

일단 [이전글](https://haroldfromk.github.io/posts/10%EC%A3%BC%EC%B0%A8-%EA%B3%BC%EC%A0%9C-(10)/){:target="_blank"}을 좀 보고 참고해서 작성했다. 

```swift
private var cancellables = Set<AnyCancellable>()
    
func fetchGitUser(user: String) -> AnyPublisher<[GithubUser], Error> {
      return Future<[GithubUser], Error> { promise in
      let url = URL(string: "https://api.github.com/search/users?q=\(user)")
      let header = ["Authorization" : "\(Constants.token)"]
      
      var request = URLRequest(url: url!)
      request.allHTTPHeaderFields = header
      
      let session = URLSession(configuration: .default)
      
      session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GithubResult.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
            .map { result in
                  return result.items
            }
            .replaceError(with: [])
            .sink { user in
                  promise(.success(user))
            }
            .store(in: &self.cancellables)

      }
      .eraseToAnyPublisher()
}
```

이렇게 했지만 사실 이건 내가 궁극적으로 원하는 코드가 아니다

왜냐면 `cancellables`를 만들었기 때문.

---

#### 3. ViewModel

```swift
@Published var users: [GithubUser] = []

func getUsers(text: String) {
      service.fetchGitUser(user: text)
      .receive(on: DispatchQueue.main)
      .sink { completion in
            if case .failure(let error) = completion {
                  print("Error fetching users: \(error)")
            }
      } receiveValue: { user in
            self.users = user
            print(user)
      }
      .store(in: &cancellables)
}
```

이렇게 새로 작성을 해주었다.

#### 4. View
```swift
.onSubmit(of: .search, {
      viewModel.getUsers(text: viewModel.searchText)
})
```

Haroldfrom으로 검색을하니 

결과값이 출력되는걸 확인

#### 5. 해결해보기

Future 삽질기 — 왜 안됐는가?

처음 시도한 코드는 이렇다.

```swift
func fetchGitUser(user: String) -> AnyPublisher<[GithubUser], Error> {
    Future<[GithubUser], Error> { promise in
        var url = URL(string: "https://api.github.com/search/users?q=\(user)")
        let header = ["Authorization" : "\(Constants.token)"]
        var request = URLRequest(url: url!)
        request.allHTTPHeaderFields = header
        let session = URLSession(configuration: .default)
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GithubResult.self, decoder: JSONDecoder())
            .map { $0.items }
    }
    .eraseToAnyPublisher()
}
```

---

##### 오류

```
Cannot convert value of type 'Publishers.Map<...>' to closure result type 'Void'
```

---

##### 왜 에러가 났는가?

`Future`의 클로저 반환 타입은 `Void`다.

즉 클로저 안에서 `return`으로 값을 내보내는 구조가 아니라, 비동기 작업이 끝난 시점에 `promise(.success(...))` 또는 `promise(.failure(...))`를 호출해서 값을 전달하는 구조다.

그런데 위 코드는 `promise`를 한 번도 호출하지 않고 `return`으로 Publisher를 반환하려 했다. `Future` 입장에서는 `Void`를 반환해야 하는 클로저에서 Publisher 타입이 들어오니 타입 불일치 에러가 발생한 것.

---

##### 근본적인 문제

`Future`는 **기존 콜백 기반 코드를 Publisher로 감쌀 때** 쓰는 도구다.

강의에서 `Future`를 쓴 이유는 로컬 파일 읽기라는 **동기 작업**을 `promise`로 감싼 것이었다.

```swift
// 강의 코드 — 동기 작업을 Future로 감싼 올바른 사용
Future<Data, Error> { promise in
    do {
        let data = try Data(contentsOf: url)
        promise(.success(data))  // promise 호출
    } catch {
        promise(.failure(error))
    }
}
```

반면 `dataTaskPublisher`는 **이미 Publisher**다. 이걸 또 `Future`로 감쌀 이유가 없다.

---

##### 해결책

`Future` 없이 `dataTaskPublisher`를 바로 파이프라인으로 연결하면 된다.

사실 예전에 카카오 API 연동할 때 이미 이 방식을 썼었다.

```swift
func fetchGitUser(user: String) -> AnyPublisher<[GithubUser], Error> {
    let url = URL(string: "https://api.github.com/search/users?q=\(user)")!
    var request = URLRequest(url: url)
    request.allHTTPHeaderFields = ["Authorization": Constants.token]
    
    return URLSession.shared.dataTaskPublisher(for: request)
        .map(\.data)
        .decode(type: GithubResult.self, decoder: JSONDecoder())
        .map { $0.items }
        .eraseToAnyPublisher()
}
```

---

##### 정리

| | 잘못된 방식 | 올바른 방식 |
|---|---|---|
| 구조 | `Future` 안에 `dataTaskPublisher` 혼용 | `dataTaskPublisher` 바로 파이프라인 연결 |
| 문제 | `promise` 미호출 → Void 타입 불일치 에러 | - |
| `Future` 용도 | 콜백 기반 코드를 Publisher로 감쌀 때 | 이미 Publisher인 경우엔 불필요 |

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/4b6a5b60-27ac-42b2-9776-d41bf6dc8b59" />

---

#### 6. 요청 강제 취소하기

이제 진짜 본격적으로 요청을 강제 취소해보도록 한다.

```swift
func getUsers(text: String) {
      service.fetchGitUser(user: text)
      .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
      .receive(on: DispatchQueue.main)
      .print()
      .sink { completion in
            if case .failure(let error) = completion {
                  print("Error fetching Users: \(error)")
            }
      } receiveValue: { [weak self] user in
            self?.users = user
            print("-----")
            print(user)
      }
      .store(in: &cancellables)
}
```

우선 여기에 시간차를 줘봤는데? 값을 가져오지못한다.

곰곰히 생각을해보니? 일단 호출을 하는데 debounce가 걸리면서 sink에 결과값이 도달하지 않는게 아닌가? 라는 생각이 든다.

즉 debounce 뒤에 `service.fetchGitUser(user: text)` 이걸 호출을 해야한다는 생각이 들었다.

##### 1. map

```swift
func getUsers() {
      $searchText
      .debounce(for: .seconds(2), scheduler: RunLoop.main)
      .map({ value in
            self.service.fetchGitUser(user: value)
      })
      .sink(receiveValue: { value in
            print(value)
      })
      .store(in: &cancellables)
}
```

우선 이렇게 하고 print하니 `AnyPublisher`가 나왔다.

이건 우리가 service에서 리턴할때 `A`nyPublisher<[GithubUser], Error>`했던 이걸 그대로 받은 듯 하다.

즉 여기서 한번 더 작업을 해야하는 아주 불필요한 일이 생긴다.

```swift
func getUsers() {
        $searchText
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .map({ value in
                self.service.fetchGitUser(user: value)
            })
            .sink(receiveValue: { value in
                value
                    .receive(on: DispatchQueue.main)
                    .sink { completion in
                    if case .failure(let error) = completion {
                        print("Error fetching Users: \(error)")
                    }
                    
                } receiveValue: { user in
                    self.users = user
                    print("-----")
                    print(user)
                }
                .store(in: &self.cancellables)
                
            })
            .store(in: &cancellables)
        
    }
```

sink를 두번치는 아주 번거로움의 끝 작업을 하고있다.

즉 이건 방법이 아니다.

---

##### 2. flatMap

flatMap은 [FlatMap Docs](https://developer.apple.com/documentation/swift/set/flatmap(_:)-i3my){:target="_blank"}에 의하면

상위 퍼블리셔의 요소를 받아 새로운 퍼블리셔로 변환한다고 한다.

즉 우리가 service에서 요청한 값을 가져올때 Return type이 `AnyPublisher`가 아닌 새로운 Publisher가 된다는것.

일단 코드를 작성하면

```swift
func getUsers() {
      $searchText
      .debounce(for: .seconds(1), scheduler: RunLoop.main)
      .removeDuplicates()
      .flatMap { text in
            self.service.fetchGitUser(user: text)
                  .replaceError(with: [])
      }
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] value in
            self?.users = value
            print(value)
      })
      .store(in: &cancellables)
}
```
이때는 error대해서 sink로 작업하기 싫어서 `.replaceError(with: [])` 이걸로 대체했다.

우선 내부 클로저의 value를 옵션을 누른채로 클릭해보면

```swift
value: Publishers.FlatMap<Publishers.ReplaceError<AnyPublisher<[GithubUser], any Error>>, Publishers.RemoveDuplicates<Publishers.Debounce<Published<String>.Publisher, RunLoop>>>.Output
```

뭔가 많이 달라졌다. 길어보이지만 사실은

```swift
Publishers.ReplaceError<
    Publishers.FlatMap<
        AnyPublisher<[GithubUser], Error>,
        ...
    >
>.Output
```

이건 Combine Operator들이 체이닝되면서 만들어진 내부 타입이다.

즉 `flatMap`, `replaceError`, `debounce` 같은 Operator들이 하나씩 감싸진 결과라고 보면 된다.

하지만 실제로 중요한 건 최종 Output 타입이다.

현재 `fetchGitUser()`는

```swift
AnyPublisher<[GithubUser], Error>
```

를 반환하고 있고,

```swift
.replaceError(with: [])
```

를 통해 Error를 제거했기 때문에 최종적으로 sink에서 받는 value 타입은 `[GithubUser]`가 된다.

즉 지금 보이는 긴 타입은 내부 파이프라인 구조일 뿐이고, 실제로 우리가 사용하는 최종 결과 타입만 보면 된다.

그래서 Combine에서는 이런 복잡한 내부 타입 노출을 숨기기 위해 `eraseToAnyPublisher()`를 자주 사용한다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/bd5a97fe-7b44-41c7-8f74-224e0444eac4" />

이제 그러면 요청을 강제취소하는 부분만 추가하면 될것같다.

`switchToLatest`를 사용하면 될 것 같다.

[switchToLatest Docs](https://developer.apple.com/documentation/combine/publisher/switchtolatest()-453ht){:target="_blank"}

```swift
func getUsers() {
      $searchText
      .debounce(for: .seconds(2), scheduler: RunLoop.main)
      .removeDuplicates()
      .map { text in
            self.service.fetchGitUser(user: text)
                  .replaceError(with: [])
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] value in
            self?.users = value
            print(value)
      })
      .store(in: &cancellables)
}
```

다만 flatMap을 사용하게되면 

```text
No exact matches in call to instance method 'flatMap'

Candidate requires that '()' conform to 'Publisher' (requirement specified as 'P' : 'Publisher') (Combine.Publisher.flatMap)
```

이런 에러가 발생

그래서 map으로 바꿔주었다. 하지만 

빠르게 2번 호출을 하니, 최신값으로 되긴하는데, 최신값으로 2번 호출 되었다.
알고보니 버튼때문이었고, 여기선 init()안에 넣어줘서 강제 취소를 하라는듯

---

### 4.에러 대처하기

1. 통신 중 에러 발생 시 **최대 2번까지 자동으로 재요청**을 보낼 것
2. 최종 실패하더라도 에러가 파이프라인 외부로 퍼져 검색창 스트림이 파괴되지 않도록, **안전한 빈 결과(Fallback 데이터)로 대체**하여 전체 파이프라인을 계속 살려둘 것

#### 재시도 후 Fallback 처리하기

이건 재시도가 retry밖에 없었고 fallback처리는 이미 해뒀기 때문에 사실상 retry 추가 밖에 없긴 하다.

```swift
$searchText
      .debounce(for: .seconds(2.5), scheduler: RunLoop.main)
      .removeDuplicates()
      .map { text in
            self.service.fetchGitUser(user: text)
                  .print()
                  .retry(2)
                  .replaceError(with: [])
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] value in
            self?.users = value
            print(value)
      })
      .store(in: &cancellables)
```

이렇게 코드를 구성했다.

일단은 url을 바꿔서 retry와 error 잘 출력 되는지 확인하도록 한다

error가 발생하면 빈배열을 리턴 하므로 []이게 나오는지 확인을 해본다.

```text
receive error: (keyNotFound(CodingKeys(stringValue: "items", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"items\", intValue: nil) (\"items\").", underlyingError: nil)))
receive subscription: (Decode)
request unlimited
receive error: (keyNotFound(CodingKeys(stringValue: "items", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"items\", intValue: nil) (\"items\").", underlyingError: nil)))
receive subscription: (Decode)
request unlimited
receive error: (keyNotFound(CodingKeys(stringValue: "items", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"items\", intValue: nil) (\"items\").", underlyingError: nil)))
[]
```

이렇게 나오는걸 알 수 있다.

---

굳이 Error 메세지를 리턴하겠다고 하면

```swift
.map { text in
      self.service.fetchGitUser(user: text)
            .print()
            .retry(2)
            .catch { error -> Just<[GithubUser]> in
                  print(error)
                  return Just([])
            }
      }
```
이렇게 해준다.

여기서 순간 `error -> Just<[GithubUser]>`를 "에러를 저 타입으로 반환한다"고 잘못 생각했는데,
`error`는 클로저가 받는 입력 파라미터고, `Just<[GithubUser]>`는 클로저가 반환할 대체 Publisher의 타입이다.
즉 에러를 받아서 빈 배열을 담은 Publisher로 교체하는 구조.

에러는 콘솔에 출력되지만, 

```
keyNotFound(CodingKeys(stringValue: "items", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"items\", intValue: nil) (\"items\").", underlyingError: nil))
```

결과값은 빈 배열로 대체되기 때문에 View에서는 아무것도 표시되지 않는다.

---

Day 1 끝

상당히 글이 길어졌지만 만족한다.