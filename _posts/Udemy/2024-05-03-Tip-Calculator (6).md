---
title: Tip-Calculator (6)
writer: Harold
date: 2024-05-03 17:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## 결과를 Result View에 출력

현재는 bind 함수에 콘솔로 보여주게만 되어있다.

그걸 이제 result view에 출력이 되도록 한다.

```swift
func configure(result: Result) {
        let text = NSMutableAttributedString(
            string: String(result.amountPerPerson),
            attributes: [.font: ThemeFont.bold(ofSize: 48)])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 24)
        ], range: NSMakeRange(0, 1))
        amountPersonLabel.attributedText = text
    }
```

결과값을 폰트를 별도 적용하여 label에 적용해주는 함수를 구현

## TotalBillview 구현

```swift
private let totalBillView: AmountView = {
       let view = AmountView(
            title: "Total Bill",
            textAlignment: .left)
        return view
    }()
    
private let totalTipView: AmountView = {
       let view = AmountView(
            title: "Total Tip",
            textAlignment: .left)
        return view
    }()
```

다시 view를 새로 만들어 주고, 기존에

```swift
private lazy var hStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            AmountView(
                title: "Total Bill",
                textAlignment: .left),
            UIView(), // 사이에 끼워줌.
            AmountView(
                title: "Total Tip",
                textAlignment: .right)
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()
```

hstackView에 위와 같이 만들어 뒀던것을 인스턴스를 넣어준다.

```swift
private lazy var hStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            totalBillView,
            UIView(), // 사이에 끼워줌.
            totalTipView
        ])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        return stackView
    }()
```

## AmountView에 configure 함수 구현.

```swift
func configure(text: String) {
        let text = NSMutableAttributedString(string: text, attributes: [
            .font: ThemeFont.bold(ofSize: 24)
        ])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 16)
        ], range: NSMakeRange(0, 1))
        amountLabel.attributedText = text
    }
```

## Resultview에 적용

```swift
func configure(result: Result) {
        let text = NSMutableAttributedString(
            string: String(result.amountPerPerson),
            attributes: [.font: ThemeFont.bold(ofSize: 48)])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 24)
        ], range: NSMakeRange(0, 1))
        amountPersonLabel.attributedText = text
        totalBillView.configure(text: String(result.totalBill)) // added
        totalTipView.configure(text: String(result.totalTip))   // added
    }
```

## VC에 적용

```swift
// bind
output.updateViewPublisher.sink { [unowned self] result in
            resultView.configure(result: result)
        }.store(in: &cancellables)
```

![Simulator Screenshot - iPhone 15 Pro - 2024-05-03 at 18 19 20](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6a9996a4-cefb-49d5-ae79-f40fae933c34){: width="50%" height="50%"}

좀 우스꽝스럽게 나왔다.

수정을 해야한다.

## 보강

Double에 대해 extension을 만든다

```swift
extension Double {
    var currencyFormatted: String {
        var isWholeNumber: Bool {
            isZero ? true: !isNormal ? false: self == rounded()
            }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = isWholeNumber ? 0 : 2
        return formatter.string(for: self) ?? ""
    }
}
```

```swift
// AmountView
func configure(amount: Double) { // modified String -> Double
        let text = NSMutableAttributedString(string: amount.currencyFormatted, attributes: [ // modified
            .font: ThemeFont.bold(ofSize: 24)
        ])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 16)
        ], range: NSMakeRange(0, 1))
        amountLabel.attributedText = text
    }

// ResultView 
 func configure(result: Result) {
        let text = NSMutableAttributedString(
            string: result.amountPerPerson.currencyFormatted, // modified
            attributes: [.font: ThemeFont.bold(ofSize: 48)])
        text.addAttributes([
            .font: ThemeFont.bold(ofSize: 24)
        ], range: NSMakeRange(0, 1))
        amountPersonLabel.attributedText = text
        totalBillView.configure(amount: result.totalBill) // modified
        totalTipView.configure(amount: result.totalTip)   // modified
    }
```

