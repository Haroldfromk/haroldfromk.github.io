---
title: Tip-Calculator (7)
writer: Harold
date: 2024-05-03 22:13
#last_modified_at: 2024-05-02 07:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

## Unit Test 세팅

```swift
import XCTest
import Combine

@testable import tip_calculator

final class tip_calculatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    
    override func tearDown() {
        super.tearDown()
    }
}
```

test 클래스 안에 있던 모든 함수들을 다 지우고 setUp만 만든다.

이떄 set치면 여러개가 나오고 첫번째 세번째가 같은 setUp인데 이때 3번째걸 해줘야한다.

첫번째것은 class

teardown도 마찬가지.

> setUp?
>> 기본값을 생성할때 사용
>>> 객체 인스턴스생성, db초기화, 규칙 작성 등

> tearDown?
>> 초기상태로 복원할때 사용
>>> 파일 닫기, 연결, 새로 만든 항목 제거 등

[출처](https://ios-daniel-yang.tistory.com/63){:target="_blank"}

![CleanShot 2024-05-03 at 22 05 31@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e95f663d-1148-4257-8858-8965740ad37e)

재생버튼같은걸 누르면 

테스트가 무사히 끝나면

초록색으로 v가 된다는데 난 왜 안되는지 모르겠다.

```swift
final class tip_calculatorTests: XCTestCase {
    
    // Sut -> System Under Test
    
    private var sut: CalculatorVM!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        sut = .init()
        cancellables = .init()
        super.setUp()
    }
    
    
    override func tearDown() {
        super.tearDown()
        sut = nil
        cancellables = nil
    }
}
```

setup할때 init을 해주고

끝나면 nil로 바꿔준다.

$100 bill, None Tip, 1명이라는 조건으로 테스트를 하는 시나리오를 만들어 보자.

```swift
private let logoViewTapSubject = PassthroughSubject<Void, Never>()

func testResultWithoutTipFor1Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .none
        let split: Int = 1
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 100)
            XCTAssertEqual(result.totalBill, 100)
            XCTAssertEqual(result.totalTip, 0)
        }.store(in: &cancellables)
    }
    
    private func buildInput(bill: Double, tip: Tip, split: Int) -> CalculatorVM.Input {
        return .init(
            billPublisher: Just(bill).eraseToAnyPublisher(),
            tipPublisher: Just(tip).eraseToAnyPublisher(),
            splitPublisher: Just(split).eraseToAnyPublisher(),
            logoViewTapPublisher: logoViewTapSubject.eraseToAnyPublisher())
    }
```
이때 위에 왜 logoViewTapSubject를 만들었냐면 우리가 사운드 테스트는 하지 않을것이라서 그렇다.

given에 주어지는 조건을 만들고.

transform을 통해 들어온값을 output으로 보냄

output에선 publisher를 통해 처리

```swift
XCTAssertEqual(result.amountPerPerson, 100) 
XCTAssertEqual(result.totalBill, 100)
XCTAssertEqual(result.totalTip, 0)
```

한사람이 내야할돈 100
전체 돈 100
팁 0

이기에 위와 같이 했다.

![CleanShot 2024-05-03 at 22 34 40@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e5feeb54-aba7-4b6b-9999-494cbfc086be)

테스트 성공

만약에 값을 다르게 주면?

![CleanShot 2024-05-03 at 22 35 29@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1b3d1b5d-641c-4529-b12b-44ef12057f21)

이렇게 에러가 발생한다.

## 조건을 더 추가하여 테스트

추가하려는 조건은 아래와 같다.

1. 2명이고 팁이 없다.
2. 2명이고 10% 팁이 있다.
3. 4명이고 Custom Tip이 존재

### 1. 2명이고 팁이 없는 조건

```swift
func testResultWithoutTipFor2Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .none
        let split: Int = 2
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 50)
            XCTAssertEqual(result.totalBill, 100)
            XCTAssertEqual(result.totalTip, 0)
        }.store(in: &cancellables)
    }
```

### 2. 2명이고 10% 팁이 있는 조건

```swift
func testResultWith10PercentTipFor2Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .tenPercent
        let split: Int = 2
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 55)
            XCTAssertEqual(result.totalBill, 110)
            XCTAssertEqual(result.totalTip, 10)
        }.store(in: &cancellables)
    }
```

### 3. 4명이고 Custom Tip이 존재하는 조건

```swift
func testResultWithCustomTipFor4Person() {
        // given
        let bill: Double = 200.0
        let tip: Tip = .custom(value: 201)
        let split: Int = 4
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 100.25)
            XCTAssertEqual(result.totalBill, 401)
            XCTAssertEqual(result.totalTip, 201)
        }.store(in: &cancellables)
    }
```

이렇게 테스트가 가능하다.

이렇게 했는데 테스트가 실패한다면 로직이 잘못짜여있다는걸 의미한다.

그럴땐 계산로직을 확인해봐야함.

## Logoview Double Tap Test

```swift
func testSoundPlayedCalculatorResetOnLogoViewTap() {
        // given
        let input = buildInput(bill: 100, tip: .tenPercent, split: 2)
        let output = sut.transform(input: input)
        let expectation1 = XCTestExpectation(description: "reset calculator called")
        
        // then
        output.resetCalculatorPublisher.sink { _ in
            expectation1.fulfill()
        }.store(in: &cancellables)
        
        // when
        logoViewTapSubject.send()
        wait(for: [expectation1], timeout: 1.0)
    }
```


`expectation1.fulfill()`을 실행하지 않으면 에러가 발생한다.

저부분은 나중에 다시 서술하도록 하는걸로.

```swift
override func setUp() {
        sut = .init()
        cancellables = .init()
        super.setUp()
    }
```
아까 init에 audio를 하지않았기에,

오디오 테스트를 하기위해 init 수정


목업 같은 오디오 플레이어 생성

```swift
class MockAudioPlayerService: AudioPlayerService {
    
    var expectation = XCTestExpectation(description: "playSound is Called")
    
    func playSound() {
        expectation.fulfill()
    }

}

private var audioPlayerService: MockAudioPlayerService!
    
override func setUp() {
    audioPlayerService = .init() // added
    sut = .init(audioPlayerService: audioPlayerService) // modified
    cancellables = .init()
    super.setUp()
}

func testSoundPlayedCalculatorResetOnLogoViewTap() {
        // given
        let input = buildInput(bill: 100, tip: .tenPercent, split: 2)
        let output = sut.transform(input: input)
        let expectation1 = XCTestExpectation(description: "reset calculator called")
        let expectation2 = audioPlayerService.expectation // added
        
        // then
        output.resetCalculatorPublisher.sink { _ in
            expectation1.fulfill()
        }.store(in: &cancellables)
        
        // when
        logoViewTapSubject.send()
        wait(for: [expectation1, expectation2], timeout: 1.0) // modified
    }
```

전체코드

```swift
import XCTest
import Combine

@testable import tip_calculator

final class tip_calculatorTests: XCTestCase {
    
    // Sut -> System Under Test
    
    private var sut: CalculatorVM!
    private var cancellables: Set<AnyCancellable>!
    
    private var logoViewTapSubject: PassthroughSubject<Void, Never>!
    private var audioPlayerService: MockAudioPlayerService!
    
    override func setUp() {
        audioPlayerService = .init()
        sut = .init(audioPlayerService: audioPlayerService)
        logoViewTapSubject = .init()
        cancellables = .init()
        super.setUp()
    }
    
    
    override func tearDown() {
        super.tearDown()
        sut = nil
        cancellables = nil
        audioPlayerService = nil
        logoViewTapSubject = nil
    }
    
    func testResultWithoutTipFor1Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .none
        let split: Int = 1
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 100)
            XCTAssertEqual(result.totalBill, 100)
            XCTAssertEqual(result.totalTip, 0)
        }.store(in: &cancellables)
    }
    
    private func buildInput(bill: Double, tip: Tip, split: Int) -> CalculatorVM.Input {
        return .init(
            billPublisher: Just(bill).eraseToAnyPublisher(),
            tipPublisher: Just(tip).eraseToAnyPublisher(),
            splitPublisher: Just(split).eraseToAnyPublisher(),
            logoViewTapPublisher: logoViewTapSubject.eraseToAnyPublisher())
    }
    
    func testResultWithoutTipFor2Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .none
        let split: Int = 2
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 50)
            XCTAssertEqual(result.totalBill, 100)
            XCTAssertEqual(result.totalTip, 0)
        }.store(in: &cancellables)
    }
    
    func testResultWith10PercentTipFor2Person() {
        // given
        let bill: Double = 100.0
        let tip: Tip = .tenPercent
        let split: Int = 2
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 55)
            XCTAssertEqual(result.totalBill, 110)
            XCTAssertEqual(result.totalTip, 10)
        }.store(in: &cancellables)
    }
    
    func testResultWithCustomTipFor4Person() {
        // given
        let bill: Double = 200.0
        let tip: Tip = .custom(value: 201)
        let split: Int = 4
        let input = buildInput(bill: bill, tip: tip, split: split)
        
        // when
        let output = sut.transform(input: input)
        
        // then
        output.updateViewPublisher.sink { result in
            XCTAssertEqual(result.amountPerPerson, 100.25)
            XCTAssertEqual(result.totalBill, 401)
            XCTAssertEqual(result.totalTip, 201)
        }.store(in: &cancellables)
    }
    
    func testSoundPlayedCalculatorResetOnLogoViewTap() {
        // given
        let input = buildInput(bill: 100, tip: .tenPercent, split: 2)
        let output = sut.transform(input: input)
        let expectation1 = XCTestExpectation(description: "reset calculator called")
        let expectation2 = audioPlayerService.expectation
        
        // then
        output.resetCalculatorPublisher.sink { _ in
            expectation1.fulfill()
        }.store(in: &cancellables)
        
        // when
        logoViewTapSubject.send()
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }
}

class MockAudioPlayerService: AudioPlayerService {
    
    var expectation = XCTestExpectation(description: "playSound is Called")
    
    func playSound() {
        expectation.fulfill()
    }

}


```

