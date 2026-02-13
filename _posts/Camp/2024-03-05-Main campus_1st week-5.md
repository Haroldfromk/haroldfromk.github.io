---
title: 1주차 (5)
writer: Harold
date: 2024-03-05 04:11:00 +0800
categories: [캠프, 1주차]
tags: [옵셔널]

toc: true
toc_sticky: true
---
# Optional
## 1. Optional과 nil
![](https://i.esdrop.com/d/f/E8Nib9NqGY/dhmGpzLOjA.png)
### 1. Optional
- 값이 없을 수 있는 상황에서 Optional을 사용한다.
- 옵셔널은 ? 로 나타낸다.
- 다음 두 가지 가능성을 나타낸다.
    - 값이 있고 옵셔널로 래핑해놓은 값을 언래핑 하여 해다 ㅇ값에 엑세스 할 수 있다.
    - 값이 전혀 없다.
- 옵셔널 타입끼리의 연산은 불가능하다.

```swift
// 축약 타입 표현
var serverResponseCode: Int? = 404 
// 정식 타입 표현
var myPetName: Optional<String> = "멍멍이"

func pay(with card: String?) {
   // 구현 코드
}

// 옵셔널 타입끼리의 연산은 불가능
var num1: Int? = 4
var num2: Int? = 2

num1 + num2 // 에러 발생!

let optionalString1: String? = "Hello, "
let optionalString2: String? = "world!"

// 옵셔널 String 값들을 연결하려는 시도
let result = optionalString1 + optionalString2 // 에러 발생!
```
 
- 참고 자료
<https://developer.apple.com/documentation/swift/optional/>
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals>

### 2. nil
- 변수에 nil을 할당함으로써 값이 없는 상태의 옵셔널 프로퍼티를 만들 수 있다.

```swift
var serverResponseCode: Int? = 404
serverResponseCode = nil

var surveyAnswer: String?
// surveyAnswer 는 자동으로 nil 로 설정된다.
```

- 참고 자료
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#nil>

## 2. Optional Binding
- 옵셔널 값이 빈값인지(nil) 존재하는지 검사한 후, 존재하는 경우 그 값은 다른 변수에 대입시켜 바인딩함.
- 빈 값을 체크하고 옵셔널 값을 언래핑 해주는 것이 강제로 언래핑(!) 하는 것보다 훨씬 안전하다.
- `if let` , `if var`, `guard let`, `guard var` 를 사용하여 옵셔널 값을 추출해 새로운 변수에 바인딩 한다.
    - `if let` vs `guard let`
        - `if let`은 if문의 코드 구현부 내 (`{ code }`)에서만 사용 가능하다. (지역변수)
        - `guard let`은 guard문을 통과한 상수를 guard문 밖에서도 사용이 가능하다. (전역변수)

```swift
if let <#상수 이름#> = <#옵셔널 값#> {
   // 구현 코드
}


let roommateNumbers: Int? = nil
if let roommates = roommateNumbers {
    print (roommates)
}
// 출력값 없음

let ticketCounts: Int? = 3
if let ticket = ticketCounts {
    print (ticket)
}
// 출력값: 3


// 옵셔널 바인딩 할 변수가 여러 개인 경우
let boyName : String?
let girlName : String?

boyName = "하늘"
girlName = "나연"

// , 콤마로 나열한다
if let boy = boyName,
   let girl = girlName {
    print(boy, girl)
}
// 출력값: 하늘 나연

let x : Int? = 10
let y : Int? = nil

func opbinding() {
    guard let x = x else { return }
    print(x)

    guard let y = y else { return } // y는 nil 이므로 여기서 return 
    print(y) // 위에서 return 하였기 때문에 이 코드 라인은 실행되지 않음
}

opbinding()
// 출력값: 10
```

## 3. Optional Force Unwrapping
- 강제 언래핑은 !를 사용하여 강제로 옵셔널을 추출한다.
    - 다만 변수 앞에 !를 붙이는건 not 의미이다.
- 강제 언래핑을 잘못 사용할 경우 프로그램이 비정상적으로 종료될 수도 있으므로 반드시 nil이 아닌 것이 확실한 상황에서 사용해야한다.
    - 가급적이면 사용하지 않는것이 좋다.

```swift
let number = Int("42")!
// String값을 Int로 변환하는 함수는 return값으로 옵셔널 값을 반환한다.
print(number)
// 출력값: 42

// 강제 언래핑이 실패한 경우
let address: String? = nil
print(address!)
// 에러🚨 메시지: Unexpectedly found nil while unwrapping an Optional value
```

## 4. Nil Coalescing Operator
- 값이 nil일 경우를 위해 기본값을 설정 할 수있따(nil-coalescing)
    - ?? 을 사용하여 기본 값을 사용할 수 있는데, ??을 사용하여 기본값을 부여한 변수는 **옵셔널 타입이 아니다**
    - `let(var) a = b ?? c` 형태로 이루어진다
        - b가 nil일 경우 a에 c가 대입된다.
        - b가 nil이 아닐경우엔 a에 옵셔널을 제거한 값이 대입된다.
        - b → Optional Type
        - c → Optional Type (X)

```swift
var optNumber: Int? = 3
let number = optNumber ?? 5
print(number) // 출력값 : 3
//number는 Int? 타입이 아니라 Int 타입

optNumber = nil
let number2 = optNumber ?? 5
print(number) // 출력값 : 5
//number는 Int? 타입이 아니라 Int 타입

print(heartPath)
// imagePaths["heart"]가 nil일 때 
// 출력값: "/images/default.png"
```

## 5. Optional Chaining
- 옵셔널을 연쇄적으로 사용하는 것을 말한다.
- `.`을 통해 내부 프로퍼티나 메서드에 연속적으로 접근할 때 옵셔널 값이 있으면 옵셔널 체이닝으로 접근할 수 있다.

```swift
struct Person {
	var name: String
	var address: Address
}

struct Address {
	var city: String
	var street: String
	var detail: String
}

let sam: Person? = Person(name: "Sam", address: Address(city: "서울", street: "신논현로", detail: "100"))
print(sam.address.city) // 에러 🚨. 에러 메시지: Chain the optional using '?' to access member 'address' only for non-'nil' base values
sam?.address.city  // ✅
// 출력값: 서울
```

- 참고 자료
<https://developer.apple.com/documentation/swift/optional/>
<https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/#Optionals>