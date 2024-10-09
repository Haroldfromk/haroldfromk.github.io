---
title: Tip-Calculator (9)
writer: Harold
date: 2024-05-04 10:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## UI Test

[Hacking with Swift](https://www.hackingwithswift.com/articles/148/xcode-ui-testing-cheat-sheet){:target="_blank"}
에서 어떤 property를 사용할지 확인이 가능하다.

파일을 하나 만들어준다.

![CleanShot 2024-05-04 at 10 49 25@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/52f31e54-2650-4d74-950c-363842cf3815)

UITest를 체크를 꼭 하자.

이 파일은 일종의 Constants를 관리한다.

```swift
enum ScreenIdentifier {
    
    enum ResultView: String {
        case totalAmountPerPersonValueLabel
        case totalBillValueLabel
        case totalTipValueLabel
    }
}
```

이렇게 ResultView에 대한 identifier를 열거형을 통해 만들어준다.

그리고 ResultView로 돌아가서,

```swift
 private let amountPersonLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        let text = NSMutableAttributedString(
            string: "$0",
            attributes: [
                .font: ThemeFont.bold(ofSize: 48)
            ]
        )
        // $ 부분만 작게
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 24)
        ], range: NSMakeRange(0, 1))
        label.attributedText = text
        label.accessibilityIdentifier = ScreenIdentifier.ResultView.totalAmountPerPersonValueLabel.rawValue // added
        return label
    }()
```

이렇게 Identifier를 통해 접근할수있게 해준다.

나머지 tip, bill은 AmountLabel을 통해 만들어졌으므로

다시 AmountLabel로 가서

```swift
private let amountLabelIdentifier: String // added

    private lazy var amountLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = textAlignment
        label.textColor = ThemeColor.primary
        let text = NSMutableAttributedString(
            string: "$0",
            attributes: [
                .font: ThemeFont.bold(ofSize: 24)
            ])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 16)
        ], range: NSMakeRange(0, 1))
        label.attributedText = text
        label.accessibilityIdentifier = amountLabelIdentifier // added
        return label
    }()
    
```

이렇게 일종의 dependency를 만들어 주었다.

그리고 뜨는 initializer 부분의 에러

```swift
// custom Initializer
    init(title: String, textAlignment: NSTextAlignment, amountLabelIdentifier: String) { // modified
        self.title = title
        self.textAlignment = textAlignment
        self.amountLabelIdentifier = amountLabelIdentifier // added
        super.init(frame: .zero)
        layout()
    }
```

여기에도 identifier를 추가.

여기에 추가하게되면 우리가 Resultview에서 AmountLabel을 사용하는 label도 그대로 init을 다시 해주면 된다.

![CleanShot 2024-05-04 at 12 39 58@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2bf75fbf-d75a-4369-8b02-c0fa843a9af4)

친절하다.

```swift
private let totalBillView: AmountView = {
       let view = AmountView(
            title: "Total Bill",
            textAlignment: .left,
            amountLabelIdentifier: ScreenIdentifier.ResultView.totalBillValueLabel.rawValue) // added
        return view
    }()
    
    private let totalTipView: AmountView = {
       let view = AmountView(
            title: "Total Tip",
            textAlignment: .right,
            amountLabelIdentifier: ScreenIdentifier.ResultView.totalTipValueLabel.rawValue) // added
        return view
    }()
```

그리고 런치 테스트는 필요없으니까 쓰레기통

![CleanShot 2024-05-04 at 12 41 30@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/7f224f50-f66a-4bf9-a1f4-f40a1b7b6618){: width="50%" height="50%"}

그리고 uitests파일 역시 지난번 test처럼 내부 함수는 다 지워준다.

```swift
import XCTest

final class tip_calculatorUITests: XCTestCase {

   
}

```

새로운 파일을 생성해준다 CaculatorScreen이라는 class 파일을 하나 생성을 해주었고,

```swift
import XCTest

class CalculatorScreen {
    
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    var amountPerPersonValueLabel: XCUIElement {
        return app.staticTexts[ScreenIdentifier.ResultView.totalAmountPerPersonValueLabel.rawValue]
    }
    
    var totalBillValueLabel: XCUIElement {
        return app.staticTexts[ScreenIdentifier.ResultView.totalBillValueLabel.rawValue]
    }
    
    var totalTipValueLabel: XCUIElement {
        return app.staticTexts[ScreenIdentifier.ResultView.totalTipValueLabel.rawValue]
    }
}

```

다음과 같이 적었다.

app instance를 하나 만들어 주었고 initialize를 한뒤,

각각의 label을 만들어 주는데, 이때 아까전에 설정해둔 Identifier를 통해 우리가 접근을 가능하게 한다.

다시 uitest로 돌아가서,

```swift
final class tip_calculatorUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    private var screen: CalculatorScreen {
        CalculatorScreen(app: app)
    }
   
    override func setUp() {
        super.setUp()
        app = .init()
        app.launch()
    }
    
    override func tearDown() {
        super.tearDown()
        app = nil
    }
    
    func testResultViewDefaultValues() {
        XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$0")
        XCTAssertEqual(screen.totalBillValueLabel.label, "$0")
        XCTAssertEqual(screen.totalTipValueLabel.label, "$0")
    }
}

```

다음과 같이 작성을 해준다.

그리고 테스트를 돌리니 pass

그런데 저기서 value의 $0을 $1로 바꾸면 에러가 발생,

왜냐 초기화면에서는 전부 $0 으로 되어있어서 같지 않기 때문.

testResultViewDefaultValues의 함수는 ui의 resultview label의 초기화면 값이 설정한 값과 같은지를 테스트한다.

## 모든 Identifier 추가.

다시 ScreenIdentifier로 돌아가서,

```swift
enum ScreenIdentifier {
    
    enum LogoView: String { // added
        case logoView
    }
    
    enum ResultView: String {
        case totalAmountPerPersonValueLabel
        case totalBillValueLabel
        case totalTipValueLabel
    }
    
    enum BillInputView: String { // added
        case textField
        
    }
    
    enum TipInputView: String { // added
        case tenPercentButton
        case fifteenPercentButton
        case twentyPercentButton
        case customTipButton
    }
        
    enum SplitInputView: String { // added
        case decrementButton
        case incrementButton
        case quantityValueLabel
    }
}
```

ui에 해당하는 것을 모두 등록을 해준다.

### 1. Logoview Identifier

```swift
init () {
        super.init(frame: .zero)
        accessibilityIdentifier = ScreenIdentifier.LogoView.logoView.rawValue // added
        layout()
    }
```

logoview 전체에 대한 identifier를 등록.

### 2. BillInputView Identifier

```swift
private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.font = ThemeFont.demibold(ofSize: 28)
        textField.keyboardType = .decimalPad
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.tintColor = ThemeColor.text
        textField.textColor = ThemeColor.text
        textField.accessibilityIdentifier = ScreenIdentifier.BillInputView.textField.rawValue // added
        // Add Toolbar
        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 36))
        toolBar.barStyle = .default
        toolBar.sizeToFit()
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(doneButtonTapped))
        toolBar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            doneButton
        ]
        toolBar.isUserInteractionEnabled = true
        textField.inputAccessoryView = toolBar
        return textField
    }()
```

### 3. TipInputView Identifier

```swift
 private lazy var tenPercentTipButton: UIButton = {
        let button = buildTipButton(tip: .tenPercent)
        button.accessibilityIdentifier = ScreenIdentifier.TipInputView.tenPercentButton.rawValue // added
        button.tapPublisher.flatMap({
            Just(Tip.tenPercent)
        }).assign(to: \.value, on: tipSubject).store(in: &cancellables)
        return button
    }()
```

이건 하나로 대체,

나머지도 button도 상동

### 4. SplitInputView Identifier

```swift
private lazy var incrementButton: UIButton = {
        let button = buildButton(text: "+", corners: [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        button.accessibilityIdentifier = ScreenIdentifier.SplitInputView.incrementButton.rawValue // added
        button.tapPublisher.flatMap { [unowned self] _ in
            Just(splitSubject.value + 1)
        }.assign(to: \.value, on: splitSubject)
            .store(in: &cancellables)
        return button
    }()
    
    private lazy var quantityLabel: UILabel = {
        let label = LabelFactory.build(
            text: "1",
            font: ThemeFont.bold(ofSize: 20),backgroundColor: .white)
        label.accessibilityIdentifier = ScreenIdentifier.SplitInputView.quantityValueLabel.rawValue // added
        return label
    }()
```

QuantityLabel의 경우 우리가 보통 label.text 이런식으로 text property에 접근을 하다보니 자연스레 text를 쓰게 되는데 여기서는 label 그 자체를 해주는게 포인트.

버튼은 3번과 동일.

## CaculatorScreen에 모든 view 추가

```swift
class CalculatorScreen {
    
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // LogoView
    var logoView: XCUIElement {
        app.otherElements[ScreenIdentifier.LogoView.logoView.rawValue]
    }
    
    
    // ResultView
    var totalAmountPerPersonValueLabel: XCUIElement {
        app.staticTexts[ScreenIdentifier.ResultView.totalAmountPerPersonValueLabel.rawValue]
    }
    
    var totalBillValueLabel: XCUIElement {
        app.staticTexts[ScreenIdentifier.ResultView.totalBillValueLabel.rawValue]
    }
    
    var totalTipValueLabel: XCUIElement {
        app.staticTexts[ScreenIdentifier.ResultView.totalTipValueLabel.rawValue]
    }
    
    // BillInputView
    var billInputViewTextField: XCUIElement {
        app.textFields[ScreenIdentifier.BillInputView.textField.rawValue]
    }
    
    // TipInputView
    var tenPercentTipButton: XCUIElement {
        app.buttons[ScreenIdentifier.TipInputView.tenPercentButton.rawValue]
    }
    
    var fifteenPercentTipButton: XCUIElement {
        app.buttons[ScreenIdentifier.TipInputView.fifteenPercentButton.rawValue]
    }
    
    var twentyPercentTipButton: XCUIElement {
        app.buttons[ScreenIdentifier.TipInputView.twentyPercentButton.rawValue]
    }
    
    var customTipButton: XCUIElement {
        app.buttons[ScreenIdentifier.TipInputView.customTipButton.rawValue]
    }
    
    // customTip을 입력하려고 하면 뜨는 textField도 추가.
    var customTipAlertTextField: XCUIElement {
        app.textFields[ScreenIdentifier.TipInputView.customTipAlertTextField.rawValue]
    }
    
    // SplitInputView
    var incrementButton: XCUIElement {
        app.buttons[ScreenIdentifier.SplitInputView.incrementButton.rawValue]
    }
    
    var decrementButton: XCUIElement {
        app.buttons[ScreenIdentifier.SplitInputView.decrementButton.rawValue]
    }
    
    var splitValueLabel: XCUIElement {
        app.staticTexts[ScreenIdentifier.SplitInputView.quantityValueLabel.rawValue]
    }
    
    // Actions
    func enterBill(amount: Double) {
        billInputViewTextField.tap() // 실제 텍스트 필드를 탭한것과 같은 효과
        billInputViewTextField.typeText("\(amount)\n") // parmeter값을 입력한뒤, \n을 하면서 키보드를 닫게함.
    }
    
    func selectTip(tip: Tip) {
        switch tip {
        case .tenPercent:
            tenPercentTipButton.tap()
        case .fifteenPercent:
            fifteenPercentTipButton.tap()
        case .twentyPercent:
            twentyPercentTipButton.tap()
        case .custom(let value):
            customTipButton.tap()
            XCTAssertTrue(customTipAlertTextField.waitForExistence(timeout: 1.0)) // tip alert view가 보여지기까지 기다려줌
            customTipAlertTextField.typeText("\(value)\n") // alert가 나오면 textfield에 값 입력
        }
        
    }
    
    func selectIncrementButton(numberOfTaps: Int) {
            incrementButton.tap(withNumberOfTaps: numberOfTaps, numberOfTouches: 1)
        }
        
    func selectdecrementButton(numberOfTaps: Int) {
            decrementButton.tap(withNumberOfTaps: numberOfTaps, numberOfTouches: 1)
        }
        
    func doubleTapLogoView() {
            logoView.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        }

    enum Tip {
        case tenPercent
        case fifteenPercent
        case twentyPercent
        case custom(value: Int)
    }
    
    
}
```

코드로 대체

코드만 봐도 크게 어려움은 없다.

디테일한건 주석을 달아두었음.

## test에 조건을 부여

조건 : $100의 bill, tip은 10%/15%/20%/, split 4/2

```swift
// UItests

func testRegulapTip() {
        // user enters a $100 bill
        screen.enterBill(amount: 100)
        XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$100")
        XCTAssertEqual(screen.totalBillValueLabel.label, "$100")
        XCTAssertEqual(screen.totalTipValueLabel.label, "$0")
    }
```

이렇게 조건을 추가.

실행하니

![CleanShot 2024-05-04 at 14 25 43@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/b49ff1ca-70b5-4549-bd5f-a2610b419c32)

갑자기 표기법이 달라진다?

`$ → ₩` ?? 

의심이 가는 부분이 있어 지역을 미국으로 변경

![simulator_screenshot_ADE569F9-98DD-41D8-BE5A-063687B92224](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/ed8c9092-7785-4d65-a5fa-0c135fa50ece){: width="50%" height="50%"}

테스트 재실행.

테스트 성공.

지역이 달라 표기법이 바뀐 문제였다.

```swift
func testRegularTip() {
    // User enters a $100 bill
    screen.enterBill(amount: 100)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$100")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$100")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$0")
  
    // User selects 10%
    screen.selectTip(tip: .tenPercent)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$110")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$110")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$10")

    // User selects 15%
    screen.selectTip(tip: .fifteenPercent)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$115")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$115")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$15")

    // User selects 20%
    screen.selectTip(tip: .twentyPercent)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$120")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$120")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$20")

    // User splits the bill by 4
    screen.selectIncrementButton(numberOfTaps: 3)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$30")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$120")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$20")

    // User splits the bill by 2
    screen.selectDecrementButton(numberOfTaps: 2)
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$60")
    XCTAssertEqual(screen.totalBillValueLabel.label, "$120")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$20")
  }
```

두번째 부터 에러가 발생.

뭐가 잘못되었는지 확인이 필요.

우선 확실한건 로고쪽만 2번이 탭되었을때 리셋이 되어야하는데 지금 다른부분 탭을해도 리셋이 되는게 문제이다

그래서 `screen.selectIncrementButton(numberOfTaps: 3)` 여기서 리셋이 되어버려 문제가 되는것도 있다.

## 문제 해결

```swift
 private lazy var logoviewTapPublisher: AnyPublisher<Void, Never> = {
        let tapGesture = UITapGestureRecognizer(target: self, action: nil)
        tapGesture.numberOfTapsRequired = 2
        logoView.addGestureRecognizer(tapGesture) // modified
        return tapGesture.tapPublisher.flatMap { _ in
            Just(())
        }.eraseToAnyPublisher()
    }()
```

코드를 보다가 logoview쪽에 뭔가가 문제가 있다고 판단해서 찾아보던중

`logoView.addGestureRecognizer` 이었어야 하는데 `View.addGestureRecognizer` 로 해버렸다.

그러니 모든 화면에서 리셋이 된것이다.

이걸해결하니 모든 문제가 해결.

![May-04-2024 14-48-29](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/bde8d3fb-9e5b-4768-8963-7289ca7e90c3){: width="50%" height="50%"}

테스트는 이런식으로 진행이됨.

상당히 빠르다.

이렇게 테스트를 하면서 우리가 답으로 설정해둔값과 같은지를 비교한다.

## CustomTip 조건 설정

바로 밑에 다음과 같이 조건을 적어보자

```swift
func testCustomTipAndSplitBillBy2() {
    screen.enterBill(amount: 300)
    screen.selectTip(tip: .custom(value: 200))
    screen.selectIncrementButton(numberOfTaps: 1)
    XCTAssertEqual(screen.totalBillValueLabel.label, "$500")
    XCTAssertEqual(screen.totalTipValueLabel.label, "$200")
    XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$250")
  }
```

$300를 입력하고 tip으로 $200 입력하고 1명을 더 추가 했을때

결과값으로 우리가 위에 설정한 값이 나오면 된다.

하지만 실패

![May-04-2024 14-59-24](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d879ab3e-7d3f-4745-8a4a-52483a667dac){: width="50%" height="50%"}

그냥 얼타고있다?

![CleanShot 2024-05-04 at 14 51 53@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2a9f64fa-d8b4-479f-8110-019df81037ec)

무엇이 문제일까?

customTip 과 관련된 부분을 가보니

![CleanShot 2024-05-04 at 14 53 05@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c1953a6c-3c60-4e78-a9a8-870a3ff442bd)

에러가 났음을 표시해주고 있다.

우선 `customTipAlertTextField` 에 대한 identifier가 없다.

```swift
// CalculatorScreen

// customTip을 입력하려고 하면 뜨는 textField도 추가.
    var customTipAlertTextField: XCUIElement {
        app.textFields[ScreenIdentifier.TipInputView.customTipAlertTextField.rawValue]
    }
```

이렇게 적었는데 없다는게 무슨말일까? 라고 한다면.

```swift
// tipinputview

private func handleCustomTipButton() {
        let alertController: UIAlertController = {
            let controller = UIAlertController(title: "Enter Custom Tip", message: nil, preferredStyle: .alert)
            controller.addTextField { textField in
                textField.placeholder = "Make it generous!"
                textField.keyboardType = .numberPad
                textField.autocorrectionType = .no
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                guard let text = controller.textFields?.first?.text, let value = Int(text) else { return }
                self?.tipSubject.send(.custom(value: value))
            }
            [okAction, cancelAction].forEach(controller.addAction(_:))
            return controller
        }()
        parentViewController?.present(alertController, animated: true)
    }
```

바로 여기 textField에 identifier를 등록하지 않았기에

tester가 계속 textfield에 접근하지 못해 얼타면서 timeout이 발생했던것.

```swift
private func handleCustomTipButton() {
        let alertController: UIAlertController = {
            let controller = UIAlertController(title: "Enter Custom Tip", message: nil, preferredStyle: .alert)
            controller.addTextField { textField in
                textField.placeholder = "Make it generous!"
                textField.keyboardType = .numberPad
                textField.autocorrectionType = .no
                textField.accessibilityIdentifier = ScreenIdentifier.TipInputView.customTipAlertTextField.rawValue // added
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                guard let text = controller.textFields?.first?.text, let value = Int(text) else { return }
                self?.tipSubject.send(.custom(value: value))
            }
            [okAction, cancelAction].forEach(controller.addAction(_:))
            return controller
        }()
        parentViewController?.present(alertController, animated: true)
    }
```

이렇게 추가를 해주자.

다시 테스트하면 성공.

![May-04-2024 15-00-49](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/28f87f86-6c9a-4cdd-b0dd-8bef18d9cbc0){: width="50%" height="50%"}

이제는 제대로 textField에 값을 입력한다.

## 리셋 기능 테스트

```swift
func testResetButton() {
        screen.enterBill(amount: 300)
        screen.selectTip(tip: .custom(value: 200))
        screen.selectIncrementButton(numberOfTaps: 1)
        screen.doubleTapLogoView()
        XCTAssertEqual(screen.totalBillValueLabel.label, "$0")
        XCTAssertEqual(screen.totalTipValueLabel.label, "$0")
        XCTAssertEqual(screen.totalAmountPerPersonValueLabel.label, "$0")
        XCTAssertEqual(screen.billInputViewTextField.label, "")
        XCTAssertEqual(screen.splitValueLabel.label, "1")
        XCTAssertEqual(screen.customTipButton.label, "Custom Tip")
    }
```

이렇게 위에 먼저 조건을 설정하고 로고뷰를 두번 탭했을대 제대로 리셋이 되는지에 대한 테스트이다.

테스트해보니 잘된다

![May-04-2024 15-02-19](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d18d1d96-25ce-47ae-bd46-afa176cfa076){: width="50%" height="50%"}

끝

4시간 반짜리 강의였던걸로 기억하는데 너무 신선한 충격 + 도움을 준 강의였다.

Fok형 Respect