---
title: Swift Algorithms (7) - Recursion
writer: Harold
date: 2026-09-18 12:06
categories: []
tags: []

toc: true
toc_sticky: true
---

## Part 5: Recursion 시작하기

Recursion(재귀)을 다루는 새 섹션이다. 재귀 함수는 자기 자신을 호출하는 정의를 가진 함수이고, 언젠가 멈추게 만드는 조건(base case)이 반드시 있어야 한다.

전형적인 예가 factorial이다. 반복문으로 짜면 `n! = 1 × 2 × 3 × ... × n`이지만, 재귀적으로 정의하면 이렇다.

```
0! = 1                  (base case)
n! = n × (n-1)!         (재귀 정의)
```

`3!`을 계산해보면, `3! = 3 × 2!`인데 `2!`을 알아야 하고, `2! = 2 × 1!`인데 `1!`을 알아야 하고, `1! = 1 × 0!`인데 `0!`은 정의상 `1`이다. 여기서부터 거꾸로 값이 확정되며 올라온다. `0! = 1` → `1! = 1 × 1 = 1` → `2! = 2 × 1 = 2` → `3! = 3 × 2 = 6`. 재귀 해법은 우아할 때도 있지만 비효율적일 때도 있는데, 그 비효율은 이후 Memoization 섹션에서 다룬다.

---

## reverseString 챌린지

문자열을 받아서 문자 순서를 뒤집은 문자열을 반환하는 재귀 함수를 만든다. Swift 표준 라이브러리의 `reversed()` 같은 내장 함수는 쓸 수 없다.

---

### 테스트부터 작성하기: 이모지를 포함시킨 이유

구현 전에 테스트를 먼저 썼다. 이때 일부러 이모지를 테스트 데이터에 포함시켰다.

```swift
func testReverseString() {
    let str1 = "Hello🛳️ World!🙃"
    let str2 = "🙃"
    let str3 = ""
    let str4 = "abcd"
    let str5 = "abcde"

    let expectedValue1 = "🙃!dlroW 🛳️olleH"
    let expectedValue2 = "🙃"
    let expectedValue3 = ""
    let expectedValue4 = "dcba"
    let expectedValue5 = "edcba"

    XCTAssertEqual(part5Problems.reverseString(str: str1), expectedValue1)
    XCTAssertEqual(part5Problems.reverseString(str: str2), expectedValue2)
    XCTAssertEqual(part5Problems.reverseString(str: str3), expectedValue3)
    XCTAssertEqual(part5Problems.reverseString(str: str4), expectedValue4)
    XCTAssertEqual(part5Problems.reverseString(str: str5), expectedValue5)
}
```

예전 ASCII 시대에는 문자 하나가 항상 고정된 바이트 크기였지만, 지금은 이모지처럼 문자 하나의 크기가 일정하지 않은 경우가 많아서 문자열 처리 시 문제가 될 수 있다. 이런 문제를 미리 잡아내기 위해 테스트 데이터에 이모지를 일부러 섞어뒀다. 빈 문자열, 한 글자, 여러 글자 케이스도 함께 포함시켰다.

---

### 첫 번째 구현: inout 헬퍼 함수로 스택이 풀리는 순서 이용하기

```swift
static func reverseStringWithHelperFunction(str: String) -> String {
    var charArray = Array(str)
    reverseStringHelper(charArray: &charArray)
    return String(charArray)

    func reverseStringHelper(charArray: inout [Character]) {
        if charArray.count <= 1 {
            return
        } else {
            let first: Character = charArray.removeFirst()
            reverseStringHelper(charArray: &charArray)
            charArray.append(first)
        }
    }
}
```

`reverseStringHelper`는 값을 반환하는 대신 `inout` 파라미터로 배열을 직접 변경한다. 원소가 1개 이하면(base case) 아무것도 안 하고 리턴한다. 그렇지 않으면 첫 글자를 `removeFirst()`로 떼어내고, **재귀 호출이 끝날 때까지 기다렸다가** 그 다음에 떼어낸 글자를 배열 맨 뒤에 `append`한다.

이게 흥미로운 이유는, "떼어내는" 동작은 재귀가 깊어지는(스택이 쌓이는) 순서로 일어나고, "붙이는" 동작은 재귀가 되돌아오는(스택이 풀리는) 순서로 일어난다는 것이다. `"abc"`로 추적해보면, `'a'`를 떼고 재귀(`"bc"`)를 먼저 끝낸 뒤에 `'a'`를 맨 뒤에 붙이고, `"bc"`도 마찬가지로 `'b'`를 떼고 재귀(`"c"`)를 끝낸 뒤 `'b'`를 붙인다. 가장 안쪽(`"c"`)부터 시작해서 `append('c')` → `append('b')` → `append('a')` 순서로 붙으면서, 결과적으로 `['c', 'b', 'a']`가 만들어진다. 스택이 풀리는 순서 자체를 이용해서 순서를 뒤집는 것이 이 구현의 핵심이다.

