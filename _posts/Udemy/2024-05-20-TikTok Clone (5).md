---
title: TikTok Clone (5)
writer: Harold
date: 2024-05-20 09:13
categories: [Udemy, TikTok]
tags: []
last_modified: 2024-05-26 05:13
toc: true
toc_sticky: true
---

## TabBar controller 생성

VC는 3개를 추가로 더 이어주었다.

Home, Discover, Add, Inbox, Profile 총 5개이다.

우선 NavController의 Storyboard id를 mainvc, tabbar controller의 Storyboard id를 TabbarVC로 해준다.

![CleanShot 2024-05-20 at 09 51 44@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/915d082a-56f1-4847-bec3-548b06f708c0)

이렇게.

## 자동 로그인, 로그아웃 설정

SceneDelegat에서 다음과 같이 설정

```swift
func configureInitialViewController () {
        var initialVC = UIViewController()
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if Auth.auth().currentUser != nil {
            initialVC = storyboard.instantiateViewController(withIdentifier: IDENTIFIER_TABBAR)
        } else {
            initialVC = storyboard.instantiateViewController(withIdentifier: IDENTIFIER_MAIN)
        }
        window?.rootViewController = initialVC
        window?.makeKeyAndVisible()
    }


func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        configureInitialViewController() // added
        
        guard let _ = (scene as? UIWindowScene) else { return }
    }
```

이렇게 해준다.

`Auth.auth().currentUser`를 통해 현재 로그인 한 정보가 있다면 vc의 탭바를 띄우고 아니면 다른 페이지를 띄우라는것.

실행하니 탭바가 나온다, 즉 현재 로그인이 되어있다는 의미

ProfileVC에 로그아웃 기능을 설정해본다.

우선 UserApi에 로그아웃 함수를 하나 만들어준다.

간단하다

Auth를 통해 signout 메서드를 호출하면 끝

```swift
func logOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            ProgressHUD.error(error.localizedDescription)
            return
        }
        let scene = UIApplication.shared.connectedScenes.first
        if let sd: SceneDelegate = (scene?.delegate as? SceneDelegate) {
            sd.configureInitialViewController()
        }
    }
```

그리고 로그아웃 시 어떤 화면을 보여줄지도 정해준다.

이전에 Signin할때도 화면전환이 되게 하기 위해

```swift
@IBAction func signInDidTapped(_ sender: Any) {
        self.view.endEditing(true)
        self.validateFields()
        self.signIn { // added
            let scene = UIApplication.shared.connectedScenes.first
            if let sd: SceneDelegate = (scene?.delegate as? SceneDelegate) {
                sd.configureInitialViewController()
            }
        } onError: { errorMessage in
            ProgressHUD.failed(errorMessage)
        }
        
    }
```

화면전환에 대한내용을 추가해준다.

Signup도 마찬가지!

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        self.validateFields()
        self.signUp {
            let scene = UIApplication.shared.connectedScenes.first
            if let sd: SceneDelegate = (scene?.delegate as? SceneDelegate) {
                sd.configureInitialViewController()
            }
        } onError: { errorMessage in
            ProgressHUD.failed(errorMessage)
        }
        
    }
```

![May-26-2024 16-13-05](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d8f36ff9-c40d-4b5d-85f9-e503b0bce401)


로그아웃, 로그인 전부 잘된다.

로그인 할때 왜 화면이 안넘어가나 했는데

```swift
func signIn(onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        ProgressHUD.animate("Loading...")
        Api.User.signIn(email: self.emailTextfield.text!, password: self.passwordTextfield.text!) {
            ProgressHUD.dismiss()
            onSuccess() // missed!
        } onError: { errorMessage in
            onError(errorMessage)
        }
    }
```

저부분이 빠져있었다.