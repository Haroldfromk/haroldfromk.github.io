---
title: SwiftUI Views = View Models?
writer: Harold
date: 2025-8-22 10:00:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## SwiftUI View의 본질: View는 이미 ViewModel이다

SwiftUI의 View가 단순히 화면을 그리는 도구가 아니라, 데이터를 가공하고 바인딩하는 ViewModel의 역할을 이미 수행하고 있음을 분석한다.

### 1. SwiftUI View와 UIKit View의 차이
SwiftUI의 View는 픽셀을 직접 그리는 주체가 아니라, 화면이 어떻게 보여야 하는지 정의하는 '선언(Declaration)'에 불과하다. 실제 그리기는 내부적으로 UI Switch, Collection View 등 UIKit 요소들이 담당한다.

### 2. View가 ViewModel인 이유
ViewModel의 핵심 정의는 **'모델의 데이터를 가져와 뷰에 바인딩하고 구조화하는 것'**이다. SwiftUI View는 이미 이를 위한 강력한 도구들을 내장하고 있다.

- **상태 관리 도구**: @State, @Binding, @Environment 등은 데이터와 뷰를 연결하는 바인딩 기능을 제공한다.
- **특수 데이터 접근**: @Query(Swift Data), @FetchRequest(Core Data) 등 데이터베이스 접근 매크로는 오직 View 내부에서만 동작하도록 설계되어 있다.
- **편의 기능**: GestureState, FocusState 등 UI 상호작용에 필요한 상태 역시 View 내부에서 가장 효율적으로 관리된다.

### 3. 실전 사례 분석: Food Truck 앱 (Apple Sample Code)
애플의 공식 예제인 Food Truck 앱의 OrdersView를 보면, 별도의 OrdersViewModel을 만들지 않고 View 내부에서 직접 데이터를 가공한다. (코드가 너무 길어서 생략)

- **데이터 가공(Massaging)**: View 내부에서 직접 filter 연산을 수행하거나 세션을 정렬한다. 
- **이유**: View 자체가 ViewModel이므로, 데이터를 View가 쓰기 편한 구조로 변환하는 작업(Transformations)을 View 내부 프로퍼티에서 수행하는 것이 가장 효율적이기 때문이다.

### 4. 서비스 레이어와 View의 직접 통신
데이터가 단일 뷰에서만 사용된다면, View에서 직접 서비스(HTTPClient 등)를 호출하여 데이터를 가져와도 무방하다.

- **데이터 전파**: 만약 이 데이터가 하위 계층(Nested Views)으로 깊게 전달되어야 한다면, 그때는 이전 강의에서 배운 Bounded Context와 Environment 객체를 활용하여 계층 간 결합도를 낮춘다.
- **성능과 효율**: 애플이 권장하는 방식대로 View를 ViewModel처럼 활용하면 데이터 업데이트가 반영되지 않는 버그를 원천적으로 방지할 수 있다.

### 핵심 요약
SwiftUI View는 단순한 UI 레이어가 아니라 데이터를 바인딩하고 구조화하는 ViewModel 그 자체이다. 별도의 ViewModel 클래스를 만들기보다 SwiftUI가 제공하는 속성 래퍼(@State, @Query 등)를 View 내부에서 적극적으로 활용하는 것이 더 빠르고 효율적이며, SwiftUI의 설계 철학에 부합하는 방식이다.

[SwiftUI View Struct 글 참고](https://www.malcolmhall.com/2023/03/23/learn-swiftuis-view-struct-value-semantics-diffing-and-dependency-tracking/){:target="_blank"}

