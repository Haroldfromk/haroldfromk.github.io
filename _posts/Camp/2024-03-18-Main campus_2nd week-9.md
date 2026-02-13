---
title: 3주차 (1)
writer: Harold
date: 2024-03-18 14:00
categories: [캠프, 3주차]
tags: []

toc: true
toc_sticky: true
---

## UIView Component

### 1. UILabel
- 텍스트를 표시하는 데 사용되는 UI Component

- 함수를 통한 UILabel 생성

```swift
func setUIlabel () {
        let label = UILabel()
        label.text = "Hello World!" // Label에 보여주기
        label.font = UIFont.systemFont(ofSize: 15) // Font size 설정
        label.textColor = UIColor.red // Font color 설정
        label.textAlignment = .center // Text alignment 설정
        label.numberOfLines = 2 // Number of lines 최대 2줄까지 표시
                                // 0으로 하면 자동으로 줄을 바꾼다.
        label.lineBreakMode = .byTruncatingTail // Text가 너무 길면 ... 으로 표시
        
        label.frame = CGRect(x:150, y:150, width: 150, height: 150)
        // 생성될 label의 위치와 크기를 세팅
        label.backgroundColor = #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1) // label 배경색을 설정.
        
        label.layer.borderWidth = 3 // label에 테두리 굵기를 설정한다.
        label.layer.borderColor = UIColor.red.cgColor // label 테두리 색을 설정
                                                                // 뒤에 cgColor가 오는걸 명심하자
        
        self.view.addSubview(label)
        // 실제로 해당 뷰를 띄우겠다. 이걸 작성하지 않으면 함수를 호출해도 보이지 않는다.
    }
```

### 2. UIImageView
- Image를 표시하는 데 사용되는 UI Component
    - image : 표시할 이미지를 설정, UIImage 객체 할당
    - contentMode : 이미지가 UIImageView에 맞춰질 대의 크기 및 배치 방법을 설정한다.
    - isUserInteractionEnabled : 사용자 상호작용을 허용할지에 대한 여부
    - animationImages : 애니메이션을 위한 이미지 배열을 설정, 여러 UIImage객체를 할당하여 애니메이션을 만들 수 있다.`

```swift
func setImageView () {
        let imageView = UIImageView()
        let image = UIImage(named: "test") // Image File 명으로 UIImage 오브젝트 생성
        imageView.image = image
        
        // 이미지 뷰의 프레임 설정
        imageView.frame = CGRect(x: 150, y: 350, width: 150, height: 150)
        
        // contentMode 설정
        imageView.contentMode = .scaleAspectFit // 이미지 비율 유지하면서 맞춘다.
        
        // 뷰를 화면에 표시
        self.view.addSubview(imageView)
    }
```

### 3. UITextField
- 사용자로부터 텍스트를 입력받기 위해 사용되는 UI Component
    - text : TextField에 표시되는 문자열
    - placeholder : TextField에 입력을 유도하기 위해 표시되는 플레이스 홀더 텍스트를 설정
    - keyboardType : 사용자가 텍스트 필드에 입력할 때 표시되는 키보드 유형을 설정
    - isSecureTextEntry : 입력된 텍스트를 숨기기 위해 설정하는 속성
    - returnKeyType :  키보드의 리턴키의 타입을 설정 

```swift
func setUITextField() {
        let textField = UITextField()
        
        textField.placeholder = "여기에 입력해"
        textField.borderStyle = .roundedRect // TextField의 모양 (둥근 테두리)
        textField.keyboardType = .default // 일반 키보드
        textField.isSecureTextEntry = false // 비밀번호처럼 *** 이런식으로 가릴건지의 여부
        textField.returnKeyType = .done // Return키의 종류

        
        textField.frame = CGRect(x: 150, y: 400, width: 150, height: 40)
        
        self.view.addSubview(textField)
        
    }
```

### 4. UIButton
- 사용자가 터치하여 상호작용 할 수 있는 UI Component
    - titleLabel : 버튼에 표시되는 텍스트 레이블에 대한 접근 제공
    - setImage(_:for:) : 버튼에 이미지를 설정하고 상태에 따라 다른 이미지를 사용 할 수 있다.
    - setTitle(_:for:) : 버튼에 텍스트를 설정하고 상태에 따라 다른 텍스트를 사용할 수 있도록 한다.
    - addTarget(_:action:for:) : 버튼이 터치되었을 때 실행할 액션을 등록한다. 버튼의 동작을 정의한다.
    - isEnabled : 버튼이 활성화 되었는지의 여부를 나타낸다.
        - 비활성화 된 버튼은 터치 또는 클릭 이벤트를 무시한다.

```swift
 func setUIButton() {
        let uiButton = UIButton(type: .system)
        
        uiButton.setTitle("눌러봐", for: .normal) // 현재 버튼의 text
        uiButton.setTitleColor(UIColor.green, for: .normal) // 글자색
        uiButton.frame = CGRect(x: 150, y: 500, width: 150, height: 50)
        uiButton.backgroundColor = .blue // 배경색
        uiButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside) // 버튼을 눌렀을때 실행할 함수를 지정해준다.
        
        self.view.addSubview(uiButton)
    }
    
    @objc func buttonTapped() {
        print("Button Pressed")
    }
```

### 5. UISwitch
- On/Off 상태를 표시하고 전환하는데 사용되는 UI Component
    - isOn : 스위치의 현재 상태
    - onTintColor : 스위치가 켜져있을 때의 배경 색
    - thumbTintColor : 스위치의 썸네일 색상
    - OnImage : 스위치가 켜져있을 때 표시되는 이미지
    - offImage : 스위치가 꺼져있을 때 표시되는 이미지

```swift
func setUISwitch () {
        let uiSwitch = UISwitch()
        uiSwitch.isOn = true
        uiSwitch.onTintColor = .blue
        uiSwitch.thumbTintColor = .orange
        
        uiSwitch.addTarget(self, action: #selector(switchValueChanged(_ :)), for: .valueChanged) // valuechanged : 값이 변했을때 인지
        
        uiSwitch.frame = CGRect(x: 50, y: 70, width: 40, height: 40)
        
        self.view.addSubview(uiSwitch)
    }
    
    @objc func switchValueChanged (_ sender : UISwitch ) {
        if sender.isOn {
            print("switch on")
        } else {
            print("switch off")
        }
    }
```