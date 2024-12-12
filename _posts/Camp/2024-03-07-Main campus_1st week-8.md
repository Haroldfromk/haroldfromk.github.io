---
title: 1주차 (8)
writer: Harold
date: 2024-03-07 01:11:00 +0800
categories: [캠프, 1주차]
tags: []

toc: true
toc_sticky: true
---

## 1. Class(클래스)
- 클래스는 프로퍼티와 메서드로 구분 되어있다.

### 1. Properties(프로퍼티)
- 프로퍼티는 클래스, 구조체, 또는 열거형 안에 있는 변수 또는 상수를 나타낸다.
- 클래스의 속성으로 객체의 상태를 저장하거나 제공한다. 이러한 상태는 클래스의 인스턴스가 가질 수 있는 고유한 데이터를 나타낸다.
- 프로퍼티는 저장 프로퍼티(Stored Properties)와 계산 프로퍼티(Computed Properties)로 나눌 수 있따.
    - 저장 프로퍼티: 값을 저장하고, 인스턴스의 일부로서 그 값을 유지
    - 계산 프로퍼티: 특정한 계산을 통해 값을 반환하며, 값을 저장하지 않고 필요할 때마다 새로 계산한다.

### 2. 메서드(Methods)
- 메서드는 클래스, 구조체, 또는 열거형 안에 있는 함수를 나타낸다.
- 클래스의 동작을 정의하고, 클래스의 인스턴스에 대해 수행되는 특정한 작업을 수행한다.
- 메서드는 인스턴스 메서드(Instance Methods)와 타입 메서드(Type Methods)로 구분한다.
    - 인스턴스 메서드: 특정 인스턴스에 속하는 동작을 정의하고, 인스턴스의 상태에 접근할 수 있다.
    - 타입 메서드: 클래스 자체와 관련된 동작을 정의하며, 특정 인스턴스에 속하는 것이 아닌 클래스 자체에 영향을 준다.
- 클래스는 이니셜라이저(Initializer)를 통해 초기값을 설정할 수 있다.
    - 프로퍼티에 기본 값이 없는 경우 이니셜라이저를 필수로 구현해야 한다. 그렇지 않을 경우 에러가 발생합니다.
    - 즉, 클래스를 구성하고 변수를 만들때 거기에 초기값을 부여를 하지 않으면 반드시 init을 해야한다.
- 참조 타입
    - 참조 타입은 변수나 상수에 할당될 때에는 값을 복사하는 것이 아니라 참조(주소)가 복사되어 같은 인스턴스를 가리키게 된다. 클래스(Class)가 참조 타입의 대표적인 예시이다.
    - 참조 타입의 경우 변수나 상수에 할당될 때 참조가 복사되므로, 동일한 인스턴스를 공유하게 된다. 따라서 한 쪽에서 값을 변경하면 다른 쪽에서도 영향을 받게 된다.

```swift
// 참조 타입인 클래스
class Person {
    var name: String

    init(name: String) {
        self.name = name
    }
}

var person1 = Person(name: "Alice")
var person2 = person1 // 참조 복사
person2.name = "Bob"

print(person1.name) // 출력: Bob
print(person2.name) // 출력: Bob
```

```swift
// 클래스 구성
// 예시 1
class Name {
    var name: String

		init(name: String) {
				self.name = name
		}
    
    func sayMyName() {
        print("my name is \(name)")
    }
}

let song : Name = Name(name: "song")

print(song.name) // song
song.sayMyName() // my name is song

song.name = "kim"
song.sayMyName() // my name is kim


// 예시 2
class Person {
    var name: String // 저장 프로퍼티
    
    var introduction: String { // 계산 프로퍼티
        return "제 이름은 \(name)입니다."
    }
    
    init(name: String) {
        self.name = name
    }
}

// Person 객체 생성
let person1 = Person(name: "Alice")
print(person1.introduction) // 출력: 제 이름은 Alice입니다.


// 예시 3
class Counter {
    var count = 0 // 저장 프로퍼티
    
    func increment() { // 인스턴스 메서드
        count += 1
    }
    
    static func reset() { // 타입 메서드
        print("카운터를 초기화합니다.")
    }
}

// Counter 객체 생성
let counter1 = Counter()
counter1.increment()
counter1.increment()
print(counter1.count) // 출력: 2

// 타입메서드(Static)는 반드시 클래스를 통해 호출해야한다! 
Counter.reset() // 출력: 카운터를 초기화합니다.
```

### 3. 상속
- 상속
    - Swift에서 상속(Inheritance)은 클래스(Class) 간에 코드 및 속성을 공유하는 메커니즘을 제공한다.
    - 상속은 기존 클래스에서 새로운 클래스를 만들고, 기존 클래스의 특성(속성과 메서드)을 재사용하면서 새로운 기능을 추가할 수 있도록 해준다(서브 클래싱).
