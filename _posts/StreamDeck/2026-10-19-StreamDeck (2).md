---
title: StreamDeck (2) 맥에 설치된 앱 목록과 아이콘을 보내고, 눌러서 실행하기
writer: Harold
date: 2026-10-19 18:10:00 +0900
last_modified_at: 2026-10-20 16:47:00 +0900
categories: [StreamDeck]
tags: [NSWorkspace, AppKit, Bundle]

toc: true
toc_sticky: true
published: true
---

아이패드에서 빈 칸을 누르면 맥에 설치된 앱 목록이 아이콘과 함께 떠야 하고, 하나 고르면 그 칸이 그 앱 버튼이 된다. 버튼을 누르면 맥에서 앱이 열린다. 이번 글은 맥이 앱 목록을 모으고, 아이콘을 그림으로 바꿔 보내고, 눌렸을 때 앱을 여는 부분이다.

---

## 앱 목록을 모으는 폴더들

맥에서 앱은 결국 `.app`으로 끝나는 폴더다. 그래서 앱이 들어 있는 폴더 몇 곳을 훑어서 `.app`을 찾고, `Bundle(url:)`로 열어 고유 ID(bundle identifier)를 읽었다. 버튼에는 앱 이름이 아니라 이 고유 ID를 저장한다. 이름은 언어 설정에 따라 바뀌지만 고유 ID는 안 바뀐다.

---

### 앱 번들과 번들 ID란?

맥의 앱은 파일 하나처럼 보이지만 실제로는 정해진 모양을 갖춘 폴더다. 이런 폴더를 번들이라고 부른다. Finder에서 Safari를 오른쪽 클릭하고 "패키지 내용 보기"를 누르면 안이 열린다.

![Safari.app은 겉보기엔 앱 하나지만 안에는 Contents 폴더가 있고, 그 안에 번들 ID가 적힌 Info.plist, 실제로 실행되는 프로그램, 아이콘 같은 그림이 들어 있다](/assets/images/upload/touchdeck-app-bundle.png)

안에는 실제로 실행되는 프로그램, 아이콘 같은 그림, 그리고 앱 정보를 적은 `Info.plist`가 들어 있다. `Info.plist`에 적힌 번들 ID는 앱마다 하나뿐인 이름표다. 회사 도메인을 거꾸로 쓰는 규칙(`com.apple.Safari`)이라 다른 회사 앱과 겹치지 않는다. `Bundle(url:)`은 이 폴더를 열어서 `Info.plist`를 읽어 주는 도구다.

---

### 앱이 들어 있는 폴더 다섯 곳과 Finder

앱을 찾을 폴더는 다섯 곳으로 정했다.

```swift
// AppCatalog.swift (맥)
static var folders: [URL] {
    [
        URL(filePath: "/Applications"),
        URL(filePath: "/Applications/Utilities"),
        URL(filePath: "/System/Applications"),
        URL(filePath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications"),
    ]
}
```

#### URL과 FileManager로 폴더 위치 만들기

