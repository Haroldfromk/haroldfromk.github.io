---
title: GitExplorer (draft)
writer: Harold
date: 2026-05-14 08:06
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

### 🎯 미션 (Task)

1. **입력창 바인딩**
   - 사용자가 검색창에 타이핑하는 글자를 실시간 데이터 스트림으로 수신할 것

2. **노이즈 및 중복 필터링**
   - 불필요한 네트워크 요청 방지를 위해 **입력이 완전히 멈추고 0.5초가 지났을 때만** 이벤트를 통과시킬 것
   - 글자를 지웠다 다시 쳐서 **이전과 완벽히 같은 검색어라면 무시**할 것
   - 최소 **2글자 이상**일 때만 다음 단계로 진입시킬 것
   *(FlightLog에서 GPS 센서의 순간적인 노이즈를 걸러내는 패턴)*

3. **스트림 스위칭 및 이전 요청 취소**
   - 새로운 검색어가 통과되면, **이전에 처리 중이던 네트워크 요청은 즉시 취소**하고 이번에 들어온 새 검색어로 API 요청을 교체할 것

4. **네트워크 에러 방어벽 구축**
   - 통신 중 에러 발생 시 **최대 2번까지 자동으로 재시도**를 보낼 것
   - 최종 실패하더라도 검색창 스트림 자체가 파괴되어 앱이 먹통이 되지 않도록, **안전한 빈 결과(Fallback 데이터)로 대체**하여 전체 파이프라인을 계속 살려둘 것
   *(FlightLog에서 달리는 도중 GPS 신호가 끊겨도 전체 러닝 세션 스트림은 살아있어야 하는 구조와 동일)*

### 1. 입력 바인딩하기

#### 시도

Combine을 사용하지 않을때에는 입력받을 값을 바인딩하여 사용자가 입력을 다하고, 검색버튼이나 엔터를 눌렀을때 TextField에 입력한값이 우리가 만든 변수에 담겨서 작업을 처리하지만,
Combine은 실시간으로 입력한값이 넘어가게 된다.

검색은 SearchView에서 담당을 하므로 여기에 함수와 변수를 먼저 다 만들어두고, 기능이 제대로 작동하는걸 확인한 뒤에, ViewModel로 옮겨서 관리를 할 생각이다.

일단은 Data Streaming을 Console에 Print를 할생각.
그전에 기억을 되짚어서 flow를 생각해보면

1. 우선 구독관계를 형성
2. 값이 변할때마다 subscriber를 통해 값을 print.

그때는 UIKit으로 해서 SearchBar를 만들면서 거기에 observe를 심어서 Text의 변화를 관측했던 기억이 있는데,
지금은 SwiftUI라서 조금 다를것같다. (검색하지않고 스스로 해볼거라 시간이 좀 걸릴지도)

---

```swift
extension UITextField {
    var textPublisher: AnyPublisher<String, Never> {
        NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: self)
            .map { ($0.object as? UITextField)?.text  ?? "" }
            .eraseToAnyPublisher()
    }
}

private func observe() {
        searchBar.searchTextField.textPublisher.sink { value in
            print(value)
        }.store(in: &cancellables)
    }
```

이게 기존에 UIKit을 했던 방식.

