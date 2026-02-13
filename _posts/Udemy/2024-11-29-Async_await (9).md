---
title: Async/Await (9)
writer: Harold
date: 2024-11-29 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## AsyncSeqeunce

지진정보를 가지고 해보려한다.

### 1. without AsyncSequence

우선 여기서 특이점이라면

```swift
extension URL {
    func allLines() async -> Lines {
        Lines(url: self)
    }
}

struct Lines: Sequence {
    
    let url: URL
    
    func makeIterator() -> some IteratorProtocol {
        let lines = (try? String(contentsOf: url))?.split(separator: "\n") ?? []
        return LinesIterator(lines: lines)
    }
    
}
struct LinesIterator: IteratorProtocol {
    
    typealias Element = String
    var lines: [String.SubSequence]
    
    mutating func next() -> Element? {
        if lines.isEmpty {
            return nil
        }
        return String(lines.removeFirst())
    }
}
let endpointURL = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv")!

Task {
    for line in await endpointURL.allLines() {
        print(line)
    }
}
```

Sequence라는 프로토콜을 사용하게 된다.

Iterator는 예전에 자바를 공부했었을때 사용했던 기억이 있는데, 여기서도 사용이 된다.

이걸 실행하게 되면 csv다운로드를 하고난뒤 해당 파일의 내용을 한줄씩 출력하게 된다

이전에 보지못했던것이니 한번 짚고 넘어가보도록 한다.

#### 자세히 확인 해보기

##### 1. Sequence

CountDown 구조체에 Sequence 프로토콜을 채택하면서, 

