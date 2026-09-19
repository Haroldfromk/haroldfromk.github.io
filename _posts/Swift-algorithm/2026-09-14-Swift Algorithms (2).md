---
title: Swift Algorithms (2) - Variables, Strings, Conditions
writer: Harold
date: 2026-09-14 11:06
categories: []
tags: []

toc: true
toc_sticky: true
---

## 문제 풀이 워밍업: Trapezoid(사다리꼴)

Playground에서 실제로 문제를 풀어보면서 몸을 푸는 첫 번째 예제다. 사다리꼴 `ABCD`의 네 변(`AB`, `BC`, `DC`, `AD`)의 길이와 넓이(`area`)가 주어졌을 때, 둘레(circumference)와 중간선(mid-segment) 길이, 높이(height)를 계산해서 반환하는 함수를 만든다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/trapezoid_diagram_fixed.png){: width="70%" height="70%"}

---

### 필요한 공식 정리하기

- **둘레**: 네 변의 길이를 그냥 더하면 된다 → `AB + BC + DC + AD`
- **mid-segment(중간선)**: 위 변(`AB`)과 아래 변(`DC`)의 평균이다 → `(AB + DC) / 2`
- **높이(height)**: 사다리꼴 넓이 공식이 `area = mid-segment × height`이므로, 여기서 높이를 거꾸로 구할 수 있다 → `height = area / mid-segment`

---

### trapezoid 함수 만들기

세 값을 한 번에 반환해야 하니 named tuple을 쓴다.

```swift
func trapezoid(AB: Double, BC: Double, DC: Double, AD: Double, area: Double) -> (circumference: Double, midSegment: Double, height: Double) {
    let circumference = AB + BC + DC + AD
    let midSegment = (AB + DC) / 2
    let height = area / midSegment

    return (circumference, midSegment, height)
}
```

반환 타입을 그냥 `(Double, Double, Double)`로 적을 수도 있지만, 그러면 호출부에서 어떤 값이 뭘 의미하는지 알기 어렵다. `(circumference: Double, midSegment: Double, height: Double)`처럼 각 요소에 이름을 붙인 named tuple을 쓰면, 결과를 받을 때 `.circumference`, `.midSegment`, `.height`로 바로 접근할 수 있어서 훨씬 읽기 좋다.

---

### 실행해보기

```swift
print(trapezoid(ab: 20, bc: 10, dc: 35, ad: 15, area: 220))
```

이 값들을 넣고 실행하면 `circumference: 80.0`, `midSegment: 27.5`, `height: 8.0`이 반환된다. `20 + 10 + 35 + 15 = 80`, `(20 + 35) / 2 = 27.5`, `220 / 27.5 = 8`로 손으로 계산해봐도 정확히 맞아떨어진다.

Playground의 자동 실행(auto-run) 모드를 켜두면, 입력값을 바꿀 때마다 결과가 즉시 갱신되는 걸 확인할 수 있어서 여러 값으로 빠르게 실험해보기 좋다. 다만 입력한 네 변의 길이가 실제로 기하학적으로 성립 가능한 사다리꼴인지는 이 함수가 검증하지 않는다. 이 부분은 나중에 SwiftUI로 사다리꼴을 실제로 그려보는 섹션에서 다룬다.

---

## 문자열로 표현된 숫자의 나눗셈 판별하기

이번 문제는 문자열로 표현된 숫자(`number`)가 정수 `n`으로 나누어떨어지는지 판별하는 함수를 만드는 것이다. `number`가 실제로는 숫자가 아닌 문자열일 수도 있다는 게 핵심 변수다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/number_divisible_flow_fixed.png){: width="70%" height="70%"}

---

### numberDivisibleByN(number:n:) 함수 만들기

```swift
func numberDivisibleByN(number: String, n: Int) -> Bool {
    if n == 0 {
        print("\(n) must be non-zero.")
        return false
    }

    guard let num = Int(number) else {
        print("#"Number "\#(number)" is not a valid input."#")
        return false
    }

    return num % n == 0
}
```

단계별로 짚어보면 이렇다.

