---
title: Hummingbird (5)
writer: Harold
date: 2026-09-09 07:06
categories: [Hummingbird]
tags: [JWT Authentication]

toc: true
toc_sticky: true
---

## 인증 시작하기: users 테이블 만들기

이번글에선 인증(authentication)을 다룬다. 인증을 하려면 사용자 정보(username, password)가 필요하고, 이걸 저장할 테이블이 있어야 하니 먼저 migration부터 작성한다.

---

### CreateUsersTable 작성하기

```swift
import FluentKit

struct CreateUsersTable: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("password", .string, .required)
            .unique(on: "username")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
```

`username`, `password` 두 컬럼을 두고, `username`에는 `.unique(on:)`으로 중복을 막는 제약을 건다.

---

### Migration 등록하기

기존에 등록해둔 `CreateMoviesTable`, `CreateReviewsTable`에 이어서 추가한다.

```swift
// App+build
await fluent.migrations.add(CreateUsersTable(), to: .psql)
```

`watchexec`가 파일 변경을 감지해서 서버를 재시작하면 migration이 실행된다. 이미 실행된 `CreateMoviesTable`, `CreateReviewsTable`은 `_fluent_migrations` 테이블에 기록이 남아있어서 다시 실행되지 않고, 새로 추가한 `CreateUsersTable`만 실행된다.

Beekeeper Studio로 확인해보면 `users` 테이블이 새로 생겼고, `id`, `username`, `password` 컬럼이 정의한 대로 만들어져 있다. 아직 데이터는 비어있는 상태다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_08-12.5829.png){: width="50%" height="50%"}

---

## User Model 만들기

이번엔 `users` 테이블에 대응하는 데이터 모델을 만든다. `Movie`, `Review` 모델을 만들 때와 같은 패턴이다.

---

### User 모델 작성하기

```swift
final class User: Model, ResponseCodable, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password")
    var password: String

    init() {}

    init(id: UUID? = nil, username: String, password: String) {
        self.id = id
        self.username = username
        self.password = password
    }
}
```

`Model` 프로토콜을 채택하고, `schema`를 `users`로 지정한다. `username`, `password` 필드는 각각 database의 같은 이름 컬럼과 매핑된다. 값을 채워서 만드는 초기화 함수는 아직 database에 저장되지 않은(따라서 `id`가 없는) 새 user를 만들 때 쓰게 된다.

이제 남은 건 실제로 사용자가 계정을 만들 수 있게 하는 것, 즉 회원가입(registration) 기능이다. 회원가입이 없으면 애초에 인증할 대상 자체가 database에 존재하지 않기 때문이다.

---

## 회원가입(register) 기능 만들기

이번엔 `UsersController`를 만들어서 회원가입 기능을 구현한다.

---

### UsersController 기본 골격

`MoviesController`, `ReviewsController`와 같은 패턴으로 Fluent를 의존성으로 받는다.

```swift
import Hummingbird
import HummingbirdFluent

struct UsersController {
    
    let fluent: Fluent

    var endpoints: RouteCollection<AppRequestContext> {
        let routeCollection = RouteCollection(context: AppRequestContext.self)
        return routeCollection
    }
}
```

`App+build.swift`에도 등록한다.

```swift
router.addRoutes(UsersController(fluent: fluent).endpoints, atPath: "/api/users")
```

---

### CreateUserRequest와 RegisterResponse DTO

클라이언트가 회원가입 시 보내는 값은 username과 password뿐이다. `User` 모델을 직접 decode할 수도 있지만, `createdAt`이나 `isActive`처럼 나중에 모델에 추가될 수 있는 필드까지 신경 쓰지 않아도 되게끔 전용 DTO를 만드는 게 깔끔하다.

```swift
struct CreateUserRequest: ResponseCodable, Decodable, Equatable {
    let username: String
    let password: String
}

struct RegisterResponse: ResponseCodable, Decodable, Equatable {
    let message: String
}
```

응답은 자유롭게 설계하면 되는데, 여기선 간단하게 메시지 하나만 담는다. 참고로 사용자 정보를 응답에 포함시키더라도 password는 절대 돌려주면 안 된다.

---

### register 함수 작성하기

```swift
func register(request: Request, context: some RequestContext) async throws -> RegisterResponse {
    
    let db = fluent.db()

    let createUserRequest = try await request.decode(as: CreateUserRequest.self, context: context)
    
    // make sure that user does not already exist

    guard let existingUser = try await User.query(on: db)
        .filter(\.$username == createUserRequest.username)
        .first()
    else {
        throw HTTPError(.conflict)
    }

    let user = User(username: existingUser.username, password: existingUser.password)
    
    try await user.save(on: db)

    return RegisterResponse(message: "user has been created")
}
```

먼저 같은 username을 가진 user가 이미 있는지 확인한다. 있으면 `409 Conflict`를 던지고, 없으면 새 `User`를 만들어서 저장한 뒤 성공 메시지를 반환한다.

그리고 routeCollection에 추가해준다.

```swift
routeCollection.post("/register", use: register)
```

---

### 테스트하다가 만난 문제

Postman으로 `POST /api/users/register`에 username "John Doe", password를 담아 요청을 보냈는데, database가 완전히 비어있는 상태인데도 `409 Conflict`가 발생했다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-02.3657.png){: width="50%" height="50%"}

