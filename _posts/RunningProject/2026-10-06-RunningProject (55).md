---
title: RunWay 1.4 (12) 돌아오지 않는 저장 한 줄
writer: Harold
date: 2026-10-06 18:00:00 +0900
categories: [RunWay]
tags: [WatchConnectivity, HealthKit, OSLog, SwiftUI]

toc: true
toc_sticky: true
published: true
---

워치에서 러닝을 끝내면 아이폰도 같이 끝나야 한다. 그런데 간헐적으로 아이폰이 러닝 화면에 그대로 남는다.

**이건 내가 찾아낸 증상이 아니다.** 1.3.1 을 쓰던 지인이 그런 게 보인다고 알려줬고, 그 전까지 내 눈에는 한 번도 안 띄었다. 간헐적인 데다 다시 해보면 멀쩡해서 내가 쓰는 동안에는 그냥 지나갔던 것이다. 나도 최근에 테스트를 돌리다가 처음 봤다.

이번에 **정상일 때의 기록과 실패한 기록을 하루에 둘 다 받았고, 원인까지 나왔다.** 그동안 알게 된 걸 순서대로 적어두기만 해서 흩어져 있어서, 처음부터 한 번에 정리한다.

내용이 여러 글에 흩어져 있어서 순서를 다시 잡고 설명을 다듬는 데는 AI의 도움을 받아 글을 작성했다. 측정값과 로그는 전부 실제로 받은 것이다.

---

## 한 러닝에 기기가 두 대인 상태

RunWay 는 러닝을 아이폰에서 시작할 수도 있고 워치에서 시작할 수도 있다. 어느 쪽에서 끝내든 양쪽이 같이 끝나야 한다.

둘은 WatchConnectivity 로 이야기한다. 그런데 오가는 것이 두 종류고, **성질이 아주 다르다.**

<svg viewBox="0 0 680 246" width="100%" xmlns="http://www.w3.org/2000/svg" style="max-width:680px;display:block;margin:18px auto;color:inherit" role="img" aria-label="건강 데이터는 5초마다 계속 오고 종료 신호는 한 번만 간다">
  <g fill="none" stroke="currentColor" stroke-width="1.4" opacity="0.75">
    <rect x="8" y="42" width="92" height="166" rx="12"/>
    <rect x="580" y="42" width="92" height="166" rx="12"/>
  </g>
  <g fill="currentColor" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="13" text-anchor="middle">
    <text x="54" y="30" opacity="0.85">워치</text>
    <text x="626" y="30" opacity="0.85">아이폰</text>
  </g>

  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12.5" fill="currentColor">
    <text x="116" y="78" opacity="0.85">건강 데이터 · 5초마다</text>
    <text x="116" y="186" opacity="0.85">종료 신호 · 러닝당 한 번</text>
  </g>

  <g stroke="currentColor" stroke-width="1.6" opacity="0.55" fill="none">
    <polyline points="560,100 568,106 560,112"/>
    <line x1="112" y1="106" x2="146" y2="106"/>
    <line x1="172" y1="106" x2="206" y2="106"/>
    <line x1="292" y1="106" x2="326" y2="106"/>
    <line x1="352" y1="106" x2="386" y2="106"/>
    <line x1="412" y1="106" x2="446" y2="106"/>
    <line x1="472" y1="106" x2="506" y2="106"/>
    <line x1="532" y1="106" x2="566" y2="106"/>
  </g>
  <g stroke="#e05252" stroke-width="1.8">
    <line x1="236" y1="98" x2="258" y2="114"/>
    <line x1="258" y1="98" x2="236" y2="114"/>
  </g>
  <text x="247" y="134" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="11.5" fill="#e05252" text-anchor="middle">놓침</text>
  <text x="340" y="150" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12" fill="currentColor" opacity="0.6" text-anchor="middle">하나 놓쳐도 5초 뒤에 다음 게 온다</text>

  <g stroke="currentColor" stroke-width="2" opacity="0.55" fill="none">
    <polyline points="558,199 568,206 558,213"/>
    <line x1="112" y1="206" x2="300" y2="206"/>
    <line x1="340" y1="206" x2="566" y2="206"/>
  </g>
  <g stroke="#e05252" stroke-width="2.2">
    <line x1="309" y1="197" x2="331" y2="215"/>
    <line x1="331" y1="197" x2="309" y2="215"/>
  </g>
  <text x="340" y="236" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12" fill="#e05252" text-anchor="middle">놓치면 다음이 없다</text>
</svg>

건강 데이터는 흐르는 물이다. 한 번 못 받아도 5초 뒤에 또 온다. 그래서 중간에 몇 개 빠져도 러닝은 멀쩡히 굴러간다.

**종료 신호는 한 번뿐이다.** 러닝 하나에 딱 한 번 가고, 그게 안 가면 아이폰은 러닝이 끝났다는 걸 알 길이 없다. 재시도도 없다. 이 비대칭이 이 문제의 전부다.

---

## 내 눈에 안 띄던 증상

증상은 단순하다. 워치는 끝났는데 아이폰이 안 끝난다.

![워치는 TOUCHDOWN 인데 아이폰은 아직 러닝 중인 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_sim_stuck.gif)

왼쪽 워치는 요약 버튼이 떠 있는데, 오른쪽 아이폰은 `REC` 가 켜진 채로 20.09km, 1시간 29분을 계속 세고 있다. 이 상태로 두면 **실제로 뛰지 않은 거리와 시간이 기록에 계속 붙는다.** 20km 를 뛰고 21.7km 로 저장된 적이 있다.

조건을 못 잡은 이유는 두 가지다.

하나는 **조건이 안 잡힌다.** 짧은 러닝은 해볼 때마다 멀쩡했고, 긴 러닝에서만 났다. 그런데 긴 러닝도 날 때가 있고 안 날 때가 있다. 40분에서 나고 114분에서 안 난 적이 있어서 길이로 선을 그을 수가 없다.

다른 하나는 **아이폰 쪽에 남는 게 없다.** 신호가 안 오면 아이폰은 아무 일도 안 일어난 상태다. 받은 적 없는 메시지는 기록할 방법이 없다. 신호가 워치에서 안 나갔는지, 가다가 없어졌는지, 와서 버려졌는지를 아이폰 로그로는 구분할 수 없다.

---

## 종료 버튼을 누른 뒤의 10초

그래서 **워치 쪽에 흔적을 남기기로 했다.** 버튼에서 신호가 나가기까지 거치는 자리마다 한 줄씩이다.

이번에 그 흔적으로 정상 종료를 끝까지 받았다. 아래는 그 시간을 그대로 옮긴 것이다. 위 버튼으로 경우를 바꿔가며 볼 수 있다.

가운데 띠가 두 기기 사이를 오가는 신호다. **종료 버튼을 누르기 전부터 재생된다.** 흐르던 건강 데이터가 끊기고 그 뒤에 종료 신호 하나가 올라가는 모양을 보기 위해서다. 실패하는 경우에는 그 하나가 끝내 안 올라가고, 10초와 15초에 아이폰이 어떻게 반응하는지가 같이 나온다.

<style>
.rw-stop-sim {
  width: 100%;
  height: 1015px;
  border: 1px solid rgba(120, 113, 108, 0.2);
  border-radius: 16px;
  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
}
@media (max-width: 640px) { .rw-stop-sim { height: 1325px; } }
</style>

<iframe
  class="rw-stop-sim"
  src="/assets/demo/watch_stop_trace_simulator.html"
  scrolling="no"
  loading="lazy"
></iframe>

다섯 가지 모두 **고치기 전의 순서**다. 바뀐 뒤의 모습은 글 끝에 적었다.

네 가지 실패를 하나씩 눌러보면 한 가지가 눈에 띈다. **워치 쪽 흔적은 경우마다 다른데, 아이폰 쪽은 전부 똑같이 비어 있다.** 아이폰 로그만 들여다봐서는 아무것도 못 가렸던 이유가 이거다.