- **`n == 0` 체크**: 0으로 나누는 건 애초에 불가능하니 먼저 걸러내고 `false`를 반환한다
- **`Int(number)`로 변환**: `String`을 `Int`로 바로 변환하면 `Int?`(optional)가 반환된다. `number`가 `"hummus"`처럼 숫자가 아닌 문자열이면 변환이 실패해서 `nil`이 나오기 때문이다. `guard let`으로 변환에 성공했을 때만(`num`이 non-optional로 확보됐을 때만) 다음 로직으로 넘어가고, 실패하면 `else` 블록에서 에러 메시지를 출력하고 `false`를 반환한다
- **나머지 연산**: 여기까지 통과했으면 `num % n == 0`으로 나누어떨어지는지 판별해서 그대로 반환한다

---

### raw string과 string interpolation

에러 메시지에서 `number` 값을 따옴표로 감싸서 출력하고 싶을 때, 두 가지 방법이 있다.

```swift
print("Number \"\(number)\" is not a valid input.")     // 이스케이프 사용
print(#"Number "\#"Error: "\#(number)" is not a valid input."#)     // raw string 사용
```

일반 문자열에서는 `\"`처럼 백슬래시로 따옴표를 이스케이프해야 하는데, `#"..."#`로 감싸는 raw string을 쓰면 그 안의 문자를 있는 그대로 취급해서 백슬래시 없이 `"`를 바로 쓸 수 있다. 대신 raw string 안에서는 string interpolation(`\(...)`)도 기본적으로는 그냥 텍스트로 처리되기 때문에, interpolation을 쓰려면 `\#(...)`처럼 `#`을 하나 더 붙여줘야 한다.

---

### 결과 출력용 함수 추가하기

```swift
func printNumberDivisible(number: String, n: Int) {
    if numberDivisible(number: number, n: n) {
        print("I am \(number) and I am divisible by \(n)")
    } else {
        print("I am \(number) and I am not divisible by \(n)")
    }
}
```

---

### 테스트

```swift
printNumberDivisible(number: "49", n: 7)
printNumberDivisible(number: "-14", n: 7)
printNumberDivisible(number: "hummus", n: 7)
printNumberDivisible(number: "31", n: 0)
```

결과는 각각 "49는 7로 나누어떨어짐", "-14도 7로 나누어떨어짐", "hummus는 유효한 입력이 아님", "0으로는 나눌 수 없음"으로 출력된다. 에러 메시지를 출력하는 대신 그냥 `true`/`false`만 반환하도록 단순화할 수도 있는데, 그러면 함수 호출 네 번에 결과 네 줄로 훨씬 깔끔해진다.

---

## 여러 구현 방식 비교하기

같은 `numberDivisible` 문제를 여러 방식으로 다시 구현해보면서, 코드 스타일과 안전성 사이의 트레이드오프를 살펴본다.

---

### 두 번째 구현: if let 한 줄로

```swift
func numberDivisibleByN2(number: String, n: Int) -> Bool {
    if let num = Int(number), n != 0, num % n == 0 {
        return true
    } else {
        return false
    }
}
```

`if let`에 콤마로 여러 조건을 이어붙이는 방식이다. 문자열이 숫자로 변환되는지, `n`이 0이 아닌지, 나누어떨어지는지를 한 번에 검사한다. 동작은 정확하지만, 조건이 한 줄에 몰려있어서 가독성 면에서는 아쉽다는 평가다.

---

### 세 번째 구현: force unwrap 한 줄

```swift
func numberDivisibleByN3(number: String, n: Int) -> Bool {
    Int(number) != nil && n != 0 && Int(number)! % n == 0
}
```

`Int(number) != nil`로 변환 가능 여부를 먼저 확인한 다음, `Int(number)!`로 강제 언래핑해서 쓰는 방식이다. 이미 `nil`이 아님을 확인했으니 강제 언래핑이 crash로 이어지지는 않지만, 같은 변환을 두 번(`Int(number) != nil`과 `Int(number)!`) 하고 있는 데다 force unwrap 자체가 읽는 사람 입장에서 불안하게 느껴질 수 있다는 게 이 방식의 단점이다. 짧다고 해서 항상 좋은 코드는 아니라는 걸 보여주는 예시다.

