---
title: 2주차 (6)
writer: Harold
date: 2024-03-13 05:11:00 +0800
categories: [캠프, 2주차]
tags: []

toc: true
toc_sticky: true
---

## 1. Protocol (프로토콜)

### 1. 프로토콜
- 특정 역할을 하기 위한 메소드, 프로퍼티, 기타 요구사항 등을 정의 해놓은 “규약” 혹은 “약속”
- class, structure, enum이 프로토콜을 ‘채택’하고 모든 요구사항을 충족하면 프로토콜을 ‘준수’했다고 한다.
- class, structure, enum이 프로토콜을 채택해서 특정 기능을 실행하기 위한 프로토콜의 요구사항을 실제로 구현할 수 있다.
- 프로토콜은 설계된 조건만 정의를 하고 제시를 할 뿐 스스로 기능을 구현하지 않는다.
- 프로토콜에서는 이름과 타입 그리고 `gettable`, `settable`을 명시한다
- 프로퍼티는 항상 `var`로 선언해야 한다.
- 메서드를 정의할 때 메서드 이름과 리턴값을 지정할 수 있고, ****`{}`(구현 코드)는 적지 않는다.
- 상속과 유사하다고 볼 수도 있겠지만 class 이외에 struct나 enum도 프로토콜을 채택할 수 있다는 특징이 있다
- 상속은 다중 상속이 불가능하지만 프로토콜은 다중 상속이 가능(확장성이 높음)

```swift
protocol 프로토콜이름 {
 // 프로토콜 정의
}

// 상속받는 클래스의 프로토콜 채택
class 클래스이름: 슈퍼클래스, 프로토콜1, 프로토콜2 {
 // 클래스 정의
}

protocol Vehicle {
    var speed: Double { get set } // get과 set을 모두 요구하는 가변 속성
    var manufacturer: String { get } // 읽기 전용 속성
}

class Car: Vehicle {
    var speed: Double = 0.0 // get과 set이 요구되는 속성을 구현
    var manufacturer: String = "Toyota" // 읽기 전용 속성을 구현
}

class Bicycle: Vehicle {
    var speed: Double = 0.0 // get과 set이 요구되는 속성을 구현
    var manufacturer: String { return "Giant" } // 읽기 전용 속성을 연산 프로퍼티로 구현
}

let car = Car()
car.speed = 60.0 // set 가능
print(car.speed) // get 가능
print(car.manufacturer) // get 가능

let bike = Bicycle()
bike.speed = 20.0 // set 가능
print(bike.speed) // get 가능
print(bike.manufacturer) // get 가능
```

```swift
// 예시
protocol Student {
    var studentId: Int { get set }
    var name: String { get }
    func printInfo() -> String
}

struct UnderGraduateStudent: Student {
    var studentId: Int
    var name: String
    var major: String
    
    func printInfo() -> String {
        return "\(name), whose student id is \(studentId), is major in \(major)"
    }
}

struct GraduateStudent: Student {
    var studentId: Int
    var name: String
    var degree: String
    var labNumber: Int
    
    func printInfo() -> String {
        return "\(name), member of lab no.\(labNumber), has a \(degree) degree"
    }
}

// 프로토콜은 타입으로서도 사용가능
let underGraduate: Student = UnderGraduateStudent(studentId: 1, name: "홍길동", major: "computer")
let graduate: Student = GraduateStudent(studentId: 2, name: "김철수", degree: "master", labNumber: 104)

let studentArray: [Student] = [underGraduate, graduate]
```

```swift
// 프로토콜의 다중상속
protocol Coordination
 {
    var top: String { get set }
    var pants: String { get set }

    init(top: String, pants: String)

    func checkCoordination()
}

protocol Hair {
    var hair: String { get }

    func checkHairStyle()
}

struct Person: Coordination, Hair {
    var top: String
    var pants: String
    let hair: String = "포마드"

    func checkHairStyle() {
        print("오늘의 헤어스타일은 \(hair)스타일")
    }

    func checkCoordination() {
        print("상의: \(top)\n하의: \(pants)")
    }

    init(top: String, pants: String) {
        self.top = top
        self.pants = pants
    }     
}

let safari: Person = Person(top: "긴팔", pants: "반바지")
safari.checkHairStyle()
safari.checkCoordination()
//오늘의 헤어스타일은 포마드스타일
//상의: 긴팔
//하의: 반바지
```

