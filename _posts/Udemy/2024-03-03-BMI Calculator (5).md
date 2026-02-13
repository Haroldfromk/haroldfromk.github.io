---
title: BMI Calculator (5)
writer: Harold
date: 2024-03-03
categories: [Udemy, BMI Calculator]
tags: []


toc: true
toc_sticky: true
---

## NIL값 처리하기

전에 했던것에 이어서, if문을 사용해 bmi값이 nil일 경우를 대비하자.

첫번째 방법

```swift
func getBMIValue() -> String {
        if bmi != nil {
            let bmiTo1DecimalPlace = String(format: "%.1f", bmi!)
            return bmiTo1DecimalPlace
        } else {
            return "0.0"
        }
    }
```

두번째 방법
```swift
func getBMIValue() -> String {
        if let safeBMI = bmi {
            let bmiTo1DecimalPlace = String(format: "%.1f", safeBMI)
            return bmiTo1DecimalPlace
        } else {
            return "0.0"
        }
    }
```

세번째 방법
```swift
func getBMIValue() -> String {
       
        let bmiTo1DecimalPlace = String(format: "%.1f", bmi ?? 0.0)
            return bmiTo1DecimalPlace
        
    }
```

---

이렇게 nil값에 대해 어떻게 처리할지 코드를 작성 했다면,

bmi수치에따른 권고 사항을 만들 새로운 파일을 만들자

## 새로운 모델파일 생성

BMI라는 swift file을 만들고

다음과 같이 필요한걸 적어주었다.
```swift
import UIKit

struct BMI {
    let value : Float
    let advice : String
    let color : UIColor
}
```

## CalculatorBrain 모델 수정

이젠 BMI라는 구조체를 만들었으니, 그에 맞게 모델파일을 수정해보자.

```swift
import Foundation


struct CalculatorBrain {
    
    var bmi : BMI?
    
    
    func getBMIValue() -> String {
        
        let bmiTo1DecimalPlace = String(format: "%.1f", bmi?.value ?? 0.0)
        return bmiTo1DecimalPlace
        
    }
    
    mutating func calculateBMI(height : Float, weight : Float){
        bmi?.value = weight / (height * height)
    }
       
}
```

그런데 다음과 같이 에러가 발생하였다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/0CIO4tJBW9.png)

구조체에는 let으로 되어있기 때문에, 값이 계속 변하는 특성상 맞지않는것이다.

그래서 `let bmiValue = weight / (height * height)` 로 기존을 유지 하되, 아래에 다음과 같이 적어 초기화를 해줄것이다.


```swift
bmi = BMI(value: <#T##Float#>, advice: <#T##String#>, color: <#T##UIColor#>)
``` 

그전에, 

![](https://i.esdrop.com/d/f/E8Nib9NqGY/vKcKCzXnuZ.png)

다음 조건을 참고 하여 bmivalue를 분류해보자.

```swift
mutating func calculateBMI(height : Float, weight : Float){
        let bmiValue = weight / (height * height)
        
        if bmiValue < 18.5 {
            print("underweight")
            
        } else if bmiValue < 24.9 {
        //else if bmiValue >= 18.5 && bmiValue <= 24.9 { // 굳이 이렇게 적을 필요가 없다.
            print("normal")
        } else {
            print("overweight")
        }
        
        //bmi = BMI(value: <#T##Float#>, advice: <#T##String#>, color: <#T##UIColor#>)
    }
```
![](https://www.ngpg.org/wp-content/uploads/2022/07/bmi-chart.jpg)

이젠 위의 사진 표를 보고 색상도 추가를 해보자!
`bmi = BMI(value: bmiValue, advice: "Eat more pies", color: UIColor.blue)` 보통 이렇게 UIColor.blue 로 색을 정할텐데,

Color Literal을 통해 색상을 고를 수도 있다.

`#colorLiteral()` 을 사용하면 되는데 난 왜 수치로 보이는지 모르겠다.

밖에서 쓰니 된다. 왜이러는지 잘 모르겠다.

그래서 그냥 외부에 원하는 색을 선택하고 cut & paste로 했다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/8Hr4VRygHr.gif)

---

아래와 같이 두 코드가 적용이 되도록 코드를 추가해보자.

```swift
// calculateViewController
 destinationVC.advice = calculatorBrain.getAdvice()
 destinationVC.color = calculatorBrain.getColor()
```

---

내 코드

```swift
// CalculatorBrain
func getAdvice() -> String {
        let advice = bmi?.advice ?? ""
        return advice
    }
    
func getColor() -> UIColor {
        let color = bmi?.color ?? UIColor.red
        return color
    }
```

우선 다음과 같이 값을 얻어오게 하는 함수를 구현하였다.

그다음 destinationVC로 값을 전달하는데 그게 어떤 형태로 갈것인가를 생각을 해보았고,

```swift
//ResultViewController
var advice : String?
var color : UIColor?
```
이렇게 넘겨 받아서 전달할 변수를 만들어 주었다.

```swift
override func viewDidLoad() {
        super.viewDidLoad()
        adviceLabel.text = advice
        bmiLabel.text = bmiValue
    }
```

그리고 배경색을 해야하는데 생각해봐도 color를 받아서 처리할 변수가 없었다.

그래서 storyboard를 보았다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/iqA9NAw4iy.png) 아니나 다를까 Background인 ImageView가 있어서

`@IBOutlet weak var background: UIImageView!` 다음과 같이 링크 해주었고.

`background.backgroundColor = color`를 추가해주었다.

잘된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/xPYA53rCWS.gif){: width="50%" height="50%"}

강의에서의 차이점이라면 딱하나
나는 background imageview를 만들었는데

강의에서는 만들지 않고 view로 해결하였다.

```swift
// ResultViewController

override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = color
        adviceLabel.text = advice
        bmiLabel.text = bmiValue
    }
```

또 이렇게 하나 배워간다.