---
title: RunWay 1.3.1 HotFix
writer: Harold
date: 2026-09-02 07:00:00 +0900
categories: [RunWay]
tags: [GPS]

toc: true
toc_sticky: true
published: true
---

1.3을 배포하고 얼마 안 돼서 실제로 뛰다가 문제를 겪었다. 흐름은 이랬다. OVERSPEED(너무 빠름) 경고가 떠서 속도를 줄였더니 정상적으로 SINK RATE(너무 느림)로 바뀌었고, 다시 속도를 올렸는데 SINK RATE에서 안 돌아왔다. 화면에 뜨는 편차 숫자는 계속 커져서 나중엔 300초까지 갔고, 결국 앱이 강제 종료됐다.

배포한 지 얼마 안 된 버전에서 나온 문제라 밴드에이드로 덮지 않고 진짜 원인을 찾기로 했다. 원인을 정리하면 아래 흐름과 같다.

<picture>
  <source srcset="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-08-27-RunningProject-40/speed-accuracy-gap-flow-dark.png" media="(prefers-color-scheme: dark)">
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-08-27-RunningProject-40/speed-accuracy-gap-flow-light.png" alt="GPS 속도값을 못 믿을 때 정지 판단은 건너뛰지만 페이스 계산용 스무딩 값은 그대로 갱신되면서, 페이스가 계속 커지다 결국 앱이 강제 종료되는 흐름도">
</picture>

---

## 정지 판단과 페이스 계산이 서로 다른 걸 보고 있었다

RunWay는 GPS로 받은 순간 속도(`location.speed`)를 가지고 두 가지를 한다. 하나는 "지금 멈춰있는지" 판단하는 것(`isStationary`), 다른 하나는 그 속도로 페이스를 계산하는 것이다. 멈춰있을 땐 페이스를 얼려서 보여주는데(계속 재계산하면 멈춰있어도 숫자가 흔들리니까), 이 "멈춰있다"는 판단을 내릴 때 GPS가 알려주는 신뢰도 값(`speedAccuracy`)도 같이 본다. 이 신뢰도가 음수면 그 순간의 속도값 자체를 못 믿는다는 뜻이라, 정지 판단에는 아예 반영하지 않고 이전 상태를 그대로 둔다.

```swift
// RunningCenter.swift (기존 코드)
if location.speedAccuracy >= 0 {
    if compensatedSpeed < stationarySpeedThreshold {
        // 저속 지속 시간을 재서 정지 여부를 확정
    } else {
        isStationary = false
    }
}

// 생략

let rawPace: Double
if isStationary {
    rawPace = lastValidPace  // 멈춰있으면 얼린 값
} else {
    rawPace = 1 / (smoothingSpeedSecond * 60 / 1000)  // 아니면 매번 새로 계산
}
```

문제는 페이스 계산에 쓰는 스무딩 값(`smoothingSpeedSecond`, 속도를 부드럽게 만드는 이동평균)은 이 신뢰도 체크 없이 매 위치 업데이트마다 무조건 갱신되고 있었다는 거다. 오버스피드에 반응해서 속도를 확 줄이는 순간은 GPS 입장에서도 속도를 가늠하기 애매한 구간이라, 신뢰도가 음수로 찍히는 일이 흔했다. 그러면 "멈춰있다"는 확정은 못 되는데(위 코드에서 통째로 건너뛰니까), 스무딩 값은 계속 낮은 속도 쪽으로 끌려 내려간다.

멈춰있다는 확정이 안 됐으니 `isStationary`는 계속 `false`로 남고, 그럼 페이스는 계속 "새로 계산"하는 쪽 분기를 탄다. 근데 그 계산의 재료인 스무딩 속도는 계속 0에 가까워지고 있으니, 페이스(1÷속도)는 점점 커진다. 실제로는 사람은 다시 뛰고 있는데, 화면에 찍히는 페이스는 계속 나빠지는 쪽으로 갔던 거다.

---

