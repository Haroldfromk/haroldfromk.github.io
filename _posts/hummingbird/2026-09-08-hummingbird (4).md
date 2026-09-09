---
title: Hummingbird (4)
writer: Harold
date: 2026-09-08 04:06
categories: [Hummingbird]
tags: [Fluent]

toc: true
toc_sticky: true
---

## ORM(Fluent) 시작하기

지금까지는 SQL을 직접 손으로 작성해서 database와 통신했는데, 이제부터는 ORM인 Fluent를 써서 SQL 생성과 실행을 대신 맡겨보도록한다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-06.4224.png){: width="50%" height="50%"}

프로젝트를 새로 만들때 위의 사진에서 Fluent를 설치하도록 했다.
(다만 이렇게 설치할 경우 강의의 초기 프로젝트와 코드 구성이 상이하다.)

---

### 의존성 구성

`Package.swift`에 Fluent 관련 패키지들이 추가되어 있다.

```swift
dependencies: [
    // 생략
    .package(url: "https://github.com/hummingbird-project/hummingbird-fluent.git", from: "2.0.0"),
    .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
],
targets: [
    .executableTarget(name: "HelloBirdFluent",
        dependencies: [
            // 생략
            .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
        ]
    )
]
```

`Fluent`, Postgres용 driver, 그리고 Hummingbird와 Fluent를 이어주는 `HummingbirdFluent`까지 필요한 패키지가 다 포함되어 있다.

다만 직접 `hb init`으로 Hummingbird 프로젝트를 새로 생성해보면, 같은 목적인데도 구성이 살짝 다르게 나온다.

```swift
dependencies: [
    // 생략
    .package(url: "https://github.com/hummingbird-project/hummingbird-fluent.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0", traits: [.defaults, "CommandLineArguments"]),
    .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.56.0"),
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.12.0"),
],
targets: [
    .executableTarget(name: "HelloBirdFluent",
        dependencies: [
            // 생략
            .product(name: "FluentKit", package: "fluent-kit"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFluent", package: "hummingbird-fluent"),
        ]
    )
]
```


| | 강의 버전 | `hb init` 버전 |
|---|---|---|
| 사용 패키지 | `vapor/fluent` (product: `Fluent`) | `vapor/fluent-kit` (product: `FluentKit`) |
| 성격 | FluentKit을 Vapor 생명주기에 엮어주는 래퍼 | Vapor 의존성 없는 프레임워크 독립적 ORM 코어 |
| Vapor 의존성 | 딸려옴 | 없음 |

`vapor/fluent`는 원래 Vapor 프로젝트를 염두에 둔 패키지라 Vapor 의존성을 함께 끌고 온다. 지금 프로젝트는 Vapor가 아니라 Hummingbird니까, 그 의존성은 사실 불필요하다. `hb init`이 만들어주는 구성은 이 부분을 건너뛰고 Vapor에 의존하지 않는 코어 `fluent-kit`을 직접 사용하며, `HummingbirdFluent`가 이를 Hummingbird와 자연스럽게 이어주는 역할을 한다. 그래서 실제로는 `hb init` 쪽 구성이 더 정확하다.

그리고 database 쪽에서 `movies_db`는 그대로 두되 기존에 있던 `movies`, `reviews` 테이블은 미리 삭제해뒀다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-06.4955.png){: width="50%" height="50%"}

이 테이블들은 앞으로 Fluent의 migration 기능으로 새로 만들 예정이기 때문이다.

---

## Fluent로 Postgres 연결하기

이번엔 Hummingbird 애플리케이션을 Fluent를 통해 Postgres와 연결한다.

---

### import 및 Fluent 인스턴스 생성

`HummingbirdFluent`와 `FluentPostgresDriver`를 import한다. Fluent는 여러 database driver를 지원하는 ORM이라, Postgres를 쓰면 Postgres driver를, MySQL이면 MySQL driver를, SQLite면 SQLite driver를 쓰는 식이다.

```swift
import HummingbirdFluent
import FluentPostgresDriver

let fluent = Fluent(logger: logger)
```

logger는 이미 만들어둔 걸 그대로 넘긴다.

---

### 연결 설정하기

`SQLPostgresConfiguration`으로 접속 정보를 구성한다.

