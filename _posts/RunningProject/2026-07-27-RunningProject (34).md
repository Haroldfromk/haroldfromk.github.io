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

[이전글](https://haroldfromk.github.io/posts/RunningProject-(33)/){:target="_blank"}에서 km 스플릿 기능을 다 붙였다. 로드맵상 다음 순서는 이 스플릿이 끊길 때마다 화면을 안 봐도 페이스/심박/케이던스를 음성으로 읽어주는 기능이다. 오늘은 코드는 하나도 안 건드리고, 어떻게 만들면 될지만 정리해본다.

---

## 스플릿 끊기는 순간을 그대로 재활용하면 될 것 같다

[이전글](https://haroldfromk.github.io/posts/RunningProject-(33)/){:target="_blank"}에 적었던 `recordSplitSample(at:)`을 다시 보면, `while` 루프 안에서 1km 경계를 넘을 때마다 그 구간의 평균 페이스/심박/케이던스를 이미 다 계산해두고 있다.

```swift
// RunningCenter

while totalDistance - splitStartDistance >= 1000 {
    splitIndex += 1
    // 생략 (elapsedTime, splitDuration, splitPace 계산)
    let avgHeartRate = splitHeartRateCount > 0 ? Int(splitHeartRateSum / Double(splitHeartRateCount)) : 0
    let avgCadence = splitCadenceCount > 0 ? Int(splitCadenceSum / Double(splitCadenceCount)) : 0

    let split = Split(order: splitIndex, pace: splitPace, heartRate: avgHeartRate, cadence: avgCadence, elapsedTime: elapsedTime)
    splitContinuation?.yield(split)
    // 생략
}
```

음성 안내에 필요한 값이 딱 여기서 다 나온다. 그러니까 새로운 계산을 추가할 필요 없이, 이 `split`이 만들어지는 시점에 "이 값으로 한 번 읽어줘"라고 알려주기만 하면 될 것 같다.

다만 실제로 읽어줄 값은 화면에 나오는 최종 기록이랑 미묘하게 다르다. 스플릿이 끝나는 순간의 평균이라서, 예를 들어 페이스는 그 구간 1km를 걷다 뛰다 했으면 그 결과가 그대로 평균에 섞여 들어간다. 그래도 "지금 이 구간이 대략 이랬다"를 알려주는 용도로는 충분하다고 봤다.

## 근데 지금 구조로는 바로 못 쓴다

문제는 지금 스플릿 데이터를 꺼내는 방법이 `allSplits()` 하나뿐이라는 거다. 이건 러닝이 끝나고 저장할 때 딱 한 번 부르라고 만든 함수다.

```swift
// RunningCenter

func allSplits() -> [Split] {
    finalizePendingSplit()
    return completedSplits
}
```

`finalizePendingSplit()`은 부를 때마다 지금까지 안 끊긴 자투리 구간을 하나의 스플릿으로 확정시켜버린다. 러닝 저장 시점엔 이게 맞는 동작인데, 만약 음성 안내를 이 함수로 처리하려고 1km마다 반복해서 불렀다간 매번 자투리 구간을 강제로 끊어버리는 부작용이 생긴다. 그러니까 이 함수는 그대로 두고, 스플릿이 진짜로 완성되는 순간에만 딱 한 번 신호를 주는 별도의 통로가 하나 더 필요하다.

방법 자체는 어렵지 않아 보인다. `recordSplitSample(at:)`의 `while` 루프 안, `Split`이 만들어진 바로 그 줄에서 이 값을 밖으로 한 번 흘려보내는 함수 하나만 추가하면 된다. 저장용 `completedSplits`는 그대로 쌓이고, 음성 안내는 이 신호를 받는 쪽에서 별개로 처리하는 식이다. 구체적으로 어떤 방식으로 흘려보낼지는 다음에 실제로 붙이면서 정하기로 했다.

## 음성은 뭘로 읽어줄까 - AVSpeechSynthesizer

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

([AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer){:target="_blank"}, [AVSpeechUtterance](https://developer.apple.com/documentation/avfaudio/avspeechutterance){:target="_blank"} 공식 문서)

## 백그라운드에서, 음악 틀어놓고 뛸 때도 문제없이 나오려면

두 가지를 더 챙겨야 할 것 같다.

하나는 백그라운드 재생이다. 러닝 중엔 화면을 꺼놓고 뛰는 경우가 많으니까, 앱이 백그라운드에 있어도 음성이 나오려면 Xcode 프로젝트 설정에서 백그라운드 모드 중 오디오 재생 관련 항목을 켜줘야 한다.

다른 하나는 음악이나 팟캐스트를 같이 듣는 경우다. 지금처럼 아무 설정도 안 하면 스플릿 안내 음성이 나올 때 듣고 있던 음악이 끊기거나, 반대로 음성이 음악에 묻혀서 안 들릴 수 있다. `AVAudioSession` 카테고리를 어떻게 설정하느냐에 따라 "음성 나오는 동안만 음악 소리를 줄였다가 끝나면 다시 키워주는" 식의 동작이 가능하다고 하는데, 이 부분은 실제로 붙여보면서 확인해야 할 것 같다.

## 정리하면

1. `RunningCenter`의 `recordSplitSample(at:)`에서 `Split`이 만들어지는 순간, 저장용 `completedSplits`랑 별개로 "지금 이 스플릿 값으로 안내해줘"라는 신호를 한 번 흘려보내는 통로를 하나 만든다.
2. 그 신호를 받아서 `AVSpeechSynthesizer` + `AVSpeechUtterance`로 문장을 만들어 읽어준다. 문장은 페이스/심박/케이던스를 조합한 간단한 형태부터 시작.
3. 백그라운드 오디오 모드랑 `AVAudioSession` 카테고리는 실제로 실기기에서 음악 틀어놓고 테스트하면서 맞춰본다.

다음엔 이 순서대로 실제 코드를 붙여볼 예정이다.
