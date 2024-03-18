---
title: 1주차 (4)
writer: Harold
date: 2024-03-05 03:11:00 +0800
categories: [캠프, 1주차]
tags: [연산자와반복문]

toc: true
toc_sticky: true
---

## 연산자

### 1. 산술 연산자
1. 덧셈
    - `+`
    - +=

2. 뺄셈
    - `-`
    - +=

3. 곱셈
    - `*`

4. 나눗셈
    - /

5. 나머지 
    - %

```swift
var result = 1 + 2
print(result)
// 출력값: 3

result += 5
// result = result + 5
print(result)
// 출력값: 8

result = 10 - 6
print(result)
// 출력값: 4

result -= 3
// result = result - 3
print(result)
// 출력값: 1

result = 8 * 2
print(result)
// 출력값: 16

result = 12 / 5
print(result)
// 출력값: 2
result = 10 % 3
print(result)
// 출력값: 1
// result는 10을 3으로 나눈 후 나머지 이므로 1
```

### 2. 비교 연산자
- 비교한 값을 true or false로 반환한다.

1. 같다 / 같지 않다
    - a == b
    - a != b

2. 크다 / 작다
    - a > b
    - a < b

3. 크거나 같다 / 작거나 같다
    - a >= b
    - a <= b

```swift
var result = (1 == 2)
print(result)
// 출력값: false

result = (1 != 2)
print(result)
// 출력값: true

result = (1 > 2)
print(result)
// 출력값: false

result = (1 < 2)
print(result)
// 출력값: true

result = (1 >= 2)
print(result)
// 출력값: false

result = (2 <= 2)
print(result)
// 출력값: true

```

### 3. 논리 연산자
- 비교한 값을 true or false로 반환한다.

1. 논리 부정 NOT
    - !a
        - true라면 false를 return
        - false라면 true를 return

2. 논리 곱 AND
    - a&&b
        - 두 값이 모두 true일때 true를 리턴
        - 두 값중 하나라도 false이면 false를 리턴

3. 논리 합 OR
    - a||b
        - 둘 중 하나라도 true면 true를 리턴

```swift
var allowedEntry = false
allowedEntry = !allowedEntry
print(allowedEntry)
// 출력값: true

let enteredDoorCode = true
let passedRetinaScan = false
let permittedAccess = enteredDoorCode && passedRetinaScan
print(permittedAccess)
// 출력값: false

let enter = allowedEntry || permittedAccess
print(enter)
// 출력값: true
```

### 4. 범위 연산자

1. (a...b)
    - a 이상 b 이하

2. (a..<b)
    - a 이상 b 미만

3. a... ...a
    - 범위의 시작 또는 끝만 지정하여 사용
    - a는 포함시킨다.

```swift
(1...5)
// 1, 2, 3, 4, 5

(1..<5)
// 1, 2, 3, 4

(3...)
// 3, 4, 5, 6, 7 ...

let names = ["안나", "알렉스", "오드리", "잭"]

for name in names[2...] {
    print(name)
}
// 출력값: 
// 오드리
// 잭

for name in names[...2] {
    print(name)
}
// 출력값: 
// 안나
// 알렉스
// 오드리

for name in names[..<2] {
    print(name)
}
// 출력값: 
// 안나
// 알렉스
```

### 5. 삼항 연산자
- a ? n : c
    - question ? answer1 : answer2
    - question의 답이 true이면 answer1, false이면 answer2
    - if-else문의 간략화한 버전

```swift
let height = 150
var nickname = (height > 185) ? "Daddy Long Legs" : "TomTom"
print(nickname)
// 출력값: TomTom

// 이를 if-else 문으로 표현하면
var nickname2 = ""
if height > 185 {
	nickname = "Daddy Long Legs"
} else {
	nickname = "TomTom"
}

```

### 6. 주의 사항
- ※ Swift는 띄어쓰기도 신경써야 하는 언어이다.

예를들어
`a - b` 와 `a -b`는 완전히 다른 의미 
`a - b`는 a에서 b를 빼는 수식이고 `a -b` 는 a와 -b를 의미

- 참고 자료
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/basicoperators>

## 조건문

### 1. if 문
- 조건을 확인하는 문법
- if문에 작성한 조건이 true일때만 구현 부 코드를 실행

```swift
// if 뒤 "조건"은 Bool 타입 즉 true 혹은 false 이어야 한다
if <#조건#> {
  // 구현부 코드
}

var temperature = 17
if temperature <= 13 {
    print("쌀쌀한 날씨가 지속되겠습니다.")
} else if temperature >= 22 {
    print("해가 떠오르는 낮부터는 더위 예상됩니다.")
} else {
    print("밤낮으로 선선한 날씨가 예상됩니다.")
}
// 출력값: 밤낮으로 선선한 날씨가 예상됩니다.

if true {
		print("항상 실행됩니다")
}
// 출력값: 항상 실행됩니다

if false {
		print("항상 실행됩니다")
}
// 출력값: (없음) - if 뒤 조건문이 false이므로 중괄호 내부 코드가 실행되지 않음 

```

