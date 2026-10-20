---
title: StreamDeck (7) 아이패드로 맥 화면을 보고 터치로 조작하기
writer: Harold
date: 2026-10-20 2:00:00 +0900
categories: [StreamDeck]
tags: [ScreenCaptureKit, VideoToolbox, AVFoundation, CGEvent, CryptoKit]

toc: true
toc_sticky: true
published: true
---

모니터 옆에 세워 둔 아이패드로 맥 화면을 실시간으로 보고, 손가락으로 눌러서 조작할 수 있게 했다. 맥에 모니터가 3개라서 먼저 모니터 목록을 작은 미리보기와 함께 보여주고, 하나를 고르면 그 모니터만 전체 화면으로 본다.

macOS에도 화면 공유가 있지만 TouchDeck 안에 넣은 이유는 세 가지다. 이미 만든 페어링과 암호화를 그대로 쓸 수 있고, 모니터를 골라 볼 수 있고, 스트림덱 버튼판과 한 앱에서 오갈 수 있다.

만들기 전에 정한 조건이 있다.

- 같은 와이파이나 기기끼리 직접 연결(1편)에서만 쓴다. 집 밖에서 붙는 건 범위 밖이다.
- 새 인증 방식이나 새 연결 통로를 만들지 않는다. 허락받은 WebSocket 연결 위에서만 화면과 입력이 오간다.
- 키보드, 한글 입력, 소리, 클립보드는 이번에 넣지 않는다.

---

## 맥 화면이 아이패드까지 가는 길

![맥에서 고른 모니터를 ScreenCaptureKit으로 찍고 VideoToolbox로 H.264 압축한 뒤 이번 접속 키로 봉인해 WebSocket 바이너리로 보낸다. 아이패드는 봉인을 풀고 H.264를 풀어 그린다. 터치는 JSON 봉투로 맥에 돌아가 마우스 이벤트가 된다](/assets/images/upload/touchdeck-screen-pipeline.png)

맥 쪽은 모니터를 찍어서 압축하고 봉인해서 보낸다. 아이패드는 반대 순서로 풀어서 그린다. 터치는 기존 버튼 메시지처럼 JSON으로 봉투에 넣어 맥으로 보내고, 맥이 마우스 이벤트로 바꾼다.

새로 만든 파일은 이렇게 나눴다. 순수 계산(좌표, 메시지 모양, 봉인)은 공용 패키지 DeckKit에 두고 테스트부터 썼다.

| 어디 | 파일 | 하는 일 |
|---|---|---|
| DeckKit | `Screen.swift` | 모니터 정보, 터치 메시지, 보여줘도 되는지 판단 |
| DeckKit | `VideoPacket.swift` | 영상 프레임을 바이너리에 싣는 모양, 밀리면 버리는 `SendGate` |
| DeckKit | `ScreenGeometry.swift` | 터치 위치 → 영상 안 위치 → 맥 좌표 |
| DeckKit | `SecureSession.swift` | 바이너리 봉인 `sealBinary` / `openBinary` 추가 |
| 맥 | `ScreenCapture.swift` | 모니터 목록과 미리보기, 찍기와 압축 |
| 맥 | `ScreenHost.swift` | 누가 보는지, 끊기, 잠김 확인 |
| 맥 | `PointerInjector.swift` | 터치를 마우스 동작 순서로 바꾸고 이벤트 보내기 |
| 아이패드 | `VideoRenderer.swift` | 압축 풀어서 그리기 |
| 아이패드 | `ScreenPickerView.swift`, `ScreenViewer.swift` | 모니터 카드, 전체 화면 보기, 제스처 |

---

## 영상을 실을 통로 고르기

영상은 초당 최대 30장이고, 키프레임(앞 화면 없이 혼자 완성된 한 장)은 수백 KB가 된다. 지금까지 쓰던 JSON 글자 메시지에 그대로 넣기는 어렵다. 후보를 비교했다.

| 방법 | 새 통로 | 크기 | 결과 |
|---|---|---|---|
| JSON에 base64로 넣기 | 없음 | 약 1.33배로 커짐, 글자 변환 비용 | <span style="color:#e5534b">**안 씀**</span> |
| 영상용 연결을 따로 열기(UDP 등) | 생김 | 그대로 | <span style="color:#e5534b">**안 씀**</span> (인증을 또 만들어야 함) |
| 같은 WebSocket의 바이너리 메시지 | 없음 | 그대로 + 봉인 36바이트 | <span style="color:#2e9e4f">**채택**</span> |

---

### 글자 메시지와 바이너리 메시지

WebSocket 메시지는 두 종류다. 글자 메시지는 사람이 읽는 글자(UTF-8)만 담을 수 있고, 지금까지 쓴 JSON이 이쪽이다. 바이너리 메시지는 0~255 사이 바이트를 아무거나 그대로 담는다. 압축된 영상은 글자가 아니라 바이트 덩어리라서, 글자 메시지에 넣으려면 2편의 base64처럼 글자로 바꿔야 하고 그만큼 커진다.

![글자 메시지에 영상을 넣으면 base64 글자로 바꿔야 해서 약 1.33배 커지고, 바이너리 메시지는 영상 바이트를 그대로 싣고 봉인 36바이트만 더 붙는다](/assets/images/upload/touchdeck-text-vs-binary.png)

WebSocket은 한 연결에서 글자 메시지와 바이너리 메시지를 섞어 보낼 수 있다(RFC 6455의 opcode). 그래서 허락받은 그 연결에 바이너리 메시지만 추가했다. 나중에 붙일 ESP32는 글자 메시지만 쓰니까 JSON 형식은 하나도 안 바뀐다.

`WebSocketChannel`은 지금까지 글자만 받았는데, 바이너리도 받고 보내게 했다.

```swift
// WebSocketChannel.swift (DeckKit)
/// onSent: 네트워크로 다 넘어간 뒤(또는 실패 뒤) 불린다. 밀린 프레임 수를 세는 데 쓴다.
public func sendBinary(_ data: Data, onSent: (@Sendable () -> Void)? = nil) {
    let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
    let context = NWConnection.ContentContext(identifier: "binary", metadata: [meta])
    connection.send(content: data, contentContext: context, isComplete: true,
                    completion: .contentProcessed { [weak self] error in
                        onSent?()
                        if error != nil { self?.connection.cancel() }
                    })
}

// 받는 쪽 (receiveNext 안)
if let content, meta?.opcode == .text, let text = String(data: content, encoding: .utf8) {
    self.onText?(text)
} else if let content, meta?.opcode == .binary {
    self.onBinary?(content)
}
```

#### NWConnection으로 바이너리 메시지 보내기

바이너리 하나는 이렇게 보낸다.

