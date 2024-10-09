---
title: Tip-Calculator (1)
writer: Harold
date: 2024-04-30 15:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, Combine]
tags: []

toc: true
toc_sticky: true
---

이제는 Combine, RxSwift에 대한 이야기도 나와서 슬슬 준비를 해야겠다는 생각이 들어 글을 써본다.

## 시작

![CleanShot 2024-04-30 at 16 38 00@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3bb5beda-a320-49bf-9f4c-231ab8bf3371){: width="50%" height="50%"}

Test를 체크를 해준다.

> Test 체크를 하는 이유?
>> 소스 코드에서 특정 모듈, 클래스가 개발자가 의도한 대로 정확하게 작동하는지 테스트를 한다.

## 라이브러리 추가

SPM을 통해 설치를 해주자.

3개의 Target에 설치를 다 하는데,

1. project target (combinecocoa, snapkit)
2. test target (combinecocoa, snapkit test)
3. uitest target (combinecocoa)

처음에 라이브러리를 추가를 해주면 2,3 번째에서는 간단하게

![CleanShot 2024-04-30 at 16 47 35@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/408ef2e1-e2af-40c9-a608-959d57ea37ab)

이렇게 추가가 가능.

그리고 2번에서 추가할때 

![CleanShot 2024-04-30 at 16 49 44@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/acff677b-32d1-4cac-85aa-67904167642d)

주의! 테스트로 할것.

## Root VC 설정 (promatically)

스토리보드를 지워준다.

![CleanShot 2024-04-30 at 17 11 50@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/720b6da7-42fb-4eeb-9924-0098e8bf4ec0)

그리고 네모로 표시한부분도 삭제 해준다.

이대로 실행하면 Crash가 발생한다.

SceneDelegate에서 설정을 해줘야한다.

안쓰는 메서드에 대해 다 지워주고 (첫번째 빼고는 다 삭제)
```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        
        
        guard let _ = (scene as? UIWindowScene) else { return }
    }


}

```

이제 여기서 root VC를 설정해준다.

```swift
guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        let vc = ViewController()
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()
```

그래도 안된다면?

![CleanShot 2024-04-30 at 17 10 12@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/79f97991-0bbf-46d0-9595-aedca34aeff2)

이걸 확인해보자.

## 코드로 UI 디자인

> 전반적으로 큰틀에서 어떻게 이루어질지 각각의 View를 만들어서 배치를 해주고 그다음에 세부 디자인을 하는 매커니즘으로 간다.

```swift
private let logoView = LogoView()
private let resultView = ResultView()
private let billInputView = BillInputView()
private let tipInputView = TipInputView()
private let spiltInputView = SplitInputView()
    
private lazy var vStackView: UIStackView = {
    let stackView = UIStackView(arrangedSubviews: [
        logoView,
        resultView,
        billInputView,
        tipInputView,
        spiltInputView
        ])
        stackView.axis = .vertical
        stackView.spacing = 36
        return stackView
}()
```

여러 View를 만들어주고 그걸 전체로 감싸는 StackView도 만들어준다. 중심축을 수직으로 해주고, 간격을 36으로 해주었다.

그리고 snapkit을 사용하여 autolayout 설정을 해주었다.

```swift
 private func layout() {
     
        
        vStackView.snp.makeConstraints { make in
            make.leading.equalTo(view.snp.leadingMargin).offset(16)
            make.trailing.equalTo(view.snp.trailingMargin).offset(-16)
            make.bottom.equalTo(view.snp.bottomMargin).offset(-16)
            make.top.equalTo(view.snp.margins).offset(16)
            
        }
    }
```

하지만 실행하면 에러가 발생한다.

`view.addSubview(vStackView)`이게 빠졌기 때문.


## Build Settings 재 수정

![simulator_screenshot_D639E5E1-56D6-4625-959F-1C3FA12FBB21](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8bcac74c-6957-452b-ae17-9f66a0d83989){: width="50%" height="50%"}

현재 SafeArea쪽도 그렇고 위와 아래쪽이 예전 폰으로 보이는듯한 느낌이 들어서 우리가 보는것 처럼 확대를 해보려 한다.

![CleanShot 2024-04-30 at 20 23 58@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8b454419-728c-4bcd-ac67-3afc0186b1bf)

이부분을 아까 잘못지워서 생긴 문제였다.

해결.

## 색상 설정

Config 디렉토리를 만들어 주었다.

`UIColor(hexString:)` 메서드를 사용하기위해 extension으로 기능을 구현해준다. [StackOverFlow참고](https://stackoverflow.com/questions/24263007/how-to-use-hex-color-values/33397427#33397427)

```swift
extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
```

오늘은 여기까지