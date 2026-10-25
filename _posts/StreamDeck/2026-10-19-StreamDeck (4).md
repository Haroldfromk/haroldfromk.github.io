---
title: StreamDeck (4) 키캡처럼 눌리는 버튼, 길게 눌러 편집하기, 옆으로 넘기는 페이지
writer: Harold
date: 2026-10-19 18:30:00 +0900
last_modified_at: 2026-10-25 22:34:00 +0900
categories: [StreamDeck]
tags: [SwiftUI, Gesture, TabView]

toc: true
toc_sticky: true
published: true
---

> 이 시리즈는 내가 직접 쓴 개발기가 아니다. 무엇을 만들지 정해 Claude Code 에게 앱을 만들게 했고, 만든 과정과 쓰인 기술은 Claude Code 가 정리했다. 나는 방향을 정하고, 실기기에서 써 보며 고칠 곳을 찾아 다시 맡겼다. 그래도 글로 남기는 건 공부 때문이다. 아직 내가 아는 프레임워크가 몇 개 없어서, 이 앱에 쓰인 여러 프레임워크를 정리해 두고 나중에 하나씩 찾아보며 익히려고 한다.
{: .prompt-info }

아이패드 화면 배치는 시안 세 개를 놓고 골랐다. 버튼만 5×3으로 꽉 채운 안, 가로로 놓고 4×3 버튼 옆에 세로 볼륨 슬라이더를 붙인 안, 세로로 세우고 3×4 버튼 아래에 가로 슬라이더를 둔 안이었다. 아이패드가 모니터 옆에 가로로 놓여 있고 소리 크기는 쓸어 올리는 게 편할 것 같아서 두 번째(B안)로 정했다. 이번 글은 이 화면과 버튼 편집이다.

---

## 가로 4×3과 볼륨 페이더

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-page1.png)

(오른쪽 볼륨 슬라이더는 나중에 실제 값만큼 차오르는 게이지와 음소거 키로 바뀌었다. 모니터 소리 값을 BetterDisplay로 읽는 과정은 3편에 적었다.)

색은 버튼 종류를 구분하는 데만 썼다. 키캡 왼쪽 위의 작은 점이 앱은 파랑, 명령어는 초록, 새 터미널은 주황이고, 볼륨 슬라이더는 보라다. 바탕은 순검정 대신 아노다이징한 금속 같은 회색(`#2A2D33`)으로 했다. 나중에 ESP32 보드로 바뀔 물건이라 화면 속 버튼도 진짜 키보드 키처럼 보이게 하고 싶었다. 키 이름은 둥근 글꼴(SF Pro Rounded)로 키캡 각인 느낌을 냈고, 명령 글자는 실제로 코드라서 고정폭 글꼴로 따로 작게 적었다.

화면 전체는 스크롤되지 않는다. `GeometryReader`로 화면 크기를 받아서 가로가 더 길면 B안, 세로가 더 길면 3열 배치로 그린다. 버튼 크기는 남은 공간을 칸 수로 나눠 정해진다.

---

### GeometryReader란?

SwiftUI에서 화면은 큰 상자 안에 작은 상자를 넣어 가며 만든다. 보통 안쪽 상자는 자기가 쓸 수 있는 자리가 얼마인지 모른 채, 부모가 정해 준 대로 놓인다. `GeometryReader`는 "지금 나한테 주어진 자리가 가로 몇, 세로 몇인지"를 알려 주는 상자다. 그 숫자를 보고 안쪽에 무엇을 어떻게 놓을지 직접 정할 수 있다.

![가로가 더 긴 아이패드에서는 4×3 버튼 옆에 세로 볼륨, 세로가 더 긴 아이폰에서는 3×4 버튼 아래에 가로 볼륨을 놓는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-geometry.png)

여기서는 그 너비와 높이를 비교해서 배치를 고르고, 남은 자리를 칸 수로 나눠 버튼 크기를 정한다. 그래서 아이패드를 돌리거나 아이폰에서 열어도 화면에 꼭 맞는다.

```swift
// DeckView.swift (iOS)
GeometryReader { geo in
    let landscape = geo.size.width > geo.size.height
    VStack(spacing: 14) {
        ConnectionStatusView(phase: client.phase)
        if landscape {
            HStack(spacing: 18) {
                pages(columns: DeckConstants.columns)
                VolumeSlider(value: client.volume, available: client.volumeAvailable, vertical: true,
                             onChange: client.setVolume, onToggleMute: client.toggleMute)
                    .frame(width: 76)
            }
        } else {
            pages(columns: 3)
            VolumeSlider(value: client.volume, available: client.volumeAvailable, vertical: false,
                         onChange: client.setVolume, onToggleMute: client.toggleMute)
                .frame(height: 64)
        }
    }
    .padding(20)
    .disabled(!client.isConnected)
    .opacity(client.isConnected ? 1 : 0.55)
}
```

