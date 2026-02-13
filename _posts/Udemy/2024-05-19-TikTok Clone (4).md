---
title: TikTok Clone (4)
writer: Harold
date: 2024-05-19 19:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## Storage Service 구현

사진을 저장하는것도 코드를 다시 세분화하여 나눠본다.

```swift
class StorageService {
    static func savePhoto (username: String, uid: String, data: Data, metaData: StorageMetadata, storageProfileRef: StorageReference ,dict: Dictionary<String, Any>, onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        
        storageProfileRef.putData(data, metadata: metaData) { storageMetaData, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            
            storageProfileRef.downloadURL { url, error in
                if let metaImageUrl = url?.absoluteString {
                    print(metaImageUrl)
                    
                    if let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
                        changeRequest.photoURL = url
                        changeRequest.displayName = username
                        changeRequest.commitChanges { error in
                            if let error = error {
                                ProgressHUD.failed(error.localizedDescription)
                            }
                        }
                    }
                    var dictTemp = dict
                    dictTemp["profileImageUrl"] = metaImageUrl
                    Database.database().reference().child("users").child(uid).updateChildValues(dict) { error, ref in
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
```

Storage와 관련된 부분을 다시 클래스를 만들어 세분화를 한것인데,

여기서 변경점이라면

```swift
if let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() {
                        changeRequest.photoURL = url
                        changeRequest.displayName = username
                        changeRequest.commitChanges { error in
                            if let error = error {
                                ProgressHUD.failed(error.localizedDescription)
                            }
                        }
}
```

바로 이부분이 추가가 되었다는 것.

