---
title: String Index
writer: Harold
date: 2024-02-29 10:52:00 +0800
categories: [Deep Dive]
tags: [코딩테스트]

toc: true
toc_sticky: true
---
코딩테스트 문제를 풀다보면 String Index에 관한 문제가 많이 나와 정리한다.

추가로 더 서술해야할게 있다면 지속적으로 수정을 할 예정


## String.Index
- Int를 리턴한다.
- String.Index의 구조체 내용이 나온다.
```swift
var string : String = "abcdefg"
print(string.startIndex) //Index(_rawBits: 15)
```
---

## String.distance(from:to:)
- Int를 리턴한다
 - from : string.startIndex
  - to : 변환할 String.Index

```swift
let distance = string.distance(from: string.startIndex, to: 변환할 String.Index)
```
---
## StartIndex (첫글자 구하기)
- 문자열의 시작 인덱스를 알 수 있다.
  
 - startIndex를 String의 Subscript로 전달 하면 해당 인덱스의 문자를 알 수 있다.

```swift
let string: String = "abcdefg"

let first = string.startIndex
print(string[first]) //a
```
---
## prefix(_:)
- 0~n번째까지의 Substring을 구할 수 있다.
```swift
let first = string.prefix(2)
print(first) //ab
```

---

## index(after:)
- n번째 글자를 구할 수 있다.

```swift
let first = string.startIndex

//index(after:)은 매개변수로 String.Index를 받고 전달받은 String.Index의 다음 String.Index를 구할 수 있다.
let second = string.index(after: first)
print(string[second]) //b

```
---
## String.Index(endcodedOffset:)
	
  - String.Index를 생성할 때 encodedOffset 프로퍼티를 설정하면 n 번째 String.Index를 생성할 수 있다.
		
        - 인덱스는 0부터 시작이니 3은 네 번째 문자가 된다.

```swift
print(string[String.Index(encodedOffset: 3)]) //d
```
---

## index(_:offsetBy:)
- offsetBy에 정수 n을 입력하면 Index에서 n만큼 이동한 String.Index를 구할 수 있다.

```swift
let start = string.startIndex
print(string[string.index(start, offsetBy: 0)]) //a
print(string[string.index(start, offsetBy: 2)]) //c

// offsetBy는 음수도 전달할 수 있다.

let index = String.Index(encodedOffset: 3)
print(string[string.index(index, offsetBy: -2)]) //b
//3에서 -2를 한 1 번째 글자인 b가 출력된다.

//주의할 점은 string 범위를 벗어날 경우 런타임 에러가 발생
//startIndex에서 -1을 하면 string의 범위를 벗어나기 때문.
```
---
## endIndex (문자열의 마지막 문자 구하기)

- 그냥 endIndex를 하면 런타임 에러가 발생함
    - 빈 공간을 가리키기 때문.
  - 아래와 같이 사용한다.

```swift
print(string[string.index(before: string.endIndex)]) //g
```
---
## suffix(_:)

- 뒤에서 부터 n개의 Substring을 구할 수 있다.
```swift
print(string.suffix(3)) //efg
```
---
## firstIndex(of:)

- 특정 문자의 인덱스를 구할 때 쓴다.
```swift
print(string.firstIndex(of: "d")) //d의 String.Index
print(string.firstIndex(of: "h")) //nil
```
	
- firstIndex는 문자가 가장 먼저 나오는 String.Index를 반환하기 때문에 일치하는 문자가 여러 개면 가장 먼저 나오는 글자의 인덱스를 리턴한다.

```swift
let string = "aaaaa"
let distance = string.distance(from: string.startIndex, to: string.firstIndex(of: "a")!)
print(distance) //0
```
- index(of:) 도 같은 기능을 수행한다.

---
## lastIndex(of:)
- 마지막으로 나오는 String.Index를 반환.
- 일치하지 않는다면 nil을 반환
```swift
let string = "aaaaa"
let distance = string.distance(from: string.startIndex, to: string.lastIndex(of: "a")!)
print(distance) //4
```