---
title: RunWay 1.5 진단 로그 보내기
writer: Harold
date: 2026-11-24 12:20:00 +0900
categories: [RunWay, SwiftUI]
tags: [SwiftUI, WatchConnectivity, OSLog, UIKit, watchOS]

toc: true
toc_sticky: true
published: true
---

> RunWay 1.1 부터는 Claude Code 와 함께 만든다. 코드와 글의 문장은 거기서 나오고, 방향을 정하고 실기기에서 확인해 틀린 걸 찾아오는 건 직접 한다. 그래도 과정을 글로 남기는 건 업데이트를 AI 에게 맡기고 끝내지 않으려는 것이다. 거기서 배울 점을 찾아 적어 두고 나중에 공부하려고 한다.
{: .prompt-info }

지인의 기기에 RunWay 러닝이 갑자기 끝나 버린 기록이 9월부터 일곱 건 남아 있다. 내 기기에서는 한 번도 재현되지 않는다. 원인 후보는 남아 있는데, 어느 쪽인지 가르려면 그 순간의 로그가 필요하다.

문제는 그 로그를 받아 올 길이 없다는 것이다. 지금까지는 기기를 Mac 에 연결해서 꺼냈는데, 지인의 워치를 팅길 때마다 빌려 올 수는 없다. 그래서 1.5 에 "진단 로그 보내기"를 넣었다. 설정에서 한 줄을 누르면 아이폰과 워치의 기록이 파일 하나로 합쳐지고, 사용자가 원하는 방법으로 직접 보내 준다.

이 글은 그걸 만든 과정이다. 바꾼 것은 세 가지다.

| 자리 | 한 일 |
|---|---|
| 로그 | 배포판에서도 파일에 남기고, 200KB 를 넘으면 앞쪽을 버린다 |
| 워치에서 아이폰으로 | 워치 기록 파일을 `transferFile` 로 아이폰에 넘긴다 |
| 설정 화면 | 안내 알림을 거쳐 공유 시트로 합친 파일을 내보낸다 |

---

## 서버로 모으지 않은 이유

로그를 받는 가장 흔한 방법은 앱이 알아서 서버로 올리는 것이다. 사용자는 아무것도 안 해도 되고 개발자는 전부 볼 수 있다. 이번에는 그 길을 고르지 않았다.

RunWay 는 개인정보 처리방침에 데이터가 기기 밖으로 나가지 않는다고 적어 둔 앱이다. 러닝 기록은 기기와 사용자의 iCloud 에만 있고, 내 서버는 없다. 로그 몇 줄을 받자고 그 약속을 바꾸면 처리방침, App Store 의 개인정보 표시, 세 언어로 된 웹 문서를 전부 고쳐야 하고, 무엇보다 "밖으로 안 나간다"는 말이 더는 참이 아니게 된다.

그래서 정한 원칙은 하나다. **앱은 파일을 만들기만 하고, 보내는 건 사용자가 한다.** 사용자가 누르지 않으면 아무것도 나가지 않는다. 받는 사람도 사용자가 고른다.

메뉴를 누구에게 보여줄지도 정해야 했다. 숨겨 두고 특정 동작을 해야 나오게 하는 방법이 있었지만, 지인에게 "설정에서 로고를 일곱 번 누르세요"라고 설명하는 것보다 그냥 보이는 줄 하나가 낫다고 봤다. 모두에게 보이게 했다.

---

## 배포판에서도 남는 파일 로그

RunWay 에는 조용히 실패하는 자리마다 한 줄씩 남기는 `RemoteStopLogger` 가 이미 있다. 같은 줄을 두 군데에 쓴다. 하나는 시스템 로그이고, 하나는 앱 폴더 안의 파일이다. 파일 쪽은 지금까지 개발용 빌드에서만 켜져 있었다.

---

### 시스템 로그와 파일 로그는 무엇이 다른가

