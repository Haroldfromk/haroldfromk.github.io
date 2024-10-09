---
title: 2주차 (5)
writer: Harold
date: 2024-03-12 05:11:00 +0800
categories: [캠프, 2주차]
tags: []

toc: true
toc_sticky: true
---

## 예외처리

### 실패 가능한 상황과 예외 처리
- 에러처리
    - 프로그램에서 에러가 발생한 상황에 대응하고 이에 대응하는 과정.
    - Swift에서는 런타임에 에러가 발생한 경우, 이를 처리를 지원하는 클래스를 제공한다.
    - 프로그램에서 모든 기능이 개발자가 예상하고 원하는대로 동작한다는 보장은 없다. 
        - 따라서 예외 처리를 통해 예외 상황을 구별하고 프로그램 자체적으로 오류를 해결하거나, 사용자에게 어떤 에러가 발생했는지 알려주는 등에 대한 조치와 대응을 해야한.
- Error
    - Error는 던져질 수 있는 오류 값을 나타내는 유형을 말한다.
    - Error 프로토콜을 채택하여 사용자 정의 에러를 정의하여 사용할 수 있다

```swift
enum VendingMachineError: Error {
    case invalidSelection
    case insufficientFunds(coinsNeeded: Int)
    case outOfStock
}
```

### throw와 do-catch문 & try문

- throw와 throws
    - `throws`는 리턴 값을 반환하기 전에 오류가 발생하면 에러 객체를 반환한다는 의미.
    - `throws`는 오류가 발생할 가능성이 있는 메소드 제목 옆에 써준다.
    - `throw`는 오류가 발생할 구간에서 써준다.
- throw로 던진 에러를 do-catch문에서 처리한다.

```swift
// 표현
func canThrowErrors() throws -> String
func cannotThrowErrors() -> String

enum CustomError: Error {
    case outOfBounds
    case invalidInput(String)
}

func processValue(_ value: Int) throws -> Int {
    if value < 0 {
        throw CustomError.invalidInput("Value cannot be negative")
    } else if value > 100 {
        throw CustomError.outOfBounds
    }
    
    return value * 2
}

// do-catch 블록을 이용하여 throwing 함수 호출 및 에러 처리하기
do {
    let result = try processValue(50)
    print("Result is \(result)")
} catch CustomError.outOfBounds {
    print("Value is out of bounds!")
} catch CustomError.invalidInput(let errorMessage) {
    print("Invalid Input: \(errorMessage)")
} catch {
    print("An error occurred: \(error)")
}
// 출력 : Result is 100


do {
    let result = try processValue(-10)
    print("Result is \(result)")
} catch CustomError.outOfBounds {
    print("Value is out of bounds!")
} catch CustomError.invalidInput(let errorMessage) {
    print("Invalid Input: \(errorMessage)")
} catch {
    print("An error occurred: \(error)")
}
// 출력 : Invalid Input: Value cannot be negative

```

### `try` , `try?` , `try!`
- `try`
    - 에러가 발생할 수 있는 코드 블록을 표시
    - 에러를 던질 수 있는 함수나 메서드를 호출할 때 사용된다.
    - 해당 코드 블록에서 발생한 에러를 잡거나 처리할 수 있다(do - catch문).
- `try?`
    - do - catch 구문 없이도 사용이 가능하다.
    - 에러 발생시 nil값을 반환.
    - 에러가 발생하지 않으면 리턴 값의 타입은 옵셔널로 반환.
- `try!`
    - 에러가 발생을 하면 앱이 강제 종료된다.
    - 반환 타입은 옵셔널이 언래핑된 값이 리턴된다.
    - 오류가 발생하지 않는다는 보장아래 사용해야한다.

```swift
enum MyError: Error {
    case invalidInput
}

func someThrowingFunction(value: Int) throws -> String {
    guard value >= 0 else {
        throw MyError.invalidInput // value가 음수인 경우 에러를 던짐
    }

    return "The value is \(value)"
}

// throwing 함수 호출과 에러 처리하기
do {
    let result = try someThrowingFunction(value: 5)
    print(result)
} catch {
    print("Error occurred: \(error)")
}

do {
    let result = try someThrowingFunction(value: -2) // 에러 발생
    print(result)
} catch {
    print("Error occurred: \(error)") // 음수 값을 처리하는 에러
}

// try?를 사용하여 에러 처리하기
let result1 = try? someThrowingFunction(value: 5) // 유효한 값 호출
print(result1) // Optional("The value is 5")

let result2 = try? someThrowingFunction(value: -2) // 에러 발생
print(result2) // nil

// try!를 사용하여 에러 처리하기
let result3 = try! someThrowingFunction(value: 5) // 유효한 값 호출
print(result3) // The value is 5

let result4 = try! someThrowingFunction(value: -2) // 에러 발생
print(result4)
```