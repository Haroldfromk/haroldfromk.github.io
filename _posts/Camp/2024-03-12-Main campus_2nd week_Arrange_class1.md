---
title: 2주차 과제 class화 (1)
writer: Harold
date: 2024-03-12 08:11:00 +0800
#last_modified_at: 2024-03-07 03:11:00 +0800
categories: [캠프, 2주차]
tags: [야구, 과제]

toc: true
toc_sticky: true
---

이미 과제는 끝났지만, 클래스화를 하고싶은데 생각대로 그게 되지않았다.

사실 어떻게 나눠야할지 모르겠다가 더 맞는 표현인듯 하다.

그래서 새롭게 클래스 화 하려고 한다. 각 레벨에 대한 내용은 생략하겠다.

## Lv.1
```swift
// main.swift
import Foundation

let game = BaseballGame()
game.start()

// BaseballGame.swift
import Foundation

class BaseballGame{
    
    var answer = Array<Int>()
    var numbers = Array<Int>()
    
    init(answer: [Int] = Array<Int>(), numbers: [Int] = Array<Int>() ) {
        self.answer = answer
        self.numbers = numbers
    }
    
    func start () {
        let answer = makeAnswer()
        print(answer)
    }
    
    func makeAnswer() -> [Int]{
        numbers = (1...9).map{$0}
        for _ in 0...2 {
            let a = numbers.randomElement()!
            answer.append(a)
            numbers.remove(at:numbers.firstIndex(of: a)!)
        }
        
        return answer
    }
}
```

## Lv.2

```swift
import Foundation

class BaseballGame{
    
    var question = Array<Int>()
    var numbers = Array<Int>()
    var answer = Array<Int>()
    var gameStart : Bool = true
    var ball : Int = 0
    var strike : Int = 0
        
    func start () {
        
        let question = makeAnswer()
        gameStart = true
        print("<<<<<게임을 시작합니다>>>>>")

        while gameStart {

            print("숫자를 입력해주세요.") // for notification when app starts
            print(question)
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
        
    }
    
    func makeAnswer() -> [Int]{
        numbers = (1...9).map{$0}
        for _ in 0...2 {
            let a = numbers.randomElement()!
            answer.append(a)
            numbers.remove(at:numbers.firstIndex(of: a)!)
        }
        
        return answer
    }
}


```

## Lv.3
```swift


import Foundation

class BaseballGame{
    
    var question = Array<Int>()
    var numbers = Array<Int>()
    var answer = Array<Int>()
    
    var gameStart : Bool = true
    var quesMaking : Bool = true
    
    var ball : Int = 0
    var strike : Int = 0
    
    func start () {
        
        let question = makeQuestion()
        gameStart = true
        print("<<<<<게임을 시작합니다>>>>>")
        
        while gameStart {
            
            print("숫자를 입력해주세요.") // for notification when app starts
            print(question)
            let input = Int(readLine()!)
            
            if let input = input { // if type is Int
                answer = String(input).map{Int(String($0))!}
                if answer.count != 3 {
                    print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요\n")
                    continue
                }
                
                if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] {
                    print("중복된 수가 존재 합니다. 다시 입력해주세요\n")
                    continue
                }
                
            }
            else { // if type is not Int
                print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요\n")
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
                print("<<<<<축하합니다 정답입니다>>>>>.\n")
                gameStart = false
            } else if strike == 0 && ball == 0 {
                print("Nothing\n")
            } else {
                print("현재 \(strike) Strike \(ball) Ball 입니다.\n")
            }
            
        }
        
    }
    
    func makeQuestion() -> [Int]{
        
        numbers = (0...9).map{$0}
        
        while quesMaking {
            var a = 0
            a = numbers.randomElement()!
            question.append(a)
            numbers.remove(at:numbers.firstIndex(of: a)!)
            
            if question[0] == 0 {
                question = []
                continue
            }
            
            if question.count == 3 {
                quesMaking = false
            }
        }
        
        return question
    }
}
```

