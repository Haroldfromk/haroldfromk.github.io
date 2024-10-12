---
title: 2주차 (4)
writer: Harold
date: 2024-03-12 03:11:00 +0800
categories: [캠프, 2주차]
tags: []

toc: true
toc_sticky: true
---

## 클로저

### 1. 클로저
- 클로저는 이름없는 함수 즉, 코드 블록을 의미한다.
- 클로저는 상수나 변수의 참조를 캡쳐(capture)해 저장할 수 있다
    - 스위프트의 클로저는 주변 환경에 있는 변수나 상수를 캡처하여 저장하고, 이를 나중에 사용할 수 있도록 한다. 이것은 클로저가 생성될 때 클로저가 참조하는 변수 또는 상수의 값에 대한 복사본을 유지하고 저장하는 메커니즘이다
    - **값(value) 캡처**: 클로저가 변수나 상수의 값을 캡처 이때, 클로저 내부에서 캡처한 값이 변경되어도 원본 값은 변경되지 않는다.
    - **참조(reference) 캡처**: 클로저가 변수나 상수의 참조를 캡처. 따라서 클로저 내에서 해당 변수나 상수를 변경하면 원본 값도 변경된다.

```swift
// 값 캡처
func makeIncrementer(forIncrement amount: Int) -> () -> Int {
    var total = 0
    
    // 클로저를 반환합니다.
    let incrementer: () -> Int = {
        // total 변수를 캡처하여 저장합니다.
        total += amount
        return total
    }
    
    return incrementer
}

let incrementByTen = makeIncrementer(forIncrement: 10)

print(incrementByTen()) // total = 10, 결과: 10
print(incrementByTen()) // total = 20, 결과: 20

// 참조 캡처
class SimpleClass {
    var value: Int = 10
}

func createClosure() -> (() -> Int) {
    let instance = SimpleClass()
    
    // 참조 캡처를 사용하여 SimpleClass의 인스턴스를 캡처.
    let closure: () -> Int = {
        // 클로저가 참조하는 인스턴스의 속성을 업데이트.
        instance.value *= 2
        return instance.value
    }
    
    return closure
}

// 클로저 생성
let myClosure = createClosure()

print(myClosure()) // 20
print(myClosure()) // 40

// 클로저 내부에서 참조된 인스턴스의 속성을 변경하였으므로 원본에도 영향을 준다.
```

- 클로저를 사용하는 이유는 ? 가장 일반적으로는 기능을 저장하기 위해 사용한다.
- 클로저는 비동기 처리가 필요할 때 사용할 수 있는 코드 블록이다.(반드시 비동기에만 사용하는 것은 아님)
- 클로저는 클래스와 마찬가지로 참조 타입(reference type)이다.

```swift
{ (parameters) -> return type in
    // 구현 코드
}

// 함수와 클로저 비교
func pay(user: String, amount: Int) {
    // code
}

let payment = { (user: String, amount: Int) in
    // code
}
```

