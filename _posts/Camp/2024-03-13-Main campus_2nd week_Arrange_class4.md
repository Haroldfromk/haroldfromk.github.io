---
title: 2주차 과제 class화 (4)
writer: Harold
date: 2024-03-13 17:30
last_modified_at: 2024-03-18 13:11
categories: [캠프, 2주차]
tags: [야구, 과제]

toc: true
toc_sticky: true
---

static을 사용했던게 좀 찝찝해서 튜터님과 대화를 하던중,

내가 구현했던 함수들이 return을 하는게 많이 없었다.

그래서 static을 사용할 수 밖에 없었다.

대화를 하던중 갑자기 아이디어가 생각나서 하던걸 잠시 멈추고 야구를 좀 더 다듬어 보기로 했다.

우선 GameModel의 static부터 고치기로 하였다.

```swift

import Foundation

struct GameModel {
    
    var answer = Array<Int>()
    var question = Array<Int>()
    
    var gameStart : Bool = true
    var ansCheck : Bool = true
    var gameTitle : Bool = true
    
}


```

InputManager 

```swift

import Foundation

class InputManager {
    
    let recordManager = RecordManager()
    var recordModel = RecordModel()
    
    func answerCheck (answer : [Int]) -> Bool {
        
        if answer.count != 3 {
            
            print("         Please Enter 3 Numbers again.\n")
            recordManager.inreaseAnsCount()
            
            return true
        } else {
            
            if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] { // to avoid duplicated number
                
                print("         Duplicated numbers detected!\n         Please Enter 3 Numbers again.\n")
                recordManager.inreaseAnsCount()
                
                return true
                
            } else {
                
                recordManager.inreaseAnsCount()
                
                return false
            }
        }
        
    }
    
}

```

return을 함으로써 해결하였는데

문제는 recordManager쪽이다. 모든 클래스가 다 쓰고 있어서 이걸 어떻게 해야할지 많은 고민이 든다.

recordManager는 수많은 시행착오를 겪다가 갑자기 아이디어가 떠올랐다.

요지는 이것이었다.

> static을 사용하지 않고 어떻게 숫자가 증가하고, 배열에 담을것인가?

그래서 recordManager와 recordModel을 보았다.

일단 의미없는 gameCount를 삭제했다. 쓰이지도 않았고, 또한 게임횟수는 배열에서 i+1로 이미 횟수를 보이고있기 때문이었다.

그래서 배열은 후순위에 두고 ansCount를 어떻게 내가 1씩 증가를 시킬것인가를 생각해보았다.

```swift
func start () {
        
        // 기록 데이터 초기화.
        recordModel.ansCount = 0
        recordModel.scoreArray = []
```

일단 사용하기 위해서 이부분에 게임시작과 동시에 사용하게 초기화를 해주었다.

그리고 함수도 무의미한 것들은 죄다 지웠다.

그리고 게임을 재시작의 경우를 생각하여 1을 눌렀을때 다시 0으로 초기화 하게 해주었다.

```swift
case 1 : // 1을 눌렀을때
                
    gameModel.question = makingQuestion.makeQuestion() // 문제 생성 시작
                
    gameModel.gameStart = true // 실제 게임을 실행할 while문의 조건을 true
                
    recordModel.ansCount = recordManager.resetCount() // 게임 재시작의 경우도 고려하여 시도횟수 0으로 초기화
```

시도횟수를 튜플을 안쓰고 오기를 부려보다, 결국 안되었다.

튜터님께도 여쭤보았지만, 튜플을 사용하지 않고도 하는 방법은 있다고 하셨으나, 현재 단계에서는 튜플이 제일 좋은 방법이라고 하셨다.

그래서 결국 튜플을 사용하였다.

```swift
let result = inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount)
                            // 유져가 입력한 값을 검증한다.
                           
                            gameModel.ansCheck = result.0
                            recordModel.ansCount = result.1
```
inputManager에서 원래는 answer만 받아오는걸로 하다가, inputManager안에는 시도 횟수를 증가시키는 함수가 존재하기에,
다음과 같이 수정해주었다.

> `inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount)`
>> parameter : 내가 입력한 값, 현재의 시도횟수
>>> return (Bool, Int)

이렇게 했다