## 왜 300초까지 가고, 왜 강제 종료까지 됐는가

이 상태에서 SINK RATE 판정은 페이스가 목표보다 계속 느려지는 방향으로 움직이니 당연히 계속 뜬다. 화면에 보여주는 편차 숫자(목표 페이스와의 차이를 초 단위로 바꾼 값)도 그 부풀어 오른 페이스를 그대로 따라가니 300초까지 올라간 거고, 사람이 실제로 속도를 올려도 이미 오염된 스무딩 값이 천천히 감쇠하는 방식이라 쉽게 회복이 안 됐다.

더 나쁜 건, 스무딩 속도가 계속 줄어들다 결국 컴퓨터가 표현할 수 있는 가장 작은 값보다도 작아져서 정확히 0으로 취급되는 순간이 온다는 점이다. 그러면 1÷속도가 무한대가 되는데, 이 무한대 값을 화면에 정수로 바꿔서 보여주려는 순간 정수로 바꿀 수 없는 값을 억지로 바꾸려 한 거라 그 자리에서 앱이 죽어버린다. 강제 종료의 정체가 이거였다.

정리하면, "정지 판단"과 "페이스 계산"이 같은 상황을 서로 다른 기준으로 보고 있었던 게 문제였다. 못 믿을 속도값은 정지 판단에서는 확실히 걸러지는데, 페이스 계산 쪽에는 그 필터가 안 걸려 있었던 거다.

### 숫자로 보면

페이스는 `1 ÷ 속도` 꼴이라 속도가 작아질수록 결과가 급격히 커진다. 나누는 값이 절반이 되면 결과는 두 배가 된다.