[Docs](https://firebase.google.com/docs/auth/ios/manage-users?hl=ko#swift)에 의하면,

사용자 프로필을 업데이트 할때 사용을 한다고 한다.

즉 사용자의 이름, 프로필 사진등을 업데이트할때 사용을 한다는것.

그리고 userapi의 signup에서도

```swift
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
                // modified
                StorageService.savePhoto(username: username, uid: authData.user.uid, data: imageData, metaData: metaData, storageProfileRef: storageProfileRef, dict: dict) {
                    onSuccess()
                } onError: { errorMessage in
                    onError(errorMessage)
                }

                
            }
        }
    }
}

```

이렇게 심플하게 된다.

## Ref 세분화.

Firebase정보를 담고있는 plist file에 다음과 같이 추가해준다.

![CleanShot 2024-05-20 at 00 11 28@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/98545eed-0512-4f8d-be3e-d0e5cebaab05)

```swift
let REF_USER = "users"
let STORAGE_PROFILE = "profile"
let URL_STORAGE_ROOT = "gs://~~~~.appspot.com"
let EMAIL = "email"
let UID = "uid"
let USERNAME = "username"
let PROFILE_IMAGE_URL = "profileImageUrl"
let STATUS = "status"

class Ref {
    let databaseRoot = Database.database().reference()
    
    var databaseUsers: DatabaseReference {
        return databaseRoot.child(REF_USER)
    }
    
    // storage Ref
    let storageRoot = Storage.storage().reference(forURL: URL_STORAGE_ROOT)
    
    var storageProfile: StorageReference {
        return storageRoot.child(STORAGE_PROFILE)
    }
}
```

다음과 같이 적는다, 주소는 storage 그 주소를 가져오면된다.

이렇게 한것은 UserAPI에 있는 Stringvalue를 변수로 바꾸겠다는 것이다.

```swift
// before
var dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "username": username,
                    "profileImageUrl": "",
                    "status": ""
                ]

// after
var dict: Dictionary<String, Any> = [
                    UID: authData.user.uid,
                    EMAIL: authData.user.email,
                    USERNAME: username,
                    PROFILE_IMAGE_URL: "",
                    STATUS: ""
                ]
```
이렇게 바꾸겠다는것.

다시 ref로 가서

```swift
func databaseSpecificUser(uid: String) -> DatabaseReference {
        return databaseUsers.child(uid)
    }

func storageSpecificProfile(uid: String) -> StorageReference {
        return storageProfile.child(uid)
    }
```

두개의 함수를 만들어 준다.

다시 UserApi로 가서

```swift
// before
let storageRef = Storage.storage().reference(forURL: "gs://tiktoktutorial-d9129.appspot.com")
let storageProfileRef = storageRef.child("profile").child(authData.user.uid)

// after                
let storageProfileRef = Ref().storageSpecificProfile(uid: authData.user.uid)
```

두줄이었던걸 한줄로 바꿔주었다.

그리고 StorageService로 가서

```swift
// before
Database.database().reference().child("users").child(uid).updateChildValues(dict) { error, ref in
                        if error == nil {
                            onSuccess()
                        } else {
                            onError(error!.localizedDescription)
                        }
                    }

// after
Ref().databaseSpecificUser(uid: uid).updateChildValues(dict) { error, ref in
                        if error == nil {
                            onSuccess()
                        } else {
                            onError(error!.localizedDescription)
                        }
                    }
```

변경.

VC로 가서

signup함수에 escaping closure와 hud를 사용해준다.

```swift
func signUp(onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        ProgressHUD.animate()
        Api.User.signUp(withUsername: self.usernameTextfield.text!, email: self.emailTextfield.text!, password: self.passwordTextfield.text!, image: self.image) {
            ProgressHUD.dismiss()
            onSuccess()
        } onError: { errorMessage in
            onError(errorMessage)
        }

    }

@IBAction func signUpDidTapped(_ sender: Any) {
        self.validateFields()
        self.signUp {
            // switch view
        } onError: { errorMessage in
            ProgressHUD.failed(errorMessage)
        }

    }
```

실행하면 등록되는 동안 로딩 애니메이션이 작동

![May-20-2024 00-28-19](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/533cbe9d-134d-4ce9-a3d4-46cd622eadc5){: width="50%" height="50%"} 

잘된다. 저 애니메이션이 끝난다는건 firebase와의 통신이 완료되어 유저 졍보 등록이 되었다는걸 의미.

## Sign In 구현

VC에

```swift
func signIn(onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        ProgressHUD.animate()
        Api.User.signUp(withUsername: self.usernameTextfield.text!, email: self.emailTextfield.text!, password: self.passwordTextfield.text!, image: self.image) {
            ProgressHUD.dismiss()
            onSuccess()
        } onError: { errorMessage in
            onError(errorMessage)
        }

    }
```

signUp함수를 그대로 가져와서 이름만 바꿔주었다.

해당 함수를 이용할 예정.

UserApi로 가서 다음과 같이 틀을 잡고, 확인을위해 프린트만 적어준다.

```swift
func signIn(email: String, password: String, onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authData, error in
            if error != nil {
                onError(error!.localizedDescription)
                return
            }
            print(authData?.user.uid)
            onSuccess()
        }
        
    }
    
```

VC에도 다음과 같이 해준다.

```swift
func signIn(onSuccess: @escaping() -> Void, onError: @escaping (_ errorMessage: String) -> Void) {
        ProgressHUD.animate()
        Api.User.signIn(email: self.emailTextfield.text!, password: self.passwordTextfield.text!) {
            ProgressHUD.dismiss()
        } onError: { errorMessage in
            onError(errorMessage)
        }
    }
```

signUpVC에 있던 `validateFields` 이 함수도 가져와서 username부분만 지워주면된다.

그리고 ibaction을 다듬어준다.

```swift
@IBAction func signInDidTapped(_ sender: Any) {
        self.view.endEditing(true) // added
        self.validateFields() // added
        self.signIn {
            // switch view
        } onError: { errorMessage in
            ProgressHUD.failed(errorMessage)
        }
        
    }
```

텍스트필드를 터치하면 올라오는 키보드를 Signin버튼을 누르면 키보드를 사라지게 하고, 바로 각 텍스트필드의 유효성을 검사 후 로그인 시도를 하게 된다.

버튼을 눌러보니 콘솔에 uid가 출력이 되는걸 알 수 있다.

