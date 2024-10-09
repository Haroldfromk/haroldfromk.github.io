---
title: Magic 8 Balls 만들어보기
writer: Harold
date: 2024-02-20 04:13:00 +0800
categories: [Udemy, Dices]
tags: []

toc: true
toc_sticky: true
---
1. 아래와같이 디자인을 한다
![](https://velog.velcdn.com/images/haroldfromk/post/49f1b60f-c2ae-4cff-936b-50f98416cf3b/image.png){: width="50%" height="50%"}

2. imageview와, button을 viewcontroller와 연결 시켜준다.
![](https://velog.velcdn.com/images/haroldfromk/post/41f1a97c-51be-4997-bca5-a34a8deda7e5/image.png){: width="50%" height="50%"}

3. 버튼을 눌렀을때 이미지가 변환이되게 코드를 짠다.
```swift
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    let ballArray = [#imageLiteral(resourceName: "ball1.png"),#imageLiteral(resourceName: "ball2.png"),#imageLiteral(resourceName: "ball3.png"),#imageLiteral(resourceName: "ball4.png"),#imageLiteral(resourceName: "ball5.png")]


    @IBAction func askButtonPressed(_ sender: UIButton) {
        imageView.image = ballArray.randomElement()
    }
    
}


```
4. 작동확인!
![](https://velog.velcdn.com/images/haroldfromk/post/c33a3c2e-54c1-40b0-bbb2-b9e9eb601d10/image.gif){: width="50%" height="50%"}