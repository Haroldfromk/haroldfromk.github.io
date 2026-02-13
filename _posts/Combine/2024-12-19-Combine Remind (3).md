---
title: Combine Remind (Fin)
writer: Harold
date: 2024-12-19 06:16
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## Http Client

이 코드를 가지고 UIKit, SwiftUI에 적용을 한다.


```swift
import Combine

enum NetworkError: Error {
    case badUrl
}

class HTTPClient {
    
    func fetchMovies(search: String) -> AnyPublisher<[Movie], Error> {
        
        guard let encodedSearch = search.urlEncoded,
              let url = URL(string: "https://www.omdbapi.com/?s=\(encodedSearch)&page=2&apiKey=apikey")
        else {
            return Fail(error: NetworkError.badUrl).eraseToAnyPublisher()
        }
                
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: MovieResponse.self, decoder: JSONDecoder())
            .map(\.Search)
            .receive(on: DispatchQueue.main)
            .catch { error -> AnyPublisher<[Movie], Error> in
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
}
```

Fetch를 해서 데이터를 가져오는 매커니즘 자체는 크게 달라진게 없다. ViewModel도 크게 언급할게 없어서 패스

다만 기존에서 했던것과 차이를 보이는 부분이 2군데가 있어서 그부분을 확인하고 넘어간다.

물론 위의 코드는 UIKit이라고해서 달라진게 아니라 Fetch를 하는 표현의 방법중 Error Handling에서 차이를 보여 정리를 하고자 한다.

### 1. 기존의 방식

```swift
func fetchPosts() -> AnyPublisher<[Post], Error> {
    
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .tryMap { data, response in
            print("retries")
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.badServerResponse
            }
            
            return data
        }
        .decode(type: [Post].self, decoder: JSONDecoder())
        .retry(3)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
}
```

1. `let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!`
    - 기존에는 url 자체를 옵셔널 바인딩 하지않고 강제 Unwrapping(!)을 사용하였다.
    - 그러다보니 예외처리가 되어있지는 않은 상황.
        - 주소가 잘못되었다면 App Crash 발생 
2. `tryMap`
    - throw를 통해 response가 잘못되었을 경우 Network에러를 던짐

여기서의 주요특징은 이렇게 2가지로 정할 수 있다.

---

### 2. 지금의 코드 방식