실제로 받은 줄은 이렇다. 20km, 1시간 24분짜리 러닝이다.

```
18:26:26 [watch.tapped]     종료 버튼. 저장 시작
18:26:26 [watch.saved]      워치 저장 끝, touchdown 으로
18:26:26 [stopWorkout]      세션=상태2 startOrigin=remote
18:26:28 [watch.state]      toState=6 처리=stopped
18:26:28 [watch.finishing]  워크아웃 마무리 시작
18:26:28 [watch.state]      toState=3 처리=other
18:26:34 [watch.finished]   워크아웃 마무리 끝
18:26:34 [watch.sink]       stopOrigin=local
18:26:34 [send.message]     바로 보냄
18:26:34 [watch.published]  stopOrigin=local 으로 발행
```

여기서 신호가 나가고, 아이폰 쪽에 이어서 찍힌다.

```
18:26:35 [receive]  통과=true
18:26:35 [handle]   stopOrigin 을 remote 로 두고 상태 발행
18:26:35 [vm.sink]  처리중=false 러닝중=true
18:26:35 [vm.done]  정리 끝, navigationPath 비움
18:26:36 [pfd.gone] PFD 가 화면에서 빠짐
```

버튼부터 홈 화면까지 **10초**다. 그동안 아이폰은 9초째까지 아무것도 모르고 계속 세고 있었다.

---

## 신호가 저장 뒤에 줄 서 있는 구조

10초 중 **6초가 한 줄에서 나왔다.** `watch.finishing` 과 `watch.finished` 사이다.

```swift
if toState == .stopped {
    await finishWatchWorkout(at: date)   // 여기가 6초
    updateAndSendState(event)            // 끝나야 돈다
}
```

`finishWatchWorkout` 안은 이렇다.

```swift
func finishWatchWorkout(at date: Date) async {
    do {
        if let session, session.state != .ended {
            session.end()
        }
        try await builder?.endCollection(at: date)
        workout = try await builder?.finishWorkout()
    } catch {
        alertPublisher.send(AlertContext.workoutSessionFailed)
    }
}
```

`session.end()` 는 바로 돌아왔다. 흔적에서 `toState=3` 이 6초가 끝나기 전인 18:26:28 에 찍힌 게 그 증거다. 세션은 그때 이미 닫혔다.

느린 건 아래 두 줄, HealthKit 의 `endCollection` 과 `finishWorkout` 이다. 워크아웃을 닫고 건강 앱에 쓰는 일이다.

문제는 그 다음 줄이 종료 신호라는 것이다. `updateAndSendState` 가 발행을 하고, 그 발행을 받아서 신호가 나간다. 그러니 **아이폰은 워치의 저장이 끝날 때까지 기다리는 구조다.** 아이폰이 제 러닝을 끝내는 데 워치의 저장이 끝날 이유는 없는데도 그렇다.

6초로 끝나면 10초 만에 홈으로 간다. **안 끝나면 신호는 영영 안 나간다.** 그리고 같은 날 밤에 그게 실제로 났다.

같은 흔적에서 하나 더 보인다. 18:26:28 의 `toState=3 처리=other` 다.

```swift
if toState == .stopped {
    // 발행
} else if toState == .running {
    // 발행
}
// 그 외는 아무것도 안 한다
```

`.ended` 는 어느 갈래에도 안 들어간다. 이번엔 `.stopped` 가 먼저 와서 넘어갔지만, 순서가 바뀌어 `.ended` 로 바로 가면 이벤트가 아예 안 나간다. 두 갈래만 적어두면 나머지는 없는 것처럼 느껴지는데, **실제로는 나머지로 빠졌을 때 가장 조용하다.**

---

## 시뮬레이터에서 안 남던 워치 로그

흔적을 남기기로 한 다음에 막힌 데가 있었다. **재현되는 곳에서는 못 읽고, 읽을 수 있는 곳에서는 재현이 안 됐다.**

증상은 시뮬레이터에서 긴 러닝을 돌리면 잘 났다. 그런데 워치 시뮬레이터에서 우리 앱이 남긴 줄을 꺼내려고 하면 한 줄도 안 나왔다. 6시간 치를 뒤져도 0줄인데, 같은 시간대 시스템 앱 로그는 멀쩡히 쌓여 있었다. **워치 시뮬레이터가 앱이 쓴 로그를 저장소에 안 남기는 것이다.** 실기기에서는 멀쩡하지만, 실기기에서는 증상이 잘 안 난다.

그래서 같은 줄을 앱 폴더 안 파일에도 쓰기로 했다.

```swift
extension RemoteStopLogger {

    /// 쓰는 자리가 여러 액터에 걸쳐 있어 순서를 보장하려고 직렬 큐를 둔다.
    private static let fileQueue = DispatchQueue(label: "...RemoteStopTrace")

    /// 앱 폴더 안 기록 파일. 러닝마다 지우지 않고 계속 덧붙인다.
    private static var traceURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("remote-stop-trace.log")
    }

    static func appendToFile(_ step: String, _ detail: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) [\(step)] \(detail)\n"
        fileQueue.async {
            guard let url = traceURL, let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
```

### 값을 꺼내는 세 가지 자리

읽을 데가 세 군데인데 방법이 다 다르다. 매번 찾아 헤매서 한 번에 정리해둔다. 아래에서 `<워치-UDID>` 같은 건 각자 기기 값이라 그대로 두고, 바로 아래 방법으로 찾아 넣으면 된다.

**시뮬레이터, 앱이 남긴 파일.** 기기 번호부터 찾는다.

```bash
xcrun simctl list devices booted
```

켜져 있는 기기만 나온다. 거기 괄호 안의 긴 문자열이 UDID 다. 그걸로 앱 폴더를 묻는다.

```bash
cat "$(xcrun simctl get_app_container <워치-UDID> <워치-번들ID> data)/Documents/remote-stop-trace.log"
```

경로를 직접 적지 않고 `get_app_container` 에 묻는 게 핵심이다. 앱 폴더 번호는 설치할 때 정해지는데 **지우고 다시 깔면 바뀐다.** 묻는 방식으로 쓰면 바뀌어도 같은 명령이 계속 통한다.

두 기기를 짝으로 봐야 하니 둘 다 꺼내는 쪽이 낫다.

```bash
W=$(xcrun simctl get_app_container <워치-UDID> <워치-번들ID> data)
P=$(xcrun simctl get_app_container <폰-UDID> <폰-번들ID> data)
echo "=== 워치 ==="; tail -12 "$W/Documents/remote-stop-trace.log"
echo "=== 아이폰 ==="; tail -12 "$P/Documents/remote-stop-trace.log"
```

**시뮬레이터, 시스템이 남긴 로그.** 우리 앱 로그는 안 남지만 시스템 쪽은 남는다. 원인이 나온 자리가 여기였다.

```bash
xcrun simctl spawn <워치-UDID> log show --last 10m \
  --predicate 'subsystem == "com.apple.HealthKit"' --style compact
```

`subsystem` 을 바꾸면 다른 것도 본다. 전송 쪽을 보려면 `'process == "wcd"'` 로 거른다. 그냥 받으면 수만 줄이 나오니 **시간 범위와 조건을 반드시 같이 준다.**

**실기기.** 시뮬레이터와 달리 앱 로그가 멀쩡히 남는다. 대신 꺼내는 방법이 다르다.

```bash
sudo log collect --device-name "<기기 이름>" --last 30m --output ~/runway.logarchive
log show ~/runway.logarchive --predicate 'subsystem == "<우리 subsystem>"' --style compact
```

여기서 두 번 걸렸다. 하나는 `sudo` 없이는 안 된다는 것, 다른 하나는 **같은 이름의 파일이 이미 있으면 "File exists (17)" 로 끝난다**는 것이다. 지우고 다시 받으면 된다.

