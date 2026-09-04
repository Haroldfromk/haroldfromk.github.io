---
title: RunWay 1.3 (1) 워치 UX 다듬기 & 7일 리마인더 알림
writer: Harold
date: 2026-08-19 06:46:00 +0900
categories: [RunWay]
tags: [watchOS, SwiftUI, UserNotifications]

toc: true
toc_sticky: true
published: true
---

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

0.1에서 0.5씩 더하면 0.1, 0.6, 1.1, 1.6... 순서가 된다. 100m라는 시작점 자체가 0.5의 배수가 아니다 보니, 그 뒤로 나오는 값도 전부 시작점만큼 밀려서 어중간해진 것. 코드에 `// 수정해야함`이라는 TODO까지 이미 남겨져 있었다.

---

## 수정

Crown 값을 거리 자체가 아니라, 미리 정해둔 거리 배열의 인덱스로 바꿨다. 100m는 배열 맨 앞에 예외로 두고, 그 다음부터는 0.5km 단위로 채우되 하프/풀마라톤(21.1km, 42.2km)만 격자 중간에 따로 끼워 넣었다.

```swift
// after
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

프리셋 버튼(3K/5K/10K/HALF/FULL)도 거리 대신 인덱스를 찾아서 설정하도록 같이 고쳤다.

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

일주일 정도 러닝을 안 하면 다시 뛰라고 알려주는 로컬 알림을 추가했다. 원격 푸시가 아니라 [`UserNotifications`](https://developer.apple.com/documentation/usernotifications) 프레임워크의 `UNUserNotificationCenter`만 쓰는 순수 로컬 알림이라, APNs나 Info.plist 등록 없이 기기 안에서만 동작한다.

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

`reminderIdentifier`는 고정된 문자열 하나만 쓴다. 재예약할 때마다 같은 identifier로 `removePendingNotificationRequests`를 먼저 호출해서 기존 예약을 지우고 나서 새로 등록하는 방식이라, 러닝을 여러 번 저장해도 리마인더가 중복으로 쌓이지 않는다.

![러닝을 저장할 때마다 기존 예약을 지우고 마지막 러닝 기준으로 다시 잡는 흐름](/assets/img/runway/reminder-reschedule.svg){: width="720" height="250"}

그림으로 보면 이 방식의 핵심이 **살아남는 예약이 항상 하나뿐**이라는 점이다. 러닝을 세 번 하면 예약도 세 번 잡히는데, 앞의 두 개는 새로 잡을 때 같이 지워진다. 그래서 알림 기준은 언제나 마지막 러닝이 된다.

트리거는 [`UNCalendarNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) 대신 [`UNTimeIntervalNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/untimeintervalnotificationtrigger)를 썼다. 매주 같은 요일/시각에 반복되는 알림이 아니라 "마지막 러닝으로부터 정확히 7일 뒤"라는 상대적인 시점만 필요해서, 절대 시각(`lastRunDate + 7일`)을 `timeIntervalSinceNow`로 변환해 넘기는 쪽이 더 맞는 방식이었다.

`fireDate > .now` 가드도 그냥 넣은 방어 코드가 아니다. 앱을 오래 안 켜서 예약 시점이 이미 지나버린 경우, 앱을 켜자마자 알림이 즉시 뜨는 걸 막는 역할을 한다. 이 경우엔 그냥 아무 알림도 새로 잡지 않고 넘어가는데, 다음 러닝을 저장하는 시점에 `reschedule`이 다시 호출되면서 정상적인 7일 뒤 시점으로 재계산된다.

이 재예약을 호출하는 지점이 세 곳이다. 아이폰이 러닝을 저장할 때(`RunViewModel.saveRunningData()`), 워치 단독 기록이 아이폰에 동기화될 때(`HomeView.drainPendingWatchData()`), 그리고 앱을 켤 때(`HomeView.onAppear`). 마지막 건 재설치나 첫 실행처럼 예약이 아예 없던 경우를 보정하기 위해서다.

문구는 앱 톤에 맞춰서 관제탑이 부르는 느낌으로 썼다. 한국어 원문을 그대로 키로 써서 `Localizable.xcstrings`에 영어/일본어 번역을 등록하는 기존 방식을 그대로 따랐다.

| 언어 | 제목 | 본문 |
|---|---|---|
| KO | 관제탑에서 호출 중 | 일주일째 활주로가 비어있어요. 오늘 다시 이륙해볼까요? |
| EN | Tower calling | The runway's been quiet for a week. Ready for takeoff again? |
| JA | 管制塔より呼び出し | 滑走路が1週間静かです。そろそろ離陸しませんか？ |

권한 요청은 언제 할지도 고민했다. 온보딩이 이미 HealthKit, 모션 권한까지 요청하는 게 많은 편이라, 페이지마다 따로 묻는 대신 기존에 있던 마지막 페이지(개인정보 동의) 완료 시점의 배치 요청에 [`requestAuthorization(options:completionHandler:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)) 호출을 그대로 얹었다. 이미 허용/거부가 결정된 상태에서 다시 호출해도 시스템이 조용히 무시하기 때문에, 온보딩 도중 놓쳤더라도 다음에 `HomeView.onAppear`에서 자연스럽게 다시 시도된다.

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
