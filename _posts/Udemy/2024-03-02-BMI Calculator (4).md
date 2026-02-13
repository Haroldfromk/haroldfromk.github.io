---
title: BMI Calculator (4)
writer: Harold
date: 2024-03-02 
categories: [Udemy, BMI Calculator]
tags: [Segue]

toc: true
toc_sticky: true
---

## Model 만들기

먼저 파일을 만들어 준다.

CalculatorBrains으로 만들어 주었다.

일단은 struct만 만들어 주었다.

```swift
struct CalculatorBrain {

}
```

## ViewController에 초기화 및 내용 수정

이전에 Viewcontroller에 실제로 사용하던 변수들을 이제 structure에 넣으면서 하나씩 바꿀 예정이다.

```swift
// CalculatorViewController
var calculatorBrain = CalculatorBrain()
```
이렇게 초기화를 해주고,

```swift
// CalculatorViewController, calculatePressed
calculatorBrain.calculateBMI(height: height, weight: weight)

// prepare
destinationVC.bmiValue = calculatorBrain.getBMIValue()
```

이렇게 해주었다.

structure에 어떤 값이 들어갈지 내부값을 하나씩 변경해주면서 디자인을 해보자

## Model 내용 추가

현재 `calculateBMI`, `getBMIValue`라는 함수를 추가해주고 기존 값을 지웠다. 즉 우리는 저 함수를 structure에 추가 해주면 되겠다.


일단 다음과 같이 작성을 하였다.

```swift
struct CalculatorBrain {   
    var calculatedBMIValue : String = ""
    
    mutating func calculateBMI(height : Float, weight : Float) -> String{
        calculatedBMIValue = String(format: "%.1f", (weight / (height * height)))
        
        return calculatedBMIValue
    }
    
    func getBMIValue() -> String {
        
    return calculatedBMIValue}
}
```

CalculateViewController에 다음과 같은 창이 경고가 뜬다, 저번에 Quizzler때도 그랬다. 

![](https://i.esdrop.com/d/f/E8Nib9NqGY/wtHbR2MYJB.png)

리턴을 하지말고 계산만 하게 해볼까? 라는 생각이 들어

```swift
mutating func calculateBMI(height : Float, weight : Float){
        calculatedBMIValue = String(format: "%.1f", (weight / (height * height)))
        
    }
```

리턴을 하지않고 계산만 하게 해보았다.

잘된다.

그래서 내가 쓴 코드는 다음과 같다.

```swift
import Foundation

struct CalculatorBrain {
    
    var calculatedBMIValue : String = ""
    
    mutating func calculateBMI(height : Float, weight : Float){
        calculatedBMIValue = String(format: "%.1f", (weight / (height * height)))
        
    }
    
    func getBMIValue() -> String {
        
        return calculatedBMIValue
    }
}
```

그냥 calculateBMIValue는 계산만하게 해도 되는건데 굳이 리턴을 하려고 하니 warning 이떴던 것이었다.

어차피 structure에서 value를 getBMIValue로 받으니 리턴이 필요없다.

---
강의에선 다음과 같이 하였다.

```swift
struct CalculatorBrain {
    
    var bmi : Float = 0.0
    
    mutating func calculateBMI(height : Float, weight : Float){
        bmi = weight / (height * height)
    }
    
    func getBMIValue() -> String {
        let bmiTo1DecimalPlace = String(format: "%.1f", bmi)
        return bmiTo1DecimalPlace
    }
}
```

## structure 에서 initialization을 하지않은 이유.

struct CalculatorBrain에서 

```swift
bmi : Float = 0.0 //강의
calculateBMIValue : String = "" //나

```
이런식으로 먼저 값을 적고 했다.

그 이유는 우리가 그냥

```swift
bmi : Float 
calculateBMIValue : String  //나
```

이런식으로 표현을 하게 될경우

calculate 뷰 컨트롤러에서는 

```swift
var calculatorBrain = CalculatorBrain( )
```

여기 괄호안에 우리가 매개변수를 넣어줘야한다.

하지만 굳이 우리가 여기 컨트롤러에서 값을 초기화 해줄 필요가 전혀 없다.

구조체에서 이미 값을 계산을 하고, 가져 올 수 있기 때문이다.

그렇다면.


```swift
bmi : Float = nil
calculateBMIValue : String = nil
```

이렇게 nil일 경우를 생각해서


```swift
bmi : Float?
calculateBMIValue : String?

```

옵셔널을 한다면??

```swift
func getBMIValue() -> String {
        let bmiTo1DecimalPlace = String(format: "%.1f", bmi!)
    
    }
```

이렇게 ! 를 여태 붙이듯이 해야할것이다.

그렇게 했을때 실행을 하면 어떻게 될까?

앱을 실행하자마자 nil값을 얻기 위해

calculate뷰 컨트롤러의 코드를 잠깐 수정한다.

```swift
override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        calculatorBrain.getBMIValue()
    }
```

바로 작동하자마자 bmivalue를 얻게 해보았다.

다음과 같이 시작하자마자 팅기면서 에러가 발생한다.

viewDidLoad()를 통해 앱이 구동되자마자 getBMIValue를 하게되는데 nil값을 가져오기 때문이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/QH3W2dwKX2.png)

다음 글에서 계속 서술하도록 하겠다.