```swift
let config = SQLPostgresConfiguration(
    hostname: "localhost",
    port: 5432,
    username: "postgres",
    password: "",
    database: "moviesdb",
    tls: .disable
)
```

Postgres.app 기본 포트인 5432, 기본 계정 `postgres`(password 없음), 그리고 database는 `moviesdb`를 그대로 쓴다.

---

### Fluent에 driver 등록하기

Fluent한테 어떤 종류의 database를 쓸지 알려준다.

```swift
fluent.databases.use(.postgres(configuration: config), as: .psql)
```

---

### Fluent 생명주기 관리

Postgres client 때와 마찬가지로, Fluent도 `app.addServices`로 등록해서 애플리케이션이 생명주기를 관리하도록 한다.

```swift
var app = Application(
    router: router,
    configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
    logger: logger
)

app.addServices(fluent)
```

이를 위해 `app` 선언을 `let`에서 `var`로 바꿔야 한다.

이렇게 연결 설정까지는 끝났지만, 아직 실제 테이블은 하나도 없는 상태다.

---

## Migration으로 테이블 만들기

이번엔 Fluent의 migration 기능으로 `movies` 테이블을 만들어본다.

---

### Migration 파일 작성하기

`Migrations` 폴더를 만들고, 그 안에 무슨 작업을 하는 migration인지 알 수 있게 이름을 짓는다. 단순히 `CreateMovies`가 아니라 `CreateMoviesTable`처럼 `Table`을 붙이는 게 좋은데, migration이 항상 테이블 생성만 하는 건 아니고 제약 조건 추가/삭제나 컬럼 타입 변경 같은 작업도 할 수 있어서, 이름에 "무엇을 하는지"가 명확히 드러나는 게 좋다고 한다.

`AsyncMigration` 프로토콜을 채택한다(예전 방식인 `Migration` 프로토콜도 있지만 async를 지원 안 해서 이제 잘 안 쓴다). 이 프로토콜을 채택하려면 `prepare`, `revert` 두 함수를 구현해야 한다.

```swift
import FluentKit

struct CreateMoviesTable: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("movies")
            .id()
            .field("title", .string, .required)
            .field("year", .int, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("movies").delete()
    }
}
```

`prepare`는 실제로 테이블을 만들거나 컬럼을 바꾸는 등 migration이 하려는 작업을 담당하고, `revert`는 그 반대 동작을 담당한다. 여기선 테이블을 만드니까 `revert`에서는 그 테이블을 삭제한다. `id()`를 호출하면 기본적으로 UUID 타입의 primary key가 만들어진다.

---

### Migration 등록 및 실행하기

`App+build.swift`에서 이 migration을 Fluent에 등록하고 실행한다.

```swift
await fluent.migrations.add(CreateMoviesTable(), to: .psql)
// 생략
try await fluent.migrate()

return app
```

`fluent.migrate()`를 호출하면 아직 실행되지 않은 migration들을 찾아서 전부 실행한다. 서버가 재시작될 때마다 이 코드가 다시 실행되긴 하지만, 이미 실행된 migration은 다시 실행되지 않는다.

---

### 결과 확인하기

저장하고 서버가 재시작되면, Beekeeper Studio 같은 도구로 확인했을 때 `public` 스키마 안에 `movies` 테이블과 함께 `_fluent_migrations`라는 테이블이 새로 생긴 걸 볼 수 있다. `movies` 테이블은 정의한 대로 만들어져 있지만 아직 데이터는 없다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-07.1202.png){: width="50%" height="50%"}

`_fluent_migrations` 테이블은 Fluent가 어떤 migration이 이미 실행됐는지 이름 기준으로 기록해두는 곳이다. 예를 들어 `CreateMoviesTable`이 이미 실행됐다고 기록해두면, 다음에 다시 `migrate()`를 호출해도 이 migration은 건너뛴다. 이 테이블은 Fluent가 내부적으로 관리하는 용도라 직접 손대지 않는 게 좋다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-07.1244.png){: width="50%" height="50%"}

---

## Movie Model 만들기

앞서 만든 `CreateMoviesTable` migration은 어디까지나 database 스키마(테이블 구조)를 정의한 것이다. ORM의 "O", 즉 객체 쪽을 담당할 데이터 모델은 아직 없으니, 이번엔 그걸 만든다.