---

### 조건 순서가 중요한 이유: short-circuit 평가

`&&`로 여러 조건을 이어 쓸 때는 평가 순서가 왼쪽에서 오른쪽으로 진행되고, 앞 조건이 `false`면 뒤 조건은 아예 평가하지 않는다(short-circuit). 그래서 `n != 0`을 반드시 `num % n == 0`보다 먼저 검사해야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/short_circuit_order_fixed.png){: width="80%" height="80%"}

`n != 0 && num % n == 0`처럼 순서를 지키면, `n`이 0일 때 `num % n` 자체가 아예 평가되지 않아서 0으로 나누는 crash를 원천 차단한다. 반대로 `num % n == 0 && n != 0`처럼 순서를 바꾸면, `n`이 0일 때 `n != 0` 체크에 도달하기도 전에 `num % n`에서 먼저 crash가 난다.

---

### optional을 반환하는 버전 만들기

지금까지 만든 함수들은 `number`가 유효하지 않은 문자열일 때 그냥 `false`를 반환했는데, 이건 살짝 어색하다. "hummus는 7로 나누어떨어지지 않는다"는 문장 자체가 이상하기 때문이다. 애초에 숫자가 아닌 값에 대해 나누어떨어지는지 여부를 말하는 게 말이 안 되므로, 이런 경우엔 `false`가 아니라 `nil`을 반환하는 게 더 적절하다.

```swift
func numberDivisibleByNOptional(number: String, n: Int) -> Bool? {
    guard let num = Int(number) else {
        return nil
    }

    // check if num is divisible by n and check that n != 0
    return n != 0 && num % n == 0 
}
```

`guard let`으로 숫자 변환에 실패하면 `nil`을 반환해서 "이 질문 자체가 성립하지 않는다"는 걸 명확히 드러낸다. 변환에 성공하면, `isDivisible`이라는 이름 있는 상수로 조건을 한 번 정리해서 가독성을 높였다. `!=`와 `==`이 한 줄에 같이 있으면 어떤 게 참 조건인지 헷갈릴 수 있어서, 이렇게 이름을 붙여 중간 변수로 빼는 것도 방법이다.

---

### optional 반환값 다루기

```swift
func printNumberDivisibleByNOptional(number: String, n: Int) {
    guard let result = numberDivisibleByNOptional(number: number, n: n) else {
        print(#"ERROR: "\#(number)" is not a valid input."#)
    return

    // result is either true or false
    let useNot = result ? "" : "NOT "

    print("I am \(number) and I am \(useNot)divisible by \(n)")
    }
}
```

`numberDivisibleOptional`의 결과를 `guard let`으로 받는다. `nil`이면(숫자가 아니면) 에러 메시지를 출력하고 종료하고, 값이 있으면(`true`/`false` 둘 중 하나) 그 값에 따라 "not "이라는 단어를 넣을지 말지를 삼항 연산자로 결정해서 자연스러운 문장을 만든다.

`"hummus"`를 넣으면 "hummus is not a valid input"이라는 정확한 메시지가 나오고, 유효한 숫자를 넣으면 "I am 49 and I am divisible by 7"처럼 자연스러운 문장이 만들어진다.

`n == 0`인 경우를 어떻게 처리할지는 여전히 고민할 여지가 있다. 지금은 `isDivisible`이 그냥 `false`가 되지만, 이것도 사실 "나누어떨어지지 않는다"보다는 "애초에 0으로 나눌 수 없다"는 별도의 에러 케이스로 다루는 게 더 정확할 수 있다. 이런 경우까지 세밀하게 구분하려면 `enum`으로 결과 타입을 확장하는 방법도 있지만, 실무에서는 상황에 따라 optional 없는 단순한 버전을 쓰는 경우도 많다.

---

## 문자열 홀짝 인덱스로 재구성하기: strangeRepeat

