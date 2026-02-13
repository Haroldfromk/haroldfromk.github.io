---
title: TikTok Clone (3)
writer: Harold
date: 2024-05-19 18:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## Textfield 유효 함수 구현

여러 Textfield 값이 입력이 될때 해당 컴포넌트에 제대로 값이 있는지 확인하는 함수를 구현한다.

```swift
func validateFields() {
        guard let username = self.usernameTextfield.text, !username.isEmpty else {
            print("Please enter an username")
            return
        }
        guard let email = self.emailTextfield.text, !email.isEmpty else {
            print("Please enter an username")
            return
        }
        guard let password = self.passwordTextfield.text, !password.isEmpty else {
            print("Please enter an username")
            return
        }
    }
```

우선은 틀만 이렇게 잡는다.

그리고 버튼을 클릭했을때 작동이 먼저되게

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        self.validateFields()
```

여기에 바로 구현.

버튼을 클릭하니

```
Please enter an username
Avatar is nil
```

이렇게 나온다.

## Progress HUD 사용.

[주소](https://github.com/relatedcode/ProgressHUD.git)는 여기에

SPM으로 추가한다.

이전에는 `showError` 메서드가 있었으나 지금은 없다. 그래서 `failed`로 대체

```swift
func validateFields() {
        guard let username = self.usernameTextfield.text, !username.isEmpty else {
            ProgressHUD.failed("Please enter an username")
            return
        }
        guard let email = self.emailTextfield.text, !email.isEmpty else {
            ProgressHUD.failed("Please enter a email")
            return
        }
        guard let password = self.passwordTextfield.text, !password.isEmpty else {
            ProgressHUD.failed("Please enter a password")
            return
        }
    }
```

![May-19-2024 23-15-08](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e18f43b6-f4b9-48e0-b70d-1e83b7089deb){: width="50%" height="50%"} 

실행하니 아주 괜찮다.

이미지에도 적용을 해주자.

```swift
guard let imageSelected = self.image else {
            ProgressHUD.failed("Please enter a Profile Image")
            return
        }
```

## textfield값 적용

이전까지는 이메일주소, 비밀번호를 미리 파라미터에 입력했다면 이젠 textfield의 값을 받도록 변경한다.

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        self.validateFields()
        
        
        guard let imageSelected = self.image else {
            ProgressHUD.failed("Please enter a Profile Image") // modified
            return
        }
        guard let imageData = imageSelected.jpegData(compressionQuality: 0.4) else {return}
        
        Auth.auth().createUser(withEmail: self.emailTextfield.text!, password: self.passwordTextfield.text!) { authDataResut, error in // modified
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if let authData = authDataResut {
                print(authData.user.email)
                var dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "username": self.usernameTextfield.text!, // added
                    "profileImageUrl": "",
                    "status": ""
                ]
```

DB를 리셋시키고 테스트를 해보자.

그전에 비밀번호를 보이지 않게 하기위해

![CleanShot 2024-05-19 at 23 21 06@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3c621d41-56f1-4638-bd71-2b731d09f5f2)

여기 부분을 체크해주자.

![May-19-2024 23-23-31](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/270adc78-87f4-4180-be87-c248922bbf19){: width="50%" height="50%"} 

아직 이후 액션이 없어서 저기서 멍때리지만

DB에는 값이 잘 들어온걸로 확인이 된다.

사진은 pass

그리고 extension을 통해 signUp이라는 함수로 코드를 옮겨준다.

```swift
extension SignUpViewController {
    
    func signUp() {
        guard let imageSelected = self.image else {
            ProgressHUD.failed("Please enter a Profile Image")
            return
        }
        guard let imageData = imageSelected.jpegData(compressionQuality: 0.4) else {return}
        
        Auth.auth().createUser(withEmail: self.emailTextfield.text!, password: self.passwordTextfield.text!) { authDataResut, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if let authData = authDataResut {
                print(authData.user.email)
                var dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "username": self.usernameTextfield.text!,
                    "profileImageUrl": "",
                    "status": ""
                ]
                let storageRef = Storage.storage().reference(forURL: "gs://tiktoktutorial-d9129.appspot.com")
                let storageProfileRef = storageRef.child("profile").child(authData.user.uid)
                let metaData = StorageMetadata()
                metaData.contentType = "image/jpg"
                storageProfileRef.putData(imageData, metadata: metaData) { storageMetaData, error in
                    if error != nil {
                        print(error!.localizedDescription)
                        return
                    }
                    storageProfileRef.downloadURL { url, error in
                        if let metaImageUrl = url?.absoluteString {
                            print(metaImageUrl)
                            dict["profileImageUrl"] = metaImageUrl
                            Database.database().reference().child("users").child(authData.user.uid).updateChildValues(dict) { error, ref in
                                if error != nil {
                                    print("Done")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
}
```

그리고 원래 objc 함수에는

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        self.validateFields()
        self.signUp()
    }
```

이렇게 단순하게 해준다.

## Api 구현

정확하게는 위에 정리한 함수를 클래스처럼해서 모듈화 해주는것이다.

```swift
struct Api {
    static var User = UserApi()
}
```

이렇게 만들고

UserApi 부분에

```swift
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import ProgressHUD

class UserApi {
    func signUp (withUsername username: String, email: String, password: String, image: UIImage?, onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        guard let imageSelected = image else {
            ProgressHUD.failed("Please enter a Profile Image")
            return
        }
        guard let imageData = imageSelected.jpegData(compressionQuality: 0.4) else {return}
        
        Auth.auth().createUser(withEmail: email, password: password) { authDataResult, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if let authData = authDataResult {
                print(authData.user.email)
                var dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "username": username,
                    "profileImageUrl": "",
                    "status": ""
                ]
                let storageRef = Storage.storage().reference(forURL: "gs://tiktoktutorial-d9129.appspot.com")
                let storageProfileRef = storageRef.child("profile").child(authData.user.uid)
                let metaData = StorageMetadata()
                metaData.contentType = "image/jpg"
                storageProfileRef.putData(imageData, metadata: metaData) { storageMetaData, error in
                    if error != nil {
                        print(error!.localizedDescription)
                        return
                    }
                    storageProfileRef.downloadURL { url, error in
                        if let metaImageUrl = url?.absoluteString {
                            print(metaImageUrl)
                            dict["profileImageUrl"] = metaImageUrl
                            Database.database().reference().child("users").child(authData.user.uid).updateChildValues(dict) { error, ref in
                                if error == nil {
                                    onSuccess()
                                } else {
                                    onError(error!.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

이 내용을 모두 옮겼다.

특이점이라면 CompletionHandler를 사용하였고, success와 failure를 나눠서 구현했다.

VC로 돌아와서는

```swift
func signUp() {
        Api.User.signUp(withUsername: self.usernameTextfield.text!, email: self.emailTextfield.text!, password: self.passwordTextfield.text!, image: self.image) {
            print("Done")
        } onError: { errorMessage in
            print(errorMessage)
        }

    }
```

이렇게 심플하게 처리해주면 끝.

실행해서 확인

작동이 된다.
