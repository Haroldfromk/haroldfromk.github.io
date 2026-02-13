---
title: Tip-Calculator (5)
writer: Harold
date: 2024-05-03 16:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## TipInputView publisher 생성

```swift
private let tipSubject: CurrentValueSubject<Tip, Never> = .init(.none)

var valuePublisher: AnyPublisher<Tip, Never> {
        return tipSubject.eraseToAnyPublisher()
    }
```

tipSubject는 CurrentValueSubject인 이유는 값이 전달되고도 해당 값을 새로운 값이 들어오기 전까지 가지고 있게하는데에 의미가 있다.

valuePublisher를 또 만든건 지난글 마지막부분쯤에 있으니 참고.

## Button에 Publisher 생성

```swift
private lazy var tenPercentTipButton: UIButton = {
        let button = buildTipButton(tip: .tenPercent)
        button.tapPublisher.flatMap({ // added
            Just(Tip.tenPercent)
        }).assign(to: \.value, on: tipSubject).store(in: &cancellables)
        return button
    }()
```

이 부분의 의미는 뭐냐, 10% 버튼을 클릭하면 Tip에서 tenpercent를 가져온다.

flatmap을 사용함으로써. 여러 publisher들을 하나의 새로운 publisher로 만들어준다.

![](https://techblog.recochoku.jp/wp-content/uploads/2022/09/FlatMap.png)

해당 사진의 예시 코드

```swift
enum ConvertError: Error {
    case integerError
}
 
["1", "hoge", "2"].publisher
    .flatMap { value in
        return Just(value)
            .tryMap { value throws -> Int in
                if let integer = Int(value) {
                    return integer
                } else {
                    throw ConvertError.integerError
                }
            }
            .catch { _ in
                Just(0)
            }
    }
    .sink { completion in
        switch completion {
        case let .failure(error):
            print(error)ㅁ
 
        case .finished:
            print("finished")
        }
    } receiveValue: { value in
        print(value)
    }
 
// 出力結果: 1, 0, 2, finished
```

[출처](https://techblog.recochoku.jp/8514){:target="_blank"}



```swift
enum Tip {
    
    case none
    case tenPercent // here
    case fifteenPercent
    case twentyPercent
    case custom(value: Int)
    
    var stringValue: String {
        switch self{
        case .none:
            return ""
        case .tenPercent:
            return "10%"  // here
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

tipSubject의 value property에 tenPercent 가 들어가게 된다.

나머지 버튼들도 수정을 해주고,

```swift
// calculatorVC

private func bind() {

        let input = CalculatorVM.Input(
            billPublisher: billInputView.valuePublisher, 
            tipPulbisher: tipInputView.valuePublisher, // modfied
            splitPublisher: Just(5).eraseToAnyPublisher())
        
        let output = vm.transform(input: input)
        
    }

```

vc에서 이부분도 수정해준다.

그리고 vm에서 transform에 

```swift
input.tipPublisher.sink { tip in
    print("the tip: \(tip)")
}.store(in: &cancellables)
```

이걸 적어 보고 실행 후, 팁 버튼을 클릭하면

`the tip: tenPercent` 라고 출력이 된다.

왜 10%가 아니지? 라는 부분은 enum에 또 var로 stringvalue를 computed property로 구성을 해두었기에,

`print("the tip: \(tip.stringValue)")`를 하게되면 퍼센티지로 출력이 된다.


## customtip button 기능 구현

```swift
private lazy var customTipButton: UIButton = {
        let button = UIButton()
        button.setTitle("Custom Tip", for: .normal)
        button.titleLabel?.font = ThemeFont.bold(ofSize: 20)
        button.backgroundColor = ThemeColor.primary
        button.tintColor = .white
        button.addCornerRadius(radius: 8.0)
        button.tapPublisher.sink { [weak self] _ in // added
            self?.handleCustomTipButton()
        }.store(in: &cancellables)
        return button
    }()


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


extension UIResponder {
    
    var parentViewController: UIViewController? {
        return next as? UIViewController ?? next?.parentViewController
    }
    
}
```

code로 대체 사실 코드 보면 알기에 별다른 말이 필요 없을듯 하다.

UIResponder만 신선했다.

>UIResponder 클래스는 iOS 앱에서 이벤트를 처리하고 응답 체인(responder chain)을 통해 이벤트를 전달하는 데 사용되는 기본 클래스이다.
>> Extension은 UIResponder에 `parentViewController`라는 Computed Property를 추가한다. 
>> 이 속성은 옵셔널 UIViewController를 반환.
>>`parentViewController`의 구현은 `next` 속성을 사용한다.
>> `next`는 응답 체인에서 다음 응답자를 반환하는 UIResponder 속성이다. 
>> 먼저 `next` 응답자가 `UIViewController`인지 확인하고, 그렇다면 해당 `UIViewController`를 반환
>> 만약 `next` 응답자가 `UIViewController`가 아니라면, `next?.parentViewController`를 재귀적으로 호출하여 UIViewController를 찾거나 응답 체인의 끝까지 탐색

![CleanShot 2024-05-03 at 16 21 00@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e4b7994c-8dad-4d13-8d21-3913b4d11d76){: width="50%" height="50%"}

그리고 다시 VM으로 돌아가서

```swift
// transform

input.tipPublisher.sink { tip in
            print("the tip: \(tip)")
        }.store(in: &cancellables)
```

이걸 추가해서 실행해서 custom tip을 적어보면

프린트가 된다.

`the tip: custom(value: 25)` 이런식.

## Handle Custom Tip Button 

팁버튼을 누르게되면 배경색이 변하고, custom tip에 값을 입력하면 그부분이 입력한 값으로 변하게 할것이다.

우선 원상태로 돌릴 함수를 구현, 일종의 Initializer

```swift
private func resetView() {
        [tenPercentTipButton,
         fifTeenPercentTipButton,
         twentyPercentTipButton,
         customTipButton].forEach {
            $0.backgroundColor = ThemeColor.primary
        }
        let text = NSMutableAttributedString(string: "Custom Tip",
                                             attributes: [.font: ThemeFont.bold(ofSize: 20)])
        customTipButton.setAttributedTitle(text, for: .normal)
    }
```

resetView 함수는 모든 버튼의 색을 돌리고, custom tip 부분은 Custom tip 이라고 다시 돌아오게 한다.

observe 함수 구현

```swift
private func observe() {
        tipSubject.sink { [unowned self] tip in
            resetView()
            switch tip {
            case .none:
                break
            case .tenPercent:
                tenPercentTipButton.backgroundColor = ThemeColor.secondary
            case .fifteenPercent:
                fifTeenPercentTipButton.backgroundColor = ThemeColor.secondary
            case .twentyPercent:
                twentyPercentTipButton.backgroundColor = ThemeColor.secondary
            case .custom(let value):
                customTipButton.backgroundColor = ThemeColor.secondary
                let text = NSMutableAttributedString(
                    string: "$\(value)",
                    attributes: [
                        .font: ThemeFont.bold(ofSize: 20)
                    ])
                text.addAttributes([
                    .font: ThemeFont.bold(ofSize: 14)
                ], range: NSMakeRange(0, 1))
                customTipButton.setAttributedTitle(text, for: .normal)
            }
        }.store(in: &cancellables)
    }
```

우선 화면을 리셋 해주고나서, switch case를 통해 tip이 어떤 값인지에 따라 다르게 처리하게 한다.

배경색을 바꾸는것이고 custom 만 입력한 값이 보이게 한다.

그리고 이것 역시도 tipSubject를 통해 전달을 하는데, `.store(in: &cancellables)`를 통해 subscription을 저장해두지 않으면 

적용이 안됨.

## splitview 기능 구현

```swift
private let splitSubject: CurrentValueSubject<Int, Never> = .init(1)
    
    var valuePublisher: AnyPublisher<Int, Never> {
        return splitSubject.eraseToAnyPublisher()
    }
```

이번에도 역시 subject와 pulisher를 생성.

```swift
//TipInputView

//before
private let tipSubject = CurrentValueSubject<Tip, Never>(.none)

//after
private let tipSubject: CurrentValueSubject<Tip, Never> = .init(.none)
```

TipInputView에 type 설정과 initializing으로 하는것으로 교체.

다시 splitview로 와서

```swift
private lazy var incrementButton: UIButton = {
        let button = buildButton(text: "+", corners: [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        button.tapPublisher.flatMap { [unowned self] _ in // added
            Just(splitSubject.value + 1)
        }.assign(to: \.value, on: splitSubject)
            .store(in: &cancellables)
        return button
    }()
```

현재 splitSubject가 가지고 있는 값에서 1을 추가를 해주고 그것을 다시 splitSubject의 value 프로퍼티에 할당시켜준다.

```swift
private lazy var decrementButton: UIButton = {
        let button = buildButton(text: "-", corners: [.layerMinXMinYCorner, .layerMinXMaxYCorner])
        button.tapPublisher.flatMap { [unowned self] _ in // added
            Just(splitSubject.value == 1 ? 1 : splitSubject.value - 1)
        }.assign(to: \.value, on: splitSubject)
            .store(in: &cancellables)
        return button
    }()
```

이때 decrementBtn의 경우 1이 최소값이 므로 삼항연산자를 통해 1일때는 1을 그대로 유지하고, 1이 아닐때만 -1 을 하여 그값을 splitSubject의 value프로퍼티에 넣게 해주었다.

## observe 함수 구현

```swift
private func observe() {
        splitSubject.sink { [unowned self] quantity in
            quantityLabel.text = quantity.stringValue
        }.store(in: &cancellables)
    }
```

observe 함수를 통해 splitSubject의 value를 quantityLabel에 표시하게 한다.

quantity의 type이 int이므로 extension을 통해 변환을 하게 해주었다.

## vm에서 작동 확인

```swift
// transform
input.splitPublisher.sink { split in
            print("the split: \(split)")
        }.store(in: &cancellables)
```

에 이부분을 추가하여 +, - 버튼을 클릭할때마다 값이 제대로 증감하는지 확인.

```swift
the split: 1
the split: 2
the split: 3
the split: 2
the split: 1
// 1인 상태에서 여러번 - 클릭
the split: 1
the split: 1
the split: 1
the split: 1
```

## 1을 계속 눌렀을때 이벤트가 생기는걸 방지.
```swift
var valuePublisher: AnyPublisher<Int, Never> {
        return splitSubject.removeDuplicates().eraseToAnyPublisher()
    }
```

removeDuplicates는 중복상황이 생기는걸 방지하는데 지금은 split의 최소 값은 1인데 1에서 - 를 계속 누르면 1이라는 이벤트가 계속 발생하게 되는데, 이때 저 메서드를 통해 1인 상태 즉 최소값일 때 더이상 같은 이벤트가 발생하지 않게 막아주는 역할을 하게된다.

## Compute Result

우선 vm의 transform 함수를 수정

```swift
func transform(input: Input) -> Output {
        
        let updateViewPublisher = Publishers.CombineLatest3( // added
            input.billPublisher,
            input.tipPublisher,
            input.splitPublisher).flatMap { [unowned self] (bill, tip, split) in
                let totalTip = getTipAmount(bill: bill, tip: tip)
                let totalBill = bill + totalTip
                let amountPerPerson = totalBill / Double(split)
                let result = Result( 
                    amountPerPerson: amountPerPerson, // modified
                    totalBill: totalBill,             // modified
                    totalTip: totalTip)               // modified
                
                return Just(result)
            }.eraseToAnyPublisher()
        
        return Output(updateViewPublisher: updateViewPublisher) // modified
    }

private func getTipAmount(bill: Double, tip: Tip) -> Double {
        switch tip{
        case .none:
            return 0
        case .tenPercent:
            return bill * 0.1
        case .fifteenPercent:
            return bill * 0.15
        case .twentyPercent:
            return bill * 0.2
        case .custom(let value):
            return Double(value)
        }
    }    
```

CombineLatest 메서드를 통해 3개의 publisher를 묶어준다.

그리고 flatMap을 통해 하나의 Publisher로 리턴을 해준다.

vc로 돌아가서 bind 수정

```swift
private func bind() {
        
        
        let input = CalculatorVM.Input(
            billPublisher: billInputView.valuePublisher,
            tipPublisher: tipInputView.valuePublisher,
            splitPublisher: spiltInputView.valuePublisher)
        
        let output = vm.transform(input: input)

        output.updateViewPublisher.sink { result in // added
            print(result)
        }.store(in: &cancellables)
        
    }

```

이렇게 하면 우리가 시뮬레이터를 실행하면 값에 따라 모든게 출력이 된다.

![CleanShot 2024-05-03 at 17 05 36@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/57c3b3fb-f337-4ba7-8220-268535798b9d)
