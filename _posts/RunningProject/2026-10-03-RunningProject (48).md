---
title: RunWay 1.4 (5) 앱 언어 선택, 안 도는 코드 정리, 업데이트 알림
writer: Harold
date: 2026-10-03 10:00:00 +0900
last_modified_at: 2026-10-06 02:00:00 +0900
categories: [RunWay]
tags: [SwiftUI, WatchConnectivity, Localization]

toc: true
toc_sticky: true
published: true
---

v1.4를 마무리하면서 손본 세 가지는 성격이 비슷했다. 셋 다 **이미 있는데 닿지 않고 있던 것**이다.

번역은 세 언어가 다 들어있는데 사용자가 고를 수 없었고, 코드는 멀쩡히 있는데 한 줄도 안 돌고 있었고, 버그는 고쳐서 올렸는데 쓰는 사람에게 전해지지 않았다.

---

## 고를 수 없던 앱 언어

RunWay는 한국어, 영어, 일본어 세 언어로 번역돼 있다. 그런데 어떤 언어로 뜰지는 **아이폰 시스템 언어가 정했다.** 시스템을 영어로 쓰면서 이 앱만 한국어로 보고 싶어도 방법이 없었다.

iOS에는 앱마다 언어를 따로 고르는 기능이 원래 있다. 설정 앱의 그 앱 항목에 들어가면 "언어" 줄이 뜨고 거기서 바꾼다. 그런데 RunWay에는 그 줄이 안 떴다.

---

### 번역 파일만으로는 안 되는 이유

번역은 다 들어있는데 왜 안 뜨는지가 한참 안 풀렸다. 원인은 `Info.plist`였다.

시스템은 앱이 **어떤 언어를 지원한다고 선언했는지**를 보고 그 줄을 띄울지 정한다. 번역 리소스가 들어있는 것과 지원 언어를 선언한 것은 별개다. 선언이 없으면 시스템은 고를 게 하나뿐이라고 보고 아예 줄을 안 만든다.

```xml
<key>CFBundleDevelopmentRegion</key>
<string>ko</string>
<key>CFBundleLocalizations</key>
<array>
    <string>ko</string>
    <string>en</string>
    <string>ja</string>
</array>
```

두 줄을 넣자 설정에 언어 항목이 생겼다.

![iOS 설정 앱의 RunWay 항목 아래쪽에 Preferred Language 와 Language 줄이 생긴 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-48/runway14_settings_language.webp)

맨 아래 Preferred Language 가 그것이다. 이 줄은 앱이 만드는 게 아니라 시스템이 만들어준다.

여기서 한 번 더 걸렸다. **빌드만 다시 해서는 안 바뀐다.** 설정 앱이 들고 있는 앱 정보는 설치 시점에 읽히는 것이라, 앱을 지우고 다시 설치해야 반영된다. 안 바뀐다고 `Info.plist`를 몇 번이나 다시 보다가 재설치하고 나서야 떴다.

---

### 앱 안이 아니라 iOS 설정으로

설정에 항목이 생겼으니 앱 안에 언어 화면을 따로 만들 수도 있었다. 안 만들고 설정 앱으로 보내는 버튼만 뒀다.

```swift
// 언어는 앱 안에서 바꾸지 않고 iOS 설정으로 보낸다. 앱 안에서 바꾸려면
// 화면 글자만 바뀌고 알림 문구와 Watch 화면은 시스템 언어로 남거나,
// 전부 반영하려면 앱을 다시 시작해야 한다. 스스로 종료하는 건 사용자에게
// 크래시로 보이고 심사 지침에도 어긋난다. iOS 설정에서 바꾸면 시스템이
// 알아서 앱을 다시 띄워주고 Watch 앱까지 같이 따라온다.
Button {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
} label: {
    SettingsRow(icon: "globe", title: "언어")
}
```

앱 안에서 바꾸면 화면 글자는 바로 바뀌지만 **알림 문구와 Watch 화면은 시스템 언어로 남는다.** 전부 반영하려면 앱을 다시 시작해야 하는데, 앱이 스스로 꺼지는 건 사용자 눈에 크래시로 보이고 심사 지침에도 어긋난다.

