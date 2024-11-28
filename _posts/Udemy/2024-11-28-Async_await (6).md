---
title: Async/Await (6)
writer: Harold
date: 2024-11-28 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

이제 공부한 내용을 새로운 프로젝트를 통해 적용해보도록 한다.

여기선 News App을 만들것이고
1. URLSessoin Async/Await
2. Continuation
3. DispatchQueue to MainActor

이렇게 3가지를 적용해본다.

현재 프로젝트에서

```swift
func fetchSources(url: URL?, completion: @escaping (Result<[NewsSource], NetworkError>) -> Void) {
    
    guard let url = url else {
        completion(.failure(.badUrl))
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, _, error in
        
        guard let data = data, error == nil else {
            completion(.failure(.invalidData))
            return
        }
        
        let newsSourceResponse = try? JSONDecoder().decode(NewsSourceResponse.self, from: data)
        completion(.success(newsSourceResponse?.sources ?? []))
        
    }.resume()
    
}

// viewmodel
func getSources() {
    
    Webservice().fetchSources(url: Secret.Urls.sources) { result in
        switch result {
            case .success(let newsSources):
                DispatchQueue.main.async {
                    self.newsSources = newsSources.map(NewsSourceViewModel.init)
                }
            case .failure(let error):
                print(error)
        }
    }
    
}
```

이렇게 콜백함수로 쓰이고 있다.

## Converting FetchSources to Async/Await

위의 함수를 async/await를 적용한 함수로 만들어본다.

```swift
func fetchSourcesAsync(url: URL?) async throws -> [NewsSource] {
        
    guard let url = url else {
        return []
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let newsSourceResponse = try? JSONDecoder().decode(NewsSourceResponse.self, from: data)
    
    return newsSourceResponse?.sources ?? []
}
```

뭐 크게 언급할 부분은 없어 보인다

return에서 옵셔널 바인딩을 해주었다. url이 잘못되었을 경우나 디코딩이 잘못되었을 경우 대비

이제 viewmodel에서도 바꿔보자

```swift
func getSources() async {    
    do {
        let newsSources = try await Webservice().fetchSourcesAsync(url: Secret.Urls.sources)
        DispatchQueue.main.async {
            self.newsSources = newsSources.map(NewsSourceViewModel.init)
        }
    } catch {
        print(error)
    }
}
```

여기도 크게 뭐 언급할건 없다.

## DispatchQueue → MainActor

```swift
func getNewsBy(sourceId: String) {
    
    Webservice().fetchNews(by: sourceId, url: Secret.Urls.topHeadlines(by: sourceId)) { result in
        switch result {
            case .success(let newsArticles):
                DispatchQueue.main.async {
                    self.newsArticles = newsArticles.map(NewsArticleViewModel.init)
                }
            case .failure(let error):
                print(error)
        }
    }
}
```

현재 이렇게 `DispatchQueue.main.async`를 사용하는데 `@MainActor`를 사용하여 코드를 조금 더 간략하게 할 수 있다.

```swift
@MainActor
class NewsArticleListViewModel: ObservableObject {
    
    @Published var newsArticles = [NewsArticleViewModel]()
    
    func getNewsBy(sourceId: String) {
        
        Webservice().fetchNews(by: sourceId, url: Secret.Urls.topHeadlines(by: sourceId)) { result in
            switch result {
            case .success(let newsArticles):
                self.newsArticles = newsArticles.map(NewsArticleViewModel.init)
            case .failure(let error):
                print(error)
            }
        }
    }   
}
```

보통 `@MainActor`를 사용할때는 함수에 적용하는게 아닌 해당 클래스에 적용한다.

## async를 지원하지않는 코드 블럭에서 사용

```swift
.navigationBarItems(trailing: Button(action: {
    async {
        await newsSourceListViewModel.getSources()
    }
}
```

refresh 버튼을 눌렀을때 재호출을 해야하는데 async를 지원하지 않는 코드 블럭이라면 

