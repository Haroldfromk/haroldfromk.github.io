---
title: (Deep Dive) throws VS rethrows
writer: Harold
date: 2025-06-18 07:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]
published: false
toc: true
toc_sticky: true
---

(작성중...)

최근에 공부를 하다가 filter method에서 try를 사용하는것을 보고, 내가 알던 filter가 아니어서 조금 당혹스러웠는데,

오늘은 이것에 대해 좀 적어보려고 한다.

## throws vs rethrows

[Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/declarations/){:target="_blank"}를 기반으로 작성해본다.

### throws

```text
Throwing Functions and Methods

Functions and methods that can throw an error must be marked with the throws keyword. 
These functions and methods are known as throwing functions and throwing methods. 

Calls to a throwing function or method must be wrapped in a try or try! expression (that is, in the scope of a try or try! operator).
```
> throws를 사용하는 함수는 자체적으로 에러를 발생시킬 수 있는 함수이다.
> Swift에서 throws가 선언된 함수(또는 메서드)는 호출할 때 반드시 try 또는 try!, try?로 감싸야 한다.

#### 예시

```swift
class NetworkManager {
    
    static let shared = NetworkManager()
    let decoder = JSONDecoder()
    
    private init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func getRepo(atUrl urlString: String) async throws -> Repository {
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidRepoURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        do {
            return try decoder.decode(Repository.self, from: data)
        } catch {
            throw NetworkError.invalidRepoData
        }
    }
    
}

enum NetworkError: Error {
    case invalidRepoURL
    case invalidResponse
    case invalidRepoData
}

func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    Task {
        let nextUpdate = Date().addingTimeInterval(43200) // 12 hours in seconds
        
        do {
            let repo = try await NetworkManager.shared.getRepo(atUrl: RepoURL.swiftUIStudy)
            let entry = RepoEntry(date: .now, repo: repo)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate)) // update every 12hours
            completion(timeline)
        }   
        catch {
            print("❌ Error - \(error.localizedDescription)")
        }

    }
}
```

일부러 Network 코드를 가져왔다.

1. getRepo(atUrl:) 함수는 async throws로 선언되어 있음 → 비동기 처리 + 에러를 발생시킬 수 있는 함수라는 의미
2. 내부에서는 총 3가지 경우에 throw가 발생할 수 있음
    - URL이 잘못된 경우
    - 서버 응답이 실패했거나 응답 코드가 200이 아닌 경우
    - JSON 디코딩에 실패한 경우
3. 각 경우에 따라 명확한 에러 타입(NetworkError)을 던짐 → 호출하는 쪽에서 구체적인 원인을 알 수 있도록 설계




### rethrows

```text
Rethrowing Functions and Methods

A function or method can be declared with the rethrows keyword to indicate that it throws an error only if one of its function parameters throws an error.
These functions and methods are known as rethrowing functions and rethrowing methods.
Rethrowing functions and methods must have at least one throwing function parameter.

```
> rethrows는 함수 자신은 에러를 직접 던지지 않지만, 전달받은 클로저가 에러를 던질 경우에만 에러를 전달(rethrow) 한다.

#### 예시

```swift
func functionWithRethrow(_ operation: () throws -> Void) rethrows {
    try operation() // 자신은 throw하지 않음, 전달받은 함수가 throws라면 try 필요
}

func throwingClosure() throws {
    throw SomeError.example
}

do {
    try functionWithRethrow(throwingClosure)
} catch {
    print("Caught an error from closure")
}
```




## Filter

### 고차함수의 Filter
우선 우리가 아는 Filter의 는 여기.

다른걸 떠나서 우선 Filter의 기본 형태를 보자.

```swift
func filter(_ isIncluded: (Self.Element) throws -> Bool) rethrows -> Self
```



### Sequence의 Filter

다른 filter의 는 여기

```swift
func filter(_ predicate: Predicate<Self.Element>) throws -> [Self.Element]
```


### 참고
- [Filter Docs](https://developer.apple.com/documentation/swift/string/filter(_:)){:target="_blank"}
- [Sequence Filter Docs](https://developer.apple.com/documentation/swift/sequence/filter(_:)-8li9y){:target="_blank"}