---

### Model 클래스 작성하기

`Models.swift`에 `FluentKit`과 `Hummingbird`를 import하고, `Movie`를 class로 정의한다.

```swift
import FluentKit
import Hummingbird

final class Movie: Model, ResponseCodable, @unchecked Sendable {
    static let schema = "movies"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "year")
    var year: Int

    init() {}

    init(id: UUID? = nil, title: String, year: Int) {
        self.id = id
        self.title = title
        self.year = year
    }
}
```

몇 가지 눈여겨볼 부분이 있다.

- Fluent의 `Model` 프로토콜을 채택해야 ORM이 제공하는 기능(저장, 조회, 업데이트 등)을 쓸 수 있다
- `class`이기 때문에 여러 context에서 안전하게 넘나들 수 있어야 하는데, 이를 위해 `@unchecked Sendable`을 붙인다
- `static let schema`로 이 모델이 어떤 테이블에 매핑되는지 지정한다(`movies`)
- `@ID(key: .id)`는 Model 프로토콜이 요구하는 필수 요소로, 기본은 UUID다(정수 기반 ID를 쓰고 싶다면 migration 쪽 스키마도 맞춰서 정수로 바꿔야 한다)
- `@Field(key: "...")`로 각 프로퍼티가 실제 컬럼 이름과 매핑된다. 컬럼 이름이 프로퍼티명과 다르면(예: DB엔 `name`인데 Swift에선 `title`을 쓰고 싶다면) `key`에 실제 컬럼 이름을 넣어주면 된다
- 빈 초기화 함수 `init()`과, 값을 다 채워서 만드는 초기화 함수 둘 다 만들어두는 게 권장되는 패턴이다

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-08.1404.png){: width="50%" height="50%"}

---

## MoviesController에 Fluent 연결하기

MVC 패턴대로 `MoviesController`를 만들어뒀지만 아직 아무 내용도 없는 상태였다. 이번엔 여기에 Fluent를 연결해서, 실제로 movie를 생성하는 기능부터 채워본다.

---

### Fluent를 의존성으로 주입하기

이전처럼 별도의 repository를 만드는 대신, `Fluent` 인스턴스를 직접 controller에 주입해서 사용한다.

```swift
import Hummingbird
import HummingbirdFluent

struct MoviesController {
    
    let fluent: Fluent

    var endpoints: RouteCollection<AppRequestContext> {
        let routeCollection = RouteCollection(context: AppRequestContext.self)
        return routeCollection
    }
    
}
```

---

### buildRouter와 연결하기

`buildRouter`가 `Fluent` 인스턴스를 파라미터로 받도록 하고, `MoviesController`를 등록할 때 그대로 넘겨준다.

```swift
func buildRouter(_ fluent: Fluent) throws -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
    }
    
    router.addRoutes(MoviesController(fluent: fluent).endpoints, atPath: "/api/movies")
    
    return router
}
```

---

### CreateMovieRequest DTO와 createMovie 함수 만들기

클라이언트가 movie를 생성할 때 보내는 값은 title과 year뿐이다(id는 database가 생성하니까). 이번에도 전용 DTO를 만든다.

```swift
struct CreateMovieRequest: ResponseCodable, Decodable, Equatable {
    let title: String
    let year: Int
}
```

```swift
var endpoints: RouteCollection<AppRequestContext> {
    let routeCollection = RouteCollection(context: AppRequestContext.self)
    routeCollection.post(use: createMovie)
    return routeCollection
}

func createMovie(request: Request, context: some RequestContext) async throws -> Movie {
    
    let request = try await request.decode(as: CreateMovieRequest.self, context: context)
    
    let db = fluent.db()
    
    let movie = Movie(title: request.title, year: request.year)
    try await movie.save(on: db)

    return movie
}
```

`fluent.db()`로 database에 접근하고, `Movie` 모델 인스턴스를 만든 뒤 `save(on:)`을 호출하는 게 전부다. INSERT 쿼리를 직접 쓰거나 `RETURNING id`로 생성된 값을 받아오는 작업이 전혀 필요 없다. ORM이 이 모든 걸 대신 처리해준다.

