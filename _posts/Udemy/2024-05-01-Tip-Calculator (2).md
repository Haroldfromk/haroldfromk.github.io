---
title: Tip-Calculator (2)
writer: Harold
date: 2024-05-01 09:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## Warning 해결

현재 실행을 하게되면

```
Unable to simultaneously satisfy constraints.
	Probably at least one of the constraints in the following list is one you don't want. 
	Try this: 
		(1) look at each constraint and try to figure out which you don't expect; 
		(2) find the code that added the unwanted constraint or constraints and fix it. 
```

이런식으로 Auto Layout에 대한 워닝이 발생한다.

![CleanShot 2024-05-01 at 10 02 17@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e04e5b2f-35ac-4678-83ed-7daa3c427cb8)

에러가 발생하는 이유는 Vertical StackView 때문인데

여기안에 UIView를 하나 더 추가를 해줘야한다.

![CleanShot 2024-05-01 at 10 03 00@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/a747974b-a82f-4530-bb53-3966e9e85794)

설명이 이해가 안가서 나중에 다시 알아봐야할거같다.

이렇게 UIView하나가 새로 생기면서 해결이 되긴 했다.

## 폰트 적용 틀 만들어두기.

지원버전은 [사이트](https://developer.apple.com/fonts/system-fonts/)참고

```swift
struct ThemeFont {
    // AvenirNext
    static func regular(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "AvenirNext-Regular", size: size) ?? .systemFont(ofSize: size)
    }
    
    static func bold(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "AvenirNext-Bold", size: size) ?? .systemFont(ofSize: size)
    }
    
    static func demibold(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "AvenirNext-Demibold", size: size) ?? .systemFont(ofSize: size)
    }
}
```

## LogoView 디자인

이건 완성된 코드하나도 될 것 같다.

이렇게 디자인 할 생각을 하지 못했는데 새로운 강의를 들으면서 제대로 배웠다.

구현할 View를 먼저 클래스 파일로 만들고 거기서 디자인을 한다.

이게 포인트다.

```swift
class LogoView: UIView {
    
    private let imageView: UIImageView = {
        let view = UIImageView(image: .init(named: "icCalculatorBW"))
        view.contentMode = .scaleAspectFit
        
        return view
    }()
    
    private let topLabel: UILabel = {
        let label = UILabel()
        let text = NSMutableAttributedString(string: "Mr TIP",attributes: [.font: ThemeFont.demibold(ofSize: 16)])
        text.addAttributes([.font: ThemeFont.bold(ofSize: 24)], range: NSMakeRange(3, 3)) // TIP부분 더 강조
        label.attributedText = text
        return label
    }()
    
    private let bottomLabel: UILabel = {
        LabelFactory.build(
            text: "Calculator",
            font: ThemeFont.demibold(ofSize: 20),
            textAlignment: .left)
    }()
    
    private lazy var vStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [
        topLabel,
        bottomLabel
        ])
        view.axis = .vertical
        view.spacing = -4
        return view
    }()
    
    private lazy var hStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [
            imageView,
            vStackView
        ])
        view.axis = .horizontal
        view.spacing = 8
        view.alignment = .center
        return view
    }()
    
    init () {
        super.init(frame: .zero)
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func layout() {
        addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.height.equalTo(imageView.snp.width)
        }
    }
    
    
}

// LabelFactory
struct LabelFactory {

    // 기본적인 틀을 구조화
    static func build(  
        text: String?,
        font: UIFont,
        backgroundColor: UIColor = .clear,
        textColor: UIColor = ThemeColor.text,
        textAlignment: NSTextAlignment = .center) -> UILabel {
            let label = UILabel()
            label.text = text
            label.font = font
            label.backgroundColor = backgroundColor
            label.textColor = textColor
            label.textAlignment = textAlignment
            return label
    }
}
```

![simulator_screenshot_BB4540C1-DF33-46C7-83FA-6D08A67DB033](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/a0de7409-f6d2-45c4-9444-4fe1bba73020){: width="50%" height="50%"}

완성.

## ResultView 추가

위와 상동

다만 하나 알아두면 좋을 것은

```swift
private lazy var hStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
        AmountView(),
        UIView(), // 사이에 끼워줌.
        AmountView()
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()
```

이렇게 가운데에 UIView 를 끼워주고 3분할을 정확하게 해주었다는 것.

![simulator_screenshot_69CF9F22-965E-491B-90EC-8EC1C43E553A](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/29095007-0b6d-4549-8b74-05c48b1988df){: width="50%" height="50%"}

![CleanShot 2024-05-01 at 10 59 47@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/feb8d05c-ff66-403c-b274-10c523d7875e){: width="50%" height="50%"}

또 하나 배웠다.

## shadow효과를 위한 extension 생성

```swift
extension UIView {
    
    func addShadow(offset: CGSize, color: UIColor, radius: CGFloat, opacity: Float) {
        layer.cornerRadius = radius
        layer.masksToBounds = false
        layer.shadowOffset = offset
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        let backgroundCGColor = backgroundColor?.cgColor
        backgroundColor = nil
        layer.backgroundColor = backgroundCGColor
    }
}
```

## 가운데 선과 아래 View 사이 패딩 추가

```swift
private func buildSpacerView(height: CGFloat) -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }
```

이렇게 하나 만들어주고

```swift
horizontalLineView,
buildSpacerView(height: 0),
hStackView
```
높이 0짜리를 하나 사이에 끼워 넣어주면서 패딩이 자연스럽게 된다.

![simulator_screenshot_FF2FC5AC-684D-454E-A371-834A53EBFE20](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/eec15818-bee9-4f7b-90af-7950d315b67e){: width="50%" height="50%"}

완성

## AmountView 디자인

```swift
class AmountView: UIView {
    
    private let title: String
    private let textAlignment: NSTextAlignment
    
    private lazy var titleLabel: UILabel = {
        LabelFactory.build(
            text: title,
            font: ThemeFont.regular(ofSize: 18),
            textColor: ThemeColor.text,
            textAlignment: textAlignment)
    }()
    
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
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
        titleLabel,
        amountLabel
        ])
        stackView.axis = .vertical
        return stackView
    }()
    
    // custom Initializer
    init(title: String, textAlignment: NSTextAlignment) {
        self.title = title
        self.textAlignment = textAlignment
        super.init(frame: .zero)
        layout()
    }
//    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        layout()
//    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
}
```

처음에 AmountView를 같은걸 해놔서 똑같은 뷰가 두개가 되어있었는데,

이것을 Custom Initializer를 통해 text와 문자 배열을 하게 설정을 한다.

```swift
    // custom Initializer
    init(title: String, textAlignment: NSTextAlignment) {
        self.title = title
        self.textAlignment = textAlignment
        super.init(frame: .zero)
        layout()
    }

    // origin initializer -> Don't use this method    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layout()
    }
```

```swift
// resultview의 일부
private lazy var hStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            AmountView( // modified
                title: "Total Bill",
                textAlignment: .left),
            UIView(), // 사이에 끼워줌.
            AmountView( // modified
                title: "Total Tip",
                textAlignment: .right)
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()
```

뭔가 Code로 UIdesign 하는것에 신세계를 경험하게 된다.

![simulator_screenshot_605D83F7-908C-4CEF-8302-1EC090B130DC](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/b4ddef92-0079-4c18-ac47-60fb062d64ee)

너무 길어지니 파트2는 여기까지