---
title: LOTR Converter (3)
writer: Harold
date: 2024-7-22 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Info View 디자인하기

우선 파일을 하나 생성해주고

![CleanShot 2024-09-10 at 16 18 51@2x](https://github.com/user-attachments/assets/b60bb66d-4f31-4d8a-992c-7ddcceb73e20)

이때 UIkit을 할때는 Swift File을 했지만

이제는 아래에 있는 SwiftUI View로 만들어 준다.

그리고 다음과 같이 큰 틀을 짜준다.

```swift
struct ExchangeInfo: View {
    var body: some View {
        ZStack {
            // Background parchment image
            
            VStack {
                // Title text
                
                // Description Text
                
                // Exchnage rates
                
                HStack {
                    // Left Currency image
                    
                    // Exchange rate text
                    
                    // Right Currency image
                }
                
                // Done Button
            }
        }
    }
}
```

배경화면을 추가해주고

Title Text를 추가를 해주었다.

이때 자간을 늘리려고 할때 사용되는것이 바로 `tracking` Modifier이다.

```swift
Text("Exchange Rates")
                    .font(.largeTitle)
                    .tracking(3)
```

![Sep-10-2024 20-15-04](https://github.com/user-attachments/assets/38c2e0ac-7043-4e20-bcae-6b2eecc5368f){: width="50%" height="50%"}

차이가 명확하다.

```swift
struct ExchangeInfo: View {
    var body: some View {
        ZStack {
            // Background parchment image
            Image(.parchment)
                .resizable()
                .ignoresSafeArea()
                .background(.brown)
            
            VStack {
                // Title text
                Text("Exchange Rates")
                    .font(.largeTitle)
                    .tracking(3)
                
                // Description Text
                Text("Here at the Prancing Pony, we are happy to offer you a place where you can exchange all the known currencies in the entire world except one. We used to take Brandy Bucks, but after finding out that it was a person instead of a piece of paper, we realized it had no value to us. Below is a simple guide to our currency exchange rates:")
                    .font(.title2)
                    .padding()
                
                // Exchnage rates
                HStack {
                    // Left Currency image
                    Image(.goldpiece)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 33)
                    
                    // Exchange rate text
                    Text("1 Gold Piece = 4 Gold Pennies")
                    
                    // Right Currency image
                    Image(.goldpenny)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 33)
                }
                
                // Done Button
                Button("Done") {
                    
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .font(.largeTitle)
                .padding()
                .foregroundStyle(.white)
            }
            .foregroundStyle(.black)
        }
    }
}
```

![CleanShot 2024-09-10 at 20 20 35@2x](https://github.com/user-attachments/assets/1f91e743-c82f-4b1e-be19-f37a6540cf27){: width="50%" height="50%"}

이렇게 완성이 되었다.

## SubView 사용해보기

![CleanShot 2024-09-10 at 20 32 55@2x](https://github.com/user-attachments/assets/d57db523-3dab-420b-979f-33223bf59530){: width="50%" height="50%"}

HStack을 여러번 사용할것이라 효과적으로 코드를 작성하기위해 SubView를 사용하려고 한다.

그래서 HStack을 우클릭하여 Extract 해주자.

```swift
struct ExtractedView: View {
    var body: some View {
        HStack {
            // Left Currency image
            Image(.goldpiece)
                .resizable()
                .scaledToFit()
                .frame(height: 33)
            
            // Exchange rate text
            Text("1 Gold Piece = 4 Gold Pennies")
            
            // Right Currency image
            Image(.goldpenny)
                .resizable()
                .scaledToFit()
                .frame(height: 33)
        }
    }
}
```

그러면 이렇게 별도로 Seperated 된다.

또한 SubView만 preview로 보고싶다면

```swift
#Preview {
    ExtractedView()
}
```

그냥 아래에 이렇게 적어주면 된다.

![CleanShot 2024-09-10 at 21 09 14@2x](https://github.com/user-attachments/assets/f457694f-9ea2-4eaa-b597-a27cbddb1eb6){: width="50%" height="50%"}

그럼 이렇게 상단에 preview를 선택해서 볼 수 있다.

하지만 폰 전체 말고 딱 그 사이즈만 보고싶다면

[이전 글](https://haroldfromk.github.io/posts/SwiftUI-(2)/)을 참조.

```swift
#Preview(traits: .sizeThatFitsLayout) {
    ExtractedView()
}
```

여기선 코드로 대체한다.

그리고 파일을 새롭게 만들어 주고 코드를 이관해주자.

파일명은 ExchangeRate로 해주었다.

그리고 다시 Exchange Info로 와서 view를 3개 더 추가해준다.

```swift
// Exchnage rates
                ExtractedView()
                
                ExtractedView()
                
                ExtractedView()
                
                ExtractedView()
```

![CleanShot 2024-09-10 at 22 07 16@2x](https://github.com/user-attachments/assets/8999bdf4-d4f1-4bd2-bdd3-0425a9340fd1){: width="50%" height="50%"}

이렇게 SubView를 사용하면 코드를 좀 더 간결하게 할 수 있고, 유지 보수도 용이해진다.

## SubView 모듈화 하기

현재는 ExchangeRate 뷰 자체가 같은 이미지를 가지고 있다.

하지만 4개가 모두 같은 이미지, 내용을 가지고 있기에 커스터마이징이 불가능 하다.

```swift
struct ExchangeRate: View {
    let leftImage: ImageResource
    let text: String
    let rightImage: ImageResource
    
    var body: some View {
        HStack {
            // Left Currency image
            Image(leftImage)
                .resizable()
                .scaledToFit()
                .frame(height: 33)
            
            // Exchange rate text
            Text(text)
            
            // Right Currency image
            Image(rightImage)
                .resizable()
                .scaledToFit()
                .frame(height: 33)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ExchangeRate(leftImage: .silverpiece, text: "1 Gold Piece = 4 Gold Pennies", rightImage: .silverpenny)
}

```

이렇게 변수를 만들어 주었다.

정확히 말하면 let을 사용하여 상수로 했다.

이제 ExchangeInfo 에서 Error가 발생하는데 그전에는 내부에 파라미터가 없었지만 지금은 생겼기에 설정을 해줘야한다.

![CleanShot 2024-09-10 at 23 08 51@2x](https://github.com/user-attachments/assets/c53b446a-c5b5-4988-ba79-433fa8094f54)

친절한 녀석들.

```swift
 
                // Exchnage rates
                ExchangeRate(leftImage: .goldpiece, text: "1 Gold Piece = 4 Gold Pennies", rightImage: .goldpenny)
                
                ExchangeRate(leftImage: .goldpenny, text: "1 Gold Penny = 4 Silver Pieces", rightImage: .silverpiece)
                
                ExchangeRate(leftImage: .silverpiece, text: "1 Silver Piece = 4 Silver Pennies", rightImage: .silverpenny)
                
                ExchangeRate(leftImage: .silverpenny, text: "1 Silver Penny = 100 Copper Pennies", rightImage: .copperpenny)
```

코드를 모두 적어주자.

![CleanShot 2024-09-10 at 23 17 47@2x](https://github.com/user-attachments/assets/4fb8f47b-ca61-4e56-b597-1e14a8fcefad){: width="50%" height="50%"}

이렇게 코드는 간결해지고, 원하는 내용을 바로바로 추가하거나 변경만 하면 되므로 쉽게 커스터마이징이 가능해졌다.


