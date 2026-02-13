---
title: Async/Await (4)
writer: Harold
date: 2024-11-28 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## MVVM 디자인 패턴 적용하기

[Async_Await (2)](https://haroldfromk.github.io/posts/Async_await-(2)/){:target="_blank"}에서 했던 프로젝트를 이어서 진행한다.

구현할 매커니즘에 대해 간략하게 표현하면 다음과 같다

![example31 drawio](https://github.com/user-attachments/assets/f77abd16-7c52-4365-9e35-6d56f5d437e3)

### Webservice 구현

Webservice 클래스 파일을 하나 만들어 준다.

그리고 기존에 구현했었던 getDate 함수를 옮겨준다.

```swift
class Webservice {
    
    private func getDate() async throws -> CurrentDate? {
        
        guard let url = URL(string: "https://ember-sparkly-rule.glitch.me/current-date") else {
            fatalError("URL is incorrect")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(CurrentDate.self, from: data)
    }
}
```

### ViewModel 구현

이제 Webservice를 호출할 ViewModel을 구현해본다

또 새롭게 파일을 하나 만들어주고 이름은 CurrentDateListViewModel로 한다

```swift
@MainActor
class CurrentDateListViewModel: ObservableObject {
    
    @Published var currentDates: [CurrentDateViewModel] = []
    
    func populateDates() async throws {
        do {
            let currentDate = try await Webservice().getDate()
            if let currentDate = currentDate {
                let currentDateViewModel = CurrentDateViewModel(currentDate: currentDate)
                    self.currentDates.append(currentDateViewModel)
            }
        } catch {
            print(error)
        }
    }
    
}

struct CurrentDateViewModel {
    let currentDate: CurrentDate
    
    var id: UUID {
        currentDate.id
    }
    
    var date: String {
        currentDate.date
    }
}
```

1. **ObservableObject로 선언**  
   - `@Published` 프로퍼티를 통해 View와 데이터를 연결.  
   - 화면에 표시될 각 날짜는 **`CurrentDateViewModel`** 구조체로 표현.

2. **`CurrentDateViewModel`**  
   - Model(`CurrentDate`)을 기반으로 생성. 

3. **배열 업데이트**  
   - UI 업데이트를 위해 **메인 스레드**에서 배열 작업 수행.
   - **iOS 15** 이상에서는 `@MainActor`를 ViewModel에 선언해 모든 작업이 메인 스레드에서 실행되도록 설정.
      - `DispatchQueue.main.async`를 사용할 필요가 없어졌다.

### ContentView에서 ViewModel 사용하기

1. **StateObject 생성**  
   - `CurrentDateListViewModel`의 인스턴스를 **`@StateObject`**로 생성하여 ContentView와 연결한다.

```swift
struct ContentView: View {
    
    @StateObject private var currentDateListVM = CurrentDateListViewModel()
        
    var body: some View {
        NavigationView {
            List(currentDateListVM.currentDates) { currentDate in
                Text(currentDate.date)
            }.listStyle(.plain)
            
                .navigationTitle("Dates")
                .navigationBarItems(trailing: Button(action: {
                    // button action
                    async {
                        await currentDateListVM.populateDates()
                    }
                }, label: {
                    Image(systemName: "arrow.clockwise.circle")
                }))
                .task {
                    await currentDateListVM.populateDates()
                }
        }
    }
}
```

이렇게 ViewModel로 적용을 하다보면

![CleanShot 2024-11-28 at 13 38 48](https://github.com/user-attachments/assets/e43b54e2-366e-4a8d-8a5f-e2b24d60571e)

List에서 위와 같은 에러가 발생한다.

해당 에러는 **SwiftUI의 List**를 사용할 때 발생하며, List의 항목들이 고유하게 식별 가능하도록 **Identifiable 프로토콜을 준수해야 한다**는 요구 사항 때문이다.

이때 두가지 방법이 존재한다.

1. `struct CurrentDateViewModel`에 Identifiable 프로토콜 채택

```swift
struct CurrentDateViewModel: Identifiable {
    private let currentDate: CurrentDate

    init(currentDate: CurrentDate) {
        self.currentDate = currentDate
    }

    var id: UUID {
        currentDate.id
    }

    var date: String {
        currentDate.date
    }
}
```

이런식으로 한다.

2. List에서 식별자를 설정

이렇게 id를 적으면

아래와 같이 뜨는데,
![CleanShot 2024-11-28 at 13 43 31](https://github.com/user-attachments/assets/5f2f26c8-d0f7-47e0-a71b-fce16ef3f60e)

보통은 식별을 id로 하기에 id를 해주자.

그리고 이런 KeyPath를 사용할때는 `\` Backslash를 사용한다.
![CleanShot 2024-11-28 at 13 43 01](https://github.com/user-attachments/assets/8d21a120-bc41-4ebe-b2d7-3e095714e701)

그리고 id를 해주면 된다.

그래서 위에 `struct CurrentDateViewModel`에서도 id를 만들어 두는 것.

**참고하면 좋을 링크(Backslash)**
1. [Youtube](https://www.youtube.com/watch?v=YY7SlOklZzk){:target="_blank"}  
2. [StackOverFlow](https://stackoverflow.com/questions/56489766/what-is-the-backslash-used-for-in-swiftui){:target="_blank"} 


#### Identifiable Protocol?

[Docs](https://developer.apple.com/documentation/swift/identifiable){:target="_blank"}를 보면 설명이 있다.

여기서 나는 이게 포인트라고 생각한다. 
-	Guaranteed always unique, like UUIDs.

---

다시 돌아와서 그다음엔 try가 필요하다는 에러가 나와서 try를 적어준다.

그리고 task있는곳에도 똑같이 try를 적고나니 

![CleanShot 2024-11-28 at 13 56 37](https://github.com/user-attachments/assets/08ce1cd4-135e-4dc9-a81d-18fac79e65b3)

이런에러가 발생

throws가 선언된 비동기 함수를 호출하는 클로저가 throws를 지원하지 않는 함수 타입에 전달되었을 때 발생한다. 

```swift
func populateDates() async throws {
        do {
            생략
         } catch {
             print(error)
         }
        
}
```

이미 위에서 throws를 적었는데도 불구하고 do ~ catch 를 통해 에러를 해결하기 때문에 발생

throws를 지워주자. 그래도 여전히 에러가 발생한다.

이젠 throw가 없으므로 에러를 호출한쪽으로 던지지 않으니 try도 다시 지워준다.

실행화면은 똑같으니 올리지 않는다.