---

### 테스트

Postman으로 `POST /api/movies`에 `Content-Type: application/json`을 설정하고 `{"title": "Lord of the Rings", "year": 2002}`를 보내본다. 

응답으로 title, year와 함께 database가 생성한 id까지 포함된 movie가 돌아온다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-08.2559.png){: width="50%" height="50%"}

database를 직접 확인해봐도 정상적으로 저장되어 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-08.2647.png){: width="50%" height="50%"}

---

## 전체 조회 & ID로 조회하기

이번엔 Fluent로 전체 movie 목록 조회, 그리고 ID로 movie 하나 조회하는 기능을 만든다. Lord of the Rings에 이어 Spider-Man, Batman도 미리 추가해둔 상태다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.1607.png){: width="50%" height="50%"}

---

### getAll 함수

모든 데이터를 불러오는 함수를 만들어 본다.

```swift
// MoviesController
func getAll(request: Request, context: some RequestContext) async throws -> [Movie] {
    
    let db = fluent.db()
    return try await Movie.query(on: db).all()
    
}
```

`Movie.query(on:).all()` 두 줄이면 전체 조회가 끝난다. 직접 SQL을 쓰던 방식과 비교하면 확실히 간결하다.

route 등록하는 것도 잊지 말아야 한다.

```swift
routeCollection.get(use: getAll)
```

`GET /api/movies`로 요청해보면 Lord of the Rings, Batman, Spider-Man이 전부 반환된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.1821.png){: width="50%" height="50%"}

---

### getById 함수

id를 조회하여 일치하는 영화를 가져오는 함수를 만들어 본다.

```swift
func getById(request: Request, context: some RequestContext) async throws -> Movie? {
    
    let db = fluent.db()
    
    guard let id = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }

    return try await Movie.query(on: db)
        .filter(.id, .equal, id)
        .first()
}
```

URL parameter에서 `id`를 꺼내고, `filter`로 조건을 걸어서 `first()`로 하나만 가져온다.

route 등록 시 `:id` parameter를 경로에 포함시켜야 한다.

```swift
routeCollection.get(":id", use: getById)
```

`GET /api/movies/:id`로 Lord of the Rings의 id를 넣어 요청하면 정상적으로 해당 movie만 반환된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.2300.png){: width="50%" height="50%"}

---

### filter 작성 방식 두 가지

`filter`를 쓰는 방법은 두 가지다.

```swift
return try await Movie.query(on: db)
    .filter(.id, .equal, id)
    .first()
```

또는 key path를 사용하는 방식.

```swift
import FluentPostgresDriver

return try await Movie.query(on: db)
    .filter(\.$id == id)
    .first()
```

key path 방식이 좀 더 간결하고 많은 사람들이 선호한다고 하는데, 이 문법을 쓰려면 `FluentPostgresDriver`가 import되어 있어야 한다(빠지면 "binary operator cannot be applied" 에러가 난다). 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.2434.png){: width="50%" height="50%"}

결과는 두 방식 다 동일하므로 편한 쪽을 쓰면 된다.

---

## 삭제 & 수정하기

이번엔 Fluent로 movie를 삭제하고 수정하는 기능을 만든다.

---

### deleteMovie 함수

삭제된 movie 자체를 반환하는 구조로 만든다.

```swift
func deleteMovie(request: Request, context: some RequestContext) async throws -> Movie {
    
    let db = fluent.db()

    guard let id = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }

    guard let movie = try await Movie.query(on: db)
        .filter(\.$id == id)
        .first()
    else {
        throw HTTPError(.badRequest)
    }

    let _ = try await Movie.query(on: db)
        .filter(\.$id == id)
        .delete()

    return movie
}
```

먼저 삭제할 movie를 조회해서 반환할 값을 확보해두고, 그 다음 실제 삭제를 수행한다. 이때 주의할 점은, `Movie.query(on: db).delete()`처럼 `filter` 없이 바로 `delete()`를 호출하면 테이블 전체가 삭제되어 버린다는 것. 반드시 `filter`로 대상을 좁힌 뒤 삭제해야 한다.

route도 등록한다.

```swift
routeCollection.delete(":id", use: deleteMovie)
```

