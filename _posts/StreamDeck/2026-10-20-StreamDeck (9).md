---
title: StreamDeck (9) 밖에서 맥에 붙기, Tailscale과 잠자기 막기
writer: Harold
date: 2026-10-20 21:00:00 +0900
categories: [StreamDeck]
tags: [Tailscale, Network, IOKit, Observation, SwiftUI]

toc: true
toc_sticky: true
published: true
---

8편까지는 집 와이파이 안에서만 썼다. 그런데 맥에 빌드나 클로드 코드 작업을 걸어 두고 나가면, 잘 돌고 있는지 밖에서 한번 보고 싶을 때가 있다. 그래서 집 밖에서도 아이패드와 아이폰이 맥에 붙게 만들었다. 밖에서 하고 싶은 일은 중요한 순서대로 화면 보기(진행 상황 확인), 글자 입력(엔터나 짧은 답), 버튼이다.

조건은 앞 편들과 같다. 새 인증이나 새 통로는 만들지 않는다. 밖에서도 5편의 허락과 6편의 봉투를 그대로 쓴다.

---

## 밖에서는 맥이 보이지 않는 이유

집에서는 Bonjour(1편)로 맥을 찾았다. 밖에서는 이게 안 된다. Bonjour는 같은 와이파이 안의 기기에게만 묻는 방식이라 공유기 바깥으로 나가지 않는다. 맥 주소를 직접 안다고 해도 붙을 수 없는데, 그건 공유기 때문이다.

---

### 사설 주소와 공유기란?

공유기는 집 안 기기마다 192.168로 시작하는 주소를 나눠 준다. 이런 주소를 사설 주소라고 한다. 집 안에서만 통하는 내선 번호와 같다. 인터넷 쪽에서 보이는 주소는 공유기가 가진 하나뿐이다. 회사 대표 번호 하나 뒤에 내선이 여러 개 있는 것과 비슷하다.

![집 와이파이 안의 맥과 아이패드는 192.168로 시작하는 사설 주소를 쓰고, 밖의 아이폰에게는 공유기 주소 하나만 보인다. 밖에서 먼저 걸어온 연결은 공유기가 안쪽 누구에게 줄지 몰라 버린다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-nat.png)

안에서 밖으로 먼저 건 연결은 공유기가 기억해 두었다가, 돌아오는 답을 그 기기에게 넘겨준다. 그런데 밖에서 먼저 걸어온 연결은 안쪽 누구에게 줄지 모르니 버린다. 그래서 밖의 아이폰은 집 맥에 먼저 말을 걸 수 없다.

---

### 밖에서 붙는 길 세 가지

밖에서 맥에 붙는 방법은 크게 세 가지다.

| 방법 | 하는 일 | 걸리는 점 |
|---|---|---|
| 공유기 포트 열기 | 공유기에 "52801번으로 오면 맥에게 줘"라고 적어 둔다 | 인터넷 전체에 맥 포트가 열린다. 집 주소가 바뀌면 따라가야 한다 |
| 중계 서버 | 맥과 아이폰이 둘 다 바깥 서버에 먼저 붙고, 서버가 사이에서 전해 준다 | 서버를 따로 돌리고 계정을 만들어야 한다 |
| 개인 VPN (Tailscale) | 맥과 아이폰을 하나의 사설망으로 묶는다 | 두 기기에 Tailscale 앱을 깔아야 한다 |

나 혼자 쓰는 앱이라 Tailscale을 골랐다. 앱 코드는 거의 그대로 두고, 두 기기에 Tailscale만 깔면 된다.

---

### VPN과 Tailscale이란?

VPN(가상 사설망)은 멀리 떨어진 기기들을 같은 사설망에 있는 것처럼 묶는 방법이다. Tailscale은 이걸 쉽게 해 주는 서비스다. 같은 계정으로 로그인한 기기마다 100으로 시작하는 주소를 하나씩 주고, 그 주소끼리는 어디에 있든 바로 붙게 해 준다. 오가는 데이터는 WireGuard라는 방식으로 암호화된다. 주소 대신 Tailscale이 기기에 붙인 이름(MagicDNS)으로도 부를 수 있다.

![맥은 100.80.12.3, 아이폰은 100.92.40.7처럼 Tailscale 주소를 받고, 서로의 100 주소로 바로 붙는다. 실제 데이터는 암호화된 채로 공유기와 인터넷, LTE를 지난다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-tailscale.png)

밖에서 먼저 온 연결을 공유기가 버리는 문제는 Tailscale이 알아서 푼다. 두 기기가 동시에 서로에게 연결을 걸어 공유기에 길을 내고, 그게 안 되면 Tailscale의 중계 서버를 거친다. 그 서버를 내가 돌릴 필요는 없다. 앱 입장에서는 맥 주소가 192.168 대신 100으로 바뀌었을 뿐이다.

---

## 먼저 Bonjour, 3초 뒤 주소로

아이패드는 이제 두 가지로 맥을 찾는다. 집에서는 지금처럼 Bonjour로 바로 붙어야 하고, 밖에서는 넣어 둔 주소로 붙어야 한다. 순서는 이렇게 정했다.

