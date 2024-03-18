---
title: Quizzler (5) Advanced
writer: Harold
date: 2024-02-27 04:13:00 +0800
categories: [Udemy, Quizzler]
tags: []

toc: true
toc_sticky: true
---
![](https://velog.velcdn.com/images/haroldfromk/post/1eaa1a29-8526-4b71-ae25-b798b123506a/image.png)

위의 사진 처럼 여태해온 2지선다가 아닌 3지선다로 UI와 code 모두 수정해보자.

---

1. 주어진 문제는 3지선다이고, 정답도 따로있다.
우선 주어진 문제는 아래와 같다
q: "Which is the largest organ in the human body?",
a: ["Heart", "Skin", "Large Intestine"], correctAnswer: "Skin"

q: / a: / correcntAnswer :

이런 형식으로 되어있다.
Structure를 바꿔보도록하자.

```swift
//before
import Foundation

struct Question {
    let text : String
    let answer : String
        
    init(q: String, a: String) {
        text = q
        answer = a
    }
}

//after
import Foundation

struct Question {
    let text : String
    let answer : [String]
    let correctAnswer : String
        
    init(q: String, a: [String], correctAnswer : String) {
        text = q
        answer = a
        self.correctAnswer = correctAnswer
    }
}
```
새로운 매개변수 correctAnswer를 만들어주었고, answer가 string이었던것을 배열로 바꿔 주었다.
그리고 init()안의 parameter도 추가를 해주었다.

처음에 init parameter를 생각지 못해서
분명히 안에 코드를 다 적었는데 왜 에러가 나나 잠깐 고민을 했다.
![](https://velog.velcdn.com/images/haroldfromk/post/5ca02efd-bb0e-4cee-987e-303ee27d56d0/image.png)

안에 correctAnswer로 내부 파라미터가 들어갔기에
self.를 적지않으면 error가 발생한다.
![](https://velog.velcdn.com/images/haroldfromk/post/f6beaacb-9719-4631-8f3d-8dafa615fea4/image.png)

그렇게 내부 parameter까지 수정을 하면서 structure 부분을 끝냈다
정확히말하면 Question.swift 파일을 끝냈다.

---
2. UI 수정.
![](https://velog.velcdn.com/images/haroldfromk/post/7837ad7e-ee62-46bf-95ec-bde8627bf13d/image.png)
![](https://velog.velcdn.com/images/haroldfromk/post/d9ee1e6d-5347-4797-be39-c2c31a1d2f70/image.png)

2지선다가 아닌 3지선다를 하기위해 버튼을 추가 해주었다.

Title name이 현재 True로 되어있다.
![](https://velog.velcdn.com/images/haroldfromk/post/66a86b35-76ee-428b-b5c4-187d92a6995c/image.png)

배열이름을 바꿔보자
name -> 0, 1, 2 이런식으로 했다
배열안에 답을 골라야 할것 같아서 배열 index에 해당하는 title을 꺼내오기위해 네이밍을 저렇게 했다.

![](https://velog.velcdn.com/images/haroldfromk/post/1074775c-2678-40fb-b214-b4c5e738ab46/image.png){: width="50%" height="50%"}

그리고 

기존에 작업하였던 uibutton은 현재 view controller에 연결이 되어있으므로 끊어주자!
![](https://velog.velcdn.com/images/haroldfromk/post/0881dbb6-0e94-43ac-9237-7f1f7632a2d0/image.png)

그냥 해당 버튼을 우클릭하고 빨갛게 표시한 저 x 버튼만 눌러주면 main과 controller의 연결이 끊어진다.

![](https://velog.velcdn.com/images/haroldfromk/post/cfa02a9f-e407-4601-bbda-28718f9222bb/image.png){: width="50%" height="50%"}

아주 잘 끊어졌다.
![](https://velog.velcdn.com/images/haroldfromk/post/9110d927-537a-4245-9262-28bd6c216f1f/image.png){: width="50%" height="50%"}

그렇게 버튼에 현재 연결되어있던것을 끊어주었다.
(기존에 있던 프로젝트를 수정하는것이므로)
![](https://velog.velcdn.com/images/haroldfromk/post/0518a721-c524-4649-9f65-7f564b644d5d/image.gif)

그리고 새로운 연결을 해주었다.
![](https://velog.velcdn.com/images/haroldfromk/post/e2351855-264f-48e9-ae7e-51adbf6c5a63/image.png){: width="50%" height="50%"}

나는 zero / first / second Button으로 해주었다.
![](https://velog.velcdn.com/images/haroldfromk/post/9bf59f85-a30e-459e-b297-b29897ce3512/image.gif)

이렇게 모두 연결이 되었다!
![](https://velog.velcdn.com/images/haroldfromk/post/feb421b7-668a-4d53-8090-5fe5b5f8afca/image.png){: width="50%" height="50%"}

그리고 IBaction도 새로 만들어주어야 하는데 이것은 생략하겠다. 방식은 같다.
(나는 기존의 작성되어있는것을 그대로 두고 내부 코드만 바꿔보려고한다.)

---
이제부터가 진짜 시작이다. 어떻게 보면 기존의 코드를 수정하는것이지만 새로운 버튼이 추가되었기에 그부분도 테스트를 하면서 계속 코드를 작성 그리고 디버깅을 해야할 것 같다. 이부분은 꽤 길어질것같아 다음글에서 서술 하도록 하겠다.