문자열 `text`와 반복 횟수 `copies`가 주어졌을 때, `text`의 홀수 인덱스 문자들로 만든 문자열과 짝수 인덱스 문자들로 만든 문자열을 이 순서(홀수 먼저, 짝수 다음)로 이어붙이고, 그 결과를 `copies`번 반복하는 문제다. 인덱스는 0부터 시작하므로 0은 짝수로 취급한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/strange_repeat_diagram_fixed.png){: width="80%" height="80%"}

---

### 문자열을 배열로 바꿔서 인덱스 접근하기

Swift의 `String`은 정수 인덱스로 바로 subscript 접근이 안 되기 때문에(`String.Index`를 써야 한다), 배열로 변환해서 인덱스 접근을 편하게 만든다.

```swift
let textAsArray = Array(text)
```

이모지가 섞인 문자열의 경우 문자 하나의 바이트 크기가 균일하지 않아서 더 복잡해질 수 있다는 점도 짚고 넘어간다. `Array(text)`로 변환하면 이런 문제를 신경 쓰지 않고 `Character` 단위로 순회할 수 있다.

---

### 홀수/짝수 인덱스 문자열 만들기

```swift
var oddString = ""
for i in stride(from: 1, to: textAsArray.count, by: 2) {
    oddString += String(textAsArray[i])
}

var evenString = ""
for i in stride(from: 0, to: textAsArray.count, by: 2) {
    evenString += String(textAsArray[i])
}
```

`stride(from:to:by:)`로 홀수는 1부터, 짝수는 0부터 2씩 건너뛰며 순회한다. `textAsArray[i]`는 `Character` 타입이라 `String`과 바로 `+`로 이어붙일 수 없어서, `String(textAsArray[i])`로 감싸서 문자열로 변환한 뒤 이어붙인다.

---

### 결합하고 반복하기

```swift
func strangeRepeat(text: String, copies: Int) -> String {

    let textAsArray = Array(text)

    // Create odd string
    var oddString = ""
    for i in stride(from: 1, to: textAsArray.count, by: 2) {
        oddString += String(textAsArray[i])
    }

    // Create even string
    var evenString = ""
    for i in stride(from: 0, to: textAsArray.count, by: 2) {
        evenString += String(textAsArray[i])
    }

    /*
    // Concatenate
    let combinedString = oddString + evenString
    */

    return String(repeating: oddString + evenString, count: copies)
}
```

`String(repeating:count:)`는 Swift 표준 라이브러리가 제공하는 이니셜라이저로, 주어진 문자열을 지정한 횟수만큼 반복한 새 문자열을 만들어준다.

이 로직을 더 짧게 한 줄로 압축할 수도 있다(`oddString`, `evenString`을 별도 변수에 담지 않고 바로 결합해서 반환하는 식). 강사 본인은 짧은 버전을 실제로 쓰겠다고 했지만, 중간 변수를 두는 버전이 더 읽기 쉽다는 점도 함께 짚었다. 어느 쪽이 낫다고 단정하기보다는, 둘 다 시간 복잡도상으로는 동일하다는 게 핵심이다.

---

### 테스트

```swift
print(strangeRepeat(text: "hello", copies: 1))  // "elhlo"
print(strangeRepeat(text: "hello", copies: 2))  // "elhloelhlo"
print(strangeRepeat(text: "hello", copies: 3))  // "elhloelhloelhlo"
```

`"hello"`에서 홀수 인덱스(1, 3)는 `e`, `l`로 `"el"`을, 짝수 인덱스(0, 2, 4)는 `h`, `l`, `o`로 `"hlo"`를 만든다. 이 둘을 홀수 먼저 순서로 합치면 `"elhlo"`가 되고, `copies`만큼 반복된다. 이모지가 섞인 문자열로 테스트해도 동일하게 잘 동작하는 걸 확인할 수 있다.

---

## 문자열을 Q에서 잘라 각각 뒤집기: reverseSplit

문자열 `name`과 정수 `Q`가 주어졌을 때, `name`을 인덱스 `Q`를 기준으로 두 부분으로 나누고(`0..<Q`와 `Q..<count`), 각 부분을 뒤집은 다음 공백으로 이어붙여 반환하는 문제다.

