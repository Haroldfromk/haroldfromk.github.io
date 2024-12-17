---
title: (Deep Dive) Closure
writer: Harold
date: 2024-03-06 10:11:00 +0800
categories: [Deep Dive]
tags: [클로저]

toc: true
toc_sticky: true
---

## 1. 클로저란?
- 클로저는 본질적으로 이름이 없는 익명 함수이다.

우리가 보통 함수를 정의 할때
```
func functionName (parameter : parameterType) -> returnType {
    //code
    
    return output
}
```

이런식으로 구현하였다.

![](https://mathinsight.org/media/image/image/function_machine.png)

이렇게 뭔가 정제되지않은 값이 들어가면 함수를 통해 정제된 값으로 나오게된다.

즉 **함수는 패키지화 된 기능의 집합체** 이다.

그리고 함수에 이름을 부여하여 이후에 해당 기능이 필요하면 언제든지 이름을 호출하여 사용 할 수 있다.

함수는 함수를 입력값으로 받아 출력을 할 수 있다.

코드를 보자
```swift
import UIKit

func calculator (n1 : Int, n2 : Int) -> Int {
    
    return n1 + n2
}

calculator(n1: 2, n2: 3) // 5
```

두값을 더하는 계산기 함수를 만들었다.

그럼 이번에 저 계산기의 입력값을 함수로 받고 싶다면 어떻게 해야할까?

우선 add라는 함수를 하나 더 만들어 주었다.

```swift
func add (no1 : Int, no2:Int) -> Int {
    
    return no1 + no2
}
```

함수를 다른 함수의 파라미터로 넣기 위해선 이함수를 데이터타입으로 간추려야 한다.

```swift
func calculator (n1 : Int, n2 : Int) -> Int {
    
    return n1 * n2
}

func add (no1 : Int, no2:Int) -> Int {
    
    return no1 + no2
}

// 곱을 구하는 함수도 추가로 생성해주었다.
func multiply (no1 : Int, no2 : Int) -> Int {
    
    return no1 * no2
}
```

현재는 두 함수 모두 Int type의 파라미터를 받고, Int type으로 리턴을 하고 있다.

즉 이걸 데이터 타입으로 표현을 해보면

`(Int, Int) -> Int` 인걸 알 수 있다.

이걸 calculator 함수에 넣어보자.

그리고 매개변수명을 operation으로 해주었다.

return또한 그에 맞게 고쳐준다.

```swift
func calculator (n1 : Int, n2 : Int, operation : (Int, Int) -> Int) -> Int {
    //                                            ---  ---
    //                                             n1   n2
    return operation(Int, Int)
}
```

그다음 위에있는 return도 바꿔주자!

`return operation(n1, n2)`

이렇게 되면, n1과 n2가 operation을 통과하게 된다.

그럼 함수를 다시 호출 해보자
```swift
calculator(n1: 2, n2: 3, operation: add) // 5
calculator(n1: 2, n2: 3, operation: multiply) // 6
```

우선 n1, n2값이 calculator 함수로 가게 된다. 그리고 add 함수를 호출하게되고 그 n1, n2값이 add 함수로 전달이 된다.

뭔가 이렇게 쓰니 코드가 장황 해진다. 이때 클로저를 사용하여 간략하게 표시 할 수 있다.

## 2. 클로저 함수로 전환하는 방법

다음과 같은 함수가 있다.

```swift
    func sum (firstNumber : Int, secondNumber : Int) -> Int {
//            -------------------------------------     ---
//                           Input                     output


        return firstNumber + secondNumber
    }
```

우선 func와 함수의 이름을 지운다.

```swift
(firstNumber : Int, secondNumber : Int) -> Int {

    return firstNumber + secondNumber
}
```

그리고 Arrow function 뒤에있는 대괄호(`{`) 이걸 앞으로 옮겨준다 그리고 옮겼던 자리에 in을 적어준다

```swift
{   (firstNumber : Int, secondNumber : Int) -> Int in
//                                                 --
    return firstNumber + secondNumber
}
```

이걸 바탕으로 multiply 함수를 클로저 형식으로 바꿔보자.
```swift
import UIKit

func calculator (n1 : Int, n2 : Int, operation : (Int, Int) -> Int) -> Int {
    return operation(n1, n2)
}

func add (no1 : Int, no2:Int) -> Int {
    return no1 + no2
}

func multiply(no1: Int, no2: Int) -> Int {
    return no1 * no2
}


calculator(n1: 2, n2: 3, operation: multiply)
```

지우면 이렇게 된다.

```swift
{ (no1: Int, no2: Int) -> Int in
    return no1 * no2
}


calculator(n1: 2, n2: 3, operation: )
```

이렇게 지운걸 operation 저기에 옮겨주면서 더 줄일 수 있다!

no1, no2의 데이터 타입을 지워준다. 
- 지워줘도 swift는 리턴 타입을 통해 input의 데이터타입을 추론 할 수있다.

```swift
calculator(n1: 2, n2: 3, operation:{ (no1, no2) -> Int in
    return no1 * no2
} )
```

그 다음엔 Arrow function과 return type과 return 키워드도 지워주자!

이것 역시도 스위프트가 추론을 할 수 있기에 가능한 것이다.

```swift
calculator(n1: 2, n2: 3, operation:{ (no1, no2) in no1 * no2 }) 
```

이렇게 바뀌었다.

그리고 매개변수명 역시 바꿀 수 있다.
- 익명 매개 변수명으로 바꾸자.
    - $0은 첫번째 매개변수를 의미한다.
    - $1은 두번째 매개변수를 의미한다.

```swift
calculator(n1: 2, n2: 3, operation:{$0 * $1}) 
```

`{$0 * $1}`을 트레일링 클로저라고 한다.

```swift
let result = calculator(n1: 2, n2: 3, operation:{$0 * $1}) 
let result = calculator(n1: 2, n2: 3){$0 * $1} 
```
이렇게 간소화가 된다.

클로저사용의 장점은 코드가 간소화가 되는것이지만 그 간소화로인해 가독성이 떨어지는게 단점이다.

## 3. 클로저의 실제 활용

배열의 값에 모두 1씩 더해보자.

```swift
let array = [6,2,3,9,4,1]
```

swift는 map을 제공하는데 컬렉션 유형의 모든 항목을 변환 할 수있다.

```swift
let array = [6,2,3,9,4,1]

func addOne (n1:Int) -> Int {
    
    return n1 + 1
}
print(array.map(addOne)) // [7, 3, 4, 10, 5, 2]

```

이걸 위의 방법으로 클로저로 만들어 보자

```swift
print(array.map{$0 + 1}) // [7, 3, 4, 10, 5, 2]
```

## 4. 마무리
일반적인 클로저 표현은 다음과 같다. 

```swift
{ (parameters) -> return type in
    statements
}
```
- 괄호로 입력 파라미터를 감싸준다.
- -> 를 통해 반환 유형을 명시한다.
- in은 클로저 바디의 시작을 나타낸다.

클로저에 관한 Docs이다 나중에 한번 읽어보자.

<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures/>