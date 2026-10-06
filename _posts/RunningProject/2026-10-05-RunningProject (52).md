---
title: RunWay 1.4 (9) 사라진 게 아니라 늦은 5초
writer: Harold
date: 2026-10-05 09:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, OSLog, SwiftUI]

toc: true
toc_sticky: true
published: true
---

워치에서 러닝을 끝내면 아이폰도 같이 끝나야 한다. 그런데 간헐적으로 아이폰이 러닝 화면에 그대로 남는다. 1.3.1 때 제보가 들어왔고 1.4에서도 재현됐는데, 다시 해보면 멀쩡해서 조건을 못 잡고 있었다.

이번엔 로그를 받아봤다. 추측이 틀렸다는 것만 확실해졌다.

---

## 일곱 번을 전부 받아 적은 로그

200m씩 다섯 번, 그리고 긴 러닝 두 번. 아이폰 상태를 바꿔가며 했다. 러닝 화면을 켜둔 채로, 홈으로 뺀 채로, 화면을 끄고 주머니에, 다른 앱을 쓰는 중에, 그리고 앞 러닝이 끝나자마자 바로 다시.

```bash
sudo log collect --device --last 6h --output ~/runway.logarchive
log show ~/runway.logarchive --predicate 'subsystem == "com.haroldfromk.RunWay" AND category == "RemoteStop"' --style compact
```

일곱 번 모두 네 줄이 전부 찍혔다. 신호를 받았고(`receive`), 지금 러닝 것이 맞다고 판단했고(`handle`), 화면 쪽이 들었고(`vm.sink`), 정리까지 끝냈다(`vm.done`).

**한 번도 안 끊겼다.** 신호가 사라진 적이 없다.

| 받은 시각 | 배달 | 러닝 길이 | 저장 |
| --- | --- | --- | --- |
| 19:58:30 | 0.87s | 2.4분 | 92ms |
| 20:00:54 | 0.10s | 2.0분 | 80ms |
| 20:04:00 | 1.24s | 2.4분 | 72ms |
| 20:07:27 | 0.16s | 3.0분 | 80ms |
| 20:07:43 | 0.56s | 0.1분 | 15ms |
| 20:28:34 | 0.24s | 18.9분 | 78ms |
| 21:31:59 | 0.22s | **61.9분** | **101ms** |

배달은 신호에 실어 보낸 시각(`sentAt`)과 아이폰이 받은 시각의 차이다. 저장은 `vm.sink`와 `vm.done`의 차이고.

---

## 로그가 뒤집은 추측

긴 러닝은 좌표가 수천 개, 표본이 수백 개다. 그걸 솎아내고 저장하느라 느린 거라고 봤다. 화면이 빠지는 자리가 정리의 맨 끝에 매달려 있으니 말이 됐다.

```swift
Task {
    await self.flightActivityService.endActivity()
    await self.saveRunningData()
    await self.resetState()        // 맨 마지막 줄에서 navigationPath 를 비운다
}
```

**62분짜리 러닝이 101ms였다.** 2분짜리와 20ms 차이다.

거리가 많아서 느렸다는 설명은 여기서 끝났다. 그런데 그 62분 러닝은 실제로 **5초쯤 기다려야 홈으로 넘어갔다.** 로그가 말하는 시간을 다 더해도 0.4초가 안 된다.

**4.6초가 로그에 없다.**

---

## 양 끝이 비어 있던 시간축

흔적을 어디에 찍었는지 다시 봤다.

```
워치에서 버튼 누름
   ↓  ← 아무것도 없다
sentAt      21:31:59.128
receive     21:31:59.347
vm.done     21:31:59.448
   ↓  ← 여기도 없다
화면이 실제로 바뀜
```

로그는 **워치가 신호를 보낸 순간부터** 시작해서 **아이폰이 화면 경로를 비운 순간에** 끝난다. 양 끝이 비어 있다.

앞쪽이 특히 의심스러웠다. 워치 코드를 보니 이렇게 생겼다.

```swift
onEndFlight: {
    didNavigateToTouchdown = true
    Task {
        await viewModel.saveRunningData()   // 워치가 제 기록을 먼저 저장
        viewModel.updatePhase(.touchdown)   // 여기서야 stopWorkout()
        // 생략
    }
}
```

