---
title: LOTR Converter (6)
writer: Harold
date: 2025-3-11 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Grid 부분 별도로 추출

이전글에서 최종 코드로 적었던 부분을 IconGrid로 별도의 View로 만들어 준다.

코드의 간소화를 위함이다.

```swift
struct SelectCurrency: View {
    // 생략
    var body: some View {
        ZStack {
        // 생략
            VStack {
            // 생략
            // Currency icons
                IconGrid(currency: currency)
            // 생략
            }
        // 생략
        }
    }
}
```

별도로 추출한 이유는 

![Image](https://github.com/user-attachments/assets/a3dbbfaa-9cc5-434d-a9b4-327338f89e7d){: width="50%" height="50%"} 

첫화면을 보면 알듯이 좌,우 currency를 다르게 해서 convert를 하기 때문.

그래서 IconGrid를 만들어서 아래에도 똑같은 grid를 만들어 준다.

이제 변수도 이렇게 해주자

```swift
@State var leftCurrency: Currency
@State var rightCurrency: Currency
```

## select currency sheet 띄우기 및 값 적용하기

그리고 처음에 ContentView에도 하드코딩이 되어있는데 이제 이부분도 바꿔줘야한다.

왜냐면 Currency를 선택했을때 그에 맞는 이미지와 Text가 나와야하기 때문이다.

또한 우리가 만든 SelectCurrency 창이 나와야 하기에 코드를 아래와 같이 추가 및 수정하자. (수정하면서 SelectCurrenct의 leftCurrency는 topCurrency로 right는 bottom으로 수정)

```swift
struct ContentView: View {
    // 생략
    @State var showSelectCurrency = false
    @State var leftCurrency = Currency.silverPiece
    @State var rightCurrency: Currency = .goldPiece
    
    var body: some View {
        ZStack {
           // 생략
            VStack {
                // 생략
                HStack {
                    // Left conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency image
                            Image(leftCurrency.image) // changed
                                // 생략
                            // Currency text
                            Text(leftCurrency.name) // changed
                                // 생략
                        }
                        .onTapGesture {
                            showSelectCurrency.toggle()
                        } // new
                       // 생략
                    }
                    // 생략
                    // Right conversion section
                    VStack {
                        // Currency
                        HStack {
                            // Currency text
                            Text(rightCurrency.name) // changed
                                // 생략
                            
                            // Currency image
                            Image(rightCurrency.image) // changed
                                // 생략
                        }
                        .onTapGesture {
                            showSelectCurrency.toggle()
                        } // new
                        // 생략
                    }

                    // Info Button
                HStack {
                    Spacer()
                    // 생략
                }
               // 생략
        }
    }
    .sheet(isPresented: $showExchangeInfo) {
                        ExchangeInfo()
                    }
    .sheet(isPresented: $showSelectCurrency) {
        SelectCurrency(topCurrency: leftCurrency, bottomCurrency: rightCurrency)
}
```

이렇게 바꿔주자.

실행하면

![Image](https://github.com/user-attachments/assets/c46141a2-dbb6-49ad-a46d-26fc62ca8098){: width="50%" height="50%"} 

이렇게 나온다.

하지만 사진을 보면 알겠지만 선택을 하고 돌아와도 변하지 않는다

이유는 뭘까?
> 바로 selectCurrency view에서 ContentView로 값을 전달하지는 않았기 때문이다.
> 현재는 `@State var topCurrency: Currency = .silverPiece` 이런식으로 값을 그대로 고정을 해둔 상태이다.

이 문제를 해결하기위해 `@Binding` Wrapper를 사용한다.

이전에 currency가 있던 부분이 전부 `@State`로 되어있었는데 전부 `@Binding`으로 바꿔준다.

이때 preview쪽에 에러가 발생하는데

```swift
#Preview {
    @Previewable @State var topCurrency: Currency = .silverPenny
    @Previewable @State var bottomCurrency: Currency = .goldPenny
    
    SelectCurrency(topCurrency: $topCurrency, bottomCurrency: $bottomCurrency)
}
```

이런식으로 `@Preiviewable`을 사용해서 별도의 변수를 만들어 적용을 해주자.

그리고 Binding으로 변수가 만들어지면 해당 변수가 적용되는 부분에 반드시 `$`가 붙어야한다.

`IconGrid(currency: $topCurrency)` 이런식으로.

간단하게 Wrapper를 바꾼 이유를 적어본다면

### ✅ `@State` vs `@Binding` 차이 요약
| 속성 래퍼 | 역할 | 소유권 | 값 변경 시 | 주 사용 위치 |
|------------|------|--------|------------|---------------|
| `@State`   | 상태를 소유하고 관리함 | 자신(뷰) | 뷰가 다시 렌더링됨 | 부모 뷰 |
| `@Binding` | 다른 뷰의 상태를 참조함 | 다른 뷰(`@State`) | 참조한 원본 값이 변경됨 | 자식 뷰에서 전달받아 사용 |

---

#### 🔍 핵심 차이
- `@State`: **상태의 원본**  
  → 해당 뷰에서 직접 소유하고 값을 관리

- `@Binding`: **상태의 참조**  
  → 다른 뷰(`@State`)에서 전달된 값을 읽고, 수정할 수 있음

쉽게 말해서 
부모 뷰가 `@State`로 상태를 가지고 있고, 자식 뷰는 `@Binding`으로 그 값을 **공유받아** 쓴다.

즉, **자식 뷰에서 값을 바꾸면 부모 뷰의 값도 함께 바뀐다** → 이게 바로 `@Binding`의 핵심 기능이다.

---

## 값을 계산하는 함수 만들기

이제 값을 입력했을때 우리가 enum을 통해 설정한 값으로 계산을 해주는 함수를 만들어 본다.

```swift
enum Currency: Double, CaseIterable, Identifiable {
    // 생략
    func convert(amountString: String, currency: Currency) -> String {
        guard let doubleAmount = Double(amountString) else {
            return ""
        }
        
        let convertedAmount = (doubleAmount / self.rawValue) * currency.rawValue
        
        return String(format:"%.2f", convertedAmount)
    }
}
```

format의 경우 링크를 예전에 걸었던걸로 기억하는데 이번엔 [다른링크](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html){:target="_blank"}를 올려보니 참고

## 함수 적용하기

이제 함수를 만들었다면 ContentView에 함수를 적용해보도록 한다.

왼쪽의 TextField에 값을 입력하면 우측의 TextField에 자동으로 값이 바뀌어야 한다. 물론 우측에서도 좌측의 값이 바뀌게 할 예정

이때 우리가 사용할 Modifier는 바로 `onChange`이다.

```swift
// left textfield
TextField("Amount", text: $leftAmount)
    .textFieldStyle(.roundedBorder)
    .onChange(of: leftAmount) {
        rightAmount = leftCurrency.convert(amountString: leftAmount, currency: rightCurrency)
    }
```

![Image](https://github.com/user-attachments/assets/017d9d65-7b50-4c64-a01d-4e6be9c72f37){: width="50%" height="50%"} 

이렇게 값이 변하는걸 알 수 있다.

### 함수의 파라미터명을 바꾸기

이건 이전에 해봤던건데 리마인드겸 적어본다.

[Docs](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions#Function-Argument-Labels-and-Parameter-Names){:target="_blank"}는 여기

함수 파라미터 앞에

```swift
func convert(_ amountString: String, to currency: Currency) -> String {
   // 생략
}
```

`_, to` 만 붙여주었다.

이제 contentview로 가서 `rightAmount = leftCurrency.convert(leftAmount, to: rightCurrency)` 이렇게 바꿔주면 조금 더 함수를 보았을때 직관적으로 이해가 된다.

이제 이렇게 우측 TextField에도 똑같이 적용을 해보도록 한다.

코드는 생략

## FocusState Wrapper를 통해 문제 해결하기

하지만 여기서 문제가 발생

우리가 예를들어 Silver Piece, Gold Piece가 된 상태에서 왼쪽에 5를 입력해도

4.96/0.31 이라는 결과 값이 나온다.

즉 우리가 왼쪽에서 값을 입력을 하면 좌,우 text field의 onchange modifier가 동시에 작동하면서 꼬이게 된다.

보이지 않는 boolean property가 있는데 우리가 textfield에 탭을 하지 않을 경우 그 프로퍼티의 값은 false가 된다.

우리가 text field에 탭을 해서 커서가 생기는경우 해당 text field의 invisible property는 true가 된다.

이걸 조금더 명확하게 코드에서 가시작으로 표현하기 위해 우리는 `@FocusState` Wrapper를 사용해보려고 한다.

그리고 `focused` Modifier도 사용한다.

```swift
@FocusState var leftTyping
@FocusState var rightTyping

TextField("Amount", text: $leftAmount)
    .textFieldStyle(.roundedBorder)
    .focused($leftTyping) // new
    .onChange(of: leftAmount) {
        if leftTyping { // new
            rightAmount = leftCurrency.convert(leftAmount, to: rightCurrency)
        }
    }
```

### ✅ `@FocusState` vs `.focused()` 정리

- `@FocusState`: 특정 뷰(주로 TextField)가 **포커스를 가지고 있는지 추적**하고 제어할 수 있게 해주는 속성 래퍼  
- `.focused()`: 해당 뷰가 **어떤 FocusState 변수와 연결되어 있는지를 바인딩**하는 Modifier

이 둘은 함께 사용되어 **어떤 TextField가 현재 입력 중인지 구분하고**,  
그에 따라 `onChange`나 기타 UI 반응을 **정확하게 제어할 수 있다.**

---

#### 🔍 예시

```swift
@FocusState var leftTyping

TextField("Amount", text: $leftAmount)
    .focused($leftTyping)
    .onChange(of: leftAmount) {
        if leftTyping {
            // 사용자가 실제 입력 중일 때만 처리
        }
    }
```

- 사용자가 해당 TextField를 탭하면 `leftTyping = true`가 되고,
- 포커스를 잃으면 `leftTyping = false`가 된다

이런 방식으로 좌/우 입력 필드가 **서로 영향을 주지 않도록 분리된 입력 제어**가 가능하다.

---

동일한 방법으로 우측 textfield도 적용해준다.

이렇게 문제를 해결 할 수 있다.
