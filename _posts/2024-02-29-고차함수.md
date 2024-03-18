---
title: 고차함수
writer: Harold
date: 2024-02-29
categories: [Deep Dive]
tags: [코딩테스트]

toc: true
toc_sticky: true
---
고차함수 정리.

## map
- 컬렉션 내부의 데이터를 가공하여 새로운 컬렉션을 생성한다.
- map 메서드는 인자로 클로저를 받아 컨테이너 내부에 들어있는 요소들의 값을 어떻게 바꿀 것인지를 결정한다.

- 선언
```swift
func map<T>(_ transform: (Element) throws -> T) rethrows -> [T]
```
	 - 매개변수
     	- transform : 매핑 클로저로, 이 컨테이너의 요소를 매개변수로 받아들이고 정의한 클로저의 형태에 맞게 변환된 값을 반환한다.
     
     - 리턴타입 : 이 컨테이너의 변환된 요소를 포함하는 배열을 반환.
     
- 예시 (For문을 사용했을 때)

```swift
// numbers의 각 요소에 9 곱하기

let Numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var multiplyArray: [Int] = []

for number in Numbers {
    multiplyArray.append(number * 9)
}

print(multiplyArray)
// [9, 18, 27, 36, 45, 54, 63, 72, 81]
```


- 예시 (map을 사용했을 때)

```swift
// numbers의 각 요소에 9 곱하기
let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
let multiplyArray: [Int] = numbers.map { $0 * 9 }

print(multiplyArray)
// [9, 18, 27, 36, 45, 54, 63, 72, 81]
```

## reduce
- 컬렉션 내부에서 조건에 맞는 데이터들만 골라 새로운 컬렉션을 생성한다.
- filter 메서드는 클로저를 인자로 받고, 이 클로저 내부에는 어떤 데이터를 포함시킬지 그 조건을 정의한다.

- 선언 
```swift

func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) rethrows -> Result
```
- 매개변수
    - initialResult : 초기값으로 사용할 값을 넣으면 클로저가 처음 실행될 때, nextPartialResult에 전달된다.
    - nextPartialResult : 컨테이너 요소를 새로운 누적값으로 결합하는 클로저이다.
        - 리턴타입 : 최종 누적 값이 반환되며, 컨테이너 요소가 없다면 initialResult의 값이 반환된다.

- 예시 (for문을 사용 했을 때)
```swift
// 각 요소의 합 구하기

let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var sum = 0

for number in numbers {
    sum += number
}

print(sum)
// 55
```

- 예시 (reduce를 사용했을 때)
```swift
// 각 요소의 합 구하기 (1)

let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let sum = numbers.reduce(0, +)

print(sum)
// 55


// 각 요소의 합 구하기 (2)

let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let sum = numbers.reduce(0) { $0 + $1 }

print(sum)
// 55
```

- 예시 (for문을 사용 했을 때)
```swift
// 각 요소의 곱셈 결과 구하기

let numbers = [1, 2, 3, 4, 5]
var sum = 1

for number in numbers {
    sum *= number
}

print(sum)
// 120
```
- 예시 (reduce를 사용했을 때)
```swift
// 각 요소의 곱셈 결과 구하기 (1)

let numbers = [1, 2, 3, 4, 5]
let sum = numbers.reduce(1, *)

print(sum)
// 120


// 각 요소의 곱셈 결과 구하기 (2)

let numbers = [1, 2, 3, 4, 5]
let sum = numbers.reduce(1) { $0 * $1 }

print(sum)
// 120
```
## filter
- 컬렉션 내부의 데이터들을 하나로 통합시킨다
- 다른 고차함수들과는 다르게 reduce는 두 개의 인자를 받는다.
    	
     - 첫번째 인자는 통합할 데이터의 초기 값이다.
     - 두번째 인자는 클로저인데, 클로저에서는 어떻게 값을 통합할 것인지를 정의한다.
     - 이때 사용되는 두 파라미터 중 첫번째는 바로 이전값에 대한 통합된 데이터를 의미하고, 두번째는 이번에 새로 통합할 데이터를 의미한다.
 
- 선언
```swift
func filter(_ isIncluded: (Self.Element) throws -> Bool) rethrows -> [Self.Element]
```

- 매개변수
	- isIncluded : 컨테이너의 요소를 인수로 취하고, 요소가 반환된 배열에 포함되어야 하는지 여부를 Bool 값으로 반환하는 클로저.
        
    - 리턴 타입 : inIncluded 에 맞게 true로 반환되는 값만 리턴한다.
- 예시 (일반적인 For문을 사용 했을 때)
```swift
// numbers에서 짝수만 추출하기

let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
var evenNumbers: [Int] = []

for number in numbers {
    if number % 2 == 0 {
        evenNumbers.append(number)
    }
}

print(evenNumbers)
// [2, 4, 6, 8]
```

- 예시 (filter를 사용했을 때)
```swift
// numbers에서 짝수만 추출하기

let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
let evenNumbers = numbers.filter { $0 % 2 == 0 }

print(evenNumbers)
// [2, 4, 6, 8]
```
---

# 다른 고차함수들

## CompactMap
- 옵셔널 바인딩을 지원한다.
    
- 예시
```swift
let students : [String?] = ["Mike", "Jane", nil, "John", nil]
// nil이 섞여 있는 컬렉션에서 존재하는 모든 이름앞에 "Boost2021-" 키워드를 붙여주자.

// 1. map을 이용한 코드
let boostStudents = students.map({"BoostCamp2021" + $0})
// 에러가 발생한다 nil이 있기 때문.


// 2. compactMap을 이용한 코드
let students : [String?] = ["Mike", "Jane", nil, "John", nil]
let boostStudents = students.compactMap({ $0 }).map( {"BoostCamp2021-" + $0})
 
print(boostStudents) // ["BoostCamp2021-Mike", "BoostCamp2021-Jane", "BoostCamp2021-John"
```
## FlatMap
	- 2차원 배열에 나누어져있는 데이터들을 1차원 배열로 합쳐주는 기능이 포함되어있다.
예시
```swift
let students = [["Mike", nil], [nil, nil, "Jane"], ["John"]]
// 먼저 위와 같은 배열을 1차원으로 만들때 사용한다.

let goodStudents = students.flatMap({$0})
print(goodStudents) // [Optional("Mike"), nil, nil, nil, Optional("Jane"), Optional("John")]

//아직은 옵셔널 바인딩이 안되어 있고 nil이 포함되어 있습니다. 이때 실제 이름 값만 추출하고 싶다면 위의 compactmap을 추가로 쓸 수 있다.

let goodStudents = students.flatMap({$0}).compactMap({ $0 })
print(goodStudents) // ["Mike", "Jane", "John"]


```

## ForEach
- for - in 구문처럼 컬렉션의 각 요소들을 뽑아낼 수 있다.
- for - in 과는 다르게 고차함수에 포함되어 있기에 글로벌 스코프에서 사용했을 때도 return을 통해 현재 반복을 종료하고 다음 반복으로 이어나갈 수 있다 (continue와 비슷하게 동작)
- 다른 고차함수처럼 새로운 컬렉션이나 데이터를 반환하지 않기 때문에 단순한 순회의 용도로 사용하기에 적합하다.
    
- 예시

```swift
let numbers = [1, 2, 3, 4, 5]
numbers.forEach({
    print($0)
})
 
//1
//2
//3
//4
//5
```