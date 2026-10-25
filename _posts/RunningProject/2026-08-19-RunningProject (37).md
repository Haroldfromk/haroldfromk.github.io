---
title: RunWay 1.3 (1) 워치 UX 다듬기 & 7일 리마인더 알림
writer: Harold
date: 2026-08-19 06:46:00 +0900
last_modified_at: 2026-10-25 23:00:00 +0900
categories: [RunWay]
tags: [watchOS, SwiftUI, UserNotifications]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

Watch에서 CUSTOM 거리를 Digital Crown으로 조절하다가 이상한 걸 발견했다. 최소값 100m부터 시작해서 계속 돌리다 보면 500m, 600m, 1.1km, 1.6km처럼 애매한 값에서 멈췄다.

---

## 원인

`WatchDistanceSettingView`의 Crown 바인딩을 보니 시작값 0.1(100m)에서 0.5씩 계속 더하는 구조였다.

```swift
// before
.digitalCrownRotation(
    $crownValue,
    from: 0.1, // 수정해야함
    through: 42.2,
    by: 0.5,
    sensitivity: .low,
    isContinuous: false,
    isHapticFeedbackEnabled: true
)
.onChange(of: crownValue) { _, newVal in
    distance = newVal
}
```

#### digitalCrownRotation으로 크라운 값 받기

[`digitalCrownRotation`](https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation%28%5F%3Afrom%3Athrough%3Aby%3Asensitivity%3Aiscontinuous%3Aishapticfeedbackenabled%3A%29){:target="_blank"}은 워치의 용두를 돌릴 때 값이 따라 움직이게 묶어준다. 인자가 많은데 하나씩 보면 단순하다.

| 인자 | 하는 일 |
|---|---|
| 첫 인자 | 값을 담을 자리. `$` 를 붙인 바인딩이다 |
| `from`, `through` | 값이 오갈 수 있는 처음과 끝 |
| `by` | 한 칸에 얼마씩 움직일지 |
| `sensitivity` | 같은 거리를 돌렸을 때 몇 칸이 움직일지 |
| `isContinuous` | 끝에서 처음으로 이어 돌지 여부 |
| `isHapticFeedbackEnabled` | 한 칸 넘어갈 때마다 손목을 톡 칠지 |

여기서 중요한 건 **`from` 이 눈금의 기준점이 된다**는 점이다. `by` 는 거기서부터 더해지므로, 시작값이 격자에 안 맞으면 그 뒤가 전부 어긋난다.

0.1에서 0.5씩 더하면 0.1, 0.6, 1.1, 1.6... 순서가 된다. 100m라는 시작점 자체가 0.5의 배수가 아니다 보니, 그 뒤로 나오는 값도 전부 시작점만큼 밀려서 어중간해진 것. 코드에 `// 수정해야함`이라는 TODO까지 이미 남겨져 있었다.

---

## 수정

Crown 값을 거리 자체가 아니라, 미리 정해둔 거리 배열의 인덱스로 바꿨다. 100m는 배열 맨 앞에 예외로 두고, 그 다음부터는 0.5km 단위로 채우되 하프/풀마라톤(21.1km, 42.2km)만 격자 중간에 따로 끼워 넣었다.

```swift
// 새로 만든 눈금 배열
private let distanceSteps: [Double] = {
    var steps: [Double] = [0.1]
    var v = 0.5
    while v < 21.1 {
        steps.append(v)
        v += 0.5
    }
    steps.append(21.1)
    v = 21.5
    while v < 42.2 {
        steps.append(v)
        v += 0.5
    }
    steps.append(42.2)
    return steps
}()
```

Crown은 이 배열의 인덱스만 오가고, 실제 거리는 인덱스로 배열을 조회해서 얻는다.

```swift
// after
.digitalCrownRotation(
    $stepIndex,
    from: 0,
    through: Double(distanceSteps.count - 1),
    by: 1,
    sensitivity: .low,
    isContinuous: false,
    isHapticFeedbackEnabled: true
)
.onChange(of: stepIndex) { _, newVal in
    let idx = min(max(Int(newVal.rounded()), 0), distanceSteps.count - 1)
    distance = distanceSteps[idx]
}
```

