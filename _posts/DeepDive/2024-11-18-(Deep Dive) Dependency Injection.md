---
title: (Deep Dive) Dependency Injection
writer: Harold
date: 2024-11-18 07:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

이전에 개인과제를 하면서 또는 마지막 프로젝트를 하면서 튜터님께 들었던건 **의존성 주입(Dependency Injection)**을 해보는게 어떻겠냐? 라는 것이었다.

## 1. 의존성 주입이란?

그러면 의존성 주입이 뭔지 알아봐야한다.

위키에서는 의존성 주입을 다음과 같의 정의한다.

![CleanShot 2024-11-18 at 08 45 42](https://github.com/user-attachments/assets/ecc1d75e-efab-4b47-978f-2b2135863813)

내용이 길어 이미지로 한다.

의존성 주입에 관한 간단한 이미지는

![image](https://lucasvandongen.dev/images/dependencies_created_consumed.png)

이게 가장 적합해 보인다.

### 1-1. 의존성 주입의 장단점

의존성 주입은 객체 간의 의존 관계를 외부에서 주입해주는 설계 패턴이다. 의존성 주입은 다음과 같은 장점을 제공한다:
- 테스트 용이성: 외부에서 주입된 의존성을 Mock으로 교체할 수 있어 단위 테스트에 유리함.
- 코드의 유연성: 클래스가 직접 의존성을 생성하지 않기 때문에 다른 구현체로 쉽게 교체 가능함.
- 모듈화: 객체 간의 결합도가 낮아지며, 코드의 재사용성이 높아짐.

그리고 단점이라면
- 초기 설정이 복잡해질 수 있고, 필요 이상의 추상화로 인해 코드가 복잡해질 가능성도 있다.

### 1-2. 의존성 주입 예시

사실 의존성주입은 여태 우리가 어떤 class를 만들고 내부에 변수를 만들때 사용을 해왔다. (왜냐 그렇게 하지않으면 에러가 발생했으니까)

![CleanShot 2024-11-18 at 10 47 15](https://github.com/user-attachments/assets/52e648fc-5f54-46b5-9d13-0d8ef2ee49df)

#### 1-2-1. 의존성 주입을 하지않은 경우

```swift
class UserViewModel {
    private let userName = "Default User" // 직접 인스턴스를 생성하여 값 설정

    func printUserName() {
        print("👤 사용자 이름: \(userName)")
    }
}

// 사용 예시
let viewModel = UserViewModel()
viewModel.printUserName()

class NetworkService {
    func fetchData() {
        print("Data fetched from network")
    }
}

class UserViewModel {
    private let networkService = NetworkService() // 직접 인스턴스를 생성

    func loadData() {
        networkService.fetchData()
    }
}

// 사용 예시
let viewModel = UserViewModel()
viewModel.loadData()
```

1.	강한 결합: UserViewModel은 NetworkService에 직접 의존하고 있다.
2.	테스트 어려움: 네트워크 요청을 Mock 객체로 대체할 수 없어 테스트 작성이 어렵다.
3.	확장성 부족: NetworkService의 구현을 변경할 경우, UserViewModel도 수정해야 한다.

#### 1-2-2. 의존성 주입을 한 경우

```swift
class UserViewModel {
    private let userName: String

    // 생성자를 통한 의존성 주입
    init(userName: String) {
        self.userName = userName
    }

    func printUserName() {
        print("👤 사용자 이름: \(userName)")
    }
}

// 사용 예시
let viewModel = UserViewModel(userName: "John Doe")
viewModel.printUserName()

class NetworkService {
    func fetchData() {
        print("Data fetched from network")
    }
}

class MockNetworkService: NetworkService {
    override func fetchData() {
        print("Mock data fetched for testing")
    }
}

class UserViewModel {
    private let networkService: NetworkService

    // 생성자를 통한 의존성 주입
    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func loadData() {
        networkService.fetchData()
    }
}

// 사용 예시
let realService = NetworkService()
let mockService = MockNetworkService()

let viewModel = UserViewModel(networkService: realService)
viewModel.loadData() // 실제 네트워크 서비스 사용

let testViewModel = UserViewModel(networkService: mockService)
testViewModel.loadData() // Mock 네트워크 서비스 사용
```

1.	결합도 감소: UserViewModel은 NetworkService의 구체적인 구현에 의존하지 않고, 추상적인 인터페이스에 의존한다.
2.	테스트 용이성: Mock 객체를 쉽게 주입할 수 있어 단위 테스트가 가능하다.
3.	확장성 증가: 다른 NetworkService 구현체로 쉽게 교체할 수 있다.

#### 1-2-3. 정리

의존성 주입 방식에서 가장 기본적인 차이점은 객체 생성 시 **직접 인스턴스화**와 **타입을 통한 주입**의 차이다.

1. **직접 인스턴스화**: 의존성 주입을 사용하지 않는 경우, 필요한 클래스나 객체를 직접 인스턴스화하여 사용함.
   - 예시: `private let networkService = NetworkService()`
   - 이 방식은 객체를 직접 생성하므로, 해당 클래스 내부에서 의존성에 대한 강한 결합이 발생함.

2. **타입을 통한 의존성 주입**: 의존성 주입을 사용하는 경우, 생성자나 프로퍼티를 통해 외부에서 객체를 전달받음.
   - 예시: `private let networkService: NetworkService`
   - 이 방식은 객체를 외부에서 주입받으므로, 클래스 간의 결합도를 낮출 수 있으며, 테스트 및 유지보수가 용이해짐.

차이점 요약

| 방식                      | 설명                                 | 장점                          | 단점                      |
| ------------------------- | ------------------------------------ | ----------------------------- | ------------------------- |
| **직접 인스턴스화**       | 클래스 내부에서 직접 객체를 생성     | 간단하고 직관적               | 클래스 간의 강한 결합 발생 |
| **타입을 통한 의존성 주입** | 외부에서 객체를 주입받아 사용        | 결합도 낮춤, 테스트 용이       | 초기 설정이 복잡할 수 있음 |

#### 1-2-4. 그렇다면?

```swift
class Book {
    var title: String
    
    init(title: String) {
        self.title = title
    }
}

struct Book2 {
    var title: String
}
```

왜 class를 할땐 init을 해야하고, struct로 만든것에는 init을 안해도 에러가 발생하지 않나요?

우선 이런 의문을 가진다면, 

class와 struct의 차이를 정확하게 알고 넘어가야한다.

#### 1-2-4-1. struct vs class

![dog](https://miro.medium.com/v2/resize:fit:720/format:webp/1*FGOiCRT6MmN7Nb1lyeOV-g.png)

Swift에서 `class`는 **참조 타입(Reference Type)**이고, `struct`는 **값 타입(Value Type)**이다.

```swift
class SomeClass {
    var name: String
    init(name: String) {
        self.name = name
    }
}

var aClass = SomeClass(name: "Bob")
var bClass = aClass // aClass and bClass now reference the same instance!
bClass.name = "Sue"

println(aClass.name) // "Sue"
println(bClass.name) // "Sue"

struct SomeStruct {
    var name: String
    init(name: String) {
        self.name = name
    }
}

var aStruct = SomeStruct(name: "Bob")
var bStruct = aStruct // aStruct and bStruct are two structs with the same value!
bStruct.name = "Sue"

println(aStruct.name) // "Bob"
println(bStruct.name) // "Sue"
```

- **값 타입(Value Type)**
  - `struct`는 값 타입으로, 인스턴스가 생성될 때 **값이 복사(copy)**된다.
  - 서로 독립된 복사본을 가지며, 한 인스턴스의 변경은 다른 인스턴스에 영향을 주지 않는다.

- **참조 타입(Reference Type)**
  - `class`는 참조 타입으로, 인스턴스가 생성될 때 **메모리 주소(reference)**를 참조한다.
  - 여러 변수가 동일한 인스턴스를 가리킬 수 있으며, 한 곳에서 인스턴스를 변경하면 이를 참조하는 모든 곳에서 변경이 반영된다.

init의 차이?
`class`와 `struct`의 초기화 방식 차이는 Swift에서 **참조 타입과 값 타입의 특성 차이** 때문이다

1. `struct`의 경우
    - `struct`는 **값 타입**이기 때문에 Swift에서는 자동으로 **멤버와이즈 이니셜라이저(Memberwise Initializer)**를 제공한다.
    - 모든 프로퍼티가 값을 가지며, 초기화할 때 직접 값을 할당할 수 있도록 자동 생성된 초기화 메서드가 제공된다.
2. `class`의 경우
    - `class`는 **참조 타입**으로, 상속(Inheritance)을 지원하기 때문에 초기화 과정이 더 복잡하다.
    - `class`는 **기본값이 없는 저장 프로퍼티**를 가진 경우, 컴파일러가 자동으로 초기화 메서드를 생성하지 않는다. 따라서, 모든 저장 프로퍼티에 대해 명시적으로 초기화 메서드를 작성해야 한다.
3. 결론
    -  **값 타입(`struct`)**에서는 인스턴스의 복사본이 독립적으로 존재하므로, 컴파일러가 자동으로 초기화 메서드를 제공하여 인스턴스를 쉽게 생성할 수 있다.
    - **참조 타입(`class`)**에서는 상속과 초기화 과정이 복잡해질 수 있기 때문에, 초기화 메서드를 명시적으로 정의해야 한다. 이는 저장 프로퍼티가 올바르게 초기화되고, 부모 클래스의 초기화 규칙을 따르기 위함이다.

### 1-3. 의존성 주입의 방식

의존성 주입에는 3가지 방법이 있다.

- 생성자 주입 (Constructor Injection)
- 속성 주입 (Property Injection)
- 메서드 주입 (Method Injection)

#### 1-3-1. 생성자 주입

의존성을 객체 생성 시점에 주입받는 방식이다. 객체 생성과 동시에 의존성을 설정하므로 필수 의존성에 적합하다.

- 장점
    - 의존성이 nil이 될 가능성이 없어 안정적이다.
    - 객체 생성 시점에 모든 의존성이 설정되므로 초기화가 명확하다.
- 단점
    - 의존성이 많아질수록 생성자의 매개변수가 늘어나 복잡해질 수 있다.

```swift
class UserViewModel {
    private let userName: String

    // 생성자를 통한 의존성 주입
    init(userName: String) {
        self.userName = userName
    }

    func printUserName() {
        print("👤 사용자 이름: \(userName)")
    }
}

// 사용 예시
let viewModel = UserViewModel(userName: "John Doe")
viewModel.printUserName()
```

init을 통해 의존성을 주입을 해주면서 시작을 한다.
>초기화 단계에서 필수 의존성을 주입하여 객체를 생성함.

#### 1-3-2. 속성 주입

의존성을 객체 생성 후, 속성을 통해 주입하는 방식이다. 인스턴스를 생성한 후, 외부에서 직접 의존성을 할당한다.

- 장점
    - 유연하게 의존성을 주입할 수 있다.
    - 초기화 시점에 의존성을 설정하지 않아도 된다.
- 단점
    - 의존성이 주입되지 않을 경우 nil이 될 가능성이 있어, 옵셔널 타입이 필요하다.
    - 객체의 상태가 불완전할 수 있다.

```swift
class UserViewModel {
    var userName: String?

    func printUserName() {
        if let name = userName {
            print("👤 사용자 이름: \(name)")
        } else {
            print("⚠️ 사용자 이름이 설정되지 않았습니다.")
        }
    }
}

// 사용 예시
let viewModel = UserViewModel()
viewModel.userName = "Jane Doe" // 속성을 통한 의존성 주입
viewModel.printUserName()
```

생성자 주입과는 달리 ?를 붙여 Optional의 형태를 가지게 된다. (주입할수도 있고 안할수도 있으니)
선택지가 주어지는 방식이다. 
> 선택적인 의존성을 가진 객체를 초기화 후 속성으로 주입함 (Optional 사용 가능).

#### 1-3-3. 메서드 주입

의존성을 메서드를 통해 주입받는 방식이다. 필요한 시점에 메서드를 호출하여 의존성을 설정한다.

- 장점
    - 특정 메서드 호출 시점에 의존성을 주입할 수 있어 유연하다.
    - 객체의 생명 주기 동안 의존성을 변경할 수 있다.
- 단점
    - 메서드 호출 전에 의존성을 주입하지 않으면, 런타임 에러가 발생할 수 있다.
    - 메서드 호출을 잊으면 예상치 못한 문제가 발생할 수 있다.

```swift
class UserViewModel {
    private var userName: String?

    // 메서드를 통한 의존성 주입
    func setUserName(_ name: String) {
        self.userName = name
    }

    func printUserName() {
        if let name = userName {
            print("👤 사용자 이름: \(name)")
        } else {
            print("⚠️ 사용자 이름이 설정되지 않았습니다.")
        }
    }
}

// 사용 예시
let viewModel = UserViewModel()
viewModel.setUserName("Alice Doe") // 메서드를 통한 의존성 주입
viewModel.printUserName()
```

setUserName 함수를 만들었고, 여기서 주입을 하게 되는 방식이다.
>메서드를 통해 필요한 시점에 의존성을 주입하여 유연하게 변경 가능함.

#### 1-3-4. 정리

| 주입 방식      | 장점                                          | 단점                                          | 사용 예시                |
| -------------- | --------------------------------------------- | --------------------------------------------- | ------------------------ |
| 생성자 주입    | 의존성이 확실히 주입됨<br>초기화가 명확함    | 생성자 매개변수가 많아질 수 있음               | 필수 의존성, 초기화 시 필요 |
| 속성 주입      | 유연한 의존성 설정<br>초기화 후 주입 가능    | `nil` 체크 필요<br>객체 상태가 불완전할 수 있음 | 선택적 의존성, 설정 후 변경 가능 |
| 메서드 주입    | 필요 시점에 주입 가능<br>의존성 변경 가능    | 메서드 호출 잊을 가능성<br>런타임 에러 위험     | 동적으로 의존성을 설정할 때 |

의존성 주입 방식은 상황에 따라 선택하면 된다. 필수 의존성에는 생성자 주입을, 선택적 의존성에는 속성 주입이나 메서드 주입을 고려할 수 있다.

## 2. UIKit / SwiftUI에서의 의존성 주입 비교

### 2-1. UIKit

UIKit에서는 주로 생성자 주입(Initializer Injection)이 많이 사용되며, delegate나 closure를 통한 의존성 주입도 자주 사용된다.

#### 2-1-1. 의존성 주입이 된 경우

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private lazy var signViewModel = SignViewModel(signManager: signManager)

    }

    class ManageViewModel {
        private let manageManager: ManageManager
        
        init(manageManager: ManageManager) {
            self.manageManager = manageManager
        }
    }

    class ManageViewController: UIViewController {

        var viewModel: ManageViewModel!

        convenience init(viewModel: ManageViewModel) {
                self.init()
                self.viewModel = viewModel
        }
}
```

이 경우는 생성자 주입을 통해 만들어 졌다.

##### 2-1-1-1. Delegate 통한 의존성 주입

Delegate 패턴을 사용한 의존성 주입은 **프로토콜**을 사용하여 객체 간의 느슨한 결합을 가능하게 한다. 이 패턴은 데이터를 전달할 때, Sender 클래스에서 직접 Receiver 클래스를 참조하지 않고, 프로토콜을 통해 의존성을 주입받는 방식이다. 이 예시에서는 **프로토콜 정의**, **Sender 클래스**, **Receiver 클래스**로 나누어 설명할 수 있다

이전에 [Data Communication이라는 글](https://haroldfromk.github.io/posts/(Deep-Dive)-Data-Communication/){:target="_blank"}을 작성했었는데, 그때 Protocol (Delegate) 부분이 있는데, 이부분 역시 의존성 주입에 해당하므로 그 코드를 통한 예시를 적용해본다.

###### 2-1-1-1-1. **프로토콜 정의**

`SendDelegate`라는 프로토콜을 정의한다. 이 프로토콜은 데이터를 전달하기 위해 `sendData(data:)` 메서드를 선언한다.

- 이 프로토콜은 데이터를 전달받을 객체가 구현해야 할 메서드를 정의한다.
- Sender 클래스는 이 프로토콜을 통해 데이터를 전달할 수 있다.

```swift
// 1. 프로토콜 정의
protocol SendDelegate {
    func sendData(data: String)
}
```

###### 2-1-1-1-2. **Sender 클래스: SecondViewController**

`SecondViewController`는 데이터를 전달하는 클래스이다. 여기서는 `delegate` 속성을 통해 외부에서 의존성을 주입받는다.

- `delegate` 속성은 `SendDelegate` 타입으로 정의되며, 외부에서 주입된다.
- 버튼을 클릭했을 때(`dataSendButton` 메서드), delegate의 `sendData(data:)` 메서드를 호출하여 데이터를 전달한다.
- 데이터 전송 후, 현재 화면을 pop하여 이전 화면으로 돌아간다.


**의존성 주입의 포인트**:
- `SecondViewController`는 직접적으로 데이터를 전달할 대상(Receiver 클래스)을 알지 못한다.
- 대신, delegate를 통해 데이터를 전달하며, 이는 외부에서 주입된다.

```swift
// 2. Sender class: SecondViewController
class SecondViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    
    var delegate: SendDelegate? // 의존성 주입을 받을 delegate 속성
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
  
    @IBAction func dataSendButton(_ sender: UIButton) {
        if let text = textField.text {
            delegate?.sendData(data: text) // 주입된 delegate를 통해 데이터 전달
        }
        
        self.navigationController?.popViewController(animated: true)
    }
}
```

###### 2-1-1-1-3. **Receiver 클래스: FirstViewController**

`FirstViewController`는 데이터를 받는 클래스이다. 이 클래스는 `SendDelegate` 프로토콜을 채택하고, 데이터를 전달받는 메서드를 구현한다.

- `sendData(data:)` 메서드를 구현하여 데이터를 전달받고, 이를 UI에 반영한다.
- 버튼 클릭 시(`getDataButton` 메서드), **SecondViewController**를 인스턴스화하고, delegate 속성에 `self`를 할당한다.
- 이로써 **FirstViewController**는 **SecondViewController**의 delegate 역할을 하게 되며, 데이터를 전달받을 준비가 된다.

**의존성 주입의 포인트**:
- `FirstViewController`는 delegate 패턴을 통해 **SecondViewController**와 데이터를 주고받는다.
- `self`를 delegate로 설정함으로써 의존성을 주입받는다.

```swift
// 3. Receiver class: FirstViewController
class FirstViewController: UIViewController, SendDelegate {

    @IBOutlet weak var currentLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func sendData(data: String) {
        currentLabel.text = data // 데이터를 전달받아 UI 업데이트
    }

    @IBAction func getDataButton(_ sender: UIButton) {
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            secondVC.delegate = self // 의존성 주입
            self.navigationController?.pushViewController(secondVC, animated: true)
        }
    }
}
```
###### 2-1-1-1-4. 결론

이 예시에서 의존성 주입은 다음과 같은 흐름으로 이루어진다:

1. `SecondViewController`는 데이터를 전달하기 위해 `SendDelegate` 프로토콜 타입의 `delegate` 속성을 주입받는다.
2. `FirstViewController`는 `SendDelegate` 프로토콜을 준수하며, 자신을 delegate로 주입하여 데이터를 전달받는다.
3. 데이터는 delegate의 메서드를 통해 전달되며, 이는 프로토콜을 통해 간접적으로 이루어지기 때문에, 클래스 간의 결합도가 낮아진다.

**장점**
- **결합도 감소**: Sender 클래스는 Receiver 클래스에 대한 구체적인 의존이 없으며, 대신 프로토콜에 의존한다.
- **확장성**: 여러 클래스에서 `SendDelegate` 프로토콜을 구현할 수 있어, 다양한 객체 간의 데이터 통신이 가능하다.
- **테스트 용이성**: Mock 객체를 사용하여 delegate 메서드 호출을 쉽게 테스트할 수 있다.

**단점**
- **복잡성 증가**: 간단한 데이터 전달에서는 delegate 패턴이 오히려 코드를 복잡하게 만들 수 있다.
- **순환 참조 위험**: delegate를 사용할 때 `[weak self]`를 사용하지 않으면 메모리 누수가 발생할 수 있다.

##### 2-1-1-2. Closure를 통한 의존성 주입

이건 이전에 Final Project 했던 부분을 가져왔다.

Closure를 통한 의존성 주입은 간단한 콜백 처리를 위해 자주 사용되는 방식이다. Delegate 패턴과는 다르게, Closure를 사용하면 간단한 코드 블록을 통해 필요한 동작을 외부에서 주입받아 실행할 수 있다.

이 예시에서는 SceneDelegate, GreetingViewController, 그리고 GreetingBodyView가 서로 연결되어 있으며, Closure를 통해 필요한 동작이 주입되고 실행된다.

**구성 요소**
1. Closure 정의: GreetingViewController에서 네 가지 Closure(appleTapped, googleTapped, hiddenTapped, guestTapped)를 정의한다.
2. Injection (의존성 주입): SceneDelegate에서 GreetingViewController의 인스턴스를 생성하고, 네 가지 Closure를 외부에서 주입한다.
3. Closure 실행: GreetingBodyView에서 사용자 액션(버튼 클릭)이 발생하면, Closure를 호출하여 외부에서 정의된 동작을 실행한다.

###### 2-1-1-2-1. Closure 정의

GreetingViewController는 네 가지 Closure(appleTapped, googleTapped, hiddenTapped, guestTapped)를 정의한다.
- 이 Closure들은 사용자 액션(예: 버튼 클릭)에 대한 동작을 정의할 수 있다.
- 외부에서 동작을 주입받아, 해당 액션이 발생할 때 실행된다.

```swift
// Closure 정의: GreetingViewController
private var appleTapped: (() -> Void)!
private var googleTapped: (() -> Void)!
private var hiddenTapped: (() -> Void)!
private var guestTapped: (() -> Void)!
```

- 이 Closure들은 사용자 액션(예: 버튼 클릭)에 대한 동작을 정의할 수 있다.
- 외부에서 동작을 주입받아, 해당 액션이 발생할 때 실행된다.

###### 2-1-1-2-2. 의존성 주입: SceneDelegate

SceneDelegate는 GreetingViewController의 인스턴스를 생성하고, 네 가지 Closure를 주입한다.
- 각각의 Closure는 외부에서 정의된 동작으로, SignViewModel의 메서드를 호출하거나, 특정 UI 처리를 수행한다.
- Closure는 Delegate 패턴과 다르게 간단하게 정의할 수 있으며, 함수 호출처럼 사용된다.

**의존성 주입의 포인트:**
- GreetingViewController는 직접 SignViewModel에 접근하지 않고, Closure를 통해 외부에서 필요한 동작을 주입받는다.
- 이는 클래스 간의 결합도를 줄이고, 더 유연한 구조를 제공한다.

```swift
// SceneDelegate에서 의존성 주입
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
greetingVC = GreetingViewController(
    appleTapped: { [weak signViewModel] in
        signViewModel?.appleLoginDidTapped()
    },
    googleTapped: { [weak signViewModel] in
        signViewModel?.googleLoginDidTapped(presentViewController: self.greetingVC)
    },
    hiddenTapped: {
        self.greetingVC.generate(completion: { bool in
            if bool {
                self.greetingVC.present(self.manageVC, animated: true)
            }
        })
    },
    guestTapped: {
        self.customUser = CustomUser(guestUID: "guest")
        self.switchToMainTabBarController()
    },
    viewModel: signViewModel)
}
```

###### 2-1-1-2-3. Closure 실행: GreetingViewController와 GreetingBodyView

GreetingViewController는 외부에서 주입받은 Closure를 사용자 액션이 발생할 때 GreetingBodyView를 통해 실행한다.
- 사용자가 “Apple 로그인” 버튼을 클릭하면, GreetingBodyView에서 appleTapped라는 Closure가 호출되고, 이는 외부에서 주입된 동작을 실행한다.
- 이 방식은 간단한 콜백 처리나 이벤트 기반의 사용자 액션을 처리할 때 매우 유용하며, 직접적인 의존성을 줄여준다.

**의존성 주입의 포인트:**
- GreetingViewController는 직접적으로 SignViewModel이나 다른 객체에 의존하지 않고, Closure를 통해 필요한 동작을 주입받는다.
- GreetingBodyView는 사용자 액션에 따라 주입된 Closure를 실행하며, 이는 Delegate 패턴과 비교했을 때 더 간단하고 코드량이 적다.
- 그러나 복잡한 데이터 흐름이나 여러 메서드가 연계되는 경우에는 Delegate 패턴이 더 적합할 수 있다.

```swift
// GreetingViewController에서의 Closure 주입
final class GreetingViewController: UIViewController {
    private lazy var greetingBodyView: GreetingBodyView = {
        let view = GreetingBodyView()
        view.appleTapped = appleTapped   // 외부에서 주입된 Closure 연결
        view.googleTapped = googleTapped // 외부에서 주입된 Closure 연결
        view.guestTapped = guestTapped   // 외부에서 주입된 Closure 연결
        return view
    }()
}

