---
title: How to load a remote image from the Internet?
writer: Harold
date: 2024-8-01 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## AsyncImage

AsyncImage는 비동기로 이미지를 로드할때 사용한다.

로드중일때는 보통 Placeholder를 사용한다.

### 1. 뼈대 작성

```swift
struct ContentView: View {
    private let imageURL: String = "https://credo.academy/credo-academy@3x.png"
    
    var body: some View {
        // MARK: - 1. BASIC
        
        AsyncImage(url: URL(string: imageURL))
        
    }
}
```

이것이 바로 기본 틀이다.

![CleanShot 2024-10-14 at 01 45 16](https://github.com/user-attachments/assets/ddaeba13-ae3f-4781-8717-2df3cf1ac498){: width="50%" height="50%"} 

실행하면 다음과 같다.


### 2. Scale

```swift
var body: some View {
        // MARK: - 2. Scale
        AsyncImage(url: URL(string: imageURL), scale: 3.0)
    }
```

Scale의 경우는 숫자가 클수록 이미지가 작아지고, 작아질수록 이미지가 커진다.

## 3. PlaceHolder

PlaceHolder의 경우 이미지가 로드되기전에 보여주는 이미지 이다.

```swift
var body: some View {
        // MARK: - 3. PlaceHolder
        AsyncImage(url: URL(string: imageURL)) {
            image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            Image(systemName: "photo.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 128)
                .foregroundColor(.purple)
                .opacity(0.5)
        }
        .padding(40)
    }
```

![Oct-14-2024 01-52-12](https://github.com/user-attachments/assets/313b3046-15f4-4bfa-a13a-39be9a4484cd){: width="50%" height="50%"} 

###  4. Extension 사용으로 코드 줄이기

현재 

```swift
.resizable()
.scaledToFit()
```

위 두개의 Modifier가 반복되고 있다.

이걸 Extension을 사용하여 코드를 줄여보자.

```swift
extension Image {
    func imageModifier() -> some View {
        self
            .resizable()
            .scaledToFit()
    }
    
    func iconModifier() -> some View {
        self
            .imageModifier()
            .frame(maxWidth: 128)
            .foregroundColor(.purple)
            .opacity(0.5)
    }
}
```

여기서 흥미로운건 some View 를 리턴한다는 것이다.

some View를 리턴한다는 의미는 이 함수가 어떤 특정한 뷰 타입을 리턴한다는 것이다.

SwiftUI에서 some View는 함수가 리턴할 구체적인 뷰 타입을 명시하지 않고, 대신 SwiftUI의 View 프로토콜을 준수하는 하나의 뷰를 반환한다고 선언하는 방식이다.

예를 들어, imageModifier() 함수는 View 프로토콜을 따르는 구체적인 뷰인 Image를 리턴하는데, 함수가 직접 리턴하는 타입을 명시하지 않고, 대신 어떤 View 타입이든 리턴할 수 있음을 나타낸다. 하지만 Swift가 컴파일 시점에 이 리턴 타입을 추론하므로, 내부적으로 리턴하는 뷰 타입은 고정되어 있다.

이 방식의 장점은 함수가 여러 개의 뷰를 리턴할 수 있게 하는 대신, Swift의 타입 안정성과 최적화 기능을 유지할 수 있다는 점이다.

그리고 안애서 self가 나오는데, self는 그 해당하는 뷰 자신을 의미한다.

`imageModifier`함수를 예로 들면

거기서 self는 이 메서드가 호출된 뷰 자신을 가리킨다. 즉, 이 메서드를 호출한 뷰(예를 들어, Image)에 대해 resizable()과 scaledToFit() 같은 modifier를 적용하게 된다.

### 5. Phase

```swift
AsyncImage(url: URL(string: imageURL)) { phase in
            // Success: The image successfully loaded
            if let image = phase.image {
                image.imageModifier()
            } else if phase.error != nil {
                // Failure: The image failed to load with an error
                Image(systemName: "ant.circle.fill").iconModifier()
            } else {
                // Empty: No image is loaded
                Image(systemName: "photo.circle.fill").iconModifier()
            }
            
        }
        .padding(40)
```

Phase는 이미지가 제대로 로드가 되었는지, 아닌지 이런 예외처리를 하는것으로 이해하면 쉽다.

즉 이미지가 제대로 로드가 될경우엔 imageModifier 함수가 적용이 되고

여기선 이미지 로드에 문제가 발생했을때 개미 아이콘이 나오게 되어있다.

### 6. Animation

```swift
AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .success(let image):
                image.imageModifier()
            case .failure(_):
                Image(systemName: "ant.circle.fill").iconModifier()
            case .empty:
                Image(systemName: "photo.circle.fill").iconModifier()
            }
        }
        .padding(40)
```

5번의 케이스를 if 대신 switch-case를 사용하여 다르게 표현을 했다.

이때 Warning이 발생했다.

warning에대해 Fix를 누르니 `@unknown default`에 관한 항목이 생긴다.

```swift
AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .success(let image):
                image.imageModifier()
            case .failure(_):
                Image(systemName: "ant.circle.fill").iconModifier()
            case .empty:
                Image(systemName: "photo.circle.fill").iconModifier()
            @unknown default:
                ProgressView()
            }
        }
        .padding(40)
```

transaction을 추가하여 애니메이션을 넣어보자.

```swift
AsyncImage(url: URL(string: imageURL),
                   transaction: Transaction(
                    animation: .spring(response: 0.5,
                    dampingFraction: 0.6,
                    blendDuration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.imageModifier()
                    .transition(.move(edge: .bottom))
            case .failure(_):
                Image(systemName: "ant.circle.fill").iconModifier()
            case .empty:
                Image(systemName: "photo.circle.fill").iconModifier()
            @unknown default:
                ProgressView()
            }
        }
        .padding(40)
```

- Transaction은 상태 변화에 대해 애니메이션을 정의하는 구조체이다.
- animation: .spring(...)는 스프링 애니메이션을 지정하고 있다.
- response: 0.5: 애니메이션의 지속 시간을 의미한다. 값이 클수록 애니메이션이 느리게 진행된다.
- dampingFraction: 0.6: 애니메이션이 끝날 때 진동을 얼마나 억제할지를 나타낸다. 값이 낮을수록 진동이 더 많이 발생한다.
- blendDuration: 0.25: 애니메이션이 다른 애니메이션과 섞이는 데 걸리는 시간이다.

따라서 이 transaction은 이미지가 성공적으로 로드되었을 때, 스프링 애니메이션을 적용하는 데 사용된다.

![Oct-14-2024 03-01-08](https://github.com/user-attachments/assets/c658130b-af94-44f6-ad0d-4fd221437d54){: width="50%" height="50%"} 