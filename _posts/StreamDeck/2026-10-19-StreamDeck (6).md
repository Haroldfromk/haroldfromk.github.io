---
title: StreamDeck (6) 무각 키보드 대신 쓰는 아이패드 숫자 키패드, 그리고 메시지 암호화
writer: Harold
date: 2026-10-19 18:50:00 +0900
last_modified_at: 2026-10-20 00:18:00 +0900
categories: [StreamDeck]
tags: [CGEvent, CryptoKit, ChaChaPoly, SwiftUI]

toc: true
toc_sticky: true
published: true
---

가끔 해피해킹 키보드를 쓰는데, 무각이라 숫자를 칠 때 손으로 위치를 더듬어야 해서 불편했다. 특히 로그인할 때나 비밀번호에 숫자를 넣을 때가 그렇다. 그래서 아이패드 화면을 스트림덱과 숫자 키패드 사이에서 바꿔 쓸 수 있게 했다. 키패드를 누르면 맥에서 지금 앞에 떠 있는 앱에 그 키를 누른 것처럼 입력된다.

비밀번호 숫자가 오가는 기능이라 만들기 전에 정한 게 있다. 친 숫자가 와이파이로 그대로 보이면 안 되고, 맥 로그나 아이패드 화면 어디에도 남으면 안 된다. 비밀번호를 저장하거나 자동으로 채우는 기능은 넣지 않고, 누른 키를 그대로 보내기만 한다.

---

## 스트림덱과 바꿔 쓰는 키패드 화면

상태 줄 옆에 "스트림덱 / 숫자 키패드" 전환을 두고, 마지막에 고른 화면을 `@AppStorage`로 기억하게 했다. 오른쪽 볼륨 게이지는 어느 화면이든 그대로 있다.

```swift
// DeckView.swift (iOS)
@AppStorage("screen") private var screen = Screen.deck

enum Screen: String, CaseIterable {
    case deck = "스트림덱"
    case keypad = "숫자 키패드"
}
```

키패드는 전화기처럼 3×4로 놓고 아래에 넓은 Enter를 뒀다. 마지막 줄의 Tab은 아이디 칸에서 비밀번호 칸으로 넘어갈 때 쓰고, 오른쪽은 지우기다. 키 크기는 남은 공간에 3열, 5줄이 다 들어가는 가장 큰 정사각형으로 정했다. 화면 전체는 스크롤되지 않는다.

```swift
// KeypadView.swift (iOS)
private let rows: [[TypedKey]] = [
    [.digit(7), .digit(8), .digit(9)],
    [.digit(4), .digit(5), .digit(6)],
    [.digit(1), .digit(2), .digit(3)],
    [.tab, .digit(0), .delete],
]

var body: some View {
    GeometryReader { geo in
        let spacing: CGFloat = 14
        // 3열, 숫자 4줄 + Enter 1줄이 화면에 다 들어가는 가장 큰 정사각형 키
        let side = min((geo.size.width - spacing * 2) / 3, (geo.size.height - spacing * 4) / 5)
        // 생략 (키 격자와 Enter)
    }
}
```

키 모양과 눌림, 진동은 스트림덱 버튼과 똑같이 했다. 친 숫자는 화면 어디에도 표시하지 않는다. 옆에서 아이패드를 보는 사람이 있을 수도 있어서다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-6/touchdeck-keypad.png)

실제 아이패드에서 키패드를 고른 모습이다. 오른쪽은 3편의 볼륨 게이지로, LG 모니터 소리가 7일 때라 아래쪽만 조금 차 있다.

---

## 맥에서 키를 누른 것과 같은 입력

키패드의 키는 메시지 하나로 간다. 볼륨 키처럼 종류만 보낸다.

```json
{ "type": "typeKey", "key": "7" }
{ "type": "typeKey", "key": "enter" }
```

맥은 이걸 받아서 키보드 이벤트를 만든다. 볼륨 키는 "시스템 정의 이벤트"였지만 숫자는 일반 키라서 `CGEvent(keyboardEventSource:virtualKey:keyDown:)`로 누름과 뗌을 만든다. 볼륨 키 때문에 이미 받아 둔 손쉬운 사용 권한을 그대로 쓴다.

```swift
// KeyTyper.swift (맥)
/// 맥 키보드의 키 번호. 숫자는 윗줄 숫자 키라 한글 입력 상태여도 숫자가 들어간다.
static func keyCode(for key: TypedKey) -> CGKeyCode? {
    switch key {
    case .digit(let d):
        let digits = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                      kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        return digits.indices.contains(d) ? CGKeyCode(digits[d]) : nil
    case .tab: return CGKeyCode(kVK_Tab)
    case .delete: return CGKeyCode(kVK_Delete)
    case .enter: return CGKeyCode(kVK_Return)
    }
}

/// 누르고 떼기를 한 번. 권한이 없거나 모르는 키면 false
static func type(_ key: TypedKey) -> Bool {
    guard MediaKey.allowed, let code = keyCode(for: key) else { return false }
    let source = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
        // 맥에서 Shift 같은 걸 누르고 있어도 키패드 키만 들어가게
        event?.flags = []
        event?.post(tap: .cghidEventTap)
    }
    return true
}
```

숫자를 키보드 오른쪽 숫자 키패드의 키 번호가 아니라 윗줄 숫자 키 번호로 보낸 건, 맥 키보드에 원래 있는 키라서 어느 앱이든 똑같이 받기 때문이다. 한글 입력 상태여도 윗줄 숫자 키는 숫자로 들어간다. 키 번호는 `Carbon.HIToolbox`에 이름(`kVK_ANSI_7` 같은)으로 들어 있어서 그 이름으로 테스트했다.

