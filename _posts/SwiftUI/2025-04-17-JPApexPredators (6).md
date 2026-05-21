---
title: JPApexPredators (6)
writer: Harold
date: 2025-4-13 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Map View 사용하기

이전 Mapkit에 이어서...

지금은 지도의 일부만 표시가 되고 있다.

이렇게 일부만 보는게 아니라 지도를 확대해서 조금 더 잘 보이게끔 해보도록 하자

새롭게 파일을 만들고 PredatorMap이라고 명명하였다.

이전글에서는 camera의 distance를 30000으로하고 끝냈는데

이번에는

```swift
positoin: .camera(
            MapCamera(
                centerCoordinate: Predators().apexPredators[2].location,
                distance: 1000,
                heading: 250,
                pitch: 80))
```

이렇게 distance도 줄이고 heading, pitch도 준다.

heading, pitch의 경우는

[여기서](https://haroldfromk.github.io/udemy/swiftui/MapKit/){:target="_blank"} 언급을 했었기에 패스

현재는 preview에만 적용을 했고

다음과 같다.

![Image](https://github.com/user-attachments/assets/95ad1445-fe0f-46b6-ae12-6df3e9393fd2){: width="50%" height="50%"} 

MapView에 모든 이미지를 담기위해서

`let predators = Predators()` 를 만들어 주었다.

그리고 Map안에 Curly brace에 foreach를 사용하여 모든 공룡의 이미지가 나오게 했다

```swift
Map(position: $positoin) {
            ForEach(predators.apexPredators) { predator in
                Annotation(predator.name, coordinate: predator.location) {
                    Image(predator.image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .shadow(color:.white, radius: 3)
                        .scaleEffect(x: -1)
                }
            }
        }
```

이건 딱히 언급할만한 건 없다.

![Image](https://github.com/user-attachments/assets/9d2c93c3-1a1a-46c0-a1b0-a20601857c18){: width="50%" height="50%"} 

축소를 하면 이렇게 전부 다 나오는걸 알 수 있다.

여기서 조금 더 응용해서 위성사진 사용을 위한 버튼을 만들어 본다.

우선 변수를 하나 만들고
`@State var satellite = false`

변수를 만든 이유는 toggle이 되어야 하기 때문.

```swift
Map(position: $positoin) {
        // 생략
    }
    .mapStyle(satellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
    .overlay(alignment: .bottomTrailing) {
        Button {
            satellite.toggle()
        } label: {
            Image(systemName: satellite ? "globe.americas.fill" : "globe.americas")
                .font(.largeTitle)
                .imageScale(.large)
                .padding(3)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 7))
                .shadow(radius: 3)
                .padding()
        }

    }
```

overlay를 통해 우측 하단에 버튼을 만들어 주고 위와 같이 코드를 작성한다.

여기서는 `.mapStyle(satellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))`에 포커스를 두면 될 것 같다.

- `.mapStyle(...)`은 `Map` 뷰의 **지도 스타일을 설정**하는 modifier이다.

- 이 코드에서는 `satellite`라는 불리언 상태 값에 따라 다음 두 가지 스타일을 전환함:
  - `true`일 때: **위성지도(.imagery)** 스타일
  - `false`일 때: **표준지도(.standard)** 스타일

- 두 경우 모두 `.elevation(.realistic)`이 적용되어, **지형의 고도감을 실제처럼 입체적으로 표현**한다.

👉 사용자는 버튼을 눌러 `satellite` 상태를 토글하며  
**위성 뷰와 일반 뷰를 전환**할 수 있고,  
**보다 생생한 지도 표현**을 경험할 수 있다.

그리고 실행하면 이렇게 된다.

![Image](https://github.com/user-attachments/assets/55d48e11-99e5-4398-942d-bcbca342cd27){: width="50%" height="50%"} 

위성사진 로딩이 좀 걸리긴 하네..

이전에는 Detail에서 지도를 탭하면 공룡이 나왔는데

지금 만든 mapview가 나오도록 바꿔주자.

```swift
NavigationLink {
    PredatorMap(
        positoin: .camera(
            MapCamera(
                centerCoordinate: predator.location,
                distance: 1000,
                heading: 250,
                pitch: 80))
    )
}
```

간단하다. preview에 작성해둔 코드를 위와같이 navigation link에 옮겨주기만 하면 끝

대신 `centerCoordinate: predator.location`만 이렇게 다시 바꿔준다.

왜냐면 preview에선 특정값으로 일부러 하드코딩을 해뒀기 때문.

![Image](https://github.com/user-attachments/assets/d855a3f5-a573-4fb9-b178-84ff5cf1a624){: width="50%" height="50%"} 

잘 되는걸 알 수 있다.

## navigation transition 사용하기

```swift
@Namespace var namespace

NavigationLink {
    PredatorMap(
        // 생략
    )
    .navigationTransition(.zoom(sourceID: 1, in: namespace))
} label: {
    Map(position: $position) {
       // 생략
    }
    // 생략
}
.matchedTransitionSource(id: 1, in: namespace)
```

여기서 약간 zoom transition의 효과를 주기위해 navigationTransition과 matchedTransitionSource을 사용했다.


### 🧭 `@Namespace`, `.matchedTransitionSource`, `.navigationTransition`

---

#### 🌀 @Namespace

`@Namespace`는 SwiftUI에서 뷰 간 애니메이션을 **연결하고 동기화**하기 위해 사용하는 속성 래퍼이다.  
서로 다른 뷰 간에 동일한 `namespace`를 공유하면, SwiftUI가 해당 뷰들의 전환 관계를 인식하고 **자연스럽고 부드러운 전환 효과**를 적용할 수 있다.

---

#### ✨ SwiftUI 전환 애니메이션 핵심 개념

SwiftUI에서는 `@Namespace`를 활용하여 **화면 전환 시 부드러운 애니메이션 효과**를 만들 수 있다.  
이때 사용하는 핵심 modifier는 `matchedTransitionSource`와 `navigationTransition`이다.

---

#### 🔗 matchedTransitionSource(id:in:)

`matchedTransitionSource(id:in:)`는 **전환의 출발점이 되는 View**를 지정하는 modifier이다.

- `id`: 전환을 구분하기 위한 고유 식별자
- `namespace`: 전환 효과를 공유할 수 있도록 연결해주는 공간
- 같은 `namespace` 내에서 `navigationTransition`의 `sourceID`와 연결됨
- 이 View의 스타일 변화가 전환 중 애니메이션으로 반영된다

---

#### 🚀 navigationTransition(_:)

`navigationTransition(_:)`는 **도착지 View에 적용하는 Modifier**로,  
전환될 때 어떤 애니메이션 효과를 사용할지 정의한다.

- 전환 방식: `.zoom(sourceID:in:)` 등 사용 가능
- `sourceID`는 `matchedTransitionSource`의 `id`와 일치해야 함
- 동일한 `namespace`를 공유해야 전환 애니메이션이 자연스럽게 연결됨

---

#### ⚙️ 실무 팁

- `id` 값은 같아도 전혀 문제 없다.  
  → 각각 **다른 modifier context**에서 작동하므로 충돌 없음  
- 중요한 포인트는 `@Namespace`를 통해 **두 View가 같은 전환 공간을 공유**해야 한다는 점이다.

---

### ✅ 요약

| 역할                        | 적용 위치     | 필요한 요소           |
|-----------------------------|---------------|------------------------|
| `matchedTransitionSource`   | 출발지 View   | `id`, `namespace`      |
| `navigationTransition`      | 도착지 View   | `sourceID`, `namespace`|

- **같은 `id` + 공유된 `namespace`** = 전환 연결 완성  
- 서로 다른 modifier지만 하나의 **전환 흐름을 완성**하기 위해 함께 사용됨

---

![Image](https://github.com/user-attachments/assets/55632f15-e097-48d0-b02c-c779dc0773db){: width="50%" height="50%"} 

이렇게 화면전환이 달라진걸 볼 수 있다.