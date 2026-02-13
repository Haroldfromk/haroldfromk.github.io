---
title: (Deep Dive) Array
writer: Harold
date: 2024-02-29 10:19:00 +0800
categories: [Deep Dive]
tags: [배열]

toc: true
toc_sticky: true
---

## Array (배열)
- 아이템들의 컬렉션이라고 할 수 있다.
- 변수에서 배열이란 단일 데이터와 연관되어있다.

1. 배열의 생성
- 기본적으로 [ ] 대괄호를 사용한다.
- 대괄호 안에 데이터를 , 를 붙여 적어준다.
```swift
[1, 2, 3, "apple"][X]
```
뒤에 있는 또 다른 대괄호 안의 X는 배열에서 검색하고자 하는 항목의 위치 즉 Index를 가르킨다.

Q : 그렇다면 1은 첫번째니까 X 는 1부터 시작하는가?
A : 안타깝지만 답은 X이다. 우리는 인덱스의 시작을 0으로 정의를 하므로 까먹지 말자.

- 또한 배열 앞에 변수를 선언 할 수 있다.
```swift
var fruits = ["apple", "banana", "grape", "orange"]

// 변수 뒤에 인덱스를 표현해보자
fruits[0]
fruits[1]
```


이번에도 아래 컴파일러를 통해 간단히 연습해보자.

<iframe src="https://paiza.io/projects/e/WKfD-BGJ56qEc0hDGODPpw?theme=twilight" width="100%" height="500" scrolling="no" seamless="seamless"></iframe>