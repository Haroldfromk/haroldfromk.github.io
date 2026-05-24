---
title: GitExplorer (1)
writer: Harold
date: 2026-05-21 08:06
categories: [Combine]
tags: []

toc: true
toc_sticky: true
published: false
---

## Project 시작

Combine을 오랜만에 사용할 겸 간단한 프로젝트를 만든다.

검색을 통해 GitHub 사용자를 찾아서, 해당 유저의 Repository도 보고 Following 기능까지 하는 간단한 앱이지만, Combine을 사용하면서 여러 Data Streaming이 필요한 작업이라 쉬우면서도 쉽지 않을? 그런 프로젝트이다.

4일 계획으로 끝낼 미니 프로젝트지만 Combine의 실전 데이터 흐름 개념은 확실하게 잡을 듯하다.

**UI는 생략**

아마 여기선 생각의 흐름대로 쓰면서 내용을 정리하지 않을까 싶다.

## Day 1 — 검색 시스템의 노이즈 캔슬링
### 미션 (Task)

1. **입력창 바인딩**
   - 사용자가 검색창에 타이핑하는 글자의 변화를 실시간 데이터 스트림으로 수신할 것

2. **노이즈 및 중복 필터링**
   - 불필요한 네트워크 요청 방지를 위해 **입력이 완전히 멈추고 0.5초가 지났을 때만** 최종 검색어를 통과시킬 것
   - 글자를 지웠다 다시 쳐서 **이전과 완벽히 같은 검색어라면 무시**하여 중복 요청을 차단할 것
   - 서버 부하 방지 및 유의미한 결과 도출을 위해 최소 **2글자 이상**일 때만 다음 단계로 진입시킬 것

3. **비동기 레이스 컨디션 방지 (스트림 스위칭)**
   - 새로운 검색어가 통과되면, **이전에 처리 중이던 네트워크 요청은 강제로 즉시 취소**할 것
   - 과거의 검색 결과가 뒤늦게 도착해 화면을 덮어씌우는 현상을 막고, 최신 검색어에 대한 요청으로 스트림을 교체할 것

4. **네트워크 에러 방어벽 구축 (스트림 생존 보장)**
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

### 3. 비동기 레이스 컨디션 방지

1. 새로운 검색어가 통과되면, **이전에 처리 중이던 네트워크 요청은 강제로 즉시 취소**할 것
2. 과거의 검색 결과가 뒤늦게 도착해 화면을 덮어씌우는 현상을 막고, 최신 검색어에 대한 요청으로 스트림을 교체할 것

---

#### 1. 진행 중인 이전 요청 강제 취소하기

여기서부턴 실제로 GitHubApi를 통해 Network 통신을 해야할것같아서

GitHubNetworkService라는걸 만들도록 한다.

##### 1. Modeling

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
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}
```

그래서 이렇게 모델링을 해주었다.
지금 당장 필요한것만 살려두었다.

##### 2. GitHubNetworkService

이제 본격적으로 GitHub API를 사용하여 통신을 해보도록 한다.


---

#### 2. 최신 검색 스트림으로 교체하기