---
title: Async/Await (Fin)
writer: Harold
date: 2024-12-02 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

마지막 글이되겠다.

5시간 강의였는데 하나하나 정리하면서 넘어가다보니 꽤나 많은 시간이 걸렸다.

## MainActor

>MainActor란?
>>MainActor는 UI 업데이트와 관련된 코드를 안전하게 실행하기 위해 사용되는 Swift의 동시성 모델이다. 이를 사용하면 UI 상태 변경이 항상 메인 스레드에서 이루어지도록 보장한다.

우선 

```swift
// VM
func populateTodos() {
    
    do {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com/todos") else {
            throw NetworkError.badUrl
        }

        Webservice().getAllTodos(url: url) { result in
            switch result {
            case .success(let todos):
                self.todos = todos.map(TodoViewModel.init)
            case .failure(let error):
                print(error)
            }
        }
        
        
    } catch {
        print(error)
    }
    }


// Webservice
func getAllTodos(url: URL, completion: @escaping (Result<[Todo], NetworkError>) -> Void) {
    
    URLSession.shared.dataTask(with: url) { data, _, error in
        
        guard let data = data, error == nil else {
            
            completion(.failure(.badRequest))
            
            return
        }
        
        guard let todos = try? JSONDecoder().decode([Todo].self, from: data) else {
            
            completion(.failure(.decodingError))
            
            return
        }
        
        
        completion(.success(todos))
        
        
        
    }.resume()
    
}
```

