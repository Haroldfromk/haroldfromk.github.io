---
title: BMI Calculator (3)
writer: Harold
date: 2024-03-01 15:19:00 +0800
categories: [Udemy, BMI Calculator]
tags: [Segue]

toc: true
toc_sticky: true
---

지난 글에서 코드로 label, frame 등 코드로 수작업을 해보았다.

확실히 수작업을 해보니 너무나도 불편했다. storyboard가 그리울줄이야..

그래서 여기서는 코드로 UserInterface를 작성하지 않고, 디자인 된 storyboard를 다른 view컨트롤러로 연결 하여 사용하는 것을 해보려한다.

우선 기존의 secondViewController는 이제 사용하지 않을것이다. (지워도 그만 아니어도 그만.)

난 그대로 냅둘 생각이다.

## 새로운 class file 생성

여태 우리는 file을 새로 만들때 Swift File을 선택하였다.

하지만 이번에는 Cocoa Touch Class를 선택하여 만든다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/hSm1Fgqf33.png){: width="50%" height="50%"}

습관이 무섭다고. 막 엔터치지말고 확인하면서 만들자.

> CocoaTouch class ?
>> Apple이 만든 UIkit을 포함한 Framework이다.

아래 밑줄 친 곳에 우리가 naming을 해주면 된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/4IPtg663rO.png){: width="50%" height="50%"}

이렇게 자동으로 만들어준다.

```swift
import UIKit

class ResultViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }
}
```

## Contoller와 StoryBoard 연결하기

만들어진 controller와 디자인된 storyboard를 연결하려면

2가지 방법이 있다. (단지 클릭의 차이)

1. 먼저 storyboard로가서 디자인된 storyboard를 클릭

![](https://i.esdrop.com/d/f/E8Nib9NqGY/TPCGMHATBG.png){: width="50%" height="50%"}

빨갛게 박스한 부분을 클릭

다음과 같이 Inspector Tab에서 네모로 표시한부분을 클릭

![](https://i.esdrop.com/d/f/E8Nib9NqGY/BqtcUNaBeZ.png){: width="50%" height="50%"}

그리고 만들어진 컨트롤러 면을 적어준다. 그러면 링크 끝

2. 왼쪽의 목록에서 viewController 선택

![](https://i.esdrop.com/d/f/E8Nib9NqGY/mo0LsXjFfr.png){: width="50%" height="50%"}

이후 inspector tap에서 똑같이 하면 된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/qFfX4uFrnb.gif)

그리고 Asistant view를 눌러보면 연결되어있는걸 볼 수 있다.

## IBAction IBOutlet 연결해주기

설명은 생략하겠다.

```swift
import UIKit

class ResultViewController: UIViewController {

    @IBOutlet weak var bmiLabel: UILabel!
    
    @IBOutlet weak var adviceLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func recalculatePressed(_ sender: UIButton) {
    }
}
```

혹시라도 이름을 변경하고 싶다면?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/1M8u6bZMSy.png){: width="50%" height="50%"}

이름을 명명한 부분을 우클릭하고 rename을 클릭해준다.

그러면 새로운 창으로 전환되는데 여기서 이름을 바꿔주면된다.

일반적으로 file의 이름이 그 기능의 전반적인걸 표시하게 하는 경우도 있으니 이름을 변경해보자

![](https://i.esdrop.com/d/f/E8Nib9NqGY/clGdD0T6LS.png){: width="50%" height="50%"}

viewController → CalculateViewController로 변경.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/Y7THGmOg3i.png){: width="50%" height="50%"}

변경이 잘 되었다.

## Segue를 통한 viewController 초기화

전에 secondViewController를 viewController에서 사용할때 `var secondVC = secondViewController()` 이런식으로 초기화를 해서 사용하였다.

하지만 그렇게 하지않아도 된다.

다음과 같이 해주면된다

먼저 아까처럼 컨트롤러를 선택해준다. 위에서 1 이나 2의 방식으로.

그리고 IBOutlet, IBAction을 만들듯이 Control을 누른 상태로 드래그 해주자.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/JibNVS3Cd6.png){: width="50%" height="50%"}

그리고 present modally를 선택해 주었다. (개취)

![](https://i.esdrop.com/d/f/E8Nib9NqGY/PdiwNBtUAv.png){: width="50%" height="50%"}

아래처럼 저렇게 해도 상관없다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/Rq9iIC7i2T.png){: width="50%" height="50%"}

![](https://i.esdrop.com/d/f/E8Nib9NqGY/w02Zhpz4qK.gif)

그 결과

![](https://i.esdrop.com/d/f/E8Nib9NqGY/8yMe549snL.png){: width="50%" height="50%"}

세그웨이가 생성되었다.

insector tap을 통해 어떻게 애니메이션을 할지 설정 할 수 있다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/jfqIthdGfW.png){: width="50%" height="50%"}

세그웨이에도 네이밍을 해주자.

identifier에 이름을 정해주면된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/xaKf77DNSm.png){: width="50%" height="50%"}

