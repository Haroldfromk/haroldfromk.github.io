---
title: Screens vs Views / Reusable Event Pattern
writer: Harold
date: 2025-8-22 11:00:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## SwiftUI 프로젝트 구조화: Screen과 View의 분리

SwiftUI의 모든 요소는 View 프로토콜을 따르지만, 역할과 재사용성에 따라 Screen과 View로 구분하여 관리하는 설계 전략을 분석한다.

### 1. Screen과 View의 정의 및 차이
Flutter의 Widget 네이밍 컨벤션에서 아이디어를 얻은 이 방식은 앱의 규모가 커질 때 유지보수성을 극대화한다.

[참고글 (flutter docs)](https://docs.flutter.dev/cookbook/navigation/passing-data){:target="_blank"}

<img width="80%" height="80%" alt="Image" src="https://github.com/user-attachments/assets/bf4fd8f7-2e78-45f6-86a4-d31734139b92" />

| 구분 | Screen (스크린) | View (뷰) |
| :--- | :--- | :--- |
| **재사용성** | 재사용을 목적으로 하지 않음 (단일 화면 단위) | 높은 재사용성이 핵심 (컴포넌트 단위) |
| **주요 역할** | 전체적인 레이아웃 구성 및 데이터 흐름 관리 | 상위로부터 전달받은 데이터를 화면에 렌더링 |
| **데이터 처리** | HTTP Client 호출 등 데이터 다운로드 수행 | 직접적인 데이터 요청을 하지 않음 |
| **패턴 역할** | 데이터를 관리하는 컨테이너(Container) 역할 | 데이터를 표현하는 프리젠테이션(Presentation) 역할 |
| **네이밍 예시** | HomeScreen, OrderListScreen | StockListView, OrderCellView |

- 스크린과 뷰에 대해서 간단하게 비유를 해본다면, 집과 방이라고 생각 해볼 수도 있을것같다. 집은 Screen이고 그 안에 있는 방이 View 인것이다. 집은 전체적으로 전기나, 난방 등 필요한걸 관리를 하지만, 방의 개념에선 우리가 방의 내부를 개인에 맞게 바꿔주면서 재사용을 하는 그런 느낌이랄까?
    - **집(Screen)**: 전기, 난방, 수도 등 집 전체에서 필요한 인프라를 외부(서버/네트워크)로부터 끌어와 관리한다. 집 자체를 통째로 어디론가 옮겨서 재사용하는 경우는 뭐 없다고 볼 수 있다.
    - **방(View)**: 집에서 끌어온 자원을 받아 거실, 침실, 공부방 등으로 용도에 맞게 꾸며 사용한다. 방의 구조나 가구 배치(UI)는 다른 집에서도 그대로 가져가 쓸 수 있는 재사용성이 높은 단위이다.

### 2. 컨테이너 패턴 (Container Pattern)의 적용
스크린은 데이터를 가져오고, 뷰는 그 데이터를 표현만 하는 방식을 통해 로직과 UI를 분리한다.

```swift
struct CoffeeOrderListScreen: View {
    
    @Environment(\.httpClient) private var httpClient
    
    @State private var isPresented: Bool = false
    @State private var orders: [CoffeeOrder] = []
    
    private func loadOrders() async {
        
        do {
            let resource = Resource(url: APIs.orders.url, modelType: [CoffeeOrder].self)
            orders = try await httpClient.load(resource)
        } catch {
            print(error)
        }
        
    }

    var body: some View {
        CoffeeOrderListView(orders: orders)
    }
}
```

- **데이터 처리**: `CoffeeOrderListScreen`에서 서버로부터 주문 내역을 다운로드한다.
- **데이터 전달**: 다운로드된 주문 내역(`orders`)을 하위 뷰인 `OrderListView`나 리스트 셀에 전달한다.
- **이점**: 뷰가 데이터를 직접 내려받지 않으므로, 동일한 UI를 다른 데이터로 채워 재사용하기가 매우 쉬워진다.

### 3. 코드 가독성과 추적(Tracking) 최적화
스크린에서 하위 뷰로 로직을 추출할 때는 필요한 데이터만 최소한으로 넘기는 것이 중요하다.

- **리팩토링**: 스크린의 코드가 너무 길어지면 리스트나 셀 단위를 별도의 뷰로 추출한다.
- **성능 이점**: 하위 뷰에 전체 객체가 아닌 필요한 데이터(`orders`)만 전달하면, SwiftUI는 해당 데이터의 변화만 정밀하게 감지(Diffing)하여 렌더링 성능을 최적화한다.

### 4. 프로젝트 폴더 구조화
관리의 편의를 위해 Xcode 프로젝트 내에서도 그룹(Folder)을 분리하여 관리하는 것이 권장된다.

- **Screens 그룹**: `LoginScreen`, `ProfileScreen`, `SettingsScreen` 등 화면 단위 파일 보관.
- **Views 그룹**: `CommonButton`, `UserAvatarView`, `ProductRow` 등 재사용 가능한 컴포넌트 보관.

### 번외: UIKit의 TableView 아키텍처를 Screen과 View의 관점에서 분석
과거 UIKit의 UITableView 구조는 Screen(데이터 관리자)과 View(재사용 컴포넌트) 패턴을 이해하는 데 있어 아주 훌륭한 비교 대상이다.

- **Screen의 역할: UITableView (Controller & DataSource)**
    - 데이터 관리: 서버에서 데이터를 받아오거나 배열(Array)을 관리하는 주체는 컨트롤러이다. 이는 Screen이 데이터를 소유하고 관리한다는 개념과 일치한다.
    - 분배자 역할: cellForRowAt 메서드에서 "몇 번째 행(IndexPath)에 어떤 데이터(Model)를 넣을지" 결정한다. 즉, Screen이 자원을 각 방(Cell)에 배급하는 역할을 한다.

- **View의 역할: UITableViewCell**
    - 수동적 렌더링: Cell은 자신이 몇 번째 행에 있는지, 전체 데이터가 무엇인지 모른다. 단지 던져진 데이터(Text, Image)를 받아 화면에 그릴 뿐이다.
    - 재사용 대기열(Reuse Queue): UIKit은 메모리 효율을 위해 화면 밖으로 나간 Cell을 파괴하지 않고 '재사용 큐'에 넣었다가 다시 꺼내 쓴다. 이것이 View의 재사용성(Reusability)을 극대화한 형태이다.

- **prepareForReuse와 데이터 꼬임 현상의 원인**
    - 상태의 잔존: 토글 스위치 꼬임 현상은 재사용되는 View(Cell)가 '클래스(Reference Type)'이기 때문에 발생한다. 누군가 1번 방(Cell)의 스위치를 켜고 나갔는데, 100번 손님이 그 방에 들어올 때 청소(초기화)를 안 하면 스위치가 켜진 채로 보인다.
    - prepareForReuse의 본질: 이것은 Screen(Controller)이 View(Cell)를 재사용하기 전에 수행하는 '강제 초기화(Reset)' 과정이다. SwiftUI에서는 View가 구조체(Value Type)라서 매번 새로 생성되므로 이 과정이 불필요하지만, UIKit에서는 이 수동 관리가 필수적이었다.

### 핵심 요약
SwiftUI에서 Screen과 View의 구분은 기술적인 제약이 아닌 관리를 위한 설계 전략이다. Screen은 데이터를 가져오는 컨테이너 역할을 하며 재사용하지 않고, View는 전달받은 데이터를 표현하는 재사용 가능한 컴포넌트로 설계한다. 과거 UIKit의 TableView 구조가 Screen과 View 패턴의 원형이며, prepareForReuse와 같은 수동 초기화의 번거로움을 SwiftUI의 구조체 기반 뷰 생성 방식이 해결해 주었다는 점을 기억하면 이해가 쉽다.

---

## View의 재사용성을 높이는 이벤트 처리 패턴

재사용 가능한 컴포넌트인 MovieCellView를 예로 들어, 내부 로직을 외부로 위임하고 관리하기 편한 구조로 리팩토링하는 과정을 분석한다.

### 1. 초기 구조와 문제점: 강한 결합
처음에는 MovieCellView 내부에서 직접 @Environment를 통해 MovieStore에 접근하여 기능을 수행한다.

```swift
struct MovieCellView: View {
    
    @Environment(MovieStore.self) private var movieStore

    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(movie.name)
                .font(.headline)
            Text(movie.description)
            HStack {
                Image(systemName: "star")
                    .onTapGesture {
                        movieEvent(.markFavorite(movie))
                    }
                Image(systemName: "trash")
                    .onTapGesture {
                        movieEvent(.delete(movie))
                    }
            }
        }
    }
}
```

- 문제점: 이렇게 하면 MovieCellView는 무조건 MovieStore가 있어야만 동작하며, 기능이 고정되어 다른 곳에서 재사용하기 어렵다.
- 비유: 집(Screen)을 꾸미는데 가구(데이터)뿐만 아니라 전력 공급 장치(Store)까지 방(View) 바닥에 고정해버린 꼴이라, 이 방을 다른 집으로 옮기기가 매우 힘들어진다.

### 2. 클로저(Closure)를 이용한 이벤트 위임
View 내부에서 직접 기능을 수행하는 대신, 외부에서 행동을 정의할 수 있도록 클로저를 노출한다.

```swift
struct MovieCellView: View {
    
    let movie: Movie
    let onMarkFavorite: (Movie) -> Void
    let onDelete: (Movie) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(movie.name)
                .font(.headline)
            Text(movie.description)
            HStack {
                Image(systemName: "star")
                    .onTapGesture {
                        onMarkFavorite(movie)
                    
                    }
                Image(systemName: "trash")
                    .onTapGesture {
                        onDelete(movie)
                    }
            }
        }
    }
}

@Observable
class MovieStore {
    
    func markMovieFavorite(_ movie: Movie) {
        
    }
    
    func deleteMovie(_ movie: Movie) {
        
    }
}

struct ContentView: View {
    
    @Environment(MovieStore.self) private var movieStore
    
    // 생략

    var body: some View {
        List(movies) { movie in
            VStack(alignment: .leading, spacing: 10) {
                // 1. Closure 사용
                MovieCellView(movie, onMarkFavorite: { movie in
                    movieStore.markMovieFavorite(movie)
                }, onDelete: { movie in 
                    movieStore.deleteMovie(movie)
                })
                // 2. movieStore의 Function 사용
                MovieCellView(movie: movie, onMarkFavorite: movieStore.markMovieFavorite, onDelete: movieStore.deleteMovie)
            }
        }
    }
}
```

- 방법: onMarkFavorite, onDelete와 같은 클로저 프로퍼티를 MovieCellView에 선언한다.
- 효과: MovieCellView는 클릭되었다는 사실만 알리고, 실제 데이터 처리는 부모(Screen)가 담당하게 된다. 이를 통해 View는 순수하게 화면을 보여주는 역할에만 집중한다.



### 3. 이벤트 그룹화 (Event Grouping using Enum)
전달해야 할 클로저가 많아질수록 View의 생성자가 비대해지는데, 이때 Enum을 활용하여 이벤트를 하나로 묶을 수 있다.

```swift
struct MovieCellView: View {
    
    let movie: Movie
    let movieEvent: (MovieCellEvents) -> Void
    
    enum MovieCellEvents {
        case markFavorite(Movie)
        case delete(Movie)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(movie.name)
                .font(.headline)
            Text(movie.description)
            HStack {
                Image(systemName: "star")
                    .onTapGesture {
                        movieEvent(.markFavorite(movie))
                    }
                Image(systemName: "trash")
                    .onTapGesture {
                        movieEvent(.delete(movie))
                    }
            }
        }
    }
}

struct ContentView: View {
    
    @Environment(MovieStore.self) private var movieStore
    
    var body: some View {
        List(movies) { movie in
            VStack(alignment: .leading, spacing: 10) {
                MovieCellView(movie: movie) { movieCellEvents in
                    switch movieCellEvents {
                        case .markFavorite(let movie):
                            movieStore.markMovieFavorite(movie)
                        case .delete(let movie):
                            movieStore.deleteMovie(movie)
                    }
                }
            }
        }
    }
}
```

- 구조: MovieCellEvent라는 열거형을 만들고 각 케이스에 필요한 데이터를 연관값으로 담는다.
- 이점: 
    - 간결함: 여러 개의 클로저 인자를 단 하나의 이벤트 핸들러로 줄일 수 있다.
    - 가독성: 어떤 이벤트들이 발생하는지 Enum 정의만 봐도 한눈에 파악된다.
    - 확장성: 새로운 기능이 추가되어도 생성자 파라미터를 수정하는 대신 Enum 케이스만 추가하면 된다.

### 4. 구현 방식 비교

| 방식 | 특징 | 권장 상황 |
| :--- | :--- | :--- |
| 개별 클로저 | 코드가 직관적이고 호출 시점에 바로 로직 연결 가능 | 이벤트가 1~3개로 적을 때 |
| Enum 그룹화 | 생성자가 깔끔해지고 대규모 이벤트 관리에 용이함 | 이벤트가 4개 이상일 때 |

### 핵심 요약
재사용 가능한 View를 만들 때는 내부에서 특정 Store에 직접 접근하는 것을 피해야 한다. 클로저나 Enum을 활용해 이벤트를 외부로 위임함으로써 View와 로직의 결합도를 낮출 수 있다. 특히 관리해야 할 액션이 많아질 경우 Enum으로 이벤트를 그룹화하는 패턴을 사용하면 코드의 가독성과 유지보수성을 크게 향상시킬 수 있다.