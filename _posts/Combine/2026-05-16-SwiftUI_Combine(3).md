---
title: SwiftUI Combine (3)
writer: Harold
date: 2026-05-16 07:16
categories: [Udemy, Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

## 진짜 Fighter Service 만들기

이전글에서 Future에 너무 매몰이 되어서 글이 너무 길어지는 바람에 새로 적고 제대로 시작해본다.

---

### 진짜 fetchAllFightersData 만들기

```swift
private func fetchAllFightersData() -> AnyPublisher<Data, Error> {
    Future<Data, Error> { promise in
        guard let url = Bundle.main.url(forResource: "MMAFighters", withExtension: "json") else {
            return promise(.failure(NSError(
                domain: "MockUFCFighterService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "MMAFighters.json not found"]
            )))
        }
        
        do {
            let data = try Data(contentsOf: url)
            promise(.success(data))
        } catch {
            promise(.failure(error))
        }
    }
    .eraseToAnyPublisher()
}
```

코드를 보면 솔직히 url 부분과 do~catch 블럭은 너무나도 익숙한 부분이라 굳이 언급을 할 필요는 없어보인다.

우선 보게되면?

우리가 Json을 Data 형식으로 바꿔야 Decoding이 가능해서 리턴타입에 Data가 들어가있다.

그리고 결과론적으로 `AnyPublisher<Data, Error>`로 리턴이 되어야 하기에 마지막 부분에 `.eraseToAnyPublisher()`를 써주었다.

---

### fetchFightersData

MMAFighters.json으로 부터 raw Data를 가져온다. search에 값이 들어간다면 필터링된 값을 리턴

```swift
func fetchFightersData(search: String? = nil) -> AnyPublisher<Data, Error> {
    fetchAllFightersData()
        .tryMap { data -> Data in
            let decoder = JSONDecoder()
            let response = try decoder.decode(FightersResponse.self, from: data)
            
            // If search string is empty or nil, return all fighters
            guard let query = search, !query.isEmpty else {
                return data
            }
            
            // Filter by name (case-insensitive)
            let filtered = response.fighters.filter {
                $0.name.lowercased().contains(query.lowercased())
            }
            
            let filteredResponse = FightersResponse(fighters: filtered)
            return try JSONEncoder().encode(filteredResponse)
        }
        .eraseToAnyPublisher()
}
```

우선 파라미터에서 신선한게 `search: String? = nil` 여기
search에 값이 없을 수도 있기에 `""` 로 처리를 한게 아니라 optional로 해주었다. 그리고 default값을 일부러 `nil`로 해주었다.

그리고 위에서 만든 함수를 호출을 하는데 여기서 부터가 왜 우리가 `AnyPublisher`로 굳이 리턴을 했는지 알 수 있는 대목

바로 `tryMap`을 통해 리턴값을 재가공 하기 위해서다.

그리고 tryMap을 사용한 이유는 `try` 어디서 본거같지않나? 물론 여기선 `error handling`이 빠져있는데 애초에 퍼블리셔를 통해 에러도 리턴을 하기때문에 그 에러에 대해서 대처할때 사용하기위해 tryMap을 쓴것.

만약 query에 값이 있다면 디코딩한 값에서 필터링을 하여 값을 filtered에 담고 다시 인코딩을 해주었다.

사실 강의를 보면서 왜 인코딩을 다시 해줬는지 모르겠다.

굳이? 라는 생각이다.

---

### fetchFighters

```swift
func fetchFighters(search: String? = nil) -> AnyPublisher<[MMAFighter], Error> {
    fetchFightersData(search: search)
        .decode(type: FightersResponse.self, decoder: JSONDecoder())
        .map { $0.fighters }
        .eraseToAnyPublisher()
}
```

진짜 최종적으로 Data -> [MMAFighter]로 디코딩 하는 단계이다.

여긴 딱히 설명이 필요없어 보이긴 한다.

`fetchFightersData`에서 바로 `[MMAFighter]`로 반환하면 `fetchFighters`가 필요 없다.
굳이 `Data → [MMAFighter] → Data → [MMAFighter]` 이렇게 왔다 갔다 할 이유가 없는데 아이러니 하지만 강의에서 그렇게 했으니 패스...

---

## ViewModel 만들기

여기선 선수 검색에 필요한 함수만 있으면 된다.

```swift
final class FighterListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var fighters: [MMAFighter] = []
    private let service = MockUFCFighterService()
    private var cancellables = Set<AnyCancellable>()

    func search() {
        service.fetchFighters(search: searchText)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error fetching fighters: \(error)")
                    }
                },
                receiveValue: { [weak self] fighters in
                    self?.fighters = fighters
                }
            )
            .store(in: &cancellables)
    }
}
```



앞서 Service에서 `tryMap`이 에러를 throws로 던졌는데, 결국 그 에러가 여기까지 흘러온다.

```swift
func tryMap<T>(_ transform: @escaping (Self.Output) throws -> T) -> Publishers.TryMap<Self, T>
```

`fetchAllFightersData` → `fetchFightersData` → `fetchFighters` → `search()`

이 흐름의 최종 종착지가 `sink`의 `receiveCompletion`이고, 거기서 `.failure`를 처리하는 구조다. 지금은 `print`로만 처리했지만, 실제 앱이라면 여기서 Alert를 띄우거나 에러 상태를 `@Published`로 관리하면 된다.

그리고

`if case .failure(let error) = completion` 이 처음 보면 낯선 문법인데, Swift의 **패턴 매칭**이다.

`completion`은 `Subscribers.Completion<Error>` 타입으로 `.finished`와 `.failure(Error)` 두 가지 케이스를 가진다. 이 중 `.failure`인 경우에만 실행하고 싶을 때 `if case`를 사용한다.

```swift
// if case 없이 쓰면
switch completion {
case .finished:
    break
case .failure(let error):
    print(error)
}

// if case로 줄이면
if case .failure(let error) = completion {
    print(error)
}
```

`.failure`일 때만 처리하고 싶은데 `switch`를 쓰면 `.finished`까지 처리해야 해서 장황해진다. `if case`는 원하는 케이스 하나만 간결하게 꺼낼 때 쓴다.

간단하게 한마디로 정리하면 `completion이 가질 수 있는 케이스 중에서 .failure인 경우에~` 이거다.

---

## ViewModel을 View에 적용

```swift
@StateObject private var vm = FighterListViewModel()

VStack {
    TextField("Search fighters...", text: $vm.searchText)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding()

    Button("Search") {
        vm.search()
    }
    .padding(.bottom)

    List(vm.fighters, id: \.name) { fighter in
        VStack(alignment: .leading) {
            Text(fighter.name)
                .font(.headline)
            Text("\(fighter.record) • \(fighter.fightTeam) • \(fighter.country)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
```

사실 크게 뭐 언급할게 없어보인다.

굳이 하나꼽자면 `id: \.name`?
저건 List에서 각 row를 구분할 때 name 값을 식별자로 사용하겠다. 라는것

---

### id?

`id`는 조금 자세하게 알아둘 필요가 있다.

`id`를 사용하는 방식에 따라 필요한 조건이 조금 다르다.

---

#### id를 명시적으로 제공하는 경우

```swift
List(vm.fighters, id: \.name)
```

이건 `name` 값을 식별자로 사용하겠다는 의미다.
즉 `name` 값이 중복되지 않는다는 보장이 필요하다.

```swift
List(vm.fighters, id: \.self)
```

모델 객체 자체를 식별자로 사용하므로, 객체 전체가 `Hashable`이어야 한다.

---

#### id를 생략하는 경우

```swift
List(vm.fighters)
```

이 경우는 `MMAFighter`가 `Identifiable` 프로토콜을 채택해야 한다.
`Identifiable`은 고유한 `id` 프로퍼티를 요구하는데, 보통 이렇게 추가한다.

```swift
struct MMAFighter: Codable, Identifiable {
    let id = UUID()
    let name: String
    // ...
}
```

`UUID()`는 매번 고유한 값을 생성하기 때문에 중복 걱정 없이 식별자로 쓸 수 있다.
실제 프로젝트에서 가장 많이 쓰는 방식이기도 하다.

---

#### 왜 식별자가 필요한가?

`ForEach`를 포함한 SwiftUI의 리스트는 데이터가 변경될 때 **변경된 부분만 효율적으로 다시 그린다.**

이를 위해 SwiftUI는 이전 데이터와 새 데이터를 비교(diff)해야 하는데, 각 항목이 "같은 항목인가"를 판단하려면 고유한 식별자가 반드시 필요하다.

식별자가 없으면 어떤 행이 바뀌었는지, 어떤 행이 그대로인지 알 수 없어서 컴파일러가 혼란스러워진다.

실제로 `Identifiable`을 채택하지 않은 커스텀 타입을 `ForEach`에 그냥 넣으면:

```swift
ForEach(fighters) { fighter in  // ❌
    Text(fighter.name)
}
```

이런 에러가 발생한다.

```
Generic parameter 'ID' could not be inferred
```

`Identifiable`을 채택하면 SwiftUI가 각 항목을 안전하게 추적할 수 있게 되어 리스트가 올바르게 렌더링된다.

---

#### 정리

| 방식 | 필요한 조건 |
|---|---|
| `List(data)` | `Identifiable` 필요 |
| `List(data, id: \.name)` | `name`이 `Hashable` |
| `List(data, id: \.self)` | 객체 전체가 `Hashable` |

무튼 실행하면 잘 되는 걸 알 수 있다.

<img width="288" height="598" alt="Image" src="https://github.com/user-attachments/assets/b32d7b64-b322-4496-9fd0-33b5ddadf9bd" />{: width="50%" height="50%"}
