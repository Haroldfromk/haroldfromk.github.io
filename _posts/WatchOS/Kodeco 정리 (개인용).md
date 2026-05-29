## Watch Connectivity (Kodeco 정리)
Watch Connectivity는 iOS 앱과 watchOS 앱 사이에서 데이터를 주고받기 위한 Apple 전용 프레임워크다.

두 앱이 동시에 켜져 있으면 거의 실시간으로 통신하고, 한쪽이 꺼져 있어도 백그라운드에서 데이터를 전달해준다. 다만 Bluetooth 같은 시스템 리소스를 사용하기 때문에 배터리 소모가 크다는 점은 염두에 둬야 한다.

또한 시뮬레이터끼리는 통신이 제대로 안 되는 경우가 많아서 실기기 테스트가 권장된다.

### Connectivity 싱글톤 구조

```swift
import WatchConnectivity

final class Connectivity: NSObject, ObservableObject {
    static let shared = Connectivity()
    
    override private init() {
        super.init()
        #if !os(watchOS)
        guard WCSession.isSupported() else { return }
        #endif
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}
```

- `NSObject` 상속이 필수인 이유는 `WCSessionDelegate`가 `NSObjectProtocol`을 요구하기 때문이다. 즉 `NSObject`를 상속하지 않으면 델리게이트 채택 자체가 안 된다.
- `isSupported()` 체크를 `#if !os(watchOS)`로 감싸는 이유는 watchOS는 항상 `true`를 반환하기 때문에 iOS에서만 체크하면 된다.
- `static let shared`로 싱글톤을 만들고 `private init()`으로 외부에서 인스턴스를 직접 만들지 못하게 막는다.
- `Shared` 폴더에 파일을 두고 iOS / watchOS 양쪽 타겟 멤버십에 모두 추가해야 한다. 한쪽만 추가하면 빌드 에러난다.

---

### iOS 전용 델리게이트 메서드

```swift
extension Connectivity: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate() // 워치 기기 교체 시 재활성화
    }
    #endif
}
```

- `sessionDidBecomeInactive`, `sessionDidDeactivate`는 iOS 전용 메서드다. watchOS에는 존재하지 않아서 `#if os(iOS)`로 감싸지 않으면 watchOS 빌드에서 컴파일 에러가 난다.
- 사용자가 Apple Watch를 교체하면 기존 세션이 비활성화된다. `sessionDidDeactivate`에서 `activate()`를 다시 호출해줘야 새 워치와 연결된다.
- `activationDidCompleteWith`는 세션 활성화가 완료됐을 때 호출된다. 에러가 있으면 여기서 잡을 수 있다.

---

### 전송 전 사전 체크

```swift
guard WCSession.default.activationState == .activated else { return }

#if os(watchOS)
guard WCSession.default.isCompanionAppInstalled else { return }
#else
guard WCSession.default.isWatchAppInstalled else { return }
#endif
```

- 데이터를 보내기 전에 이 두 가지를 반드시 체크해야 한다.
- `activationState`가 `.activated`가 아니면 전송 자체가 불가능하다. 배터리가 방전되거나 워치를 교체하는 중일 때 `.activated`가 아닐 수 있다.
- iOS와 watchOS에서 companion 앱 확인 메서드 이름이 다르다. watchOS에서는 `isCompanionAppInstalled`, iOS에서는 `isWatchAppInstalled`다. 레거시 코드 때문에 Apple이 따로 만들었다고 한다.

---

### 3가지 전송 방식 선택 기준

```swift
// 최신값 하나만 필요할 때 (설정, 상태값)
try? WCSession.default.updateApplicationContext(userInfo)

// 순서대로 전부 받아야 할 때 (로그, 기록)
WCSession.default.transferUserInfo(userInfo)

// 양쪽 다 켜져 있을 때 즉시 전송
WCSession.default.sendMessage(userInfo, replyHandler: nil, errorHandler: nil)
```

- `updateApplicationContext` - 여러 번 호출하면 마지막 것만 전달된다. 중간에 보낸 데이터는 덮어써진다. 최신 상태 하나만 필요한 경우에 적합하다. (예: 다크모드 설정, 즐겨찾기 목록)
- `transferUserInfo` - 보낸 순서대로 유실 없이 전달된다. 상대 앱이 꺼져 있어도 나중에 깨어나면 밀린 데이터를 순서대로 다 받는다. (예: 운동 로그, 결제 내역)
- `sendMessage` - 양쪽 앱이 동시에 켜져 있을 때만 동작한다. 워치에서 iOS로 보내면 iOS 앱이 백그라운드에서 깨어나지만, iOS에서 워치로 보낼 때 워치 앱이 꺼져 있으면 메시지가 유실된다.

---

### 데이터 수신 델리게이트

```swift
// transferUserInfo 수신
func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { }

// updateApplicationContext 수신
func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { }

// sendMessage 수신 (reply 없을 때)
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { }

// sendMessage 수신 (reply 있을 때)
func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    replyHandler(["result": true]) // 반드시 호출해야 함
}
```

- 전송 방식마다 수신 델리게이트가 다르다. 보내는 방식이랑 받는 방식이 짝을 맞춰야 한다.
- `sendMessage`에서 `replyHandler`를 넘기면 수신 측에서 반드시 `replyHandler`를 호출해야 한다. 안 하면 OS가 에러를 발생시킨다.
- 델리게이트 메서드는 백그라운드 쓰레드에서 호출된다. UI 업데이트는 반드시 `DispatchQueue.main.async`로 감싸야 한다.