[이전글](https://haroldfromk.github.io/posts/10%EC%A3%BC%EC%B0%A8-%EA%B3%BC%EC%A0%9C-(2)/){:target="_blank"} 참고

---

지금은 아예 `.searchable`이라는 Modifier가 있어서 편하긴 하다.
편하긴한데, 이전에 써보긴 했어서 크게 어렵진 않다.

```swift
@State private var query = ""

.searchable(text: $query, prompt: "Search GitHub users")
.onSubmit(of: .search, {
      print(query)
})
```

보통은 이렇게 해서 `onSubmit`에서 viewModel을 사용해서 검색기능을 구현하곤 한다.

이 프로젝트에서 Combine을 사용 안했다면, 나도 위의 방법을 사용하고 끝냈을 것.

---

갑자기 `onChange`를 통해 해보면 어떨까? 라는 생각이 들어 테스트를 해본다.

```swift
.onChange(of: query, {
   print(query)
})
```

이렇게 하면 입력할때마다 단어가 출력되긴하지만 내가 의도한 Combine의 Data Streaming은 아니다.

Pass

---

생각을 해보면?

1. 일단 입력값을 담을 변수가 Publisher의 Type이어야함.
2. 그걸 Searchable에 어떻게 반영할것인가?
3. 그렇다면 observe를 Searchable에 어떻게 사용을 할수있을것인가?
4. 그게아니라면 다른 Modifier를 찾아야 하는건가?

가장 큰 난관이 Text를 Publisher로 해야하는데 searchable이 바인딩 값을 원한다는것...

그렇다고 `@Published`를 쓰자니 그건 struct에서 안된다.

원래 계획은 View에서 먼저 기능을 해결하고 이후에 viewModel로 옮겨서 하려는건데 그냥 SearchViewModel을 만들고 거기에 Published를 사용하고, 그걸 사용하기 위해 view에서는 `@Binding`을 사용해서 변수를 만들어 searchable에 해야하나 생각을 했지만, 그렇게하더라도 결국엔 `searchable` Modifier에서 막힌다고 판단.

SearchBar는 TextField로 만드는 것이 맞다는 판단을 내렸다.

그렇다면 이제 TextField에서 입력값을 어떻게 Combine 스트림으로 연결할 것인가?

#### 난관 봉착: Combine 스트림을 어떻게 엮을 것인가?

View 안에서 먼저 기능을 구현하고 데이터 흐름을 검증하려다 보니 고민에 빠졌다.

1. **`onReceive`를 사용해서 이어나간다.**
2. **`TextField`를 커스텀해서 이어나간다.**

처음에는 `.searchable`이 제공하는 UI를 유지하면서 `.onReceive`로 이벤트를 받으려 했다.
하지만 데이터 스트리밍 관점에서 치명적인 문제가 있었다.

`@State`로 선언된 변수는 `Publisher`가 아니라 `Binding` 타입이기 때문에, `$query.debounce(...).filter(...)` 같은 Combine 특유의 파이프라인 체이닝을 걸 수가 없었다. `.onReceive`는 단순히 이벤트를 일회성으로 받을 뿐, 복잡한 스트림을 조작하기엔 적합하지 않았다.

> **핵심:** `@State`는 `Binding` 타입이라 Combine Publisher가 아니다.
> `$query.debounce(...)` 같은 체이닝이 불가능한 이유가 여기 있다.

---

#### 해결책: 중요한 건 UI가 아니라 구독관계였다

결국 지금 당장 포커스를 둬야 할 것은 UI가 아니라 **'데이터 스트리밍의 완벽한 제어'**였다.

```swift
// Before
.searchable(text: $query, prompt: "Search GitHub users")
// After
HStack(spacing: 10) {
   Image(systemName: "magnifyingglass")
      .foregroundStyle(.secondary)
   TextField("Search GitHub users", text: $query)
      .autocorrectionDisabled()
      .textInputAutocapitalization(.never)
   if !query.isEmpty {
      Button {
            query = ""
      } label: {
            Image(systemName: "xmark.circle.fill")
               .foregroundStyle(.secondary)
      }
   }
}
// Modifier 생략
```

그래서 위와 같이 UI를 변경해주었다. (searchable → TextField)

---

일단 여기서 내가 생각을 해내야하는건? TextField를 사용했을때 어떻게 이걸
`var textPublisher = PassthroughSubject<String, Never>()`를 연결해서 실시간 데이터 스트리밍으로 연결하냐는 것이다.

우선 구독이 필요하고.

그다음 그 구독을 이용해서 PassthroughSubject가 값을 보내면 subsciber가 값을 print 하는 매커니즘이 필요.

그렇다면 이걸 어떻게 TextField에서 가능하게 할것인가?

보통이라면 ViewModel에서 `@Pulished`를 사용하여 변수를 하나를 만들고.

`init()`을 통해 DataStreaming을 만들면 끝이다.

그렇게 고민을 하다가... Udemy강의를 잠깐 봤는데 생각이 났다.

지금 TextField와 Searchable은 사실 중요하지 않았다.

onChange를 통해 publisher가 값을 보내면 구독한 Subscriber가 값을 스트리밍하면되는데

구독을 어떻게 해야하는지 너무 기억이 안났는데 `onAppear`를 내가 생각을 못했다.
(UI는 다시 searchable로 변경....ㅎㅎ)

---

왜 이렇게 내가 해결책을 썼냐면 구독관계를 내가 함수를 만들고도 어떻게 정의를 해야할지 아무 생각이 없었다.

근데 onAppear가 있었다.

실제로 UIKit에서도 `ViewDidLoad`에 구독함수를 넣어서 View가 로드되자마자 구독관계를 만들었는데, 그걸 생각지 못했던것.

| 단계 (Phase) | UIKit | SwiftUI |
| :--- | :--- | :--- |
| **구독 관계 형성**<br>(Subscription) | `viewDidLoad()` 에서<br>`.sink` 구독 함수 호출 | `.onAppear()` 에서<br>`.sink` 구독 함수 호출 |
| **입력 이벤트 감지**<br>(Event Observation) | `NotificationCenter`<br>`textDidChangeNotification` | `.onChange(of: query)`<br>상태 변화 감지 |
| **스트림에 데이터 방출**<br>(Data Emission) | 커스텀 `textPublisher` 내<br>`.map` 가공 후 방출 | `PassthroughSubject`<br>`.send(newValue)` 호출 |   


---

> **참고 — View 먼저, ViewModel은 나중에**
>
> 보통 처음 접하는 개념이나 오랜만에 쓰는 기술이면 View에서 먼저 검증하고 ViewModel로 추출하는 게 일반적인 흐름이다.
> 처음부터 ViewModel을 만들고 시작하는 건 이미 흐름을 다 알고 있을 때나 팀 프로젝트에서 구조가 먼저 잡혀있을 때 하는 방식.
> 지금은 Combine 체화가 목적이므로 View에서 먼저 검증하는 게 맞다.