그리고 로그 등급을 조심해야 한다. `.notice` 이상만 디스크에 남고 **`.info` 는 메모리에만 있다가 사라진다.** 나중에 꺼내 볼 생각이면 처음부터 `.notice` 로 남겨야 한다.

Console 앱으로 보는 방법도 있는데 이 문제에는 안 맞았다. **기기 보기는 실시간 흘러가는 것만 보여준다.** 러닝하는 동안 맥에 연결해두고 창을 켜놓지 않았으면 아무것도 안 남는다. 증상이 언제 날지 모르는 상황에서는 쓸 수 없다.

이렇게 바꾸고 얻은 게 두 가지다.

파일이라 **지켜보고 있을 필요가 없다.** 전에는 증상이 난 순간에 로그를 열어야 했는데, 이제는 러닝을 돌려놓고 나중에 읽으면 된다. 러닝마다 지우지 않고 덧붙이니까 성공한 기록과 실패한 기록이 한 파일에 같이 쌓인다.

그리고 읽을 때 조심할 게 하나 생겼다. 위 기록에서 `watch.finishing` 다음 줄이 6초 뒤에 찍혔는데, **그 6초 안에 읽으면 멈춘 것처럼 보인다.** 멈춘 것과 아직 저장 중인 것이 파일상 구분이 안 된다. 1분쯤 간격으로 두 번 읽어서 같아야 멈춘 것이다.

---

## 15초라는 안전장치

원인을 모르는 동안에도 사용자가 겪는 피해는 줄여야 했다. 신호가 안 오는 걸 아이폰이 눈치채고 물어보게 만들었다.

처음 잡은 값은 **60초**였다. 워치가 건강 데이터를 5초 간격으로 보내니 그 열두 배면 넉넉하겠다는 계산이었다. 간격의 배수라는 건 근거처럼 들리지만 **실제로 얼마나 끊기는지는 재보지 않은 숫자**다. 보내는 간격과 도착하는 간격은 같지 않다.

기준을 정하려고 실기기에서 잰 값을 썼다. 11.3km, 1시간 53분 러닝에서 워치가 보낸 메시지가 1398개였고, 도착 간격은 중앙값 5.1초에 95%가 5.2초 안쪽이었다. **러닝 중 가장 길게 끊긴 것이 10.5초다.**

그보다 길게 끊긴 구간이 하나 있었는데 18.7초였고, 그건 종료 버튼을 누른 뒤 워치가 제 기록을 저장하던 구간이라 러닝 중 값이 아니다. 그래서 10.5초 위, 넉넉하지 않게 **15초**로 잡았다. 60초는 재보고 나니 네 배 가까이 느슨한 값이었다.

더 길게 잡는 쪽이 안전해 보이지만 그쪽이 오히려 손해다. 이 알림을 못 본 사람은 몇 초 만에 포기하고 아이폰에서 직접 끝내버리는데, 그러면 기록에 그 시간이 통째로 더 붙는다. 기다리게 하는 비용보다 모르고 방치하는 비용이 크다.

두 단계로 나눴다. 10초에는 화면 아래에 기다리는 중이라는 표시만 띄우고, 15초에 끝낼지 묻는다.

![러닝 화면 아래에 AWAITING WATCH 표시가 뜬 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_awaiting_watch.png)

1단계는 이렇게 생겼다. 러닝을 덮지 않고 아래쪽에만 뜬다. 신호가 다시 오면 조용히 사라진다.

```swift
private func checkWatchSilence() {
    guard isRunning, let last = lastWatchHealthAt else { return }
    let silence = Date().timeIntervalSince(last)

    // 1단계. 기다리는 중이라는 표시만. 신호가 오면 저절로 사라진다.
    isWaitingForWatch = silence >= watchWaitingThreshold

    // 2단계. 여기서부터 끝낼지 묻는다. 한 번 끊김에 한 번만.
    guard !hasAskedWatchEnded, silence >= watchSilenceThreshold else { return }
    hasAskedWatchEnded = true
    isAskingWatchEnded = true
}
```

10초에서 끝났다고 말하지 않는 건 이 시점에 아는 게 **"데이터가 안 온다"뿐**이기 때문이다. 진짜 끝난 건지 잠깐 끊긴 건지는 모른다. 뛰는 중에 "종료 중"이 뜨면 멀쩡히 달리던 사람이 멈춰 선다.

알림은 끝내지 않고 묻기만 한다. 아이폰이 아는 건 데이터가 안 온다는 것뿐이고, 그걸로 남의 러닝을 대신 끝낼 수는 없다.

![워치에서 데이터가 15초 넘게 오지 않았다는 알림이 뜬 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_lost_contact.webp)

### 떠야 할 때 안 뜨던 알림

만들어두고 한참 뒤에야 **알림이 안 뜨는 걸 봤다.** 워치가 조용해졌고 AWAITING WATCH 는 멀쩡히 떠 있는데 15초가 지나도 알림만 안 나왔다. 흔적에는 묻기로 한 줄이 찍혀 있었으니 값은 켜져 있었다.

```swift
// 안 뜨던 쪽
.alert("LOST CONTACT", isPresented: Binding(
    get: { runViewModel.isAskingWatchEnded },
    set: { runViewModel.isAskingWatchEnded = $0 }
))

// 같은 화면에서 잘 뜨던 쪽
@State private var showAlert = false
.alert(..., isPresented: $showAlert, ...)
.onChange(of: runViewModel.didError) { _, new in if new { showAlert = true } }
```

차이는 하나다. 안 뜨던 쪽만 뷰모델 값을 그 자리에서 직접 감싸 쓴다. 잘 뜨던 쪽으로 모양을 맞췄다.

**왜 안 됐는지는 끝까지 못 밝혔다.** 같은 화면의 표시는 같은 값이 바뀔 때 잘 떴으니 화면이 멈춘 것도 아니었다. 작동하는 쪽으로 옮겼을 뿐이고, 이건 고친 게 아니라 피한 것에 가깝다.

고치고 나서는 일부러 끊어서 확인했다. 러닝 중에 워치 앱을 강제 종료하면 아이폰 입장에서는 데이터가 끊긴 것과 같다.

![워치 앱을 강제 종료하자 아이폰에 AWAITING WATCH 와 LOST CONTACT 가 차례로 뜨는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_lost_contact_test.gif)

10초에 표시가 뜨고 15초에 알림이 떴다. 계속 뛰기를 누르면 알림만 닫히고 러닝은 이어지고, 러닝 종료를 누르면 그 자리에서 저장된다. 둘 다 눌러서 확인했다.

내리는 조건을 안 적어서 한 번 더 걸렸다. 시뮬레이터에서 연결이 잠깐 끊겨 알림이 떴고, 그 뒤에 워치 데이터가 다시 5초 간격으로 들어오고 있었는데 **10분 뒤에도 알림이 그대로 떠 있었다.**

```swift
vm?.lastWatchHealthAt = .now
vm?.hasAskedWatchEnded = false
vm?.isWaitingForWatch = false
vm?.isAskingWatchEnded = false   // 이 줄이 없었다
```

데이터를 받을 때마다 기다림 표시는 껐는데 **띄워둔 알림을 내리는 건 빠뜨렸다.** 거슬리는 정도로 끝나지 않는다. 그 알림에서 러닝 종료를 누르면 멀쩡히 살아서 기록 중인 러닝이 끝난다.

띄우는 조건을 정하는 데는 실기기 1398개를 재면서 공을 들였는데, 내리는 조건은 아예 생각을 안 했다. 조건 하나를 넣으면 반대쪽 조건도 같이 적어야 한다.

---

## 영영 안 끝난 마무리

안전장치를 넣은 날 밤에 그 상태가 났다. 1시간 18분 56초를 돌리고 워치에서 끝냈다.

![워치는 TOUCHDOWN 인데 아이폰은 AWAITING WATCH 를 띄운 채 계속 세고 있는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_hang_awaiting.gif)

