---
title: 1주차 (7)
writer: Harold
date: 2024-03-06 00:11:00 +0800
categories: [캠프, 1주차]
tags: [배열]

toc: true
toc_sticky: true
---

# 1. 배열 (Array)
- 배열은 동일한 타입의 요소를 저장하는 순서가 있는 컬렉션이다.
- Index는 1부터가 아닌 **0부터 시작**한다.
- 처음에 배열의 길이를 미리 정하지 않아도 된다.

## 1. 관련 메서드
### 1. 배열 갯수 확인 : array.count
``` swift
var array1 = [1, 2, 3]
array1.count // 1
```

### 2. 배열 요소 추가
#### 1. array.append 
```swift
// append : 배열의 마지막에 추가
var array1 = [1, 2, 3]
array1.append(4)                            // [1, 2, 3, 4]
// 여러값을 한번에 추가할 때
array1.append(contentsOf: [5, 6, 7])        // [1, 2, 3, 4, 5, 6, 7] 
```

#### 2. array.insert
```swift
// insert : 배열의 중간에 추가
var array2 = [1, 2, 3]
array2.insert(0, at: 0)                      // [0, 1, 2, 3]
array2.insert(contentsOf: [10, 100], at: 2)  // [0, 1, 10, 100, 2, 3 ]
```

### 3. 배열 값 변경
#### 1. Subscript로 변경
```swift
var array1 = [1, 2, 3]
// 0 번째 인덱스의 값을 10으로 ㅂ꾸기
array1[0] = 10                       // [10, 2, 3]
// 0~2 번째 인덱스의 값을 순서대로 10,20,30으로 바꾸기
array1[0...2] = [10, 20, 30]         // [10, 20, 30]
// 0~2번째 인덱스의 값을 0으로 바꾸기, 즉 1,2번째 값에 대한 내용이 없으므로 빈배열로 처리가 되어 [0] 만 남게 된다.
array1[0...2] = [0]                  // [0]
// 0번째 인덱스의 값을 빈배열로 만들기
array1[0..<1] = []                   // []
```

#### 2. replaceSubrange
``` swift
array2.replaceSubrange(0...2, with: [10, 20, 30])     // [10, 20, 30]
array2.replaceSubrange(0...2, with: [0])              // [0]
array2.replaceSubrange(0..<1, with: [])               // []
```

### 4. 배열 값 삭제
#### 1. 일반적인 삭제
```swift
var array1 = [1, 2, 3, 4, 5, 6, 7, 8, 9]

// 2번째 인덱스 삭제 
array1.remove(at: 2)             // [1, 2, 4, 5, 6, 7, 8, 9]
// 첫번째 삭제하기 : removeFirst()
array1.removeFirst()             // [2, 4, 5, 6, 7, 8, 9]
// 첫번째 부터 2개의 값 삭제하기 : removeFirst(2)   
array1.removeFirst(2)            // [5, 6, 7, 8, 9]
// 마지막 삭제하기 : removeLast()
array1.removeLast()              // [5, 6, 7, 8]
// 마지막 삭제하기 : popLast()
array1.popLast()                 // [5, 6, 7] 
// 마지막 2개의 값 삭제하기 : removeLast(2)
array1.removeLast(2)             // [5]
// 전부 삭제하기 : removeAll()
array1.removeAll()               // [] 
```

#### 2. 특정 범위 삭제
```swift
var array2 = [1, 2, 3, 4, 5, 6, 7, 8, 9]
 
// Index로 1~3번까지의 인덱스 삭제 : removeSubrange(1...3) 
array2.removeSubrange(1...3)     // [1, 5, 6, 7, 8, 9] 
// 0~1 index를 [] 빈배열로 처리 함으로써 값 삭제하기
array2[0..<2] = []               // [6, 7, 8, 9]
```

### 5. 배열 비교하기
```swift
var array1 = [1, 2, 3]
var array2 = [1, 2, 3]
var array3 = [1, 2, 3, 4, 5,]
 
array1 == array2                    //true
// 모든 요소가 같은 값인지? : elementsEqual(Array)
array1.elementsEqual(array3)        //false
```

### 6. 배열 정렬하기
```swift
let array1 = [1, 5, 3, 8, 6, 10, 14]
 
// sort : 배열을 직접 "오름차순"으로 정렬
array1.sort()
// [1, 3, 5, 6, 8, 10, 14]
 
// 1-1. sort + 클로저 : 배열을 직접 "내림차순"으로 정렬
array1.sort(by: >) 
// [14, 10, 8, 6, 5, 3, 1]
 
 
// 2. sorted : 원본은 그대로 두고, "오름차순"으로 정렬된 새로운 배열을 만들어 리턴
let sortedArray = array1.sorted() 
// [1, 3, 5, 6, 8, 10, 14]
 
// 2-1. sorted + 클로저 : 원본은 그대로 두고, "내림차순"으로 정렬된 새로운 배열을 만들어 리턴
let sortedArray2 = array1.sorted(by: >)
// [14, 10, 8, 6, 5, 3, 1]
```

