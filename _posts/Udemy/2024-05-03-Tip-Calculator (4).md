---
title: Tip-Calculator (4)
writer: Harold
date: 2024-05-03 15:02
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## 컴바인을 사용하여 Calculator ViewModel 만들기

### input과 output 정의

우선 ViewModel을 구성할 CalculatorVM을 하나 만들어준다.

```swift
import Foundation
import Combine

class CalculatorVM {
    
    struct Input {
        let billPublisher: AnyPublisher<Double, Never>
        let tipPublisher: AnyPublisher<Tip, Never>
        let splitPublisher: AnyPublisher<Int, Never>
    }
    
    
    struct Output {
        let updateViewPublisher: AnyPublisher<Result, Never>
    }
}
```

Input에는 유져가 입력할 가격(bill)과 tip이 있다.

그래서 이걸 publisher를 설정을 해둔다.

Publisher에는 input, output type이 Generic의 형태로 존재.

bill은 소수점도 가능하기에 Double로 설정

Tip은 우리가 이미 modeling을 해두었으므로 Tip타입으로 설정 해둔다.

Split도 몇명으로 나눌건지에 대한 설정이므로 당연히 양수.

그리고 뒤에 보면 전부 Never가 있는데,

Never를 사용하게되면 failure에 대한 내용을 리턴하지 않는다.

앞에는 성공했을때의 리턴 타입 

즉 api 에서 escaping closure를 사용했을때와 유사.

``` swift
struct Output {
        let updateViewPublisher: AnyPublisher<(Double, Double, Double)>
    }
```

튜플 type으로 3개를 리턴 하는 이유?


![CleanShot 2024-05-01 at 16 22 35@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/f58b714e-6286-4f88-bc75-1f2a5e087b8c){: width="50%" height="50%"}

이렇게 3개의 값을 리턴하기 위해. 한번에 3개를 리턴함.

이렇게 하는것 보다 새로운 struct를 만들어서 하는게 더 깔끔. (Tip처럼 새로운 모델링)

