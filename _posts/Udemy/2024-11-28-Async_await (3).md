---
title: Async/Await (3)
writer: Harold
date: 2024-11-28 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

이번 섹션은 MVVM에 대한 내용을 다루는듯 하다.

시작하기전 Design Pattern에 대해 먼저 다루고 시작한다.

## Design Pattern ?

[참고글](https://refactoring.guru/ko/design-patterns){:target="_blank"}이 너무 잘되어있어서 이걸 보면 좋을듯.

일반적으로 디자인 패턴이라고 하면

>디자인 패턴은 소프트웨어 개발에서 **자주 발생하는 문제를 해결하기 위한 모범 사례**이다.  
주로 **클래스와 객체 간의 관계**를 설명하며, 반복적으로 발생하는 문제를 해결하기 위한 검증된 접근 방식을 제공한다.

![image](https://aglowiditsolutions.com/wp-content/uploads/2022/01/Creational-design-pattern-swift.png)
![image](https://aglowiditsolutions.com/wp-content/uploads/2022/01/Structural-Design-Pattern-Swift.png)
![image](https://aglowiditsolutions.com/wp-content/uploads/2022/01/Behavioural-Design-Patterns.png)
![image](https://aglowiditsolutions.com/wp-content/uploads/2022/01/iOS-design-patterns-in-swift.png)

위의 이미지는 아래 참고글에서 가져왔다.

또다른 [참고글](https://aglowiditsolutions.com/blog/top-swift-design-patterns/){:target="_blank"}도 봐두면 좋을듯

### 디자인 패턴의 특징

1. **개발 속도 향상**  
   - 미리 정의된 패턴을 활용함으로써 개발 시간을 단축하고, 새로운 해결책을 찾는 데 소모되는 시간을 줄일 수 있다.  
   - 특정 애플리케이션 부분을 구축하는 템플릿 역할을 한다.

2. **프로그래밍 언어 독립적**  
   - 디자인 패턴은 특정 언어나 프레임워크에 종속되지 않는다.  
   - 예를 들어, 동일한 디자인 패턴은 **C#**, **Java**, **Swift** 등 다양한 언어에서 구현할 수 있다.  
   - 이러한 보편성 덕분에 여러 플랫폼에서 유연하게 활용할 수 있다.

3. **유연성, 재사용성, 유지보수성**  
   - 디자인 패턴은 **유연성**을 갖추고 있어 프로젝트 요구사항에 따라 수정이 가능하다.  
   - **재사용성**을 높여 코드 중복을 줄이고, 유지보수가 용이한 솔루션을 제공한다.

## MVVM ?

MVVM은 다음 3개의 단어의 약자이다.

**M**: **M**odel → 데이터와 비즈니스 로직을 담당
**V**: **V**iew → 사용자가 실제로 상호작용하는 UI 화면
**VM**: **V**iew**M**odel → **Model**과 **View** 사이를 연결하는 중간 역할

![mvvm drawio](https://github.com/user-attachments/assets/441df072-0cbd-49e2-a3d4-eead837be468)

### 간단한 시나리오: Model과 View의 관계

1. **View**  
   - 사용자에게 보이는 UI 화면 (예: iPhone 화면, Android 화면 등)

2. **Model**  
   - 고객 정보, 쇼핑카트 정보 등 데이터와 비즈니스 로직을 포함

**문제점:**  
Model의 데이터를 직접 View에 전달하고 표시하는 방식은 **좋지 않다**.  
- Model 클래스에는 복잡한 비즈니스 로직이 포함될 수 있다.
- View에 Model을 직접 노출하면 유지보수가 어려워진다.


#### ViewModel을 사용한 해결

**ViewModel**을 도입하여 **Model**과 **View** 간의 직접적인 의존성을 제거한다.

1. **Model → ViewModel → View**  
   - Model이 데이터를 View에 표시하려면, 데이터를 ViewModel에 전달한다.  
   - ViewModel은 필요한 데이터를 가공하여 View에 전달한다.

2. **View → ViewModel → Model**  
   - View가 Model에 접근하려면, ViewModel을 통해 데이터를 요청한다.  
   - ViewModel이 데이터를 받아 필요한 처리를 한 뒤 Model과 통신한다.

**결과:**  
- View는 Model의 내부 비즈니스 로직을 알 필요가 없다.  
- 모든 데이터 흐름은 ViewModel을 통해 이루어진다.

## 그렇다면 왜 MVVM을 사용하는가?

위에서 **Model이 View에 직접 노출되면 안 되는 이유**를 다뤘지만, 구체적으로 **왜 그런지** 살펴본다.
- Model을 View에 직접 노출했을 때 발생할 수 있는 문제를 아래 간단한 시나리오를 통해 알아본다.

### 시나리오: 비밀번호 재설정 화면

1. **비밀번호 재설정 화면 구성**
   - **필드**: 사용자명(username), 새 비밀번호(new password), 이전 비밀번호 또는 확인 비밀번호(confirm password).
   - **Model**: 사용자명(username), 비밀번호(password).
![example drawio3](https://github.com/user-attachments/assets/98d228e3-0f2a-4ce3-98c6-89fed9651dca)

2. **문제점: Model과 View의 직접 연결**
   - Model에는 `confirm password`라는 필드가 없다.  
     - `confirm password`는 데이터베이스에 저장되지 않는 정보로, Model의 역할과 관계가 없다.
   - Model을 View에 직접 매핑하면, View에서 `confirm password`를 처리하기 어려워진다.
![example drawio1](https://github.com/user-attachments/assets/e64ffc92-570f-4887-a85f-c5d6608f7837)
#### 해결: ViewModel 사용

1. **PasswordResetViewModel**
   - **ViewModel의 역할**:  
     - View와 Model 사이에서 데이터를 주고받는 중간자 역할.
     - View의 추가적인 데이터를 관리(예: `confirm password`).
   - **PasswordResetViewModel 예시**:
     - 사용자명(username): 텍스트 필드의 데이터 가져오기.
     - 새 비밀번호(new password): 텍스트 필드의 데이터 가져오기.
     - 확인 비밀번호(confirm password): 텍스트 필드의 데이터 가져오기.

2. **검증 기능 추가**
   - ViewModel에서 데이터 검증을 수행하여 데이터가 Model로 전달되기 전에 문제를 해결.  
     - 예: 새 비밀번호와 확인 비밀번호가 일치하는지 확인

![example drawio](https://github.com/user-attachments/assets/b1329eb6-709e-4f24-bf63-5088406f6644)

## MVVM & Web APIs

이번에도 하나의 시나리오를 만들어 본다.

### 시나리오: 잘못된 접근 방식

1. **View와 Web Service의 직접 연결**  
   - View가 Web Service와 직접 통신하여 JSON 데이터를 요청.  
   - 예: View에서 클라우드에 데이터를 요청하고 응답을 처리.
![example2 drawio](https://github.com/user-attachments/assets/4da56edf-1927-4c21-b498-23567be52d34){: width="50%" height="50%"} 

2. **문제점**  
   - View와 Web Service가 강하게 결합되어 있음.  
   - **추상화 부족**: 코드의 유연성과 유지보수성이 저하됨.  
   - 변경이 발생할 경우, View와 Web Service 모두를 수정해야 할 가능성이 높아짐.

### MVVM과 네트워크 계층의 분리: 올바른 접근 방식

1. **데이터 요청 흐름**  
   - View는 ViewModel에 데이터를 요청.  
   - ViewModel은 **Web Service**나 **Client Layer**를 통해 데이터를 요청.  
   - Web Service는 클라우드와 통신하여 데이터를 가져온 뒤, ViewModel로 반환.
![example3 drawio](https://github.com/user-attachments/assets/b6d317fa-e7aa-45cb-8544-552bc5f7059c)
2. **핵심 원칙**  
   - **ViewModel은 직접 네트워크 요청을 수행하지 않음.**  
     - ViewModel은 단순히 Web Service나 Client Layer에 요청을 전달.  
   - **책임 분리**: 네트워크 요청은 Web Service 계층에서 수행.

## 참고하면 좋을 유튜브 영상
1. [YouTube1](https://www.youtube.com/watch?v=cbqMkIG6Qeg&t=576s){:target="_blank"} 

2. [YouTube2](https://www.youtube.com/watch?v=5qqTAAY7W_Y){:target="_blank"}

3. [YouTube3](https://www.youtube.com/watch?v=1V37XQLoiIY&t=299s){:target="_blank"}
