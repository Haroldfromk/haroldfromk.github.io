---
title: RunWay 1.2 (5) TTS 마무리 & CloudKit 백업 기능
writer: Harold
date: 2026-07-28 11:00:00 +0900
categories: [RunWay]
tags: [AVFoundation, SwiftData, CloudKit]

toc: true
toc_sticky: true
published: true
---

km 스플릿 음성 안내는 이미 붙였는데, 원래 계획했던 오디오 콜아웃엔 시작 카운트다운이랑 터치다운 때 안내도 포함돼 있었다. 그리고 v1.2b 로드맵에 남은 큰 항목이 로컬 기록 CloudKit 백업이라 먼저 어떻게 할지 생각을 해보고 구현을 해보기로한다.

---

## 오디오 콜아웃 남은 부분

`TakeoffView`엔 이미 ROTATE 버튼을 누르면 3, 2, 1, ROTATE! 순서로 숫자가 커지는 카운트다운(`startCountdown()`, `countdownValue`)이 있다. 여기에 숫자가 바뀔 때마다 `SpeechAnnouncerService`로 짧게 읽어주기만 하면 될 것 같다. km 스플릿 때 만든 서비스를 그대로 재사용하는 거라 새로 만들 건 별로 없어 보인다.

터치다운 쪽은 `TouchdownHoldButton`의 홀드가 끝나는 시점(`onTouchdown` 클로저)에 이미 `distance`, `time`, `avgPace`를 계산해서 Live Activity 갱신에 쓰고 있으니, 같은 값을 그대로 문장 하나로 만들어서 읽어주면 된다. km 스플릿 안내랑 똑같이 영어로 고정하는 게 맞을 것 같다. "TOTAL 5.2 KILOMETERS, TIME 32 MINUTES, AVERAGE PACE 6 10 PER KILOMETER" 이런 식으로.

카운트다운/터치다운 둘 다 km 스플릿 안내랑 겹칠 일은 없다. 카운트다운은 러닝 시작 전, 터치다운은 러닝이 완전히 끝난 시점이라 시간상 안 마주친다.

---

## CloudKit 백업 생각해보기

로컬 기록이 통째로 날아가는 걸 막는 백업이라, 여러 유저 레코드를 공유하는 크루 기능(v1.3에서 쓸 Public Database)이랑은 성격이 다르다. 내 계정 Private Database에만 쓰는 개인 백업이라 리스크도 훨씬 작다.

백업 대상은 `SwiftDataFlight`랑 거기 딸린 관계(`SwiftDataCoordinate`, `SwiftDataAlert`, `SwiftDataSplit`)다. 다행히 오늘 미션 목표 필드 추가할 때 이미 한 번 겪어봤듯이, SwiftData는 새 필드에 선언부 기본값을 주는 방식으로 마이그레이션을 관리하고 있는데, SwiftData가 지원하는 자동 CloudKit 동기화(`ModelConfiguration(cloudKitDatabase:)`)도 비슷한 조건을 요구한다고 알고 있다. 필드마다 기본값이 있거나 옵셔널이어야 하고, 유니크 제약이 없어야 하는 식. 지금까지 필드 추가할 때마다 이 규칙을 지켜온 게 우연히 CloudKit 동기화 조건도 같이 만족시켜온 셈이라, 스키마를 아예 새로 짤 필요 없이 이 자동 동기화를 그대로 써볼 수 있을 것 같다.

그래도 몇 가지는 미리 정해야 한다.

- **백업 시점** - 러닝 저장(`saveRunningData()`) 직후마다 할지, 아니면 주기적으로/앱이 백그라운드로 갈 때 한 번씩 할지.
  > **결정**: 자동 트리거는 없이, 유저가 설정 화면에서 직접 백업 버튼을 눌러서 실행하는 방식으로 간다. 대신 한동안 백업을 안 했으면 노티피케이션으로 한 번씩 리마인드해줄지는 아직 더 생각해볼 부분.
- **복원 흐름** - 기기를 새로 설정했을 때 CloudKit에 있는 기록을 로컬 SwiftData로 다시 채워 넣는 화면이 필요한데, 지금 앱엔 이 흐름을 넣을 Settings 화면 자체가 없다. v1.0 때 의도적으로 뺐던 부분이라, 이것 때문에라도 Settings 화면을 만들어야 할 수도 있다.
- **충돌 처리** - 기기 A에서 지운 기록이 기기 B에서 되살아나는 것 같은 경우를 어디까지 신경 써야 할지. 크루 기능 없이 혼자 쓰는 백업이라 크게 복잡하진 않을 것 같지만, 그래도 한 번은 정리하고 가는 게 나을 것 같다.

다음엔 이 중 어디부터 실제로 붙여볼지 정하고 시작할 예정이다.

---

## 설정 화면 구현

CloudKit 백업을 하려면 복원 흐름을 넣을 화면이 필요한데, v1.0 때부터 Settings 화면 자체가 없었다. 그래서 먼저 뼈대만 잡기로 했다.

처음엔 홈 화면 헤더에 주석으로 잠들어 있던 톱니바퀴 버튼을 살려서 Deck 탭 안에서만 들어가게 만들었는데, 다시 생각해보니 탭바 자체에 넣는 게 더 맞는 것 같아서 Deck/Logbook/Alerts 옆에 Settings 탭을 하나 더 추가하는 쪽으로 바꿨다. 안에는 공지사항, 개인정보 처리방침, 데이터 저장/복원 3개 메뉴를 뒀다.

![홈 화면과 새 Settings 탭](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_home_button.png){: width="50%" height="50%"}
![설정 화면 목록](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_list.png){: width="50%" height="50%"}

---

### 공지사항 구현

공지사항은 일단은 버전 업데이트 내역을 여기서도 보여주면 좋을것 같아 내역을 적는 방향으로 했다. 그렇게 하고 확인을 해보니 모든 내용을 펼쳐놓는 건 답답해서, 각 버전을 `DisclosureGroup`으로 접었다. 최신 버전(v1.2)만 기본으로 펼쳐두고 나머지는 눌러야 펼쳐지게 했다.

기본 `DisclosureGroup` 화살표는 `.tint()`를 줘도 색이 안 바뀌길래, 라벨과 화살표를 직접 그리는 커스텀 `DisclosureGroupStyle`을 만들어서 화살표를 앱 accent 컬러(`rwGreen`)로 맞췄다.

![공지사항](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_announcements.png){: width="50%" height="50%"}

---

### 개인정보 처리방침 구현

개인정보 처리방침은 원래 온보딩(`OnboardingPrivacyConsent`)에만 있어서 한 번 동의하고 나면 다시 볼 방법이 없었다. 한/영/일 본문 텍스트와 언어 피커를 `PrivacyPolicyContent`라는 뷰로 따로 빼서, 온보딩(동의 체크박스 있는 버전)이랑 설정 화면(읽기 전용 버전) 양쪽에서 같이 쓰도록 했다. 뽑아내는 김에 CoreMotion(기압계 고도) 접근에 대한 문구가 빠져 있던 것도 이번에 추가했다.

![개인정보 처리방침](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_privacy_policy.png){: width="50%" height="50%"}

---

### 데이터 저장/복원 구현

데이터 저장/복원 화면은 아직 CloudKit이 없으니 백업/복원 버튼을 둘 다 비활성 상태로 두고 "준비 중"이라고만 안내했다. 