맥 앱에서 파일과 폴더는 대부분 URL로 다룬다. [`URL(filePath:)`](https://developer.apple.com/documentation/foundation/url/init%28filepath:directoryhint:relativeto:%29){:target="_blank"}는 경로 글자로 파일 URL을 만들고, [`appending(path:)`](https://developer.apple.com/documentation/foundation/url/appending%28path:directoryhint:%29){:target="_blank"}는 URL 뒤에 경로를 이어 붙인 새 URL을 돌려준다. 파일과 폴더를 읽고 만드는 도구가 [`FileManager`](https://developer.apple.com/documentation/foundation/filemanager){:target="_blank"}이고, 보통 `FileManager.default` 하나를 쓴다. 그 [`homeDirectoryForCurrentUser`](https://developer.apple.com/documentation/foundation/filemanager/homedirectoryforcurrentuser){:target="_blank"}가 지금 사용자의 홈 폴더(`/Users/이름`)다.

`/System/Applications`는 메모, 캘린더, 음악처럼 macOS에 들어 있는 앱 자리고, 직접 설치한 앱은 `/Applications`에 있다.

처음엔 이 다섯 곳이면 다 될 줄 알았다. 그런데 아이패드에서 Finder 버튼을 추가하려고 하니 목록에 Finder가 없었다. Finder는 이 폴더들 어디에도 없고 `/System/Library/CoreServices/Finder.app`에 따로 있다. 매일 쓰는 앱이라 빠지면 안 돼서, 먼저 "목록에 Finder가 있어야 한다"는 테스트를 만들고 실패하는 걸 본 다음 따로 넣었다.

```swift
// AppCatalogTests.swift (맥)
@Test func scanIncludesFinder() {
    #expect(AppCatalog.scan().contains { $0.bundleId == "com.apple.finder" })
}
```

#### Swift Testing의 Test와 expect

테스트는 Swift Testing으로 썼다. [`@Test`](https://developer.apple.com/documentation/testing/test%28%5F:%5F:%29){:target="_blank"}를 붙인 함수 하나가 테스트 하나가 되고, [`#expect(_:_:)`](https://developer.apple.com/documentation/testing/expect%28%5F:%5F:sourcelocation:%29){:target="_blank"}는 안의 조건이 참인지 확인한다. 거짓이면 그 테스트가 실패로 기록되고, 어떤 값 때문에 틀렸는지도 같이 보여 준다.

```swift
// AppCatalog.swift (맥)
/// 폴더 목록 밖에 있지만 자주 쓰는 앱. Finder는 /System/Library/CoreServices에 있다.
static let extraApps = [URL(filePath: "/System/Library/CoreServices/Finder.app")]

static func scan() -> [AppInfo] {
    var seen = Set<String>()
    var apps: [AppInfo] = []
    let found = folders.flatMap { folder in
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "app" }
    }
    for url in found + extraApps {
        guard let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier,
              seen.insert(bundleId).inserted else { continue }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        apps.append(AppInfo(name: name, bundleId: bundleId, icon: iconPNG(for: url)?.base64EncodedString() ?? ""))
    }
    return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}
```

#### 폴더를 훑어 앱 정보 모으기

`scan()`은 이 순서로 돈다.

1. [`contentsOfDirectory(at:includingPropertiesForKeys:options:)`](https://developer.apple.com/documentation/foundation/filemanager/contentsofdirectory%28at:includingpropertiesforkeys:options:%29){:target="_blank"}로 폴더 바로 아래 항목들의 URL을 받는다. 하위 폴더 안까지는 들어가지 않는다.
2. [`pathExtension`](https://developer.apple.com/documentation/foundation/url/pathextension){:target="_blank"}(점을 뺀 확장자)이 `app`인 것만 남긴다.
3. [`Bundle(url:)`](https://developer.apple.com/documentation/foundation/bundle/init%28url:%29-3n9rf){:target="_blank"}로 번들을 열고 [`bundleIdentifier`](https://developer.apple.com/documentation/foundation/bundle/bundleidentifier){:target="_blank"}로 번들 ID를 읽는다. 번들이 아니면 nil이라 `guard let`에서 걸러진다.
4. [`displayName(atPath:)`](https://developer.apple.com/documentation/foundation/filemanager/displayname%28atpath:%29){:target="_blank"}로 Finder에 보이는 이름을 받는다. 맥 언어 설정에 맞춘 이름(메모)이 온다.
5. 아이콘 PNG는 [`base64EncodedString(options:)`](https://developer.apple.com/documentation/foundation/data/base64encodedstring%28options:%29){:target="_blank"}로 글자로 바꿔 담는다.
6. 마지막에 [`localizedStandardCompare(_:)`](https://developer.apple.com/documentation/foundation/nsstring/localizedstandardcompare%28%5F:%29){:target="_blank"}로 정렬한다. Finder처럼 숫자는 크기대로(2가 10보다 앞), 언어 설정에 맞는 순서로 비교한다.

`Set.insert(_:)`는 넣은 결과를 `(inserted: Bool, memberAfterInsert:)`로 돌려준다. 이미 있던 값이면 `inserted`가 false라서, 처음 본 번들 ID일 때만 목록에 넣는 데 썼다.

`seen`은 같은 앱이 두 폴더에 있을 때 한 번만 넣으려고 둔 것이다. 이름은 `displayName(atPath:)`로 꺼내서 맥 언어 설정에 맞는 이름(예: Notes 대신 메모)이 나오게 했다.

---

## 아이콘을 그림 파일로, 그리고 바로가기 화살표

아이콘은 `NSWorkspace.shared.icon(forFile:)`로 꺼낸다. 이건 맥 화면에 그리기 위한 그림 객체라서 그대로는 아이패드로 못 보낸다. 96×96 크기의 빈 그림판(`NSBitmapImageRep`)을 만들고 거기에 아이콘을 그린 다음 PNG로 바꿨다. 아이패드 버튼에서 아이콘이 48pt쯤으로 그려지고, 아이패드 화면이 1pt에 2픽셀이라 96픽셀이면 선명하다.

```swift
// AppCatalog.swift (맥)
static func iconPNG(for appURL: URL) -> Data? {
    // /Applications/Safari.app은 시스템 폴더를 가리키는 링크라 그대로 쓰면 바로가기 화살표가 붙는다
    let icon = NSWorkspace.shared.icon(forFile: appURL.resolvingSymlinksInPath().path)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: iconSize, pixelsHigh: iconSize,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}
```

#### NSBitmapImageRep으로 아이콘을 PNG로 만들기

아이콘은 다섯 단계로 PNG가 된다.

1. [`NSWorkspace`](https://developer.apple.com/documentation/appkit/nsworkspace){:target="_blank"}의 [`icon(forFile:)`](https://developer.apple.com/documentation/appkit/nsworkspace/icon%28forfile:%29){:target="_blank"}으로 앱의 Finder 아이콘을 `NSImage`로 받는다. `NSWorkspace`는 앱을 열고 아이콘을 꺼내는 등 "Finder가 하는 일"을 맡는 객체이고, `NSWorkspace.shared` 하나를 쓴다. 경로는 [`resolvingSymlinksInPath()`](https://developer.apple.com/documentation/foundation/url/resolvingsymlinksinpath%28%29){:target="_blank"}로 링크를 끝까지 따라간 실제 위치를 넘긴다.
2. [`NSBitmapImageRep`](https://developer.apple.com/documentation/appkit/nsbitmapimagerep){:target="_blank"}로 96×96픽셀, RGBA 네 채널짜리 빈 그림판을 만든다.
3. [`NSGraphicsContext`](https://developer.apple.com/documentation/appkit/nsgraphicscontext){:target="_blank"}`(bitmapImageRep:)`로 그 그림판을 그리기 대상으로 만들어 `current`에 넣는다. 바꾸기 전에 [`saveGraphicsState()`](https://developer.apple.com/documentation/appkit/nsgraphicscontext/savegraphicsstate%28%29-swift.type.method){:target="_blank"}로 원래 대상을 기억해 둔다.
4. `NSImage`의 [`draw(in:)`](https://developer.apple.com/documentation/appkit/nsimage/draw%28in:%29){:target="_blank"}로 아이콘을 그림판 크기(`NSRect`)에 맞춰 그린다. 다 그리면 `restoreGraphicsState()`로 원래 대상으로 돌린다. 저장과 복원은 꼭 짝으로 쓴다.
5. [`representation(using:properties:)`](https://developer.apple.com/documentation/appkit/nsbitmapimagerep/representation%28using:properties:%29){:target="_blank"}로 그림판 내용을 PNG 바이트(`Data`)로 뽑는다.

`NSImage`는 크기마다 다른 그림을 여러 장 담을 수 있는 "그릴 수 있는 것"이라 그대로는 파일이 아니다. 그래서 정해진 크기의 그림판에 한 번 그린 뒤 PNG로 뽑았다.

`resolvingSymlinksInPath()`는 처음엔 없었다. 아이패드 화면을 찍어 보니 Safari 아이콘 왼쪽 아래에만 작은 화살표가 붙어 있었다(왼쪽이 고치기 전, 오른쪽이 고친 뒤).

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-2/touchdeck-safari-badge.png)

Finder에서 바로가기를 만들면 붙는 그 화살표다. 확인해 보니 `/Applications/Safari.app`은 진짜 앱이 아니라 시스템 폴더를 가리키는 링크였다.

```text
$ ls -la /Applications/ | grep -i safari
Safari.app -> ../System/Cryptexes/App/System/Applications/Safari.app
```

Safari 진짜 앱은 `/System/Cryptexes` 아래 별도 공간에 있고, `/Applications`에는 링크만 남아 있다. (Safari를 시스템 보안 업데이트와 함께 따로 갱신하려고 이렇게 둔 것으로 보인다.) `icon(forFile:)`에 링크 경로를 그대로 주면 "이건 바로가기"라는 표시까지 같이 그려 준다. 링크를 따라간 실제 위치를 주니 화살표가 사라졌다.

---

### 심볼릭 링크란?

심볼릭 링크는 내용 없이 "진짜는 저기 있다"는 주소만 적힌 파일이다. 링크를 열면 운영체제가 적힌 곳으로 대신 데려간다. Finder의 가상본처럼 아이콘에 화살표가 붙는다. 위의 `ls -la` 결과에서 `->`가 이 링크라는 표시이고, 화살표 오른쪽이 진짜 위치다.

![/Applications/Safari.app은 가리키기만 하는 링크이고, 따라가면 /System/Cryptexes 아래 진짜 앱이 있다. 링크 경로로 아이콘을 달라고 하면 바로가기 화살표가 붙고, 실제 경로로 달라고 하면 원래 아이콘이 나온다](/assets/images/upload/touchdeck-symlink.png)

`resolvingSymlinksInPath()`는 경로 안의 링크를 끝까지 따라가서 진짜 위치를 돌려준다.

---

## 2MB가 넘는 앱 목록 메시지

아이콘 PNG를 글자(base64)로 바꿔 앱 정보에 넣었더니, 이 맥에서는 앱 목록 메시지 하나가 2,298,435바이트였다. 아이패드가 맥에 붙어서 허락을 받으면 맥이 버튼 배치, 소리 크기, 앱 목록 순서로 보낸다.

```text
<- 21 bytes {"type":"authorized"}
<- 101 bytes {"pages":[{"buttons":[null,null,null,null,null,null,null,null,null,null,null,null]}],"type":"layout"}
<- 59 bytes {"available":false,"muted":false,"type":"volume","value":0}
<- 2298435 bytes {"items":[{"bundleId":"com.openmedia.4kvideodownloaderplus","icon":"iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAAAXNS
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-2/touchdeck-edit-app.png)

빈 칸을 누르면 뜨는 편집 화면이다. 맥이 보낸 앱 목록이 아이콘과 함께 나오고, 검색으로 좁힐 수 있다.

---

### base64란?

PNG 그림은 0~255 사이 숫자(바이트)가 줄지어 있는 파일이다. 그런데 메시지는 JSON 글자라서, 이 숫자를 그대로 넣으면 따옴표나 줄바꿈처럼 글자 규칙을 깨는 값이 섞인다. base64는 이런 바이트를 64가지 안전한 글자로만 다시 적는 방법이다.

3바이트(24비트)를 6비트씩 네 조각으로 자르고, 조각마다 0~63번 글자표에서 한 글자를 고른다. 글자표는 A~Z(0~25번), a~z(26~51번), 0~9(52~61번), +, / 순서다.

![PNG 파일 맨 앞 3바이트 0x89, 0x50, 0x4E를 6비트씩 네 조각으로 다시 자르면 34, 21, 1, 14번 글자가 되고, 글자표에서 i, V, B, O가 된다](/assets/images/upload/touchdeck-base64.png)

PNG 파일은 언제나 같은 8바이트(`89 50 4E 47 0D 0A 1A 0A`)로 시작해서, base64로 바꾸면 늘 `iVBORw0KGgo`로 시작한다. 위 로그의 아이콘 값이 `iVBOR`로 시작하는 이유다. 3바이트가 4글자가 되니 크기는 약 1.33배로 커진다. 아이콘 150개 넘게 담은 목록이 2MB를 넘은 데는 이 몫도 있다.

---

### 메시지 크기 한도란?

WebSocket은 메시지 하나를 끝까지 다 받은 뒤에 앱에 넘긴다. 그동안 받는 쪽은 메시지를 메모리에 쌓아 둬야 한다. 상대가 끝없이 큰 메시지를 보내면 메모리가 다 차서 앱이 죽을 수 있으니, 받는 쪽은 "이보다 크면 받지 않는다"는 한도를 둔다. Network 프레임워크에서는 그게 [`maximumMessageSize`](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options/maximummessagesize){:target="_blank"}다.

1편에서 이 한도를 16MB로 잡아 둔 이유가 이거다. 버튼 배치에는 아이콘을 넣지 않고 고유 ID만 넣었다. 아이패드가 앱 목록을 받을 때 아이콘을 고유 ID별로 기억해 두고, 배치를 그릴 때 거기서 꺼내 쓴다. 배치는 버튼을 바꿀 때마다 다시 오는데, 그때마다 아이콘까지 다시 보내면 낭비라서다. 나중에 ESP32 보드에도 같은 생각으로 아이콘을 한 번만 보낼 생각이다.

![맥은 아이콘을 담은 약 2.3MB 앱 목록을 한 번만 보내고, 버튼 배치는 번들 ID만 담아 약 100바이트로 바꿀 때마다 보낸다. 아이패드는 아이콘을 번들 ID별로 보관한다](/assets/images/upload/touchdeck-icon-once.png)

---

### 메인 스레드란?

앱 안에서 일을 하는 일꾼을 스레드라고 부른다. 그중 메인 스레드는 화면을 그리고 클릭과 키 입력을 받는 일꾼이다. 이 일꾼은 하나뿐이라, 오래 걸리는 일을 맡기면 그 일이 끝날 때까지 메뉴를 눌러도 반응이 없다.

![메인 스레드에서 아이콘 150개를 그리면 그동안 클릭을 받지 못하고, 다른 일꾼에게 맡기면 메인 스레드는 계속 클릭을 받는다](/assets/images/upload/touchdeck-main-thread.png)

앱 목록을 만드는 건 이 맥 기준으로 앱 150개 넘게 아이콘을 하나씩 그리는 일이라 맥 앱의 메인 스레드 밖에서 하고, 한 번 만든 목록은 기억해 둔다. 아래의 `Task.detached`가 "다른 일꾼에게 맡기기"다.

```swift
// TouchDeckMacApp.swift (맥)
func apps() async -> [AppInfo] {
    if let cachedApps { return cachedApps }
    let apps = await Task.detached { AppCatalog.scan() }.value
    cachedApps = apps
    return apps
}
```

#### Task.detached로 메인 밖에서 돌리기

[`Task.detached`](https://developer.apple.com/documentation/swift/task/detached%28name:priority:operation:%29-9xki7){:target="_blank"}는 지금 하던 곳(메인)과 상관없는 별도 작업을 시작한다. 오래 걸리는 일을 메인 스레드 밖으로 보낼 때 쓴다. [`value`](https://developer.apple.com/documentation/swift/task/value-40dtq){:target="_blank"}는 그 작업이 끝날 때까지 기다렸다가(`await`) 결과를 받는다.

---

## 버튼을 누르면 앱이 열리기까지

아이패드에서 버튼을 누르면 몇 번째 페이지의 몇 번 칸인지만 보낸다. 무슨 앱인지는 맥이 자기 설정을 보고 정한다. 설정 원본이 맥에 있으니 아이패드가 옛날 배치를 들고 있어도 엉뚱한 앱이 열리지 않는다.

```swift
// DeckServer.swift (맥)
case .press(let page, let index):
    guard config.layout.pages.indices.contains(page),
          config.layout.pages[page].buttons.indices.contains(index),
          let button = config.layout.pages[page].buttons[index] else {
        session.send(.pressResult(page: page, index: index, ok: false, message: "빈 칸"))
        return
    }
    Task {
        let result = await actions.run(button.action)
        session.send(.pressResult(page: page, index: index, ok: result.ok, message: result.message))
    }
```

#### Task로 기다리지 않고 실행하기

`Task { }`([`Task.init`](https://developer.apple.com/documentation/swift/task/init%28name:priority:operation:%29-2dll5){:target="_blank"})는 지금 자리(여기서는 메인)를 이어받는 새 작업을 시작한다. 결과를 기다리지 않고 바로 다음 줄로 가서, 앱을 여는 동안에도 다음 메시지를 받을 수 있다.

앱을 여는 건 고유 ID로 앱 위치를 찾고, 그 위치를 여는 두 단계다.

```swift
// ActionRunner.swift (맥)
openApp: { bundleId in
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { throw AppNotFound() }
    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
},
```

#### NSWorkspace로 번들 ID의 앱 열기

[`urlForApplication(withBundleIdentifier:)`](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication%28withbundleidentifier:%29){:target="_blank"}는 번들 ID로 설치된 앱의 위치를 찾는다. 없으면 nil이다. 찾은 위치는 [`openApplication(at:configuration:)`](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication%28at:configuration:completionhandler:%29){:target="_blank"}로 연다. 이미 켜져 있으면 앞으로 가져오고, `await`로 기다리면 연 앱(`NSRunningApplication`)을 준다. 열 때 옵션은 [`NSWorkspace.OpenConfiguration`](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration){:target="_blank"}에 담는데, 여기서는 기본값을 썼다.

앱을 지웠으면 `urlForApplication`이 nil을 돌려주고, 그때는 "앱을 찾을 수 없음: com.example.none"처럼 이유를 담아 아이패드에 돌려준다. 실패하면 아이패드 버튼에 빨간 테두리가 생기고 아래에 이유가 잠깐 뜬다.

`ActionRunner`는 바깥 세계와 닿는 부분(앱 열기, 폴더 확인, 프로세스 실행)을 전부 클로저로 받게 만들었다. 실제 앱에서는 진짜 `NSWorkspace`를 쓰는 걸 넣고, 테스트에서는 원하는 부분만 가짜로 바꾼다. 그래서 "앱이 없을 때 이유가 제대로 나오는지" 같은 걸 실제로 앱을 지우지 않고 확인할 수 있다.

```swift
// ActionRunnerTests.swift (맥)
@Test func missingAppFails() async {
    var r = ActionRunner.fake()
    r.openApp = { _ in throw ActionRunner.AppNotFound() }
    let out = await r.run(.app(bundleId: "com.example.none"))
    #expect(out.ok == false)
    #expect(out.message == "앱을 찾을 수 없음: com.example.none")
}
```

맥 앱은 Dock 아이콘 없이 메뉴바에만 뜨게 [`LSUIElement`](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement){:target="_blank"}를 켰고, 다른 앱을 열고 Alacritty를 띄워야 해서 앱 샌드박스는 껐다. 앱스토어에 낼 앱이 아니라 내 맥에서만 쓰는 앱이라 가능한 선택이다.

매일 쓰려면 맥을 켤 때마다 앱을 직접 띄우는 것도 번거롭다. 메뉴바 창에 "로그인 시 자동 실행" 토글을 넣고 `SMAppService.mainApp`으로 등록했다. 등록은 지금 실행 중인 앱의 경로로 된다. Xcode에서 띄운 빌드로 켜면 로그인할 때 그 빌드가 뜨니, Release로 빌드해 /Applications에 넣은 앱에서 켜야 한다. 그래서 앱이 /Applications 밖에 있으면 토글 아래에 그렇게 안내하고, 시스템 설정에서 허용을 기다리는 상태(`requiresApproval`)일 때도 안내를 띄운다.

```swift
// LoginItem.swift (맥)
var isOn: Bool { [.enabled, .requiresApproval].contains(status()) }

func set(_ on: Bool) -> String? {
    do {
        try on ? register() : unregister()
        return nil
    } catch {
        return "로그인 항목 \(on ? "등록" : "해제") 실패: \(error.localizedDescription)"
    }
}
```

#### SMAppService로 로그인 항목 등록하기

[`SMAppService`](https://developer.apple.com/documentation/servicemanagement/smappservice){:target="_blank"}는 로그인 항목처럼 "따로 도는 앱 부분"을 시스템에 등록하는 도구다. 앱 자체를 로그인 항목으로 다룰 때는 [`mainApp`](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp){:target="_blank"}을 쓴다. [`register()`](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29){:target="_blank"}로 등록하고 `unregister()`로 해제하며, 지금 상태는 [`status`](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.property){:target="_blank"}로 읽는다. 상태는 `.enabled`(켜짐), `.requiresApproval`(시스템 설정에서 허용 기다림), `.notRegistered` 등이다.

위 코드의 `status()`, `register()`, `unregister()`는 테스트에서 바꿔 끼울 수 있게 `SMAppService.mainApp`의 같은 이름 기능을 감싸 둔 것이다.