// GreetingBodyView에서의 Closure 실행
final class GreetingBodyView: UIView {
    var appleTapped: (() -> Void)?
    var googleTapped: (() -> Void)?
    var guestTapped: (() -> Void)?

    @objc func appleButtonDidTapped() {
        appleTapped?() // 주입된 Closure 실행
    }

    @objc func googleButtonDidTapped() {
        googleTapped?() // 주입된 Closure 실행
    }

    @objc func guestButtonDidTapped() {
        guestTapped?() // 주입된 Closure 실행
    }
}
```

###### 2-1-1-2-4. 결론

이 예시에서 의존성 주입은 다음과 같은 흐름으로 이루어진다:

1.	Closure 정의: GreetingViewController에서 네 가지 Closure(appleTapped, googleTapped, hiddenTapped, guestTapped)를 정의하고, 외부에서 주입받을 준비를 한다.
2.	Closure 주입: SceneDelegate에서 GreetingViewController의 인스턴스를 생성하고, 필요한 동작을 정의하여 Closure로 주입한다.
3.	Closure 실행: GreetingBodyView에서 사용자가 버튼을 클릭하면, 해당 Closure가 호출되고, 외부에서 정의된 동작이 실행된다.

**장점**
- **결합도 감소**: Closure를 통한 의존성 주입은 클래스 간의 직접적인 의존성을 줄이고, 함수 호출을 통해 간접적으로 의존성을 주입할 수 있다.
- **코드의 간결함**: Delegate 패턴처럼 프로토콜을 정의하고 메서드를 구현할 필요 없이, 간단하게 Closure로 콜백을 처리할 수 있다.
- **유연한 동작 주입**: 외부에서 동작을 정의하고 주입할 수 있어, 다양한 시나리오에 맞춰 쉽게 동작을 변경할 수 있다.
- **콜백 처리의 용이성**: 비동기 작업이나 사용자 액션 처리에 적합하며, Closure로 간단하게 콜백을 처리할 수 있다.

**단점**
- **복잡한 데이터 흐름에 부적합**: 여러 메서드 간의 복잡한 데이터 흐름이 있을 경우, Closure 사용은 오히려 가독성을 떨어뜨리고 유지보수가 어려워질 수 있다.
- **순환 참조 위험**: Closure 사용 시 `[weak self]`를 사용하지 않으면 강한 순환 참조(Strong Retain Cycle)가 발생할 수 있어 메모리 누수가 생길 수 있다.
- **가독성 저하 가능성**: 중첩된 Closure나 복잡한 로직을 포함할 경우, 코드의 가독성이 떨어지고 흐름을 파악하기 어려워질 수 있다.
- **테스트 어려움**: Closure는 직접 함수를 주입받는 방식이기 때문에, 단위 테스트 시 Mock 객체를 사용하는 것이 어려울 수 있다.

#### 2-1-2. 의존성 주입이 되지 않은 경우

아래는 의존성 주입이 이루어지지 않은 경우의 예시이다. DetailViewController에서는 CardViewModel을 직접 인스턴스화하고 있다.
- 이 경우, DetailViewController는 CardViewModel의 구체적인 구현에 의존하고 있어, 테스트나 유지보수 시 확장성이 떨어진다.
- Mock 객체를 주입하거나 다른 구현체로 대체할 수 없어, 단위 테스트가 어려워진다.

```swift
class DetailViewController: UIViewController, UISearchBarDelegate {