데이터 백업쪽에 뭔가 수치로 보여줄게 필요해서 고민을 하다가 총 러닝 횟수, 거리, 시간을 보여주기로 결정 했다.

![데이터 저장/복원](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_databackup.png){: width="50%" height="50%"}

여기에 데이터 초기화 버튼도 새로 추가했다. 기기에 저장된 모든 기록을 지우는 기능이라 실수로 눌렸을 때 되돌릴 수 없으니, 버튼을 누르면 바로 지우지 않고 확인 alert를 한 번 더 띄운다. 

취소 버튼은 기본 스타일 그대로 두고, 삭제 버튼만 `role: .destructive`를 줘서 빨간색으로 강조되게 했다.

```swift
Button {
    showResetConfirmation = true
} label: {
    // 생략
}
.disabled(flights.isEmpty)
// 생략
.alert("모든 기록을 삭제할까요?", isPresented: $showResetConfirmation) {
    Button("취소", role: .cancel) { }
    Button("삭제", role: .destructive) {
        for flight in flights {
            modelContext.delete(flight)
        }
    }
} message: {
    Text("이 기기에 저장된 모든 러닝 기록이 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
}
```

`SwiftDataFlight`는 좌표, 알림, 스플릿 전부 `deleteRule: .cascade`로 연결해 놨어서, `modelContext.delete(flight)`로 기록 하나만 지워도 거기 딸린 데이터가 알아서 같이 지워진다. 따로 좌표 배열이나 스플릿 배열을 순회하면서 지울 필요가 없었다.

```swift
// SwiftDataFlight
@Relationship(deleteRule: .cascade) var alerts: [SwiftDataAlert] = []
@Relationship(deleteRule: .cascade) var coordinates: [SwiftDataCoordinate] = []
@Relationship(deleteRule: .cascade) var splits: [SwiftDataSplit] = []
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/settings_delete.png){: width="50%" height="50%"}

만드는 중에 화면 전환이 전혀 안 되는 문제를 겪었다. 처음(헤더 버튼 방식)에는 설정 화면 전용으로 `SettingsDestination`이라는 열거형을 만들어서 썼는데, 원인은 `HomeView`의 `NavigationStack`이 들고 있는 경로가 타입 제한이 없는 범용 경로가 아니라 `[FlightDestination]`으로 못박힌 배열이었던 것. 이 배열엔 `FlightDestination`이 아닌 값은 애초에 들어갈 수가 없어서 버튼을 눌러도 조용히 아무 일도 안 일어났다.

```swift
// before: HomeView 안에서, 설정 전용 경로 타입을 따로 둠
enum SettingsDestination: Hashable {
    case announcements
    case privacyPolicy
    case dataBackup
}
```

앱 전체가 화면 전환 경로를 하나만 쓰고 있다는 걸 깜빡하고 새 열거형부터 만든 게 원인이었다. Settings를 아예 독립된 탭으로 옮기면서는, `RootTabView`가 새로 만들어주는 전용 `NavigationStack` 안에서만 쓰는 거라 `SettingsDestination`을 다시 써도 문제가 없어졌다. 그리고 공지사항/개인정보 처리방침/데이터 저장 화면 헤더도 `FLIGHT CALENDAR`, `TAKEOFF` 같은 다른 화면들과 똑같이 앱 공용 `customNavHeader`로 맞췄다.

```swift
// after
enum SettingsDestination: Hashable {
    case announcements
    case privacyPolicy
    case dataBackup
}