Batman의 id로 DELETE 요청을 보내면 삭제된 Batman 정보가 반환되고, 다시 전체 목록을 조회하면 Batman이 사라져 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.3657.png){: width="50%" height="50%"}

---

### UpdateMovieRequest DTO와 updateMovie 함수 만들기

업데이트할 때 `Movie` 모델을 직접 decode할 수도 있지만, 나중에 `createdAt`, `isPublished`처럼 클라이언트가 건드리면 안 되는 필드가 모델에 추가될 걸 대비해서 전용 DTO를 만들어두는 게 낫다.

```swift
// Models
struct UpdateMovieRequest: ResponseCodable, Decodable, Equatable {
    let id: UUID
    let title: String
    let year: Int
}
```

```swift
func updateMovie(request: Request, context: some RequestContext) async throws -> Movie {
    
    let db = fluent.db()
    
    let updateRequest = try await request.decode(as: UpdateMovieRequest.self, context: context)

    guard let movie = try await Movie.query(on: db)
        .filter(\.$id == updateRequest.id)
        .first()
    else {
        throw HTTPError(.badRequest)
    }

    movie.title = updateRequest.title
    movie.year = updateRequest.year
    
    try await movie.save(on: db)

    return movie
}
```

body에서 `id`, `title`, `year`를 받아서 기존 movie를 찾은 뒤, 프로퍼티를 직접 갱신하고 `save(on:)`을 호출한다. 부분 수정이 아니라 객체 전체를 새 값으로 갱신하는 개념이라 PUT을 사용한다.

```swift
routeCollection.put(use: updateMovie)
```

Lord of the Rings의 id로 title을 "Lord of the Rings: Fellowship of the Ring", year를 2001로 바꿔서 PUT 요청을 보내면, 응답과 database 양쪽에서 값이 갱신된 걸 확인할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-09.4127.png){: width="50%" height="50%"}

이렇게 해서 Fluent(ORM) 기반으로도 CRUD 전체를 구현했다. 코드량이 줄어드는 것도 있지만, 그보다 SQL을 문자열로 직접 작성할 때 생기는 콤마 하나 빠뜨리거나 세미콜론을 놓치는 것 같은 오타 리스크 자체가 사라진다는 게 더 크게 와닿는 장점이다.

---

## Reviews 테이블 Migration 만들기

Fluent ORM으로 review 기능을 다시 구현한다. 먼저 `reviews` 테이블을 만드는 migration부터 작성한다.

---

### CreateReviewsTable 작성하기

```swift
import FluentKit

struct CreateReviewsTable: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("reviews")
            .id()
            .field("subject", .string, .required)
            .field("comment", .string, .required)
            .field("movie_id", .uuid, .required, .references("movies", "id", onDelete: .cascade))
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("reviews")
            .delete()
    }
}
```

컬럼 구성은 이렇다.

- `subject`: review의 제목 격인 필드
- `comment`: review 본문
- `movie_id`: `movies` 테이블의 `id`를 참조하는 foreign key. `.references(...)`로 참조 관계를 지정하고, `onDelete: .cascade`로 movie가 삭제되면 관련 review도 함께 삭제되게 한다
- `created_at`: 생성 시각

`revert`는 앞서와 마찬가지로 테이블을 삭제하는 것으로 처리한다.

---

### Migration 등록하기

`App+build.swift`에서 기존에 등록해둔 `CreateMoviesTable`에 이어 이번 migration도 추가한다.

```swift
await fluent.migrations.add(CreateReviewsTable(), to: .psql)
```

서버를 재시작하면 migration이 실행되면서 `reviews` 테이블이 새로 생긴다. `id`, `subject`, `comment`, `movie_id`, `created_at` 컬럼이 정의한 대로 만들어져 있고, 아직 데이터는 비어있는 상태다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-11.3204.png){: width="50%" height="50%"}

---

## Review Model과 관계 정의하기

이번엔 Review 데이터 모델을 만들고, movie와의 관계를 Fluent 방식으로 정의해본다.

---

### Review 모델 만들기

