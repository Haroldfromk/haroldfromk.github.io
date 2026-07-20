---
title: RunWay 1.1 (1) - 네비게이션 헤더 커스텀 통일
writer: Harold
date: 2026-07-17 11:00:00 +0900
categories: [RunWay]
tags: [SwiftUI, Navigation]

toc: true
toc_sticky: true
published: true
---

네비게이션 헤더를 바꿔보려고한다.

사실 의식을 하지 않고있었는데, 새로운 기능을 준비중이라 AI에게 관련 기능을 설명하고 mockui를 받고, 또 그걸 swiftui로 그리게 했는데 UI를 확인해보던 중 Custom Navigation Header 가 눈에 띄였다.

그래서 이걸 아예 디폴트로 해서 헤더를 바꿔보려고 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/before.png){: width="50%" height="50%"}

이걸

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/after.png){: width="50%" height="50%"}

이런식으로 헤더를 바꿀 생각이다.

블러 처리를 한건, 기능 스포때문에 잠시..

---

## 헤더 디자인

우선 코드를 그대로 가져온 뒤에 별도의 파일을 만들어 주었다.

```swift
struct NavigationHeader: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    
    var body: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.rwText)
            }
            Spacer()
            Text(title)
                .font(.orbitron(14, weight: .black))
                .foregroundColor(.rwGreen)
                .kerning(1)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
```

이걸 화면마다 매번 손으로 끼워 넣어야 하나 싶었는데, [이전글](https://haroldfromk.github.io/posts/MapKit-(1)/){:target="_blank"}에서 반복되는 모디파이어를 CustomModifier로 뽑아냈던 게 떠올랐다. 

지금 상황도 똑같다. 헤더를 디폴트로 할거면 매 화면마다 `NavigationHeader`를 직접 얹는 것보다, 그때처럼 `ViewModifier` + `View` extension으로 묶어서 `.customNavHeader(...)` 하나만 붙이는 게 더 낫다고 생각했다.

우측 버튼이 화면마다 있을 수도 없을 수도 있고, 나중에 버튼이 여러 개 붙거나 메뉴로 바뀔 수도 있을 것 같아서, 단순히 옵셔널 아이콘 하나로 받기보다 `@ViewBuilder` 트레일링 클로저로 받기로 했다. 

루트 화면처럼 뒤로가기 버튼 자체가 없어야 하는 경우도 있어서 `showsBackButton` 플래그도 같이 뒀다.

우선 `NavigationHeader` 자체를 트레일링 컨텐츠를 받을 수 있게 제네릭으로 바꿨다.

---

## 제네릭 사용하기

[이전글](https://haroldfromk.github.io/posts/Main-campus_2nd-week-7/){:target="_blank"}에서 간단하게 제네릭에 대해서 정리를 했었다. 그때 당시는 그냥 공부할 내용을 복붙했던 개념이었다.

이번엔 실제 코드에 써먹은 김에 `<T: View>`가 뭘 뜻하는지 제대로 정리하고 넘어간다. 이건 "`NavigationHeader`는 `T`라는 미지의 타입 하나를 받는데, 그 `T`는 반드시 `View` 프로토콜을 따라야 한다"는 뜻이다. `T`가 정확히 어떤 타입인지는 이 구조체를 실제로 쓰는 시점에 결정된다. 예를 들어 `trailing`에 `Button`을 넘기면 그 순간 `T`는 `Button`이 되고, `Image`를 넘기면 `T`는 `Image`가 되는 식이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/nav-header-generic.png){: width="70%" height="70%"}

이렇게 제네릭으로 만든 이유는, `trailing: () -> T`처럼 클로저가 정확히 어떤 뷰를 돌려주는지 Swift가 미리 알고 있어야 하기 때문이다.

---

## 헤더 디자인 (제네릭 적용)

```swift
struct NavigationHeader<T: View>: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var showsBackButton: Bool = true
    @ViewBuilder var trailing: () -> T

    var body: some View {
        ZStack {
            Text(title)
                .font(.orbitron(14, weight: .black))
                .foregroundColor(.rwGreen)
                .kerning(1)

            HStack {
                if showsBackButton {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.rwText)
                    }
                }
                Spacer()
                trailing()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
```

기존엔 `HStack { 뒤로가기, Spacer, 타이틀, Spacer }` 구조였는데, 이건 우측에 아무것도 없을 때만 대충 중앙처럼 보이는 거였다. 트레일링 버튼이 붙는 순간 좌우 폭이 달라지면서 타이틀이 한쪽으로 쏠린다. 그래서 타이틀은 `ZStack`으로 따로 빼서 항상 정중앙에 고정하고, 뒤로가기/트레일링은 그 위에 얹는 `HStack`으로 분리했다. 이러면 좌우에 뭐가 있든 없든 타이틀 위치는 안 흔들린다.

---

## Custom Modifier로 감싸기

다음은 이 헤더를 화면 콘텐츠 위에 얹어주는 `ViewModifier`다.

```swift
private struct CustomNavHeaderModifier<T: View>: ViewModifier {
    var title: String
    var showsBackButton: Bool
    @ViewBuilder var trailing: () -> T

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            NavigationHeader(title: title, showsBackButton: showsBackButton, trailing: trailing)
            content
        }
        .navigationBarHidden(true)
    }
}
```

헤더를 화면 콘텐츠 맨 위에 얹고, 시스템 네비게이션 바는 같이 숨겨버렸다. 이걸 안 숨기면 커스텀 헤더 위에 시스템 바가 하나 더 남아서 두 줄짜리 헤더가 된다.

마지막으로 이 모디파이어를 `.customNavHeader(...)`처럼 쓸 수 있게 `View` extension으로 감쌌다.

```swift
extension View {
    func customNavHeader<T: View>(
        _ title: String,
        showsBackButton: Bool = true,
        @ViewBuilder trailing: @escaping () -> T = { EmptyView() }
    ) -> some View {
        modifier(CustomNavHeaderModifier(title: title, showsBackButton: showsBackButton, trailing: trailing))
    }
}
```

`trailing`에 기본값으로 `EmptyView()`를 줘서, 우측 버튼이 필요 없는 화면은 `.customNavHeader("타이틀")`만 붙이면 되고, 필요한 화면만 트레일링 클로저를 채워주면 된다.

글로만 따라오면 헷갈릴 수 있어서 지금까지 나온 구조를 그림으로 정리해봤다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/nav-header-structure.png)