- 상속의 장점
    - 코드 재사용성
        - 기존 클래스의 특성을 재사용하여 중복을 피하고 유지보수성을 높일 수 있다.
    - 계층 구조
        - 부모 클래스와 이를 상속받는 자식 클래스 간에 계층 구조를 형성하여 다양한 수준의 추상화와 분류를 가능하게한다. 
- `override`
    - 부모 클래스에서 상속받은 메서드, 속성 또는 서브스크립트를 자식 클래스에서 다시 정의할 때 사용.
    - 자식 클래스에서 부모 클래스의 메서드를 **재정의**하여 새로운 구현을 제공할 수 있다.
    - 메서드, 속성, 서브스크립트를 재정의하기 위해서는 **`override`** 키워드를 사용해야 한다.
- `super`
    - 자식 클래스에서 부모 클래스의 메서드, 속성 또는 초기화 메서드를 호출할 때 사용.
    - 부모 클래스의 메서드를 호출하거나 부모 클래스의 초기화 메서드를 호출하는 데 사용됩니다.
    - **`super.method()`** 또는 **`super.property`**와 같이 사용하여 부모 클래스의 기능을 호출할 수 있다.
- `final`
    - 클래스, 메서드, 속성 또는 서브스크립트를 표시하여 상속이 불가능하도록 만든다.
    - **`final`** 키워드가 클래스에 사용되면 해당 클래스는 상속될 수 없다.
    - 메서드, 속성, 서브스크립트에 사용될 경우, 해당 멤버들을 재정의(Override)할 수 없다.

```swift
// 부모 클래스(Person) 선언
class Person {
    var name: String
    var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    func greet() {
        print("Hello, my name is \(name).")
    }
}

// Person 클래스를 상속받는 자식 클래스(Student) 선언
class Student: Person {
    var studentID: Int

    init(name: String, age: Int, studentID: Int) {
        self.studentID = studentID
        super.init(name: name, age: age)
    }

    func study() {
        print("\(name) is studying.")
    }
}

// Student 클래스 인스턴스 생성 및 사용
let john = Student(name: "John", age: 20, studentID: 123)
john.greet() // 출력: Hello, my name is John.
john.study() // 출력: John is studying.



// override, super 키워드 예시

class Animal {
    func makeSound() {
        print("Some generic sound")
    }
}

class Dog: Animal {
    override func makeSound() {
        super.makeSound() // 부모 클래스의 메서드 호출
        print("Bark!")
    }
}

let dog = Dog()
dog.makeSound()


// final 키워드 예시

final class Vehicle {
    final var wheels: Int = 0
    
    final func makeSound() {
        print("Some generic sound")
    }
}

// Error: 'SubVehicle' cannot inherit from final class 'Vehicle' → class에 final을 붙였을 경우 발생
class SubVehicle: Vehicle {
    // Error: 'wheels' cannot override 'final' var from superclass → 변수에 final을 붙였을 경우 발생
    // override var wheels: Int = 4
    
    // Error: 'makeSound()' cannot override a final method → function에 final을 붙였을 경우 발생
    // override func makeSound() {
    //     print("Custom sound")
    // }
}
```

## 2. Struct(구조체)
- 구조체는 클래스와 마찬가지로 프로퍼티에 값을 저장하거나 메서드를 통해 기능을 제공하고 이걸 하나로 캡슐화할 수 있는 사용자 정의 타입이다.
- 생성자(initializer)를 정의하지 않으면 구조체가 **자동으로 생성자(Memberwise Initializer.)를 제공한다.**
- init을 할 필요가 없다!
- 값 타입
    - 값 타입은 변수나 상수에 할당될 때 값의 복사본이 생성되는 타입이다. 주로 구조체(Structures), 열거형(Enumerations), 기본 데이터 타입(Int, Double, Bool, 등)이 값 타입에 해당

```swift
// 값 타입인 구조체 예시
struct Point {
    var x: Int
    var y: Int
}

var point1 = Point(x: 5, y: 10)
var point2 = point1 // 값 복사
point2.x = 15

print(point1) // 출력: Point(x: 5, y: 10)
print(point2) // 출력: Point(x: 15, y: 10)
// class와 달리 같은 주소를 공유 하지 않아, 값이 다르다!
```

- 클래스와 달리 구조체는 상속을 할 수 없다.
- 클래스와 같이 인스턴스로 만들어 사용할 수 있다.

