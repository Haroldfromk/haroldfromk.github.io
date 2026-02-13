---
title: Async/Await (2)
writer: Harold
date: 2024-11-27 01:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## Async/Await를 사용하여 날짜 가져오기

강의 흐름에 따라 정리를 해본다.

먼저, Async/Await 패턴은 Swift의 비동기 프로그래밍을 더욱 효율적이고 직관적으로 만드는 패턴이다. 이 패턴의 주요 장점은 다음과 같다.

- **코드의 가독성 향상**: 비동기 코드를 동기 코드와 유사하게 작성할 수 있어 로직의 흐름을 쉽게 이해할 수 있다.  
- **콜백 지옥 해결**: 중첩된 콜백 대신 선형적인 코드 흐름을 사용하여 복잡한 비동기 로직을 간결하게 표현할 수 있다.  
- **에러 처리 용이**: `try`/`catch` 구문을 사용하여 비동기 작업에서 발생하는 에러를 효과적으로 처리할 수 있다.  

[출처](https://f-lab.kr/insight/understanding-async-await-in-swift){:target="_blank"} 

### 1. 기본 구성

우선 기본 코드는 다음과 같이 구성이 되어있다.

```swift
struct CurrentDate: Decodable, Identifiable {
    let id = UUID()
    let date: String
    
    private enum CodingKeys: String, CodingKey {
        case date = "date"
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            List(1...10, id: \.self) { index in
                Text("\(index)")
            }.listStyle(.plain)
            
            .navigationTitle("Dates")
            .navigationBarItems(trailing: Button(action: {
                // button action
            }, label: {
                Image(systemName: "arrow.clockwise.circle")
            }))
        }
    }
}
```

![CleanShot 2024-11-27 at 17 49 44](https://github.com/user-attachments/assets/d51cf51b-22df-4d65-a91e-d1c7fd67c75b){: width="50%" height="50%"} 

### 2. getDate 함수 만들기

함수를 하나 만들어준다.

```swift
private func getDate() async throws -> CurrentDate? {
   
   guard let url = URL(string: "https://ember-sparkly-rule.glitch.me/current-date") else {
      fatalError("URL is incorrect")
   }
   
   let (data, _) = try await URLSession.shared.data(from: url)
   return try? JSONDecoder().decode(CurrentDate.self, from: data)
}
```

#### 1. 과정 정리

이부분은 예전에 파이널 프로젝트할때도 에러뜨면 기본지식이 없어 그냥 Fix 클릭해서 해결했는데 이번엔 조금 정리를 하면서 진행해본다.

![CleanShot 2024-11-27 at 19 39 03](https://github.com/user-attachments/assets/af65fa02-102e-4e17-829b-08dd346d76f9)

URLSession으로 Network에 대한 코드를 작성하니 위와 같은 에러가 뜬다.

갑자기 concurrency를 지원하지 않는 함수에서 async 호출되었다고 한다?

하지만 코드를 봐도 async에 관한 부분은 코빼기도 찾을 수 없다.

![CleanShot 2024-11-27 at 19 42 29](https://github.com/user-attachments/assets/7e7fdf8d-94cb-4f42-98fc-67d6c69c37b0)

바로 우리가 자주썼지만 이렇게 까지 확인하면서 쓰지는 않아서 몰랐을 뿐 여기에 있었다.

그러므로 getDate 함수 역시도 async를 사용하여 비동기 함수라는걸 알려주자.

![CleanShot 2024-11-27 at 19 44 12](https://github.com/user-attachments/assets/10518c2c-a560-4d0d-a245-064448598c83)

이렇게 하고나니 뜨는 에러 throw를 호출 할 수 있지만 try가 없어 에러에 대한 핸들링이 안된다고 한다.

그리고 두번째 에러코드는 async를 사용했으나 await가 없다는것.

await는 간단하게 말하면 결과를 기다린다 라고 보면 된다.

즉, 여기서는 `await URLSession.shared.data(from: url)` 인데, 네트워크 통신한것에 대한 결과를 기다린다. 라고 보면 된다.

>**async와 await** 한쌍이다.

---

그렇다면 async는 무엇인가?

[참고글1](https://www.hackingwithswift.com/quick-start/concurrency/what-is-an-asynchronous-function){:target="_blank"}와 [참고글2](https://www.avanderlee.com/swift/async-await/){:target="_blank"} 를 보고 정리를 해본다면.

`async`는 함수 타입의 하나이다.
- async를 사용함으로써 비동기 함수를 만들 수 있다.

---

다시 돌아와서

![CleanShot 2024-11-27 at 19 50 13](https://github.com/user-attachments/assets/28a72755-cd8b-4649-bff4-12503b61b800)

throw를 호출할 수 있고, try를 사용하지 않아 에러에 대한 핸들링을 할 수 없다는것

그리고 URLSession의 경우엔 예외를 던질 수(throw) 있는데,

에러를 던진다 즉 핸들링 하기위해선 try가 필요하다. 그래서 위와 같이 에러가 뜨는 것.

![CleanShot 2024-11-27 at 19 53 07](https://github.com/user-attachments/assets/50c7bc99-0c77-4949-bb86-e03be8b98771)

여기서 에러가 던져지자만 핸들링이 아직 안된다고 한다.

그래서 에러를 던지기 위해서 throw를 사용해주는 것이다.

throw가 붙은 함수를 보통 throwing 함수라하는데, 함수 내부에서 에러를 던져서 함수가 호출된 곳으로 전달을 한다.

그다음 부터는 Decoding 부분이라 패스.

그렇다면 이런생각도 해볼 수 있다.

```swift
private func getDate() async -> CurrentDate? {
   guard let url = URL(string: "https://ember-sparkly-rule.glitch.me/current-date") else {
      fatalError("URL is incorrect")
   }
   do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return try JSONDecoder().decode(CurrentDate.self, from: data)
   } catch {
      fatalError()
   }
}
```

이렇게 throw를 사용하지 않고 코드를 작성하면??

우선 빌드를 해도 컴파일링에는 문제가 없다.

하지만 이것에 대한 결과는 다음 함수를 만들고 난 후에 서술.

### 3. populateDates 함수 만들기

그리고 getDate를 호출 하고 데이터를 배열에 추가하는 새로운 함수를 만들어 준다.

```swift
private func populateDates() async {
    do {
        guard let currentDate = try await getDate() else {
            return
        }
        currentDates.append(currentDate)
    } catch {
        print("Error fetching date: \(error.localizedDescription)")
    }
}
```

#### 1. 과정 정리

![CleanShot 2024-11-27 at 18 03 16](https://github.com/user-attachments/assets/17d86942-ebe6-48c4-bf88-05f6dacd234a)

이렇게 처음에 만들게 되면 에러가 발생
- async를 사용한 이유: getDate가 async로 정의되어 있으므로 populateDates도 async로 선언한다.

![CleanShot 2024-11-27 at 18 04 45](https://github.com/user-attachments/assets/273b757d-1849-4306-a5fa-2a9d5195e953)

두번째 에러는 위에서도 언급 했으니 패스.

await를 해주자

![CleanShot 2024-11-27 at 19 28 23](https://github.com/user-attachments/assets/df54e635-8c04-4481-9a6f-409e521d10d7)

getDate에서 throw를 사용하여 예외사항(error 등)을 처리하므로 try를 사용

![CleanShot 2024-11-27 at 19 31 46](https://github.com/user-attachments/assets/c045b921-3f1b-457a-b449-9cf1be936d10)

try를 썼지만 에러에 대한 핸들링이 없다.

이분을 해결하기 위해 do ~ catch 를 사용해준다.

그리고선 나머지는 작성해주면 끝.

물론

```swift
private func pupulateDates() async {
   let currentData = await getDate()
   self.currentDates.append(currentData!)
}
```

이렇게 작성도 되지만 이건 currentData 가 무조건 값이 있다는것과 예외사항이 아예 없다라고 확신한 상태에서 하는경우라 에러에 대한 핸들링이 없기에 상당히 위험한 코드이다.

아까 위에서 getDate를 throw 대신 do ~ catch를 사용했을때의 경고문구가 나오고 있다.

![CleanShot 2024-11-27 at 20 04 03](https://github.com/user-attachments/assets/faeba9ad-f35f-48bc-9c61-2f9be8b46b6c)

우선 문제의 원인은 try 키워드가 사용되었지만, 해당 코드에서 호출된 함수가 **throws**로 선언되지 않았기 때문에 발생한다.

즉, populateDates함수가 getDate함수를 호출하기에 getDate에서의 Exception을 populateDates함수가 받는데 그것에 대해서 do ~ catch를 통해 핸들링을 하는데 지금은 throws가 없는데 그것에 대한 에러 핸들링을 하려고 해서 뜬 경고

### 4. 호출 결과를 보여주기

![CleanShot 2024-11-27 at 20 15 11](https://github.com/user-attachments/assets/9501cf03-8a27-4563-b4f8-3423390770b7)

`onAppear`를 통해 View가 렌더링 될때 함수를 작동하게 하려고 한다.

하지만 onAppear는 async함수가 아니다.

물론 Udemy강의 이전에 어떻게 하는지 알고는 있으나, 여기서는 서술하지 않고 강의의 흐름 그대로를 따라간다.

이것을 해결하기 위한 방법이 있는데,

바로 Task Modifier를 사용하는 것이다.

![CleanShot 2024-11-27 at 20 16 44](https://github.com/user-attachments/assets/dbaa2e5c-5284-45ac-a9ed-56be26ac5f6f)

async가 있음을 알 수 있다.

![CleanShot 2024-11-27 at 20 17 56](https://github.com/user-attachments/assets/d13c9721-76a8-4c38-bda6-ef5d782e6368)

이렇게 함수를 호출하면 async함수이기에 await가 필요하다고 하므로 적어주자.

그리고 실행하기전에 

```swift
List(1...10, id: \.self) { index in
      Text("\(index)")
}.listStyle(.plain)
```

이 부분을 수정해주자.

지금은 1~10이 필요가 없다.

```swift
List(currentDates) { currentDate in
      Text(currentDate.date)
}.listStyle(.plain)
```

통신 결과에 대한 값을 바로 list에 보여주는 식으로 한다.

![simulator_screenshot_B0A18628-2BA2-45C1-AFE8-059126684C65](https://github.com/user-attachments/assets/40e808fb-76b0-49f8-b34e-5a8c87aa1255){: width="50%" height="50%"} 

잘 나오는걸 알 수 있다.

### 5. refresh 적용하기

지금은 앱이 실행되면 바로 호출이 된다.

새롭게 갱신을 하고싶은데 지금은 그런 기능이 없으니 refresh가 되도록 해보자.

![CleanShot 2024-11-27 at 20 23 46](https://github.com/user-attachments/assets/3ffc45d9-17d4-4a4c-a9c4-5d4422c296d9)

함수를 호출하니 역시나 또 발생하는 에러

![CleanShot 2024-11-27 at 20 24 31](https://github.com/user-attachments/assets/e2934302-91e7-4865-a46a-b4bff834c63b)

Button에 대한 action에 대한 설명이다.

async는 없다.

async 클로저를 사용하면된다 (지금은 Deprecated 되었다.)

![CleanShot 2024-11-27 at 20 26 08](https://github.com/user-attachments/assets/4e023241-7a8f-4ca9-97cf-9b34598acd6d)

Task를 사용해주면 된다.

그리고 async 와 await는 한쌍이나 await를 적어주고 실행해보자.

![Nov-27-2024 20-27-48](https://github.com/user-attachments/assets/e3be1b1d-3d74-4478-ba0e-7f830cbe160c){: width="50%" height="50%"} 

잘 된다.