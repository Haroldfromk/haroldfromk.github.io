---
title: (Deep Dive) Variables
writer: Harold
date: 2024-02-29 10:13:00 +0800
categories: [Deep Dive]
tags: [변수]

toc: true
toc_sticky: true
---
생각해보니 Deep Dive는 내가 알고있던것들은 그냥 넘어갔는데, 이참에 그냥 내가 알고있는것들도 정리하는게 좋을 것 같아, Deep Dive로 하여 정리를 하고자 한다.

---
어떤 데이터가 있다
```swift
8907218937
```

이런 데이터에 우리는 이름을 붙일 수 있다.

```swift
Number = 8907218937
```

이런식으로 이름을 붙일 수 있다.

하지만 이걸로는 부족하다 조금 더 작성을 해주어야한다.
**var** 라는 키워드가 필요하다.

우리가 변수를 생성하고 있다고 알려주는 것이다.

그래서 다시 한번 적어보면,
```swift
var Number = 8907218937
```
이렇게 되겠다.

그럼 코드를 한번 작성해보자.
a와 b라는 변수가 있다. 각각 5,8이라는 값을 주고 이것을 프린트 해보자

```swift
var a = 5
var b = 8

print("a") // a
print(b) // 8
```
괄호 안에 "a" 이렇게 적어버리면 우리가 원하는 5가 아닌 a를 출력한다.
그래서 어떤 변수를 출력할때는 괄호안에 그 변수명만 적어두도록 하자.

Q : " " 안에는 변수를 넣지 못하는 걸까?
A : 아니다, 가능하다.
출력을 할때 \ ()를 사용하게 되면 변수를 담을 수 있다.

```swift
var a = 5
var b = 8

print("The value of a is \(a)") // the value of a is 5
print("The value of a is \(b)") // the value of a is 8
```

아래 간단한 연습을 할 수있는 컴파일러가 있다. 한번 연습 해보도록 하자.

<iframe src="https://paiza.io/projects/e/WKfD-BGJ56qEc0hDGODPpw?theme=twilight" width="100%" height="500" scrolling="no" seamless="seamless"></iframe>