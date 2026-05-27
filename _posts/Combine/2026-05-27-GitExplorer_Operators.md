---
title: GitExplorer Operators
writer: Harold
date: 2026-05-18 08:06
categories: [Combine]
tags: [Combine]
published: false

toc: true
toc_sticky: true
---

# 실무에서 숨 쉬듯이 쓰는 Combine 오퍼레이터

Combine에는 수백 개의 오퍼레이터가 있지만, 실제 iOS 현업에서 매일같이 쓰는 핵심 오퍼레이터는 정해져 있다.
개념만 나열하기보다는 **"실무에서 이 오퍼레이터를 왜 써야만 하는가?"**에 초점을 맞춰 카테고리별로 정리해 본다.

> **💡 참고: `sink`와 `assign`은 오퍼레이터인가?**
> 엄밀히 말해 이 둘은 데이터를 변환하는 '오퍼레이터(Operator)'가 아니라, 파이프라인의 끝에서 데이터를 소비하는 **'구독자(Subscriber)'**다. 하지만 실무에서는 파이프라인을 조립하는 필수 블록으로 함께 묶어서 이해하는 것이 훨씬 직관적이다.

---

## 1. 스트림 전환 및 변환 (Transformation)

데이터의 형태를 바꾸거나, 사용자의 액션을 네트워크 요청으로 전환할 때 사용하는 가장 기본적인 오퍼레이터들이다.

### `map`
**실무 목적:** 서버에서 내려온 Raw 데이터(JSON 모델)를 화면에 그리기 편한 View 데이터 모델로 껍데기를 바꿀 때 숨 쉬듯이 사용한다.

```swift
service.fetchUser(login: "harold")
    .map { user in
        UserViewModel(name: user.login, bio: user.bio ?? "")
    }
    .sink { print($0) }
    .store(in: &cancellables)
```

---

### `compactMap`
**실무 목적:** `map`과 비슷하지만 `nil`을 자동으로 걸러준다. 옵셔널 처리할 때 `map` + `filter { $0 != nil }` 콤보 대신 이걸 하나로 쓴다.

```swift
$searchText
    .compactMap { text -> String? in
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
    .sink { print("유효한 검색어: \($0)") }
    .store(in: &cancellables)
```

---

### `flatMap` ⭐️
**실무 목적:** 사용자의 '버튼 클릭'이나 '검색어 입력' 같은 단순 이벤트를, 실제 서버 API를 호출하는 **'새로운 비동기 네트워크 스트림'**으로 바꿔치기(전환)할 때 무조건 사용한다.

```swift
$searchText
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .flatMap { username in
        GithubService.shared.searchUsers(query: username)
            .catch { _ in Just([]) }
    }
    .sink { users in print(users) }
    .store(in: &cancellables)
```

---

### `switchToLatest`
**실무 목적:** `flatMap`과 비슷하게 스트림을 전환하는데, 새 이벤트가 오면 이전 스트림을 **자동으로 취소**한다. 검색에서 이전 요청을 확실하게 버리고 싶을 때 `flatMap` 대신 쓴다.

```swift
$searchText
    .map { username in
        GithubService.shared.searchUsers(query: username)
            .catch { _ in Just([]) }
    }
    .switchToLatest()
    .sink { users in print(users) }
    .store(in: &cancellables)
```

---

### `scan`
**실무 목적:** 누적 계산이 필요할 때 쓴다. 장바구니 합계, 좋아요 카운트, GPS 누적 거리처럼 이전 값과 새 값을 합쳐서 계속 업데이트해야 하는 상황에 적합하다.

```swift
favoriteAction
    .scan([GithubUser]()) { currentList, action in
        switch action {
        case .add(let user):
            return currentList + [user]
        case .remove(let user):
            return currentList.filter { $0.id != user.id }
        }
    }
    .sink { updatedList in print(updatedList) }
    .store(in: &cancellables)
```

<iframe
    src="/assets/demo/sim3_transform.html"
    width="100%"
    height="320px"
    frameborder="0"
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden;"
    title="map / compactMap / flatMap 시뮬레이터">
</iframe>

---

## 2. 노이즈 캔슬링 (Noise Cancelling)

사용자의 연타나 시스템 노이즈로부터 서버를 보호한다.

### `debounce`
**실무 목적:** 실시간 검색창에서 유저가 **타이핑을 멈출 때까지 기다렸다가** 단 한 번만 API를 쏘게 만들어, 무의미한 통신비를 절약하고 서버 과부하를 막는다.

```swift
$searchText
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .sink { print("최종 검색어: \($0)") }
    .store(in: &cancellables)
```

---

### `throttle`
**실무 목적:** `debounce`는 멈출 때까지 기다리고, `throttle`은 **일정 간격으로 한 번씩만** 통과시킨다. 버튼 연타 방지나 스크롤 이벤트 제어에 자주 쓴다.

```swift
refreshButton
    .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: false)
    .sink { print("새로고침 실행") }
    .store(in: &cancellables)
```

| | `debounce` | `throttle` |
|---|---|---|
| 동작 방식 | 이벤트가 멈추고 N초 뒤 통과 | N초 간격으로 한 번씩 통과 |
| 주요 용도 | 실시간 검색창 | 버튼 연타 방지 |
| 결과 | 마지막 값 | 첫 번째 또는 마지막 값 |

