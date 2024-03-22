---
title: BMI Calculator (2)
writer: Harold
date: 2024-03-01 08:19:00 +0800
categories: [Udemy, BMI Calculator]
tags: []

toc: true
toc_sticky: true
---
어제 포스팅을 해야했으나 velog에서 git blog로 전환 및 내용을 전부 이관하면서 공부를 거의 하지못했다 ㅠ

근데 깃블로그 맘에든다. 넘어가길 잘한듯?

각설하고 이어서 계속 작성해보도록 하자.

## 새로운 ViewController 생성하기.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/cw7nhq5Uym.png){: width="50%" height="50%"}

우선 현재 위와 같이 2개의 viewController가 있지만,

![](https://i.esdrop.com/d/f/E8Nib9NqGY/ZVFWVTusuD.png){: width="50%" height="50%"}

우리는 현재 viewController가 하나이므로 추가로 하나 더 생성해주자.

이름은 SecondViewController로 해주었다.

만들어진 viewcontroller에 class를 만들어주자!

class 입력하고 나오는 recommendation중 subclass를 누르면 다음과 같이 나온다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/EFIuiwYVxs.png){: width="80%" height="80%"}

**Swift에서는 클래스를 만들때 클래스 그자체와 같은 이름을 가진 파일의 이름을 정하는 것이 규칙이다**

즉, 위에 name부를 SecondViewController로 해주자.
그리고 super class는 우리가 일반적으로 viewcontroller를 보게되면 

`class ViewController:UIViewController{ }`
위와 같이 되어있다.

그러므로 우리가 만든 클래스 역시 super class는 UIViewContoller로 해주면 되겠다!