**유효하지 않은 입력**: `Q`가 음수이거나, `Q`가 `name`의 길이보다 작지 않거나(즉 `Q >= name.count`), `name`이 빈 문자열이면 유효하지 않은 입력으로 보고 `nil`을 반환한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/reverse_split_diagram.png){: width="80%" height="80%"}

---

### 유효성 검사와 기본 구조

```swift
func reverseSplit(name: String, q: Int) -> String? {
    // Valid input ?
    if q < 0 || name.isEmpty || q >= name.count {
        print("Error - Illegal input!")
        return nil
    }

    var str1 = ""
    var str2 = ""

    for (i, ch) in name.enumerated() {
        if i < q {
            // Create str1 and reverse
            str1 = String(ch) + str1
        } else {
            // Create str2 and reverse
            str2 = String(ch) + str2
        }
    }

    return "\(str1) \(str2)"
}
```

세 가지 조건 중 하나라도 해당하면 `nil`을 반환하고 함수를 종료한다. 반환 타입을 `String?`(optional)로 둔 이유가 바로 이거다.

---

### 순회하면서 동시에 뒤집기

여기서 흥미로운 부분은 `name.enumerated()`로 인덱스(`i`)와 문자(`ch`)를 함께 순회하면서, 먼저 두 substring을 따로 만든 다음 나중에 뒤집는 게 아니라 순회하는 과정 자체에서 이미 뒤집힌 상태로 문자열을 만든다는 것이다.

```swift
if i < q {
    str1 = String(ch) + str1
} else {
    str2 = String(ch) + str2
}
```

`str1 += String(ch)`처럼 뒤에 붙이는 대신, `str1 = String(ch) + str1`로 **새 문자를 항상 맨 앞에** 붙인다. 그러면 루프가 끝났을 때 `str1`, `str2` 둘 다 이미 뒤집힌 상태가 된다. 순회가 끝난 뒤 별도로 `.reversed()`를 호출할 필요가 없어서, 한 번의 순회로 분리와 뒤집기를 동시에 처리하는 효율적인 방식이다.

---

### 결과 합치기

```swift
return "\(str1) \(str2)"
```

문자열 concatenation 대신 string interpolation을 쓰는 편이 더 깔끔하다는 의견도 함께 제시됐다. 둘 다 기능적으로는 동일하지만, 가독성 면에서 interpolation 쪽을 선호한다는 것.

---

### 테스트하면서 발견한 것들

`Q`를 -1부터 시작해서 여러 값으로 바꿔가며 테스트해봤다. 이때 몇 가지가 확인됐다.

- `Q = -1`일 때는 음수라서 곧바로 실패한다
- `Q = 0`일 때는 `sub1`이 빈 문자열인 채로도 로직 자체는 문제없이 정상 동작한다
- `Q`가 5 이상이면 실패한다. `"hello"`의 길이가 5라서, `Q >= name.count` 조건에 걸리기 때문이다
- `name`을 빈 문자열로 바꾸면, `Q`에 어떤 값을 넣어도 전부 유효하지 않은 입력으로 처리된다

에러 메시지를 함수 안에서 출력하는 것과, 호출부에서 결과가 `nil`일 때 별도로 메시지를 출력하는 것을 동시에 하면 같은 에러가 중복 출력되는 문제도 짚었다. 함수 자체는 값을 반환하는 역할에만 집중하고, 에러 메시지 출력 같은 부수 효과는 호출부에서 처리하는 쪽이 더 깔끔하다는 게 이 경험에서 나온 결론이다.

---

## SwiftUI로 알고리즘 문제들 보여주기: 기록할 만한 패턴만

지금까지 만든 알고리즘 문제들을 실제로 SwiftUI 앱으로 보여주는 과정을 진행한다. `NavLink` → `ViewWithHelp` → `CardView`로 이어지는 화면 구조를 만드는데, 대부분은 익숙한 SwiftUI 조합이라 그중 따로 기록해둘 만한 패턴 하나만 남긴다.

---

### Blur + Disabled + 조건부 오버레이로 자체 팝업 만들기

`.sheet`나 `.alert` 대신, 지금 보고 있는 화면 위에 흐림 효과를 주고 카드를 얹는 방식으로 도움말 팝업을 구현했다.