---

### 2.associatedtype, typealias

1. associatedtype
- **`associatedtype`**은 프로토콜 내에서 실제 타입을 명시하지 않고, 해당 프로토콜을 채택하는 타입에서 실제 타입을 결정하도록 하는데 사용된다.
- 프로토콜에서 특정 메서드, 속성 또는 서브스크립트의 반환 타입이나 매개변수 타입으로 구체적인 타입을 명시하지 않고 대신 **`associatedtype`**으로 선언하여 프로토콜을 채택하는 타입에서 실제 타입을 정의할 수 있다.

2. typealias
- **`typealias`**는 기존 타입에 대해 새로운 이름을 지정하거나 복잡한 타입에 대한 간결한 별칭을 생성할 때 사용된다.
- 코드를 읽기 쉽게 만들거나 여러 번 사용되는 긴 타입 이름을 간략하게 대체할 때 유용하다.

```swift
protocol Container {
    associatedtype Item // 연관 타입
    var count: Int { get }
    mutating func append(_ item: Item)
    func item(at index: Int) -> Item
}

struct IntContainer: Container {
    typealias Item = Int // 연관 타입을 Int로 typealias하여 구현
    var items = [Item]()
    
    var count: Int {
        return items.count
    }
    
    mutating func append(_ item: Item) {
        items.append(item)
    }
    
    func item(at index: Int) -> Item {
        return items[index]
    }
}

var intBox = IntContainer()
intBox.append(5)
intBox.append(10)
print(intBox.item(at: 0)) // 출력: 5

/*
위의 예시에서 Container 프로토콜은 Item이라는 연관 타입을 가지고 있다. 
이 연관 타입은 Container 프로토콜을 채택하는 구체적인 타입에서 실제 타입으로 정의된다. 
IntContainer 구조체에서 Item을 Int로 typealias하여 실제 타입을 정의하고, 
이를 사용하여 배열에 Int 값을 저장하고 반환하는 메서드를 구현한다.
*/
```

## 2. Extension (확장)

### 1. Extension
- 확장을 이용하여 structure, class, enum, protocol 타입에 새로운 기능을 추가할 수 있다.
- 기존 타입에 기능을 추가하는 수평 확장하는 개념이다.
- 확장은 타입에 새로운 기능을 추가할 수는 있지만, 기존에 존재하는 기능을 재정의할 수는 없다.
- 외부에서 가져온 타입에 내가 원하는 기능을 추가하고자 할 때 확장을 사용할 수 있다.

```swift
extension 확장할 타입 이름 {
	 //타입에 추가될 새로운 기능 구현
}

extension 확장할 타입 이름: 프로토콜1, 프로토콜2, 프로토콜3 {
	//프로토콜 요구사항 구현
}
```

### 2. 확장(Extension)이 가능한 경우와 불가능한 경우

#### 1. Extension으로 구현 가능한 것들
1. **새로운 계산된 속성(Computed Property) 추가**
2. **새로운 인스턴스/타입 메서드 추가**
3. **새로운 초기화(Initializer) 추가**
4. **프로토콜 채택(Protocol Conformance)**
5. **서브스크립트 추가(Subscripting)**
6. **중첩 타입(Nested Type) 추가**