```swift
// KeyTyperTests.swift (맥)
@Test func digitsMapToTopRowKeys() {
    let expected = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                    kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
    for (digit, code) in expected.enumerated() {
        #expect(KeyTyper.keyCode(for: .digit(digit)) == CGKeyCode(code))
    }
}
```

맥 앱은 받은 메시지를 로그에 찍어 왔는데, 키패드 입력만은 찍지 않게 했다.

```swift
// DeckServer.swift (맥)
// 키패드로 친 키(비밀번호일 수 있다)는 로그에 남기지 않는다
if case .typeKey = message {} else {
    print("[server] <- (봉투)", text.prefix(220))
    print("[server] <- (암호 풀림)", session.deviceName ?? "?", body.prefix(200))
}
```

macOS는 일부 비밀번호 칸에서 다른 프로그램이 보낸 키 입력을 받지 않을 수 있다. 그런 칸이 실제로 있는지는 아직 확인 못 했다.

---

## 서명에서 암호화로 바뀐 봉투

5편에서 허락 뒤의 모든 메시지에 서명을 붙였다. 서명은 메시지를 바꾸거나 지어내는 걸 막지만 내용을 숨기지는 않는다. 봉투의 `body`는 누가 엿봐도 그대로 읽힌다. 버튼 누르기는 상관없지만 비밀번호 숫자는 다르다.

그래서 봉투를 ChaChaPoly 암호화로 바꿨다. ChaChaPoly는 암호화와 위조 확인을 한 번에 하는 방식이다. 키가 없으면 내용을 못 읽고, 한 글자라도 바뀌면 열리지 않는다. 키는 5편에서 만든 이번 접속 전용 키(방향별로 따로)를 그대로 쓴다. 메시지 번호는 암호화할 때 "같이 확인할 값"으로 넣어서, 번호만 바꿔 다시 보내도 열리지 않게 했다. CryptoKit에 `ChaChaPoly`가 있고, ESP32 쪽 Mbed TLS에도 `chachapoly.h`가 있다.

```swift
// SecureSession.swift (DeckKit)
public mutating func seal(_ body: String) -> String {
    sentSeq += 1
    let sealed = try? ChaChaPoly.seal(Data(body.utf8), using: sendKey, authenticating: Data("\(sentSeq)".utf8))
    let envelope = Envelope(seq: sentSeq, box: sealed?.combined.base64EncodedString() ?? "")
    // 생략 (JSON 글자로 바꾸기)
}

public mutating func open(_ text: String) throws -> String {
    guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(text.utf8)), envelope.type == "secure" else {
        throw OpenError.notSecure
    }
    guard let combined = Data(base64Encoded: envelope.box),
          let box = try? ChaChaPoly.SealedBox(combined: combined),
          let plain = try? ChaChaPoly.open(box, using: receiveKey, authenticating: Data("\(envelope.seq)".utf8)),
          let body = String(data: plain, encoding: .utf8) else {
        throw OpenError.badSignature
    }
    guard envelope.seq > receivedSeq else { throw OpenError.replayed }
    receivedSeq = envelope.seq
    return body
}
```

봉투는 이제 `{"box":"…","seq":2,"type":"secure"}` 모양이고, `box`에 무작위 nonce, 암호문, 확인용 값이 같이 들어 있다. 5편에서 만든 테스트(지어낸 봉투, 바꾼 봉투, 다시 보낸 봉투, 되돌려 보낸 봉투는 안 열린다)는 그대로 통과했고, 내용이 안 보이는지와 번호만 바꾼 봉투가 안 열리는지를 더했다.

```swift
// SecureSessionTests.swift (DeckKit)
@Test func sealedMessageHidesBody() throws {
    // 비밀번호 숫자가 와이파이로 그대로 보이면 안 된다. 봉투 안에 원래 글자가 없어야 한다
    var (ipad, _) = pair()
    let sealed = ipad.seal(#"{"key":"7","type":"typeKey"}"#)
    #expect(!sealed.contains("typeKey"))
    #expect(!sealed.contains("\"7\""))
    #expect(sealed.contains(#""type":"secure""#))
}

@Test func changedSeqIsRejected() throws {
    // 번호도 암호화에 묶여 있어서, 번호만 바꿔 다시 보내도 안 열린다
    var (ipad, mac) = pair()
    let sealed = ipad.seal(#"{"type":"getApps"}"#)
    _ = try mac.open(sealed)
    let bumped = sealed.replacingOccurrences(of: #""seq":1"#, with: #""seq":2"#)
    #expect(throws: SecureChannel.OpenError.badSignature) { try mac.open(bumped) }
}
```

봉투 모양이 바뀌어서 맥 앱과 아이패드 앱을 둘 다 새로 빌드해야 서로 알아듣는다. 토큰은 그대로라 페어링은 다시 하지 않아도 된다.

---

## 참고자료

- [CGEvent.init(keyboardEventSource:virtualKey:keyDown:) (Apple)](https://developer.apple.com/documentation/coregraphics/cgevent/init(keyboardeventsource:virtualkey:keydown:))
- [CGEvent.post(tap:) (Apple)](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:))
- [ChaChaPoly (CryptoKit, Apple)](https://developer.apple.com/documentation/cryptokit/chachapoly)
- [ChaChaPoly.seal(\_:using:nonce:authenticating:) (Apple)](https://developer.apple.com/documentation/cryptokit/chachapoly/seal(%5F:using:nonce:authenticating:))
- [RFC 8439: ChaCha20 and Poly1305](https://www.rfc-editor.org/rfc/rfc8439)
- [Mbed TLS chachapoly.h (ESP32 쪽)](https://github.com/Mbed-TLS/mbedtls/blob/v3.6.0/include/mbedtls/chachapoly.h)
- [AppStorage (Apple)](https://developer.apple.com/documentation/swiftui/appstorage)
