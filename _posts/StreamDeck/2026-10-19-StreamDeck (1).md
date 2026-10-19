---
title: StreamDeck (1) 아이패드와 맥이 같은 와이파이에서 서로를 찾아 붙기까지
writer: Harold
date: 2026-10-19 18:00:00 +0900
categories: [StreamDeck]
tags: [Network, Bonjour, WebSocket, NWListener]

toc: true
toc_sticky: true
published: true
---

책상 위에 작은 터치 화면을 두고, 거기서 버튼을 누르면 맥에서 앱이 열리는 나만의 스트림덱을 만들어 보려고 한다. 최종 목표는 ESP32 보드(CYD 2.8인치 터치 화면)로 만드는 건데, 보드를 사기 전에 지금 모니터 바로 옆에 세워 둔 아이패드로 먼저 만들어 보기로 했다. 아이패드에서 맥 쪽까지 다 만들어 두면 보드가 왔을 때 보드는 같은 방식으로 맥에 붙기만 하면 된다.

이 글은 클로드 코드와 대화하면서 바이브 코딩으로 진행한 과정을 정리한 것이다. 버튼에 무엇을 올릴지(자주 쓰는 앱, `blogrun` 같은 별칭 명령, 새 Alacritty 창, 소리 크기), 화면을 어떻게 놓을지 같은 건 대화로 정했고, 처음 써 보는 애플 도구가 많아서 애플 공식 문서를 같이 찾아 가면서 확인했다. 이번 글은 아이패드와 맥이 서로를 찾아 메시지를 주고받는 데까지다.

---

## 세 기기가 나눠 맡는 일

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-1/touchdeck-structure.png)

아이패드(아이폰도 같은 앱)는 버튼을 누르고, 버튼을 꾸미는 쪽이다. 맥에는 메뉴바에 작은 앱이 떠 있고, 아이패드가 "몇 번 버튼 눌림"을 보내면 실제로 앱을 열거나 명령을 실행한다. 어떤 칸에 어떤 버튼이 있는지도 맥에만 저장한다. 아이패드가 꺼져 있어도 나중에 붙을 보드는 계속 동작해야 하고, 설정이 한 곳에만 있어야 아이패드와 보드가 서로 다른 화면을 보여주는 일이 없어서다.

맥과 아이패드는 계속 붙어 있어야 해서 블루투스가 아니라 와이파이로 붙기로 했다. 예전에 GestureClip에서 쓴 MultipeerConnectivity는 애플 기기끼리만 통해서 ESP32가 알아듣지 못한다. 그래서 보드도 쓸 수 있는 WebSocket으로 통일했다. WebSocket은 한 번 연결해 두면 양쪽이 아무 때나 메시지를 보낼 수 있는 방식이고, ESP32에도 이걸 쓰는 라이브러리(arduinoWebSockets)가 있다.

메시지는 JSON 글자로 주고받는다. 보드에서도 읽기 쉽게 하려고 최상위에 `type` 하나로 종류를 나눴다.

```json
{ "type": "press", "page": 0, "index": 3 }
```

맥 서버는 처음엔 Hummingbird로 하려고 했다. 그런데 ChatBird 때 제대로 써 본 게 아니라 익숙하다는 장점이 거의 없었고, 아이패드는 어차피 애플 Network 프레임워크로 맥을 찾아야 했다. 그래서 맥 서버도 같은 프레임워크의 `NWListener`로 만들었다. 외부 라이브러리가 하나도 없다.

---

## 맥이 기다리고 아이패드가 찾아오는 구조

`NWListener`는 정해진 포트에서 들어오는 연결을 기다리는 객체다. 여기에 WebSocket 옵션을 얹으면 WebSocket 서버가 되고, `service`를 정해 주면 같은 와이파이에 "나 여기 있어"라고 알리는 것(Bonjour)까지 같이 한다. Bonjour는 IP 주소를 몰라도 같은 네트워크 안의 기기를 이름으로 찾게 해 주는 애플의 방식이다. 아이패드에서 맥 IP를 직접 칠 필요가 없어진다.