그랬더니 다음과 같이 에러가 발생한다!
![](https://i.esdrop.com/d/f/E8Nib9NqGY/VoVdWZSttz.png) 

그렇다 UIViewController class를 사용하기 위해선

위의 권고처럼 import UIKit를 해줘야한다.

**UI로 시작하는것들은 대부분 UIKit에서 오기때문에 UIKit가 있는지 확인후, 없으면 import를 해주도록 하자**

처음에 생성된 Foundation은 어차피 UIkit에 포함이 되어있으므로 Foundation → UIKit으로 변경하자.

그리고 기본적으로 Project를 만들게 되면, ViewController에 viewDidLoad 메서드가 있는데 우리가 새롭게 만들게 되면 없다.

그래서 viewDidLoad도 작성을 해주자.

swift는 help에 가면 documentaion을 볼 수있으므로, 참고해두자
![](https://i.esdrop.com/d/f/E8Nib9NqGY/tM4HOdNH8T.png){: width="50%" height="50%"}

## 새로 생성한 ViewController 빌드하기.

기존에는 우리가 Storyboard에서 ViewController로 드래그를 하면서 UILabel을 만들고 했는데 이번에는 그러지 않고, 온전히 ViewController내부에서 작업하여 만들어 보도록 하겠다.

먼저 label을 생성해준다.
label = UILabel() 이렇게 함으로써 label을 초기화 해줄 수 있다.

```swift
class SecondViewController: UIViewController {
    
    override func viewDidLoad() {
        
        let label = UILabel()
        label.text = "Hello"
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        // (x,y)좌표에 가로 세로가 100, 50 인 프레임 생성
        view.addSubview(label) // 우리가 알고 있는 controller를 만들었을때의 전체를 덮고 있는 view가 addsubview앞에 있는 그 view이다.
    }
    
}
```
그리고 label의 frame을 위와같이 코드를 작성하여 만들어준다.
Rect는 흔히 우리가 아는 Rectangular의 Abbreviation이라고 생각하면 좋을것 같다. 이렇게 우리가 코드로 프레임도 만들어 줄 수있다. 

addSubview의 괄호 안에는 UIView의 DataType을 가지고있는 변수가 들어와야하는데, label들어와도 문제가 없다?
![](https://i.esdrop.com/d/f/E8Nib9NqGY/3dBIIDcaOM.png)

왜냐하면 아래와 같이 UILabel은 UIView의 상속을 받기 때문에 문제가 없는것이다! 호환이 된다!
![](https://i.esdrop.com/d/f/E8Nib9NqGY/AyZfjxCWxX.png)

우리가 새로운 컨트롤러에 새로운 뷰를 생성하게 되면 그 뷰는 투명하게 되어있다.
- 즉 우리가 배경색을 설정해주어야 한다!

```swift
view.backgroundColor = UIColor.red
view.backgroundColor = .red
```

두개의 코드는 서로 같다. 
.을써도 문제가 없다? 이게 무슨 말일까?
swift는 이미 우리가 배경색을 바꾸려고할때 UIColor가 나올것을 알고있기에 . 으로 그냥 넘어가도 상관이 없다.

이것도 잘 알아두도록하자. (그렇다고 막써보지는 말자...)

첫번째 viewcontroller의 calculate 버튼을 눌렀을때 새로 만든 viewcontroller로 전환이 되도록 설정을 해보자.

## viewcontroller 서로 연결 해보기.

secondVC라는 것을 만들어주고 초기화를 해준다.
```swift
let secondVC = SecondViewController() // Initialize
```

secondVC라는 매개변수가 생겼고, 이를 통해 우리는 이제 secondViewController 를 보여줄수 있게 되었다.

하지만 다른 viewcontroller를 보여주려면 현재의 viewcontroller가 필요하다.

![](https://i.esdrop.com/d/f/E8Nib9NqGY/SfzOXjHutn.png)

이렇게 현재 뷰컨트롤러 그 자신이 필요하기에 self 메서드를 통해서 코드를 작성하면 된다.
![](https://i.esdrop.com/d/f/E8Nib9NqGY/pa72P9lI7E.png)

- parameter
1. parameter에는 우리가 보여줄 viewcontroller
2. animated 컨트롤러 전환시 효과를 주는가?
3. 애니메이션과 프레젠테이션이 끝나면 무엇을 할건지?
    - 여기선 우리는 할게 없으므로 nil을 해준다.

그래서 아래와 같이 첫번째 view controller에서 작성을 해준다

```swift
@IBAction func calculatePressed(_ sender: UIButton) {
        let height = heightSlider.value
        let weight = weightSlider.value
        //let bmi = weight / (height * height)
        let bmi = weight / pow(height,2)

        print(bmi)
        
        // 새롭게 추가 버튼을 눌렀을때 다음 뷰 컨트롤러로 전환 하기 위해 작성.
        let secondVC = SecondViewController()
        self.present(secondVC, animated: true, completion: nil)
    }
```

그럼 이제 제대로 돌아가는지 작동 테스트를 해보도록하자.
![](https://i.esdrop.com/d/f/E8Nib9NqGY/l4F6zQgPDp.gif){: width="50%" height="50%"}

아주 잘된다.

그렇다면 animated를 false를 하면 어떻게 될까?

![](https://i.esdrop.com/d/f/E8Nib9NqGY/0YSJvKV9G5.gif){: width="50%" height="50%"}

이렇게 효과 없이 그냥 떡하니 바뀌는 걸 알 수 있다.

## BMI 결과 값을 다른 ViewController에 전달하기
화면 전환까지 되는것을 확인했다.

이제는 우리가 첫번째 뷰컨트롤러에서 키와 무게를 설정하고 calculate를 눌렀을때 현재는 console에 출력이 되었지만, 이제는 이 결과값을 다른 ViewController에 넘겨보도록 하자.

우선 bmi값을 담을 변수를 하나 생성해주자.
그리고 해당변수를 label.text가 받게 해주자

```swift
var bmiValue = "0.0" // 변수생성
    
    override func viewDidLoad() {
        
        // view.backgroundColor = UIColor.red
        view.backgroundColor = .red
        
        let label = UILabel()
        label.text = bmiValue // 변수를 표시하게!
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        // (x,y)좌표에 가로 세로가 100, 50 인 프레임 생성
        view.addSubview(label) // 우리가 알고 있는 controller를 만들었을때의 전체를 덮고 있는 view가 addsubview앞에 있는 그 view이다.
    }
```

다시 첫번째 Viewcontroller로 넘어가서
우리는 이제 아까 만들어둔 `secondVC`를 통해 두번째 컨트롤러에 있는 매개변수에도 접근이 가능해졌다.

그래서 두번째 컨트롤러에 있는 `bmiValue`에 첫번째 컨트롤러에서 나오는 결과값을 전달 해주도록 하자.

```swift
let bmi = weight / pow(height,2)// 우리가 bmi값의 데이터형을 Float형태로 해두었기에 String으로 형변환을 해주었다.
// 그리고 소수점 첫번재자리까지 표시하기위해서 format을 설정해주었다.
secondVC.bmiValue = String(format: "%.1f", bmi)
```

![](https://i.esdrop.com/d/f/E8Nib9NqGY/bCwg92QkiQ.gif){: width="50%" height="50%"}

전달이 잘 되는것을 확인 할 수 있다.