`reverseStringHelper`를 별도 함수로 밖에 두는 대신, `reverseStringWithHelperFunction` 안에 지역 함수(nested function)로 넣어서 바깥에서는 호출할 수 없게 캡슐화했다.

---

### 두 번째, 세 번째 구현: force unwrap 버전과 안전한 버전

```swift
static func reverseStringForceUnwrap(str: String) -> String {
    if str.isEmpty {
        return ""
    } else {
        let first: String = String(str.first!)
        let subStringReversed = reverseString(str: String(str.dropFirst()))
        return subStringReversed + first
    }
}

static func reverseString(str: String) -> String {
    if let first = str.first {
        let subStringReversed = reverseString(str: String(str.dropFirst()))
        return subStringReversed + String(first)
    } else {
        return ""
    }
}
```

이 두 버전은 접근 자체가 다르다. `str`이 비어있으면 그대로 `""`를 반환하고(base case), 아니면 첫 글자를 떼어내고 나머지(`str.dropFirst()`)에 대해 재귀 호출한 결과 뒤에 그 첫 글자를 붙인다. `subStringReversed + first`처럼 재귀 결과 **뒤에** 첫 글자를 붙이는 방식이라, 첫 번째 구현과 달리 `inout`이나 지역 함수 없이도 간결하게 같은 효과를 낸다.

`reverseStringForceUnwrap`은 `str.first!`로 강제 언래핑하는 버전이고, `reverseString`은 `if let first = str.first`로 안전하게 처리하는 버전이다. 둘은 기능적으로 동일하지만, 재귀 함수를 짤 때도 optional 안전성을 지키는 습관은 그대로 유지해야 한다는 걸 나란히 보여준다. 세 구현 모두 같은 테스트를 통과시켜서 서로 동일하게 동작함을 확인했다.

---

## findMax 챌린지

정수 리스트를 받아서 그중 최댓값을 재귀적으로 찾는 함수를 만든다. 리스트가 비어있으면 `nil`을 반환하고, Swift의 내장 `max` 함수는 쓸 수 없다.

---

### 테스트부터 작성하기

```swift
func testFindMax() {
    let ex1: [Int] = []
    let ex2: [Int] = [7]
    let ex3: [Int] = [-11, 5]
    let ex4: [Int] = [1, -2, 3, 5, 3]
    let ex5: [Int] = [1, -2, 3, 5, 3, 6]

    let max1: Int? = nil
    let max2: Int? = 7
    let max3: Int? = 5
    let max4: Int? = 5
    let max5: Int? = 6

    XCTAssertEqual(part5Problems.findMax(nums: ex1), max1)
    XCTAssertEqual(part5Problems.findMax(nums: ex2), max2)
    XCTAssertEqual(part5Problems.findMax(nums: ex3), max3)
    XCTAssertEqual(part5Problems.findMax(nums: ex4), max4)
    XCTAssertEqual(part5Problems.findMax(nums: ex5), max5)
}
```

빈 배열, 원소 1개, 원소 2개, 그리고 중복 값(`3`)이 섞인 케이스, 순서가 뒤섞인 케이스까지 다양하게 준비했다. 함수가 아직 `nil`만 반환하는 상태라 첫 번째 케이스(빈 배열 → `nil`)만 우연히 통과하고 나머지는 전부 실패하는 걸 확인하고 구현을 시작했다.

---

### 구현하기