---

### 주의사항

- **시뮬레이터끼리는 통신이 거의 안 된다.** Kodeco 본문에서도 실기기 테스트를 권장한다.
- `replyHandler`를 쓸 생각이 없으면 반드시 `nil`을 넘겨야 한다. 클로저를 넘기면 OS가 응답을 기다리다가 에러를 발생시킨다.
- 딕셔너리 값으로 보낼 수 있는 타입은 Property List 타입만 가능하다. `GithubUser` 같은 커스텀 타입은 직접 못 보내고 JSON으로 직렬화해서 `Data` 타입으로 변환해야 한다.
- 배터리 소모가 크기 때문에 메시지는 가능하면 묶어서 한 번에 보내는 게 좋다.

---

### GitExplorer 적용 방향

- 즐겨찾기는 최신값만 필요 → `updateApplicationContext` 사용
- `[GithubUser]`를 `JSONEncoder`로 직렬화 → `Data`로 변환 → 딕셔너리에 담아서 전송
- Watch에서 받아서 `JSONDecoder`로 역직렬화 → `@Published` 프로퍼티 업데이트 → 뷰 자동 갱신

---

## Watch Connectivity (Medium 정리)

이 글은 Kodeco와 달리 iOS/watchOS를 **별도 클래스**로 분리해서 구현한다.
`sendMessage`를 메인으로 쓰되, 워치가 비활성 상태일 때는 `updateApplicationContext`로 폴백하는 구조가 특징이다.

---

### 전체 구조

- `iOSConnectivity` - iPhone 쪽 통신 담당
- `watchOSConnectivity` - Watch 쪽 통신 담당
- `AppState` - Watch 앱 전역 상태 관리 (UserDefaults 기반)

---

### iOSConnectivity

```swift
class iOSConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = iOSConnectivity()
    
    private var session = WCSession.default
    @Published var receivedData: [String: Any] = [:]
    
    private var isActivated = false
    private var pendingMessages: [[String: Any]] = [] // 세션 준비 전 메시지 임시 저장
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
}
```

- `pendingMessages`가 Kodeco 버전과의 차이점이다. 세션이 아직 활성화되기 전에 보내려는 메시지를 큐에 쌓아두고, 활성화 완료 시점에 한꺼번에 전송한다.
- `isActivated` 플래그로 세션 상태를 직접 추적한다.

---

### 세션 활성화 완료 시 큐 처리

```swift
func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated {
        isActivated = true
        for message in pendingMessages {
            send(message: message)
        }
        pendingMessages.removeAll()
    }
}
```

- 세션이 `.activated` 상태가 되면 쌓아뒀던 메시지를 순서대로 전송하고 큐를 비운다.

---

### sendMessage + ApplicationContext 폴백

```swift
private func send(message: [String: Any]) {
    if session.isReachable {
        session.sendMessage(message, replyHandler: nil) { error in
            print("전송 실패: \(error.localizedDescription)")
        }
    } else {
        try? session.updateApplicationContext(message)
    }
}
```

- `isReachable`이 `true`면 `sendMessage`로 즉시 전송, `false`면 `updateApplicationContext`로 폴백한다.
- 이 패턴 덕분에 워치가 꺼져 있어도 데이터가 유실되지 않는다.

---

### watchOSConnectivity

```swift
class watchOSConnectivity: NSObject, ObservableObject {
    @Published var receivedData: [String: Any] = [:]
    
    private var session: WCSession
    
    override init() {
        self.session = WCSession.default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
}
```

- iOS와 구조가 거의 동일하다.
- 수신한 데이터를 `UserDefaults`에 저장해서 앱을 껐다 켜도 유지되게 한다.

---

### 수신 처리 (Watch)

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    DispatchQueue.main.async {
        self.receivedData = message
        if let token = message["token"] as? String {
            UserDefaults.standard.set(token, forKey: "token")
        }
    }
}
```

- 수신 메서드에서 `DispatchQueue.main.async` 감싸는 거 필수. 델리게이트는 백그라운드 쓰레드에서 호출된다.
- `UserDefaults`에 저장하는 이유는 앱이 종료됐다가 다시 켜졌을 때도 데이터를 유지하기 위해서다.

---

### AppState (전역 상태 관리)

```swift
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isLogin: Bool = UserDefaults.standard.bool(forKey: "isLogin")
    @Published var token: String = UserDefaults.standard.string(forKey: "token") ?? ""
    
    private init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.isLogin = UserDefaults.standard.bool(forKey: "isLogin")
                self?.token = UserDefaults.standard.string(forKey: "token") ?? ""
            }
            .store(in: &cancellable)
    }
}
```

- `UserDefaults.didChangeNotification`을 구독해서 UserDefaults 값이 바뀌면 `@Published` 프로퍼티도 자동으로 업데이트된다.
- Combine의 `sink`로 변화를 감지하고 뷰에 반영하는 구조다.

---

### Kodeco vs Medium 비교

| | Kodeco | Medium |
|---|---|---|
| 클래스 구조 | iOS/watchOS 공용 싱글톤 1개 | iOS/watchOS 별도 클래스 |
| 전송 방식 | 상황에 맞게 선택 (Delivery enum) | sendMessage 기본 + ApplicationContext 폴백 |
| 세션 준비 전 처리 | 없음 | pendingMessages 큐 |
| 데이터 영속성 | 없음 | UserDefaults 저장 |