---
title: RunWay 1.1 (1) - 네비게이션 헤더 커스텀 통일
writer: Harold
date: 2026-07-17 11:00:00 +0900
last_modified_at: 2026-10-25 23:00:00 +0900
categories: [RunWay]
tags: [SwiftUI, Navigation]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다.
{: .prompt-info }

네비게이션 헤더를 바꿔보려고한다.

사실 의식을 하지 않고있었는데, 새로운 기능을 준비중이라 AI에게 관련 기능을 설명하고 mockui를 받고, 또 그걸 swiftui로 그리게 했는데 UI를 확인해보던 중 Custom Navigation Header 가 눈에 띄였다.

그래서 이걸 아예 디폴트로 해서 헤더를 바꿔보려고 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/before.png)

지금은 iOS 기본 네비게이션 바를 쓰고 있다. 타이틀이 왼쪽 위에 작게 붙고, 앱의 다른 화면과 글꼴도 색도 따로 논다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/after.png)

이런식으로 헤더를 바꿀 생각이다. 타이틀이 가운데로 오고 Orbitron 글꼴에 초록색이 붙는다.

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

#### Environment로 뒤로가기 버튼 만들기

[`@Environment`](https://developer.apple.com/documentation/swiftui/environment){:target="_blank"}는 상위 뷰나 시스템이 내려준 값을 읽는 property wrapper다. 값을 일일이 인자로 넘기지 않아도, 화면 계층 어디서든 같은 값을 꺼내 쓸 수 있다.

그중 [`\.dismiss`](https://developer.apple.com/documentation/swiftui/environmentvalues/dismiss){:target="_blank"}는 **이 화면을 닫는 동작**이다. 돌려주는 값은 [`DismissAction`](https://developer.apple.com/documentation/swiftui/dismissaction){:target="_blank"} 타입이고, `dismiss()`처럼 함수를 부르듯 쓴다. 지금이 네비게이션으로 밀고 들어온 화면이면 뒤로 가고, 모달로 올라온 화면이면 내려간다. 어느 쪽인지 내가 따로 따질 필요가 없다는 게 이걸 쓰는 이유다.

나머지는 SwiftUI 기본 요소다. `HStack`은 가로로 늘어놓고, `Spacer`는 남은 공간을 차지해 옆 요소를 밀어내고, `Image(systemName:)`은 애플이 기본으로 주는 SF Symbols 아이콘을 그린다. [`kerning(_:)`](https://developer.apple.com/documentation/swiftui/view/kerning%28%5F%3A%29){:target="_blank"}는 글자 사이를 벌리는 값이라 `1`을 주면 1pt씩 떨어진다.

이걸 화면마다 매번 손으로 끼워 넣어야 하나 싶었는데, [이전글](https://haroldfromk.github.io/posts/MapKit-(1)/)에서 반복되는 모디파이어를 CustomModifier로 뽑아냈던 게 떠올랐다. 

지금 상황도 똑같다. 헤더를 디폴트로 할거면 매 화면마다 `NavigationHeader`를 직접 얹는 것보다, 그때처럼 `ViewModifier` + `View` extension으로 묶어서 `.customNavHeader(...)` 하나만 붙이는 게 더 낫다고 생각했다.

우측 버튼이 화면마다 있을 수도 없을 수도 있고, 나중에 버튼이 여러 개 붙거나 메뉴로 바뀔 수도 있을 것 같아서, 단순히 옵셔널 아이콘 하나로 받기보다 `@ViewBuilder` 트레일링 클로저로 받기로 했다. 

루트 화면처럼 뒤로가기 버튼 자체가 없어야 하는 경우도 있어서 `showsBackButton` 플래그도 같이 뒀다.

우선 `NavigationHeader` 자체를 트레일링 컨텐츠를 받을 수 있게 제네릭으로 바꿨다.

---

## 제네릭 사용하기

[이전글](https://haroldfromk.github.io/posts/Main-campus_2nd-week-7/)에서 간단하게 제네릭에 대해서 정리를 했었다. 그때 당시는 그냥 공부할 내용을 복붙했던 개념이었다.

이번엔 실제 코드에 써먹은 김에 `<T: View>`가 뭘 뜻하는지 제대로 정리하고 넘어간다. 이건 "`NavigationHeader`는 `T`라는 미지의 타입 하나를 받는데, 그 `T`는 반드시 `View` 프로토콜을 따라야 한다"는 뜻이다. `T`가 정확히 어떤 타입인지는 이 구조체를 실제로 쓰는 시점에 결정된다. 예를 들어 `trailing`에 `Button`을 넘기면 그 순간 `T`는 `Button`이 되고, `Image`를 넘기면 `T`는 `Image`가 되는 식이다.

![NavigationHeader 는 T 하나를 받고, trailing 에 Button 을 넘기면 T 가 Button 으로, Image 를 넘기면 Image 로 정해진다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/nav-header-type.png)

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

#### ViewBuilder로 여러 뷰를 하나로 받기

[`@ViewBuilder`](https://developer.apple.com/documentation/swiftui/viewbuilder){:target="_blank"}는 클로저 안에 뷰를 여러 개 써도 그걸 하나의 뷰로 묶어주는 result builder다. 이게 없으면 클로저는 뷰를 딱 하나만 돌려줄 수 있어서, 트레일링 자리에 버튼 두 개를 넣고 싶을 때 `HStack`으로 직접 감싸야 한다. 붙여두면 쓰는 쪽에서 그냥 나란히 쓰기만 하면 된다.

![@ViewBuilder 가 없으면 클로저가 뷰를 하나만 돌려줄 수 있어 HStack 으로 감싸야 하고 붙이면 여러 개가 하나로 묶인다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/viewbuilder.png)

`SwiftUI`의 `body`에 이미 이게 붙어 있다. 평소에 `VStack` 안에 뷰를 여러 개 쓰는 게 되는 이유가 이것이다.

[`ZStack`](https://developer.apple.com/documentation/swiftui/zstack){:target="_blank"}은 자식 뷰를 **앞뒤로 겹쳐 쌓는다.** `HStack`이나 `VStack`처럼 자리를 나눠 갖는 게 아니라 같은 자리에 포개진다. 나중에 쓴 뷰가 위로 온다.

기존엔 `HStack { 뒤로가기, Spacer, 타이틀, Spacer }` 구조였는데, 이건 우측에 아무것도 없을 때만 대충 중앙처럼 보이는 거였다. **가운데에 둔 게 아니라 양옆 여백이 우연히 같았을 뿐**이라는 게 정확한 표현이다. 트레일링 버튼이 붙는 순간 좌우 폭이 달라지면서 타이틀이 한쪽으로 쏠린다. 그래서 타이틀은 `ZStack`으로 따로 빼서 항상 정중앙에 고정하고, 뒤로가기/트레일링은 그 위에 얹는 `HStack`으로 분리했다. 이러면 좌우에 뭐가 있든 없든 타이틀 위치는 안 흔들린다.

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

#### ViewModifier로 화면을 감싸기

[`ViewModifier`](https://developer.apple.com/documentation/swiftui/viewmodifier){:target="_blank"}는 **뷰 하나를 받아서 바꾼 뷰를 돌려주는** 규칙이다. 지켜야 할 건 `body(content:)` 하나뿐이다. 여기서 `content`는 이 modifier가 붙은 원래 화면이고, 타입은 `Content`다. 구체적으로 어떤 뷰가 올지는 붙이는 쪽에서 정해지므로 이름만 있는 타입으로 받는다.

![ViewModifier 는 화면 View 를 받아 헤더와 원래 content 를 쌓은 새 뷰를 돌려주므로 화면 쪽 코드는 그대로다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/viewmodifier-wrap.png)

여기서는 받아온 `content` 위에 헤더를 올린 `VStack` 을 돌려준다. 원래 화면을 고치는 게 아니라 **감싸는 것**이라, 화면 쪽 코드는 한 줄도 바뀌지 않는다.

[`navigationBarHidden(_:)`](https://developer.apple.com/documentation/swiftui/view/navigationbarhidden%28%5F%3A%29){:target="_blank"}는 시스템이 그려주는 네비게이션 바를 숨긴다. 이걸 안 숨기면 커스텀 헤더 위에 시스템 바가 하나 더 남아서 두 줄짜리 헤더가 된다.

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

#### modifier로 점 하나짜리 문법 만들기

[`modifier(_:)`](https://developer.apple.com/documentation/swiftui/view/modifier%28%5F%3A%29){:target="_blank"}는 앞에서 만든 `ViewModifier`를 뷰에 실제로 적용하는 메서드다. 이걸 `View` extension 안에 넣어두면 `.padding()`이나 `.background()`처럼 점을 찍어 부르는 모양이 된다.

[`EmptyView`](https://developer.apple.com/documentation/swiftui/emptyview){:target="_blank"}는 **아무것도 그리지 않는 뷰**다. 자리도 차지하지 않는다. `trailing`의 기본값으로 줘서, 우측 버튼이 필요 없는 화면은 `.customNavHeader("타이틀")`만 붙이면 되고, 필요한 화면만 트레일링 클로저를 채워주면 된다.

`@escaping`이 붙은 건 이 클로저가 함수가 끝난 뒤에도 살아남기 때문이다. `modifier`에 넘겨져 뷰가 그려질 때마다 불리므로, 함수 호출이 끝났다고 버리면 안 된다.

글로만 따라오면 헷갈릴 수 있어서 지금까지 나온 구조를 그림으로 정리해봤다.

![NavigationHeader 안에서는 ZStack 이 타이틀 레이어와 뒤로가기 레이어를 겹쳐 쌓고, 화면에 customNavHeader 를 붙이면 CustomNavHeaderModifier 가 VStack 으로 헤더와 원래 화면을 쌓아 올린다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/nav-header-layers.png)

위쪽은 `NavigationHeader` 내부에서 `ZStack`이 타이틀 레이어와 뒤로가기/trailing 레이어를 어떻게 겹치는지, 아래쪽은 화면에 `.customNavHeader(...)`를 붙였을 때 `CustomNavHeaderModifier`가 `VStack`으로 헤더와 콘텐츠를 쌓아 올리는 흐름이다.

![반복되던 헤더를 modifier 한 줄로 줄이고, 제네릭과 ViewBuilder 로 어떤 트레일링 뷰든 받을 수 있게 되기까지를 열두 장면으로 정리한 그림](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/generic.png)

여기까지를 한 장으로 묶으면 위와 같다. 화면마다 헤더를 붙이던 것에서 시작해, 트레일링 아이콘이 화면마다 다른 문제를 제네릭으로 풀고, 여러 개를 넘기는 건 `@ViewBuilder`가, 아무것도 안 넘기는 건 `EmptyView`가 받아주는 흐름이다.

---

## 헤더 적용하기

이제 `navigationTitle`이 있는곳에 적용을 해주면 된다.

command + shift + F를 통해 `navigationTitle`을 어디서 사용하는지 확인을 했다.

확인결과, FlightCalendarView, FlightSummaryView, ModeAView, TakeoffView에서 사용되는걸 확인했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/navtitle.png)

Xcode 전체 검색 결과다. `navigationTitle`이 네 화면에서만 쓰이고 있다.

이제 여기에 우리가 만든 CustomModifier를 적용해주면 된다.

네 화면 다 구조가 똑같다. `FlightCalendarView` 기준으로 보면

```swift
.navigationTitle("FLIGHT CALENDAR")
.navigationBarTitleDisplayMode(.inline)
.toolbarBackground(Color.rwPanel, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)
.toolbarColorScheme(.dark, for: .navigationBar)
```

#### 걷어낸 네 가지 navigation modifier

지우는 쪽이지만, 커스텀 헤더가 대신 떠맡게 된 일이라 뭘 하던 것들인지 적어둔다.

| API | 하는 일 |
|---|---|
| [`navigationTitle(_:)`](https://developer.apple.com/documentation/swiftui/view/navigationtitle%28%5F%3A%29){:target="_blank"} | 네비게이션 바에 띄울 제목 문자열 |
| [`navigationBarTitleDisplayMode(_:)`](https://developer.apple.com/documentation/swiftui/view/navigationbartitledisplaymode%28%5F%3A%29){:target="_blank"} | 제목을 크게 깔지(`.large`) 한 줄로 작게 둘지(`.inline`) |
| [`toolbarBackground(_:for:)`](https://developer.apple.com/documentation/swiftui/view/toolbarbackground%28%5F%3Afor%3A%29){:target="_blank"} | 네비게이션 바 배경색과 보임 여부. `for:`로 어느 바인지 고른다 |
| [`toolbarColorScheme(_:for:)`](https://developer.apple.com/documentation/swiftui/view/toolbarcolorscheme%28%5F%3Afor%3A%29){:target="_blank"} | 그 바 안의 글자와 아이콘을 밝게 쓸지 어둡게 쓸지 |

배경을 칠하는 일을 `toolbarBackground`가 맡고 있었다는 점은 기억해둘 만하다. 조금 뒤에 이것 때문에 문제가 하나 생긴다.

이 다섯 줄이

```swift
.customNavHeader("FLIGHT CALENDAR")
```

한 줄로 줄어든다. 네 화면 다 우측에 버튼이 따로 없어서 `trailing`은 기본값(`EmptyView`)을 그대로 쓰면 된다.

나머지 세 화면도 타이틀 문자열만 바꿔서 똑같이 적용하면 된다. `FlightSummaryView`는 `.customNavHeader("FLIGHT SUMMARY")`, `ModeAView`는 `.customNavHeader("MISSION FLIGHT")`, `TakeoffView`는 `.customNavHeader("TAKEOFF")`.

---

## 배경색이 빠지는 문제

실기기에서 돌려보니 상단 상태바 영역이 흰색으로 비어 보였다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/before1.png)

화면 맨 위, 시계와 배터리가 있는 줄의 배경이 흰색으로 떠 있다. 그 아래 커스텀 헤더부터는 정상이다.

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

#### ignoresSafeArea로 상태바까지 배경 채우기

세이프에어리어는 상태바나 홈 인디케이터처럼 **시스템이 이미 쓰고 있는 가장자리를 피해 남겨둔 영역**이다. 평소에는 이 안쪽에만 그려지므로 글자가 시계에 가려지는 일이 없다.

[`ignoresSafeArea(_:edges:)`](https://developer.apple.com/documentation/swiftui/view/ignoressafearea%28%5F%3Aedges%3A%29){:target="_blank"}는 그 경계를 무시하고 화면 끝까지 뻗으라는 뜻이다. 인자를 비우면 네 방향 모두, `edges:`를 주면 특정 방향만 넘어간다.

주의할 점은 **이걸 어디에 붙이느냐**다. 여기서는 `Color`에 붙였다. 색만 화면 끝까지 퍼지고 헤더와 콘텐츠는 원래 자리에 남는다. 바깥 `VStack`에 붙였다면 타이틀까지 상태바 밑으로 올라가 시계와 겹쳤을 것이다.

다시 확인해보니 상태바까지 배경색이 제대로 채워졌다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-17-RunningProject-29/after11.png)

같은 자리를 다시 찍은 화면이다. 흰 띠가 사라지고 상태바까지 앱 배경색으로 이어진다.

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

---

## 참고자료

- [Configure your apps navigation titles (Apple)](https://developer.apple.com/documentation/swiftui/configure-your-apps-navigation-titles){:target="_blank"}
- [Reducing view modifier maintenance (Apple)](https://developer.apple.com/documentation/swiftui/reducing-view-modifier-maintenance){:target="_blank"}
