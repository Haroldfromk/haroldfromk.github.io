---
title: Combine Remind (2)
writer: Harold
date: 2024-12-18 14:16
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## CustomSubject

Subject하면 우리는

PassthroughSubject와 CurrentValueSubject 이렇게 2개를 알고 있는데,

Subject를 Customizing 할 수 있다.

짝수에 관한 CustomSubject를 만들어본다.

```swift
class CustomSubject<Failure: Error>: Subject {
    
}
```

Generic을 사용해서 Error를 다룬다. 이때 class는 반드시 Subject 프로토콜을 준수해야한다.

[Subject Docs](https://developer.apple.com/documentation/combine/subject){:target="_blank"}

에러가 떠서 Fix를 하면

```swift
typealias Output = <#type#>
typealias Failure = <#type#>

func send(subscription: any Subscription) {
    <#code#>
}
```

3개가 생기는데, 우린 Failure를 generic으로 처리할것이므로 지우고 output만 int로 바꾼다.

그러면또 에러가뜨면서 fix하라고 뜨는데 fix를 하면 이렇게 기본 구성이 갖춰지게 된다.

```swift
class CustomSubject<Failure: Error>: Subject {
    
    typealias Output = Int
    
    func send(subscription: any Subscription) {
        
    }
    
    func send(_ value: Int) {
        
    }
    
    func send(completion: Subscribers.Completion<Failure>) {
        
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Int == S.Input {
        
    }
    
}
```

이제 함수부분을 채워보자.

```swift
class CustomSubject<Failure: Error>: Subject {
    
    typealias Output = Int
    
    private let wrapped: PassthroughSubject<Int, Failure>
    
    init(initialValue: Int) {
        self.wrapped = PassthroughSubject()
        let evenInitialValue = initialValue % 2 == 0 ? initialValue : 0
        send(initialValue)
    }
    
    func send(subscription: any Subscription) {
        wrapped.send(subscription: subscription)
    }
    
    func send(_ value: Int) {
        wrapped.send(value)
    }
    
    func send(completion: Subscribers.Completion<Failure>) {
        wrapped.send(completion: completion)
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Int == S.Input {
        wrapped.receive(subscriber: subscriber)
    }
    
}
```

send나 receive 부분은 파라미터를 그대로 넣어주면 된다.


```swift
func send(_ value: Int) {
    if value % 2 == 0 {
        wrapped.send(value)
    }
}
```

이렇게 바꾸고

```swift
subject.send(10)
subject.send(5)

// 10
```

10만 출력하게 된다.

하지만 init에 대한 의도가 불분명하기에 코드를 임의로 내가 수정한다.

```swift
class CustomSubject1<Failure: Error>: Subject {
    
    typealias Output = Int
    
    private let wrapped: CurrentValueSubject<Int, Failure>
    
    init(initialValue: Int) {
        self.wrapped = CurrentValueSubject(initialValue)
        let evenInitialValue = initialValue % 2 == 0 ? initialValue : 0
        send(evenInitialValue)
    }
    
    func send(subscription: any Subscription) {
        wrapped.send(subscription: subscription)
    }
    
    func send(_ value: Int) {
        if value % 2 == 0 {
            wrapped.send(value)
        }
    }
    
    func send(completion: Subscribers.Completion<Failure>) {
        wrapped.send(completion: completion)
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Int == S.Input {
        wrapped.receive(subscriber: subscriber)
    }
    
}

let subject1 = CustomSubject1<Never>(initialValue: 4)

let cancellable1 = subject1.sink { value in
    print(value)
}
```

바로 CurrentValueSubject를 사용

그러면 initialValue의 값이 어떠냐에 따라 처음에 초기값이 어떻게 리턴이 되는지도 확인이 가능하기 때문이다.

## Combine을 활용한 Network request

api는 [여기](https://jsonplaceholder.typicode.com/posts){:target="_blank"}에서 가져온다.

```swift
struct Post: Codable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}

func fetchPost() -> AnyPublisher<[Post], Error> {
    
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts")
        
    return URLSession.shared.dataTaskPublisher(for: url!)
        .map(\.data)
        .decode(type: [Post].self, decoder: JSONDecoder())
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
}

var cancellables = Set<AnyCancellable>()

fetchPost()
    .sink { completion in
        switch completion {
        case .finished:
            print("done")
        case .failure(let error):
            print(error.localizedDescription)
        }
    } receiveValue: { posts in
        print(posts)
    }.store(in: &cancellables)
```

이전에 한번 해본적이 있어서 크게 이해하는데는 문제가 없었다.

[이전글](https://haroldfromk.github.io/posts/10%EC%A3%BC%EC%B0%A8-%EA%B3%BC%EC%A0%9C-(2)/){:target="_blank"} 참고

물론 그당시엔 어떻게든 하려고 이것저것 끼워맞추기식으로 한거였어서, 지금 보면 코드가 그렇게 좋은건 아닌듯하다.

위의 코드를 내 나름대로 분석을 해본다면

우선 dataTaskPublisher를 통해 리턴을 하는데,

- `map(\.data)`:
    - URLSession을 통해 반환되는 값은 data, response 두개가 있다.
        - 그중 우리는 data가 필요하기에 data만 map을 통해 사용한다는 것.
- `.receive(on: DispatchQueue.main)`:
    - 해당 작업은 메인스레드에서 진행
- `eraseToAnyPublisher`:
    - eraseToAnyPublisher는 지금까지의 데이터 스트림이 어떠했던간에 publisher type을 없애고, AnyPublisher형태로 리턴한다.

### Error 핸들링

```swift
func fetchPost() -> AnyPublisher<[Post], Error> {
    
    let url = URL(string: "https://jsonplaceholder.typicode.com/postss")
        
    return URLSession.shared.dataTaskPublisher(for: url!)
        .tryMap({ data, response in
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.badServerResponse
            }
            
            return data
        })
        .decode(type: [Post].self, decoder: JSONDecoder())
        .retry(3)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
}
```

tryMap과, retry를 통해 Error Handling을 한다.

### Multi Request

```swift
func fetchWeather(city: String) -> AnyPublisher<WeatherData, Error> {
    
    let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=apikey")!
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: WeatherData.self, decoder: JSONDecoder())
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
}

Publishers.CombineLatest(fetchWeather(city: "london"), fetchWeather(city: "paris"))
    .sink { completion in
        switch completion {
        case .finished:
            print("done")
        case .failure(let error):
            print(error)
        }
    } receiveValue: { WeatherData1, WeatherData2 in
        print(WeatherData1)
        print("==========")
        print(WeatherData2)
    }.store(in: &cancellables)
```

CombineLatest를 통해 2개를 동시에 fetch가능

하지만 CombineLatest로만 다중 fetch를 하는게 아니니 상황에 맞는 operator를 사용하자.

### 예제

```swift
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

## Custom Operator

Publisher의 Extension을 활용하여 커스터마이징을 한다.

```swift
extension Publisher where Output == Int {
    
    func filterEvenNumbers() -> AnyPublisher<Int, Failure> {
        return self.filter { $0 % 2 == 0 }
            .eraseToAnyPublisher()
    }

    func filterNumberGreaterThan(_ value: Int) -> AnyPublisher<Int, Failure> {
        return self.filter { $0 > value }
            .eraseToAnyPublisher()
    }
    
}

let publisher = [1,2,3,4,5,6,7,8].publisher

let cancellable = publisher.filterEvenNumbers()
    .sink { value in
        print(value)
}

let _ = publisher
    .filterNumberGreaterThan(5)
    .sink { value in
        print(value)
    }

```

이부분도 딱히 언급할 부분은 없어서 패스...

### operator 조합

```swift
extension Publisher {
    
    func mapAndFilter<T>(_ transform: @escaping (Output) -> T, _ isIncluded: @escaping (T) -> Bool) -> AnyPublisher<T, Failure> {
        
        return self
            .map { transform($0) }
            .filter { isIncluded($0) }
            .eraseToAnyPublisher()
    }
}

let publisher = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].publisher

let _ = publisher
    .mapAndFilter({ $0 * 3 }) { value in
        return value % 2 == 0
    }.sink { value in
        print(value)
    }

let _ = publisher
    .mapAndFilter { value in
        value * 3
    } _: { value in
        value % 2 == 0
    }
    .sink { value in
        print(value)
    }
```

이번에는 Generic도 사용하면서 해당기능을 구현했는데 이부분은 그래도 짚고 넘어가면 좋을것같다. (둘은 동일하다.)

사실 저 함수는

```swift
let cancel = publisher
    .map { value in
        value * 3
    }
    .filter { value in
        value % 2 == 0
    }
    .eraseToAnyPublisher()
    .sink { value in
        print("result: \(value)")
    }
```

이 과정을 한번에 만든것이다.

즉, `mapAndFilter`는 두 연산을 한 번에 수행할 수 있도록 합성한 함수로, 코드의 간결성과 가독성을 높인다.

반면 개별 연산(map과 filter)은 더 유연하지만, 복잡한 연산이 많아지면 코드 가독성이 떨어질 수 있다.

**mapAndFilter의 Generic 매커니즘 이해**

1. transform: @escaping (Output) -> T
	- Output 타입을 받아서 T 타입으로 리턴하는 클로저이다.
	- 현재 publisher가 [1, 2, 3, ... 10]을 발행하므로 Output 타입은 Int이다.
	- Output은 배열 전체가 아니라, 배열의 각 요소를 의미한다.
	- 예: 1, 2, …, 10이 순차적으로 발행되므로, transform 클로저는 하나의 Int를 받아 새로운 T 타입을 리턴한다.
	- 따라서 transform의 역할은 발행된 각 Int를 원하는 형태로 변환하는 것이다.
	- 예: transform { $0 * 3 } -> 1, 2, … → 3, 6, …
2. _ isIncluded: @escaping (T) -> Bool
	- T 타입을 받아서 Bool을 리턴하는 클로저이다.
	- transform 이후 결과값 [3, 6, 9, ... 30]에서 T 타입은 여전히 Int이다.
	- isIncluded 클로저는 값이 조건(value % 2 == 0)을 만족하는지 판단하며, true인 값만 필터링된다.
	- 예: 6 -> true, 9 -> false, 12 -> true 등.
3. 반환 타입: AnyPublisher<T, Failure>
	- 반환 타입은 AnyPublisher<T, Failure>이며,
	- T는 Int이고, Failure는 원래 publisher의 에러 타입을 따른다.
	- 따라서 최종적으로 AnyPublisher<Int, Failure> 형태로 리턴된다.
