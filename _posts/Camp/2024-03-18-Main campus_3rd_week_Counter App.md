---
title: 3주차 Counter App
writer: Harold
date: 2024-03-18 14:00
categories: [캠프, 3주차]
tags: []

toc: true
toc_sticky: true
---


## 문제
![](https://i.esdrop.com/d/f/E8Nib9NqGY/ezjwKJfUrs.png)

다음과 같이 주어졌다.

만들어 보자.

우선 프로젝트생성 및 UILabel, UIButton은 생략하겠다.

## 해결 과정
1. 우선 숫자를 표현해야하므로 변수 value를 하나 만들어 주었다.

2. 그리고 앱을 구동하자마자 Label이라고 그대로 보이는것이 아니라,숫자 0으로 보이기 위해서 viewDidLoad에 `displayLabel.text = String(value)` 작성해주었다.

3. 버튼을 구현해준다.
up / down 목적에 맞게 + / - 를 해주고 눌렀을때 값만 변하는게 아닌 화면에 보여줘야하므로 `displayLabel.text = String(value)` 를 작성해주었다.

4. 작동 테스트

![](https://i.esdrop.com/d/f/E8Nib9NqGY/ghN6lwUsez.gif)

잘 된다.

## AutoLayout

1. StackView 지정
- 우선 3개의 Component를 하나의 Stack View로 지정을 해준다.
![](https://i.esdrop.com/d/f/E8Nib9NqGY/3brJZZPGCT.png){: width="50%" height="50%"} 

2. 정중앙에 오도록 지정
- 이번엔 정중앙에 깔끔하게 정리하려고 별도의 Constraints(제약)을 주지는 않겠다.
![](https://i.esdrop.com/d/f/E8Nib9NqGY/pDx22nuiT7.png){: width="50%" height="50%"}

3. label 조금 삐뚤다 가운데 정렬만 해주자
- ![](https://i.esdrop.com/d/f/E8Nib9NqGY/l267proxLw.png){: width="50%" height="50%"}

4. 작동 테스트
![](https://i.esdrop.com/d/f/E8Nib9NqGY/0WnKdUeD4M.png)

잘 된다.

## 완성 코드
```swift

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var displayLabel: UILabel!
    
    var value = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        displayLabel.text = String(value)
    }
    
    
    @IBAction func upBtn(_ sender: UIButton) {
        value += 1
        displayLabel.text = String(value)
    }
    
    
    
    @IBAction func downBtn(_ sender: UIButton) {
        value -= 1
        displayLabel.text = String(value)
    }
    
}
```

>updated(19.Mar)

못들었던 강의를 들으며 해당 부분에대한 설명을 듣는데.

viewDidLoad의 생명주기를 활용을 해주었다고 한다.

```swift
import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var textLabel: UILabel!
    private var count: Int = 0

    // 감소 버튼이 클릭된 경우
    @IBAction func tappedDecreaseButton(_ sender: UIButton) {
        self.count -= 1 // count를 -1 합니다.
        self.refreshTextLabel() // textLabel을 새로고침 합니다.
    }
    
    // 증가 버튼이 클릭된 경우
    @IBAction func tappedIncreaseButton(_ sender: UIButton) {
        self.count += 1 // count를 +1 합니다.
        self.refreshTextLabel() // textLabel을 새로고침 합니다.
    }
    
    // count값을 self.textLabel의 text에 반영합니다.
    private func refreshTextLabel() {
        self.textLabel.text = String(self.count)
    }
    
    // viewDidLoad 생명주기 활용
    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshTextLabel()
    }
}
```

이부분은 미처 생각하지 못했던 부분이다.

생명주기에 대해서 주말에 한번 글을 적어봐야 할 것 같다.