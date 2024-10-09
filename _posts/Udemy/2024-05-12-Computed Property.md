---
title: Computed Property
writer: Harold
date: 2024-05-12 10:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Advanced]
tags: []

toc: true
toc_sticky: true
---

## Computed Property

그동안 과제나, 팀프로젝트를 하면서 Computed Property를 잘 안쓴것 같다.

이번에 좀 적어보려한다.

```swift
let pizzaInInches: Int = 10
var numberOfSlices: Int = 6
```

이렇게 두 변수에 값이 할당 되어있다.

현재는 값이 모두 수동으로 설정이 되어있다.

우리는 이 변수의 값을 변경하려면 다음과 같이 한다.

```swift
numberOfSlices = 4
```

만약 `numberOfSlices`라는 변수가 위에있는 `pizzaInInches`의 값에 따라 변화를 주고싶다면?

이때사용하는게 바료 Computed Property이다.

```swift
var numberOfSlices: Int {
    return pizzaInInches - 4
}
```

이런식으로 약간 함수처럼 연산을 하게 하는것인데. 이때 return을 적어서 반환하게 해준다.

이때 꼭 지켜야하는게 있다.

1. 반드시 변수는 `var`로 선언해야 한다는 것
2. 반드시 변수의 타입을 명시해줘야 한다는 것

이렇게 하면 변수에 대해 동적으로 사용할 수 있게 된다.

## Getter

사실 지금 위에 있는 부분이 바로 getter 이다

엄밀히 말하면 getter의 생략된 버전.

```swift
var numberOfSlices: Int {
    return pizzaInInches - 4
}
```

getter는 말 그대로 값을 가져오는 것이다.

FM으로는 이렇게 사용한다.

```swift
var numberOfSlices: Int {
    get {
        return pizzaInInches - 4
    }
}
```

## Setter

```swift
var numberOfSlices: Int {
    get {
        return pizzaInInches - 4
    }
    set {
        print("numberOfSlices now has a new value which is \(newValue)")
    }
}

print(numberOfSlices) // 6

numberOfSlices = 12 // numberOfSlices now has a new value which is 12
```

값이 변화하거나 우리가 설정을 하게 되면 set이 실행이 된다.

이때 newValue가 바로 우리가 새롭게 설정한 값이다.

setter를 사용하는 목적은 연산이나 다양한 코드 내에서 새 값을 사용할 수 있게 하고, 속성이 업데이트되는 정확한 시간에 실행할 수 있게 해준다. 

![CleanShot 2024-05-12 at 21 39 16@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/ba03738a-b062-49c3-86ab-52b1ba8495ea)

이때 setter를 설정해두지않은 상태에서 값을 부여하면 error가 발생.

## 예시

피자의 인치가 있고, 사람수가 있고, 한사람당 먹을수있는 슬라이스 조각이 있다.

조건을 만들어 본다.

1. 피자의 인치는 16
2. 사람 수는 12
3. 한 사람당 피자조각은 4

이때 피자가 몇판이 필요할까?

우선 조건은 이렇게 표현이 가능하다.

```swift
var pizzaInInches: Int = 16  // 1번조건
var numberOfPeople: Int = 12 // 2번조건
let slicesPerPerson: Int = 4 // 3번조건
```

이걸 Computed Property를 사용해서 몇판의 피자가 필요한지 계산을 해보자.

```swift
var numberOfSlices: Int {
    get {
        return pizzaInInches - 4
    }
}

var numberOfPizza: Int {
    get {
        let numberOfPeopleFedPerPizza = numberOfSlices / slicesPerPerson
        return numberOfPeople / numberOfPeopleFedPerPizza
    }
}
```

우선 인치에서 4를뺀 만큼 피자조각이 나온다고 가정, 그걸 동적으로 리턴하기위해 getter를 사용했다.

이렇게 하니 유동적으로 우리가 몇판의 피자가 필요한지 알 수 있다.

이젠 Setter를 사용해서 피자의 개수를 알면 몇사람이 먹을 수 있는지 계산을 할 수 있다.

왜냐 setter를 사용해서 값을 입력하면 set이 실행되기 때문.

Setter에 있는 newValue는 우리가 임의대로 변경할수없다.

```swift
var numberOfPizza: Int {
    get {
        let numberOfPeopleFedPerPizza = numberOfSlices / slicesPerPerson
        return numberOfPeople / numberOfPeopleFedPerPizza
    }
    set {
        let totalSlices = numberOfSlices * newValue
        numberOfPeople = totalSlices / slicesPerPerson
    }
}
```

이렇게 setter를 구성하고 다음과 같이 피자의 개수를 설정하면?

```swift
numberOfPizza = 8
print(numberOfPeople) // 24
```

이렇게 값이 출력이된다.

이렇게 값을 동적으로 받을 수도 있고, 값을 받음으로써 동적으로 어떤 변수의 값을 바꿀수도있다.

## Observed Property

값이 변할때 코드를 트리거 할수 있는데 바로 willSet과 didSet이다.

willSet은 변경 직전에 트리거 되며

didSet은 변경 직후에 트리거 된다.