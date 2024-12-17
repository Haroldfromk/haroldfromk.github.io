---
title: (Deep Dive) Keywords
writer: Harold
date: 2024-04-14 13:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

가끔 여러 사이트를 보며 참고를 할때 변수 앞에 lazy가 붙는 경우가 종종 있다.

이왕 하는거 keyword에 대한 부분을 좀 정리를 해보려고 한다.

Strong, weak에 대한 부분은 ARC에서 적었으므로 pass하도록 한다.

## 1. lazy

Literal 의미 그대로 받아들이는게 좋다고 생각한다. 요근래 swift의 keyword를 좀 보고있다보면 이런 Literal로 그냥 받아들이면 이해가 가는 단어들이 꽤 있는듯 하다.

다시 돌아가서,

> lazy의 가장 큰 특징은 
>> 선언한 프로퍼티가 처음 사용되기 전까지는 메모리에 올라가지 않는다! 는 점이다.

그래서 우리가 lazy를 사용할때의 예를 보면

Container, 아니면 Code로 작성하는 UIComponent들도 lazy를 사용한다.

이렇게 프로퍼티가 처음부터 메모리에 올라가는것이 아닌, 사용이 될때 메모리가 올라가기에

**메모리를 효율적으로 사용할 수 있다.** 는 장점이 생긴다.

[Stackoverflow](https://stackoverflow.com/questions/40694691/what-is-the-advantage-of-a-lazy-var-in-swift)에도 한 유져가 질문했고 추천수가 많은 대답이 있는데, 한번 읽어보면 좋다. 짧은글이기에 시간도 얼마 안걸린다.

### var와 비교

```swift
var computedValue = {
        var a = 7
        var b = 8
        return a + b
    }
```

![CleanShot 2024-04-14 at 13 12 14@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/12751c32-4cd6-4bb3-849e-010c95c61357)

메모리에 할당이 되어있는걸 볼 수 있다.

이번엔 앞에 lazy를 붙이고 하나더 만들어 보겠다.

```swift
 lazy var lazyComputedValue = {
        var a = 7
        var b = 8
        return a + b
    }
```

![CleanShot 2024-04-14 at 13 14 58@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d7195075-fa65-413b-b973-ad1167b654e4)

lazy var로 선언한 lazyComputedValue는 nil이라 아직 할당이 되어 있지 않는다.

그럼 viewDidLoad에 print를 하면 어떻게 되는지 알아보자.

```swift
print(computedValue())
print(lazyComputedValue())
```

![CleanShot 2024-04-14 at 13 21 50@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6fe104c7-d762-4aed-8685-a861b09914e3)

메모리에 할당이 되었다.

이렇게 메모리에 상주시키지 않고 만들어 뒀다가 필요할때 쓰는것이 바로 lazy 라고 보면 될것같다.

그래서 container의 경우도 AppDelegate에 적었지만, 메모리에 할당시키지 않다가, 유져가 CoreData 파일을 만들면서 연결을 시키면 그때 부터 메모리에 할동하고 작동하게 하는것도 이런 이유이다.

## 2. final

Override가 필요 없을 때 즉 상속이 필요 없을때 final을 사용한다.

**이게 진짜 끝이야** 라는 느낌으로 보면 좋지않을까 싶다.

```swift
class Person1 {
    final var name: String = ""

    final func speak() {
        print("Say Ho!")
    }
}

final class Student: Person {

    override var name: String {
        set {
            super.name = newValue
        }

        get {
            return "Student"
        }
    }
}

class normalPerson: Student {
    
}

```

Student Class가 Person을 상속 받았으나! name앞에 final로 선언이 되었기에, 위의 함수를 swift그대로 적게되면 Error가 발생한다.

그리고 normalPerson이라는 class가 Student class를 상속 받으려고 했지만, Student는 final class이기에 상속이 되지 않는다.

![CleanShot 2024-04-14 at 14 13 51@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/71ec620f-b239-41c7-80dc-eeddd9cdca73)

이렇게 뭔가 상속을 할때, 해당 함수, 변수등이 상속시 하위 클래스에서 사용하지 못하게 할때 final을 사용한다.

## 3. self

우리가 무의식적으로 자주 사용하는? self이다.

클로저에서도 사용이되고, delegate를 사용할때는 필수요소이다.

그럼 우리는 self에 대해서 자세히 알고 쓰는걸까? 아니면 그냥 빌드하니 error가 뜨면서 self를 입력하라고해서, 그냥 하라는대로 하는걸까?

모든 인스턴스는 암시적으로 생성된 self 프로퍼티를 갖는다.

> 자기 자신을 나타내는 프로퍼티.
>> 인스턴스를 더 명확히 지칭하고 싶을때 사용한다.
>> 인스턴수 변수인지, 지역변수인지? 확인할때

@escaping Closure에서도 사용을 하게되는데 이때는 강한 참조를 피하기 위해 사용한다.

