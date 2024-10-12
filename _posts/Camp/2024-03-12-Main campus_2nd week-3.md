---
title: 2주차 (3)
writer: Harold
date: 2024-03-12 01:11:00 +0800
categories: [캠프, 2주차]
tags: []

toc: true
toc_sticky: true
---

## 접근 제한자

- 접근 제한자는 다른 소스 파일이나 모듈의 코드에서 코드 일부에 대한 접근을 제한.
- [제약이 적음] `open` < `public` < `internal` < `fileprivate` < `private` [제약이 많음]
    - open : 모든 소스 파일에서 해당 level 접근 가능 + 모든 곳에서 서브클래싱 가능
    - public : 모든 소스 파일에서 해당 level 접근 가능 + 같은 모듈 내에서만 서브클래싱 가능
    - internal : 같은 모듈 내에서만 접근 가능, default
    - fileprivate : 같은 소스파일 내에서만 접근 가능
    - private : 클래스 내부에서만 접근 가능
- 접근 제한자를 작성하지 않으면  `internal`로 판단
- 상위 요소보다 하위 요소가 더 높은 접근 수준을 가질 수 없다.

```swift
private struct Car {
	  public var model: String // 🚨 에러 : private이 하위인데 public이 사용되었다
} 
```

- 모듈과 소스파일
    - 모듈(module)
        - 배포할 코드의 묶음 단위
        - 하나의 프레임워크/ 라이브러리/ 어플리케이션이 모듈 단위가 될 수 있다.
        - import 키워드를 통해 불러올 수 있다.
    - 소스파일
        - 하나의 swift 소스 코드 파일을 의미한다.
- `public`, `open`
    - 둘 다 모듈 외부까지 접근할 수 있다.
    - `open`은 클래스와 클래스 맴버에서만 사용할 수 있고 다른 모듈에서 서브클래싱이 가능하지만 `public`은 그렇지 않다.
    - `open`으로 클래스를 개방 접근 수준으로 명시하는 것은 그 클래스를 다른 모듈에서도 수퍼클래스로 사용하겠다는 의미로 해당 클래스를 설계하고 만들었다는 것을 의미한다. (다른 모듈에서 상속을 허용함)
    - `public`은 주로 프레임워크에서 외부와 연결될 인터페이스를 구현하는데 많이 사용한다.
- `internal`
    - 모든 요소에 암묵적으로 지정하는 디폴트 접근 제어자
    - 소스 파일이 속해있는 모듈 어디에든 접근할 수 있지만 외부 모듈에서는 접근할 수 없다.
- `fileprivate`
    - 소스 파일 내부에서만 접근할 수 있다.
    - 서로 다른 클래스가 같은 하나의 소스 파일에 정의되어있고 `fileprivate`로 선언되어 있다면 두 클래스는 서로 접근할 수 있다.
- `private`
    - 가장 제한적인 접근제어자
    - `fileprivate`과 달리 같은 파일 안에 있어도 서로 다른 클래스이고 `private`로 선언되어 있다면 두 요소는 서로 접근할 수 없다.

```swift
// open 
open class Vehicle {
    open func startEngine() {
        print("Engine started")
    }
}

open class Car: Vehicle {
    open var carType: String = "Sedan"
}

// public 
public struct Point {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public mutating func moveByX(_ deltaX: Int, y deltaY: Int) {
        self.x += deltaX
        self.y += deltaY
    }
}

// internal
internal class InternalClass {
    internal var internalProperty: Int = 10

    internal func doSomethingInternally() {
        print("Internal operation performed")
    }
}

internal let internalConstant = 20

// fileprivate
class OuterClass {
    fileprivate var outerVariable = 30

    fileprivate func outerFunction() {
        print("Outer function called")
    }

    fileprivate class InnerClass {
        fileprivate func innerFunction() {
            print("Inner function called")
        }
    }
}

// private
class MyClass {
    private var privateVariable = 40

    private func privateFunction() {
        print("Private function called")
    }
}



/*
Swift에서 mutating 키워드는 구조체(Structs)나 열거형(Enum) 내에서 
메서드(Method)가 해당 구조체 또는 열거형의 속성을 수정할 수 있도록 하는 키워드.

기본적으로 Swift에서는 구조체나 열거형의 인스턴스가 상수로 선언되면 
해당 인스턴스의 속성을 변경할 수 없다. 
그러나 메서드 내에서 해당 인스턴스의 속성을 변경하려면 mutating 키워드를 사용하여 
해당 메서드가 해당 인스턴스의 속성을 수정할 수 있도록 허용해야 한다.
*/

// 구조체 예시
struct Point {
    var x = 0.0, y = 0.0

    mutating func moveBy(x deltaX: Double, y deltaY: Double) {
        x += deltaX
        y += deltaY
    }
}

var point = Point(x: 1.0, y: 1.0)
print("Before moving: x = \(point.x), y = \(point.y)")

point.moveBy(x: 2.0, y: 3.0)
print("After moving: x = \(point.x), y = \(point.y)")

// Before moving: x = 1.0, y = 1.0
// After moving: x = 3.0, y = 4.0


// 열거형 예시
enum TrafficLight {
    case red, yellow, green

    mutating func next() {
        switch self {
        case .red:
            self = .green
        case .yellow:
            self = .red
        case .green:
            self = .yellow
        }
    }
}

var currentLight = TrafficLight.red
print("Current light is \(currentLight)")

currentLight.next()
print("Next light is \(currentLight)")

// Current light is red
// Next light is green

```