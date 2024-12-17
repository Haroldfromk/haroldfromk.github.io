---
title: (Deep Dive) Data Communication
writer: Harold
date: 2024-03-16 13:32
last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---


## 1. Intro

이번에 Byte Coin을 하면서 ViewController를 통해 데이터를 전송하려고 하였으나 

nil이 되면서 에러가 떴다, 하지만 아이러니한건 print를 했을때는 그 값이 출력이 되었다는 것이다.

도대체 뭐가 문제일까를 내 스스로 해답을 찾아가보기 위해 처음으로 나만의 Deep Dive를 해본다.

기존에 Deep Dive들은 강의를 통해서 정리를 한것이어서 뭔가 수동적인 느낌이었다면, 이번엔 내가 직접 자료를 찾아보고 테스트를 하면서하는

능동적인 Deep Dive이다.

앞으로 내가 직접 분석을 하면서 찾아내는 결과를 담은 Deep Dive엔 별도의 태그(Myself)를 붙여서 관리를 할 생각이다.

그럼 이제 진짜 시작해보자

## 2. 데이터 전달 방식의 종류

Swift에서 View Controller간 데이터 전달을 하는 방식에는 크게 2가지로 나뉘게 된다.

1. 직접 전달 방식(동기 방식) : 데이터를 직접 넘겨준다
    - present, push시 프로퍼티에 접근해 넘겨주는 방식
    - Segue prepare 메서드를 활용하여 데이터를 넘겨주는 방식
    - Protocol / Delegation을 활용하여 데이터를 **넘겨받는** 방식
    - Closure를 활용하여 데이터를 **넘겨받는** 방식
    - Notification Centre를 활용해 데이터를 넘기는 방식

2. 간접 전달 방식(비 동기 방식) : 데이터를 다른곳에 저장하고, 필요할때마다 꺼내는 방식
    - AppDelegate.swift 활용
    - UserDefaults 사용
    - CoreData or Realm 활용

## 3. 가장 많이 쓰이는 전달 방식은?

1. present, push시 프로퍼티에 접근해 넘겨주는 방식
2. Protocol / Delegation을 활용하여 데이터를 **넘겨받는** 방식
3. Closure를 활용하여 데이터를 **넘겨받는** 방식
4. Notification Center를 활용해 데이터를 넘기는 방식

실제로 내가 시도했던것도, 1번, 2번이었고 1번을 시도했을때 잘 안되어서 튜터님께 물어봤을때도 3번을 활용해보는게 어떠냐고 하셨다.
그리고 4번의 경우는 야구게임을 할때 Tuple로 리턴을 해야하는 경우가 생겼는데, notification을 활용해서 넘기는 방식도 있다고 하셨다.

즉 가장 많이쓰이는 전달 방식 4개는 모두 알아 두는게 좋다!

## 4. Instance Property (present, push)

### 0. 어떻게 전달이 되는가?

- 프로퍼티를 사용해서 데이터를 전달할때는 보통 present/push를 통해 데이터를 전달을 한다.
- VC Instance를 생성하고, 해당 Instance에 내가 전달할 값을 추가로 달아둔다.
- 그리고 화면을 전환하는 present를 통해 전달된 데이터를 다른 VC가 받아 처리.
- 보통 First → Second로 갈때 사용한다

### 1. 코드 작성 (내가하던 방식)

>Property를 사용하여 데이터를 전송해보자

우선 테스트용 뷰컨트롤러를 하나 더 만들어주었다.

1. FirstViewController
2. SecondViewController

이렇게 구분을 지어주었다.

그리고 textfield에 입력한값을 send버튼을 눌러 두번째 뷰 컨트롤러에 전달할 것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/6UgLU5o2yZ.png)

우선은 내가 실패했던 방법으로 해보았다.

