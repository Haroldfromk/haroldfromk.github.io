---
title: 2주차 과제
writer: Harold
date: 2024-03-11 08:11:00 +0800
#last_modified_at: 2024-03-07 03:11:00 +0800
categories: [캠프, 2주차]
tags: [야구, 과제]

toc: true
toc_sticky: true
---

2주차 과제가 주어졌다.

## Lv1
- [ ]  1에서 9까지의 서로 다른 임의의 수 3개를 정하고 맞추는 게임입니다
- [ ]  정답은 랜덤으로 만듭니다.(1에서 9까지의 서로 다른 임의의 수 3자리)

---

나의 코드
```swift
var question : [Int] = []
var numbers : [Int] = (1...9).map{$0} 

for _ in 0...2 { // operate 3 times
    var a = 0
    a = numbers.randomElement()!
    question.append(a)
    numbers.remove(at:numbers.firstIndex(of: a)!)

```


우선 1~9까지의 서로다른 임의의 수 3개를 생성 하는것이었고, 랜덤으로 추출하지만 중복값은 없어야 했다.

1~9까지 수를 numbers라는 변수에 담았고, 해당 배열에서 1개를 뽑아 a라는 변수에 넣었고, 그 a 값을 실제 문제를 담을 question에 넣어 주었다.

그리고 중복이 없어야 하기에 배열에서 그 수를 제거 해주었다.

---

## Lv2
- [ ]  정답을 맞추기 위해 3자리수를 입력하고 힌트를 받습니다
    - [ ]  힌트는 야구용어인 **볼**과 **스트라이크**입니다.
    - [ ]  같은 자리에 같은 숫자가 있는 경우 **스트라이크**, 다른 자리에 숫자가 있는 경우 **볼**입니다
    - ex) 정답 : 456 인 경우
        - 435를 입력한 경우 → 1스트라이크 1볼
        - 357를 입력한 경우 → 1스트라이크
        - 678를 입력한 경우 → 1볼
        - 123를 입력한 경우 → Nothing
    - ex) 정답 : 456 인 경우
        - 435를 입력한 경우 → 1스트라이크 1볼
        - 357를 입력한 경우 → 1스트라이크
        - 678를 입력한 경우 → 1볼
        - 123를 입력한 경우 → Nothing
        - 만약 올바르지 않은 입력값에 대해서는 오류 문구를 보여주세요
    - 3자리 숫자가 정답과 같은 경우 게임이 종료됩니다

    ```swift
    < 게임을 시작합니다 >
    숫자를 입력하세요
    435
    1스트라이크 1볼

    숫자를 입력하세요
    357
    1스트라이크

    숫자를 입력하세요
    123
    Nothing

    숫자를 입력하세요
    dfg // 세 자리 숫자가 아니어서 올바르지 않은 입력값
    올바르지 않은 입력값입니다

    숫자를 입력하세요
    199 // 9가 두번 사용되어 올바르지 않은 입력값
    올바르지 않은 입력값입니다

    숫자를 입력하세요
    103 // 0이 사용되어 올바르지 않은 입력값
    올바르지 않은 입력값입니다

    숫자를 입력하세요
    456
    정답입니다!
    ```
---

나의 코드
```swift
var numbers : [Int] = (1...9).map{$0} // for creating random numbers
var question : [Int] = []

var answer : [Int] = []
var gameStart : Bool = true

var strike : Int = 0
var ball : Int = 0

for _ in 0...2 { // operate 3 times
    var a = 0
    a = numbers.randomElement()!
    question.append(a)
    numbers.remove(at:numbers.firstIndex(of: a)!) 
}

print(question)
// MARK: - Input user's number

print("<<<<<게임을 시작합니다>>>>>")

while gameStart {

    print("숫자를 입력해주세요.") // for notification when app starts

    let input = Int(readLine()!)

    if let input = input { // if type is Int
        answer = String(input).map{Int(String($0))!}
        if answer.count != 3 {
            print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요")
            continue
        }

        if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] {
            print("중복된 수가 존재 합니다. 다시 입력해주세요")
            continue
        }

    }
    else { // if type is not Int
        print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요")
        continue
    }

    strike = 0
    ball = 0

    for i in question.indices {
        for j in question.indices {
            if i == j {
                if answer[i] == question[j] {
                    strike += 1
                }
            } else {
                if answer[i] == question[j] {
                    ball += 1
                }
            }
        }
    }


    if strike == 3 {
        print("<<<<<축하합니다 정답입니다>>>>>.")
        gameStart = false
    } else if strike == 0 && ball == 0 {
        print("Nothing")
    } else {
        print("현재 \(strike) Strike \(ball) Ball 입니다.")
    }

}
```

이제는 게임 로직을 구현해야 한다.

우선 내가 만들어진 문제를 맞출때 까지 계속 풀어야 하므로 무한 루프인 while을 사용해주었고, true일때 계속 돌게하고,
정답을 맞출때 false로 while문을 빠져나가도록 틀을 잡았다.

