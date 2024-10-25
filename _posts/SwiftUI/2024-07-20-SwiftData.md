---
title: SwiftData
writer: Harold
date: 2024-7-20 07:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

EmptyFile을 하나 만들어주고 이름을 Place.swift로 해주었다.

그리고 3가지를 import해준다.

```swift
import SwiftData
import SwiftUI
import MapKit
```

### 1. Data Modeling

새로운 파일을 만들어서 모델링을 해도 되지만 여기서는 하나의 파일에 하는것같다.

한가지 새로운점이라면 `@Model`을 사용했다는 점이다.

```swift
@Model
class Place {
    #Unique<Place>([\.name, \.latitude, \.longitude])
    
    @Attribute(.unique) var name: String
    var latitude: Double
    var longitude: Double
    var intersted: Bool
        
    init(name: String, latitude: Double, longitude: Double, intersted: Bool) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.intersted = intersted
    }
}
```

UIKit를 사용하면서 했던 데이터 모델링과는 다른 양상을 보여준다.

1. @Model
- @Model은 SwiftData에서 데이터 모델을 정의하는 데 사용되는 속성 래퍼이다. 이를 사용하면 클래스가 데이터 모델로 인식되도록 지정한다. SwiftData는 이러한 데이터 모델을 기반으로 데이터베이스에서 데이터를 저장하고 관리한다.
- 주요 특징
    - @Model이 적용된 클래스는 SwiftData의 데이터 모델로 인식된다.
	- @Model로 선언된 클래스의 인스턴스는 SwiftData의 데이터베이스에서 관리된다.
	- @Model은 자동으로 클래스의 속성을 추적하고, 데이터의 변경 사항을 감지하여 SwiftUI와 같은 프레임워크와 통합할 수 있다.

2. #Unique
- #Unique는 SwiftData에서 사용되는 매크로로, 데이터 모델의 고유(유니크) 제약 조건을 설정하는 데 사용된다. 이 매크로는 특정 속성 조합이 데이터베이스에서 고유해야 함을 보장한다.
- 사용법
	- #Unique<Place>([\.name, \.latitude, \.longitude])는 Place 모델의 name, latitude, longitude 조합이 고유해야 함을 나타낸다.
	- 이는 데이터베이스 수준에서 중복 항목을 방지하고, 특정 조건이 만족될 때만 데이터가 삽입되거나 업데이트되도록 한다.
- 주요 특징
	- 데이터의 무결성을 보장한다.
	- 중복된 데이터 입력을 방지한다.
	- 데이터베이스에서 Unique Index로 사용될 수 있다.

3. @Attribute
- @Attribute는 SwiftData에서 모델 속성의 특성을 정의하는 데 사용되는 속성 래퍼이다. @Attribute(.unique)는 해당 속성이 고유해야 한다는 의미이다. SwiftData는 이를 사용하여 데이터베이스 내에서 속성의 유일성을 보장한다.
- 사용법
	- @Attribute(.unique) var name: String는 name 속성이 데이터베이스에서 고유해야 한다는 것을 나타낸다.
	- 이 속성에 같은 값이 존재하는 경우 데이터베이스에 저장할 수 없도록 제약 조건을 설정한다.
- 주요 특징
	- 속성에 제약 조건을 부여하여 데이터베이스 내에서 데이터 무결성을 보장한다.
	- 다양한 제약 조건을 설정할 수 있으며, .unique는 그중 하나이다.

---

즉 여기서는 

1. `@Model`: Place 클래스가 SwiftData의 데이터 모델로 인식되도록 지정한다. 이를 통해 이 클래스의 인스턴스는 SwiftData에서 관리되는 데이터베이스 엔티티가 된다.

2. `#Unique<Place>([\.name, \.latitude, \.longitude])`: Place 모델의 name, latitude, longitude 속성 조합이 고유해야 함을 정의한다. 이를 통해 동일한 장소(같은 이름과 위치 조합)가 중복으로 저장되지 않도록 보장한다.

3. `@Attribute(.unique) var name: String`: name 속성이 데이터베이스에서 고유해야 함을 나타낸다. 이 속성에 중복된 값이 존재할 수 없으며, 데이터베이스에 저장할 때 이를 보장한다.

---

그리고 변수를 몇개 더 추가해줄 것이다.

이때 변수는 Computed Properties로 만든다.

```swift
var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
var image: Image {
        Image(name.lowercased().replacingOccurrences(of: " ", with: ""))
    }
```

첫번째는 좌표에 대한 변수이다. Computed Property로 하였고, 위, 경도 값을 리턴하게 한다.