```swift
final class Review: Model, ResponseCodable, @unchecked Sendable {
    static let schema = "reviews"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "subject")
    var subject: String

    @Field(key: "comment")
    var comment: String

    @Parent(key: "movie_id")
    var movie: Movie

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(id: UUID? = nil, subject: String, comment: String, movieId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.subject = subject
        self.comment = comment
        self.$movie.id = movieId
        self.createdAt = createdAt
    }
}
```

여기서 핵심은 `@Parent(key: "movie_id")`다. database 스키마 관점에서는 `reviews.movie_id`가 `movies.id`를 참조하는 foreign key지만, 데이터 모델 관점에서는 이 관계를 "review는 movie 하나에 속한다(belongs to)"는 의미로 표현한다. 그래서 프로퍼티 타입 자체를 `Movie`로 선언하고, `@Parent` property wrapper로 감싸서 연결을 나타낸다.

초기화 시점에는 `Movie` 객체 전체가 아니라 `movieId`만 넘겨받아서, `self.$movie.id = movieId`처럼 관계의 foreign key 값만 세팅해준다. (`$movie`처럼 프로퍼티 이름 앞에 `$`를 붙이면 관계 자체를 다루는 wrapper에 접근할 수 있다.)

---

### Movie 모델에 반대 방향 관계 추가하기

지금까지는 review → movie 방향의 관계만 만들었다. 반대로 movie 입장에서 "나는 여러 review를 가진다(has many)"는 관계도 표현해줘야 한다. `Movie` 모델에 다음을 추가한다.

```swift
@Children(for: \.$movie)
var reviews: [Review]
```

`@Parent`가 "하나에 속한다"였다면, `@Children`은 "여러 개를 가진다"는 의미다. `for: \.$movie`는 이 관계가 `Review` 모델의 `movie` 프로퍼티(정확히는 그 관계 wrapper)를 통해 연결된다는 뜻이다. 즉 "movie는 review.movie로 연결되는 review들을 여러 개 가진다"는 관계가 이렇게 표현된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/parent_children_relationship_v3.png){: width="50%" height="50%"}

---

## Review 생성하기

이번엔 `ReviewsController`를 만들어서 특정 movie에 review를 생성하는 기능을 구현한다.

---

### ReviewsController 기본 골격

`MoviesController`와 마찬가지로 `Fluent`를 의존성으로 받는다.

```swift
import Hummingbird
import HummingbirdFluent
import FluentKit

struct ReviewsController {
    
    let fluent: Fluent

    var endpoints: RouteCollection<AppRequestContext> {
        return RouteCollection(context: AppRequestContext.self)
    }
}
```

`App+build.swift`에도 등록해준다.

```swift
router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/movies/:id/reviews")
```

---

### CreateReviewRequest DTO

클라이언트가 review를 생성할 때 보내는 값은 subject와 comment 뿐이다. movieId는 URL에 있고, id와 createdAt은 자동으로 채워지는 값이라 별도 DTO를 만든다.

```swift
struct CreateReviewRequest: ResponseCodable, Decodable, Equatable {
    let subject: String
    let comment: String
}
```

---

### createReview 함수 작성하기

```swift
// ReviewsController
var endpoints: RouteCollection<AppRequestContext> {
    let routeCollection = RouteCollection(context: AppRequestContext.self)
    routeCollection.post(use: createReview)
    return routeCollection
}

func createReview(request: Request, context: some RequestContext) async throws -> Review {
    let db = fluent.db()

    guard let movieId = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }

    let createRequest = try await request.decode(as: CreateReviewRequest.self, context: context)

    let review = Review(
        subject: createRequest.subject,
        comment: createRequest.comment,
        movieId: movieId
    )

    try await review.save(on: db)

    return review
}
```

URL parameter에서 movieId를 꺼내고, body는 `CreateReviewRequest`로 decode한다. 이 둘을 조합해서 `Review` 모델을 만들고 `save(on:)`으로 저장한다.

---

### 테스트

먼저 movie 목록을 조회해서 Lord of the Rings의 id를 확인한다. `POST /api/movies/:id/reviews`에 `Content-Type: application/json`을 설정하고 subject와 comment를 담아 요청을 보내면, 생성된 review(id, subject, comment, createdAt까지 포함)가 그대로 반환된다. database를 확인해보면 movieId로 연결된 review가 잘 저장되어 있다. 여러 개를 더 추가해봐도 문제없이 다 저장된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-11.5253.png){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-11.5433.png){: width="50%" height="50%"}

