---
title: WhatFlower (2)
writer: Harold
date: 2024-04-18 01:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, CoreML]
tags: []

toc: true
toc_sticky: true
---

## 기본 코드 구성.

```swift
class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        
    }

    @IBAction func cameraTapped(_ sender: UIBarButtonItem) {
        present(imagePicker, animated: true)
        
        imagePicker.dismiss(animated: true)
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
        let userPickedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        
        imageView.image = userPickedImage
    }
}

```

SeeFood와 동일한 구조로 기본 코드를 구성한다.

차이점이라면 allowsEditing이 true로 되었고, 그에따라 userPickedImage 역시 editedImage가 되었다는 것.

## info.plist file 수정

카메라 접근 권한 허용을 유져에게 물어봐야 하기에 해당부분을 구현한다.

![CleanShot 2024-04-18 at 10 03 10@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/de8afae8-2bb8-4767-8282-d6155bdc37c0)


## CoreML, Vision 사용하여 기능 구현.

어제 SeeFood와 했던 것 그대로 작성한다.

고고

우선 내 기억과 이해를 바탕으로 먼저 작성해본다.

```swift
// 나
func detect (image: CIImage) {
            
    var coremlModel = try! VNCoreMLModel(for: FlowerClassifier().model)
    var request = VNCoreMLRequest(model: coremlModel) { (request, error) in
        print(request)
    }
        
    var handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }  

// 강의
func detect (image: CIImage) {
            
        guard let coremlModel = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Import model failed")
        }
        let request = VNCoreMLRequest(model: coremlModel) { (request, error) in
            print(request)
        }
        
        var handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }

// request 수정.
let request = VNCoreMLRequest(model: coremlModel) { (request, error) in
            let result = request.results?.first as? VNClassificationObservation
            
            self.navigationItem.title = result?.identifier
        }
```

실행하여 테스트.

102 종류의 꽃을 분류한다고하니 확인해보자.

![IMG_0025](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/4ed81e1f-7c37-4a7a-8704-608c3fec3d90)

애플 개발자 계정은 무료일땐 3개가 최대이다. (실제 폰에서 테스트할때)

## 결과의 첫번째 문자를 대문자로 바꾸기.

현재 결과를 보면 전부 소문자로 나온다.

앞에 대문자를 만들어 주자.

`self.navigationItem.title = result?.identifier.capitalized`

뒤에 capitalized 만 넣어주면 해결.

## 특정 Library 설치

Alamofire 와 swiftyJson을 설치한다.

## 위키피디아 api를 사용.

[Docs](https://en.wikipedia.org/api/rest_v1/#/) 참고.

API에 대한 간략한 정보는 여기에.

```text
let wikipediaURl = "https://en.wikipedia.org/w/api.php"

  let parameters : [String:String] = [
  "format" : "json",
  "action" : "query",
  "prop" : "extracts",
  "exintro" : "",
  "explaintext" : "",
  "titles" : flowerName,
  “indexpageids” : "",
  "redirects" : "1", 
  ]
```

위의 정보를 바탕으로 api 호출 url을 만들어본다.

그럼 다음과 같다

`https://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&exintro=&explaintext=&titles=flowerName&indexpageids=&redirects=1`

저기서 flowerName 부분에 label에 있는 꽃의 이름을 입력하면

![CleanShot 2024-04-18 at 14 31 41@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3f0d994f-254c-430c-ba31-b52e03790c0e)

이렇게 json 정보를 얻을 수 있다

## Alamofire(Old version) 사용하여 JSON 가져오기.

```swift
  func requestInfo(flowerName: String) {

          let parameters : [String:String] = [
          "format" : "json",
          "action" : "query",
          "prop" : "extracts",
          "exintro" : "",
          "explaintext" : "",
          "titles" : flowerName,
          "indexpageids" : "",
          "redirects" : "1",
          ]
        
        Alamofire.request(wikipediaURl, method: .get, parameters: parameters).responseJSON { (response) in
            if response.result.isSuccess {
                print("Got")
                print(response)
            }
        }
        
    }
```

parameters라는 배열을 통해 위에처럼 주소로 다 안적고 심플하게 할 수 있다.

강의상 Alamofire를 구버전으로 설치했기에 그걸로 했다.

특히 어려워할부분은 없다.

특이한건 responseJSON을 사용했다는것.

![CleanShot 2024-04-18 at 15 00 18@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6bfb112f-d450-40f1-983a-ef59499e8de6){: width="50%" height="50%"}

그러다보니 데이터 타입이 다르다.

기존에 우리가 아는 개념으로 적용했을땐 decoding 하고 어떤 Model이 DataType이었는데, 그런식으로 적용한 코드가 아니다.

기능테스트

![IMG_0026](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/3d1e04ca-c26a-4665-85db-5d9933187ea4)

화면과 콘솔에 출력되는 결과이다.

## swiftyJSON 사용

![CleanShot 2024-04-18 at 18 11 00@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/97a57ed8-e4f3-4749-a3dd-f238ad37ce95)


```swift
let flowerJSON: JSON = JSON(response.result.value!)
let pageid = flowerJSON["query"]["pageids"][0].stringValue
let flowerDescription = flowerJSON["query"]["pages"][pageid]["extract"].stringValue
                
self.label.text = flowerDescription
```

## SDWebImage 사용하기.

위키에서 제공하는 이미지를 사용하기위해 파라미터를 수정

```swift
let parameters : [String:String] = [
          "format" : "json",
          "action" : "query",
          "prop" : "extracts|pageimages", // modified
          "exintro" : "",
          "explaintext" : "",
          "titles" : flowerName,
          "indexpageids" : "",
          "redirects" : "1",
          "pithumbsize" : "500"
          ]

let flowerImageURL = flowerJSON["query"]["pages"][pageid]["thumbnail"]["source"].stringValue
                
self.imageView.sd_setImage(with: URL(string: flowerImageURL))
```

![CleanShot 2024-04-18 at 18 49 58@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/614b00fe-f3d9-42f6-9816-64f87e7f8834)

이미지에 주소에 대한 파라미터를 바꾸니 경로가 나온다.

![IMG_0027](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/f14a283f-fd5c-46c4-be92-c013394de734)

작동 완료.