시스템 로그는 iOS 와 watchOS 가 관리하는 공용 기록장이다. 앱이 [`Logger`](https://developer.apple.com/documentation/os/logger){:target="_blank"}로 한 줄을 쓰면 시스템이 받아서 보관한다. 빠르고 용량 걱정도 시스템이 해 주지만, 꺼내려면 기기를 Mac 에 연결해야 한다. 앱이 [`OSLogStore`](https://developer.apple.com/documentation/oslog/oslogstore){:target="_blank"}로 다시 읽어 올 수 있는 건 지금 실행 중에 쓴 줄뿐이라, 팅긴 뒤 다시 켠 앱은 그 전 기록을 못 읽는다.

파일 로그는 앱이 자기 폴더에 직접 쓰는 메모장이다. 느리고 용량도 앱이 챙겨야 하지만, 앱이 언제든 다시 열어서 읽을 수 있다.

아파트에 빗대면 시스템 로그는 관리사무소의 CCTV 이고 파일 로그는 내 집 안의 일기장이다. CCTV 는 관리사무소에 찾아가야 볼 수 있다. 사용자가 직접 보내 주는 기능을 만들려면 일기장이 필요하다.

---

### 파일이 끝없이 커지지 않게 하는 상한

개발용에서는 파일이 얼마나 크든 상관없었다. 배포판에서는 다르다. 러닝마다 줄이 쌓이는데 지우는 사람이 없다. 그래서 200KB 를 넘으면 오래된 앞쪽을 버리게 했다.

```swift
// RunWay/Debug/RemoteStopLogger.swift
static let maxTraceBytes = 200_000

fileQueue.async {
    guard let url = traceURL, let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.write(contentsOf: data)
        try? handle.close()
        guard Int(size) + data.count > maxTraceBytes, let all = try? Data(contentsOf: url) else { return }
        try? trimmed(all, limit: maxTraceBytes).write(to: url, options: .atomic)
    } else {
        try? data.write(to: url)
    }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    var target = url
    try? target.setResourceValues(values)
}
```

#### FileHandle로 파일 끝에 한 줄 붙이고 백업에서 빼기

1. [`DispatchQueue`](https://developer.apple.com/documentation/dispatch/dispatchqueue){:target="_blank"}는 일을 줄 세워 처리하는 대기열이다. `fileQueue` 는 한 번에 하나씩만 처리하는 직렬 큐라서, 여러 곳에서 동시에 로그를 남겨도 줄이 섞이지 않는다. `async` 는 일을 맡기고 기다리지 않는다는 뜻이다
2. [`FileHandle(forWritingTo:)`](https://developer.apple.com/documentation/foundation/filehandle/init%28forwritingto%3A%29){:target="_blank"}는 이미 있는 파일을 쓰기용으로 연다. 파일이 없으면 오류를 던져서 `try?` 가 nil 이 되고, 그때는 `else` 로 가서 새로 만든다
3. [`seekToEnd()`](https://developer.apple.com/documentation/foundation/filehandle/seektoend%28%29){:target="_blank"}는 쓰는 위치를 파일 맨 끝으로 옮기고 그 위치를 돌려준다. 맨 끝의 위치가 곧 파일 크기라서, 크기를 따로 묻지 않고 이 값을 쓴다
4. [`write(contentsOf:)`](https://developer.apple.com/documentation/foundation/filehandle/write%28contentsof%3A%29){:target="_blank"}로 한 줄을 붙이고 [`close()`](https://developer.apple.com/documentation/foundation/filehandle/close%28%29){:target="_blank"}로 닫는다
5. 붙인 뒤 크기가 상한을 넘었을 때만 파일 전체를 읽어 줄이고 다시 쓴다. `.atomic` 은 임시 파일에 다 쓴 다음 한 번에 바꿔치기하는 옵션이다. 쓰다가 앱이 죽어도 반쯤 쓰인 파일이 남지 않는다
6. [`isExcludedFromBackup`](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup){:target="_blank"}을 `true` 로 두면 이 파일은 iCloud 백업에 들어가지 않는다. [`setResourceValues(_:)`](https://developer.apple.com/documentation/foundation/url/setresourcevalues%28%5F%3A%29){:target="_blank"}가 그 값을 파일에 적는다

백업 제외 표시는 파일을 통째로 다시 쓰면 사라진다. 그래서 새로 만들었을 때만이 아니라 줄여서 다시 썼을 때도 다시 건다.

줄이는 함수는 따로 뺐다. 파일을 건드리지 않고 `Data` 만 받아서 `Data` 를 돌려주니 테스트하기 쉽다.

```swift
static func trimmed(_ data: Data, limit: Int) -> Data {
    guard data.count > limit else { return data }
    let tail = data.suffix(limit / 2)
    guard let newline = tail.firstIndex(of: 0x0A) else { return Data(tail) }
    return Data(tail[tail.index(after: newline)...])
}
```

#### suffix로 뒤쪽 절반만 남기기

[`suffix(_:)`](https://developer.apple.com/documentation/swift/bidirectionalcollection/suffix%28%5F%3A%29){:target="_blank"}는 뒤에서부터 정해 준 개수만큼을 돌려준다. 상한이 200KB 면 뒤쪽 100KB 만 남긴다. 상한에 딱 맞추지 않고 절반으로 줄이는 건, 딱 맞추면 다음 줄에서 또 넘어서 줄마다 파일 전체를 다시 쓰게 되기 때문이다.

그대로 자르면 첫 줄이 중간에서 끊긴다. `0x0A` 는 줄바꿈 문자의 번호다. [`firstIndex(of:)`](https://developer.apple.com/documentation/swift/collection/firstindex%28of%3A%29){:target="_blank"}로 첫 줄바꿈을 찾아 그 다음 칸부터 남기면 온전한 줄로 시작한다.

주의할 점이 하나 있다. `suffix` 가 돌려준 조각은 번호가 0 부터 다시 매겨지지 않고 원래 `Data` 의 번호를 그대로 쓴다. 그래서 `tail[0]` 처럼 숫자로 직접 집지 않고 `firstIndex` 가 준 위치와 `index(after:)` 로만 움직였다.

이 함수에는 테스트를 세 개 붙였다. 상한 이하면 그대로 두는지, 넘으면 줄 경계에서 뒤쪽만 남기는지, 줄바꿈이 하나도 없어도 줄어드는지다.

---

## 워치 기록을 아이폰으로 넘기는 길

팅기는 건 워치다. 그런데 워치에는 공유 시트도 메일 앱도 없다. 워치에 쌓인 기록은 아이폰으로 먼저 옮겨야 사용자가 보낼 수 있다.

---

### transferFile이란?

워치와 아이폰이 데이터를 주고받는 틀이 WatchConnectivity 이고, 그 안에 보내는 방법이 여러 개 있다. RunWay 는 지금까지 두 가지를 썼다. 지금 당장 닿아야 하는 신호는 `sendMessage`, 나중에라도 꼭 닿아야 하는 러닝 기록은 `transferUserInfo` 다.

[`transferFile(_:metadata:)`](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile%28%5F%3Ametadata%3A%29){:target="_blank"}은 세 번째 방법이고, 파일을 통째로 보낸다. 택배에 빗대면 쉽다. 상자(파일)에 송장(metadata)을 붙여 맡기면 시스템이 알아서 배달한다. 상대 앱이 꺼져 있어도, 두 기기가 잠깐 떨어져 있어도 대기열에 남아 있다가 연결되면 간다. 대신 언제 도착할지는 정할 수 없다.

로그는 급하지 않고 크기가 있으니 이 방법이 맞다. `transferUserInfo` 에 문자열로 실어 보낼 수도 있었지만, 200KB 짜리 글을 dictionary 에 넣는 것보다 파일로 보내는 쪽이 원래 용도에 맞는다.

```swift
// RunWayWatch Watch App/Services/WatchConnectivityService+watchOS.swift
nonisolated static func sendDiagnosticLog() {
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    guard let url = RemoteStopLogger.snapshotTrace() else { return }
    for transfer in session.outstandingFileTransfers where transfer.file.metadata?["type"] as? String == "diagnosticLog" {
        transfer.cancel()
    }
    session.transferFile(url, metadata: ["type": "diagnosticLog"])
}
```

#### transferFile로 워치 기록 파일 보내기

1. [`WCSession.default`](https://developer.apple.com/documentation/watchconnectivity/wcsession/default){:target="_blank"}는 앱에 하나뿐인 연결 창구다. [`activationState`](https://developer.apple.com/documentation/watchconnectivity/wcsession/activationstate){:target="_blank"}가 `.activated` 가 아니면 아직 창구가 안 열린 것이라 그냥 돌아간다
2. `snapshotTrace()` 는 직접 만든 함수다. 기록 파일을 임시 폴더로 복사해 그 주소를 준다. 로그는 계속 쓰이는 파일이라, 쓰는 도중의 파일을 그대로 맡기지 않으려고 복사본을 보낸다
3. [`outstandingFileTransfers`](https://developer.apple.com/documentation/watchconnectivity/wcsession/outstandingfiletransfers){:target="_blank"}는 맡겼지만 아직 배달이 안 끝난 전송 목록이다. 그중 송장에 `diagnosticLog` 라고 적힌 것을 [`cancel()`](https://developer.apple.com/documentation/watchconnectivity/wcsessionfiletransfer/cancel%28%29){:target="_blank"}로 취소한다. 매번 전체 기록을 보내니 옛 상자가 대기열에 남아 있을 이유가 없다
4. `transferFile` 의 첫 인자는 보낼 파일의 주소, `metadata` 는 받는 쪽이 무슨 파일인지 알아볼 수 있게 붙이는 dictionary 다

보내는 때는 두 번이다. 워치 앱이 켜져서 연결이 열렸을 때, 그리고 러닝을 마무리한 직후다. 팅긴 그 순간에는 보낼 수 없다. 앱이 죽었기 때문이다. 대신 다음에 워치 앱을 열면 그때 간다. 설정의 안내 알림에 "워치에서 RunWay 를 한 번 열어야 최신 기록이 들어간다"는 문장을 넣은 이유다.

아이폰은 받은 파일을 자기 폴더로 옮긴다.

```swift
// RunWay/Services/WatchConnectivityService+iOS.swift
nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
    guard file.metadata?["type"] as? String == "diagnosticLog",
          var destination = DiagnosticLogExporter.watchTraceURL else { return }
    try? FileManager.default.removeItem(at: destination)
    guard (try? FileManager.default.copyItem(at: file.fileURL, to: destination)) != nil else { return }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? destination.setResourceValues(values)
}
```

#### session didReceive file로 받은 파일 옮기기

[`session(_:didReceive:)`](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate/session%28%5F%3Adidreceive%3A%29){:target="_blank"}는 파일이 도착하면 시스템이 불러 주는 함수다. [`WCSessionFile`](https://developer.apple.com/documentation/watchconnectivity/wcsessionfile){:target="_blank"}에는 받은 파일의 임시 주소(`fileURL`)와 보낸 쪽이 붙인 `metadata` 가 들어 있다.

여기서 꼭 지켜야 할 것은 **이 함수 안에서 바로 옮기는 것**이다. 시스템은 이 함수가 끝나면 받은 파일을 지운다. 나중에 옮기려고 주소만 적어 두면 그때는 파일이 없다. 그래서 [`copyItem(at:to:)`](https://developer.apple.com/documentation/foundation/filemanager/copyitem%28at%3Ato%3A%29){:target="_blank"}를 그 자리에서 부른다. 같은 이름의 파일이 있으면 복사가 실패하니 [`removeItem(at:)`](https://developer.apple.com/documentation/foundation/filemanager/removeitem%28at%3A%29){:target="_blank"}으로 먼저 지운다.

---

## 두 기록을 합친 파일

사용자에게 파일 두 개를 보내 달라고 하면 하나만 올 때가 생긴다. 그래서 아이폰 기록과 워치 기록을 파일 하나로 합친다. 맨 위에는 기기 정보를 한 줄 적는다. 증상이 OS 버전에 따라 갈리는지 보려는 것이다.

```swift
// RunWay/Services/DiagnosticLogExporter.swift
static func merged(header: String, phone: String?, watch: String?) -> String? {
    let phone = phone ?? ""
    let watch = watch ?? ""
    guard !phone.isEmpty || !watch.isEmpty else { return nil }
    return "\(header)\n=== iPhone ===\n\(phone.isEmpty ? "(로그 없음)\n" : phone)=== Apple Watch ===\n\(watch.isEmpty ? "(워치 로그 없음)\n" : watch)"
}

static func header(now: Date) -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    var system = utsname()
    uname(&system)
    let model = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    return "RunWay \(version) (\(build)) / iOS \(ProcessInfo.processInfo.operatingSystemVersionString) / \(model) / \(ISO8601DateFormatter().string(from: now))"
}
```

#### Bundle과 uname으로 앱 버전과 기기 모델 읽기

- [`Bundle.main.infoDictionary`](https://developer.apple.com/documentation/foundation/bundle/infodictionary){:target="_blank"}는 앱의 `Info.plist` 내용을 dictionary 로 준다. `CFBundleShortVersionString` 이 사용자에게 보이는 버전(1.4.1), `CFBundleVersion` 이 빌드 번호(10)다
- [`operatingSystemVersionString`](https://developer.apple.com/documentation/foundation/processinfo/operatingsystemversionstring){:target="_blank"}은 OS 버전을 사람이 읽는 글로 준다
- `uname` 은 Apple 프레임워크가 아니라 Unix 에서 물려받은 C 함수다. `utsname` 이라는 빈 표를 건네면 시스템 정보를 채워 준다. 그중 `machine` 칸에 `iPhone17,1` 같은 모델 식별자가 들어 있다. C 의 글자 배열이라 Swift 의 `String` 으로 바꾸려면 [`withUnsafeBytes(of:_:)`](https://developer.apple.com/documentation/swift/withunsafebytes%28of%3A%5F%3A%29-3ywhh){:target="_blank"}로 바이트를 꺼내, 끝을 알리는 0 이 나오기 전까지만 읽는다
- [`ISO8601DateFormatter`](https://developer.apple.com/documentation/foundation/iso8601dateformatter){:target="_blank"}는 시각을 `2026-11-24T03:16:13Z` 같은 국제 표준 모양으로 적는다. 받는 사람의 시간대와 상관없이 같은 순간을 가리킨다

`merged` 는 글자만 받아서 글자를 돌려준다. 파일도 시계도 건드리지 않아서 테스트가 쉽다. 두 기록이 순서대로 붙는지, 워치 기록이 없으면 없다고 적는지, 둘 다 없으면 nil 인지 세 개를 붙였다. 둘 다 없을 때 nil 을 주는 건 화면이 "보낼 로그가 없습니다"를 띄울 수 있게 하려는 것이다.

구역 제목(`=== iPhone ===`)과 "(로그 없음)"은 번역하지 않았다. 이 파일을 읽는 사람은 나다.

---

## 설정 화면에서 공유 시트까지

화면 흐름은 줄 하나, 알림 하나, 시트 하나다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-24-RunningProject-61/runway-diagnostic-log-settings.png)

설정 화면이다. 맨 아래 청진기 아이콘이 붙은 "진단 로그 보내기"가 새로 생긴 줄이다.

---

### 공유 시트란?

공유 시트는 사진 앱에서 공유 버튼을 누르면 아래에서 올라오는 그 화면이다. 메시지, 메일, AirDrop, 파일에 저장 같은 선택지가 나온다. 앱은 "이걸 내보내고 싶다"고 넘기기만 하고, 어디로 보낼지는 사용자가 고른다.

이번 기능에 이게 맞는 이유가 여기 있다. 앱은 누구에게 가는지 모른다. 받는 주소가 코드 어디에도 없다. "직접 보낼 때만 전달된다"는 말을 구조가 보장한다.

SwiftUI 에는 공유 시트를 여는 [`ShareLink`](https://developer.apple.com/documentation/swiftui/sharelink){:target="_blank"}가 있다. 그런데 `ShareLink` 는 누르자마자 시트가 뜬다. 그 사이에 "이 파일에 무엇이 들어 있는지" 알려 주는 알림을 끼울 수가 없다. 그래서 UIKit 의 공유 시트를 직접 감쌌다.

```swift
// RunWay/Views/Settings/ActivityShareSheet.swift
struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

#### UIViewControllerRepresentable로 UIKit 공유 시트 감싸기

[`UIViewControllerRepresentable`](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable){:target="_blank"}은 UIKit 의 화면을 SwiftUI 안에서 쓸 수 있게 해 주는 어댑터다. 두 함수를 채워야 한다. [`makeUIViewController(context:)`](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable/makeuiviewcontroller%28context%3A%29){:target="_blank"}는 화면을 처음 만들 때 한 번 불리고, [`updateUIViewController(_:context:)`](https://developer.apple.com/documentation/swiftui/uiviewcontrollerrepresentable/updateuiviewcontroller%28%5F%3Acontext%3A%29){:target="_blank"}는 SwiftUI 쪽 값이 바뀔 때 불린다. 여기서는 한 번 띄우고 나면 바꿀 게 없어서 비워 뒀다.

[`UIActivityViewController`](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller){:target="_blank"}가 공유 시트 그 자체다. `activityItems` 에는 내보낼 것을 배열로 넣는다. 파일 주소를 넣으면 시스템이 파일로 다룬다. `applicationActivities` 는 앱이 직접 만든 선택지를 추가하는 자리인데 쓰지 않아서 nil 이다.

설정 화면은 이걸 이렇게 잇는다.

```swift
// RunWay/Views/Settings/SettingsView.swift
Button {
    isAskingToSendLog = true
} label: {
    SettingsRow(icon: "stethoscope", title: "진단 로그 보내기")
}

// ...

.alert("진단 로그 보내기", isPresented: $isAskingToSendLog) {
    Button("취소", role: .cancel) {}
    Button("보내기") {
        if let url = DiagnosticLogExporter.export() {
            logToShare = DiagnosticLogFile(url: url)
        } else {
            hasNoLogToSend = true
        }
    }
} message: {
    Text("...")   // 무엇이 들어 있고 무엇이 안 들어 있는지
}
.alert("보낼 로그가 없습니다", isPresented: $hasNoLogToSend) {
    Button("확인", role: .cancel) {}
}
.sheet(item: $logToShare) { file in
    ActivityShareSheet(url: file.url)
}
```

#### alert와 sheet로 안내 뒤에 공유 시트 띄우기

1. 줄을 누르면 `isAskingToSendLog` 가 `true` 가 된다. [`alert(_:isPresented:actions:message:)`](https://developer.apple.com/documentation/swiftui/view/alert%28%5F%3Aispresented%3Aactions%3Amessage%3A%29-8dvt8){:target="_blank"}는 이 값이 `true` 인 동안 알림을 띄우고, 닫히면 스스로 `false` 로 되돌린다
2. "보내기"를 누르면 그때 파일을 만든다. 알림을 띄우기 전에 미리 만들지 않는 건, 취소하면 쓸모없는 파일이 되기 때문이다
3. 파일이 만들어지면 `logToShare` 에 넣는다. [`sheet(item:onDismiss:content:)`](https://developer.apple.com/documentation/swiftui/view/sheet%28item%3Aondismiss%3Acontent%3A%29){:target="_blank"}는 이 값이 nil 이 아니게 되는 순간 시트를 띄우고, 그 값을 안쪽에 건네준다. 시트가 닫히면 다시 nil 이 된다
4. 만들 게 없으면 두 번째 알림을 띄운다

`sheet(item:)` 에 넣는 값은 [`Identifiable`](https://developer.apple.com/documentation/swift/identifiable){:target="_blank"}이어야 한다. 서로 다른 값인지 구분할 `id` 가 있어야 한다는 뜻이다. `URL` 은 그렇지 않아서 `DiagnosticLogFile` 이라는 작은 struct 로 감쌌다.

`isPresented` 로 "띄울지"만 따로 두고 파일 주소를 다른 변수에 두는 방법도 있다. 그러면 "띄우라고 했는데 주소가 아직 없는" 순간이 생길 수 있다. `item` 하나로 묶으면 주소가 있을 때만 뜬다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-24-RunningProject-61/runway-diagnostic-log-alert.png)

줄을 누르면 나오는 안내 알림이다. 무엇이 들어 있는지(러닝 시작과 종료 시각, 세션 상태, 오류 코드, 버전, 기기 모델)와 무엇이 안 들어 있는지(위치, 심박수)를 적었다. 아래 문단은 워치 기록이 언제 넘어오는지다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-11-24-RunningProject-61/runway-diagnostic-log-share.png)

"보내기"를 누른 뒤의 공유 시트다. 맨 위에 `runway-log` 라는 텍스트 문서가 잡혀 있다. 시뮬레이터라서 선택지가 몇 개 없고, 실기기에서는 메시지와 메일, AirDrop 이 여기에 나온다.

---

## 시뮬레이터에서 확인한 것

이 기능은 단위 테스트만으로는 다 확인할 수 없다. 줄을 눌렀을 때 알림이 뜨는지, 그 뒤에 시트가 뜨는지는 화면을 눌러 봐야 안다. 그래서 RunWay 프로젝트와 상관없는 임시 프로젝트를 하나 만들어, 설치된 RunWay 를 대신 눌러 보는 UI 테스트를 돌렸다. `XCUIApplication(bundleIdentifier:)` 에 앱의 번들 ID 를 주면 다른 프로젝트의 앱도 조작할 수 있다.

두 번 돌렸다.

| 상태 | 한 일 | 결과 |
|---|---|---|
| 기록 파일 없음 | 설정 줄, 안내 알림의 "보내기" | "보낼 로그가 없습니다" 알림 |
| 아이폰과 워치 기록 파일을 앱 폴더에 넣어 둠 | 같은 순서 | 공유 시트, `runway-log` 241바이트 |

두 번째에서 만들어진 파일은 이렇다. 기록 세 줄은 시험용으로 넣은 것이다.

```
RunWay 1.4.1 (10) / iOS Version 26.5 (Build 23F77) / arm64 / 2026-11-24T03:16:13Z
=== iPhone ===
2026-11-24T03:00:00Z [phone] probe line 1
2026-11-24T03:00:01Z [phone] probe line 2
=== Apple Watch ===
2026-11-24T03:00:02Z [watch] probe line
```

여기서 두 가지가 눈에 띈다. 기기 모델이 `arm64` 로 나온 건 시뮬레이터라서다. 시뮬레이터에서 `uname` 은 Mac 의 CPU 종류를 준다. 실기기에서는 모델 식별자가 나와야 하는데 아직 확인 못 했다. 그리고 `iOS Version 26.5` 는 "iOS" 를 내가 붙였는데 시스템이 준 글에도 "Version" 이 붙어 있어서 말이 겹쳤다. 그래서 `header` 에서 내가 붙인 "iOS " 를 뺐다. 고친 뒤에는 그 자리에 `Version 26.5 (Build 23F77)` 만 남는다.

---

## 아직 확인 못 한 것

시뮬레이터로 본 것은 아이폰 쪽 화면과 파일을 합치는 부분까지다. 나머지는 실기기가 있어야 한다.

- 워치에서 아이폰으로 파일이 실제로 넘어오는지. 워치 빌드는 통과했고 코드는 위에 적은 대로지만, 시뮬레이터에서는 `transferFile` 이 도착하는 것까지 보지 못했다. 위 표의 워치 기록은 손으로 넣은 파일이다
- 실기기 공유 시트에서 메시지와 메일로 보냈을 때 파일이 첨부로 잘 붙는지
- 200KB 상한이 실제 러닝 몇 번 분량인지. 러닝 한 번에 몇 줄이 쌓이는지 아직 세지 않았다
- 영어와 일본어 문구. 번역은 넣었지만 원어민이 읽기에 자연스러운지는 보지 못했다

그리고 이 기능은 원인을 찾는 도구이지 원인이 아니다. 워치가 왜 팅기는지는 여전히 모른다.

---

## 참고자료

- [Transferring data with Watch Connectivity (Apple)](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity){:target="_blank"}
- [Generating log messages from your code (Apple)](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code){:target="_blank"}