![simulator_screenshot_92F80971-E271-44C0-A0D4-7B90BE60A1B1](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c5e30d88-c2f0-4313-89f9-e59b3e55c443){: width="50%" height="50%"}

이젠 잘된다.

## Tap Gesture 추가

CombineCocoa를 사용한다.

![CleanShot 2024-05-03 at 18 33 48@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/59504e8c-ca6f-4a68-ad2a-aef432986788)

여기에 tap gesture가 있다.

퍼블리셔 생성

```swift
private lazy var viewTapPublisher: AnyPublisher<Void, Never> = {
        let tapGesture = UITapGestureRecognizer(target: self, action: nil)
        view.addGestureRecognizer(tapGesture)
        return tapGesture.tapPublisher.flatMap { _ in
            Just(())
        }.eraseToAnyPublisher()
    }()  
```

> Input이 Void?
>> 그 이유는 우리가 탭을 할때 Int나 String 이런 값을 보내지 않을 것이라서 그렇다.
>> 그래서 just안에도 ()를 넣었음.

## observe 함수 추가

```swift
private func observe() {
        viewTapPublisher.sink { [unowned self] value in
            view.endEditing(true)
        }.store(in: &cancellables)
    }
```

parameter로 value가 있지만 void이므로 어차피 리턴할게 없다.

제스쳐를 추가한 이유는 키보드가 올라왔을때 키보드를 내리게 하기 위함.

![May-03-2024 19-08-12](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1169e0a9-d931-4e43-8fcd-2715420349bf){: width="50%" height="50%"}

## LogoView를 탭했을 때의 이벤트 추가

```swift
 private lazy var logoviewTapPublisher: AnyPublisher<Void, Never> = {
        let tapGesture = UITapGestureRecognizer(target: self, action: nil)
        tapGesture.numberOfTapsRequired = 2 // added
        view.addGestureRecognizer(tapGesture)
        return tapGesture.tapPublisher.flatMap { _ in
            Just(())
        }.eraseToAnyPublisher()
    }()
```

2번 탭했을때 해당 gestureRecognizer가 발생

![May-03-2024 19-11-31](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/b7f3b5d4-5862-4f82-90f9-a3c891be6815){: width="50%" height="50%"}


## GestureTapPublisher를 vm에 전달.

```swift
struct Input {
        let billPublisher: AnyPublisher<Double, Never>
        let tipPublisher: AnyPublisher<Tip, Never>
        let splitPublisher: AnyPublisher<Int, Never>
        let logoViewTapPublisher: AnyPublisher<Void, Never> // added
    }
struct Output {
        let updateViewPublisher: AnyPublisher<Result, Never>
        let resultCalculatorPublisher: AnyPublisher<Void, Never>
    }    
```

로고뷰에 대한 퍼블리셔를 하나 추가. vc에서 로고뷰에 대한 퍼블리셔를 void로 했기에 이것도 void로 해준다.

output에도 void로 해서 하나 만들어 준다. (Reset용)

```swift
// vc

let input = CalculatorVM.Input(
            billPublisher: billInputView.valuePublisher,
            tipPublisher: tipInputView.valuePublisher,
            splitPublisher: spiltInputView.valuePublisher,
            logoViewTapPublisher: logoviewTapPublisher) // added

let output = vm.transform(input: input)
        
        output.updateViewPublisher.sink { [unowned self] result in
            resultView.configure(result: result)
        }.store(in: &cancellables)
        
        output.resultCalculatorPublisher.sink { _ in // added
            print("hey, reset the form please")
        }.store(in: &cancellables)            

// vm

func transform(input: Input) -> Output {
        
        let updateViewPublisher = Publishers.CombineLatest3(
            input.billPublisher,
            input.tipPublisher,
            input.splitPublisher).flatMap { [unowned self] (bill, tip, split) in
                let totalTip = getTipAmount(bill: bill, tip: tip)
                let totalBill = bill + totalTip
                let amountPerPerson = totalBill / Double(split)
                let result = Result(
                    amountPerPerson: amountPerPerson,
                    totalBill: totalBill,
                    totalTip: totalTip)
                
                return Just(result)
            }.eraseToAnyPublisher()
        
        let resultCalculatorPublisher = input.logoViewTapPublisher // added
        
        return Output(updateViewPublisher: updateViewPublisher, resultCalculatorPublisher: resultCalculatorPublisher) // modified
    }
```

