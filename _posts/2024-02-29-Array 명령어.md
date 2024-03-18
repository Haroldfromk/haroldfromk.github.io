---
title: Array 명령어
writer: Harold
date: 2024-02-29 14:56
last_modified_at: 2024-03-01
categories: [Deep Dive]
tags: [코딩테스트]

toc: true
toc_sticky: true
---
배열에 대해서 정리를 해보자.
이것도 추가로 필요한게 있다면 지속적으로 수정 할 예정

## 초기화 및 선언
- 배열은 가지는 요소에 타입에 따라 자동으로 타입 추론이 가능하다.
- 선언과 동시에 초기화 할 때는 요소에 값이 들어있다면 자동으로 타입 추론이 이루어지기 때문에 타입을 명시해주지 않아도 된다.

- 예시
```swift
var intNumbers = [1,2,3,4,5] // 'Int' 요소를 갖는 배열
var strings = ["A", "BC", "DEF"] // 'String' 요소를 갖는 배열
```
- 단, 빈 배열을 선언할 때는 타입을 명시해주지 않으면 에러가 발생
예시
```swift
var emptyDoubles: [Double] = []
var emptyStrings = [String]()
var emptyFloats: Array<Float> = Array()

var emptyArray = [] // [!] Empty collection literal requires an explicit type
```

- Int 타입 배열은 연속된 숫자 배열을 쉽게 선언할 수 있다
```swift
var intArray = Array<Int>(1...10) // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
```


- 한 배열에 여러 자료형 요소를 넣고싶으면 Any 타입을 사용하면 된다.
```swift
let anyArray: [Any] = [1, 2, "a", "b"]
```
---

## 모든 요소를 반복되는 값으로 초기화
- 특정 값만 반복적으로 가지는 배열일 경우 Array(repeating:count:)를 사용한다.
```swift
var digitCounts = Array(repeating: 0, count: 10) 
print(digitCounts) // [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

var stringCounts = [String](repeating: "", count: 10) 
print(stringCounts) // ["", "", "", "", "", "", "", "", "", ""]
```

- 여기서 repeating에 들어가는 값이 클래스의 인스턴스일 경우, 반복되는 모든 요소가 동일한 인스턴스를 참조하게 되므로 주의 해야함. (요소 하나의 속성만 변경해도 모든 값이 변경됨)
```swift
class Person: CustomStringConvertible {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    var description: String {
        return "Person(\(self.name))"
    }
}

var persons = Array(repeating: Person(name: "홍길동"), count: 3)
print(persons)  // [Person("홍길동"), Person("홍길동"), Person("홍길동")]

persons[0].name = "이순신"
print(persons)  // [Person("이순신"), Person("이순신"), Person("이순신")]
```
---
## 배열 출력
- print()를 사용하면 된다.
```swift
var array = ["A","B","C"]
print(array) // ["A", "B", "C"]
```
---
## 값 접근
- 배열에서 요소의 위치(인덱스) 값으로 요소를 찾아올 수 있다. 인덱스 범위를 사용해도 된다.
```swift
var array = ["A","B","C"]
print(array[0]) // "A"
print(array[1..<3]) // ["B", "C"]
```
- 빈 배열의 경우, 값을 참조하려고 할 때 없는 인덱스를 참조하는 것이므로 런타임 에러(Index out of range)가 발생
```swift
var EmptyDoubles: [Double] = []
print(emptyDoubles[0]) // [!] Triggers runtime error: Index out of range
```
---
## 값 변경
- 변경하고 싶은 요소의 위치에 다른 값을 넣을 수 있다.
- let으로 선언된 배열에는 변경할 수 없다.
```swift
var array = ["A","B","C"]
array[0] = "Apple"
array[1] = "Banana"
array[2] = "Carrot"
print(array) // ["Apple", "Banana", "Carrot"]

let intArray = [1,2,3]
intArray[0] = 100 // [!] Cannot assign through subscript: 'intArray' is a 'let' constant
```
---
## 값 추가
- 배열의 맨 뒤에 값을 추가하는 방법으로는 append(_:)를 사용한다.
```swift
var numbers = [1,2,3,4]
numbers.append(5)
print(numbers) // [1, 2, 3, 4, 5]
```
- 배열 뒤에 여러 요소들을 한꺼번에 추가 하고 싶을 때는 append(contentsOf:)를 사용한다. (또는 += 연산자를 사용할 수도 있다.)
```swift
var numbers = [1,2,3,4]

var moreNumbers = [5, 6, 7]
numbers.append(contentsOf: moreNumbers)
print(numbers) // [1, 2, 3, 4, 5, 6, 7]

numbers += [8,9,10]
print(numbers) // [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
```
- 배열의 특정 위치에 값을 삽입하고 싶을 경우에는 insert(_:at:)을 사용한다.
	
    - 앞의 인자에는 넣고 싶은 값을 입력한다.
    - 뒤의 인자 at에는 넣을 위치(인덱스)를 입력한다.
    - 이 메소드를 사용하면 값을 삽입한 위치 뒤의 요소들은 한 칸씩 뒤로 밀리게되고, 배열의 크기는 1 증가한다.