```swift
/// 예시1
// 1) (클로저를 파라미터로 받는 함수)정의

func closureFunc2(closure: () -> ()) {
    print("시작")
    closure()
}

// 파라미터로 사용할 함수/클로저를 정의
func doneFunc() {          // 함수를 정의
    print("종료")
}

let doneClosure = { () -> () in      // 클로저를 정의
    print("종료")
}

// 함수를 파라미터로 넣으면서 실행 (그동안에 배운 형태로 실행한다면)
closureFunc2(closure: doneFunc)

closureFunc2(closure: doneClosure)


// 2) 함수를 실행할때 클로저 형태로 전달 (클로저를 사용하는 이유)
closureFunc2(closure: { () -> () in
    print("프린트 종료")           // 본래 정의된 함수를 실행시키면서, 클로저를 사후적으로 정의 가능
})                              // (활용도가 늘어남)

closureFunc2(closure: { () -> () in
    print("프린트 종료 - 1")
    print("프린트 종료 - 2")
    
})

/// 예시2
// 1) (클로저를 파라미터로 받는 함수)정의
func closureCaseFunction(a: Int, b: Int, closure: (Int) -> Void) {
    let c = a + b
    closure(c)
}

// 2) 함수를 실행할 때 (클로저 형태로 전달)
closureCaseFunction(a: 1, b: 2, closure: { (n) in    // 사후적 정의
    print("plus : \(n)")
})

closureCaseFunction(a: 1, b: 2) {(number) in      // 사후적 정의
    print("result : \(number)")
}

closureCaseFunction(a: 4, b: 3) { (number) in      // 사후적 정의
    print("value : \(number)")
}

/*
 파라미터 생략 등 간소화 문법
 */

// 함수의 정의

func performClosure(param: (String) -> Int) {
    param("Swift")
}

// 문법을 최적화하는 과정
// 1) 타입 추론(Type Inference)
performClosure(param: { (str: String) in
    return str.count
})

performClosure(param: { str in
    return str.count
})

// 2) 한줄인 경우, 리턴을 안 적어도 됨(Implicit Return)
performClosure(param: { str in
    str.count
})

// 3) 아규먼트 이름을 축약(Shorthand Argements)
performClosure(param: {
    $0.count
})

// 4) 트레일링 클로저
performClosure(param: {
    $0.count
})

performClosure() {
    $0.count
}

performClosure { $0.count }

let closureType1 = { (param) in
    return param % 2 == 0
}

let closureType2 = { $0 % 2 == 0 }

// 축약 형태로의 활용
let closureType3 = { (a: Int, b:Int) -> Int in
    return a * b
}

let closureType4: (Int, Int) -> Int = { (a, b) in
    return a * b
}

let closureType5: (Int, Int) -> Int = { $0 * $1 }
```

### 2. 탈출 클로저
- 코드의 순차적 실행과 비동기의 실행 순서

```swift
// 순차적 실행
func sequentialExecutionExample() {
    print("Start")

    // 1. 첫 번째 작업
    for i in 1...3 {
        print("Task \(i)")
    }

    // 2. 두 번째 작업
    print("Next Task")

    // 3. 세 번째 작업
    let result = 5 + 3
    print("Result: \(result)")

    print("End")
}

sequentialExecutionExample()
/*
위의 코드는 함수 sequentialExecutionExample 내에서 순차적으로 실행된다.
각각의 작업은 순서대로 실행되며, 한 작업이 끝나야 다음 작업이 실행된다. 
이 예시에서는 
'Start', 'Task 1', 'Task 2', 'Task 3', 'Next Task', 'Result: 8', 'End'
와 같은 순서로 출력.
*/
​
func asynchronousExecutionExample() {
    print("Start")

    // 1. 비동기로 실행되는 작업
    DispatchQueue.global().async {
        for i in 1...3 {
            print("Async Task \(i)")
        }
    }

    // 2. 순차적으로 실행되는 작업
    print("Next Task")

    // 3. 또 다른 비동기 작업
    DispatchQueue.global().async {
        let result = 5 + 3
        print("Async Result: \(result)")
    }

    // 4. 끝 부분
    print("End")
}

asynchronousExecutionExample()

/*
위의 코드는 비동기적으로 실행되는 예시 
DispatchQueue.global().async를 사용하여 클로저가 다른 스레드에서 비동기적으로 실행된다. 
따라서 비동기 작업은 순차적인 흐름을 방해하지 않고 별도의 스레드에서 실행된다.

실행 결과는 
'Start', 'Next Task', 'End' 순서로 출력되고, 
비동기 작업은 나중에 완료되어 
'Async Task 1', 'Async Task 2', 'Async Task 3', 'Async Result: 8'와 같이 
순서는 보장되지 않는 시점에 출력된다. 
이는 비동기 작업이 별도의 스레드에서 동작하기 때문에, 
주 스레드의 작업과 병행적으로 실행됨을 보여준다.
*/

/* 실제로 해당 코드를 xcode에서 실행을 해보면 
Start
Next Task
End
이렇게 출력이 되고 끝난다. 즉 비동기로 실행되는 작업의 결과가 나타나기전에 해당 함수가 끝이나버리는 경우인것이다.
강의의 내용을 보통 올렸지만 해당코드는 조금 수정을 해서 올려본다.

*/
```

- 이스케이핑 클로저(escaping closure)
    - 1) 어떤 함수의 내부에 존재하는 클로저(함수)를 외부 변수에 저장하는 경우
    - 2) 이스케이핑 클로저는 클로저가 메서드의 인자로 전달됐을 때, 메서드의 실행이 종료된 후 실행되는 클로저(비동기)
    - 이 경우 파라미터 타입 앞에 `@escaping`이라는 키워드를 명시해야 한다.
        - 예를들어, 비동기로 실행되거나 `completionHandler`로 사용되는 클로저의 경우
    - 클로저를 메서드의 파라미터로 넣을 수 있다.

