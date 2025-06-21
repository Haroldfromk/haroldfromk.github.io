---
title: JPApexPredators (2)
writer: Harold
date: 2025-3-27 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Navigation Stack 사용
이제는 Navigation Stack을 사용하여 각 공룡에 대한 cell을 탭했을때 다음 화면으로 넘어가게 해보자

이미 많이 사용해봤지만 간단하다.

현재는 List가 ContentView안에서 제일 상위 View인데 이 List를 NavigationStack이 감싸주면 된다.


```swift
struct ContentView: View {
    let predators = Predators()
    
    var body: some View {
        NavigationStack { // here
            List(predators.apexPredators) { predator in
                HStack {
                    // 생략
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
```

이런식으로

### Navigation Title 추가하기

List View의 Modifier로 `navigationTitle`을 추가해주면 된다.

이때

- `navigationTitle`은 **현재 화면(View)에 표시되는 제목**을 설정할 때 사용한다.
- `NavigationStack` 자체에는 제목을 붙이지 않는다.

**왜 `NavigationStack`이 아닌 화면(View)에 붙이는가?**

- `NavigationStack`은 **하위 뷰들을 감싸는 컨테이너 역할**만 한다.  
  → 우리가 실제로 **보는 건 Stack 안의 화면(View)** 이지 Stack 자체가 아니다.
- 하나의 `NavigationStack` 안에는 여러 화면(List, Detail 등)이 있을 수 있다.
- 각각의 화면은 서로 **다른 제목(navigationTitle)** 을 가질 수 있다.

![Image](https://github.com/user-attachments/assets/d9263418-9461-471d-b9d6-8f4ef7d7a864){: width="50%" height="50%"} 

이렇게 Navigation Title이 생긴다.

## Navigation Link를 통해 View 전환하기

Navigation Stack 하위에 Nagivation Link를 만들고 label 안에 Hstack을 담아준다. label 내부의 Curly Brace에는 내가 화면을 전환 시키고 싶은 view가 들어간다. 즉 우리는 list의 각 cell을 탭했을때 관련된 정보가 보이길 원하기 때문에 label 안에는 아래와 같이 Hstack이 담기게 된다.

```swift
struct ContentView: View {
    let predators = Predators()
    
    var body: some View {
            NavigationStack {
                List(predators.apexPredators) { predator in
                    NavigationLink { // new
                        
                    } label: {
                        HStack {
                            // 생략
                        }
                    }    
                }
                .navigationTitle("Apex Predators")
            }
            .preferredColorScheme(.dark)   
    }
}
```

![Image](https://github.com/user-attachments/assets/0abd0e6a-7e79-43b7-a6f8-987d4156a876){: width="50%" height="50%"} 그러면 이렇게 `>` 가 생긴다.


이제 `NavigationLink { }` 여기에 있는 Curly Brace 안에는 어떤게 들어가느냐

화면전환시 보여줄 content를 담으면 된다.

우리는 화면 전환시 json의 정보가 담기길 바라기때문에 우선 이미지를 먼저 담아 보도록 한다.

```swift
NavigationLink {
    Image(predator.image)
        .resizable()
        .scaledToFit()
}
```

![Image](https://github.com/user-attachments/assets/a9343eea-d16a-4cd7-a77d-d0856b0adf04){: width="50%" height="50%"} 

실행하면 위와 같다.

## SearchBar 구현하기

searchbar는 이전에도 언급해본적이 있다. swiftui는 비교적 간단한편

UIKit이었다면 UISearchBarDelegate를 통해서 구현해야하지만 swiftui는 `searchable` Modifier로 간단하게 구현이 가능하다. 

```swift
@State var searchText = ""

.navigationTitle("Apex Predators")
.searchable(text: $searchText)
.autocorrectionDisabled()
```

이렇게 해주면 된다.
아래 autocorrectionDisabled는 자동완성 금지.

![Image](https://github.com/user-attachments/assets/256ef977-bf1e-46ac-856f-a105eb19f368){: width="50%" height="50%"} 

하지만 아직 작동은 되지않는다.

## SearchBar를 통해 Filtering 하기

우선 필터링 된 배열값을 담을 변수를 하나 만들어 준다.

```swift
var filteredDinos: [ApexPredator] {
        if searchText.isEmpty {
            return predators.apexPredators
        } else {
            return predators.apexPredators.filter { predator in
                predator.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

var body: some View {
        NavigationStack {
            List(filteredDinos) { predator in // changed
```

여기서 filteredDinos는 computed Property로 만드는데, 유져가 아무런 입력을 안했을때는 모든 값이 다 나와야하므로 첫번째와 같이 리턴을 해준다.

여기서 눈여겨봐야할 점은 바로 else 구문.

고차함수인 filter를 사용하고 searchText와 일치하는 단어만 리턴하기 위해서 `localizedCaseInsensitiveContains`를 사용해주었다.

![Image](https://github.com/user-attachments/assets/20ffc44e-e14b-4ae7-83d3-81d84b567965)

boolean을 return하지만 애초에 filter 함수 역시도 

![Image](https://github.com/user-attachments/assets/96f6f2c1-6ae9-4f87-a8fe-f71ecb8358f4)

isIncluded가 true인 것만 리턴하기에 둘은 천생연분

![Image](https://github.com/user-attachments/assets/fd436505-263a-4da4-8fda-cea4e0ad0478){: width="50%" height="50%"} 

그럼 이렇게 필터링 된 값만 보이게 된다.

### 애니메이션 효과 주기

이건 하나의 옵션인데 `.animation` Modifier를 사용하여 아주 간단한 애니메이션 효과를 줄 수 있다.

```swift
.navigationTitle("Apex Predators")
.searchable(text: $searchText)
.autocorrectionDisabled()
.animation(.default, value: searchText)
```

이렇게 Animation Modifier도 추가를 해보았다.

하지만 현재는 되지 않는 것 같은데, 이건 이후에 다시 직접 고쳐보는걸로...

그리고 오타가 나는 경우 맞는 값이 없어서 지우려고할때 화면이 검게 되어버리는 현상이 존재한다. 이부분도 나중에 직접 수정해보는걸로...