1. `guard let url`
    - url 자체를 `guard let`을 사용하여 안전하게 사용.
    - 주소가 잘못되면 else가 작동.
    - 이때 리턴하는 타입은 `AnyPublisher<[Movie], Error>`
    - Fail도 Publisher 이고 아래와 같은 경우에 사용
        1. 단일 에러를 방출해야 할 때: 한 번의 에러 방출로 작업을 종료해야 할 경우 (지금 케이스)
        2. 작업의 실패를 나타낼 때: 특정 작업이나 연산이 성공하지 못했음을 나타내야 할 때.
        3. Publisher 파이프라인에서 에러를 처리할 때: 에러를 명시적으로 표현하여 파이프라인 흐름에서 처리해야 할 경우.
    - [Fail Docs](https://developer.apple.com/documentation/combine/fail){:target="_blank"}
2. `catch`
    - **`error -> AnyPublisher<[Movie], Error>`**:
        - 상위 퍼블리셔에서 발생한 에러를 `catch`를 통해 처리하며, 이를 새로운 **Publisher**로 변환한다.

    - **`return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()`**:
        1. 에러가 발생했을 때, Output 타입인 `[Movie]`의 빈 배열 `[]`을 방출한다.
        2. `Just([])`:
            - `[Movie]` 타입의 값을 방출하는 단일 Publisher를 생성.
        3. `.setFailureType(to: Error.self)`:
            - 상위 Publisher에서 기대하는 **Failure** 타입을 `Error`로 설정하여 타입 일치를 보장.
            - 이는 상위 퍼블리셔(즉, `error -> AnyPublisher<[Movie], Error>`)와 **Failure 타입**을 맞춰 파이프라인이 깨지지 않도록 한다.
        4. `.eraseToAnyPublisher()`:
            - 타입 정보를 지우고, 결과적으로 **AnyPublisher<[Movie], Error>** 를 반환.

---

- **상위 퍼블리셔란?**
    - 여기서 상위 퍼블리셔는 `catch` 이전의 퍼블리셔 체인을 의미하며, **`error -> AnyPublisher<[Movie], Error>`**가 상위 퍼블리셔이다.
    - 상위 퍼블리셔에서 에러가 발생하면, `catch`를 통해 이를 처리하고 동일한 **Output** 및 **Failure** 타입을 유지해야 한다.
- **왜 `setFailureType(to:)`가 필요한가?**
    - `Just([])`는 Failure 타입이 `Never`로 되어 있으므로, 이를 상위 퍼블리셔의 Failure 타입(`Error`)에 맞춰야 한다.
    - `setFailureType(to: Error.self)`를 사용해 Failure 타입을 맞춤으로써, 타입 불일치로 인해 파이프라인이 깨지는 문제를 방지한다.

---

### 3. 부록: Just, setFailureType, eraseToAnyPublisher

1. `Just([ ])`
- Just는 Combine에서 제공하는 퍼블리셔(Publisher) 중 하나로, 단일 값을 즉시 방출한 후 완료(completion)를 방출한다.
```swift
let justPublisher = Just("Hello, Combine!")
justPublisher.sink { completion in
    print(completion) // .finished
} receiveValue: { value in
    print(value) // "Hello, Combine!"
}
```
- 2번에서의 코드에서는 [Movie] 타입의 빈 배열 []을 발행하기 위해 Just([])를 사용하고 있다.
    - Just([])는 [Movie] 타입의 값을 바로 내보내고 .finished를 방출한다.
    - 이 단계에서는 에러 타입을 포함하지 않는다(Never).

2. setFailureType(to: Error.self)
- Just 퍼블리셔는 기본적으로 에러를 방출하지 않는 타입(Failure == Never)이다. 하지만 파이프라인에 일관된 에러 타입을 맞추기 위해 setFailureType(to:)를 사용하여 **실패 유형(failure type)**을 명시적으로 설정한다.
```swift
let justPublisher = Just("Hello").setFailureType(to: MyError.self)
justPublisher.sink(receiveCompletion: { completion in
    switch completion {
    case .finished:
        print("Finished")
    case .failure(let error):
        print("Error: \(error)")
    }
}, receiveValue: { value in
    print("Value: \(value)")
})
```
- MyError라는 에러 타입을 선언하여 해당 퍼블리셔의 에러 타입을 명시적으로 추가할 수 있다.

3. eraseToAnyPublisher()
- eraseToAnyPublisher()는 구체적인 퍼블리셔 타입을 감추고, 표준화된 AnyPublisher<Output, Failure> 형태로 변환한다.
	- 이유:
	- 파이프라인을 단순화하고, 다른 코드와의 호환성을 유지하기 위해 사용한다.
	- 구체적인 퍼블리셔 타입이 노출되면, 코드를 확장하거나 변경하기 어려워진다.
```swift
let publisher = Just(42)
    .map { $0 * 2 }
    .eraseToAnyPublisher()
```
- Just<Int>가 최종적으로 AnyPublisher<Int, Never>로 변환된다.

위의 내용을 디테일하게 하다보니 생각보다 설명이 길어졌다.

## UIKit에서의 Combine 활용

기본적인건 제외하고 알아두면 좋을 것같은 내용만 적어본다.
코드를 보면서 필요한것만 가져오다보니 순서는 크게 신경쓰지 말자.

### 1. 의존성 주입

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
      
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MoviesViewController(viewModel: MovieListViewModel(httpClient: HTTPClient())) 
        window.makeKeyAndVisible()
        self.window = window
    }
```

SceneDelegate에서 ViewModel에 대해 의존성 주입을 한다.

이렇게 의존성 주입을 하게되면 ViewModel을 우리가 굳이 Instance화 해서 사용을 하지 않아도 되는 장점이 있다.

### 2. ViewModel

```swift
class MovieListViewModel {
    @Published private(set) var movies: [Movie] = []
    private var cancellables: Set<AnyCancellable> = []
    @Published var loadingCompleted: Bool = false