```swift
static func findMax(nums: [Int]) -> Int? {
    if nums.isEmpty {
        return nil
    } else if nums.count == 1 {
        return nums[0]
    } else if nums.count == 2 {
        return nums[0] > nums[1] ? nums[0] : nums[1]
    } else {
        guard let maxTail = findMax(nums: Array(nums.dropFirst())) else {
            return nil
        }

        return nums[0] > maxTail ? nums[0] : maxTail
    }
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-18-Swift-Algorithms-7/find_max_recursion_fixed.png){: width="90%" height="90%"}

base case가 세 단계로 나뉜다.

- 빈 배열이면 `nil`
- 원소가 1개면 그 값 자체가 최댓값
- 원소가 2개면 굳이 재귀를 더 안 하고 바로 두 값을 비교해서 반환

원소가 3개 이상이면, 첫 원소(`nums[0]`)를 제외한 나머지(`nums.dropFirst()`)에 대해 재귀 호출해서 그 부분의 최댓값(`maxTail`)을 구하고, `nums[0]`과 `maxTail`을 비교해서 더 큰 쪽을 반환한다. `findMax`가 재귀 호출에서 `nil`을 반환할 가능성은 이론상 없지만(원소가 있는 리스트를 넘기니까), `guard let`으로 안전하게 처리해둔다.

---

### 겪었던 실수: 인덱스 오타

처음 코드를 작성할 때 `nums[0] > nums[1] ? nums[0] : nums[1]` 대신 실수로 `nums[0] > nums[2]`처럼 잘못된 인덱스를 썼다. 이 실수는 테스트를 돌리자마자 바로 실패로 드러났다. 미리 여러 케이스(특히 중복값이나 순서가 뒤섞인 배열)를 준비해뒀기 때문에, 오타를 수정하는 데 오래 걸리지 않았다. 오타를 고치고 다시 테스트를 돌리니 다섯 케이스 모두 통과했다.

또한 문제 조건에 "내장 `max` 함수는 쓸 수 없다"는 제약이 있었는데, 처음엔 무심코 `max(nums[0], maxTail)`처럼 쓸 뻔했다가, 삼항 연산자(`nums[0] > maxTail ? nums[0] : maxTail`)로 직접 비교하는 방식으로 바꿔서 이 제약을 지켰다.

---

## isPalindrome 챌린지: 정의를 명확히 하는 것부터 시작하기

문자열이 Palindrome(앞으로 읽어도 뒤로 읽어도 같은 문자열)인지 판별하는 재귀 함수를 만든다.

---

### 빈 문자열은 Palindrome인가: 정의를 직접 정하기

문제 지문 자체가 "Palindrome은 최소 한 글자를 가진다"고 전제하고 있어서, 빈 문자열을 어떻게 처리할지는 애매했다. 처음엔 "빈 문자열은 Palindrome이 아니다(`false`)"로 정의하고 시작했는데, 실제로 구현해보니 이 정의가 오히려 부자연스러웠다. 빈 문자열은 뒤집어도 여전히 빈 문자열이라 앞뒤가 똑같다는 논리로 보면, 빈 문자열도 Palindrome(`true`)으로 보는 게 더 일관성 있다고 판단해서 정의를 바꿨다. 이렇게 명세에 없거나 애매한 엣지 케이스를 어떻게 다룰지는, 구현하면서 직접 판단하고 명확히 문서화해야 하는 부분이다. 최종 정의는 "빈 문자열이면 `true`를 반환한다"로 정리했다.

---

### 테스트부터 작성하기

```swift
func testIsPalindrome() {
    let ex1 = "abcab"
    let ex2 = ""
    let ex3 = "abba"
    let ex4 = "aba"

    let expectedValue1 = false
    let expectedValue2 = true
    let expectedValue3 = true
    let expectedValue4 = true

    XCTAssertEqual(part5Problems.isPalindrome(str: ex1), expectedValue1)
    XCTAssertEqual(part5Problems.isPalindrome(str: ex2), expectedValue2)
    XCTAssertEqual(part5Problems.isPalindrome(str: ex3), expectedValue3)
    XCTAssertEqual(part5Problems.isPalindrome(str: ex4), expectedValue4)
}
```

Palindrome이 아닌 케이스(`"abcab"`), 빈 문자열, 그리고 짝수 길이(`"abba"`)와 홀수 길이(`"aba"`) Palindrome을 각각 테스트에 포함시켰다. 짝수/홀수 케이스를 둘 다 넣은 이유는, 혹시 어느 한쪽에서만 우연히 통과하고 다른 쪽에서는 실패하는 로직 결함이 있을 수 있기 때문이다. 함수가 아직 무조건 `true`만 반환하는 상태에서 테스트를 돌려보니, 예상대로 `false`가 기대되는 케이스(`ex1`)만 실패하고 나머지는 우연히 통과했다.

---

### 구현하기

```swift
static func isPalindrome(str: String) -> Bool {
    if str.count <= 1 {
        return true
    } else {
        let first = str.first
        let last = str.last

        if first != last {
            return false
        } else {
            let begin = str.index(after: str.startIndex)
            let end = str.index(before: str.endIndex)
            let range = begin..<end
            let newString = String(str[range])

            return isPalindrome(str: newString)
        }
    }
}
```

로직을 정리하면 이렇다.

- 문자열 길이가 0 또는 1이면(base case) 무조건 `true`. 글자가 없거나 하나뿐이면 뒤집어도 같기 때문이다
- 첫 글자와 마지막 글자가 다르면 그 즉시 `false`
- 같다면, 양 끝 글자를 제거한 나머지 부분 문자열에 대해 재귀적으로 다시 확인한다. `str.index(after:)`로 시작 다음 인덱스를, `str.index(before:)`로 끝 이전 인덱스를 구해서, 그 사이 범위(`begin..<end`)만 잘라낸 새 문자열을 만든다

`"abba"`로 예를 들면, 양 끝(`'a'`, `'a'`)이 같으니 가운데(`"bb"`)만 남겨서 다시 확인하고, `"bb"`도 양 끝이 같으니 그 가운데(빈 문자열)를 확인하면 base case에 걸려 `true`가 나온다.

---

### 읽기 쉬운 코드로 유지하기

이 로직을 한 줄로 완전히 압축하는 것도 가능했지만(`begin`, `end`, `range`, `newString` 같은 중간 변수를 다 없애고 표현식을 한 줄에 몰아넣는 식), 일부러 그렇게 하지 않았다. 코드를 짧게 줄이는 게 기술적으로 더 있어 보일 수는 있어도, 실제로 버그가 생겼을 때 디버깅하기 어려워지고 타이핑하는 과정에서도 실수하기 쉽다. 코드가 왜 짧아야 하는지에 대한 뚜렷한 이유가 없다면, 중간 변수 몇 개를 더 두더라도 읽고 이해하기 쉬운 형태를 유지하는 쪽을 택했다.

---

## climbCombinations 챌린지: 손으로 패턴을 찾아 Fibonacci에 도달하기

`n`개의 계단을 오르는데, 한 번에 1칸 또는 2칸씩 오를 수 있다고 할 때, 계단을 전부 오르는 방법의 수를 재귀적으로 구한다.

---

### 손으로 작은 케이스부터 풀어보며 패턴 찾기

바로 코드를 짜기 전에, `n`이 작은 경우부터 손으로 세어보면서 규칙을 찾아봤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-18-Swift-Algorithms-7/staircase_three_panels_v5.png){: width="95%" height="95%"}

- `n = 1`: 방법은 1가지 (한 칸)
- `n = 2`: 방법은 2가지 (두 칸을 한 번에, 또는 한 칸씩 두 번)
- `n = 3`: 방법은 3가지 (2+1, 1+1+1, 1+2)

`n = 3`을 세면서 중요한 관찰이 나왔다. 첫걸음을 1칸으로 시작하면 남은 건 2칸(`n=2`의 경우와 같음), 첫걸음을 2칸으로 시작하면 남은 건 1칸(`n=1`의 경우와 같음)이라는 것. 즉 **첫걸음이 1칸이냐 2칸이냐에 따라 문제가 더 작은 같은 문제로 쪼개진다.**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-18-Swift-Algorithms-7/climb_stairs_recurrence_fixed.png){: width="90%" height="90%"}

이 관찰을 `n = 4`에 적용해보면, 첫걸음이 1칸이면 남은 계단은 3칸(`climbCombinations(3)`), 첫걸음이 2칸이면 남은 계단은 2칸(`climbCombinations(2)`)이 되고, 이 둘을 더하면 전체 경우의 수가 나온다. `n=3`이 3가지, `n=2`가 2가지이므로 `n=4`는 `3 + 2 = 5`가지다. 실제로 `n=10`일 때 89가지라는 힌트도 주어졌는데, 이 규칙을 계속 적용해서 손으로 확인해볼 수 있다. 이 점화식은 사실 Fibonacci 수열과 똑같은 패턴이다.

---

### 짧은 구현

```swift
static func climbCombinations(n: Int) -> Int {
    n < 3 ? n : climbCombinations(n: n - 1) + climbCombinations(n: n - 2)
}
```

`n`이 3보다 작으면(즉 0, 1, 2) `n` 자체가 답이고, 그렇지 않으면 방금 찾은 점화식 그대로 `climbCombinations(n-1) + climbCombinations(n-2)`를 반환한다. 삼항 연산자 하나로 함수 전체가 한 줄에 담기는, 꽤 우아한 형태다.

---

### 겪었던 문제: 음수를 넣었더니 무한 재귀

이 함수가 실제로 어디까지 안전한지 확인해보려고 일부러 음수(`-3`)를 넣어봤다. 결과는 프로그램이 멈추지 않는 **무한 재귀**였다. `n < 3`이라는 조건은 음수에 대해서도 항상 참이라 base case처럼 보이지만, 실제로는 `n - 1`, `n - 2`로 재귀 호출을 하는 쪽(`else` 분기)에 도달하려면 `n >= 3`이어야 하는데, 음수는 계속 `n < 3` 분기로 빠지므로 재귀 호출 자체가 일어나지 않고 그냥 `n`(음수)을 그대로 반환한다는 걸 뒤늦게 깨달았다. 즉 애초에 무한 재귀는 이 코드에서 일어나지 않고, 음수를 넣으면 그냥 그 음수가 그대로 반환된다는 게 정확한 동작이었다.

문제는 이게 의미적으로 맞지 않다는 것이었다. "음수 개의 계단을 오르는 방법의 수"가 그 음수 자체와 같을 이유가 없다. 그래서 "계단 수가 음수면 오르는 방법은 0가지"라는 규칙을 추가하기로 했다.

```swift
static func climbCombinationsForNegative(n: Int) -> Int {
    if n < 0 {
        return 0
    } else if n < 3 {
        return n
    } else {
        return climbCombinations(n: n - 1) + climbCombinations(n: n - 2)
    }
}
```

한 줄짜리 삼항 연산자로는 이 조건을 깔끔하게 담기 어려워서, `if-else if-else`로 풀어 썼다. 짧은 코드가 항상 정답은 아니라는 게 여기서도 다시 확인된다. 코드가 길어지더라도 의미가 명확한 쪽을 택했다.

---

### 최종 테스트

```swift
func testClimbCombinations() {
    let examples: [Int] = [0, 1, 2, 3, 4, 10]
    let expectedValues: [Int] = [0, 1, 2, 3, 5, 89]

    for i in 0..<examples.count {
        XCTAssertEqual(part5Problems.climbCombinations(n: examples[i]), expectedValues[i])
        XCTAssertEqual(part5Problems.climbCombinationsForNegative(n: examples[i]), expectedValues[i])
    }

    XCTAssertEqual(part5Problems.climbCombinations(n: -2124), -2124)
    XCTAssertEqual(part5Problems.climbCombinationsForNegative(n: -2124), 0)
}
```

`0`부터 `10`까지의 케이스를 배열로 준비해서 반복 검증하고, 마지막에 음수(`-2124`) 케이스를 별도로 확인한다. `climbCombinations`(원래 버전)는 음수를 넣으면 그 음수를 그대로 반환하고, `climbCombinationsForNegative`는 `0`을 반환하는 것까지 각각 검증했다. "음수 계단 = 내려가는 계단이라고 해석하면 방법의 수가 0가지"라는 해석도 이 설계와 자연스럽게 맞아떨어진다.

---

## ReverseStringView: 기록할 만한 패턴

이 화면은 대본 설명 없이 소스 코드만 보고 정리한다. 대부분은 지금까지 본 "텍스트 필드 + 결과 표시" 패턴 그대로라 생략하고, 두 가지만 남긴다.

---

### 재사용 가능한 2줄 라벨 컴포넌트: TwoLineView

```swift
struct TwoLineView: View {
    let text1: String
    let text2: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text1)
                .font(.largeTitle)
            Text(text2)
                .font(.title)
                .bold()
        }
    }
}
```

"제목 한 줄 + 그 아래 강조된 결과 한 줄"이라는 조합을 별도 View로 뽑아뒀다. 지금까지는 이 조합을 각 화면마다 `Text` 두 개를 직접 나열하는 식으로 반복해왔는데, 이렇게 재사용 가능한 컴포넌트로 분리해두면 앞으로 같은 레이아웃이 필요할 때마다 `TwoLineView(text1:text2:)` 한 줄로 끝낼 수 있다.

---

### 함수를 자기 자신에 두 번 합성해서 검증하기

```swift
var reversedText: String {
    part5Problems.reverseString(str: text)
}

var reverseTwice: String {
    part5Problems.reverseString(str: reversedText)
}
```

`reverseTwice`는 `text`를 한 번 뒤집은 결과(`reversedText`)를 다시 한 번 뒤집은 값이다. 문자열을 두 번 뒤집으면 원래 문자열로 돌아와야 한다는 수학적 성질을, 함수를 두 번 합성하는 것만으로 화면에 그대로 드러낸다.

```swift
Button(action: {
    withAnimation {
        twiceReversed.toggle()
    }
}, label: {
    Text(twiceReversed ? "Reverse" : "Twice Reversed")
})
```

버튼으로 "한 번 뒤집은 결과"와 "두 번 뒤집은 결과"(=원본과 같아야 함)를 `TwoLineView`로 토글하며 보여준다. 별도의 assertion이나 텍스트 설명 없이, 사용자가 버튼을 눌러보는 것만으로 "두 번 뒤집으면 원래대로 돌아온다"는 `reverseString`의 성질을 직접 눈으로 확인하게 만드는 구성이다.