iOS 설정에서 바꾸면 시스템이 알아서 앱을 다시 띄워주고 Watch 앱까지 같이 따라온다. 직접 만들었으면 더 못했을 일이라 만들 이유가 없었다.

---

## 한 줄도 안 돌던 미러링 잔재

RunWay는 한때 **워치가 주도하는 미러링**을 지원했다. 워치에서 러닝을 시작하면 아이폰이 그 세션을 넘겨받아 따라가는 구조다. 건강 앱에 러닝이 두 번 저장되는 문제를 쫓다가 걷어냈고, 지금은 아이폰이 주도하는 한 방향만 남아있다.

걷어낼 때 코드를 다 지우지는 않았다. 되살릴지 몰라서 "지금은 안 돈다"는 주석만 달아뒀다. v1.4에서 안 되살리기로 정하면서 정리했다.

---

### 안 도는 코드를 가리는 기준

가장 큰 덩어리는 아이폰이 워치에서 계기 값을 받는 자리였다.

```swift
guard HealthKitService.shared.startOrigin == .remote else { return }
```

`startOrigin`이 `.remote`라는 건 "이 러닝은 상대 기기가 주도한다"는 뜻이다. 그런데 아이폰에서 이 값을 `.remote`로 세팅하는 **유일한 자리가 미러링 세션을 받아오는 함수**였고, 그 함수는 걷어낼 때 주석 처리됐다.

즉 이 가드는 참이 될 수 없다. 워치는 여전히 3초마다 계기 값을 보내고 있었고, 아이폰은 그걸 받아서 전부 버리고 있었다.

받는 쪽을 지우면서 **보내는 쪽도 같이 지웠다.** 수신부만 지우면 워치가 아무도 안 읽는 메시지를 러닝 내내 쏘는 상태가 그대로 남는다. 전파와 배터리를 그냥 버리는 셈이다. 정리 목록에는 수신부만 적혀 있었는데, 지우고 보니 짝이 비어서 알게 됐다.

---

### 죽은 줄 알았던 가드

정리 목록에 이렇게 적어둔 항목이 있었다.

> `RunViewModel.saveRunningData()`의 `startOrigin == .remote` 가드도 같은 이유로 걸리지 않는다

실제 코드는 이랬다.

```swift
guard HealthKitService.shared.startOrigin == .local else { return }
```

`.remote`가 될 일이 없는 건 맞다. 그래서 "항상 통과한다"고 적었던 건데, 지우기 전에 다시 보니 아니었다. **`resetWorkout()`이 `startOrigin`을 `nil`로 비운다.** `nil`은 `.local`이 아니니 이 가드는 걸린다.

그러니까 이 가드가 실제로 하는 일은 "미러링 중이면 저장하지 마라"가 아니라 **"진행 중인 러닝이 없으면 저장하지 마라"**였다. 설명이 낡았을 뿐 코드는 멀쩡히 일하고 있었다.

지우지 않고 주석만 지금 하는 일로 다시 적었다. 목록을 만들 때 "같은 이유로"라고 묶은 게 함정이었다. 두 자리가 같은 값을 보고 있다고 해서 같은 이유로 죽은 건 아니었다.

---

### 남겨둔 하나

정리 목록에 `ZombieSessionLogger`도 있었다. 호출부 없이 로거만 남아있는 파일이다.

안 지웠다. 남겨둔 이유가 "같은 문제를 다시 팔 때 Console 필터를 재사용하려고"인데, **좀비 세션은 `healthd`를 앱에서 통제할 수 없다는 별개의 한계다.** 미러링을 어떻게 하기로 했든 다시 팔 수 있는 문제라 이번 결정이 닿는 범위가 아니었다.

목록에 같이 적혀 있다고 같은 결정으로 처리하면 안 된다는 게, 앞의 가드와 함께 이번 정리에서 두 번 나왔다.

---

## 고쳐도 닿지 않던 수정

1.3.1을 쓰던 사람이 워치 화면이 튕기는 버그를 겪고 있었다. 1.3.2에서 이미 고친 문제였는데 **업데이트가 나왔다고 알려줄 방법이 앱에 하나도 없었다.**