만약 응답에서 review 데이터 전체가 아니라 일부만 보여주고 싶다면, movie 부분을 뺀 커스텀 DTO를 별도로 만들어서 반환하는 방법도 있다.

---

## movie 조회 시 review도 같이 가져오기

movie를 ID로 조회할 때, 앞서 추가한 review들도 같이 반환되게 만들어본다.

---

### with으로 관계 eager loading하기

`getById`에서 movie만 조회하던 쿼리에 `.with(\.$reviews)`를 추가하면, 연결된 review들까지 한 번에 가져올 수 있다.

```swift
func getById(request: Request, context: some RequestContext) async throws -> Movie? {
    
    let db = fluent.db()
    
    guard let id = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    
    guard let movie = try await Movie.query(on: db)
            .filter(\.$id == id)
            .with(\.$reviews)
            .first()
        else {
            throw HTTPError(.badRequest)
        }

    return movie
}
```

이렇게 요청해보면 movie의 id, title, year와 함께 review 배열도 응답에 포함된다. 다만 이 review들은 `Review` 데이터 모델 그대로라서, 각 review 안에 movieId를 담은 관계 정보나 createdAt처럼 클라이언트 입장에서 필요 없는 정보까지 같이 딸려온다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-12.0044.png){: width="50%" height="50%"}

---

### MovieResponse / ReviewResponse DTO로 응답 다듬기

클라이언트가 실제로 필요로 하는 형태로 다시 구성한다.

```swift
struct MovieResponse: ResponseCodable, Decodable, Equatable {
    let id: UUID
    let title: String
    let year: Int
    let reviews: [ReviewResponse]
}

extension MovieResponse {
    
    init(from movie: Movie) {
        self.id = movie.id!
        self.title = movie.title
        self.year = movie.year
        self.reviews = movie.reviews.map(ReviewResponse.init)
    }
}
```

```swift
struct ReviewResponse: ResponseCodable, Decodable, Equatable {
    let id: UUID
    let subject: String
    let comment: String
}

extension ReviewResponse {
    
    init(from review: Review) {
        self.id = review.id!
        self.subject = review.subject
        self.comment = review.comment
    }
}
```

`MovieResponse`의 초기화 함수 안에서 `Movie` 데이터 모델을 받아 필요한 값만 옮겨 담고, `reviews`도 각각 `ReviewResponse`로 변환한다. `id`는 database에서 온 값이라 항상 존재한다고 보고 강제 언래핑한다.

---

### Controller에서 변환하기

`getById`의 반환 타입을 `Movie`에서 `MovieResponse`로 바꾼다.

```swift
func getById(request: Request, context: some RequestContext) async throws -> MovieResponse {
    
    let db = fluent.db()
    
    guard let id = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    
    guard let movie = try await Movie.query(on: db)
            .filter(\.$id == id)
            .with(\.$reviews)
            .first()
        else {
            throw HTTPError(.badRequest)
        }

    return MovieResponse(from: movie)
}
```

다시 요청해보면 응답이 훨씬 깔끔해진다. movie의 id, title, year와 함께, review는 subject/comment/id만 포함된 형태로 정리되어서 온다. `movieId`가 담긴 관계 정보나 `createdAt`처럼 클라이언트 UI에 필요 없는 값은 더 이상 노출되지 않는다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-12.0656.png){: width="50%" height="50%"}

---

## 전체 review와 연결된 movie 조회하기

이번엔 admin이 쓸 법한 기능으로, 전체 review를 그 review가 속한 movie 정보와 함께 조회하는 걸 만든다.

---

### getAll 함수 작성하기

`ReviewsController`에 `getAll`을 추가한다. `Movie.query`에서 `.with(\.$reviews)`를 썼던 것처럼, 이번엔 `Review.query`에서 `.with(\.$movie)`로 연결된 movie를 같이 가져온다.

```swift
func getAll(request: Request, context: some RequestContext) async throws -> [Review] {
        
    let db = fluent.db()
    
    return try await Review.query(on: db)
        .with(\.$movie)
        .all()
}
```

route도 등록한다.

