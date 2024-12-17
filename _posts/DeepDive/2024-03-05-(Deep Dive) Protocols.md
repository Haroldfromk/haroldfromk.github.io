---
title: (Deep Dive) Protocols
writer: Harold
date: 2024-03-05 11:11:00 +0800
categories: [Deep Dive]
tags: [프로토콜]

toc: true
toc_sticky: true
---

프로토콜 → 일종의 인증서의 개념으로 생각하면 될 것 같다.

## 프로토콜 정의

```swift
protocol Myprotocol {
    //Define requirements
}
```

> 프로토콜이란?
>> 어떤 기능에 적합한 특정 메서드, 프로퍼티 및 기타 요구 사항의 청사진을 의미한다.
프로토콜은 클래스, 구조체, 열거형에 의해 채택되며, 프로토콜에 정의 된 요구사항의 실제 구현을 제공한다.

## Class, Struct, Protocol 비교

비교는 코드로 대체하겠다.

Bird라는 class가 있다.

```swift
class Bird {
    
    var isFemale = true
    
    func layEgg() {
        if isFemale {
            print ("The bird makes a new bird in a shell.")
        }
    }
    
    func fly () {
        print("The bird flaps its wings and lifts off into the sky")
    }
}

```

새(조류)라는 클래스는 암컷이고, 알을 낳고, 날수있는 기능(함수)를 가지고 있다.

그리고 그 조류를 상속 받은 독수리라는 클래스를 만들어 주었다.

```swift
class Eagle : Bird { // 상속을 하였다.
     
    func soar(){
        print("The eagle glides in the air using air currents.")
    }
}
```

독수리는 Bird가 가지고있는 기능을 모두 사용 할 수 있다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/UvNEOCF2Cu.png)

그리고 조류를 상속받는 펭귄도 만들어보자

```swift
class Penguin : Bird {
    func swin() {
        print("The penguin paddles through the water.")
    }
}
```

펭귄도 역시 조류가 가지고 있는 기능을 모두 사용 할 수있다

그런데 상식적으로 펭귄은 날 수 없는데? fly 함수를 사용 할 수 있다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/sTrlx5jAG1.png)

이것은 말이 안된다.

그리고 조류 박물관을 하나 구조체로 만들어 주었다.

조류 박물관은 조류를 상속 받을 수는 없지만 매개변수로 가져 올 수는 있다.

```swift
struct FlyingMuseum {
    func flyingDemo(flyingObject : Bird) {
        flyingObject.fly()
    }
}
```

그리고 다음과 같이 작성하였다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/FJAUuiZShV.png)

조류박물관이라는 구조체를 만들었고 거기에 flyingDemo라는 함수를 만들었는데 매개변수의 타입을 조류로 하였고 호출을 하면 fly를 하게끔 하였다.

이런식으로도 표현을 할 수 있다.

마지막으로 비행기도 해보자.

```swift
class Airplane : Bird {
    override func fly() {
        print ("The airplane uses its engine to lift off into the air.")
    }
}
```

비행기도 일단 조류로 넣었다(?) 근데 조류와 달리 엔진을 사용해서 하늘을 비행하니 함수를 오버라이드하여 재정의 해주었다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/LsXz88TqUl.png)

이렇게 클래스와 구조체를 사용해서 조류에대해 표현을 해봤는데, 상속을 받으면 그 해당기능을 다 사용가능하다.

그런데 펭귄은 하늘을 날 수 없고, 비행기는 알을 낳지 못한다.

하지만 클래스로 표현하면 이 모든것이 가능해진다.

그렇다면, 펭귄은 조류의 클래스를 상속 받으면서 날 수는 없게하고,

비행기는 조류의 클래스를 상속 받으면서 알을 낳지 못하게 할 수는 없을까?

이때 필요한게 바로 프로토콜이다.

프로토콜을 하나 만들어 보자 

날 수 있게 하기위해 Canfly로 하였다.

```swift
protocol CanFly {
    func fly()
}
```

이 때 프로토콜에는 함수의 body내역은 적지 않는다!

![](https://i.esdrop.com/d/f/E8Nib9NqGY/eQxraPOnMC.png)

이런식으로 에러가 뜬다.

그리고 조류 클래스도 약간 수정을 해주자.

```swift
class Bird {
    
    var isFemale = true
    
    func layEgg() {
        if isFemale {
            print ("The bird makes a new bird in a shell.")
        }
    }
}
```

이제 독수리 클래스에 Canfly 프로토콜을 적용해보자!

Canfly 프로토콜을 사용했는데 fly 함수가 없어서 에러가 발생한다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/fG6aIJ0149.png)

그래서 fly함수를 새로 만들어 준다!

```swift
class Eagle : Bird, CanFly {
//           -----  ------
//            상속   프로토콜
    func fly() {
        print("The bird flaps its wings and lifts off into the sky")
    }
    // 프로토콜에 fly함수가 있으므로, 반드시 fly함수가 들어가야 한다!

    func soar(){
        print("The eagle glides in the air using air currents.")
    }
}
```

이젠 조류의 특성을 가지면서, 날 수 있는 함수를 별도로 만들어 주었다!

그렇다면 펭귄은 어떨까?

펭귄은 그대로 두었고 다만 이제는 fly 함수를 쓸 수가 없다.

그리고 비행기로 넘어가자

```swift
struct Airplane : CanFly {
// class에서 struct로 변경하였다. 프로토콜은 구조체, 클래스 둘다 사용가능하다!
    func fly() {
        print ("The airplane uses its engine to lift off into the air.")
    }
}

```

클래스였던것을 구조체로 바꾸어 주었다.

그리고 재정의 했던것이 이제는 의미가 없으므로 `override`는 지워주었다.

그리고 박물관 역시 바꿔준다. 왜냐 Bird 클래스엔 더이상 fly가 없기 때문이다!

![](https://i.esdrop.com/d/f/E8Nib9NqGY/2pnnjv3dr3.png)

```swift
struct FlyingMuseum {
    func flyingDemo(flyingObject : CanFly) {
        flyingObject.fly()
    }
}
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/AORWXYtf6O.png)

myEagle, myPlane은 Canfly 프로토콜을 가지고 있고

위에 FlyingMuseumdㅔ도 매개변수의 타입을 Canfly 프로토콜을 가진 타입으로 하였다.

펭귄으로 하면 어떻게 될까?

이렇게 Canfly가 없다고 나온다.
![](https://i.esdrop.com/d/f/E8Nib9NqGY/Rmv1Pc93CZ.png)

이제 더이상 펭귄은 날수가 없다...

이미지로 정리해보면

처음에는 이렇게 모두 날 수 있었다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/i23THm705h.png)

그러다보니 날수 없는 조류도 fly라는 기능을 가질 수 있었다.

하지만 프로토콜을 적용하면서

분류를 하게 된것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/o8Dsz1dBFG.png)

프로토콜을 새로 비유를 하여 해보았다.

여러 프로토콜을 사용할때는 다음과 같이 사용하면된다.

```swift
struct Mystructure: FirstProtocol, AnotherProtocol {
    // code
}

class MyClass : SuperClass, FirstProtocol, AnotherProtocol {
    //code
}
```