iOS는 기본이 자동 업데이트라 대부분은 이런 알림을 볼 일이 없다. 자동 업데이트를 꺼둔 소수가 대상인데, 지금은 그 소수에게 닿을 길이 없다.

---

### 서버 없이 쓰는 애플 조회 창구

"알려준다"고 하면 애플이 먼저 말을 걸어주는 걸 떠올리기 쉬운데 반대다. **앱이 켜질 때 스스로 물어보러 간다.** 받은 답을 제 버전과 견주고, 스토어 쪽이 높을 때만 입을 연다.

<svg viewBox="0 0 680 262" width="100%" xmlns="http://www.w3.org/2000/svg" style="max-width:680px;display:block;margin:20px auto;color:inherit" role="img" aria-labelledby="u48t u48d">
<title id="u48t">앱이 스스로 물어보고 두 버전을 견준다</title>
<desc id="u48d">앱은 켜질 때 하루 한 번 애플 조회 창구에 물어보고, 돌아온 스토어 버전을 설치된 버전과 견준다. 스토어 쪽이 높을 때만 알림이 뜨고, 같으면 아무 일도 하지 않는다.</desc>
<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
<defs>
<marker id="u48a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">
<path d="M0,1 L9,5 L0,9" fill="none" stroke="currentColor" stroke-width="1.6"/>
</marker>
</defs>

<rect x="18" y="38" width="172" height="62" rx="8" stroke-width="1.6" opacity="0.55"/>
<text x="104" y="64" font-size="12" font-weight="600" text-anchor="middle" fill="currentColor" stroke="none">내 아이폰의 RunWay</text>
<text x="104" y="84" font-size="11" text-anchor="middle" fill="currentColor" stroke="none" opacity="0.6">설치된 버전을 알고 있다</text>

<rect x="490" y="38" width="172" height="62" rx="8" stroke-width="1.6" opacity="0.55"/>
<text x="576" y="64" font-size="12" font-weight="600" text-anchor="middle" fill="currentColor" stroke="none">애플 조회 창구</text>
<text x="576" y="84" font-size="11" text-anchor="middle" fill="currentColor" stroke="none" opacity="0.6">itunes.apple.com/lookup</text>

<path d="M196,58 L484,58" stroke-width="1.6" marker-end="url(#u48a)"/>
<text x="340" y="48" font-size="11" text-anchor="middle" fill="currentColor" stroke="none">하루 한 번, 앱을 켤 때 물어본다</text>

<path d="M484,84 L196,84" stroke-width="1.6" opacity="0.6" marker-end="url(#u48a)"/>
<text x="340" y="99" font-size="11" text-anchor="middle" fill="currentColor" stroke="none" opacity="0.65">스토어 버전과 앱 페이지 주소</text>

<path d="M0,132 L680,132" stroke-width="1" opacity="0.18"/>

<text x="0" y="156" font-size="12" font-weight="600" fill="currentColor" stroke="none">돌아온 값을 내 버전과 견준다</text>

<text x="20" y="192" font-size="11" fill="currentColor" stroke="none" opacity="0.6">설치</text>
<text x="66" y="192" font-size="13" font-weight="700" fill="currentColor" stroke="none">1.3.2</text>
<text x="150" y="192" font-size="11" fill="currentColor" stroke="none" opacity="0.6">스토어</text>
<text x="208" y="192" font-size="13" font-weight="700" fill="currentColor" stroke="none">1.4</text>
<path d="M262,187 L298,187" stroke-width="1.4" marker-end="url(#u48a)"/>
<text x="312" y="192" font-size="12" font-weight="600" fill="currentColor" stroke="none">스토어가 높다 · 알림이 뜬다</text>

<text x="20" y="232" font-size="11" fill="currentColor" stroke="none" opacity="0.6">설치</text>
<text x="66" y="232" font-size="13" font-weight="700" fill="currentColor" stroke="none" opacity="0.55">1.4</text>
<text x="150" y="232" font-size="11" fill="currentColor" stroke="none" opacity="0.6">스토어</text>
<text x="208" y="232" font-size="13" font-weight="700" fill="currentColor" stroke="none" opacity="0.55">1.4</text>
<path d="M262,227 L298,227" stroke-width="1.4" opacity="0.45" marker-end="url(#u48a)"/>
<text x="312" y="232" font-size="12" fill="currentColor" stroke="none" opacity="0.6">같다 · 아무 일도 안 한다</text>

