---
title: LOTR Converter (fin)
writer: Harold
date: 2025-3-15 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## modifier 정리 및 추가 문제 수정

![Image](https://github.com/user-attachments/assets/25f1abb8-0284-40a1-b420-5887bcb65ac0){: width="50%" height="50%"} 를 보면 알겠지만 값이 입력된 상태에서 Currency를 바꾸면 값이 변경되지 않는다.

이제 이부분을 보완해본다.

우선 sheet가 있는 부분에 text field의 onchange modifier를 옮겨주고

```swift
.onChange(of: leftAmount) {
    if leftTyping {
        // 생략
    }
}
.onChange(of: rightAmount) {
    if rightTyping {
        // 생략
    }
}
.onChange(of: leftCurrency) { // new
    leftAmount = rightCurrency.convert(rightAmount, to: leftCurrency)
}
.onChange(of: rightCurrency) { // new
    rightAmount = leftCurrency.convert(leftAmount, to: rightCurrency)
}
.sheet(isPresented: $showExchangeInfo) {
    // 생략
}
.sheet(isPresented: $showSelectCurrency) {
    // 생략
}
```

![Image](https://github.com/user-attachments/assets/374d3fc7-035c-4ebb-8db7-da3a50124163){: width="50%" height="50%"} 

이렇게 값이 변하게 된다.

## 키보드 타입 고정하기

현재는 키보드의 별도 타입이 설정되어있지않아 일반적인 qwerty 키보드가 나오게 되는데 물론 현재 입력받는 값을 String으로 해놔서 에러가 발생하지는 않지만, Numpad만 나오게 고정을 하여 미리 방지를 하도록 하자

![Image](https://github.com/user-attachments/assets/86a32994-977d-4876-82c7-ce87a6a0d8a9){: width="50%" height="50%"} 

현재의 키보드

```swift
// 
HStack {
    // 생략
}
.padding()
.background(.black.opacity(0.5))
.clipShape(.capsule)
.keyboardType(.numberPad) // new
```

![Image](https://github.com/user-attachments/assets/968375e5-53e8-4482-a827-2f6ca472de82){: width="50%" height="50%"} 

바뀐 키보드

그리고 현재 가로모드에 대해서 별도의 작업을 하지 않았기에, 

![Image](https://github.com/user-attachments/assets/57f79aed-0d35-4902-bb72-b25a711aec03)

이렇게 체크를 풀어서 세로모드만 유지하도록 한다.

## Tip Kit

**TipKit?**
- **TipKit**은 사용자가 앱을 효과적으로 사용할 수 있도록 **간단한 팁(도움말)**을 보여주는 Apple의 프레임워크이다.  
- iOS 17 이상에서 사용 가능하며, SwiftUI와 통합되어 자연스러운 사용자 경험을 제공한다.

**주요 특징**
- 사용자 행동에 따라 **조건부로 팁을 보여줌**
- **애플 스타일**의 깔끔한 UI
- 표시 여부는 **자동으로 추적되고 관리됨**
- `.popoverTip()`과 함께 사용 가능

**필수 구성 요소**

- `Tip`을 정의한 구조체  
- `Tips.configure()` → 앱 시작 시 초기화 필수
- `.popoverTip(...)` → 팁을 표시할 위치를 설정

**`Tips.configure()`**
- TipKit 시스템을 초기화하는 함수이다  
- 앱에서 **팁이 화면에 표시되기 전에 반드시 한 번 호출해야 한다**
- 보통 `.task` 내부에서 앱 실행 시점에 호출한다

[Docs](https://developer.apple.com/documentation/tipkit/){:target="_blank"}는 여기


```swift
import TipKit

struct CurrencyTip: Tip {
    var title = Text("Change Currency")
    
    
}
```

실제로 Tip이라는 프로토콜이 존재...

그리고 해당 프로토콜을 채택할 경우 반드시 title이 들어가야한다. 어차피 없으면 에러가 발생하면서 missing을 클릭하면 자동으로 title이 만들어진다.

![Image](https://github.com/user-attachments/assets/7096ed8b-7a54-4d69-b580-d06f35477e38)

위의 사진을 보면 알듯 아래 2개는 Optional이어서 없어도 그만인데, Title의 경우는 반드시 있어야 한다.

그리고 **Docs에 보면 변수의 type을 optional로 설정하고 Default Value를 설정하지 않는다면 기본적으로 nil값을 가진다.**

무튼 아래와 같이 작성을 해주었다.

```swift
import TipKit

struct CurrencyTip: Tip {
    var title = Text("Change Currency")
    
    var message: Text? = Text("You can tap the left or right currency to bring up the Select Currency screen.")
    
    var image: Image? = Image(systemName: "hand.tap.fill")
}
```

이제 TipKit을 사용하기 위해 ConetentView로 돌아간다.

```swift
import TipKit

let currencyTip = CurrencyTip()
```

TipKit을 사용하기위해 import와 property를 만들어 주었다.

그리고 onTapGesture의 아래에 `popoverTip` Modifier를 사용해준다.

```swift
    .onTapGesture {
        showSelectCurrency.toggle()
        currencyTip.invalidate(reason: .actionPerformed) // new
    }
    .popoverTip(currencyTip, arrowEdge: .bottom) // new
}
.task { // end of Vstack
    try? Tips.configure()
}
```

### TipKit 핵심 정리

#### `.popoverTip(_:arrowEdge:)`

- 뷰에 **Tip을 말풍선 형태로 표시**하는 Modifier  
- `arrowEdge`는 말풍선의 **화살표가 연결되는 뷰의 방향(엣지)**을 지정함  
- 예시:
`.popoverTip(currencyTip, arrowEdge: .bottom)`
→ 팁이 뷰 **위쪽에 표시되고**, 화살표는 **아래쪽을 향함**

⚠️ **주의**:  
`arrowEdge`는 **우선 요청값**일 뿐이며,  
**시스템(SwiftUI)**이 **화면 공간과 레이아웃 상황에 따라 자동으로 위치를 조정**할 수 있음 from Docs
즉, `.bottom`을 지정해도 공간이 부족하면 다른 방향으로 표시될 수 있음

---

#### `.invalidate(reason:)`

- 팁의 **노출 조건을 무효화**하거나 **사용 완료 처리**
- 예시:
`currencyTip.invalidate(reason: .actionPerformed)`
→ 사용자가 팁 대상 액션을 수행했을 때 다시 보이지 않도록 설정
→ 다시 보려면 앱을 삭제하고 재설치를 해야한다.

---

#### `Tips.configure()` 

- TipKit 시스템을 초기화  
- 앱 실행 시 한 번만 호출하면 됨  
- 예시:
```swift
.task {
    try? Tips.configure()
 }
```
→ TipKit 팁 로직이 정상 작동할 수 있도록 설정됨

> 📌 참고:
이 함수는 팁이 표시되기 전에 호출되어야 한다. 그렇지 않으면 팁이 제대로 작동하지 않을 수 있다. (출처: Apple Docs)
따라서 .task를 사용해 뷰가 등장하기 전에 실행되도록 구성하는 것이 일반적이다.
---

### 전체 흐름 요약
1. 앱 시작 시 `Tips.configure()`로 초기화  
2. `.popoverTip()`으로 뷰에 팁 연결  
3. 사용 후 `.invalidate()`로 팁 노출 종료


![Image](https://github.com/user-attachments/assets/c9e783c4-6882-4499-9b40-f67644e6b0eb){: width="50%" height="50%"} 

이렇게 Tip이 보이게 된다.

---

## Challenge

### 💻 코딩 챌린지 요약 (총 4가지)

#### 1️⃣ 새로운 화폐 추가
- 현재 앱에는 5개의 화폐가 있음
- 사용자가 **6번째 화폐**를 자유롭게 추가  
  - 이름, 이미지, 환율 (gold piece 기준) 자유 설정 가능
- 구조상 코드 추가는 많지 않음

---

#### 2️⃣ 사용자 선택 상태 저장 (Persistence)
- 앱을 완전히 종료하면 선택된 화폐가 초기값으로 초기화됨
- 사용자가 선택한 화폐 상태를 **영구적으로 저장**하도록 구현  
- 🔍 힌트: `UserDefaults` 사용 고려

---

#### 3️⃣ 키보드 숨기기 기능 추가
- 텍스트 입력 후 화면을 터치해도 키보드가 계속 보이는 문제 발생
- 사용자가 입력을 마쳤을 때 **키보드를 자동으로 숨기도록 개선**
- 🔍 힌트: `@FocusState` 활용 가능

---

#### 4️⃣ ContentView 리팩터링
- 좌/우 화폐 선택 영역 코드가 **거의 동일**  
- 중복 제거를 위해 **CurrencySection 뷰로 분리**  
  - ContentView에 **재사용 형태로 두 번 배치**

---

### ✅ 추가 팁
- 난이도는 1 → 4 순서 (점점 어려워짐)
- 너무 어렵다면 **다음 강의로 넘어간 뒤 다시 시도**해도 괜찮음
- 직접 챌린지를 만들어 보거나, 커뮤니티에 공유하는 것도 추천!

이건 이후에 별도로 글을 작성해보면 좋을듯