```swift
func answerCheck (answer : [Int], number : Int) -> (Bool, Int) {
        
        if answer.count != 3 { // 3자리가 아닌 수를 입력했을때
            
            print("         Please Enter 3 Numbers again.\n")
            var Number = number
            Number = recordManager.inreaseAnsCount(number: Number) // 1번 시도했으므로 시도횟수 1 증가
            
            return (true, Number)
        } else {
            
            if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] { // 중복숫자를 입력했을 경우
                
                print("         Duplicated numbers detected!\n         Please Enter 3 Numbers again.\n")
                var Number = number
                Number = recordManager.inreaseAnsCount(number: Number) // 1번 시도했으므로 시도횟수 1 증가
                
                return (true, Number)
                
            } else {
                
                var Number = number
                Number = recordManager.inreaseAnsCount(number: Number) // 1번 시도했으므로 시도횟수 1 증가
                
                return (false, Number)
            }
        }
        
    }
```

위에서 바뀐거라면 파라미터를 하나더 받고, 1을 증가시키고 그걸 튜플로 리턴하게 하는것이었다.

그렇게 받은 데이터를 이제 입력해야하는데, 처음에는 무식하게 해버렸다.

```swift
gameModel.ansCheck = inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount).0
recordModel.ansCount = inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount).1
```

변수를 생성하지 말고 해야한다는 그런 의미없는 생각이 뇌를 지배해버려서 만들어낸 괴짜 코드이다.

저렇게 실행하면 함수가 두번 호출되기에 출력도 2번, 그리고 시도횟수도 2로 올라가기에 의미가 없었다.

순간 멍해졌다. 어떻게해야할지 아무 생각이 없었다..

튜터님께 여쭤봤는데, 너무 기본적인걸 망각했다.

그냥 변수를 하나 만들어서 처리하면 되는것이었는데, 이미 뇌를 잠식당해서 그랬던것이었을까 생각을 하질 못했다.

그래서 튜터님의 조언을 받아 다음과같이 수정하였다.

```swift
let result = inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount)
// 유져가 입력한 값을 검증한다.
                           
    gameModel.ansCheck = result.0
    recordModel.ansCount = result.1
```
RecordManager의 increaseAnsCount 함수도 다음과 같이 수정해주었다.

```swift
func increaseAnsCount (number : Int) -> Int {
        var Number = number
        Number += 1
        return Number
    }
```

while문 안에 print를 넣어 테스트를 해보니 잘 되었다.

이제 남은 건 배열에 어떻게 넣는가? 이다.

원래는 3strike일때, 함수를 사용하여, 배열에 담으려고 하였다.

근데 생각해보니 그 배열은 어떻게 내가 가져오고 다시 리턴을 시키느냐? 였다.

이미 클래스에서 리턴없이 했을때 아무리 내가 배열에 넣어도 현재 실행중인곳에는 값이 전달이 되지 않았던 것을 경험 하였기에,

생각이 많아졌다.

그러다가 문특 아이디어가 떠올랐다.

while문 밖에 하는건 어떨까? 였다.

그래서 처음에는 테스트를 하기위해 `recordModel.scoreArray.append()` 를 사용하여 3스트라이크 이후 게임이 종료되고 메인 화면으로

돌아갔을때, 기록에 배열값이 남느냐를 확인해보았다.

잘되었다.

즉 베열에 관한 내용은 여기에 담으면 되나? 라는 생각에서 확신으로 되는데는 그리 오랜시간이 걸리지 않았다.

이젠 이걸 어떻게 함수로 바꾸냐? 였다.

>`recordModel.scoreArray = recordManager.saveCount(array: recordModel.scoreArray, count: recordModel.ansCount)`
>> parameter : 시도횟수를 담을 배열, 시도횟수
>>> return (Array)

그리고 recordModel의 saveCount도 다음과 같이 바꿔주었다.

```swift
func saveCount (array : [Int], count : Int) -> [Int] {
        var scoreArray = array
        scoreArray.append(count)
        return scoreArray
    }
```

이러고나니 기록을 확인할 showRecord역시 바꿔야해서 바꿔주게 되었다.

왜냐 파라미터를 받아서 그걸 통해 넘겨야만 값이 전달이 되기때문이다.

`recordManager.showRecord(array: recordModel.scoreArray)`

이렇게 하고 함수도 다음과 같이 바꿔 주었다.

