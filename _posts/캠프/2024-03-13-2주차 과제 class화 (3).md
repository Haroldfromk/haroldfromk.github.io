---
title: 2주차 과제 class화 (3)
writer: Harold
date: 2024-03-13 00:30
#last_modified_at: 2024-03-07 03:11:00 +0800
categories: [캠프, 2주차]
tags: [야구, 과제]

toc: true
toc_sticky: true
---

이젠 더이상 건드릴게 없어 보인다.

Model
```swift
// GameModel

import Foundation

struct GameModel {
    
    static var answer = Array<Int>()
    var question = Array<Int>()
    
    static var gameStart : Bool = true
    static var ansCheck : Bool = true
    var gameTitle : Bool = true
    
}

// QuestionModel
struct QuestionModel {
    
    var numbers = Array<Int>()
    var quesMaking : Bool = true
    
}

// BallCountModel
struct BallCountModel {
    
    var ballCount = Dictionary<String,Int>()
    
}

// RecordModel
struct RecordModel {
    
    static var gameCount : Int = 0
    static var ansCount : Int = 0
    static var scoreArray = Array<Int>()
    
}

```

Controller
```swift
// BaseballGame

import Foundation

class BaseballGame{
    
    var gameModel = GameModel()
    let recordManager = RecordManager()
    let makingQuestion = MakingQuestion()
    let ballCountManager = BallCountManager()
    let gameManager = InputManager()
    
    func start () {
        
        while gameModel.gameTitle { // Game must be operated when gameTitle is true
            
            print("               ⚾️ Play Ball ⚾️  ")
            print(" [1]. Game Start! [2]. Game Record [3]. Exit ")
            
            let titleInput = Int(readLine()!)
            
            switch titleInput {
                
            case 1 :
                
                gameModel.question = makingQuestion.makeQuestion()
                
                GameModel.gameStart = true
                
                recordManager.resetCount()
                
                while GameModel.gameStart { // Game must be operated when gameStart is true
                    
                    GameModel.ansCheck = true
                    
                    while GameModel.ansCheck { // Player should follow the rule which is answer's count is 3
                        
                        print("           Please Enter 3 Numbers")
                        print(gameModel.question)
                        
                        let input = Int(readLine()!)
                        
                        if let input = input {
                            
                            GameModel.answer = String(input).map{Int(String($0))!}
                            gameManager.answerCheck()
                            
                        }
                        else {
                            
                            print("      Please Enter the Number Correctly")
                            recordManager.inreaseAnsCount()
                            
                        }
                    }
                    
                    ballCountManager.resetAllBallCount() // reset ball counts
                    ballCountManager.getTotalCount(gameModel.question, GameModel.answer) // to get ball count
                    ballCountManager.checkBallCount() // get ball count using checkballcount function
                    
                }
                
            case 2 :
 
                recordManager.showRecord()
                
            case 3 :
                
                print("                  Good Bye👋")
                gameModel.gameTitle = false
                
            default :
                
                print("      Please Enter the Number Correctly\n")
                
            }
        }
    }
   
}



// MakingQuestion


import Foundation

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
    var gameModel = GameModel()
    var recordManager = RecordManager()
    let recordModel = RecordModel()
    
    func getTotalCount(_ question : [Int], _ answer : [Int]) {
        
        ballCountModel.ballCount = ["Strike": 0, "Ball" : 0 ]
        
        // Just want to use High order Function for getting ball count
        
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
    
    func checkBallCount () {
        
        if getStrikeCount() == 3 {
            
            print("                HomeRun!!!!!\n")
            recordManager.increaseGameCount()
            recordManager.saveCount()
            GameModel.gameStart = false
            
        } else if getStrikeCount() == 0 &&  getBallCount() == 0 {
            
            print("                    Out!\n")
            
        } else {
            
            print("               \(getStrikeCount()) Strike \(getBallCount()) Ball!\n")
            
        }
    }

}

// RecordManager

import Foundation

class RecordManager {
     
    // increase Count
    func inreaseAnsCount (){
        RecordModel.ansCount += 1
    }
    
    func increaseGameCount () {
        RecordModel.gameCount += 1
    }
    
    // Reset Count
    func resetCount () {
        RecordModel.ansCount = 0
    }
    
    // add ansCount into Array
    func saveCount () {
        RecordModel.scoreArray.append(RecordModel.ansCount)
    }
    
    // Current game count
    func getGameCount () -> Int {
        let gameCount = RecordModel.gameCount
        return gameCount
    }
    
    // Current score count
    func getScoreCount () -> [Int] {
        let scoreCount = RecordModel.scoreArray
        return scoreCount
    }
    
    func showGameScore () {
        for i in 0 ..< getGameCount() {
            print("           \(i+1) Game, Attempts : \(getScoreCount()[i])\n")
        }
    }
    
    func showRecord () {
        if getGameCount() != 0 {
            
            print("         <<<<< Game Records >>>>>")
            showGameScore()
            
        } else {
            
            print("          There is no Game Record.\n")

        }
    }
    
}

import Foundation

class InputManager {
    
    let recordManager = RecordManager()
    
    func answerCheck () {
        
        if GameModel.answer.count != 3 {
            
            print("         Please Enter 3 Numbers again.\n")
            recordManager.inreaseAnsCount()
            
        } else {
            
            if GameModel.answer[0] == GameModel.answer [1] || GameModel.answer[0] == GameModel.answer [2] || GameModel.answer[1] == GameModel.answer [2] { // to avoid duplicated number
                
                print("         Duplicated numbers detected!\n         Please Enter 3 Numbers again.\n")
                recordManager.inreaseAnsCount()
                
            } else {
                
                recordManager.inreaseAnsCount()
                GameModel.ansCheck = false
                
            }
        }
        
    }
    
}

```