## Lv.4~6
```swift
// BaseballGame


import Foundation

class BaseballGame{
    
    var question = Array<Int>()
    var numbers = Array<Int>()
    var answer = Array<Int>()
    var ballCount = Dictionary<String,Int>()
    
    var gameStart : Bool = true
    var quesMaking : Bool = true
    var gameTitle : Bool = true
    
    var ball : Int = 0
    var strike : Int = 0
    
    // MARK: - Function : Game Start
    func start () {
        
        var recordManager = RecordManager()
        
        while gameTitle {
            print("<<<<<게임을 시작합니다>>>>>") // for notification when app starts
            print("1. 게임 시작하기. 2. 게임 기록 보기 3. 종료하기")
            let titleInput = Int(readLine()!)
            switch titleInput {
            case 1 :
                question = makeQuestion()
                gameStart = true
                recordManager.ansCount = 0
                while gameStart {
                    
                    print("숫자를 입력해주세요.") // for notification when app starts
                    print(question)
                    let input = Int(readLine()!)
                    
                    if let input = input { // if type is Int
                        answer = String(input).map{Int(String($0))!}
                        if answer.count != 3 {
                            print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요\n")
                            recordManager.ansCount += 1
                            continue
                        }
                        
                        if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] {
                            print("중복된 수가 존재 합니다. 다시 입력해주세요\n")
                            recordManager.ansCount += 1
                            continue
                        }
                        
                    }
                    else { // if type is not Int
                        print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요\n")
                        recordManager.ansCount += 1
                        continue
                    }
                    recordManager.ansCount += 1
                    strike = 0
                    ball = 0
                    
                    ballCount = getBallCount(question, answer)
                    
                    if ballCount["Strike"] == 3 {
                        print("<<<<<축하합니다 정답입니다>>>>>.\n")
                        recordManager.gameCount += 1
                        recordManager.scoreArray.append(recordManager.ansCount)
                        gameStart = false
                    } else if strike == 0 && ball == 0 {
                        print("Nothing\n")
                    } else {
                        print("현재 \(ballCount["Strike"] ?? 0) Strike \(ballCount["Ball"] ?? 0) Ball 입니다.\n")
                    }
                    
                }
            case 2 :
                if recordManager.gameCount != 0 {
                    
                    print("<게임 기록 보기>")
                    
                    for i in 0..<recordManager.gameCount {
                        print("\(i+1) 번째 게임, 시도 횟수 : \(recordManager.scoreArray[i])")
                    }
                    print("")
                    continue
                    
                } else { // when user type 2, before starting game
                    print("게임 기록이 없습니다.\n")
                    continue
                }
            case 3 :
                print("종료합니다")
                gameTitle = false
            default :
                print("1, 2, 3 숫자만 입력하세요\n")            }
        }
    }
    
    // MARK: - Getting Ball count
    func getBallCount(_ question : [Int], _ answer : [Int]) -> [String : Int]{
        
        // init strike & ball count
        strike = 0
        ball = 0
        ballCount = ["Strike": 0, "Ball" : 0 ]
        
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
        
        ballCount["Strike"] = strike
        ballCount["Ball"] = ball
        
        return ballCount
    }
    
    // MARK: - Making Question
    func makeQuestion() -> [Int]{
        
        // initialize
        question = []
        numbers = (0...9).map{$0}
        quesMaking = true
        
        // making question
        while quesMaking {
            var a = 0
            a = numbers.randomElement()!
            question.append(a)
            numbers.remove(at:numbers.firstIndex(of: a)!)
            
            if question[0] == 0 {
                question = []
                continue
            }
            
            if question.count == 3 {
                quesMaking = false
            }
        }
        
        return question
    }
}

// RecordManager

import Foundation

struct RecordManager {
    
    var gameCount : Int = 0
    var ansCount : Int = 0
    var scoreArray = Array<Int>()
    
    func showRecords () {
        for i in scoreArray.indices{
            print("\(i+1) 번째 게임, 시도 횟수 : \(scoreArray[i])")
        }
    }
    
}


```

---