두번째는 이미지이다. 현재 Assets에 이미지들이 있는데 소문자로 되어있고, 띄어쓰기가 없는 상태이다.

그래서 유져가 대문자와 띄어쓰기를 포함시켜서 입력을 해도 그것을 소문자로 바꾸면서, 공백을 없애도록 하였다.

`Image(name.lowercased().replacingOccurrences(of: " ", with: ""))`

1. lowercased(): 문자열을 소문자로 치환
2. eplacingOccurrences(of: " ", with: ""): of의 값을 with의 값으로 치환.

### 2. Sample Data 추가하기

```swift
    static var previewPlaces: [Place] {
        [
            Place(name: "Bellagio", latitude: 36.1129, longitude: -115.1765, intersted: true),
            Place(name: "Paris", latitude: 36.1125, longitude: -115.1707, intersted: true),
            Place(name: "Treasure Island", latitude: 36.1247, longitude: -115.1721, intersted: false),
            Place(name: "Stratosphere", latitude: 36.1475, longitude: -115.1566, intersted: false),
            Place(name: "Luxor", latitude: 36.0955, longitude: -115.1761, intersted: false),
            Place(name: "Excalibur", latitude: 36.0988, longitude: -115.1754, intersted: true),
        ]
    }
```

다음과 같이 Sample Data를 만들어 주었다.

### 3. Preview Container 만들어주기

```swift
@MainActor
    static var preview: ModelContainer {
        let container = try! ModelContainer(for: Place.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
        for place in previewPlaces {
            container.mainContext.insert(place)
        }
        
        return container
    }
```

- **`@MainActor`** 가 뭘까?
    - @MainActor는 코드를 메인 스레드에서 실행하도록 보장하는 속성 래퍼이다. UI 관련 코드는 반드시 메인 스레드에서 실행되어야 한다.

	    - preview는 ModelContainer의 정적 변수이다. 프리뷰나 테스트를 위해 인메모리(in-memory) 데이터베이스를 생성하는 데 사용된다.
	    - try! ModelContainer(for: Place.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))는 Place 모델을 관리하는 ModelContainer를 생성한다. isStoredInMemoryOnly: true는 데이터가 메모리에만 저장되고 영구 저장소에는 저장되지 않음을 의미한다.
	    - for place in previewPlaces는 previewPlaces라는 샘플 데이터를 반복하며, container.mainContext.insert(place)로 각 Place 인스턴스를 mainContext에 삽입한다.
	    - 최종적으로, 준비된 container를 반환하여 프리뷰나 테스트 환경에서 사용할 수 있게 한다.


그리고 메인으로 돌아와서 

```swift
@main
struct VacationInVegasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Place.self)
    }
}
```

이렇게 modelContainer를 추가해준다.

WindowGroup에 modelContainer를 설정하여 데이터 모델의 컨테이너를 지정한다. modelContainer는 SwiftData에서 모델 데이터를 관리하는 역할을 한다.

- .modelContainer(for: Place.self)는 Place 모델을 관리하는 ModelContainer를 설정한다. 앱 내에서 Place 모델 데이터를 읽고 쓰는 작업을 수행할 수 있게 한다.
- 이 컨테이너는 WindowGroup과 연결되어 있어, 해당 뷰 계층 구조 내에서 Place 모델에 대한 데이터 작업을 할 수 있다.


확실히 SwiftUI는 Wrapper가 있다보니 생소한게 많다.

---

### 4. Database 접근을 위한 Query 작성

PlaceList라는 파일을 만들어 주었고

```swift
import SwiftUI
import SwiftData

struct PlaceList: View {
    @Query(sort: \Place.name) private var places: [Place]
    
    var body: some View {
        List (places) { place in
            HStack {
                
            }
        }
    }
}

#Preview {
    PlaceList()
        .modelContainer(Place.preview)
}
```

우선 이렇게 작성을 해주었다.

이때 또 Wrapper가 나타나는데 Query이며 DB에 접근하여 값을 가져올때 무작위로 가져오므로 sorting을 통해 순서대로 정렬을 하기로 결정.

여기서는 장소의 이름순으로 소팅을 해주었다.

