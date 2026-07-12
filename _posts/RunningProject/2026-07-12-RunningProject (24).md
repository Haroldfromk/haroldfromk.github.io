---
title: RunWay (24) 다이나믹 아일랜드 미러링 버그수정
writer: Harold
date: 2026-07-12 11:33:00 +0900
categories: [RunWay]
tags: [ActivityKit, WatchConnectivity, SwiftUI]

toc: true
toc_sticky: true
published: true
---

Watch로 미러링해서 러닝을 해보다가, 종료했는데도 iPhone의 다이나믹 아일랜드가 계속 떠있는 걸 발견했다. 

종료 신호는 분명 Watch에서 iPhone으로 잘 넘어가는데 왜 저것만 안 없어지나 싶어서 코드를 따라가 봤다.

---

## 원인 1 - Watch가 주도하면 애초에 시작이 안 된다

먼저 `startActivity()`가 어디서 호출되는지부터 찾아봤다.

```swift
// TakeoffView.swift
func startCountdown() {
    countdownActive = true
    countdownValue = 3
    Task {
        let missionName = runViewModel.isModeA ? "MISSION FLIGHT" : "FREE FLIGHT"
        let targetPace = runViewModel.isModeA ? PaceFormatter.format(runViewModel.modeAData?.targetPace ?? 0) : "--'--\""
        await runViewModel.flightActivityService.startActivity(missionName: missionName, targetPace: targetPace)
        // 생략
    }
}
```

ROTATE를 눌러서 카운트다운이 시작될 때만 호출되고 있었다. 문제는 Watch가 주도하는 미러링에서는 iPhone이 이 화면 자체를 안 거친다는 거다.

```swift
// RunViewModel.init()
HealthKitService.shared.sessionStatePublisher
    .sink { [weak self] result in
        guard let self else { return }
        if result.state == .running {
            if result.startOrigin == .remote {
                self.navigationPath.append(.pfd)
            }
        }
        // 생략
    }
```

`startOrigin == .remote`면 TakeoffView를 건너뛰고 바로 PFDView로 넘어간다. Watch로 시작한 러닝은 iPhone에 다이나믹 아일랜드가 처음부터 뜬 적이 없었던 거다.

---

## 원인 2 - Watch에서 종료해도 iPhone에서는 정지 신호만 처리한다

종료 쪽도 따라가 봤다. Watch에서 온 정지 신호를 iPhone이 받는 지점은 이랬다.

```swift
// RunViewModel.init()
} else if result.state == .stopped {
    if result.stopOrigin == .local {
        watchConnectivityService.sendStopSignal()
    }
    if result.stopOrigin == .remote {
        Task {
            await self.resetState()
        }
    }
}
```

`stopOrigin == .remote`(Watch가 종료를 주도한 경우)에는 `resetState()`만 호출하고 있었다. `endActivity()`를 호출하는 곳을 전부 찾아봤는데 딱 세 군데였고, 전부 터치다운 화면이나 서머리 화면을 벗어날 때처럼 로컬 UI 액션에 걸려있었다. Watch발 종료 신호로는 그중 어디도 안 탄다.

정리하면 이렇다.

1. Watch 주도 미러링에서는 iPhone에 다이나믹 아일랜드가 처음부터 안 뜬다 (원인 1).
2. 혹시 이전 세션에서 뜬 게 남아있는 상태라면, Watch에서 종료해도 그게 안 없어진다 (원인 2).

결국 다음에 앱을 다시 켜서 `RunViewModel`이 새로 만들어질 때, 아래 방어적 정리 코드가 실행되고 나서야 지워지는 구조였다.

```swift
// RunViewModel.init() - 새 세션이 만들어질 때만 실행되는 방어적 정리
Task {
    for activity in Activity<FlightActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
```

---

## 해결

두 곳을 고쳤다. 종료 흐름만 그림으로 정리하면 이렇게 갈렸다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-24/runway24-dynamicisland-before.png){: width="60%" height="60%"}
![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-24/runway24-dynamicisland-after.png){: width="60%" height="60%"}

Watch 주도로 시작할 때도 TakeoffView와 같은 방식으로 `startActivity()`를 호출하도록 추가했다.

```swift
if result.state == .running {
    if result.startOrigin == .remote {
        self.navigationPath.append(.pfd)
        Task {
            let missionName = self.isModeA ? "MISSION FLIGHT" : "FREE FLIGHT"
            let targetPace = self.isModeA ? PaceFormatter.format(self.modeAData?.targetPace ?? 0) : "--'--\""
            await self.flightActivityService.startActivity(missionName: missionName, targetPace: targetPace)
        }
    }
}
```

그리고 Watch발 종료 신호를 받을 때 `resetState()` 전에 `endActivity()`를 먼저 호출하도록 추가했다.

```swift
if result.stopOrigin == .remote {
    Task {
        await self.flightActivityService.endActivity()
        await self.resetState()
    }
}
```

TakeoffView 카운트다운이 끝날 때 쓰던 것과 같은 `missionName`/`targetPace` 계산식을 그대로 가져다 썼다. 어느 쪽이 주도하든 다이나믹 아일랜드가 똑같이 뜨고, 똑같이 사라지게 됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-12-RunningProject-24/ttl.png){: width="50%" height="50%"}