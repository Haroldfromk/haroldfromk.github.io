---
title: ScrollView
writer: Harold
date: 2024-7-19 07:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

```swift
struct ScrollImage: View {
    let image: String
    
    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 20))
            .scrollTransition { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.5)
                    .opacity(phase.isIdentity ? 1 : 0.5)
            }
    }
}
```

![CleanShot 2024-09-06 at 14 08 24@2x](https://github.com/user-attachments/assets/e4eb9a65-4419-41fb-9f1f-5966ddd468df){: width="50%" height="50%"}

scrollTransition의 phase:
- scrollTransition 클로저 내부에서 phase는 현재 스크롤 상태를 나타내는 객체이다.
- phase.isIdentity는 콘텐츠가 스크롤 상태의 기본 위치에 있는지 (true) 또는 전환 중인지 (false)를 나타낸다.
- 즉 어디에 있는지?

**isIdentity**는 Bool 타입의 값으로, true일 때는 콘텐츠가 기본 상태(identity)에 있으며, false일 때는 애니메이션 또는 전환의 다른 상태에 있음을 나타낸다. 

예를 들어, 스크롤 애니메이션 중에 콘텐츠가 처음 위치에 있으면 isIdentity는 true가 되며, 스크롤에 의해 변형되거나 이동 중이라면 isIdentity는 false가 된다.

위와 같이 Preview에서는 지금 false인 상태로 되는데 이유는 스크롤을 할때 어떤 상태인지를 보여주기 위해서이다!

그리고 새롭게 파일을 만들고 다음과 같이 코드를 적어주었다.

```swift
struct Scrolling: View {
    var body: some View {
        ScrollView {
            VStack {
                ScrollImage(image: "bellagio")
                
                ScrollImage(image: "excalibur")
                
                ScrollImage(image: "luxor")
                
                ScrollImage(image: "paris")
                
                ScrollImage(image: "stratosphere")
                
                ScrollImage(image: "treasureisland")
            }
            .padding()
        }
    }
}

```

![Sep-06-2024 14-09-04](https://github.com/user-attachments/assets/f1e00330-2c97-4c2e-8c3b-954e1a8e28bb){: width="50%" height="50%"}

그리고 ScollImage는 우리가 위에 만들어둔 구조체이다.

그렇기에 위로 스크롤할때 opacity와 이미지 스케일이 변화가 되는것이다.