```swift
routeCollection.get(use: getAll)
```

---

### 별도 경로로 등록하기

기존에 `ReviewsController`는 `/api/movies/:id/reviews` 경로로만 등록되어 있었는데, 이번 기능은 특정 movie에 종속되지 않으니 `/api/reviews` 경로로 한 번 더 등록한다.

```swift
router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/reviews")
```

`GET /api/reviews`로 요청해보면 review 목록과 함께 각 review에 연결된 movie 정보까지 그대로 반환된다.

지금은 `Review` 데이터 모델을 그대로 반환하고 있어서 movie 관계 정보나 불필요한 필드까지 딸려오는데, 필요하다면 앞서 만든 `MovieResponse`/`ReviewResponse` 같은 방식으로 DTO를 만들어서 원하는 형태로만 다듬을 수도 있다. 다만 이런 "전체 review + movie" 조회는 일반 사용자보다는 admin 관점에 가까운 기능이고, 개별 사용자 입장에서는 movie ID 기준으로 review를 조회하는 기존 방식이 더 적절하다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/CleanShot_08-12.2159.png){: width="50%" height="50%"}

---

## 경로만 지정했는데 함수가 호출되는 이유

`routeCollection.get(use: getAll)`에는 경로를 적지 않았고, `addRoutes`에는 `/api/reviews`라는 경로만 넘겼는데 어떻게 `getAll`이 호출되는지 짚고 넘어간다.

---

### RouteCollection은 상대 경로만 알고 있다

```swift
routeCollection.get(use: getAll)
```

여기서 경로를 생략한 건 "이 RouteCollection 기준으로 루트 경로(`""`)에 GET 요청이 오면 `getAll`을 호출해라"라는 뜻이다. 즉 이 시점에는 최종 URL이 뭐가 될지 전혀 모르는 상태고, 어디에 붙든 그 지점을 기준으로 적용될 **상대 경로 규칙**만 담고 있다.

---

### addRoutes가 prefix를 붙여 확정한다

```swift
router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/reviews")
```

`addRoutes`가 하는 일은 두 가지다.

1. `endpoints`가 들고 있는 상대 경로 규칙들(`GET ""` → `getAll`, `POST ""` → `createReview`)을 전부 꺼내온다
2. 각 규칙 앞에 `atPath`로 지정한 prefix를 붙여서 실제 router에 등록한다

그래서 `GET ""`였던 규칙이 이 시점에 `GET /api/reviews`로 확정되고, 해당 요청이 들어오면 `getAll`이 호출된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/route_mounting_fixed.png){: width="50%" height="50%"}

---

### 같은 controller를 여러 경로에 mount할 수 있는 이유

이 구조 덕분에 동일한 `ReviewsController`를 서로 다른 prefix에 각각 등록할 수 있다.

```swift
router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/movies/:id/reviews")
router.addRoutes(ReviewsController(fluent: fluent).endpoints, atPath: "/api/reviews")
```

controller 안의 배선(`GET ""` → `getAll`)은 그대로 두고, 그걸 어느 위치에 꽂아 넣느냐만 달라지는 것이다. 미리 조립해둔 배선판을 벽의 다른 콘센트에 꽂는 것과 비슷하다고 보면 된다.

---

### 결론: (경로, method) 조합이 곧 하나의 라우트다

라우터는 내부적으로 "경로"만이 아니라 "경로 + HTTP method" 조합을 하나의 키로 취급한다. 그래서 같은 `/api/movies`라는 경로라도 GET이면 `getAll`, POST면 `createMovie`처럼 완전히 다른 함수로 연결된다.

Postman에서 method를 선택해서 요청을 보내는 건 클라이언트가 "이런 조합의 요청을 보낸다"는 사실을 만드는 것일 뿐이고, 실제로 그 요청의 (경로, method)를 자기가 등록해둔 테이블과 대조해서 일치하는 함수를 찾아 실행하는 건 전적으로 서버(라우터) 쪽의 역할이다. 클라이언트가 능동적으로 뭔가를 맞추는 게 아니라, 서버가 들어온 요청 정보를 보고 수동적으로 탐색해서 연결하는 구조인 것이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-4/method_path_matching_fixed.png){: width="50%" height="50%"}