---
title: GitExplorer (3)
writer: Harold
date: 2026-05-23 08:06
categories: [GitExplorer]
tags: [Combine]

toc: true
toc_sticky: true
---

## Day 3: 즐겨찾기 만들기
### 미션 (Task)

1. **버튼 액션을 스트림으로 바꾸기**
   - 즐겨찾기 추가 및 삭제 버튼 클릭이라는 사용자의 물리적 터치 액션을 단순한 변수 조작이 아닌 **순간적인 이벤트 신호 스트림**으로 변환하여 시스템에 흘려보낼 것

2. **즐겨찾기 목록 누적 관리하기**
   - 기존에 즐겨찾기된 목록이라는 과거의 상태를 시스템이 기억하게 할 것
   - 새로운 추가/삭제 이벤트가 들어올 때마다 과거의 배열과 결합하여 **최신화된 전체 목록을 지속적으로 산출(누적)**해 낼 것

3. **변경될 때마다 바로 저장하기**
   - 누적 계산되어 갱신된 최신 즐겨찾기 목록 데이터가 스트림의 끝에 도달할 때마다, 즉각적으로 기기 내부 저장소에 덮어씌워 **앱을 껐다 켜도 상태가 유실되지 않게** 막을 것

---

### 1. 버튼 액션 활성화

- 즐겨찾기 추가 및 삭제 버튼 클릭이라는 사용자의 물리적 터치 액션을 단순한 변수 조작이 아닌 **순간적인 이벤트 신호 스트림**으로 변환하여 시스템에 흘려보낼 것.

---

이건 내가 즐겨찾기를 하면 로컬저장소에 값을 보관해서 로컬에서도 볼수있게 하는 걸 구현한다.

```swift
.toolbar {
   ToolbarItem(placement: .topBarTrailing) {
         Button {
            isFavorite.toggle()
         } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
               .foregroundStyle(isFavorite ? .yellow : .primary)
         }
   }
}
```

현재 프로필뷰에서의 버튼은 그냥 별의 색이 채워지냐 마냐의 차이밖에 없다.

이걸 현재 검색한 유저의 아이디만 저장해서 그 저장한 이름들을, FavoriteView에 보여주면 될것같다.

---

#### UserDefaults vs AppStrorage