튜터님과 대화를 하던중. 변수를 Model화 해서 별도의 Struct에 넣는게 어떨까라는 생각이 들었다.
```swift 
// Record Manager

import Foundation

struct RecordManager {
    
    var gameCount : Int = 0
    var ansCount : Int = 0
    var scoreArray = Array<Int>()
    
    func showRecords () {
        for i in scoreArray.indices{
            print("\(i+1) 번째 게임, 시도 횟수 : \(scoreArray[i])")
        }
    }
    
    // increase Count
    mutating func inreaseCount (){
        ansCount += 1
    }
    
    // Reset Count
    mutating func resetCount () {
        ansCount = 0
    }
    
}

// MakingQuestion

import Foundation

class MakingQuestion {
    
    var gameModel = GameModel()
    
    func makeQuestion() -> [Int]{
        
        // initialize
        gameModel.question = []
        gameModel.numbers = (0...9).map{$0}
        gameModel.quesMaking = true
        
        // making question
        while gameModel.quesMaking {
            
            var a = 0
            
            a = gameModel.numbers.randomElement()!
            gameModel.question.append(a)
            gameModel.numbers.remove(at:gameModel.numbers.firstIndex(of: a)!)
            
            if gameModel.question[0] == 0 {
                gameModel.question = []
                continue
            }
            
            if gameModel.question.count == 3 {
                gameModel.quesMaking = false
            }
            
        }
        
        return gameModel.question
    }
    
}

// Handling Ball Count

import Foundation

class HandlingBallCount {
    
    var gameModel = GameModel()
    
    func getBallCount(_ question : [Int], _ answer : [Int]) -> [String : Int]{
        
        gameModel.ballCount = ["Strike": 0, "Ball" : 0 ]
        
        // Just want to use High order Function
        
        answer.enumerated().map{$0}.forEach{
            (aoffset, aelement) in question.enumerated().map{$0}.forEach{
                (qoffset, qelement) in
                if aoffset == qoffset {
                    if aelement == qelement {
                        gameModel.ballCount["Strike"]! += 1
                    }
                }else {
                    if aelement == qelement {
                        gameModel.ballCount["Ball"]! += 1
                    }
                }
            }
        }
        
        return gameModel.ballCount
    }
}

// Baseball Game


import Foundation

class BaseballGame{
    
    var gameModel = GameModel()
    
    func start () {
        
        var recordManager = RecordManager()
        let makingQuestion = MakingQuestion()
        let handlingBallCount = HandlingBallCount()
        
        while gameModel.gameTitle {
            
            print("<<<<<게임을 시작합니다>>>>>")
            print("1. 게임 시작하기. 2. 게임 기록 보기 3. 종료하기")
            
            let titleInput = Int(readLine()!)
            
            switch titleInput {
                
            case 1 :
                
                gameModel.question = makingQuestion.makeQuestion()
                gameModel.gameStart = true
                
                recordManager.resetCount()
                
                while gameModel.gameStart {
                    
                    print("숫자를 입력해주세요.")
                    print(gameModel.question)
                    
                    let input = Int(readLine()!)
                    
                    if let input = input {
                        
                        gameModel.answer = String(input).map{Int(String($0))!}
                        
                        if gameModel.answer.count != 3 {
                            print("3자리의 숫자가 아닙니다. 3자리로 입력해주세요\n")
                            recordManager.inreaseCount()
                            continue
                        }
                        
                        if gameModel.answer[0] == gameModel.answer [1] || gameModel.answer[0] == gameModel.answer [2] || gameModel.answer[1] == gameModel.answer [2] {
                            print("중복된 수가 존재 합니다. 다시 입력해주세요\n")
                            recordManager.inreaseCount()
                            continue
                        }
                        
                    }
                    else {
                        print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요\n")
                        recordManager.inreaseCount()
                        continue
                    }
                    
                    recordManager.inreaseCount()
                    
                    gameModel.ballCount["Strike"] = 0
                    gameModel.ballCount["Ball"] = 0
                    
                    gameModel.ballCount = handlingBallCount.getBallCount(gameModel.question, gameModel.answer)
                    
                    if gameModel.ballCount["Strike"] == 3 {
                        print("<<<<<축하합니다 정답입니다>>>>>.\n")
                        recordManager.gameCount += 1
                        recordManager.scoreArray.append(recordManager.ansCount)
                        gameModel.gameStart = false
                        
                    } else if gameModel.ballCount["Strike"] == 0 &&  gameModel.ballCount["Ball"] == 0 {
                        print("Nothing\n")
                        
                    } else {
                        print("현재 \(gameModel.ballCount["Strike"] ?? 0) Strike \(gameModel.ballCount["Ball"] ?? 0) Ball 입니다.\n")
                    }
                    
                }
                
            case 2 :
                
                if recordManager.gameCount != 0 {
                    
                    print("<게임 기록 보기>")
                    
                    for i in 0..<recordManager.gameCount {
                        print("\(i+1) 번째 게임, 시도 횟수 : \(recordManager.scoreArray[i])")
                    }
                    print("")
                    continue
                    
                } else {
                    print("게임 기록이 없습니다.\n")
                    continue
                }
                
            case 3 :
                
                print("종료합니다")
                gameModel.gameTitle = false
                
            default :
                
                print("1, 2, 3 숫자만 입력하세요\n")            }
        }
    }
   
}

// main

import Foundation

let game = BaseballGame()
game.start()

// Game Mode

import Foundation

struct GameModel {
    
    var question = Array<Int>()
    var numbers = Array<Int>()
    var quesMaking : Bool = true
    
    var answer = Array<Int>()
    var ballCount = Dictionary<String,Int>()

    var gameStart : Bool = true
    var gameTitle : Bool = true
    
    var gameCount : Int = 0
    var ansCount : Int = 0
    
    var scoreArray = Array<Int>()
    
}
```

어떻게 보면 이렇게 바꾸면서
`gameModel.property` 로 다 바뀐것같다.

이게 맞는지는 솔직히 잘 모르겠다.

다른 튜터님과 이야기 해본결과, 좀 더 Model에 대해 세분화를 해보는게 어떠냐는 말을 들어 더 세분화를 해보기로한다.