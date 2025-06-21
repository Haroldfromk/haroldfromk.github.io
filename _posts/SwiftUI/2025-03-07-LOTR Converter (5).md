---
title: LOTR Converter (5)
writer: Harold
date: 2025-3-7 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

해당 강의를 잊고 있다가 마무리를 짓기 위해 작성한다.

[지난글](https://haroldfromk.github.io/posts/LOTR-Converter-(4)/){:target="_blank"}에 이어 몇달만에 다시하는 건지는 몰라도 내용자체는 어렵지 않기에 마무리를 짓는다.

## SelectCurrency View 만들기

![Image](https://github.com/user-attachments/assets/080a587c-58f8-4f68-8e8c-71f0b22fa890){: width="50%" height="50%"} 

위와 같은 View를 만들기위해 구상은 다음과 같이 한다.

```swift
struct SelectCurrency: View {
    
    var body: some View {
        ZStack {
            // Parchment background image
            
            VStack {
                // Text
                
                // Currency icons
                
                // Text
                
                // Currency icons
                
                // Done Button
            }
        }
    }
}
```

이렇게 어떤 View를 만들기전에 주석을 통해 미리 청사진을 그려놓으면 코드를 작성할때 훨씬 편리하다.

Done Button의 경우 지난글에서 했던 내용을 그대로 사용했기에 pass

Text부분도 대부분은 pass하고

`.multilineTextAlignment(.center)`부분만 적어보면, 글이 길어지면서 여러줄이 될때 배열을 가운데 정렬로 하게하는 내용의 modifier 이다.

알아두면 좋을듯

그리고 Image와 Text를 같이 사용하는 경우엔 너무나 당연하게도 Zstack 으로 사용 하면 되는데 이거하나만 언급을 해본다

바로 Modifer 순서의 중요성이다.

```swift
ZStack(alignment: .bottom) {
    // Currency image
    Image(.copperpenny)
        .resizable()
        .scaledToFit()
    
    // Currency name
    Text("Copper")
        .padding(3)
        .font(.caption)
        .frame(maxWidth: .infinity)
        .background(.brown.opacity(0.75))
}
.padding(3)
.frame(width: 100, height: 100)
.background(.brown)
.clipShape(.rect(cornerRadius: 25))
```

이렇게 한 결과의 이미지가 바로 아래와 같다.

![Image](https://github.com/user-attachments/assets/fe0692e8-ee4b-44cb-b0ae-73f00f651f18)

Background에 포커스를 하고 Background Modifier의 순서를 바꿔본다.

```swift
Text("Copper")
    .background(.brown.opacity(0.75)) // here
    .padding(3)
    .font(.caption)
    .frame(maxWidth: .infinity)
```

첫번째를 두고 하게되면

![Image](https://github.com/user-attachments/assets/f10d199a-73f0-4c05-a68c-31d37757276a)

이렇게 Text 부분에 대한 background만 된다.

그리고

```swift
Text("Copper")
    .padding(3)
    .background(.brown.opacity(0.75)) // here
    .font(.caption)
    .frame(maxWidth: .infinity)
```

이렇게 2번째에 두게 되면 (3번째도 동일)

![Image](https://github.com/user-attachments/assets/e251159a-e781-4612-9eda-2656c910c67b)

이렇게 padding도 적용된 범위까지 background가 적용이 된다.

참고하자!

하지만 이렇게 하나의 swift 파일에 text, image를 다 하게되면 코드가 길어진다.

```swift
struct SelectCurrency: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Parchment background image
            Image(.parchment)
                .resizable()
                .ignoresSafeArea()
                .background(.brown)
            
            VStack {
                // Text
                Text("Select the currency you are starting with:")
                    .fontWeight(.bold)
                // Currency icons
                ZStack(alignment: .bottom) {
                    // Currency image
                    Image(.copperpenny)
                        .resizable()
                        .scaledToFit()
                    
                    // Currency name
                    Text("Copper Penny")
                        .padding(3)
                        .background(.brown.opacity(0.75))
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .padding(3)
                .frame(width: 100, height: 100)
                .background(.brown)
                .clipShape(.rect(cornerRadius: 25))
                
                // Text
                Text("Select the currency you would like to convert to:")
                    .fontWeight(.bold)
                    
                // Currency icons
                
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
            .padding()
            .multilineTextAlignment(.center)
        }
    }
}
```

![Image](https://github.com/user-attachments/assets/d9cd1a36-3cfd-4481-bb41-755e7897433a){: width="50%" height="50%"} 

아이콘을 하나밖에 추가를 안했음에도 불구하고 길어진 코드들...

너무 비효율적이므로 Icon을 따로 관리하는 View를 만들어 준다면 코드관리도 용이하기에 새롭게 파일을 만들어 준다.

## Currency Icon

Modifier 순서의 중요성을 언급하며 작성했던 코드만 별개로 가져와서

CurrencyIcon이라는 View를 만들고 다음과 같이 해준다.

```swift
struct CurrencyIcon: View {
    let currencyImage: ImageResource
    let currencyName: String
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Currency image
            Image(currencyImage)
                // modifer 생략
            
            // Currency name
            Text(currencyName)
                // modifer 생략
        }
        // modifer 생략
    }
}
```

이제는 SelectCurrency에서 CurrencyIcon을 가져와서 Image와 Text에 값만 넣어주면 원하는 아이콘이 생성이 된다.

```swift
CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
```

이제 처음의 사진처럼 아이콘을 배치할건데 그냥 하는것이 아니다.

### Grid

**`Grid`** 를 사용해서 배치를 할것이다.

```swift
LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
    CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
    
    CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
    
    CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
    
    CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
    
    CurrencyIcon(currencyImage: .copperpenny, currencyName: "Copper Penny")
}
```

이렇게 하게되면

![Image](https://github.com/user-attachments/assets/68f729fd-0946-4518-a521-0873543eb94e){: width="50%" height="50%"} 

위와같이 배치가 되는데

columns에 GridItem()은 행에 몇개를 추가할것인지를 설정한다, 현재는 GridItem()이 3개이기 때문에 위와같이 한행에 3개가 배열이 되는 것이다.

만약 GridItem의 갯수를 4개로 한다면

![Image](https://github.com/user-attachments/assets/695f9182-7542-4059-ae64-f4a4ccdcad2a){: width="50%" height="50%"} 

이렇게 배치가 된다.

### ForEach

지금 CurrencyIcon의 경우 복붙으로 5개를 배치했는데(물론 안의 내용은 현재 수정하지 않았음) ForEach를 사용하여 조금 더 코드를 간소화한다.

그전에 Enum 을 통해 각 case에 대한 값을 미리 설정해둔다.

```swift
enum Currency: Double {
    case copperPenny = 6400
    case silverPenny = 64
    case silverPiece = 16
    case goldPenny = 4
    case goldPiece = 1
}
```

보통 enum 을 사용할때 값을 정하지는 않았지만 이렇게 각 case에 대해 값을 정할 수 있다. 물론 이때는 rawValue를 사용한다.

추가로 image, name도 computedproperty를 활용하기위해 작성해준다.

```swift
enum Currency: Double {
    // 생략
    
    var image: ImageResource {
        switch self {
        case .copperPenny: .copperpenny
        case .silverPenny: .silverpenny
        case .silverPiece: .silverpiece
        case .goldPenny: .goldpenny
        case .goldPiece: .goldpiece
        }
    }
    
    var name: String {
        switch self {
        case .copperPenny: "Copper Penny"
        case .silverPenny: "Silver Penny"
        case .silverPiece: "Silver Piece"
        case .goldPenny: "Gold Penny"
        case .goldPiece: "Gold Piece"
        }
    }
}
```

이렇게 해주자.

이제 ForEach를 사용하기위해 한가지 필요한 작업이 더 남았다.

바로 enum에 2가지 프로토콜을 채택해주어야 하는데 

`enum Currency: Double, CaseIterable, Identifiable` CaseIterable, Identifiable 이다.

[CaseIterable](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(5)/){:target="_blank"}, [Identifiable](https://haroldfromk.github.io/posts/Async_await-(4)/){:target="_blank"} 참고..

그리고 id가 필요한데

id는 
```swift
var id: Double { rawValue }
var id: Currency { self }
```

2가지 방법으로 사용이 가능하다.

#### 🔍 `Currency` 열거형의 `id` 속성 구현 비교

`Currency`가 `Identifiable`을 채택할 때, `id` 프로퍼티를 어떤 방식으로 정의하느냐에 따라 의미와 사용 방식이 달라진다.

---

##### ✅ 1. `rawValue`를 사용하는 경우

- **타입**: `Double`
- **값**: 각 case의 `rawValue` (예: 6400, 64 등)
- **용도**: 숫자 기반 비교나 정렬이 필요한 경우 유용
- **특징**:
  - 외부 시스템과 연동(예: 데이터베이스, API) 시 단순한 수치로 다루기 편리
  - 다만 동일한 `rawValue`를 가질 가능성이 있는 경우 식별자로 부적절할 수 있음

**장점**:
- 숫자 기반 정렬 및 비교에 용이  
- 외부 시스템과의 연동 시 직관적

**단점**:
- 타입 안전성이 낮음  
- 동일한 `rawValue`를 갖는 다른 타입과 충돌 위험 있음

---

##### ✅ 2. `self`를 사용하는 경우

- **타입**: `Currency`
- **값**: 해당 열거형 case 자체 (`self`)
- **용도**: SwiftUI 뷰 구성 등에서 안전하게 고유 식별자로 사용
- **특징**:
  - 각 case는 고유하므로 중복 우려가 없음
  - SwiftUI의 `ForEach`, `List`에서 식별자로 적합

**장점**:
- 타입 안전성 높음  
- 중복 가능성 없음  
- SwiftUI에서 가장 안정적으로 사용 가능

**단점**:
- 외부 시스템에서 수치 기반 처리 시 불편할 수 있음

---

#### 🏁 결론 요약

| 구현 방식       | 타입       | 장점                                | 단점                                  | 추천 상황                        |
|----------------|------------|-------------------------------------|---------------------------------------|----------------------------------|
| `rawValue` 사용 | `Double`   | 숫자 기반 정렬, 외부 연동 용이      | 타입 안전성 낮음, 중복 위험 있음     | 외부 시스템과 연동, 정렬 필요 시 |
| `self` 사용     | `Currency` | 타입 안전성 높음, 중복 없음         | 외부 시스템과 연동 불편 가능성 있음 | SwiftUI 내부 식별자용으로 적합   |

---

#### 주의사항
⚠️ `rawValue` 중복 관련 정리

Swift에서 `rawValue`가 중복되면 **컴파일 에러가 발생**한다.  
이는 `Int`, `Double`, `String` 등 모든 `RawRepresentable` 타입에서 동일하게 적용된다.

예시:

```swift
enum Currency: Double {
    case silverPenny = 64
    case fakeSilverPenny = 64 // ❌ 에러 발생
}
```

- 에러 메시지: `Raw value for enum case is not unique`
- 중복된 rawValue를 가진 case가 있을 경우, 열거형 자체가 유효하지 않음
- 따라서 `id = rawValue`로 사용할 경우 모든 case가 **고유한 rawValue**를 갖도록 주의해야 한다

**안전한 대안**:
- 중복 가능성이 있거나 rawValue를 통제하기 어렵다면  
  `id = self`처럼 열거형 case 자체를 식별자로 사용하는 방식이 더 안전하다
  - 여기서 id = self는 `var id: Currency { self }` 이걸 의미

---

다시 돌아와서 ForEach문을 다음과 같이 작성해주자

```swift
ForEach(Currency.allCases) { currency in
    CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
}
```

그러면

![Image](https://github.com/user-attachments/assets/76acad63-f369-4029-abb0-f86752e240ab){: width="50%" height="50%"} 

이렇게 우리가 enum을 통해 만들어둔 순서대로 만들어 진다.

그리고

```swift
ForEach(Currency.allCases) { currency in
    CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
        .shadow(color: .black, radius: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 25)
                .stroke(lineWidth: 3)
                .opacity(0.5)
        }
}
```


![Image](https://github.com/user-attachments/assets/447b000d-d60b-4343-bfe8-9bc7d1c6efb2){: width="50%" height="50%"} 

이렇게 디자인을 해준다

### Select Icon

이제 아이콘을 선택했을때 효과를 주기로 하자.

우리가 위의 디자인을통해 shadow와 overlay 효과를 준건 아이콘은 탭했을때 효과를 주기 위함이었다.

우선 변수를 하나 만들어준다 `@State var currency: Currency`

물론 currency 대신 selectedCurrency로 해도 된다. (여기서 그냥 사용한 이유는 `self`를 사용하기 위함.)

우선 if 문을 사용하는데

```swift
// 1
ForEach(Currency.allCases) { currency in
    if currency == currency {
    // 생략
    }
}

// 2
ForEach(Currency.allCases) { currency in
    if self.currency == currency {
    // 생략
    }
}
```

1, 2의 결과가 다르다.
1의 경우에는
![Image](https://github.com/user-attachments/assets/1b296c9b-84be-477d-90d6-5116067b6069){: width="50%" height="50%"} 

이렇게 5개 전부가 나오는 반면

2의 경우엔
![Image](https://github.com/user-attachments/assets/cf8bf4bd-9890-4680-91fb-050b4adca5f8){: width="50%" height="50%"} 

이렇게 1개만 보이게 된다.

이건 self를 붙임으로써 currency가 어떤걸 가르키냐의 차이인데

1의 경우엔 ForEach 내부에 있는 currency를 가르키기에 5개 전부가 나오게 되는것이고, 2의 경우엔 self가 붙음으로써 우리가 `@State` Wrapper를 사용하여 만든 currency 변수가 적용이 되는 것이다.

이런 차이 때문에 일반적으로 선택 여부를 판단할 때는, **ForEach 클로저의 매개변수 이름을 currency가 아닌 다른 이름으로 지정** 해주는 것이 혼동을 줄이고 코드 가독성도 높여준다.

현재는 1개만 보이기에 else를 통해서 전체 아이콘을 전부 보여지게 해준다.

```swift
else {
    CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
}
```

하지만 이렇게만 해두면 우리가 선택을 해도 아이콘이 Effect가 변하지 않는다.

![Image](https://github.com/user-attachments/assets/1d79c302-cb64-4f07-a038-a20fccc34a41){: width="50%" height="50%"} 

이제 `onTapGesture` Modifier를 사용한다.

```swift
CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
    .onTapGesture {
        self.currency = currency
    }
```

아이콘을 탭했을때 우리가 위에 만들어둔 currency변수 값에 현재 선택한 currency로 적용해준다는 것이다.

실행해보면

![Image](https://github.com/user-attachments/assets/dde7a62c-6fc4-4a37-b685-213aba1ee19e){: width="50%" height="50%"}

이렇게 잘 적용이 되는걸 알 수 있다.

해당 부분의 최종 코드

```swift
LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
    ForEach(Currency.allCases) { currency in
        if self.currency == currency {
            CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
                .shadow(color: .black, radius: 10)
                .overlay {
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(lineWidth: 3)
                        .opacity(0.5)
                }
        } else {
            CurrencyIcon(currencyImage: currency.image, currencyName: currency.name)
                .onTapGesture {
                    self.currency = currency
                }
        }
    }
}
```