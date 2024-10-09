---
title: TikTok Clone (1)
writer: Harold
date: 2024-05-18 14:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

틱톡 클론 앱 과정을 정리해본다.

아마 모르는 개념 위주로만 정리할듯.

UIDesgin


![simulator_screenshot_2BBB5E1E-D293-4244-84AA-DB8320854B62](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c1e780e3-0e45-4cc7-b912-dc18b0e3a663){: width="50%" height="50%"} 
![simulator_screenshot_079E0A6B-E3AD-4CDC-8D02-84A771CDAF12](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/73d81b69-2fa8-4ffc-bc23-39858a63a3e0){: width="50%" height="50%"} 
![simulator_screenshot_63ECCB97-72C8-4933-A1C4-49AA46F52567](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8b362d24-6df5-47c7-b9be-cecf6afc5889){: width="50%" height="50%"}


사진으로 대체한다.


## AppDelegate 설정

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UINavigationBar.appearance().tintColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 1)
        let backImg = UIImage(systemName: "chevron.backward")
        UINavigationBar.appearance().backIndicatorImage = backImg
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImg
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(.init(horizontal: -1000, vertical: 0), for: .default)
        
        return true
    }
```

이렇게 해서 backButton을 설정 해준다.


![May-19-2024 20-39-42](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2b622b41-5a43-4666-8775-a43af1e45431){: width="50%" height="50%"} 

## Sign In VC 설정

### 1. NavigationTitle 설정
```swift
func setupNavigationBar() {
        navigationItem.title = "Create new account"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
```
이렇게 해주면 위에 타이틀이 생긴다.

### 2. TextField, ContainerView 설정

```swift
func setupUsernameTextfield() {
        usernameContainerView.layer.borderWidth = 1
        usernameContainerView.layer.borderColor = CGColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 0.8)
        usernameContainerView.layer.cornerRadius = 20
        usernameContainerView.clipsToBounds = true
        usernameTextfield.borderStyle = .none
    }
```

현재 디자인이 TextField가 UIview안에 들어있는데, 그 uiview를 ContainerView라고 이름을 지었고, 그것을 설정해준다.

Sign up도 동일

## Firebase 설정.

Auth, Database, Storage(swift도 혹시몰라 설치) 이렇게 설치를 해주었다.

Sign Up VC에서

`import FirebaseAuth`를 해주고

sign up 버튼을 클릭하여 회원가입을 하기 위해

버튼에 다음과 같이 작성해본다.

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        Auth.auth().createUser(withEmail: "test1@gmail.com", password: "123456") { authDataResut, error in
            if error != nil {
                print(error?.localizedDescription)
                return
            }
            if let authData = authDataResut {
                print(authData.user.email)
            }
        }
    }
```

![CleanShot 2024-05-19 at 21 58 39@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/17f20960-6fc2-4577-beb5-db6a3bd95461)

현재는 Firebase 에서 로그인 방식을 email / password로 해둔상태이다.

버튼을 눌러보면

```
Optional("test1@gmail.com")
```

이 출력되고,

![CleanShot 2024-05-19 at 22 00 13@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3dcbea40-25f9-43cf-88b8-421da00641b9)

이렇게 Firebase, Auth에도 등록이 된걸 알 수 있다.

## Realtime Database 설정.

이전과 동일하게 테스트모드로 만들어 주면 된다.

유저정보를 데이터 베이스에 저장하는 코드를 작성한다.

```swift
if let authData = authDataResut {
                print(authData.user.email)
                let dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "profileImageUrl": "",
                    "status": ""
                ]
                
                Database.database().reference().child("users").child(authData.user.uid).updateChildValues(dict) { error, ref in
                    if error != nil {
                        print("Done")
                    }
                }
            }
```

dict라는 dictionary를 만드는데 uid, email, profileImageUrl, status의 정보를 가지는 배열이다.

그리고 `Database.database().reference().child("users").child(authData.user.uid).updateChildValues(dict)` 이건

users라는 table에서, 또 거기서 유저의 uid table을 만들고 거기에 유져의 데이터가 담기는 방식이다.

![CleanShot 2024-05-19 at 22 09 50@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/477b5c2b-9fbf-4919-9cde-89b74a10ef94)

그러면 이렇게 정보가 담기게 된다.