#### GeometryReader와 VStack으로 배치 고르기

[`GeometryReader`](https://developer.apple.com/documentation/swiftui/geometryreader){:target="_blank"}는 안쪽에 주어진 자리 크기를 `geo.size`(가로, 세로)로 알려 주는 상자다. 그 값을 비교해 가로가 길면 [`HStack`](https://developer.apple.com/documentation/swiftui/hstack){:target="_blank"}(왼쪽에서 오른쪽으로 놓기)에 버튼과 볼륨을 나란히, 세로가 길면 [`VStack`](https://developer.apple.com/documentation/swiftui/vstack){:target="_blank"}(위에서 아래로 쌓기)에 위아래로 놓았다. `spacing`은 사이 간격이다. 화면 전체에 붙인 modifier는 이렇다.

| API | 하는 일 |
|---|---|
| [`frame(width:height:alignment:)`](https://developer.apple.com/documentation/swiftui/view/frame%28width:height:alignment:%29){:target="_blank"} | 뷰 크기를 정한다. 볼륨 칸 너비를 76으로 고정했다 |
| [`padding(_:_:)`](https://developer.apple.com/documentation/swiftui/view/padding%28%5F:%5F:%29){:target="_blank"} | 뷰 둘레에 여백을 둔다 |
| [`disabled(_:)`](https://developer.apple.com/documentation/swiftui/view/disabled%28%5F:%29){:target="_blank"} | true면 안의 버튼과 제스처가 전부 눌리지 않는다 |
| [`opacity(_:)`](https://developer.apple.com/documentation/swiftui/view/opacity%28%5F:%29){:target="_blank"} | 투명도. 0.55면 흐리게 보인다 |

맥에 연결이 안 돼 있으면 화면 전체를 흐리게 하고 누를 수 없게 했다. 눌러도 아무 일이 안 일어나는 버튼이 멀쩡해 보이면 더 헷갈려서다.

---

## 키캡이 눌려 들어가는 모양

키캡은 두 겹이다. 아래에 어두운 아랫단을 깔고, 그 위에 윗면을 올린다. 평소엔 윗면이 아랫단보다 조금 위에 떠 있어서 키의 옆면이 보이고, 누르는 동안에는 윗면을 그만큼 아래로 내려서 아랫단에 딱 붙게 했다.

```swift
// ButtonTile.swift (iOS)
private func keycap(_ button: DeckButton, side: CGFloat) -> some View {
    let lip = side * 0.06
    let radius = side * 0.16
    return ZStack(alignment: .top) {
        // 아랫단: 누르면 윗면이 이만큼 내려앉는다
        RoundedRectangle(cornerRadius: radius)
            .fill(DeckTheme.keyLip)
            .offset(y: lip)

        RoundedRectangle(cornerRadius: radius)
            .fill(LinearGradient(colors: [DeckTheme.keycapTop, DeckTheme.keycap], startPoint: .top, endPoint: .bottom))
            // 생략 (테두리, 종류 점, 아이콘과 이름)
            .offset(y: pressed ? lip : 0)
    }
    .padding(.bottom, lip)
    .animation(.spring(duration: 0.12), value: pressed)
}
```

#### ZStack으로 키캡을 두 겹 그리기

키캡은 이 순서로 그린다.

1. [`ZStack`](https://developer.apple.com/documentation/swiftui/zstack){:target="_blank"}으로 겹쳐 쌓는다. 뒤에 쓴 것이 위로 올라오고, `alignment: .top`은 위쪽 끝을 맞춘다.
2. 아랫단은 [`RoundedRectangle`](https://developer.apple.com/documentation/swiftui/roundedrectangle){:target="_blank"}(모서리가 둥근 사각형, `cornerRadius`가 둥글기)을 어두운 색으로 [`fill`](https://developer.apple.com/documentation/swiftui/shape/fill%28%5F:style:%29){:target="_blank"}한 뒤 [`offset(x:y:)`](https://developer.apple.com/documentation/swiftui/view/offset%28x:y:%29){:target="_blank"}으로 `lip`만큼 아래로 내려 둔다. `offset`은 자리는 그대로 두고 그리는 위치만 옮긴다.
3. 윗면은 같은 모양을 [`LinearGradient`](https://developer.apple.com/documentation/swiftui/lineargradient){:target="_blank"}(위가 밝고 아래가 어두운 색)로 칠한다. 눌렸을 때만 `offset`으로 `lip`만큼 내려 아랫단에 붙인다.
4. [`animation(_:value:)`](https://developer.apple.com/documentation/swiftui/view/animation%28%5F:value:%29){:target="_blank"}으로 `pressed` 값이 바뀔 때 내려가고 올라오는 움직임을 애니메이션으로 보여 준다.

`some View`는 "정확한 타입은 숨기지만 어떤 화면 조각 하나를 돌려준다"는 뜻이다. SwiftUI 뷰를 돌려주는 함수는 거의 다 이렇게 쓴다.

키 크기(`side`)에 비례해서 아랫단 두께와 모서리 둥글기를 정했다. 아이패드에서 키가 커지든 아이폰에서 작아지든 같은 비율로 보인다. 누르는 동안 종류 점의 빛도 살짝 퍼지게 했다.

빈 칸은 키캡이 빠진 자리처럼 점선 홈으로 그렸다. 누르면 버튼 추가 화면이 뜬다.

실제 아이패드에서 써 보니 눌렀다는 느낌이 거의 없었다. 원인은 두 가지였다. 하나는 눌림이 "누르고 있는 동안" 신호(`onPressingChanged`)로만 움직였다는 것이다. 짧게 탭하면 이 신호가 오기 전에 손이 떨어져서 키캡이 아예 안 움직였다. 다른 하나는 아이패드에는 진동 모터가 없다는 것이다. 진동을 넣어 뒀지만 아이폰에서만 느껴졌다.

그래서 탭하면 신호와 상관없이 0.12초 동안 확실히 눌렸다 올라오게 했다. 눌리는 동안 윗면이 살짝 밝아지고 종류 점이 커지면서 환해진다. 숫자 키패드와 음소거 키도 같은 방식이다.

```swift
// ButtonTile.swift (iOS)
@State private var pressed = false
/// 짧게 탭하면 "누르고 있는 동안" 신호가 오기 전에 손이 떨어진다. 그래도 눌림이 보이게 잠깐 켠다
@State private var tapFlash = false
private var down: Bool { pressed || tapFlash }

/// 0.12초 동안 확실히 눌렸다 올라온다. 아이패드는 진동이 없어서 화면으로 보여줘야 한다
private func flashPress() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    tapFlash = true
    Task {
        try? await Task.sleep(for: .milliseconds(120))
        tapFlash = false
    }
}
```

#### State와 Task.sleep으로 잠깐 눌림 보이기

[`@State`](https://developer.apple.com/documentation/swiftui/state){:target="_blank"}는 뷰가 스스로 들고 있는 값이고, 바뀌면 그 뷰를 다시 그린다. `flashPress()`는 [`UIImpactFeedbackGenerator`](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator){:target="_blank"}로 짧게 진동한 뒤(`.light`처럼 세기를 고른다, 아이패드에서는 아무 일도 없다) `tapFlash`를 켜고, [`Task.sleep(for:)`](https://developer.apple.com/documentation/swift/task/sleep%28for:tolerance:clock:%29){:target="_blank"}으로 0.12초 기다렸다가 끈다. `Task.sleep`은 스레드를 막지 않고 그 작업만 쉰다.

눌린 것과 맥에서 실제로 실행된 것은 다르다. 처음엔 실패할 때만 빨간 테두리를 띄웠는데, 그러면 아무 표시가 없을 때 "된 건가?" 싶다. 그래서 맥이 "실행했음"을 돌려주면 그 버튼 테두리가 버튼 종류 색(앱 파랑, 명령 초록, 새 터미널 주황)으로 0.7초 동안 빛나게 했다. 명령 버튼은 실행 전 확인에 1초쯤 걸려서, 눌림이 먼저 보이고 조금 뒤에 테두리가 빛난다.

---

## 한 버튼에 담은 탭과 길게 누르기

버튼은 짧게 누르면 맥에서 실행하고, 길게 누르면 편집 화면을 띄워야 한다. 거기에 손가락이 닿아 있는 동안 키캡이 눌려 들어가 있어야 한다. 그래서 SwiftUI `Button` 대신 일반 뷰에 탭과 길게 누르기를 따로 붙이고, 누르고 있는 상태를 길게 누르기 쪽에서 받아 왔다.

---

### 탭과 길게 누르기는 어떻게 갈리나

화면은 손가락이 닿은 순간, 움직이는 동안, 떨어진 순간을 앱에 알려 줄 뿐이다. 이게 탭인지 길게 누르기인지는 제스처라는 판단 장치가 시간과 움직임을 보고 정한다. 길게 누르기는 "정해 둔 시간(여기서는 0.45초)이 지날 때까지 손가락이 크게 움직이지 않고 닿아 있으면 성공"이다. 그 전에 손을 떼면 길게 누르기는 실패하고, 탭이 성공한다.

![0.45초 전에 손을 떼면 탭이 되어 맥에서 실행하고, 0.45초가 지나도 닿아 있으면 길게 누르기가 되어 편집 화면이 뜬다. 손가락이 닿아 있는 동안은 키캡이 눌려 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-tap-longpress.png)

두 제스처는 같은 손가락 하나를 두고 서로 경쟁한다. 그래서 한 버튼에 둘을 같이 붙여도, 시간으로 갈려서 둘 중 하나만 실행된다.

```swift
// ButtonTile.swift (iOS)
.contentShape(.rect)
.onTapGesture { button == nil ? onEdit() : onTap() }
.onLongPressGesture(minimumDuration: 0.45) {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    onEdit()
} onPressingChanged: { pressed = $0 }
```

#### 한 버튼에 탭과 길게 누르기 붙이기

[`contentShape(_:eoFill:)`](https://developer.apple.com/documentation/swiftui/view/contentshape%28%5F:eofill:%29){:target="_blank"}는 눌리는 범위를 정한다. `.rect`면 투명한 부분까지 사각형 전체가 눌린다. 그 위에 [`onTapGesture`](https://developer.apple.com/documentation/swiftui/view/ontapgesture%28count:perform:%29){:target="_blank"}로 탭을, [`onLongPressGesture(minimumDuration:…)`](https://developer.apple.com/documentation/swiftui/view/onlongpressgesture%28minimumduration:maximumdistance:perform:onpressingchanged:%29){:target="_blank"}로 0.45초 길게 누르기를 붙였다. 길게 누르기의 `onPressingChanged`는 손가락이 닿을 때 true, 뗄 때 false로 불린다.

`onLongPressGesture`의 `onPressingChanged`는 손가락이 닿아 있는 동안 `true`, 떨어지면 `false`를 알려 준다. 이걸 키캡이 눌려 들어가는 `pressed` 값으로 그대로 썼다. 짧게 눌렀다 떼면 이 값이 잠깐 `true`였다가 돌아오면서 키가 들어갔다 나오고, 탭 동작이 실행된다. 0.45초 넘게 누르고 있으면 진동과 함께 편집 화면이 뜬다.

---

### VoiceOver란?

VoiceOver는 화면을 보지 않고도 쓸 수 있게 화면에 있는 것을 소리 내어 읽어 주는 iOS 기능이다. 손가락으로 훑으면 그 자리의 요소를 읽고, 두 번 탭하면 누른다. 읽을 거리는 앱이 붙여 둔 접근성 정보에서 가져온다. 이름(Label), 종류(버튼인지 글자인지), 도움말(Hint), 그리고 따로 고를 수 있는 동작이다.

![Safari 버튼을 VoiceOver가 Safari, 버튼이라고 읽고 잠깐 뒤 맥에서 실행이라고 읽는다. 위아래로 쓸면 편집 동작을 고를 수 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-voiceover.png)

`Button`을 안 쓰니 VoiceOver가 이걸 버튼으로 모른다. 그래서 접근성 정보를 직접 붙였다. 편집은 VoiceOver의 동작 목록에 "편집"으로 들어간다.

```swift
// ButtonTile.swift (iOS)
.accessibilityElement(children: .ignore)
.accessibilityLabel(button?.label ?? "빈 칸")
.accessibilityHint(button == nil ? "버튼 추가" : "맥에서 실행")
.accessibilityAddTraits(.isButton)
.accessibilityAction(named: "편집", onEdit)
```

#### VoiceOver에 읽힐 정보 붙이기

`Button`이 아닌 뷰를 VoiceOver가 버튼처럼 다루도록 접근성 modifier를 붙였다.

| API | 하는 일 |
|---|---|
| [`accessibilityElement(children:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityelement%28children:%29){:target="_blank"} | 안의 여러 뷰를 하나로 묶어 읽게 한다. `.ignore`는 안쪽 글자를 따로 읽지 않는다 |
| [`accessibilityLabel(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilitylabel%28%5F:%29){:target="_blank"} | 읽을 이름 |
| [`accessibilityHint(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityhint%28%5F:%29){:target="_blank"} | 이름 뒤에 잠깐 쉬고 읽는 도움말(누르면 무슨 일이 생기는지) |
| [`accessibilityAddTraits(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityaddtraits%28%5F:%29){:target="_blank"} | 종류 표시. `.isButton`을 붙이면 "버튼"이라고 읽고 두 번 탭으로 누를 수 있다 |
| [`accessibilityAction(named:_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityaction%28named:%5F:%29){:target="_blank"} | 동작 목록에 이름 붙은 동작을 더한다. 위아래로 쓸어 고른다 |

이 이름표 덕분에 화면 캡처를 UI 테스트로 찍을 때도 좌표 대신 "빈 칸", "Safari" 같은 이름으로 버튼을 찾아 누를 수 있었다.

---

## 편집 화면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-edit-existing.png)

버튼을 길게 누르면 뜨는 편집 화면이다. 위에서 종류(앱 / 명령어 / 새 터미널)를 고르면 아래 입력칸이 바뀐다. 이미 있는 버튼이면 아래에 삭제가 있다. 저장하면 아이패드는 자기 화면을 바로 고치지 않고 맥에 "이 칸을 이 버튼으로" 요청만 보낸다. 맥이 설정을 저장하고 바뀐 배치를 붙어 있는 모든 기기에 다시 보내면, 그걸 받아서 화면이 바뀐다. 아이패드와 아이폰이 같이 붙어 있어도 둘이 항상 같은 배치를 보여준다.

명령어 입력 화면을 처음 찍었을 때는 한글 자판이 떴다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-edit-command.png)

명령과 폴더 경로는 영문이라 매번 자판을 바꿔야 한다. 이 두 칸에 `.keyboardType(.asciiCapable)`을 넣어서 영문 자판이 바로 뜨게 했다. 자동 대문자와 자동 고침도 껐다. `blogrun`이 `Blogrun`이 되면 별칭을 못 찾는다.

```swift
// EditSheet.swift (iOS)
TextField("명령 (예: blogrun)", text: $command)
    .font(.body.monospaced())
    .keyboardType(.asciiCapable)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
```

#### TextField 입력 옵션

[`TextField`](https://developer.apple.com/documentation/swiftui/textfield){:target="_blank"}는 한 줄 입력칸이다. 첫 글자는 빈칸일 때 흐리게 보이는 안내 글이고, `text:`에 묶은 값이 친 글자다. 명령 칸에 붙인 옵션은 이렇다.

| API | 하는 일 |
|---|---|
| [`monospaced()`](https://developer.apple.com/documentation/swiftui/font/monospaced%28%29){:target="_blank"} | 모든 글자 폭이 같은 고정폭 글꼴 |
| [`keyboardType(_:)`](https://developer.apple.com/documentation/swiftui/view/keyboardtype%28%5F:%29){:target="_blank"} | 뜨는 키보드 종류. [`.asciiCapable`](https://developer.apple.com/documentation/uikit/uikeyboardtype/asciicapable){:target="_blank"}은 영문 자판이 바로 뜬다 |
| [`textInputAutocapitalization(_:)`](https://developer.apple.com/documentation/swiftui/view/textinputautocapitalization%28%5F:%29){:target="_blank"} | 첫 글자 자동 대문자. `.never`로 껐다 |
| [`autocorrectionDisabled(_:)`](https://developer.apple.com/documentation/swiftui/view/autocorrectiondisabled%28%5F:%29){:target="_blank"} | 자동 고침을 끈다 |

---

### 화면에 보이는 줄만 만드는 목록

앱 고르기 목록은 `Form` 안의 줄들이라 화면에 보이는 줄만 만들어진다. 줄이 150개라도 화면에 보이는 열 줄 남짓만 실제로 그리고, 스크롤해서 보일 때가 되면 그제야 만든다. 안 보이는 줄까지 한꺼번에 만들면 목록을 여는 데 오래 걸리고 메모리도 많이 쓰기 때문이다.

![150개 넘는 앱 목록 중 화면에 보이는 줄만 만들어지고, 아래쪽 Safari 같은 줄은 스크롤하거나 검색하기 전까지 아직 없다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-lazy-list.png)
 150개가 넘는 앱 중에 아래쪽에 있는 Safari는 스크롤하거나 검색하기 전까지 아직 만들어지지 않은 상태다. 그래서 UI 테스트에서 Safari를 바로 찾으려다 "앱 목록에 Safari 없음"으로 실패했고, 검색어를 먼저 넣고 찾게 테스트 순서를 바꿨다. 실제로 쓸 때도 검색부터 하는 게 빨라서 검색칸을 목록 위에 뒀다.

처음 검색칸은 이름 칸 아래, 목록 사이에 그냥 글자 칸으로 들어가 있었다. 써 보니 검색하는 칸처럼 보이지 않았고, 목록을 내리면 같이 위로 사라졌다. 그래서 목록 밖 맨 위에 고정된 검색창으로 바꿨다. 돋보기와 지우기 버튼이 있고, 키보드에는 "검색" 키가 뜬다. 결과가 하나뿐이면 그 키만 눌러도 그 앱이 골라진다. 칠 때마다 목록이 줄어들고, 맞는 글자는 파랗게 굵게 보이고, 위에 "검색 결과 3개"처럼 개수가 나온다.

---

### 초성으로 찾기와 한글 음절 번호

맥 언어가 한국어라 앱 이름이 "메모"로 오는데, 가끔은 notes로 찾고 싶다. 초성(ㅁㅁ)으로도 찾고 싶었다. 그래서 검색 규칙을 공용 코드에 따로 두고 테스트로 먼저 정했다. 이름 앞에서 맞는 것, 이름 가운데서 맞는 것, 초성으로 맞는 것, bundle ID(`com.apple.Notes`)로 맞는 것 순서로 보여준다.

```swift
// AppSearch.swift (DeckKit)
private static func rank(_ app: AppInfo, _ q: String) -> Int? {
    let name = app.name.lowercased()
    if name.hasPrefix(q) { return 0 }
    if name.contains(q) { return 1 }
    if q.allSatisfy({ initials.contains($0) }), choseong(app.name).contains(q) { return 2 }
    if app.bundleId.lowercased().contains(q) { return 3 }
    return nil
}

/// "미리보기" → "ㅁㄹㅂㄱ". 한글 음절이 아닌 글자는 그대로 둔다.
static func choseong(_ text: String) -> String {
    String(text.map { ch -> Character in
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1,
              (0xAC00...0xD7A3).contains(scalar.value) else { return ch }
        return initials[Int(scalar.value - 0xAC00) / 588]
    })
}
```

#### 검색에 쓴 글자 함수

이름은 [`lowercased()`](https://developer.apple.com/documentation/swift/string/lowercased%28%29){:target="_blank"}로 모두 소문자로 바꿔 대소문자 상관없이 비교한다. [`hasPrefix(_:)`](https://developer.apple.com/documentation/swift/string/hasprefix%28%5F:%29){:target="_blank"}는 그 글자로 시작하는지, `contains(_:)`는 어디든 들어 있는지 본다. 친 글자가 전부 초성인지는 [`allSatisfy(_:)`](https://developer.apple.com/documentation/swift/sequence/allsatisfy%28%5F:%29){:target="_blank"}(모든 요소가 조건에 맞는지)로 확인했다. 초성 계산은 [`unicodeScalars`](https://developer.apple.com/documentation/swift/string/unicodescalars){:target="_blank"}로 글자를 유니코드 번호(`Unicode.Scalar`) 단위로 보고, `.value`로 그 번호(UInt32)를 꺼냈다.

한글 음절은 유니코드에서 가(0xAC00)부터 순서대로 놓여 있고, 첫소리 하나마다 588개(가운뎃소리 21 × 끝소리 28)씩 묶여 있다. 그래서 (글자 번호 − 0xAC00) ÷ 588을 하면 첫소리 순번이 나온다.

![한글 음절은 가(0xAC00)부터 첫소리마다 588자씩 묶여 있어서, 메(0xBA54)는 (0xBA54 - 0xAC00) ÷ 588 = 6.2를 버림해 6번 묶음, ㅁ이 된다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-hangul.png)

컴퓨터 안에서 글자는 모두 번호로 저장된다. 이 번호표가 유니코드이고, 한글은 가부터 힣까지 11,172자가 순서대로 붙어 있다. 순서가 규칙적이라서 표를 따로 들고 있지 않아도 나눗셈 한 번으로 첫소리를 구할 수 있다.

```swift
// AppSearchTests.swift (DeckKit)
@Test func initialConsonantsMatch() {
    // 초성만 쳐도 찾아진다: ㅁㅁ → 메모, ㅁㄹ → 미리보기
    #expect(names("ㅁㅁ") == ["메모"])
    #expect(names("ㅁㄹ") == ["미리보기"])
}

@Test func englishNameInBundleIdMatches() {
    // 맥 언어가 한국어라 이름은 "메모"지만 notes로도 찾고 싶다
    #expect(names("notes") == ["메모"])
    #expect(names("SAF") == ["Safari"])
}
```

처음엔 새 앱 버튼을 추가할 때 바로 칠 수 있게 검색창에 커서를 미리 넣어 뒀다. 그런데 편집 화면이 열리자마자 키보드가 올라와 목록을 가렸다. 검색 없이 목록에서 바로 고를 때도 많아서, 검색창은 직접 누를 때만 커서가 가게 바꿨다.

---

## 사본 없이 맥 하나만 보는 구조

아이폰과 아이패드를 같이 쓰면 둘이 서로 다른 버튼을 보여주지 않을까 걱정됐다. 이걸 맞추려고 따로 한 일은 없다. 처음부터 버튼 배치를 맥의 설정 파일 한 곳에만 두기로 했기 때문이다.

---

### 원본을 한 곳에만 둔다는 것

같은 정보를 여러 곳에 저장해 두면, 한 곳만 바뀌었을 때 어느 쪽이 맞는지 따져야 한다. 원본을 한 곳에만 두고 나머지는 그걸 받아서 보여 주기만 하면 이런 일이 생기지 않는다. 이걸 흔히 "원본은 하나(single source of truth)"라고 부른다.

![기기마다 사본을 두면 아이패드는 5번 칸이 Safari, 아이폰은 Xcode처럼 서로 달라질 수 있다. 맥 한 곳에만 원본을 두면 아이패드와 아이폰은 같은 원본을 받아 그리기만 한다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-single-source.png)

기기에는 사본이 아예 없다. 아이폰과 아이패드는 맥이 보내 준 배치를 메모리에 들고 화면에 그리기만 하고, 파일로 저장하지 않는다. 앱을 껐다 켜면 맥에 다시 붙어서 받아 온다. 버튼을 고칠 때도 자기 화면을 먼저 바꾸지 않고 맥에 요청만 보낸다. 맥은 설정을 고쳐 저장한 다음, 붙어 있는 모든 기기에 바뀐 배치를 다시 보낸다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-sync.png)

아이패드에서 버튼을 바꿔도, 요청을 보내지 않은 아이폰까지 같은 새 배치를 받는다.

```swift
// DeckServer.swift (맥)
private func editLayout(_ session: ClientSession, _ edit: (inout DeckLayout) throws -> Void) {
    do {
        try edit(&config.layout)
        try store.save(config)
    } catch {
        print("[server] edit failed:", error)
    }
    broadcast(.layout(config.layout))
}

private func broadcast(_ message: ServerMessage) {
    for session in sessions where session.stage == .authorized {
        session.send(message)
    }
}
```

#### inout으로 원본 고치기

[`inout`](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/functions/#In-Out-Parameters){:target="_blank"}은 함수가 받은 값을 고치면 부른 쪽 원본도 바뀌게 하는 표시다. 부를 때 `&config.layout`처럼 `&`를 붙인다.

```swift
// DeckClient.swift (iOS)
case .layout(let layout):
    self.layout = layout
```

그래서 기기끼리 서로 다른 값을 들고 맞춰야 하는 일이 생기지 않는다. 아이폰과 아이패드가 거의 동시에 버튼을 고쳐도, 맥은 메시지를 하나씩 받은 순서대로 처리하고 그 결과를 모두에게 보낸다. 같은 칸을 둘이 고치면 나중에 도착한 쪽이 남는다. 웹 서비스로 치면 서버 데이터베이스 하나에 여러 기기가 붙어서 보는 것과 같은 모양이고, 여기서는 맥이 그 서버다. 볼륨 값도 같은 방식이라 두 기기의 게이지가 같이 움직인다.

단점도 있다. 맥이 꺼져 있으면 버튼을 고칠 수 없다. 연결이 끊긴 동안에는 마지막으로 받은 배치가 흐리게 남아 있지만 누를 수 없고, 그 상태에서 앱을 껐다 켜면 맥에 붙기 전까지 빈 화면이다. 그래도 괜찮다고 봤다. 맥이 꺼져 있으면 버튼을 눌러도 실행할 곳이 없어서다.

여러 기기가 데이터를 나눠 쓴다고 하면 App Group이 먼저 떠오르는데, App Group은 한 기기 안에서 앱과 위젯처럼 여러 앱이 같은 저장 공간을 쓰게 하는 기능이다. 아이폰과 아이패드처럼 서로 다른 기기 사이에는 효과가 없다.

허락(페어링)은 기기마다 따로 받는다. 아이폰과 아이패드가 각자 자기 토큰을 갖고, 맥 메뉴의 "허락한 기기" 목록에도 따로 보인다. 그래서 아이폰만 허락을 취소하는 것도 된다. 나중에 ESP32 보드를 붙여도 맥에 붙어서 배치를 받기만 하면 되니 똑같이 맞춰진다.

---

## 빈 페이지가 하나 남는 규칙

한 페이지는 12칸이고, 다 차면 옆으로 넘겨서 다음 페이지에 넣는다. 그러려면 "다음 페이지"가 항상 있어야 한다. 그래서 배치에 규칙을 하나 정했다. 마지막 페이지에 버튼이 하나라도 있으면 끝에 빈 페이지를 하나 붙이고, 끝에 빈 페이지가 두 개 이상이면 하나만 남긴다. 버튼을 넣거나 지울 때마다 이 규칙을 다시 맞춘다.

```swift
// DeckLayout.swift (DeckKit)
/// 끝에는 항상 빈 페이지가 정확히 하나 있다 (다음 버튼을 넣을 자리).
/// 단, 버튼이 하나도 없으면 빈 페이지 하나만 남는다.
private mutating func normalize() {
    while pages.count > 1, pages[pages.count - 1].isEmpty, pages[pages.count - 2].isEmpty {
        pages.removeLast()
    }
    if let last = pages.last, !last.isEmpty {
        pages.append(DeckPage())
    }
}
```

이 규칙은 맥과 아이패드가 같이 쓰는 코드(DeckKit)에 있고, 테스트로 먼저 정했다.

```swift
// DeckLayoutTests.swift (DeckKit)
@Test func settingOnLastPageAppendsEmptyPage() throws {
    var l = DeckLayout.empty
    try l.set(DeckButton(label: "Xcode", action: .app(bundleId: "com.apple.dt.Xcode")), page: 0, index: 3)
    #expect(l.pages.count == 2)
    #expect(l.pages[0].buttons[3]?.label == "Xcode")
}

@Test func clearingTrimsTrailingEmptyPages() throws {
    var l = DeckLayout.empty
    try l.set(DeckButton(label: "a", action: .terminal(directory: nil)), page: 0, index: 0)
    try l.set(DeckButton(label: "b", action: .terminal(directory: nil)), page: 1, index: 0)
    try l.clear(page: 1, index: 0)
    #expect(l.pages.count == 2)
}
```

페이지 넘기기는 `TabView`의 [`.page`](https://developer.apple.com/documentation/swiftui/tabviewstyle/page){:target="_blank"} 스타일을 썼고, 기본 점 표시는 끄고 버튼 격자 아래에 작은 점을 직접 그렸다. 볼륨 슬라이더는 `TabView` 밖에 있어서 페이지를 넘겨도 그대로 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-page2.png)

12칸을 다 채우고 13번째 버튼을 넣으니 2페이지가 생기고, 그 뒤에 빈 3페이지가 하나 붙었다(아래 점 세 개).

---

## 아이폰의 3×4 배치

아이폰은 같은 앱이고, 세로로 들고 쓰니 3열 4줄로 바뀌고 볼륨 슬라이더가 아래로 눕는다. 한 페이지 12칸이라는 데이터는 같아서 칸 번호도 아이패드와 똑같다. 아이패드에서 5번 칸에 넣은 버튼은 아이폰에서도 5번 칸에 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-iphone.png)

책상 위에 세워 두는 기기라 앱이 켜져 있는 동안은 화면이 꺼지지 않게 `isIdleTimerDisabled`를 켰고, 상태 표시줄도 숨겼다.

---

## 키캡 네 개로 만든 앱 아이콘

아이콘도 화면과 같은 느낌으로 그렸다. 그래파이트 바탕에 키캡 네 개를 놓고, 각 키에 버튼 종류 색의 점(앱 파랑, 명령 초록, 새 터미널 주황, 볼륨 보라)과 그 종류를 나타내는 그림을 넣었다. 오른쪽 아래 볼륨 키만 아랫단이 안 보이게 눌린 모양으로 해서 누르는 기기라는 게 보이게 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-app-icon.png)

SVG로 그리고 1024×1024 PNG로 바꿨다. 아이패드는 이 그림 한 장을 넣으면 시스템이 모서리를 둥글게 잘라 준다. 맥은 다르다. macOS 26부터는 아이콘이 둥근 사각형 틀에 맞지 않으면 회색 틀 안에 작게 갇혀 보여서, 1024 캔버스 안에 824 크기의 둥근 사각형으로 줄이고 바깥은 투명하게 둔 맥용 그림을 따로 만들었다. 맥 앱은 메뉴바에만 떠서 아이콘이 잘 안 보이지만, 시스템 설정의 손쉬운 사용 목록 같은 곳에 이 아이콘이 나온다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-home-icon.png)

---

## 참고자료

- [XCUIElement (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuielement){:target="_blank"}
- [XCUIElement.press(forDuration:) (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuielement/press%28forduration:%29){:target="_blank"}
- [XCUIDevice.orientation (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/orientation){:target="_blank"}
- [App Groups 권한 (com.apple.security.application-groups, Apple)](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups){:target="_blank"}
