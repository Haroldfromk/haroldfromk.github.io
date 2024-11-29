---
title: Async/Await (7)
writer: Harold
date: 2024-11-28 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## Structured Concurrency ?

[WWDC21](https://developer.apple.com/kr/videos/play/wwdc2021/10134/){:target="_blank"}에 해당 관련 설명이 있다.

한번 봐두는것도 좋을듯

아래는 WWDC에 나온 리소스 링크
[Structured Concurrency](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md){:target="_blank"} 
[Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/){:target="_blank"} 
[async let](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0317-async-let.md){:target="_blank"} 

우선 Structured Concurrency는 아래와 같이 있다.
1. Async let
2. Task Group
3. Unstructured Tasks
4. Detached Tasks

## 시나리오: Credit Score를 사용하여 APR 계산

```swift
enum NetworkError: Error {
    case badUrl
    case decodingError
}

struct CreditScore: Decodable {
    let score: Int
}

struct Constants {
    struct Urls {
        static func equifax(userId: Int) -> URL? {
            return URL(string: "https://ember-sparkly-rule.glitch.me/equifax/credit-score/\(userId)")
        }
        
        static func experian(userId: Int) -> URL? {
            return URL(string: "https://ember-sparkly-rule.glitch.me/experian/credit-score/\(userId)")
        }
        
    }
}

func getAPR(userId: Int) async throws -> Double {
    
    guard let equifaxUrl = Constants.Urls.equifax(userId: userId),
          let experianUrl = Constants.Urls.experian(userId: userId) else {
              throw NetworkError.badUrl
          }

    let (equifaxData, _) = try await URLSession.shared.data(from: equifaxUrl)
    let (experianData, _) = try await URLSession.shared.data(from: experianUrl)
    
    return 0.0
    
}
```

코드는 다음과 같다.

### 1. Async-let Tasks

지금 시나리오대로 하게되면 equifaxData를 얻는 작업이 끝나야 experianData를 받는 작업이 실행된다.

즉 전에 언급한 `Serial Queue`가 되는것이다.

이런 비효율성을 방지하기 위해 

`async-let`을 사용하는 것이다.

```swift
async let (equifaxData, _) = URLSession.shared.data(from: equifaxUrl)
async let (experianData, _) = URLSession.shared.data(from: experianUrl)
```

이렇게 try/await를 지워주고 앞에 async를 붙여준다.

그러면 동시에 작업이 실행된다.

즉 기존에는 await가 있어 suspended point가 존재하였기에 작업이 끝나는동안 기다렸지만 지금은 그렇지 않다는 점이 가장 큰 특징이다.

그리고 해당 값은 Json 형식으로 가져오기에 디코딩 작업을 해보자

```swift
let equifaxCreditScore = try? JSONDecoder().decode(CreditScore.self, from: try await equifaxData)
let experianCreditScore = try? JSONDecoder().decode(CreditScore.self, from: try await experianData)
```

이때 특이점이라면 보통 우리는 `try await`를 보통 메소드 앞에 썼다.

지금은 equifaxData, experianData 앞에 사용을 했다.

간단하게 위의 두 값이 async로 선언이 되어있기에, 그것을 사용을 하는쪽에서도 그 변수앞에 try await를 명시해주는 것이다.

Decoding은 optional이므로 옵셔널 바인딩을 해주자. (이건 생략)

그리고 실행

```swift
async { // 지금은 async대신 Task 사용
    let apr = try await getAPR(userId: 1)
    print(apr) // 7.0
}
```

실제로 이것 역시도 파이널 프로젝트에서 튜터님이 구현하신 바가 있다.

```swift
// 가게 단일정보 로드
func loadStore(with name: String) {
    
    if let store = findStore(with: name) {
            let storeName = store.placeName
            Task {
                async let isScrapped = getScrap(for: storeName)
                async let ratings = getRatings(for: storeName)
                let presentable = await ShopView(
                    title: storeName,
                    address: store.roadAddressName,
                    rating: getAverageRating(ratings: ratings),
                    reviews: ratings.count,
                    latitude: Double(store.y) ?? 0.0,
                    longitude: Double(store.x) ?? 0.0,
                    isScrapped: isScrapped,
                    callNumber: store.phone == "" ? "가게 번호 없음" : store.phone
                )
                await MainActor.run {
                    state = .didLoadedStore(store: presentable)
                }
            }
        } else if let store = findJsonStore(with: name) {
            // JSON store
            Task {
                let presentable = ShopView(
                    title: store.storeName,
                    address: store.address,
                    rating: 0.0,
                    reviews: 0,
                    latitude: store.y,
                    longitude: store.x,
                    isScrapped: false,
                    callNumber: "" // JSON 데이터에서 전화번호를 제공하지 않는다고 가정
                )
                await MainActor.run {
                    state = .didLoadedStore(store: presentable)
                }
            }
        }
}

// 스크랩 정보 확인
func getScrap(for storeName: String) async -> Bool {
    await withCheckedContinuation { continuation in
        fetchScrapStatus(shopName: storeName) {
            continuation.resume(returning: $0)
        }
    }
}

// 리뷰정보 확인
func getRatings(for storeName: String) async -> [Float] {
    await withCheckedContinuation { continuation in
        fetchRatings(for: storeName) { ratings, error in
            guard let ratings, error == nil else { return }
            continuation.resume(returning: ratings)
        }
    }
}
```

여기가 지도부분인데 튜터님이 팀원분을 도와주시면서 이렇게 작성을 해주신것같은데, 이전에는 몰랐는데 이제서야 보이기 시작했다.

여기서도 보면 `async let` / `Continuation` 두개가 사용이 되었음을 알 수 있다.

Continuation은 [지난글](https://haroldfromk.github.io/posts/Async_await-(6)/){:target="_blank"}에서 조금 다뤘으니 참고 하면 될듯



위의 강의에선 사용하는 변수 앞에 `try await` 조금 더 정확하게 하자면 `await`를 사용했다. 하지만 위의 방식을 보면 `ShopView`앞에 await를 감싸주는 형태로 작성이 되었다.

```swift
let presentable = await ShopView(
    title: storeName,
    address: store.roadAddressName,
    rating: getAverageRating(ratings: ratings),
    reviews: ratings.count,
    latitude: Double(store.y) ?? 0.0,
    longitude: Double(store.x) ?? 0.0,
    isScrapped: isScrapped,
    callNumber: store.phone == "" ? "가게 번호 없음" : store.phone
)

let presentable = ShopView(
    title: storeName,
    address: store.roadAddressName,
    rating: getAverageRating(ratings: await ratings),
    reviews: await ratings.count,
    latitude: Double(store.y) ?? 0.0,
    longitude: Double(store.x) ?? 0.0,
    isScrapped: await isScrapped,
    callNumber: store.phone == "" ? "가게 번호 없음" : store.phone
)
```

위 아래 둘다 코드상 문제는 없다. 하지만 가독성으로 보았을때는 위의 사례가 더 좋다.

하지만 약간의 단점이라고 보면, 타인이 봤을때는 어디서 비동기 작업이 이루어지는지 모를수도 있을것같다.

### 2. Async-let in a Loop

이젠 반복문에서의 쓰임을 알아본다.

```swift
let ids = [1,2,3,4,5]

async {
    for id in ids {
       let apr = try await getAPR(userId: id)
        print(apr)
    }
}
```

간단하다.

실제로 프린트를 하면 id 순서대로 작동을 한다.

뭐 당연한거다.

getAPR 메서드 자체는 작업이 동시에 이루어진다 하더라도

for 안에서는 id 순서대로 Serial Queue로 진행이 되기 때문이다.

그렇다면 1,2,3,4,5 모두 getAPR처럼 같이 시작하게는 할 수 없나? 물론 방법은 있다.

그건 이후 서술.

### 3. Cancelling a Task

이제 조건을 하나 만들어 본다

```swift
if userId % 2 == 0 {
        throw NetworkError.invalidId
}
```

짝수일때 에러를 리턴한다.

그리고 실행을 해보자.

이전에 비해서 상당히 오래걸리고

```text
getAPR
6.0
```

이거 하나만 뜬다

왜냐면 짝수에서 에러를 리턴하기 때문

그렇다면 어떻게 이걸 체크할수있을까?

`Task.checkCancellation`을 사용하면 된다.

```swift
async {
    for id in ids {
        do {
            try Task.checkCancellation()
            let apr = try await getAPR(userId: id)
            print(apr)
        } catch {
            print(error)
        }
        
    }
}
```

에러 확인을 위해 do catch로 에러를 출력하자

do catch를 안하면 모른다. 그리고 결과도 1번의 결과만 나온다.

```text
getAPR
6.0
invalidId
getAPR
6.0
invalidId
getAPR
7.0
```

이제 이렇게 뜨는걸 알 수 있다.

아까와 차이라면 아까는 2번째 실행중 에러가났을때 아예 멈췄는데, 지금은 에러를 보여주면 1~5까지 전부 작업이 된걸 알 수 있다.

### 4. Group Tasks

![example4 drawio](https://github.com/user-attachments/assets/cbabdf25-1bd8-4fbc-b102-6f0e92df746a)

이런식으로 동시에 작업이 실행되게 할 것이다.

`withThrowingTaskGroup` 메서드를 사용할것이다. 이때 `of`에는 리턴타입이 들어간다.

`try await withThrowingTaskGroup(of: (Int, Double).self)`

그리고 코드를 작성하다보니

![CleanShot 2024-11-28 at 19 32 04](https://github.com/user-attachments/assets/e852e528-85eb-4f4e-b54b-91d53625b463)

`Group.async`에서 값을 처리하려고하니 위와 같은 경고가 뜬다.

이전에는 아예 에러가 났었다고한다.

이렇게 경고하는 이유는

Concurrency의 안전 문제로 인해 금지된다.

자세히 살펴보면.

원인: TaskGroup 내에서 **병렬 작업(concurrent task)**을 실행하면서 외부 변수를 직접 수정

에러의 이유:
1.	병렬 작업의 실행 순서 예측 불가:
    -	group.async로 실행된 각 작업은 비동기적으로 병렬 실행된다.
	-	어떤 작업이 먼저 완료될지 예측할 수 없기 때문에, 작업들이 동시에 userAPR 딕셔너리를 수정하면 데이터 충돌이 발생할 가능성이 있다.
2.	데이터 경합 방지:
	-	병렬 작업이 동일한 변수에 동시에 접근하고 수정할 경우, 값이 손상되거나 일관성을 잃는 문제가 생길 수 있다.
	-	Swift의 동시성 모델은 이러한 경합을 방지하기 위해 TaskGroup 내부에서 외부 변수의 직접 수정(access)과 변경(mutation)을 금지한다.
3.	Swift 동시성 제약:
	-	외부 변수(userAPR)는 group.async의 작업이 정의된 범위와 독립적이다.
	-	병렬 작업은 독립적으로 실행되므로, 외부 변수를 동기화 없이 수정할 수 없게 설계되었다

그래서 이렇게 하지않고 작업이 끝난 값을 리턴한다.

```swift
group.async {
        return (id, try await getAPR(userId: id))
}
```

그리고 작업이 끝난 그룹 부터 값을 수정하게 한다.

```swift
for try await (id, apr) in group {
    userAPR[id] = apr
}
```

완성된 코드

```swift
func getAPRForAllUsers(ids: [Int]) async throws -> [Int: Double] {
    
    var userAPR: [Int: Double] = [:]
    
    try await withThrowingTaskGroup(of: (Int, Double).self) { group in
        for id in ids {
            group.async {
                return (id, try await getAPR(userId: id))
            }
        }
        
        for try await (id, apr) in group {
            userAPR[id] = apr
        }
    }
    
    return userAPR
}

async {
    let userAPRs = try await getAPRForAllUsers(ids: ids)
    print(userAPRs)
}
```

![example4 drawio1](https://github.com/user-attachments/assets/5b71e9ff-9cf0-4286-977f-2a79039300a5)

작업은 동시에 시작이 되나, 모든 작업이 끝나야만 출력이 된다.

결과를 확인해보면 id 순서대로가 아닌 먼저 끝난 대로 이렇게 배열에 들어간다.

실행하보면 전부 순서가 다름을 알 수 있다.

```text
[5: 6.0, 2: 7.0, 3: 7.0, 1: 7.0, 4: 7.0] // 첫번째 실행
[4: 7.0, 3: 6.0, 1: 7.0, 5: 7.0, 2: 7.0] // 두번째 실행
[2: 7.0, 5: 7.0, 3: 7.0, 4: 6.0, 1: 7.0] // 세번째 실행
```

### 5. Unstructured Tasks

그냥 간단하게 말하면 독립적으로 실행하는 비동기 작업이다. 위의 사례들은 구조적으로 작동하면서 구조적 동시성을 따르는데, 이건 그냥 호출해서 독립적으로 작동하게 하는 작업이다.

최근에 만든 BookStore를 보면

```swift
.onSubmit(of: .search) {
    Task {
        await  apiViewModel.request(searchText: searchText)
    }
}
```

이런식으로 그냥 작동하게 하는것이다.

### 6. Detached Tasks

```swift
func fetchThumbnails() async -> [UIImage] {
    return [UIImage()]
}

func updateUI() async {
    
    // get thumbnails
    let thumbnails = await fetchThumbnails()
    
    Task.detached(priority: .background) {
        writeToCache(images: thumbnails)
    }
}

private func writeToCache(images: [UIImage]) {
    // write to cache
}


Task {
    await updateUI()
}
```

[참고](https://www.avanderlee.com/concurrency/detached-tasks/){:target="_blank"}하면 좋을듯.

이 부분은 다른글을 좀 참고해서 적어본다.

- Detached Task?
	-	Detached Task는 Swift 동시성 모델에서 부모 Task와 완전히 독립적으로 실행되는 상위 수준의 비동기 작업이다.
	-	**구조적 동시성(Structured Concurrency)** 의 맥락에서 벗어나 작동하며, 다음과 같은 특성을 갖는다:
	-	부모 Task로부터 우선순위(priority), Task Local 값, 캔슬 상태 등을 상속받지 않는다.
	-	독립적으로 실행되며, 부모-자식 관계 없이 작동한다.

```swift
Task.detached(priority: .background) {
    writeToCache(images: thumbnails)
}
```

바로 이부분

참고글에서는

```swift
Task.detached(priority: .background) {
    // Runs asynchronously
}
```

그러면

```swift
await asyncPrint("Operation one")
Task.detached(priority: .background) {
    // Runs asynchronously
    await self.asyncPrint("Operation two")
}
await asyncPrint("Operation three")

func asyncPrint(_ string: String) async {
    print(string)
}
```

이런코드에서 실행은 어떻게 될까

결과는

```text
Operation one
Operation three
Operation two
```

one과 three는 Serial Queue이므로 순서대로 실행이 된다.

하지만 Operation Two는 독립적이라 순서가 보장이 되지 않는다.

#### Detached Task의 위험성
- 부모 컨텍스트 상속 없음:
    - Detached Task는 부모 Task의 컨텍스트(우선순위, Task Local 값, 캔슬 상태 등)를 상속받지 않는다.
    - 이로 인해 독립적으로 설정해야 하며, 예상치 못한 동작을 초래할 수 있다.
- 캔슬 관리 필요:
    - Detached Task는 부모 Task가 캔슬되더라도 독립적으로 실행된다.
    - Detached Task를 수동으로 캔슬하려면 참조를 직접 관리해야 한다.
- 캡처된 self 사용:
    - Detached Task 내에서는 self를 명시적으로 캡처해야 한다. 이는 retain cycle과 같은 메모리 관리 문제를 야기할 수 있다.

```swift
let outerTask = Task {
    /// This one will cancel.
    await longRunningAsyncOperation()

    /// This detached task won't cancel.
    Task.detached(priority: .background) {
        /// And, therefore, this task won't cancel either.
        await self.longRunningAsyncOperation()
    }
}
outerTask.cancel()
```

![image](https://www.avanderlee.com/wp-content/uploads/2023/02/detached_tasks_explicit_self-1024x130.jpg)

#### 언제 사용할까?

- Detached Task는 최후의 수단으로 사용해야 한다. 대부분의 경우 TaskGroup이나 구조적 동시성 모델을 사용하는 것이 더 안전하고 효율적이다.
- 다음과 같은 경우 Detached Task를 고려할 수 있다:

1.	완전히 독립적인 작업:
    - 부모 Task와 연결되지 않고 독립적으로 실행해야 하는 작업.
	- ex: 백그라운드에서 캐시 데이터 정리.
    ```swift
    Task.detached(priority: .background) {
        await DirectoryCleaner.cleanup()
    }
    ```
2. 부모 컨텍스트 상속 불필요:
	- 부모 Task의 우선순위, Task Local 값 등을 상속받을 필요가 없는 작업.
	- ex: 백그라운드에서 진행되는 파일 업로드.

#### 결론

- Detached Task는 부모 Task와 완전히 독립적인 작업이 필요할 때 사용된다.
- 그러나 구조적 동시성을 따르지 않으므로, 가능한 경우 TaskGroup, async let과 같은 더 안전한 동시성 모델을 사용하는 것이 권장된다.
- 사용 시 캔슬 관리, 우선순위 설정, 메모리 관리에 주의해야 한다.