```swift
var numbers = [1,2,3,4,5]
numbers.insert(0, at: 0)
print(numbers) // [0, 1, 2, 3, 4, 5]
```
- insert(contentsOf:at:)을 사용하여 특정 위치에 여러 요소를 한꺼번에 삽입할 수 있다.
```swift
var numbers = [1,2,3,4,5]
numbers.insert(contentsOf: [1,2,3], at: 3)
print(numbers) // [1, 2, 3, 1, 2, 3, 4, 5]
```
---
## 값 제거
- 값을 제거할때는 remove(at:)에 제거하고 싶은 값의 인덱스를 입력하면 된다.
```swift
var numbers = [1,2,3]
numbers.remove(at: 1) // 인덱스 1에 있는 2를 제거한다.
print(numbers) // [1,3]
```
- 첫번째 값을 제거하고 싶을 때는 removeFirst(), 마지막 값을 제거하고 싶을때는 removeLast()를 사용한다.
	
    - 제거한 값을 반환하기 때문에, 빈 배열일 경우 에러가 발생
```swift
var numbers = [1,2,3]
numbers.removeFirst() // numbers.remove(at: 0)와 같은 표현
numbers.removeLast()  // numbers.remove(at: numbers.count-1)와 같은 표현
print(numbers) // [2]
```

- removeFirst()와 removeLast()에 인자값으로 점프할 인덱스 값을 넣을 수 있다.
	
    - 배열의 맨 앞 또는 맨 뒤에서부터 몇 칸 띄운 값을 지우겠다는 의미. 
```swift
var numbers = [1,2,3,4,5]
numbers.removeFirst(2) // numbers.remove(at: 2)와 같은 표현 => 3 삭제
numbers.removeLast(1)  // numbers.remove(at: numbers.count-2)와 같은 표현 => 4 삭제
print(numbers) // [1,2,5]
```

- 마지막 값을 제거하는 방법으로는 popLast()도 있다.
	
    - 마지막 값(Optional)을 반환하면서 제거한다.
    - 빈 배열일 경우 nil을 반환하고 에러가 발생하지 않는다.
```swift
var numbers = [1,2,3]
print(numbers.popLast()) // Optional(3)
print(numbers) // [1,2]
```

- 모든 요소를 제거하여 빈 배열로 만들고 싶을 경우에는 removeAll()을 사용한다.
```swift
var numbers = [1,2,3]
numbers.removeAll()
print(numbers) // []
```

- 일부 구간을 제거하고 싶을 때는 removeSubrange(_:)에 제거하고 싶은 인덱스 범위를 입력한다.

```swift
var numbers = [1,2,3,4,5,6]
numbers.removeSubrange(1..<4) // 인덱스 1,2,3 범위의 값을 제거한다.
print(numbers) // [1,5,6]
```

- dropFirst(_:), dropLast(_:)를 사용하면 기존 배열은 그대로두고, 기존 배열에서 앞 또는 뒤에서 몇개의 값을 제거한 새로운 배열을 반환
```swift
let numbers = [1, 2, 3, 4, 5]
print(numbers.dropFirst(2))	// [3, 4, 5] : 앞에서부터 2개 제거한 새로운 배열 반환
print(numbers.dropFirst(10))	// [] : 앞에서부터 10개 제거한 새로운 배열 반환
print(numbers) // [1, 2, 3, 4, 5] : 기존 배열은 그대로

let numbers = [1, 2, 3, 4, 5]
print(numbers.dropLast(2))	// [1, 2, 3] : 뒤에서부터 2개 제거한 새로운 배열 반환
print(numbers.dropLast(10))	// [] : 뒤에서부터 10개 제거한 새로운 배열 반환
print(numbers) // [1, 2, 3, 4, 5] : 기존 배열은 그대로
```
---
## 값의 인덱스 찾기
- 배열에서 원하는 값의 인덱스를 찾고 싶을 때는 firstIndex(of:)를 사용한다. Optional Int 형태를 반환한다.
- 배열에서 찾고자 하는 값이 여러개일 경우, 가장 앞에 있는 값의 인덱스를 반환한다.
	
    - 해당하는 값이 없을 때는 nil을 반환한다.