</g>
</svg>

애플이 공개한 조회 창구가 있다.

```
https://itunes.apple.com/lookup?bundleId=HaroldSong.Project.RunWay&country=kr
```

응답에 스토어에 올라간 버전과 앱 페이지 주소가 같이 들어온다. 서버를 세울 필요도, 키를 발급받을 필요도 없다. `country`를 빼면 다른 나라 스토어 버전이 올 수 있어서 붙인다.

```swift
static func checkForUpdate() async -> Update? {
    guard shouldCheckToday() else { return nil }
    guard let lookupURL else { return nil }

    do {
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let storeVersion = first["version"] as? String,
              let trackViewURL = (first["trackViewUrl"] as? String).flatMap(URL.init(string:))
        else { return nil }

        UserDefaults.standard.set(Date(), forKey: lastCheckedKey)
        guard isNewer(storeVersion, than: currentVersion) else { return nil }
        return Update(version: storeVersion, storeURL: trackViewURL)
    } catch {
        return nil
    }
}
```

버전 비교는 숫자로 읽는 방식을 쓴다. 문자열로 그냥 비교하면 `1.10`이 `1.9`보다 작다고 나온다.

```swift
return storeVersion.compare(installed, options: .numeric) == .orderedDescending
```

지금은 1.4라 안 걸리지만 `1.10`까지 가면 그날부터 알림이 영영 안 뜬다. 글자 순서로는 `1`이 `9`보다 앞이라서 스토어 쪽이 더 낮다고 판정한다.

하나 더 알아둘 게 있다. **스토어에 올린 직후 몇 시간은 이 창구가 아직 옛 버전을 돌려줄 수 있다.** 올리자마자 알림이 뜨는 건 기대하지 않는 게 맞다.

---

### 띄울 때와 안 띄울 때

이런 알림은 만드는 것보다 **언제 안 띄울지**를 정하는 쪽이 더 중요했다.

**러닝 중에는 묻지도 띄우지도 않는다.** 뛰는 중에 알림이 뜨면 그게 더 사고다. 그런데 확인을 시작할 때 러닝이 아니었어도 응답을 기다리는 사이에 시작될 수 있다. 그래서 응답을 받은 뒤에도 한 번 더 본다.

```swift
private func checkForAppUpdate() {
    guard !runViewModel.isRunning else { return }
    Task {
        guard let update = await AppUpdateService.checkForUpdate() else { return }
        guard !runViewModel.isRunning else { return }
        availableUpdate = update
        showUpdateAlert = true
    }
}
```

**하루에 한 번만 묻는다.** 띄울 때마다 물어보면 사람은 알림 자체를 무시하게 된다. 자동 업데이트를 꺼둔 사람에게 하루 한 번이면 충분히 닿는다.

**실패하면 아무 말도 안 한다.** 업데이트 확인에 실패했다는 사실이 사용자에게 보일 이유가 없다. 비행기 모드일 때마다 경고가 뜨면 그게 더 나쁘다. 다만 실패했을 때는 확인한 날짜를 저장하지 않는다. 한 번 실패했다고 그날 하루를 날리면 안 되기 때문이다.

**막지 않고 권한다.** 버튼은 `업데이트`와 `나중에` 둘이다. 앱이 멀쩡히 도는데 막을 이유가 없고, 강제 업데이트 벽은 심사에서도 걸릴 수 있다.

안 넣은 것도 있다. "이 버전은 그만 보기"를 줄까 했는데, 하루 한 번이면 이미 하루 한 번의 방해로 묶인다. 영구히 끄는 선택지는 정작 중요한 업데이트를 가릴 수 있어서 뺐다. 성가시다는 말이 실제로 나오면 그때 넣는 게 낫다고 봤다.

---

### 워치 앱 버전 안내

