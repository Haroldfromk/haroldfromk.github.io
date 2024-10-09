---
title: 2주차 과제 class화 (2)
writer: Harold
date: 2024-03-12 13:11:00 +0800
#last_modified_at: 2024-03-07 03:11:00 +0800
categories: [캠프, 2주차]
tags: [야구, 과제]

toc: true
toc_sticky: true
---

조금 더 세분화를 하였다.

기존에 GameModel로 모든 변수에 대해 관리를 하였다면?

그것을 좀 더 쪼개서 세분화 하였다.


```swift
// GameModel
struct GameModel {
    
    var question = Array<Int>()
    var answer = Array<Int>()
  
    var gameStart : Bool = true
    var gameTitle : Bool = true

    
}

// QuestionModel
struct QuestionModel {
    
    var numbers = Array<Int>()
    var quesMaking : Bool = true
    
}

// RecordModel
struct RecordModel {
    
    var gameCount : Int = 0
    var ansCount : Int = 0
    var scoreArray = Array<Int>()
    
}

// BallCountModel
struct BallCountModel {
    
    var ballCount = Dictionary<String,Int>()
    
}
```

여기까지가 모델이다.

```swift
// BaseballGame


import Foundation

class BaseballGame{
    
    var gameModel = GameModel()
    let recordManager = RecordManager()
    let makingQuestion = MakingQuestion()
    let ballCountManager = BallCountManager()
    
    func start () {
        
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
                            recordManager.inreaseAnsCount()
                            continue
                        }
                        
                        if gameModel.answer[0] == gameModel.answer [1] || gameModel.answer[0] == gameModel.answer [2] || gameModel.answer[1] == gameModel.answer [2] {
                            print("중복된 수가 존재 합니다. 다시 입력해주세요\n")
                            recordManager.inreaseAnsCount()
                            continue
                        }
                        
                    }
                    else {
                        print("숫자가 아닌 값이 입력 되었습니다. 숫자만 입력해주세요\n")
                        recordManager.inreaseAnsCount()
                        continue
                    }
                    
                    recordManager.inreaseAnsCount()
                    ballCountManager.resetAllBallCount()
       
                    ballCountManager.getTotalCount(gameModel.question, gameModel.answer)
                                       
                    if ballCountManager.getStrikeCount() == 3 {
                        print("<<<<<축하합니다 정답입니다>>>>>.\n")
                        recordManager.increaseGameCount()
                        recordManager.saveCount()
                        gameModel.gameStart = false
                        
                    } else if ballCountManager.getStrikeCount() == 0 &&  ballCountManager.getBallCount() == 0 {
                        print("Nothing\n")
                        
                    } else {
                        print("현재 \(ballCountManager.getStrikeCount()) Strike \(ballCountManager.getBallCount()) Ball 입니다.\n")
                    }
                    
                }
                
            case 2 :
                
                if recordManager.getGameCount() != 0 {
                    
                    print("<게임 기록 보기>")
                    
                    for i in 0 ..< recordManager.getGameCount() {
                        print("\(i+1) 번째 게임, 시도 횟수 : \(recordManager.getScoreCount()[i])")
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

// MakingQuestion
class MakingQuestion {
    
    var gameModel = GameModel()
    var questionModel = QuestionModel()
    
    func makeQuestion() -> [Int]{
        
        // initialize
        gameModel.question = []
        questionModel.numbers = (0...9).map{$0}
        questionModel.quesMaking = true
        
        // making question
        while questionModel.quesMaking {
            
            var a = 0
            
            a = questionModel.numbers.randomElement()!
            gameModel.question.append(a)
            questionModel.numbers.remove(at:questionModel.numbers.firstIndex(of: a)!)
            
            if gameModel.question[0] == 0 {
                gameModel.question = []
                continue
            }
            
            if gameModel.question.count == 3 {
                questionModel.quesMaking = false
            }
            
        }
        
        return gameModel.question
    }
    
}

// BallCountManager

import Foundation

class BallCountManager {

    var ballCountModel = BallCountModel()
    
    
    func getTotalCount(_ question : [Int], _ answer : [Int]) {
        
        ballCountModel.ballCount = ["Strike": 0, "Ball" : 0 ]
        
        // Just want to use High order Function
        
        answer.enumerated().forEach{
            (aoffset, aelement) in question.enumerated().forEach{
                (qoffset, qelement) in
                
                if aoffset == qoffset {
                    if aelement == qelement {
                        ballCountModel.ballCount["Strike"]! += 1
                    }
                }else {
                    if aelement == qelement {
                        ballCountModel.ballCount["Ball"]! += 1
                    }
                }
            }
        }
        
       
    }
    
    func getBallCount () -> Int {
        
        if let ballCount = ballCountModel.ballCount["Ball"] {
            return ballCount
        } else {
            return 0
        }
        
    }
    
    func getStrikeCount () -> Int {
        
        if let strikeCount = ballCountModel.ballCount["Strike"] {
            return strikeCount
        } else {
            return 0
        }
        
    }
    
    func resetAllBallCount () {
        ballCountModel.ballCount["Strike"] = 0
        ballCountModel.ballCount["Ball"] = 0
    }
    
    func getAllBallCount () -> [String:Int] {
        let ballCount = ballCountModel.ballCount
            return ballCount
        
    }
    
}

// RecordManager

import Foundation

class RecordManager {
    
    var recordModel = RecordModel()
    
    func showRecords () {
        for i in recordModel.scoreArray.indices{
            print("\(i+1) 번째 게임, 시도 횟수 : \(recordModel.scoreArray[i])")
        }
    }
    
    // increase Count
    func inreaseAnsCount (){
        recordModel.ansCount += 1
    }
    
    func increaseGameCount () {
        recordModel.gameCount += 1
    }
    
    // Reset Count
    func resetCount () {
        recordModel.ansCount = 0
    }
    
    // add ansCount into Array
    func saveCount () {
        recordModel.scoreArray.append(recordModel.ansCount)
    }
    
    func getGameCount () -> Int {
        let gameCount = recordModel.gameCount
        return gameCount
    }
    
    func getScoreCount () -> [Int] {
        let scoreCount = recordModel.scoreArray
        return scoreCount
    }
    
}

```

확실히 이렇게 구분해놓으니 좀 더 코드를 처음 보는사람도 이게 어떤의미로 쓰였는지 보기 좋다는 생각이 들었다.

나누면서 뭔가 swift공부할때처럼 내가 class, struct를 나눠서 쓰는게 더 와닿았다!

튜터님께 다시 피드백을 받으러 갔다.

확실히 전보다 낫다고 하셨고, 튜터님 개인적인 욕심이라면, 실제 게임내 부분에 관한 로직도 조금 더 숨길수 있을것 같다고 하셨다.

물론 그건 튜터님 개인 욕심이라 지금도 충분하다고 하시지만, 뭔가 좀 더 도전해보고 싶은 마음이 생긴다.