```swift
import UIKit

class FirstViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    
    let secondVC = SecondViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func sendData(_ sender: UIButton) {
        
            secondVC.message = textField.text
            secondVC.modalPresentationStyle = .fullScreen
            self.present(secondVC,animated: true,completion: nil)
       
    }
    
}

import UIKit

class SecondViewController: UIViewController {

    @IBOutlet weak var secondLabel: UILabel!
    
    var message : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        getText()
    }
    
    func getText() {
        if let gotMessage = message {
            secondLabel.text = gotMessage
        } else {
            secondLabel.text = "sending text failed"
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true,completion: nil)
    }

}

```
역시 저번처럼 print할때는 값을 전달하나, 그걸 label에 전달하려고하니 nil이 되어버린다.

### 2. 코드 수정 (구글링)

아무리 찾아봐도 viewcontroller를 인스턴스화 해서 전달할때는 instantiateViewController 를 사용하고있다.

일단 위의 방식대로 해보았다.

```swift
@IBAction func sendData(_ sender: UIButton) {
        
        guard let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController
        else {
            return
        }
        
        secondVC.message = textField.text
        secondVC.modalPresentationStyle = .fullScreen
        self.present(secondVC,animated: true,completion: nil)
        
    }
    
```

as를 통해 DownCasting을 하지 않으니 SecondViewController의 프로퍼티에 접근을 할수가 없었다.

실행해보았다.

### 3. 문제 해결
![](https://i.esdrop.com/d/f/E8Nib9NqGY/gK0uNieAuG.png)

??? 이건 identifier의 값이 잘못되었거나 내가 뷰컨트롤러에 제대로 네이밍을 하지 않았을때 발생하는것인데

왜 이게 발생했을까?

확인을 해보았다.

아... 내가 해주질 않았다. 단순히 클래스만 연결을 해주었다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/3s9c58ES8b.png)

그래서 위에 `instantiateViewController(identifier: "SecondViewController")` 적었음에도 불구하고

`secondVC.` 했을때 아무런 값이 안나온걸끼? 다운캐스팅을 지워봤는데 역시나 에러가 난다. 일단 하던대로 하자

다시 실행해보면?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/BRHGtPJqEr.gif)

전달이 잘된다.

### 4. 복기

그럼 왜 이전 방식은 왜 안될까에대한 생각을 해봤다. 갑자기 아차 싶었다.

우리가 하고있는 이 뷰컨트롤러도 결국은 **클래스였다**....

아마 저렇게 할경우 계속 새로운 인스턴스가 만들어지기에 내가 의도한 연결과는 다르게 될것이다.

내가 아무렇지않게 클래스간 값을 전달할때 각각의 클래스가 값을 따로 가지고 있어서 벙쪘던 기억이 되살아나버렸다.

이제서야 모든것이 이해가 되기 시작한다. 왜 내가 전달을 못했는지, 왜 뷰컨트롤러를 단순히 인스턴스화 시키면 안되는지를

갑자기 머리속이 맑아진다. 뭔가 득도한 느낌이다.

클래스를 인스턴스화 시켜서하려면 결국 함수를 만들고 리턴을 하는 방식으로 해야하는데 뷰컨트롤러는 모든것을 포함하고 있는 메인의 느낌이라,

아마 그렇게 하면 복잡해질 것이다. 

### 5. 최종 코드
```swift
// FirstVC
import UIKit

class FirstViewController: UIViewController {
    
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func sendData(_ sender: UIButton) {
        
        guard let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController
        else {
            return
        }
        
        secondVC.message = textField.text
        secondVC.modalPresentationStyle = .fullScreen
        self.present(secondVC,animated: true,completion: nil)
        // present로 위로 화면을 띄워주면서 Data 전달.
    }
    
}

// SecondVC
import UIKit

class SecondViewController: UIViewController {

    
    @IBOutlet weak var secondLabel: UILabel!
    
    var message : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        getText()
    }
    
    func getText() {
        if let gotMessage = message {
            secondLabel.text = gotMessage
        } else {
            secondLabel.text = "sending text failed"
        }
    }
    
    @IBAction func back(_ sender: Any) {
        self.dismiss(animated: true,completion: nil)
    }
    
}

```