struct SettingsView: View {
    var body: some View {
        // 생략
        .customNavHeader("SETTINGS", showsBackButton: false)
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .announcements: AnnouncementsView()
            case .privacyPolicy: SettingsPrivacyPolicyView()
            case .dataBackup: DataBackupView()
            }
        }
    }
}
```

시뮬레이터로 직접 눌러보다가 발견해서 바로 고쳤다.

---

## 온보딩 업데이트

지금까지 추가한 기능들이 온보딩엔 하나도 반영이 안 돼 있어서 손을 봤다. 페이지 수도 6개에서 7개로 늘었다.

두 번째 페이지(TWO FLIGHT MODES)의 Mission Flight 목업을 실제 `ModeAView`의 PACE/HEART RATE 토글과 똑같이 캡슐 두 개로 바꾸고, 1km마다 음성 안내한다는 문구도 추가했다. 원래는 "목표 페이스·거리를 설정하는 Mission Flight"라고만 적혀 있었는데, 심박수 목표 모드가 생긴 지 한참인데 온보딩엔 이게 전혀 없었다.

![두 가지 비행 모드](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/onboarding_modes.png){: width="50%" height="50%"}

세 번째 페이지(GPWS ALERT)엔 Watch에서 경고 화면을 길게 눌러 실시간 계기판을 확인할 수 있다는 문구를 한 줄 추가했고, 네 번째 페이지(ALERTS ON MAP)의 지도 목업은 종료 마커를 실제 앱과 똑같이 E에서 F로 바꿨다.

![GPWS 경고](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/onboarding_gpws.png){: width="50%" height="50%"}
![지도 위의 경고](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/onboarding_alertmap.png){: width="50%" height="50%"}

CloudKit 백업은 아직 구현 전이지만, 다 됐다고 가정하고 새 페이지(CLOUD BACKUP)를 만들어서 Privacy Consent 바로 앞에 끼워 넣었다. 처음엔 "자동으로 백업되어"라고 썼는데, 백업 시점 자체를 아직 정하지 않았고(위 CloudKit 백업 생각해보기 참고) 지금 설정 화면의 백업 버튼도 수동 트리거를 전제로 만들어둔 거라 "자동"이라는 표현은 맞지 않아서 뺐다.

![CLOUD BACKUP](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/onboarding_cloudbackup.png){: width="50%" height="50%"}

---

## Alert 중복 처리

실기기로 심박 기반 Mission Flight를 테스트해보니 GPWS 경고가 너무 자주 떴다. 목표 구간 경계에 페이스나 심박이 딱 걸쳐 있으면 normal ↔ sink rate/overspeed 사이를 짧은 간격으로 계속 왔다 갔다 하는 게 원인이었다.

그럴 때마다 `PFDView`의 `saveAlert()`가 매번 새 `SwiftDataAlert`를 만들어서, 사실상 같은 사건인데 지도에 마커가 여러 개 찍히고 기록(`AlertsView`)에도 중복으로 쌓이는 문제가 있었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/alertsss.png){: width="50%" height="50%"}

화면 경고(플래시, 햅틱, 사운드, Live Activity)는 매번 그대로 뜨는 게 맞다.

실제로 그 순간 페이스/심박이 벗어난 건 사실이니까. 문제는 그걸 "새로운 사건"으로 기록에 남길지 여부였다. 그래서 방향을 심박수 자체를 더 다듬는 대신, "최근에 같은 종류의 경고가 해제된 적이 있으면 새로 저장하지 않는다"는 쿨다운을 경고 저장 쪽에 추가하는 걸로 바꿨다.

```swift
// RunViewModel.swift / WatchViewModel.swift
/// GPWS 상태별 마지막으로 정상(.normal)으로 돌아간 시각
var lastGPWSClearedAt: [String: Date] = [:]
/// 해제된 경고가 이 시간(초) 이내에 같은 종류로 다시 뜨면 새 기록으로 저장하지 않는다
static let alertRecordCooldown: TimeInterval = 20
```

`.onChange(of: gpwsStatus)`에서 `.normal`로 돌아가는 순간, 방금까지 어떤 경고였는지(`oldValue`)를 같이 봐서 그 시각을 기록해둔다.

```swift
// PFDView
.onChange(of: runViewModel.flightData.gpwsStatus) { oldValue, newValue in
    guard let status = newValue else { return }
    triggerGPWS(status)
    switch status {
    case .normal:
        if let previous = oldValue, previous == .sinkRate || previous == .overspeed {
            runViewModel.lastGPWSClearedAt[previous.rawValue] = .now
        }
        Task { await runViewModel.flightActivityService.clearGPWS() }
    // 생략
    }
}
```

`saveAlert()`는 저장하기 전에 이 쿨다운부터 확인한다.

```swift
func saveAlert() {
    let type = runViewModel.flightData.gpwsStatus?.rawValue ?? "normal"
    if let clearedAt = runViewModel.lastGPWSClearedAt[type],
       Date.now.timeIntervalSince(clearedAt) < RunViewModel.alertRecordCooldown {
        return
    }
    // 생략
}
```

같은 로직을 워치(`WatchPFDView`/`WatchViewModel`)에도 그대로 옮겼다. 심박 기반 모드가 원래 워치 전용이라, 사실 이 쿨다운이 제일 필요한 곳도 워치 쪽이다.

20초라는 쿨다운 값은 일단 감으로 잡은 거라, 실기기로 다시 테스트해보면서 조정할 수도 있다.

---

## 긴 러닝일수록 터치다운이 느려지는 문제

10km 정도 걷거나 뛰고 나서 TOUCHDOWN 버튼을 누르면 다음 화면으로 넘어가기까지 살짝 지연이 있었다. 처음엔 기록이 쌓일수록 `HomeView`의 전체 조회 쿼리가 느려지는 문제인 줄 알았는데, 다시 코드를 보니 그게 아니라 이번 러닝 자체의 크기 문제였다.

`saveRunningData()`를 도는 `RunViewModel`은 `@MainActor`다. 즉 화면을 그리는 것과 같은 스레드에서 이 함수도 돈다는 뜻이다. 10km면 GPS 좌표가 보통 수천 개는 쌓이는데, 이걸 `for` 루프로 `SwiftDataCoordinate`를 하나씩 만들어서 배열에 `.append()`하고 있었다. 좌표를 하나 넣을 때마다 SwiftData는 그 좌표한테 "너는 이 러닝 기록 소속이야"라는 연결 정보를 새로 써야 하는데, 이 작업을 3천 개면 3천 번 따로따로 하다 보니 그동안 화면이 멈춰 있는 구조였다.

중요한 건 좌표를 SwiftData가 쓸 수 있는 형태로 바꾸는 "변환" 자체는 두 방식 다 N번 해야 한다는 것. 차이는 그렇게 변환한 걸 러닝 기록에 "붙이는" 횟수다.

![좌표를 러닝 기록에 붙이는 횟수 차이](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/touchdown_attach_count_diagram.png){: width="100%" height="100%"}

```swift
// before
for (i, coord) in coords.enumerated() {
    runningData.coordinates.append(SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: i))
}
runningData.alerts.append(contentsOf: tempAlertArray)
let splits = await runningCenter.allSplits()
runningData.splits.append(contentsOf: splits.map { 
    // 생략
})
```

개별 append 대신 배열을 한 번에 통째로 대입하는 쪽으로 바꿨다. 이러면 그 연결 정보 쓰는 작업이 좌표 개수만큼 3천 번 반복되는 게 아니라, 배열 전체를 두고 한 번만 처리된다.

```swift
// after
runningData.coordinates = coords.enumerated().map { i, coord in
    SwiftDataCoordinate(latitude: coord.latitude, longitude: coord.longitude, order: i)
}
runningData.alerts = tempAlertArray
let splits = await runningCenter.allSplits()
runningData.splits = splits.map { 
    // 생략
}
```

워치 쪽(`WatchViewModel.saveRunningData()`)도 같은 구조라 똑같이 고쳤다. 이걸로 확실히 나아졌다고 자신하기보다는, 일단 제일 안전하고 간단한 것부터 해본 거라 실기기로 다시 10km쯤 뛰어보고 체감이 얼마나 달라지는지 봐야 할 것 같다. 그래도 여전히 느리면, 좌표를 메인 스레드가 아닌 별도 `ModelContext`에서 저장하거나 터치다운 화면 전환 자체를 저장 완료를 안 기다리고 먼저 넘어가는 방향도 남아있다.

좌표 개수(N)를 슬라이더로 바꿔가면서 두 방식이 얼마나 차이 나는지 직접 눌러볼 수 있게 만들어봤다.

<iframe
  src="/assets/demo/touchdown_save_simulator.html"
  width="100%"
  height="520px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

---

## 최적화?

CloudKit 백업 대상을 생각하다가, 좌표를 다 그대로 올릴 필요가 있나 싶어졌다. 실제로 좌표 배열을 쓰는 곳을 찾아보니 `FlightSummaryView`의 지도 폴리라인 그리기, `HomeView`의 최근 러닝 미니 경로 미리보기, 이 두 곳뿐이었다. 

페이스·심박수·케이던스·고도 같은 수치는 이미 km 스플릿 단위로 따로 저장돼 있어서, 좌표 자체를 다시 계산에 쓰는 곳은 없었다.

그러면 지도에 그릴 정도의 정밀도만 있으면 되는 셈이라, AI에게 어떤 방법을 통해 최적화를 하면 좋을지 물어보았고 경로를 단순화하는 유명한 알고리즘인 Douglas-Peucker를 추천해주었다. 

직선 구간은 점을 왕창 줄이고, 코너나 커브 구간은 모양을 지키려고 점을 더 남겨두는 방식이다. 이해를 돕기 위해 직접 눌러보는 시각화를 AI를 통해 만들어봤다.

<iframe
  src="/assets/demo/douglas_peucker_demo.html"
  width="100%"
  height="620px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

`RouteMapView`를 다시 보니 지도 확대 정도(`region.span`)를 경로 좌표들의 위도/경도 범위 × 1.3배로 정하고 있었다. 러닝이 짧을수록 지도가 자동으로 더 확대돼서 보인다는 뜻이다.

```swift
// RouteMapView
struct RouteData {
    let coordinates: [CLLocationCoordinate2D]

    var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else { return MKCoordinateRegion() }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.max()! + lats.min()!) / 2,
            longitude: (lons.max()! + lons.min()!) / 2
        )
        // 경로의 위도/경도 범위에 여백 30%를 더한 값을 span으로 쓴다.
        // 경로 자체가 짧으면 이 범위도 좁아지니, 지도는 그만큼 더 확대된다.
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.3,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.3
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
```

유저가 손으로 확대하는 게 아니라 러닝 길이 자체가 확대 배율을 정하는 구조라, 고정된 미터 단위 기준으로는 짧은 러닝에서 단순화 오차가 화면에 훨씬 크게 티가 날 수 있다.

그래서 기준을 경로 대각선 길이에 비례하는 값(예: 대각선의 0.5%)으로 두되, 최소/최대 상한선을 같이 두는 쪽으로 방향을 잡았다. 너무 작으면(GPS 자체 오차인 3~5m보다 작으면) 의미가 없고, 너무 크면 긴 러닝에서 모양 자체가 뭉개질 수 있어서다.

```swift
// before: 처음 생각했던, 고정된 미터 값 기준
enum PolylineSimplifier {
    private static let tolerance = 5.0 // 러닝 길이와 상관없이 항상 5m

