---
title: RunWay (1) 프로젝트 시작
writer: Harold
date: 2026-06-01 07:33:00 +0800
categories: [RunWay]
tags: [Project]

toc: true
toc_sticky: true
published: true
---

개인 장기? 프로젝트를 진행해본다.

---

## 1. 프로젝트 만들기

위의 표처럼 기본적인 세팅을 하고 들어간다.

사실 개인적으로 여기서 가장 큰 핵심은 `Swift6`을 사용했다는 점이다.

확실히 **Swift 5**를 쓰다가 최근에 **Swift 6**을 접하니 `Concurrency`부분이 상당히 빡셌다. 

즉 그만큼 철저한 Thread 관리가 필요하다는걸 느꼈는데, 이참에 시작을 6으로 해서 개발을 한다면 나중에 리팩토링 할때보다는 훨씬 괜찮을 것이라고 생각했다.

---

### 프로젝트 구조

우선 셋업은 아래와 같이 했다.

```
RunWay/
├── Models/
├── Services/
├── Utilities/
├── ViewModels/
├── Views/
├── Assets.xcassets
├── ContentView.swift
└── RunWayApp.swift

RunWayWatch Watch App/
├── Assets.xcassets
├── ContentView.swift
└── RunWayWatchApp.swift
```

초기 뼈대는 이렇게 했지만 언제 바뀔지는 몰라서. 수정할때마다 다시 최신화 하는걸로...

---

### 컨벤션 세팅

그리고 이제부턴 깃에 커밋할 때도 컨벤션을 정해서 관리하려고 한다.

| 타입 | 설명 |
| :--- | :--- |
| feat | 새로운 기능 추가 |
| fix | 버그 수정 |
| chore | 설정, 패키지 등 기타 작업 |
| refactor | 리팩토링 |
| docs | 문서 수정 |

---

### 브랜치 전략

| 브랜치 | 용도 |
| :--- | :--- |
| `main` | 안정적인 릴리즈 |
| `dev` | 개발 기본 브랜치 |
| `feature/weekN-dayN-기능명` | Day 단위 작업 브랜치 (ex. feature/weekN-dayN-mainFeature) |

---

**브랜치 명령어**

```bash
# dev 브랜치 생성
git checkout -b dev

# feature 브랜치 생성 (dev 기반)
git checkout dev
git checkout -b feature/weekN-dayN-mainFeature

# 작업 완료 후 dev로 머지
git checkout dev
git merge feature/weekN-dayN-mainFeature

# 머지 후 feature 브랜치 삭제
git branch -d feature/weekN-dayN-mainFeature
```

---

### Issue + Projects 활용

깃허브 Issue를 적극적으로 활용할 계획이다. 혼자 진행하는 프로젝트지만 기능 단위로 Issue를 열어서 진행 상황을 기록하고, 블로그와 병행해서 개발 과정을 남기려고 한다.

| 라벨 | 용도 |
| :--- | :--- |
| `feat` | 새로운 기능 |
| `bug` | 버그 |
| `question` | 의문점, 조사 필요 |
| `docs` | 문서 작업 |

Issue는 GitHub Projects의 `RunWay Board`와 연동해서 `Todo / In Progress / Done` 형태로 진행 상황을 시각적으로 관리한다.

Issue에는 세부 체크리스트보다는 큰 틀 위주로 내용을 적을 예정이고, 자세한 과정은 블로그에 기록한다.

---

## 2. 모델링

Day 1이 너무 기본적이 셋업만 있고 너무 아쉬워서 모델링까지는 해보려고한다.

### 1. Flight Model: 러닝기록

항공 컨셉의 러닝앱이다보니 자연스레 모델명도 이렇게 하게 되었다.

우선적으로 생각해둔건 기본적인 러닝 데이터이다

- 거리 
- 시간
- 페이스 
- 심박수 
- 케이던스

```swift
enum RunMode {
    case modeA
    case modeB
}

struct Flight {
    
    var id = UUID()
    let mode: RunMode       // .modeA / .modeB
    let distance: Double    // km
    let time: Int           // seconds
    let pace: Double        // min/km
    let heartRate: Int      // bpm
    let cadence: Int        // spm
    let fuel: Int        // kcal (calories burned)
    let date: Date
    
}
```

그리고 러닝 모드에 따라 저장되는 기록의 성격이 다르기 때문에 `RunMode` enum을 추가했다.

Mode A는 목표 페이스를 설정하고 뛰는 기록이고, Mode B는 자유 러닝 기록이다. 나중에 로그북에서 어떤 모드로 뛰었는지 구분해서 보여줄 때 필요하다.

### 2. ModeA

```swift
struct ModeA {
    
    var id = UUID()
    let targetPace: Double // 목표 페이스
    let paceDeviation: Int // 허용 오차(seconds)
    
}
```

ModeB는 모델링을 하지 않는다. 어차피 자율 러닝이라서 그냥 flight를 그대로 써도 되기 때문이다.

---

### 3. Aircraft

처음엔 `User` 모델을 따로 만들려고 했는데, 지인과 이야기하다가 좋은 아이디어가 나왔다.

유저를 하나의 항공기로 보는 것이다. 항공 컨셉 앱이다 보니 자연스럽게 맞아떨어졌다. `AircraftView`가 곧 유저 프로필 화면이 되는 구조다.

```swift
struct Aircraft {
    var id = UUID()
    let name: String        // 기체명 (닉네임)
    let model: String       // 기종 (ex. A320-200)
    let height: Double      // cm
    let weight: Double      // kg
    let age: Int            // 세
    let gender: String      // 성별
}
```

키/몸무게/나이를 입력받으면 BMI와 최대 심박수(`220 - 나이`)를 자동으로 계산할 수 있다.

나중에 기종을 추가할 수도 있고, 기종마다 기본 목표 페이스나 허용 오차 기본값을 다르게 줄 수도 있다.

---

오늘은 컨디션때문에 여기까지