즉 "이미 존재하는 user"라는 응답이 나왔는데, 실제로는 `users` 테이블에 아무 데이터도 없는 상황이었다.

그래서 코드를 수정한다.

```swift
var endpoints: RouteCollection<AppRequestContext> {
    let routeCollection = RouteCollection(context: AppRequestContext.self)
    routeCollection.post("register", use: register) // /register -> register
    return routeCollection
}

func register(request: Request, context: some RequestContext) async throws -> RegisterResponse {
    
    let db = fluent.db()

    let createUserRequest = try await request.decode(as: CreateUserRequest.self, context: context)
    
    // make sure that user does not already exist

    let existingUser = try await User.query(on: db) // guard 삭제
        .filter(\.$username == createUserRequest.username)
        .first()
    
    guard existingUser == nil else { throw HTTPError(.conflict) }

    let user = User(username: createUserRequest.username, password: createUserRequest.password) // createUserRequest로 변경
    
    try await user.save(on: db)

    return RegisterResponse(message: "user has been created")
}
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-02.4107.png){: width="50%" height="50%"}

이젠 생성이 잘 되는걸 알 수 있다.

---

## 비밀번호 암호화하기 (bcrypt)

지금까지는 회원가입 시 비밀번호를 평문 그대로 database에 저장하고 있었다. 당연히 위험한 방식이라, 이번엔 bcrypt로 암호화해서 저장하도록 고친다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-03.3818.png){: width="50%" height="50%"}

---

### HummingbirdAuth 패키지 추가하기

`Package.swift`에 `HummingbirdAuth`를 추가한다. 이 패키지 안에 bcrypt를 포함한 몇 가지 관련 product가 들어있다.

```swift
dependencies: [
    // 생략
    .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
],
targets: [
    .executableTarget(name: "HelloBirdFluent",
        dependencies: [
            // 생략
            .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
            .product(name: "HummingbirdBasicAuth", package: "hummingbird-auth"),
            .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
        ]
    )
]
```

이때 패키지 명을 잘못 입력하면 에러가 뜨니 확실하게 하자

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-03.5933.png){: width="50%" height="50%"}

```swift
.product(name: "HummingbirdBCrypt", package: "hummingbird-auth"),  // ❌ 틀림
.product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),  // ✅ 맞음
```


---

### User 모델에 해싱 로직 추가하기

기존에 `username`, `password`를 각각 받던 초기화 함수 대신, `CreateUserRequest`를 통째로 받아서 그 안에서 비밀번호를 해싱하는 초기화 함수로 바꾼다.

```swift
// Models
import HummingbirdBcrypt

init(request: CreateUserRequest) async throws {
    self.username = request.username
    self.password = try await NIOThreadPool.singleton.runIfActive {
        Bcrypt.hash(request.password, cost: 12)
    }
}
```

`Bcrypt.hash(_:cost:)`는 클라이언트가 보낸 평문 비밀번호를 단방향 해시 값으로 변환한다. `cost`는 해싱에 드는 연산 비용을 조절하는 값으로, 값이 클수록 내부적으로 도는 라운드 수가 많아져서 해싱이 느려지는 대신 보안은 강해진다. 10 정도가 표준으로 여겨지고, 12는 흔히 쓰이는 값이며, 14 이상은 고보안이 필요한 경우에 쓴다고 한다. 여기선 12를 사용했다.

bcrypt 연산은 CPU를 많이 쓰는 무거운 작업이라, `NIOThreadPool.singleton.runIfActive { ... }`로 감싸서 별도 스레드 풀에서 실행하도록 처리한다.

---

### 사용하기

`UsersController.register`에서 기존에 `username`, `password`를 개별로 넘기던 부분을, `CreateUserRequest`를 그대로 넘기는 방식으로 바꾼다.

```swift
// UsersController
let user = try await User(request: createUserRequest)
```

---

### 테스트

기존에 평문으로 저장돼 있던 John Doe 계정을 지우고 같은 정보로 다시 등록해보면, 응답은 이전과 동일하게 "user has been created"가 오지만 database를 확인해보면 password 컬럼에 더 이상 평문이 아니라 bcrypt로 암호화된 값이 들어가 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-04.0425.png){: width="50%" height="50%"}

비밀번호뿐 아니라 주민등록번호, 여권번호, 신용카드 번호처럼 민감한 정보라면 마찬가지로 암호화해서 저장해야 한다는 점도 함께 짚어두고 넘어간다.

---

### 정리

`POST /api/users/register`로 username, password가 평문 그대로 도착한다. `request.decode(as: CreateUserRequest.self)`를 거치면 `createUserRequest`가 만들어지는데, 이 시점엔 아직 순수하게 decode만 된 상태라 password도 여전히 평문이다. 해싱은 이 단계에서 일어나지 않는다.

그다음 `User.query(on: db).filter(\.$username == createUserRequest.username).first()`로 같은 username을 가진 user가 이미 있는지 확인한다. 이건 순전히 중복 가입을 막기 위한 체크이고, 비밀번호와는 아무 관련이 없다. 이미 존재하면 `HTTPError(.conflict)`를 던지고 여기서 끝난다.

중복이 아니면 `User(request: createUserRequest)`를 호출하는데, 이건 `User` 모델에 정의해둔 `async` 초기화 함수다. **바로 이 초기화 함수 내부에서** `Bcrypt.hash(request.password, cost: 12)`가 실행되면서 평문 password가 비로소 해시값으로 바뀐다. 즉 해싱은 decode 시점도, 중복 체크 시점도 아니고, `User` 객체를 실제로 만드는 이 초기화 시점에 일어난다.

이렇게 만들어진 `user`를 `user.save(on: db)`로 저장하면, database에는 처음부터 끝까지 해시된 값만 들어가고, 클라이언트에는 `RegisterResponse`로 성공 메시지만 돌아간다.

참고로 bcrypt는 단방향 해싱이라 "복호화"라는 개념 자체가 없다. 나중에 로그인 시에도 저장된 해시값을 원래 비밀번호로 되돌리는 게 아니라, 입력받은 비밀번호를 다시 같은 방식으로 해싱해서 저장된 해시값과 비교하는 방식으로 검증하게 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/register_flow.png){: width="50%" height="50%"}

---

## 로그인 구현하기

이번엔 로그인 기능을 만든다. 분량이 꽤 되니 여러 파트로 나눠서 진행하는데, 이번 파트에서는 username/password를 검증해서 인증되었는지 확인하는 부분까지 다룬다.

---

### UsersController에 login route 추가하기

```swift
routeCollection.post("login", use: login)
```

---

### LoginRequest DTO

클라이언트가 로그인 시 보내는 값은 username과 password뿐이다.

```swift
struct LoginRequest: ResponseCodable, Decodable, Equatable {
    let username: String
    let password: String
}
```

---

### login 함수 작성하기: 사용자 조회 및 비밀번호 검증

```swift
import HummingbirdBcrypt

