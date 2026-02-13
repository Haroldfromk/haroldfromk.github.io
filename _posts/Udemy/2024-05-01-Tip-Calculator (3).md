---
title: Tip-Calculator (3)
writer: Harold
date: 2024-05-01 09:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## Input View 디자인

HeaderView라는 클래스를 하나 만들어 주고 시작한다.

```swift
class HeaderView: UIView {
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layout() {
        backgroundColor = .red
    }
    
}

```

그리고 TextField를 감쌀 View도 하나 만들어준다.

```swift
private let textFieldContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        
        return view
    }()
```

extension에 코너를 둥글게할 기능도 새로 추가해준다

```swift
func addCornerRadius(radius: CGFloat) {
        layer.masksToBounds = false
        layer.cornerRadius = radius
    }
```
> setContentHuggingPriority
>> 뷰 내에서 Label의 높이가 조정되어 제약을 만족시키고자 할 때 setContentHuggingPriority() 메서드를 사용한다.
>>> 높이가 고정될 Label의 우선순위를 .defaultHight, 높이가 조정될 Label의 우선순위를 .defaultLow로 설정해준다

[출처](https://velog.io/@sun02/%EC%82%AC%EC%9D%B4%EC%A6%88-%EC%A1%B0%EC%A0%88-%EC%9A%B0%EC%84%A0%EC%88%9C%EC%9C%84-%EC%84%A4%EC%A0%95)

```swift
private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.font = ThemeFont.demibold(ofSize: 28)
        textField.keyboardType = .decimalPad
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.tintColor = ThemeColor.text
        textField.textColor = ThemeColor.text
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

![simulator_screenshot_049ABB94-21A6-41F3-9F83-6BECAFECAFC4](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/f8abb4ee-fd65-4c29-ba5b-bc0965257a47){: width="50%" height="50%"}

이렇게 하면 키보드 위에 Toolbar가 생성이 되고 done버튼이 있다.

이걸 누르게 되면 키보드가 내려간다.

## HeaderView 디자인

```swift
class HeaderView: UIView {
    
    private let topLabel: UILabel = {
        LabelFactory.build(text: nil, font: ThemeFont.bold(ofSize: 18))
    }()
    
    private let bottomLabel: UILabel = {
        LabelFactory.build(text: nil, font: ThemeFont.regular(ofSize: 16))
    }()
    
    private let topSpacerView = UIView()
    private let bottomSpacerView = UIView()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            topSpacerView,
            topLabel,
            bottomLabel,
            bottomSpacerView
        ])
        stackView.axis = .vertical
        stackView.alignment = . leading
        stackView.spacing = -4
        return stackView
    }()
    
    init() {
        super.init(frame: .zero)
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layout() {
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        topSpacerView.snp.makeConstraints { make in
            make.height.equalTo(bottomSpacerView)
        }
    }
    
    func configure(topText: String, bottomText: String) {
        topLabel.text = topText
        bottomLabel.text = bottomText
    }
    
}
```

코드로 대체 딱히 적을게 없다.

## InputView 디자인

팁 버튼을 디자인을 하는데 그전에 enum 을 통해 어떤 케이스로 될지 디자인을 해둔다.

```swift
enum Tip {
    
    case none
    case tenPercent
    case fifteenPercent
    case twentyPercent
    case custom(value: Int)
    
    var stringValue: String {
        switch self{
        case .none:
            return ""
        case .tenPercent:
            return "10%"
        case .fifteenPercent:
            return "15%"
        case .twentyPercent:
            return "20%"
        case .custom(let value):
            return String(value)
        }
    }
    
}
```

그리고 Default 버튼 디자인을 해준다

```swift
private func buildTipButton(tip: Tip) -> UIButton{
        let button = UIButton(type: .custom)
        button.backgroundColor = ThemeColor.primary
        button.tintColor = .white
        button.addCornerRadius(radius: 8.0)
        let text = NSMutableAttributedString(
            string: tip.stringValue,
            attributes: [
                .font: ThemeFont.bold(ofSize: 20)
            ])
        text.addAttributes([
            .font: ThemeFont.demibold(ofSize: 14)
        ], range: NSMakeRange(2, 1))
        button.setAttributedTitle(text, for: .normal)
        return button
    }
```

이렇게 enum과 버튼 디자인을 해두면

```swift
private lazy var tenPercentTipButton: UIButton = {
        let button = buildTipButton(tip: .tenPercent)
        return button
    }()
```

이렇게 그냥 사용만 해주면 된다.

그리고 스택뷰 생성

```swift
private lazy var buttonHStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
        tenPercentTipButton,
        fifTeenPercentTipButton,
        twentyPercentTipButton
        ])
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.axis = .horizontal
        return stackView
    }()
```

하지만 그 아래에 들어갈 customTipButton의 경우 위와 같은 스타일이 아니므로 별도로 디자인을 해줘야한다.

```swift
private lazy var customTipButton: UIButton = {
        let button = UIButton()
        button.setTitle("Custom Tip", for: .normal)
        button.titleLabel?.font = ThemeFont.bold(ofSize: 20)
        button.backgroundColor = ThemeColor.primary
        button.tintColor = .white
        button.addCornerRadius(radius: 8.0)
        return button
    }()
```

그리고 버튼 3개를 합친 스택뷰와 새로만든 customTipButton을 감쌀 VerticalStackview 생성.

그리고 오토레이아웃도 잡아주면 끝.

## splitview 디자인

특정 모서리만 둥글게 해주는 기능을 extension에 추가

```swift
func addRoundedCorners(corners: CACornerMask, radius: CGFloat) {
        layer.cornerRadius = radius
        layer.maskedCorners = [corners] // 특정 모서리만 둥글게
    }
```

완성

![simulator_screenshot_54B0B130-282F-4A7C-A550-978A26C14E35](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/06d8b7e3-8fec-4901-bce1-3ddae914e0ac){: width="50%" height="50%"}