    static func simplify(_ coordinates: [(latitude: Double, longitude: Double)]) -> [(latitude: Double, longitude: Double)] {
        guard coordinates.count > 2 else { return coordinates }
        let points = project(coordinates) // 위경도 -> 로컬 미터 좌표 변환
        let keptIndices = simplifiedIndices(points, tolerance: tolerance)
        return keptIndices.map { coordinates[$0] }
    }
    // 생략
}
```

```swift
// after: 경로 대각선 길이에 비례한 값 + 최소/최대 상한
enum PolylineSimplifier {
    private static let minTolerance = 3.0   // GPS 자체 오차(3~5m)보다 작으면 의미 없음
    private static let maxTolerance = 18.0  // 너무 크면 긴 러닝에서 모양이 뭉개짐
    private static let toleranceRatio = 0.005 // 대각선 길이의 0.5%

    static func simplify(_ coordinates: [(latitude: Double, longitude: Double)]) -> [(latitude: Double, longitude: Double)] {
        guard coordinates.count > 2 else { return coordinates }
        let points = project(coordinates) // 위경도 -> 로컬 미터 좌표 변환

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let diagonal = hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
        let tolerance = min(max(diagonal * toleranceRatio, minTolerance), maxTolerance)

        let keptIndices = simplifiedIndices(points, tolerance: tolerance)
        return keptIndices.map { coordinates[$0] }
    }
    // 생략
}
```

좌표를 나중에 다른 용도로 더 쓰게 되더라도 문제는 없어 보인다. GPWS 경고 기록은 자기 위도/경도를 따로 저장하고 있고, 분석에 쓸 지표들도 이미 스플릿 단위로 집계돼 있어서, 좌표 배열의 해상도랑은 무관하기 때문이다. 이건 아직 생각만 정리한 단계라, 실제로 로컬 저장 방식까지 손볼지는 CloudKit 붙일 때 같이 정할 예정이다.

---

## CloudKit 백업/복원 구현하기

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/signandcap.png){: width="50%" height="50%"}

우선 Signing & Capabilities에 CloudKit을 추가해준다. CloudKit 백업 생각해보기에서는 SwiftData의 자동 동기화(`ModelConfiguration(cloudKitDatabase:)`)를 그대로 써볼 생각이었는데, 다시 보니 애초에 방향을 "자동 트리거 없이 버튼을 눌러야 실행"으로 잡아뒀었다. SwiftData의 자동 동기화는 백그라운드에서 알아서 도는 방식이라 이 방향이랑 안 맞아서, 처음부터 버튼을 눌렀을 때만 [`CKRecord`](https://developer.apple.com/documentation/cloudkit/ckrecord)를 직접 만들어서 CloudKit에 올리고 받는 방식으로 갔다.

---

### CloudBackupService로 백업/복원 구현

`CloudBackupService`라는 서비스를 새로 만들었다. 레코드 타입은 `Flight` 하나만 쓰고, 기록 하나(`SwiftDataFlight`)에 딸린 좌표/알림/스플릿 배열은 각각 레코드로 쪼개지 않고 JSON으로 인코딩해서 같은 레코드의 필드 하나에 통째로 넣었다. 개인 백업이라 CloudKit에서 좌표 하나하나를 따로 조회할 일이 없어서, 굳이 여러 레코드 타입 + 관계로 나눌 필요가 없었다.

`Flight` 레코드의 필드 구성은 이렇다.

- **레코드 ID**: `flight.id`(UUID)를 문자열로 바꿔서 `CKRecord.ID(recordName:)`에 그대로 쓴다. 같은 기록을 다시 백업해도 항상 같은 레코드를 가리키게 하기 위해서다.
- **스칼라 필드 12개**: `mode`(String), `distance`(Double), `time`(Int), `pace`(Double), `heartRate`(Int), `cadence`(Int), `fuel`(Int), `date`(Date), `missionTarget`(String), `missionTargetPace`(Double), `missionPaceDeviation`(Int), `missionTargetHeartRate`(Double), `missionHeartRateDeviation`(Int), `missionTargetDistance`(Double). `SwiftDataFlight`의 필드 이름과 타입을 그대로 옮겼다.
- **`coordinatesData`, `alertsData`, `splitsData`**: 전부 `Data` 타입. 좌표/알림/스플릿 배열을 각각 작은 `Codable` 구조체(`CoordinateBackup`, `AlertBackup`, `SplitBackup`)로 만들고, `JSONEncoder`로 인코딩해서 넣는다.

```swift
// CloudBackupService.swift
enum CloudBackupService {
    private static let recordType = "Flight"

    static func backup(_ flights: [SwiftDataFlight]) async throws -> Int {
        let records = try flights.map { flight -> CKRecord in
            let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: flight.id.uuidString))
            record["mode"] = flight.mode
            record["distance"] = flight.distance
            record["time"] = flight.time
            // 생략 

            let coordinates = flight.coordinates.map { CoordinateBackup(latitude: $0.latitude, longitude: $0.longitude, order: $0.order) }
            record["coordinatesData"] = try JSONEncoder().encode(coordinates) as NSData
            // 생략 

            return record
        }

        let database = CKContainer.default().privateCloudDatabase
        let (saveResults, _) = try await database.modifyRecords(saving: records, deleting: [])
        return saveResults.values.filter { if case .success = $0 { return true }; return false }.count
    }

    static func restore(into modelContext: ModelContext, existingIDs: Set<UUID>) async throws -> Int {
        let database = CKContainer.default().privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (matchResults, _) = try await database.records(matching: query)
        // 생략 
    }
}
```

---

### CloudSyncStatusService 구현

백업/복원 버튼은 iCloud 계정이 실제로 연결돼 있을 때만 눌리게 하고 싶어서, `CKContainer.default().accountStatus()`로 계정 상태를 확인하는 `CloudSyncStatusService`도 같이 만들었다.

```swift
// CloudSyncStatusService.swift
enum CloudSyncStatus {
    case checking, available, noAccount, restricted, unavailable

    var label: String {
        switch self {
        case .checking: return "iCloud 상태 확인 중"
        case .available: return "iCloud 연결됨"
        case .noAccount: return "iCloud에 로그인되어 있지 않습니다"
        case .restricted: return "iCloud 사용이 제한되어 있습니다"
        case .unavailable: return "iCloud 상태를 확인할 수 없습니다"
        }
    }
}

