---
title: (Deep Dive) Extensions
writer: Harold
date: 2024-03-08 14:52
categories: [Deep Dive]
tags: []

toc: true
toc_sticky: true
---



Extensions는 본질적으로 기존클래스, 구조, 기타데이터유형에 추가 기능을 추가 할 수 있게 한다.

기본형태는 다음과 같다

```swift
extension SomeType {
    // new functionality
}
```

우리가 늘상 만드는 것과 형태가 다르지 않다.

그저 앞에 class, protocol, struct 대신 extension이 사용되었다.

다음과 같은 수가 있고
```swift
let myDouble = 3.14159

//반올림
let myRoundedDouble = String(format:"%.1f", myDouble)

print(myRoundedDouble) // 3.1
```

그런데 문자열을 생성하지않고 만들고 싶다.
```swift
var myDouble = 3.14159

print(myDouble.round(to: 3))
```

하지만 작동하지 않는다.

우리가 직접 작동하게 만들어 보자.

일단 시퀀스는 다음과 같다
```swift
// ex) 넷째자리에서 반올림한다면?
myDouble=myDouble*1000 // 3141.59
myDouble.round()       // 3142
myDouble=myDouble/1000 // 3.142
```

extension을 다음과 같이 해주었다.

```swift
extension Double {
    func round(to places: Int) -> Double {
        let precisionNumber = pow(10, Double(places)) // 1000처럼 10의 x제곱 형태로 나타내었다.
        var n = self // 해당수 자신을 10제곱수 곱해야 한다.
        n = n * precisionNumber
        n.round()
        n = n / precisionNumber
        return n
    } 
}

```

```swift
print(myDouble.round(to: 3)) // 3.142
```

이젠 원하는 자리수 만큼 반올림이 가능해졌다.

자세한건 애플 깃허브에 들어가보면 있다

애플이 공개한 오픈 소스들이 있다.

하지만 공개되지 않은 코드들도 많다.

<https://github.com/apple/swift>

우리가 UIlabel같은 기능을 만들면서 코드에 대해선 접근 권한이 있는건 아니다.

하지만, 클래스들을 확장 할 수 있다.

```swift
let button = UIButton(frame: CGRect(x:0, y:0, width: 50, height: 50))
button.backgroundColor = .red
button.layer.cornerRadius = 25
button.clipsToBounds = true
```
이렇게 작성을 하면

![](https://i.esdrop.com/d/f/E8Nib9NqGY/taz447yG6c.png)

그렇다면 UIButton을 확장해서, 버튼의 디자인을 동그랗게 해주게 해보자

```swift
extension UIButton {
    func makeCircular() {
        self.clipsToBounds = true
        self.layer.cornerRadius = self.frame.size.width / 2
    }
}
```

그리고나서 해보면?

```swift
let button1 = UIButton(frame: CGRect(x:0, y:0, width: 50, height: 50))
button1.backgroundColor = .red

button1.makeCircular()
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/G489sO2NCs.png)

잘된다!

이렇게 extension은 프로토콜을 확장 할 수 있고,

```swift
extension SomeProtocol {
    // Define default behavior
}
```

저번에 조류를 예로 들었던것을 가져왔다.
```swift
protocol CanFly {
    func fly()
}

extension CanFly {
    func fly() {
        print("The object takes off into the air")
    }
}

struct Airplane: CanFly {

}
```

프로토콜에서는 함수의 내용을 정의 할 수 없었다.

즉 우리가 다른 클래스에서 해당 function을 추가하면서 내용을 정의를 했는데,

extension을 사용하면, 프로토콜의 내용을 정의하면서 프로토콜의 function을 default로 사용 할 수가 있다.

airplane에 Canfly 프로토콜을 추가해도 이젠 에러가 발생하지 않는다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/NYGB6Ir7Fz.png)

이렇게 입력하는순간 바로 사용가능하게 뜬다!

실제로 작동해보면

`The object takes off into the air`

결과값도 잘 나오는걸 확인 할 수있다.

그래서 WeatherViewController 에서

`class WeatherViewController: UIViewController, UITextFieldDelegate,`

이렇게 UITextFieldDelegate 프로토콜을 가져왔음에도 불구하고

함수를 만들지 않아도 에러가 발생하지 않았던 것이다.

extension은 모든 데이터 유형에 대해 다른 프로토콜을 적용 할 수도 있다.

```swift
extension SomeType : SomeProtocol {
    // add new functionality
}
```

해당내용의 예시는 clima(6)과 연관이 되므로 거기서 서술하도록 하겠다