```swift
var numbers = [1,2,3,4,4,3,2,1]
print(numbers.firstIndex(of: 3)) // Optional(2)
print(numbers.firstIndex(of: 5)) // nil
```
- 반환값이 Optional 이므로 Unwrapping하여 사용한다.
```swift
var fruits = ["Apple", "Banana", "Carrot"]
if let i = fruits.firstIndex(of: "Banana") {
    fruits[i] = "Beetroot"
}
print(fruits) // ["Apple", "Beetroot", "Carrot"]
```

- 원하는 값의 마지막 인덱스를 찾고 싶을때는 lastIndex(of:)를 사용한다.
---
## 특정 값 포함
- 특정 요소가 있는지 판단하기 위해서는 firstIndex(of:)를 사용 했을때 반환값이 nil이 아닌지를 검사해도 된다.
- 하지만 단순히 포함 여부만 알고싶다면 contains() 메소드를 사용한다
	
    - Bool값을 반환한다.
```swift
var numbers = [1,2,3,4]
print(numbers.contains(4)) // true
print(numbers.contains(5)) // false
```
---
## 배열의 크기
- 배열에 요소가 몇 개 있는지 알고 싶으면 count를 사용한다.
```swift
var empty = [Int]()
print(empty.count) // 0
```

- 배열을 처음에 선언하면, 배열의 크기와 별개로 내용을 보관하기 위한 메모리를 예약하게 된다.
- 배열에 예약된 메모리 크기는 capacity 속성을 사용해서 알 수 있다.

	
    - capacity속성은 새 스토리지를 할당하지 않고 배열에 포함될 수 있는 총 요소수 이다.
- 요소를 추가하다가 배열의 capacity를 초과하게 되면 배열은 더 큰 메모리를 할당하여 새 공간에 요소들을 복사한다.
- 이 때 할당되는 새로운 배열의 용량은 기존 크기의 배수이다.
- 요소를 많이 추가하게 될 수록, 점점 재할당 발생 빈도가 낮아지게 된다.

```swift
var numbers = [1,2,3,4]
print(numbers.count)    // 4
print(numbers.capacity) // 4

numbers.append(5)
print(numbers.count)    // 5
print(numbers.capacity) // 8

```
- 만약 배열에 요소가 얼마나 저장될 지 대략 예상할 수 있으면 미리 capacity를 설정하여 재할당을 방지할 수 있다.
- capacity를 설정하는 방법은 reserveCapacity(_:)를 사용하면 된다.

```swift
numbers.reverseCapacity(10) 
print(numbers.capacity) // 10
```

---
## 빈 배열 여부
- 빈 배열인지 알고 싶으면 count를 사용하여 요소의 개수가 0개인지 판단하면 된다.
```swift
var empty = [Int]()
print(empty.count == 0) //true
```
- 요소의 개수가 아니라 단순히 빈 배열인지만 알고싶으면, isEmpty를 사용하면 된다.
```swift
var empty = [Int]()
print(empty.isEmpty) //true
```
---
12. 배열 뒤집기
- 기존 배열의 순서를 거꾸로 뒤집는 방법으로는 reverse()를 사용하면 된다.
```swift
var array = [1,3,5,2,4,6]
array.reverse()
print(array) // [6, 4, 2, 5, 3, 1]
```

- reserved()는 기존 배열은 그대로 두고 순서가 뒤집어진 새로운 배열을 리턴한다.
```swift
var array = [1,3,5,2,4,6]
array.reversed() // [6, 4, 2, 5, 3, 1]
print(array) // [1, 3, 5, 2, 4, 6]
```

- 빠른 수행시간을 위해 reserved()를 사용하는걸 추천한다.

