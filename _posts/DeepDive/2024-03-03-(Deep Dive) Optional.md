---
title: (Deep Dive) Optional
writer: Harold
date: 2024-03-03
categories: [Deep Dive]
tags: [옵셔널]

toc: true
toc_sticky: true
---

## 옵셔널은 왜 사용할까?

옵셔널은 **값이 있을 수도 있고 없을 수도 있다**

보통 우리가 어떤 로직을 짤때, 보통 초기값을 부여하곤 하지만, 값이 없을 수도 있을 상황이 있을 수도 있다.

옵셔널은 보통 nil값이 들어갈 수 있는 변수 뒤에 ? 를 붙여 사용한다.

우선 코드를 작성해보았다.

```swift
let myOptional : String? // Optional String Type 변수 생성 뒤에 ?
myOptional = "Harold"
let text : String = myOptional // Error 발생
```
에러가 발생한다
![](https://i.esdrop.com/d/f/E8Nib9NqGY/9qc1qLrRQN.png)

myOptional에는 Data Type이 Optional String이고
text는 String이기 때문에 안되는 것이다.

```swift
let myOptional : String? // Optional String Type 변수 생성 뒤에 ?
myOptional = "Harold"
let text : String = myOptional! // ! 를 붙여 Force Unwrapping 해주었다,
```

## 1. Force Unwrapping

!를 사용하여 강제로 Unwrapping해주는 것이다.

하지만 사용할때 아주 신중하게 해야한다. nil값이 저장되는 경우도 고려해야하기 때문,

myOptional의 값을 "Harold"에서 nil로 변경을 해보자.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/kPjtdF7ozY.png)

이렇게 에러가 발생하는 것이다.

그러므로 !를 사용할때는 신중해야 한다는 것!

## 2. Check for nil Value

- 기본 형태
```swift
if optional != nil {
    optional!
}
```

이런 형태를 띈다.

즉 옵셔널이 아니면 unwrapping 하여 그값을 이용한다는 것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/yFNcAsblvF.png)

그리고 nil이라면? else를 통해 예외처리를 해준다.

앱구동시 충돌을 이렇게 방지를 할 수 있다.

하지만 한가지 문제가 있다.

내가 이미 옵셔널인지 아닌지 if문을 통해 확인을 했지만...

그래도 !를 써서 unwrapping을 해줘야 한다는 것이다.

그리고 여러번 사용을 하게되면? 그때마다 계속 !를 사용해야한다.

예를들어 아래와 같이 또 옵셔널로 정의 된 변수를 사용을 해야할때

```swift
let myOptional : String?

myOptional = nil

if myOptional != nil {
    let text : String = myOptional!
    let text2 : String = myOptional! // !를 또 붙어야한다.
} else {
    print("myOptional was found to be nil.")
}
```

이렇게 또 !를 붙여야 사용을 할 수 있는것이다.

## 3. Optional Binding

하지만 Swift에는 이걸 처리할 수 있는 내장된 기능이 있다.

바로 OptionBinding이다.

if let을 사용하는 방법이다.

- 기본 형태

```swift
if let safeOptional = optional {
    safeOptional
}
```
이런 형태로 작성을 한다.

어떤 변수의 값이 nil이 아닐경우 새로운 변수로 담아 if문을 통해 코드를 진행하는 방식이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/E9rGnVB09a.png)

myOptional의 값을 nil에서 Harold로 변경하였다.

그리고 text에 safeOptional값을 넣고 출력을 해보았다.

잘나온다

이렇게 !를 통해 강제로 언래핑 하지않고 옵셔널 바인딩을 통해 nil값을 처리 할 수 있다.

그렇다면 `myOptional = nil`인 상태일때 기본 값을 부여하고 싶다면 어떻게 해야할까?

## 4. Nil Coalescing Operator (nil 병합 연산자)

- 기본 형태

```swift
optional ?? defaultvalue
```

만약 nil이 아닐경우엔 그 값을 사용하고 nil일 경우에는 defaultvalue를 사용한다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/WMAYfEGcaq.png)

이런식으로 nil일때 ?? 뒤에 있는 그 값이 myOptional에 들어가는 것이다.

이걸 if로 표현해본다면

```swift
if myOptional != nil {
    let text = myOptional
} else {
    myOptional = "I am the default value"
}

이런식으로 표현이 된다.

```

그런데 Optional 대신 Optional struct나 class가 들어간다면??

다음과 같이 코드를 작성하였다.

근데 에러가 발생했다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/tlYMSykZIx.png)

현재 MyOptional이라는 구조체 안에 property가 옵셔널타입이 아니더라도, 구조체가 옵셔널타입이기때문에 unwrapping하지 않으면 사용할 수 없다. 

! 를 사용하여 unwrapping 해주면 리스크가 크다

만약 `myOptional = nil` 이라면?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/N06d3oUAXh.png)

이렇게 에러가 발생하기 때문이다.

그럼 이 코드를 안전하게 실행하려면 어떻게 해야할까?

## 5. Optional Chaining

```swift
optional?.property
optional?.method()
```

. 을 사용하여 일부 속성이나 메서드에 접근을 할때 Optional 다음에 ? 를 붙여 접근을 한다.

이때 optional이 nil이 아니면 property에 접근을 한다.

(method도 마찬가지.)

```swift
struct MyOptional {
    var property = 123
    func method() {
        print("I am the struct's method")
    }
}

let myOptional : MyOptional?

myOptional = nil

print(myOptional?.property)
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/Sag6geodaV.png)

현재 MyOptional 구조체의 property에는 123이 있지만, 우리가 구조체를 nil이라고 값을 부여했기에 property에 엑세스를 해도 이렇게 nil이 출력되는걸 알 수 있다.

반대로 `myOptional = MyOptional()` 로 초기화를 해주어 출력을 하면?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/p41JUMefIl.png)

결과값이 optional Int type으로 출력된다.

## 표현법만 정리

### 1. Force Unwrapping
- `optional!`

### 2. nil값인지 확인
- 
```swift 
if optional!= nil {
    optional!
}
```

### 3. 옵셔널 바인딩
- 
```swift
if let safeOptional = optional{
    safeOptional
}
```

### 4. nil병합 연산자
- `optional ?? defaultValue`

### 5. 옵셔널 체이닝
- `optional?.property`
- `optional?.method()`


## 연습 해보기

아래 컴파일러를 통해 연습을 해보자.

<iframe src="https://paiza.io/projects/e/WKfD-BGJ56qEc0hDGODPpw?theme=twilight" width="100%" height="500" scrolling="no" seamless="seamless"></iframe>