![CleanShot 2024-12-02 at 16 18 46](https://github.com/user-attachments/assets/2912bcb3-42b8-47d9-9819-2695a3a71fd0)

이건 이전글에서도 언급했던 내용이긴 한데,
>UI 업데이트는 반드시 Main Thread에서 이루어져야 한다.

지금 UI업데이트와 관련이 있는 `@Published var todos: [TodoViewModel] = []`가 background thread에서 값을 변경하기 때문이다.

그렇다면 한가지 생길수 있는 의문

**변수가 UI업데이트와 무슨상관?**

```swift
var body: some View {
    List(todoListVM.todos, id: \.id) { todo in
        Text(todo.title)
    }
    
    .task {
        await todoListVM.populateTodos()
    }
}
```

List에서 적용하는 데이터가

![CleanShot 2024-12-02 at 16 21 16](https://github.com/user-attachments/assets/c8d6d298-b044-4b28-b41e-6126d442807e)

바로 VM의 todos이기 때문,

즉 List는 Todos의 데이터 변화에 따라 유동적으로 작동함.

뭐 지금도 충분히 사용하지만 UIKit을 사용할땐 해당문제를 DispatchQueue를 사용하여 해결하곤 했다.

```swift
// ex 1
func didUpdateWeather(_ weatherManager:WeatherManager, weather : WeatherModel) {
        DispatchQueue.main.async{
            self.temperatureLabel.text = weather.temperatureString
        }
    }
```

그래서 지금 부분은 이렇게 하면 문제없이 작동이 된다.
```swift
    Webservice().getAllTodos(url: url) { result in
        switch result {
        case .success(let todos):
            DispatchQueue.main.async {
                self.todos = todos.map(TodoViewModel.init)
            }
        case .failure(let error):
            print(error)
        }
    }
```

그리고 Combine을 사용했을때는 다음과 같이 하곤했다.

```swift
private func bind () {
        searchVM.transform(input: SearchVM.Input(searchPublisher: searchView.valuePublisher))
        searchVM.$document
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resultView.tableView.reloadData()
            }.store(in: &cancellables)
        
        recentVM.$wishDocument
            .print()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recentView.collectionView.reloadData()
            }.store(in: &cancellables)
    }
```

그리고 SwftUI를 할떈 `@MainActor`를 사용하곤 했다.

```swift
@MainActor
class TodoListViewModel: ObservableObject {
```

이렇게 하고 실행했지만?

![CleanShot 2024-12-02 at 16 18 46](https://github.com/user-attachments/assets/2912bcb3-42b8-47d9-9819-2695a3a71fd0)

아직도 발생하는 같은에러?

뭐가 문제일까??

![CleanShot 2024-12-02 at 16 44 02](https://github.com/user-attachments/assets/54bf96af-f035-4df4-a350-79b1c0b2bcb4)

분명 이렇게 단일(싱글톤) actor로, 그 **실행기(executor)** 가 Main Dispatch Queue와 동일하다라고 되어있는데,

이유가 뭘까?

@MainActor를 사용하면 해당 클래스 또는 함수가 Main Thread에서 실행되도록 보장하지만, 콜백 기반의 비동기 방식에서는 이 설정이 제대로 작동하지 않을 수 있다.
이는 콜백이 실행되는 스레드가 Main Thread가 아닌 경우에 발생한다.

현재 getAllTodos 함수는

```swift
func getAllTodos(url: URL, completion: @escaping (Result<[Todo], NetworkError>) -> Void) {
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            
            guard let data = data, error == nil else {
                
                    completion(.failure(.badRequest))
                
                return
            }
            
            guard let todos = try? JSONDecoder().decode([Todo].self, from: data) else {
                
                completion(.failure(.decodingError))
                
                return
            }
            
            
                completion(.success(todos))
            
            
            
        }.resume()
        
    }
```

이렇게 Callback 기반의 함수 성격을 띄고 있다.

### MainActor.run

이때 할수있는 방법 중 하나가

`MainActor.run`을 사용하는 것이다.

![CleanShot 2024-12-02 at 17 31 00](https://github.com/user-attachments/assets/37cc46f6-921c-44a3-944c-74a9ad24c4e0)

그랬더니 갑자기 뜨는 async?

run 함수를 보면 이렇게 async 가 있는걸 알 수 있다.

![CleanShot 2024-12-02 at 17 31 18](https://github.com/user-attachments/assets/0599e0d7-922a-4e01-8a21-538f8553ac4c)

즉 해당 함수는 Task가 필요.

```swift
Task {
    await MainActor.run {
        self.todos = todos.map(TodoViewModel.init)
    }
}
```

이렇게 run이 비동기 함수이므로 앞에 await를 붙여주자.

그렇게 하니 해결이 되었다.

### @MainActor

#### MainActor를 활용한 Completion Handler 격리와 비동기 UI 업데이트 패턴
```swift
func getAllTodos(url: URL, completion: @MainActor @escaping (Result<[Todo], NetworkError>) -> Void) {
```

이렇게 콜백하는 쪽에 `@MainActor`를 달수도있다.

![CleanShot 2024-12-02 at 17 36 25](https://github.com/user-attachments/assets/b430cea9-1c0f-4731-b36f-dde24815c084)

그랬더니 completion에서 다음과같이 뜬다.

이전에는 에러였지만 지금은 Warning이다.

이 에러는 Swift 6 언어 모드에서 발생하며, 이는 @MainActor로 선언된 비동기 작업이나 매개변수를 동기적이고 비격리된(nonisolated) 컨텍스트에서 호출하려고 할 때 발생하는 문제입니다.

이부분도 해결해보자.

```swift
Task {
    await completion(.failure(.badRequest))                    
}
```

이렇게 Completion을 비동기적으로 처리함으로써 isolated 즉 격리 해준다.

그리고 

```swift
Webservice().getAllTodos(url: url) { result in
    switch result {
    case .success(let todos):
        self.todos = todos.map(TodoViewModel.init)
    case .failure(let error):
        print(error)
    }
}
```

해당 내용을 그대로 사용해도 된다. 왜냐 이젠 콜백이 MainActor를 통해 Main Thread에서 작업이 되기 때문.

하지만 그렇게 좋은 방법은 아니다.

#### 새롭게 함수 만들기.

```swift
@MainActor
    func populateTodos() {
```

class했던 방식으로 함수에 적용해도 되지 않는다.

왜냐 이미 `Webservice`에서의 `getAllTodos`의 작업은. background thread에서 작업하기 때문이다.

그래서 해당 작업을 비동기적으로 처리할수있게 함수를 새롭게 만든다.

```swift
func getAllTodosAsync(url: URL) async throws -> [Todo] {
    
    let (data, _) = try await URLSession.shared.data(from: url)
    
    let todos = try? JSONDecoder().decode([Todo].self, from: data)
    return todos ?? []
    
}
```

그리고 

```swift
func populateTodos() async {
        do {
            guard let url = URL(string: "https://jsonplaceholder.typicode.com/todos") else {
                throw NetworkError.badUrl
            }
            let todos = try await Webservice().getAllTodosAsync(url: url)
            self.todos = todos.map(TodoViewModel.init)
        } catch {
            print(error)
        }
 }
```

이렇게 내부를 작성해준다.

이때 `getAllTodosAsync`가 비동기 작업이므로 `populateTodos` 여기에도 async를 달아주자.

실행하면 잘 된다.

강의에서는 해당 부분을 이렇게 설명하고있다.

todos 속성을 Background Thread에서 설정해도 에러가 발생하지 않는 이유는, 비동기 함수(async) 안에서 await를 사용하기 때문.

즉, await를 호출하면 현재 작업이 일시 중단되며, 작업이 완료된 후 **원래의 스레드(Main Thread)**로 복귀한다.
> await 호출 시 Swift는 작업을 일시적으로 중단하고, 비동기 작업이 완료되면 Main Thread로 복귀하여 나머지 작업을 이어간다.

그래서 언급을 하지않아도 되었던것.

##### Detached Task 라면?

그렇다면 Task를 독립적으로 작동하게 된다면?

무슨말이냐면 Task는 생성된 컨텍스트(예: MainActor)에 속하며 해당 컨텍스트의 규칙을 따른다. 반면 Task.detached는 컨텍스트에 독립적으로 동작하며, 기본적으로 백그라운드 스레드에서 작업이 수행이 되기 때문.

그럼 코드를 통해 실제로 백그라운드인지 확인을 해보자.

```swift
Task.detached { 
    print(Thread.isMainThread)
    print(Thread.current)
    let todos = try await Webservice().getAllTodosAsync(url: url)
    self.todos = todos.map(TodoViewModel.init)
}

// false
// <NSThread: 0x6000017515c0>{number = 6, name = (null)}
```

결과는 false 즉 main thread가 아니다.

그리고 name이 null이다 즉 없다는것이다.

위에서 언급했듯이 Task 라면

```swift
Task {
    let todos = try await Webservice().getAllTodosAsync(url: url)
    print(Thread.isMainThread)
    print(Thread.current)
    self.todos = todos.map(TodoViewModel.init)
}

// false
// <NSThread: 0x60000177be80>{number = 11, name = (null)}
```

같은 결과를 가져온다.

#### @MainActor 사용하기

이제 다시 class에 `@MainActor`를 달아주고

```swift
Task.detached {
    print(Thread.isMainThread)
    print(Thread.current)
    let todos = try await Webservice().getAllTodosAsync(url: url)
    print(Thread.isMainThread)
    print(Thread.current)
    self.todos = todos.map(TodoViewModel.init)
}
```
![CleanShot 2024-12-02 at 18 25 41](https://github.com/user-attachments/assets/6fedfb80-e39d-492a-bd82-9038e451ac37)

사용하려하니 에러가 뜬다.

사실 Task.detached를 썼다는것 자체가 Main Thread에서 작업하는게 아닌 background 에서 하기에 이걸 중첩해서 쓰는거 자체가 말이 안되는 경우지만 지금은 그냥 비교용이다.

무튼 해당 내용을 해결하려면 

```swift
Task.detached { // background thread
    print(Thread.isMainThread)
    print(Thread.current)
    let todos = try await Webservice().getAllTodosAsync(url: url)
    await MainActor.run {
        print(Thread.isMainThread)
        print(Thread.current)
        self.todos = todos.map(TodoViewModel.init)
    }
}
```

MainActor를 사용하자.

실행하면

```text
false
<NSThread: 0x600001773b80>{number = 10, name = (null)}
true
<_NSMainThread: 0x600001700040>{number = 1, name = main}
```

이녀석은 메인스레드이고 main은 이렇게 이름도 있다.

Task.detached를 빼면 원래 코드는 다음과 같을 것이다.

```swift
let todos = try await Webservice().getAllTodosAsync(url: url)
print(Thread.isMainThread)
print(Thread.current)
self.todos = todos.map(TodoViewModel.init)

// true
// <_NSMainThread: 0x60000170c000>{number = 1, name = main}
```

그리고 위에서 Task는 context를 따른다고 했기에 `@MainActor`를 사용하면 정말 메인에서 작업하는지도 확인해보자

```swift
Task {
    let todos = try await Webservice().getAllTodosAsync(url: url)
    print(Thread.isMainThread)
    print(Thread.current)
    self.todos = todos.map(TodoViewModel.init)
}
// true
// <_NSMainThread: 0x600001708000>{number = 1, name = main}
```

이렇게 확인이 된다.

그리고 실제로 MainActor.run은 이전에 프로젝트할때 튜터님이 작성하신걸 보면

```swift
func loadStore(with name: String) {
        
        if let store = findStore(with: name) {
                let storeName = store.placeName
                Task {
                    async let isScrapped = getScrap(for: storeName)
                    async let ratings = getRatings(for: storeName)
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
                    await MainActor.run {
                        state = .didLoadedStore(store: presentable)
                    }
                }
            } 
}
```

이렇게 있다.

이부분도 역시 UI 업데이트 관련이라 위와같이 작성이 되었음을 알 수 있다.

5시간 강의에서 상당히 많은 지식을 얻었다.

Concurrency 이녀석 공부하면 할수록 재미있는 녀석이다.
