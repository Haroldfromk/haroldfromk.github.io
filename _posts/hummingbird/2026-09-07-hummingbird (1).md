---
title: Hummingbird (1)
writer: Harold
date: 2026-09-07 11:06
categories: [Hummingbird]
tags: []

toc: true
toc_sticky: true
---

Udemy에 흥미로운 강의가 있어서 수강하면서 과정을 기록해보려고 한다.

[Hummingbird](https://hummingbird.codes/){:target="_blank"}는 Swift로 작성된 경량 REST API 프레임워크다. Vapor보다 가볍고 의존성이 적은 것이 특징이며, 라우팅부터 미들웨어, 인증, 데이터베이스 연동까지 백엔드 API 개발에 필요한 요소들을 지원한다. 무엇보다 iOS 개발자에게 익숙한 Swift 문법과 async/await 기반 동시성 모델을 그대로 사용할 수 있다는 점이 매력적이다.

---

## 설치

이전에는 git clone을 해서사용하는 방식이었으나 [Docs](https://docs.hummingbird.codes/2.0/documentation/hummingbird/gettingstarted/){:target="_blank"}를 보게되면 설치 방식이 바뀌었다.

이후 `hb init MyNewProject`을 하게되면 여러 선택지가 주어지는데

지금은 처음이라 기본세팅만했다.

1. Sever (Lambda는 ❌)
2. App Name: HelloBird (App name은 공백시 에러이므로 필수)
3. feature (여기서 3개가 뜨는데 그냥 아무거나 했다 지금 당장은 중요하지 않아서)

이후 해당 폴더로가서 `swift run`을 하고 기다린뒤

```text
info HelloBird: [HummingbirdCore] Server started and listening on 127.0.0.1:8080
```

이렇게 뜨고 해당 주소를 입력해보면 Hello! 라고 브라우저에 뜨는걸 알 수 있다. (사진은 생략)

---

## 구성

이제 터미널에서 서버를 중단하고(`Ctrl + C`), `open Package.swift`를 입력해서 프로젝트를 열어본다.

`Package.swift`를 열면 Xcode가 프로젝트 전체를 불러오면서 의존성을 다운로드하고 인덱싱한다. 이때 실행 대상은 반드시 **Mac**으로 선택해야 한다(서버는 로컬 머신에서 실행되므로 iPhone 시뮬레이터가 아님). 빌드가 성공하면 스타터 프로젝트의 파일 구성을 확인할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-15.49.png){: width="50%" height="50%"}

이렇게 구성이 되어있는 걸 알 수 있다.

---

### Package.swift 의존성

의존성은 두 가지가 잡혀있다.

```swift
dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
],
```

- **Hummingbird** - 프레임워크 본체니까 당연히 필요하다
- **swift-configuration** (Apple 제공) - 환경 변수, JSON, 커맨드라인 등 여러 소스에서 설정값을 읽어오는 패키지. `ConfigReader`와 여러 provider를 통해 동작한다

---

### 진입점: main 함수

`Sources` 폴더 안의 코드는 대부분 스타터 프로젝트가 자동으로 만들어준 것들이라, 커스텀 설정이 필요한 게 아니라면 굳이 건드릴 일은 없어 보인다.

가장 먼저 봐야 할 건 `main` 함수다. `async throws`로 선언되어 있는데, 설정을 세팅하는 과정에서 예외가 던져질 수도 있다는 뜻이다. 여기서 여러 provider를 가진 `ConfigReader`를 만드는데, provider마다 우선순위가 있다(위에서 아래로 우선순위가 높음).

```swift
@main
struct App {
    static func main() async throws {
        // Application will read configuration from the following in the order listed
        // Command line, Environment variables, dotEnv file, defaults provided in memory 
        let reader = try await ConfigReader(providers: [
            CommandLineArgumentsProvider(),
            EnvironmentVariablesProvider(),
            EnvironmentVariablesProvider(environmentFilePath: ".env", allowMissing: true),
            InMemoryProvider(values: [
                "http.serverName": "HelloBird"
            ])
        ])
        let app = try await buildApplication(reader: reader)
        try await app.runService()
    }
}
```

1. Command line
2. Environment variable
3. Env file
4. In-memory
5. Defaults

이렇게 만든 `reader`를 `buildApplication` 함수에 넘겨서 host, port, database URL 같은 설정값을 가져오고, 애플리케이션을 빌드해서 실행하는 흐름이다.

---

### buildApplication 함수

`App+Build`에 정의되어 있고, 하는 일은 대략 이렇다.

```swift
func buildApplication(reader: ConfigReader) async throws -> some ApplicationProtocol {
    let logger = {
        var logger = Logger(label: "HelloBird")
        logger.logLevel = reader.string(forKey: "log.level", as: Logger.Level.self, default: .info)
        return logger
    }()
    let router = try buildRouter()
    let app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    return app
}
```

- `config`를 받아서 `Logger` 생성
- `RequestContext` 생성. 요청마다 생성되는 컨텍스트 객체인데, 지금은 기본 제공되는 basic context를 쓰고 있다. 나중에 인증된 사용자, request ID, DB 커넥션 같은 걸 담고 싶으면 커스텀 컨텍스트로 확장하면 된다
- `Router` 생성. 라우트/엔드포인트를 정의하는 곳
- 이걸 다 조합해서 `Application` 객체를 만들고 반환

반환된 `Application` 객체는 `runService()`로 서비스를 시작한다.

---

### buildRouter 함수

앞으로 제일 많이 만지게 될 부분인 것 같다. 라우트를 추가하고 미들웨어를 등록하는 곳인데, 스타터 프로젝트에는 `hello` 라우트 하나만 정의되어 있다. `127.0.0.1:8080`에 접속했을 때 "hello"가 뜬 이유가 이거였다.

```swift
func buildRouter() throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    // Add default endpoint
    router.get("/") { _,_ in
        return "Hello!"
    }
    return router
}
```

---

## 코드 변경이 자동으로 반영되지 않는 문제

`hello`를 `hello world`로 바꾸고 새로고침해봤는데 반영이 안 된다. 알고 보니 Hummingbird 서버는 파일이 바뀌어도 알아서 재시작해주지 않는다. 그래서 반영하려면 이렇게 해야 한다.

```
Control-C   # 서버 중지
swift run   # 서버 재시작
```

근데 코드 고칠 때마다 매번 이렇게 중지하고 다시 켜는 건 너무 귀찮다. Node.js의 `nodemon`처럼 파일이 바뀌면 알아서 서버를 재시작해주는 도구가 있으면 좋을 텐데, Hummingbird에서는 `watchexec`라는 도구로 이 문제를 해결한다고 한다.

---

## watchexec으로 자동 재시작 설정하기

이제 파일 바꿀 때마다 서버 껐다 켰다 하는 문제를 해결해보자. 쓸 수 있는 도구가 
[watchexec](https://github.com/watchexec/watchexec){:target="_blank"}라는 패키지다. 

Hummingbird랑 딱히 관련은 없고, 그냥 독립적인 도구다. 경로를 감시하다가 변경이 감지되면 지정한 커맨드를 실행해주는 심플한 Stand alone Tool이라고 한다. 딱 우리가 원하는 동작이다. Swift 파일이 수정될 때마다 서버를 재시작하는 것.

---

### 설치

brew로 설치하면 된다.

```
brew install watchexec
```

brew가 없다면 brew.sh에서 설치 커맨드를 받아서 먼저 brew부터 설치해야 한다. brew는 macOS용 패키지 매니저다. watchexec 설치는 한 번만 해주면 된다.

---

### 실행

설치가 끝나면 이렇게 실행한다.

```
watchexec -e swift --restart swift run
```

Swift 확장자를 가진 파일들을 감시하다가, 변경이 감지되면 `swift run`으로 재시작하라는 뜻이다.

실행하면 서버가 시작되면서 `localhost:8080`에 접속하면 Hello World가 뜬다. 여기서 코드를 수정하고 저장하면 watchexec가 바로 감지해서 서버를 자동으로 재시작해준다. 새로고침만 하면 바뀐 내용이 바로 반영된다.

---

## Custom Route 만들기

route는 buildRouter 함수 안에서 원하는 만큼 자유롭게 추가할 수 있다. 직접 몇 개 만들어보면서 어떻게 동작하는지 살펴본다.

---

### 기본 root Route

```swift
router.get("/") { _,_ in
    return "Hello World!!!"
}
```

`buildRouter` 함수 안에 이미 하나 있는 route가 바로 root route다. `/`로 시작해서 `/`로 끝나는, 그러니까 애플리케이션의 root를 뜻한다(`abc.com`, `xyz.com` 같은 도메인 자체). 서버 켜놓고 접속해보면 `1, 2, 3, 4`가 그대로 반환되는 걸 확인할 수 있다.

---

### Route 추가하기

route는 원하는 만큼 추가할 수 있다. 나중엔 `buildRouter` 함수에서 route들을 따로 분리하겠지만, 배우는 단계에서는 일단 여기다 몰아서 작성해도 괜찮다고 한다.

```swift
router.get("/movies") { request, context in
    "Lord of the Rings"
}
```

`request`, `context` 두 개가 클로저로 넘어온다. `request`는 클라이언트에서 온 요청 객체고, `context`는 데이터베이스나 인증 정보 같은 걸 담을 수 있는 context다.

`/movies`로 가보면 "Lord of the Rings"가 반환된다. 리턴 타입은 따로 명시 안 해도 Swift가 알아서 String으로 추론해준다.

배열도 그대로 반환할 수 있다.

```swift
router.get("/movies") { request, context in
    ["Lord of the Rings", "Finding Nemo", "Inception"]
}
```

반환하는 값은 `Decodable`을 만족해야 하는데, String이나 배열 같은 기본 타입들은 이미 Decodable이라 별도 작업이 필요 없다. 다만 지금 반환하는 건 JSON이 아니라 그냥 문자열 배열이다. 구조화된 JSON을 반환하는 방법은 나중에 다룰 예정.

---

### Route Parameter

영화 장르별로 route를 나누고 싶다면? `horror`, `kids`, `action`처럼 장르마다 따로 route를 만드는 대신, route parameter(`:`)를 쓰면 된다.

```swift
router.get("/movies/:genre") { request, context in
    guard let genre = context.parameters.get("genre", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    return "The genre is \(genre)"
}
```

여기서 `:genre`는 route 경로에 선언해두는 parameter 이름이다(이름은 마음대로 지어도 된다). 그리고 `context.parameters.get("genre", as: String.self)`는 그 경로에서 `genre`라는 이름으로 들어온 값을 꺼내오면서, 동시에 String 타입으로 변환해서 가져오라는 뜻이다. 이 변환이 실패하면(=String으로 못 바꾸면) `guard`에 걸려서 bad request를 던진다.

`:genre` 부분에 `fiction`, `kids`, `action` 등 뭐가 오든 매칭되고, `context.parameters.get`으로 값을 꺼내면서 타입도 지정할 수 있다(`String`으로 안 들어오면 bad request를 던지는 식). 숫자를 넣어도 문자열로 변환되니 문제없이 들어온다.

route parameter는 여러 개도 가능하다.

```swift
router.get("movies/:genre/year/:year") { request, context in
    guard let genre = context.parameters.get("genre", as: String.self),
          let year = context.parameters.get("year", as: Int.self) else {
        throw HTTPError(.badRequest)
    }
    return "Genre is \(genre), year is \(year)"
}
```

이렇게 하면 `/movies/horror/2026` 같은 URL로 접속했을 때 genre는 "horror", year는 2026으로 각각 추출된다. 연도마다 route를 따로 만드는 건 현실적으로 불가능하니까, 이럴 때 route parameter가 진짜 유용하다.

---

## JSON으로 return하기

지금까지 만든 route들은 전부 string을 반환했는데, 실제 애플리케이션에서는 iOS든 Android든 웹 클라이언트든 구조화된 데이터를 받는 게 훨씬 낫다. 백엔드에서는 이 구조화된 데이터를 JSON으로 표현한다.

---

### Model 만들기

지금까지 만든 route들은 전부 string을 반환했는데, 실제 애플리케이션에서는 iOS든 Android든 웹 클라이언트든 구조화된 데이터를 받는 게 훨씬 낫다. 백엔드에서는 이 구조화된 데이터를 JSON으로 표현한다.

Model은 원래 별도 파일로 분리하는 게 맞지만, 일단 간단하게 같은 파일에 만들어본다.

```swift
struct Movie {
    let id: Int
    let name: String
    let year: Int
}

extension Movie: ResponseEncodable, Decodable, Equatable {
    
}
```

`ResponseEncodable`, `Decodable`, `Equatable`을 채택해야 route에서 바로 반환할 수 있다.

배열도 만들어서(하드코딩으로 10개 정도, ChatGPT로 만들어도 무방하다고 한다) route에서 그냥 반환하면 끝이다.

```swift
let movies: [Movie] = [
    Movie(id: 1, name: "The Shawshank Redemption", year: 1994),
    Movie(id: 2, name: "The Godfather", year: 1972),
    Movie(id: 3, name: "The Dark Knight", year: 2008),
    Movie(id: 4, name: "Pulp Fiction", year: 1994),
    Movie(id: 5, name: "Forrest Gump", year: 1994),
    Movie(id: 6, name: "Inception", year: 2010),
    Movie(id: 7, name: "The Matrix", year: 1999),
    Movie(id: 8, name: "Interstellar", year: 2014),
    Movie(id: 9, name: "Parasite", year: 2019),
    Movie(id: 10, name: "Gladiator", year: 2000)
]

router.get("/movies") { request, context in
    movies
}
```

Hummingbird가 알아서 JSON으로 변환해서 클라이언트한테 보내준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.00.png){: width="50%" height="50%"}

---

### 특정 movie 하나만 반환하기

movie ID로 특정 영화 하나만 조회하고 싶다면 이런 식으로 route를 추가한다.

```swift
router.get("/movies/:movieID") { request, context in
    guard let movieID = context.parameters.get("movieID", as: Int.self) else {
        throw HTTPError(.badRequest)
    }
    guard let movie = movies.first(where: { $0.id == movieID }) else {
        throw HTTPError(.badRequest)
    }
    return movie
}
```

movieID를 parameter로 꺼내면서 Int로 변환하고, 못 찾으면 bad request를 던진다.

---

### Route 충돌 문제

빌드는 잘 됐는데 서버를 실행하니 fatal error가 나면서 죽어버렸다. 

```bash
💣 Program crashed: System trap at 0x000000019af94d04

Platform: arm64 macOS 26.6.2 (25G83)

Thread 1 crashed:

  0 Router.buildResponder() + 664 in HelloBird at /Users/dongik/Documents/Workspace/Hummingbrid/HelloBird/.build/checkouts/hummingbird/Sources/Hummingbird/Router/Router.swift:57:13

    55│             try self.validate()
    56│         } catch {
    57│             assertionFailure("\(error)")
      │             ▲
    58│         }
    59│         #endif

  1 buildApplication(reader:) + 584 in HelloBird at /Users/dongik/Documents/Workspace/Hummingbrid/HelloBird/Sources/App/App+build.swift:41:15

    39│     }()
    40│     let router = try buildRouter()
    41│     let app = Application(
      │               ▲
    42│         router: router,
    43│         configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),

  2 static App.main() in HelloBird at /Users/dongik/Documents/Workspace/Hummingbrid/HelloBird/Sources/App/App.swift:18

    16│             ])
    17│         ])
    18│         let app = try await buildApplication(reader: reader)
      │         ▲
    19│         try await app.runService()
    20│     }

...

Backtrace took 0.82s

[Command killed by Custom(5)]
```


원인은 route 충돌이었다. `/movies/:genre`, `/movies/:movieID` 같은 dynamic parameter를 쓰는 route들이 같은 경로 depth에 여러 개 있으니까, Hummingbird 입장에서는 `/movies/뭔가`가 왔을 때 어떤 route로 매칭해야 할지 헷갈려버리는 거다.

해결 방법은 route 경로를 좀 더 구체적으로 나눠주는 것. 예를 들면 genre route는 `/movies/genre/:genre` 이런 식으로 앞에 고정된 segment를 붙여서, movie ID route(`/movies/:movieID`)와 겹치지 않게 만들어주면 된다. 

```swift
router.get("/movies/genre/:genre") { request, context in
    // 생략
}

router.get("movies/genre/:genre/year/:year") { request, context in
    // 생략
}
```


이렇게 하니까 서버가 정상적으로 돌아갔다.

`/movies`로 전체 목록을 확인하고, movie ID 3번(다크나이트)으로 조회해봐도 정상적으로 해당 movie 하나만 잘 반환된다.

---

## POST Request 만들기

지금까지는 GET route만 다뤘는데, 이번엔 클라이언트가 데이터를 보내서 서버에 추가할 수 있도록 POST route를 만들어본다.

---

### POST Route 기본 구조

`router.post`로 movies에 대한 POST route를 만든다.

```swift
router.post("/movies") { request, context in
    
    return ""
}
```

클라이언트가 보낼 body는 movie의 JSON 표현(id, name, year)이라고 가정한다. 그러면 request를 Movie로 decode해야 하는데, `request.decode`가 async 함수라서 클로저 자체를 `async throws`로 바꾸고 `try await`으로 받아야 한다.

```swift
router.post("/movies") { request, context async throws in
    let movie = try await request.decode(as: Movie.self, context: context)
    return movie
}
```

---

### movies 배열에 추가하려다 막힌 이유

decode한 movie를 기존 `movies` 배열에 `append`하면 될 것 같지만, `movies`가 `let`이라 애초에 append가 안 된다. 

```swift
router.post("/movies") { request, context async throws in
    let movie = try await request.decode(as: Movie.self, context: context)
    movies.append(movie)
    
    return movie
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.10.png){: width="50%" height="50%"}

그럼 `var`로 바꾸면 되지 않을까 싶은데, 이번엔 concurrency 에러가 난다. non-isolated global shared mutable state라서 안전하지 않다는 것.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.11.png){: width="50%" height="50%"}

`buildRouter` 함수 안으로 옮겨서 지역 변수로 만들어보려고 해도, 동시에 실행되는 코드에서 참조를 캡처한다는 에러가 또 발생한다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.12.png){: width="50%" height="50%"}

결국 지금 방식으로는 전역 mutable 배열에 안전하게 추가할 방법이 없다는 뜻이다.

이 문제는 `actor` 기반의 movie store를 만들어야 해결되는데, 일단 여기서는 넘어가고 다음 강의에서 다룬다고 한다. 지금은 decode한 movie를 그대로 return만 해서, 요청이 잘 들어오고 잘 디코딩됐는지만 확인한다.

```swift
router.post("/movies") { request, context async throws in
    let movie = try await request.decode(as: Movie.self, context: context)
    //movies.append(movie)
    
    return movie
}
```

---

### Postman으로 테스트하기

GET request는 브라우저 주소창에 URL만 치면 되지만, POST request는 그렇게 안 된다. Postman 같은 도구를 쓰면 된다(무료로 다운로드 가능, 앱 버전도 있음).

1. Method를 POST로 변경
2. URL은 `/movies`
3. Header에 `Content-Type: application/json` 추가 (서버한테 JSON을 보낸다고 알려주는 것)
4. Body에 id, name, year를 담아서 전송

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.19.png){: width="50%" height="50%"}

서버 쪽에 이미 Movie라는 타입이 있어서 body를 그대로 매핑/decode할 수 있는 것. 실제로 요청을 보내보면 보낸 것과 동일한 movie가 그대로 응답으로 돌아온다. decode가 정상적으로 동작한다는 뜻이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.191.png){: width="50%" height="50%"}

---

## Actor로 MovieStore 만들기

movie를 추가하는 방법은 여러 가지가 있지만, 방금 본 것처럼 movies 배열에 그냥 append하려는 시도는 concurrency 문제로 막혔다. 여기서는 그 문제를 해결하는 방법 중 하나인 actor를 써본다.

---

### concurrency-safe하게 movies 관리하기

`movies` 배열에 새 movie를 추가하려면 방법이 여러 개 있지만, 가장 직접적인 방법인 `let`을 `var`로 바꾸고 append하는 건 이전에 본 것처럼 concurrency 에러 때문에 막혔다. 전역으로 공유되는 mutable state라 안전하지 않기 때문이다.

이걸 해결하는 방법 중 하나가 `actor`를 쓰는 것이다. actor로 만들면 concurrency-safe해진다.

```swift
actor MovieStore {
    private(set) var movies: [Movie] = [
        Movie(id: 1, name: "The Shawshank Redemption", year: 1994),
        Movie(id: 2, name: "The Godfather", year: 1972),
        Movie(id: 3, name: "The Dark Knight", year: 2008),
        Movie(id: 4, name: "Pulp Fiction", year: 1994),
        Movie(id: 5, name: "Forrest Gump", year: 1994),
        Movie(id: 6, name: "Inception", year: 2010),
        Movie(id: 7, name: "The Matrix", year: 1999),
        Movie(id: 8, name: "Interstellar", year: 2014),
        Movie(id: 9, name: "Parasite", year: 2019),
        Movie(id: 10, name: "Gladiator", year: 2000)
    ]
}
```

`movies`를 `private`으로 두면 외부에서 아예 접근을 못 하니까, `private(set)`으로 바꿔서 읽기는 가능하되 외부에서 직접 변경은 못 하게 만든다.

기존에 전역으로 있던 `movies` 배열은 지우고, MovieStore 인스턴스를 하나 만들어서 그걸로 대체한다.

```swift
let movieStore = MovieStore()
```

---

### async/await로 접근하기

이제 `movies`에 접근하는 모든 곳에서 `movieStore.movies`로 바꿔줘야 하는데, actor라서 access가 async/await을 요구한다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.49.png.png){: width="50%" height="50%"}

그래서 route 클로저들을 `async throws`로 바꾸고, `movieStore.movies`에 접근할 때마다 `await`을 붙여준다.

```swift
router.get("/movies") { request, context async in
        await movieStore.movies
    }

router.get("/movies/:movieID") { request, context async throws in
    guard let movieID = context.parameters.get("movieID", as: Int.self) else {
        throw HTTPError(.badRequest)
    }
    guard let movie = await movieStore.movies.first(where: { $0.id == movieID }) else {
        throw HTTPError(.badRequest)
    }
    return movie
}
```

이렇게 하면 한 번에 하나의 요청만 movies에 접근할 수 있고, 나머지는 대기하게 된다.

---

### add 메서드로 캡슐화하기

POST route에서 `movieStore.movies.append(...)`를 바로 시도해도 안 되는데, `private(set)`으로 선언했기 때문에 movies를 바꿀 수 있는 건 MovieStore 자기 자신뿐이기 때문이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.52.png){: width="50%" height="50%"}

그래서 외부에서 직접 변경하는 대신, MovieStore 안에 `addMovie` 같은 함수를 만들어서 그 함수를 통해서만 추가하도록 한다.

```swift
actor MovieStore {
    private(set) var movies: [Movie] = [...]

    func addMovie(_ movie: Movie) {
        movies.append(movie)
    }
}
```

POST route에서는 이제 이렇게 호출하면 된다.

```swift
router.post("/movies") { request, context async throws in
    let movie = try await request.decode(as: Movie.self, context: context)
    await movieStore.addMovie(movie)
    return movie
}
```

---

### 테스트

먼저 GET으로 movies 목록이 잘 나오는지 확인을 해본다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.54.png){: width="50%" height="50%"}

그리고 POST로 "Finding Nemo"를 추가해봤다. 다시 GET으로 조회하니 목록 맨 끝에 Finding Nemo가 잘 들어가 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-1/CleanShot_07-17.541.png){: width="50%" height="50%"}

다만 지금은 MovieStore가 메모리에만 저장되기 때문에, 서버를 재시작하면 추가한 movie는 전부 사라진다. 결국 나중엔 데이터베이스로 영속화해야 한다는 뜻.

---

## Query String 다루기

검색, 필터링, 페이지네이션 같은 기능을 만들 때 query string을 많이 쓰게 되는데, Hummingbird에서는 이걸 어떻게 다루는지 살펴본다.

---

### Route 만들기

`/movies/search` route를 하나 만든다. 이름은 마음대로 지어도 된다.

```swift
router.get("/movies/search") { request, context in
    // ...
}
```

`/movies/search?q=Batman&page=12` 같은 형태로 요청이 들어온다고 가정한다. `q`는 검색어, `page`는 페이지 번호다.

---

### Query Parameter 꺼내기

query parameter는 `request.uri.queryParameters`로 접근할 수 있다.

```swift
router.get("/movies/search") { request, context in
    let queryParameters = request.uri.queryParameters

    guard let q = queryParameters.get("q", as: String.self),
          let page = queryParameters.get("page", as: Int.self) else {
        throw HTTPError(.badRequest)
    }

    return "Your search term was \(q), page number was \(page)"
}
```

`.get`에 타입을 지정해서 꺼내올 수 있고(`q`는 String, `page`는 Int), 둘 다 필수 값으로 취급해서 없으면 bad request를 던지도록 했다. required로 할지 말지는 API를 설계하는 사람 마음이다.

---

### 테스트

`?q=Batman&page=12`로 요청하면 정상적으로 Batman, 12가 잘 추출된다. `q`를 Superman으로, page를 1로 바꿔도 문제없이 동작한다.

다만 `page`를 아예 안 보내면 요청이 실패한다. `guard`에서 필수로 지정해뒀기 때문이다. 보통은 UI에서 페이지 번호를 항상 붙여서 보내도록 설계하니까(1페이지여도 `page=1`을 명시적으로 붙이는 식), 실무에서는 크게 문제되지 않는다.

---

## Route Group으로 구조화하기

route마다 계속 `/movies`, `/movies`, `/movies` 이렇게 경로를 반복해서 쓰는 게 마음에 안 든다. 게다가 외부에 공개하는 API라면 `/api`처럼 prefix를 붙여주는 게 일반적인데, 그렇다고 모든 route 앞에 매번 `api`, `api`, `api`를 붙이는 것도 지저분하다. Hummingbird는 이 문제를 route group으로 해결한다.

---

### Group 만들기

`router.group`으로 group을 만들면, 그 group에 붙이는 모든 route 앞에 자동으로 prefix가 붙는다.

```swift
let api = router.group("api")

api.get("/users") { request, context in
    "users"
}
```

이렇게 하면 `/api/users`로 요청해야 매칭된다.

---

### Nested Group

movies 관련 route가 많으니, `api` 밑에 `movies`라는 nested group을 하나 더 만든다.

```swift
let movies = api.group("movies")

movies.get("/") { request, context async in
    await movieStore.movies
}
```

이 route는 `api` group 안에 있는 `movies` group이니까, 최종 경로는 `/api/movies`가 된다. 실제로 접속해보면 movie 목록이 정상적으로 반환된다. (http://127.0.0.1:8080/api/movies)

`users`도 마찬가지로 group을 하나 만들어서 root route를 붙이면 `/api/users`가 그대로 동작한다.

```swift
let users = api.group("users")

users.get("/") { request, context in
    "Users"
}
```

---

### 기존 route들 옮기기

이 구조를 이용해서 앞서 만든 movie 관련 route들을 전부 `movies` group 밑으로 옮길 수 있다.

```swift
movies.get("/:movieID") { request, context in
    // movie ID로 조회
}

movies.post("/") { request, context in
    // movie 추가
}

movies.get("/search") { request, context in
    // 검색
}

movies.get("/genre/:genre") { request, context in
    // 장르별 조회
}

movies.get("/genre/:genre/year/:year") { request, context in
    // 장르 + 연도별 조회
}
```

각 route마다 `/api/movies`를 반복해서 쓸 필요 없이, group에 이미 포함된 경로는 생략하고 그 뒤에 붙는 부분만 적어주면 된다. route group, 특히 nested group을 잘 활용하면 애플리케이션 구조를 훨씬 깔끔하게 정리할 수 있다.