    // ViewModel 인스턴스를 직접 생성하여 의존성 주입 없이 사용
    let viewModel = CardViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        bind() // ViewModel의 데이터를 바로 바인딩
    }

    private func bind() {
        viewModel.$card
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cards in
                guard let card = cards.first else { return }
                self?.configureView(with: card)
            }
            .store(in: &cancellables)
    }

    private func configureView(with card: Card) {
        titleLabel.text = card.title
        descriptionLabel.text = card.description
    }
}
```

### 2-2. SwiftUI

SwiftUI에서는 주로 `@EnvironmentObject`, `@StateObject`, `@ObservedObject`를 통해 의존성을 주입한다.

- `@StateObject`: 객체를 처음부터 소유하고 관리
- `@ObservedObject`: 외부에서 주입된 객체를 관찰
- `@EnvironmentObject`: 상위 뷰에서 주입된 객체를 사용할 때

이 방식은 뷰 간의 데이터 공유와 상태 관리를 쉽게 해준다.

예시는 [State/ObservedObject비교 글](https://haroldfromk.github.io/posts/ObjectTest/){:target="_blank"}의 코드 예시를 적용한다.

#### 2-2-1. 의존성 주입이 된 경우

##### 2-2-1-1  @StateObject, @ObservedObject 사용

SwiftUI에서는 @StateObject와 @ObservedObject를 통해 의존성 주입이 이루어진다. @StateObject는 뷰가 처음 생성될 때 인스턴스를 초기화하고 소유하는 데 사용되며, @ObservedObject는 외부에서 주입된 객체를 관찰하는 데 사용된다. 

###### 2-2-1-1-1. MainView: 의존성 주입

- MainView에서 @StateObject를 사용하여 wishViewModel, cartViewModel, sdCartViewModel을 초기화하고 관리함.
- ItemView에 이 ViewModel들을 주입하여 의존성을 전달함.

```swift
struct MainView: View {
    @StateObject var wishViewModel = WishViewModel()
    @StateObject var cartViewModel = CartViewModel()
    @StateObject var sdCartViewModel = SDCartViewModel()