간단한 메서드는 [여기](https://medium.com/harrythegreat/swift-combine-%EC%9E%85%EB%AC%B8%ED%95%98%EA%B8%B0-%EA%B0%80%EC%9D%B4%EB%93%9C-1-525ccb94af57)서 확인하면 좋을듯 하다.

```swift
struct Result {
    
    let amountPerPerson: Double
    let totalBill: Double
    let totalTill: Double
    
}

struct Output {
        let updateViewPublisher: AnyPublisher<Result, Never> // modified
    }
```

## transform 함수 구현 (vm)

```swift
func transform(input: Input) -> Output {
    
    let result = Result(amountPerPerson: 500, totalBill: 1000, totalTip: 50.0)
        
    return Output(updateViewPublisher: Just(result).eraseToAnyPublisher())
}
```

Input 타입과 Output 타입은 위에 Struct로 이미 구현을 해두었다.

테스트를 위해 result를 하나 만들고 Initializing을 해주었다.

> `eraseToAnyPublisher`는 Publisher 타입을 없애고, AnyPublisher형태로 리턴한다.
>> 지금까지의 데이터 스트림이 어떠했던 최종적인 형태의 Publisher를 리턴합니다.

## bind 함수 구현 (vc)

```swift
 private func bind() {
        
        let input = CalculatorVM.Input(
            billPublisher: Just(10).eraseToAnyPublisher(),
            tipPulbisher: Just(.tenPercent).eraseToAnyPublisher(),
            splitPublisher: Just(5).eraseToAnyPublisher())
        
        let output = vm.transform(input: input)
        
    }
```

input 과 output변수를 만들어 주었고. input엔 테스트를 위해 initializing을 해준다.

그리고 그값을 위에 적은 transform 함수를 통해 output으로 받게 하였다.

`updateViewPublisher`가 어디? 라고 생각한다면 위에 struct에 Output에 있다.

그래서 result Type을 리턴을 하게 되는데, 거기엔 다시 적어보면

```swift
let amountPerPerson: Double
let totalBill: Double
let totalTip: Double
```

즉 이렇게 리턴을 한다는것.

```swift
        output.updateViewPublisher.sink { result in
            print(">>>> \(result)")
        }.store(in: &cancellables)
```

그 이후에 이제 아웃풋의 값을 가지고.updatePublisher를 붙여서 값을 처리할것이다.

updateViewPublisher가 제공한 데이터를 처리 할 수 있는 sink메서드를 통해서 지금은 콘솔에 확인하는 용도로 print를 통해 출력하게 해두고, 이 subscription은 `.store(in: &cancellables)`을 통해 저장 한다.

그리고 CalulatorVC에 

```swift
override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        bind() // added
    }
```

해당 함수를 트리거하는걸 잊지 말자.

그러면 이상태로 출력을 하게되면?

```
>>>> Result(amountPerPerson: 500.0, totallBill: 1000.0, totalTip: 50.0)
```

이렇게 출력이 된다.

현재는 bind에 input에 대한 내용이 있지만, 애초에 Initialize를 할때, transform함수에 있는 result가 들어가므로 input에는 그냥 dummy로 생각하는게 좋다.

즉 현재 transform함수에는 input값을 처리하는 메서드가 없음.

그래서 위와같은 값이 콘솔로 출력이 된다.

### Observe 함수 구현 (view)

유져가 bill의 값을 직접 입력을 하게 되면 이 값이 ViewModel로 전달이 되어 값을 처리해야한다.

하지만 지금 직접 입력쪽의 ui인 InputView의 class에는 직접적으로 전달하는 컴포넌트가 없다.

이제 이부분을 핸들링할 Observe 함수 부터 구현하면서 진행을 해보도록 하겠다.

BillInputView에 임포트해주기

```swift
import Combine
import CombineCocoa
```

텍스트 필드에 입력한게 적용이 되는 observe 함수 구현

```swift
    
    private var cancellables = Set<AnyCancellable>()

    init () {
        super.init(frame: .zero)
        layout()
        observe() // added
    }

    private func observe() {
        textField.textPublisher.sink { text in
            print("text: \(text)")
        }.store(in: &cancellables)
    }
```

textField의 TextFieldPublisher 메서드를 사용해 퍼블리셔를 생성을 한다.

TextField에 Publisher? 그게 별도로 존재하나? 라고 생각 할 수 있기에, 아래 그 부분에 대한 내용을 코드로 적었다.

이건 실제로 Combine에 있는 내용.

```swift
public extension UITextField {
    /// A publisher emitting any text changes to a this text field.
    var textPublisher: AnyPublisher<String?, Never> {
        Publishers.ControlProperty(control: self, events: .defaultValueEvents, keyPath: \.text)
                  .eraseToAnyPublisher()
    }

    /// A publisher emitting any attributed text changes to this text field.
    var attributedTextPublisher: AnyPublisher<NSAttributedString?, Never> {
        Publishers.ControlProperty(control: self, events: .defaultValueEvents, keyPath: \.attributedText)
                  .eraseToAnyPublisher()
    }

    /// A publisher that emits whenever the user taps the return button and ends the editing on the text field.
    var returnPublisher: AnyPublisher<Void, Never> {
        controlEventPublisher(for: .editingDidEndOnExit)
    }

    /// A publisher that emits whenever the user taps the text fields and begin the editing.
    var didBeginEditingPublisher: AnyPublisher<Void, Never> {
        controlEventPublisher(for: .editingDidBegin)
    }
}
```

그래서 사용이 가능.

다시 정리하면 textField에 퍼블리셔를 생성하고, sink를 통해 textField에 값이 입력이 되면 콘솔로 바로 출력이 되게 보여주게 하는것이다.

실행하면

![May-01-2024 16-49-42](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/a2b60e54-5742-4f80-bb89-cefb97d0cabe){: width="50%" height="50%"}

바로 반응이 된다.

Stanby로 대기를 하다가, 유져의 입력이 들어오자마자 바로 출력을 하는 것이다.

## TextField의 값을 vc로 전달.

```swift
// BillInputView

private let billSubject: PassthroughSubject<Double, Never>  = .init()
    
var valuePublisher: AnyPublisher<Double, Never> {
    return billSubject.eraseToAnyPublisher()
}
```

billSubject를 PassthroughSubject를 사용 하였다.

Type이 Doube인 이유는? 굳이 우리가 저기서 String을 할 필요가 없다.

```swift
private func observe() {
        textField.textPublisher.sink { [unowned self] text in // modified
            billSubject.send(text?.doubleValue ?? 0) // added
        }.store(in: &cancellables)
    }
```

그리고 billSubject가 등장하여 text값을 전달한다.

PassthroughSubject를 가지고 있으므로, Subscriber가 요청할때만 값을 전달한다.

그리고 valuePublisher를 만들어 준다.

> valuePublisher? 는 굳이 왜?
>> billSubject는 값을 받아서 방출이 가능(방출이란 데이터를 보내는 의미)
>> 그런데 valuePublisher는 값을 방출만 할 수 있다. (즉 읽기의 기능)
>> 현재 billSubject는 앞에 private을 사용함으로써 해당 뷰에서만 가능
>> 그래서 그값을 방출(전달) 하기위해 publisher를 만들어 주어 전달하게 함.

> 둘의 공통점은 데이터 전달 / 차이점은 데이터의 수용의 차이.

이게 포인트.

```swift
var valuePublisher: AnyPublisher<Double, Never> {
        return billSubject.eraseToAnyPublisher()
    }
```

다시 VC로 돌아가서

```swift
// vc
private var cancellables = Set<AnyCancellable>()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layout()
        bind()
    }
    
    private func bind() {

        let input = CalculatorVM.Input(
            billPublisher: billInputView.valuePublisher, // modfied
            tipPulbisher: Just(.tenPercent).eraseToAnyPublisher(),
            splitPublisher: Just(5).eraseToAnyPublisher())
        
        let output = vm.transform(input: input)
        
    }
```

확인용도인데 bind에 있던것이다.

```swift
billInputView.valuePublisher.sink { bill in
            print("bill: \(bill)")
        }.store(in: &cancellables)
```

해당 부분을 위에 적고 실행하면 유져가 입력한 부분(bill)에 대한 값이 보여진다.

아까의 콘솔은 view에서의 출력이었다면, 이젠 그게 vc로 전달이 되어 프린트가 된것이다. 

입력한게 그대로 print가 된다.


물론 vm에서도 확인이 가능

```swift
func transform(input: Input) -> Output {
    
    let result = Result(amountPerPerson: 500, totalBill: 1000, totalTip: 50.0)
        
    return Output(updateViewPublisher: Just(result).eraseToAnyPublisher())
}
```

위의 부분에

```swift
input.billPublisher.sink { bill in
            print("the bill: \(bill)")
}.store(in: &cancellables)
```

이걸 적으면 역시나 콘솔로 확인이 된다. 즉 vm에도 데이터 전달이 된다는 뜻.