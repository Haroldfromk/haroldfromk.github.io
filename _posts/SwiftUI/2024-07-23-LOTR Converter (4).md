---
title: LOTR Converter (4)
writer: Harold
date: 2024-7-23 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Info Button 기능 추가하기

Info Button을 누르면 Exchange Info 화면이 나오게 할 것이다.

```swift
// Info Button
                HStack {
                    Spacer()
                    
                    Button {
                        showExchangeInfo.toggle()
                        
                        
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing)
                    .sheet(isPresented: $showExchangeInfo) {
                        ExchangeInfo()
                    }
                }
```

이렇게 버튼 뒤에 Modifier를 추가해준다.

이때 사용된 Modifier는 Sheet이며, 새로운 페이지를 보여줄때 사용한다.

뭐랄까 화면전환의 개념이다.

UIKit에서는 present와 비슷하다고 생각하면 될듯하다.

이때 isPresented의 parameter로 showExchangeInfo를 받게하고 true / false에 따라 보여지는지 아닌지를 확인하게한다.

![Sep-11-2024 07-47-50](https://github.com/user-attachments/assets/9c75137f-2800-4f61-94df-7caeacab20a5){: width="50%" height="50%"}

지금은 modal처럼 화면이 올라온다.

## Done 버튼을 눌렀을때 화면을 다시 이전으로 돌아가게 하기

새로운 Wrapper를 사용한다. 바로 `@Environment`이다.

SwiftUI에서 @Environment는 뷰에 환경 값을 주입하는 데 사용하는 프로퍼티 래퍼이다.

SwiftUI는 뷰 간에 데이터를 전달하기 위해 다양한 방법을 제공하며, @Environment는 부모 뷰에서 하위 뷰로 환경 값을 전달하는 중요한 방법 중 하나이다.

- @Environment의 주요 개념
    - @Environment는 SwiftUI 앱의 전역 설정이나 상태를 뷰에 제공하는 데 사용된다.
    - 앱의 여러 뷰가 동일한 데이터를 필요로 할 때, 환경을 통해 해당 데이터를 공유하고 접근할 수 있다.

- @Environment의 특징
	- 미리 정의된 환경 값: SwiftUI는 미리 정의된 여러 환경 값을 제공한다. 예를 들어 colorScheme, presentationMode, accessibilityDifferentiateWithoutColor, horizontalSizeClass 등이 있다.
	- 커스텀 환경 값: 사용자가 직접 커스텀 환경 값을 정의하고 공유할 수도 있다. EnvironmentKey 프로토콜을 채택하여 커스텀 키를 만들고, 그 키에 대한 기본 값을 제공하는 식으로 구현한다.

![CleanShot 2024-09-14 at 04 25 40@2x](https://github.com/user-attachments/assets/a4eb1e56-9d1b-41b1-b6b6-77f55f7c92bf){: width="50%" height="50%"}

`@Environment(\.dismiss) var dismiss`: @Environment를 사용하여 시스템에서 제공하는 dismiss 메서드를 가져와 뷰를 닫는 데 사용한다.


```swift
struct ExchangeInfo: View {
    @Environment(\.dismiss) var dismiss
    
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
                ExchangeRate(leftImage: .goldpiece, text: "1 Gold Piece = 4 Gold Pennies", rightImage: .goldpenny)
                
                ExchangeRate(leftImage: .goldpenny, text: "1 Gold Penny = 4 Silver Pieces", rightImage: .silverpiece)
                
                ExchangeRate(leftImage: .silverpiece, text: "1 Silver Piece = 4 Silver Pennies", rightImage: .silverpenny)
                
                ExchangeRate(leftImage: .silverpenny, text: "1 Silver Penny = 100 Copper Pennies", rightImage: .copperpenny)
                
                // Done Button
                Button("Done") {
                    dismiss()
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

![Sep-14-2024 04-32-20](https://github.com/user-attachments/assets/6c75b91a-60b6-4d8e-8b07-53e9382a7a29){: width="50%" height="50%"}

작동도 잘된다.

이떄 ExchangeInfo에서 하면 작동확인이 안되므로, ContentView에서 확인하도록 하자.

그리고 흥미로운게 dismiss를 변수로 만들었지만

![CleanShot 2024-09-14 at 04 33 51@2x](https://github.com/user-attachments/assets/0a766cc3-5c24-4bdd-90d2-dd116025c5ac)

이녀석 일종의 액션의 형태를 가진다.

그래서 dismiss를 하기위해선 ()를 적어주는것이다.