![CleanShot 2024-09-09 at 21 18 56@2x](https://github.com/user-attachments/assets/98389cd3-57df-46dc-8b79-e824e693f623){: width="50%" height="50%"}

이렇게만 해줘도 Preview에 바로 row가 6개가 나온다

왜냐 이전에 우리가 Sample Data를 6개 만들어 두었기 때문


```swift
struct PlaceList: View {
    @Query(sort: \Place.name) private var places: [Place]
    
    var body: some View {
        List (places) { place in
            HStack {
                place.image
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 7))
                    .frame(width: 100, height: 100)
                
                Text(place.name)
            }
        }
    }
}
```

이렇게 해주니

![CleanShot 2024-09-09 at 21 22 35@2x](https://github.com/user-attachments/assets/ceda8761-8186-4431-8a71-0c65a1683f52){: width="50%" height="50%"}

이렇게 나온다.

여기서 우리가 아까 interested도 해주었기에 true/false에 따라 ⭐️가 나오게 해보자.

```swift
struct PlaceList: View {
    @Query(sort: \Place.name) private var places: [Place]
    
    var body: some View {
        List (places) { place in
            HStack {
                place.image
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 7))
                    .frame(width: 100, height: 100)
                
                Text(place.name)
                
                Spacer()
                
                if place.intersted {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .padding(.trailing)
                }
            }
        }
    }
}

```

![CleanShot 2024-09-09 at 21 23 53@2x](https://github.com/user-attachments/assets/aad9f8ee-8cf9-4dc7-9d31-2c97353bac76){: width="50%" height="50%"}

이렇게 확인이 가능하다.

### 5. NavigationStack 추가 하기

navigationBar로 생각하면 될듯하다.

```swift
.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show Images", systemImage: "photo") {
                        showImages.toggle()
                    }
                }
            }
```

이렇게 toolbar를 하나 만들어 줄것이다.

그리고 버튼을 하나 만들고 이름은 Show Images로 하고 디자인은 photo로 했다. 버튼이 눌러지면 토글이 되게한다.

그렇기에 변수를 하나 만들어 준다.

`@State private var showImages = false`

![CleanShot 2024-09-09 at 21 29 40@2x](https://github.com/user-attachments/assets/589817d4-6a25-4811-8a0b-8729955d054c){: width="50%" height="50%"}

위치는 위에 코드를 보면 topBarTrailing으로 해두어서 우상단에 위치한 걸 알 수 있다.

### 6. 버튼에 기능을 추가하기

이제 버튼을 만들었으니 기능을 추가해보자

```swift
struct PlaceList: View {
    @Query(sort: \Place.name) private var places: [Place]
    
    @State private var showImages = false
    
    var body: some View {
        NavigationStack {
            List (places) { place in
                HStack {
                    place.image
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 7))
                        .frame(width: 100, height: 100)
                    
                    Text(place.name)
                    
                    Spacer()
                    
                    if place.intersted {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .padding(.trailing)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show Images", systemImage: "photo") {
                        showImages.toggle()
                    }
                    .sheet(isPresented: $showImages) {
                        Scrolling()
                    }
                }
            }
        }
    }
}
```

isPresented는 showImages 상태 변수를 바인딩하여 시트(sheet)가 표시될지를 결정한다.

showImages가 true일 때 시트가 나타나고, false일 때 시트가 사라진다.

.sheet(isPresented: $showImages)는 showImages가 변경될 때마다 시트의 표시 상태를 업데이트한다. sheet 내부에는 Scrolling() 뷰가 표시된다.

- `isPresented`?
    - isPresented는 SwiftUI의 sheet modifier에서 사용되는 매개변수로, 시트(sheet) 뷰가 표시될지 여부를 결정하는 역할을 한다. isPresented는 Binding<Bool> 타입으로, 이 값이 true일 때 시트가 화면에 나타나고, false일 때 시트가 사라진다. 이를 통해 뷰의 상태에 따라 시트의 표시 여부를 동적으로 제어할 수 있다.

---

![Sep-09-2024 21-52-57](https://github.com/user-attachments/assets/3edea502-6dcb-4eee-a694-cbaaa43deb90){: width="50%" height="50%"}

### 7. predicates 사용하기

#### 1. Search Bar 만들기

```swift
struct PlaceList: View {
    @Query(sort: \Place.name) private var places: [Place]
    
    @State private var showImages = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List (places) { place in
                HStack {
                    place.image
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 7))
                        .frame(width: 100, height: 100)
                    
                    Text(place.name)
                    
                    Spacer()
                    
                    if place.intersted {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .padding(.trailing)
                    }
                }
            }
            .navigationTitle("Places")
            .searchable(text: $searchText, prompt: "Find a Place")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show Images", systemImage: "photo") {
                        showImages.toggle()
                    }
                    .sheet(isPresented: $showImages) {
                        Scrolling()
                    }
                }
            }
        }
    }
}
```

SwiftUI를 공부하면서 느낀점은 UIComponent 추가하는게 너무 쉽게 느껴진다는 것이다.

우선 검색어가 필요하므로 변수를 하나 만들어 주었다.

`@State private var searchText = ""`

그 이후 List의 `}`뒤에 (끝에) navigation Title과 서치바를 만들어 주어야 한다.

일일이 대괄호를 찾기가 힘드니,

![CleanShot 2024-09-09 at 21 59 05@2x](https://github.com/user-attachments/assets/03692bd8-6c06-42ad-a43f-5c1a6e22533f)

저부분을 더블 클릭 해주면?

![Sep-09-2024 21-58-31](https://github.com/user-attachments/assets/05441cb6-c54b-496a-8572-a39c82271cf2)

좀 더 쉽게 확인이 가능해진다!.

![CleanShot 2024-09-09 at 21 59 47@2x](https://github.com/user-attachments/assets/1a6bd575-dd71-487a-8558-57f41152838d){: width="50%" height="50%"}

이렇게 Search Bar가 만들어졌다.

하지만 아직 작동은 하지 않는다.

그래서 Predicate를 만들어 줄 것이다.

Computed Property를 활용을 해서 만들것이다.

```swift
private var predicate: Predicate<Place> {
        #Predicate<Place> {
            if !searchText.isEmpty && filterByInterested {
                $0.name.localizedStandardContains(searchText) && $0.intersted
            } else if !searchText.isEmpty {
                $0.name.localizedStandardContains(searchText)
            } else if filterByInterested {
                $0.intersted
            } else {
                true // default
            }
        }
    }
```

이렇게 작성을 해주었다.

- `localizedStandardContains(_:)`
    - 문자열이 다른 문자열을 포함하는지 여부를 확인하는 메서드로, 로케일에 따라 사용자의 언어 및 지역 설정에 맞게 비교를 수행한다. 이 메서드는 String 타입에서 사용할 수 있으며, 대소문자 구분 없이 검색어가 포함되어 있는지 검사한다. 특히 사용자에게 친숙한 방식으로 문자열을 비교하므로, 예를 들어 한국어나 다른 언어에서도 효과적으로 사용할 수 있다.
    
**주요 특징**

1. 로케일 민감한 비교
- 로케일(언어 및 지역) 설정에 따라 문자열 비교를 수행한다.
- 즉, 영어와 같은 언어뿐만 아니라 한국어, 일본어 등 다양한 언어 환경에서도 유사한 문자열을 잘 인식한다.

2. 대소문자 구분 없음
- 기본적으로 대소문자를 구분하지 않고 검색을 수행한다. 
- 예를 들어, "Vacation"과 "vacation"은 동일하게 취급된다.

3.	사용자가 기대하는 방식으로 비교
- 문자열 비교는 사용자에게 친숙한 방식으로 수행된다.
- 이는 특히 사용자가 다양한 언어로 데이터를 검색하는 앱에서 유용하다.

그리고 `List ((try? places.filter(predicate)) ?? places)` 이렇게 place 부분을 바꿔 주었다.

그러면 filter를 통해 걸러지게 된다.

#### 2. 애니메이션 추가하기

```swift
.navigationTitle("Places")
            .searchable(text: $searchText, prompt: "Find a Place")
            .animation(.default, value: searchText)
```

여기에 modifier인 animation을 추가해주자.

![Sep-09-2024 23-35-22](https://github.com/user-attachments/assets/c80ccc06-4d31-4ca1-9c43-4d12fb51fb89){: width="50%" height="50%"}

뭔가 디퍼블 사용하는듯한 느낌이 든다.

#### 3. Toolbar Item 추가하기

```swift
ToolbarItem(placement: .topBarLeading) {
                    Button("filter", systemImage: "star") {
                        withAnimation {
                            filterByInterested.toggle()
                        }
                    }
                }
```

trailing했던 부분 바로 밑에 하나를 더 만들어 주었다.

이녀석은 interested = true인 것만 보여주는 녀석이다.

![Sep-09-2024 23-39-07](https://github.com/user-attachments/assets/196d8263-c73d-4d15-99d8-0c1e9dc53bb8){: width="50%" height="50%"}

이것 역시도 `withAnimation`을 추가하여 애니메이션 효과를 주었다.

그리고 지금은 버튼이 클릭이 되었는지 아닌지 결과를 보고 해야하기에 툴바 버튼을 삼항연산자를 통해 색이 바뀌게 해보자.

```swift
 ToolbarItem(placement: .topBarLeading) {
                    Button("filter", systemImage: filterByInterested ? "star.fill" : "star") {
                        withAnimation {
                            filterByInterested.toggle()
                        }
                    }
                    .tint(filterByInterested ? .yellow : .blue)
                }
```


![Sep-09-2024 23-41-14](https://github.com/user-attachments/assets/e6714580-5548-48c4-999e-e27cfcbaa7aa){: width="50%" height="50%"}

완료.