안내 문구에 한 줄을 더 넣었다.

> Apple Watch 앱도 같이 업데이트해주세요. 두 앱의 버전이 다르면 기기 사이 동작이 어긋날 수 있어요.

RunWay는 아이폰 앱과 워치 앱이 짝이다. 1.3.2만 해도 워치 쪽 수정이 셋이었는데, 아이폰만 올라가면 그 수정이 안 들어간 상태로 돈다.

양쪽 버전이 다른 것 자체를 앱이 알아내는 것도 가능하다. 두 기기가 이미 메시지를 주고받고 있으니 버전 문자열 하나만 더 실으면 된다. 이번에는 문구까지만 하고 그건 따로 두기로 했다. 어디에 어떻게 띄울지를 정하는 게 구현보다 큰 일이라서다.

---

## 지금은 뜰 수 없는 알림

조회 창구는 **스토어에 올라간 버전**을 돌려준다. 1.4가 올라가기 전까지는 설치본이 항상 같거나 더 높아서 알림이 뜰 수가 없다.

실제로 뜨는 걸 확인하려면 1.4가 심사를 통과한 뒤 1.5를 작업하면서 봐야 한다. 지금 미리 보려면 **설치본의 버전 번호를 낮추는 수밖에 없다.**

---

### 버전만 낮춰서 띄워본 화면

옛 커밋으로 돌아갈 필요는 없었다. 조회 창구가 돌려주는 건 스토어 버전이고 그건 지금 1.3.2다. **설치본이 그보다 낮기만 하면 된다.**

프로젝트 파일은 1.4 그대로 두고 빌드할 때만 덮어썼다.

```bash
xcodebuild -project RunWay.xcodeproj -scheme RunWay -configuration Debug \
  -destination 'platform=iOS Simulator,id=<시뮬레이터 id>' \
  -derivedDataPath <임시 폴더> \
  MARKETING_VERSION=1.3.1 CODE_SIGNING_ALLOWED=NO build
```

명령줄에서 준 빌드 설정이 프로젝트에 적힌 값을 이긴다. 저장소에는 아무 변경도 안 남는다. 만들어진 앱의 `CFBundleShortVersionString`만 1.3.1이 된다.

이미 깔려 있던 자리에 덮어 설치하면 **데이터가 남아서 온보딩을 다시 안 거친다.** 지우고 깔면 첫 실행 화면부터 다시 타야 하고 기록도 날아간다.

![RunWay 홈 화면 위에 '업데이트가 있어요' 알림이 떠 있고, App Store에 1.3.2 버전이 올라와 있다는 안내와 나중에·업데이트 두 버튼이 보이는 화면](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-10-03-RunningProject-48/runway14_update_alert.png)

한 번 띄우고 나면 **같은 날에는 다시 안 뜬다.** 확인한 날짜를 저장하는 그 장치가 그대로 걸린다. 다시 보려면 그 값을 지워야 하는데, 앱 컨테이너 안 설정 파일을 직접 고치는 걸로는 안 된다. 시스템이 그 값을 메모리에 들고 있어서 파일만 고치면 무시된다.

**업데이트 버튼이 App Store를 여는 것만은 시뮬레이터로 확인이 안 된다.** 시뮬레이터에는 App Store 앱이 없어서, 그 주소를 열면 Safari로 떨어졌다가 Safari도 자기가 열 주소가 아니라며 거부한다. 주소는 조회 응답이 준 것을 그대로 쓰므로 실기기에서 같은 주소를 눌러 App Store가 열리는 것으로 확인했다.

버튼 색이 민트인 건 고른 게 아니라 **탭 화면에 걸어둔 틴트가 여기까지 내려온 것**이다. 시스템 알림도 그 환경을 물려받는다.

```swift
// RootTabView
.tint(.rwGreen)
```

---

만들어놓고 한동안 못 보는 기능이 된 셈인데, 애초에 이게 필요했던 이유가 "1.3.1에 멈춰 있는 사람에게 닿을 방법이 없다"였다. 1.4에 멈출 사람에게 닿으려면 1.4에 들어있어야 한다. 다음 버전에 넣으면 늦는다.