    private var searchSubject = CurrentValueSubject<String, Never>("")

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        setupSearchPublisher()
    }

    private func setupSearchPublisher() {

    searchSubject
        .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
        .sink { [weak self] searchText in
            self?.loadMovies(search: searchText)
        }.store(in: &cancellables)

    }

    func setSearchText(_ searchText: String) {
        searchSubject.send(searchText)
    }   

    func loadMovies(search: String) {
    
    httpClient.fetchMovies(search: search)
        .sink { [weak self] completion in
            switch completion {
                case .finished:
                    self?.loadingCompleted = true
                case .failure(let error):
                    print(error)
            }
        } receiveValue: { [weak self] movies in
            self?.movies = movies
        }.store(in: &cancellables)

        
    }
}
```

우선 ViewModel의 코드를 전부 가져오기는 했다.

#### 1. private(set) var

`@Published private(set) var movies: [Movie] = []`
- 변수를 선언할때 private(set)을 사용함으로써 외부에서는 읽기만 가능하고 변수에 값을 넣는 쓰기작업은 선언한 ViewModel 내에서만 가능하다는것을 의미.

#### 2. searchSubject

`private var searchSubject = CurrentValueSubject<String, Never>("")`

해당 Subject를 통하여 사용자가 입력한 Text를 스트림 형태로 처리한다.

#### 3. setupSearchPublisher

- 2번의 searchSubject로 부터 방출된 Text를 전달 받아 해당 text를 loadMovies 함수에 전달.
    - 이때 과도한 Api 호출을 방지하기위해 `debounce`를 사용하여 text를 전달받은 시점으로 부터 0.5초 뒤에 loadMovies에 전달

#### 4. setSearchText

- searchSubject에 사용자 입력 텍스트를 전달하는 메서드이다.
- 전달된 setupSearchPublisher에서 정의된 스트림으로 처리된다

### 3. ViewController 

여기는 코드가 UIKit 특성상 길기에 해당부분만 덜어내어서 정리

#### 1. init

```swift
init(viewModel: MovieListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
}
```

의존성 주입을 한다. 크게 언급하지 않겠다.

자세한건 [이전글](https://haroldfromk.github.io/posts/(Deep-Dive)-Dependency-Injection/){:target="_blank"} 참고.

#### 2. loadingCompleted

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    setupUI()
    
    viewModel.$loadingCompleted
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completed in
            if completed {
                // reload the tableview
                self?.moviesTableView.reloadData()
            }
        }.store(in: &cancellables)
    
}
```

일반적으로 이부분은 VC에서 `bind`라는 메서드를 만들어서 처리를 한다. 여기서는 그냥 loadingCompleted를 바인딩하여, fetch의 유무를 판단하여 TableView를 렌더링 한다.

#### 3. VC extenstion (UISearchBarDelegate)

```swift
extension MoviesViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.setSearchText(searchText)
    }
}
```

searchBar를 사용하기위해 코드의 간결함을 위하여 extension으로 분리를 해주었으며, 여기서 setSearchText를 호출하여 사용자가 searchBar에서 Text를 입력하면 VM의 `setupSearchPublisher`로 전달하여 fetch를 진행하게 된다.

## SwiftUI에서의 Combine 활용

HTTP Client의 코드는 동일하고 UIKit과 달리 View에서 어떻게 사용하느냐의 차이로 생각 하면 된다.

### 1. 데이터 모델링

데이터 모델링을 먼저 언급한 이유는 UIKit에서의 TableView와 달리 List에서 사용될 객체타입은 반드시 `Identfiable` 프로토콜을 따라야 한다.

```swift
struct Movie: Identifiable, Decodable {
    
    let title: String
    let year: String
    let imdbId: String
    let poster: URL?
    
    var id: String {
        imdbId 
    }
    
    private enum CodingKeys: String, CodingKey {
        case title = "Title"
        case year = "Year"
        case imdbId = "imdbID"
        case poster = "Poster"
    }
}
```

### 2. 의존성 주입

```swift
struct MoviesSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(httpClient: HTTPClient())
            }
        }
    }
}

struct ContentView: View {
    // 생략
    init(httpClient: HTTPClient) {
            self.httpClient = httpClient
        }
    // 생략
}
```

여기서도 의존성 주입이 되었다.

### 3. searahable, onChange

```swift
.searchable(text: $search)
.onChange(of: search) {
    searchSubject.send(search)
}
```

- `.searchable` Modifier를 사용하여 SearchBar를 구현 
    - 이때 해당 Modifier NavigationStack이 반드시 필요하다.
    - 여기선 App에서 자체적으로 NavigationStack을 씌워주었다.
- `onChange` Modifier를 사용하여 사용자가 입력한 값에 반응.
    - 값을 입력할때마다 **searchSubject를 통해 setupSearchPublisher로 전달**

---

## Debugging Combine Code

Combine을 사용하면 Subscription 관계를 파악하기 위해 중간중간에 `Print()`를 활용하여 스트림의 상태를 파악하곤 했다.

자주사용한 `print`는 제외하고 다른 방법을 적어본다.

먼저 언급을 해본다면, breakpoint는 특정 조건에서 디버거를 중단시키는 데 주로 사용하고, handleEvents는 전체 스트림의 생명 주기를 추적하는 데 더 적합하다.

