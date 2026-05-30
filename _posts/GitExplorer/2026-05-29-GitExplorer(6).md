---
title: GitExplorer (6)
writer: Harold
date: 2026-05-29 08:06
categories: [GitExplorer]
tags: [WidgetKit]

toc: true
toc_sticky: true
---

## Widget 적용하기

이제 GitExplorer의 마지막 단계인 Widget 적용하기이다.

[이전에](https://haroldfromk.github.io/categories/widgetkit/){:target="_blank"}이미 정리를 해본적이 있기에, 이걸 참고해서 빠르게 적용을 해보려 한다.

사실 이전에도 WidgetKit을 처음접할때 했던게 Github Repo였어서 결이 비슷할지도 모른다.

---

### 1. Widget Extension 만들기

Target을 추가해서 만들면되는데

이때 주의할것이 WatchOS에도 Widget이 있으므로 주의하자.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/947d3589-86b0-466e-8619-f67b32e9e39a" />

Watch용 위젯은 여기선 만들지 않는다.
(앱용 만들고 시간나면 만들어볼지도?)

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/f14b1a17-fa92-413c-88a6-cf07f1f76f0d" />

지금은 굳이 위젯으로 추가할게 없어서 체크를 하지는 않는다.

* **Include Live Activity** - 잠금화면 / Dynamic Island에 실시간 정보를 표시하는 Live Activity 기능을 포함한다. (예: 배달 현황, 스포츠 경기 점수 등 실시간 업데이트가 필요한 경우)

* **Include Control** - iOS 18에서 추가된 기능으로, 제어 센터에 앱의 커스텀 컨트롤을 추가할 수 있다.

* **Include Configuration App Intent** - 위젯 롱프레스 시 나타나는 설정 화면을 통해 유저가 위젯을 커스터마이징할 수 있게 해준다. (예: 표시할 유저 선택, 새로고침 주기 설정 등)

그리고 아래 Project와, Embed쪽에 앱이 맞는지 반드시 확인하자.

또 Widget에 필요한 여러 Swift 파일들을 만들때

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/cc0d7559-4189-4779-9700-2bd931db025b" />

반드시 Target을 확인하도록 하자.

---

### 2. App Group 설정하기

App Group은 [이전글](https://haroldfromk.github.io/posts/Widget-(7)/){:target="_blank"}에서 언급을 한적이 있는데,

App Group을 설정하면 공유된 컨테이너를 통해 데이터를 교환할 수 있다.
즉 지금 설정하는 이유는 `앱과 위젯은 서로 분리된 프로세스로 실행되므로, 기본적으로 동일한 UserDefaults나 파일 시스템을 공유하지 않기 때문`이다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/9ad33ceb-6c18-40c3-befe-10ea34a4da1c" />

사진처럼 추가를 해주면 된다.

그러면 App Group이라는 항목이 추가되는데 거기서 +를 눌러서 컨테이너 이름을 적어주면된다.

여기선 `group.co.harold.GitExplorer`로 해주었다. 그리고 Widget도 같이 추가해주면된다.

이건 예전 강의에서 하던 방식인데

```swift
extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: "group.co.harold.GitExplorer")!
    }
    static let favoritesKey = "FavoriteNames"
}
```

이런식으로 한다. (여기서 favoritesKey 쓴이유는 GitExplorer에서 써왔기 때문)

---

하지만 파일을 하나 더 만들어야 하기에 그냥 통합으로 관리하기 위해서

```swift
class Constants {
    static let token = "" // token here
    static let favoritesKey = "FavoriteNames"
}

extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: "group.co.harold.GitExplorer")!
    }
}
```

이렇게 작성하고 대신 target을 추가해준다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/81fd8e96-9fb4-4bb3-b3bf-e582f9610f95" />

추가한 사진은 pass

현재 우리 앱과 위젯, 그리고 App gruop을 사진으로 간단하게 정리하면

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/fe0a8634-3079-4686-80aa-097b6863f8e8" />

그리고 App Group의 이해를 돕기위해 간단하게 시뮬레이션화 하면

<iframe 
    src="/assets/demo/appgroup-shared-storage.html" 
    width="100%" 
    height="520" 
    style="border: none; border-radius: 12px; overflow: hidden;" 
    scrolling="no">
</iframe>

---

### 3. 모델링 (GithubUser + Entry)

여기 위젯에서는 

```swift
struct GithubUser: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: String
    var name: String?
    var bio: String?
    var publicRepos: Int?
    var followers: Int?
    var following: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case name
        case publicRepos = "public_repos"
        case followers, following
        case bio
    }
}
```

이렇게 모델링을 하기로 했다.

---

그리고 위젯에선

모델링과 별개로 Entry가 필요한데, 이전에도 언급했었는데

타임라인 내에서 위젯이 특정 시점에 표시할 데이터를 캡슐화하는 프로토콜이다.

그냥 모델링이라고 보면 된다.

```swift
struct SingleGitExplorerEntry: TimelineEntry {
    let date: Date
    let user: GithubUser
}


struct MultiGitExplorerEntry: TimelineEntry {
    let date: Date
    let users: [GithubUser]
}
```

일단은 두개로 나눈 이유는 Small은 유저 1명, Medium은 유저 2명을 보여주는 구조라서 데이터 구조를 명확하게 분리하기 위해서다.

---

### 4. NetworkService 만들기

위에서 우리는 GitExplorer와 UserDefaults를 공유하는 App Group을 통해 이제 즐겨찾기한 유져의 리스트를 가져 올 수 있게 되었다.

해당 유져의 정보를 가지고 API 호출을 하여 정보를 가져오려고 한다.

```swift
final class NetworkService {
    
    static let shared = NetworkService()
    
    func asyncFetchGitUser(user: String) async throws -> GithubUser {
        let url = URL(string: "https://api.github.com/users/\(user)")!
        let header = ["Authorization" : "\(Constants.token)"]
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = header
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decodedData = try JSONDecoder().decode(GithubUser.self, from: data)
        
        return decodedData
    }
    
}
```

이건 기존에 사용했던 코드를 가져왔다.

그리고 굳이 위젯에서 인스턴스를 만들필요없이 싱글턴을 사용하기로 결정.

---

## Single Widget
### 1. Provider

사실 일반적으로 손목에 차는 시계의 심장은 무브먼트라고 한다면 개인적으로 Widget의 심장은 바로 Provider라고 생각한다.

그만큼 Provider에서 설정해야하는게 많다는것이다.

[이전글](https://haroldfromk.github.io/posts/Widget-(1)/){:target="_blank"}에서 설명한적이 있어서 설명은 pass

우선 Entry가 2개라서 Provider도 2개로 나눠주었다

---

#### 1. placeholder

```swift
func placeholder(in context: Context) -> SingleGitExplorerEntry {
        SingleGitExplorerEntry(date: Date(), user: MockData.mockUser)
    }
```

미리보기를 보여주는 곳이라 MockData를 사용했다.

---

#### 2. getSnapshot

여긴 위젯의 현재 상태를 나타내기에 바로 직전에 만든 NetworkService를 통해 정보를 호출한 뒤, 그 값을 넣어 주면 된다.

```swift
func getSnapshot(in context: Context, completion: @escaping (SingleGitExplorerEntry) -> ()) {
    Task {
        do {
            let names = UserDefaults.shared.array(forKey: Constants.favoritesKey) as? [String] ?? []
            let firstName = names.first ?? "haroldfromk"
            let user = try await NetworkService.shared.asyncFetchGitUser(user: firstName)
            completion(SingleGitExplorerEntry(date: Date(), user: user))
        } catch {
            completion(SingleGitExplorerEntry(date: Date(), user: MockData.mockUser))
        }
    }
}   
```

이렇게 해주었다. 

다만 값이 없을 경우(즐겨찾기에 아무도 없을 경우)에 내 정보를 가져오게 했다.

그래도 네트워크 에러도 발생하는 경우가 있으므로 Catch 블럭을 통해 MockData 를 가져오게 했다.
---

#### 3. getTimeline

Provider의 핵심이다.

위젯이 언제, 어떤 데이터를 보여줄지를 결정하는 곳이다.
달력에 일정을 미리 적어두면 그 시간에 자동으로 알림이 오는 것처럼, Timeline에 Entry를 미리 등록해두면 위젯이 그 시점에 맞춰 자동으로 갱신된다.

App Group UserDefaults에서 즐겨찾기 이름 목록을 읽어서 첫 번째 유저의 정보를 API로 가져온 뒤 Entry에 담아 타임라인을 구성한다. 

이때 기본 템플릿에는 5시간치 Entry를 미리 만들어두는 for loop가 있는데, 지금은 6시간마다 한 번만 갱신하면 되므로 불필요한 `for-loop`를 제거해준다.

```swift
for hourOffset in 0 ..< 5 {
    // 생략
    entries.append(entry)
}
```

이제 코드를 작성해보면

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    Task {
        do {
            let names = UserDefaults.shared.array(forKey: Constants.favoritesKey) as? [String] ?? []
            let firstName = names.first ?? "haroldfromk"
            let userInfo = try await NetworkService.shared.asyncFetchGitUser(user: firstName)
            let entry = SingleGitExplorerEntry(date: .now, user: userInfo)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
            completion(timeline)
        } catch {
            let entry = SingleGitExplorerEntry(date: .now, user: MockData.mockUser)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
            completion(timeline)
        }
    }
}
```

이렇게 된다.

이때 catch 블럭에 단순히 에러를 콘솔에 출력하는게 아니라 mockdata를 보여주도록 하였다.

---

### 2. Widget 설정 
EntryView는 사실 해도되고 안해도 그만이다.

UI에 대해서 언급을 안했지만 이미 `SmallWidgetView`가 있기에
이걸 그대로 쓰면 된다.

하지만 위젯을 만들때의 기본구성을 지키고싶어서 적용해주었다.

```swift
struct SingleGitExplorerEntryView: View {
    var entry: SingleGitExplorerEntry
    
    var body: some View {
        SmallWidgetView(user: entry.user)
    }
}
```

진짜 마지막 단계이다 최종적으로 그동안에 적용했던 우리의 설정을 Widget에 적용해주는 작업이다.

```swift
struct SingleGitExplorerWidget: Widget {
    let kind: String = "SingleGitExplorerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SingleProvider()) { entry in
            SingleGitExplorerEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GitExplorer")
        .description("즐겨찾기 유저 정보를 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall])
    }
}

```

`StaticConfiguration`은 사용자 설정 없이 고정된 데이터를 보여주는 위젯 구성 방식이다.

- `kind` - 위젯의 고유 식별자. 여러 위젯이 있을 때 구분하는 데 사용된다.
- `provider` - 타임라인 데이터를 제공하는 Provider를 연결한다.
- `configurationDisplayName` - 위젯 추가 화면에서 보이는 이름이다.
- `description` - 위젯 추가 화면에서 보이는 설명이다.
- `supportedFamilies` - 지원하는 위젯 사이즈를 지정한다.

---

## Multi Widget
### 1. Provider
#### placeholder, getSnapshot, getTimeline, Widget설정

Single과 구조는 같다. 다만 즐겨찾기 개수가 2개 미만이거나 2개 초과일 경우 분기 처리가 필요하다.

---

getSnapshot, getTimeline의 경우 Medium 위젯은 유저 2명을 보여주는 구조라서, 즐겨찾기 개수에 따라 분기 처리가 필요하다는 것이다.

- 2명 이상: 첫 번째, 두 번째 유저 API 호출
- 1명: 첫 번째 유저 API 호출 + Mock 유저로 채움
- 0명: Mock 유저 2명으로 채움

```swift
do {
    if names.count >= 2 {
        for name in names.prefix(2) {
            let user = try await NetworkService.shared.asyncFetchGitUser(user: name)
            users.append(user)
        }
    } else if names.count == 1 {
        let user = try await NetworkService.shared.asyncFetchGitUser(user: names[0])
        users.append(user)
        users.append(MockData.mockUsers[1])
    } else {
        users = MockData.mockUsers
    }
} catch {
    users = MockData.mockUsers
}
```

에러가 발생하면 `catch` 블럭에서 Mock 데이터로 대체 해준다.

그외엔 Single과 같다.


---

## WidgetBundle 설정

여기가 앱으로 치면 xxxApp.swift 와 같다.
앱의 시작점.

```swift
import WidgetKit
import SwiftUI

@main
struct GitExplorerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SingleGitExplorerWidget()
        MultiGitExplorerWidget()
    }
}
```

그냥 우리가 만들어준 위젯을 넣어주면 된다.

---

## 문제 수정하기

### 위젯 검색이 안되는 문제 수정

현재 위젯이 안뜨는 문제가 있어서 이걸 해결해보려 한다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/a06c998e-ce77-4cf2-9bbd-c72bc1e6eef1" />

별거아니었다.

알고보니

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/9a8b7308-6a43-466d-9363-c1a1b010d8b1" />

deploy 버전이 앱과 위젯이 서로 달랐기 때문...

---

### AvatarView 이미지 로드 수정

그리고 이후에 확인을 해보니 AvatarView에 이미지가 안되어서 확인을 해보니

현재는

```swift
AsyncImage(url: URL(string: url)) { image in
    image
            .resizable()
            .scaledToFill()
} placeholder: {
    ProgressView()
}
.clipShape(Circle())
```

이렇게 했는데, 위젯에서는 작동을 안하기에

api호출을 통해 가져온 url을 Data로 바꿔주는 작업이 필요하다.

이전 강의에서 썼던 함수를 그대로 사용한다

```swift
func downloadImageData(from urlString: String) async -> Data? {
    guard let url = URL(string: urlString) else {
        return nil
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    } catch {
        return nil
    }
}
```

이걸 `NetworkService`에 추가해주었다.

먼저 Entry를 수정한다 (single, multi 전부 같기에 하나만 예시로 들도록 한다.)

```swift
struct SingleGitExplorerEntry: TimelineEntry {
    let date: Date
    let user: GithubUser
    let avatarData: Data?
}
```

그리고 Provider를 수정해주도록 한다.

```swift
func placeholder(in context: Context) -> SingleGitExplorerEntry {
    SingleGitExplorerEntry(date: Date(), user: MockData.mockUser, avatarData: nil)
}

