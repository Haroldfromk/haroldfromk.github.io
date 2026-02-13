---
title: Quizzler (6) Advanced
writer: Harold
date: 2024-02-27 04:13:00 +0800
categories: [Udemy, Quizzler]
tags: []

toc: true
toc_sticky: true
---
이어서 내부 코드를 수정해보도록 하자.

3. 코드 수정.
위에서부터 아래로 내려가면서 고쳐보려고한다.
![](https://velog.velcdn.com/images/haroldfromk/post/341d7bb5-f567-4492-b5dd-4991f76f596e/image.png){: width="50%" height="50%"}

일단 title을 0,1,2로 하면서 sender.title을 가져올때 주석과같이 0,1,2로 리턴하게 하였다.

하지만 0,1,2가 어떤타입으로 리턴이 되는지 모르기에 일단 
```swift
print(type(of:userAnswer))
```
이걸 적으면서 어떤 타입으로 값이 리턴이 되는지 알아보기로 했다. 하지만 아직 확인 할 수는 없다.

UI와 structure를 고치고 있기에 그와 관련된 코드들이 모두 터지고 말았다...
하나씩 수정하면서 가보자

위에서 아래로 흐름을 따라 코드를 보던 중

![](https://velog.velcdn.com/images/haroldfromk/post/9306b261-2677-4d71-98b7-6d121fc927b4/image.png){: width="50%" height="50%"}

```swift
// if user's answer is correct
let userGotItRight = quizBrain.checkAnswer(userAnswer)


mutating func checkAnswer(_ userAnswer: String) -> Bool {
        if userAnswer == quiz[questionNumber].answer {
            score += 1
            return true
        } else {
            return false
        }
    }
```
function에서 에러가 났다. 저 부분을 수정해보자.
```swift
mutating func checkAnswer(_ userAnswer: String) -> Bool {
        if userAnswer == quiz[questionNumber].correctAnswer {
//                                            -------------
            score += 1
            return true
        } else {
            return false
        }
    }
```
저 밑줄친 부분을 수정 하였다.
userAnswer가 실제 정답일때? 를 조건으로 해야하므로
quiz내에 correctAnswer를 사용했다.

이제 true/falsebutton에 관한 error이다.
왜냐하면 우리는 true/false버튼을 없애고 0,1,2 이런식으로 버튼을 바꿨기에 없는것이 당연하다.

![](https://velog.velcdn.com/images/haroldfromk/post/0ba03fa6-c2ba-456b-8693-f8a2ada0a034/image.png){: width="50%" height="50%"}

```swift
@objc func updateUI() {
        questionLabel.text = quizBrain.getQuestionText()
        progresBar.progress = quizBrain.getProgress()
        scoreLabel.text = "Score: \(quizBrain.getScore())"
        zeroButton.backgroundColor = UIColor.clear
        firstButton.backgroundColor = UIColor.clear
        secondButton.backgroundColor = UIColor.clear
    }
```
각각의 버튼을 zero / first / second로 바꿔 주었다.

작동해보자.

![](https://velog.velcdn.com/images/haroldfromk/post/ffd31c6a-3d9d-4a02-bf0e-b7e8e54e8ae7/image.png){: width="50%" height="50%"}

켜자마자 문제를 찾았다...
문제에 대한 3지선다인데 그 3지선다를할 내용이 표시가 되지않았다....
그리고 print를 사용해서 title의 type을 보니 string이었다.
![](https://velog.velcdn.com/images/haroldfromk/post/92d87e34-c01b-481a-bf9c-c7bf0a2e03b0/image.gif){: width="50%" height="50%"}
그리고 문제도 다음문제로 넘어갔고...

저 button의 title을 3지선다에 있는 선택지로 바꿔준다면 해결이 될것같다!

---
우선 그부분과 관련된 코드쪽을 찾아보자.

일단 의심스러운 곳은 여기이다.
![](https://velog.velcdn.com/images/haroldfromk/post/efad11af-bf08-433c-bfdf-ae395facebb0/image.png){: width="50%" height="50%"}

updateUI에는 우리가 문제, 진행률, 스코어, 버튼 이렇게 계속 트리거를 해주는걸 알수있다.
즉 저부분에 button에 관해 text를 넣어주면 될것같다!

혹시 몰라 우선 ui에 0,1,2로 적었던것을 모두 지웠다.
![](https://velog.velcdn.com/images/haroldfromk/post/4f0f1e77-4d0f-42c0-ae65-e2c069a70306/image.png){: width="50%" height="50%"}

그리고 아래와 같이 적었다
![](https://velog.velcdn.com/images/haroldfromk/post/da179c48-7f61-4213-9022-f2d1d41dec52/image.png){: width="50%" height="50%"}

그럼 이제 structure에가서 관련된 함수를 한번 만들어 보도록 하자!

일단은 각각의 버튼을 통제할 함수를 만들어 주었다.
![](https://velog.velcdn.com/images/haroldfromk/post/3b89030a-c430-4737-8d43-93eb5fdb0490/image.png){: width="50%" height="50%"}

그리고 updateUI도 수정을 해주었다.
```swift
@objc func updateUI() {
        questionLabel.text = quizBrain.getQuestionText()
        zeroButton.titleLabel?.text = quizBrain.getAnswerText0()
        firstButton.titleLabel?.text = quizBrain.getAnswerText1()
        secondButton.titleLabel?.text = quizBrain.getAnswerText2()
        progresBar.progress = quizBrain.getProgress()
        scoreLabel.text = "Score: \(quizBrain.getScore())"
        zeroButton.backgroundColor = UIColor.clear
        firstButton.backgroundColor = UIColor.clear
        secondButton.backgroundColor = UIColor.clear
    }
```
![](https://velog.velcdn.com/images/haroldfromk/post/99a39051-6b47-44db-94e3-a35634521c6d/image.png){: width="50%" height="50%"}

처음에 그냥 titleLabel만 하면되는줄 알았는데 안되어서 다시보니 text가 필요하여 변경해주었다.

작동을 해보자!.
![](https://velog.velcdn.com/images/haroldfromk/post/c1ecf315-3e14-4159-9020-bc1858f47cc1/image.png){: width="50%" height="50%"}

돌리자마자 이상하다. 버튼 내용은 어디갔지?
![](https://velog.velcdn.com/images/haroldfromk/post/fc779ddc-6da9-43e3-a63b-31d8ff87dbd5/image.png){: width="50%" height="50%"}

그리고 버튼을 눌러보니 error가 바로 발생한다.
optional value? 

생각해보니 ui에서 버튼내용을 다 지웠기도 했지만, updateui에서 내가 새롭게 작성한 그 함수가 제대로 작동을 하지 않는것 같다.

문제는 잘나오는걸로 봐선
```swfit
zeroButton.titleLabel?.text = quizBrain.getAnswerText0()
firstButton.titleLabel?.text = quizBrain.getAnswerText1()
secondButton.titleLabel?.text = quizBrain.getAnswerText2()    
```
이부분에 문제가있는것 같다.
```swift
func getAnswerText0 () -> String {
        return quiz[questionNumber].answer[0]
    }
```
혹시 이게 값을 못가져오는게 아닐까?
playground로 테스트를 해봐야겠다.
![](https://velog.velcdn.com/images/haroldfromk/post/1e741b6d-d1bc-43aa-992b-28f109cc3aec/image.png){: width="50%" height="50%"}

확인결과 아주 잘나온다...
그럼 0,1,2를 넣고 다시 테스트를 해보자!
![](https://velog.velcdn.com/images/haroldfromk/post/c6fb19f5-f582-4199-bcf0-3c2270c93fb1/image.gif){: width="50%" height="50%"}

아주 잠깐이지만 값이 나왔다가 0, 1, 2로 덮어버려진다.

강의에서 챌린지때 화면을 다시 보았다.
![])https://velog.velcdn.com/images/haroldfromk/post/da8b7562-192c-456c-b783-021bd8a068ee/image.png){: width="50%" height="50%"}

choice1 choice2 이런식으로 해뒀다..
하지만 나와의 차이점이라면
나는 초기에 해둔 title이 계속 덮어씌워진다는 것이다. viewdidload에서 혹시 건드려야하는걸까 updateui에서 뭘 더 해야하는걸까 좀 더 생각해보자.

```swift
zeroButton.setTitle(QuizBrain().getAnswerText0(), for: .normal)
firstButton.setTitle(QuizBrain().getAnswerText1(), for: .normal)
secondButton.setTitle(QuizBrain().getAnswerText2(), for: .normal)
```
이걸써보니 choice에서 바뀌었다!
![](https://velog.velcdn.com/images/haroldfromk/post/2b171637-438c-446e-983c-b09458dab4e1/image.gif){: width="50%" height="50%"}

하지만 그대로였다. 즉 setTitle을 사용하니 문제는 바뀌는데 버튼의 텍스트가 바뀌지않는다는건
setTitle은 초기에 보여지는 화면의 text를 설정해주는것 같다.

그러면 이걸 viewcontroller에 적고 원래 있던 그대로 해보자.

혹시나 했는데 역시 안된다 viewcontroller 자체에는 안되나보다
![](https://velog.velcdn.com/images/haroldfromk/post/c6dd9fbd-72ca-4430-8390-120378d1c289/image.png){: width="50%" height="50%"}

---
강의 코드를 살짝 보니 이건 내가 모르는 부분이었다..

```swift
 
//Need to fetch the answers and update the button titles using the setTitle method. 
        
let answerChoices = quizBrain.getAnswers()
choice1.setTitle(answerChoices[0], for: .normal)
choice2.setTitle(answerChoices[1], for: .normal)
choice3.setTitle(answerChoices[2], for: .normal)
```
update를 하려면 변수를 만들고 설정을 해줘야하나보다. 저걸수정하니 된다...

```swift
func getAnswerText () -> [String] {
        return quiz[questionNumber].answer
    }
    
zeroButton.setTitle(getAnswer[0], for: .normal)
firstButton.setTitle(getAnswer[1], for: .normal)
secondButton.setTitle(getAnswer[2], for: .normal)    
```
그럼 원래 내가하려고했던것도 될것같다...

일단 titleLable?.text는 되지않기에 pass!
![](https://velog.velcdn.com/images/haroldfromk/post/012315f2-3c5f-4285-9f03-13ae5539d08a/image.png){: width="50%" height="50%"}

setTitle을 하고 실행해보았다.
![](https://velog.velcdn.com/images/haroldfromk/post/3fc7bfc1-aae4-4856-82bc-3284274ee892/image.png){: width="50%" height="50%"}

잘된다...
![](https://velog.velcdn.com/images/haroldfromk/post/0b3c5d82-cf47-4e45-9fc9-3f6ccbe7147a/image.gif){: width="50%" height="50%"}

그래도 이거 하나만 집어넣었더니 잘되어서 다행이다 :)

---
# 오늘 가장 큰 수확!
setTitle을 사용할때는 그냥 structure에서 가져와서 쓰는게 아니라 이렇게 변수를 만들고 집어넣자..
그래야 갱신이 된다!
-> 문제를 보여주는 label하고는 다른 개념이다.

![](https://velog.velcdn.com/images/haroldfromk/post/6cf3d388-39c0-41cc-a103-59464c52810d/image.png){: width="50%" height="50%"}

before (wrong way!)
![](https://velog.velcdn.com/images/haroldfromk/post/5eeccfe4-6c59-42df-95d2-a0e6051f07e8/image.png){: width="50%" height="50%"}

after
![](https://velog.velcdn.com/images/haroldfromk/post/c797ba77-1d7d-4809-808e-bcbb148a529b/image.png){: width="50%" height="50%"}