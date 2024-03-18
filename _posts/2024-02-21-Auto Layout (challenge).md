---
title: Auto Layout (challenge)
writer: Harold
date: 2024-02-21 04:13:00 +0800
categories: [Udemy, Auto Layout]
tags: []

toc: true
toc_sticky: true
---
![](https://velog.velcdn.com/images/haroldfromk/post/a6c6a73f-e925-4f98-8495-f100069ae0ad/image.png){: width="50%" height="50%"}

다음과 같이 만들어 보자.

우선 해당 Project를 clone하여 가져오니 다음과 같다.
![](https://velog.velcdn.com/images/haroldfromk/post/fdc7ec6b-ecfe-4400-abde-d45f0145488f/image.png){: width="50%" height="50%"}

내가 해야할건 위의 portrait인상태에서 landscape일때 위와 같은 형태로 보여지게 하면 되는것같다.

먼저 Landscape모드를 보았다.
![](https://velog.velcdn.com/images/haroldfromk/post/7312c444-4c94-433b-8621-0e49449634d3/image.png){: width="50%" height="50%"}

다음과같다.

constraint(제약)을 해야할것같다.

view구성을 보았다.
![](https://velog.velcdn.com/images/haroldfromk/post/80ef1a84-cbe1-456a-b1e7-4ffeff506a8e/image.png){: width="50%" height="50%"}

우선 Container들을 만들어야할것같다.

행개념으로 총 6개의 Container들을 만들면 될것같다.

하지만 이렇게하니 실패하였다....

---
각 button이 있는곳을 stackview를 만들어준다.
![](https://velog.velcdn.com/images/haroldfromk/post/00c93226-f20c-4586-ad15-429b1d3c9572/image.png){: width="50%" height="50%"}

그다음 전체를 다시 stackview로 만든다.
(이때 0이 있는 부분을 포함)
![](https://velog.velcdn.com/images/haroldfromk/post/bac396c5-9302-495d-93ba-ed6168c0b816/image.png){: width="50%" height="50%"}

그다음 현재 vertical stackview는 가장자리로 가야하므로 제약조건을 설정해준다.
![](https://velog.velcdn.com/images/haroldfromk/post/d1e59e0e-1619-411b-ba9b-a7f50ef21913/image.png){: width="50%" height="50%"}

그다음 fill equally를 통해 높이가 고르게 되도록 설정해준다.
![](https://velog.velcdn.com/images/haroldfromk/post/479caacf-b023-4564-92f3-fc2393649672/image.png){: width="50%" height="50%"}

그리고 그 하위 stackview역시 fill equally를 해줌으로써 가로도 똑같이 맞춰준다

그렇게 했을경우 마지막에 문제가된다
![](https://velog.velcdn.com/images/haroldfromk/post/ae4a4d81-2e63-41b5-b82e-ffe86b988679/image.png){: width="50%" height="50%"}

바로 이렇게 되는데

이때 (. =) 부분을 또 stack view로 만들어준다.
![](https://velog.velcdn.com/images/haroldfromk/post/3806cd0a-fc09-45e3-809b-e5254b9c2c3c/image.png){: width="50%" height="50%"}

그리고나서 다시 fill equally를 해주면 정렬이 제대로 된다.
![](https://velog.velcdn.com/images/haroldfromk/post/d998ad4f-95de-4d7a-b040-08cbf0b96c67/image.png){: width="50%" height="50%"}

얼추 다되어 간다.
하지만 상단의 0이있는 부분이 오른쪽 끝자락으로 붙어있다.

이것을 해결해주기위해 view를 새롭게 만들어준다.

![](https://velog.velcdn.com/images/haroldfromk/post/c29f365e-326d-4bcc-a045-f3a4c5ef68a4/image.png){: width="50%" height="50%"}

그리고 view를 투명하게 해주고
0이있는 부분에 다음과 같이 제약조건을 해준다
(지금 이미지는 이미 제약조건을 모두 설정해 둔 상태이다)

완성!