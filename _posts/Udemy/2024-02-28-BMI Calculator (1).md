---
title: BMI Calculator (1)
writer: Harold
date: 2024-02-28 07:13:00 +0800
categories: [Udemy, BMI Calculator]
tags: []

toc: true
toc_sticky: true
---
![](https://velog.velcdn.com/images/haroldfromk/post/c1ce05ee-3f86-408a-b8e8-70ba3ac18f43/image.png){: width="50%" height="50%"}

UI Slider의 값을 미리 설정 해줄 수 있다.

![](https://velog.velcdn.com/images/haroldfromk/post/523ec1fd-5b4b-4e02-9178-1ac6c4cfef6e/image.png){: width="50%" height="50%"}

slider가 움직일때 console에서 값이 변하도록 만들어 보자.

먼저 IBAction을 만들어 준다.
![](https://velog.velcdn.com/images/haroldfromk/post/f9c7b5d5-107b-478f-b6df-db6ee614a98f/image.png){: width="50%" height="50%"}

```swift
var maximum : Double = 0.0
var minimum : Double = 0.0
    
var currentValue : Double = 0.0
    

    @IBAction func heightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        print(currentValue)
    }
    
    
    @IBAction func weightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        print(currentValue)
    }
    
```

이렇게 코드를 작성하였다.

![](https://velog.velcdn.com/images/haroldfromk/post/1343c04e-3c56-4cb6-ac25-f77dab543abe/image.gif){: width="50%" height="50%"}


계속 프린트가 되는 건데 내가한것과는 다르다..

코드차이는 없었다 그냥 창이 어떻게 보여지느냐의 차이였다.

그렇다면 소숫점을 둘째자리까지만 나오게 해보자.
```swift
@IBAction func heightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        print(String(format:"%.2f", currentValue))
    }
    
    @IBAction func weightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        print(String(format:"%.2f", currentValue))
    }

```

![](https://velog.velcdn.com/images/haroldfromk/post/a159dfa7-9d89-4777-80ba-0f1143b03643/image.png){: width="50%" height="50%"}

소수점이 안나오게하기위해 Int를 씌웠다.
```swift
 @IBAction func weightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        print(Int(currentValue))
    }
```
![](https://velog.velcdn.com/images/haroldfromk/post/3233e1cb-239e-44e3-b736-ff8c9c881e3d/image.png){: width="50%" height="50%"}

값을 변할때 console이 아닌 label에 값이 표시가 되게 구현해보자

![](https://velog.velcdn.com/images/haroldfromk/post/5d37dcb6-ea88-4bb7-b0c7-7e9511d1ab37/image.png){: width="50%" height="50%"}

```swift
@IBAction func heightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        
        heightLabel.text = String(format:"%.2f", currentValue)
        //print(String(format:"%.2f", currentValue))
    }
    
@IBAction func weightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        
        weightLabel.text = String(Int(currentValue))
        //print(Int(currentValue))
    }
```
![](https://velog.velcdn.com/images/haroldfromk/post/329fd480-da85-4d9e-a73b-c196a84a0f0e/image.gif){: width="50%" height="50%"}

뭐 이정도는 가볍지.

위와 아래 통일성을 주기위해 수정을 해보자
(String(format:"%.2f", currentValue))
(String(Int(currentValue))

-> (String(format:"%.0f", currentValue))

하지만 처음에는 m / kg같은 단위가 있는데
수치만 나온다.

단위도 나오게 수정을 해보자.
```swift
 @IBAction func heightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        
        heightLabel.text = "\(String(format:"%.2f", currentValue))m"
        //print(String(format:"%.2f", currentValue))
    }
    
@IBAction func weightSliderChanged(_ sender: UISlider) {
        currentValue = Double(sender.value)
        
        weightLabel.text = "\(String(format:"%.0f", currentValue))Kg"
        //print(Int(currentValue))
    }
```

끝.
![](https://velog.velcdn.com/images/haroldfromk/post/550ded68-dd1a-48e2-84c9-e3f94628d3bd/image.png){: width="50%" height="50%"}

---
현재 slider들을 움직이고 calculate버튼을 누르면 현재 위치한 슬라이더의 값이 나오게 해보자.

가장 쉬운 방법은 slider들의 IBoutlet을 생성해주고 그 value를 바로 찍어내면 된다.
![](https://velog.velcdn.com/images/haroldfromk/post/8a052205-95f2-441b-a8e4-2a8c46dcdb46/image.png){: width="50%" height="50%"}

```swift
 @IBAction func calculatePressed(_ sender: UIButton) {
        print(heightSlider.value)
        print(weightSlider.value)
    }
```

![](https://velog.velcdn.com/images/haroldfromk/post/836f4b8b-8324-438e-beb1-84cc8fb3f766/image.png){: width="50%" height="50%"}

위에 주어진 식을 이용하여 BMI를 출력해보자.

```swift
let bmi = weight / (height * height)
let bmi = weight / pow(height,2)
```
둘은 같은 표현이다.