# 2. 세트 (Set)
- 집합이다.
- 순서는 상관이 없고, 같은 타입의 값만 저장을 한다.
- 모든 값은 고유해야 하므로 중복을 허용하지 않는다.

## 1. 자주 사용하는 메서드
### 1. 값 추가
```swift
var letters = Set<String>()
// 값 넣기 : insert 
// 배열은 append 였으나 set는 다르다!
letters.insert("Classical Music")
```

### 2. 값 업데이트
```swift
// update : 삽입, 교체, 추가
var set1: Set<Int> = [1,1,2,2,3,3]
set1.update(with: 1) // 1 -> 기존에 있던 요소이므로 값을 옵셔널 타입으로 리턴
set1.update(with: 7) // nil -> 기존에 없던 요소이므로 Set에 요소가 추가되고 nil 리턴

set1.remove(1) // 1 -> 삭제된 요소를 리턴
set1 // [2,3,7]

set1.remove(5) // nil -> 존재하지 않는 요소를 삭제했을 때 에러는 발생하지 않고 nil 리턴

// 전체요소 삭제
set1.removeAll()
set1.removeAll(keepingCapacity: true) // 요소는 제거하지만 메모리는 제거하지 않는다
```

### 3. 집합
```swift
let oddDigits: Set = [1, 3, 5, 7, 9]
let evenDigits: Set = [0, 2, 4, 6, 8]
let singleDigitPrimeNumbers: Set = [2, 3, 5, 7]

// 합집합
oddDigits.union(evenDigits).sorted()
// [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

// 교집합
oddDigits.intersection(evenDigits).sorted()
// []

// 차집합
oddDigits.subtracting(singleDigitPrimeNumbers).sorted()
// [1, 9]

// 대칭 차집합
oddDigits.symmetricDifference(singleDigitPrimeNumbers).sorted()
// [1, 2, 9]
```

# 3. 딕셔너리 (Dictionary)
- 사전을 생각하면 된다.
- 순서는 상관 없고 key, value로 되어있다.
    - key는 중복이 불가능
    - 모든 key는 동일한 타입이어야 한다.
    - 모든 value 역시 동일한 타입이어야 한다.

## 1. 자주 사용하는 메서드
```swift
var namesOfIntegers: [Int: String] = [:]

namesOfIntegers[16] = "sixteen" // 16은 subscript가 아니라 "키"임

// 초기화
namesOfIntegers = [:]

var airports: [String: String] = ["YYZ": "Toronto Pearson", "DUB": "Dublin"]

airports.keys // ["YYZ", "DUB"]
airports.values // ["Toronto Pearson", "Dublin"]

airports.keys.sorted() // ["DUB", "YYZ"]
airports.values.sorted() // ["Dublin", "Toronto Pearson"]

airports["APL"] = "Apple International"
// airports = ["YYZ": "Toronto Pearson", "DUB": "Dublin", "APL": "Apple International"]

// key에 매칭된 value 값 초기화
airports["APL"] = nil

// 딕셔너리 airports에 있는 값의 수
print(airports.count)
// 출력값: 2

// 딕셔너리 airports에 있는 모든 key들
print(airports.keys)
// ["YYZ", "DUB"]

// 해당 key가 있다면 value를 덮어쓰고, 덮어쓰기 전 기존값울 반환
// 즉 updateValue를 하게 되면 새로 생성 한변수에 기존에 있던 "Toronto Pearson"이 들어가게 되고,
// 딕셔너리에는 ["YYZ" : "Hello YYZ"] 이렇게 바뀐다.
// 다만 타입은 옵셔널로 바뀌는게, 값이 있을수도, 없을수도 있기 때문이다.
let newYyz = airports.updateValue("Hello YYZ", forKey: "YYZ") 
           
print(newYyz) // 출력값: Optional("Toronto Pearson")
print(airports["YYZ"]) // 출력값: Optional("Hello YYZ")

// 해당 key가 없다면 그 key에 해당하는 value에 값을 추가하고 nil을 반환
let newApl = airports.updateValue("Hello APL", forKey: "APL") 

print(newApl) // 출력값: nil
print(airports["APL"]) // 출력값: Optional("Hello APL")
```