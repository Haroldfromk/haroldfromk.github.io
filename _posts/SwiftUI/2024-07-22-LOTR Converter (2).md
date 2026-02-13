---
title: LOTR Converter (2)
writer: Harold
date: 2024-7-22 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Info Button 추가하기

기본적인 틀이 만들어졌으니, 버튼을 추가해보도록한다.

우선 버튼 디자인을 할 것인데,

```swift
Button {
        
        } label: {
                    Image(systemName: "info.circle.fill")
                    
                }
                .font(.largeTitle)
                .foregroundStyle(.white)
```

이렇게 해준다.

이전의 글에 있었던 마지막 화면과 동일하므로 이미지는 패스

label에 이미지를 넣고 버튼의 이미지를 디자인 해주는 것이다.

이제 버튼을 작동시키기 위해 변수를 하나 만들어준다.

`var showExchangeInfo = false`

![CleanShot 2024-09-10 at 14 43 54@2x](https://github.com/user-attachments/assets/82b8d3f2-ffa3-4ad0-b27c-f5eda318b489)

하지만 이렇게 에러가 뜬다.

이때 이전에 사용했던 `@State` Wrapper를 적용시켜주면 된다.

버튼 작동의 확인을 위해 toggle을 해주었는데,

preview에서도 확인이 가능하다.

![CleanShot 2024-09-10 at 14 52 20@2x](https://github.com/user-attachments/assets/1f45a3bc-398a-467a-ad65-e97035d8a325)

아래에 있는 Preview를 탭해주고 테스트하면 이렇게 콘솔에 출력이 되는것을 확인할 수 있다.

그리고 버튼이 현재 중간에 위치하므로, HStack 하나 더 추가 해주고 버튼의 위치를 `Spacer()`를 통해 옮겨볼 것이다.

<span style="color:red">이전에 컨트롤 클릭으로 추가하는것을 언급했는데, 그냥 우클릭을 해도 된다.</span>

참고하자

![CleanShot 2024-09-10 at 15 02 52@2x](https://github.com/user-attachments/assets/d5ae152c-fc6e-4a19-bae1-8e4a451cf113){: width="50%" height="50%"}

하지만 이렇게 완전 사이드에 붙은것을 알 수 있다.

현재 파란선은 이해를 돕기 위해 임시로 BorderLine을 추가해주었다.

그래서 버튼에 패딩을 준다.

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
                }
```

![CleanShot 2024-09-10 at 15 24 46@2x](https://github.com/user-attachments/assets/a01ce0c3-4ca1-4eb2-925d-6b19f0565bc1){: width="50%" height="50%"}

이렇게 trailing쪽에 패딩을 줌으로써 약간의 간격이 생겼다.

## Textfields 추가하기

현재는 Text로 해두고 위치만 설정 해두었는데 이제 Textfield로 바꾸어 입력이 가능하게 하자.

그전에 변수를 만들어 준다.

```swift
    @State var leftAmount = ""
    @State var rightAmount = ""
```

왼쪽 오른쪽 값을 받을 변수이다.

그리고 이제 Textfield를 추가해주자.


![CleanShot 2024-09-10 at 15 28 10@2x](https://github.com/user-attachments/assets/7132f409-2d69-4119-b36e-bf75e1e83828){: width="50%" height="50%"}

이때 여러가지 옵션이 있는데 우린 바로 첫번째것을 선택한다.

titleKey는 PlaceHolder이다.
text는 값이라고 간단하게 생각하면 되는데, UIKit처럼 바로 변수를 대입하는것은 아니다.

![CleanShot 2024-09-10 at 15 30 28@2x](https://github.com/user-attachments/assets/1000ced4-ec45-42ac-8d94-716721f65de0)

이렇게 바인딩 스트링 타입이 필요하다고 한다.

이전에 컴바인을 하면서 했던것 처럼 앞에 `$`를 붙여주면 된다.

그러면 값의 변화를 감지할것이다.

![CleanShot 2024-09-10 at 15 33 35@2x](https://github.com/user-attachments/assets/18f20bc8-8d97-4cf5-a984-7cc93cae8407){: width="50%" height="50%"}

하지만 입력을 어디에 해야하는지 보이지 않아서 이렇게 Modifier를 추가해준다.


```swift
TextField("Amount", text: $leftAmount)
                            .textFieldStyle(.roundedBorder)
```

![CleanShot 2024-09-10 at 15 32 44@2x](https://github.com/user-attachments/assets/1d625ebf-4dd7-4001-bced-6cf8873b9ab6){: width="50%" height="50%"}

우측도 똑같이 해주자.

![CleanShot 2024-09-10 at 15 34 46@2x](https://github.com/user-attachments/assets/5ecaeb10-e605-4386-b70b-417cb9d7d6d7){: width="50%" height="50%"}

Amount가 둘다 왼쪽에 붙어있어서 뭔가 이쁘지 않아 보인다.

우측의 placeholder는 우측에 붙이는게 어떨까?

```swift
// Textfield
                        TextField("Amount", text: $rightAmount)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
```

이렇게 `.multilineTextAlignment(.trailing)` Modifier를 통해 우측으로 붙여줄 수 있다.

![CleanShot 2024-09-10 at 15 36 16@2x](https://github.com/user-attachments/assets/41f5b205-e578-482d-8b27-b1bef24f68b4){: width="50%" height="50%"}

뭔가 이쁘게 정돈이 되었다.

그리고 패딩을 사용해서 간격을 좀 더 붙여본다.

```swift
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
                        .padding(.bottom, -5)
                        
                        // Textfield
                        TextField("Amount", text: $leftAmount)
                            .textFieldStyle(.roundedBorder)
                        
                    }
```

![CleanShot 2024-09-10 at 15 37 27@2x](https://github.com/user-attachments/assets/c1ff7d5a-0d22-4fe3-99ed-efecdb31ce09){: width="50%" height="50%"}

이렇게 before / after로 확인이 가능하다.

우측도 똑같이 해주자.

그리고 관련된 전체 Hstack부분에 

```swift
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
                        .padding(.bottom, -5)
                        
                        // Textfield
                        TextField("Amount", text: $leftAmount)
                            .textFieldStyle(.roundedBorder)
                        
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
                        .padding(.bottom, -5)
                        
                        // Textfield
                        TextField("Amount", text: $rightAmount)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        
                    }
                }
                .padding()
                .background(.black.opacity(0.5))
                .clipShape(.capsule)
```

투명도 0.5인 검은색을 배경화면으로 주고, 캡슐 모양으로 해서 좀 더 디자인 해보았다. (코드의 마지막 부분)

![CleanShot 2024-09-10 at 15 40 19@2x](https://github.com/user-attachments/assets/6970f98a-ae0e-494a-83e6-41d731199076){: width="50%" height="50%"}

이렇게 메인화면 디자인이 끝났다. 