---
title: TikTok Clone (2)
writer: Harold
date: 2024-05-18 18:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## 이미지 업로드

프로필 이미지 클릭시 ImagePicker 나오게 구현

우선 

```swift
func setupView() {
        avatar.layer.cornerRadius = 60
        avatar.clipsToBounds = true
        avatar.isUserInteractionEnabled = true
        signUpButton.layer.cornerRadius = 18
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(presentPicker))
        avatar.addGestureRecognizer(tapGesture)
    }
```

여기서 `avatar.isUserInteractionEnabled = true` 이걸 통해 유져의 이벤트를 무시하고 이벤트 큐에서 제거할지 여부를 결정한다.

true를 하면 원래대로 View에 이벤트가 전달된다.

false를 하면 touch, press, keyboard 그리고 focus의 이벤트가 무시되고 이벤트 큐에서 제거됨.

지금은 true를 함으로써 tapgesture를 사용하여 touch의 이벤트를 작동시키기 위함이다.

ImagePicker는 WWDC20에서 공개한 PHPicker를 사용한다.

[WWDC20](https://developer.apple.com/videos/play/wwdc2020/10652) 링크 참고.

extension을 사용하여 구현해주었다.

```swift
extension SignUpViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        for item in results {
            item.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                if let imageSelected = image as? UIImage {
                    print(imageSelected)
                }
            }
        }
    }
    
    
    
    @objc func presentPicker() {
        var configuration: PHPickerConfiguration = PHPickerConfiguration()
        configuration.filter = PHPickerFilter.images
        configuration.selectionLimit = 1
        
        let picker: PHPickerViewController = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }
}
```

출력이 되는걸 알 수 있다.

```
<UIImage:0x600003006010 anonymous {217, 232} renderingMode=automatic(original)>
```

이제 이미지를 ui에 띄워야하니 DispatchQueue를 사용한다.

```swift
extension SignUpViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        for item in results {
            item.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                if let imageSelected = image as? UIImage {
                    DispatchQueue.main.async { // added
                        self.avatar.image = imageSelected
                    }
                }
            }
        }
        dismiss(animated: true) // added
    }
    
    
    
    @objc func presentPicker() {
        var configuration: PHPickerConfiguration = PHPickerConfiguration()
        configuration.filter = PHPickerFilter.images
        configuration.selectionLimit = 1
        
        let picker: PHPickerViewController = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }
}

```

그리고 dismiss를 하는 이유는 이것도 하나의 VC의 개념이라 dismiss를 통해 해당 vc를 사라지게 해준다.

![May-19-2024 22-27-14](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/ee044dee-c5cb-42d2-ae9e-1e9d0ab69116){: width="50%" height="50%"} 

이렇게 이미지가 뜨는걸 확인할 수 있다.

## 이미지 저장

`var image: UIImage? = nil` 이렇게 초기값을 잡아주고.

```swift
func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        for item in results {
            item.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                if let imageSelected = image as? UIImage {
                    DispatchQueue.main.async {
                        self.avatar.image = imageSelected
                        self.image = imageSelected // added
                    }
                }
            }
        }
        dismiss(animated: true)
    }
```

저기에 저장을 해준다.

이제 저 이미지를 사용해서 Database에 등록할 것이다.

Firebase Storage를 빌드해주고, 이것도 역시 테스트로 한다.

그리고 Storage 주소를 복하해준다.

![CleanShot 2024-05-19 at 22 33 27@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/5238b871-e5a6-45e8-a47f-8d39f3318df1)

바로 이녀석.

그리고 다음과 같이 적는다

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        
        // added
        guard let imageSelected = self.image else {
            print("Avatar is nil")
            return
        }
        guard let imageData = imageSelected.jpegData(compressionQuality: 0.4) else {return}
        
        Auth.auth().createUser(withEmail: "test2@gmail.com", password: "123456") { authDataResut, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if let authData = authDataResut {
                print(authData.user.email)
                let dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
                    "profileImageUrl": "",
                    "status": ""
                ]

                // added
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
                        }
                    }
                }
                
                Database.database().reference().child("users").child(authData.user.uid).updateChildValues(dict) { error, ref in
                    if error != nil {
                        print("Done")
                    }
                }
            }
        }
    }
```

저기가 바로 추가된 부분인데,

우리가 선택한 이미지를 가져와서 이미지 데이터라는 변수에 담는데 jpeg로 담고 0~1사이의 퀄리티로 해서 전환을 하는데 높을수록 퀄리티가 좋다.

그리고, 레퍼런스라는 변수를 만들어서 복사한 주소값을 넣음으로써 저 주소로 된 스토리지를 사용하겠다는 것이다.

`storageProfileRef`이건 이전의 글에서 한것처럼 db가 어떤 구조로 저장이 될건지에 대해 계층구조를 나타내는 것,

metadata를 가져와서, 우리가 사용할 이미지 형식이 어떤것인지를 정해준다. 위에서 적은것처럼 jpg를 사용하겠다라는 것이다.

completionHandler를 통해 이미지를 스토리지에 저장하고 그 url주소를 출력하게 했다.

콘솔로 이미지 주소가 출력이 되고, 또한 사이트에서도 확인이 된다.

![CleanShot 2024-05-19 at 22 44 06@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3ea6adcb-f4e6-4a32-a276-25d8101b7ed8)

이제 이미지를 저장하고 그걸 유저 정보를 가진 database에도 올리기 위해

```swift
@IBAction func signUpDidTapped(_ sender: Any) {
        
        guard let imageSelected = self.image else {
            print("Avatar is nil")
            return
        }
        guard let imageData = imageSelected.jpegData(compressionQuality: 0.4) else {return}
        
        Auth.auth().createUser(withEmail: "test3@gmail.com", password: "123456") { authDataResut, error in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if let authData = authDataResut {
                print(authData.user.email)
                var dict: Dictionary<String, Any> = [
                    "uid": authData.user.uid,
                    "email": authData.user.email,
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
                            dict["profileImageUrl"] = metaImageUrl // moved
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
```

주석친 부분이 원래는 아래에 있었지만 위로 올려준다.

다시 이메일 주소를 바꿔서 등록을 해보면?

![CleanShot 2024-05-19 at 22 48 03@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/2fa0deda-e181-488c-8933-61155a3a3475)

이렇게 database 에도 확인이 되고,

![CleanShot 2024-05-19 at 22 49 12@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3d9e66de-22e5-4cd3-b1bb-2ac850df0f63)

auth도 확인 완료,

마지막으로

![CleanShot 2024-05-19 at 22 49 51@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1ec09546-93a1-4f42-be0d-ed7ad91b94f8)

Storage에서도 확인이 된다.