워치는 요약 화면으로 넘어갔는데 아이폰은 `REC` 가 켜진 채다. 아래쪽에 AWAITING WATCH 가 돌고 있다.

흔적을 열었다.

```
20:53:05.075  watch.tapped      종료 버튼. 저장 시작
20:53:05.078  stopWorkout       세션=상태2 startOrigin=remote
20:53:07.219  watch.state       toState=6 처리=stopped
20:53:07.219  watch.finishing   워크아웃 마무리 시작
20:53:07.220  watch.state       toState=3 처리=other
```

**`watch.finished` 가 없다.** 아이폰 쪽에는 `receive` 도 없다. 신호가 워치를 떠난 적이 없다는 뜻이다.

9분을 기다려도 안 왔다. 성공했을 때 같은 구간이 6.0초였으니 **느린 게 아니라 멈춘 것**이다.

### 심박 회복이 붙잡고 있던 세션

여기서 더 들어갈 수 있었던 건 워치의 HealthKit 로그가 시뮬레이터에도 남기 때문이다. 우리 앱 로그와 달리 시스템 쪽이라 살아 있다.

```
05:53:07.207  <target-stop(6): FinalizeActivity(12) -> StoppedHeartRateRecovery(14)>
05:53:07.208  <target-ended(3): StoppedHeartRateRecovery(14) -> HeartRateRecovery(15)>

05:53:10.731  <HDWorkoutBuilderServer AwaitingFinalData(3)>: Ending collection
05:53:10.732  <HDWorkoutBuilderServer Saving(5)>: <finish(3): Ended(4) -> Saving(5)>

      (3분 17초 아무 기록 없음)

05:56:27.219  <HDWorkoutSessionServer [finished]>: Finishing associated builder.
05:56:27.220  Not automatically finishing builder: Builder server is still present.
05:56:27.220  <end-heart-recovery(107): HeartRateRecovery(15) -> Finished(16)>
```

**느린 건 `endCollection` 이 아니었다.** 수집 종료(`Ending collection`)는 3.5초에 끝났다. 그 다음 `finishWorkout` 이 `Saving` 에 들어가서 안 나온다.

워크아웃이 멈추면 watchOS 는 **심박 회복을 재려고 세션을 3분 넘게 더 붙잡는다.** 그 사이 저장은 `Saving` 에 갇혀 있고, 세션이 드디어 끝났을 때 시스템은 저장을 정리하려다 "저장하는 쪽이 아직 살아 있다"며 물러선다. 서로를 기다리는 모양이고 9분이 지나도 안 풀렸다.

여기까지가 **멈춘 자리**다. 처음엔 이 심박 회복 구간이 원인이라고 생각했는데, 나중에 성공한 러닝을 같은 방식으로 들여다보고 그게 아니라는 걸 알았다.

| | 러닝 길이 | endCollection | Saving | 결과 |
| --- | --- | --- | --- | --- |
| 멈춘 것 | 1시간 18분 | 3.5초 | **안 나옴** | 교착 |
| 성공한 것 | 6시간 41분 | 19.5초 | 6.5초 | 26초에 끝 |

**둘 다 심박 회복 구간 안에서 돌았다.** 하나는 나오고 하나는 안 나왔다. 데이터 양도 아니다. 6시간 41분짜리가 쓸 게 훨씬 많았는데 그게 끝났고, 멈춘 쪽은 오히려 데이터베이스 쓰기가 0.007초로 빨랐다. `Saving` 에 들어간 뒤에도 샘플 501개가 정상적으로 기록됐다. **일은 다 됐는데 상태만 안 바뀌었다.**

그래서 지금 말할 수 있는 건 **어디서 멈추는지**까지다. 왜 어떤 러닝에서만 그러는지는 모른다. 길이도 아니고 데이터 양도 아니고 심박 회복에 들어갔느냐도 아니다.

### 기록에 더 붙은 9분

```
19:34:08  러닝 시작
20:53:05  워치에서 종료        → 실제 1:18:56
21:02:15  아이폰에서 직접 종료   → 저장된 기록 1:28:06
```

**9분 10초가 더 기록됐다.** FLIGHT DATA RECORDER 에서 BPM 줄이 PACE 줄보다 일찍 끊기는 구간이 이 9분이다. 워치가 심박을 안 보내는 동안 아이폰 GPS 는 계속 그렸다.

반대 방향은 멀쩡했다. 아이폰이 보낸 종료 신호는 **1.5초** 만에 워치에 닿았다.

### 순서를 뒤집은 것

```swift
// 전
await finishWatchWorkout(at: date)   // 안 끝나면 여기서 영영
updateAndSendState(event)

// 후
updateAndSendState(event)
await finishWatchWorkout(at: date)
```

저장을 없앤 게 아니라 **신호 뒤로 보냈다.** 아이폰이 제 러닝을 끝내는 데 워치의 저장이 끝날 이유가 없으니, 저장이 3분이 걸리든 안 풀리든 아이폰은 1초 만에 홈으로 간다.

고치고 1시간 16분을 다시 돌려봤다.

```
22:30:50.228  watch.tapped      종료 버튼
22:30:52.367  send.message      바로 보냄            ← 신호가 먼저
22:30:52.367  watch.finishing   워크아웃 마무리 시작   ← 저장은 그 다음
22:30:56.614  watch.finished    워크아웃 마무리 끝

22:30:53.442  [아이폰] pfd.gone  PFD 가 화면에서 빠짐
```

| | 고치기 전 성공 | 고치기 전 실패 | 고친 뒤 |
| --- | --- | --- | --- |
| 러닝 길이 | 1:24:41 | 1:18:56 | 1:16:03 |
| 버튼 → 아이폰 홈 | 10.0초 | 영영 안 감 | **3.2초** |
| 워치 저장 | 6.0초 | 안 끝남 | 4.25초 |
| 기록에 더 붙은 시간 | 없음 | 9분 10초 | 없음 |

제일 중요한 줄은 시간이 아니라 순서다. **저장이 끝나기 3.17초 전에 아이폰은 이미 홈이었다.** 저장이 4초가 걸리든 안 끝나든 아이폰은 기다리지 않는다.

남은 2.14초는 버튼을 누르고 상태 변화 알림이 오기까지다. 시스템 로그에 "멈춤 이벤트를 2초 안에 못 받아 흉내낸 것을 만든다"고 적히는 그 구간이라 우리 쪽에서 줄일 자리가 아니다.

### 실기기에서 일곱 번

시뮬레이터 한 번으로는 못 믿겠어서 고친 빌드를 실기기에 올리고 하루 동안 종료를 일곱 번 눌렀다.

| 종료 시각 | 신호 나가기까지 | 워치 저장 | 순서 |
| --- | --- | --- | --- |
| 19:15 | 1.07초 | 1.24초 | 신호 먼저 |
| 21:50 | 1.09초 | 2.35초 | 신호 먼저 |
| 22:03 | 0.40초 | 2.28초 | 신호 먼저 |
| 22:50 | 2.55초 | 0.32초 | 신호 먼저 |
| 22:54 | 0.27초 | 0.96초 | 신호 먼저 |
| 23:40 | 0.36초 | **7.95초** | 신호 먼저 |
| 23:57 | 0.28초 | 2.71초 | 신호 먼저 |

일곱 번 다 신호가 먼저 나갔다. 눈여겨볼 줄은 23:40 이다. 워치 저장이 **7.95초** 걸렸는데 신호는 0.36초에 이미 나가 있었다. 고치기 전이었으면 그 7.95초를 아이폰이 통째로 서서 기다렸을 자리다.

저장 시간이 0.32초에서 7.95초까지 **스물다섯 배 차이**가 난다는 것도 같이 남는다. 같은 기기, 같은 코드인데 그렇다. 이 줄 뒤에 종료 신호를 세워두면 안 되는 이유가 평균이 아니라 이 폭에 있다.