연결 설정은 맥과 아이패드가 똑같은 걸 쓰게 한 곳에 뒀다.

```swift
// WebSocketChannel.swift (DeckKit, 맥과 iOS 공용)
public enum DeckNetwork {
    public static func parameters() -> NWParameters {
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        // 앱 목록에 아이콘이 다 들어가서 메시지가 커질 수 있다.
        ws.maximumMessageSize = 16 * 1024 * 1024
        let params = NWParameters.tcp
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        return params
    }
}
```

`NWParameters.tcp`가 기본 연결이고, 그 위에 WebSocket 옵션을 끼워 넣는 모양이다. (이 설정은 나중에 맥이 잠들었을 때 끊김을 알아채려고 TCP keepalive를 켜는 쪽으로 바뀐다. 5편에 적었다.) `maximumMessageSize`는 메시지 하나의 최대 크기인데, 다음 글에서 다룰 앱 목록이 아이콘까지 담으면 2MB가 넘어서 넉넉하게 16MB로 잡았다.

맥 쪽 서버는 이렇게 연다.

```swift
// DeckServer.swift (맥)
func start() {
    do {
        let listener = try NWListener(using: DeckNetwork.parameters(), on: Self.port)
        listener.service = NWListener.Service(type: DeckConstants.serviceType)
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.listenerChanged(state) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        listener.start(queue: .main)
        self.listener = listener
    } catch {
        // 생략
    }
}
```

서비스 타입은 `_touchdeck._tcp`로 정했다. 이름을 따로 안 주면 맥 컴퓨터 이름이 그대로 쓰인다. 포트는 52801로 고정했다. Bonjour로 찾으면 포트를 몰라도 되지만, 나중에 보드를 처음 붙일 때 IP와 포트를 코드에 직접 적고 시작할 생각이라 고정해 두는 게 편했다.

네트워크 콜백을 전부 main 큐에서 받게 했다. 아이패드 몇 대가 버튼을 누르는 정도라 메시지 양이 아주 적어서, 상태를 한 곳(메인 스레드)에서만 바꾸는 쪽이 단순했다. 그래서 콜백 안에서 `MainActor.assumeIsolated`로 "여기는 이미 메인이다"라고 알려 주고 바로 상태를 바꾼다.

맥 앱을 켜고 터미널에서 광고가 보이는지 확인했다.

```text
$ dns-sd -B _touchdeck._tcp
Timestamp     A/R    Flags  if Domain               Service Type         Instance Name
18:29:36.442  Add        3   1 local.               _touchdeck._tcp.     Dongik’s MacBook Pro
18:29:36.442  Add        3  17 local.               _touchdeck._tcp.     Dongik’s MacBook Pro
18:29:36.442  Add        2  14 local.               _touchdeck._tcp.     Dongik’s MacBook Pro
```

같은 이름이 여러 줄 나오는 건 맥의 네트워크 장치(와이파이, 유선 등)마다 한 번씩 광고해서다. 아이패드 쪽은 `NWBrowser`로 같은 서비스 타입을 찾고, 찾은 결과로 바로 연결한다.

```swift
// DeckClient.swift (iOS)
let browser = NWBrowser(for: .bonjour(type: DeckConstants.serviceType, domain: nil), using: .tcp)
browser.browseResultsChangedHandler = { [weak self] results, _ in
    MainActor.assumeIsolated { self?.found(results) }
}
browser.start(queue: .main)
```

```swift
// DeckClient.swift (iOS)
private func found(_ results: Set<NWBrowser.Result>) {
    guard channel == nil, let result = results.first else { return }
    if case .service(let name, _, _, _) = result.endpoint { macName = name }
    connect(to: result.endpoint)
}
```