    var body: some View {
        NavigationStack {
            TabView {
                Tab("Display", systemImage: "eye") {
                    ItemView(
                        wishViewModel: wishViewModel,
                        cartViewModel: cartViewModel,
                        sdCartViewModel: sdCartViewModel
                    )
                }
            }
        }
    }
}
```

###### 2-2-1-1-2. 의존성 주입된 ViewModel 사용

- ItemView는 외부에서 주입된 wishViewModel을 @ObservedObject로 받아서 사용함.
- cartViewModel과 sdCartViewModel은 @StateObject로 초기화된 상태로 전달받아 사용함.
- 이 구조는 뷰 간의 데이터 흐름을 명확하게 하고, 데이터의 일관성을 유지함.

**의존성 주입의 포인트**
1.	MainView에서 ViewModel을 생성(@StateObject)하고, 이를 하위 뷰(ItemView)에 전달하여 의존성을 주입함.
2.	ItemView는 외부에서 주입된 ViewModel을 사용하여 데이터를 처리하고 사용자 인터페이스를 업데이트함.

```swift
struct ItemView: View {
    @ObservedObject var wishViewModel: WishViewModel
    @StateObject var cartViewModel: CartViewModel
    @StateObject var sdCartViewModel: SDCartViewModel

    Button("Core추가") {
        if let checkTitle = wishViewModel.wishList.first?.title {
            isDuplicated = cartViewModel.checkDuplicate(title: checkTitle)
            if isDuplicated == false {
                cartViewModel.addCart(model: wishViewModel.wishList.first!)
            }
        }
    }
}
```

##### 2-2-1-2 @EnvironmentObject 사용

SwiftUI에서는 `@EnvironmentObject`를 사용하면 뷰 계층 전체에서 공유되는 객체를 쉽게 주입하고 사용할 수 있다. 이는 `@ObservedObject`와 달리 직접 인자로 전달할 필요 없이 상위 뷰에서 환경 객체로 등록되면, 하위 모든 뷰에서 자동으로 접근할 수 있다.

###### 2-2-1-2-1. MainView: EnvironmentObject 등록

- @StateObject로 초기화한 ViewModel들을 .environmentObject() modifier를 사용해 등록한다.
- 등록된 ViewModel은 하위 뷰에서 @EnvironmentObject로 쉽게 접근할 수 있다.

```swift
struct MainView: View {
    @StateObject var wishViewModel = WishViewModel()
    @StateObject var cartViewModel = CartViewModel()
    @StateObject var sdCartViewModel = SDCartViewModel()