func login(request: Request, context: some RequestContext) async throws -> String? {
    
    let db = fluent.db()

    let loginRequest = try await request.decode(as: LoginRequest.self, context: context)

    guard let existingUser = try await User.query(on: db)
        .filter(\.$username == loginRequest.username)
        .first()
    else {
        throw HTTPError(.unauthorized)
    }
    
    

    let isAuthenticated = try await Bcrypt.verify(loginRequest.password, hash: existingUser.password)

    guard isAuthenticated else {
        throw HTTPError(.unauthorized)
    }

    // create access token
    
    // create refresh token

    return nil
}
```

먼저 username으로 user를 조회한다. 존재하지 않으면 `401 Unauthorized`를 던진다(사용자가 누구인지조차 알 수 없는 상황이니까). 존재하면 그다음이 핵심인데, database엔 비밀번호가 bcrypt로 해시되어 저장되어 있으므로 평문끼리 직접 비교할 수 없다. 그래서 `Bcrypt.verify(_:hash:)`를 쓰는데, 이 함수는 클라이언트가 보낸 평문 비밀번호를 받아서 저장된 해시값과 같은 방식으로 비교해준다. 결과가 `true`가 아니면 마찬가지로 `401 Unauthorized`를 던진다.

---

### LoginResponse DTO

인증까지 통과하면 access token과 refresh token을 발급해서 돌려준다는 계획이지만, 토큰을 실제로 만드는 방법은 다음 파트에서 다룬다. 일단 응답 형태만 미리 정의해둔다.

```swift
struct LoginResponse: ResponseCodable, Decodable, Equatable {
    let accessToken: String
    let refreshToken: String
}
```

이후 함수를 고쳐준다.

```swift
func login(request: Request, context: some RequestContext) async throws -> LoginResponse {
    // 생략
    return LoginResponse(accessToken: "", refreshToken: "")
}
```

---

### JWTKit 패키지 추가하기

`Package.swift`에 JWTKit을 추가한다. 토큰을 생성(sign)하고 검증(verify)하는 기능을 제공한다.

```swift
dependencies: [
    // 생략
    .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
],
targets: [
    .executableTarget(name: "HelloBird",
        dependencies: [
            // 생략
            .product(name: "JWTKit", package: "jwt-kit"),
        ]
    )
]
```

---

### JWTPayloadData 정의하기

`Middlewares` 폴더를 만들고, `JWTAuthenticator.swift` 파일을 만ㄷ르어 그 안에 토큰의 payload(토큰 안에 실릴 데이터)를 정의한다. `JWTKit`이 제공하는 `JWTPayload` 프로토콜을 채택한다.

```swift
import JWTKit

