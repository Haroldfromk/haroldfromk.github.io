---
title: JPApexPredators (3)
writer: Harold
date: 2025-4-2 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## filter 부분 수정 및 sort 추가

이전글에서 searchText에 관해 computed property로 하던 것을

Predator Class 내에서 함수로 처리하도록 해본다.

```swift
class Predators {
    // 생략
    func search(for searchTerm: String) -> [ApexPredator] {
        if searchTerm.isEmpty {
            return apexPredators
        } else {
            return apexPredators.filter { predator in
                predator.name.localizedCaseInsensitiveContains(searchTerm)
            }
        }
    }
}

// content view
var filteredDinos: [ApexPredator] {
        return predators.search(for: searchText)
    }
```

이렇게 해주면 끝

이번엔 sort도 넣어본다.

역시나 Predators Class에서 함수로 만든다.

```swift
func sort(by alphabetical: Bool) {
    apexPredators.sort { predator1, predator2 in
        if alphabetical {
            predator1.name < predator2.name
        } else {
            predator1.id < predator2.id
        }
    }
}
```

단순 알파뱃으로만 소팅하는것이 아닌 json에 id도 있었기에 id 순으로도 정렬이 가능하게 한다.

## Sorting을 위한 ToolBar 만들기

이것 역시 간단하다.

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button {
            alphabetical.toggle()
        } label: {
            if alphabetical {
                Image(systemName: "film")
            } else {
                Image(systemName: "textformat")
            }
        }
        
    }
}
```

navigation title 있는 곳에 modifier를 사용하여 만들어 주면 된다.

물론 animation을 주고 싶으면

```swift
withAnimation {
    alphabetical.toggle()
}
```

이렇게 해주면 된다.

![Image](https://github.com/user-attachments/assets/9c6730fb-a7dd-4e15-af64-b6f5acb9287d){: width="50%" height="50%"} 

잘 되는걸 확인할 수 있다.

### 삼항연산자로 간소화하기

```swift
// before
label: {
    if alphabetical {
        Image(systemName: "film")
    } else {
        Image(systemName: "textformat")
    }
}

// after
Image(systemName: alphabetical ? "film" : "textformat")
```

이 부분은 삼항연산자를 사용하여 간략하게 하니 심플 해졌다

해외에선Ternary Operator 라고 하니 참고.

그리고 이것 역시도 약간의 Animation 효과를 줄 수 있다.

`symbolEffect`라는 Modifier를 통해 사용 가능.

```swift
label: {
    Image(systemName: alphabetical ? "film" : "textformat")
        .symbolEffect(.bounce, value: alphabetical)
}
```

![Image](https://github.com/user-attachments/assets/809906c7-dd6b-4364-8ebf-b623d216325b){: width="50%" height="50%"} 

Toolbar를 보면 통통 튀듯 이펙트가 있는걸 알 수 있다.

## Type Filtering

이전에는 searchbar를 통해 입력한 단어를 포함하는 목록이 보여졌다면, 이번에는 type이 일치하는 목록만 보여지도록 해보려 한다.

지금은 Predators Class 내부에 APType이 있는데, 이걸 Class 밖으로 꺼내주도록 한다.

왜냐면 

```swift
func filter(by type: ApexPredator.APType) { }
```

이런식으로 parameter의 타입설정할때는 보통 그 타입은 어떤 클래스 내부의 타입으로 설정하지는 않기 때문

무튼 enum을 빼주고 함수를 마무리해보면

```swift
func filter(by type: APType) {
    apexPredators = apexPredators.filter { $0.type == type }
}
```

이번엔 강의와 달리 클로저를 통해 조금 더 코드를 간소화 시켜보았다.

### Toolbar 만들기

이것 역시도 툴바를 만들어본다.

이전에는 툴바에 Button을 달았다면 이번엔 Menu를 달아보려고 한다.

이때 알아두어야 하는건 현재 type은 enum을 보면 알겠지만 

```swift
case land
case air
case sea
```

이렇게 3개가 존재한다.

하지만 여기서 우리가 3개만 사용하는것이 아니다. 무슨말이나면 우리는 모두 보여주는 All이 필요하다.

즉 메뉴에선 4개가 있어야한다는것.

그래서 enum에서 all이라는 case를 하나더 추가해주기로 하자.

```swift
enum APType: String, Decodable {
    case all
    // 생략
    
    var background: Color {
        switch self {
        case .all: .black
        // 생략
        }
    }
    
