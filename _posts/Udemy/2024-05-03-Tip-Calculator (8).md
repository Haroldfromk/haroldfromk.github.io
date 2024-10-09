---
title: Tip-Calculator (8)
writer: Harold
date: 2024-05-03 23:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## Add image Snapshot test

> Snapshot Test
>> 간단하게 말해서 디자인 시안대로 UI를 잘 구현했는가에 대한 테스트

[Snapshot Test Github](https://github.com/pointfreeco/swift-snapshot-testing){:target="_blank"}

여기에 들어가면 readme에 설명이 있다.

이 라이브러리를 사용해서 테스트를 한다.

```swift
import XCTest
import SnapshotTesting
@testable import tip_calculator

final class tip_calculatorSnapshotTests: XCTestCase {
    
    private var screenWidth: CGFloat {
        return UIScreen.main.bounds.size.width
    }
    
    func testLogoView() {
        // given
        let size = CGSize(width: screenWidth, height: 48)
        
        
        // when
        let view = LogoView()
        
        // then
        assertSnapshot(matching: view, as: .image(size: size), record: true)
        
    }
}
```

record를 true하면서 Logoview에 대한 이미지가 생긴다.

![May-03-2024 23-19-53](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1a12d6a7-73ee-4ca8-a4d2-5e444632e35e)

![CleanShot 2024-05-03 at 23 20 44@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/52e68079-6d01-48df-96d5-9b0633f43146){: width="50%" height="50%"}

이제 이사진을 가지고 비교를 하게된다..

**그래서 record를 true하여 원본 사진을 남겨놔야한다.**

만약 누가 logoview의 디자인을 수정했다면?

```swift
 private let topLabel: UILabel = {
        let label = UILabel()
        let text = NSMutableAttributedString(string: "Mr TIPs",attributes: [.font: ThemeFont.demibold(ofSize: 16)])
        text.addAttributes([.font: ThemeFont.bold(ofSize: 24)], range: NSMakeRange(3, 3)) // TIP부분 더 강조
        label.attributedText = text
        return label
    }()
```

`Mr TIP → MR TIPs`로 변경

그리고 테스트를 하면?

![CleanShot 2024-05-03 at 23 24 02@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/26425963-ce89-4c3f-8025-4a2b5e4f526d)

에러 발생.

![CleanShot 2024-05-03 at 23 24 53@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e3a2f29b-08b0-475d-a61e-449035cb0f4d)

그 경로에 있는 이미지파일을 실행해서 비교해보면?

위에 있는게 변형한것,

아래있는게 오리지널

디자인의 변화가 생겨서 Test Fail이 발생한다.

### Result View Test

```swift
func testInitialResultView() {
        // given
        let size = CGSize(width: screenWidth, height: 224)

        // when
        let view = ResultView()
        
        // then
        assertSnapshot(matching: view, as: .image(size: size), record: true)
    }
```

이렇게 이미지를 만들어주고

record를 지우고 실행.

### Tip Input View Test

```swift
func testInitialTipInputView() {
        // given
        let size = CGSize(width: screenWidth, height: 56+56+16)

        // when
        let view = TipInputView()
        
        // then
        assertSnapshot(matching: view, as: .image(size: size))
    }
```

### Bill Input View Test

```swift
func testInitialBillInputView() {
        // given
        let size = CGSize(width: screenWidth, height: 56)

        // when
        let view = BillInputView()
        
        // then
        assertSnapshot(matching: view, as: .image(size: size))
    }
```

### Split Input View Test

```swift
func testInitialSplitInputView() {
        // given
        let size = CGSize(width: screenWidth, height: 56)

        // when
        let view = SplitInputView()
        
        // then
        assertSnapshot(matching: view, as: .image(size: size))
    }
```

## Custom Value로 Snapshot Test

[StackOverFlow](https://stackoverflow.com/questions/32151637/swift-get-all-subviews-of-a-specific-type-and-add-to-an-array/45297466#45297466){:target="_blank"} 참고

```swift
func testResultViewWithValues() {
        // given
        let size = CGSize(width: screenWidth, height: 224)
        let result = Result(
            amountPerPerson: 100.25,
            totalBill: 45,
            totalTip: 60)
        
        // when
        let view = ResultView()
        view.configure(result: result)
        
        // then
        assertSnapshot(matching: view, as: .image(size: size), record: true)
    }
```

![testResultViewWithValues 1](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/21096e95-2b22-4a26-8c72-6b9b2e86df77){: width="50%" height="50%"}

이렇게 값이 입력된 view가 생성됨.

### BillInputView test

그전에 위의 스택오버플로우 사이트에서 extension을 적용


```swift
func testBillInputViewWithValues() {
        // given
        let size = CGSize(width: screenWidth, height: 56)

        // when
        let view = BillInputView()
        let textField = view.allSubViewsOf(type: UITextField.self).first
        textField?.text = "500"
        // then
        assertSnapshot(matching: view, as: .image(size: size))
    }
```
그리고
```swift
let textField = view.allSubViewsOf(type: UITextField.self).first
textField?.text = "500"
```

여기서 Extension을 사용하는데 

![testBillInputViewWithValues 1](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/cda6b596-68a6-4a48-bc06-3ee4e3edddb6){: width="50%" height="50%"}

이렇게 실제로 입력된것처럼 보인다.

### TipInput View Test

```swift
func testTipInputViewWithValues() {
        // given
        let size = CGSize(width: screenWidth, height: 56+56+16)
        
        // when
        let view = TipInputView()
        let button = view.allSubViewsOf(type: UIButton.self).first
        button?.sendActions(for: .touchUpInside)
        // then
        assertSnapshot(matching: view, as: .image(size: size))
}
```

![testTipInputViewWithValues 1](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/81ace4d0-48be-4bd4-8d18-3de66c2aa5e6){: width="50%" height="50%"}

역시나 선택 된 것처럼 구현이 가능.

### SplitInputView Test

```swift
func testSplitInputViewWithSelection() {
        // given
        let size = CGSize(width: screenWidth, height: 56)
        
        // when
        let view = SplitInputView()
        let button = view.allSubViewsOf(type: UIButton.self).last
        button?.sendActions(for: .touchUpInside)
        // then
        assertSnapshot(matching: view, as: .image(size: size))
    }
```

여기서 button의 first를 하게되면 - 버튼을 클릭하는데 숫자의 변화가 없기에 last를 선택하여 + 버튼이 클릭되는 이벤트가 보여지게 한다.

이렇게 snapshot test를 할 수 있다.

포인트는 먼저 `record: true`를 하고, 원본을 저장하고 이후에 ui를 재확인할때 하면 좋을듯 하다.