`.touchdown` 으로 넘어가야 워크아웃이 끝나고, **거기서 비로소 종료 신호가 나간다.** 그러니까 `sentAt` 은 이 체인의 시작이 아니라 끝이다.

워치가 62분치를 저장하는 건 아이폰의 101ms와 같지 않다. 훨씬 느린 기기다.

뒤쪽도 비어 있다. `navigationPath` 를 비우는 것과 SwiftUI 가 실제로 화면을 바꾸는 건 다른 일이다.

흔적을 세 개 더 찍었다.

```
watch.tapped  →  watch.saved  →  sentAt  →  receive  →  vm.done  →  pfd.gone
```

이제 시간축에 구멍이 없다. 긴 러닝 한 번이면 4.6초가 어디 있는지 나온다.

---

## 화면에 띄운 버려진 신호

이 버그는 **아무 일도 안 일어나는 게 증상**이다. 그래서 그 순간 뭐가 걸렸는지 알 방법이 없다. 집에 와서 로그를 받기 전까지는.

조용히 넘어가는 자리만 골라서 화면에 띄우기로 했다.

```swift
private static func isWorthShowing(step: String, detail: String) -> Bool {
    switch step {
    case "receive": return detail.contains("통과=false")
    case "vm.skipped", "send.failed": return true
    default: return false
    }
}
```

정상 경로는 뺐다. 제대로 처리되면 화면이 홈으로 돌아가는 걸로 이미 보이니 알림은 소음이다.

띄우는 자리는 러닝 화면이다. **그 화면에 그대로 남아 있는 게 증상**이니 거기가 맞다. 손에 든 화면에 바로 뜨면 캡처 한 장으로 끝난다.

전부 `#if DEBUG` 로 감쌌다. 배포 빌드에는 안 들어간다. Release 로도 따로 빌드해서 이 코드 없이 컴파일되는 걸 확인했다.

---

## 00초에서만 접히던 스테퍼

목표 페이스를 7분 00초로 맞추니 화면이 이렇게 됐다.

![목표 페이스 스테퍼에서 00 이 위아래로 나뉘어 보이는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-05-RunningProject-52/runway14_stepper_00.webp)

`0` 두 개가 가로로 안 붙고 위아래로 쌓였다. 다른 값에서는 멀쩡했다.

Orbitron 의 숫자 폭을 직접 재봤다. 칸은 50이다.

```
00   50.0pt   ← 안 들어감
05   49.9pt
55   49.8pt
30   49.8pt
```

**0.04pt 차이로 넘친다.** `0` 이 Orbitron 에서 제일 넓은 숫자고, 두 자리가 모두 `0` 인 경우는 `00` 하나뿐이다. 그래서 그 값에서만 접혔다.

```swift
Text(String(format: "%02d", targetPaceSec))
    .font(.orbitron(30, weight: .bold))
    .lineLimit(1)
    .frame(width: 56)
```

칸을 56으로 넓히고 한 줄로 못 박았다. 워치 요약 화면에서 글자가 잘렸던 것과 같은 종류다. **Orbitron 숫자 폭이 제각각이라 생기는 문제가 이걸로 세 번째다.**

---

## 한 자리에 겹친 핀 두 개

왕복 코스로 뛴 기록의 지도다.

![S 글리프 아래에 END 라고 적혀 있는 지도](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-05-RunningProject-52/runway14_loop_pin.png)

`S` 핀 아래에 `END` 라고 적혀 있다. 말이 안 되는 조합이다.

제자리로 돌아오는 코스라 출발점과 도착점이 거의 같은 자리다. 코드는 둘을 언제나 따로 찍는다.

```swift
start.title = "START"   // 글리프 S
end.title = "END"       // 글리프 F
```

둘이 겹치면서 나중에 그려진 `S` 핀이 `F` 핀을 덮었고, `F` 의 라벨만 밖으로 남았다. `displayPriority` 를 `.required` 로 둬서 맵킷이 겹친다고 하나를 숨겨주지도 않는다.

처음엔 가까우면 핀 하나로 합치려고 했다.

```swift
let apart = CLLocation(latitude: first.latitude, longitude: first.longitude)
    .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
if apart <= loopThreshold {
    // 생략
}
```