enum CloudSyncStatusService {
    static func currentStatus() async -> CloudSyncStatus {
        do {
            let status = try await CKContainer.default().accountStatus()
            switch status {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .couldNotDetermine, .temporarilyUnavailable: return .unavailable
            @unknown default: return .unavailable
            }
        } catch {
            return .unavailable
        }
    }
}
```

이 상태로 엔타이틀먼트를 잠깐 지운 채로 빌드했더니, 데이터 저장/복원 화면에 들어가자마자 크래시가 났다. 

[CKContainer.default() Docs](https://developer.apple.com/documentation/cloudkit/ckcontainer)는 앱에 iCloud 엔타이틀먼트가 아예 없으면 그 자리에서 죽어버리는 API였다. 맨 위에서 Signing & Capabilities에 CloudKit을 추가해둔 이유가 이거였고, 엔타이틀먼트를 되돌리니 바로 해결됐다.

버튼도 백업/복원 둘 다 이 상태가 연결됨일 때만 눌리게 했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/icloud_status.png){: width="50%" height="50%"}

**버그 1. 두 번째 백업부터 조용히 0개 처리됨**

백업 버튼을 눌러보니 CloudKit Dashboard에 `Flight` 레코드 타입까지는 잘 생겼는데, 두 번째로 누르니 "0개 백업했습니다"라고 떴다. [`modifyRecords(saving:deleting:savePolicy:)`](https://developer.apple.com/documentation/cloudkit/ckmodifyrecordsoperation/recordsavepolicy)의 기본 저장 정책은 `.ifServerRecordUnchanged`인데, 이미 같은 `id`로 레코드가 한 번 올라가 있는 상태에서 "서버에 있는 버전이랑 내가 지금 보내는 버전이 같은 건지"를 비교하다가, 새로 만든 레코드엔 그 비교에 필요한 정보(변경 태그, `recordChangeTag`)가 없으니 충돌로 보고 저장을 실패시킨 거였다. 게다가 이 실패가 에러를 던지는 게 아니라 레코드별 결과(`Result<CKRecord, Error>`) 안에 실패로만 담겨서, 겉으로는 아무 문제 없어 보였다.

```swift
// before
let (saveResults, _) = try await database.modifyRecords(saving: records, deleting: [])

// after: 항상 로컬 상태로 무조건 덮어쓴다
let (saveResults, _) = try await database.modifyRecords(
    saving: records, deleting: [], savePolicy: .changedKeys, atomically: false
)
```

---

**버그 2. 백업은 되는데 대시보드에서 조회가 안 됨**

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/dashboarderror.png){: width="50%" height="50%"}

백업은 됐는데 이번엔 CloudKit Dashboard에서 직접 `Flight` 레코드를 조회해보니 "Field 'recordName' is not marked queryable"이라는 에러가 났다. CloudKit은 [`CKQuery`](https://developer.apple.com/documentation/cloudkit/ckquery)로 조회할 때 조건이나 정렬에 쓰는 필드마다 Queryable 인덱스가 걸려 있어야 하는데, `mode`/`distance`/`date` 같은 우리가 만든 필드는 레코드를 저장할 때 자동으로 인덱스가 걸리는 반면, `recordName`은 기본으로는 인덱스가 안 걸려 있다. 그런데 우리 쿼리(`NSPredicate(value: true)`, 조건 없이 전체 조회)는 조건에 걸리는 필드가 하나도 없어서, CloudKit이 내부적으로 recordName을 끌어다 쓰려다 막힌 것.

```swift
// before
let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

// after: 조회 가능한 필드(date)를 조건 자체에 넣어서 recordName 참조를 피한다
let query = CKQuery(
    recordType: recordType,
    predicate: NSPredicate(format: "date > %@", Date(timeIntervalSince1970: 0) as NSDate)
)
query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
```

코드는 고쳤는데, CloudKit Dashboard의 Query Records 화면에서 조건/정렬 없이 그냥 눌러보면 여전히 같은 에러가 난다. 앱에서는 복원이 잘 되는데 대시보드에서는 왜 안 될까 궁금했는데, 이건 우리 스키마 문제가 아니라 대시보드 자체의 동작 방식 때문이었다. 

대시보드의 "Query Records" 버튼은 필터/정렬을 아무것도 안 넣으면 자기 나름의 기본 조회를 만드는데, 그때 recordName을 참조하는 것으로 보인다. 반면 우리 앱 코드는 조건(`date > ...`)과 정렬(`date` 기준) 둘 다 이미 인덱스가 있는 `date` 필드만 쓰도록 명시했기 때문에 recordName을 아예 참조할 일이 없다. 대시보드에서 그때그때 `date`로 정렬(또는 필터) 조건을 직접 추가해서 눌러봐도 되지만, [Apple Docs](https://developer.apple.com/documentation/cloudkit/inspecting-and-editing-an-icloud-container-s-schema#Enable-querying-for-your-record-type)를 보니 아예 recordName 자체에 QUERYABLE 인덱스를 걸어두는 방법도 있었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/addindex.png){: width="50%" height="50%"}

- Dashboard 왼쪽 메뉴에서 **Schema > Indexes**로 들어간다.
- 위쪽 **+** 버튼을 눌러 Add Index를 연다.
- Record Type을 `Flight`(우리 레코드 타입)로 고른다.
- Name엔 아무 이름이나 넣는다(예: `RecordNameIndex`).
- Type을 **QUERYABLE**로 설정한다.
- Field를 `recordName`으로 고르고 Add.

이렇게 인덱스를 한 번 추가해두면, 그다음부턴 Query Records를 조건 없이 눌러도 에러가 안 난다.

이 두 가지를 고치고 나서야 기기에서 기록을 전부 지운 다음 복원 버튼으로 CloudKit에 있던 기록을 다시 받아오는 것까지 확인됐다.

![](/assets/images/upload/cloudresult.png){: width="50%" height="50%"}

---

## 로컬라이제이션 빠진 부분 채우기

CloudKit 백업까지 붙이고 나니 새로 만든 화면들 로컬라이제이션은 제대로 됐는지 궁금해져서 `Localizable.xcstrings`를 처음부터 훑어봤다. 파일을 열어보니 숫자나 기호만 있는 키(예: `%lld`, `-`)는 원래 영어/일본어로 따로 번역할 필요가 없는 것들이고, RUNWAY나 TAKEOFF 같은 항공 컨셉 브랜딩 텍스트도 의도적으로 항상 영어로 두는 것들이라 그대로 둬야 했다. 진짜 문제는 이 둘을 걸러내고 나서 남는, 화면에 진짜 한국어로만 박혀 있고 영어/일본어 번역이 아예 비어 있는 텍스트들이었다.

찾아보니 데이터 초기화 버튼과 확인 알럿("데이터 초기화", "모든 기록을 삭제할까요?"), iCloud 백업 화면 설명 문구, "현재 이 기기에 저장된 기록", HEART RATE 모드를 못 쓸 때 뜨는 알럿 두 개, "HEART RATE 모드 사용 불가", "MINIMUMS 50m 전 경고", GPWS/Mission Flight 온보딩 설명 문구, "마지막 %lldM 구간 - TOO SHORT"까지 총 15개 키가 번역이 빠져 있었다. `Localizable.xcstrings`는 결국 JSON이라서, 각 키 밑에 `localizations.en`/`localizations.ja`를 채워 넣는 스크립트를 짜서 한 번에 넣었다.

```json
"데이터 초기화": {
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Reset Data" } },
    "ja": { "stringUnit": { "state": "translated", "value": "データをリセット" } }
  }
}
```

이걸로 끝난 줄 알았는데, 나중에 iCloud 백업/복원 결과 메시지("N개의 기록을 백업했습니다" 같은 문구)가 여전히 한글로만 뜨는 걸 발견했다. 다시 찾아보니 `Localizable.xcstrings`가 자동으로 잡아주는 건 `Text("리터럴 문자열")`처럼 소스 코드에 직접 박혀 있는 문자열뿐이었다. `CloudSyncStatusService`의 상태 문구는 `var label: String { switch self { ... return "iCloud 연결됨" ... } }`처럼 계산 프로퍼티가 반환하는 값이었고, 데이터 저장/복원 화면의 결과 메시지도 `resultMessage`라는 변수에 담아서 `Text(resultMessage)`로 뿌리고 있었다. 둘 다 `Text()` 안에 직접 리터럴이 있는 게 아니라 변수를 거쳐서 나가니, Xcode가 애초에 이런 문자열이 있는지조차 몰랐던 거다.

고치는 방법은 그 변수/프로퍼티의 타입을 `String` 대신 `LocalizedStringKey`로 바꾸는 거였다. 같은 파일 안에서 이미 이 타입을 쓰고 있는 `OnboardingScaffold(title:subtitle:)`는 온보딩 문구가 잘 번역되고 있었어서, 타입만 바꾸면 될 거라 생각했다. `CloudSyncStatusService.label`, 데이터 저장/복원 화면의 `resultMessage`와 버튼 타이틀, 설정 화면 메뉴 이름, 공지사항 항목들, Mission Flight 목표 거리의 "하프"/"풀" 라벨까지 같은 패턴을 전부 찾아서 타입을 바꿨다.

```swift
// before
var label: String {
    switch self {
    case .checking: return "iCloud 상태 확인 중"
    // 생략
    }
}