![](https://i.esdrop.com/d/f/E8Nib9NqGY/D4XOEOI71D.gif)

## Segue를 사용하여 연결하기

우리는 CalulatorViewController에서 ResultViewController로 넘어가기에 

perfromSegue메서드를 사용할 것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/VX52HImh2o.png){: width="50%" height="50%"}


```swift
self.performSegue(withIdentifier: "goToResult", sender: self)
```

- withIdentifier : 세그웨이의 이름 
- sender : 일종의 전달자

세그를 사용하여 연결했으니 한번 작동 테스트를 해보자.

전환이 잘된다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/sCe7ivg5p4.gif){: width="50%" height="50%"}

하지만 아직 계산값은 넘어가지 않는다.

## BMI 값 전달하기

ResultViewController에서 전달값을 받을 변수 생성해주기

아래와 같이 생성했다.
String으로 한건 값을 소수점표현하기 위해서이다.

`var bmiValue : String?`

그리고 다시 Calculate로 돌아와서

prepare 메서드를 생성해준다.
- 세그를 실행하기전 재정의 해야하는 override method이다.

보통 해당내용이 우리가 새로운 뷰컨트롤러를 만들게 되면 viewdidload 밑에 주석으로 처리되어있는 그 내용이다.

segue.identifier 가 goToResult일때 세그가 작동하게 하였다.
왜냐 우리가 viewContoller를 여러개 만들 수 있으니까.

그리고 destination을 설정해주어야 하는데.

destination은 기본적으로 UIViewController 형식이다
말그대로 도착지를 이야기 하는것이다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/FwmKWYWDdP.png){: width="50%" height="50%"}


그리고 그 도착지의 viewcontroller에 있는 bmiValue를 연결해준다.

그런데 에러가 난다?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/MVQhOcRVAf.png){: width="50%" height="50%"}

UIViewController는 bmiValue가 없다고한다.

위의 적어놓은대로 UIViewController이지 우리가 원한 ResultViewController가 아니었던것이다.

그 상위 개념을 담아버렸다....

이럴땐 다운 캐스팅을 해주어 정확하게 지정해주자.

as를 사용한다.

as!를 사용하면서 강제로 다운캐스팅을 진행한다.

```swift
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToResult" {
            let destinationVC = segue.destination as! ResultViewController
            destinationVC.bmiValue = "0.0"
        }
    }
```

그렇다면 이제 calculated에있는 값을 result로 넘겨보자

---
난 이렇게 하였다.

일단 bmi를 새로 변수를 만들어 주었다.

weight, height를 서로 반대로 적어두고 계속 0.0 나와서 뭔가 싶었는데 저걸 잘못적어서 얼타버렸다...

```swift
//CalculateViewController
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let bmi = weightSlider.value / pow(heightSlider.value,2)
        print(bmi)
        if segue.identifier == "goToResult" {
            let destinationVC = segue.destination as! ResultViewController
            destinationVC.bmiValue = String(format: "%.1f", bmi)
        }
    }

//ResultViewController
override func viewDidLoad() {
        super.viewDidLoad()
                
        
        bmiLabel.text = bmiValue
    }
```

넘어온 값을 받아 보여주는 코드를 작성하였다.

---
강의에선 어떻게 했을까?

```swift
//CalculateViewController
var bmiValue = "0.0"

@IBAction func calculatePressed(_ sender: UIButton) {
        let height = heightSlider.value
        let weight = weightSlider.value
        let bmi = weight / (height * height)
        
        bmiValue = String(format: "%.1f", bmi)
        
        self.performSegue(withIdentifier: "goToResult", sender: self)
    }

override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToResult" {
            let destinationVC = segue.destination as! ResultViewController
            destinationVC.bmiValue = bmiValue
        }
    }

//ResultViewController
override func viewDidLoad() {
        super.viewDidLoad()
                
        
        bmiLabel.text = bmiValue
    }
```

이렇게 하였다.

---

실행화면

![](https://i.esdrop.com/d/f/E8Nib9NqGY/ftC3umxHZc.gif){: width="50%" height="50%"}

## Segue를 다시 전환시키기

dismiss 메서드를 통해 다시 이전 view로 돌아갈 수 있다.

위의 실행화면은 수동으로 내렸지만, 이제는 버튼으로 가능해졌다.

```swift
@IBAction func recalculatePressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
```

실행화면

![](https://i.esdrop.com/d/f/E8Nib9NqGY/3Sf88qwORs.gif){: width="50%" height="50%"}

UI를 3D로 볼 수도있다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/AI0AaTq80z.png){: width="50%" height="50%"}

3D구현화면은 생략하겠다. 드래그로도 돌려 볼수있으니 나중에 시간 되면 해보는걸 추천한다.