아이폰 쪽은 신호를 받고 정리를 끝내기까지 **60~120밀리초**로 일곱 번이 거의 같았다. 시뮬레이터에서 101밀리초로 쟀던 값이 실기기에서도 그대로다.

### 화면이 늦게 바뀐 두 번

대신 다른 게 걸렸다. `navigationPath` 를 비우는 것과 화면이 실제로 바뀌는 건 다른 일인데, 그 사이가 실기기에서 들쭉날쭉했다.

| | 정리 끝까지 | 화면이 바뀌기까지 |
| --- | --- | --- |
| 다섯 번 | 60~120밀리초 | 0.08~0.64초 |
| 한 번 | 112밀리초 | **4.6초** |
| 한 번 | 88밀리초 | **11.7초** |

11.7초짜리는 데이터가 다 저장되고 경로도 비워진 뒤에 화면만 11.7초를 더 러닝 화면이었다는 뜻이다. 그 11초 동안 쓰는 사람 눈에는 **고치기 전과 구별이 안 된다.**

짐작은 있다. 늦은 두 번은 러닝 중에 아이폰이 주머니에 있었을 때이고, 빠른 다섯 번은 내가 화면을 보면서 누른 때다. 화면이 꺼져 있으면 화면 갱신이 미뤄지니 깨어날 때까지 안 바뀌는 게 이상한 일은 아니다. **다만 확인은 못 했다.** 흔적에 화면이 켜져 있었는지가 안 남아 있다.

확인했어도 1.4 에 손댈 자리는 아니라고 봤다. 영영 안 가는 것과 11.7초는 다르고, 주머니에서 꺼내 볼 때는 이미 바뀌어 있다.

이 재현에서 LOST CONTACT 알림이 아예 안 뜬 것도 같이 고쳤다. 같은 화면의 AWAITING WATCH 는 멀쩡히 떠 있었으니 값은 분명히 켜져 있었는데 알림만 안 나왔다. 뷰모델 값을 그 자리에서 `Binding` 으로 감싸 쓰고 있었던 건데, 같은 화면의 다른 경고가 쓰는 `@State` 와 `onChange` 방식으로 맞췄다. 이유를 끝까지 못 밝힌 건 남는다. **작동하는 쪽으로 맞췄을 뿐 왜 안 됐는지는 설명하지 못한다.**

---

## 네 번까지만 보이던 달력 점

같은 날 두 번 뛰면 달력 칸에 점이 두 개 찍힌다. 거리만 보이면 두 번 뛴 것이 한 번 길게 뛴 것처럼 읽혀서 넣어둔 표시다.

그런데 점을 네 개에서 끊고 있었다.

```swift
ForEach(0..<min(runCount, 4), id: \.self) { _ in
    Circle().fill(Color.rwBg.opacity(0.65)).frame(width: 3, height: 3)
}
```

끊은 것 자체는 맞다. 한 칸이 가로를 7등분한 폭이라 점을 계속 늘리면 날짜와 거리가 밀린다. 문제는 **네 번 뛴 날과 여섯 번 뛴 날이 똑같아 보인다**는 것이다.

점을 더 찍는 대신 몇 개 더 있는지만 작게 붙였다.

```swift
if runCount > 4 {
    Text("+\(runCount - 4)")
        .font(.orbitron(8, weight: .bold))
        .foregroundColor(Color.rwBg.opacity(0.65))
        .offset(y: -1)
}
```

점 네 개가 21pt, 거기에 글자가 붙어도 38pt다. 제일 좁은 기기에서 한 칸이 44pt쯤이라 들어간다.

![달력 칸에 점 네 개와 +5 가 함께 표시된 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-06-RunningProject-56/runway14_calendar_plus.webp)

이날 시뮬레이터를 하도 돌려서 3일에 아홉 번이 쌓였다. 덕분에 평소라면 안 나왔을 `+5` 를 바로 확인했다.

---

## 1.3.2 부터 달라진 한 줄

원인을 알고 나서 한 가지가 걸렸다. **그 전에는 이런 게 없었다는 것.** 제보가 1.3.1 에 들어왔고 1.3.2 에서 다시 났는데, 그 사이에 뭘 건드렸길래 갑자기 이러나 싶었다.

기록을 뒤져보니 한 줄이 자리를 옮겨 있었다.

```swift
// 1.3.1 까지
try await builder?.endCollection(at: date)
workout = try await builder?.finishWorkout()
session?.end()                               // 저장 다 끝내고 세션 종료

// 1.3.2 부터
if let session, session.state != .ended { session.end() }   // 세션 먼저 종료
try await builder?.endCollection(at: date)
workout = try await builder?.finishWorkout()                // 그 다음 저장
```

`session.end()` 가 심박 회복을 시작시키는 자리다. 자리가 바뀌면서 저장이 그 창 안으로 들어갔다.

<svg viewBox="0 0 680 300" width="100%" xmlns="http://www.w3.org/2000/svg" style="max-width:680px;display:block;margin:18px auto;color:inherit" role="img" aria-label="세션 종료 위치가 바뀌면서 저장이 심박 회복 구간과 겹치게 된 과정">
  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" fill="currentColor">
    <text x="8" y="22" font-size="12.5" opacity="0.75">1.3.1 까지</text>
    <text x="8" y="172" font-size="12.5" opacity="0.75">1.3.2 부터</text>
  </g>

  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="11.5" text-anchor="middle">
    <rect x="8" y="36" width="190" height="34" rx="8" fill="none" stroke="currentColor" stroke-width="1.3" opacity="0.55"/>
    <text x="103" y="58" fill="currentColor" opacity="0.9">저장 (endCollection · finish)</text>
    <rect x="214" y="36" width="120" height="34" rx="8" fill="none" stroke="currentColor" stroke-width="1.3" opacity="0.55"/>
    <text x="274" y="58" fill="currentColor" opacity="0.9">session.end()</text>
    <rect x="350" y="36" width="230" height="34" rx="8" fill="none" stroke="currentColor" stroke-width="1.3" opacity="0.3" stroke-dasharray="4 3"/>
    <text x="465" y="58" fill="currentColor" opacity="0.6">심박 회복 3분</text>
  </g>
  <text x="8" y="96" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12" fill="currentColor" opacity="0.6">저장이 다 끝난 뒤에 심박 회복이 시작된다. 겹치지 않는다.</text>

  <g stroke="currentColor" stroke-width="1" opacity="0.18">
    <line x1="8" y1="124" x2="672" y2="124"/>
  </g>

  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="11.5" text-anchor="middle">
    <rect x="8" y="186" width="120" height="34" rx="8" fill="none" stroke="currentColor" stroke-width="1.3" opacity="0.55"/>
    <text x="68" y="208" fill="currentColor" opacity="0.9">session.end()</text>
    <rect x="144" y="186" width="436" height="34" rx="8" fill="none" stroke="currentColor" stroke-width="1.3" opacity="0.3" stroke-dasharray="4 3"/>
    <text x="362" y="208" fill="currentColor" opacity="0.6">심박 회복 3분</text>
    <rect x="160" y="228" width="190" height="34" rx="8" fill="none" stroke="#e05252" stroke-width="1.6"/>
    <text x="255" y="250" fill="#e05252" font-weight="700">저장이 이 안에서 돈다</text>
  </g>
  <text x="8" y="286" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12" fill="#e05252" opacity="0.95">세션이 아직 살아 있는 구간에서 저장이 시작되고, 거기서 안 돌아온다.</text>
</svg>

옛 순서에서는 **저장이 다 끝난 뒤에 세션이 끝나서 겹칠 일이 없었다.** 새 순서에서는 저장이 심박 회복 창 안에서 돈다. 멈춘 러닝이 멈춘 자리가 거기다.

다만 **그 창 안에 있다고 반드시 멈추는 건 아니다.** 성공한 러닝도 같은 창 안에서 저장을 끝냈다. 그러니 이 변경이 멈춤을 가능하게 만든 것까지는 말할 수 있어도, 이것이 원인이라고 단정할 수는 없다. 증상이 보고되기 시작한 시점과 맞는 유일한 구조 변경이라는 게 지금 근거의 전부다.