```swift
struct Coffee {
  var name: String?
  var size: String?

  func brewCoffee() -> String {
    if let name = self.name {
      return "\(name) ☕️ 한 잔 나왔습니다"
    } else {
      return "오늘의 커피 ☕️ 한잔 나왔습니다"
    }
  }
}

let americano = Coffee(name: "아메리카노")
// 출력값: 아메리카노 ☕️ 한 잔 나왔습니다

// 따로 init()을 구현하지 않아도 자동으로 생성자를 받습니다.

// Memberwise Initializer 예시
struct ShoppingListItem {
    let name: String?
    let quantity: Int
    var purchased = false
}

let item1 = ShoppingListItem(name: "칫솔", quantity: 1)
let item2 = ShoppingListItem(name: "치약", quantity: 1, purchased: true)
let item3 = ShoppingListItem(name: nil, quantity: 1, purchased: true)
```

## 3. enum(열거형)
- Enum은 관련된 값으로 이뤄진 그룹을 같은 타입으로 선언해 타입 안전성을 보장하는 방법으로 코드를 다룰 수 있게 해준다.

```swift
// 간단한 열거형 선언
enum CompassDirection {
    case north
    case south
    case east
    case west
}

// 열거형의 인스턴스 생성 및 사용
var direction = CompassDirection.north
var anotherDirection = direction // 값 복사

direction = .east // 값을 변경해도 anotherDirection에는 영향이 없음

print(direction) // 출력: east
print(anotherDirection) // 출력: north
```

- Swift의 열거형(Enum)은 연관 값(Associated Values)을 가질 수 있습니다. 이는 각 case가 특정 값을 연결하여 저장할 수 있는 기능을 제공한다.

```swift
// 연관 값을 가진 열거형 선언
enum Trade {
    case buy(stock: String, amount: Int)
    case sell(stock: String, amount: Int)
    case hold
}

// 열거형의 인스턴스 생성 및 사용
let trade1 = Trade.buy(stock: "AAPL", amount: 100)
let trade2 = Trade.sell(stock: "GOOG", amount: 50)
let trade3 = Trade.hold

// switch 문을 사용하여 연관 값 추출
func processTrade(trade: Trade) {
    switch trade {
    case .buy(let stock, let amount):
        print("Buy \(amount) shares of \(stock).")
    case .sell(let stock, let amount):
        print("Sell \(amount) shares of \(stock).")
    case .hold:
        print("Hold this position.")
    }
}

// 각 열거형 케이스에 따라 다른 동작 수행
processTrade(trade: trade1) // 출력: Buy 100 shares of AAPL.
processTrade(trade: trade2) // 출력: Sell 50 shares of GOOG.
processTrade(trade: trade3) // 출력: Hold this position.
```

- 자주 사용하는 메서드
```swift
enum CompassPoint {
    case north
    case south
    case east
    case west
}

// 한 케이스 선언 방법
var directionToHead = CompassPoint.west
directionToHead = .east

// 활용 예시 1
directionToHead = .south
switch directionToHead {
case .north:
    print("북쪽")
case .south:
    print("남쪽")
case .east:
    print("동쪽")
case .west:
    print("서쪽")
}
// 출력값: "남쪽"

// allCases 
enum Beverage: CaseIterable {
    case coffee, tea, juice
}
let numberOfChoices = Beverage.allCases.count
print("\(numberOfChoices) 잔 주문 가능합니다.")
// 출력값: 3잔 주문 가능합니다
```

- Optional은 enum이다. (특강에서도 언급되었던 내용)

```swift
// 실제 Optional의 정의
@frozen public enum Optional<Wrapped> : ExpressibleByNilLiteral {

    /// The absence of a value.
    ///
    /// In code, the absence of a value is typically written using the `nil`
    /// literal rather than the explicit `.none` enumeration case.
    case none

    /// The presence of a value, stored as `Wrapped`.
    case some(Wrapped)


print(Optional.none == nil) // true
```

## 4. 정리
- 클래스와 구조체, 열거형 모두 메모리에 할당되고 그 생성된 대상을 인스턴스(instance)라고 한다.
- 스위프트에서는 클래스의 인스턴스(instance)를 특별히 객체(object)라고 한다.
- 메모리 저장 방식
    - 구조체, 열거형
        - 값 타입(Value Type)
        - 인스턴스 데이터를 모두 스택(Stack)에 저장
        - 새로운 변수에 할당(값을 전달할때마다)할때마다 복사본을 생성 (다른 메모리 공간 생성)
        - 스택(Stack)의 공간에 저장, 스택 프레임 종료시, 메모리에서 자동 제거
    - 클래스
        - 참조 타입(Reference Type)
        - ARC시스템을 통해 메모리 관리
        - 인스턴스 데이터는 힙(Heap)에 저장, 해당 힙을 가르키는 변수는 스택에 저장하고 변수의 메모리 주소값이 힙을 가리킴
        - 값을 전달하는 것이 아니고, 저장된 주소를 전달

![](https://koenig-media.raywenderlich.com/uploads/2015/11/types-700x195.png)

![](https://i.stack.imgur.com/3scvQ.png)