struct JWTPayloadData: JWTPayload, Equatable {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case username = "username"
        case tokenType = "type"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var username: String
    var tokenType: TokenType

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

// Models
enum TokenType: String, Codable {
    case access
    case refresh
}
```

`subject`는 관례적으로 `sub`, `expiration`은 `exp`로 인코딩되는 게 일반적이라 `CodingKeys`로 맞춰준다. `username`, `tokenType`은 원하는 이름을 그대로 써도 된다. payload에 절대 넣으면 안 되는 정보도 있는데, password나 주민등록번호, 신용카드 번호처럼 민감한 데이터는 토큰이 디코딩 가능하다는 점을 감안하면 절대 포함시키면 안 된다. `verify(using:)`에서는 만료 여부만 확인한다.

---

### access token / refresh token payload 만들기

`UsersController.login`에서 인증에 성공한 뒤, 두 종류의 payload를 만든다.

```swift
// UsersController 
let accessTokenPayload = JWTPayloadData(
    subject: .init(value: try existingUser.requireID().uuidString),
    expiration: .init(value: Date(timeIntervalSinceNow: 60 * 15)),
    username: existingUser.username,
    tokenType: .access
)

let refreshTokenPayload = JWTPayloadData(
    subject: .init(value: try existingUser.requireID().uuidString),
    expiration: .init(value: Date(timeIntervalSinceNow: 60 * 60 * 24 * 7)),
    username: existingUser.username,
    tokenType: .refresh
)
```

`requireId()`는 `id`가 존재한다고 확신할 수 있을 때 optional을 안전하게 풀어주는 메서드로, 없으면 에러를 던진다. access token은 15분, refresh token은 7일로 만료 시간을 다르게 준다. access token은 실제로 보호된 리소스에 접근할 때 매번 쓰이는 짧은 수명의 토큰이고, refresh token은 access token이 만료됐을 때 새 access token을 발급받기 위한 용도라 상대적으로 길게 잡는다.

---

### JWTKeyCollection으로 서명하기

```swift
let jwtKeyCollection = JWTKeyCollection()

let accessToken = try await jwtKeyCollection.sign(accessTokenPayload)
let refreshToken = try await jwtKeyCollection.sign(refreshTokenPayload)

return LoginResponse(accessToken: accessToken, refreshToken: refreshToken)
```

`JWTKeyCollection`이 토큰 서명과 검증을 담당하는 핵심 객체다. `hmac`으로 secret key와 해시 알고리즘을, `kid`(key identifier)로 이 키에 붙일 식별자를 설정한다. secret key는 코드에 하드코딩하면 안 되고, `.env` 파일에 넣은 뒤 `.gitignore`에 포함시켜서 GitHub에 올라가지 않도록 관리해야 한다.

---

### 겪었던 문제: Internal Server Error

로그인 요청을 보내면 internal server error가 발생했다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-06.3919.png){: width="50%" height="50%"}

```swift
await jwtKeyCollection.add(hmac: "my-secret-key", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
```

secret key나 알고리즘 같은 설정이 하나도 안 된 상태에서 바로 `sign`을 호출했기 때문. `add(hmac:...)` 설정을 추가하고 나니 정상적으로 access token과 refresh token이 발급됐다.

다만 여기서 `"my-secret-key"`처럼 secret key를 코드에 그대로 하드코딩하는 건 임시방편일 뿐, 실제로는 절대 이렇게 두면 안 된다. 코드에 박아넣은 채로 GitHub에 커밋하면 이 프로젝트를 보는 누구나 secret key를 그대로 알 수 있게 되기 때문이다. 그래서 이 값은 `.env` 같은 환경 파일에 넣어두고, `.gitignore`에 그 파일을 추가해서 저장소에 올라가지 않도록 관리해야 한다.

---

### 짧은 secret key로 인한 crash

하지만 실제로 실행해보니 Terminal에서 다음과 같은 에러가 발생한다.

```bash
💣 Program crashed: Signal 5: Backtracing from 0x19afacd04...
// 생략

60│         // Should NOT make instace here
61│         let jwtKeyCollection = JWTKeyCollection()
62│         await jwtKeyCollection.add(hmac: "my-secret-key", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
  │                                ▲
63│
64│         let accessToken = try await jwtKeyCollection.sign(accessTokenPayload)
```

`HMACSigner<SHA256>(key: key.key)` 초기화 과정에서 crash가 나는데, 원인을 바로 알기 어려워서 AI에게 물어봤다. 답은 secret key로 쓴 문자열이 너무 짧다는 것이었다.

실제로 HMAC의 표준 규격인 [RFC 2104](https://www.rfc-editor.org/rfc/rfc2104)에는 이런 내용이 있다. HMAC 키는 원칙적으로 어떤 길이든 가능하지만, 해시 함수의 출력 길이(L)보다 짧은 키는 함수의 보안 강도를 약화시키므로 강력히 권장하지 않는다는 것. SHA-256의 출력 길이는 32바이트(256비트)이므로, HMAC-SHA256을 쓴다면 최소 32바이트 이상의 키를 쓰는 게 표준 권장 사항이다.

`"my-secret-key"`는 13자밖에 안 되니 이 기준에 한참 못 미친다. 그래서 충분히 긴 문자열로 바꿔보니 crash 없이 정상적으로 동작했다.

```swift
await jwtKeyCollection.add(hmac: "a-much-longer-random-secret-key-for-testing-purposes-1234567890", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-07.0114.png){: width="50%" height="50%"}

물론 이것도 어디까지나 테스트용 문자열이고, 실제 운영 환경에서는 암호학적으로 안전한 난수 생성기로 만든 32바이트 이상의 랜덤 값을 env file에서 읽어와 쓰는 게 맞다.

---

### 테스트

username, password가 맞으면 access token과 refresh token이 정상적으로 발급된다. username을 틀리거나(`John Doe2`) password를 틀리면 각각 `401 Unauthorized`가 반환되는 것도 확인했다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-07.0201.png){: width="50%" height="50%"}

발급된 토큰은 클라이언트(iOS 앱이라면 Keychain 같은 안전한 저장소)가 보관하고, 이후 보호된 리소스에 접근할 때 함께 실어 보내는 방식으로 쓰이게 된다.

---

## JWTKeyCollection을 buildApplication으로 옮기기

지금까지는 `login` action 안에서 매번 `JWTKeyCollection()`을 생성하고 설정하고 있었다. 

```swift
let jwtKeyCollection = JWTKeyCollection()
await jwtKeyCollection.add(hmac: "a-much-longer-random-secret-key-for-testing-purposes-1234567890", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
```

이러면 로그인 요청이 올 때마다 이 설정 작업이 반복되니 비효율적이고, secret key도 코드에 그대로 하드코딩되어 있어서 GitHub에 올리면 그대로 노출된다는 문제가 있다. 이 두 가지를 이번에 정리한다.

---

### buildApplication에서 한 번만 생성하기

`login` action 안에 있던 초기화 코드를 `buildApplication(App+build)`으로 옮긴다.

```swift
import JWTKit

// create jwtKeyCollection
let jwtKeyCollection = JWTKeyCollection()
// REMOVE KEY FROM CODE AND MOVE IT TO ENV FILE
await jwtKeyCollection.add(hmac: "a-much-longer-random-secret-key-for-testing-purposes-1234567890", digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
```

이제 서버가 시작될 때 딱 한 번만 만들어지고, 이후 요청마다 재사용된다.

---

### UsersController에 의존성으로 주입하기

`buildRouter`가 `jwtKeyCollection`을 파라미터로 받도록 하고, `UsersController` 초기화 시 넘겨준다.

```swift
let router = try buildRouter(fluent, jwtKeyCollection: jwtKeyCollection)

func buildRouter(fluent: Fluent, jwtKeyCollection: JWTKeyCollection) throws -> Router<AppRequestContext> {
    // 생략
    router.addRoutes(UsersController(fluent: fluent, jwtKeyCollection: jwtKeyCollection).endpoints, atPath: "/api/users")
}

struct UsersController {

    let fluent: Fluent
    let jwtKeyCollection: JWTKeyCollection
    // 생략
}
```

`login` 함수 안에서 직접 만들던 두 줄은 지우고, 이미 주입받은 `jwtKeyCollection`을 그대로 사용하면 된다.

---

### secret key를 .env 파일로 옮기기

secret key를 코드에서 완전히 빼기 위해, 프로젝트 루트에 `.env` 파일을 만든다. 이 파일은 `key=value` 형식으로 작성한다.

하지만 이미 파일은 존재한다.(단지 중요파일이라 숨김처리가 되어있을뿐이다.)

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-07.1318.png){: width="50%" height="50%"}

그리고 파일을 열어서 (터미널에서 `open .env`)

```
JWT_SECRET=a-much-longer-random-secret-key-for-testing-purposes-1234567890
```

위와 같이 Secretkey를 작성해준다.

`.gitignore`에 `.env`가 이미 포함되어 있어야 한다(포함되어 있지 않다면 추가한다). 그래야 이 파일이 GitHub에 올라가지 않는다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-07.1655.png){: width="50%" height="50%"}