    var icon: String {
        switch self {
        case .all: "square.stack.3d.up.fill"
        case .land: "leaf.fill"
        case .air: "wind"
        case .sea: "drop.fill"
        }
    }
}
```
menu에 사용할 icon도 여기에 추가를 해주도록 하자.

다시 Content View로 돌아와서

`@State var currentSelection = APType.all` 변수를 하나 만들어 준다.

Menu의 경우 [이전](https://haroldfromk.github.io/posts/ObjectTest/){:target="_blank"}에는 Button을 여러개 나열해서 만들었는데, 여기선 Picker를 사용한다.

```swift
Picker("Filter", selection: $currentSelection) {
    ForEach(APType.allCases) { type in
        Label(type.rawValue.capitalized, systemImage: type.icon)
    }
}
```

이렇게 Picker를 사용해주는데 이때 ForEach를 사용하기 위해서는 APType에 프로토콜을 또 추가해주어야 한다.

```swift
enum APType: String, Decodable, CaseIterable, Identifiable { // added
    // 생략
    var id: APType {
        self
    }
    // 생략
}
```

`CaseIterable, Identifiable` 두개의 프로토콜이 필요하다.

이건 이전에 언급을 한적이 있기에 패스...

![Image](https://github.com/user-attachments/assets/feea1256-262d-4d52-9f33-98c428acfb2b){: width="50%" height="50%"} 

그럼 이렇게 만들어지지만 아직 작동하지는 않는다

우리는 `filteredDinos` 변수를 다시 손봐줘야하기 때문

```swift
var filteredDinos: [ApexPredator] {
    predators.filter(by: currentSelection)
    
    predators.sort(by: alphabetical)
    return predators.search(for: searchText)
}
```

이렇게 필터 함수를 적용한것까지 해주었지만 보이지 않는다?

이유는 간단하다. json파일에는 all이라는 type을 가지고 있지 않는데 우리가 새롭게 만들어주었기 때문이다.

```swift
func filter(by type: APType) {
    if type == .all {
        
    } else {
        apexPredators = apexPredators.filter { $0.type == type }            
    }
}
```

이렇게 filter 함수를 손봐준다.

> all일때는 아무것도 작업을 행하지 않나요?
> 이유는 아무것도 안하면 init()에 의해 모든 데이터가 기본적으로 담기기 때문.

이제는 모두 보이게 된다.

### 문제 해결하기

하지만 아직 완전히 해결한건 아니다.

![Image](https://github.com/user-attachments/assets/f6cc341b-661b-41c5-bcf5-5eaf3047fa37){: width="50%" height="50%"} 

필터링이 단 1회성에서 끝나게 된다.

위에 all일때 아무것도 안한게 이제는 이유가 된다.

그걸 해결하기위해 


```swift 
class Predators {
    // 생략
    var allApexPredators: [ApexPredator] = []
    // 생략
    func decodeApexPredators() {
        if let url = Bundle.main.url(forResource: "jpapexpredators", withExtension: "json") {
            do {
                // 생략
                allApexPredators = try decoder.decode([ApexPredator].self, from: data) // changed
                apexPredators = allApexPredators // added
            } catch {
                print("Error deconding Json data: \(error)")
            }
        }
    }
    // 생략
}
``` 

전부를 담는 배열을 별도로 만들어 준다.

그리고 filter 함수를 수정해주자

```swift
func filter(by type: APType) {
    if type == .all {
        apexPredators = allApexPredators // added
    } else {
        apexPredators = allApexPredators.filter { $0.type == type } // changed
    }
}
```

![Image](https://github.com/user-attachments/assets/29447653-df2d-455f-9e72-5cba5cdb40ac){: width="50%" height="50%"} 

이제는 문제없이 작동이 된다.

결국 문제의 핵심은 `apexPredators` 하나의 배열만을 사용해 필터링을 하다 보니, **원본 데이터로 되돌아갈 방법이 없었던 것**이다.

하지만 이제 `allApexPredators`라는 **전체 데이터를 담고 있는 별도 배열**을 만들어둠으로써, 언제든지 초기 상태로 되돌아가거나, 다시 필터링을 적용할 수 있게 되었다.

이로써 필터링 기능이 **단발성에 그치지 않고 반복적으로 작동**할 수 있게 되었으며, 안정적으로 타입 기반 탐색이 가능한 구조가 완성되었다.

따라서 추후 다른 필터 조건이나 정렬 방식이 추가되더라도, **원본 데이터는 항상 안전하게 유지되기 때문에 유지보수에도 유리한 구조**라 할 수 있다.