1. [`NWProtocolWebSocket.Metadata(opcode:)`](https://developer.apple.com/documentation/network/nwprotocolwebsocket/metadata/init%28opcode:%29){:target="_blank"}로 메시지 정보를 만든다. [`opcode: .binary`](https://developer.apple.com/documentation/network/nwprotocolwebsocket/opcode/binary){:target="_blank"}면 바이너리, `.text`면 글자 메시지다.
2. 그 정보를 [`NWConnection.ContentContext`](https://developer.apple.com/documentation/network/nwconnection/contentcontext){:target="_blank"}(보낼 내용에 붙이는 꼬리표)에 담는다.
3. [`send(content:contentContext:isComplete:completion:)`](https://developer.apple.com/documentation/network/nwconnection/send%28content:contentcontext:iscomplete:completion:%29-5ecuz){:target="_blank"}로 보낸다. `isComplete: true`면 이 내용이 메시지 하나의 끝이다.
4. 완료 방식을 [`.contentProcessed`](https://developer.apple.com/documentation/network/nwconnection/sendcompletion/contentprocessed%28%5F:%29){:target="_blank"}로 주면 내용이 네트워크로 다 넘어갔을 때(또는 실패했을 때) 불린다. 밀린 프레임 수를 줄이는 데 썼다.

`onSent`는 뒤에 나오는 "밀리면 버리기"에서 보내는 중인 프레임 수를 셀 때 쓴다. 기기는 맥에 바이너리를 보낼 일이 없어서, 맥은 바이너리가 오면 그 연결을 바로 끊는다.

---

## 바이너리도 이번 접속 키로 봉인하기

6편에서 만든 글자 봉투는 `{"type":"secure","seq":번호,"box":"…"}` 모양이다. 영상까지 JSON과 base64로 감싸면 위에서 버린 방법과 같아지니까, 바이너리는 겉모양을 따로 만들었다. 앞 8바이트가 번호이고, 그 뒤는 ChaChaPoly 결과 그대로다.

```swift
// SecureSession.swift (DeckKit)
// 영상(바이너리)은 번호를 따로 센다. 확인 값에 "bin|"을 붙여 글자 봉투와 섞어 쓸 수 없게 한다.
private var sentBinarySeq: UInt64 = 0
private var receivedBinarySeq: UInt64 = 0

/// 영상 프레임용. 겉모양: 번호 8바이트(big endian) + ChaChaPoly 결과(nonce 12 + 암호문 + 태그 16).
public mutating func sealBinary(_ body: Data) -> Data {
    sentBinarySeq += 1
    let sealed = try? ChaChaPoly.seal(body, using: sendKey, authenticating: Self.binaryLabel(sentBinarySeq))
    return withUnsafeBytes(of: sentBinarySeq.bigEndian) { Data($0) } + (sealed?.combined ?? Data())
}

public mutating func openBinary(_ data: Data) throws -> Data {
    guard data.count >= 8 + 12 + 16 else { throw OpenError.notSecure }
    let seq = data.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    guard let box = try? ChaChaPoly.SealedBox(combined: data.dropFirst(8)),
          let plain = try? ChaChaPoly.open(box, using: receiveKey, authenticating: Self.binaryLabel(seq)) else {
        throw OpenError.badSignature
    }
    guard seq > receivedBinarySeq else { throw OpenError.replayed }
    receivedBinarySeq = seq
    return plain
}

private static func binaryLabel(_ seq: UInt64) -> Data {
    Data("bin|\(seq)".utf8)
}
```

#### ChaChaPoly와 바이트 번호로 바이너리 봉인하기

봉인하고 여는 과정은 이렇다.

1. 잠그기는 글자 봉투와 같은 [`ChaChaPoly`](https://developer.apple.com/documentation/cryptokit/chachapoly){:target="_blank"}의 `seal`이다. 확인 값에는 `"bin|번호"`를 넣는다.
2. 번호는 [`withUnsafeBytes(of:_:)`](https://developer.apple.com/documentation/swift/withunsafebytes%28of:%5F:%29-3ywhh){:target="_blank"}로 `UInt64`의 `bigEndian`(큰 자리부터) 8바이트를 꺼내 `Data`로 만들어 앞에 붙인다.
3. 여는 쪽은 앞 8바이트를 [`reduce(_:_:)`](https://developer.apple.com/documentation/swift/sequence/reduce%28%5F:%5F:%29){:target="_blank"}로 한 칸씩 밀며(`<< 8`) 이어 붙여 번호로 되돌린다.
4. [`dropFirst(_:)`](https://developer.apple.com/documentation/swift/sequence/dropfirst%28%5F:%29){:target="_blank"}로 번호 8바이트를 뺀 나머지를 상자로 나눠 `open`으로 연다.

번호를 글자 메시지와 따로 세는 이유는, 영상은 맥에서 기기로만 초당 30번씩 가고 글자 메시지는 양쪽으로 가끔 오가기 때문이다. 한 번호를 같이 쓰면 둘이 서로의 번호를 밀어내서 엉킨다.

그런데 번호를 따로 세면 같은 번호(예: 1번)가 글자 쪽과 바이너리 쪽에 하나씩 생긴다. 확인 값(ChaChaPoly의 authenticating 값)이 둘 다 `"1"`이면, 글자 봉투의 `box`를 떼어 앞에 1번을 붙여 바이너리로 보내도 열려 버린다. 그래서 바이너리 쪽 확인 값에만 `"bin|"`을 붙였다. 글자 쪽 확인 값은 6편 그대로 `"1"`이라 ESP32 쪽 계산은 바뀌지 않는다.

이걸 테스트로 확인했다.

```swift
// ScreenBinaryTests.swift (DeckKit)
@Test func textBoxCannotBeReplayedAsBinary() throws {
    // 글자 봉투의 내용을 떼어 바이너리 번호를 붙여도 열리지 않는다 (확인 값에 종류가 들어간다)
    var (ipad, mac) = channels()
    let text = mac.seal(#"{"type":"authorized"}"#)
    let obj = try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    let box = try #require(Data(base64Encoded: obj["box"] as! String))
    let forged = Data([0, 0, 0, 0, 0, 0, 0, 1]) + box
    #expect(throws: SecureChannel.OpenError.badSignature) { try ipad.openBinary(forged) }
}

@Test func binaryAndTextCountSeparately() throws {
    // 글자 메시지가 많이 오가도 영상 번호와 엉키지 않는다 (둘 다 1부터)
    var (ipad, mac) = channels()
    for _ in 0..<3 { _ = try ipad.open(mac.seal(#"{"type":"authorized"}"#)) }
    let sealed = mac.sealBinary(Data([7]))
    #expect(sealed.prefix(8) == Data([0, 0, 0, 0, 0, 0, 0, 1]))
    #expect(try ipad.openBinary(sealed) == Data([7]))
    #expect(try ipad.open(mac.seal(#"{"type":"unauthorized"}"#)) == #"{"type":"unauthorized"}"#)
}
```

#### JSONSerialization으로 봉투 칸 하나 꺼내기

[`JSONSerialization.jsonObject(with:options:)`](https://developer.apple.com/documentation/foundation/jsonserialization/jsonobject%28with:options:%29-8demi){:target="_blank"}는 JSON을 타입 없이 사전(`[String: Any]`)과 배열로 읽는다. 테스트에서 봉투의 `box` 칸 하나만 꺼내 보려고 썼다.

| 바꿔 본 것 | 결과 |
|---|---|
| 맥이 봉인한 프레임을 아이패드가 열기 | <span style="color:#2e9e4f">**열림**</span> |
| 마지막 바이트 하나 바꾸기 | <span style="color:#e5534b">**거절**</span> (badSignature) |
| 앞 8바이트 번호만 바꾸기 | <span style="color:#e5534b">**거절**</span> (badSignature) |
| 같은 프레임 두 번 보내기 | <span style="color:#e5534b">**거절**</span> (replayed) |
| 글자 봉투 내용을 바이너리로 / 바이너리를 글자 봉투로 | <span style="color:#e5534b">**거절**</span> (badSignature) |
| 맥이 보낸 걸 맥에게 되돌려 보내기 | <span style="color:#e5534b">**거절**</span> (방향마다 키가 다름) |

---

## ScreenCaptureKit으로 고른 모니터 하나만 찍기

ScreenCaptureKit은 macOS가 화면을 찍어서 앱에 넘겨주는 프레임워크다. 모니터 하나(`SCDisplay`)를 골라 [`SCStream`](https://developer.apple.com/documentation/screencapturekit/scstream){:target="_blank"}을 만들면, 화면이 바뀔 때마다 한 장씩 콜백으로 준다.

---

### 프레임과 fps란?

영상은 그림을 아주 빠르게 넘겨 보여 주는 것이다. 한 장 한 장을 프레임이라고 하고, 1초에 몇 장을 넘기는지를 fps(frames per second)라고 한다. 30fps면 1/30초마다 새 그림이 나온다. 장수가 많을수록 움직임이 부드럽지만 보낼 양도 늘어난다.

![영상은 1/30초마다 한 장씩 넘기는 그림이라, 창이 조금씩 옮겨 간 그림이 이어지면 움직이는 것처럼 보인다](/assets/images/upload/touchdeck-frames.png)

`SCStream`은 화면이 바뀔 때마다 이 한 장을 앱에 넘겨준다. 화면이 그대로면 새 장이 오지 않는다.

---

### 모니터 하나를 골라 찍기

```swift
// ScreenCapture.swift (맥)
let config = SCStreamConfiguration()
config.width = width            // 기기가 원한 크기로 맥이 미리 줄여서 찍는다
config.height = height
config.minimumFrameInterval = CMTime(value: 1, timescale: 30)   // 초당 30장까지
config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
config.showsCursor = true
config.queueDepth = 4
// 원본 해상도로 찍은 뒤 줄인다 (기본값은 레티나에서 낮은 해상도로 찍을 수 있다)
config.captureResolution = .best
let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: self)
try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
try await stream.startCapture()
```

#### SCStream으로 모니터 찍기 시작하기

찍기는 설정, 대상, 흐름, 받을 곳, 시작 순서로 만든다.

1. [`SCStreamConfiguration`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration){:target="_blank"}에 찍는 방법을 담는다(아래 표).
2. [`SCContentFilter(display:excludingWindows:)`](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28display:excludingwindows:%29){:target="_blank"}로 무엇을 찍을지 정한다. 모니터 하나를 통째로, 뺄 창 없이.
3. [`SCStream(filter:configuration:delegate:)`](https://developer.apple.com/documentation/screencapturekit/scstream/init%28filter:configuration:delegate:%29){:target="_blank"}로 찍기 흐름을 만든다. `delegate`는 멈췄을 때 알림을 받을 곳이다.
4. [`addStreamOutput(_:type:sampleHandlerQueue:)`](https://developer.apple.com/documentation/screencapturekit/scstream/addstreamoutput%28%5F:type:samplehandlerqueue:%29){:target="_blank"}로 찍은 장을 받을 곳과 큐를 정한다. `.screen`은 화면, `.audio`는 소리다.
5. [`startCapture(completionHandler:)`](https://developer.apple.com/documentation/screencapturekit/scstream/startcapture%28completionhandler:%29){:target="_blank"}로 시작한다. `try await`로 부르면 시작될 때까지 기다리고, 화면 기록 권한이 없으면 오류를 던진다.

| API | 하는 일 |
|---|---|
| `width`, `height` | 찍을 크기. 기기가 원한 크기로 맥이 미리 줄여서 찍는다 |
| [`minimumFrameInterval`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/minimumframeinterval){:target="_blank"} | 장 사이 최소 간격. [`CMTime(value:timescale:)`](https://developer.apple.com/documentation/coremedia/cmtime/init%28value:timescale:%29){:target="_blank"}(`value / timescale`초)로 1/30초를 줬다 |
| [`pixelFormat`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/pixelformat){:target="_blank"} | 픽셀을 담는 모양. `420YpCbCr8BiPlanarVideoRange`는 밝기와 색을 나눠 담는 영상용 형식이라 H.264 압축기에 바로 넣을 수 있다 |
| `showsCursor` | 마우스 커서를 같이 찍을지 |
| [`queueDepth`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/queuedepth){:target="_blank"} | 압축이 밀릴 때 쌓아 둘 수 있는 장 수 |
| [`captureResolution`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/captureresolution){:target="_blank"} | 찍는 해상도. `.best`는 레티나 실제 픽셀로 찍은 뒤 줄인다 |

- 크기는 기기가 정한다. 아이패드와 아이폰은 자기 화면의 실제 픽셀 긴 변(11인치 아이패드는 2388)을 보내고, 맥은 모니터 비율을 지켜 줄인다. 3440×1440 울트라와이드는 2388×1000이 된다.
- 픽셀 형식은 압축기가 바로 먹는 YUV(420) 형식으로 받는다. RGB로 받으면 압축 전에 한 번 더 바꿔야 한다.
- 커서도 같이 찍는다. 아이패드에서 지금 마우스가 어디 있는지 보여야 끌기가 편하다.

화면이 그대로면 ScreenCaptureKit은 "바뀐 것 없음" 상태의 빈 프레임을 준다. 이건 압축하지 않고 넘긴다.

```swift
func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    // 화면이 그대로면 "변화 없음" 프레임이 온다. 실제로 그린 프레임만 압축한다
    guard type == .screen, Self.isComplete(sampleBuffer), let frame = sampleBuffer.imageBuffer else { return }
    lastFrame = frame
    encode(frame)
}

private static func isComplete(_ sample: CMSampleBuffer) -> Bool {
    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let raw = attachments.first?[.status] as? Int else { return false }
    return SCFrameStatus(rawValue: raw) == .complete
}
```

#### 찍힌 장 받아서 새 장만 고르기

한 장이 찍힐 때마다 이렇게 처리한다.

1. [`stream(_:didOutputSampleBuffer:of:)`](https://developer.apple.com/documentation/screencapturekit/scstreamoutput/stream%28%5F:didoutputsamplebuffer:of:%29){:target="_blank"}(`SCStreamOutput`의 함수)가 [`CMSampleBuffer`](https://developer.apple.com/documentation/coremedia/cmsamplebuffer){:target="_blank"}로 불린다. `CMSampleBuffer`는 영상이나 소리 한 덩어리와 시간, 꼬리표를 함께 담는 상자이고, `imageBuffer`가 픽셀(`CVPixelBuffer`)이다.
2. [`CMSampleBufferGetSampleAttachmentsArray(_:createIfNecessary:)`](https://developer.apple.com/documentation/coremedia/cmsamplebuffergetsampleattachmentsarray%28%5F:createifnecessary:%29){:target="_blank"}로 상자에 붙은 꼬리표를 꺼낸다.
3. 꼬리표의 `.status`를 [`SCFrameStatus`](https://developer.apple.com/documentation/screencapturekit/scframestatus){:target="_blank"}로 읽어 `.complete`(새로 그린 장)일 때만 압축한다. `.idle`은 화면이 그대로라 새 내용이 없다.

`lastFrame`에 마지막 화면을 들고 있는 이유가 있다. 맥 화면이 가만히 있으면 새 프레임이 안 오는데, 그때 아이패드가 화면을 처음 열면 받을 게 없다. 그래서 키프레임 요청이 오면 마지막 화면을 다시 압축해서 보낸다.

---

### 포인트와 픽셀이란?

픽셀은 화면에서 실제로 빛나는 작은 점이다. 포인트는 앱이 화면 위 크기를 잴 때 쓰는 단위다. 레티나 화면은 같은 크기에 점을 두 배씩 촘촘히 넣어서, 1포인트가 가로세로 2픽셀(점 4개)이다. 앱은 포인트로 그리고, 화면은 그걸 픽셀로 바꿔 또렷하게 보여 준다.

![레티나가 아닌 화면은 1포인트가 1픽셀이고, 레티나 화면은 1포인트가 2×2픽셀이다. 맥북은 1512포인트지만 픽셀은 3024개다](/assets/images/upload/touchdeck-points-pixels.png)

화면을 찍을 때는 포인트가 아니라 픽셀 수만큼 찍어야 원래 선명함이 남는다. 포인트 수만큼만 찍으면 점을 절반으로 줄여 찍은 셈이라 작은 글자가 뭉개진다.

---

### 실기기에서 글자가 흐릿했던 이유

처음 실기기에서 보니 글자가 살짝 흐릿했다. 화질을 깎는 곳이 세 군데 있었다.

| 원인 | 고친 것 |
|---|---|
| 아이패드가 긴 변을 1920으로 고정해서 달라고 했다. 11인치 화면은 2388픽셀이라 받은 영상을 다시 늘려 보여줬다 | 기기 화면의 실제 픽셀 크기(`UIScreen.nativeBounds`)를 보낸다 |
| "모니터보다 크게 찍지 않기"를 포인트 기준으로 계산했다. 레티나 맥북은 1512포인트지만 픽셀은 3024라 절반 해상도로 찍혔다 | `CGDisplayCopyDisplayMode`의 `pixelWidth`/`pixelHeight` 기준으로 맞추고, `captureResolution = .best`로 찍는다 |
| 비트레이트가 글자 많은 화면에 비해 빠듯했다 | 픽셀당 0.2비트로 올리고 25Mbps에서 멈춘다 |

```swift
// ScreenCapture.swift (맥)
// 포인트가 아니라 실제 픽셀 기준으로 맞춘다. 레티나 맥북은 1512포인트지만 픽셀은 3024라 절반으로 찍으면 흐리다
let mode = CGDisplayCopyDisplayMode(displayId)
let pixels = (width: mode?.pixelWidth ?? display.width, height: mode?.pixelHeight ?? display.height)
let size = ScreenGeometry.fit(width: pixels.width, height: pixels.height, maxSide: maxSide)
```

#### CGDisplayCopyDisplayMode로 실제 픽셀 수 읽기

[`CGDisplayCopyDisplayMode(_:)`](https://developer.apple.com/documentation/coregraphics/cgdisplaycopydisplaymode%28%5F:%29){:target="_blank"}는 모니터의 지금 화면 모드를 준다. `pixelWidth`, `pixelHeight`가 실제 픽셀 수이고, `width`, `height`는 포인트 수다.

```swift
// DeckClient.swift (iOS)
/// 11인치 아이패드는 2388, 12.9인치는 2732
private var screenPixelLongSide: Int {
    let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    let size = screen?.nativeBounds.size ?? CGSize(width: 1920, height: 1080)
    return Int(max(size.width, size.height))
}
```

#### nativeBounds로 기기 화면 픽셀 읽기

[`connectedScenes`](https://developer.apple.com/documentation/uikit/uiapplication/connectedscenes){:target="_blank"}는 앱이 지금 띄운 장면(창) 목록이고, 그중 `UIWindowScene`의 `screen`이 그 창이 떠 있는 화면이다. 그 화면의 [`nativeBounds`](https://developer.apple.com/documentation/uikit/uiscreen/nativebounds){:target="_blank"}가 실제 픽셀 크기다. 기기를 돌려도 세로 기준으로 주며, 11인치 아이패드는 1668×2388이다.

남는 것도 하나 있다. H.264는 색 정보를 가로세로 절반 해상도로 저장한다(4:2:0). 흰 바탕 검은 글자는 괜찮지만, 빨간 글자처럼 색이 들어간 가는 선은 조금 번진다. 이건 색을 다 담는 HEVC 4:4:4 같은 다른 압축으로 바꿔야 풀린다.

모니터 목록의 미리보기는 [`SCScreenshotManager`](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager){:target="_blank"}로 한 장만 찍는다. 긴 변 320px로 찍어 JPEG로 바꾼다. 목록을 열 때만 찍고, 영상을 보는 동안에는 찍지 않는다.

---

### SCDisplay를 넘기다 만난 오류

처음에는 메인 액터(화면 상태를 바꾸는 쪽)에서 모니터를 찾고, 찾은 `SCDisplay`를 찍기 시작하는 함수에 넘겼다. Swift 6 빌드가 멈췄다.

```
ScreenHost.swift:60:36: error: sending 'target' risks causing data races [#RegionIsolation::SendingRisksDataRace]
```

`SCDisplay`는 여러 스레드에서 같이 써도 된다는 표시(`Sendable`)가 없는 클래스다. 메인 액터에서 찾은 걸 다른 쪽에서 도는 `async` 함수에 넘기면, 두 쪽이 같은 객체를 동시에 만질 수 있다고 본 것이다.

찾기부터 찍기 시작까지를 한 함수 안에서 하도록 옮겼다. 메인 액터에는 모니터 번호(숫자)만 넘기고, 돌아오는 건 스트리머 객체(내부를 큐 하나에서만 만지게 만든 것)다.

```swift
// ScreenCapture.swift (맥)
/// 모니터를 찾아 크기를 정하고 찍기 시작한다. SCDisplay는 여러 스레드에 넘길 수 없어서 찾기부터 여기서 한다.
static func start(displayId: CGDirectDisplayID, maxSide: Int, onPacket: @escaping @Sendable (VideoPacket) -> Void,
                  onStop: @escaping @Sendable () -> Void) async throws -> ScreenStreamer {
    guard let display = try await DisplayCatalog.displays().first(where: { $0.displayID == displayId }) else {
        throw StartError.noDisplay
    }
    let size = ScreenGeometry.fit(width: display.width, height: display.height, maxSide: maxSide)
    let streamer = ScreenStreamer(width: size.width, height: size.height, onPacket: onPacket, onStop: onStop)
    try await streamer.start(display: display)
    return streamer
}
```

#### SCDisplay와 모니터 번호

[`SCDisplay`](https://developer.apple.com/documentation/screencapturekit/scdisplay){:target="_blank"}는 찍을 수 있는 모니터 하나다. `displayID`와 포인트 크기(`width`, `height`)를 갖고, `SCShareableContent`로 목록을 받는다. `displayID`는 [`CGDirectDisplayID`](https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid){:target="_blank"}, 맥이 모니터마다 붙이는 번호다. CoreGraphics 함수들은 이 번호로 모니터를 가리킨다.

`@escaping`은 받은 함수를 나중에 부르려고 들고 있겠다는 표시이고, `@Sendable`은 다른 스레드에서 불려도 안전한 함수라는 표시다. 찍기는 다른 큐에서 돌아서 둘 다 필요했다.

---

## VideoToolbox로 H.264 압축하기

찍은 화면을 그대로 보내면 2388×1000 한 장이 3MB가 넘는다. 맥의 하드웨어 압축기(VideoToolbox)로 H.264 영상으로 만든다. 화면 공유용이라 "늦게 오는 것보다 덜 예쁜 게 낫다" 쪽으로 설정했다.

---

### 압축과 H.264란?

압축은 보내는 양을 줄이는 것이다. 영상 압축은 두 가지를 덜어 낸다. 하나는 사람 눈에 잘 띄지 않는 아주 작은 차이이고, 다른 하나는 앞 장과 똑같은 부분이다. 화면 공유는 대부분 가만히 있고 일부만 바뀌어서 많이 줄어든다. H.264는 이렇게 줄이고 다시 푸는 방법을 정한 약속(코덱) 중 하나다. 오래되고 흔해서 맥과 아이패드 둘 다 전용 칩(하드웨어)으로 빠르게 압축하고 푼다.

![찍은 한 장 그대로는 2388×1000에 약 3.6MB이고, H.264로 압축하면 보통 수십 KB, 키프레임은 수백 KB가 된다](/assets/images/upload/touchdeck-compression.png)

---

### 비트레이트란?

비트레이트는 1초 동안 영상에 쓸 수 있는 데이터 양이다. 압축기에게 주는 예산이라고 보면 된다. 예산이 넉넉하면 덜어 내는 게 적어 또렷하고, 빠듯하면 작은 글자의 가장자리부터 뭉개진다. 대신 예산이 클수록 와이파이가 그만큼 실어 날라야 한다.

![비트레이트는 1초에 쓸 수 있는 데이터 예산이라, 10Mbps처럼 빠듯하면 작은 글자 가장자리가 뭉개지고 25Mbps처럼 넉넉하면 또렷하다](/assets/images/upload/touchdeck-bitrate.png)

---

### 압축기 설정

```swift
// ScreenCapture.swift (맥)
// 지연이 적은 실시간 모드 (B프레임 없음)
let spec = [kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true] as CFDictionary
let status = VTCompressionSessionCreate(allocator: nil, width: Int32(width), height: Int32(height),
                                        codecType: kCMVideoCodecType_H264, encoderSpecification: spec,
                                        imageBufferAttributes: nil, compressedDataAllocator: nil,
                                        outputCallback: nil, refcon: nil, compressionSessionOut: &session)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_ConstrainedHigh_AutoLevel)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2 as CFNumber)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 30 as CFNumber)
VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                     value: Self.bitRate(width: width, height: height) as CFNumber)

/// 글자가 많은 화면이라 넉넉하게(픽셀당 0.2비트 × 30장). 와이파이가 버티게 25Mbps에서 멈춘다
static func bitRate(width: Int, height: Int) -> Int {
    min(Int(Double(width * height) * 30 * 0.2), 25_000_000)
}
```

#### VTCompressionSession 만들고 설정하기

압축기는 만들고 나서 설정을 하나씩 넣는다.

1. [`VTCompressionSessionCreate`](https://developer.apple.com/documentation/videotoolbox/vtcompressionsessioncreate%28allocator:width:height:codectype:encoderspecification:imagebufferattributes:compresseddataallocator:outputcallback:refcon:compressionsessionout:%29){:target="_blank"}로 압축기를 만든다. 크기와 코덱(`kCMVideoCodecType_H264`)을 주고, 만든 압축기는 `&session`에 담긴다. `encoderSpecification`에 [`kVTVideoEncoderSpecification_EnableLowLatencyRateControl`](https://developer.apple.com/documentation/videotoolbox/kvtvideoencoderspecification%5Fenablelowlatencyratecontrol){:target="_blank"}을 넣어 지연이 적은 실시간 모드를 골랐다.
2. [`VTSessionSetProperty`](https://developer.apple.com/documentation/videotoolbox/vtsessionsetproperty%28%5F:key:value:%29){:target="_blank"}로 설정을 하나씩 바꾼다. 넣은 키는 아래와 같다.

| API | 하는 일 |
|---|---|
| [`kVTCompressionPropertyKey_RealTime`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Frealtime){:target="_blank"} | 실시간으로 써야 하니 빨리 내보내라는 표시 |
| [`kVTCompressionPropertyKey_ProfileLevel`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Fprofilelevel){:target="_blank"} | H.264 안에서 쓸 기능 묶음. ConstrainedHigh는 B프레임 없이 화질이 좋은 묶음 |
| [`kVTCompressionPropertyKey_AllowFrameReordering`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Fallowframereordering){:target="_blank"} | 장 순서를 바꿔 압축하기(B프레임)를 막는다. 막아야 찍은 순서대로 바로 나온다 |
| [`kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Fmaxkeyframeintervalduration){:target="_blank"} | 키프레임 사이 최대 시간(초) |
| `kVTCompressionPropertyKey_ExpectedFrameRate` | 1초에 몇 장이 올지 알려 준다 |
| [`kVTCompressionPropertyKey_AverageBitRate`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Faveragebitrate){:target="_blank"} | 초당 평균 비트 수(비트레이트) |

| 설정 | 값 | 이유 |
|---|---|---|
| 저지연 모드 | 켬 | 프레임을 모아 두지 않고 바로 내보낸다 (WWDC21 저지연 압축 세션) |
| 프레임 순서 바꾸기(B프레임) | 끔 | 뒤 프레임을 보고 앞 프레임을 만드는 방식이라 기다림이 생긴다 |
| 키프레임 간격 | 2초 | 중간에 몇 장 잃어도 2초 안에 다시 또렷해진다 |
| 평균 비트레이트 | 가로×세로×30×0.2, 최대 25Mbps | 화면 글자가 뭉개지지 않게 영상보다 넉넉히. 2388×1000이면 약 14Mbps |

H.264 프레임에는 두 종류가 있다. 키프레임은 혼자서 한 장이 완성되고, 나머지는 "앞 장에서 바뀐 부분"만 담는다. 그래서 아이패드가 처음 붙었을 때나 중간에 프레임을 잃었을 때는 키프레임이 와야 다시 그릴 수 있다. 다음 프레임을 키프레임으로 만들라는 옵션이 있다.

```swift
if forceKeyframe {
    properties = [kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue] as CFDictionary
    forceKeyframe = false
}
```

#### 다음 장을 키프레임으로 만들기

[`kVTEncodeFrameOptionKey_ForceKeyFrame`](https://developer.apple.com/documentation/videotoolbox/kvtencodeframeoptionkey%5Fforcekeyframe){:target="_blank"}는 한 장을 압축할 때 넘기는 옵션이다. true를 넣으면 이번 장을 키프레임으로 만든다.

---

### 바이너리 안에 싣는 모양

압축된 프레임을 아이패드가 풀려면, 키프레임일 때 SPS/PPS라는 설정 조각(영상 크기, 압축 방식)이 같이 가야 한다. 이걸 담는 묶음 모양을 정했다.

```
[종류 1바이트: 1=H.264][플래그 1바이트: 1=키프레임]
키프레임이면 [개수 1바이트] + 개수만큼 [길이 2바이트 + SPS 또는 PPS]
그 뒤 나머지 전부가 프레임 데이터
```

```swift
// VideoPacket.swift (DeckKit)
public func encoded() -> Data {
    var out = Data([Self.h264, keyframe ? 1 : 0])
    if keyframe {
        out.append(UInt8(parameterSets.count))
        for set in parameterSets {
            out.append(contentsOf: [UInt8(set.count >> 8), UInt8(set.count & 0xFF)])
            out.append(set)
        }
    }
    out.append(frame)
    return out
}
```

첫 바이트를 종류로 둔 건 나중에 HEVC 같은 다른 압축을 넣을 자리다. 지금 아이패드는 1이 아니면 버린다. 잘린 데이터도 nil로 버리는 테스트를 같이 넣었다.

---

## 밀리면 버리고 키프레임으로 따라잡기

와이파이가 잠깐 느려지면 보낼 프레임이 쌓인다. 쌓인 걸 다 보내면 아이패드 화면이 맥보다 몇 초씩 늦어진다. 화면 공유에서는 옛 화면을 늦게 보는 것보다 몇 장 건너뛰는 게 낫다.

---

### 키프레임과 차이 프레임이란?

압축된 영상의 프레임은 두 종류다. 키프레임(K)은 그 한 장만으로 온전한 그림이 되는 프레임이다. 차이 프레임(P)은 "앞 장에서 어디가 바뀌었는지"만 적은 프레임이라 훨씬 작다. 그래서 영상은 키프레임 하나 뒤에 차이 프레임이 줄줄이 이어진다.

![키프레임 K 뒤에 바뀐 부분만 담은 P가 이어진다. P 하나를 버리면 그 뒤 P들은 기준이 되는 앞 장이 없어 깨지고, 다음 K가 와야 다시 또렷해진다](/assets/images/upload/touchdeck-keyframe.png)

차이 프레임은 앞 장이 있어야 그릴 수 있다. 중간 하나가 빠지면 그 뒤 차이 프레임들은 없는 그림을 기준으로 고치게 돼서 화면이 깨진다. 다음 키프레임이 와야 다시 온전해진다.

---

### 보내는 중인 프레임 세기

그래서 아직 보내는 중인 프레임을 센다. 2개 이상 밀려 있으면 새 프레임을 버린다. 그런데 키프레임이 아닌 프레임은 "앞 장에서 바뀐 부분"이라, 하나를 버리면 그 뒤 프레임들은 없는 앞 장을 기준으로 그려져 화면이 깨진다. 그래서 하나라도 버렸으면 다음 키프레임이 올 때까지 다 버리고, 압축기에 키프레임을 한 번 달라고 한다.

```swift
// VideoPacket.swift (DeckKit)
public struct SendGate: Sendable {
    public let limit: Int
    private var inFlight = 0
    /// 하나라도 버렸으면 키프레임이 올 때까지 다 버린다 (버린 프레임을 참조하는 프레임은 깨져 보인다)
    private var waitingForKeyframe = false
    private var keyframeRequested = false

    /// 이 프레임을 보내도 되면 true (보낸 것으로 센다)
    public mutating func begin(keyframe: Bool) -> Bool {
        if waitingForKeyframe && !keyframe { return false }
        guard inFlight < limit else {
            if !waitingForKeyframe { keyframeRequested = true }
            waitingForKeyframe = true
            return false
        }
        if keyframe { waitingForKeyframe = false }
        inFlight += 1
        return true
    }

    public mutating func finish() {
        inFlight = max(0, inFlight - 1)
    }

    /// 압축기에 다음 프레임을 키프레임으로 달라고 할 때인지. 한 번 읽으면 지운다
    public mutating func takeKeyframeRequest() -> Bool {
        defer { keyframeRequested = false }
        return keyframeRequested
    }
}
```

맥에서는 프레임이 나올 때마다 이걸 거친다. `finish()`는 앞에서 만든 `sendBinary`의 `onSent`에서 부른다.

```swift
// ScreenHost.swift (맥)
guard gate.begin(keyframe: packet.keyframe) else {
    if gate.takeKeyframeRequest() { streamer?.requestKeyframe() }
    return
}
viewer.sendBinary(packet.encoded()) { [weak self] in
    MainActor.assumeIsolated { self?.gate.finish() }
}
```

#### 보내기 완료를 메인에서 세기

[`MainActor.assumeIsolated(_:file:line:)`](https://developer.apple.com/documentation/swift/mainactor/assumeisolated%28%5F:file:line:%29){:target="_blank"}는 "지금 메인 스레드다"라고 알리고 메인 전용 값을 바로 바꾼다. 보내기 완료 알림이 메인 큐에서 오기 때문에 쓸 수 있다.

---

### #expect 안에서 값을 바꾸는 함수를 부르다 만난 오류

`SendGate` 테스트를 처음엔 이렇게 썼다.

```swift
var gate = SendGate(limit: 2)
#expect(gate.begin(keyframe: true))
```

빌드가 실패했다.

```
macro expansion #expect:2:6: error: cannot use mutating member on immutable value: '$0' is immutable
```

`#expect`는 매크로라서 안의 식을 펼쳐서 다시 쓴다. `a == b` 같은 비교는 양쪽 값을 따로 꺼내 보여주려고, `gate.begin(...)` 같은 호출은 `gate`를 클로저 인자(`$0`)로 받아서 부르는 모양으로 바꾼다. 클로저 인자는 상수라서 값을 바꾸는 `mutating` 함수를 부를 수 없다.

결과를 먼저 배열에 모아 두고, 배열을 한 번에 비교했다. 순서가 중요한 테스트라 오히려 읽기도 쉬워졌다.

```swift
// ScreenBinaryTests.swift (DeckKit)
@Test func sendGateWaitsForKeyframeAfterDrop() {
    // 버린 프레임을 참조하는 프레임은 깨져 보인다. 키프레임이 올 때까지 다 버리고, 압축기에 키프레임을 한 번 요청한다
    var gate = SendGate(limit: 1)
    var steps: [Bool] = []
    steps.append(gate.begin(keyframe: true))
    steps.append(gate.begin(keyframe: false))
    steps.append(gate.takeKeyframeRequest())
    steps.append(gate.takeKeyframeRequest())
    gate.finish()
    steps.append(gate.begin(keyframe: false))
    steps.append(gate.begin(keyframe: true))
    gate.finish()
    steps.append(gate.begin(keyframe: false))
    #expect(steps == [true, false, true, false, false, true, true])
}
```

---

## AVSampleBufferDisplayLayer로 아이패드에 바로 그리기

아이패드는 받은 묶음을 하드웨어 디코더로 풀어 그린다. `AVSampleBufferDisplayLayer`에 압축된 프레임을 넣으면 풀기와 그리기를 같이 해 준다. 따로 디코더 세션을 만들지 않아도 된다.

키프레임에 실려 온 SPS/PPS로 영상 형식을 만들고, 프레임 데이터를 `CMSampleBuffer`로 감싸 넣는다. SPS/PPS는 영상 크기와 압축 설정을 적은 머리말이라, 이게 있어야 디코더가 뒤따르는 프레임을 풀 수 있다.

```swift
// VideoRenderer.swift (iOS)
func enqueue(_ packet: VideoPacket) -> Bool {
    let renderer = layer.sampleBufferRenderer
    if renderer.status == .failed || renderer.requiresFlushToResumeDecoding {
        renderer.flush()
        format = nil
    }
    if packet.keyframe, let made = Self.makeFormat(packet.parameterSets) {
        format = made
    }
    guard let format, let sample = Self.makeSample(packet.frame, format: format) else { return false }
    renderer.enqueue(sample)
    return renderer.status != .failed
}

private static func makeFormat(_ sets: [Data]) -> CMVideoFormatDescription? {
    // 생략: SPS/PPS를 포인터 배열로 옮기기
    let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
        allocator: kCFAllocatorDefault, parameterSetCount: sets.count,
        parameterSetPointers: buffers.map { UnsafePointer($0) }, parameterSetSizes: sets.map(\.count),
        nalUnitHeaderLength: 4, formatDescriptionOut: &format)
    return status == noErr ? format : nil
}
```

#### AVSampleBufferDisplayLayer에 프레임 넣기

받은 묶음 하나를 이렇게 그린다.

1. [`AVSampleBufferDisplayLayer`](https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer){:target="_blank"}는 압축된 영상 상자를 풀고 화면에 그리는 레이어이고, 실제로 풀고 그리는 쪽이 [`sampleBufferRenderer`](https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer/samplebufferrenderer){:target="_blank"}([`AVSampleBufferVideoRenderer`](https://developer.apple.com/documentation/avfoundation/avsamplebuffervideorenderer){:target="_blank"})다.
2. 풀기가 멈춰 비워야 다시 시작할 수 있는 상태([`requiresFlushToResumeDecoding`](https://developer.apple.com/documentation/avfoundation/avsamplebuffervideorenderer/requiresflushtoresumedecoding){:target="_blank"}, 앱이 뒤로 갔다 오면 생긴다)거나 실패 상태면 `flush()`로 비운다.
3. 키프레임이면 [`CMVideoFormatDescriptionCreateFromH264ParameterSets`](https://developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreatefromh264parametersets%28allocator:parametersetcount:parametersetpointers:parametersetsizes:nalunitheaderlength:formatdescriptionout:%29){:target="_blank"}로 SPS/PPS에서 영상 형식(`CMVideoFormatDescription`)을 만든다. `nalUnitHeaderLength: 4`는 프레임 조각마다 앞에 4바이트 길이가 붙어 있다는 뜻이다.
4. 프레임을 `CMSampleBuffer`로 감싸 `enqueue(_:)`로 넣는다.

`noErr`는 C로 된 함수들이 "성공"을 알리는 0이다.

`nalUnitHeaderLength: 4`는 맥의 압축기가 내놓는 프레임 데이터가 조각마다 앞에 4바이트 길이를 붙인 모양(AVCC)이라서다. 맥이 받은 그대로 보내니까 아이패드도 그대로 넣으면 된다.

프레임마다 "도착하면 바로 보여주기" 표시를 붙였다. 재생 시간을 따로 맞추지 않으니, 늦게 온 프레임을 기다렸다 보여주는 일이 없다.

```swift
CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                     Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
```

#### 받자마자 보여 주는 꼬리표 붙이기

[`kCMSampleAttachmentKey_DisplayImmediately`](https://developer.apple.com/documentation/coremedia/kcmsampleattachmentkey%5Fdisplayimmediately){:target="_blank"}를 상자에 붙이면 시간을 따지지 않고 풀자마자 바로 보여 준다. 꼬리표 사전은 C로 된 사전이라 [`CFDictionarySetValue`](https://developer.apple.com/documentation/corefoundation/cfdictionarysetvalue%28%5F:%5F:%5F:%29){:target="_blank"}로 넣고, 키와 값은 [`Unmanaged`](https://developer.apple.com/documentation/swift/unmanaged){:target="_blank"}의 `passUnretained(_:).toOpaque()`로 넘긴다. Swift가 메모리를 관리하지 않는 C 쪽에 소유권을 넘기지 않고 주소만 주는 방법이다.

`enqueue`가 false를 돌려주면(아직 키프레임이 없거나 풀기에 실패하면) 맥에 키프레임을 달라고 한다. 같은 요청이 쏟아지지 않게 0.5초에 한 번까지만 보낸다. 화면 보기가 시작됐다는 답(`screenStarted`)을 받은 직후에도 한 번 요청한다.

---

## 터치 위치를 맥 좌표로 바꾸는 계산

아이패드에서 누른 곳이 맥의 어디인지 계산하는 부분이 이번에 가장 틀리기 쉬운 곳이었다. 세 가지가 겹친다.

1. 울트라와이드 화면을 4:3 아이패드에 넣으면 위아래에 빈 띠(레터박스)가 생긴다.
2. 핀치로 확대하고 옮긴 상태일 수 있다.
3. 맥 모니터 3개는 맥 전체 좌표에서 각자 자리가 있다. 주 모니터 왼쪽에 놓인 모니터는 x가 음수에서 시작한다.

---

### 레터박스란?

비율이 다른 영상을 화면에 넣을 때, 잘리지 않게 비율을 지키며 꽉 차게 넣으면 남는 쪽이 빈 띠가 된다. 극장 영화를 TV로 볼 때 위아래에 생기는 검은 띠가 이것이고, 레터박스라고 부른다. 21:9 울트라와이드를 4:3 아이패드에 넣으면 위아래가 넓게 빈다.

![4:3 아이패드 화면에 21:9 울트라와이드 영상을 비율을 지키며 넣으면 위아래가 빈 띠가 되고, 빈 띠를 누르면 맥에는 아무것도 보내지 않는다](/assets/images/upload/touchdeck-letterbox.png)

---

### 맥 전체 좌표란?

맥은 모니터가 여러 개여도 큰 도화지 하나로 본다. 시스템 설정의 디스플레이 배치 그대로 모니터들이 이 도화지 위에 놓이고, 주 모니터의 왼쪽 위가 (0, 0)이다. 그래서 주 모니터 왼쪽에 놓인 모니터는 x가 음수에서 시작한다. 마우스를 어느 모니터로 옮기든 이 하나의 좌표로 말한다.

![주 모니터 왼쪽 위가 (0, 0)이고, 왼쪽 모니터는 x가 -1512부터, 오른쪽 모니터는 주 모니터 너비부터 시작한다](/assets/images/upload/touchdeck-global-coords.png)

---

### 두 단계로 나눈 계산

그래서 두 단계로 나눴다. 아이패드는 터치를 "영상 안에서 0~1 위치"로 바꿔 보내고, 맥은 그 0~1을 고른 모니터 자리에 맞춰 맥 좌표로 바꾼다. 0~1로 주고받으니 영상 크기나 레티나 배율이 중간에 끼지 않는다.

```swift
// ScreenGeometry.swift (DeckKit)
/// 터치 위치 → 영상 안 0~1. 확대는 화면 가운데 기준으로 zoom배, 그다음 offset만큼 옮긴 상태.
/// 빈 띠를 누르면 nil (맥에 아무것도 보내지 않는다).
public static func normalized(touch: CGPoint, view: CGSize, video: CGSize,
                              zoom: CGFloat = 1, offset: CGSize = .zero) -> CGPoint? {
    let rect = videoRect(video: video, in: view)
    guard rect.width > 0, rect.height > 0, zoom > 0 else { return nil }
    // 확대와 이동을 되돌려서 확대 전 화면 위치를 구한다
    let center = CGPoint(x: view.width / 2, y: view.height / 2)
    let x = center.x + (touch.x - offset.width - center.x) / zoom
    let y = center.y + (touch.y - offset.height - center.y) / zoom
    guard x >= rect.minX, x <= rect.maxX, y >= rect.minY, y <= rect.maxY else { return nil }
    return CGPoint(x: (x - rect.minX) / rect.width, y: (y - rect.minY) / rect.height)
}

/// 영상 안 0~1 → 맥 전체 좌표(포인트). display는 CGDisplayBounds 값이라 왼쪽/위 모니터는 음수에서 시작한다.
/// 끝(1.0)은 옆 모니터 첫 칸이 되지 않게 마지막 칸에 둔다.
public static func global(normalized p: CGPoint, display: CGRect) -> CGPoint {
    let nx = min(max(p.x, 0), 1), ny = min(max(p.y, 0), 1)
    return CGPoint(x: min(display.minX + nx * display.width, display.maxX - 1),
                   y: min(display.minY + ny * display.height, display.maxY - 1))
}
```

#### 위치와 크기 타입

[`CGPoint, CGSize, CGRect`](https://developer.apple.com/documentation/corefoundation/cgrect){:target="_blank"}는 위치(x, y), 크기(가로, 세로), 사각형(위치 + 크기)이다. 사각형은 `minX`, `maxX`, `width`처럼 가장자리와 크기를 바로 꺼낼 수 있어서 영상 자리 계산에 그대로 썼다.

확대를 되돌리는 식은 아이패드가 영상에 거는 변환의 거꾸로다. 아이패드는 영상 뷰에 "가운데 기준 zoom배 확대 후 offset만큼 이동"을 건다.

```swift
// ScreenViewer.swift (iOS)
view.videoView.transform = CGAffineTransform(translationX: offset.width, y: offset.height).scaledBy(x: zoom, y: zoom)
```

#### CGAffineTransform으로 확대와 이동 걸기

[`CGAffineTransform`](https://developer.apple.com/documentation/corefoundation/cgaffinetransform){:target="_blank"}는 옮기기, 늘리기, 돌리기를 담은 변환 값이다. 뷰의 `transform`에 넣으면 그대로 그려진다. [`scaledBy(x:y:)`](https://developer.apple.com/documentation/corefoundation/cgaffinetransform/scaledby%28x:y:%29){:target="_blank"}는 지금 변환에 늘리기를 덧붙인 새 변환이고, 덧붙인 것이 먼저 적용된다.

`CGAffineTransform`은 뒤에 붙인 것(`scaledBy`)이 먼저 적용된다. 그래서 이 줄은 "확대 먼저, 이동 나중"이고, 계산 함수는 "이동 먼저 빼고, 확대 나중에 나누기"로 되돌린다.

맥 좌표는 [`CGDisplayBounds`](https://developer.apple.com/documentation/coregraphics/cgdisplaybounds%28%5F:%29){:target="_blank"}가 주는 포인트 단위다. 레티나 모니터도 포인트로 주니까 2배 같은 배율을 따로 곱할 필요가 없다. 마우스 이벤트(`CGEvent`)도 같은 포인트 좌표를 쓴다.

테스트로 박은 경우들이다.

| 경우 | 넣은 값 | 기대 |
|---|---|---|
| 정사각형 영상을 2:1 화면에 | (600, 200) 터치 | (0.25, 0.25) |
| 옆 빈 띠 터치 | (100, 400) | nil |
| 가운데 기준 2배 확대 | 화면 왼쪽 위 끝 | (0.25, 0.25) |
| 2배 확대 + 오른쪽으로 500 이동 | 화면 왼쪽 끝 | (0, 0.5) |
| 왼쪽 모니터 (-1512, 200, 1512×982) | (0.5, 0.5) | (-756, 691) |
| 끝 1.0 | (1, 1) on 1920×1080 | (1919, 1079) |

---

### 확대 중에 옮길 수 있는 만큼

확대한 영상을 너무 옮기면 가장자리 밖의 빈 곳이 보인다. 확대된 만큼의 절반까지만 옮길 수 있게 막았다. 2배 확대면 화면 너비의 절반까지다.

```swift
public static func clampOffset(_ offset: CGSize, zoom: CGFloat, view: CGSize) -> CGSize {
    let maxX = max(0, view.width * (zoom - 1) / 2)
    let maxY = max(0, view.height * (zoom - 1) / 2)
    return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
}
```

---

### 영상 크기 정하기

기기가 보낸 긴 변 값을 그대로 믿지 않는다. 0이나 아주 큰 값이 와도 320~3840 안으로 자르고, 모니터보다 크게 키우지는 않는다. H.264 압축기는 짝수 크기를 좋아해서 짝수로 맞춘다.

```swift
public static func fit(width: Int, height: Int, maxSide requested: Int) -> (width: Int, height: Int) {
    let limit = Double(min(max(requested, minSide), maxSide))
    let scale = min(1, limit / Double(max(width, height, 1)))
    func even(_ v: Double) -> Int { max(2, Int((v / 2).rounded()) * 2) }
    return (even(Double(width) * scale), even(Double(height) * scale))
}
```

---

## 탭과 끌기를 마우스 동작으로 바꾸기

아이패드는 터치 종류와 0~1 위치만 보낸다. 메시지는 다른 JSON처럼 `type`과 같은 단계에 값을 펼쳐 둔다.

```json
{"dx":0,"dy":0,"kind":"click","type":"pointer","x":0.25,"y":0.75}
```

| 아이패드에서 | 보내는 kind | 맥에서 |
|---|---|---|
| 탭 | click | 그 자리로 이동 → 왼쪽 누름 → 뗌 |
| 빠르게 두 번 탭 | click 두 번 | 두 번째를 더블클릭으로 |
| 두 손가락 탭 | rightClick | 오른쪽 누름 → 뗌 |
| 한 손가락이나 두 손가락으로 쓸기 | scroll | 그 자리로 이동 → 스크롤 |
| 길게 눌렀다 끌기 | down → move… → up | 왼쪽 누름 → 끌기 → 뗌 (블록 선택, 창 옮기기) |
| 핀치 | 보내지 않음 | 아이패드 화면만 확대 |

맥은 터치를 바로 이벤트로 만들지 않고, 먼저 "어떤 마우스 동작을 어떤 순서로" 할지만 정한다. 이벤트를 실제로 보내지 않으니 테스트할 수 있다.

```swift
// PointerInjector.swift (맥)
struct PointerPlan {
    enum Step: Equatable {
        case move(CGPoint)
        /// clicks: 맥이 더블클릭을 알아보는 값(1, 2, 3)
        case leftDown(CGPoint, clicks: Int)
        case leftDragged(CGPoint)
        case leftUp(CGPoint, clicks: Int)
        case rightDown(CGPoint)
        case rightUp(CGPoint)
        case scroll(dx: Double, dy: Double)
    }

    static let doubleClickInterval: TimeInterval = 0.5
    static let doubleClickDistance: CGFloat = 8

    mutating func steps(for event: PointerEvent, display: CGRect, now: Date) -> [Step] {
        let p = ScreenGeometry.global(normalized: CGPoint(x: event.x, y: event.y), display: display)
        switch event.kind {
        case .click:
            let count = clickCount(at: p, now: now)
            lastClick = (p, now, count)
            return [.move(p), .leftDown(p, clicks: count), .leftUp(p, clicks: count)]
        // 생략: 우클릭, 누름/움직임/뗌, 스크롤
        }
    }
}
```

더블클릭은 따로 신경 써야 했다. 사람이 마우스로 두 번 누르면 macOS가 시간을 보고 두 번째 클릭에 "두 번째"라는 값을 붙인다. 그런데 프로그램이 만든 클릭 이벤트에는 그 값을 직접 넣어야 한다. 안 넣으면 빠르게 두 번 탭해도 맥은 클릭 두 번으로만 알아서 파일이 안 열린다. 그래서 0.5초 안에 8포인트 안쪽을 다시 누르면 횟수를 올려서 `mouseEventClickState`에 넣는다.

```swift
case .leftDown(let p, let clicks):
    event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)
    event?.setIntegerValueField(.mouseEventClickState, value: Int64(clicks))
```

#### CGEvent로 마우스 누르기와 더블클릭

[`CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)`](https://developer.apple.com/documentation/coregraphics/cgevent/init%28mouseeventsource:mousetype:mousecursorposition:mousebutton:%29){:target="_blank"}는 마우스 이벤트를 만든다. `.leftMouseDown`, `.leftMouseUp`, `.leftMouseDragged`, `.mouseMoved` 같은 종류와 맥 전체 좌표(포인트)를 준다. [`setIntegerValueField(_:value:)`](https://developer.apple.com/documentation/coregraphics/cgevent/setintegervaluefield%28%5F:value:%29){:target="_blank"}는 이벤트의 숫자 칸 하나를 바꾸는데, `.mouseEventClickState`에 2를 넣으면 맥이 더블클릭으로 알아본다.

끌던 중에 화면 보기가 끊기면 맥 마우스 버튼이 눌린 채로 남을 수 있다. 끊을 때 눌린 버튼이 있으면 떼는 동작을 한 번 보낸다.

```swift
/// 화면 보기가 끊길 때 눌린 버튼을 뗀다 (맥 마우스가 눌린 채로 남지 않게)
mutating func release() -> [Step] {
    guard let held else { return [] }
    self.held = nil
    return [.leftUp(held, clicks: 1)]
}
```

이벤트를 보내는 건 숫자 키패드(6편)와 같은 손쉬운 사용 권한을 쓴다. 권한이 없으면 화면은 보이지만 조작은 안 되고, 아이패드 아래에 켜는 곳을 알려준다.

---

### 한 손가락은 스크롤, 길게 눌러야 끌기

처음에는 맥 트랙패드처럼 한 손가락으로 끌면 마우스를 누른 채 끌기, 두 손가락으로 쓸면 스크롤로 나눴다. 실기기에서 써 보니 아이패드에서는 한 손가락으로 미는 게 "내용을 내리는" 동작으로 손에 익어 있어서, 내리려고 밀면 글자가 블록으로 잡혔다.

그래서 한 손가락 쓸기도 스크롤로 바꾸고, 끌기는 길게 누른 뒤에만 시작하게 했다. 원격 데스크톱 앱들의 터치 모드도 이렇게 나눈다. 끌기는 스크롤보다 훨씬 덜 쓰니까, 끌기를 시작할 때만 잠깐 기다리게 하는 쪽이 손해가 적다.

```swift
// ScreenViewer.swift (iOS)
// 한 손가락으로 쓸면 스크롤. 아이패드에서 손에 익은 동작이라 이쪽을 기본으로 한다
let oneScroll = UIPanGestureRecognizer(target: self, action: #selector(oneFingerScroll(_:)))
oneScroll.minimumNumberOfTouches = 1
oneScroll.maximumNumberOfTouches = 1
// 0.4초 가만히 대고 있으면 끌기. 그 전에 10포인트 넘게 움직이면 스크롤로 간다
let drag = UILongPressGestureRecognizer(target: self, action: #selector(drag(_:)))
drag.minimumPressDuration = 0.4
drag.allowableMovement = 10
```

#### UIKit 제스처로 스크롤과 끌기 나누기

[`UIPanGestureRecognizer`](https://developer.apple.com/documentation/uikit/uipangesturerecognizer){:target="_blank"}는 끄는 손가락을 알아보는 UIKit 제스처다. `minimumNumberOfTouches`, `maximumNumberOfTouches`로 손가락 수를 정해 한 손가락 스크롤로 썼다. [`UILongPressGestureRecognizer`](https://developer.apple.com/documentation/uikit/uilongpressgesturerecognizer){:target="_blank"}는 길게 누르기다. `minimumPressDuration`(몇 초)과 `allowableMovement`(그동안 움직여도 되는 거리)를 정하고, 잡힌 뒤에는 끌어도 계속 이어진다. 제스처가 일어나면 부를 함수는 [`#selector`](https://developer.apple.com/documentation/objectivec/selector){:target="_blank"}로 가리키고, 그 함수에는 `@objc`를 붙인다.

두 제스처는 같이 받지 않게 둬서, 먼저 알아챈 쪽이 이긴다. 손가락을 대고 가만히 0.4초가 지나면 길게 누르기가 먼저 시작되고, 그 전에 10포인트 넘게 움직이면 길게 누르기가 실패하고 스크롤이 시작된다.

길게 누르기는 손가락이 움직여도 끝나지 않고 `.changed`로 계속 위치를 준다. 그래서 끌기를 이걸로 바로 만들 수 있다. 잡힌 순간 손가락 자리에 동그라미를 띄운다. 아이패드는 진동이 없어서, 끌기가 잡혔다는 걸 눈으로 보여줘야 한다.

```swift
/// 길게 눌러서 잡은 뒤 끌기: 누른 자리에서 왼쪽 버튼을 누르고, 끄는 동안 움직이고, 떼면 놓는다
@objc private func drag(_ g: UILongPressGestureRecognizer) {
    let here = g.location(in: view)
    switch g.state {
    case .began:
        guard let start = normalized(here) else { return }
        lastDragPoint = start
        send(.down, start)
        view?.showRing(at: here)
    case .changed:
        guard lastDragPoint != nil else { return }
        view?.moveRing(to: here)
        guard let p = normalized(here) else { return }
        lastDragPoint = p
        if throttled() { send(.move, p) }
    case .ended, .cancelled, .failed:
        guard let last = lastDragPoint else { return }
        let p = normalized(here) ?? last
        send(.move, p)
        send(.up, p)
        lastDragPoint = nil
        view?.hideRing()
    default:
        break
    }
}
```

#### 제스처 위치와 단계 읽기

[`location(in:)`](https://developer.apple.com/documentation/uikit/uigesturerecognizer/location%28in:%29){:target="_blank"}는 제스처가 일어난 자리를 뷰 안 좌표로 준다. [`state`](https://developer.apple.com/documentation/uikit/uigesturerecognizer/state-swift.property){:target="_blank"}는 단계로, `.began`(시작), `.changed`(움직이는 중), `.ended`(끝), `.cancelled`(취소)를 나눠 마우스 누름, 끌기, 뗌으로 바꿨다.

---

### 두 손가락은 스크롤인지 확대인지 먼저 정하기

두 손가락 쓸기(스크롤)와 핀치(확대)는 둘 다 두 손가락이라 같이 들어온다. 둘을 같이 받게 해 두고, 처음 움직임으로 하나를 고른다. 손가락 사이가 8% 넘게 벌어지거나 좁아지면 확대, 사이는 그대로인데 12포인트 넘게 같이 움직이면 스크롤이다. 한 번 정하면 손을 뗄 때까지 바꾸지 않는다.

```swift
// ScreenViewer.swift (iOS)
/// 두 손가락 제스처를 시작할 때 정한다: 벌리면 확대(맥에 안 보냄), 그냥 쓸면 스크롤
private enum TwoFinger { case undecided, zoom, scroll }

// 핀치 쪽
if twoFinger == .undecided, abs(g.scale - 1) > 0.08 { twoFinger = .zoom }

// 두 손가락 쓸기 쪽
if twoFinger == .undecided, hypot(t.x, t.y) > 12, abs(pinchScale - 1) <= 0.08 { twoFinger = .scroll }
switch twoFinger {
case .zoom:
    // 확대하면서 손가락을 옮기면 확대한 영상이 따라 움직인다
    // 생략: offset에 움직인 만큼 더하고 clampOffset
case .scroll:
    pendingScroll.x += delta.x
    pendingScroll.y += delta.y
    if throttled() { flushScroll(at: g.location(in: view)) }
case .undecided:
    break
}
```

#### UIPinchGestureRecognizer로 확대 정도 읽기

[`UIPinchGestureRecognizer`](https://developer.apple.com/documentation/uikit/uipinchgesturerecognizer){:target="_blank"}는 두 손가락 벌리기와 오므리기다. `scale`은 처음 간격에 비해 몇 배인지(1이면 그대로)라서, 8% 넘게 변하면 확대로 정했다.

스크롤 양은 아이패드에서 손가락이 움직인 포인트를 맥 포인트로 바꿔서 보낸다. 3440포인트 모니터가 아이패드에 1200포인트로 보이면 손가락 100포인트는 맥에서 약 287포인트다. 내용이 손가락을 따라오는 느낌이 나게 하려고 이렇게 맞췄다.

움직임(끌기, 스크롤)은 초당 60번까지만 보낸다. 손을 뗄 때는 마지막 위치를 꼭 보낸다.

---

## 누가 맥 화면을 볼 수 있는지

맥 화면은 버튼보다 훨씬 많은 게 보이는 기능이라, 허락한 기기라도 따로 켜야 보게 했다.

- 맥 메뉴바의 허락한 기기마다 "화면 보기 허용" 스위치. 기본은 꺼짐이고, 다시 페어링하면 다시 꺼진다.
- 한 번에 한 기기만 본다.
- 맥이 잠겨 있거나 화면 보호기가 돌고 있으면 화면도 입력도 보내지 않는다. 보는 동안 1초마다 확인해서, 잠기면 바로 멈춘다.
- 누가 보고 있으면 메뉴바 아이콘이 눈 모양으로 바뀌고, 메뉴에 "지금 화면을 보는 중: (기기)"와 "끊기" 버튼이 뜬다.

이 판단은 DeckKit에 순수 함수로 뒀다.

```swift
// Screen.swift (DeckKit)
public enum ScreenAccess {
    /// viewer: 지금 보고 있는 기기 ID. 같은 기기가 다시 붙으면 이어서 볼 수 있다.
    public static func decide(allowed: Bool, permission: Bool, locked: Bool, viewer: String?, requester: String) -> ScreenState {
        // 허용 안 된 기기에는 권한이나 잠김 상태도 알려 주지 않는다
        guard allowed else { return .notAllowed }
        guard permission else { return .noPermission }
        guard !locked else { return .locked }
        if let viewer, viewer != requester { return .busy }
        return .ok
    }
}
```

검사 순서에도 이유가 있다. 허용을 맨 앞에 둬서, 허용 안 된 기기는 맥에 권한이 있는지, 지금 잠겨 있는지 같은 것도 알 수 없게 했다.

| 상황 | 아이패드가 받는 답 |
|---|---|
| 허용 켜짐, 권한 있음, 안 잠김, 아무도 안 봄 | <span style="color:#2e9e4f">**보기 시작**</span> |
| 허용 꺼짐 | <span style="color:#e5534b">**notAllowed**</span> (다른 상태는 안 알려줌) |
| 맥 앱에 화면 기록 권한 없음 | <span style="color:#e5534b">**noPermission**</span> |
| 맥이 잠김 | <span style="color:#e5534b">**locked**</span> |
| 다른 기기가 보는 중 | <span style="color:#d29922">**busy**</span> (보는 기기 이름) |
| 같은 기기가 다시 붙음 | <span style="color:#2e9e4f">**이어서 보기**</span> |
| 보는 중에 허용 끔 / 허락 취소 | <span style="color:#e5534b">**바로 끊김**</span> |

허용 값은 `config.json`의 허락한 기기 목록에 저장된다. 이 기능 전에 저장한 파일에는 그 칸이 없어서, 없으면 꺼짐으로 읽게 했다. 이걸 안 하면 업데이트한 맥 앱이 예전 설정을 못 읽고 빈 설정으로 시작한다(허락한 기기가 다 사라진다).

```swift
// Pairing.swift (DeckKit)
/// 화면 기능 전에 저장한 config.json에는 screenAllowed가 없다. 그때는 꺼짐으로 읽는다.
public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    token = try c.decode(String.self, forKey: .token)
    screenAllowed = try c.decodeIfPresent(Bool.self, forKey: .screenAllowed) ?? false
}
```

#### 예전 설정 파일을 읽는 Decoder

[`container(keyedBy:)`](https://developer.apple.com/documentation/swift/decoder/container%28keyedby:%29){:target="_blank"}는 JSON 객체 하나를 키로 읽을 준비를 한다. 거기서 [`decodeIfPresent(_:forKey:)`](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent%28%5F:forkey:%29-2hn6i){:target="_blank"}는 그 키가 있으면 읽고 없으면 nil을 준다. 예전 설정 파일에 없는 칸을 기본값으로 채울 때 쓴다.

---

### 연결 전에는 화면 요청을 보내지 않기

"맥 화면" 탭은 열리자마자 모니터 목록을 달라고 한다. 마지막에 고른 탭을 기억하니까, 앱을 켜면 맥과 붙기도 전에 이 탭이 열릴 수 있다. 그런데 아이패드의 `send`는 봉투 키가 아직 없으면 평문으로 보낸다(허락 전의 hello, pair, auth 때문). 맥은 허락 전에 모르는 요청이 오면 `unauthorized`를 돌려주고, 아이패드는 그걸 받으면 인사부터 다시 한다. 붙는 도중에 인사가 꼬일 수 있다.

화면 요청은 허락받은 뒤에만 보내게 막고, 연결되는 순간 목록을 다시 달라고 했다.

```swift
// DeckClient.swift (iOS)
// 화면 요청은 허락받은 뒤 봉투 안에서만. 허락 전에 평문으로 나가면 맥이 인사부터 다시 하게 된다
func listDisplays() {
    guard isConnected else { return }
    screenNotice = nil
    send(.listDisplays)
}
```

```swift
// ScreenPickerView.swift (iOS)
.onChange(of: client.isConnected) { _, connected in
    if connected { client.listDisplays() } else { viewing = nil }
}
```

#### onChange로 연결될 때 다시 요청하기

[`onChange(of:initial:_:)`](https://developer.apple.com/documentation/swiftui/view/onchange%28of:initial:%5F:%29-4psgg){:target="_blank"}는 값이 바뀔 때마다 불리고, 바뀌기 전 값과 바뀐 값을 준다. 연결이 새로 붙으면 모니터 목록을 다시 달라고 했다.

---

## 화면 기록 권한 안내하기

macOS에서 다른 앱 화면을 찍으려면 "화면 및 시스템 오디오 녹화" 권한이 필요하다. 손쉬운 사용 권한과는 따로다. 권한이 없을 때 두 곳에서 알려준다.

- 아이패드: "맥의 시스템 설정 > 개인정보 보호 및 보안 > 화면 및 시스템 오디오 녹화에서 TouchDeck을 켜고, TouchDeck을 다시 실행해 주세요"
- 맥 메뉴바: 화면 보기를 허용한 기기가 있는데 권한이 없으면 같은 안내와 "화면 기록 설정 열기" 버튼

```swift
// ScreenSystem.swift (맥)
enum ScreenPermission {
    static var granted: Bool { CGPreflightScreenCaptureAccess() }

    /// 아직 묻지 않았으면 시스템이 묻는 창을 띄운다 (한 번만 뜬다)
    static func request() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

#### 화면 기록 권한 묻고 설정 열기

[`CGPreflightScreenCaptureAccess()`](https://developer.apple.com/documentation/coregraphics/cgpreflightscreencaptureaccess%28%29){:target="_blank"}는 화면 기록 권한이 있는지 묻기만 하고 창은 띄우지 않는다. [`CGRequestScreenCaptureAccess()`](https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess%28%29){:target="_blank"}는 아직 안 물었으면 권한을 묻는 시스템 창을 띄우는데, 한 번만 뜬다. 거절했으면 [`NSWorkspace.open(_:)`](https://developer.apple.com/documentation/appkit/nsworkspace/open%28%5F:%29){:target="_blank"}로 `x-apple.systempreferences:`로 시작하는 URL을 열어 시스템 설정의 그 화면으로 보낸다.

맥 앱이 화면 기능 전 버전이면 문제가 하나 더 있다. 예전 맥 앱은 `listDisplays`를 모르는 메시지로 보고 답 없이 버린다. 아이패드는 "모니터 목록을 불러오는 중"에서 계속 기다리게 된다. 실제로 아이패드 앱만 새로 깔고 맥에는 예전 Release 빌드가 돌고 있을 때 이렇게 됐다. 5초 안에 답이 없으면 맥 앱을 새로 빌드하라는 안내로 바꾸게 했다.

```swift
// ScreenPickerView.swift (iOS)
.task(id: requestCount) {
    noReply = false
    try? await Task.sleep(for: .seconds(5))
    if client.isConnected && client.displays.isEmpty && client.screenNotice == nil { noReply = true }
}
```

#### task(id:)로 기다렸다가 안내 띄우기

[`task(id:priority:_:)`](https://developer.apple.com/documentation/swiftui/view/task%28id:name:priority:file:line:%5F:%29){:target="_blank"}는 뷰가 보일 때 작업을 시작하고, `id`가 바뀌면 하던 작업을 취소하고 다시 시작한다. 뷰가 사라지면 저절로 취소된다. 다시 불러오기를 누를 때마다 `requestCount`를 올려 5초 기다리기를 처음부터 다시 했다.

권한을 켠 직후 앱을 다시 실행하기 전에는 모니터 목록이 비어 올 수 있다. 맥은 모니터가 최소 하나는 있으니, 목록이 비면 권한 문제로 보고 같은 안내를 보내게 했다.

```swift
// ScreenHost.swift (맥)
let items = await DisplayCatalog.list()
// 모니터가 하나도 안 잡히면 권한 문제다 (권한을 켠 뒤 앱을 다시 실행하지 않았을 때 이렇게 된다)
session.send(items.isEmpty ? .screenStatus(.noPermission, message: nil) : .displays(items))
```

---

## 맥 화면 탭 화면

상단 전환에 "맥 화면"을 세 번째로 넣었다(스트림덱 / 숫자 키패드 / 맥 화면). 이 탭에서는 모니터 카드를 넓게 쓰려고 볼륨 게이지를 숨긴다.

- 모니터 카드: 미리보기, 이름(맥이 알려주는 모니터 이름), 크기. 맥 모니터 배치대로 왼쪽 모니터부터 놓인다.
- 카드를 누르면 전체 화면 보기. 오른쪽 위 작은 도구 막대에 "모니터 바꾸기", 확대했을 때만 보이는 "확대 원래대로", "닫기"가 있다.
- 앱이 뒤로 가면 맥에서 찍기를 멈추고, 다시 앞으로 오면 같은 모니터로 다시 시작한다. 안 보는 동안 맥이 계속 압축하지 않게 하려는 것이다.

---

## 테스트

| 묶음 | 개수 | 결과 |
|---|---|---|
| DeckKit (`swift test`) | 123개 (이번에 44개 추가) | <span style="color:#2e9e4f">**통과**</span> |
| 맥 앱 (`xcodebuild test`) | 52개 (PointerPlan 8개, 비트레이트 2개 추가) | <span style="color:#2e9e4f">**통과**</span> |
| 아이패드 앱 빌드, UI 테스트 빌드 | | <span style="color:#2e9e4f">**성공**</span> |

DeckKit에 추가한 테스트는 메시지 왕복, 예전 설정 파일 읽기, 허용 판단, 바이너리 봉인과 위조/다시 보내기, 영상 묶음과 잘린 데이터, `SendGate`, 루프백으로 300KB 바이너리 주고받기, 좌표 계산이다.

실기기에서 모니터를 골라 화면을 보고 터치로 조작하는 것, 한 손가락 스크롤과 길게 눌러 끌기, 실제 픽셀 크기로 바꾼 뒤의 선명도까지 확인했다.

---

## 참고자료

- [ScreenCaptureKit (Apple)](https://developer.apple.com/documentation/screencapturekit){:target="_blank"}
- [Meet ScreenCaptureKit (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10156/){:target="_blank"}
- [Take ScreenCaptureKit to the next level (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10155/){:target="_blank"}
- [VTCompressionSession (Apple)](https://developer.apple.com/documentation/videotoolbox/vtcompressionsession){:target="_blank"}
- [Explore low-latency video encoding with VideoToolbox (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10158/){:target="_blank"}
- [RFC 6455: The WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455){:target="_blank"}