```swift
// 1. 새로운 계산된 속성(Computed Property) 추가
// String 타입에 확장하여 문자열의 길이를 반환하는 속성 추가
extension String {
    var length: Int {
        return self.count
    }
}

let str = "Hello"
print(str.length) // 출력: 5

// 2. 새로운 인스턴스/타입 메서드 추가
// Int 타입에 확장하여 제곱 값을 반환하는 메서드 추가
extension Int {
    func squared() -> Int {
        return self * self
    }
}

let number = 3
print(number.squared()) // 출력: 9

// 3. 새로운 초기화(Initializer) 추가
// Double 타입에 확장하여 특정 숫자로 초기화하는 초기화 메서드 추가
extension Double {
    init(fromString str: String) {
        self = Double(str) ?? 0.0
    }
}

let value = Double(fromString: "3.14")
print(value) // 출력: 3.14


// 4. 프로토콜 채택(Protocol Conformance)
protocol Printable {
    func printDescription()
}

struct MyStruct {}

// Extension을 사용하여 기존 타입에 프로토콜 채택
extension MyStruct: Printable {
    func printDescription() {
        print("Printing description of MyStruct")
    }
}

let myInstance = MyStruct()
myInstance.printDescription() // 출력: Printing description of MyStruct


// 5. 서브스크립트 추가(Subscripting)
struct Matrix {
    private var data: [[Int]]
    
    init(rows: Int, columns: Int) {
        data = Array(repeating: Array(repeating: 0, count: columns), count: rows)
    }
}

extension Matrix {
		// Extension을 사용하여 서브스크립트 추가
    subscript(row: Int, column: Int) -> Int {
        get {
            return data[row][column]
        }
        set {
            data[row][column] = newValue
        }
    }
}
    


var matrix = Matrix(rows: 3, columns: 3)
matrix[0, 0] = 1
matrix[1, 1] = 2

print(matrix[0, 0]) // 출력: 1
print(matrix[1, 1]) // 출력: 2

// 6. 중첩 타입(Nested Type) 추가
struct Container {
    // 기존 타입 내에서 중첩된 타입
    struct NestedType {
        var value: Int
    }
}

// Extension을 사용하여 중첩 타입 추가
extension Container {
    struct AnotherNestedType {
        var name: String
    }
}

let nested = Container.NestedType(value: 5)
print(nested.value) // 출력: 5

let anotherNested = Container.AnotherNestedType(name: "NestedType")
print(anotherNested.name) // 출력: NestedType
```

#### 2. Extension으로 구현 불가능한 것들
1. **저장 프로퍼티(Stored Property) 추가**
    - Extension으로는 저장 프로퍼티를 추가할 수 없다. 오직 계산된 프로퍼티만 추가할 수 있다.
2. **기존 기능의 재정의(Override)**
    - 이미 존재하는 기능을 Extension에서 재정의(Override)할 수 없다. 상속과 재정의는 클래스에서만 가능.
3. **초기화 메서드(Initializer)의 재정의**
    - Extension으로는 새로운 편의 초기화 메서드를 추가할 수 있지만, 기본 초기화 메서드 또는 지정 초기화 메서드를 재정의할 수는 없다.
4. **기존 타입의 저장된 프로퍼티에 기본값 설정**
    - Extension에서는 기존 타입에 저장된 프로퍼티에 기본값을 설정할 수 없다.

```swift
// 1. 저장 프로퍼티(Stored Property) 추가
// Extension으로 저장 프로퍼티 추가 시 컴파일 에러 발생
extension Int {
    var newProperty: Int = 5 // 컴파일 에러 발생
}


// 2. 기존 기능의 재정의(Override)
// Extension으로 기존 메서드 재정의 시 컴파일 에러 발생
extension Int {
    func description() -> String { // 컴파일 에러 발생
        return "This is an extension method"
    }
}


// 3. 초기화 메서드(Initializer)의 재정의
// Extension으로 기존 타입의 초기화 메서드 재정의 시 컴파일 에러 발생
extension String {
    init() { // 컴파일 에러 발생
        self = "Default Value"
    }
}


// 4. 기존 타입의 저장된 프로퍼티에 기본값 설정
// Extension으로 기존 타입의 저장된 프로퍼티에 기본값 설정 시 컴파일 에러 발생
extension Double {
    var defaultValue: Double = 10.0 // 컴파일 에러 발생
}
```