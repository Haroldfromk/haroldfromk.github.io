---
title: 1주차 과제
writer: Harold
date: 2024-03-05 04:11:00 +0800
last_modified_at: 2024-03-07 03:11:00 +0800
categories: [캠프, 1주차]
tags: [계산기, 과제]

toc: true
toc_sticky: true
---
1주차 과제가 주어졌다.

과제는 다음과 같다.

## 1. Lv1
![](https://i.esdrop.com/d/f/E8Nib9NqGY/ORDasUAc8R.png)

물론 Lv1 ~ Lv4까지 있지만.

Step by Step으로 하나씩 해보려고 한다.

```swift
class Calculator {
    
    func addOperation (_ x: Int, _ y: Int) -> Int {
        print(x+y)
        return x+y
    }
    
    func substractOperation (_ x: Int, _ y: Int) -> Int {
        print(x-y)
        return x-y
    }
    
    func multiOperation (_ x: Int, _ y: Int) -> Int {
        print(x*y)
        return x*y
    }
    
    func divideOperation (_ x: Int, _ y: Int) -> Int {
        print(x-y)
        return x/y
    }
    
}
```

일단은 이런식으로 class안에 function을 사용하여 구현하였다.

일단은 두수가 Int일때만을 고려하여 계산하였다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/7Hgn6DGZEh.png)

## 2. Lv2

![](https://i.esdrop.com/d/f/E8Nib9NqGY/hq1WCxj2HJ.png)

나머지를 구하게하는 기능을 추가 해보자.


```swift
func modOperation (_ x: Int, _ y: Int) -> Int {
        print(x%y)
        return x%y
    }
```

```swift
class Calculator {
    
    func addOperation (_ x: Int, _ y: Int) -> Int {
        print(x+y)
        return x+y
    }
    
    func substractOperation (_ x: Int, _ y: Int) -> Int {
        print(x-y)
        return x-y
    }
    
    func multiOperation (_ x: Int, _ y: Int) -> Int {
        print(x*y)
        return x*y
    }
    
    func divideOperation (_ x: Int, _ y: Int) -> Int {
        print(x-y)
        return x/y
    }
    
    func modOperation (_ x: Int, _ y: Int) -> Int {
        print(x%y)
        return x%y
    }
    
}

```

위의 코드를 추가하였고 결과는 다음과 같다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/CnHth9USVu.png)

## 3. Lv3

![](https://i.esdrop.com/d/f/E8Nib9NqGY/T9UcVQOqO1.png)

지금은 각각의 기능이 Class안에 함수로 구현이 되어있는데 이걸이제는 각각의 클래스로 나누어 표현을 해야한다.

```swift
class Calculator {
   
}

class AddOperation  {
   
}

class SubstractOperation {
    
}

class MutiplyOperation {

}

class DivideOperation  {

}

class ModOperation {

}
```
우선 각 클래스들을 만들어 주었다.

여기서 부터 뭔가 고민이 많아졌다

calculator 클래스를 초기화 하면서 내가 원하는 숫자를 미리 calculator(no1 : Int, no2 : Int) 이런식으로 할 건지

calculator.~ 이런식으로 나아가서 해결할지. 생각이 많아졌다.

일단은 이렇게 구현했다

보완
```swift
// MARK: - 계산기 본체
class Calculator {
    
    let add = AddOperation()
    let substract = SubstractOperation()
    let multiply = MutiplyOperation()
    let divide = DivideOperation()
    let mod = ModOperation()
}

// MARK: - 덧셈
class AddOperation  {
    func operation (first : Int, second : Int) {
        print(first + second)
    }
}

// MARK: - 뺄셈
class SubstractOperation {
    func operation (first : Int, second : Int) {
        print(first - second)
    }
}

// MARK: - 곱셈
class MutiplyOperation {
    func operation (first : Int, second : Int) {
        print(first * second)
    }
}

// MARK: - 나눗셈
class DivideOperation  {
    func operation (first : Int, second : Int) {
        print(first / second)
    }
}

// MARK: - 나머지
class ModOperation {
    func operation (first : Int, second : Int) {
        print(first % second)
    }
}

// MARK: - Test
let calculator = Calculator()
```

```swift
// MARK: - 계산기 본체
class Calculator {
    
    let add = AddOperation()
    let substract = SubstractOperation()
    let multiply = MutiplyOperation()
    let divide = DivideOperation()
    let mod = ModOperation()
}

// MARK: - 덧셈
class AddOperation  {
    func operation (first : Int, second : Int) {
        print(first + second)
    }
    func operation (first : Int, second : Double) {
        print(Double(first) + second)
    }
    func operation (first : Double, second : Int) {
        print(first + Double(second))
    }
    func operation (first : Double, second : Double) {
        print(first + second)
    }
}

// MARK: - 뺄셈
class SubstractOperation {
    func operation (first : Int, second : Int) {
        print(first - second)
    }
    func operation (first : Int, second : Double) {
        print(Double(first) - second)
    }
    func operation (first : Double, second : Int) {
        print(first - Double(second))
    }
    func operation (first : Double, second : Double) {
        print(first - second)
    }
}

// MARK: - 곱셈
class MutiplyOperation {
    func operation (first : Int, second : Int) {
        print(first * second)
    }
    func operation (first : Int, second : Double) {
        print(Double(first) * second)
    }
    func operation (first : Double, second : Int) {
        print(first * Double(second))
    }
    func operation (first : Double, second : Double) {
        print(first * second)
    }
}

// MARK: - 나눗셈
class DivideOperation  {
    func operation (first : Int, second : Int) {
        print(first / second)
    }
    func operation (first : Int, second : Double) {
        print(Double(first) / second)
    }
    func operation (first : Double, second : Int) {
        print(first / Double(second))
    }
    func operation (first : Double, second : Double) {
        print(first / second)
    }
}

// MARK: - 나머지
class ModOperation {
    func operation (first : Int, second : Int) {
        print(first % second)
    }
    func operation (first : Int, second : Double) {
        print(second.truncatingRemainder(dividingBy: Double(first)))
    }
    func operation (first : Double, second : Int) {
        print(first.truncatingRemainder(dividingBy: Double(second)))
    }
    func operation (first : Double, second : Double) {
        print(first.truncatingRemainder(dividingBy: second))
    }
}
```