[Medium](https://medium.com/@nsuneelkumar98/swiftui-data-persistence-userdefaults-vs-appstorage-a66c41666d15){:target="_blank"}을 참고하여 정리를 한다.


둘 다 작은 데이터를 Key-Value로 저장하는 방식인데, 핵심 차이는 하나다.

`@AppStorage`는 새로운 저장소가 아니라 **내부적으로 `UserDefaults`를 사용하는 SwiftUI용 Wrapper**다.

---

##### UserDefaults

```swift
UserDefaults.standard.set("Harold", forKey: "username")
let name = UserDefaults.standard.string(forKey: "username")
```

값이 바뀌어도 UI가 자동으로 갱신되지 않는다. `@State`나 `@Published`랑 같이 써야 한다.

UIKit/Foundation 기반이라 ViewModel이나 Manager 계층에서 주로 쓴다.

---

##### AppStorage

```swift
@AppStorage("username") var username = ""
```

값이 바뀌면 UI가 자동으로 갱신된다. `@State`처럼 동작한다고 보면 된다.

SwiftUI View 내부에서 간단한 설정값 저장할 때 쓴다. 다크모드, 온보딩 완료 여부, 자동로그인 여부 같은 것들.

---

##### 어디서 뭘 쓰냐

- **View 내부** → `@AppStorage`
- **ViewModel, Manager 계층** → `UserDefaults`

정리하면 다음과 같다.

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/4940eee5-5304-405d-b638-bd0ffd2b69ce" />

---

#### 1. ViewModel 만들기

위에 정리를 한 이유는 UserDefaults를 여기서 사용할것이긴 하지만, `@AppStorage`도 있는데? 라는 생각이 스쳐지나가서 글을 참고해서 정리를 했다.

우선 userdefaults의 array를 사용해서 배열을 만들어 저장을 하려고 한다.

```swift
final class FavoriteViewModel: ObservableObject {
    
    @Published var names: [String] = []
    
    
    func addToFavorite(id: String) {
        names.append(id)
        UserDefaults.standard.set(names, forKey: "FavoriteNames")
    }
    
}
```

우선은 심플하게 이렇게 뼈대를 잡았는데

생각보니 이건 Streaming은 아니다. 그냥 함수가 실행되는것일뿐.

즉 Subject Publisher를 사용해서 해당 기능을 구현하라는 것 같다.

---

##### Subject를 사용하여 Streaming 활성화

처음엔 이렇게 함수 안에서 구독을 만들었다.

```swift
func addToFavorite(id: String) {
    addSubject.sink { _ in
        self.names.append(id)
        UserDefaults.standard.set(self.names, forKey: "FavoriteNames")
    }.store(in: &cancellables)
}
```
근데 이렇게 하면 함수를 호출할 때마다 구독이 새로 생겨서 쌓이는 문제가 있다.

구독은 `init`에서 한 번만 만들고, 함수에서는 `send()`만 호출하는 구조가 맞다.

전에 Subject 타입을 정할 때 예전에 UIKit에서 `PassthroughSubject<Void, Error>`를 썼던 기억이 있었다. [이전글1](https://haroldfromk.github.io/posts/Final-(8)/){:target="_blank"}, [이전글2](https://haroldfromk.github.io/posts/Final-(17)/){:target="_blank"}

근데 그때 에러가 한 번 발생하니까 스트림이 끊겨버렸는데, 이유가 Failure 타입에 `Error`를 쓰면 에러 발생 시 스트림이 종료되기 때문이다.

즐겨찾기처럼 에러가 없는 단순 액션에는 `Never`를 써야 한다. `Never`는 "이 스트림은 절대 에러를 방출하지 않는다"는 의미라서 스트림이 계속 살아있다.

그렇게 변경을 하고 처음엔 `PassthroughSubject<Void, Never>`로 함수 호출 자체를 신호로 보내려 했는데, 그러면 `init` 안에서 어떤 `id`를 추가할지 알 수가 없다. 

그래서 `PassthroughSubject<String, Never>`로 바꿔서 `id`를 같이 흘려보내는 방식으로 정리했다.

```swift
final class FavoriteViewModel: ObservableObject {
    
    @Published var names: [String] = []
    var addSubject = PassthroughSubject<String, Never>()
    var cancellables = Set<AnyCancellable>()
    
    init() {
        addSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.names.append(id)
                UserDefaults.standard.set(self?.names, forKey: "FavoriteNames")
            }.store(in: &cancellables)
    }
    
    func addToFavorite(id: String) {
        addSubject.send(id)
    }
}
```

버튼 탭 → `send(id)` → 구독에서 `names` 업데이트 + `UserDefaults` 저장 순서로 흐른다.

같은 방식으로 remove도 만들어주었다.

```swift
var removeSubject = PassthroughSubject<String, Never>()

removeSubject
   .receive(on: DispatchQueue.main)
   .sink { id in
         self.names.removeAll { $0 == id }
   UserDefaults.standard.set(self.names, forKey: "FavoriteNames")
}.store(in: &cancellables)

func removeToFavorite(id: String) {
   removeSubject.send(id)
}
```

---

#### 2. ProfileView에 적용하기

우선은

```swift
init(user: GithubUser) {
       // 생략

   if favoriteViewModel.names.contains(user.login){
      isFavorite = true
   }
}

.toolbar {
   ToolbarItem(placement: .topBarTrailing) {
         Button {
            if isFavorite {
               favoriteViewModel.removeToFavorite(id: user.login)
            } else {
               favoriteViewModel.addToFavorite(id: user.login)
            }
            isFavorite.toggle()
         } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
               .foregroundStyle(isFavorite ? .yellow : .primary)
         }
   }
}
```

이렇게 수정을 해주었다.

일단은 버튼을 누르니

`if favoriteViewModel.names.contains(user.login){` 이 지점에서

```
Accessing StateObject<FavoriteViewModel>'s object without being installed on a View. This will create a new instance each time.
```

이런 경고가 발생

이 경고는 해석해보면 **`@StateObject`로 선언된 뷰모델(ViewModel)이 SwiftUI의 View 계층 구조에 정상적으로 장착(Installed)되지 않은 상태에서 그 내부 데이터나 인스턴스에 접근했을 때 발생한다.** 라고 되어있다.

즉, SwiftUI가 해당 객체의 생명주기를 관리하지 못하게 되며, 코드가 호출될 때마다 매번 새로운 인스턴스가 불필요하게 생성되는 문제가 발생.

그래서 `init`에서 즐겨찾기 여부를 확인하는 대신, View가 화면에 나타나는 시점인 `onAppear`에서 확인하는 방향으로 바꾸기로 했다.

```swift
.onAppear {
   if favoriteViewModel.names.contains(user.login){
         isFavorite = true
   }
}
```

잘되는걸 알 수 있다.

<img width="302" height="630" alt="Image" src="https://github.com/user-attachments/assets/6963a6f5-4b72-40ca-846e-fb4e20d196c4" />{: width="50%" height="50%"}

---

### 2. 즐겨찾기 목록 누적 관리하기 + 바로저장하기

1. 기존에 즐겨찾기된 목록이라는 과거의 상태를 시스템이 기억하게 할 것
2. 새로운 추가/삭제 이벤트가 들어올 때마다 과거의 배열과 결합하여 **최신화된 전체 목록을 지속적으로 산출(누적)**해 낼 것
3. 누적 계산되어 갱신된 최신 즐겨찾기 목록 데이터가 스트림의 끝에 도달할 때마다, 즉각적으로 기기 내부 저장소에 덮어씌워 **앱을 껐다 켜도 상태가 유실되지 않게** 막을 것

이건 하나로 합치는게 나아서 묶어서 한다. 근데 사실이미 위에서 다했던 부분도 있다.
---

#### 1, 과거의 상태를 기억하게 하기
이건 ViewModel에서 init을 할때 값을 UserDefault의 값을 가져오면 된다.

```swift
init () {
   if let savedArray = UserDefaults.standard.array(forKey: "FavoriteNames") as? [String] {
      names = savedArray
   }
   
   // 생략
}
```

이건 [이전글](https://haroldfromk.github.io/posts/Todoey-(2)/){:target="_blank"}에서 한번 한적이 있으므로, 읽어보면 좋을지도

---

#### 2. 추가/삭제 이벤트가 들어올 때마다 과거의 배열과 결합하기 + 최신화

이부분은 2, 3의 조건을 묶어서 정리한다.

처음에 위에서 viewmodel을 만들때 이미 구현이 되었다.

```swift
init () {
   // 생략
   
   addSubject
      .receive(on: DispatchQueue.main)
      .sink { id in
      self.names.append(id)
      UserDefaults.standard.set(self.names, forKey: "FavoriteNames")
   }.store(in: &cancellables)
   
   removeSubject
      .receive(on: DispatchQueue.main)
      .sink { id in
            self.names.removeAll { $0 == id }
      UserDefaults.standard.set(self.names, forKey: "FavoriteNames")
   }.store(in: &cancellables)
}
```

여기 코드에 모든게 담겨있다.

추가/삭제 관리는 여기서 관리를 하고 있고
```swift
names.append(id)
names.removeAll { $0 == id }
```
배열의 상태 업데이트를 하자마자 `UserDefaults.standard.set(self.names, forKey: "FavoriteNames")`를 통해 로컬 저장소 업데이트를 한다.

### FavoriteView에 연결하기

```swift
@StateObject private var viewModel = FavoriteViewModel()

ForEach(viewModel.names, id: \.self) { user in
      NavigationLink(value: user) {
         FavoriteRow(login: user)
      }
}
.onDelete { indexSet in
        viewModel.removeToFavorite(id: viewModel.names[indexSet.first!])
                            viewModel.names.remove(atOffsets: indexSet)
}
```

indexset이 생소해서 내용을 정리한다.

#### IndexSet이란?

`.onDelete`를 쓰다 보면 `IndexSet`이 나온다.

```swift
.onDelete { indexSet in
    items.remove(atOffsets: indexSet)
}
```

UIKit에서는 `indexPath.row` 하나로 삭제했는데, SwiftUI는 왜 `IndexSet`을 쓰는 걸까?

둘 다 본질은 **배열 위치 기반 삭제**로 같다. 차이는 `IndexSet`이 여러 위치를 한 번에 담을 수 있다는 것.

```swift
IndexSet([0, 2])  // 0번, 2번 동시 삭제 가능
```

SwiftUI는 swipe delete, edit mode 다중 선택 삭제 같은 상황을 내부적으로 처리해서 `IndexSet`으로 전달해준다. 개발자는 그냥 받아서 `remove(atOffsets:)`만 하면 된다.

그리고 `IndexSet`은 데이터가 아니라 **위치 정보**만 담는다. 또한 내부적으로 정렬되어 있어서 선택 순서는 유지되지 않는다.

시뮬레이터를 통해 간단하게 비교를 해보도록 했다.

<iframe
    src="/assets/demo/indexset-simulator.html"
    width="100%"
    height="720"
    style="
        border:none;
        border-radius:16px;
        overflow:hidden;
    ">
</iframe>

무튼 실을 하면 이렇게

<img width="50%" height="50%" alt="Image" src="https://github.com/user-attachments/assets/ef38a113-feb5-44ba-a2b1-095b8f433818" />

잘 되는걸 알 수 있다. (삭제부분 이미지는 생략)

---

#### 수정

생각해보니 

```swift
viewModel.removeToFavorite(id: viewModel.names[indexSet.first!])
viewModel.names.remove(atOffsets: indexSet)
```

삭제 코드 중복이 있다.

removeSubject 에서 이미 삭제를 하기 때문, 그래서 코드를 지워준다.

```swift
.onDelete { indexSet in
   indexSet.forEach { index in
      viewModel.removeToFavorite(id: viewModel.names[index])
   }
}

.onDelete { indexSet in
   if let index = indexSet.first {
      viewModel.removeToFavorite(id: viewModel.names[index])
   }
}
```

둘중에하나 아무거나 쓰면 된다.

근데 swipe delete는 한 번에 하나라서 `if let index = indexSet.first` 방식이 더 적합하다.

만약에 뭐 edit모드를 해서 여러개를 체크해서 삭제해야하는 상황이 온다면

그땐 `forEach`를 사용하도록 하자.

#### UIUpdate

현재 FavoriteViewModel 객체가 ProfileView, FavoriteView에나뉘어 있어서 값이 공유가 안되고 있다.
(이후에 해결할 예정 -> 의존성 주입)

그래서 임시로

```swift
func reloadData() {
   if let savedArray = UserDefaults.standard.array(forKey: "FavoriteNames") as? [String] {
      names = savedArray
   }
}

.onAppear {
      viewModel.reloadData()
}
```

UserDefaults의 값을 가져오는식으로 했다.

---

Day 3 끝 이번엔 글이 생각보다 짧다.