func getSnapshot(in context: Context, completion: @escaping (SingleGitExplorerEntry) -> ()) {
    Task {
        do {
            // 생략
            let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
            completion(SingleGitExplorerEntry(date: Date(), user: user, avatarData: avatarData))
        } catch {
            // 생략
        }
    }
}

func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    Task {
        do {
            // 생략
            let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
            let entry = SingleGitExplorerEntry(date: .now, user: user, avatarData: avatarData)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
            completion(timeline)
        } catch {
            // 생략
        }
    }
}
```

---

Multi는 `let avatarData: [Data?]` 배열이 들어간다.

```swift
func placeholder(in context: Context) -> MultiGitExplorerEntry {
    MultiGitExplorerEntry(date: Date(), users: MockData.mockUsers, avatarData: [Data(), Data()])
}

func getSnapshot(in context: Context, completion: @escaping (MultiGitExplorerEntry) -> ()) {
    Task {
        // 생략
        var avatarDatas: [Data] = []
        
        do {
            if names.count >= 2 {
                for name in names.prefix(2) {
                    // 생략
                    let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
                    users.append(user)
                    avatarDatas.append(avatarData ?? Data())
                }
            } else if names.count == 1 {
                // 생략
                let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
                // 생략
                avatarDatas.append(avatarData ?? Data())
                avatarDatas.append(Data())
            } else {
                users = MockData.mockUsers
                avatarDatas = [Data(), Data()]
            }
        } catch {
            users = MockData.mockUsers
            avatarDatas = [Data(), Data()]
        }
        completion(MultiGitExplorerEntry(date: Date(), users: users, avatarData: avatarDatas))
    }
}

