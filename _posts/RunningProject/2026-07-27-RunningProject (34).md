---
title: RunWay 1.2 (3) 스플릿 음성 안내 구상해보기
writer: Harold
date: 2026-07-27 21:00:00 +0900
categories: [RunWay]
tags: [AVFoundation]

toc: true
toc_sticky: true
published: true
---

[이전글](https://haroldfromk.github.io/posts/RunningProject-(33)/){:target="_blank"}에서 km 스플릿 기능을 다 붙였다. 로드맵상 다음 순서는 이 스플릿이 끊길 때마다 화면을 안 봐도 페이스/심박/케이던스를 음성으로 읽어주는 기능이다.

이제 이 과정을 기록해본다

---

## 스플릿 재활용

[이전글](https://haroldfromk.github.io/posts/RunningProject-(33)/){:target="_blank"}에 적었던 `recordSplitSample(at:)`을 다시 보면, `while` 루프 안에서 1km 경계를 넘을 때마다 그 구간의 평균 페이스/심박/케이던스를 이미 다 계산해두고 있다.

```swift
// RunningCenter

while totalDistance - splitStartDistance >= 1000 {
    splitIndex += 1
    // 생략
    let avgHeartRate = splitHeartRateCount > 0 ? Int(splitHeartRateSum / Double(splitHeartRateCount)) : 0
    let avgCadence = splitCadenceCount > 0 ? Int(splitCadenceSum / Double(splitCadenceCount)) : 0

    let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime, distance: 1, elevationGain: splitElevationGain)
    completedSplits.append(split)
    // 생략
}
```

음성 안내에 필요한 값이 딱 여기서 다 나온다. 그러니까 새로운 계산을 추가할 필요 없이, 이 `split`이 만들어지는 시점에 "이 값으로 한 번 읽어줘"라고 알려주기만 하면 될 것 같다.

다만 실제로 읽어줄 값은 화면에 나오는 최종 기록이랑 미묘하게 다르다. 스플릿이 끝나는 순간의 평균이라서, 예를 들어 페이스는 그 구간 1km를 걷다 뛰다 했으면 그 결과가 그대로 평균에 섞여 들어간다. 그래도 "지금 이 구간이 대략 이랬다"를 알려주는 용도로는 충분하다고 봤다.

---

## 구조적 한계

문제는 지금 스플릿 데이터를 꺼내는 방법이 `allSplits()` 하나뿐이라는 거다. 이건 러닝이 끝나고 저장할 때 딱 한 번 부르라고 만든 함수다.

```swift
// RunningCenter

func allSplits() -> [Split] {
    finalizePendingSplit()
    return completedSplits
}
```

`finalizePendingSplit()`은 부를 때마다 지금까지 안 끊긴 자투리 구간을 하나의 스플릿으로 확정시켜버린다. 

러닝 저장 시점엔 이게 맞는 동작인데, 만약 음성 안내를 이 함수로 처리하려고 1km마다 반복해서 불렀다간 매번 자투리 구간을 강제로 끊어버리는 부작용이 생긴다. 그러니까 이 함수는 그대로 두고, 스플릿이 진짜로 완성되는 순간에만 딱 한 번 신호를 주는 별도의 통로가 하나 더 필요하다.

방법 자체는 어렵지 않아 보인다. `recordSplitSample(at:)`의 `while` 루프 안, `Split`이 만들어진 바로 그 줄에서 이 값을 밖으로 한 번 흘려보내는 함수 하나만 추가하면 된다. 저장용 `completedSplits`는 그대로 쌓이고, 음성 안내는 이 신호를 받는 쪽에서 별개로 처리하는 식이다.

말로만 하면 잘 안 와닿아서, 두 방식을 나란히 돌려볼 수 있게 만들었다. 왼쪽은 실제로 저장될 스플릿 목록이고 오른쪽은 귀에 들리는 안내다.

<iframe
  src="/assets/demo/split_announce_channel_simulator.html"
  width="100%"
  height="810px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

`allSplits()`를 계속 부르는 쪽으로 두고 끝까지 돌리면, 4.33km를 뛴 시점에 안내가 이미 "15킬로미터"라고 말하고 있다. 확인만 하려고 부른 함수가 매번 자투리를 진짜 스플릿으로 확정해버리고, 그때마다 번호를 하나씩 써버리기 때문이다. 더 나쁜 건 안내만 이상해지는 게 아니라 **저장되는 기록까지 같이 망가진다**는 점이다.

여기서 배운 건, 값을 꺼내는 함수와 값이 만들어졌다고 알려주는 통로는 서로 다른 물건이라는 거다. `allSplits()`는 "지금까지의 결과를 정리해서 내놔"라는 뜻이고, 안내에 필요한 건 "방금 하나가 완성됐다"는 사실뿐이다. 앞의 것으로 뒤의 것을 대신하려니 정리하는 동작이 부작용으로 딸려온 것이다.

---

## AVSpeechSynthesizer ?

애플 프레임워크에 텍스트를 음성으로 바꿔주는 게 이미 있어서 이걸 쓰면 될 것 같다. `AVFoundation`에 있는 `AVSpeechSynthesizer`다.

사용법은 단순하다. 읽고 싶은 문장으로 `AVSpeechUtterance`를 하나 만들고, 그걸 `AVSpeechSynthesizer`에 넘기면 끝이다.

```swift
let utterance = AVSpeechUtterance(string: "1킬로미터, 페이스 5분 30초")
utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
utterance.rate = 0.5

let synthesizer = AVSpeechSynthesizer()
synthesizer.speak(utterance)
```

`AVSpeechUtterance` 쪽에 조절할 수 있는 값이 몇 개 있다.

- `voice`: 어떤 언어/목소리로 읽을지. 한국어는 `"ko-KR"`
- `rate`: 읽는 속도. 0.0~2.0 범위고 기본값이 0.5
- `pitchMultiplier`: 음높이. 0.5~2.0, 기본 1.0
- `volume`: 음량. 0.0~1.0, 기본 1.0

`AVSpeechSynthesizer` 쪽은 `speak(_:)`로 말을 시키고, `stopSpeaking(at:)`/`pauseSpeaking(at:)`로 멈추거나 잠깐 끊을 수 있다. 지금 말하고 있는지는 `isSpeaking` 값으로 확인 가능하고, 델리게이트를 붙이면 언제 시작했는지/끝났는지도 콜백으로 받을 수 있다.

([AVSpeechSynthesizer Docs](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer){:target="_blank"}, [AVSpeechUtterance Docs](https://developer.apple.com/documentation/avfaudio/avspeechutterance){:target="_blank"} 공식 문서)

---

## 백그라운드나 음악재생시에도 작동하게 하려면?

두 가지를 더 챙겨야 할 것 같다.

하나는 백그라운드 재생이다. 러닝 중엔 화면을 꺼놓고 뛰는 경우가 많으니까, 앱이 백그라운드에 있어도 음성이 나오려면 Xcode 프로젝트 설정에서 백그라운드 모드 중 오디오 재생 관련 항목을 켜줘야 한다.

다른 하나는 음악이나 팟캐스트를 같이 듣는 경우다. 지금처럼 아무 설정도 안 하면 스플릿 안내 음성이 나올 때 듣고 있던 음악이 끊기거나, 반대로 음성이 음악에 묻혀서 안 들릴 수 있다. 

`AVAudioSession` 카테고리를 어떻게 설정하느냐에 따라 "음성 나오는 동안만 음악 소리를 줄였다가 끝나면 다시 키워주는" 식의 동작이 가능하다고 하는데, 이 부분은 실제로 붙여보면서 확인해야 할 것 같다.

---

## 적용하기

생각했던 순서 그대로 붙였다.

`RunningCenter`에 저장용 `completedSplits`와는 별개로 스플릿 완료 알림만 전달하는 스트림을 하나 추가했다. `Split`이 만들어지는 바로 그 줄에 한 줄만 더 넣으면 됐다.

```swift
// RunningCenter

var splitAnnouncementContinuation: AsyncStream<Split>.Continuation?

let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime, distance: 1, elevationGain: splitElevationGain)
completedSplits.append(split)
splitAnnouncementContinuation?.yield(split)
// 생략

func streamSplitAnnouncements() -> AsyncStream<Split> {
    AsyncStream<Split> { continuation in
        self.splitAnnouncementContinuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.clearContinuation()
            }
        }
    }
}
```

`completedSplits.append(split)`은 저장용이라 계속 쌓이기만 하고, `splitAnnouncementContinuation?.yield(split)`은 그 순간 딱 한 번 흘려보내고 끝이다. 그래서 이 스트림은 몇 번을 구독해도 `finalizePendingSplit()`처럼 자투리 구간을 건드리는 부작용이 없다.

음성 합성은 새 서비스 하나로 분리했다.

```swift
// SpeechAnnouncerService

final class SpeechAnnouncerService {

    private let synthesizer = AVSpeechSynthesizer()

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    func announce(split: Split) {
        let paceText: String
        if split.pace.isFinite, split.pace > 0 {
            let totalSeconds = Int(round(split.pace * 60))
            paceText = "\(totalSeconds / 60)분 \(totalSeconds % 60)초"
        } else {
            paceText = "측정 불가"
        }

        var sentence = "\(split.order)킬로미터, 페이스 \(paceText)"
        if split.heartRate > 0 {
            sentence += ", 심박수 \(split.heartRate)"
        }
        if split.cadence > 0 {
            sentence += ", 케이던스 \(split.cadence)"
        }

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}
```

`RunViewModel`/`WatchViewModel` 양쪽 다 `streamPhaseData()`를 구독하는 자리 옆에 똑같은 패턴으로 하나 더 추가했다.

```swift
Task {
    for await split in await runningCenter.streamSplitAnnouncements() {
        self.speechAnnouncerService.announce(split: split)
    }
}
```

`RunningCenter`는 iPhone/Watch가 각자 따로 갖고 있는 인스턴스라서, GPS를 실제로 수신하는 쪽(러닝을 주도한 기기)에서만 스플릿이 만들어지고 음성도 그쪽에서만 나온다. 미러링만 하는 쪽은 자기 `RunningCenter`에 위치 데이터가 안 들어오니 자연히 조용하다.

오디오 세션은 걱정했던 것보다 간단했다. `.playback` 카테고리에 `.duckOthers` 옵션만 주면, 음성이 나오는 순간에만 다른 소리(음악, 팟캐스트)가 알아서 줄었다가 끝나면 원래대로 돌아온다. 이 설정은 러닝 시작(`start()`) 시점에 한 번만 해주면 된다.

백그라운드 재생을 위해서 iPhone 쪽 `Info.plist`의 `UIBackgroundModes`에 `location` 옆에 `audio`를 추가했다. 워치는 러닝 중엔 이미 `HKWorkoutSession`이 백그라운드 실행을 보장해주니까 따로 안 건드려도 될 줄 알았는데, 나중에 지적을 받고 다시 찾아보니 틀린 생각이었다. 워크아웃 세션이 백그라운드 실행 자체는 보장해줘도, 오디오 재생은 별도로 `audio` 백그라운드 모드를 켜줘야 한다.

워치 쪽은 `RunWayWatch-Watch-App-Info.plist`라는 별도 파일에 `UIBackgroundModes`(`location`)랑 `WKBackgroundModes`(`workout-processing`)가 이미 있었는데, 여기에 `audio`가 빠져 있었다. 추가해서 해결했다.

```xml
<!-- RunWayWatch-Watch-App-Info.plist -->

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
```

찾아보니 `AVSpeechSynthesizer`는 이 설정을 다 해줘도 워치 백그라운드에서 완벽하게 동작하지 않는다는 보고가 있다([Apple Developer Forums](https://developer.apple.com/forums/thread/64275){:target="_blank"}). 화면을 보고 있을 땐 문제없이 들리겠지만, 화면이 꺼진 채로도 항상 들릴 거라고는 장담 못 한다. 이 부분은 실기기로 오래 뛰어보면서 확인해야 할 것 같다.

---

## 정리하면

1. `RunningCenter`에 저장용 배열과 별개로 스플릿 완료를 실시간으로 알리는 `AsyncStream`을 추가했다.
2. `SpeechAnnouncerService`가 그 신호를 받아 페이스/심박/케이던스를 조합한 문장을 `AVSpeechSynthesizer`로 읽어준다.
3. 오디오 세션은 `.playback` + `.duckOthers`로 설정해서 음악을 듣고 있어도 그 순간만 자연스럽게 줄어들게 했다.
4. iPhone `Info.plist`에 `audio` 백그라운드 모드를 추가해서 화면을 꺼도 안내가 계속 나오게 했다.

다음 실기기 테스트에서는 이어폰 연결 상태별로 볼륨 밸런스가 괜찮은지, 그리고 짧은 구간(예: 오르막에서 페이스가 갑자기 느려진 구간)에서 문장이 너무 길게 느껴지지 않는지 확인해볼 예정이다.
