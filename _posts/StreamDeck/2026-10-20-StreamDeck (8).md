---
title: StreamDeck (8) 60fps와 소리, 그리고 맥에 글자 보내기
writer: Harold
date: 2026-10-20 3:00:00 +0900
categories: [StreamDeck]
tags: [ScreenCaptureKit, VideoToolbox, AVAudioEngine, CGEvent, SwiftUI]

toc: true
toc_sticky: true
published: true
---

7편에서 아이패드로 맥 화면을 보고 터치로 조작하게 만들었다. 실제로 써 보니 아쉬운 게 네 가지 있었다.

- 30fps라서 창을 끌거나 스크롤할 때 뚝뚝 끊겨 보인다.
- 맥에서 나는 소리가 안 들린다.
- 확대한 뒤에는 보는 위치를 옮길 수가 없다.
- 검색어나 클로드 코드 명령처럼 글자를 칠 방법이 없다.

이번 글은 이 네 가지를 채운 기록이다. 연결할 때 서로 앱 버전을 알려 주는 인사도 같이 넣었다. 7편과 같은 조건을 그대로 지켰다. 새 연결이나 새 인증은 만들지 않고, 허락받은 WebSocket 연결의 봉투 안에서만 오간다.

---

## 30fps와 60fps 고르기

보기 화면 툴바에 "30 / 60" 고르기를 넣었다. 기본값은 60이고, 와이파이가 약하면 30으로 내린다. 마지막에 고른 값은 기억한다.

화면 보기를 시작하는 메시지에 `fps`와 `audio` 칸을 더했다. 보는 중에 바꿀 때는 새 메시지 `screenOptions`를 보낸다. 옛 앱은 이 칸을 보내지 않으니, 없으면 30fps에 소리 없음으로 읽는다.

```swift
case "startScreen":
    self = .startScreen(displayId: try c.decode(UInt32.self, forKey: .displayId), maxSide: try c.decode(Int.self, forKey: .maxSide),
                        fps: ScreenFPS.normalize(try c.decodeIfPresent(Int.self, forKey: .fps) ?? ScreenFPS.low),
                        audio: try c.decodeIfPresent(Bool.self, forKey: .audio) ?? false)
```

#### decodeIfPresent로 옛 메시지 읽기