    var body: some View {
        NavigationStack {
            TabView {
                Tab("Display", systemImage: "eye") {
                    ItemView()
                }
                Tab("CoreCart", systemImage: "cart") {
                    CoreCartView(cartViewModel: cartViewModel)
                }
                Tab("SDCart", systemImage: "cart.circle") {
                    SDCartView(sdCartViewModel: sdCartViewModel)
                }
                Tab("Test", systemImage: "star") {
                    TestView()
                }
            }
            .environmentObject(wishViewModel)
            .environmentObject(cartViewModel)
            .environmentObject(sdCartViewModel)
        }
    }
}
```

###### 2-2-1-2-2. ItemView: EnvironmentObject 사용

- `@EnvironmentObject`를 사용하여 `MainView`에서 등록한 `ViewModel`들을 주입받는다.
- `@ObservedObject`와 달리, 인자로 전달받지 않고 환경에서 자동으로 주입된다.
- 이 방식은 ViewModel 간의 데이터 공유를 쉽게 해주며, 코드 간소화에 도움이 된다.

**의존성 주입의 포인트**
1.	MainView에서 @StateObject로 생성한 ViewModel을 .environmentObject()로 등록.
2.	ItemView에서는 @EnvironmentObject를 사용해 ViewModel을 자동으로 주입받아 사용.
3.	상위 뷰(MainView)에서 ViewModel을 변경하면, 하위 뷰(ItemView)에서도 자동으로 반영된다.

```swift
struct ItemView: View {
    @EnvironmentObject var wishViewModel: WishViewModel
    @EnvironmentObject var cartViewModel: CartViewModel
    @EnvironmentObject var sdCartViewModel: SDCartViewModel
}
```

## 3. 결론

의존성 주입은 코드의 **유연성**, **재사용성**, **테스트 용이성**을 높여주는 중요한 설계 패턴이다. 이번 글에서는 UIKit과 SwiftUI에서의 다양한 의존성 주입 방식(Delegate, Closure, 생성자 주입, 속성 주입, 메서드 주입 등)을 비교하고 예시를 통해 설명했다.

### 3-1. 어떤 방식을 선택할 것인가?

1. **간단한 데이터 전달**에는 **Closure**가 적합하다. Closure는 Delegate 패턴보다 코드가 간결하고, 비동기 작업이나 사용자 액션 처리에 용이하다.
2. **복잡한 데이터 흐름**이나 여러 메서드 간의 협력이 필요한 경우에는 **Delegate 패턴**이 더 적합하다. Delegate는 프로토콜을 통해 명확한 계약을 정의하고, 클래스 간 결합도를 낮출 수 있다.
3. **상위 뷰에서 하위 뷰로 공통 객체를 전달**해야 한다면, SwiftUI에서는 **@EnvironmentObject**가 편리하다. 이를 통해 뷰 계층 전체에서 동일한 객체를 쉽게 공유할 수 있다.
4. **객체 생성과 동시에 의존성을 설정**해야 한다면, **생성자 주입**이 안정적이고 초기화가 명확하다.
5. **선택적인 의존성**이나 동적으로 설정할 필요가 있는 경우에는 **속성 주입**이나 **메서드 주입**이 유연하다.

### 3-2. 의존성 주입의 Best Practice

- **의존성은 인터페이스(프로토콜)**로 정의하고, **구현체**는 외부에서 주입받는 것이 좋다. 이를 통해 클래스 간의 결합도를 낮추고, Mock 객체를 사용하여 테스트를 쉽게 할 수 있다.
- **순환 참조(Strong Retain Cycle)**를 주의해야 한다. Delegate 패턴이나 Closure를 사용할 때는 `[weak self]`를 사용하여 메모리 누수를 방지해야 한다.
- **프로젝트의 규모와 복잡도**에 따라 적절한 방식을 선택해야 한다. 간단한 프로젝트에서는 Closure나 속성 주입이 더 적합할 수 있으며, 복잡한 대규모 프로젝트에서는 Delegate 패턴이나 생성자 주입이 더 안전할 수 있다.

### 3-3. 의존성 주입의 중요성

의존성 주입은 클래스 간의 결합도를 낮추고, 모듈화된 코드 설계와 테스트 용이성을 제공한다. 이는 특히 협업이 많은 대규모 프로젝트나 다양한 환경에서의 테스트가 필요한 프로젝트에서 중요한 설계 원칙이다.

- **테스트 가능성 증가**: 외부에서 의존성을 주입받기 때문에, 테스트 시 Mock 객체나 Stub 객체를 쉽게 사용할 수 있다.
- **코드의 재사용성 및 유지보수성 향상**: 클래스가 구체적인 구현에 의존하지 않기 때문에, 다른 구현체로 교체하거나 기능을 확장할 때 코드 수정이 최소화된다.
- **모듈화된 설계**: 의존성 주입은 SOLID 원칙 중 하나인 **DIP(Dependency Inversion Principle)**를 따르며, 코드 모듈화와 유지보수를 쉽게 만든다.

## 4. 면접 질문 대비: 의존성 주입 (Dependency Injection)

역시 이런 질문과 대답생성은 GPT가 상당히 편리하다.

### 4-1. 면접에서 자주 묻는 질문

1. **의존성 주입이란 무엇인가요?**
   - 의존성 주입은 클래스가 직접 의존성을 생성하지 않고, 외부에서 주입받아 사용하는 설계 패턴이다. 이를 통해 클래스 간의 결합도를 낮추고, 코드의 유연성과 테스트 용이성을 높일 수 있다.

2. **의존성 주입의 장단점은 무엇인가요?**
   - **장점**: 결합도 감소, 테스트 용이성 증가, 코드의 모듈화와 재사용성 향상
   - **단점**: 초기 설정이 복잡해질 수 있으며, 과도한 추상화로 인해 코드의 복잡도가 증가할 수 있다.

3. **의존성 주입의 종류에는 어떤 것이 있나요?**
   - **생성자 주입**: 객체 생성 시 의존성을 주입받아 필수 의존성을 설정함.
   - **속성 주입**: 객체 생성 후 속성을 통해 선택적인 의존성을 주입함.
   - **메서드 주입**: 메서드를 호출하여 필요한 시점에 의존성을 주입함.

4. **UIKit과 SwiftUI에서 의존성 주입 방식의 차이는 무엇인가요?**
   - UIKit에서는 주로 생성자 주입과 Delegate, Closure 패턴을 사용함.
   - SwiftUI에서는 `@StateObject`, `@ObservedObject`, `@EnvironmentObject`를 사용하여 ViewModel을 주입받아 사용함.

5. **의존성 주입과 Factory 패턴의 차이점은 무엇인가요?**
   - **의존성 주입**은 객체의 생성을 외부에서 주입받아 결합도를 낮추는 방식이고, **Factory 패턴**은 객체 생성을 전담하는 Factory 클래스를 통해 인스턴스를 생성하는 방식이다.
   - Factory 패턴은 객체의 생성 로직을 캡슐화하지만, 의존성 주입은 클래스 간의 결합도를 줄이는 데 중점을 둔다.

6. **의존성 주입에서 순환 참조(Strong Retain Cycle) 문제는 어떻게 해결할 수 있나요?**
   - Delegate 패턴이나 Closure 사용 시 `[weak self]`나 `[unowned self]`를 사용하여 순환 참조 문제를 해결할 수 있다.

### 4-2. 예상 면접 질문과 답변 예시

**Q1. 생성자 주입과 속성 주입의 차이점은 무엇인가요?**

- **A**: 생성자 주입은 객체 생성 시 필수 의존성을 설정하는 방식으로, 의존성이 nil이 될 가능성이 없다. 반면 속성 주입은 객체 생성 후에 선택적으로 의존성을 설정할 수 있는 방식으로, nil이 될 수 있어 옵셔널 처리가 필요하다.

**Q2. SwiftUI에서 @ObservedObject와 @EnvironmentObject의 차이점은 무엇인가요?**

- **A**: `@ObservedObject`는 외부에서 주입된 객체를 관찰하며, 뷰가 인스턴스를 소유하지 않는다. 반면 `@EnvironmentObject`는 상위 뷰에서 주입된 공유 객체로, 하위 뷰에서 자동으로 접근할 수 있어, 전체 뷰 계층에서 데이터를 공유하기에 적합하다.

**Q3. Delegate 패턴과 Closure 패턴 중 어느 것이 더 적합한가요?**

- **A**: 간단한 콜백이나 비동기 작업에는 Closure가 더 적합하다. 하지만 여러 메서드 간의 복잡한 데이터 흐름이나 명확한 계약이 필요한 경우 Delegate 패턴이 더 적합하다. Delegate 패턴은 프로토콜을 통해 명확한 인터페이스를 정의할 수 있기 때문이다.

## 5. 추가 (Generic을 사용한다면?)

의존성 주입에서 **제네릭(Generic)**을 사용하면 더욱 유연하고 타입 안전한 코드를 작성할 수 있다. 제네릭은 타입을 추상화하여 다양한 타입의 객체를 의존성 주입할 수 있게 해준다. 이를 통해 의존성 주입의 확장성과 재사용성을 크게 높일 수 있다.

### 5-1. Generic 의존성 주입의 장점

- **유연성**: 제네릭을 사용하면 다양한 구현체를 쉽게 주입할 수 있어 코드의 확장성이 높아진다.
- **타입 안전성**: 컴파일 시점에 타입이 결정되므로 런타임 에러가 줄어들고, 코드의 안전성이 향상된다.
- **재사용성**: 제네릭은 동일한 로직을 여러 타입에 대해 재사용할 수 있어, 코드 중복을 줄이고 유지보수를 쉽게 만든다.

### 5-2. 제네릭 의존성 주입의 사용 예시

제네릭을 통한 의존성 주입의 예시는 아래와 같다. 이 예시에서는 `NetworkService` 프로토콜을 채택한 다양한 구현체(`RealNetworkService`, `MockNetworkService`)를 주입할 수 있다.

- `ViewModel` 클래스는 `Service`라는 제네릭 타입을 사용하고, 이 타입은 `NetworkService` 프로토콜을 준수해야 한다.
- `ViewModel`은 생성자에서 제네릭 타입의 객체를 주입받아, 의존성을 설정한다.

```swift
protocol NetworkService {
    func fetchData()
}