### 6. 결론

ViewController간 통신을 할때는 내가 **굳이** 인스턴스화를 하고 싶다면 **instantiateViewController**를 사용 하도록 하자.

해당 함수를 사용하기위해선 그함수를 사용하려는 뷰컨트롤러에서 `self.storyboard?.` 이렇게 해서 사용하면 된다.

그리고 이 방식을 사용할때는 화면 전환 할때 주로 사용한다. (애초에 bytecoin할때도 방식이 잘못되었다..)

### 7. instantiateViewController 사용 시 주의사항
- instantiateViewController는 지정된 identifier를 이용하여 ViewController를 만들고, 그걸 초기화한다.
    - 즉, 내가 instanciateViewController를 사용할때마다 해당 내용은 초기화가 되어있다는 것이다.
- First -> Second -> First 일때
    - second에서도 instanciateViewController를 사용하게 되면 같은 First이긴 하나 데이터는 서로 다르다.
        - 즉 First -> Second -> First인 경우에 두 First는 서로 다른녀석이다.

## 5. Protocol (Delegate)

이게 실제로 위의 방법을 했을때 나의 잘못된 생각으로 먹히지 않아서 강의에서 배웠던 내용 그대로를 적용하여 해결했던 방식이다.

> Delegate를 사용하는 이유?
>> 객체지향 프로그래밍에서 하나의 객체가 모든일을 처리하는 것이 아닌 처리해야 하는 기능 일부를 다른 객체에 위임(Delegate)한다.
>> 그래서 대리인의 의미로 Delegate로 변수를 만들어서 많이 사용한다.
>>> 위임된 기능은 프로토콜에서 정의하며, delegate가 위임된 기능을 제공한다.
>>> 위임은 특정 작업에 응답하거나 외부에서 데이터를 가져오는데 사용할 수 있다.

혹시라도 나중에 다시 프로젝트를 참고 할지도 몰라서 새프로젝트로 한다. 하지만 이름은 동일하게.

- ⭐️Delegate는 주는쪽과 받는쪽의 코드작성이 헷갈리기에 주의하자

### 0. 어떻게 전달이 되는가?

- 프로토콜을 구현을 한다.
- 그 후 Delegate Instance(Type은 프로토콜로)를 생성한다.
- 프로토콜을 생성하고 메서드를 구현한다. (Extension을 해서 코드를 깔끔하게 해도 괜찮다.)
    - 데이터를 보내는쪽에서 프로토콜을 작성한다. (찾아보니 사이트마다 설명이 다르다?)
- Delegate 위임을 한다.
    - 데이터를 받는 쪽에서 프로토콜을 채택하고, delegate에 위임을 한다.
- 동작하는 시점을 설정해두고 작동을 해서 전달을 한다.
- 보통 되돌아오는 방향일때(Second → First) 사용한다.

### 1. 코드 작성

우선 테스트용 뷰컨트롤러를 하나 더 만들어주었다.

1. FirstViewController
2. SecondViewController

이렇게 구분을 지어주었다.

그리고 textfield에 입력한값을 send버튼을 눌러 두번째 뷰 컨트롤러에 전달할 것이다.

(property와 동일한 형태로 진행한다.)

우선 내가 생각하는 방식으로 코드 작성을 해보았다.

```swift

protocol sendDataProtocol {
    func sendData (data : String)
}

import UIKit

class FirstViewController: UIViewController {
    
    var delegate : sendDataProtocol?
    
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func sendButton(_ sender: UIButton) {
        
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            if let data = textField.text {
                self.delegate?.sendData(data: data)
            }
            
            self.present(secondVC, animated: true, completion: nil)
        }
    }
    
}



import UIKit

class SecondViewController: UIViewController {

    let firstVC = FirstViewController()
    
    @IBOutlet weak var textLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        firstVC.delegate = self

    }
    
    @IBAction func backButton(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
}

extension SecondViewController : sendDataProtocol {
    func sendData(data: String) {
            self.textLabel.text = data
        print(data)
    }
}


```

