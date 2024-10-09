---
title: LOTR Converter (1)
writer: Harold
date: 2024-7-22 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## VHZStack

![CleanShot 2024-09-10 at 03 54 58@2x](https://github.com/user-attachments/assets/6d27bf4b-82a1-438c-9754-a4dd2c1c063c)
![CleanShot 2024-09-10 at 03 55 13@2x](https://github.com/user-attachments/assets/725d18ca-9f42-407e-bac8-932572383cfb)

이미지로 간단하게 설명이 가능하다.

V: Vertical
H: Horizontal
Z는 그냥 Z Axis인듯하다.

우리가 최종적으로 만들 앱의 Structure는 다음과 같이 될것이다.

![CleanShot 2024-09-10 at 03 58 34@2x](https://github.com/user-attachments/assets/284a1cb0-57f2-41e4-8bfa-ac4bef83ae0c)

VHZStack도 **View** 라는것을 꼭 기억해두자.

## 뼈대 구성하기

여기 강의에서는 먼저 어떻게 할지 이미지화를 하고 그것에 대해서 크게 뼈대를 잡는 식으로 하였다.

![CleanShot 2024-09-29 at 17 09 45@2x](https://github.com/user-attachments/assets/e1d2cf14-9397-4aaa-a193-4fec66a53746)

구성은 위와 같다.

```swift
struct ContentView: View {
    var body: some View {
        ZStack {
            // Background Image
            
            VStack {
                // Prancing pony image
                
                // Currency exchange text
                
                // Currency conversion section
                HStack {
                    // Left conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency image
                            
                            // Currency text
                        }
                        
                        // Textfield

                    }
                    
                    // Equal sign
                    
                    // Right conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency text
                            
                            // Currency image
                        }
                        
                        // Textfield
                        
                    }
                }
                
                // Info Button
            }
        }
    }
}
```

이렇게 주석을 잡아가면서 뼈대를 잡았다.

좋은 방법인듯 하다.

## UI 추가하기

이미지는 `Image(.background)` 이렇게만 적으면 된다.

이전에 UIKit을 사용할때는 `Image("background")` 이런식으로 문자열을 사용했는데, SwiftUI에서는 간편하게 할 수 있다. 물론 두개 다 여기선 사용가능하다.

이미지를 추가하면 그냥 꽉 차버리는데 이때 `.resizable()` 을 사용하자.

그러면

![CleanShot 2024-09-10 at 04 09 31@2x](https://github.com/user-attachments/assets/e03b41fe-18b0-4e86-ba97-15976b979686){: width="50%" height="50%"}

이렇게 SafeArea는 유지한채로 이미지가 깔리는데,

우리는 전역에 배경화면이 깔리게 할것이므로 Modifier를 하나 더 추가해준다.

바로 `.ignoresSafeArea()`이다.

그냥 읽어봐도 직관적으로 어떤 걸 의미하는지 알 수 있다.

![CleanShot 2024-09-10 at 04 10 43@2x](https://github.com/user-attachments/assets/7bbb1c9e-f358-4678-85f6-08c222e93e93){: width="50%" height="50%"}

이렇게 깔끔하게 되었다.

```swift
VStack {
                // Prancing pony image
                Image(.prancingpony)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
```

![CleanShot 2024-09-10 at 04 12 30@2x](https://github.com/user-attachments/assets/dba2d915-e28d-4b5c-9221-73833b615caa){: width="50%" height="50%"}

이렇게 Image 추가하듯이 Text도 추가하면 된다.

코드를 추가해주면

```swift
struct ContentView: View {
    var body: some View {
        ZStack {
            // Background Image
            Image(.background)
                .resizable()
                .ignoresSafeArea()
            
            VStack {
                // Prancing pony image
                Image(.prancingpony)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                
                // Currency exchange text
                Text("Currency Exchange")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                
                // Currency conversion section
                HStack {
                    // Left conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency image
                            Image(.silverpiece)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 33)
                            
                            // Currency text
                            Text("Silver Piece")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        // Textfield
                        Text("Textfield")
                        
                    }
                    
                    // Equal sign
                    Image(systemName: "equal")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                    
                    // Right conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency text
                            Text("Gold Piece")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            // Currency image
                            Image(.goldpiece)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 33)
                        }
                        
                        // Textfield
                        Text("Textfield")
                        
                    }
                }
                
                Spacer()
                
                // Info Button
                Image(systemName: "info.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            //.border(.blue)
        }
    }
}
```

![CleanShot 2024-09-10 at 04 23 11@2x](https://github.com/user-attachments/assets/13917d2f-1ab4-4d64-8652-c4fbebf60182){: width="50%" height="50%"}

equal이 pulse 효과를 주어 은은하게 반짝이지만 gif대신 png이미지로 대체한다.

그리고 Textfield는 임시로 Text로 해주었다.
