---
title: Async/Await (5)
writer: Harold
date: 2024-11-28 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## Async/Await

### Apple이 제공하는 Async/Await 지원 API
Apple은 여러 API에서 이미 **`async`/`await`**을 지원한다:
- **URLSession**
- **HealthKit**
- **Notification**
- **Core Data**
- **MusicKit**

### 기존 작성된 코드들의 문제점

기존에 작성한 코드가 **completion handlers**나 **callbacks**에 의존하고 있다면, 이를 `async`/`await` 방식으로 변환하는 것이 필요하다.

```swift
func getPosts(completion: (Result<[Post], Never>) -> Void) {
    // get the posts

    // call the completion handler
}
```

>Callback 함수?
>>특정 작업이 완료된 후 실행되도록 정의된 함수

[callback](https://ios-course.cornellappdev.com/chapters/networking-i/callbacks){:target="_blank"}에 관한 글

>Completion Handler?
>> Completion Handler는 작업이 완료된 후 실행되도록 설계된 콜백 함수

[completion Handler](https://medium.com/@kalidoss.shanmugam/swift-completion-handlers-an-overview-bd6e62251f1d){:target="_blank"}에 관한 글

의미가 둘이 너무 같은것 같은데?

[StackOverFlow](https://stackoverflow.com/questions/56828416/difference-between-a-callback-and-competition-handler-in-swift){:target="_blank"} 참고.

차이점
1.	Callback
    - **작업 완료 후, 제어권(scope)**이 이전 호출 메서드로 돌아가는 경우 사용.
    - 결과를 반환한다기보다는 후속 작업 처리를 위해 호출 스코프를 연결한다.
    - 중요 포인트: 작업의 흐름을 조정하기 위해 사용.
2. Completion Handler
	- 작업 완료 후, **결과 값(Result)**을 호출자에게 반환하는 메서드에서 사용.
	- 작업의 **결과(success, failure)**를 처리하는 데 중점을 둔다.
	- 중요 포인트: 호출자에게 결과를 명시적으로 전달.

## Continuation ?

**Continuation**은 기존의 **Callback 기반 함수**를 `async`/`await` 함수로 노출하기 위한 도구이다.  
이것을 사용하면 기존 비동기 함수를 **더 간단한 방식으로 호출**할 수 있다.

```swift
func getPosts(completion: ([Post]) -> Void) {
    // Get the posts

    // call the completion handler
    // completion(...)
}

// ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓

func getPosts() async -> [Post] {
    // get all posts

    // return all posts
    return {Post(title: "Post 1", body: "Body 1"),
            Post(title: "Post 1", body: "Body 1")}
}

```

이때 포인트는 **Suspension Point 제공** 이다.
- **`await`** 키워드를 사용해 함수 실행을 일시 중지하고, 작업이 완료되면 실행을 재개.

```swift
func getPosts() async throws -> [Post] {

    return await withCheckedContinuation { continuation in
        getPosts { posts in
            continuation.resume(returning: posts)
        }
    }
}
```

여기선 withCheckedContinuation이 **Suspension Point** 이다.

Suspension Point에서 실행을 재개를 한다면,
`Continuation.resume(returning: Posts)`를 호출하여 실행을 재개한다.

resume을 호출하지 않으면 계속 Suspension Point에서 머물것이다.

[참고](https://www.kodeco.com/38838074-swift-concurrency-continuations-getting-started){:target="_blank"} 

## Continuation을 사용하여 Callback 기반 함수 변환하기

이젠 Playground에서 함수를 만들어서 한번 적용을 해보도록 한다.

```swift
enum NetworkError: Error {
    case badUrl
    case noData
    case decodingError
}

struct Post: Decodable {
    let title: String
}

func getPosts(completion: @escaping (Result<[Post], NetworkError>) -> Void) {
    
    guard let url = URL(string: "https://jsonplaceholder.typicode.com/posts") else {
        completion(.failure(.badUrl))
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, _, error in
        
        guard let data = data, error == nil else {
            completion(.failure(.noData))
            return
        }
        
        let posts = try? JSONDecoder().decode([Post].self, from: data)
        completion(.success(posts ?? []))
        
    }.resume()
    
}

getPosts { result in
    switch result {
        case .success(let posts):
            print(posts)
        case .failure(let error):
            print(error)
    }
}
```

그러면 출력이 된다.

이분은 크게 언급할 만한 내용은 없다.

```swift
func getPosts() async throws -> [Post] {
    
    return try await withCheckedThrowingContinuation { continuation in
        getPosts { result in
            switch result {
                case .success(let posts):
                    continuation.resume(returning: posts)
                case .failure(let error):
                    continuation.resume(throwing: error)
            }
        }
    }
    
}

async {
    do {
        let posts = try await getPosts()
        print(posts)
    } catch {
        print(error)
    }
}
```

만약 처음에 만든 getPost가 3rd party Library에 있는 함수라고 가정을 하고 해당 함수를 사용을 한다고 가정을 한다면 새로운 getPosts를 async await를 사용하여 변환한다.

이런 상황을 가정하는 이유는 aysync await가 나오기 이전에 만들어진 라이브러리들은 async await를 업데이트 하지 않았다면 사용할 수 없기에 우리가 해당 함수의 모듈만 가져와서 추가로 함수를 만들어서 그 모듈에 적용하면서 새로 만든 함수에 async await를 만들어서 적용을 해야하기 때문

![CleanShot 2024-11-28 at 14 59 17](https://github.com/user-attachments/assets/30ababb7-61ac-4fc2-bc72-93a574a095e2)

자세한건 [Docs](https://developer.apple.com/documentation/swift/withcheckedthrowingcontinuation(isolation:function:_:)){:target="_blank"}참조.

[Medium](https://asynclearn.medium.com/mastering-continuations-in-swift-a-comprehensive-guide-454b41a40681){:target="_blank"}글도 참고 해보자

[Youtube](https://www.youtube.com/watch?v=Tw_WLMIfEPQ){:target="_blank"}영상도 같이 적어둔다.

## Continuation이 왜 필요할까?

우선, async-await의 장점은 비동기 작업을 동기 코드처럼 작성할 수 있게 하여 가독성과 유지보수성을 크게 개선할 수 있다는 점이다.

Continuation이 필요한 이유는 async-await를 적용해야하는데, 기존 프로젝트나 외부 라이브러리에서 제공하는 Callback 기반 함수나 동기 함수를 수정 없이 재사용하기 위함이다.

실제로 이전에 파이널 프로젝트에서도 해당 내용을 사용한 흔적을 찾았다.

```swift
// ManageManager
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

당시 Firebase를 사용하다보니 Firebase의 함수를 그대로 사용할 수 밖에 없었다.

![CleanShot 2024-11-28 at 15 53 39](https://github.com/user-attachments/assets/9d161883-90eb-41a3-abac-a148bd0b6592)

하지만 Firebase의 addDocument Method는 Callback 함수였다.

그래서 addReport 함수를 구현할때 async 를 사용하기 위해서 `withCheckedThrowingContinuation`를 사용하여 callback 기반 코드를 async-await로 변환을 한다.

이제 완벽하게 이해가 되었다.