로고뷰를 탭하면

```
hey, reset the form please
logoview is tapped
```
이렇게 출력이 된다.

이제는

```swift
//vc
private func observe() {
        viewTapPublisher.sink { [unowned self] value in
            view.endEditing(true)
        }.store(in: &cancellables)
    }
```

logoviewTapPublisher의 내용을 지워도 된다.

bind함수에서 호출하기때문.

## 로고뷰 탭하면 사운드 발생 이벤트 추가

사운드파일을 넣어주고 새로운 스위프트 파일을 생성

```swift
protocol AudioPlayerService {
    func playSound()
}

final class DefaultAudioPlayer: AudioPlayerService {
    
    private var player: AVAudioPlayer?
    
    
    func playSound() {
        let path = Bundle.main.path(forResource: "click", ofType: "m4a")!
        let url = URL(fileURLWithPath: path)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch (let error) {
            print(error.localizedDescription)
        }
    }
    
}
```

## VM에서 사운드 플레이어 기능 구현 - 로고 터치시

```swift
private let audioPlayerService: AudioPlayerService

init(audioPlayerService: AudioPlayerService = DefaultAudioPlayer()) {
        self.audioPlayerService = audioPlayerService
    }
```

해당 부분을 initializing

```swift
// vm
// transform

let resultCalculatorPublisher = input.logoViewTapPublisher.handleEvents(receiveOutput: { [unowned self] in
            audioPlayerService.playSound()
        }).flatMap {
            return Just($0)
        }.eraseToAnyPublisher()

```

로고탭을 하면 이벤트가 발생하고 그 이벤트로 사운드를 재생시킴, 어차피 Void로 리턴하므로 아무것도 없음.

실행했지만 nil 발생

[스택오버플로우](https://stackoverflow.com/questions/41775563/bundle-main-pathforresourceoftypeindirectory-returns-nil){:target="_blank"}

를 보고 시도.

![CleanShot 2024-05-03 at 20 05 19@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8103d020-1dce-4f96-9360-3fcdf4ee4f68)

성공.

## 로고 클릭시 리셋 기능 구현

리셋 함수 구현

```swift
//billinputview
func reset() {
        textField.text = nil
        billSubject.send(0)
}
// tipinputview
func reset () {
        tipSubject.send(.none)
    }

// splitinputview
func reset () {
        splitSubject.send(1)
    }

// vc
output.resetCalculatorPublisher.sink { [unowned self] _ in
            billInputView.reset() // added
            tipInputView.reset() // added
            spiltInputView.reset() // added
        }.store(in: &cancellables)
```

## 애니메이션 구현

```swift
private func bind() {
        
        
        let input = CalculatorVM.Input(
            billPublisher: billInputView.valuePublisher,
            tipPublisher: tipInputView.valuePublisher,
            splitPublisher: spiltInputView.valuePublisher,
            logoViewTapPublisher: logoviewTapPublisher)
        
        
        let output = vm.transform(input: input)
        
        output.updateViewPublisher.sink { [unowned self] result in
            resultView.configure(result: result)
        }.store(in: &cancellables)
        
        output.resetCalculatorPublisher.sink { [unowned self] _ in
            billInputView.reset()
            tipInputView.reset()
            spiltInputView.reset()
            
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                usingSpringWithDamping: 5.0,
                initialSpringVelocity: 0.5,
                options: .curveEaseInOut) {
                    self.logoView.transform = .init(scaleX: 1.5, y: 1.5)
                } completion: { _ in
                    UIView.animate(withDuration: 0.1) {
                        self.logoView.transform = .identity
                    }
                }
        }.store(in: &cancellables)

    }
```

완성

![May-03-2024 20-29-11](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/7f9421be-7be2-45fc-8487-c2b678ce0959){: width="50%" height="50%"}