| | 신호가 저장 뒤에 | 저장이 심박 회복과 겹침 | 결과 |
| --- | --- | --- | --- |
| 1.3.1 까지 | 그렇다 | 아니다 | 저장이 길면 **늦게** 돌아옴 |
| 1.3.2 부터 | 그렇다 | **그렇다** | **영영 안 돌아옴** |

신호가 저장 뒤에 묶여 있는 구조는 **원래부터 있었다.** 1.3.2 가 한 일은 그 뒤에 있는 저장을 끝날 수 없게 만든 것이다.

### 고치려던 일이 만든 틈

억울한 건 그 변경 자체가 고치려고 한 일이었다는 점이다. **아이폰에서 끝낸 러닝이 건강 앱에 아무것도 안 남던 문제**를 고친 커밋이다.

`finishWatchWorkout` 은 두 경로가 같이 쓰는데 **들어올 때 세션 상태가 다르다.**

| 경로 | 들어올 때 세션 |
| --- | --- |
| 워치에서 END FLIGHT | `.stopped` |
| 아이폰이 끝냄 | **`.running`** |

아래쪽이 그때 새로 생긴 경로다. 돌고 있는 세션의 빌더에 `endCollection` 을 먼저 부르면 실패할 수 있어서, 어느 쪽으로 들어오든 세션부터 끝내게 바꿨다. **아래 경로에는 꼭 필요한 조치였다.**

문제는 함수가 하나라는 것이다. 위 경로는 이미 멈춘 상태로 들어오니 세션을 먼저 끝낼 이유가 없었는데, **공유 함수를 통해 같이 당겨졌다.**

당시 주석에 이렇게 적어뒀었다.

> `end()`는 델리게이트에 `.ended`를 흘리는데 `handleWatchOSStateChange`가 `.stopped`와 `.running`만 처리하므로 되돌아오는 이벤트는 없다.

콜백이 되돌아오는 것까지는 생각했다. 생각 못 한 건 **세션이 끝난 뒤에도 3분을 더 살아 있다는 것**이었다. 끝내는 호출인 줄 알았는데 실제로는 끝내기 시작하는 호출이었다.

### 안 고치기로 한 것

경로를 둘로 갈라서 워치에서 끝낸 경우엔 예전 순서로 되돌리면 **교착 자체가 안 생긴다.** 더 깊은 수정이다.

지금은 안 하기로 했다. 신호가 저장 앞으로 가면서 **사용자가 겪는 문제는 이미 없어졌고**, 경로를 가르면 두 벌을 유지해야 한다. 더 깊은 수정은 고친 빌드가 실기기에서 어떻게 도는지 보고 판단해도 늦지 않다.

### 실기기에서 나온 같은 증상

글을 쓰는 동안 지인이 1.3.2 로 러닝을 하고 왔다. 시뮬레이터에서만 나는 게 아니냐는 의심이 남아 있었는데 그 답이 됐다.

말해준 순서는 이랬다. 워치에서 종료를 눌렀는데 **안 끝났다.** 한참 두니 아이폰 러닝이 일시정지로만 바뀌고 끝나지는 않았다. 그래서 아이폰에서 직접 끊었더니 워치에 경고가 떴다.

> Workout Session Error
> Something went wrong while tracking your run. Please restart your flight.

이 경고가 나오는 자리는 셋인데, 둘은 워크아웃을 **시작**하다 실패한 경우라 해당이 없다. 남는 건 `finishWatchWorkout` 의 catch 다. **마무리가 실패했다는 뜻이다.**

순서를 맞춰보면 이렇게 된다.

```
워치에서 END        마무리가 안 돌아옴 → 신호가 안 나감
아이폰은 계속 러닝    움직임이 없으니 일시정지로 바뀜
아이폰에서 종료      워치로 종료 신호가 감
워치가 그 신호로      마무리를 두 번째로 부름 → 실패 → 경고
```

마지막 줄이 따로 적어둔 다른 문제다. **경고는 결과고 진짜 문제는 첫 줄이다.**

여기서 중요한 건 **증상이 실기기에서도 난다**는 것 하나다. 다만 1.3.2 에는 기록 장치가 하나도 없어서, 첫 줄이 시뮬레이터에서 본 그 교착인지 다른 종류의 실패인지는 **지금 자료로 못 가린다.** 겉으로 보이는 행동만 같다.

고친 빌드에서는 신호가 먼저 나가니 아이폰이 바로 끝나고, 아이폰에서 직접 끊을 일이 없어지니 두 번째 마무리도 안 불린다. **경고까지 같이 사라질 것으로 보지만 그건 아직 확인 전이다.**

그리고 하나가 더 확인됐다. **그 러닝이 건강 앱에 남아 있었다.**

```
Name                        Apple Watch
Average Heart Rate          152 BPM
Total Walking + Running     7.7 km
```

미러링에서는 센서를 가진 워치가 저장 주체라 아이폰은 제 걸 버린다. 그래서 워치 기록 하나만 남는 게 정상이고, 그게 남아 있다는 건 **워치의 저장이 결국 끝났다는 뜻**이다.

시뮬레이터에서는 9분을 기다려도 안 끝났다. 실기기에서는 끝났다. **같은 자리에서 멈춘 게 아니라 느렸던 것이다.**

| | 시뮬레이터 | 실기기 |
| --- | --- | --- |
| 저장이 끝나는가 | **안 끝남** | **끝남** |
| 건강 앱 | 비어 있었을 것 | 남아 있음 |

그러면 지인이 겪은 건 **저장이 끝나기 전에 기다리다 지쳐 직접 끊은 것**이다. 종료 신호가 그 뒤에 줄 서 있었으니 끊기 전까지는 올 수가 없었다.

고친 내용은 그대로 맞다. 느리든 멈추든 아이폰이 거기 묶여 있으면 안 되는 건 같다. 오히려 실기기에서 느린 것뿐이라면 **이번 수정으로 끝난다.**

### 아직 설명 못 한 1.3.1 제보

날짜가 안 맞는다. 1.3.1 때는 저장이 심박 회복과 안 겹쳤으니 지금 멈춘 자리에서 멈출 수가 없었다.

짐작은 있다. 신호가 저장 뒤에 있는 구조는 그때도 같았으니 저장이 몇십 초 걸리면 아이폰은 그동안 러닝 화면에 남는다. 기다리다 지쳐 직접 끊으면 **지금 증상과 똑같아 보인다.**

**다만 그때 로그가 없어서 확인할 방법이 없다.** 같은 것이 약하게 난 건지 다른 것인지 지금 자료로는 못 가른다. 모르는 건 모르는 대로 적어둔다.

---

## 다음에도 다시 쓸 것들

이번에 만든 장치는 이 버그 하나를 위한 게 아니라고 생각한다. 다음에 다른 프로젝트에서 "어디서 멈췄는지 모르겠다"는 상황이 오면 같은 것을 다시 만들게 될 것 같아서, 무엇을 왜 그렇게 했는지 남겨둔다.

### 기기마다 다른 읽을 거리

같은 코드라도 어디서 돌리느냐에 따라 받아올 수 있는 게 다르다. 이걸 모르고 시작해서 한참 헤맸다.

