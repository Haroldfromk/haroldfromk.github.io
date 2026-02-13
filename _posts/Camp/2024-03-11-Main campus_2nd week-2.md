---
title: 2주차 (2)
writer: Harold
date: 2024-03-11 01:11:00 +0800
categories: [캠프, 2주차]
tags: []

toc: true
toc_sticky: true
---

## 타입 캐스팅

### 1. is 
- is 연산자는 타입을 체크하는 연산자로, 비교 결과를 bool 타입을 반환 (타입 체킹)

```swift
let char: Character = "A"
 
print(char is Character)
// 출력값: true
print(char is String)   
// 출력값: false
 
let bool: Bool = true

print(bool is Bool)     
// 출력값: true
print(bool is Character)
// 출력값: false
```

### 2. as, as!, as?

#### 1. `as`
- as 연산자는 컴파일 단계에서 캐스팅이 실행됩니다. 따라서 항상 타입 캐스팅이 성공할 경우에만 사용할 수 있습니다.
- 캐스팅에 실패할 경우 에러가 발생합니다.
- 캐스팅하려는 타입이 같은 타입 이거나 수퍼클래스 타입이라는 것을 알 때 `as` 연사자를 사용합니다.
#### 2.`as?`
- as? 연산자는 런타임에 캐스팅이 실행됩니다.
- 성공하면 옵셔널 타입의 인스턴스를 반환하고 실패하면 *nil* 을 반환합니다.
- 실패할 가능성이 있으면 as?를 사용하는 것이 좋습니다.
#### 3. `as!`
- as! 연산자는 런타임에 특정 타입으로 강제 캐스팅합니다.
- 강제 타입 캐스팅에 실패할 경우 런타임 에러가 발생할 수 있습니다.
- 캐스팅에 성공한 경우 인스턴스를 반환합니다.(옵셔널 x)

```swift
class Person {
    var id = 0
    var name = "name"
    var email = "hgk@gmail.com"
}

class Worker: Person {
    // id
    // name
    // email
    var salary = 300
}

class Programmer: Worker {
    // id
    // name
    // email
    // salary
    var lang = "Swift"
}


// 업캐스팅 - as
let person1 = Person()
let worker1 = Worker()
let programmer1 = Programmer()

let personList = [person1, worker1, programmer1] // 타입을 선언하지 않았지만 Person 타입으로 인식 -> 즉 업캐스팅이 되었음
personList[1].name
//personList[1].salary // Person 타입으로 보고 있기 때문에 salary에 접근하지 못함

let worker2 = Worker()
worker2.salary

let workerPerson = worker2 as Person
// workerPerson.salary // Person 타입으로 보고 있기 때문에 salary에 접근하지 못함
// Worker클래스를 인스턴스화 하였어도, as를 통해 업캐스팅을 했으므로 Person이다.

print(type(of:workerPerson)) // Worker
// 타입을 출력하게되면 Worker로 나오긴 하므로 주의하자.

// 다운캐스팅 - as? / as!
// as?
let pro = programmer1 as? Programmer // 타입 변환이 될 수도 있고 안될 수도 있기 때문에 옵셔널을 리턴

if let person2 = programmer1 as? Programmer {
    person2.lang
}

if let person3 = worker1 as? Programmer {
    person3.lang 
}

// person3은 현재 더 높은 캐스팅이 되어있는 상태이다. 그러므로 그 하위인 down Casting은 안된다.

// as!
let pro2 = worker2 as! Programmer // Error : 타입 변환 실패시 오류
```