화면 위쪽 상태 줄에 뜨는 "Dongik’s MacBook Pro에 연결됨"의 이름이 여기서 꺼낸 서비스 이름이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-1/touchdeck-connected-empty.png)

---

## host:port로는 열리지 않던 WebSocket 연결

메시지 주고받는 부분을 만들고 나서, 맥에서 서버를 열고 같은 맥에서 `127.0.0.1`로 붙어 글자를 하나 보내면 그대로 돌아오는지 테스트를 먼저 짰다. 서버가 받은 글자를 그대로 돌려주게 하고, 클라이언트는 이렇게 붙었다.

```swift
// WebSocketChannelTests.swift (처음 버전)
let client = WebSocketChannel(connection: NWConnection(host: "127.0.0.1", port: port, using: DeckNetwork.parameters()))
```

테스트는 60초 시간 제한에 걸려 실패했다. 연결 상태를 찍어 보니 이렇게 나왔다.

```text
client state preparing
server got conn
client state waiting(POSIXErrorCode(rawValue: 53): Software caused connection abort)
server state preparing
server state failed(POSIXErrorCode(rawValue: 54): Connection reset by peer)
```

서버는 연결을 받았는데 클라이언트가 곧바로 끊겨 버렸다. 네트워크 자체 문제인지부터 가르려고 작은 실험 프로그램을 따로 만들어 설정을 하나씩 바꿔 봤다.

| 클라이언트 연결 방법 | 결과 |
|---|---|
| WebSocket 옵션 + `host: "127.0.0.1", port:` | 실패 (POSIX 53) |
| WebSocket 옵션 없이 TCP만 | 성공 |
| WebSocket 옵션 + `maximumMessageSize` 빼기 | 실패 (POSIX 53) |
| WebSocket 옵션 + `.url(ws://127.0.0.1:포트/)` | 성공 |
| WebSocket 옵션 + Bonjour로 찾은 서비스 그대로 | 성공 |

TCP만 쓰면 되니까 와이파이나 방화벽 문제는 아니었고, 크기 옵션과도 상관없었다. 달라진 건 "어디로 붙는지"를 적는 방식뿐이었다. WebSocket은 처음 붙을 때 HTTP 요청(`GET / HTTP/1.1`과 `Host` 줄)을 한 번 보내고 WebSocket으로 바꿔 타는데, `host:port`로만 적으면 이 요청을 만드는 데 필요한 주소 정보가 모자라서 그런 것으로 보인다. 애플 문서에서 이 경우를 콕 집어 설명한 부분은 찾지 못해서 추정으로 남겨 둔다. `ws://` 주소로 적거나 Bonjour로 찾은 서비스로 붙으면 둘 다 바로 열렸다.

앱에서는 Bonjour 결과로 붙으니 원래 문제가 없었고, 테스트만 `ws://` 주소로 바꿨다.

```swift
// WebSocketChannelTests.swift
// WebSocket 클라이언트는 host:port 로 붙으면 POSIX 53(connection abort)으로 실패한다.
// HTTP 업그레이드 요청을 만들 주소가 필요해서 ws:// URL 이나 Bonjour 서비스로 붙어야 한다.
let url = URL(string: "ws://127.0.0.1:\(port.rawValue)/")!
let client = WebSocketChannel(connection: NWConnection(to: .url(url), using: DeckNetwork.parameters()))
```

이 테스트가 통과한 뒤에 실제 맥 앱을 띄우고, 같은 방식의 작은 스크립트로 처음 보는 기기인 척 붙어 봤다. 맥은 처음 보는 기기에게 허락 숫자부터 요구하고, 허락 전에 보낸 버튼 누르기는 거절했다. 이 허락 과정은 5편에서 따로 정리한다.

```text
<- {"type":"needPairing"}
<- {"type":"unauthorized"}
<- {"remaining":4,"type":"pairingFailed"}
```

---

## 로컬 네트워크 권한