<svg viewBox="0 0 680 236" width="100%" xmlns="http://www.w3.org/2000/svg" style="max-width:680px;display:block;margin:18px auto;color:inherit" role="img" aria-label="기기별로 읽을 수 있는 로그 종류 비교">
  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12.5" fill="currentColor">
    <text x="300" y="26" text-anchor="middle" opacity="0.75">앱이 남긴 로그</text>
    <text x="450" y="26" text-anchor="middle" opacity="0.75">시스템 로그</text>
    <text x="600" y="26" text-anchor="middle" opacity="0.75">앱 폴더 파일</text>
    <text x="8" y="72" opacity="0.9">워치 시뮬레이터</text>
    <text x="8" y="126" opacity="0.9">아이폰 시뮬레이터</text>
    <text x="8" y="180" opacity="0.9">실기기</text>
  </g>
  <g stroke="currentColor" stroke-width="1" opacity="0.18">
    <line x1="8" y1="40" x2="672" y2="40"/>
    <line x1="8" y1="94" x2="672" y2="94"/>
    <line x1="8" y1="148" x2="672" y2="148"/>
    <line x1="8" y1="202" x2="672" y2="202"/>
  </g>
  <g font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="15" text-anchor="middle">
    <text x="300" y="73" fill="#e05252" font-weight="700">안 남음</text>
    <text x="450" y="73" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="600" y="73" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="300" y="127" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="450" y="127" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="600" y="127" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="300" y="181" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="450" y="181" fill="currentColor" opacity="0.8">읽힘</text>
    <text x="600" y="181" fill="currentColor" opacity="0.5">디버그만</text>
  </g>
  <text x="340" y="226" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="12" fill="#e05252" text-anchor="middle">이 한 칸 때문에 파일 기록을 따로 넣었다</text>
</svg>

빨간 칸 하나가 이 조사를 막고 있었다. 증상은 시뮬레이터에서 나는데 거기서만 앱 로그가 안 남는다. 실기기는 멀쩡한데 증상이 잘 안 난다. **읽을 수 있는 곳과 재현되는 곳이 어긋나 있으면 가설을 아무리 세워도 소용없다.**

그래서 파일을 하나 더 쓰는 쪽을 택했다. 빈칸을 메우는 게 아니라 **그 칸을 안 써도 되게 돌아간 것**이다.

### 터미널로 앱 안을 볼 때 조심할 것

조사한다고 앱 폴더를 열면 **그 옆에 사용자의 진짜 기록이 같이 있다.** 러닝 데이터베이스, 위치 기록, 설정이 전부 한 폴더 안이다. 디버그 파일 한 줄 보러 들어가는 거라도 들어가는 곳은 거기다. 내 기기니까 괜찮지만, 습관으로 굳으면 남의 기기에서도 같은 손놀림이 나온다.

시스템 로그는 조건을 안 주면 **기기 전체가 나온다.** 다른 앱 것까지 전부다. 몇만 줄을 받아놓고 그중에 뭐가 들었는지 모르는 상태가 되는데, 그건 보는 게 아니라 쌓는 것이다. 시간 범위와 `subsystem` 은 항상 같이 준다.

그리고 남기는 쪽에서 더 조심해야 한다. os_log 는 기본적으로 동적인 값을 `<private>` 으로 가린다. 우리는 그걸 풀었다.

```swift
logger.notice("[\(step, privacy: .public)] \(detail, privacy: .public)")
```

가린 걸 푼 이상 **그 자리에 개인정보를 넣지 않겠다는 약속**이 된다. 실제로 우리가 남기는 건 단계 이름, 상태값, 시각뿐이고 위치나 심박 같은 건 한 줄도 안 들어간다. 디버깅이 급하다고 값을 통째로 찍기 시작하면 그게 그대로 기기 로그에 남는다.

마지막은 글을 쓰면서 발견한 것이다. **파일 기록이 배포본에도 들어가고 있었다.**

```swift
static func log(_ step: String, _ detail: String = "") {
    logger.notice(...)
    appendToFile(step, detail)   // 조건 없이 불리고 있었다
}
```

러닝마다 지우지 않고 덧붙이는 파일이라 그대로 두면 사용자 기기에 영원히 쌓이고 iCloud 백업에도 같이 올라간다. 조사하는 쪽에서만 필요한 것이니 `#if DEBUG` 안으로 넣었다. 배포본에서는 os_log 만 남고, 그건 실기기에서 꺼내 볼 때 쓰는 그것이다.

**조사용으로 넣은 장치는 조사 끝나고 나가는 게 아니라 처음부터 나갈 자리를 정해둬야 한다.**

### 흔적을 심을 때의 규칙

열세 개를 심으면서 정한 것들이다. 숫자가 아니라 규칙이 다음에 쓸모 있을 것 같다.

**빈 자리가 없어야 한다.** "마지막으로 찍힌 줄이 멈춘 곳"이라는 말은 체인에 구멍이 없을 때만 성립한다. 한 군데라도 비어 있으면 거기서 끊긴 건지 그 앞에서 끊긴 건지 알 수 없다.

**이름으로 출처가 보여야 한다.** `watch.*` 와 `vm.*` 와 `send.*` 로 나눠서, 줄만 보고도 어느 기기 어느 층에서 나온 건지 알게 했다. 양쪽 파일을 나란히 놓고 읽을 때 이게 없으면 섞인다.

**시간은 밀리초로 남긴다.** 처음엔 초 단위였는데 "1초"가 0.1초인지 1.9초인지 몰라서 걸린 시간을 비교할 수가 없었다. 흔적의 목적이 "어디까지 갔나"뿐이면 초로 충분하지만, **"얼마나 걸렸나"를 보려면 모자란다.**

**등급은 디스크에 남는 쪽으로.** `.info` 는 메모리에만 있다가 사라진다. 언제 날지 모르는 증상을 쫓는 중이라면 그 순간 로그 창을 켜두고 있을 수가 없으니 `.notice` 여야 한다.

**순서를 보장한다.** 여러 액터에서 같은 파일에 쓰니 직렬 큐를 하나 두었다. 섞여 쓰이면 체인이 순서대로 안 보이고, 순서가 틀어지면 흔적의 의미가 없다.

---

## 원인에 닿기까지 틀렸던 것들

결과만 보면 코드 두 줄 순서를 바꾼 일이다. 거기까지 가는 동안 틀린 길이 몇 개 있었고, 그 틀린 길이 왜 그럴듯했는지가 이 문제의 성격을 말해준다고 생각한다.

### 가다가 없어졌다는 생각

처음 의심한 건 신호가 워치를 떠났는데 아이폰에 안 닿았다는 쪽이었다. 두 기기 사이 전송이라 제일 먼저 떠오르는 설명이다.

이건 시스템이 남기는 전송 기록으로 바로 갈렸다. **워치에서 나간 게 아예 없었다.** 재현된 두 번 모두 그랬다.

틀린 가정 하나를 지운 것보다 중요한 게 있었다. 찾을 범위가 "두 기기 사이"에서 **"워치 안"으로 줄었다.** 전송을 의심하는 동안에는 네트워크 쪽 지식을 꺼내 들게 되는데, 그쪽은 애초에 볼 데가 아니었다.

### 길이 가설

긴 러닝에서 나고 짧은 러닝에서는 안 났다. 그래서 데이터가 많을수록 정리할 게 많아 오래 걸린다는 설명을 오래 붙들고 있었다.

```
40분   실패
45분   정상
62분   정상
90분   실패
114분  정상
```

보면 알겠지만 선이 안 그어진다. 그런데도 이 가설을 못 놓은 건 **다른 설명이 없었기 때문**이다. 그래서 테스트를 자꾸 더 길게 잡았다. 20km, 25km, 나중엔 밤새 돌려볼 생각까지 했다.

실제로 잡힌 날 나온 숫자가 이걸 끝냈다.

| 러닝 길이 | 저장 |
| --- | --- |
| 1시간 24분 | 6.0초 |
| 1시간 18분 | **안 끝남** |
| 1시간 16분 | 4.25초 |

**비슷한 길이 셋이 전부 다른 결과였다.** 길이가 조건이 아니라는 걸 이보다 분명하게 보여주는 건 없다. 그리고 원인을 알고 나니 왜 안 맞았는지도 분명해졌다. 조건은 심박 회복이고, 그건 얼마나 오래 뛰었느냐가 아니라 심박이 어떤 상태냐에 달렸다.

### 재현되는 곳과 읽히는 곳의 어긋남

