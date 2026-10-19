---
title: StreamDeck (4) 키캡처럼 눌리는 버튼, 길게 눌러 편집하기, 옆으로 넘기는 페이지
writer: Harold
date: 2026-10-19 18:30:00 +0900
categories: [StreamDeck]
tags: [SwiftUI, Gesture, TabView]

toc: true
toc_sticky: true
published: true
---

아이패드 화면 배치는 시안 세 개를 놓고 골랐다. 버튼만 5×3으로 꽉 채운 안, 가로로 놓고 4×3 버튼 옆에 세로 볼륨 슬라이더를 붙인 안, 세로로 세우고 3×4 버튼 아래에 가로 슬라이더를 둔 안이었다. 아이패드가 모니터 옆에 가로로 놓여 있고 소리 크기는 쓸어 올리는 게 편할 것 같아서 두 번째(B안)로 정했다. 이번 글은 이 화면과 버튼 편집이다.

---

## 가로 4×3과 볼륨 페이더

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-4/touchdeck-page1.png)

(오른쪽 볼륨 슬라이더는 나중에 실제 값만큼 차오르는 게이지와 음소거 키로 바뀌었다. 모니터 소리 값을 BetterDisplay로 읽는 과정은 3편에 적었다.)

색은 버튼 종류를 구분하는 데만 썼다. 키캡 왼쪽 위의 작은 점이 앱은 파랑, 명령어는 초록, 새 터미널은 주황이고, 볼륨 슬라이더는 보라다. 바탕은 순검정 대신 아노다이징한 금속 같은 회색(`#2A2D33`)으로 했다. 나중에 ESP32 보드로 바뀔 물건이라 화면 속 버튼도 진짜 키보드 키처럼 보이게 하고 싶었다. 키 이름은 둥근 글꼴(SF Pro Rounded)로 키캡 각인 느낌을 냈고, 명령 글자는 실제로 코드라서 고정폭 글꼴로 따로 작게 적었다.

화면 전체는 스크롤되지 않는다. `GeometryReader`로 화면 크기를 받아서 가로가 더 길면 B안, 세로가 더 길면 3열 배치로 그린다. 버튼 크기는 남은 공간을 칸 수로 나눠 정해진다.

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

키 크기(`side`)에 비례해서 아랫단 두께와 모서리 둥글기를 정했다. 아이패드에서 키가 커지든 아이폰에서 작아지든 같은 비율로 보인다. 누르는 동안 종류 점의 빛도 살짝 퍼지게 했다.

빈 칸은 키캡이 빠진 자리처럼 점선 홈으로 그렸다. 누르면 버튼 추가 화면이 뜬다.

---

## 한 버튼에 담은 탭과 길게 누르기

버튼은 짧게 누르면 맥에서 실행하고, 길게 누르면 편집 화면을 띄워야 한다. 거기에 손가락이 닿아 있는 동안 키캡이 눌려 들어가 있어야 한다. 그래서 SwiftUI `Button` 대신 일반 뷰에 탭과 길게 누르기를 따로 붙이고, 누르고 있는 상태를 길게 누르기 쪽에서 받아 왔다.

```swift
// ButtonTile.swift (iOS)
.contentShape(.rect)
.onTapGesture { button == nil ? onEdit() : onTap() }
.onLongPressGesture(minimumDuration: 0.45) {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    onEdit()
} onPressingChanged: { pressed = $0 }
```

`onLongPressGesture`의 `onPressingChanged`는 손가락이 닿아 있는 동안 `true`, 떨어지면 `false`를 알려 준다. 이걸 키캡이 눌려 들어가는 `pressed` 값으로 그대로 썼다. 짧게 눌렀다 떼면 이 값이 잠깐 `true`였다가 돌아오면서 키가 들어갔다 나오고, 탭 동작이 실행된다. 0.45초 넘게 누르고 있으면 진동과 함께 편집 화면이 뜬다.

`Button`을 안 쓰니 VoiceOver가 이걸 버튼으로 모른다. 그래서 접근성 정보를 직접 붙였다. 편집은 VoiceOver의 동작 목록에 "편집"으로 들어간다.

```swift
// ButtonTile.swift (iOS)
.accessibilityElement(children: .ignore)
.accessibilityLabel(button?.label ?? "빈 칸")
.accessibilityHint(button == nil ? "버튼 추가" : "맥에서 실행")
.accessibilityAddTraits(.isButton)
.accessibilityAction(named: "편집", onEdit)
```

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

앱 고르기 목록은 `Form` 안의 줄들이라 화면에 보이는 줄만 만들어진다. 150개가 넘는 앱 중에 아래쪽에 있는 Safari는 스크롤하거나 검색하기 전까지 아직 만들어지지 않은 상태다. 그래서 UI 테스트에서 Safari를 바로 찾으려다 "앱 목록에 Safari 없음"으로 실패했고, 검색어를 먼저 넣고 찾게 테스트 순서를 바꿨다. 실제로 쓸 때도 검색부터 하는 게 빨라서 검색칸을 목록 위에 뒀다.

처음 검색칸은 이름 칸 아래, 목록 사이에 그냥 글자 칸으로 들어가 있었다. 써 보니 검색하는 칸처럼 보이지 않았고, 목록을 내리면 같이 위로 사라졌다. 그래서 목록 밖 맨 위에 고정된 검색창으로 바꿨다. 돋보기와 지우기 버튼이 있고, 키보드에는 "검색" 키가 뜬다. 결과가 하나뿐이면 그 키만 눌러도 그 앱이 골라진다. 칠 때마다 목록이 줄어들고, 맞는 글자는 파랗게 굵게 보이고, 위에 "검색 결과 3개"처럼 개수가 나온다.

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

한글 음절은 유니코드에서 가(0xAC00)부터 순서대로 놓여 있고, 첫소리 하나마다 588개(가운뎃소리 21 × 끝소리 28)씩 묶여 있다. 그래서 (글자 번호 − 0xAC00) ÷ 588을 하면 첫소리 순번이 나온다.

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

페이지 넘기기는 `TabView`의 `.page` 스타일을 썼고, 기본 점 표시는 끄고 버튼 격자 아래에 작은 점을 직접 그렸다. 볼륨 슬라이더는 `TabView` 밖에 있어서 페이지를 넘겨도 그대로 있다.

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

- [onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:) (Apple)](https://developer.apple.com/documentation/swiftui/view/onlongpressgesture(minimumduration:maximumdistance:perform:onpressingchanged:))
- [TabViewStyle.page (Apple)](https://developer.apple.com/documentation/swiftui/tabviewstyle/page)
- [UIKeyboardType.asciiCapable (Apple)](https://developer.apple.com/documentation/uikit/uikeyboardtype/asciicapable)
- [XCUIElement (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuielement)
- [XCUIElement.press(forDuration:) (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuielement/press(forduration:))
- [XCUIDevice.orientation (Apple)](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/orientation)
