---
title: Destini
writer: Harold
date: 2024-02-28 04:13:00 +0800
categories: [Udemy, Quizzler]
tags: []

toc: true
toc_sticky: true
---
Quizzler를 했던것을 기반으로 스스로 만들어보자.
![](https://velog.velcdn.com/images/haroldfromk/post/62dafe74-1c02-4364-9f99-22190d5f4aa4/image.gif){: width="50%" height="50%"}

완성 화면은 위와 같다.

---
start!

1. 우선 어떤 기능인지에 대해 먼저 파악을 해보자.
- quizzler와 거의 같은 형태의 App이다.
- 즉, 코드의 전개는 거의 비슷할 것이다.
- 하지만 버튼들을 보면 뭔가 문제에 대한 정답보다는 현재 진행되는 스토리에 따라 내가 어떤 답을 하면 그에 따라 다른 스토리가 진행되는 그런 방식의 App으로 보인다.

---
2. ui설정을 해주자.

우선 
```swift
Story(
		title: "Your car has blown a tire on a winding road in the middle of nowhere with no cell phone reception. You decide to hitchhike. A rusty pickup truck rumbles to a stop next to you. A man with a wide brimmed hat with soulless eyes opens the passenger door for you and asks: 'Need a ride, boy?'.",
        choice1: "I'll hop in. Thanks for the help!", 
        choice1Destination: 2,
        choice2: "Better ask him if he's a murderer first.", 
        choice2Destination: 1
    )
```
이런식으로 값이 들어간다.

그러므로 Model의 Story.swift에 다음과 같이 넣어준다.
```swift
import Foundation

struct Story {
    let title : String
    let choice1 : String
    let choice1Destination : Int
    let choice2 : String
    let choice2Destination : Int
    
    init (title : String, choice1: String, choice1Destination : Int, choice2: String,  choice2Destination : Int) {
        self.title = title
        self.choice1 = choice1
        self.choice1Destination = choice1Destination
        self.choice2 = choice2
        self.choice2Destination = choice2Destination
    }
}

```

우선 Story.swift에 들어갈 뼈대는 만들어진것같다.
StoryBrain.swift에 내용을 넣었을때 Error가 발생하지는 않았다.

일단 structure를 구성하면서 내 나름대로 매개변수가 어떤것을 의미하는지 정리 해보았다.

- title : 현재 진행되는 story를 보여주는 문장.
- choice1 : 이지선다에서 선택해야하는 text
- choice2 : 이지선다에서 선택해야하는 text
- choice1Destination : 첫번째 text를 선택했을때 가게되는 index
- choice2Destination : 두번째 text를 선택했을때 가게되는 index

---

3. 필요한걸 하나씩 추가하면서 기능 구현을 해보도록 하자.

우리가 실제로 기능을 구현할 함수를 적는곳은 viewController가아닌, StoryBrain.swift가 될것이다.

의식의 흐름대로 코드를 짜보기로 했다.

우선 StoryLabel에 story가 나와야하니 그것을 가져올 함수를 구현해보자.
```swift
func getTitle () -> String {
        
        var title = story[destination].title
        
        return title
    }
```
playground로 제대로 출력이 되는지test를 해보자.
![](https://velog.velcdn.com/images/haroldfromk/post/57c3ebee-f961-4cf6-a62b-4297ce057612/image.png)

okay 일단 출력은 된다!

그리고 각 choice1 / 2에 담을 text를 가져올 함수도 구현해 주었다

```swift
func getChoice1 () -> String {
        
        var choice1 = story[destination].choice1
        
        return choice1
    }
    
func getChoice2 () -> String {
        
        var choice2 = story[destination].choice2
        
        return choice2
    }
```

그리고 여태까지 만든 함수들을 적용할 viewcontroller에서 updateUI 함수를 새로 만들었고 기능을 넣어주었다.
```swift
 func updateUI () {
        storyLabel.text = StoryBrain().getTitle()
        
        var getchoice1 = StoryBrain().getChoice1()
        var getchoice2 = StoryBrain().getChoice2()
        choice1Button.setTitle(getchoice1, for: .normal)
        choice2Button.setTitle(getchoice2, for: .normal)

    }
```

그리고 실행해 보았다. 중간점검!
![](https://velog.velcdn.com/images/haroldfromk/post/77ba8968-3db6-4dfe-b884-5680abab0324/image.png){: width="50%" height="50%"}

내가 의도한대로 현재까진 잘 되었다.

빈 깡통이라 초기화면에대한 구성만 되었고 되진 않는다.
![](https://velog.velcdn.com/images/haroldfromk/post/39a6c6ef-2952-428c-8432-96941b02bf21/image.gif){: width="50%" height="50%"}

---
4. 깡통 구성이 되었으니 이젠 버튼에 대한 코드를 작성해보도록 하자.

작성전, 버튼에서 뭘 필요로 하는지를 다시한번 생각해보자.

► 버튼을 눌렀을때 기존에는 1씩 증가하는 방식으로 이루어 졌지만 이번에는 버튼을 눌렀을때 답과 일치하는것이 아닌, 1번에 관련있는 인덱스값을 보내줘야한다.

이젠 buttonpressed를 건드릴때다.
생각을 해보니 choice1 / choice1Destination은 story안에 별도로 나뉘어진 매개변수이다.

buttonpressed 하나로 ibaction을 했을때 구분이 가능할까 라는 생각을 해보았는데, 현재 내가 가진 지식으로는 안될것 같다라는 판단이 들어서

IBaction을 하나더 만들기로 결정하였다.
일단은 내방식대로 만들고 비교를 해보는걸로.

(나중에 git에 올라가있는 completed code를 확인해야할거같다)

```swift
@IBAction func choice1Pressed(_ sender: UIButton) {
    }
    
@IBAction func choice2Pressed(_ sender: UIButton) {
    }
```

하나였던 Ibaction을 2개로 만들었다.

코드를 작성을 해보다가 갑자기 1개로도 되지않을까 싶어 다시 1개로 만든다...

코드를 적으면서 생각을 해보던중

destination을 선택하는건 이렇게 적어보았다.
```swift
mutating func selectDestination (_ choice : String) {
                
        if choice == getChoice().choice1 {
            destination = getChoice().choice1Destination
        } else {
            destination = getChoice().choice2Destination
        }
    }
    
```

고민을 하던중.. 버튼을 눌렀을때 어떤 액션도 없다는걸 테스트 하면서 알게되었다...
```swift
@IBAction func buttonPressed(_ sender: UIButton) {
        
        let userChoice = sender.currentTitle!
            
        let userDestination = storyBrain.selectDestination(userChoice)

        updateUI()
     	----------   

    }
```
그래서 버튼을 눌렀을때 트리거를 작동하게 구현하였다.
그랬더니 작동했다.

뭔가 썩 맘에 들진 않지만 작동은한다
![](https://velog.velcdn.com/images/haroldfromk/post/718f2f8c-3907-498d-8a23-dd1912208f04/image.gif){: width="50%" height="50%"}
하지만 변수로 선언한게 돌아가진 않는다. 강의해서 노란색뜨는건 무시하라고 한거같은데 이건가..
![](https://velog.velcdn.com/images/haroldfromk/post/f320513a-d49e-475e-af48-6687bfe2e0af/image.png){: width="50%" height="50%"}

코드는 깃에 그냥 저장해야겠다.