### Breakpoint

```swift
class HTTPClient {
    
    func fetchMovies(search: String) -> AnyPublisher<[Movie], Error> {
        
        guard let encodedSearch = search.urlEncoded,
              let url = URL(string: "https://www.omdbapi.com/?s=\(encodedSearch)&page=2&apiKey=564727fa")
        else {
            return Fail(error: NetworkError.badUrl).eraseToAnyPublisher()
        }
                
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: MovieResponse.self, decoder: JSONDecoder())
            .map(\.Search)
            .breakpoint(receiveOutput: { movie in
                movie.isEmpty
            })
            .receive(on: DispatchQueue.main)
            .catch { error -> AnyPublisher<[Movie], Error> in
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
}
```

[Combine Breakpoint Docs](https://developer.apple.com/documentation/combine/publisher/breakpoint(receivesubscription:receiveoutput:receivecompletion:)){:target="_blank"}

여기서는 간단하게 파라미터를 receiveOutput을 사용했다.

즉, URLSession을 통해 전달 받은 값에 대하여, 그값이 어떤 조건일때(이건 우리가 설정)의 true/ false에 따라. breakpoint를 바로 생성한다.

지금은 강제로 띄우기 위해 `!movie.isEmpty` 즉 fetch가 정상적으로 이루어 졌을때 바로 breakpoint를 호출하게 했고 사진과 같다.

![Dec-19-2024 11-28-42](https://github.com/user-attachments/assets/54238469-0435-4d67-a5b4-4dbcd0f2d8ab)

[BreakPoint 설정](https://developer.apple.com/documentation/xcode/setting-breakpoints-to-pause-your-running-app){:target="_blank"} 이건 뭐 다알지만 Docs의 링크를 걸어봤다.

#### 다른 예시

```swift
let numbers = [1, 2, 3, 4, 5].publisher

let _ = numbers
    .map({ $0 })
    .eraseToAnyPublisher()
    .breakpoint(receiveOutput: { value in
        value == 3
    })
    .sink { value in
        print(value)
    }

let _ = numbers
    .breakpoint(receiveOutput: { $0 == 3 })
    .sink { print($0) }    
```

위의 두 코드는 같은결과를 도출하는데, 간결하게 한것과 약간 풀어쓴것이라고 보면 된다.

![CleanShot 2024-12-19 at 12 12 15](https://github.com/user-attachments/assets/faf4e12a-b7c9-461b-80d9-cc1a6cbdff3b)

playground에선 위와같이 에러가 발생.

1~5까지가 정상적으로 출력이 다되었다.

확실히 playground파일과, swift파일은 실행이 다른것같다.

---

### handleEvents

```swift
let publisher = [1,2,3].publisher

let _ = publisher
    .handleEvents { _ in
        print("Subscription received")
    } receiveOutput: { value in
        print("receiveOutput")
        print(value)
    } receiveCompletion: { completion in
        print("receiveCompletion")
    } receiveCancel: {
        print("receiveCancel")
    } receiveRequest: { _ in
        print("receiveRequest")
    }
    .map { $0 * 3 }
   // .filter { $0 % 2 == 0 }
    .sink { value in
        print("sink")
        print(value)
    }

/*
Subscription received
receiveRequest
receiveOutput
1
sink
3
receiveOutput
2
sink
6
receiveOutput
3
sink
9
receiveCompletion    
*/
```

[HandleEvents Docs](https://developer.apple.com/documentation/combine/publisher/handleevents(receivesubscription:receiveoutput:receivecompletion:receivecancel:receiverequest:)){:target="_blank"}

HandleEvents에 경우 지금은 print로 출력을 해봤는데, Stream의 life cycle을 전부 핸들링을 할 수 있다는 장점이 있다.

이렇게 정리를 하고보니 SwiftUI가 너무 간단하다는게 놀랍고 전에 UIKit으로 Combine을 사용하면서, 그때는 뭔가 제대로 흐름이나, 사용법에대해 완벽하게 이해하지 않고, 마구잡이식으로 했는데, 지금 코드를 다시보니 고쳐야할 부분이 많다라는게 보이기 시작한다.

그리고 print만 사용했었는데 그게 아니라 breakpoint나 handleevent 등 새로운것에 대해 알게되었다.

다음에 Combine을 사용하여 앱을 하나 만드는 글에 대해 포스팅을 할때는 위의 저 두 요소를 통해 디버깅을 해보는 과정도 적어보도록 하겠다.