아이폰과 아이패드는 같은 와이파이의 다른 기기를 찾거나 붙으려면 사용자 허락이 필요하다. 처음 찾기를 시작할 때 "로컬 네트워크의 기기를 찾고 연결하려고 합니다" 창이 뜨는 그 권한이다. 이걸 위해 Info.plist에 두 가지를 넣어야 한다.

```yaml
# project.yml (xcodegen)
NSLocalNetworkUsageDescription: 같은 와이파이에 있는 맥의 TouchDeck을 찾아 버튼 누름을 보내기 위해 로컬 네트워크를 사용합니다.
NSBonjourServices: [_touchdeck._tcp]
```

`NSLocalNetworkUsageDescription`은 권한 창에 나오는 문구고, `NSBonjourServices`는 이 앱이 찾을 Bonjour 서비스 타입 목록이다. 목록에 없는 타입은 찾을 수 없다.

애플의 TN3179 문서에 두 가지 중요한 내용이 있었다. 하나는 시뮬레이터가 이 권한을 지원하지 않는다는 것이다. 시뮬레이터에서 잘 돌아도 실제 기기에서 권한 창이 뜨는지, 거부하면 어떻게 되는지는 실제 기기로 확인해야 한다. 다른 하나는 사용자가 거부하면 Bonjour 찾기가 `kDNSServiceErr_PolicyDenied`(-65570) 오류로 멈춰서 기다린다는 것이다. 그래서 `NWBrowser`가 이 오류로 기다리면 화면 위에 "설정 > 개인정보 보호 및 보안 > 로컬 네트워크에서 TouchDeck을 켜세요"를 띄우고 설정 열기 버튼을 두게 했다.

```swift
// DeckClient.swift (iOS)
private func browserChanged(_ state: NWBrowser.State) {
    switch state {
    case .waiting(let error), .failed(let error):
        // 로컬 네트워크 권한을 거부하면 Bonjour가 PolicyDenied(-65570)로 막힌다 (TN3179)
        if case .dns(let code) = error, code == -65570 || code == -65555 {
            phase = .localNetworkDenied
        }
    default:
        break
    }
}
```

-65555(NoAuth)도 같이 본 건 예전에 정리해 둔 자료에 이 번호가 적혀 있어서다. TN3179에 적힌 번호는 -65570이다. 서명을 해서 실제 아이패드에 설치하는 건 아직 안 해서, 권한 창과 거부했을 때 이 안내가 실제로 뜨는지는 아직 확인 못 했다.

---

## 와이파이가 달라도 붙는 직접 연결

Bonjour로 찾는 방식은 맥과 아이패드가 같은 와이파이(같은 공유기)에 있어야 한다. 집 책상에서는 늘 그렇지만, 핫스팟에 붙어 있거나 공유기가 바뀌면 서로를 못 찾는다. 블루투스로도 되냐는 얘기가 나와서 두 가지를 비교했다.

하나는 애플 Network 프레임워크의 기기끼리 직접 연결이다. 에어드롭처럼 근처 기기를 블루투스로 찾고, 공유기 없이 와이파이 무선을 직접 써서 붙는다. 연결 설정에 `includePeerToPeer`를 켜기만 하면 되고, 지금 만든 WebSocket, 페어링, 암호화는 그대로 쓴다. 대신 양쪽 다 와이파이는 켜져 있어야 한다(공유기에 붙어 있을 필요는 없다).

다른 하나는 진짜 블루투스(BLE)로 주고받는 것이다. 와이파이가 꺼져 있어도 되지만 한 번에 보낼 수 있는 양이 수백 바이트라, 아이콘을 다 담은 2MB짜리 앱 목록 같은 건 잘게 쪼개 보내고 이어 붙이는 걸 새로 만들어야 한다. 아이패드는 와이파이를 잘 쓰는 기기라 BLE로 바꿔도 얻는 게 별로 없다. BLE는 아이콘을 띄워야 하는 ESP32 보드에서 해 보기로 하고, 지금은 직접 연결만 켰다.