```swift
// 1) 외부 변수 저장
var defaultFunction: () -> () = { print("출력") }

func escapingFunc(closure: @escaping () -> ()) {
		// 클로저를 실행하는 것이 아니라  aSavedFunction 변수에 저장. 
		// 함수는 변수와 달리 기본적으로 외부 할당이 불가능
    defaultFunction = closure        
}

// 2) GCD 비동기 코드
func asyncEscaping(closure: @escaping (String) -> ()) {
    
    var name = "iOS튜터"
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { //3초뒤에 실행하도록 만들기
        closure(name)
    }
}

asyncEscaping { str in
    print("name : \(str)")
}
```
- `@escaping` 를 사용하는 클로저에서 self의 요소를 사용할 경우, self를 명시적으로 언급해야 한다.

```swift
var completionHandlers: [() -> Void] = []
func someFunctionWithEscapingClosure(completionHandler: @escaping () -> Void) {
    completionHandlers.append(completionHandler)
}

func someFunctionWithNonescapingClosure(closure: () -> Void) {
    closure()    // 함수 안에서 끝나는 클로저
}

class SomeClass {
    var x = 10
    func doSomething() {
        someFunctionWithEscapingClosure { self.x = 100 }
        // escaping이 붙은상태에서 self를 붙이지 않으면 에러가 난다. 그러므로 명시적으로 self를 적어줘야 한다.
        someFunctionWithNonescapingClosure { x = 200 }
    }
}

let instance = SomeClass()
instance.doSomething()
print(instance.x)
// Prints "200"

completionHandlers.first?()
print(instance.x)
// Prints "100"

```
## 고차함수

### 1. map
- `map` 함수는 컬렉션 내부의 **기존 데이터를 변형(transform)하여 새로운 컬렉션를 생성**한다.
- 기존의 컬렉션의 요소에 대해 정의한 익명함수로 매핑한 결과를 새로운 컬렉션으로 반환.

```swift
// for 문으로 구현
let num = ["1", "2", "3", "4", "5"]
var numberArray: [Int] = []
for index in num {
    if let changeToInt = Int(index) {
        numberArray.append(changeToInt)
    }
}

print(numberArray)
// [1, 2, 3, 4, 5]

// map으로 구현
let stringArray = ["1", "2", "3", "4", "5"]
numberArray = stringArray.map { 
		if let changeToInt = Int($0) {
				return changeToInt
		}
		return 0
}

/*
$0와 $1
{ } 를 익명함수인 클로저라고 한다.
클로저의 매개변수 이름이 필요하지 않은 경우 단축 인자 이름을 활용할 수 있다.($0, $1)
단축 인자이름은 순서대로 $0 , $1 , $2, $3 ...으로 표현한다.
$0 은 첫번째 인자, $1은 두번째 인자를 뜻한다.
*/

print(numberArray)
// [1, 2, 3, 4, 5]
```

### 2. filter
- 기존 컨테이너의 요소 중 조건에 만족하는 값에 대해 새로운 컨테이너를 만들어 반환.

```swift
// for 문으로 구현
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

// filter로 구현
// numbers에서 짝수만 추출하기

let numbers1 = [1, 2, 3, 4, 5, 6, 7, 8, 9]
let evenNumbers2 = numbers1.filter { $0 % 2 == 0 }

print(evenNumbers2)
// [2, 4, 6, 8]
```

### 3. reduce
- 기존의 컨테이너의 요소에 대해 정의한 클로저로 매핑한 결과를 새로운 컨테이너로 반환.

```swift
// for 문으로 구현
// 각 요소의 합 구하기

let numbers2 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var sum = 0

for number in numbers2 {
    sum += number
}

print(sum)
// 55


// reduce로 구현
// 표현식1
// 각 요소의 합 구하기

let numbers3 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let sum1 = numbers3.reduce(0, +)

print(sum1)
// 55


//표현식2
// 각 요소의 합 구하기

let numbers4 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
let sum2 = numbers4.reduce(0) { $0 + $1 }

print(sum2)
// 55
```