```swift
struct ViewWithHelp<Content: View>: View {
    let content: Content
    let information: Information

    @State private var isPresented = false

    var body: some View {
        ZStack {
            content
                .blur(radius: isPresented ? 8 : 0)
                .disabled(isPresented)

            if isPresented {
                CardView(isPresented: $isPresented, information: information)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { isPresented.toggle() }
                } label: {
                    Image(systemName: "info.circle.fill")
                }
            }
        }
    }
}
```

핵심은 세 가지 조합이다.

- `content.blur(radius:)`로 뒤에 있는 실제 화면을 흐리게 처리
- `.disabled(isPresented)`로 흐려진 화면이 터치에 반응하지 않도록 차단
- `isPresented`가 `true`일 때만 `ZStack` 위층에 `CardView`를 조건부로 얹기

`isPresented`는 `@State`로 부모(`ViewWithHelp`)가 갖고, `$isPresented` 바인딩을 자식(`CardView`)에게 그대로 넘긴다. 그래서 toolbar의 info 버튼과 카드 내부의 OK 버튼, 두 개의 서로 다른 트리거가 같은 상태 하나를 공유하면서 열고 닫을 수 있다.

`.sheet`처럼 화면을 완전히 새로 띄우는 대신, "지금 보던 화면 위에 살짝 흐리게 깔고 카드만 얹는" 느낌을 내고 싶을 때 재사용할 만한 패턴이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/test12.gif){: width="50%" height="50%"}

---

## TrapezoidView 만들기: 기록할 만한 패턴만

`trapezoid` 함수의 계산 결과를 슬라이더로 조작 가능한 인터랙티브 도형으로 보여주는 View를 만든다. 대부분은 레이아웃 디테일이라, 그중 두 가지 패턴만 기록해둔다.

---

### Canvas API로 도형 직접 그리기

SwiftUI의 `Canvas`를 쓰면 `Shape` 프로토콜 없이도, 슬라이더 값에 따라 실시간으로 바뀌는 임의의 도형을 직접 그릴 수 있다.

```swift
Canvas { context, size in
    let width = size.width
    let height = size.height

    let lowerLeft = CGPoint(x: 0, y: height * h)
    let lowerRight = CGPoint(x: width * bottom, y: height * h)
    let upperRight = CGPoint(x: width * (top + shiftTop), y: 0)
    let upperLeft = CGPoint(x: width * shiftTop, y: 0)

    var path = Path()
    path.move(to: lowerLeft)
    path.addLine(to: lowerRight)
    path.addLine(to: upperRight)
    path.addLine(to: upperLeft)
    path.addLine(to: lowerLeft)

    context
        .stroke(path, with: .color(.red), lineWidth: 5)
    context
        .fill(path, with: .color(.orange.opacity(0.3)))
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/trapezoid_canvas_coords_fixed.png){: width="80%" height="80%"}

`context`와 `size`를 받는 클로저 안에서 `Path`를 직접 구성하고, `context.fill(_:with:)`(또는 `stroke`)로 그린다. `top`, `bottom`, `height`, `shiftTop` 같은 슬라이더 바인딩 값(전부 0~1 사이로 정규화된 값)에 `size.width`/`size.height`를 곱해서 실제 픽셀 좌표로 스케일링하는 방식이다. Canvas 좌표계는 원점이 좌상단이고 y가 아래로 갈수록 증가한다는 점만 주의하면, 슬라이더 값이 바뀔 때마다 도형이 실시간으로 다시 그려지는 인터랙티브 다이어그램을 어렵지 않게 만들 수 있다. 커스텀 게이지나 다이어그램이 필요한 화면에 재사용할 만한 패턴이다.

---

### Optional 계산 프로퍼티로 슬라이더를 조건부로 숨기기

`shiftTop` 슬라이더가 움직일 수 있는 최대 범위를 계산하는데, 더 이상 움직일 여유가 없으면 슬라이더 자체를 화면에서 사라지게 만든다.

```swift
var shiftTopMax: Double? {
    let remaining = 1 - top
    return remaining > 0 ? remaining : nil
}
```

```swift
if let shiftTopMax {
    Slider(value: $shiftTop, in: 0...shiftTopMax)
}
```

값이 있으면(`0` 초과) 그 값을 슬라이더의 상한으로 쓰고, 남은 공간이 없으면(`nil`) `if let`이 실패하면서 슬라이더 자체가 뷰 계층에서 통째로 빠진다. "값이 없으면 이 컨트롤 자체가 의미 없다"는 상황을, 별도의 `isHidden` 플래그 없이 optional 하나로 값과 표시 여부를 동시에 표현하는 방식이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/result1.gif){: width="50%" height="50%"}

---

## NumberDivisibleByNView / StrangeRepeatView / ReverseSplitView: 기록할 만한 패턴만

`numberDivisible`, `strangeRepeat`, `reverseSplit` 세 문제를 각각 인터랙티브 화면으로 만든다. 셋 다 "텍스트 입력 + 슬라이더로 파라미터 조절 + 실시간 결과 표시"라는 같은 구조를 반복하는데, 그중 재사용할 만한 패턴 두 가지만 남긴다.

---

### Slider는 Double만 받는다: Int 도메인 값과 다리 놓기

`Slider`는 `value`로 `Double` 바인딩만 받는데, 실제 로직(`numberDivisible(number:n:)`, `reverseSplit(name:q:)`)은 `Int`를 요구한다. 그래서 `@State`는 `Double`로 갖고, 로직에 넘길 때만 `Int`로 변환하는 계산 프로퍼티를 하나 더 둔다.

```swift
@State private var n: Double = 6