```swift
// WebSocketChannel.swift (DeckKit)
// 같은 와이파이가 아니어도 근처에 있으면 붙게 (에어드롭처럼 기기끼리 직접 연결)
params.includePeerToPeer = true
```

맥의 `NWListener`, 아이패드의 `NWBrowser`와 `NWConnection` 셋 다 이 옵션이 켜져 있어야 한다. `NWBrowser`는 원래 `.tcp` 기본 설정으로 찾고 있어서, 직접 연결을 허용한 찾기용 설정을 따로 만들어 넣었다. 시뮬레이터에서는 이 연결을 시험할 수 없어서 실제 아이패드로 확인했다. 아이패드에서 와이파이를 끄고도 맥에 그대로 붙었다. 제어 센터에서 와이파이를 끄면 공유기와의 연결만 끊기고, 에어드롭 같은 기기끼리 연결에 쓰는 무선은 남아 있기 때문이다.

붙고 나니 지금 어느 길로 붙어 있는지 궁금해졌다. 연결이 실제로 타는 네트워크 장치는 `NWConnection`의 `currentPath`에 있고, 바뀔 때마다 `pathUpdateHandler`로 알려 준다. 기기끼리 직접 연결이면 장치 이름이 `awdl`(에어드롭이 쓰는 장치)이나 `llw`로 시작한다. 그래서 상태 줄의 "연결됨" 옆에 "같은 와이파이"인지 "직접 연결"인지 작은 표시를 붙였다.

```swift
// ConnectionRoute.swift (DeckKit)
public init(interfaceName: String?, isWiFi: Bool, isWired: Bool) {
    if let name = interfaceName, name.hasPrefix("awdl") || name.hasPrefix("llw") {
        self = .direct
    } else if isWiFi {
        self = .sameWiFi
    } else if isWired {
        self = .wired
    } else {
        self = .other
    }
}

/// 연결이 실제로 타고 있는 네트워크 장치로 판단한다
public init(path: NWPath) {
    let interface = path.availableInterfaces.first
    self.init(interfaceName: interface?.name,
              isWiFi: interface?.type == .wifi,
              isWired: interface?.type == .wiredEthernet)
}
```

직접 연결 장치도 종류는 와이파이(`.wifi`)로 나와서, 이름을 먼저 본다. 이름 판단은 공용 코드에 두고 테스트로 정했다. 화면에서 이 표시가 실제로 어떻게 바뀌는지는 아직 확인 못 했다.

---

## 참고자료

- [NWListener (Apple)](https://developer.apple.com/documentation/network/nwlistener)
- [NWListener.Service (Apple)](https://developer.apple.com/documentation/network/nwlistener/service-swift.property)
- [NWProtocolWebSocket.Options (Apple)](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options)
- [maximumMessageSize (Apple)](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options/maximummessagesize)
- [NWBrowser (Apple)](https://developer.apple.com/documentation/network/nwbrowser)
- [NWConnection (Apple)](https://developer.apple.com/documentation/network/nwconnection)
- [NWEndpoint.url(_:) (Apple)](https://developer.apple.com/documentation/network/nwendpoint/url(_:))
- [TN3179: Understanding local network privacy (Apple)](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [NSBonjourServices (Apple)](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices)
- [NSLocalNetworkUsageDescription (Apple)](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription)
- [WWDC25: Use structured concurrency with Network framework](https://developer.apple.com/videos/play/wwdc2025/250/)
- [NWParameters.includePeerToPeer (Apple)](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer)
- [NWConnection.currentPath (Apple)](https://developer.apple.com/documentation/network/nwconnection/currentpath)
- [NWPath.availableInterfaces (Apple)](https://developer.apple.com/documentation/network/nwpath/availableinterfaces)
- [arduinoWebSockets (ESP32 쪽에서 쓸 라이브러리)](https://github.com/Links2004/arduinoWebSockets)