이렇게 끝났다.

세분화 한건 InputManager의 추가와 BallCountManager에서의 checkBallCount 함수이다.

2와 비교하면 모델들 앞에 static이 몇개 붙었다.

checkBallCount 함수를 먼저 만들고 나서, 실행을 했는데 함수에서 시도횟수가 1씩 증가하지도 않고,

정답을 맞추면 false를 리턴하여 벗어나야하는데 그렇지 않았다.

그래서 생각을 해봤는데 두개의 다른 클래스 안에서 서로 값이 따로 논다는걸 이해했을때 아차 싶었다.

그래서 다른 클래스에서도 접근이 가능하게하기위해 `static`을 사용해 주었다.

안그래도 튜터님이 클래스와, 구조체 / Value Type, Reference Type의 중요성을 말해 주셨는데, 그걸 순간 망각하지 않았나 싶다.

덕분에 중요성을 더 알게 된 계기가 되었다.

요근래 `static`을 사용해서 뭔가를 만들어 본적이 없었던것같은데, 좋은 경험이었다.

역시 사람은 만족을 해서는 안되나보다.

다시 돌아가서 해당문제를 해결하고나니 진짜 튜터님이 원했던 기능을 InputManager를 통해 만들었다.

근데 생각을 해보니 각 조건의 끝에 continue를 붙여서 다시 처음으로 돌아갔는데, 이젠 그럴 수 없는 상황이 되어버렸다.

순간 벙쪘다가 while을 하나 더 만들자라는 생각이 들어서 여태 boolean으로 빠져나가고를 했던것을 생각하여,

input에 관한 while을 하나더 만들어 주게 되었다.

그리고 그전까지는 if를 그냥 여러개 써서 하는식으로 하다가 이렇게 나눠버리니 숫자 2하나만 입력하면 카운트에대한 조건이 나와야하는데, if순서때문에 중복값을 찾게하는 로직이 먼저 발동되어 out of range가 떠버렸다.

그래서 길이가 3일때 아닐때를 기준으로 잡고, 3일때 중복값을 확인하는 식으로 로직을 조금 수정하였다.

그리고 보면서 이건 static이 필요하다 싶은것들은 몇개 더 바꿔 주었다.

이렇게까지 하고 나니, 진짜 내가 원했던 그런 프로젝트가 되었다.

아주 만족스럽다.

사운드도 넣고 싶었지만, 찾는것도 그렇고 저작권 무료인것도 찾아야 하기에 pass 하겠다. 너무 사족을 다는것 같아서 여기까지...