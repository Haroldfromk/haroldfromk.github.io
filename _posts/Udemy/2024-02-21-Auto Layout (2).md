---
title: Auto Layout (2)
writer: Harold
date: 2024-02-21 04:13:00 +0800
categories: [Udemy, Auto Layout]
tags: []

toc: true
toc_sticky: true
---
Auto Layout (1)에서 했던것을 바탕으로
Main의 화면도 Rotate했을때 background, image, button들이 짤리지 않고 유지하게 만들어 보자.

1. background
![](https://velog.velcdn.com/images/haroldfromk/post/024db107-c200-45a2-8672-bc56997ef7df/image.png){: width="50%" height="50%"}

up / down / left / right의 제약조건을 모두 활성화 해준다.

![](https://velog.velcdn.com/images/haroldfromk/post/fb8d7793-c2b4-4a64-9541-f390c13c7cba/image.png){: width="50%" height="50%"}

하지만 이렇게 safe area가 있으므로 그부분도 조절을 해주자.

![](https://velog.velcdn.com/images/haroldfromk/post/033ea5b2-182a-4b92-b7a8-20c185b7e6f8/image.png)

Horizontal stauts일때 superview로 설정하는 것이 아닌, vertical status일때 superview로 해주자!

2. images
하려고 시도를 해보았으나 안되었다. 이것은 container를 이용해서 만들어야한다.

아래와같이 3section으로 나누어 총 3개의 container를 만들고 진행한다.
![](https://velog.velcdn.com/images/haroldfromk/post/0eefa7e7-c2f7-4074-8441-6020290d05f3/image.png){: width="50%" height="50%"}

상단부터 시작하면 로고가있는 자리의 superview는 purple area가 된다.

---
Container를 만들어보자.

1. UIview를 만들어 주면된다.
![](https://velog.velcdn.com/images/haroldfromk/post/780ad471-333e-4f00-aa0f-daa8f26d6710/image.png){: width="50%" height="50%"}

uiview를 추가하니 이렇게 된다
![](https://velog.velcdn.com/images/haroldfromk/post/233d4456-f328-401e-9142-4ee791540934/image.png){: width="50%" height="50%"}

Dices의 Logo가 가려져있는걸 알 수 있다.
Logo를 보이게 한번 적용해보자.
![](https://velog.velcdn.com/images/haroldfromk/post/b0c4302a-fab5-4919-9365-4df15ff77655/image.gif)

(Auto layout(1)의 마지막에 로고가 가려진걸 보여지게 하는 법을 알아야겠다고 적었는데 바로 알게 되었다.)
![](https://velog.velcdn.com/images/haroldfromk/post/cf8ab2eb-b7be-4592-a771-7fe4b47cd318/image.png){: width="50%" height="50%"}

우리의 시선이 화살표방향으로 보는것이라고 생각하면 이해하기 쉽다.

---
하지만 지금은 우리가 원하는 view의 하위개념은 아니다.
다시 드래그 해주어 하위로 넣어보자
![](https://velog.velcdn.com/images/haroldfromk/post/053e069e-cc88-4e87-8bcc-60717703f947/image.gif)
이렇게 view안에 arrow가 새로 생기고 그안에 들어가면 하위로 들어가게 된다 
(생각보다 드래그로 넣는게 잘 안되었다.)

몇번해보니 옆으로 평행하게 두면 잘되는것같다.
![](https://velog.velcdn.com/images/haroldfromk/post/439ca4db-dc66-44e8-9c26-64d4518d96d9/image.png){: width="50%" height="50%"}
![](https://velog.velcdn.com/images/haroldfromk/post/bd0c0f19-b0de-4795-b5a2-ee00520a5fdf/image.gif)

---
2. Editor - embed in 으로 uiview넣어보기.
![](https://velog.velcdn.com/images/haroldfromk/post/22e8cf4c-df62-4ea2-bf55-b79c334d09d1/image.gif)

uiview안에 두개의 dices image가 들어가기때문에 두개를 command 누른채로 클릭하여 두개를 모두 선택해주고
상단의 Editor -> Embed In -> View를 클릭하여 만들어준다.
![](https://velog.velcdn.com/images/haroldfromk/post/5a543279-648e-4e9f-94bd-a5a1e0fa0341/image.png){: width="50%" height="50%"}

아래와 같이 하위로 자동으로 들어간것을 볼 수 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/f0d54283-9873-4eb1-a427-f8374b01e587/image.png){: width="50%" height="50%"}

---
3. 하단에 있는 interface로 view 추가하기.
![](https://velog.velcdn.com/images/haroldfromk/post/d2ba3086-deb9-4a16-9745-8729d0ce9ba5/image.gif)

![](https://velog.velcdn.com/images/haroldfromk/post/874ee17f-8651-48c7-ae5f-e69df74bf2e9/image.png){: width="50%" height="50%"}

view를 추가하는 방법에 대해 알아 보았다.
세가지 방법중 편한대로 하면 될것같다.

---
하지만 아래와 같이 View가 3개가 추가되었고 정확하게 어떤것에 대한 view인지 하위에 뭐가 있는지 보지않는이상 모른다. 
![](https://velog.velcdn.com/images/haroldfromk/post/459482ba-7973-4d5e-a0ae-f76c3283aa3c/image.png){: width="50%" height="50%"}

labeling을 해보도록 하자

![](https://velog.velcdn.com/images/haroldfromk/post/7b36fafa-91fb-4710-b3f5-bd8a36f25a0c/image.png)
위와 같이 해주면 된다.

![](https://velog.velcdn.com/images/haroldfromk/post/53888a50-046e-482f-963f-39d97e010c90/image.gif)

![](https://velog.velcdn.com/images/haroldfromk/post/0d7f7e21-a44c-4990-8e63-d5df93efe701/image.png){: width="50%" height="50%"}

![](https://velog.velcdn.com/images/haroldfromk/post/9a395718-6a7e-471b-89ec-cda6c595af8c/image.png){: width="50%" height="50%"}

Labeling이 된걸 알 수 있다.

드래그로 순서를 바꿔주어도 된다.
다만 주의할건 드래그하다가 하위로 들어가지 않게 조심하자!

![](https://velog.velcdn.com/images/haroldfromk/post/753c986f-a6fc-4d6e-a084-1779042b1ce1/image.png)

드래그를 하여 정렬을 해주었다.
arrow를 보면 모두 superview의 하위로 들어간걸 알수있다.

---
이젠 상 중 하단의 view를 모두 추가해 주었다.
그러면 다시 제약조건을 추가해보자.

1. Dices로고의 제약조건을 추가해보자.
![](https://velog.velcdn.com/images/haroldfromk/post/9954367a-97ae-4078-8540-742470aec5fd/image.png){: width="50%" height="50%"}

추가하자마자 에러가 발생하였다.
![](https://velog.velcdn.com/images/haroldfromk/post/d7da82ee-e9a1-46be-a752-7e4a314e1d86/image.png){: width="50%" height="50%"}

우리가 설정한 Container(view)에도 제약조건이 필요하다는것이다.
-> Container의 크기나 위치를 지정하지 않았다.
-> subview / container안에 제약조건을 추가해도 애매모호하다.
-> 어떻게 배치를 해야할지 모르기 때문이다.

StackView가 필요하다.
- 여러 view들을 stack해준다.
- 여기서는 3개의 view들을 세로로 stack한다.

2가지 방법이 있다.
(우선 stack view할 view들을 선택해준다 (command누르고 클릭), 여기선 3개를 선택해줄것이다.)
1. editor - embed in - stackview
![](https://velog.velcdn.com/images/haroldfromk/post/4cc45790-5822-4efa-beba-85cc344176b7/image.png){: width="50%" height="50%"}


2. 아래의 interface에서 stackview
![](https://velog.velcdn.com/images/haroldfromk/post/ee6d852a-4f9c-44df-87c6-b620e5ccd0ad/image.png){: width="50%" height="50%"}

---
![](https://velog.velcdn.com/images/haroldfromk/post/43f0a457-b12b-4a4b-8674-0835ee295379/image.png){: width="50%" height="50%"}

stackview가 생성이 되었다.

stackview에 대한 제약조건을 설정해준다.

이때 현재 top view의 범위가 safe area를 벗어낫기 때문에 arrow를 눌렀을때 보이지 않는다.
![](https://velog.velcdn.com/images/haroldfromk/post/fb43cb6a-e126-40e6-8406-1f13fe20a3ff/image.png){: width="50%" height="50%"}

stackview의 위치를 safe area에 걸치게 조절했다.
![](https://velog.velcdn.com/images/haroldfromk/post/6c851904-8153-4dfa-ba71-26f26127198f/image.png){: width="50%" height="50%"}

이제는 제약조건에 보이는걸 확인할 수 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/07e77295-e2fe-413a-8852-328fddcde356/image.png){: width="50%" height="50%"}

다음과 같이 stackview에 대한 제약조건을 설정하였다.
![](https://velog.velcdn.com/images/haroldfromk/post/e8e5106c-931f-49cb-b650-97cb28274556/image.png){: width="50%" height="50%"}

그리고 stack view bottom을 바꿔준다.
![](https://velog.velcdn.com/images/haroldfromk/post/aba0a179-24de-4479-a644-2ed208fa42a5/image.png){: width="50%" height="50%"}

다음과 같이 바꿔주었다.
![](https://velog.velcdn.com/images/haroldfromk/post/137b2fde-977c-499b-bf9e-04c57bb81352/image.png){: width="50%" height="50%"}

safe area를 남겨두었다.
![](https://velog.velcdn.com/images/haroldfromk/post/a33e8ce2-61bf-4244-a510-c2c56b8ab4c1/image.png){: width="50%" height="50%"}

현재 위의 사진과 같이 vertical status인 상태이다.
즉 다음과 같다.
![](https://velog.velcdn.com/images/haroldfromk/post/e13aca7c-78e5-4bab-a92b-31861be09052/image.png){: width="50%" height="50%"}

그리고 Stackview에 있는 3개지 view가 현재는 높이가 제각각인데, 이걸 균등하게 맞춰준다.

Distribution에서 Fill equally를 선택한다.
![](https://velog.velcdn.com/images/haroldfromk/post/22f9320b-4838-428d-8b50-4d385baf0262/image.png){: width="50%" height="50%"}

각 Container들의 높이가 같아졌다.
![](https://velog.velcdn.com/images/haroldfromk/post/db7a8879-598e-4c90-a0aa-d09acbbba924/image.png){: width="50%" height="50%"}

그리고 에러가 사라졌다.
Roll 버튼을 이제는 제약조건을 이용해 정렬을 할수 있게 되었다.
![](https://velog.velcdn.com/images/haroldfromk/post/a94f1b4f-4221-4d31-8615-5b00120a6479/image.png){: width="50%" height="50%"}

---
middle view에 있는 주사위들이 균등하게 정렬이 되도록 해보자.

1. 우선 두 주사위에대한 stack view를 새로만든다.
2. 제약조건을 설정해준다 (horizontal, vertical)
![](https://velog.velcdn.com/images/haroldfromk/post/b2f7ce9a-d8a7-442c-af10-141e8648c2e3/image.png){: width="50%" height="50%"}
---
![](https://velog.velcdn.com/images/haroldfromk/post/24706a86-84fa-4e1e-9894-17622a02f482/image.png){: width="50%" height="50%"}
spacing을 통해 각 view들의 간격을 조절 할 수있다.
![](https://velog.velcdn.com/images/haroldfromk/post/7168f515-95c4-41c7-954e-9e3c2ac62367/image.png){: width="50%" height="50%"}

현재 view의 background가 모두 white인걸 알 수있다.

하지만 실제로 우리는 다른 background image가 있으므로 view들의 배경색을 투명으로 바꿔주자.
![](https://velog.velcdn.com/images/haroldfromk/post/01a3143a-12a4-4853-a4c4-3f7bd2937066/image.png){: width="50%" height="50%"}

![](https://velog.velcdn.com/images/haroldfromk/post/2f15df41-76e5-4603-a1fa-a19bb1e0f920/image.png){: width="50%" height="50%"}

Roll 버튼이 제약조건에 의해 Text Size에 맞게 조절이 되어있다.
![](https://velog.velcdn.com/images/haroldfromk/post/6860a752-1f6b-4dba-87ae-7b4aa9ea21df/image.png){: width="50%" height="50%"}
위와 같이 가로 세로를 설정 해줄 수 있다.

바로 warning이 나온다.
![](https://velog.velcdn.com/images/haroldfromk/post/512210b6-b12d-422e-aee9-72da70e6f14e/image.png){: width="50%" height="50%"}

우리가 이렇게 임의로 설정하게되면 혹시라도 긴 text가 나오면 text 전부 보이지 않을 것이다.

세모를 눌러보면 3가지 방법을 제시해준다.
![](https://velog.velcdn.com/images/haroldfromk/post/8694b693-406b-44c6-8a4e-882a44339051/image.png){: width="50%" height="50%"}

두번째걸로 선택하면서 warning을 clear하였다.