<iframe
    src="/assets/demo/sim2_debounce_throttle.html"
    width="100%"
    height="320px"
    frameborder="0"
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden;"
    title="debounce vs throttle 시뮬레이터">
</iframe>

---

## 3. 필터링 (Filtering)

조건에 맞지 않는 값을 걸러내는 수문장 역할을 한다.

### `filter`
**실무 목적:** 검색어가 2글자 이상인지, 값이 `nil`은 아닌지 등 조건에 맞지 않는 데이터를 하류로 못 내려가게 1차적으로 컷팅한다.

```swift
$searchText
    .filter { $0.count > 1 }
    .sink { print("2글자 이상: \($0)") }
    .store(in: &cancellables)
```

---

### `removeDuplicates`
**실무 목적:** SwiftUI `TextField`의 렌더링 버그나 유저의 실수로 완벽히 동일한 검색어가 연달아 들어왔을 때, 억울한 중복 네트워크 요청을 차단한다.

```swift
$searchText
    .removeDuplicates()
    .sink { print("중복 제거 후: \($0)") }
    .store(in: &cancellables)
```

<iframe
    src="/assets/demo/sim1_search_pipeline.html"
    width="100%"
    height="440px"
    frameborder="0"
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden;"
    title="검색 파이프라인 시뮬레이터">
</iframe>

---

## 4. 스레드 관리 (Scheduling)

UI 업데이트와 백그라운드 작업을 분리하여 앱이 멈추거나 크래시 나는 것을 방지한다.

### `receive(on:)`
**실무 목적:** 백그라운드 스레드에서 네트워크 통신이 끝난 뒤, **메인 스레드로 넘겨서 UI를 안전하게 업데이트**할 때 필수적으로 붙인다. 누락 시 보라색 에러와 크래시가 발생한다.

```swift
service.fetchUsers()
    .receive(on: DispatchQueue.main)
    .sink { users in
        self.users = users
    }
    .store(in: &cancellables)
```

---

## 5. 다중 데이터 퓨전 (Combining)

실무의 화면은 API 하나로 끝나지 않는다. 흩어져 있는 여러 데이터를 하나의 화면으로 조립할 때 사용한다.

### `combineLatest`
**실무 목적:** 프로필 정보, 팔로워 목록, 게시물 목록 등 **여러 개의 API 요청이 '전부 도착했을 때'** 비로소 화면을 한 번에 그리기 위해 타이밍을 맞춰 묶어주는 역할을 한다.

```swift
Publishers.CombineLatest3(
    service.fetchProfile(login: username),
    service.fetchRepos(login: username),
    service.fetchFollowers(login: username)
)
.map { profile, repos, followers in
    ProfileViewData(profile: profile, repos: repos, followers: followers)
}
.sink { data in print(data) }
.store(in: &cancellables)
```

---

### `merge`
**실무 목적:** 출처가 다른 여러 에러 스트림을 **'단일 파이프라인'**으로 합쳐서 일관성 있게 처리하고 싶을 때 사용한다.

```swift
Publishers.Merge(
    profileErrorPublisher.map { AppError.profile($0) },
    repoErrorPublisher.map { AppError.repo($0) }
)
.sink { error in
    self.errorMessage = error.localizedDescription
}
.store(in: &cancellables)
```

---

### `share`
**실무 목적:** 같은 Publisher를 여러 곳에서 구독할 때 **중복 네트워크 요청을 방지**한다.

```swift
let sharedPublisher = service.fetchUsers().share()

sharedPublisher
    .sink { self.users = $0 }
    .store(in: &cancellables)

sharedPublisher
    .map { $0.count }
    .sink { self.count = $0 }
    .store(in: &cancellables)
// 네트워크 요청은 단 한 번만 나감
```

<iframe
    src="/assets/demo/sim5_combining.html"
    width="100%"
    height="380px"
    frameborder="0"
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden;"
    title="combineLatest / merge 시뮬레이터">
</iframe>

---

## 6. 에러 방어벽 (Error Handling)

Combine 파이프라인은 에러를 만나면 즉시 영구 사망(종료)한다. 이 치명적인 약점을 막아주는 생명줄이다.

### `catch`
**실무 목적:** 에러가 발생했을 때 파이프라인이 죽는 것을 막고, 빈 배열(`[]`)이나 기본값 같은 **안전한 데이터(Fallback)로 대체**해서 다음 입력을 계속 대기할 수 있게 앱을 살려둔다.

```swift
$searchText
    .flatMap { username in
        service.searchUsers(query: username)
            .catch { _ in Just([]) }  // flatMap 안쪽 — 스트림 생존
    }
    .sink { users in self.users = users }
    .store(in: &cancellables)
```

<iframe
    src="/assets/demo/sim4_catch.html"
    width="100%"
    height="360px"
    frameborder="0"
    style="border-radius: 12px; border: 1px solid #444; overflow: hidden;"
    title="catch 위치 시뮬레이터">
</iframe>

---

### `retry`
**실무 목적:** 일시적인 네트워크 오류 발생 시, 유저에게 에러를 바로 보여주기 전에 지정한 횟수만큼 내부적으로 조용히 다시 요청을 시도한다.

```swift
service.searchUsers(query: username)
    .retry(2)
    .catch { _ in Just([]) }
    .sink { users in self.users = users }
    .store(in: &cancellables)
```