| 계산용 속도 | 나오는 페이스 | 목표(5'45")와 차이 |
|---|---|---|
| 2.9 m/s | 5'45" | 0초 |
| 2.0 m/s | 8'20" | +155초 |
| 1.5 m/s | 11'07" | +322초 |
| 1.0 m/s | 16'40" | +655초 |
| 0.5 m/s | 33'20" | +1655초 |
| 0 m/s | 무한대 | 앱 종료 |

속도가 2.9에서 2.0으로 떨어질 때는 페이스가 2분 반쯤 늘지만, 1.0에서 0.5로 떨어질 때는 **16분이 더 늘어난다.** 같은 0.5m/s 차이인데 결과가 이렇게 다르다. 0에 가까워질수록 걷잡을 수 없이 커지는 구간에 들어가는 것이다.

토글로 켜고 꺼보면서 값이 어떻게 벌어지는지 확인할 수 있게 만들어봤다. 회색으로 칠한 구간이 GPS 신뢰도가 음수인 구간이다.

<iframe
  src="/assets/demo/speed_accuracy_gate_simulator.html"
  width="100%"
  height="620px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

수정 전으로 두고 끝까지 재생하면 편차가 300초를 넘어간다. 실제로 화면에서 본 그 숫자다. 그리고 마지막 구간에서 **다시 정상 속도로 뛰고 있는데도 페이스가 안 돌아오는 것**까지 그대로 나온다. 수정 후로 바꾸면 신뢰도가 음수인 동안 계산용 속도가 한 값에서 멈춰 있는 게 보인다.

생각해보니 이게 한 번에 생긴 문제가 아니었다. 원래는 GPS 신호가 몇 초 이상 안 들어오면 멈춘 걸로 보는 방식이었는데, v1.3 준비하면서 그걸 지금의 raw 속도 기반 정지 판단으로 통째로 갈아엎었다. 그 다음엔 완전히 다른 이유로, 멈춰서 쉬는 동안 심박만 자연히 내려가도 SINK RATE가 떠버리는 걸 막으려고 정지 중엔 페이스와 GPWS를 얼리는 로직을 따로 추가했다. 각각은 그 순간엔 멀쩡한 이유로 손댄 거였는데, 정지 판단 쪽에 있던 "못 믿을 속도값은 건너뛴다"는 규칙이 나중에 추가한 "얼리는" 로직의 전제(정지 판단은 언젠가 확정된다)를 깨버릴 수 있다는 걸 그땐 몰랐다. 결국 한쪽만 고쳤으면 안 터졌을 문제가, 정지 판단 자체를 바꾼 게 이번 사고의 진짜 시작이었던 셈이다.

---

## 고친 방법

가장 단순하게, 스무딩 값을 갱신하는 코드를 정지 판단과 똑같은 신뢰도 체크 안으로 옮겼다. 못 믿을 속도값이면 정지 판단도, 페이스 계산도 둘 다 이전 상태를 그대로 유지하게 만든 거다.

```swift
// RunningCenter.swift (수정 후)
if location.speedAccuracy >= 0 {
    if compensatedSpeed < stationarySpeedThreshold {
        // 저속 지속 시간을 재서 정지 여부를 확정
    } else {
        isStationary = false
    }

    // 스무딩 갱신도 같은 신뢰도 체크 안으로 이동
    smoothingSpeedFirst = 0.85 * smoothingSpeedFirst + 0.15 * compensatedSpeed
    smoothingSpeedSecond = 0.85 * smoothingSpeedSecond + 0.15 * smoothingSpeedFirst
}
```

실기기(짧은 700m 구간)에서 OVERSPEED → NORMAL → SINK RATE → NORMAL이 정상적으로 돌아오는 것까지 확인했다. 버전은 1.4 작업과 구분하기 위해 1.3.1로 올렸다.

---

## 멈췄는데 진동이 계속 울리는 것도 있었다

이 수정을 확인하는 과정에서 별개의 문제를 하나 더 발견했다. 멈춰서 쉬는 중인데(Watch에서는 이 상태를 "일시정지"로 보여준다) SINK RATE/OVERSPEED 경고가 안 꺼지고 진동이 계속 울렸다.

원인은 정지 중에 GPWS 판정을 "얼리는" 기존 로직 자체에 있었다. 원래 이 로직은 심박 모드에서, 쉬면서 심박이 자연히 내려가는 것만으로 SINK RATE가 새로 뜨는 걸 막으려고 만든 거였다. 근데 방식이 "재계산을 아예 건너뛰고 멈추기 직전 상태를 그대로 유지"였다. 그러니까 하필 멈추기 직전이 SINK RATE나 OVERSPEED였으면, 그 경고 상태가 그대로 얼어붙어버린 거다.

```swift
// RunningCenter.swift (기존 코드)
if !isStationary {
    gpwsStatus = await determineGPWSStatus(pace: rawPace)
}
// isStationary가 true면 아무것도 안 하고 직전 gpwsStatus를 그대로 둔다
```

Watch의 경고 화면(`WatchGPWSView`)은 `gpwsStatus`가 normal이 아닐 때만 떠 있고, 이 화면이 떠 있는 동안엔 2초 간격으로 반복되는 햅틱 루프가 화면이 사라질 때까지(`onDisappear`) 계속 돈다. 얼어붙은 상태가 안 풀리니 화면도 안 사라지고, 진동도 정지 중 내내 안 끊겼던 거다.

고친 방법은 "얼리기" 대신 "정지 중엔 아예 normal로 되돌리기"다. 이러면 심박 하강으로 새 경고가 뜨는 것도 여전히 막히고, 멈추기 직전에 경고가 떠 있었어도 멈추는 순간 바로 사라진다.

```swift
// RunningCenter.swift (수정 후)
if isStationary {
    gpwsStatus = .normal
} else {
    gpwsStatus = await determineGPWSStatus(pace: rawPace)
}
```

빌드 번호를 5로 올려서 이전에 확인한 700m 테스트 빌드와 구분해뒀다. 두 수정 다 짧은 구간 확인은 끝났고, 실제로 길게 뛰면서(GPS 신호가 흔들리는 구간 포함) 재현 검증하는 절차가 남아있다. 이 부분은 확인되는 대로 이어서 적을 예정이다.
