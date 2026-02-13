---
title: Auto Layout (1)
writer: Harold
date: 2024-02-21 04:13:00 +0800
categories: [Udemy, Auto Layout]
tags: []

toc: true
toc_sticky: true
---
Auto Layout 에서는 폰을 Rotate했을때 어플 화면이 변경되게 하는것을 공부할 예정이다.

![](https://velog.velcdn.com/images/haroldfromk/post/1c5a526d-48d5-4c55-8fa2-32a61060ff85/image.png){: width="50%" height="50%"}

현재는 이렇게 화면을 회전할 경우 지원이 되지않는 걸 볼 수 있다.

이렇게 Launch Screen에서도 Rotate했을때 로고가 짤리는 걸 알 수 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/be0fbdbe-3e00-4452-8af6-bfbfc65ae3f5/image.png){: width="50%" height="50%"}

---
Q:그러면 직접 사이즈를 조절하면 되는걸까?
A:안된다. 아래 이미지를 보자.
![](https://velog.velcdn.com/images/haroldfromk/post/fb32e43a-db90-4a52-8441-56c72c9da50b/image.gif)

---
Constraints라는 제약조건을 통해 화면을 rotate해도 빈공간이 안생기게끔 해볼것이다.

해당 부분을 클릭하면 다음과 같이 나온다.
![](https://velog.velcdn.com/images/haroldfromk/post/a5536593-c1b6-4508-9177-f2d29dd6e74f/image.png){: width="50%" height="50%"}

지금 위의 이미지는 전부 0이아니다. 그렇다는건
background가 폰에 정확하게 맞춰져있지 않다는것이다.

![](https://velog.velcdn.com/images/haroldfromk/post/6544936b-565c-4e94-b5a4-bdf2c38991e9/image.png){: width="50%" height="50%"}

우측과 아래쪽이 딱 맞지않고 여유분이 있는걸 알 수있다.

조절을 하면 아래와 같이 딱 0이된다.
![](https://velog.velcdn.com/images/haroldfromk/post/99d47632-ddc1-4590-aea8-25f89980fea0/image.png)

제약 조건을 추가 해보자.
![](https://velog.velcdn.com/images/haroldfromk/post/1422a1fd-5af2-45f2-9258-cc5011379dc9/image.png){: width="50%" height="50%"}
아래 박스가 제약조건을 추가하기전 (반투명 점선)
위쪽 박스가 제약조건을 추가한뒤의 모습이다(실선)

![](https://velog.velcdn.com/images/haroldfromk/post/89bf0b21-1178-49e4-9876-4047ec292f86/image.gif)

제약조건이 추가된걸 볼 수 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/9a8384e4-ebdf-465e-9745-790419527e3d/image.png){: width="50%" height="50%"}

하지만 아직 회전을 하면 좌우로 공백이 있는걸 볼 수 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/5fccc34c-25e3-4fa5-922f-cd235720100c/image.png){: width="50%" height="50%"}

그리고 그라데이션 또한 그대로이다.
즉 rotate할 때 이미지가 틀어지는게 아니라 그냥 좌우보정만 해주는걸 알 수 있다.

Safe Area.trailing / leading은 참고 이미지를 찾아보면 이해하기 쉽다.
보통은 배터리정보 or signal정보 같은걸 담기위한 공간이다.
![](https://velog.velcdn.com/images/haroldfromk/post/c69f1cd1-2c02-44a5-b5e9-3e6b32e4a401/image.png){: width="50%" height="50%"}

---
하지만 배경은 저렇게 빈공간을 남기지 않고 화면 전체를 덮어줘야 하기때문에 superview가 되어야 한다.
즉 safe area가 설정되는걸 원치 않는다.

superview는 viewcontroller 바로 밑에 있는 view로 모든걸 포함한다. 
-> 항상 전체 화면을 커버한다.

설정해둔 제약 조건중, 우리가 바꾸고자하는 제약조건을 클릭 한 뒤 우측의 second item에서 super view로 바꿔준다. 
(이미지상에선 가로인 상태로 super view로 설정하는걸로 보이지만 실제로는 세로인 상태에서 superview로 설정해 주었다.)
![](https://velog.velcdn.com/images/haroldfromk/post/18b6fdbf-af3f-4ad2-9989-ec1d3b9b8303/image.png)

trailing/leading의 second Item을 모두 super view로 바꾸면 아래와 같이 공백이 없어진걸 알 수있다.
![](https://velog.velcdn.com/images/haroldfromk/post/524b5b6f-3903-42ee-bf48-25d0917fab9c/image.png)

![](https://velog.velcdn.com/images/haroldfromk/post/26afd806-2c7c-40fb-9c33-9b1560e9532c/image.png)

이렇게 확인을 해볼수도 있다.
![](https://velog.velcdn.com/images/haroldfromk/post/3318e689-a009-4716-a847-a79e1ff8e7a1/image.gif)

---
로고도 똑같이 해보자.
![](https://velog.velcdn.com/images/haroldfromk/post/c6b3506e-c480-48f2-a545-9127e762fbc6/image.png)

로고는 배경화면과 달리 그 옆에 있는걸 클릭하고
가로 세로 모두 해야하므로 제일 밑에있는 Horizontally/Verically 2개 모두 체크해주자

---

로고에서 30픽셀 떨어진 상태로 제약조건 걸기
![](https://velog.velcdn.com/images/haroldfromk/post/04b75489-0e1c-4c13-b76c-cb45ba63ae03/image.png)
label을 선택하고 제약조건 추가에서 위에서 30픽셀이므로 30픽셀인지 확인하고, 옆에 삼각형을 눌러 로고로 해주자.

(왜 로고가 안보이는지 이유를 모르겠다...)
