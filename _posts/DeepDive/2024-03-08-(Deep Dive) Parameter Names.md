---
title: (Deep Dive) Parameter Names
writer: Harold
date: 2024-03-08 14:52
categories: [Deep Dive]
tags: []

toc: true
toc_sticky: true
---

Swift에서는 기능을 명확히 설명하는 이름의 매개변수가 중요하다!

그리고 Swift 메서드와 함수의 기능은 Swift 매개 변수 이름의 특정 기능에 의존을 하는데,

일반적으로 우리는 이렇게 사용을 하지만

```swift
func myFunc(name : DataType) {
    print(name)
}
```

이렇게 외부와 내부 변수이름을 분리 할 수 있다.

```swift
func myFunc(name    eman: DataType) {
//          ----    ----    
//        external internal
    print(eman)
}
```

내부가 우리가 보통 함수안에서 매개변수를 사용할때의 그 매개변수이다.

그리고 우리가 함수를 호출을 한다면?

```swift
myFunc(name: value)
```

이런식으로 할 것이다.

이때 name이 바로 외부 변수 이름이다.

그리고, 외부 변수명을 사용하고 싶지 않고, 함수를 호출하고 바로 value를 입력하고 싶다면?

즉, `myFunc(value)`로 하고 싶다면?

처음에 함수를 만들때 나도 변수명을 생략하고 싶은데 왜 나는 안될까? 라고 공부를 해본사람이라면 다들 겪었을 경험이다. 

이제 그 해답을 찾아보자.

해답은 바로 ? 

>`_` 를 내부변수 앞에 붙여주면 된다.


그럼 한번 만들어 보자

```swift
func myFunc(_ eman: DataType) {

    print(eman)
}
```

뭔가 저 형식이 낯이 익다?

그렇다. 보통 우리가 코딩테스트 문제를 풀때 많이 봤을 그 부분이다.

```swift
func solution(_ a:Int, _ b:Int) -> String {}
```

여기서도 외부변수 명이 들어갈 자리에 `_`이 있다. 

이렇게 _ 를 사용하면 이제 우리가 함수를 호출해도 값만 넣으면 되니 훨씬 편해진다.