그리고 실제로 내가 입력한 값을 받아야 하므로 일반적인 type선언이 아닌. readLine()을 사용했다.

기본적으로 readLine은 optional String을 가지고 있어 !를 통해 unwrapping을 해주었다.

누군가가 입력을 할때 숫자가아닌 다른 수를 입력 할 수도 있으므로 옵셔널 바인딩을 해주었다.

그리고 내가 입력한 수를 그대로 배열로 만들어 주었다.

숫자를 입력 다하고 엔터를친 시점에 2개의 if문이 돌아서 3자리를 입력하지 않았거나, 또는 중복숫자를 입력했을때 다시 돌아가게끔 로직을 구현해주었다.

그리고나서 ball, strike의 값을 초기화 해주었고, 반복문을 통해 i, j이가 같을때, 즉 같은 자리일때 strike를 1씩 올려주고,

다른자리에서 같을때 ball을 1씩 올려주게 하였다.

그리고 그 값에 따라 정답이거나 또는 ball, strike, nothing이런 조건을 통해 값을 보여 유져로 하여금 문제의 값을 추론하게 만들었다.

---
## Lv3
- [ ]  정답이 되는 숫자를 0에서 9까지의 서로 다른 3자리의 숫자로 바꿔주세요
    - 맨 앞자리에 0이 오는 것은 불가능합니다
        - 092 → 불가능
        - 870 → 가능
        - 300 → 불가능

---

```swift
var numbers : [Int] = (0...9).map{$0} // for creating random numbers
var question : [Int] = []

var answer : [Int] = []
var gameStart : Bool = true
var gameMaking : Bool = true


var strike : Int = 0
var ball : Int = 0

while gameMaking {
    var a = 0
    a = numbers.randomElement()!
    question.append(a)
    numbers.remove(at:numbers.firstIndex(of: a)!)

    if question[0] == 0 {
        question = []
        continue
    }

    if question.count == 3 {
        gameMaking = false
    }
}

print("<<<<<게임을 시작합니다>>>>>") // for notification when app starts

while gameStart {

    print("숫자를 입력해주세요.")
     
    let input = Int(readLine()!)

    if let input = input { // if type is Int
        answer = String(input).map{Int(String($0))!}

        if answer.count != 3 {
            print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요")
            continue
        }
        
        if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] {
            print("중복된 수가 존재 합니다. 다시 입력해주세요")
            continue
        }
        
    }
    else { // if type is not Int
        print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요")

```

1~9까지의 수였다면, 0~9까지의 수로 바뀌었다.

그래서 for문을 통해 문제를 만들던것을 while로 바꿔 주었다.

그래서 0번째 인덱스 즉 첫번째 수가 0이 되면 다시 반복하게 하였고, 길이가 3일때, 즉 3개의 수가 만들어 졌을때 false를 하여 while문을 빠져 나가게 했다.

---


## Lv4
- [ ]  프로그램을 시작할 때 안내문구를 보여주세요
    
    ```swift
    // 예시
    환영합니다! 원하시는 번호를 입력해주세요
    1. 게임 시작하기  2. 게임 기록 보기  3. 종료하기
    ```
- [ ]  1번 게임 시작하기의 경우 **“필수 구현 기능”** 의 예시처럼 게임이 진행됩니다
    - 정답을 맞혀 게임이 종료된 경우 위 안내문구를 다시 보여주세요
    
    ```swift
    // 예시
    환영합니다! 원하시는 번호를 입력해주세요
    1. 게임 시작하기  2. 게임 기록 보기  3. 종료하기
    1 // 1번 게임 시작하기 입력

    < 게임을 시작합니다 >
    숫자를 입력하세요
    .
    .
    .
    ```



## Lv5
- [ ]  2번 게임 기록 보기의 경우 완료한 게임들에 대해 시도 횟수를 보여줍니다

    ```swift
    // 예시
    환영합니다! 원하시는 번호를 입력해주세요
    1. 게임 시작하기  2. 게임 기록 보기  3. 종료하기
    2 // 2번 게임 기록 보기 입력

    < 게임 기록 보기 >
    1번째 게임 : 시도 횟수 - 14
    2번째 게임 : 시도 횟수 - 9
    3번째 게임 : 시도 횟수 - 12
    .
    .
    .
    ```

## Lv6
- [ ]  3번 종료하기의 경우 프로그램이 종료됩니다
    - 이전의 게임 기록들도 초기화됩니다
    
    ```swift
    // 예시
    환영합니다! 원하시는 번호를 입력해주세요
    1. 게임 시작하기  2. 게임 기록 보기  3. 종료하기
    3 // 3번 종료하기 입력

    < 숫자 야구 게임을 종료합니다 >
    ```

- [ ] 1, 2, 3 이외의 입력값에 대해서는 오류 메시지를 보여주세요

    ```swift
    // 예시
    환영합니다! 원하시는 번호를 입력해주세요
    1. 게임 시작하기  2. 게임 기록 보기  3. 종료하기
    4

    올바른 숫자를 입력해주세요!
    ```