### 2. Swift - case 문
- switch 문은 가능한 여러 개의 일치하는 케이스와 값을 비교한다. 그런 다음 일치하는 첫 번째 케이스를 기반으로 구현부 코드 블록을 실행한다.
- switch 문은 여러 잠재적 케이스에 대응하기 위해 if 문을 대신 사용할 수 있다.
- 열거형(enum)과 함께 자주 사용된다.
- 모든 케이스가 적용되지 않는 경우 `default` 에 구현된 코드가 실행되며, `default`는 항상 마지막에 표시되어야 한다.
- 특정 케이스에 실행 구문이 없을 경우  `break` 키워드를 반드시 사용해야 한다.
- 특정 케이스에 해당되어 실행 구문이 실행된 이후에 다음 케이스 블럭을 실행하려면 `fallthrough` 키워드를 사용한다.

```swift
if <#조건#> {
  // 구현부 코드
}
switch <#조건#> {
case <#값 1#>:
    // 구현부 코드
case <#값 2#>,
    <#값 3#>:
    // 구현부 코드
default:
    // 모든 케이스가 적용되지 않는 경우
    // 구현부 코드
}



let cookieCount = 62
let message: String
switch cookieCount {
case 0:
    message = "🍪 없음 🙅‍♂️"
case 1..<5:
    message = "🍪 아주 조금 있음"
case 5..<12:
    message = "🍪 조금 있음"
case 12..<100:
    message = "🍪 꽤 있음 🍪"
case 100..<1000:
    message = "🍪🍪 많음 🍪🍪"
default:
    message = "🍪🍪🍪엄청 많음🍪🍪🍪"
}
print(message)
// 출력값: "🍪 꽤 있음 🍪"



let species = "시츄"

switch species {
case "말티즈" :
	print("말티즈입니다")
case "시츄":
	break // 실행 구문이 없을때는 반드시 break를 써주어야 함
default: 
	print("강아지입니다")
}



var number = 5

switch number {
case ..<5:
    print("under 5")        
    fallthrough
case 5:
    print("5")
    fallthrough // 해당 케이스의 구문이 실행된 이후에도 무조건 다음블럭을 실행함
default:
    print("default")
}
// 출력 결과 
// 5
// default

// default를 사용하지 않는 예시
enum Day { //switch - case와 좋은 콤비 
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

func activities(for day: Day) {
    switch day {
    case .monday:
        print("월요일: 회사 회의")
    case .tuesday:
        print("화요일: 운동 가기")
    case .wednesday:
        print("수요일: 책 읽기")
    case .thursday:
        print("목요일: 친구와 만나기")
    case .friday:
        print("금요일: 영화 보기")
    case .saturday:
        print("토요일: 쇼핑하기")
    case .sunday:
        print("일요일: 가족과 시간 보내기")
    }
}

activities(for: .monday)
activities(for: .friday)
```

- 참고 자료
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow#Conditional-Statements>

## 반복문

### 1. for 문
    - 순회 할 수 있는 타입(배열, 딕셔너리 등)을 순회 하거나 특정 횟수만큼 로직을 반복할 때 주로 사용

```swift
for 각 value의 변수 이름 in 순회할 수 있는 타입 {
     // 내부 로직
}

let alphabets: [String] = ["a", "b", "c", "d"]

for character in alphabet {
  print(character)
}

// 출력값: 
// a
// b
// c
// d

let students = ["Tom": 2, "Harry": 4, "Sarah": 1]

for (name, grade) in students {
  print("\(name) 은 \(grade) 학년이야")
}

// 출력값: 
// Tom 은 2 학년이야
// Harry 은 4 학년이야
// Sarah 은 1 학년이야

```

### 2. while 문
- while문은 **특정 조건이 만족하는 동안** 내부로직을 계속해서 실행한다.
- 종결 조건을 정해주지 않으면 무한루프가 생길 위험성이 있다.
- while문은 반복문의 각 패스가 시작할 때 조건을 평가한다.

```swift
// while 뒤의 "조건"은 Bool 타입, 즉 true 혹은 false이고, true일때 중괄호 내부 코드 실행
while <#조건#> {
   // 구현 코드
}

let lastName : [String] = ["송", "김", "박", "정" ]

var index : Int = 0
while index < 4 {
    print("옆집 \(lastName[index]) 씨네 \(index)번째 결혼식")
    index += 1
}
// 출력값:
// 옆집 송 씨네 0번째 결혼식
// 옆집 김 씨네 1번째 결혼식
// 옆집 박 씨네 2번째 결혼식
// 옆집 정 씨네 3번째 결혼식

while true {
		print("Hello") // Hello 가 계속 출력됨
}
```

- 참고 자료
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/controlflow>