실행을 해보니 데이터가 전달이 안되는걸까? label이 바뀌지가 않는다.

값이 제대로 전달이 되는지 확인을 먼저 해봐야겠다.

print도 안된다. 즉 현제 delegate를 통해 값이 전달이 안되는것 같다.

증상확인을 위해 breakpoint를 줘봤다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/b9NIWLM3x6.png)

되지않는다. 즉 이 함수가 실행이 안될 가능성이 높다.

breakpoint를 다른곳에 줘봤다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/YLrfOnyBtv.png)

뭔가 전달이 안되는걸까 싶어서 다른곳에 breakpoint를 줘보고 다시 실행해보았다.

왜 안되는지 모르겠다...

일단 방향을 바꿔서 했는데 된다.

처음에는 프로토콜을 Second에 만들었는데 안되었다.

### 2. 코드 전면 수정 (ChatGPT의 방식)

```swift

import UIKit

protocol SendDataDelegate {
    func sendData (_ vc : SecondViewController, data : String)
}

class FirstViewController: UIViewController, SendDataDelegate {

    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func sendButton(_ sender: UIButton) {
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            secondVC.delegate = self
            if let dataToSend = textField.text {
                secondVC.message = dataToSend
            }
            
            self.present(secondVC, animated: true)
        }
    }
    
    func sendData(_ vc: SecondViewController, data: String) {
        DispatchQueue.main.async {
            vc.secondLabel.text = data
            print(data)
        }
    }
    
}




import UIKit

class SecondViewController: UIViewController {
    
    @IBOutlet weak var secondLabel: UILabel!

    var delegate : SendDataDelegate?
    
    var message : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate?.sendData(self, data: message)
    }
    
    @IBAction func backButton(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
     
}

```

진짜 앵간하면 ChatGPT안쓰고 나의 노력으로 하는데 이건 너무 안되어서 물어보았다.

뭔가 ChatGPT의 방식은 이렇게 나오는데 작동이 되긴한다.

하지만 내가아는 방식과는 좀 다르다. 내가 구현하려고 한 부분이 도대체 무엇이 문제인걸까?

다시 테스트를 해봐야 겠다.


### 3. 복기

좀 더 찾아보니 Delegate는 Second View Controller를 present한 상황에서 First View Controller로 전달을 하고 싶을때
사용한다고 한다. 

그래서 위에도 적어두었다.

구글링을 해보니 설마했던 부분이었는데