```swift
func showRecord (array : [Int]) {
        let scoreArray = array
        
        if scoreArray.count != 0 { // 게임을 한판이라도 했다면
            
            print("         <<<<< Game Records >>>>>")
            for i in 0 ..< scoreArray.count {
                print("           \(i+1) Game, Attempts : \(scoreArray[i])\n")
            }
            
        } else { // 아예 한판도 안했다면
            
            print("          There is no Game Record.\n")

        }
    }
```

작동 테스트를 해보니 잘된다.

팀원들과 이야기를 했던 것이 생각나서 하나의 예외를 더 처리해주었다.
Lv3인데, 나는 문제 생성만 0이 안되게 하면 되는줄 알았다.

근데 아닌것 같아서 예외를 별도로 처리한다.

`let input = readLine()` Int로 형변환을 했던것을, String optional로 하였다.

`if let input = input {`을 사용해 옵셔널 바인딩 처리를 했다.

처음에는 이렇게만 하고 돌려봤는데 아니나 다를까 문자를 입력하니

`gameModel.answer = input.map{Int(String($0))!}` 이부분에서 에러가 발생한다.

그래서 생각을 해보다가, 어차피 옵셔널 바인딩은 했고 문자와 숫자를 구별하기 위해서 isNumber를 사용하기로 했다.

그래서 if조건을 하나 더 추가해줬다.

` if input.filter({$0.isNumber}).count == input.count {`

고차함수를 사용해서 내가 입력한게 정수인지를 판별하고 그것의 갯수와, 내가 입력한 값의 문자열의 갯수를 카운트해서 같으면 진행하게 하였다.

그게 아니면 횟수만 증가하게 하였다.

이렇게 얼추 구현할 건 다한것같다.

---

최종 코드는 아래와 같다.

Model
```swift
// GameModel

import Foundation

struct GameModel {
    
    var answer = Array<Int>()
    var question = Array<Int>()
    
    var gameStart : Bool = true
    var ansCheck : Bool = true
    var gameTitle : Bool = true
    
}

// QuestionModel

import Foundation

struct QuestionModel {
    
    var numbers = Array<Int>()
    var quesMaking : Bool = true
    
}

// BallCountModel

import Foundation

struct BallCountModel {
    
    var ballCount = Dictionary<String,Int>()
    
}

// RecordModel

import Foundation

struct RecordModel {
    
   var ansCount : Int = 0
   var scoreArray = Array<Int>()
    
}

```