위쪽은 `NavigationHeader` 내부에서 `ZStack`이 타이틀 레이어와 뒤로가기/trailing 레이어를 어떻게 겹치는지, 아래쪽은 화면에 `.customNavHeader(...)`를 붙였을 때 `CustomNavHeaderModifier`가 `VStack`으로 헤더와 콘텐츠를 쌓아 올리는 흐름이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/generic.png){: width="50%" height="50%"}

---

## 헤더 적용하기

이제 `navigationTitle`이 있는곳에 적용을 해주면 된다.

command + shift + F를 통해 `navigationTitle`을 어디서 사용하는지 확인을 했다.

확인결과, FlightCalendarView, FlightSummaryView, ModeAView, TakeoffView에서 사용되는걸 확인했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/navtitle.png){: width="50%" height="50%"}

이제 여기에 우리가 만든 CustomModifier를 적용해주면 된다.

네 화면 다 구조가 똑같다. `FlightCalendarView` 기준으로 보면

```swift
.navigationTitle("FLIGHT CALENDAR")
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(Color.rwPanel, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)
```

이 다섯 줄이

```swift
.customNavHeader("FLIGHT CALENDAR")
```

한 줄로 줄어든다. 네 화면 다 우측에 버튼이 따로 없어서 `trailing`은 기본값(`EmptyView`)을 그대로 쓰면 된다.

나머지 세 화면도 타이틀 문자열만 바꿔서 똑같이 적용하면 된다. `FlightSummaryView`는 `.customNavHeader("FLIGHT SUMMARY")`, `ModeAView`는 `.customNavHeader("MISSION FLIGHT")`, `TakeoffView`는 `.customNavHeader("TAKEOFF")`.

---

## 배경색이 빠지는 문제

실기기에서 돌려보니 상단 상태바 영역이 흰색으로 비어 보였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/before1.png){: width="50%" height="50%"}

`.toolbarBackground(Color.rwPanel, ...)`를 지우면서, 그 자리를 채워주던 배경색도 같이 없어진 거였다. 커스텀 헤더는 세이프에어리어(상태바 영역)까지 뻗어있지 않아서, 시스템 기본 흰 배경이 그 뒤로 그대로 비쳐 보였다.

`CustomNavHeaderModifier`에 배경을 깔고, 세이프에어리어까지 무시하도록 고쳤다.

```swift
func body(content: Content) -> some View {
    VStack(spacing: 0) {
        NavigationHeader(title: title, showsBackButton: showsBackButton, trailing: trailing)
        content
    }
    .background(Color.rwBg.ignoresSafeArea())
    .navigationBarHidden(true)
}
```

다시 확인해보니 상태바까지 배경색이 제대로 채워졌다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/after11.png){: width="50%" height="50%"}

생각보다 Custom Navigation Header의 크기가 작은것 같아 조금 사이즈를 키워 주었다.

```swift
Text(title)
    .font(.orbitron(16, weight: .black)) // modified
    // 생략

HStack {
    if showsBackButton {
       //생략
        label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold)) // modified
                .foregroundColor(.rwText)
        }
    }
    Spacer()
    trailing()
}
// 생략
.padding(.bottom, 12) // new
```

사진은 생략....