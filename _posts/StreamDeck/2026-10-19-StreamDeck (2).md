---
title: StreamDeck (2) 맥에 설치된 앱 목록과 아이콘을 보내고, 눌러서 실행하기
writer: Harold
date: 2026-10-19 18:10:00 +0900
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

`/System/Applications`는 메모, 캘린더, 음악처럼 macOS에 들어 있는 앱 자리고, 직접 설치한 앱은 `/Applications`에 있다.

처음엔 이 다섯 곳이면 다 될 줄 알았다. 그런데 아이패드에서 Finder 버튼을 추가하려고 하니 목록에 Finder가 없었다. Finder는 이 폴더들 어디에도 없고 `/System/Library/CoreServices/Finder.app`에 따로 있다. 매일 쓰는 앱이라 빠지면 안 돼서, 먼저 "목록에 Finder가 있어야 한다"는 테스트를 만들고 실패하는 걸 본 다음 따로 넣었다.

```swift
// AppCatalogTests.swift (맥)
@Test func scanIncludesFinder() {
    #expect(AppCatalog.scan().contains { $0.bundleId == "com.apple.finder" })
}
```

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

`resolvingSymlinksInPath()`는 처음엔 없었다. 아이패드 화면을 찍어 보니 Safari 아이콘 왼쪽 아래에만 작은 화살표가 붙어 있었다(왼쪽이 고치기 전, 오른쪽이 고친 뒤).

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-2/touchdeck-safari-badge.png)

Finder에서 바로가기를 만들면 붙는 그 화살표다. 확인해 보니 `/Applications/Safari.app`은 진짜 앱이 아니라 시스템 폴더를 가리키는 링크였다.

```text
$ ls -la /Applications/ | grep -i safari
Safari.app -> ../System/Cryptexes/App/System/Applications/Safari.app
```

Safari 진짜 앱은 `/System/Cryptexes` 아래 별도 공간에 있고, `/Applications`에는 링크만 남아 있다. (Safari를 시스템 보안 업데이트와 함께 따로 갱신하려고 이렇게 둔 것으로 보인다.) `icon(forFile:)`에 링크 경로를 그대로 주면 "이건 바로가기"라는 표시까지 같이 그려 준다. 링크를 따라간 실제 위치를 주니 화살표가 사라졌다.

---

## 2MB가 넘는 앱 목록 메시지

아이콘 PNG를 글자(base64)로 바꿔 앱 정보에 넣었더니, 이 맥에서는 앱 목록 메시지 하나가 2,298,435바이트였다. 아이패드가 맥에 붙어서 허락을 받으면 맥이 버튼 배치, 소리 크기, 앱 목록 순서로 보낸다.

```text
<- 21 bytes {"type":"authorized"}
<- 101 bytes {"pages":[{"buttons":[null,null,null,null,null,null,null,null,null,null,null,null]}],"type":"layout"}
<- 59 bytes {"available":false,"muted":false,"type":"volume","value":0}
<- 2298435 bytes {"items":[{"bundleId":"com.openmedia.4kvideodownloaderplus","icon":"iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAAAXNS
```

1편에서 WebSocket 메시지 최대 크기를 16MB로 잡아 둔 이유가 이거다. 버튼 배치에는 아이콘을 넣지 않고 고유 ID만 넣었다. 아이패드가 앱 목록을 받을 때 아이콘을 고유 ID별로 기억해 두고, 배치를 그릴 때 거기서 꺼내 쓴다. 배치는 버튼을 바꿀 때마다 다시 오는데, 그때마다 아이콘까지 다시 보내면 낭비라서다. 나중에 ESP32 보드에도 같은 생각으로 아이콘을 한 번만 보낼 생각이다.

앱 목록을 만드는 건 이 맥 기준으로 앱 150개 넘게 아이콘을 하나씩 그리는 일이라 맥 앱의 메인 스레드 밖에서 하고, 한 번 만든 목록은 기억해 둔다.

```swift
// TouchDeckMacApp.swift (맥)
func apps() async -> [AppInfo] {
    if let cachedApps { return cachedApps }
    let apps = await Task.detached { AppCatalog.scan() }.value
    cachedApps = apps
    return apps
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-19-StreamDeck-2/touchdeck-edit-app.png)

빈 칸을 누르면 뜨는 편집 화면이다. 맥이 보낸 앱 목록이 아이콘과 함께 나오고, 검색으로 좁힐 수 있다.

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

앱을 여는 건 고유 ID로 앱 위치를 찾고, 그 위치를 여는 두 단계다.

```swift
// ActionRunner.swift (맥)
openApp: { bundleId in
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { throw AppNotFound() }
    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
},
```

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

맥 앱은 Dock 아이콘 없이 메뉴바에만 뜨게 `LSUIElement`를 켰고, 다른 앱을 열고 Alacritty를 띄워야 해서 앱 샌드박스는 껐다. 앱스토어에 낼 앱이 아니라 내 맥에서만 쓰는 앱이라 가능한 선택이다.

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

---

## 참고자료

- [NSWorkspace.icon(forFile:) (Apple)](https://developer.apple.com/documentation/appkit/nsworkspace/icon(forfile:))
- [NSWorkspace.urlForApplication(withBundleIdentifier:) (Apple)](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:))
- [NSWorkspace.openApplication(at:configuration:completionHandler:) (Apple)](https://developer.apple.com/documentation/appkit/nsworkspace/openapplication(at:configuration:completionhandler:))
- [URL.resolvingSymlinksInPath() (Apple)](https://developer.apple.com/documentation/foundation/url/resolvingsymlinksinpath())
- [LSUIElement (Apple)](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
- [SMAppService (Apple)](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [maximumMessageSize (Apple)](https://developer.apple.com/documentation/network/nwprotocolwebsocket/options/maximummessagesize)