---
```swift

import Foundation

// MARK: - Define Parameters

var numbers : [Int] = []
var question : [Int] = []
var answer : [Int] = []
var scoreArray : [Int] = []
var ballCount : [String : Int] = [:]

var gameTitle : Bool = true
var gameStart : Bool = true
var gameMaking : Bool = true

var gameCount : Int = 0
var scoreCount : Int = 0
var strike : Int = 0
var ball : Int = 0


// MARK: - Making Question

func makeQuestion () -> [Int] {
    numbers = (0...9).map{$0} // for creating random numbers
    question = [] // init array
    
    while gameMaking {
        var a = 0
        a = numbers.randomElement()!
        question.append(a)
        numbers.remove(at:numbers.firstIndex(of: a)!) // to avoid duplicated numbers
        
        if question[0] == 0 { // to avoid the first of number which is 0
            question = [] // init array
            continue
        }
        
        if question.count == 3 { // finishing making array
            gameMaking = false
        }
    }
    
    return question
}

// MARK: - Comparing answer and question & Get ball count

func getBallCount(_ question : [Int], _ answer : [Int]) -> [String : Int]{
    
    // init strike & ball count
    strike = 0
    ball = 0
    ballCount = ["Strike": 0, "Ball" : 0 ]
    
    for i in question.indices {
        for j in question.indices {
            if i == j {
                if answer[i] == question[j] { // same position
                    strike += 1
                }
            } else {
                if answer[i] == question[j] { // different position
                    ball += 1
                }
            }
        }
    }
    
    ballCount["Strike"] = strike
    ballCount["Ball"] = ball
    
    return ballCount
}


// MARK: - Game Logic

func gamePart () {
    while gameStart {
        
        print("숫자를 입력해주세요.")
        
        print(question)
        
        let input = Int(readLine()!) // to get user's answer
        
        if let input = input { // if type is Int
            answer = String(input).map{Int(String($0))!}
            
            if answer.count != 3 { // when count is not 3
                print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요\n")
                scoreCount += 1 // count up
                continue
            }
            
            if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] { // when duplicated numbers extist
                print("중복된 수가 존재 합니다. 다시 입력해주세요\n")
                scoreCount += 1 // count up
                continue
            }
            
        } else { // if type is not Int
            print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요\n")
            scoreCount += 1 // count up
            continue
        }
        
        scoreCount += 1 // count up
        
        ballCount = getBallCount(question, answer)
        
        if ballCount["Strike"] == 3 {
            print("<<<<<축하합니다 정답입니다>>>>>.\n")
            gameCount += 1
            scoreArray.append(scoreCount)
            gameStart = false
        } else if strike == 0 && ball == 0 {
            print("Nothing\n")
        } else {
            print("현재 \(ballCount["Strike"] ?? 0) Strike \(ballCount["Ball"] ?? 0) Ball 입니다.\n")
        }
    }
}



// MARK: - Game Main Title

while gameTitle {
    
    // init game logic
    gameStart = true
    gameMaking = true
    
    scoreCount = 0
    
    print("<<<<<게임을 시작합니다>>>>>") // for notification when app starts
    print("1. 게임 시작하기. 2. 게임 기록 보기 3. 종료하기")
    
    let titleInput = Int(readLine()!)
    
    if let titleInput = titleInput { // if type is Int
        
        if titleInput == 1 {
            
            question = makeQuestion() // Make question
            gamePart() // game start
            
            
        } else if titleInput == 2 {
            
            if gameCount != 0 {
                
                print("<게임 기록 보기>")
                
                for i in 0..<gameCount {
                    print("\(i+1) 번째 게임, 시도 횟수 : \(scoreArray[i])")
                }
                print("")
                continue
                
            } else { // when user type 2, before starting game
                print("게임 기록이 없습니다.\n")
                continue
            }
            
        } else if titleInput == 3 {
            print("종료합니다")
            gameTitle = false
            
        } else { // except for 1,2,3
            print("1, 2, 3 숫자만 입력하세요\n")
        }
        
    } else{ // if type is not Int
        print("1, 2, 3 숫자만 입력하세요\n")
    }
}

```

---

코드가 꽤 길어졌다 4~6은 나누는것보다 한번에 하는게 나을것같았다.

ball strike 카운트를 고차함수로도 표현해 보았다.
```swift
    answer.enumerated().map{$0}.forEach{
        (aoffset, aelement) in question.enumerated().map{$0}.forEach{
            (qoffset, qelement) in
            if aoffset == qoffset {
                if aelement == qelement {
                    strike+=1
                }
            }else {
                if aelement == qelement {
                    ball+=1
                }
            }
        }
    }
```

튜터님께 문의 결과 역시 가독성이나 이런부분에선 선호 받지 못하는듯하다.

시간복잡도는 for문보다는 낫긴 하지만, 굳이 라는 생각이 든다.

function으로 나누었는데, 클래스로 나누는것을 추천해주셔서 클래스로 한번 나눠봐야겠다.