class RealNetworkService: NetworkService {
    func fetchData() {
        print("Real network service fetching data...")
    }
}

class MockNetworkService: NetworkService {
    func fetchData() {
        print("Mock network service fetching data...")
    }
}

// Generic ViewModel
class ViewModel<Service: NetworkService> {
    private let service: Service

    init(service: Service) {
        self.service = service
    }

    func loadData() {
        service.fetchData()
    }
}

// 사용 예시
let realService = RealNetworkService()
let mockService = MockNetworkService()

let realViewModel = ViewModel(service: realService)
realViewModel.loadData() // Real network service fetching data...

let mockViewModel = ViewModel(service: mockService)
mockViewModel.loadData() // Mock network service fetching data...
```

### 5-3. 제네릭 사용 시 고려사항

- **타입 제약 추가**: 필요에 따라 제네릭 타입에 프로토콜 제약을 추가할 수 있다. (`Service: NetworkService`와 같이 제약 설정)
- **복잡도 증가**: 제네릭 사용은 코드의 유연성을 높이지만, 지나치게 복잡한 제네릭 코드는 오히려 가독성을 떨어뜨릴 수 있다.
- **의존성 주입의 유형 결정**: 제네릭은 주로 생성자 주입에서 많이 사용되며, 특히 다양한 구현체나 Mock 객체를 사용하는 테스트 환경에서 유용하다.

### 5-4. SwiftUI에서 Generic 의존성 주입

SwiftUI에서도 제네릭을 활용하여 ViewModel을 의존성 주입할 수 있다. SwiftUI의 `@ObservedObject`나 `@StateObject`를 제네릭 타입으로 선언하면 다양한 ViewModel을 주입받아 사용할 수 있다. 이 방식은 **동일한 UI 구조**를 유지하면서 **다양한 데이터 소스**와 쉽게 연결할 수 있게 해준다.

```swift
struct ContentView<ViewModel: NetworkService>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        VStack {
            Text("Fetching data...")
            Button("Load Data") {
                viewModel.fetchData()
            }
        }
    }
}