![](https://i.esdrop.com/d/f/E8Nib9NqGY/LBoQ9e1GGs.png)

역시나 이번에도 이부분이 말썽이다.

그리고 사이트마다 프로토콜의 위치가 각각 다르다. 나만의 기준을 확실하게 정립을 해야겠다는 생각이 든다.

정말 Second → First이어야 하는건가 싶어 그렇게 해서 도전을 해본다.

그리고 이번엔 navigation을 사용하기 위해서

![](https://i.esdrop.com/d/f/E8Nib9NqGY/KscjYVe55A.png) 

이렇게 해주었다.

### 4. 코드 재작성 해보기 (Second → First)
```swift
import UIKit

class FirstViewController: UIViewController, SendDelegate {
    
    @IBOutlet weak var currentLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func sendData(data: String) {
        currentLabel.text = data
    }

    @IBAction func getDataButton(_ sender: UIButton) {
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            secondVC.delegate = self
            
            self.navigationController?.pushViewController(secondVC, animated: true)
        }
    }
    
}

import UIKit

protocol SendDelegate {
    func sendData(data : String)
}

class SecondViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    
    var delegate : SendDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
  
    @IBAction func dataSendButton(_ sender: UIButton) {
        if let text = textField.text {
            delegate?.sendData(data: text)
        }
        
        self.navigationController?.popViewController(animated: true)
    }
    
}

```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/2J3BkspiNj.gif)

### 5. 재 복기
이젠 내가 원하는대로 된다.

왜 이게 작동을 하는걸까? 한번 생각을 해보았다.

first에서 내가 위임할거다 라는걸 제공한 상태에서, second에서 데이터를 받아서 그걸 가져온다 라는 생각을 해보았다.

근데 내가 처음에 생각한 first to second는 그런부분이 반대로 된다.

### 6. 빌드업

4번항목에서 제대로 작동하였기에, 빌드업을 한번 적어본다.

> 보내는쪽 (SecondVC)
>>1. 프로토콜을 생성한다.
>>```swift
>>protocol SendDelegate {
>>    func sendData(data : String)
>>}
>>```
>>2. `var delegate : SendDelegate?` delegate 변수 생성
>>    - 위임을 해야하기에 변수를 만들어 준다
>>3. delegate를 통해 함수로 값을 전달한다.
>>    - `delegate?.sendData(data: text)`

> 받는쪽 (FirstVC)
>>1. 프로토콜을 채택한다.
>>2. 프로토콜의 함수를 작성해준다.
>>```swift
>>func sendData(data: String) {
>>        currentLabel.text = data
>>    }
>>```
>>3. SecondVC에서 선언해둔 delegate가 self. 즉 대신해서 처리할 부분이 FirstVC라는 것을 선언한다 (중요!)
>>    - `secondVC.delegate = self` 

### 7. 나의 결론
근본적으로 왜 Second→First 일까를 물어보러 갔다.
튜터님이 딱 한마디로 쉽게 알려주셨다.

- First에서 Second 로 전달할때, First는 이미 Second에 대해 모든걸 알고 있다. 굳이, delegate를 통해 위임해서 전달 할 필요가 없기 때문이다.

이걸 들었을때 내가 주말동안 이글을 작성하면서 고민해왔던 것들 그리고 내가 이렇게 정리한 내용들이 어떤 상황일때 써야하는지에 대해 밑그림이 그려졌다.

즉 Diagram으로 표현을 한다면

- FirstVC→SecondVC
    - 이미 우리가 secondVC를 instantiate를 통해 만들어서 이동하기에, FirstVC가 SecondVC에 대해 알고 있는 상태이다.
    
![](https://i.esdrop.com/d/f/E8Nib9NqGY/Gj3Zo8G5MH.png)

- SecondVC→FirstVC
    - SecondVC는 FirstVC에 대하여 아무런 정보가 없다.
        - 왜냐 다시 돌아갈때도 dismiss를 통해서 돌아가기 때문.
    - 그러므로 SecondVC에서 데이터를 전달하기 위해서, delegate가 대신 그 값을 받아서 FirstVC로 가는 것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/MecNcPkC4c.png)

## 6. Closure로 데이터 전달

### 0. 어떻게 전달이 되는가?
- 보통 되돌아오는 방향일때(Second → First) 사용한다.
    - protocol과 같은 맥락
- 차이점이라면 수신VC가 송신VC의 저장속석인 클로저에 접근하여 상세내용을 직접 주입한다.
- 이미 메모리에 올라와 있는 상태에서 데이터를 전달할때 사용한다.

### 1. 코드 작성
```swift
import UIKit

class FirstViewController: UIViewController {

    @IBOutlet weak var displayLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func nextBtn(_ sender: UIButton) {
        
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            secondVC.dataClosure = { data in
                self.displayLabel.text = data
            }
            self.present(secondVC, animated: true)
        }
        
    }
    
}


import UIKit

class SecondViewController: UIViewController {

    // Data전달 Closure
    var dataClosure : ((_ data:String) -> Void )?
    
    @IBOutlet weak var textField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func sendDataBtn(_ sender: UIButton) {
        if let text = textField.text {
            dataClosure?(text)
        }
        self.dismiss(animated: true)
    }
    
}
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/uL6yl3NjMp.gif)

### 2. 코드 분석
- 클로저는 일종의 데이터 전달 통로로 생각을 하면 된다고한다.
- 데이터를 보내려는 VC에 만들어준다
```swift
var dataClosure : ((_ data:String) -> Void )?
var dataClosure1 : ((String) -> ())?
```
- 클로저에 전달하려는 데이터를 담는다 (`dataClosure?(text)`)
- 수신을 하는 VC에 데이터를 받으면 어떻게 처리를 할지에 대한 내용을 적는다.
    - SecondVC로 화면전환을 하기 이전에 해당 연결통로에서 데이터가 들어오면 어떻게 처리할지를 정의한다.
	- 클로저 형태로 연결된다는 것을 선언함과 동시에, 데이터 처리 어떻게 하겠다는걸 정의한다.

## 7. Notification Center로 데이터 전달

### 0. 어떻게 전달이 되는가?

- 메모리에 올라와 있는 객체 모두에게 신호를 보낸다.
- 객체에서 같은 신호 이름을 가진 옵저버가 존재하면 데이터를 수신
- delegate, closure의 차이는 우리가 직접 대리자를 지정했지만, Notification은 옵저버가 존재하면 알아서 데이터를 전달받아 처리한다.
- NotificationCenter는 싱글톤이다.
    - 싱글톤 : 객체의 인스턴스가 오직 1개만 생성되는 패턴을 의미한다

### 1. 코드 작성

해당부분은 실제로 해본적이 없어서 인터넷을 참고하여 코드를 작성해보기로 하였다.

전개방식은 protocol과 같이 Second to First 로 한다.

1. FirstVC
    - addObserver : Notification을 관찰
        - 전달 받은 신호를 관찰하여 함수를 실행한다,
2. SecondVC
    - post : Notification 신호를 보낸다.
        - 원하는 데이터를 전달한다.

```swift
import UIKit

class FirstViewController: UIViewController {

    @IBOutlet weak var displayLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func getDataBtn(_ sender: UIButton) {
        
        if let secondVC = self.storyboard?.instantiateViewController(identifier: "SecondViewController") as? SecondViewController {
            
            self.navigationController?.pushViewController(secondVC, animated: true)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(dataReceived(_:)), name: NSNotification.Name("test"), object: nil)
        
    }
    
    @objc func dataReceived (_ notification : Notification) {
        
        if let text = notification.object as? String { // DownCasting
            displayLabel.text = text
        }
        
    }
    
}

import UIKit

class SecondViewController: UIViewController {

    
    @IBOutlet weak var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func sendDataBtn(_ sender: Any) {
        
        if let text = textField.text {
            
            NotificationCenter.default.post(name: NSNotification.Name("test"), object: text)
        }
        
        self.navigationController?.popViewController(animated: true)
    }
    

}

```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/oHN5zyKV6w.gif)

### 2. 코드 파헤쳐 보기

1. SecondVC(데이터 전송)
    - Notification을 전송할땐 `Notification.default`을 사용한다
        - 앱 전체적으로 하나의 객체에서 관리할 수 있도록 default가 정의 되어있다.
            - 대부분 default에 접근하여 메서드를 호출한다.
    - post : 객체가 NotificationCenter로 이벤트를 보내는 행위
    - name : Notificaion 에서 우리가 설정한 알람의 이름
        - 만약 여러개면 하나하나 이름을 붙여 구분해두면 된다.
    - object : 전달하고자 하는 데이터

2. FirstVC(데이터 수신)
    - addObserver : 알림을 받는 주체
    - selector : 알림을 받은 주체가 수행하는 함수. 
        - ⭐️obj-C 형태이다! 
    - name : 알람의 이름
    - object : post된 object값이 여기의 object와 동일할때만 값을 받는다.
    - dataReceived : notification이 생기면 실행하는 함수로 함수의 내용을 서술.
        - parameter로  Notification type을 해주었다.
            - Notification.object로 값을 가져온다.
            - DownCastin을 한 것은 object 타입이 Any? 이기 때문이다. 

3. 별도로 name 등록하기
```swift
extension Notification.Name {
    static let test = Notification.Name("test")
}
```
- 이렇게 extension형식으로도 가능하다.

### 3. 복기

뭔가 여러 viewcontroller를 만들었을때 VC마다 다른 값을 전달할때는 효과적일 것 같다는 생각이 든다.

그리고 서로 접접이 없는 컨트롤러끼리도 데이터를 주고 받을 수 있을 것 같다.

## 8. Segue로 데이터 전달

### 0. 어떻게 전달이 되는가?

- Segue는 Source, Destination으로 이루어져 있다.
    - Source : 출발지점, 화면전환의 시작점
    - Destination : 도착지점, 화면이 전환되는 곳
- performSegue 를 통해 Segue를 실행한다.
    - 화면이 전환된다.
    - 이때 identifier에 전환하는 Segue의 명칭을 정확히 적어준다.
- 그리고 prepare함수를 오버라이딩을 해준다. (Segue가 실행되기전 해당 함수를 통헤 데이터를 넘길 준비를 한다.)
    - destination은 내가 화면을 전환하려고 하는 VC를 설정해준다.
    - identifier를 정확하게 입력을 해야한다.


우선 Segue로 전달을 하기위해선 꼭 해야하는 작업이 있다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/anYkcRYOhn.png)

바로 이렇게 VC끼리 서로 연결해주어 Segue를 만들어 주고 꼭 identifier에 명칭을 부여해준다.

### 1. 코드 작성
```swift
import UIKit

class FirstViewController: UIViewController {

    
    @IBOutlet weak var textField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func dataSendBtn(_ sender: UIButton) {
        performSegue(withIdentifier: "goToVC", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToVC" {
            let secondVC = segue.destination as? SecondViewController
            if let text = textField.text {
                secondVC?.message = text
            }
        }
    }
    
}


import UIKit

class SecondViewController: UIViewController {

    
    @IBOutlet weak var displayLabel: UILabel!
    
    var message : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        displayLabel.text = message
    }
    
    @IBAction func backBtn(_ sender: UIButton) {
        
        self.dismiss(animated: true)
    }
    

}