[`decode(_:forKey:)`](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decode%28%5F:forkey:%29-1u4zx){:target="_blank"}는 그 키의 값을 정한 타입으로 읽고, 키가 없거나 타입이 다르면 오류를 던진다. [`decodeIfPresent(_:forKey:)`](https://developer.apple.com/documentation/swift/keyeddecodingcontainer/decodeifpresent%28%5F:forkey:%29-2hn6i){:target="_blank"}는 키가 있으면 읽고 없으면 nil을 준다. `?? ScreenFPS.low`로 옛 메시지에 없는 칸을 기본값으로 채웠다.

`ScreenFPS.normalize`는 30과 60이 아닌 값을 가까운 쪽으로 맞춘다. 45부터는 60이다.

맥에서는 스트림을 다시 만들지 않고 설정만 바꾼다. ScreenCaptureKit은 도는 중인 스트림에 `updateConfiguration`으로 새 설정을 넘길 수 있다. 압축기 쪽은 예상 프레임 수와 목표 비트레이트를 같은 큐에서 바꾼다.

```swift
func setFrameRate(_ fps: Int) {
    guard let stream, let config else { return }
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    stream.updateConfiguration(config) { error in
        if let error { print("[screen] fps change failed:", error) }
    }
    queue.async {
        self.fps = fps
        guard let encoder = self.encoder else { return }
        VTSessionSetProperty(encoder, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFNumber)
        VTSessionSetProperty(encoder, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: Self.bitRate(width: self.width, height: self.height, fps: fps) as CFNumber)
    }
}
```

#### updateConfiguration으로 도는 중에 fps 바꾸기

fps를 바꿀 때는 찍기와 압축 두 곳을 고친다.

1. 들고 있던 설정의 `minimumFrameInterval`을 1/fps초로 바꾼다. fps 숫자는 [`CMTimeScale`](https://developer.apple.com/documentation/coremedia/cmtimescale){:target="_blank"}(Int32)로 바꿔 `CMTime`의 timescale에 넣는다.
2. [`updateConfiguration(_:completionHandler:)`](https://developer.apple.com/documentation/screencapturekit/scstream/updateconfiguration%28%5F:completionhandler:%29){:target="_blank"}로 도는 중인 찍기에 새 설정을 넣는다. 스트림을 다시 만들지 않아도 되고, 실패하면 완료 함수로 오류가 온다.
3. 압축기는 찍기와 같은 큐에서만 만지게 [`DispatchQueue.async`](https://developer.apple.com/documentation/dispatch/dispatchqueue/async%28group:qos:flags:execute:%29){:target="_blank"}로 넘긴다. `async`는 큐에 일을 맡기고 바로 돌아온다.
4. 그 큐에서 `VTSessionSetProperty`로 [`kVTCompressionPropertyKey_ExpectedFrameRate`](https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey%5Fexpectedframerate){:target="_blank"}(1초에 몇 장이 올지)와 비트레이트를 새 값으로 바꾼다.

---

### 프레임이 두 배면 비트레이트도

7편의 비트레이트는 "픽셀당 0.2비트 × 30장"이었다. 장수를 fps로 바꾸고, 상한을 25Mbps에서 40Mbps로 올렸다.

```swift
static func bitRate(width: Int, height: Int, fps: Int) -> Int {
    min(Int(Double(width * height) * Double(fps) * 0.2), 40_000_000)
}
```

| 11인치 아이패드(2388×1668) | 계산 값 | 실제로 쓰는 값 |
|---|---|---|
| 30fps | 약 23.9Mbps | 약 23.9Mbps (7편과 거의 같음) |
| 60fps | 약 47.8Mbps | 40Mbps (상한) |

---

### 밀릴 때 버리는 기준을 시간으로 맞추기

7편의 `SendGate`는 보내는 중인 프레임이 2장 밀리면 새 프레임을 버렸다. 30fps에서 2장은 약 0.07초다. 60fps에서도 2장으로 두면 0.03초만 밀려도 버리기 시작해서, 와이파이가 조금만 흔들려도 화면이 자주 끊긴다. 그래서 한도를 fps에 맞췄다.

```swift
/// 밀릴 때 버리는 기준을 시간으로 같게: 30fps는 2장, 60fps는 4장 (둘 다 약 0.07초)
public static func limit(forFPS fps: Int) -> Int {
    max(1, fps / 15)
}
```

보는 중에 30에서 60으로 바꾸면 한도만 바꾸고, 지금 보내는 중인 수는 그대로 이어 간다. 바꾸는 순간 수를 0으로 되돌리면, 아직 가는 중인 프레임이 있는데도 더 보내 버린다. 이걸 테스트로 박아 뒀다.

```swift
@Test func changingLimitKeepsInFlight() {
    var gate = SendGate(limit: 2)
    let first = [gate.begin(keyframe: true), gate.begin(keyframe: false)]
    gate.limit = 4
    let more = [gate.begin(keyframe: false), gate.begin(keyframe: false), gate.begin(keyframe: false)]
    #expect(first == [true, true])
    #expect(more == [true, true, false])
}
```

---

## 맥 소리를 아이패드로 보내기

소리는 화면을 찍는 스트림에서 같이 받는다. ScreenCaptureKit의 `capturesAudio`를 켜면 맥 전체 소리가 들어온다. 이미 켠 "화면 및 시스템 오디오 녹화" 권한으로 되니까 새 권한도 필요 없다. TouchDeck 자신의 소리는 `excludesCurrentProcessAudio`로 뺐다.

```swift
config.capturesAudio = true
config.sampleRate = 48_000
config.channelCount = 2
config.excludesCurrentProcessAudio = true
// ...
try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
```

#### SCStreamConfiguration으로 소리도 받기

소리는 같은 설정에 아래 속성을 더하고, `addStreamOutput`에 [`SCStreamOutputType.audio`](https://developer.apple.com/documentation/screencapturekit/scstreamoutputtype/audio){:target="_blank"} 종류로 받을 곳을 하나 더 붙이면 따로 온다. 화면과 다른 큐를 줬다.

| API | 하는 일 |
|---|---|
| [`capturesAudio`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/capturesaudio){:target="_blank"} | 화면과 함께 시스템 소리도 받는다 |
| [`sampleRate`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/samplerate){:target="_blank"} | 받을 소리의 샘플레이트(1초에 몇 번 재는지) |
| [`channelCount`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/channelcount){:target="_blank"} | 받을 소리의 채널 수(2면 왼쪽, 오른쪽) |
| [`excludesCurrentProcessAudio`](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/excludescurrentprocessaudio){:target="_blank"} | 이 앱이 내는 소리는 빼고 받는다 |

영상과 소리는 같은 바이너리 메시지 통로와 같은 봉인(7편의 `sealBinary`)을 쓴다. 봉인을 푼 뒤 첫 바이트로 나눈다.

![영상 묶음(첫 바이트 1)과 소리 묶음(첫 바이트 2)을 같은 WebSocket 바이너리로 봉인해 보내고, 아이패드는 봉인을 푼 뒤 첫 바이트를 보고 영상은 화면 레이어로, 소리는 오디오 엔진으로 보낸다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-media-channel.png)

---

### 소리를 숫자로 담는 법

소리는 공기가 떨리는 모양이다. 마이크나 컴퓨터는 이 떨림의 높이를 아주 짧은 간격으로 재서 숫자로 적는다. 1초에 몇 번 재는지가 샘플레이트이고, 한 번 잰 높이를 몇 비트 숫자로 적는지가 비트 깊이다. 48kHz 16비트는 1초에 48,000번 재고, 잴 때마다 -32768~32767 사이 정수 하나로 적는다는 뜻이다.

![소리의 떨림 모양을 짧은 간격마다 재서 숫자로 적는다. 1초에 48,000번, 잴 때마다 16비트 정수 하나, 왼쪽과 오른쪽 두 채널이라 1초에 약 1.5Mbps](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-sampling.png)

맥이 주는 소리는 높이를 -1~1 사이 실수로 적어 둔 것이라, 이걸 16비트 정수로 바꿔서 보낸다.

---

### 압축하지 않고 보내는 이유

소리는 압축하지 않았다. 48kHz 2채널 16비트는 초당 약 1.5Mbps다. 영상이 24~40Mbps를 쓰니 소리를 압축해서 아끼는 양은 크지 않다. 반대로 압축하고 푸는 시간이 없어져서 지연이 가장 적다.

맥이 주는 소리는 32비트 실수이고 채널이 따로 들어 있다. 이걸 16비트 정수로 바꾸고, 왼쪽과 오른쪽을 번갈아 묶는다. -1~1 범위를 넘는 값은 끝값으로 자른다.

```swift
public static func interleave(_ planar: [[Float]]) -> [Int16] {
    guard let frames = planar.map(\.count).min() else { return [] }
    var out: [Int16] = []
    out.reserveCapacity(frames * planar.count)
    for frame in 0..<frames {
        for channel in planar {
            let value = min(max(channel[frame], -1), 1)
            out.append(Int16((value * 32767).rounded()))
        }
    }
    return out
}
```

#### reserveCapacity와 rounded

[`reserveCapacity(_:)`](https://developer.apple.com/documentation/swift/array/reservecapacity%28%5F:%29){:target="_blank"}는 넣을 개수만큼 배열 자리를 미리 잡아 둔다. 하나씩 넣을 때마다 배열을 늘리지 않아 빠르다. [`rounded()`](https://developer.apple.com/documentation/swift/floatingpoint/rounded%28%29){:target="_blank"}는 가장 가까운 정수로 반올림한 실수라, `Int16(...)`으로 정수로 바꾸기 전에 썼다.

`planar.map(\.count)`는 채널마다 길이를 꺼낸 배열이고, `.min()`은 그중 가장 짧은 길이다. 채널 길이가 달라도 넘치지 않게 짧은 쪽에 맞췄다.

묶음 모양은 영상과 같은 방식으로 앞에 몇 바이트를 붙인다.

| 자리 | 크기 | 내용 |
|---|---|---|
| 0 | 1바이트 | 종류: 2 (영상은 1) |
| 1 | 1바이트 | 채널 수 |
| 2~5 | 4바이트 | 샘플레이트 (big endian) |
| 6~ | 나머지 | 16비트 샘플 (little endian), 채널 번갈아 |

소리 묶음도 밀리면 버린다. 보내는 중인 묶음이 10개를 넘으면 새 묶음은 버린다. `SendGate`를 하나 더 만들어 모든 묶음을 키프레임처럼 넣어 썼다. 소리에는 키프레임이 없으니 키프레임 요청 신호는 읽지 않는다.

---

### 아이패드에서 짧게 쌓아 두고 틀기

와이파이로 오는 묶음은 도착 간격이 들쭉날쭉하다. 오는 대로 바로 틀면 다음 묶음이 늦을 때마다 소리가 끊긴다. 그렇다고 많이 쌓아 두면 소리가 영상보다 늦어진다. 그래서 규칙을 `AudioJitter`로 떼어 DeckKit에 두고 테스트했다.

이렇게 도착 간격이 흔들리는 걸 지터(jitter)라고 하고, 그 흔들림을 흡수하려고 짧게 쌓아 두는 칸을 지터 버퍼라고 부른다.

![들쭉날쭉하게 도착한 소리 묶음을 지터 버퍼에 0.06초쯤 쌓아 두었다가 일정한 간격으로 끊김 없이 틀어 준다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-jitter.png)

| 상황 | 하는 일 |
|---|---|
| 처음, 또는 다 틀어서 빈 뒤 | 0.06초가 쌓이면 틀기 시작 |
| 쌓인 양이 0.2초를 넘음 | 새 묶음을 버리기 시작 |
| 버리다가 0.1초 아래로 내려감 | 다시 받기 |

영상은 도착하면 바로 그리니까 소리가 약 0.06초 늦게 나온다. 사람이 입 모양과 소리가 어긋난다고 느끼는 건 소리가 0.1초쯤 넘게 늦을 때라서 이 정도면 괜찮다.

아이패드는 [`AVAudioEngine`](https://developer.apple.com/documentation/avfaudio/avaudioengine){:target="_blank"}과 플레이어 노드로 튼다. 묶음을 `scheduleBuffer`로 이어 붙이고, 다 튼 알림이 오면 쌓인 양을 줄인다. 오디오 세션은 [`.playback`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback){:target="_blank"}으로 둬서 무음 스위치를 켜 놔도 들린다.

```swift
let seconds = Double(frames) / Double(packet.sampleRate)
let decision = jitter.arrive(seconds)
guard decision != .drop else { return }
let current = generation
player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
    Task { @MainActor in self?.played(seconds, generation: current) }
}
if decision == .queueAndStart { player.play() }
```

#### AVAudioPlayerNode에 소리 조각 이어 붙이기

소리 조각 하나는 이렇게 튼다.

1. 받은 16비트 값을 [`AVAudioPCMBuffer`](https://developer.apple.com/documentation/avfaudio/avaudiopcmbuffer){:target="_blank"}(압축 안 된 소리 조각)의 `floatChannelData`에 채널마다 실수로 써 넣는다.
2. [`AVAudioPlayerNode`](https://developer.apple.com/documentation/avfaudio/avaudioplayernode){:target="_blank"}(`AVAudioEngine`에 붙여 소리 조각을 차례로 트는 부품)의 [`scheduleBuffer(_:completionCallbackType:completionHandler:)`](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulebuffer%28%5F:completioncallbacktype:completionhandler:%29){:target="_blank"}로 줄 끝에 이어 붙인다. `.dataPlayedBack`이면 그 조각이 스피커로 다 나간 뒤 완료 함수가 불린다.
3. 처음이거나 다 비었다가 0.06초가 쌓였으면 `play()`로 튼다. 비면 `pause()`로 멈춘다.

완료 함수는 오디오 쪽 스레드에서 불린다. 그래서 `Task { @MainActor in … }`로 메인으로 넘겨 쌓인 양을 줄였다.

---

### 0.02를 열 번 더해도 0.2가 아니다

`AudioJitter`의 경계는 0.06초, 0.1초, 0.2초다. 그런데 0.02초 묶음을 열 번 더하면 컴퓨터 안에서는 0.2가 아니라 0.19999999999999998이 된다. 실수는 0.02 같은 값을 정확히 담지 못해서, 더하고 뺄 때마다 끝자리에 작은 오차가 붙는다.

컴퓨터는 수를 2진수로 담는다. 0.02는 2진수로 쓰면 끝없이 이어지는 수라서, 가장 가까운 값으로 잘라 담는다. 1/3을 0.333…으로 적다가 끊는 것과 같다. 그래서 0.02를 더할 때마다 아주 작은 차이가 붙는다.

![0.02는 컴퓨터 안에 0.0200000000000000004…로 담기고, 열 번 더하면 0.2가 아니라 0.19999999999999998이 된다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-float.png)

이 오차가 위로 붙느냐 아래로 붙느냐에 따라, 경계에 딱 걸린 묶음을 버릴지 넣을지가 달라질 수 있다. 같은 양이 쌓였는데 더한 순서에 따라 판단이 바뀌면 안 되니까, 경계는 아주 작은 여유를 두고 비교했다.

```swift
/// 0.02를 여러 번 더하면 끝자리가 어긋난다(0.1999…98). 경계는 이만큼 여유를 두고 비교한다
private static let epsilon = 1e-9

if queued + seconds > Self.dropAbove + Self.epsilon {
    dropping = true
    return .drop
}
```

---

### 전화가 끼어든 뒤 앱이 꺼질 수 있던 문제

끼어들기 뒤에 앱이 꺼질 수 있는 길이 하나 있었다. 전화나 다른 앱 소리가 끼어들면 iOS가 오디오 엔진을 멈춘다. 그런데 형식이 그대로라 다시 잇지 않고 다음 묶음에서 `player.play()`를 부르게 되어 있었다. 멈춘 엔진에서 플레이어를 틀면 앱이 죽는다. 묶음을 받을 때 엔진이 멈춰 있으면 처음부터 다시 잇게 했다.

```swift
// 전화 같은 끼어들기로 엔진이 멈췄으면 다시 잇는다 (멈춘 엔진에서 play()를 부르면 앱이 죽는다)
if !engine.isRunning { format = nil }
```

#### 엔진이 멈췄는지 보기

[`AVAudioEngine.isRunning`](https://developer.apple.com/documentation/avfaudio/avaudioengine/isrunning){:target="_blank"}은 엔진이 지금 돌고 있는지다. 전화가 오거나 출력 장치가 바뀌어 시스템이 엔진을 멈추면 false가 된다.

이어폰을 꽂는 것처럼 출력이 바뀔 때도 엔진이 멈춘다. 이건 [`AVAudioEngineConfigurationChange`](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange){:target="_blank"} 알림을 받아 같은 방식으로 다시 잇는다.

---

## 소리가 나가는 동안 맥 스피커 끄기

아이패드로 소리를 듣는 동안 맥 스피커에서도 소리가 나면 메아리처럼 겹친다. 그래서 소리를 보내는 동안은 맥 스피커를 꺼 두고, 끝나면 되돌린다. 맥 앞에 다른 사람이 있을 때는 툴바의 소리 버튼을 끄면 된다. 그러면 소리를 보내지 않고 맥 스피커도 끄지 않는다.

끄는 길은 볼륨 게이지(3편)와 같은 두 가지다.

| 지금 소리가 나가는 곳 | 끄는 방법 |
|---|---|
| macOS가 아는 장치 (맥북 스피커, 에어팟) | AppleScript `set volume with output muted` |
| DisplayPort/HDMI 모니터 (LG 모니터) | BetterDisplay `set -name=<모니터> -mute=on` |
| 둘 다 아님 | 끄지 못한다. 메뉴바에 알리고 소리는 그대로 보낸다 |

되돌릴 때 지켜야 할 게 두 가지 있다.

- **원래 꺼져 있었으면 건드리지 않는다.** 끝날 때도 켜지 않는다. 우리가 끈 경우에만 되돌린다.
- **맥 앱이 중간에 죽어도 돌아와야 한다.** 끄기 전에 "무엇을 껐는지"를 맥에 적어 두고, 되돌리면 지운다. 앱이 켜질 때 이 기록이 남아 있으면 지난번에 죽은 것이니 그때 되돌린다.

판단 부분은 떼어서 테스트했다.

```swift
static func plan(source: VolumeController.Source, alreadyMuted: Bool) -> Start {
    if alreadyMuted { return .alreadyMuted }
    switch source {
    case .system: return .muted(Record(kind: .system, name: nil))
    case .betterDisplay(let name): return .muted(Record(kind: .betterDisplay, name: name))
    case .none: return .cannotMute
    }
}
```

화면 보기가 끝나는 길은 여러 가지다. 닫기, 연결 끊김, 맥 잠김, 맥 메뉴의 "끊기", 화면 보기 허용 끄기, 앱 종료. 이 길이 모두 `stopStream()` 한 곳을 지나게 하고, 거기서 되돌린다.

---

### 끄기가 끝나기 전에 되돌리기가 먼저 도는 문제

AppleScript나 BetterDisplay를 부르면 프로세스를 하나 띄우는 거라 약 0.2초가 걸린다. 그래서 끄기와 되돌리기는 메인 스레드 밖에서 돈다. 여기서 순서 문제가 생긴다. 보기를 시작하자마자 닫으면, 끄기가 아직 도는 동안 되돌리기가 먼저 끝나 버린다. 그 뒤에 끄기가 끝나면 스피커가 꺼진 채로 남는다.

---

### 큐란?

큐는 들어온 일을 들어온 순서대로 하나씩 처리하는 줄이다. 은행 번호표처럼 앞사람 일이 끝나야 다음 사람이 창구에 간다. 일을 여러 군데서 동시에 맡기면 오래 걸리는 일이 나중에 끝나면서 순서가 뒤집힐 수 있는데, 한 줄로 세우면 그럴 일이 없다.

![한 줄로 세우지 않으면 0.2초 걸리는 스피커 끄기보다 되돌리기가 먼저 끝나서 스피커가 꺼진 채로 남는다. 큐로 한 줄로 세우면 되돌리기는 늘 끄기 뒤에 온다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-queue.png)

둘을 같은 큐 하나에 세워서 들어온 순서대로 돌게 했다. 그러면 되돌리기는 언제나 끄기 뒤에 온다.

```swift
/// 끄기와 되돌리기는 프로세스를 띄워서 약 0.2초 걸린다. 한 줄로 세워서,
/// 끄기가 끝나기 전에 보기가 멈춰도 되돌리기가 반드시 끄기 뒤에 오게 한다
private static let queue = DispatchQueue(label: "touchdeck.speaker")

static func restore() {
    queue.async(execute: restoreNow)
}

/// 앱 종료 때. 끝날 때까지 기다린다
static func restoreAndWait() {
    queue.sync(execute: restoreNow)
}
```

#### DispatchQueue로 한 줄로 세우기

[`DispatchQueue(label:)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/init%28label:qos:attributes:autoreleasefrequency:target:%29){:target="_blank"}는 이름을 붙인 새 큐를 만든다. 따로 정하지 않으면 한 번에 하나씩 차례로 처리하는 큐가 된다. 평소에는 `async`로 넣고 바로 돌아오지만, 앱 종료 직전에는 [`sync(execute:)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/sync%28execute:%29-3segw){:target="_blank"}로 넣어 그 일이 끝날 때까지 기다린다.

---

## 확대한 화면 옮기기

7편에서는 두 손가락으로 벌리는 도중에만 확대한 화면이 손가락을 따라 움직였다. 손을 뗐다가 두 손가락으로 다시 쓸면 맥 스크롤로 처리돼서, 확대한 뒤에는 보는 위치를 옮길 수가 없었다.

확대된 동안에는 두 손가락 쓸기를 보는 위치 옮기기로 바꿨다. 맥 스크롤은 한 손가락으로 계속 된다. 두 손가락이 닿았을 때 무엇을 할지는 `TwoFinger.decide`로 떼어 테스트했다.

| 두 손가락 | 원래 크기 | 확대 중 |
|---|---|---|
| 간격이 8% 넘게 변함 | 확대 | 확대 |
| 12pt 넘게 움직임 | 맥 스크롤 | 보는 위치 옮기기 |

```swift
public static func decide(_ current: TwoFinger, scale: CGFloat, moved: CGFloat, zoom: CGFloat, covered: CGFloat = 0) -> TwoFinger {
    guard current == .undecided else { return current }
    if abs(scale - 1) > zoomScale { return .zoom }
    if moved > moveDistance { return zoom > 1.01 || covered > 0 ? .pan : .scroll }
    return .undecided
}
```

한 번 정하면 손을 뗄 때까지 바꾸지 않는다. 스크롤하다가 손가락 간격이 조금 변해도 확대로 바뀌지 않게 하려는 것이다. `covered`는 아래 입력칸 이야기에서 다시 나온다.

---

## 입력칸에 다 쓰고 한 번에 보내기

원격으로 글자를 치는 상황은 크게 두 가지다. 구글이나 유튜브에 검색어를 치는 것, 그리고 클로드 코드 터미널에 명령을 쓰는 것이다.

보기 화면 툴바에 키보드 버튼을 넣었다. 누르면 아래에 특수 키 줄과 입력칸이 열린다. 입력칸에 다 쓰고 "보내기"를 누르면 맥에서 앞에 떠 있는 창에 한 번에 들어간다. "보내고 엔터"를 켜 두면 보낸 뒤 엔터도 같이 누른다.

치는 대로 바로 보내지 않은 이유는 한글이다. 한글은 글자를 조합하는 도중에 계속 바뀐다. "갈"을 치면 입력칸 안에서 "ㄱ → 가 → 갈"로 바뀌는데, 이걸 바뀔 때마다 보내면 맥에 겹쳐 찍히기 쉽다. 다 쓴 뒤 보내면 아이패드가 조합을 끝낸 글자만 간다.

---

### 한글 입력기의 조합이란?

한글은 자음과 모음을 모아 한 글자를 만든다. 그래서 입력기는 키를 누를 때마다 지금 만들고 있는 글자를 바꿔 끼운다. ㄱ을 누르면 "ㄱ", ㅏ를 누르면 그 자리가 "가", ㄹ을 누르면 "갈"이 된다. 이렇게 아직 완성되지 않은 글자를 고치고 있는 상태를 조합 중이라고 한다.

![한글은 ㄱ, 가, 갈처럼 치는 동안 글자가 계속 바뀐다. 바뀔 때마다 맥에 보내면 ㄱ가갈로 겹쳐 찍히고, 다 쓰고 한 번에 보내면 아이패드가 조합을 끝낸 갈만 간다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-ime.png)

맥에 글자를 보내는 쪽은 "그 자리를 바꿔 끼운다"는 걸 전하지 못하고 글자를 더하기만 한다. 그래서 조합이 끝난 뒤에 보내야 맞게 들어간다.

---

### 보내기 전에 다듬기

메시지는 두 가지를 더했다. 글 묶음 `typeText`와 특수 키 하나 `pressKey`다. 둘 다 허락받은 봉투 안에서만 오가고, 맥은 지금 화면을 보고 있는 기기가 보낸 것만 받는다. 친 글은 비밀번호일 수도 있어서 키패드(6편)처럼 로그에 남기지 않는다.

보내기 전에 두 가지를 다듬는다. 줄바꿈과 탭은 띄어쓰기로 바꾸고, 2,000글자에서 자른다. 붙여 넣은 글에 줄바꿈이 섞여 있으면 터미널에서 중간에 엔터가 눌려 명령이 실행되기 때문이다. 이 다듬기는 아이패드가 한 번, 맥이 받을 때 한 번 더 한다. 보내는 쪽이 고장 나도 맥에서 엔터가 눌리지 않게 하려는 것이다.

```swift
public static func clean(_ text: String) -> String {
    var out = ""
    for character in text {
        out.append(character == "\n" || character == "\r\n" || character == "\r" || character == "\t" ? " " : character)
        if out.count == maxCharacters { break }
    }
    return out
}
```

#### Character 단위로 돌기

[`Character`](https://developer.apple.com/documentation/swift/character){:target="_blank"}는 사람이 보는 글자 하나다. 이모지처럼 번호 여러 개로 된 글자도 하나로 센다. `for character in text`는 이 글자 단위로 돈다.

Swift의 `Character`는 사람이 보는 글자 하나라서, 글자 단위로 자르면 이모지나 조합 글자가 반쪽 나지 않는다. `"\r\n"`도 `Character` 하나로 센다.

---

### 유니코드, UTF-16, 글자 하나

컴퓨터 안의 글자는 모두 번호다. 세계의 글자마다 붙인 번호표가 유니코드이고, "가"는 U+AC00번이다. 이 번호를 실제로 저장할 때는 칸에 나눠 적는데, 16비트짜리 칸에 적는 방법이 UTF-16이다. 작은 번호는 한 칸, 이모지처럼 큰 번호는 두 칸을 쓴다.

![가는 글자 1개, 번호 1개, UTF-16 1칸이다. 피부색을 넣은 엄지 이모지는 사람 눈에 글자 1개지만 번호 2개가 합쳐진 것이라 UTF-16으로 4칸이다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-unicode.png)

사람 눈에 글자 하나로 보이는 것이 번호 여러 개로 이루어지기도 한다. 피부색을 넣은 엄지 이모지는 엄지 번호와 피부색 번호가 합쳐진 글자 하나다. Swift의 `Character`는 이렇게 합쳐진 것까지 사람이 보는 글자 하나로 세서, `Character` 단위로 자르면 반쪽이 나지 않는다. UTF-16 칸 수로 자르면 엄지와 피부색 사이가 갈라질 수 있다.

---

### 글자를 키 번호가 아니라 글자 그대로 넣기

6편의 키패드는 키 번호로 입력했다. 숫자는 윗줄 숫자 키라서 맥이 한글 입력 상태여도 숫자가 들어갔다. 글자는 다르다. "a" 키 번호를 보내면 맥이 한글 입력 상태일 때 "ㅁ"이 들어간다.

그래서 글자는 키 번호 대신 글자 그대로 키보드 이벤트에 실었다. `CGEvent`의 `keyboardSetUnicodeString`을 쓰면 이벤트에 유니코드 글자를 직접 넣을 수 있다.

```swift
case .text(let chunk):
    let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
    let units = Array(chunk.utf16)
    event?.flags = []
    event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
    event?.post(tap: .cghidEventTap)
```

#### keyboardSetUnicodeString으로 글자 싣기

[`keyboardSetUnicodeString(stringLength:unicodeString:)`](https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring%28stringlength:unicodestring:%29){:target="_blank"}는 키 이벤트에 글자를 직접 싣는다. UTF-16 칸 배열과 그 개수를 주는데, 칸 배열은 [`utf16`](https://developer.apple.com/documentation/swift/string/utf16){:target="_blank"}(글자를 UTF-16 칸으로 본 것)을 `Array(...)`로 만들었다. 맥 입력 상태와 상관없이 실은 글자가 들어간다.

Apple 문서에 한도가 적혀 있지는 않지만, 이벤트 하나에 긴 글을 실으면 앞부분만 들어간다고 알려져 있다. 그래서 흔히 쓰는 기준인 UTF-16 20개씩 잘게 나눠 보낸다. 나눌 때도 글자 하나를 두 묶음에 걸치게 쪼개지 않는다. 👍🏽 같은 이모지는 UTF-16으로 4개라서 묶음 경계에서 쪼개지기 쉽다.

```swift
public static func chunks(_ text: String) -> [String] {
    var result: [String] = []
    var current = ""
    for character in text {
        if !current.isEmpty && current.utf16.count + character.utf16.count > maxChunkUTF16 {
            result.append(current)
            current = ""
        }
        current.append(character)
    }
    if !current.isEmpty { result.append(current) }
    return result
}
```

---

### 엔터가 글보다 먼저 눌리지 않게

"보내고 엔터"를 누르면 아이패드는 `typeText` 다음에 `pressKey(enter)`를 보낸다. 맥에서 긴 글을 묶음으로 나눠 넣는 동안 엔터가 먼저 눌리면, 반쯤 쓴 명령이 실행된다. 그래서 글과 키를 큐 하나에 세워 받은 순서대로 넣는다. 묶음 사이에는 앱이 놓치지 않게 2ms씩 쉰다.

순서는 실제 키 이벤트 대신 기록만 하는 가짜 입력을 넣어서 테스트했다.

```swift
@Test func typesInArrivalOrder() {
    let log = StepLog()
    let typer = RemoteTyper(post: { log.append($0) }, pause: { usleep(1_000) })
    typer.type(String(repeating: "가", count: 45))   // 20, 20, 5
    typer.press(.enter)
    typer.waitUntilIdle()
    #expect(log.steps.count == 4)
    #expect(log.steps.first == .text(String(repeating: "가", count: 20)))
    #expect(log.steps.last == .key(CGKeyCode(kVK_Return), []))
}
```

#### 테스트에서 쓴 usleep과 repeating

[`usleep(3)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages%5FiPhoneOS/man3/usleep.3.html){:target="_blank"}은 지금 스레드를 정한 마이크로초(1/1,000,000초) 동안 재운다. 1,000이면 1ms다. [`String(repeating:count:)`](https://developer.apple.com/documentation/swift/string/init%28repeating:count:%29-23xjt){:target="_blank"}는 같은 글자를 정한 횟수만큼 이어 붙인 글자를 만든다.

---

### 특수 키 줄

입력칸 위의 특수 키는 누르면 바로 보낸다. 클로드 코드에서 자주 쓰는 키와 검색창용 전체 선택이다.

| 키 | 맥에서 누르는 것 | 쓰는 곳 |
|---|---|---|
| esc | Escape | 클로드 코드 멈추기 |
| tab, ⇧tab | Tab, Shift+Tab | 자동 완성, 모드 바꾸기 |
| ↑ ↓ ← → | 방향키 | 이전 입력 다시 부르기 |
| ⌘A | Command+A | 검색창에 남은 글 한 번에 고르기 |
| ⌫ | Delete | 지우기 (길게 누르면 계속) |
| ⌃C | Control+C | 중단 |
| ⏎ | Return | 엔터 |

⌘A는 써 보고 나서 더했다. 유튜브 검색창처럼 이전 검색어가 남아 있으면 ⌫로 한 글자씩 지워야 했다. ⌘A로 다 고른 뒤 새 글을 보내면 바로 바뀌고, ⌫ 한 번이면 다 지워진다.

---

### ⌫를 길게 누르면 계속 지우기

⌫는 맥 키보드처럼 0.4초 누르고 있으면 뗄 때까지 0.08초마다 지운다. 처음엔 손가락이 닿고 떼는 걸 `DragGesture`의 시작과 끝으로 잡으려 했는데, 특수 키 줄은 옆으로 스크롤되는 칸 안에 있다. 누른 채 손가락을 옆으로 밀면 스크롤이 손가락을 가져가고, 그러면 "끝" 알림이 오지 않을 수 있다. 끝을 못 받으면 지우기가 멈추지 않는다.

`@GestureState`를 썼다. 이 값은 제스처가 끝나거나 다른 제스처에 뺏겨 취소되면 저절로 처음 값(`false`)으로 돌아온다. 이 값이 바뀌는 것만 보고 시작과 멈춤을 정했다.

```swift
/// 누르는 중. 손을 떼거나 스크롤에 손가락을 뺏기면 저절로 false가 돼서, 지우기가 멈추지 않는 일이 없다
@GestureState private var pressing = false

label
    .gesture(DragGesture(minimumDistance: 0).updating($pressing) { _, state, _ in state = true })
    .onChange(of: pressing) { _, now in now ? startRepeating() : stopRepeating() }
```

#### GestureState로 누르는 동안만 켜 두기

[`@GestureState`](https://developer.apple.com/documentation/swiftui/gesturestate){:target="_blank"}는 제스처가 진행되는 동안만 값을 갖는 상태다. 제스처가 끝나거나 취소되면 저절로 처음 값으로 돌아간다. [`gesture(_:including:)`](https://developer.apple.com/documentation/swiftui/view/gesture%28%5F:including:%29){:target="_blank"}로 붙인 `DragGesture`의 [`updating(_:body:)`](https://developer.apple.com/documentation/swiftui/gesture/updating%28%5F:body:%29){:target="_blank"}에서 닿아 있는 동안 `pressing`을 true로 두고, 그 값이 바뀌는 것만 보고 시작과 멈춤을 정했다.

---

### 키보드가 화면을 덮게 하기

처음에는 입력칸이 열리면 맥 화면이 키보드 위 남은 자리로 줄어들게 만들었다. 클로드 코드 입력 줄은 터미널 맨 아래에 있어서 키보드에 가려지면 안 된다고 봤다. 그런데 써 보니 키보드를 열고 닫을 때마다 화면 크기가 바뀌어 덜컹거리고, 맥 화면도 작아졌다.

그래서 맥 화면은 크기를 그대로 두고 키보드와 입력칸이 아래를 덮게 바꿨다. 대신 입력칸이 열린 동안은 1배에서도 두 손가락으로 화면을 위로 밀어 올릴 수 있다. 덮인 높이만큼만 올라가서, 가려진 아래쪽을 볼 수 있다.

7편의 `clampOffset`은 확대한 만큼만 위아래로 옮길 수 있게 막았다. 여기에 덮인 높이 `covered`를 더해서 위쪽으로만 더 갈 수 있게 했다.

```swift
public static func clampOffset(_ offset: CGSize, zoom: CGFloat, view: CGSize, covered: CGFloat = 0) -> CGSize {
    let maxX = max(0, view.width * (zoom - 1) / 2)
    let maxY = max(0, view.height * (zoom - 1) / 2)
    let minY = -maxY - max(0, covered)
    return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, minY), maxY))
}
```

덮인 높이는 화면 전체 기준으로 영상 아래 끝과 입력칸 윗변의 차이로 잰다. 키보드를 닫으면 `covered`가 0이 되고, 밀어 올렸던 화면이 이 계산을 다시 거쳐 제자리로 돌아온다.

화면 배치에서 하나 더 조심한 게 있다. 영상은 키보드 자리까지 화면 끝을 다 채우지만([`ignoresSafeArea()`](https://developer.apple.com/documentation/swiftui/view/ignoressafearea%28%5F:edges:%29){:target="_blank"}), 툴바는 안전 영역 안에 남겨 뒀다. 화면 전체가 안전 영역을 무시하게 하면, 아이폰을 가로로 눕혔을 때 오른쪽 위 툴바가 다이내믹 아일랜드 밑으로 들어간다.

---

### 안전 영역이란?

요즘 아이폰과 아이패드 화면에는 모서리가 둥글고, 다이내믹 아일랜드나 홈 막대처럼 화면을 가리는 곳이 있다. 그걸 피해서 내용이 온전히 보이고 눌리는 안쪽 영역을 안전 영역이라고 한다. SwiftUI는 기본으로 안전 영역 안에 그리고, `ignoresSafeArea()`를 붙인 것만 화면 끝까지 채운다.

![가로로 눕힌 아이폰에서 다이내믹 아일랜드와 홈 막대를 피한 안쪽이 안전 영역이다. 영상은 화면 끝까지 채우고, 툴바와 입력칸처럼 누르는 것은 안전 영역 안에 둔다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-safe-area.png)

영상은 가려져도 괜찮지만 버튼은 가려지면 누를 수 없다. 그래서 영상에만 `ignoresSafeArea()`를 붙였다.

---

## 연결할 때 기능 번호 알려 주기

7편에서 아이패드가 맥 모니터 목록을 계속 기다린 일이 있었다. 맥에 화면 기능 전의 앱이 깔려 있었고, 예전 맥 앱은 모르는 메시지를 답 없이 버렸다. 서로 버전을 모르니 아이패드는 그냥 기다릴 수밖에 없었다.

연결할 때 기능 번호를 주고받게 했다. 아이패드는 `hello`에, 맥은 허락한 뒤 보내는 `authorized`에 번호를 싣는다.

---

### 기능 번호를 주고받는다는 것

서로 다른 때 만든 앱이 만나면, 한쪽은 아는 메시지를 다른 쪽은 모를 수 있다. 그래서 연결하자마자 "나는 몇 번까지 안다"를 먼저 알려 주고, 둘 중 낮은 쪽에 맞춰 쓴다. 이렇게 맞추는 걸 흔히 버전 협상이라고 부른다.

![아이패드는 hello에 기능 번호 2를 싣고, 예전 맥 앱은 authorized에 번호가 없어 1로 읽힌다. 아이패드는 설치 안내를 띄우고 키보드 버튼을 흐리게 하지만 연결은 끊지 않는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-20-StreamDeck-8/touchdeck-protocol.png)

```swift
/// 연결할 때 서로 알려 주는 기능 번호. 번호를 안 보내는 예전 앱과 ESP32 보드는 1로 본다.
/// 1: 버튼, 볼륨, 키패드, 화면 보기(1, 2차)   2: 글자 입력(typeText, pressKey)
public enum DeckProtocol {
    public static let legacy = 1
    public static let current = 2
}
```

번호가 없으면 1로 읽는다. 예전 앱은 모르는 칸을 무시하니 새 칸을 더해도 연결은 그대로 된다.

| 상황 | 하는 일 |
|---|---|
| 맥 번호가 아이패드보다 낮음 | 아이패드 연결 상태 아래에 "맥 TouchDeck을 새 버전으로 설치해 주세요" |
| 맥 번호가 1 | 보기 화면의 키보드 버튼을 흐리게, 누르면 같은 안내 |
| 아이패드 번호가 맥보다 낮음 | 맥 메뉴 연결 목록의 그 기기 이름 옆에 "(앱 업데이트 필요)" |

버전이 다르다고 연결을 끊지는 않는다. 알리기만 하고, 되는 기능은 그대로 쓴다.

---

## 테스트

순수 계산은 이번에도 DeckKit에 두고 테스트부터 썼다. DeckKit 158개, 맥 59개가 통과한다.

| 무엇 | 테스트 |
|---|---|
| 옛 메시지 읽기 | `startScreenWithoutNewFieldsDefaults`, `helloWithoutProtocolIsOne`, `authorizedWithoutProtocolIsOne` |
| 보내는 한도 | `gateLimitFollowsFps`, `changingLimitKeepsInFlight` |
| 소리 묶음 | `audioPacketLayout`, `audioPacketRejectsBadInput`, `interleaveClampsAndAlternates` |
| 쌓아 두고 틀기 | `waitsForSixtyMsBeforeStarting`, `overTwoHundredMsStartsDropping`, `dropsUntilBelowHundredMs`, `emptyQueueWaitsAgain` |
| 맥 스피커 | `alreadyMutedIsLeftAlone`, `unknownOutputCannotMute`, `leftoverRecordIsRestoredOnLaunch` |
| 두 손가락 | `swipeWhileZoomedMovesView`, `decidedModeSticks`, `swipeAtNormalSizeMovesViewWhenBottomIsCovered` |
| 입력칸 | `cleanTurnsLineBreaksIntoSpaces`, `cleanCutsAtTwoThousandCharacters`, `chunksNeverSplitACharacter` |
| 맥 입력 | `specialKeyStrokes`, `typesInArrivalOrder` |
| 밀어 올리기 | `coveredBottomLetsViewMoveUpAtNormalSize`, `coveredAddsToZoomedRange` |

---

## 참고자료

- [CMSampleBuffer.withAudioBufferList(blockBufferMemoryAllocator:flags:body:) (Apple)](https://developer.apple.com/documentation/coremedia/cmsamplebuffer/withaudiobufferlist%28blockbuffermemoryallocator:flags:body:%29){:target="_blank"}
- [BetterDisplay 연동 기능과 CLI (mute)](https://github.com/waydabber/BetterDisplay/wiki/Integration-features,-CLI){:target="_blank"}
- [onGeometryChange(for:of:action:) (Apple)](https://developer.apple.com/documentation/swiftui/view/ongeometrychange%28for:of:action:%29){:target="_blank"}