// 사용 예시
let realService = RealNetworkService()
ContentView(viewModel: realService)
```

### 5-5. 결론

제네릭을 사용한 의존성 주입은 코드의 유연성과 재사용성을 크게 높여준다. 그러나 지나친 제네릭 사용은 오히려 코드의 복잡성을 높일 수 있으므로, **프로젝트의 요구 사항과 복잡도에 따라 신중하게 선택**하는 것이 중요하다.

- **Mock 객체나 다양한 구현체**를 사용하는 테스트 환경에서 제네릭 의존성 주입은 특히 유용하다.
- **타입 안정성**과 **재사용성**을 확보할 수 있어, 유지보수와 확장에 강한 설계를 가능하게 한다.

> 제네릭은 의존성 주입에서 선택 사항이지만, 적절하게 사용하면 코드의 품질을 한 단계 높일 수 있다.

## 6. 의존성 역전 원칙(Dependency Inversion Principle, DIP)

![Image](https://miro.medium.com/v2/resize:fit:640/format:webp/1*E3h8Rh83fO1rvwu5VO1BGA.jpeg)

1.	S: Single Responsibility Principle (단일 책임 원칙)
2.	O: Open/Closed Principle (개방-폐쇄 원칙)
3.	L: Liskov Substitution Principle (리스코프 치환 원칙)
4.	I: Interface Segregation Principle (인터페이스 분리 원칙)
5.	D: Dependency Inversion Principle (의존성 역전 원칙)

여기서 의존성 역전 원칙(Dependency Inversion Principle)은 다음의 두 가지 핵심 규칙으로 정의된다:

1. 고수준 모듈이 저수준 모듈에 의존하지 말아야 한다.
    - 고수준 모듈(High-level module)은 시스템의 주요 로직이나 비즈니스 로직을 다루는 모듈이다.
    - 저수준 모듈(Low-level module)은 데이터베이스, 네트워크 서비스, 파일 입출력 등 구체적인 세부 사항을 다루는 모듈이다.
    - DIP에서는 고수준 모듈이 저수준 모듈에 의존하지 않고, 추상화된 인터페이스에 의존해야 한다고 권장한다.
    - 이를 통해 고수준 모듈이 저수준 모듈의 구현 세부 사항에 종속되지 않게 하고, 시스템의 확장성과 변경 용이성을 높인다.
2. 추상화된 인터페이스는 구체적인 구현 세부 사항에 의존하지 않아야 한다.
    - 추상화된 인터페이스(Interface)는 구체적인 클래스가 아니라 프로토콜이나 인터페이스와 같은 추상적인 타입이다.
    - DIP에서는 이 인터페이스가 구체적인 구현 클래스에 의존하지 말아야 한다고 권장한다.
    - 구체적인 클래스는 추상화된 인터페이스를 구현함으로써, 인터페이스와 클래스 간의 의존성을 반전시킨다.
    - 이를 통해 인터페이스는 다양한 구체적인 구현체와 호환될 수 있으며, 변경이 필요할 때 고수준 모듈에는 영향을 미치지 않는다.

### 6-1. 의존성 역전 원칙이란?

의존성 역전 원칙은 **고수준 모듈(High-level module)**이 저수준 모듈(Low-level module)에 의존하지 않고, **둘 다 추상화된 인터페이스에 의존해야 한다**는 원칙이다. 이를 통해 **유연하고 확장성 있는 설계**가 가능해진다.

**전통적인 설계:**
- 고수준 모듈이 저수준 모듈에 의존한다.
- 구현 세부 사항이 변경되면 고수준 모듈도 영향을 받는다.

**의존성 역전 설계:**
- 고수준 모듈과 저수준 모듈이 모두 추상화된 인터페이스에 의존한다. 이는 인터페이스가 구현 세부 사항으로부터 독립적임을 의미한다.
- 구현 세부 사항이 변경되더라도 고수준 모듈에는 영향을 미치지 않는다.

### 6-2. DIP의 예시

#### 6-2-1. 문제점이 있는 코드 (의존성 역전 원칙 위반)

- 고수준 모듈이 직접 저수준 모듈에 의존하고 있어, 확장성과 테스트 용이성이 떨어진다.

```swift
class FileLogger {
    func log(message: String) {
        print("Log to file: \(message)")
    }
}

class UserManager {
    private let logger = FileLogger() // 직접적인 의존성
    
    func createUser(name: String) {
        logger.log(message: "User \(name) created")
    }
}
```

- UserManager는 FileLogger 클래스에 직접 의존하고 있다.
- 만약 로깅 방식을 변경하고 싶다면 UserManager의 코드를 수정해야 한다.

#### 6-2-2. 의존성 역전 원칙을 적용한 코드

- 고수준 모듈은 추상화된 인터페이스에 의존하고, 저수준 모듈이 이 인터페이스를 구현한다.
- 이를 통해 고수준 모듈은 구체적인 구현에 의존하지 않고, 다양한 구현체와 쉽게 교체할 수 있다.

```swift
// 1. 추상화된 인터페이스 정의
protocol Logger {
    func log(message: String)
}

// 2. 구체적인 구현체 정의
class FileLogger: Logger {
    func log(message: String) {
        print("Log to file: \(message)")
    }
}

class ConsoleLogger: Logger {
    func log(message: String) {
        print("Log to console: \(message)")
    }
}

// 3. UserManager 클래스는 Logger 프로토콜에 의존
class UserManager {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func createUser(name: String) {
        logger.log(message: "User \(name) created")
    }
}

// 사용 예시
let fileLogger = FileLogger()
let userManager = UserManager(logger: fileLogger)
userManager.createUser(name: "Alice")

let consoleLogger = ConsoleLogger()
let userManager2 = UserManager(logger: consoleLogger)
userManager2.createUser(name: "Bob")
```

### 6-3. DIP 적용의 장점

- **결합도 감소**: 고수준 모듈은 구체적인 클래스 대신 인터페이스에 의존하기 때문에, 클래스 간의 결합도가 낮아진다.
- **확장성 증가**: 새로운 기능이 추가될 때 고수준 모듈을 수정할 필요 없이, 새로운 구현체만 추가하면 된다.
- **테스트 용이성**: Mock 객체를 사용하여 테스트 환경을 쉽게 구성할 수 있다.

```swift
class MockLogger: Logger {
    func log(message: String) {
        print("Mock log: \(message)")
    }
}