---

### env 값 읽어와서 사용하기

`main` 함수에서 만들어둔 `ConfigReader`(command line, environment variable, env file 등 여러 provider를 갖고 있는)를 통해 `.env` 파일의 값을 읽어올 수 있다.

```swift
let jwtSecret = reader.string(forKey: "JWT_SECRET")
print(jwtSecret!)
```

확인을 위해 print를 해주고 터미널을 보면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-07.1845.png){: width="50%" height="50%"}

잘 가져오는걸 확인할 수 있다.

읽어온 값은 optional이라, 없을 경우 어떻게 처리할지는 상황에 맞게 결정하면 된다(값이 없으면 애초에 인증이 동작할 수 없으니, 앱을 그대로 crash시키는 것도 하나의 선택지다).

```swift
guard let jwtSecret = reader.string(forKey: "JWT_SECRET") else {
    fatalError("keys are missing")
}
```

이 값을 `add(hmac:...)`에 넘길 때, `hmac` 파라미터가 실제로는 문자열이 아니라 HMAC 키 타입을 요구해서 타입 에러가 났는데, 이 타입의 초기화 함수 중에 문자열을 받는 것이 있어서 그대로 넘기면 해결된다.

```swift
await jwtKeyCollection.add(hmac: .init(from: jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier("auth-jwt"))
```

---

### 결과

이렇게 정리하고 나면, secret key는 코드 어디에도 노출되지 않고 `.env` 파일에만 존재하며, 그 파일 자체는 `.gitignore`로 인해 GitHub에 올라가지 않는다. 만약 다른 사람이 이 프로젝트를 받아서 실행하려면 자신만의 `.env` 파일을 직접 만들어서 키 값을 채워넣어야 한다. Heroku, Render, Fly.io 같은 배포 플랫폼들도 대체로 환경 변수를 이런 key-value 형태로 설정할 수 있는 인터페이스를 제공한다.

---

## JWTAuthenticator Middleware 만들기

route마다 인증 로직을 일일이 복붙하는 대신, middleware로 만들어서 여러 route에 공통으로 적용할 수 있게 만든다. middleware는 실제 route 핸들러(action)에 도달하기 전에 먼저 실행되는 계층이다.

---

### AuthUser 모델 만들기