![Bonjour로 찾다가 찾으면 바로 붙고, 3초 동안 못 찾으면 ws://맥이름:52801/로 붙는다. 10초 안에 허락까지 못 가면 실패 안내를 띄우고, 끊기거나 실패하면 2초 뒤 처음부터 다시 한다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-connect-order.png)

1. 지금처럼 Bonjour로 찾는다.
2. 3초 안에 못 찾았고 넣어 둔 주소가 있으면 `ws://주소:52801/`로 붙는다. 1편에서 본 것처럼 `host:port`로는 WebSocket이 안 열려서 URL로 붙는다.
3. 주소로 붙어 있는 동안에는 Bonjour가 맥을 찾아도 바꾸지 않는다. 끊기면 1번부터 다시 한다.

로컬 네트워크 권한(1편)이 꺼져 있으면 Bonjour는 바로 막힌다. 이때는 3초를 기다리지 않고 주소로 간다. Tailscale 주소는 로컬 네트워크가 아니라서 이 권한과 상관이 없다.

이 판단은 DeckKit에 떼어 두고 테스트했다. 집에서 붙는 게 3초 느려지면 안 되니까, Bonjour가 찾았으면 기다린 시간과 상관없이 바로 Bonjour다.

```swift
public static func next(bonjourFound: Bool, waited: Double, remoteHost: String?, localNetworkDenied: Bool) -> ConnectStep {
    // 집에서는 기다리지 않고 바로 Bonjour
    if bonjourFound { return .useBonjour }
    // 로컬 네트워크 권한이 막혀도 Tailscale 주소는 상관없다
    if let remoteHost, waited >= wait || localNetworkDenied { return .useRemote(host: remoteHost) }
    return .keepSearching
}

@Test func bonjourFirstNoWait() {
    #expect(RemotePlan.next(bonjourFound: true, waited: 0, remoteHost: "mac", localNetworkDenied: false) == .useBonjour)
    #expect(RemotePlan.next(bonjourFound: false, waited: 1, remoteHost: "mac", localNetworkDenied: false) == .keepSearching)
}
```

---

### 사람이 친 주소 다듬기

"밖에서 붙기" 시트에 맥 주소를 넣는다. Tailscale이 맥에 붙인 이름이나 100으로 시작하는 주소다. 사람이 치는 값이라 앞에 `ws://`를 붙이거나 뒤에 포트를 붙여 넣기 쉽다. 그래서 저장하기 전에 다듬는다.

```swift
public static func clean(_ input: String) -> String? {
    var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    for scheme in ["ws://", "wss://", "http://", "https://"] where text.lowercased().hasPrefix(scheme) {
        text.removeFirst(scheme.count)
    }
    while text.hasSuffix("/") { text.removeLast() }
    if let colon = text.lastIndex(of: ":"), !text[text.index(after: colon)...].isEmpty,
       text[text.index(after: colon)...].allSatisfy(\.isNumber) {
        text = String(text[..<colon])
    }
    guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
    return text
}

public static func url(host: String) -> URL? {
    URL(string: "ws://\(host):\(port)/")
}
```

#### removeFirst와 hasSuffix로 앞뒤 떼기

앞뒤를 차례로 떼어 낸다. `trimmingCharacters`와 `lastIndex`는 3편, `lowercased()`와 `hasPrefix`, `allSatisfy`는 4편에 나왔다.

1. 앞뒤 공백을 지운다.
2. `lowercased()`로 소문자로 바꿔 본 글이 `ws://` 같은 앞부분으로 시작하면, [`removeFirst(_:)`](https://developer.apple.com/documentation/swift/rangereplaceablecollection/removefirst%28%5F:%29){:target="_blank"}로 그 길이만큼 앞 글자를 지운다. 대문자로 친 `WS://`도 이렇게 걸린다.
3. [`hasSuffix(_:)`](https://developer.apple.com/documentation/swift/stringprotocol/hassuffix%28%5F:%29){:target="_blank"}로 `/`로 끝나는지 보고, [`removeLast()`](https://developer.apple.com/documentation/swift/bidirectionalcollection/removelast%28%29){:target="_blank"}로 마지막 글자를 하나씩 지운다.
4. 마지막 `:` 뒤가 모두 숫자면 포트로 보고 뗀다. [`isNumber`](https://developer.apple.com/documentation/swift/character/isnumber){:target="_blank"}는 그 글자가 숫자인지다.
5. 남은 게 비었거나 빈칸이 섞였으면 nil을 돌려준다. [`isWhitespace`](https://developer.apple.com/documentation/swift/character/iswhitespace){:target="_blank"}는 띄어쓰기나 줄바꿈 같은 빈칸 글자인지다.

다듬은 주소는 [`URL(string:)`](https://developer.apple.com/documentation/foundation/url/init%28string:%29){:target="_blank"}로 `ws://주소:52801/` URL을 만든다. 주소로 쓸 수 없는 글이면 nil이다.

Tailscale은 IPv6 주소도 주지만, IPv6는 `fd7a:115c:a1e0::1`처럼 콜론이 여럿이라 포트 떼기와 겹친다. 그래서 시트에는 이름이나 100으로 시작하는 주소를 넣으라고 적었다.

---

### 주소로 붙기와 10초 제한

Bonjour 찾기를 시작할 때 3초 뒤 할 일을 하나 맡겨 둔다. 그 사이에 연결이 끊겨 처음부터 다시 찾게 되면, 맡겨 둔 일은 취소한다.

```swift
remoteTimer?.cancel()
remoteTimer = Task {
    try? await Task.sleep(for: .seconds(RemotePlan.wait))
    guard !Task.isCancelled else { return }
    tryRemote()
}
```

#### Task.isCancelled로 취소된 일 거르기

[`cancel()`](https://developer.apple.com/documentation/swift/task/cancel%28%29){:target="_blank"}는 맡겨 둔 `Task`에 "그만해도 된다"는 표시를 남긴다. 일을 강제로 멈추지는 않는다. 그래서 `Task.sleep`에서 깬 뒤 [`Task.isCancelled`](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property){:target="_blank"}로 지금 도는 일에 그 표시가 있는지 보고 스스로 그만둔다. `Task.sleep`은 취소되면 바로 깨어나 오류를 던지는데, `try?`로 그 오류를 버렸으니 이 확인이 필요하다.

3초가 지나면 판단을 다시 하고, 주소로 가야 하면 URL로 연결을 만든다.

```swift
private func tryRemote() {
    // 허락 안 된 기기면 밖에서 다시 붙어 봐야 같은 답이다. 집에 와서 Bonjour로 찾을 때까지 쉰다
    guard channel == nil, browser != nil, !isHomePairingNeeded else { return }
    let step = RemotePlan.next(bonjourFound: false, waited: Date.now.timeIntervalSince(searchStarted),
                               remoteHost: remoteHost, localNetworkDenied: bonjourDenied)
    guard case .useRemote(let host) = step, let url = RemoteAddress.url(host: host) else { return }
    macName = host
    connect(to: .url(url), remote: true)
    // 맥이 잠들어 있으면 Tailscale 안에서 답 없이 오래 기다린다. 10초 안에 허락까지 못 가면 실패로 친다
    let attempt = channel
    Task {
        try? await Task.sleep(for: .seconds(10))
        guard let attempt, attempt === channel, !isConnected, !isHomePairingNeeded else { return }
        remoteFailed = true
        reconnectLater()
    }
}
```

`channel == nil`이 먼저다. 이미 Bonjour로 붙었거나 붙는 중이면 아무것도 하지 않는다.

10초 제한은 맥이 잠들어 있을 때를 위한 것이다. Tailscale 통로는 열려 있는데 맥이 답을 하지 않으면, 연결은 "연결하는 중"에 꽤 오래 머문다. 그동안 아무 안내가 없으면 왜 안 붙는지 알 수 없다. 그래서 10초 안에 허락까지 못 가면 "밖에서 맥에 붙지 못했어요. 아이패드와 맥에서 Tailscale이 켜져 있는지 확인해 주세요"를 띄우고 처음부터 다시 찾는다.

`attempt === channel`은 같은 연결인지 보는 비교다. `===`는 값이 같은지가 아니라 같은 객체인지를 본다. 10초 사이에 연결이 끊기고 새 연결이 생겼으면 그건 다른 시도라서, 지난 시도의 시간 제한이 새 연결을 끊지 않게 했다.

---

### 밖에서 처음 허락받기는 막기

허락받은 적 없는 기기가 밖에서 붙으면, 맥은 집에서처럼 숫자를 입력하라고 한다. 이건 받지 않았다. 5편의 남는 한계가 "맨 처음 페어링하는 순간에 누가 중간에 끼면 숫자를 맞춰 볼 수 있다"였다. 처음 허락은 집 와이파이에서만 받게 해 두면, 그 순간이 열리는 곳이 집 안으로 좁아진다.

```swift
case .needPairing(let publicKey, let nonce):
    secure = nil
    macPairingKey = Data(base64Encoded: publicKey)
    macNonce = nonce
    if isRemote {
        // 밖에서는 숫자를 보여 주지 않는다. 끊고 다시 찾아, 집에 오면 Bonjour로 허락받게 한다
        phase = .needsHomePairing(macName)
        return reconnectLater()
    }
    phase = .needsPairing(macName)
```

상태 줄에는 "집 와이파이에서 먼저 허락받아 주세요"가 뜨고, 그동안은 주소로 다시 붙지 않는다. 다시 붙어 봐야 같은 답이기 때문이다. Bonjour 찾기는 계속 돌아서, 집에 오면 평소처럼 숫자 화면이 뜬다.

---

## 어느 길로 붙었는지 보여 주기

1편에서 상태 줄에 "같은 와이파이"나 "직접 연결"을 보여 줬다. 연결이 실제로 타는 네트워크 장치 이름으로 정했다. 여기에 원격을 더했다. Tailscale은 `utun`으로 시작하는 장치를 쓰니, 그 이름이면 "원격(VPN)"이다.

```swift
if let name = interfaceName, name.hasPrefix("awdl") || name.hasPrefix("llw") {
    self = .direct
} else if let name = interfaceName, name.hasPrefix("utun") {
    self = .vpn
} else if isWiFi {
    self = .sameWiFi
}
```

직접 연결 검사 뒤, 와이파이 검사 앞에 뒀다. VPN 장치는 종류로는 와이파이도 유선도 아니라서 순서가 크게 중요하진 않지만, 이름으로 가르는 것끼리 먼저 모았다.

---

### 네트워크 장치란?

기기 안에서 데이터가 나가는 출구 하나하나를 네트워크 장치(인터페이스)라고 한다. 와이파이는 `en0`, 아이폰의 LTE는 `pdp_ip0`, 에어드롭 직접 연결은 `awdl0` 같은 이름이 붙는다. VPN 앱은 여기에 `utun`이라는 가상의 장치를 하나 더 만든다. 선도 안테나도 없는 장치라서, 받은 데이터를 암호화한 뒤 아래의 진짜 장치로 넘긴다.

![TouchDeck이 100 주소로 보낸 연결은 utun이라는 가상 장치를 지나 암호화된 뒤, 실제로는 와이파이(en0)나 LTE(pdp_ip0)로 나간다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-interface.png)

그래서 Tailscale로 붙은 연결은 utun과 진짜 장치를 둘 다 거친다. 그런데 앱이 연결 길을 물었을 때 utun까지 알려 준다는 보장은 없다.

---

### 아이폰에서 "기타 연결"로 보이던 문제

아이폰으로 Tailscale을 거쳐 붙여 보니 상태 줄에 "원격(VPN)"이 아니라 "기타 연결"이 떴다. 판정은 연결 길의 첫째 장치 이름이 `utun`으로 시작하는지로 했다. 길이 바뀔 때마다 장치 목록을 콘솔에 찍어 보니, 아이폰은 utun을 아예 알려 주지 않았다.

```text
와이파이로 집에서:      [client] path ["en0(wifi)", "en0(wifi)"] 같은 와이파이
LTE에서 Tailscale로:   [client] path ["pdp_ip0(cellular)", "pdp_ip0(cellular)"] 기타 연결
```

Tailscale을 거친 연결인데도 목록에는 LTE 장치(`pdp_ip0`)만 있었다. 종류가 셀룰러라 와이파이도 유선도 아니어서 "기타 연결"이 된 것이다. 적어도 아이폰에서는 장치 이름만으로 VPN을 알아볼 수 없다.

그래서 이름표를 장치 이름에만 맡기지 않았다. 넣어 둔 주소로 붙은 연결이면 장치 이름이 무엇이든 원격으로 친다. 아래 화질도 이 값을 본다.

```swift
/// 상태 줄과 화질이 쓰는 길. 원격 주소로 붙었으면 장치 이름이 무엇이든 원격으로 친다
var shownRoute: ConnectionRoute? { isRemote ? .vpn : route }

channel.connection.pathUpdateHandler = { [weak self, weak channel] path in
    MainActor.assumeIsolated {
        guard let self, let channel, channel === self.channel else { return }
        self.route = ConnectionRoute(path: path)
        print("[client] path", path.availableInterfaces.map { "\($0.name)(\($0.type))" }, self.route.map(\.label) ?? "-")
    }
}
```

화질이 이름표를 따라가면, 이름 판정이 빗나갔을 때 LTE로 집에서처럼 40Mbps를 보내게 된다. 주소로 붙었다는 사실은 앱이 직접 아는 것이라 빗나갈 일이 없다.

---

## LTE에서 버틸 화질

8편에서 11인치 아이패드는 60fps에 40Mbps까지 썼다. 집 와이파이는 버티지만 LTE는 빠르기가 들쭉날쭉하다. 그래서 원격일 때는 화면 보기를 낮춰서 시작한다. 밖에서는 진행 상황의 글자만 읽히면 된다.

| 항목 | 집 | 원격 |
|---|---|---|
| 긴 변 | 기기 화면 픽셀 (11인치 2388) | 1600 |
| fps | 고른 값 (30 / 60) | 30 |
| 소리 | 고른 값 | 꺼짐 |
| 비트레이트 상한 | 40Mbps | 4Mbps |

```swift
public static func settings(route: ConnectionRoute?, deviceLongSide: Int, savedFPS: Int, savedAudio: Bool,
                            remoteOverride: (fps: Int, audio: Bool)?) -> ScreenSettings {
    guard route == .vpn else {
        return ScreenSettings(maxSide: deviceLongSide, fps: savedFPS, audio: savedAudio, bitrateCap: nil)
    }
    return ScreenSettings(maxSide: min(deviceLongSide, remoteMaxSide),
                          fps: remoteOverride?.fps ?? remoteFPS,
                          audio: remoteOverride?.audio ?? false,
                          bitrateCap: remoteBitrateCap)
}
```

`remoteOverride`는 원격 중에 툴바에서 30/60이나 소리를 바꾼 값이다. 이 값은 그 연결 동안만 쓰고 기억하지 않는다. 집에서 고른 값(8편에서 기억해 둔 것)은 원격 중에 바꿔도 덮어쓰지 않아서, 집에 돌아오면 원래 설정으로 붙는다.

```swift
func setScreenOptions(fps: Int, audio: Bool) {
    let fps = ScreenFPS.normalize(fps)
    if shownRoute == .vpn {
        remoteOverride = (fps, audio)
    } else {
        savedFPS = fps
        savedAudio = audio
        UserDefaults.standard.set(fps, forKey: "screen.fps")
        UserDefaults.standard.set(audio, forKey: "screen.audio")
    }
    // 생략
}
```

---

### 비트레이트 상한 보내기

7편의 비트레이트는 "픽셀당 0.2비트 × 초당 장수"였다. 긴 변 1600에 30fps면 1600×1000 화면에서 9.6Mbps다. LTE에는 아직 많아서 상한을 따로 준다.

화면 보기를 시작하는 `startScreen`과 보는 중에 바꾸는 `screenOptions` 메시지에 `bitrateCap` 칸을 더했다. 칸이 없으면 지금처럼 40Mbps까지 쓴다. 예전 맥 앱은 이 칸을 모르니 무시하고 지금 화질로 보낸다. 맥은 계산 값과 상한 중 작은 쪽을 쓴다.

```swift
static func bitRate(width: Int, height: Int, fps: Int, cap: Int?) -> Int {
    min(Int(Double(width * height) * Double(fps) * 0.2), cap ?? 40_000_000)
}
```

| 화면 | 계산 값 | 상한 4Mbps를 주면 |
|---|---|---|
| 1600×1000, 30fps | 9.6Mbps | 4Mbps |
| 640×400, 30fps | 약 1.5Mbps | 약 1.5Mbps (상한보다 작아서 그대로) |

보는 중에 상한이 바뀌면 8편의 fps 바꾸기처럼 압축기 큐에서 목표 비트레이트만 다시 넣는다. 4Mbps에서 터미널 글자가 얼마나 읽히는지는 아직 확인 못 했다.

---

### 원격에서는 소리를 더 쌓아 두기

원격에서 소리를 켜 보니 LTE에서는 소리가 가끔 끊겼다. 같은 화면을 와이파이로 보면 아이패드와 아이폰 둘 다 끊기지 않았다. 쓰는 양은 화면 4Mbps와 소리 1.5Mbps를 합쳐 5.5Mbps쯤이라 LTE로도 대개 버틸 양이다. 그래서 양보다는 도착 간격 쪽으로 봤다. LTE는 묶음이 잠깐 멈췄다가 몰려오는 일이 와이파이보다 잦고, 소리와 화면이 한 연결을 같이 쓰니 큰 화면 묶음 뒤에 소리 묶음이 줄을 서기도 한다.

8편의 지터 버퍼는 0.06초가 쌓이면 틀기 시작한다. 집 와이파이에 맞춘 값이라, 묶음이 그보다 오래 늦으면 쌓아 둔 게 바닥나 끊긴다. 그래서 세 경계를 묶어 집과 원격 두 벌로 나눴다.

```swift
public struct Limits: Equatable, Sendable {
    public let startAt: Double
    public let dropAbove: Double
    public let resumeBelow: Double

    /// 집 와이파이: 소리가 화면보다 0.06초쯤 늦다
    public static let home = Limits(startAt: 0.06, dropAbove: 0.2, resumeBelow: 0.1)
    /// 원격(LTE): 묶음이 멈췄다 몰려와도 버티게 더 쌓는다. 소리는 0.2초쯤 늦다
    public static let remote = Limits(startAt: 0.2, dropAbove: 0.6, resumeBelow: 0.3)
}
```

| 경계 | 집 | 원격 |
|---|---|---|
| 틀기 시작 | 0.06초 | 0.2초 |
| 버리기 시작 | 0.2초 넘음 | 0.6초 넘음 |
| 다시 받기 | 0.1초 아래 | 0.3초 아래 |

아이패드가 소리를 틀기 시작할 때 원격인지 알려 주고, 플레이어는 그 값으로 지터 버퍼를 만든다. 원격이면 소리가 화면보다 0.2초쯤 늦게 나오지만, 밖에서 진행 상황을 확인하는 데는 거슬리지 않는 정도다. 집 값은 그대로라 8편의 테스트도 그대로 통과한다. 0.2초로 LTE에서 끊김이 없어지는지는 아직 확인 못 했다.

---

## 맥이 잠들지 않게

밖에서 붙으려면 맥이 깨어 있어야 한다. 맥은 가만히 두면 디스플레이를 끄고, 더 지나면 잠든다. 잠들면 네트워크도 멈춰서 밖에서 붙을 수 없다. 그래서 맥 메뉴에 "잠자기 막기" 체크를 두고 직접 켜고 끄게 했다. 그런데 화면 보기에는 문제가 하나 더 있다.

---

### 잠자기와 잠금은 어떻게 이어지나

macOS는 보통 "화면 보호기가 시작되거나 디스플레이가 꺼지면 암호 요구"로 설정돼 있다. 디스플레이가 꺼지는 순간 맥이 잠긴다는 뜻이다. 그리고 7편에서 맥이 잠겨 있으면 화면을 보내지 않게 만들었다. 시스템 잠자기만 막아 두면 맥은 깨어 있는데, 디스플레이가 꺼지면서 잠겨 버려 밖에서 화면을 볼 수 없다.

![평소에는 가만히 두면 디스플레이가 꺼지고 맥이 잠겨 화면 보기가 멈춘다. 잠자기 막기를 켜면 디스플레이가 켜진 채라 잠기지 않고, 밖에서 화면을 볼 수 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-sleep-chain.png)

그래서 "잠자기 막기"를 켜면 시스템 잠자기와 함께 디스플레이 꺼짐도 막는다. 대가는 맥 앞을 지나는 누구나 그 맥을 쓸 수 있다는 것이다. 알고 고른 것이라 메뉴의 체크 아래에 "켜 두면 맥이 잠들지도 잠기지도 않아요"를 적었다.

이 요청은 가만히 있어서 잠드는 것만 막는다. 직접 잠자기를 누르거나 맥북 덮개를 닫으면 잠들고, ⌃⌘Q로 직접 잠그면 잠긴다. 밖에서 화면을 보려면 잠그지 않고 자리를 비워야 한다.

화면을 보는 동안에는 체크가 꺼져 있어도 디스플레이 꺼짐을 따로 막는다. 보는 중에 디스플레이가 꺼지면 맥이 잠겨 화면 보기가 끊기기 때문이다. 보기가 끝나면 푼다.

| 잠자기 막기 | 화면 보는 중 | 들고 있는 요청 |
|---|---|---|
| 켬 | 상관없음 | 시스템 잠자기 막기, 디스플레이 꺼짐 막기 |
| 끔 | 예 | 디스플레이 꺼짐 막기 |
| 끔 | 아니오 | 없음 |

```swift
static func wanted(enabled: Bool, viewing: Bool) -> Set<Kind> {
    if enabled { return [.system, .display] }
    return viewing ? [.display] : []
}
```

어떤 요청을 들고 있어야 하는지만 정하는 부분이라 테스트로 박아 뒀다. 끈 뒤에 요청이 남으면 맥이 계속 안 잠드니까, 둘 다 꺼진 경우가 빈 집합인지가 중요하다.

---

### IOKit에 잠들지 않게 요청하기

실제로 macOS에 요청하는 부분은 IOKit의 전원 관리 함수를 쓴다. 동영상을 트는 앱이 영상이 도는 동안 화면이 꺼지지 않게 하는 것과 같은 방법이다.

```swift
@MainActor
final class PowerAssertions {
    private var held: [KeepAwake.Kind: IOPMAssertionID] = [:]

    func apply(_ wanted: Set<KeepAwake.Kind>) {
        for (kind, id) in held where !wanted.contains(kind) {
            IOPMAssertionRelease(id)
            held[kind] = nil
        }
        for kind in wanted where held[kind] == nil {
            let type = kind == .system ? kIOPMAssertionTypePreventUserIdleSystemSleep : kIOPMAssertionTypePreventUserIdleDisplaySleep
            let name = kind == .system ? "TouchDeck 잠자기 막기" : "TouchDeck 화면 보기"
            var id = IOPMAssertionID(0)
            if IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), name as CFString, &id) == kIOReturnSuccess {
                held[kind] = id
            } else {
                print("[power] assertion failed:", name)
            }
        }
    }
}
```

#### IOPMAssertionCreateWithName으로 요청 들고 놓기

요청 하나는 이렇게 들고 놓는다.

1. 요청 종류를 고른다. [`kIOPMAssertionTypePreventUserIdleSystemSleep`](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep){:target="_blank"}은 가만히 있어서 시스템이 잠드는 것을 막는다. [`kIOPMAssertionTypePreventUserIdleDisplaySleep`](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridledisplaysleep){:target="_blank"}은 가만히 있어서 디스플레이가 꺼지는 것을 막는다. 둘 다 Swift에서는 글자(`String`)라서 `as CFString`으로 바꿔 넘긴다.
2. [`IOPMAssertionCreateWithName`](https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname){:target="_blank"}에 종류, 세기([`kIOPMAssertionLevelOn`](https://developer.apple.com/documentation/iokit/1557096-assertion/kiopmassertionlevelon){:target="_blank"}), 이름, 번호를 받을 칸을 준다. 성공하면 `kIOReturnSuccess`를 돌려주고, `&id`로 넘긴 칸에 그 요청의 번호([`IOPMAssertionID`](https://developer.apple.com/documentation/iokit/iopmassertionid){:target="_blank"})를 적는다. 이름은 나중에 누가 막고 있는지 볼 때 보인다.
3. 필요 없어지면 [`IOPMAssertionRelease`](https://developer.apple.com/documentation/iokit/1557090-iopmassertionrelease){:target="_blank"}에 그 번호를 넘겨 푼다. 앱이 끝나면 macOS가 그 앱이 든 요청을 같이 풀지만, 끝날 때도 직접 풀었다.

들고 있는 번호를 종류별로 기억해 두고, 원하는 목록과 비교해서 빠진 건 놓고 새로 생긴 것만 든다. 같은 목록으로 여러 번 불러도 요청이 겹쳐 쌓이지 않는다.

터미널에서 `pmset -g assertions`를 치면 지금 잠자기를 막고 있는 요청이 나온다. 체크를 켜면 "TouchDeck 잠자기 막기"가, 화면을 보는 동안은 "TouchDeck 화면 보기"가 보이고, 끄면 사라지는지로 확인한다. 디스플레이 꺼짐을 막을 때 화면 보호기도 뜨지 않는지는 아직 확인 못 했다.

---

### 체크와 보는 기기를 같이 지켜보기

요청은 두 값이 바뀔 때 다시 맞춰야 한다. 메뉴의 체크, 그리고 지금 화면을 보는 기기가 있는지다. 체크는 메뉴에서 바꾸니 바꿀 때 다시 맞추면 된다. 보는 기기는 다르다. 메뉴 창이 닫혀 있어도 아이패드가 화면 보기를 열고 닫는다. 그래서 메뉴 화면이 아니라 앱이 켜져 있는 동안 늘 살아 있는 객체가 보는 기기를 지켜보게 했다.

---

### 지켜보기(Observation)란?

맥 앱의 `ScreenHost`처럼 [`@Observable`](https://developer.apple.com/documentation/observation/observable%28%29){:target="_blank"}을 붙인 클래스는 속성 값이 바뀌면 그걸 읽던 쪽에 알려 줄 수 있다. SwiftUI 화면이 값이 바뀔 때 다시 그려지는 것도 이 덕분이다. 화면이 아닌 코드에서 직접 지켜보려면 [`withObservationTracking(_:onChange:)`](https://developer.apple.com/documentation/observation/withobservationtracking%28%5F:onchange:%29){:target="_blank"}을 쓴다. 첫 클로저 안에서 읽은 값을 지켜보다가, 그중 하나가 바뀌려고 하면 `onChange`를 부른다.

주의할 점은 딱 한 번만 알린다는 것이다. 알린 뒤에는 지켜보기가 끝나서, 계속 지켜보려면 다시 걸어야 한다.

![withObservationTracking은 한 번 알리고 끝난다. 다시 거는 곳이 두 군데면 지켜보기가 하나씩 쌓여 한 번 바뀔 때 셋이 다 울리고, 한 군데면 늘 하나다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-observation.png)

처음에는 요청을 다시 맞추는 `refresh()` 안에서 지켜보기를 걸었다. 그러면 체크를 바꿔서 `refresh()`를 부를 때마다 지켜보기가 하나씩 더 걸린다. 앞서 건 지켜보기는 아직 안 울렸으니 살아 있다. 체크를 세 번 바꾸면 지켜보기가 셋이 되고, 보는 기기가 한 번 바뀌면 셋이 다 울린다. 요청 맞추기는 여러 번 불러도 결과가 같아서 겉으로 드러나지는 않지만, 체크를 바꿀수록 계속 늘어난다.

그래서 지켜보기를 거는 곳을 `watchViewer()` 하나로 떼었다. 체크를 바꿀 때는 `refresh()`만 부르고, 지켜보기는 울렸을 때만 그 안에서 다시 건다.

```swift
init(screen: ScreenHost) {
    self.screen = screen
    watchViewer()
    refresh()
    NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.power.apply([]) }
    }
}

func refresh() {
    power.apply(KeepAwake.wanted(enabled: UserDefaults.standard.bool(forKey: KeepAwake.key), viewing: screen.viewerName != nil))
}

/// 지켜보기는 한 번 바뀌면 끝나서, 바뀔 때마다 다시 건다. 체크로 부르는 refresh와 나눠 두어야 지켜보기가 쌓이지 않는다
private func watchViewer() {
    withObservationTracking { _ = screen.viewerName } onChange: { [weak self] in
        Task { @MainActor in
            self?.refresh()
            self?.watchViewer()
        }
    }
}
```

#### withObservationTracking과 종료 알림 받기

`withObservationTracking`의 첫 클로저에서 `screen.viewerName`을 읽기만 했다. 읽은 값이 지켜볼 대상이 된다. `onChange`는 값이 바뀌기 직전에, 바꾸는 쪽 스레드에서 불린다. 그래서 `Task { @MainActor in … }`로 메인으로 넘긴 뒤 새 값으로 요청을 맞추고 다시 건다.

앱이 끝날 때는 [`addObserver(forName:object:queue:using:)`](https://developer.apple.com/documentation/foundation/notificationcenter/addobserver%28forname:object:queue:using:%29){:target="_blank"}로 [`NSApplication.willTerminateNotification`](https://developer.apple.com/documentation/appkit/nsapplication/willterminatenotification){:target="_blank"}(앱이 곧 끝난다는 알림)을 받아 요청을 모두 놓는다. `queue: .main`이라 메인에서 불리는 걸 아니까 `MainActor.assumeIsolated`(1편)로 메인 객체를 바로 만졌다.

메뉴 쪽은 체크 하나다.

```swift
@AppStorage(KeepAwake.key) private var keepAwakeOn = false

Toggle("잠자기 막기", isOn: $keepAwakeOn)
    .onChange(of: keepAwakeOn) { keepAwake.refresh() }
Text(keepAwakeOn ? "잠자기 막는 중. 맥이 잠들지도 잠기지도 않아요"
     : "켜 두면 맥이 잠들지도 잠기지도 않아요. 밖에서 화면을 볼 때 켜 두세요")
    .font(.caption).foregroundStyle(.secondary)
```

#### Toggle로 켜고 끄는 체크 만들기

[`Toggle`](https://developer.apple.com/documentation/swiftui/toggle){:target="_blank"}은 켜고 끄는 스위치다. 맥 메뉴바 창에서는 체크 상자로 보인다. `isOn:`에 묶은 값이 켜짐 여부이고, 여기서는 `@AppStorage`(6편)로 묶어서 앱을 다시 켜도 고른 값이 남는다. 메뉴바 아이콘은 이미 화면을 보는 중(눈 모양)을 나타내는 데 쓰고 있어서, "잠자기 막는 중"은 체크 아래 설명 줄을 바꿔서 보여 준다.

---

## 밖에서 붙기 버튼과 시트

처음에는 상태 줄 자체를 누르면 주소를 넣는 시트가 뜨게 했다. 써 보니 상태 줄이 눌린다는 걸 알 방법이 없었다. 그래서 상태 줄 오른쪽에 "밖에서 붙기" 버튼을 따로 뒀다.

맥과 끊겨 있으면 화면 아래쪽은 흐리게 하고 누를 수 없게 막아 둔다. 원래는 상태 줄까지 같이 막혀 있었는데, 주소는 끊겨 있을 때 넣어야 하니 이 버튼은 눌려야 한다. 그래서 `disabled`(4편)를 화면 전체가 아니라 화면 고르기와 아래 본문에만 붙였다.

```swift
NavigationStack {
    Form {
        Section {
            TextField("맥 주소", text: $address)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(save)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let reason {
                    Text(reason).foregroundStyle(DeckTheme.failure)
                }
                Text("Tailscale이 맥에 붙인 이름이나 100으로 시작하는 주소를 넣으세요. 비워 두면 집에서만 써요")
            }
        }
    }
    .navigationTitle("밖에서 붙기")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("취소") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("저장", action: save)
        }
    }
}
```

#### Form과 toolbar로 설정 시트 만들기

입력칸 옵션 세 개(`keyboardType`, `textInputAutocapitalization`, `autocorrectionDisabled`)는 4편에 나왔다. 나머지는 설정 화면 모양을 만드는 것들이다.

| API | 하는 일 |
|---|---|
| [`sheet(isPresented:onDismiss:content:)`](https://developer.apple.com/documentation/swiftui/view/sheet%28ispresented:ondismiss:content:%29){:target="_blank"} | 묶은 값이 true면 아래에서 시트를 올린다. 버튼이 이 값을 true로 바꾼다 |
| [`NavigationStack`](https://developer.apple.com/documentation/swiftui/navigationstack){:target="_blank"} | 위에 제목 줄과 버튼 자리가 있는 화면 틀 |
| [`Form`](https://developer.apple.com/documentation/swiftui/form){:target="_blank"} | 설정 앱처럼 칸을 묶어 보여 주는 목록 |
| [`Section`](https://developer.apple.com/documentation/swiftui/section){:target="_blank"} | 묶음 하나. `footer:`는 묶음 아래 작은 설명 글 자리 |
| [`submitLabel(_:)`](https://developer.apple.com/documentation/swiftui/view/submitlabel%28%5F:%29){:target="_blank"} | 키보드 엔터 키에 쓰일 글. `.done`이면 "완료" |
| [`onSubmit(of:_:)`](https://developer.apple.com/documentation/swiftui/view/onsubmit%28of:%5F:%29){:target="_blank"} | 키보드 엔터 키를 누르면 할 일. 저장 버튼과 같은 `save`를 불렀다 |
| [`navigationTitle(_:)`](https://developer.apple.com/documentation/swiftui/view/navigationtitle%28%5F:%29){:target="_blank"} | 제목 줄의 글 |
| [`navigationBarTitleDisplayMode(_:)`](https://developer.apple.com/documentation/swiftui/view/navigationbartitledisplaymode%28%5F:%29){:target="_blank"} | 제목 크기. `.inline`은 제목 줄 가운데 작게 |
| [`toolbar(content:)`](https://developer.apple.com/documentation/swiftui/view/toolbar%28content:%29){:target="_blank"}, [`ToolbarItem`](https://developer.apple.com/documentation/swiftui/toolbaritem){:target="_blank"} | 제목 줄에 버튼 넣기 |
| [`cancellationAction`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/cancellationaction){:target="_blank"}, [`confirmationAction`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/confirmationaction){:target="_blank"} | 취소와 확인 버튼 자리. 플랫폼 관례대로 왼쪽과 오른쪽에 놓인다 |
| [`dismiss`](https://developer.apple.com/documentation/swiftui/environmentvalues/dismiss){:target="_blank"} | `@Environment(\.dismiss)`로 꺼내 부르면 지금 시트를 닫는다 |

저장을 누르면 앞의 주소 다듬기를 거친다. 다듬을 수 없으면 시트를 닫지 않고 묶음 아래에 빨간 글로 이유를 보여 준다. 칸을 비우고 저장하면 주소를 지우고 집에서만 쓴다. 저장한 주소는 기기에 기억해 둔다.

---

## Tailscale 설정 순서

앱 밖에서 한 번 해 둘 일이다.

1. 맥과 아이패드(아이폰)에 App Store에서 Tailscale을 깔고, 같은 계정으로 로그인한다.
2. 맥의 Tailscale 메뉴(또는 아이폰 Tailscale 앱의 기기 목록)에서 맥 이름이나 100으로 시작하는 주소를 확인한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-9/touchdeck-tailscale-app.webp){: width="360" }

아이폰 Tailscale 앱 첫 화면이다. 위쪽 스위치가 켜져 있고 "Connected"면 Tailscale에 붙어 있는 것이다. 아래 목록에 같은 계정의 기기가 나오는데, `dongiks-macbook-pro`가 TouchDeck에 넣을 맥 이름이다. 이름 아래 가린 자리에 100으로 시작하는 주소가 있다. 기기 이름 옆 초록 점은 그 기기가 지금 Tailscale에 붙어 있다는 뜻이다.
3. TouchDeck 상태 줄 오른쪽의 "밖에서 붙기"를 눌러 그 이름을 넣는다.
4. 처음 허락은 집 와이파이에서 받아 둔다.
5. 밖에서는 아이패드(아이폰)의 Tailscale을 켜 둔다. 맥을 오래 비울 거면 맥 메뉴의 "잠자기 막기"를 켜고, 잠그지 않은 채 자리를 비운다.

---

## 테스트

순수 계산은 이번에도 DeckKit에 두고 테스트부터 썼다. DeckKit 171개, 맥 61개가 통과한다.

| 무엇 | 테스트 |
|---|---|
| 주소 다듬기 | `cleanStripsSchemePortAndSlash`, `rejectsEmptyAndSpaces`, `remoteURLUsesWebSocketPort` |
| 경로 | `utunIsVPN` |
| 붙는 순서 | `bonjourFirstNoWait`, `remoteAfterThreeSeconds`, `deniedLocalNetworkStillUsesRemote` |
| 원격 화질 | `vpnUsesRemotePreset`, `remoteOverrideDoesNotTouchSaved` |
| 원격 소리 | `remoteWaitsTwoHundredMsAndHoldsSixHundred`, `remoteResumesBelowThreeHundredMs` |
| 메시지 | `bitrateCapRoundTrips`, `missingBitrateCapIsNil` |
| 맥 비트레이트 | `bitRateHonorsCap` |
| 잠자기 막기 | `assertionsFollowToggleAndViewing` |

---

## 참고자료

- [How Tailscale works (Tailscale)](https://tailscale.com/blog/how-tailscale-works){:target="_blank"}
- [MagicDNS (Tailscale)](https://tailscale.com/kb/1081/magicdns){:target="_blank"}
- [Assertion types, IOPMLib (Apple)](https://developer.apple.com/documentation/iokit/iopmlib%5Fh/iopmassertiontypes){:target="_blank"}
- [pmset 명령 (ss64)](https://ss64.com/mac/pmset.html){:target="_blank"}