var intN: Int {
    Int(n)
}

// 생략

Slider(value: $n, in: 1...maxDivisor, step: 1)
```

`Slider`에는 `$n`(Double)을 그대로 바인딩하고, `part1Problems.numberDivisibleOptional(number:n:)` 같은 함수를 호출할 때만 `intN`을 넘긴다. UI 레이어는 `Double`, 도메인 로직은 `Int`로 역할을 나눠서, 매번 타입 캐스팅을 흩뿌리지 않고 계산 프로퍼티 하나로 정리하는 방식이다.

---

### Slider 범위가 무너지면 crash한다

`ReverseSplitView`에서 `Q` 슬라이더의 상한을 `name.count`에 맞춰 동적으로 계산했는데, 텍스트를 지워가며 테스트하다가 `name.count`가 1 이하로 줄어드는 순간 앱이 죽는 걸 발견했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/CleanShot_16-12.1552.png){: width="50%" height="50%"}

---

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-14-Swift-Algorithms-2/slider_range_crash_fixed.png){: width="85%" height="85%"}

```swift
if name.count > 1 {
    VStack(alignment: .leading, spacing: 5) {
        Text("q = \(Int(q))")
            .bold()
        Slider(value: $q, in: 1...Double(name.count), step: 1)
    }
}
```

`Slider(value:in:)`의 범위는 항상 `lowerBound <= upperBound`를 만족해야 하는데, 상한이 사용자 입력(`name.count`)에 의존하는 경우 그 값이 하한 밑으로 내려가는 순간 범위 자체가 깨져버린다. `if name.count > 1`로 `Slider`뿐 아니라 그 위의 `Text("q = ...")` 라벨까지 묶어서 통째로 조건부 처리한 게 포인트다. 라벨만 남기고 슬라이더만 감추면 오히려 더 어색해지기 때문에, "이 입력을 받을 수 없는 상태"에서는 관련 UI 요소 전체를 하나의 단위로 묶어서 함께 감추는 게 자연스럽다.

Trapezoid View에서 썼던 "optional 계산 프로퍼티로 슬라이더를 숨기는" 패턴과 본질적으로 같은 문제인데, 여기서는 슬라이더 범위가 동적인 입력값에 의존할 때 항상 유효성을 검증해야 한다는 걸 실제 crash로 재확인한 사례다. 입력값에 따라 범위가 움직이는 슬라이더를 만들 때는 이 검증을 빠뜨리기 쉽다는 점을 기억해둘 만하다.