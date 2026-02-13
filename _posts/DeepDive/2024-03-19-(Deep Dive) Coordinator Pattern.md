---
title: (Deep Dive) Coordinator Pattern
writer: Harold
date: 2024-03-19 02:32
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

우연히 유튜브를 보다가 Coordinator Design Pattern 이라는 제목의 영상을 보게 되었다.

## 1. 시초
<https://khanlou.com/2015/01/the-coordinator/>

<https://khanlou.com/2015/10/coordinators-redux/>

<https://vimeo.com/144116310>
Khanlou라는 분이 제안을 한 글이다. 시간이 되면 읽어보자.

## 2. Coordinator Pattern 이란?
- VC로 부터 화면 전환의 부담을 줄여주고, 화면 전환을 보다 더 관리하기 쉽도록 고안된 패턴.

## 3. 장점

1. 각각의 VC가 독립적인 개체가 된다.
2. VC를 여러번 사용할 수 있다.
3. 앱의 모든작업과 하위 작업들을 캡슐화 하는 방법이 존재한다.
4. 디스플레이 바인딩을 부작용으로 부터 분리한다.
5. Coordinator는 유져가 완전히 컨트롤 할수있는 개체이다.
6. 하드 코딩에서 벗어난다.

## 4. Diagram

- without children

![](https://i.esdrop.com/d/f/E8Nib9NqGY/DN3oBd2Wqd.png)

- with children

![](https://i.esdrop.com/d/f/E8Nib9NqGY/UmcCFLrudt.png)

- 보면 각각의 VC가 서로를 알 필요가 없다.
- 모든건 Coordinator가 관리한다.

## 5. 기본 틀
### 1. Coordinator Protocol 작성
```swift
protocol Coordinator {
    var children : [Coordinator] { get set }
    var nav : UINavigationController { get set }

    func start()
}
```

### 2. MainCoordinator 작성
```swift
class MainCoordinator : Coordinator {

    func start () {
        let vc = ViewController ()
        vc.coordinator = self
        nav.pushViewController(vc, animated: false)
    }
}

```

## 6. Main interface 지우기

![](https://i.esdrop.com/d/f/E8Nib9NqGY/r8kkgF8IB0.png)

해당 영상을 보다보면 Main interface의 Main을 지우는데 버전이 바뀌었으므로

위의 사진대로 하면 된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/FLOTTscPnU.png)

그리고 info.plist에서 해당 부분을 지워준다.

## 6-1. 코드 작성

### 1. Coordinator Protocol 작성
```swift
// Coordinator.swift
import Foundation
import UIKit

enum Event { // 현재 여기선 열거형으로 간단하게 만들었다.
    case buttonTapped // 버튼을 탭했을 경우
    
}

protocol Coordinator {
    var navigationControlller : UINavigationController? { get set } // 화면전환에 필요한 UINavigationController
    
    //var children : [Coordinator]? { get set } // 화면 전환시 생성될 하위 Coordinator를 저장할 때 사용.
    // coordinator 생성후 저장하지 않으면 메모리에서 제거되기에 꼭 저장 해야한다.

    func eventOccurred(with type : Event) // 이벤트가 발생했을때
    
    func start () // 앱이 시작될때 호출하는 함수 설정
}

protocol Coordinating { // 모든 VC가 이벤트를 전달하기 위한 Coordinator에 대한 참조가 필요.
    
    var coordinator : Coordinator? { get set }
    
}
```



### 2. AppDelegate, SceneDelegate 수정
```swift
// AppDelegate
var window: UIWindow?

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        
        let navVC = UINavigationController()
        
        let coordinator = MainCoordinator()
        coordinator.navigationControlller = navVC
        
        let window = UIWindow(frame:  UIScreen.main.bounds)
        window.rootViewController = navVC
        window.makeKeyAndVisible()
        self.window = window
        
        coordinator.start()
        
        return true
    }

// SceneDelegate
var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let navVC = UINavigationController()
        
        let coordinator = MainCoordinator()
        coordinator.navigationControlller = navVC
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navVC
        window.makeKeyAndVisible()
        self.window = window
        
        coordinator.start()
        
    }
```

- 해당 과정을 거치면 Root VC가 앱 시작시 화면에 나오게 된다.

### 3. MainCoordinator 작성
- 우선 뼈대만 작성한다.

```swift
// MainCoordinator.swift
import Foundation
import UIKit

class MainCoordinator : Coordinator {

    var navigationControlller: UINavigationController?
    
    func eventOccurred(with type: Event) {
        
    }
    
    func start() {
        var vc : UIViewController & Coordinating = ViewController()
        
        vc.coordinator = self
        
        navigationControlller?.setViewControllers([vc], animated: false)
    }
    
    
}

```

### 4. VC 작성
```swift
import UIKit

class ViewController: UIViewController,Coordinating {
    
    var coordinator : Coordinator?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .red
        title = "Home"
        
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 220, height: 55))
        view.addSubview(button)
        button.center = view.center
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        button.setTitle("Tap me!", for: .normal)
    }
    
    @objc func didTapButton () {
        coordinator?.eventOccurred(with: .buttonTapped)
        
    }

}

```

### 5. SecondVC 작성
```swift
import UIKit

class SecondViewController: UIViewController, Coordinating {
    var coordinator: Coordinator?
    

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Second"
        view.backgroundColor = .systemBlue
        
        
    }
    
}

```

### 6. MainCoordinator 코드 보완
```swift
class MainCoordinator : Coordinator {
    
    var navigationControlller: UINavigationController?
    
    func eventOccurred(with type: Event) {
        switch type {
        case .buttonTapped :
            let vc : UIViewController & Coordinating  = SecondViewController() 
            
            navigationControlller?.pushViewController(vc, animated: true)
        }
    }
    
    func start() {
        var vc : UIViewController & Coordinating = ViewController()
        
        vc.coordinator = self
        
        navigationControlller?.setViewControllers([vc], animated: false)
    }
    
    
}

```

### 7. 작동 테스트

![](https://i.esdrop.com/d/f/E8Nib9NqGY/LjryMVB9fk.gif)

## 7. 복기

우선 해당내용은 유튜브 알고리즘에 의해 우연히 알게 되었고, 튜터님과 이야기 하던중 VC간 서로 연결이 되어있지 않아도 데이터 전달이 가능하다고 해서 혹시 이건가? 싶어서 일단 유튜브 보면서 코드부분만 정리를 해보았다.

조금 더 지식이 쌓이게 된다면 정리를 해야할 것 같다.

얼추 어떤 느낌이다 라는건 감이 오지만 정확하게 각각 의미하는 바를 설명하기엔 완벽하지는 않다.

그래도 이런것이 있고 찍먹만 해본것도 만족한다.

주말에 진득하게 파봐야 할 것 같다.

그리고 찾는 자료마다 표현하는 방식이 너무 다르다.

## 출처
<https://siwon-code.tistory.com/38>

<https://velog.io/@ellyheetov/Coordinator-Pattern>

<https://jintaewoo.tistory.com/58>

<https://www.youtube.com/watch?v=SAZzcKvOvAE&t=1124s>