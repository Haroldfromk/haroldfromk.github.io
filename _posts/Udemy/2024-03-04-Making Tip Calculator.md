---
title: Tip Calculator 만들기
writer: Harold
date: 2024-03-04
categories: [Udemy, BMI Calculator]
tags: []

toc: true
toc_sticky: true
---

![](https://i.esdrop.com/d/f/E8Nib9NqGY/e0EkWXfhHW.gif){: width="50%" height="50%"} 

위와 같이 팁을 계산하는 Tip Calculator 를 만들어 보도록 하자.

디자인 부분은 생략하기 위해, 클론을 하였다.

## 1. IBOutlets, IBAction 링크하기

![](https://i.esdrop.com/d/f/E8Nib9NqGY/fihTObU5im.png){: width="50%" height="50%"} 


![](https://i.esdrop.com/d/f/E8Nib9NqGY/2d1xy0PDVD.png){: width="50%" height="50%"} 


이렇게 주어졌기에, 위와 같이 작성을 하자.

```swift
import UIKit

class ViewController: UIViewController {

   
    @IBOutlet weak var billTextField: UITextField!
    
    @IBOutlet weak var zeroPctButton: UIButton!
    
    
    @IBOutlet weak var tenPctButton: UIButton!
    
    @IBOutlet weak var twentyPctButton: UIButton!
    
    @IBOutlet weak var splitNumberLabel: UILabel!
    
    
    @IBAction func tipChanged(_ sender: UIButton) {
    }
    
    
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
    }
    
    @IBAction func calculatePressed(_ sender: UIButton) {
        print(sender.titleLabel)
    }
    
}

```

이렇게 링크가 끝났다.

그리고 뷰컨트롤러 명칭도 변경을 해주었다.

**ViewController → CalculatorViewController**

## 2. 새로운 뷰컨트롤러 생성 및 링크 해주기.

뷰컨트롤러를 만들때는 코코아터치 클래스로 만드는걸 잊지말자.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/Kxopum1VNo.png){: width="50%" height="50%"} 

이렇게 이어주었다.

그리고 여기도 역시 IBaction, IBoutlet을 링크 해주었다.

```swift
import UIKit

class ResultsViewController: UIViewController {

    @IBOutlet weak var totalLabel: UILabel!
    
    
    @IBOutlet weak var settingsLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func recalculatePressed(_ sender: UIButton) {
    }
    

}

```

## 3, 퍼센트 버튼 기능 구현하기.

우선 퍼센트 버튼을 누르고 Calculate버튼을 눌렀을때,

각각의 퍼센트가 나오게 기능을 구현해보자.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/RfID8p4s54.gif){: width="50%" height="50%"} 

버튼이 선택되는건 **isSelected**로 구현한다.

isSelected = true 일때 선택 false일땐 비활성화.

버튼쪽은 일단 이렇게 구현했다.

```swift
@IBAction func tipChanged(_ sender: UIButton) {
        zeroPctButton.isSelected = false
        tenPctButton.isSelected = false
        twentyPctButton.isSelected = false
        sender.isSelected = true
    } 
```

처음에 전부 선택이 안된상태로 두고 내가 누른것만 선택되게 한다.

그리고 if문을 추가하였다.

```swift
 if sender.currentTitle! == "0%" {
            percent = 0.0
        } else if sender.currentTitle! == "10%" {
            percent = 0.1
        } else {
            percent = 0.2
        }
```

현재 내가 누른 타이틀이 0% 일경우 percent에 0.0을 리턴하는 식으로 하였다.

물론 퍼센트에 대한 변수는 선언해두었다.

그리고나서 

```swift
@IBAction func calculatePressed(_ sender: UIButton) {
        print(percent)
    }
```

percent가 프린트 되게 하였고, 잘된다.

## 4. 증감 버튼 기능 구현하기.

```swift
@IBAction func stepperValueChanged(_ sender: UIStepper) {
        splitNumberLabel.text = String(Int(sender.value))
        person = Int(sender.value)
    }
```

Docs를 찾아보니 value에 access를 할때는 value를 그대로 쓴다고하여 sender.value를 해보았고,

그값이 제대로 리턴이 되는지 확인하기위해 calculate 버튼에 print를 해보았다.

잘넘어갔다.


## 5. 숫자 입력 구현하기

`billTextField.endEditing(true)` 단순히 TextField만 true로 해주면 입력이된다.

입력 값을 넘겨 받아야하기에 변수를 만들었고 다음과 같이 적었다.

`value = billTextField.text ?? "123.56"` nil일때를 대비해 e.g. 123.56을 그대로 리턴하게 하였다.

## 6. 계산 기능 구현하기

이제 계산했을때 제대로 된 값이 계산이 되게끔 구현한다.

```swift
@IBAction func tipChanged(_ sender: UIButton) {
        
        billTextField.endEditing(true)
        
        value = billTextField.text ?? "123.56"
        
        
        zeroPctButton.isSelected = false
        tenPctButton.isSelected = false
        twentyPctButton.isSelected = false
        sender.isSelected = true
        if sender.currentTitle! == "0%" {
            percent = 1.0
        } else if sender.currentTitle! == "10%" {
            percent = 1.1
        } else {
            percent = 1.2
        }
    }


@IBAction func calculatePressed(_ sender: UIButton) {
        let total = Float(value)
        split = (total ?? 123.56) / Float(person) * percent
        print(split)
    }
```

퍼센티지를 수정했다. 그전에는 Discount의 값이었다면, 실제로는 그만큼 더 받아야 하는 의미이므로 1.0을 다 더해주었다.

## 7. 계산값을 다른 컨트롤러로 넘기기.

### 1. Segue 만들어주기.

스토리 보드에서 세그를 연결해주었다.

그리고 Identifier에 goToResult로 명명했다.

그리고 performSegue 메서드를 통해 명명한 세그로 화면 전달이 되게끔 했다.

recalculate를 눌렀을때 다시 원래 화면이 되도록 아래와 같이 적었다.

```swift
 @IBAction func recalculatePressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
```

### 2. 값 전달하기.

```swift
    @IBAction func calculatePressed(_ sender: UIButton) {
        let total = Float(value)
        split = (total ?? 123.56) / Float(person) * percent
        self.performSegue(withIdentifier: "goToResult", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToResult" {
            destinationVC = segue.destination as! ResultsViewController
            destinationVC.result = split
        }
    }
```

다음과 같이 적었다.

## 8. 코드 수정 및 보완

일단 기능 구현자체는 끝났는데, nil값에 대한 처리가 많이 미흡하다.

해당부분을 좀 고쳐야겠다.

우선 변수선언부터 맘에 들지 않는다.

```swift
// CalculatorViewController
    var percent : Float = 0.0
    var person : Int = 0
    var value : String = "0.0"
    var split : Float = 0.0
```

습관이 되어버려서 모두 초기값을 부여했다.

이걸 모두 ? 로 바꾸어 옵셔널로 한다.

그리고 해당 변수와 관련있는 코드 역시 바꿔주었다

```swift
 @IBAction func calculatePressed(_ sender: UIButton) {
        let total = Float(value ?? "123.56")
        split = String(format:"%.2f", (total ?? 123.56) / Float(person ?? 2) * (percent ?? 1.1))
        self.performSegue(withIdentifier: "goToResult", sender: self)
    }
    
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToResult" {
            destinationVC = segue.destination as! ResultsViewController
            destinationVC.result = split
        }
    }
```

잘 된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/aCkrXhEiGc.gif){: width="50%" height="50%"}

혼자 리마인드 해본결과. 세그쪽을 좀 더 리마인드하면 좋을것같다.