// after
var label: LocalizedStringKey {
    switch self {
    case .checking: return "iCloud 상태 확인 중"
    // 생략
    }
}
```

그런데 빌드하고 `Localizable.xcstrings`를 다시 열어보니, 타입을 바꿨다고 전부 자동으로 잡히는 게 아니었다. 삼항연산자 안에 있던 "하프"/"풀"만 새로 잡히고, 나머지(계산 프로퍼티가 반환하는 값, 커스텀 뷰 프로퍼티로 전달되는 값)는 여전히 안 잡혔다. 결국 이번에도 스크립트로 23개 키를 `Localizable.xcstrings`에 직접 채워 넣었다. 타입을 `LocalizedStringKey`로 바꾸는 건 여전히 필요한 조치였다. 그래야 `Text()`가 이 값을 카탈로그에서 찾아야 하는 키로 취급하지, 화면에 그대로 찍어야 하는 리터럴 문자열로 취급하지 않기 때문이다.

---

## 러닝 중에 딴 탭 눌리면 미러링이 끊기는 문제

실기기 테스트하다가 러닝 중에 실수로 다른 탭을 눌렀더니, 러닝 자체는 `.onDisappear`에서 멈추는데 워치 쪽 미러링은 그대로 유지되면서 거리 같은 값만 더 이상 안 올라가는 상태가 됐다. ROTATE를 눌러서 실제로 러닝을 시작한 순간부터 종료할 때까지는 탭바나 뒤로가기로 못 나가게 막는 쪽으로 고쳤다. Pre-flight Check 화면(TAKEOFF)만 보고 있는 동안은 아직 아무것도 시작 안 한 상태니까 자유롭게 나갈 수 있어야 하고, Summary 화면까지 가면 탭바가 다시 보여야 한다.

고치다 보니 `RootTabView`의 Deck 탭이 `NavigationStack { HomeView() }`로 감싸져 있었는데, `HomeView` 안에서 이미 자기 `NavigationStack`을 따로 열고 있어서 이중으로 감싸진 상태였다. 이 이중 구조가 있으면 러닝 화면에서 건 `.toolbar(.hidden, for: .tabBar)`가 위쪽 탭바까지 제대로 안 먹을 수 있어서 먼저 걷어냈다.

```swift
// before
Tab("Deck") {
    NavigationStack { HomeView() }
}

// after
Tab("Deck") {
    HomeView()
}
```

TAKEOFF 화면엔 "카운트다운을 시작했는지"를 나타내는 `isLaunching` 계산 프로퍼티를 두고, 이 값에 따라 뒤로가기/탭바 숨김을 조건부로 걸었다. `countdownActive`만 보면 카운트다운이 끝나고 PFDView로 넘어가는 찰나에 다시 풀렸다가 잠기는 게 애매해지길래, 카운트다운이 끝난 뒤에도 계속 `true`로 남는 `didStartFlight`까지 같이 봤다.

```swift
// TakeoffView.swift
private var isLaunching: Bool { countdownActive || didStartFlight }
// 생략
.customNavHeader("TAKEOFF", showsBackButton: !isLaunching)
.navigationBarBackButtonHidden(isLaunching)
.toolbar(isLaunching ? .hidden : .visible, for: .tabBar)
```

PFDView(러닝 중 화면)는 들어온 시점에 이미 러닝이 시작된 뒤라 조건 없이 그냥 숨긴다.

```swift
// PFDView.swift
.navigationBarHidden(true)
.navigationBarBackButtonHidden(true)
.toolbar(.hidden, for: .tabBar)
```

FlightSummaryView는 원래부터 탭바를 숨기는 코드가 없어서 손대지 않았다. 시뮬레이터로 확인해보니 TAKEOFF에서 ROTATE 누르기 전엔 뒤로가기/탭바가 그대로 보이다가, ROTATE를 누르고 카운트다운이 시작되면서(PFDView로 넘어간 뒤까지) 둘 다 사라지는 게 의도한 대로 동작했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-07-28-RunningProject-36/rotate.gif){: width="50%" height="50%"}

---

## 워치 미러링 중 러닝이 겹쳐서 종료되는 문제

실기기에서 겪은 문제다. 미러링 중에 워치로 러닝을 종료했는데 그 순간 아이폰은 아직 살아있었다. 그 상태에서 워치로 러닝을 다시 시작하니 워치와 아이폰이 각자 위치 정보를 쌓는 상태가 겹쳤고, 워치 러닝을 마저 종료하니 로그에 값이 세 번 찍혔다. 워치에서 처음 종료했을 때 값, 겹친 상태에서 종료한 값, 그리고 아이폰을 마저 종료해서 저장된 값.

원인은 두 기기가 "이건 같은 러닝이다"를 서로 알 방법이 없었다는 거였다. `RunViewModel`과 `WatchViewModel` 둘 다에 `runSessionID`라는 문자열 프로퍼티를 추가해서, 러닝을 시작하는 쪽에서 새 UUID를 발급하고(`resetState()`에서 비움) 이 값을 `flightData`와 최종 저장 메시지에 매번 실어 보냈다. 저장할 때도 이 값을 그대로 `SwiftDataFlight.id`로 썼다.

```swift
// RunViewModel.swift
var runSessionID: String?
// start()에서: runSessionID = UUID().uuidString
// resetState()에서: runSessionID = nil