인증에 성공했을 때 route 안에서 쓸 수 있게 되는 사용자 정보를 담는 타입이다.

```swift
struct AuthUser {
    let id: UUID
    let username: String
}
```

---

### JWTAuthenticator 골격 만들기

`JWTAuthenticator`를 만든다. `AuthenticatorMiddleware` 프로토콜을 채택한다.

```swift
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit

struct JWTAuthenticator: AuthenticatorMiddleware, @unchecked Sendable {
    
    typealias Context = AppRequestContext

    let jwtKeyCollection: JWTKeyCollection
    let fluent: Fluent

    func authenticate(request: Request, context: Context) async throws -> AuthUser? {
        
    }
}
```

여기서 `Context`를 새로운 타입으로 따로 정의하지 않고, 기존에 프로젝트 전체에서 쓰던 `AppRequestContext`를 그대로 가리키게 했다. 대신 `AppRequestContext` 자체의 정의를 `App+build.swift`에서 바꿔준다.

```swift
import HummingbirdAuth

typealias AppRequestContext = BasicAuthRequestContext<AuthUser>
```

기존엔 `AppRequestContext`가 인증 정보를 담지 않는 `BasicRequestContext`를 가리켰는데, 이제 `BasicAuthRequestContext<AuthUser>`로 바뀌면서 인증 결과로 `AuthUser`를 담을 수 있는 context가 됐다. 즉 `MoviesController`, `ReviewsController`, `UsersController`가 지금까지 공통으로 써온 `AppRequestContext` 자체에 인증 정보를 실을 자리가 생긴 것이고, `JWTAuthenticator`는 별도의 context 타입을 새로 만드는 대신 이 공용 `AppRequestContext`를 그대로 재사용하는 구조다. 이렇게 하면 인증이 필요한 route든 아니든 프로젝트 전체가 여전히 하나의 context 타입만 쓰게 되어, controller들 사이에서 타입을 억지로 맞춰줄 필요가 없어진다.

인증에 성공하면 이 `AuthUser` 값이 `context.identity`로 route 안에서 꺼내 쓸 수 있게 된다.

---

### authenticate 함수 구현하기

```swift
func authenticate(request: Request, context: Context) async throws -> AuthUser? {
    
    guard let jwtToken = request.headers.bearer?.token else {
        throw HTTPError(.unauthorized)
    }

    let payload: JWTPayloadData
    do {
        payload = try await jwtKeyCollection.verify(jwtToken, as: JWTPayloadData.self)
    } catch {
        throw HTTPError(.unauthorized)
    }

    guard payload.tokenType == .access else {
        throw HTTPError(.unauthorized)
    }

    guard let userId = UUID(uuidString: payload.subject.value) else {
        throw HTTPError(.unauthorized)
    }
    
    let db = fluent.db()
    
    // check the user in the database
    guard let user = try await User.find(userId, on: db) else {
        throw HTTPError(.notFound)
    }

    return AuthUser(id: try user.requireID(), username: user.username)
}
```

단계별로 하는 일은 이렇다.

- **토큰 꺼내기**: JWT는 관례적으로 `Authorization` 헤더에 `Bearer` 방식으로 실려온다. `request.headers.bearer`로 꺼내고, 없으면 `401 Unauthorized`
- **토큰 검증**: `jwtKeyCollection.verify(_:as:)`로 서명이 위조되지 않았는지, 만료되지 않았는지 확인한다. 실패하면 토큰이 변조됐거나 만료된 것이므로 `401 Unauthorized`
- **토큰 타입 확인**: 로그인 시 access token, refresh token 두 종류를 발급했었는데, 인증에는 반드시 access token만 써야 한다. refresh token이 들어오면 거부한다
- **user 조회**: 토큰의 `subject`에 user id가 들어있으므로 그걸로 실제 database에 해당 user가 아직 존재하는지 확인한다. 토큰 자체는 유효해도, 그 사이 user가 삭제됐을 수 있기 때문
- **AuthUser 반환**: 모든 검증을 통과하면 `id`, `username`을 담은 `AuthUser`를 반환한다. 이 값이 이후 route 안에서 `context.identity`로 접근 가능해진다

middleware 자체는 이렇게 완성했지만, 아직 실제 route에 적용하지는 않은 상태다.

---

## route group에 middleware 적용하기

만들어둔 `JWTAuthenticator`를 이제 실제 route에 적용해본다. 매 route마다 인증 로직을 넣는 대신, `router.group`으로 route들을 묶고 그 그룹 전체에 middleware를 걸어주는 방식을 쓴다.

---

### movies route 그룹에 인증 걸기

```swift
let jwtAuthenticator = JWTAuthenticator(jwtKeyCollection: jwtKeyCollection, fluent: fluent)

let movies = router.group("/api/movies")
movies.add(middleware: jwtAuthenticator)
movies.addRoutes(MoviesController(fluent: fluent).endpoints)
```

middleware는 route보다 먼저 추가해야 한다. 여러 middleware를 동시에 추가하는 것도 가능한데, 이 경우 추가한 순서대로 실행된다. 이렇게 하면 `/api/movies`로 시작하는 모든 route가 `JWTAuthenticator`를 거치게 된다.

---

### 테스트: 인증 없이 접근하면 막힌다

