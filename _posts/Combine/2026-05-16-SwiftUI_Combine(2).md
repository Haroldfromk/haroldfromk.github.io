---
title: SwiftUI Combine (2)
writer: Harold
date: 2026-05-16 07:16
categories: [Udemy, Combine]
tags: [Combine]

toc: true
toc_sticky: true
---

## MMA Information App 만들어보기

UI는 크게 중요하지 않아서 대충 만든다.

[Using Combine for Your App’s Asynchronous Code Docs](https://developer.apple.com/documentation/combine/using-combine-for-your-app-s-asynchronous-code){:target="_blank"} 이거 한번 읽어보면 좋다.

---

### Modeling

MMAFighters.json 파일을 보면
```
{
    "name": "Jon Jones",
    "fightTeam": "Jackson Wink MMA",
    "country": "USA",
    "record": "28-1 (1 NC)",
    "age": 36
},
```

이렇게 되어있다.

이걸 기준으로 Modeling을 해주도록 한다.

```swift
struct MMAFighter: Codable {
    let name: String
    let fightTeam: String
    let country: String
    let record: String
    let age: Int
}

struct FightersResponse: Codable {
    let fighters: [MMAFighter]
}
```

이렇게 해주었다.

---

### Fighter Service

여기선 Json Data로 하긴하지만 그래도 이것또한 NetworkService일종이니 Service를 만들어보도록 한다.

---

#### fetchAllFightersData 만들기

이 함수의 경우 Json을 불러오는 역할을 한다.

기존에 UIKit을 쓸때라던가 Json Decoding을 하기전에 JsonFile을 가져오는 작업을 해본적이 있는데, 그걸 Combine으로 한다고 생각하면 된다.

[이전글1](https://haroldfromk.github.io/posts/TourApp_4/){:target="_blank"},[이전글2](https://haroldfromk.github.io/posts/JPApexPredators-(1)/){:target="_blank"} 참고

---

##### 기존 방식

물론 이때의 코드일부를 잠깐 가져와보면

```swift
@Published var tours = [JsonModel]()

func load() {
    guard let url = Bundle.main.url(forResource: "data", withExtension: "json")
    else {
        print("Json file not found")
        return
    }
    
    let data = (try? Data(contentsOf: url))!
    let tours = try? JSONDecoder().decode([JsonModel].self, from: data)
    
    self.tours = tours!
}
```

url에 담아서 그걸 Data를 통해 변형을 해서 디코딩처리.

##### 현재 방식

메커니즘 자체는 완전히 똑같다. 단지 Combine을 사용하기에 Publisher가 있다는 것.

우선 함수의 return type부터 보자.

```swift
private func fetchAllFightersData() -> AnyPublisher<Data, Error> { }
```

---

###### AnyPublisher

[AnyPublisher Docs](https://developer.apple.com/documentation/combine/anypublisher){:target="_blank"}

함수의 return type을 `AnyPublisher<Data, Error>`로 선언하는 이유가 있다.

Combine에서 `map`, `filter` 같은 Operator를 체이닝하면 반환 타입이 중첩되면서 점점 복잡해진다.

```swift
// eraseToAnyPublisher() 없이 체이닝만 하면
// 타입이 이렇게 노출된다
// Publishers.Map<Publishers.Filter<Just<Int>>, String>
let rawPublisher = Just(1)
    .filter { $0 > 0 }
    .map { String($0) }
```

이 복잡한 타입을 함수의 return type으로 그대로 쓰면, 내부 구현이 전부 밖으로 드러나게 된다. 나중에 내부 파이프라인을 수정하면 return type도 같이 바뀌어 버린다.

`.eraseToAnyPublisher()`를 붙이면 내부 구현은 숨기고, 외부에는 **"나는 Data를 주고 Error를 던지는 Publisher야"** 라고만 알려준다.

```swift
// eraseToAnyPublisher() 적용 후
// Return Type: AnyPublisher<String, Never>
let cleanPublisher = Just(1)
    .filter { $0 > 0 }
    .map { String($0) }
    .eraseToAnyPublisher()
```

즉 `AnyPublisher`는 타입 소거(Type Erasure) 래퍼다. 내부가 어떻게 생겼든 상관없이 **최종 결과물의 타입만 깔끔하게 노출**하기 위해 사용한다.

---

###### Future

[Future Docs](https://developer.apple.com/documentation/combine/future){:target="_blank"}

함수 내부를 보면 `Future`가 등장한다.

`Future`는 **단 하나의 값**을 방출한 뒤 즉시 완료되거나 실패하는 일회성 Publisher다.

Docs에서도 언급하듯, completion handler 같은 콜백 기반 코드를 Combine 파이프라인으로 감쌀 때 주로 사용한다. **"딱 한 번 요청하고 결과 하나만 받으면 끝"** 인 작업에 적합하다.

동작 방식은 간단하다. `Future`를 생성할 때 `promise`라는 클로저를 받고, 작업이 끝나면 `.success` 또는 `.failure`로 결과를 전달한다. 전달하는 순간 스트림이 종료된다.

```swift
func loadLocalFile() -> Future<String, Error> {
    Future { promise in
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            promise(.failure(URLError(.fileDoesNotExist)))
            return
        }
        do {
            let text = try String(contentsOf: url)
            promise(.success(text))
        } catch {
            promise(.failure(error))
        }
    }
}
```

파일이 있으면 `.success`로 내용을 전달하고 완료, 없으면 `.failure`로 에러를 전달하고 완료. 딱 한 번만 동작한다.

이걸 `AnyPublisher`로 반환하려면 마지막에 `.eraseToAnyPublisher()`만 붙이면 된다.

```swift
func loadLocalFile() -> AnyPublisher<String, Error> {
    Future { promise in
        // ...
    }
    .eraseToAnyPublisher()
}
```

정리하면:
- **Future** → 딱 한 번 쏘고 완료되는 일회성 Publisher. 콜백 기반 코드를 Combine으로 감쌀 때 사용.
- **AnyPublisher** → 복잡한 내부 타입을 숨기고 깔끔한 타입만 외부에 노출하는 타입 소거 래퍼.

---

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-16-SwiftUI_Combine2/6ebae739-61e7-4540-b939-88834913b20c.png" />

사진으로 간단하게 정리.

---

###### Future 선언 방식 비교

코드를 보다 보면 `Future`를 쓰는 방식이 제각각인 것처럼 보인다.

```swift
// 1. 타입을 명시하지 않음
Future { promise in ... }

// 2. 타입을 직접 명시
Future<Data, Error> { promise in ... }

// 3. 괄호로 초기화
Future() { promise in ... }
```

셋 다 동일하다. 표현 방식만 다를 뿐이다.

`Future { promise in ... }` 는 Swift의 타입 추론 덕분에 함수의 return type이 이미 선언되어 있으면 타입을 생략할 수 있다.

```swift
// return type이 Future<String, Error>로 선언되어 있으면
// 안에서 타입 생략 가능
func loadLocalFile() -> Future<String, Error> {
    Future { promise in   // <String, Error> 생략
        promise(.success("data"))
    }
}
```

`Future<Data, Error> { promise in ... }` 는 return type이 `AnyPublisher`처럼 다른 타입으로 선언되어 있을 때, 컴파일러가 추론을 못하니까 직접 명시해주는 것이다.

```swift
// return type이 AnyPublisher<Data, Error>라서
// Future 안에서 타입을 명시해야 함
func fetchData() -> AnyPublisher<Data, Error> {
    Future<Data, Error> { promise in   // 명시 필요
        promise(.success(Data()))
    }
    .eraseToAnyPublisher()
}
```

`Future() { promise in ... }` 는 그냥 `Future { promise in ... }` 와 같다. `()`는 생략 가능한 빈 괄호일 뿐이다.

정리하면 세 가지 모두 동일한 `Future`다. **return type에서 타입 추론이 가능하면 생략, 불가능하면 명시**하는 것이 차이의 전부다.

---

아래 간단한 시뮬레이터를 만들어 보았다.

AnyPublisher
<iframe 
    src="/assets/demo/combine-simulator.html" 
    width="100%" 
    height="280px" 
    frameborder="0" 
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden; background-color: #1e1e1e;"
    title="AnyPublisher Simulator">
</iframe>

View 업데이트 시뮬레이터
(CompletionHandler, Future비교)
<iframe 
    src="/assets/demo/e2e-simulator.html" 
    width="100%" 
    height="650px" 
    frameborder="0" 
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden; background-color: #1e1e1e;"
    title="E2E Architecture Simulator">
</iframe>

시뮬레이터의 코드전개흐름은 다음과 같다.
내용이 길지만 그래도 이런 차이가 있어야 이해하기 좋기에 넣어둔다.

---

* ComepletionHandler

```swift
import SwiftUI

// 1. Service (API 통신 역할)
class LegacyService {
    func fetchUser(id: Int, completion: @escaping (Result<String, Error>) -> Void) {
        // 1초 뒤 백그라운드에서 결과 반환
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            completion(.success("Harold"))
        }
    }
}

// 2. ViewModel
class LegacyViewModel: ObservableObject {
    @Published var uiGreetingLabel: String = "대기 중..."
    private let service = LegacyService()
    
    func loadUser() {
        self.uiGreetingLabel = "로딩 중..."
        
        // 함수 호출
        service.fetchUser(id: 1) { [weak self] result in
            // ❌ 문제점 1: 껍데기(Result)를 무조건 switch로 까야 함
            switch result {
            case .success(let name):
                // ❌ 문제점 2: 콜백 내부(백그라운드 스레드)에서 가공 로직 짬뽕
                let upperName = name.uppercased()
                let finalMessage = "Hello, \(upperName)!"
                
                // ❌ 문제점 3: UI 업데이트를 위해 메인 스레드로 수동 전환 (들여쓰기 지옥)
                DispatchQueue.main.async {
                    self?.uiGreetingLabel = finalMessage
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.uiGreetingLabel = "에러 발생"
                }
            }
        }
    }
}

// 3. View
struct LegacyView: View {
    @StateObject var vm = LegacyViewModel()
    
    var body: some View {
        VStack {
            Text(vm.uiGreetingLabel) // 결과 출력
            Button("유저 불러오기") {
                vm.loadUser() // VM에 명령
            }
        }
    }
}
```

---

* Combine

```swift
import SwiftUI
import Combine

// 1. Service (API 통신 역할)
class CombineService {
    func fetchUserFuture(id: Int) -> Future<String, Error> {
        return Future { promise in
            // 1초 뒤 결과 방출
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                promise(.success("Harold"))
            }
        }
    }
}

// 2. ViewModel
class CombineViewModel: ObservableObject {
    @Published var uiGreetingLabel: String = "대기 중..."
    private let service = CombineService()
    private var cancellables = Set<AnyCancellable>()
    
    func loadUser() {
        self.uiGreetingLabel = "로딩 중..."
        
        // 함수 호출과 동시에 파이프라인 탑승!
        service.fetchUserFuture(id: 1)
            .map { $0.uppercased() }                // ✅ 가공 1: 대문자로
            .map { "Hello, \($0)!" }                // ✅ 가공 2: 인사말 붙이기
            .receive(on: DispatchQueue.main)        // ✅ UI 업데이트를 위해 메인 스레드로 자동 전환!
            .sink(
                receiveCompletion: { completion in
                    if case .failure(_) = completion { self.uiGreetingLabel = "에러 발생" }
                },
                receiveValue: { [weak self] finalMessage in
                    // ✅ 종착지: 깔끔하게 가공된 데이터를 UI에 반영
                    self?.uiGreetingLabel = finalMessage
                }
            )
            .store(in: &cancellables)
    }
}

// 3. View
struct CombineView: View {
    @StateObject var vm = CombineViewModel()
    
    var body: some View {
        VStack {
            Text(vm.uiGreetingLabel) // 결과 출력
            Button("유저 불러오기") {
                vm.loadUser() // VM에 명령
            }
        }
    }
}
```

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-16-SwiftUI_Combine2/6b1ff7ad-0c07-43ee-b051-2314a42c3a31.png" />

이미지 참고.

---

원래는 이 포스팅에서 MMA App의 UI와 ViewModel 코드까지 전부 작성하려고 했는데, Future와 AnyPublisher, 그리고 기존 콜백 방식과의 차이점을 확실하게 짚고 넘어가다 보니 글이 엄청나게 길어졌다.

하지만 Combine을 실무에서 제대로 쓰기 위해 **"왜 이걸 써야 하는지(데이터 흐름의 차이)"**를 시뮬레이터와 함께 완벽하게 이해하고 넘어가는 것이 훨씬 중요하다고 생각한다.

아무래도 함수만들기는 다음글에서 본격적으로 다루는걸로....