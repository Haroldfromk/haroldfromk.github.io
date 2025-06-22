---
title: JPApexPredators (fin)
writer: Harold
date: 2025-4-21 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## iMessage를 위한 Sticker 만들어보기.

![Image](https://github.com/user-attachments/assets/d68db9d4-24f5-4693-9cce-da83c617f6ec)

`+` 버튼을 누른다.

![Image](https://github.com/user-attachments/assets/ffe24a21-c3d7-478c-9c44-52cef42de22c)

그리고 이렇게 sticker라고 검색하면 바로 나온다.

![Image](https://github.com/user-attachments/assets/e370754e-1ae9-4228-8ce4-31134e3e807e)

이름을 정하고 만들면 이렇게 Activate할거냐고 묻는데 그냥 Activate 해주자

![Image](https://github.com/user-attachments/assets/4443c4f1-ff43-4222-a4d2-a7e06c664bb7)

이렇게 새로운 Asset이 추가된걸 알 수 있다.

우선 Appicon이미지를 사이즈에 맞게 배치를 해주고,

![Image](https://github.com/user-attachments/assets/d18c2f58-5335-4478-9e2a-be7bf44e21d8)

이후 Sticker들도 드래그하여 추가를 해주자.

![Image](https://github.com/user-attachments/assets/f6fb700e-4ea5-47ab-b443-20c478f373e5)

물론 Sticker Pack의 이 스티커들은 드래그 하여 순서를 바꿀 수 있다.

이후 앱을 실행할때 주의점

![Image](https://github.com/user-attachments/assets/b43406c2-1f98-4207-8cc3-ba1382715729)

현재 Target이 바뀌어 있으므로 다시 앱으로 반드시 바꿔주자.

![Image](https://github.com/user-attachments/assets/8a20c55a-8470-44fb-9f9c-fa5a645485e5){: width="50%" height="50%"}

현재는 시뮬레이터라 전송은 안된다.

그리고 **주의점이 Sticker에 사용되는 아이콘들의 이미지 크기는 500kb 이하여야만 한다.**

[여기](https://developer.apple.com/design/human-interface-guidelines/imessage-apps-and-stickers){:target="_blank"} 애플이 규정한 스티커 이미지 정보가 있으니 반드시 확인해보자.

---

## Challenge

### 💻 코딩 챌린지 요약 (총 4가지)

#### 1️⃣ 디테일 화면 공룡 이미지 전체보기
- 디테일 화면의 공룡 이미지를 **탭 가능하게 만들기**
- 탭하면 **전체 화면에 공룡 이미지**만 보여주는 뷰로 전환
- 이전에 유사한 기능을 구현한 적 있음 (힌트: 연습했던 예제 참고)

---

#### 2️⃣ 지도 핀 탭 시 정보 카드 표시
- 맵 뷰에서 공룡 위치에 있는 핀(Annotation)을 탭하면  
  → **간단한 정보 카드(Info Card)** 표시
- 지도 앱에서 위치 클릭 시 나오는 정보창과 유사한 기능

---

#### 3️⃣ 영화 기반 필터 기능 추가
- 현재는 `type` 기준 필터링만 존재
- 공룡이 등장한 **영화 제목으로도 필터링** 기능 추가
- 각 공룡 데이터에 이미 등장 영화 정보가 포함되어 있음

---

#### 4️⃣ 공룡 리스트에서 항목 삭제 기능
- 사용자가 원할 경우 **공룡을 리스트에서 영구 삭제** 가능하도록 구현
- 사용 예: "이 공룡은 Apex Predator로 보기엔 부족해!" 같은 상황

---

### ✅ 추가 팁
- 난이도는 1 → 4 순 (하지만 사람마다 체감 난이도는 다를 수 있음)
- 도전 중 너무 어렵다면 **일단 건너뛰고 다음 강의로 이동**해도 무방
- 나중에 다시 돌아와 도전하거나, **새로운 챌린지를 스스로 만들어보는 것도 추천**
- 커뮤니티에 **자신만의 확장 아이디어나 구현 결과** 공유하면 좋음!

이후에 별도로 서술해보는걸로....