이 상태로 `/api/movies`에 접속하면 `401 Unauthorized`가 반환된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-09.3815.png){: width="50%" height="50%"}

접근하려면 먼저 로그인해서 access token을 받아야 한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-09.4133.png){: width="50%" height="50%"}

토큰을 받았으면, 요청 헤더에 다음과 같이 실어 보낸다.

```
Authorization: Bearer <access_token>
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-09.4244.png){: width="50%" height="50%"}

토큰을 포함해서 요청하면 movie 목록이 정상적으로 반환되고, 헤더를 빼고 보내면 다시 `401 Unauthorized`가 반환된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-09.4328.png){: width="50%" height="50%"}

여기서 주의할 점은, 이 middleware를 아무 route에나 무분별하게 걸면 안 된다는 것이다. 예를 들어 아래처럼 `/api/users` 전체를 하나의 그룹으로 묶고 그 위에 middleware를 걸어버리면,

```swift
// 이렇게 하면 안 된다
let jwtAuthenticator = JWTAuthenticator(jwtKeyCollection: jwtKeyCollection, fluent: fluent)

let users = router.group("/api/users")
users.add(middleware: jwtAuthenticator)
users.addRoutes(UsersController(fluent: fluent).endpoints)
```

`/api/users/register`와 `/api/users/login`까지 전부 `JWTAuthenticator`를 거치게 된다. 그런데 `JWTAuthenticator`는 유효한 access token이 없으면 무조건 `401 Unauthorized`를 반환하는 middleware이므로, 결과적으로 "로그인을 하려면 이미 로그인이 되어 있어야 한다"는 모순에 빠진다. 즉 애초에 계정이 없는 사용자는 회원가입도, 로그인도 영원히 할 수 없게 되어버리는 것이다.

그래서 `UsersController`의 `register`, `login` route는 middleware 없이 별도로 등록해야 한다.

```swift
// register, login은 인증 없이 접근 가능해야 한다
router.addRoutes(UsersController(fluent: fluent, jwtKeyCollection: jwtKeyCollection).endpoints, atPath: "/api/users")
```

반대로 movies나 reviews처럼 "로그인한 사용자만 접근해야 하는" route에는 middleware를 걸어야 한다. 결국 원칙은 간단하다. **인증되지 않은 사용자가 인증 상태에 도달하기 위해 반드시 거쳐야 하는 route(회원가입, 로그인)는 middleware 밖에 둬야 하고, 그 이후에 접근하는 보호된 리소스에만 middleware를 적용해야 한다.**

---

### reviews route 그룹에도 적용하기

같은 방식으로 review 관련 그룹에도 middleware를 건다.

```swift
let movieReviews = router.group("/api/movies/:id/reviews")
movieReviews.add(middleware: jwtAuthenticator)
movieReviews.addRoutes(ReviewsController(fluent: fluent).endpoints)

let reviews = router.group("/api/reviews")
reviews.add(middleware: jwtAuthenticator)
reviews.addRoutes(ReviewsController(fluent: fluent).endpoints)

//router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/movies/:id/reviews")
//router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/reviews")
```

그리고 반드시 기존에 존재하던 addRoutes는 지우거나 주석을 잡아줘야한다. 그렇지 않으면 Routes 중복으로 인한 에러가 발생

토큰 없이 `/api/reviews`에 접근하면 `401 Unauthorized`, 토큰을 포함해서 접근하면 정상적으로 review 목록이 반환되는 걸 확인할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-09.5202.png){: width="50%" height="50%"}

---

### controller 안에서 인증된 사용자 정보 꺼내기

`JWTAuthenticator.authenticate`가 반환한 `AuthUser`는 `identity`라는 이름으로 context에 실린다. `AppRequestContext`가 `BasicRequestContext<AuthUser>`를 가리키도록 이미 바꿔뒀기 때문에, 어느 controller에서든 이렇게 꺼내 쓸 수 있다.

여기서 한 가지 짚어야 할 부분이 있다. 지금까지는 함수 시그니처에서 context 파라미터를 `context: some RequestContext`처럼 범용 프로토콜 타입으로 받아왔는데, `.identity`는 `RequestContext` 프로토콜에 정의된 프로퍼티가 아니라 인증 기능이 포함된 context에만 존재하는 프로퍼티다. 그래서 `.identity`에 접근하려면 파라미터 타입을 `AppRequestContext`(정확히는 `BasicRequestContext<AuthUser>`를 가리키는 타입)로 명시해야 한다. 즉 인증이 필요 없는 route는 여전히 범용 `some RequestContext`를 써도 되지만, 인증된 사용자 정보가 필요한 route는 구체 타입인 `AppRequestContext`로 좁혀줘야 하는 것이다.

```swift
func getAll(request: Request, context: AppRequestContext) async throws -> [Movie] {
    
    guard let user = context.identity else {
        throw HTTPError(.unauthorized)
    }
    
    let db = fluent.db()
    return try await Movie.query(on: db).all()
    
}
```

`authUser.id`, `authUser.username`처럼 로그인 시 토큰에 담아뒀던 정보를 그대로 활용할 수 있다. 예를 들어 review를 생성할 때 "누가 작성했는지"를 자동으로 채워 넣는 식으로 쓸 수 있다.

---

### 남은 문제: access token 만료

access token은 15분짜리라 금방 만료된다. 만료된 access token으로는 더 이상 인증이 통과되지 않는데, 그렇다고 매번 다시 로그인하게 만드는 건 사용자 경험상 좋지 않다. 이럴 때 7일짜리 refresh token으로 새 access token을 발급받는 기능이 필요하다.

---

## refresh token으로 access token 재발급하기

access token은 15분이면 만료된다. 그렇다고 매번 다시 로그인하게 만드는 건 사용자 경험상 좋지 않으니, 7일짜리 refresh token으로 새 access token을 발급받는 기능을 만든다.

---

### RefreshTokenRequest / RefreshTokenResponse DTO

```swift
struct RefreshTokenRequest: ResponseCodable, Decodable, Equatable {
    let refreshToken: String
}