func saveRunningData() async {
    // 생략
    let sessionUUID = runSessionID.flatMap(UUID.init(uuidString:)) ?? UUID()
    var existingDescriptor = FetchDescriptor<SwiftDataFlight>(predicate: #Predicate { $0.id == sessionUUID })
    existingDescriptor.fetchLimit = 1
    if let existing = try? modelContext.fetch(existingDescriptor).first {
        lastSavedFlight = existing
        return
    }
    // 생략
    runningData.id = sessionUUID
    // 생략
}
```

저장 시점에 같은 id가 이미 있는지만 확인하면, 같은 러닝이 두 번 이상 저장 신호를 보내도 처음 한 번만 실제로 저장된다. 워치 단독 러닝을 아이폰이 나중에 받는 경로(`transferUserInfo` → `pendingWatchDataQueue`)도 같은 방식으로 고쳤다.

```swift
// HomeView.swift
private func drainPendingWatchData(_ queue: [SwiftDataFlight]) {
    guard !queue.isEmpty else { return }
    for flight in queue where flight.distance >= 0.1 {
        let flightID = flight.id
        var descriptor = FetchDescriptor<SwiftDataFlight>(predicate: #Predicate { $0.id == flightID })
        descriptor.fetchLimit = 1
        guard (try? modelContext.fetch(descriptor).first) == nil else { continue }
        modelContext.insert(flight)
    }
    runViewModel.pendingWatchDataQueue.removeAll()
}
```

id를 맞추는 것만으론 부족했다. 미러링은 항상 아이폰만 주도할 수 있어서, 워치가 러닝을 종료했다가 다시 시작한 건 미러링과 상관없이 워치 혼자 새 러닝을 도는 것뿐이다. 그런데 아직 죽지 않은 아이폰은 예전 미러링 세션이 계속되고 있는 줄 알고 자기 쪽 `flightData`를 워치로 계속 흘려보내고 있었다. 그래서 워치가 `flightData`를 받는 쪽에서 "지금 내가 실제로 미러링을 받는 입장일 때만" 반영하게 가드를 추가했다. 아이폰 쪽에도 대칭으로 같은 가드를 넣어서, 서로 자기 러닝을 새로 도는 중일 땐 상대가 보내는 예전 데이터를 무시하게 했다.

```swift
// WatchConnectivityService+watchOS.swift, session(_:didReceiveMessage:) 안 flightData 분기
Task { @MainActor in
    guard HealthKitService.shared.startOrigin == .remote else { return }
    if let incomingSessionID, !incomingSessionID.isEmpty {
        viewModel?.runSessionID = incomingSessionID
    }
    viewModel?.flightData = flightData
    viewModel?.isPaused = false
}
```

여기까지 고치고 나서 `HealthKitService+iOS.swift`의 `retrieveRemoteSession()`이라는 함수를 다시 들여다봤다. 워치가 `startMirroringToCompanionDevice()`로 자기 세션을 아이폰에 흘려보내면 이 함수가 받아서 아이폰의 `startOrigin`을 `.remote`로 바꾸는데, `HealthKitService.swift`를 보니 워치는 `startOrigin != .local`일 때만(아이폰이 주도해서 워치가 따라가는 경우에만) 그 호출 자체를 한다. 즉 `retrieveRemoteSession()`은 "워치주도 미러링"을 받는 코드가 아니라 "아이폰주도 미러링"에서 워치가 자기 세션을 다시 흘려보내주는 걸 받는 자리였다.

근데 심박수/케이던스는 이거랑 상관없이 이미 `sendHealthData()`로 3초마다 아이폰에 전달되고 있었고, Apple Health에 실제로 저장되는 워크아웃(`finishWorkout()`)도 워치 쪽 코드에만 있었다. 아이폰이 받는 미러링된 세션은 심박수 전달에도 Health 저장에도 안 쓰이고 있었던 것. 오히려 이게 아이폰 `startOrigin`을 뒤늦게 `.remote`로 바꿔버리면 `saveRunningData()`의 `startOrigin == .local` 저장 가드가 깨지거나, `TakeoffView`에서 이미 `.pfd`로 넘어간 내비게이션 경로에 같은 화면이 중복으로 쌓일 위험만 있었다.

그래서 `retrieveRemoteSession()` 등록과 본문을 주석 처리하고, 이제 절대 안 불릴 `startOrigin == .remote` running 분기도 같이 정리했다. 워치 앱을 깨우는 `startWatchApp(toHandle:)` 호출 자체는 미러링 수신과 별개(워치 앱 실행 트리거)라 그대로 뒀다.

이 정리 이후에도 "앱에서 끝내면 워치도 같이 끝나고, 워치에서 끝내면 앱도 같이 끝나는" 구조는 유지된다. 시작 쪽 native 미러링(`retrieveRemoteSession()`)과는 완전히 별개로, 우리가 직접 만든 `sendStopSignal()`/`handleStopSignal()` 메시지 채널로 돌아가기 때문이다. 아이폰이 종료하면 `stopOrigin == .local` → `sendStopSignal()` → 워치가 받아서 `stopOrigin`이 `.remote`가 되고 워치도 `saveRunningData()` + `resetState()`로 같이 종료된다. 워치에서 종료할 때(미러링 중이면)도 반대 방향으로 똑같이 일어난다. 어느 쪽에서 눌러도 이 메시지 하나로 반대쪽까지 정리되는 걸 눈으로 보면 이해가 쉬울 것 같아서 만들어봤다.

<iframe
  src="/assets/demo/mirroring_stop_signal_simulator.html"
  width="100%"
  height="580px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

실제 워치+아이폰 조합으로 겪었던 상황이라 시뮬레이터만으로는 완전히 재현이 안 됐는데, 실기기로 직접 종료→재개 순서를 다시 해보니 문제가 하나 더 있었다. 아이폰이 `startWatchApp`으로 워치 앱을 직접 실행시키면서 미러링하는 경우, 워치에서 러닝을 종료해도 아이폰 쪽 러닝이 전혀 끝나지 않았다.

원인은 `WatchViewModel`이 자기 종료를 아이폰에 알릴지를 `runningMode == .mirrored`로 판단하고 있었던 것. `runningMode`는 `session?.startMirroringToCompanionDevice()`가 **성공했을 때만** `.mirrored`로 바뀌는데, 방금 `retrieveRemoteSession()`(그 핸드셰이크를 받아주는 리스너)을 꺼버려서 아이폰 쪽에 받아줄 게 없어졌다. 이 호출이 실패하면 `runningMode`는 계속 `.standalone`으로 남고, 워치에서 종료해도 `sendStopSignal()`이 아예 안 불려서 아이폰은 종료 신호를 영영 못 받는다.

```swift
// before
if result.runningMode == .mirrored {
    watchConnectivityService.sendStopSignal()
}

// after
if HealthKitService.shared.startOrigin != .local {
    watchConnectivityService.sendStopSignal()
}
```

`startOrigin`은 `AppDelegate.handle()`에서 이 핸드셰이크 성공 여부와 무관하게 항상 먼저 세팅되고 `stopWorkout()`도 건드리지 않아서, 종료 이벤트를 처리하는 시점까지 그대로 남아있다. "이 러닝을 아이폰이 주도했는가"의 판단 기준을 핸드셰이크 성공 여부가 아니라 애초에 항상 세팅되는 값으로 바꾼 셈이다.

`origin`/`remote`/`local`이 여러 함수를 거치면서 계속 바뀌다 보니 코드만 보고 따라가긴 까다로워서, 종료 신호가 실제로 어떻게 오가는지 시각적으로 정리해봤다.

<iframe
  src="/assets/demo/mirroring_state_flow_simulator.html"
  width="100%"
  height="610px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

---

## Logbook 월 -> 주로 묶기

테스트하느라 러닝을 10몇 번 하고 나니 Logbook 화면이 그냥 쭉 나열된 리스트라 보기가 별로였다. 공지사항 화면에서 이미 쓰고 있던 `DisclosureGroup`을 이중으로 써서, 월 -> 주 단위로 접었다 펼 수 있게 바꿨다.

주는 실제 달력 주가 아니라 그 달 1일부터 7일 단위로 끊은 "N주차"로 잡았다. 달 경계에 걸쳐서 주가 애매하게 쪼개지는 걸 피하고 싶어서다. 최신 달과 그 안의 최신 주만 기본으로 펼쳐두고 나머지는 접어둔다. 한 번이라도 직접 펼치거나 접으면 그 상태가 그다음부터 우선된다.

```swift
private func monthBinding(_ month: LogMonthGroup, isLatest: Bool) -> Binding<Bool> {
    Binding(
        get: { monthOverrides[month.id] ?? isLatest },
        set: { monthOverrides[month.id] = $0 }
    )
}
```

공지사항 화면에서 화살표 색을 앱 컬러로 강제하려고 만들었던 커스텀 `DisclosureGroupStyle`을 이번엔 두 화면에서 같이 쓰게 됐길래, `Shared/View/` 밑으로 옮겨서 공용으로 썼다.

목록 자체도 `ScrollView` 안에 `VStack`을 쓰고 있던 걸 `LazyVStack`으로 바꿨다. `VStack`은 화면에 안 보이는 항목까지 전부 한 번에 레이아웃을 잡는데, 기록이 쌓일수록 매번 그 전체를 다시 그리는 셈이라 굳이 있을 필요 없는 부담이었다.

---

## 음악 들으면서 뛰면 km 스플릿 TTS가 안 들리는 문제

실기기로 음악을 들으면서 뛰어보니, km 스플릿 안내 자체가 아예 안 들렸다. `SpeechAnnouncerService`는 `AVAudioSession`을 `.playback` 카테고리 + `.duckOthers` 옵션으로 설정해서, 안내가 나오는 동안만 음악 소리를 줄이도록 되어 있는데, 이 설정(`configureAudioSession()`)이 러닝 시작(`start()`) 시점에 딱 한 번만 불리고 있었다. 중간에 음악 앱이 오디오 세션을 가져가면서 우리 세션이 인터럽트되면, 그 뒤로는 `synthesizer.speak()`가 계속 호출되어도 `.duckOthers` 설정 자체가 더 이상 유효하지 않은 상태로 남았다.

1차로는 `speak()` 호출 직전에 `configureAudioSession()`을 다시 불러서, 말할 때마다 세션을 새로 활성화시키는 걸로 고쳤다. 그런데 다시 실기기로 테스트해보니 이번엔 정반대 문제가 나왔다. 음악 소리가 스플릿 안내 몇 초 동안만 줄어드는 게 아니라 러닝 내내 줄어든 채로 안 돌아왔다. 원인은 `start()` 시점에도 여전히 세션 활성화 코드가 하나 남아있어서, 러닝을 시작하자마자 duck이 걸리고 그 뒤로는 딱히 풀어주는 코드가 없었기 때문이었다. 덕킹은 `speak()`를 부르는 순간이 아니라 세션이 활성화되어 있는 동안 계속 걸리는 것이라, `start()`에서의 활성화 호출을 완전히 없애고 `AVSpeechSynthesizerDelegate`의 `didFinish`/`didCancel` 콜백에서 바로 세션을 비활성화하도록 고쳤다.

```swift
func announce(split: Split) {
    configureAudioSession()  // 말하기 직전에만 세션을 활성화
    // 생략
    synthesizer.speak(utterance)
}

func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
}
```

여기에 더해 `.duckOthers`만으로는 팟캐스트나 오디오북처럼 상대도 말하고 있는 오디오까지는 잘 안 눌리길래, 애플 문서에서 찾은 [`interruptSpokenAudioAndMixWithOthers`](https://developer.apple.com/documentation/avfoundation/avaudiosession/categoryoptions/1616534-interruptspokenaudioandmixwithot)를 같이 켰다. 이 옵션은 음악 같은 단순 재생 오디오는 볼륨만 줄이고, 말하는 콘텐츠는 안내가 나오는 동안 아예 멈췄다가 이어서 재생해준다. 이 서비스는 `Shared/`에 있어서 iOS/watchOS 양쪽에 한 번에 적용됐다.

여기까지는 아이폰이 러닝을 주도할 때는 잘 맞았는데, 워치 단독으로 러닝하면서 아이폰으로 음악을 들을 때는 여전히 TTS가 전혀 안 들렸다. 처음엔 코드 문제인 줄 알았는데, 파고들어보니 구조적인 문제였다. 에어팟은 아이폰/워치 양쪽에 블루투스로 동시에 페어링되어 있어도, 실제 오디오 스트림은 한 번에 한 기기만 가져간다. 음악이 아이폰에서 나오고 있으면 그 순간 오디오 스트림의 주인은 아이폰이고, 워치가 아무리 자기 세션을 활성화해도 에어팟으로는 안 들린다. `AVAudioSession`은 기기별로 완전히 독립된 인스턴스라, 워치 쪽 설정이 아이폰 쪽 오디오에 영향을 줄 방법 자체가 없다.

같은 문제를 나이키 런 클럽도 겪고 있는지 찾아보니, 커뮤니티에 정확히 같은 증상과 워크어라운드가 있었다. "워치에서 러닝을 시작하든 아이폰에서 시작하든, 오디오 피드백은 워치 스피커로만 나온다"는 보고와 함께, 해결법으로 제시된 건 음악도 워치 자체(Music/Podcasts 앱 등)에서 먼저 재생한 뒤 러닝 앱을 여는 것뿐이었다. 즉 애플 생태계 전체가 갖고 있는 한계고, 우리 앱만의 버그가 아니었다. 음악과 TTS가 같은 기기의 같은 오디오 세션에서 나오기만 하면 에어팟이 어떤 기기와 페어링되어 있느냐는 상관없이 정상 작동한다는 뜻이라, 코드로는 더 손댈 게 없었다.

그래서 이건 공지사항(Settings > 공지사항) 화면에 TIPS 섹션을 새로 만들어 "워치 단독 러닝에서 아이폰으로 음악을 재생하면 에어팟 연결 특성상 TTS가 안 들릴 수 있고, 음악도 Apple Watch에서 재생하면 정상적으로 들린다"고 안내하는 걸로 정리했다. 실제로 워치 라이브러리에 저장된 음악을 워치에서 재생한 채로 실기기 테스트를 해보니 km 스플릿 TTS가 정상적으로 들렸다.

## 배포 전 정리

제출 전에 안 쓰는 설정이 있는지 점검하다가, `Info.plist`의 `UIBackgroundModes`에 `remote-notification`이, entitlements에 `aps-environment`가 남아있는 걸 발견했다. 코드 전체를 찾아봐도 `CKSubscription`이나 `didReceiveRemoteNotification` 같은 건 전혀 없었는데, `CloudBackupService`를 만들 때 SwiftData의 자동 CloudKit 동기화 대신 유저가 버튼을 누를 때만 `CKRecord`를 직접 올리고 받는 수동 방식으로 설계했었기 때문이다. 즉 백그라운드 push로 동기화되는 구조 자체가 없어서, 둘 다 완전히 죽은 설정이었다. 리뷰어에게 괜히 "이 앱이 왜 push 권한을 쓰지"라는 질문거리를 남길 이유가 없어서 둘 다 지웠다.

공지사항 화면의 v1.2 변경 내역도 다시 살펴보니 iCloud 백업/복원 기능, 로그북 월/주 단위 개편, 워치 단독 러닝 중 종료/음성 안내 문제 수정이 빠져있어서 추가했다.