Controller
```swift
// BaseballGame

import Foundation

// MARK: - 게임 큰틀에 대해 구현

class BaseballGame{
    
    var gameModel = GameModel()
    var recordModel = RecordModel()
    
    let recordManager = RecordManager()
    let makingQuestion = MakingQuestion()
    let ballCountManager = BallCountManager()
    let inputManager = InputManager()
    
    
    func start () {
        
        // 기록 데이터 초기화.
        recordModel.ansCount = 0
        recordModel.scoreArray = []
        
        while gameModel.gameTitle { // gameTitle이 true일때 무한 반복
            
            print("               ⚾️ Play Ball ⚾️")
            print(" [1]. Game Start! [2]. Game Record [3]. Exit ")
            
            let titleInput = Int(readLine()!)
            
            switch titleInput { // 유져의 값에 따라 각각 다른 기능 실행
                
            case 1 : // 1을 눌렀을때
                
                gameModel.question = makingQuestion.makeQuestion() // 문제 생성 시작
                
                gameModel.gameStart = true // 실제 게임을 실행할 while문의 조건을 true로 다시 바꾼다
                                                 // 게임이끝나면 false로 바뀌기 때문.
                
                recordModel.ansCount = recordManager.resetCount() // 게임 재시작의 경우도 고려하여 시도횟수 0으로 초기화
                
                while gameModel.gameStart {
                    
                    gameModel.ansCheck = true // 위의 내용과 이하동문
                    
                    while gameModel.ansCheck { // ansCheck를 통해 유져가 3자리의 숫자만 입력하게한다.
                                                     // 3자리를 입력했을때 false로 빠져나간다.
                        
                        print("           Please Enter 3 Numbers")
                        print(gameModel.question)
                        
                        let input = readLine() // 유져의 입력값을 받는다.
                        
                        if let input = input { // 옵셔널 바인딩
                            
                            if input.filter({$0.isNumber}).count == input.count {
                                // 내가 입력한 값에 혹시라도 문자가 있는지 없는지 확인 숫자만 이루어진다면 양변의 값은 같다.
                                
                                gameModel.answer = input.map{Int(String($0))!}
                                
                                let result = inputManager.answerCheck(answer: gameModel.answer, number: recordModel.ansCount)
                                // 유져가 입력한 값을 검증한다.
                                
                                gameModel.ansCheck = result.0
                                recordModel.ansCount = result.1
                                
                            }
                            else { // 유져가 숫자가 아닌 값을 입력했을때.
                                
                                print("      Please Enter the Number Correctly")
                                recordModel.ansCount = recordManager.increaseAnsCount(number: recordModel.ansCount)
                                // 시도 횟수 1증가.
                            }
                            
                        } else { // 옵셔널 바인딩에 실패했을경우
                            
                            print("Exception Detected")
                            break
                            
                        }
                        
                    }
                    
                    
                    
                    ballCountManager.resetAllBallCount() // 볼카운트를 초기화
                    ballCountManager.getTotalCount(gameModel.question, gameModel.answer) // 문제와 내가 입력한 값을 통해 볼카운트를 구한다.
                    
                    gameModel.gameStart = ballCountManager.checkBallCount() // 현재 볼카운트를 체크하여 해당 조건에따라 결과를 다르게함.
                    
                    
                }
                
                recordModel.scoreArray = recordManager.saveCount(array: recordModel.scoreArray, count: recordModel.ansCount) // 게임 종료 후 현재 값을 배열에 저장해준다.
                
                
            case 2 : // 메인화면에서 2를 입력했을때
                
                recordManager.showRecord(array: recordModel.scoreArray) // 현재 배열을 가져와서 기록을 보여준다.
                
            case 3 : // 메인화면에서 3을 입력했을때
                
                print("                  Good Bye👋")
                gameModel.gameTitle = false
                
            default : // 그 외의 숫자나 문자를 입력했을때
                
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
    
    func makeQuestion() -> [Int] {
        
        // initialize
        gameModel.question = [] // 재시작의 경우를 고려 초기화
        questionModel.numbers = (0...9).map{$0} // 0~9까지 배열을 만들어준다
        questionModel.quesMaking = true
        
        // making question
        while questionModel.quesMaking {
            
            var a = 0
            
            a = questionModel.numbers.randomElement()! // 랜덤의 수를 하나 배열에서 추출
            gameModel.question.append(a) // 문제에 해당 값을 추가
            questionModel.numbers.remove(at:questionModel.numbers.firstIndex(of: a)!) // 추가한값은 0~9까지의 배열에서 제거 (중복을 피하기위해)
            
            if gameModel.question[0] == 0 { // 처음에 0이 들어가면
                gameModel.question = [] // 빈배열로 초기화
                continue
            }
            
            if gameModel.question.count == 3 { // 3자리의 수가 만들어지면
                questionModel.quesMaking = false
            }
            
        }
        
        return gameModel.question // 문제 리턴
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
        
        // 고차함수를 사용하고 싶어서 사용해보았다.
        
        answer.enumerated().forEach{ // enumerated를 사용하여 인덱스 값 생성
            (aoffset, aelement) in question.enumerated().forEach{
                (qoffset, qelement) in
                
                if aoffset == qoffset { // 문제와 내 대답의 인덱스가 서로 일치할때
                    if aelement == qelement { // 그 상태에서 값이 같다면
                        ballCountModel.ballCount["Strike"]! += 1 // strike 1 추가
                    }
                    
                }else { // 문제와 내 대답의 인덱스가 서로 다를때
                    if aelement == qelement { // 그상태에서 값이 같다면
                        ballCountModel.ballCount["Ball"]! += 1 // ball 1 추가
                    }
                    
                }
            }
        }
        
       
    }

    func getBallCount () -> Int { // 볼카운트를 가져온다.
        
        if let ballCount = ballCountModel.ballCount["Ball"] {
            return ballCount
            
        } else {
            return 0
        }
        
    }
    
    func getStrikeCount () -> Int { // 스트라이크 카운트를 가져온다.
        
        if let strikeCount = ballCountModel.ballCount["Strike"] {
            return strikeCount
            
        } else {
            return 0
        }
        
    }
    
    func resetAllBallCount () { // 한번 문제와 나의 대답을 한번 비교 한 후, 값 초기화
        
        ballCountModel.ballCount["Strike"] = 0
        ballCountModel.ballCount["Ball"] = 0
        
    }
    
    func getAllBallCount () -> [String:Int] { // 현재 X strike Y Ball 인지 알기 위해 가져온다.
        
        let ballCount = ballCountModel.ballCount
            return ballCount
        
    }
    
    func checkBallCount () -> Bool {
        
        if getStrikeCount() == 3 { // 3스트라이크라면
            
            print("                HomeRun!!!!!\n")
            
            return false
            
        } else if getStrikeCount() == 0 &&  getBallCount() == 0 { // 아무것도 일치하는게 없다면
            
            print("                    Out!\n")
            
            return true
            
        } else { // 볼 스트라이크가 존재한다면
            
            print("               \(getStrikeCount()) Strike \(getBallCount()) Ball!\n")

            
            return true
        }
    }

}

// RecordManager

import Foundation

class RecordManager {
     
    var recordModel = RecordModel()
    
    // 숫자 1씩 증가
    func increaseAnsCount (number : Int) -> Int {
        var Number = number
        Number += 1
        return Number
    }
    
    // 현재의 카운트를 배열에 저장
    func saveCount (array : [Int], count : Int) -> [Int] {
        var scoreArray = array
        scoreArray.append(count)
        return scoreArray
    }
    
    func resetCount () -> Int {
        
        return 0
    }
    
    // 현재 기록을 본다.
    func showRecord (array : [Int]) {
        let scoreArray = array
        
        if scoreArray.count != 0 { // 게임을 한판이라도 했다면
            
            print("         <<<<< Game Records >>>>>")
            for i in 0 ..< scoreArray.count {
                print("           \(i+1) Game, Attempts : \(scoreArray[i])\n")
            }
            
        } else { // 아예 한판도 안했다면
            
            print("          There is no Game Record.\n")

        }
    }
    
}

// InputManager

import Foundation

// MARK: - 입력 담당

class InputManager {
    
    let recordManager = RecordManager()
    
    
    func answerCheck (answer : [Int], number : Int) -> (Bool, Int) {
        
        if answer.count != 3 { // 3자리가 아닌 수를 입력했을때
            
            print("         Please Enter 3 Numbers again.\n")
            var Number = number
            Number = recordManager.increaseAnsCount(number: Number) // 1번 시도했으므로 시도 횟수 1 증가
            
            return (true, Number)
            
        } else {
            
            if answer[0] == answer [1] || answer[0] == answer [2] || answer[1] == answer [2] { // 중복 숫자를 입력했을 경우
                
                print("         Duplicated numbers detected!\n         Please Enter 3 Numbers again.\n")
                var Number = number
                Number = recordManager.increaseAnsCount(number: Number) // 1번 시도했으므로 시도 횟수 1 증가
                
                return (true, Number)
                
            } else {
                
                if answer[0] == 0 { // 처음에 0을 입력한다면
                    
                    print("          First number must not be 0\n         Please Enter 3 Numbers again.")
                    var Number = number
                    Number = recordManager.increaseAnsCount(number: Number) // 1번 시도했으므로 시도 횟수 1 증가
                    
                    return (true, Number)
                    
                } else { // 제대로 된 값을 입력한다면
                    
                    var Number = number
                    Number = recordManager.increaseAnsCount(number: Number) // 1번 시도했으므로 시도 횟수 1 증가
                    
                    return (false, Number)
                    
                }
                
            }
        }
        
    }
    
}



```

```swift
// main

import Foundation

let game = BaseballGame()
game.start()
```

## FeedBack

피드백을 받았다.

코드에서는 이견이 없다고 하셨다.

이것만큼 극찬이 더 이상 존재할까?

사실 과제 제출 마감일 오전에 나에게 큰 영감을 주셨던 튜터님과의 대화에서도 코드에서는

더이상 손댈부분이 없다고 하셨다.

유일하게 하나 뽑는다면 변수의 이름을 어떻게 하는지?

문제는 3시간만에 풀고, 클래스화 하는데 이틀 반이 걸렸는데, 그러면서

class화에 대해서 끝없이 튜터님과 대화를 하면서 깨달음을 얻은 결과가 아닐까 싶다.

커밋 히스토리만 조금 더 자세히 적도록 해보자.

지속적으로 해당 코드를 어떻게 발전을 시킬것인가에 대한 고민을 했던게 너무 의미가 있지 않았나 내 스스로 평가해본다.