struct RefreshTokenResponse: ResponseCodable, Decodable, Equatable {
    let accessToken: String
}
```

---

### refresh 함수 작성하기

```swift
func refresh(request: Request, context: some RequestContext) async throws -> RefreshTokenResponse {
    
    let db = fluent.db()

    let refreshTokenRequest = try await request.decode(as: RefreshTokenRequest.self, context: context)

    let payload: JWTPayloadData
    do {
        payload = try await jwtKeyCollection.verify(refreshTokenRequest.refreshToken, as: JWTPayloadData.self)
    } catch {
        throw HTTPError(.unauthorized)
    }

    guard payload.tokenType == .refresh else {
        throw HTTPError(.unauthorized)
    }

    guard let userId = UUID(uuidString: payload.subject.value) else {
        throw HTTPError(.unauthorized)
    }

    guard let user = try await User.find(userId, on: db) else {
        throw HTTPError(.unauthorized)
    }
    
    // create access token
    let accessTokenPayload = JWTPayloadData(
        subject: .init(value: try user.requireID().uuidString),
        expiration: .init(value: Date(timeIntervalSinceNow: 60 * 15)),
        username: user.username,
        tokenType: .access
    )

    let newAccessToken = try await jwtKeyCollection.sign(accessTokenPayload)

    return RefreshTokenResponse(accessToken: newAccessToken)
}
```

전체 흐름은 로그인 시 검증했던 과정과 비슷하다.

- body에서 `refreshToken`을 decode한다
- `jwtKeyCollection.verify(_:as:)`로 서명과 만료 여부를 검증한다(실패하면 `401 Unauthorized`)
- `tokenType`이 `.refresh`인지 확인한다. access token으로 이 endpoint를 호출하는 걸 막기 위한 체크다
- `subject`에서 user id를 꺼내 실제로 존재하는 user인지 database에서 재확인한다
- 검증을 다 통과하면 15분짜리 access token payload를 새로 만들어서 서명하고, 새 access token만 응답으로 돌려준다(refresh token은 재발급하지 않는다)

---

### route 등록하기

```swift
routeCollection.post("refresh", use: refresh)
```

`POST`인 이유는 클라이언트가 refresh token을 body에 실어 보내야 하기 때문이다.

---

### 테스트

만료된 access token으로 `/api/movies`에 접근하면 예상대로 `401 Unauthorized`가 반환된다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-10.2116.png){: width="50%" height="50%"}

이때 로그인 시 받아뒀던 refresh token으로 `/api/users/refresh`를 호출하면 새 access token이 발급되고, 그 새 토큰으로 다시 `/api/movies`에 접근하면 정상적으로 movie 목록이 반환된다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-5/CleanShot_09-10.2227.png){: width="50%" height="50%"}

refresh token을 통해 재로그인 없이 access token을 재발급받는 흐름이 완성된 것이다.

---

## 마무리: Request/Response DTO 패턴

지금까지 인증 기능을 구현하면서 `CreateUserRequest`, `LoginRequest`, `LoginResponse`, `RefreshTokenRequest`, `RefreshTokenResponse`까지, 거의 모든 endpoint마다 입력용(`~Request`)과 출력용(`~Response`) DTO를 데이터 모델과 분리해서 만들어왔다. 이 강의 전체에 걸쳐 일관되게 반복된 패턴이다.

이렇게 하는 이유를 정리하면:

- **모델과 API 계약 분리**: database 모델(`User`, `Movie`)의 필드가 바뀌어도, 클라이언트가 주고받는 형태(DTO)는 그 변화와 무관하게 고정된 채로 유지할 수 있다
- **민감한 필드 노출 방지**: `User` 모델을 그대로 응답에 실어 보내다가 실수로 `password`(해시된 값이라도)까지 노출시키는 사고를 원천 차단한다
- **입력값 범위 명확화**: `CreateUserRequest`처럼 클라이언트가 실제로 보낼 수 있는 값만 딱 받아서, `id`나 `createdAt`처럼 서버가 채워야 할 값을 클라이언트가 임의로 넣는 걸 막는다

강의 초반(순수 SQL 구간)에는 이 패턴이 review 쪽에서야 뒤늦게 도입됐지만, Fluent(ORM)로 넘어오고 인증을 다루면서는 거의 예외 없이 이 원칙을 지키고 있다. 특히 인증처럼 토큰과 비밀번호를 다루는 영역에서는 이 분리가 단순한 코드 스타일을 넘어 실질적인 보안 장치로 작동한다는 걸 이번 섹션에서 확인할 수 있었다.