// 테스트 예시
let mockLogger = MockLogger()
let testUserManager = UserManager(logger: mockLogger)
testUserManager.createUser(name: "Test User") // "Mock log: User Test User created"
```

### 6-4. 의존성 주입과 의존성 역전 원칙의 관계

- **의존성 주입(Dependency Injection)**은 DIP를 실현하기 위한 **구체적인 방법** 중 하나이다.
- 의존성 주입은 DIP를 실현하는 구체적인 기술 중 하나이며, 이를 통해 고수준 모듈이 추상화된 인터페이스에 의존하도록 만들어준다
- DIP를 적용하면 **유연하고 확장성 있는 설계**가 가능해지고, 이를 구현하기 위해 의존성 주입이 자주 사용된다.

### 6-5. 의존성 역전 원칙과 SOLID 원칙의 관계

의존성 역전 원칙(DIP)은 SOLID 원칙의 다섯 번째 원칙이며, 나머지 네 가지 원칙과 밀접한 관계가 있다:

1. **단일 책임 원칙 (SRP)**:
   - DIP를 적용하면 고수준 모듈과 저수준 모듈 간의 의존성을 줄이기 위해 인터페이스를 사용하게 된다. 이는 각 모듈이 독립적으로 책임을 가지도록 하여 SRP를 실현하게 한다.

2. **개방-폐쇄 원칙 (OCP)**:
   - DIP는 고수준 모듈이 구체적인 구현이 아닌 인터페이스에 의존하게 한다. 이를 통해 새로운 기능이 추가될 때, 기존의 고수준 모듈을 수정하지 않고도 새로운 저수준 모듈을 추가할 수 있게 되어 OCP가 실현된다.

3. **리스코프 치환 원칙 (LSP)**:
   - DIP를 적용하면 인터페이스를 구현하는 모든 저수준 모듈은 LSP를 따르게 된다. 즉, 인터페이스를 구현하는 클래스는 어디서든 대체 가능해야 하며, 이는 LSP의 핵심 개념이다.

4. **인터페이스 분리 원칙 (ISP)**:
   - DIP는 인터페이스 사용을 권장하기 때문에, 고수준 모듈은 자신이 필요로 하는 기능만을 가진 인터페이스에 의존하게 된다. 이는 ISP의 핵심 개념과 부합한다.

5. **의존성 역전 원칙 (DIP)**:
   - DIP는 SOLID 원칙의 마지막이지만, 나머지 네 가지 원칙을 실현하기 위한 중요한 기반이 된다. 이를 통해 모듈 간 결합도가 낮아지고, 유연하고 확장 가능한 설계를 만들 수 있다.

### 6-6. 의존성 역전 원칙(DIP)과 의존성 주입(DI)의 관계

**의존성 역전 원칙(DIP)**과 **의존성 주입(DI)**은 밀접하게 연관되어 있으며, 함께 사용하면 설계의 품질과 코드의 유연성을 크게 향상시킬 수 있다.

#### 6-6-1. DIP는 **설계 원칙**, DI는 **구현 기술**이다
- **DIP**는 고수준 모듈이 저수준 모듈의 구체적인 구현에 의존하지 않고, 추상화된 인터페이스에 의존하도록 권장하는 **설계 원칙**이다.
- **DI**는 객체의 의존성을 외부에서 주입받는 **구현 기술**로, DIP를 실현하는 데 주로 사용된다.

#### 6-6-2. DIP와 DI의 관계
- DIP는 모듈 간의 **결합도를 줄이고** 유연한 설계를 가능하게 한다.
- DI는 DIP의 요구 사항을 **구현하는 방법**으로, 객체 간의 의존성을 외부에서 주입받아 결합도를 낮춘다.
- DIP를 적용하면 코드의 재사용성과 테스트 용이성이 향상되고, DI를 통해 다양한 객체 간의 **의존성 교체**가 가능해진다.

#### 6-6-3. DIP와 DI의 협력 예시
- DIP는 "구체적인 클래스 대신 인터페이스에 의존하라"는 원칙을 따른다.
- DI는 이를 구현하기 위해 **생성자 주입**, **속성 주입**, **메서드 주입** 등의 방법을 사용한다.
- DIP와 DI를 함께 사용하면, Mock 객체나 Stub 객체를 쉽게 주입할 수 있어 **테스트 가능성**이 높아진다.

##### 6-6-3-1. 의존성 주입(DI)을 사용하지 않은 경우 (DIP 위반)

```swift
class FileLogger {
    func log(message: String) {
        print("Log to file: \(message)")
    }
}

class UserManager {
    private let logger = FileLogger() // 직접 인스턴스를 생성 (DIP 위반)

    func createUser(name: String) {
        logger.log(message: "User \(name) created")
    }
}
```

- 문제점: UserManager는 FileLogger의 구현에 직접 의존하고 있다.
- 로깅 방식을 변경할 경우, UserManager의 코드도 수정해야 한다.

##### 6-6-3-1. 의존성 주입(DI)을 사용한 경우 (DIP 적용)

```swift
protocol Logger {
    func log(message: String)
}

class FileLogger: Logger {
    func log(message: String) {
        print("Log to file: \(message)")
    }
}

class ConsoleLogger: Logger {
    func log(message: String) {
        print("Log to console: \(message)")
    }
}

class UserManager {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger // 생성자 주입 (DI 사용)
    }

    func createUser(name: String) {
        logger.log(message: "User \(name) created")
    }
}
```

- DIP 적용: UserManager는 Logger 인터페이스에 의존하며, 구체적인 구현(FileLogger, ConsoleLogger)에 의존하지 않음.
- DI 사용: Logger 인터페이스의 구현체는 외부에서 주입받아 UserManager의 의존성을 설정함.

#### 6-6-4. 결론: DIP와 DI의 시너지 효과
- DIP는 설계의 방향성을 제시하고, DI는 이를 구현하는 실질적인 기술이다.
- DIP를 적용한 설계는 DI를 통해 더 유연하고 확장성 있는 구조를 가지게 되며, 변경에 강하고 유지보수가 용이한 코드를 만들 수 있다.

### 6-7. 결론

의존성 역전 원칙(DIP)은 SOLID 원칙 중에서도 특히 중요한 원칙 중 하나이다. 이 원칙을 지키면 코드의 결합도를 낮추고, 유지보수와 테스트가 용이한 설계를 할 수 있다. DIP를 실현하기 위해 의존성 주입, 프로토콜(인터페이스) 사용, 제네릭 등의 기술을 활용할 수 있다.

> "상세 구현보다는 추상화된 인터페이스에 의존하라"는 DIP의 철학은, 복잡하고 변화가 많은 소프트웨어 개발 환경에서 더욱 빛을 발한다.

## 출처 및 참고

[이미지1](https://lucasvandongen.dev/dependency_injection_swift_swiftui.php){:target="_blank"} : https://lucasvandongen.dev/dependency_injection_swift_swiftui.php

[이미지2](https://medium.com/@vipandey54/solid-principles-in-swift-75e0e7895443) : https://medium.com/@vipandey54/solid-principles-in-swift-75e0e7895443

[이미지3](https://blog.devgenius.io/class-versus-struct-in-swift-b0ce62bee676) : https://blog.devgenius.io/class-versus-struct-in-swift-b0ce62bee676

[Medium](https://medium.com/sahibinden-technology/dependency-injection-in-swift-11756a07a064){:target="_blank"} : https://medium.com/sahibinden-technology/dependency-injection-in-swift-11756a07a064

[Youtube1](https://www.youtube.com/watch?v=ooUyCbO4hNw){:target="_blank"} : https://www.youtube.com/watch?v=ooUyCbO4hNw

[Youtube2](https://www.youtube.com/watch?v=l0QehVWz2i0){:target="_blank"} : https://www.youtube.com/watch?v=l0QehVWz2i0

[cleanSwift](https://clean-swift.com/dependency-inversion-a-little-swifty-architecture/){:target="_blank"} : https://clean-swift.com/dependency-inversion-a-little-swifty-architecture/