![CleanShot 2024-11-28 at 17 39 54](https://github.com/user-attachments/assets/4ce0c551-02e0-4491-b495-3e945e3631b0)

~~그냥 `async { code }`를 만들어 주면 된다.~~

```swift
.navigationBarItems(trailing: Button(action: {
    Task {
        await newsSourceListViewModel.getSources()
    }
```

지금은 async가 deprecated 되었으므로 **`Task { code }`** 를 사용하도록 하자

## Continuation 적용해보기

우선 사용할건 기존 함수인 fetchNews이다

```swift
func fetchNews(by sourceId: String, url: URL?, completion: @escaping (Result<[NewsArticle], NetworkError>) -> Void) {
    
    guard let url = url else {
        completion(.failure(.badUrl))
        return
    }
        
    URLSession.shared.dataTask(with: url) { data, _, error in
        
        guard let data = data, error == nil else {
            completion(.failure(.invalidData))
            return
        }
        
        let newsArticleResponse = try? JSONDecoder().decode(NewsArticleResponse.self, from: data)
        completion(.success(newsArticleResponse?.articles ?? []))
        
    }.resume()
    
}
```

이 함수를 외부 라이브러리에서 가져왔다고 가정하고 이제 우리가 사용할때는 async/await를 적용할건데, 위 함수는 callback 함수이므로 continuation을 사용해본다.

물론 위에처럼 내부 코드를 모두 안다면 새롭게 함수를 만들어서 async/await를 사용하면 되지만,

지금의 조건은 위의 fetchNews의 자세한 코드는 모른다고 가정하고 적용한다.

![CleanShot 2024-11-28 at 17 32 19](https://github.com/user-attachments/assets/f99f03f3-89cc-4c0b-837c-01fa152efcdd)

우선 fetchNews에 대한 설명을 먼저 확인해본다.

이걸 통해 우리는 어떤 파라미터가 필요하고 리턴타입은 무엇인지를 알 수 있게 된다.

**파라미터**
1. `sourceId: String`
2. `url: URL?`

**리턴**
1. `[NewsArticle]`


코드 작성

1. `func fetchNewsAsync(sourceId: String, url: URL?) async throws -> [NewsArticle]`
2. `withCheckedThrowingContinuation` 사용 (왜냐 1에서 throws로 던지기 때문)
    - `withCheckedThrowingContinuation` 사용함으로써 에러를 던지는게 직관적이다.
3. `fetchNews` 호출
4. `switch~case` 를 통해 contiuation을 사용

결과

```swift
func fetchNewsAsync(sourceId: String, url: URL?) async throws -> [NewsArticle] {
    try await withCheckedThrowingContinuation { continuation in
        fetchNews(by: sourceId, url: url) { result in
            switch result {
                case .success(let newsArticles):
                    continuation.resume(returning: newsArticles)
                case .failure(let error):
                    continuation.resume(throwing: error)
            }
        }
    }
}
```

그리고 해당 함수를 호출하는 getNewsBy도 수정

```swift
// before
func getNewsBy(sourceId: String) {
    
    Webservice().fetchNews(by: sourceId, url: Secret.Urls.topHeadlines(by: sourceId)) { result in
        switch result {
        case .success(let newsArticles):
            self.newsArticles = newsArticles.map(NewsArticleViewModel.init)
        case .failure(let error):
            print(error)
        }
    }
} 

// after
func getNewsBy(sourceId: String) async {
    
    do {
        let newsArticles = try await Webservice().fetchNewsAsync(sourceId: sourceId, url: Secret.Urls.topHeadlines(by: sourceId))
        self.newsArticles = newsArticles.map(NewsArticleViewModel.init)
    } catch {
        print(error)
    }
}
```

기존에는 completion handler를 통해서 만들었기에 switch result를 통해서 또 했어야했지만 바꾸고 난뒤에는 코드가 더 간략해지고 가독성이 좋아졌다.

실제로 파이널 프로젝트를 할때도 사용이 되었다. 이때는 사실 어떻게 쓰이는지 제대로 알지 못했다.

```swift
func addReport(data: [String: Any]) async throws {
    return try await withCheckedThrowingContinuation { continuation in
        reportCollection.addDocument(data: data) { error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: ())
            }
        }
    }
}
```

여기서도 addDocument는 Firebase에서 가져온 하나의 함수이다.

![CleanShot 2024-11-28 at 15 53 39](https://github.com/user-attachments/assets/9d161883-90eb-41a3-abac-a148bd0b6592)

우리는 addDocument에 대해선 정확히 모르지만 적어도 파라미터로 뭘 받고 어떻게 핸들링이 되는지는 유추 할 수 있다.

그래서 이걸 사용하면서 우리가 함수를 만들기 위해 사용하는데 async await를 사용하여 코드를 간결하기 위해서 Continuation을 사용하는것.

여기선 error를 넘기고 에러가 없을때는 ()로 Void만 넘기게 된다.

이제서야 이게 보이기 시작한다.