---
## 배열 정렬하기
- 정렬을 하기 위해서는 요소가 Comparable 프로토콜을 준수하고 있는 타입이어야 한다.
- Comparable은 비교연산자(<)에 대한 오버로딩이 구현되어야 하기 때문에 값의 대소 비교가 가능해진다.
- Swift에서 기본 제공하는 숫자 타입이나 String 타입은 모두 Comparable을 준수하고 있고, 커스텀 객체라도 Comparable을 준수하도록 구현하면 sort() 메소드를 사용할 수 있다.

- 배열을 오름 차순으로 정렬하고 싶으면 sort()를 사용한다. 기존 배열 자체의 순서를 정렬하게 된다.
```swift
var array = [1,3,5,2,4,6]
array.sort()
print(array) // [1, 2, 3, 4, 5, 6]
```
- 내림 차순으로 정렬하고 싶을땐, sort()와 reverse()를 함께 사용하거나 sort(by:>)를 사용하면 된다.
```swift
var array = [1,3,5,2,4,6]
array.sort()
array.reverse()
print(array) // [6, 5, 4, 3, 2, 1]

var array = [1,3,5,2,4,6]
array.sort(by: >)
print(array) // [6, 5, 4, 3, 2, 1]
```
- sort()는 기존 배열은 그대로 두고 정렬된 새로운 배열을 리턴한다.
- 오름차순 정렬은 sorted(), 또는 sorted(by:<), 내림차순정렬은 sorted(by:>)

```swift
var array = [1,3,5,2,4,6]
array.sorted() //  [1, 2, 3, 4, 5, 6]
print(array) // [1, 3, 5, 2, 4, 6]

var array = [1,3,5,2,4,6]
array.sorted(by: >) // [6, 5, 4, 3, 2, 1]
print(array) // [1, 3, 5, 2, 4, 6]
```
---
## 최대 최소값 찾기
- max(), min()메소드를 활용하여 최대, 최소값을 찾을 수 있다.
	
    - 반환값은 Optional이므로 Unwrapping해서 사용하면 된다.
- comparable 프로토콜을 준수하지 않는 요소일 경우 컴파일 에러를 발생하며, 빈 배열에서 사용하면 nil을 반환한다.

```swift
var numbers = [1,2,3]
print(numbers.min()) // Optional(1)
print(numbers.max()) // Optional(3)

var numbers = [Int]()
print(numbers.min()) // nil
print(numbers.max()) // nil

var objects = [CustomClass]()
print(objects.min()) // [!] Compile Error
print(objects.max()) // [!] Compile Error
```
---
## 인덱스 관련
- 배열의 첫번째 인덱스는 0, 마지막 인덱스는 count-1과 같다.
- startIndex, endIndex를 사용하여 구할 수도 있다.
	
	
    - startIndex는 항상 0이고, endIndex는 count값과 같다.
    
```swift
var numbers = [1,2,3,4,5]
print(numbers.startIndex) // 0
print(numbers.endIndex) // 5

var numbers = []
print(numbers.startIndex) // 0
print(numbers.endIndex) // 0
```

- 부분 배열의 범위를 지정할 때 유용하게 사용 가능하다.
```swift
let numbers = [10, 20, 30, 40, 50]
if let i = numbers.firstIndex(of: 30) {
    print(numbers[i ..< numbers.endIndex]) // [30, 40, 50]
}
```

- index(after:), index(before:)를 활용할 수도 있다.
```swift
var numbers = [1,2,3,4,5]

print(numbers[numbers.startIndex]) // 1 - 첫번째 값
print(numbers[numbers.index(after: numbers.startIndex]) // 2 - 2번째 값
print(numbers[numbers.index(before: numbers.endIndex]) // 5 - 마지막 값
print(nubmers[numbers.endIndex]) // [!] Runtime Error - Index out of range
```
---
## 첫번째, 마지막 값 찾기
- array[0], array[array.count-1]을 사용하거나, numbers[numbers.startIndex], numbers[numbers.endIndex]를 사용하는 방법이 있다.
- 하지만 first, last를 사용하면 Optional요소를 반환하며 빈 배열일 경우 nil을 반환한다.
	
    - Index out of range 에러를 발생시키지 않고 안전하게 찾을 수 있다.
```swift
var numbers = [1,2,3,4,5]
print(numbers.first) // Optional(1)
print(numbers.first) // Optional(5)

var numbers = [Int]()
print(numbers.first) // nil
print(numbers.last) // nil
```
---