#### onChange로 값이 바뀔 때만 따라가기

[`onChange(of:_:)`](https://developer.apple.com/documentation/swiftui/view/onchange%28of%3Ainitial%3A%5F%3A%29){:target="_blank"}는 지켜보던 값이 **바뀐 순간에만** 블록을 실행한다. 화면이 다시 그려질 때마다 도는 게 아니라, 이전 값과 달라졌을 때만 한 번 돈다.

클로저가 인자를 두 개 받는데 앞이 바뀌기 전 값, 뒤가 바뀐 뒤 값이다. 여기서는 뒤의 것만 쓰므로 앞은 `_` 로 버렸다.

여기에 함정이 하나 있다. **크라운이 움직여야 이 블록이 돈다.** 프리셋 버튼이 거리만 바꿔놓고 크라운 값을 그대로 두면, 다음에 크라운을 한 칸 돌리는 순간 이 블록이 옛날 크라운 값을 기준으로 거리를 덮어쓴다. 아래에서 프리셋 버튼도 같이 고치는 이유가 이것이다.

프리셋 버튼(3K/5K/10K/HALF/FULL)도 거리 대신 인덱스를 찾아서 설정하도록 같이 고쳤다.

```swift
// before
Button {
    distance = preset.value
    crownValue = preset.value
} label: {
    // 생략
}
```

```swift
// after
Button {
    distance = preset.value
    if let idx = distanceSteps.firstIndex(of: preset.value) {
        stepIndex = Double(idx)
    }
} label: {
    // 생략
}
```

이제 100m에서 한 칸 돌리면 바로 500m, 그다음은 1.0km, 1.5km 순으로 깔끔하게 올라간다.

두 방식을 직접 돌려볼 수 있게 만들었다. 크라운 대신 +/− 버튼을 누르면 한 칸씩 움직인다.

<iframe
  src="/assets/demo/crown_step_simulator.html"
  width="100%"
  height="700px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

돌려보면서 알게 된 게 하나 더 있다. 수정 전 방식으로 두고 **5K 프리셋을 누른 다음 크라운을 한 칸만 돌려보면 2.6km로 튄다.** 프리셋은 거리 값만 바꿔놓고 크라운이 들고 있는 값은 건드리지 않았는데, 크라운이 움직이는 순간 `onChange`가 다시 거리를 크라운 값으로 덮어써버리기 때문이다. 프리셋 버튼도 같이 고쳐야 했던 게 이 이유다. 인덱스 방식에서는 프리셋이 크라운의 자리 번호까지 같이 옮겨놓기 때문에, 5K를 누르고 한 칸 돌리면 5.5km로 이어진다.

---

## GPWS 경고 유형별로 다른 햅틱

워치에서 GPWS 경고가 뜰 때 화면을 안 보고도 어떤 경고인지 구분할 수 있으면 좋겠다는 생각이 들었다. 코드를 보니 `WatchGPWSView`는 화면이 뜰 때 `WKInterfaceDevice.current().play(type.haptic)`로 짧은 햅틱을 한 번 울리고 있었는데, SINK RATE든 OVERSPEED든 진동 자체는 거의 같은 느낌이었다.

유형별로 진동 패턴을 다르게 주기로 했다. 대신 러닝 중에 계속 울리면 거슬리니, 반복 횟수를 정해두고 몇 초 안에 끝나게 묶었다.

```swift
// before
var haptic: WKHapticType {
    switch self {
    case .sinkRate:  return .failure
    case .overspeed: return .failure
    case .minimums:  return .notification
    }
}
```

```swift
// after
var hapticPattern: (type: WKHapticType, repeatCount: Int, interval: TimeInterval) {
    switch self {
    // 너무 느림(ADD THRUST) - 위로 두 번, 여유 있는 간격
    case .sinkRate:  return (.directionUp, 2, 0.45)
    // 너무 빠름(REDUCE THRUST) - 아래로 세 번, 빠른 간격으로 다급한 느낌
    case .overspeed: return (.directionDown, 3, 0.2)
    // 목표 거리 임박 - 한 번, 부드러운 알림
    case .minimums:  return (.notification, 1, 0)
    }
}
```

#### WKHapticType으로 손목에 다르게 울리기

[`WKInterfaceDevice`](https://developer.apple.com/documentation/watchkit/wkinterfacedevice){:target="_blank"}는 워치 기기 자체를 가리킨다. `current()` 로 가져와서 `play(_:)` 를 부르면 손목이 울린다.

[`WKHapticType`](https://developer.apple.com/documentation/watchkit/wkhaptictype){:target="_blank"}은 **진동 패턴의 종류**다. 세기를 숫자로 정하는 게 아니라 `.success`, `.failure`, `.directionUp` 처럼 뜻이 붙은 이름 중에 고른다. 시스템이 기기마다 알맞은 느낌으로 재생해주므로, 같은 이름이면 어느 워치에서도 같은 뜻으로 전달된다.

고르면서 보니 `.directionUp` 과 `.directionDown` 이 원래 방향을 알리려고 만들어진 것이라 이 경우에 딱 맞았다. 느리면 올리라고 위로, 빠르면 줄이라고 아래로 울린다.

이 패턴을 재생하는 쪽은 `Task`로 감싸서, 화면이 사라지면(`onDisappear`) 바로 취소되게 했다.

```swift
@State private var hapticTask: Task<Void, Never>?

private func playHapticPattern() {
    hapticTask?.cancel()
    let pattern = type.hapticPattern
    hapticTask = Task {
        for i in 0..<pattern.repeatCount {
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(pattern.type)
            if i < pattern.repeatCount - 1 {
                try? await Task.sleep(for: .seconds(pattern.interval))
            }
        }
    }
}
```

#### Task 취소로 울리던 햅틱을 끊기

[`Task`](https://developer.apple.com/documentation/swift/task){:target="_blank"}는 따로 돌아가는 일거리 하나다. 만들면 바로 시작하고, 손잡이를 들고 있으면 나중에 `cancel()` 로 그만두라고 말할 수 있다.

다만 **취소는 부탁이지 강제 중단이 아니다.** `cancel()` 을 불러도 돌던 코드가 그 자리에서 멈추지 않는다. 그래서 반복문 안에서 [`Task.isCancelled`](https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property){:target="_blank"}를 직접 확인하고 빠져나와야 한다. 이 확인을 안 넣으면 화면이 사라진 뒤에도 남은 횟수만큼 계속 울린다.

[`Task.sleep(for:)`](https://developer.apple.com/documentation/swift/task/sleep%28for%3Atolerance%3Aclock%3A%29){:target="_blank"}는 정해진 시간만큼 기다린다. 스레드를 붙잡고 멈춰 있는 게 아니라 그 시간 동안 자리를 내주므로, 기다리는 사이 다른 일이 돈다. 취소되면 기다리다 말고 오류를 던지는데, 여기서는 어차피 다음 바퀴에서 걸러지므로 `try?` 로 흘렸다.

![cancel 을 불러도 isCancelled 를 안 보면 남은 횟수만큼 계속 울리고 반복문에서 직접 확인해야 그 자리에서 빠져나온다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-08-19-RunningProject-37/task-cancel.png)

`hapticTask?.cancel()` 을 맨 앞에 둔 건 **경고가 연달아 뜰 때 앞 패턴이 겹쳐 울리는 걸 막기 위해서**다.

페이스가 목표보다 느리면(ADD THRUST) 위로 두 번, 빠르면(REDUCE THRUST) 아래로 세 번 빠르게, MINIMUMS는 부드럽게 한 번만 울린다. 손목을 안 보고도 세 가지를 구분할 수 있게 됐다.

---

## END FLIGHT 버튼 확대

실사용해본 지인이 워치에서 러닝 종료할 때 END FLIGHT 버튼이 좀 작다고 알려줬다. 확인해보니 `EndFlightHoldButton`이 높이 28pt, 아이콘 10pt, 텍스트 9pt짜리로 꽤 빡빡했다.

```swift
// before
.frame(height: 28)
// 아이콘 .font(.system(size: 10)), 텍스트 .orbitron(9, weight: .bold)
```

```swift
// after
.frame(height: 40)
// 아이콘 .font(.system(size: 14)), 텍스트 .orbitron(12, weight: .bold)
```

이 버튼이 있는 `WatchFlightPaceTab`은 스크롤 없이 화면 전체를 고정 레이아웃으로 채우는 화면이라, 높이를 12pt 늘리면 다른 요소가 화면 밖으로 밀려날까 봐 걱정했다. 시뮬레이터로 직접 러닝을 시작해서 확인해보니 잘리는 것 없이 딱 맞게 들어갔다.

---

## 7일 무활동 리마인더 알림

일주일 정도 러닝을 안 하면 다시 뛰라고 알려주는 로컬 알림을 추가했다. 원격 푸시가 아니라 [`UserNotifications`](https://developer.apple.com/documentation/usernotifications){:target="_blank"} 프레임워크의 `UNUserNotificationCenter`만 쓰는 순수 로컬 알림이라, APNs나 Info.plist 등록 없이 기기 안에서만 동작한다.

마지막 러닝 날짜를 SwiftData에서 조회해서, 그 날짜 + 7일 시점으로 알림을 예약한다. 러닝을 저장할 때마다 기존 예약을 지우고 새로 잡아서 카운트다운이 매번 리셋된다.

```swift
enum RunReminderService {
    private static let reminderIdentifier = "runway.run-reminder"
    private static let inactivityThreshold: TimeInterval = 7 * 24 * 60 * 60

    static func rescheduleFromLatestFlight(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<SwiftDataFlight>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = try? modelContext.fetch(descriptor).first else {
            cancel()
            return
        }
        reschedule(lastRunDate: latest.date)
    }

    private static func reschedule(lastRunDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let fireDate = lastRunDate.addingTimeInterval(inactivityThreshold)
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "관제탑에서 호출 중")
        content.body = String(localized: "일주일째 활주로가 비어있어요. 오늘 다시 이륙해볼까요?")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger))
    }
    // 생략
}
```

#### FetchDescriptor로 마지막 러닝 하나만 꺼내기

[`FetchDescriptor`](https://developer.apple.com/documentation/swiftdata/fetchdescriptor){:target="_blank"}는 SwiftData 에 "이런 조건으로 꺼내 달라"고 적어 넘기는 주문서다. 정렬과 조건, 개수 제한을 담는다.

[`SortDescriptor`](https://developer.apple.com/documentation/foundation/sortdescriptor){:target="_blank"}로 정렬 기준을 준다. `\.date` 는 어느 속성으로 줄 세울지 가리키는 것이고, `order: .reverse` 라 최근 것이 앞에 온다.

![전부 꺼낸 뒤 첫 개를 고르면 수백 건을 다 읽지만 fetchLimit 을 주면 한 건만 읽어 온다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-08-19-RunningProject-37/fetch-limit.png)

`fetchLimit = 1` 이 중요하다. **저장소에서 한 건만 읽어 온다.** 전부 꺼낸 뒤 첫 개를 고르는 것과 결과는 같지만, 기록이 수백 건 쌓였을 때 읽는 양이 다르다.

`reminderIdentifier`는 고정된 문자열 하나만 쓴다. 재예약할 때마다 같은 identifier로 `removePendingNotificationRequests`를 먼저 호출해서 기존 예약을 지우고 나서 새로 등록하는 방식이라, 러닝을 여러 번 저장해도 리마인더가 중복으로 쌓이지 않는다.

![러닝을 저장할 때마다 기존 예약을 지우고 마지막 러닝 기준으로 다시 잡는 흐름](/assets/img/runway/reminder-reschedule.svg){: width="720" height="250"}

그림으로 보면 이 방식의 핵심이 **살아남는 예약이 항상 하나뿐**이라는 점이다. 러닝을 세 번 하면 예약도 세 번 잡히는데, 앞의 두 개는 새로 잡을 때 같이 지워진다. 그래서 알림 기준은 언제나 마지막 러닝이 된다.

---

### 트리거와 가드를 고른 기준

트리거는 [`UNCalendarNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger){:target="_blank"} 대신 [`UNTimeIntervalNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger){:target="_blank"}를 썼다. 매주 같은 요일/시각에 반복되는 알림이 아니라 "마지막 러닝으로부터 정확히 7일 뒤"라는 상대적인 시점만 필요해서, 절대 시각(`lastRunDate + 7일`)을 `timeIntervalSinceNow`로 변환해 넘기는 쪽이 더 맞는 방식이었다.

`fireDate > .now` 가드도 그냥 넣은 방어 코드가 아니다. 앱을 오래 안 켜서 예약 시점이 이미 지나버린 경우, 앱을 켜자마자 알림이 즉시 뜨는 걸 막는 역할을 한다. 이 경우엔 그냥 아무 알림도 새로 잡지 않고 넘어가는데, 다음 러닝을 저장하는 시점에 `reschedule`이 다시 호출되면서 정상적인 7일 뒤 시점으로 재계산된다.

---

### 어디서 다시 예약을 잡는가

이 재예약을 호출하는 지점이 세 곳이다. 아이폰이 러닝을 저장할 때(`RunViewModel.saveRunningData()`), 워치 단독 기록이 아이폰에 동기화될 때(`HomeView.drainPendingWatchData()`), 그리고 앱을 켤 때(`HomeView.onAppear`). 마지막 건 재설치나 첫 실행처럼 예약이 아예 없던 경우를 보정하기 위해서다.

문구는 앱 톤에 맞춰서 관제탑이 부르는 느낌으로 썼다. 한국어 원문을 그대로 키로 써서 `Localizable.xcstrings`에 영어/일본어 번역을 등록하는 기존 방식을 그대로 따랐다.

| 언어 | 제목 | 본문 |
|---|---|---|
| KO | 관제탑에서 호출 중 | 일주일째 활주로가 비어있어요. 오늘 다시 이륙해볼까요? |
| EN | Tower calling | The runway's been quiet for a week. Ready for takeoff again? |
| JA | 管制塔より呼び出し | 滑走路が1週間静かです。そろそろ離陸しませんか？ |

---

### 권한을 언제 물어볼 것인가

권한 요청은 언제 할지도 고민했다. 온보딩이 이미 HealthKit, 모션 권한까지 요청하는 게 많은 편이라, 페이지마다 따로 묻는 대신 기존에 있던 마지막 페이지(개인정보 동의) 완료 시점의 배치 요청에 [`requestAuthorization(options:completionHandler:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization%28options%3Acompletionhandler%3A%29){:target="_blank"} 호출을 그대로 얹었다. 이미 허용/거부가 결정된 상태에서 다시 호출해도 시스템이 조용히 무시하기 때문에, 온보딩 도중 놓쳤더라도 다음에 `HomeView.onAppear`에서 자연스럽게 다시 시도된다.

```swift
// OnboardingView.complete()
private func complete() {
    guard hasAgreedToPrivacyPolicy else { return }
    Task {
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            HealthKitService.shared.alertPublisher.send(AlertContext.healthKitAuthorizationFailed)
        }
    }
    runViewModel.requestAltitudeAuthorization()
    RunReminderService.requestAuthorization()
    hasCompletedOnboarding = true
}
```

온보딩 페이지도 하나 늘었다(7 -> 8페이지). CLOUD BACKUP 페이지와 같은 구조로, 관제탑 벨 아이콘과 함께 이 기능을 소개하는 TOWER REMINDERS 페이지를 CLOUD BACKUP과 개인정보 동의 페이지 사이에 끼워 넣었다.

---

## 참고자료

- [Scheduling a notification locally from your app (Apple)](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app){:target="_blank"}