[Sequnce Docs](https://developer.apple.com/documentation/swift/sequence){:target="_blank"}에는 다음과 같이 정의를 한다.

>A type that provides sequential, iterated access to its elements.
>> Elements에 대한 순차적이고 반복적인 액세스를 제공하는 Type.

정확하게 무슨말일까 Docs에 있는 예시 코드를 보도록 한다.

```swift
struct Countdown: Sequence, IteratorProtocol {
    var count: Int


    mutating func next() -> Int? {
        if count == 0 {
            return nil
        } else {
            defer { count -= 1 }
            return count
        }
    }
}


let threeToGo = Countdown(count: 3)
for i in threeToGo {
    print(i)
}
// Prints "3"
// Prints "2"
// Prints "1"
```

여기서 보면 3,2,1로 감소를 한다

보통 이 로직을 간단하게 우리가 알던대로 한다고 하면

```swift
struct CountdownTest {
    var count: Int

    func next() -> [Int] {
        var result: [Int] = []
        for i in (1...count).reversed() {
            result.append(i)
        }
        return result
    }
}

let countdown = CountdownTest(count: 3)
for i in countdown.next() {
    print(i)
}
```

뭐 이런식으로 하지 않을까 싶다.

두개의 차이라면 우선 프로토콜과 mutating, defer 이렇게 세가지로 볼 수 있다.

첫번째는 struct 내에있는 count 값이 계속 바뀌기에 structure에서는 값이 원래 바뀔수가 없으므로 `mutating`을 사용하여 값이 변하게 도와준다.

그리고 우리가 생각한 반복적인 내용은 어디에도 없다.

그러면 Sequence를 왜썼을까?

위에서 정의를 했지만 **순차적이고 반복적인 접근을 제공** 이게 포인트라고 본다.

[참고글](https://itwenty.me/posts/04-swift-collections/){:target="_blank"}을 바탕으로 적어본다.

정의는 다음과 같다
```swift
public protocol Sequence {
    associatedtype Element
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element

    func makeIterator() -> some IteratorProtocol
}
```

- Element: Sequence의 Type을 나타냄
- Iterator: IteratorProtocol을 준수하며, 요소를 하나씩 반환하는 반복자.
- makeIterator():
    - Sequence에서 반복자를 생성하여 반환.
    - 반환된 반복자는 요소를 순차적으로 탐색하는 역할.

다시 Docs로 돌아와서

아까 그 코드는 실질적으로 우리가 보면

```swift
let threeToGo = Countdown(count: 3)
for i in threeToGo {
    print(i)
}
```

어디에서도 `next()`를 사용하지 않는다.

여기서 next를 사용한건 IteratorProtocol은 next 함수를 가지고 있는데, 그걸 우리가 원하는대로 커스터마이징 했다고 보면된다.

뭐랄까 오버라이딩 하는 느낌이다.

next()를 우리가 직접적으로 사용을 하는 코드는 어디에도 없지만

이렇게 적는것만으로도 실행이 된다.

**하지만 next 스펠링이 틀리면 에러가 발생한다**
즉 함수의 내용은 커스터 마이징이 가능하나, 함수명 자체는 변경이 불가! (사실 이내용은 아래 Iterator에 어울리는 내용이긴 하다. 위에서 사용되었으므로 언급을 했다.)

**makeIterator**도 next와 같이 커스터마이징이 가능하며, 스펠링이 틀리면 안된다!

##### 2. IteratorProtocol

[IteratorProtocol Docs](https://developer.apple.com/documentation/swift/iteratorprotocol){:target="_blank"}에는 

다음과 같이 정의를 한다

>A type that supplies the values of a sequence one at a time.
>> Sequence의 값을 한번에 하나씩 제공하는 Type

Docs의 예시를 보도록 하자

```swift
let animals = ["Antelope", "Butterfly", "Camel", "Dolphin"]
for animal in animals {
    print(animal)
}

// Prints "Antelope"
// Prints "Butterfly"
// Prints "Camel"
// Prints "Dolphin"

var animalIterator = animals.makeIterator()
while let animal = animalIterator.next() {
    print(animal)
}
// Prints "Antelope"
// Prints "Butterfly"
// Prints "Camel"
// Prints "Dolphin"
```

첫번째 for 문은 내부적으로 makeIterator를 호출하여 반복자를 생성하고, 각 반복에서 next()를 호출하여 배열의 요소를 순차적으로 처리한다.

단지 Iterator가 우리가 있는지 직관적으로 보이지않아서 알지 못했을뿐이다.

이렇게 배열에서 `makeIterator`를 통해서

![CleanShot 2024-11-29 at 19 09 35](https://github.com/user-attachments/assets/23fae15f-c01f-4ac5-b040-ea6ef6ed0533)

순차적으로 접근이 가능하게 해주었다.

그런데 makeIterator는 Sequnce 프로토콜에 있던 내용이다.

배열은 기본적으로 [Collection](https://developer.apple.com/documentation/swift/collection/){:target="_blank"} 프로토콜을 준수한다.

위 프로토콜 역시 `makeIterator()`메서드를 제공한다.

그래서 사용이 가능한것.

두 프로토콜에 대한 내용은 [Docs](https://developer.apple.com/documentation/swift/sequence-and-collection-protocols){:target="_blank"} 를 참고하자.

다시 돌아와서

![CleanShot 2024-11-29 at 19 12 05](https://github.com/user-attachments/assets/586c58cb-b674-4b43-a742-cd02c942b7f6)

`next`를 통해서 하나씩 순차적으로 접근을 하기 시작한다.

그리고 next는 더 이상 반환할게 없다면 nil를 리턴하면서 메서드가 종료된다.

그러면 이제 해당 프로토콜을 채택한 예를 들어보자

Sequence에서 사용한 참고글이 좋아서 그대로 사용한다.

```swift
public protocol IteratorProtocol {
    associatedtype Element
    mutating func next() -> Element?
}
```

정의는 위와 같다.

```swift
struct DoublingIterator: IteratorProtocol {
    var value: Int
    var limit: Int? = nil

    mutating func next() -> Int? {
        if let count = limit, value > count {
            return nil
        } else {
            let current = value
            value *= 2
            return current
        }
    }
}

var doublingIterator = DoublingIterator(value: 1, limit: 1024)
while let value = doublingIterator.next() {
    print(value)
}

//1
//2
//4
//8
//16
//32
//64
//128
//256
//512
//1024
```

- IteratorProtocol의 역할:
	- Sequence의 각 요소를 하나씩 반환하는 반복자(iterator)를 정의하는 프로토콜이다.
	- 데이터를 한 번에 하나씩 반환하며, 순차적인 데이터 접근을 가능하게 한다.
	- 반복이 종료될 시 nil을 반환한다.
- 사용 목적:
    1. 순차적 데이터 접근:
	    - 데이터나 계산된 값에 순차적으로 접근할 수 있는 메커니즘을 제공.
	    - 데이터의 크기가 크거나 무한한 경우, 한 번에 하나의 요소만 반환하도록 설계하여 메모리 효율성을 높임.
	2. 반복 상태 관리:
	    - 반복자가 각 요소를 반환하면서 반복 상태를 관리할 수 있도록 함.
	    - 상태를 갱신하여 다음 호출 시 적절한 값을 반환하도록 설계.
	3. 사용자 정의 반복 동작:
	    - 배열이나 컬렉션과 같은 기본 제공 타입 외에도, 사용자 정의 데이터 구조나 반복 패턴을 정의 가능.
	    - 예: DoublingIterator는 값을 두 배로 증가시키며 반환하는 반복자.
	4. 무한 반복 지원:
	    - next() 메서드가 nil을 반환하지 않는 한, 반복자는 무한히 값을 생성 가능.
	    - 필요한 경우 조건을 추가하여 반복을 제한할 수 있음 (limit 같은 매개변수).

사실 위 코드는 IteratorProtocol이 무조건 강제되는 상황은 아니다.

IteratorProtocol이 강제되는 상황은 `Sequence` 프로토콜과 같이 쓰일때 발생한다.

그래서 Sequence의 Docs 예시가 두개가 같이 쓰이는 것이다.

##### 3. Defer

Defer는 사전적의미로 미루다 라는 뜻이다.

[Medium](https://medium.com/@saumyalahera_56871/defer-statement-in-swift-ec610683ff12){:target="_blank"}도 참고 하면 좋을듯

만약 Defer를 사용하지 않았다면

```swift
mutating func next() -> Int? {
    if count == 0 {
        return nil
    } else {
        let result = count // 현재 값을 저장
        count -= 1         // count를 감소
        return result      // 저장한 값 반환
    }
}
```

이런식으로 내부적으로 변수를 하나 더 만들어야 했다.

하지만 defer를 사용하면 

```swift
mutating func next() -> Int? {
    if count == 0 {
        return nil
    } else {
        defer { count -= 1 }
        return count
    }
}
```

더 깔끔 해진다

매커니즘을 좀 확인을 해본다면, 


시점에 대한 이해를 돕기위해 print를 추가

```swift
mutating func next() -> Int? {
    if count == 0 {
        print("Due to Returning nil, function will be closed")
        return nil
    } else {
        defer {
            count -= 1
            print("Defer excuted, count to \(count)")
        }
        print("Returning \(count)")
        return count
    }
}

//Returning 3
//Defer excuted, count to 2
//3
//Returning 2
//Defer excuted, count to 1
//2
//Returning 1
//Defer excuted, count to 0
//1
//Due to Returning nil, function will be closed
```

이렇게 될것이다.

즉 먼저 리턴을 하고 나면 defer가 작동하게 된다.

Defer는 리소스 정리 또는 정해진 작업이 반드시 실행되도록 보장할 때 유용하다라는 큰 장점이 있다.

#### **결론**
- `Sequence`는 반복 가능한 객체를 정의하며, 순차적으로 데이터를 탐색할 수 있는 인터페이스를 제공.
- `IteratorProtocol`은 반복자를 정의하여 `Sequence`의 반복 동작을 구체화.
- `Defer`는 작업의 순서를 명확히 하고 코드의 간결성을 유지하며, 반드시 실행되어야 할 작업을 보장하는 데 유용.

##### 4. 강의 코드 분석

이제 어느정도 개념정리가 되었으니 다시 보도록 하자.

```swift
extension URL {
    func allLines() async -> Lines {
        Lines(url: self)
    }
}

struct Lines: Sequence {
    
    let url: URL
    
    func makeIterator() -> some IteratorProtocol {
        let lines = (try? String(contentsOf: url))?.split(separator: "\n") ?? []
        return LinesIterator(lines: lines)
    }
    
}
struct LinesIterator: IteratorProtocol {
    
    typealias Element = String
    var lines: [String.SubSequence]
    
    mutating func next() -> Element? {
        if lines.isEmpty {
            return nil
        }
        return String(lines.removeFirst())
    }
}
let endpointURL = URL(string: "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv")!

Task {
    for line in await endpointURL.allLines() {
        print(line)
    }
}
```

1. Lines
    - Sequence 프로토콜을 채택한다.
        - 이로써 csv파일에 대해서 순차적으로 접근이 가능한 권한이 생겼다.
    -  makeIterator 함수를 만들었다 정확하게는 커스터마이징 해주었다.
        - 해당 함수에서는 csv파일을 다운로드 하여 한줄씩 리턴한다.
2. LinesIterator
    - IteratorProtocol을 채택한다
        - 이로써 순차적으로 한번에 하나씩 확인을 하게 된다.
    - typealis Element = String
        - Iterator는 Element를 가지고 있다.
        - 하나씩 확인하여 반환하는 요소에 대해 type을 String으로 정의한다.
    - var lines: [String.SubSequence]
        - 배열의 타입을 String.Subsequence로 정해주었다.
            - makeIterator를 통해 한줄씩 슬라이싱 되는 line은 기본적으로 String.SubSequence 타입을 가진다.
            - [Docs](https://developer.apple.com/documentation/swift/string/subsequence){:target="_blank"}
            - 사용하지 않으면 아래와 같은 에러발생
            ![CleanShot 2024-11-29 at 20 47 18](https://github.com/user-attachments/assets/42820363-3b17-4163-9e8e-67d08265179f)
    - next 함수를 만들었다 정확하게는 커스터마이징 해주었다.
        - 해당 함수에서는 순차적으로 계속 접근을 하면서 마지막 줄이 되었을때 nil을 반환하면서 행동이 종료된다.
        - return String(lines.removeFirst())
            - 배열의 첫번째 요소를 지우면서 반환한다.

###### 예시

1. CSV파일

```text
time,latitude,longitude,depth,mag,magType
2024-11-29T11:13:40.990Z,61.863,-149.6035,7.9,1,ml
2024-11-29T11:12:09.870Z,32.9855,-116.3221667,5.49,0.79,ml
```

2. makeIterator를 통해 한줄씩 슬라이스

```text
[
  "time,latitude,longitude,depth,mag,magType",
  "2024-11-29T11:13:40.990Z,61.863,-149.6035,7.9,1,ml",
  "2024-11-29T11:12:09.870Z,32.9855,-116.3221667,5.49,0.79,ml"
]
```

3. LinesIterator 초기화

```swift
var lines: [String.SubSequence] = [
  "time,latitude,longitude,depth,mag,magType",
  "2024-11-29T11:13:40.990Z,61.863,-149.6035,7.9,1,ml",
  "2024-11-29T11:12:09.870Z,32.9855,-116.3221667,5.49,0.79,ml"
]
```

4. next 호출 

| **호출**         | **lines 상태**                                             | **반환 값**                                   |
|------------------|-----------------------------------------------------------|----------------------------------------------|
| 초기 상태         | `["time,latitude,...", "2024-11-29T11:13:40.990Z,...", ...]` |                                              |
| `next()` 호출 1   | `["2024-11-29T11:13:40.990Z,...", ...]`                   | `"time,latitude,longitude,depth,mag,magType"` |
| `next()` 호출 2   | `["2024-11-29T11:12:09.870Z,...", ...]`                   | `"2024-11-29T11:13:40.990Z,61.863,...,ml"`   |
| `next()` 호출 3   | `[]`                                                     | `"2024-11-29T11:12:09.870Z,32.9855,...,ml"`  |
| `next()` 호출 4   | `[]`                                                     | `nil`                                        |

이렇게 된다.

[RemoveFirst Docs](https://developer.apple.com/documentation/swift/array/removefirst()){:target="_blank"}에 보면 지워진 요소를 반환한다고 한다.

여태 잘못생각을 했었다.

그 지워진녀석이 리턴이 되고 하나씩 쌓여가는건데, 지워진 배열이 계속 리턴되는걸로 착각했다.

간단한 예를 들어본다.

```swift
var linesSample = ["Line 1", "Line 2", "Line 3"]
```

이런 배열있을때 

```swift
print(linesSample.removeFirst()) // Line 1
print(linesSample) // ["Line 2", "Line 3"]
```

이렇게 되는것이다.

그리고 비슷한 예로 `dropFirst()`도 있다.

```swift
var linesSample = ["Line 1", "Line 2", "Line 3"]

print(linesSample.dropFirst()) // ["Line 2", "Line 3"]
print(linesSample) // ["Line 1", "Line 2", "Line 3"]
```

즉 리턴하는데서 차이가 있다.

여태 헷갈렸던 개념은 firstRemove를 dropFirst의 개념으로 생각해서 생긴 문제였다.

[DropFist Docs](https://developer.apple.com/documentation/swift/string/dropfirst(_:)){:target="_blank"}는 여기.

### 2. with AsyncSeqeunce

```swift
Task {
    for try await line in endpointURL.lines {
        print(line)
    }

}
```

for에 try await를 통해 작성을 한다.

![CleanShot 2024-12-01 at 23 41 28](https://github.com/user-attachments/assets/994ee247-0052-4049-94b3-dd517bdebca5)

이때 URL에는 lines라는 메서드가 있다.

`The URL’s resource data, as an asynchronous sequence of lines of text.`
즉 데이터를 비동기적으로 한줄씩 처리를 할 수 있다는것.

이전글처럼 Iterator도 필요 없고, 다운로드 하면서 바로바로 한줄씩 작업을 처리하게 된다.

이전과 비교하면, 이전에는 일단 리소스데이터를 받고나서 Sequence, Iterator를 통해 한줄씩 확인하면서 그걸 가져오는방식으로 했는데,

이건 데이터를 받으면서 한줄씩 바로바로 처리를 하게 되는 장점이 있다.