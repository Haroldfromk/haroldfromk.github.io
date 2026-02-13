---
title: (Deep Dive) Constants & Functions
writer: Harold
date: 2024-03-15 14:52
categories: [Deep Dive]
tags: []

toc: true
toc_sticky: true
---

## Constants(상수)
- 변수(Variables)와 달리 값이 변하지 않는다.

상수를 생성하는 방법
`var`는 변수였다면, 상수는 `let`을 사용한다!

즉
```swift
let a = 3
```

변수와 상수의 차이를 아래 코드를 통해서 본다면

```swift
// 변수
var a = 3

a = 5

print(a) //5

// 상수
let b = 4

b = 7

print(b)
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/lfMKcSUjKg.png)

바로 이렇게 에러가 발생하게된다.

>변수와 상수의 기준
>>내가 만든 parameter에 값을 바꿀수 있느냐 없느냐
>>>있다면 변수 / 없다면 상수

Q : 그렇다면 상수는 왜 필요할까?
A : 효율성과 관련이 있다. 그래서 바꿀필요가 없는 기본값들은 상수로 만드는 것이 좋다.


## Randomisation (난수생성)

생성하는 법은 다음과 같다
```swift
// 정수
Int.random(in:lower ... uppper)

//예시
print(Int.random(in: 10...20)) // 10~20 사이의 임의의 숫자가 생성

// 배열
array.shuffle()

// 예시
var array = (0...9).map{$0}
print(array.shuffled())

```

## 함수의 생성

함수를 생성할땐 다음과 같이한다.

```swift
func functionName ( parameters : type of parameters) {
    //code
}
```

그리고 호출을 할땐
`functionName(parameters:parameter)` 이렇게 한다


함수는 우리가 원하는 지시사항을 코드블록으로 패키지화 했다고 생각하면 될 것 같다.

그리고 함수안에 코드를 작성할땐 tab을 눌러 들여쓰기를 하면서 경계를 명확하게 해주면 좋다

## 연습 해보기

아래 컴파일러를 통해 연습을 해보자.

<iframe src="https://paiza.io/projects/e/WKfD-BGJ56qEc0hDGODPpw?theme=twilight" width="100%" height="500" scrolling="no" seamless="seamless"></iframe>