func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    Task {
        // 생략
        var avatarDatas: [Data] = []
        
        do {
            if names.count >= 2 {
                for name in names.prefix(2) {
                    // 생략
                    let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
                    users.append(user)
                    avatarDatas.append(avatarData ?? Data())
                }
            } else if names.count == 1 {
                // 생략
                let avatarData = await NetworkService.shared.downloadImageData(from: user.avatarUrl)
                // 생략
                avatarDatas.append(avatarData ?? Data())
                avatarDatas.append(Data())
            } else {
                users = MockData.mockUsers
                avatarDatas = [Data(), Data()]
            }
        } catch {
            users = MockData.mockUsers
            avatarDatas = [Data(), Data()]
        }
        let entry = MultiGitExplorerEntry(date: .now, users: users, avatarData: avatarDatas)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
        completion(timeline)
    }
}
```

이전과 변화가 없던 부분은 생략했다.

---

이제 View 부분을 수정하는데

기존에 AsyncImage였던 부분을

```swift
if let data = avatarData, let uiImage = UIImage(data: data) {
    Image(uiImage: uiImage)
        .resizable()
        .scaledToFill()
        .clipShape(Circle())
} else {
    Circle()
        .fill(Color.gray.opacity(0.3))
}
```

이렇게 바꿔주었다.

이후 Entry에 `avatarData`가 새로 생겼기에 파라미터 추가 에러가 뜨는데 그걸 해결해주면 된다.
Single은 `Data?`, Multi는 `[Data?]` 타입으로 각각 추가해주면 된다.

대부분은 해당 view안에 `let avatarData`를 single과 multi에 맞게 추가를 해주면 된다.

그리고 View에 UserCell이 있는데

```swift
UserCell(user: user, avatarData: index < avatarData.count ? avatarData[index] : nil)
```

이론적으로는 `users`와 `avatarDatas`를 같이 채우기 때문에 인덱스가 벗어날 일이 없지만, 방어적으로 처리하기 위해 삼항연산자로 범위를 체크해주었다.

---

실행해서 최종 점검을 해본다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/da670072-abec-44af-81ff-7753d0bc7b30" />

이렇게 뜨는걸로봐선 UserDefaults에서 값을 제대로 가져오지 못한것 같다.

다시 한번 확인을 해본다.

알고보니 기존에 App의 FavoriteViewModel에서

`UserDefaults.standard.array` 이렇게 써왔기 때문

앱과 위젯은 서로 다른 프로세스라 `UserDefaults.standard`는 공유가 안 된다. App Group을 설정했어도 `standard` 대신 `shared` (suiteName 기반)를 써야 데이터를 공유할 수 있다.

이제 `standard를 shared`로 바꿔주자.

실행하면 잘 되는 걸 알 수 있다.

<img width="420" height="618" alt="Image" src="https://github.com/user-attachments/assets/befeaeed-4105-4b35-b3c4-af80276b1663" />{: width="50%" height="50%"}

---

일단은 App Intent를 사용하지 않고 끝냈는데, 이건 나중에 보완을 해보도록 하겠다.