기준을 30m 로 잡았다. 핀 하나가 지도에서 덮는 넓이가 그 정도라고 봤다.

**그리고 다음 날 걷어냈다.** 기준이 틀렸다는 걸 다른 거리의 기록을 열어보고 알았다.

**겹치는지는 거리가 아니라 지도 축척이 정한다.** 10km 러닝은 지도가 넓게 잡혀서 48m 가 화면에서 몇 pt 로 붙어 보이고, 200m 러닝은 같은 48m 가 멀찍이 떨어져 보인다. 미터로 선을 그으면 **둘 중 하나는 반드시 틀린다.** 짧은 러닝에서는 멀쩡히 떨어진 두 핀을 합쳐버리고, 긴 러닝에서는 붙어 있는 두 핀을 그대로 둔다.

합치는 걸 포기하고 **색을 다르게** 했다.

```swift
case "START":
    view.markerTintColor = UIColor(Color.rwGreen)
    view.glyphText = "S"
case "END":
    view.markerTintColor = UIColor(Color.rwBlue)
    view.glyphText = "F"
```

겹쳐도 색이 다르면 핀이 두 개라는 게 보인다. **축척과 무관하게 항상 맞는다.** 화면에서 겹치는지를 묻는데 모델 좌표계의 거리로 답하려 한 것이 애초에 어긋난 질문이었다.

---

## 시뮬레이터로 돌린 10km

실기기로 제일 길게 뛴 게 62분이다. 그보다 데이터가 많은 기록은 한 번도 안 만들어봤다. 시뮬레이터의 위치 시뮬레이션(City Run)으로 10km를 돌렸다.

![워치에서 종료하자 아이폰이 홈으로 돌아가는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-05-RunningProject-52/runway14_sim_10km_stop.gif)

10.05km, 44분 49초. 워치에서 종료했고 아이폰도 따라서 홈으로 돌아갔다. 저장도 됐다.

표본이 500개를 넘고 스플릿이 10개다. **이 크기를 한 번 통과시킨 건 처음이다.**

### 따로 떨어져 있던 화면 전환

이번에 흔적을 양 끝까지 늘려둔 덕에 전에 못 보던 값이 하나 나왔다.

```
워치가 보냄   10:39:03.112
아이폰 받음   10:39:04.439    배달 1.33s
저장 끝       10:39:04.564    124ms
화면 빠짐     10:39:05.073    509ms
```

마지막 줄이 새로 보인 것이다. `navigationPath` 를 비우는 것과 화면이 실제로 바뀌는 건 다른 일이고, **그 사이가 0.5초였다.**

가운데 두 값은 실기기와 거의 같다. 배달은 실기기에서 0.10~1.24초였고 저장은 15~101ms였다. 시뮬레이터라고 특별히 빠르거나 느리지 않다.

그런데도 **5초는 안 나왔다.** 받은 뒤부터 화면이 빠지기까지 0.63초다.

### 여전히 못 잰 워치 구간

흔적을 워치에도 찍어뒀는데 한 줄도 안 남았다. 설치된 워치 앱 바이너리에 그 문자열이 분명히 들어 있는데도 그렇다.

```
아이폰 시뮬      앱이 쓴 로그 정상
워치 시뮬        449줄 전부 프레임워크 추적. 앱 로그 0줄
```

워치 시뮬레이터가 앱의 로그를 저장소에 안 남긴다. 그래서 **워치가 버튼을 받고 신호를 보내기까지**가 지금도 비어 있다.

5초가 있을 수 있는 자리는 이제 거기 하나다. 실기기 워치 로그를 받아야 한다.

---

## 정리

| | |
| --- | --- |
| 신호 유실 | 일곱 번 중 **0번** |
| 아이폰 저장 | 62분 러닝도 101ms |
| 실제 체감 | 약 5초 |
| 설명 안 되는 시간 | **4.6초** |

처음에는 "신호가 사라진다"로 보고 있었다. 로그를 받아보니 사라진 적이 없었다. 그러면 남는 건 **느리다**는 것뿐인데, 느린 자리가 아직 어디인지 모른다.

재는 자리를 늘려놨으니 다음 긴 러닝 한 번이면 나온다. 그 전까지는 확정할 수 없다.