```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/W8yTKAS8UE.gif)

### 2. 복기
Segue는 Udemy에서 공부하면서 초창기에 나왔던 부분이라, 그리 어려운 부분은 아니었다.

주의해야할거라면 identifier와 DownCasting정도가 될 것 같다.

destination은 UIViewController 즉 데이터 타입이 최상위로 되어있기에 DownCasting을 꼭 해줘야한다! 

## 9. 정리 후기

생각보다 정리할것도 많고 검색해야할것도 많았다.

지금은 초창기라 뭔가 두서없이 정리를 했지만 조금씩 지식이 쌓이고 이해를 제대로 하면서 내용을 지속적으로 수정하고 보강할 생각이다.

튜터님과 대화를 하고 난후, 내가 정리한 방식을 무작정 내가 쓴다고 해서 되는것이 아닌, **VC간의 관계를 파악**하고, 그에따른 적절한 방법을 사용해야겠다. 라는 생각이 들었다.

확실히 튜터님과 이런 대화를 하면 할수록 얻어가는게 많다.

## 출처
<https://hellozo0.tistory.com/365>

<https://990427.tistory.com/90>

<https://minnit-develop.tistory.com/8>

<https://medium.com/hcleedev/swift-notificationcenter%EC%99%80-%EC%82%AC%EC%9A%A9%EB%B2%95-6eb4490aac88>

<https://silver-g-0114.tistory.com/106>