제일 오래 걸린 건 가설이 아니라 **읽을 방법이 없었던 것**이다.

증상은 시뮬레이터에서 잘 났다. 그런데 워치 시뮬레이터는 앱이 남긴 로그를 저장소에 안 남긴다. 6시간 치를 뒤져도 우리 앱 줄은 0개인데 같은 시간대 시스템 앱 로그는 멀쩡히 쌓여 있었다. 실기기에서는 로그가 멀쩡하지만 거기서는 증상이 잘 안 난다.

**재현되는 곳에서는 못 읽고, 읽을 수 있는 곳에서는 재현이 안 되는 상태였다.** 이걸 못 넘으면 가설을 아무리 세워도 확인할 방법이 없다.

푼 방법은 단순하다. 로그에만 맡기지 말고 **같은 줄을 앱 폴더 안 파일에도 쓴다.** 그러고 나니 재현을 지켜보고 있을 필요도 없어졌다. 돌려놓고 나중에 읽으면 되고, 성공한 러닝과 실패한 러닝이 한 파일에 같이 쌓인다.

### 다 찍히기 전에 읽은 것

파일을 열고 `watch.finishing` 까지만 있는 걸 보고 멈췄다고 단정했다. 6초 뒤에 나머지가 다 찍혔다. **정상 종료였다.**

이건 파일 방식의 함정이다. 진짜 멈춘 것과 아직 저장 중인 것이 **파일상 똑같이 생겼다.** 마지막 줄이 중간에서 끊겨 있다는 사실만으로는 아무것도 말할 수 없다.

그래서 규칙을 하나 만들었다. **1분쯤 띄워 두 번 읽어서 같아야 멈춘 것으로 본다.** 실제로 잡힌 날은 이 규칙 덕분에 49초, 2분 22초, 7분을 차례로 확인하고서야 "느린 게 아니라 멈춘 것"이라고 말할 수 있었다.

### 답이 내 코드에 없던 것

흔적을 열세 개까지 늘려서 얻은 건 **어디서 끊겼는지**였다. 왜 끊겼는지는 거기 없었다.

`finishWatchWorkout` 을 아무리 들여다봐도 세 줄뿐이다. 세션을 닫고, 수집을 끝내고, 저장한다. 어느 줄이 안 끝나는지도 모르고, 안 끝나는 이유는 더더욱 없다.

답은 시스템이 남긴 기록에 있었다. **심박 회복**이라는 말은 내 코드 어디에도 안 나온다. 워크아웃을 멈추면 watchOS 가 그걸 재려고 세션을 3분 넘게 붙잡는다는 건, 내 코드만 들여다봐서는 평생 안 나왔을 이야기다.

이번 일에서 제일 크게 남은 게 이거다. **내가 쓴 코드가 멈췄다고 해서 원인이 내 코드에 있는 건 아니다.**

### AI와 나눠 가진 자리

이 추적은 처음부터 끝까지 AI와 같이 했다. 어디가 잘 맞았고 어디는 내가 막아야 했는지를 적어둔다.

잘 맞은 쪽은 **빠짐없이 훑는 일**이었다. 버튼에서 신호까지 열한 걸음을 한 줄씩 따라가면서 조용히 빠져나가는 자리를 네 군데 뽑아냈는데, 그중 하나는 내가 여러 번 읽고도 못 본 자리였다. 사람이 읽으면 이미 아는 곳은 눈이 미끄러지는데 그쪽은 그냥 다 읽는다. 흔적 열세 개를 같은 형식으로 심는 일도 그렇다.

내가 막아야 했던 쪽은 **숫자의 출처**였다. 안전장치 기준을 정할 때 25초가 제안됐는데 근거로 18.7초라는 측정값이 붙어 있었다. 어디서 나온 값이냐고 물으니 그게 **종료 버튼을 누른 뒤 워치가 저장하던 구간**이었다. 러닝 중 값이 아니다. 러닝 중 최대는 10.5초였고, 그래서 15초가 됐다.

측정값이 틀린 건 아니었다. **쓰면 안 되는 자리에 쓴 것**이다. 이런 건 숫자만 봐서는 안 걸리고 그 숫자가 어떤 상황에서 나왔는지를 알아야 걸린다.

길이 가설도 비슷했다. 한 번은 "길이 가설은 거의 죽었다"는 판단이 나왔는데, 그때 근거로는 그렇게까지 말할 수 없었다. 될 수도 있고 안 될 수도 있는 상태였다. 결과적으로는 죽은 게 맞았지만, **맞는 결론을 근거보다 먼저 말하는 것**과 근거를 모으는 것은 다른 일이다.

정리하면 훑고 심고 쓰는 일은 맡길수록 좋았고, **무엇을 믿을지는 끝까지 내가 정해야 했다.**

---

## 지금 말할 수 있는 것

고친 것은 **안 끝날 수도 있는 일 뒤에 종료 신호를 둔 것**이다. 코드로는 두 줄 순서고, 겉으로는 조건이 안 잡히는 간헐적 증상이었다.

워치의 저장이 왜 어떤 러닝에서만 안 끝나는지는 **아직 모른다.** 멈추는 자리는 찾았지만 거기서 멈추게 만드는 조건은 못 찾았다. 다만 그게 아이폰 쪽 증상의 전제는 아니다. **저장이 끝나든 말든 아이폰은 제 러닝을 끝낼 수 있어야 했고, 그걸 고쳤다.**

이걸 잡는 데 결정적이었던 건 두 가지다.

**정상일 때의 모양을 먼저 쟀다.** 그게 없을 때는 실패한 기록을 봐도 "원래 여기까지 찍히는 게 맞나"를 몰랐다. 6초라는 기준이 있으니 9분이 느린 게 아니라 멈춘 거라고 말할 수 있었다.

**앱 밖의 로그를 봤다.** 우리 흔적은 "여기서 끊겼다"까지만 말해준다. 왜 끊겼는지는 시스템이 남긴 기록에 있었고, 심박 회복이라는 단어는 우리 코드 어디에도 안 나온다. 내 코드만 들여다봤으면 못 찾았다.

아직 모르는 것도 적어둔다. **시뮬레이터에서 저장이 영영 안 끝난 이유는 모른다.** 실기기에서는 같은 러닝의 기록이 건강 앱에 남아 있어서 저장이 결국 끝났다는 게 확인됐다. 같은 코드인데 한쪽은 끝나고 한쪽은 안 끝난다. 시뮬레이터 로그에 CoreMotion 오류와 "멈춤 이벤트를 못 받아 흉내낸 걸 만든다"는 줄이 있는 걸 보면 **센서가 진짜가 아니라서 생긴 시뮬레이터 쪽 사정**일 가능성이 있지만, 그것도 짐작이다.

실기기에서 느린 것뿐이라면 이번 수정으로 끝난다. 아이폰이 그 시간을 기다리지 않게 된 것이 전부이기 때문이다. 실기기에서 일곱 번을 눌러 일곱 번 다 신호가 먼저 나간 것까지 확인했다.

**저장이 완전히 멈춘 상태에서 아이폰이 끝나는 것도 아직 직접은 못 봤다.** 다만 거기 가까운 건 봤다. 6시간 41분짜리를 돌렸더니 저장이 **26초** 걸렸는데 아이폰은 **4.2초**에 홈으로 갔다. 저장이 끝나기 24초 전이다. 고치기 전이었으면 그 26초 동안 러닝 화면에 남아 있었을 테고, 15초를 넘으니 알림까지 떴을 것이다.

26초가 멈춘 것은 아니니 완전한 확인은 아니다. 다만 숫자가 커진 덕에 아이폰이 저장을 기다리지 않는다는 건 분명히 보였다.

모르는 것이 셋 남았지만 고친 내용은 그 답들과 무관하게 맞다. 아이폰이 제 러닝을 끝내는 데 워치의 저장을 기다릴 이유는 애초에 없었다.
