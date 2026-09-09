---
title: Hummingbird (2)
writer: Harold
date: 2026-09-07 12:06
categories: [Hummingbird]
tags: []

toc: true
toc_sticky: true
---

## MVC 패턴 적용하기

MVC는 UIKit 할 때 하도 많이 써서 익숙한 개념이지만, 백엔드에서는 Model, View, Controller가 각각 조금 다른 역할을 한다. Model은 데이터의 형태(dog가 있으면 name, age, breed, weight, height 같은 속성들), View는 클라이언트가 눈으로 보는 화면(웹이든 iOS든 뭐든), Controller는 그 사이에서 요청을 처리하고 응답(View든 JSON 데이터든)을 돌려주는 중간자 역할이다. 우리 프로젝트는 API 서버라 View는 없고, Model(Movie)과 Controller 위주로 구조를 잡아본다.

---

### Controller 폴더 구성

`App` 폴더 밑에 `Controllers` 폴더를 만들고, `MovieController`를 생성한다. Controller는 `RouteCollection`을 프로퍼티로 가지고, 그 안에 실제 route들을 등록한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-18.4008.png){: width="50%" height="50%"}

이때 `routeCollection.get(use:)`에서 `use`로 넘기는 함수는 아무 함수나 되는 게 아니라, `request`와 `context`를 받아서 뭔가를 반환하는(그리고 `async throws`인) 특정 시그니처를 만족해야 한다. 그래서 `getMovies` 함수를 그 시그니처에 맞게 정의해두면, `use: getMovies`라고 참조만 해줘도 알아서 연결된다.

```swift
struct MovieController {
    let movieStore: MovieStore

    var endpoints: RouteCollection<AppRequestContext> {
        let routeCollection = RouteCollection(context: AppRequestContext.self)
        routeCollection.get(use: getMovies)
        return routeCollection
    }

    func getMovies(request: Request, context: some RequestContext) async throws -> String {
        "Movies"
    }
}
```

일단 간단하게 문자열만 반환하는 route 하나로 시작한다.

---

### buildRouter에 등록하기

기존에 `buildRouter`에 잔뜩 있던 route 코드는 지우고(일단 주석 처리), `router.addRoutes`로 controller를 등록한다.

```swift
router.addRoutes(MovieController(movieStore: MovieStore()).endpoints, atPath: "/api/movies")
```

이제 `/api/movies`로 오는 모든 요청은 `MovieController`가 처리하게 된다. 실제로 접속해보면 "movies"가 잘 반환된다.

---

### Repository 패턴 도입

지금까지 쓰던 `MovieStore`는 사실상 "데이터를 어디선가 가져오는" 역할이니, 이 개념을 `Repository`로 옮긴다. 나중에 실제 데이터베이스를 연결하게 되면, repository 내부 구현만 바뀌고 controller는 그대로 유지될 수 있게 하기 위함이다.

```swift
actor MovieRepository {
    private var movies: [Movie] = [
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
    
    func getMovies() -> [Movie] {
        movies
    }

    func addMovie(_ movie: Movie) {
        movies.append(movie)
    }
}

// MovieController
let repository: MovieRepository
```

`movies`는 아예 `private`으로 막아버리고, `getMovies()` 같은 함수를 통해서만 접근하도록 한다. Controller에서는 `repository.getMovies()`를 호출해서 movie 목록을 반환한다.

```swift
func getMovies(request: Request, context: some RequestContext) async throws -> [Movie] {
    await repository.getMovies()
}
```

---

### Naming 컨벤션: MovieRepository vs MoviesController

Repository는 단수(`MovieRepository`), Controller는 복수(`MoviesController`)로 이름 붙이는 게 컨벤션이라고 한다. Controller는 리소스(movies라는 컬렉션) 전체를 다루는 개념이라 복수형이 더 적절하다는 것.

그래서 

```swift
struct MoviesController { }
```

이렇게 바꿔주었다.

---

### 나머지 route 옮기기: movie ID로 조회

기존에 만들어둔 movie ID 조회 route도 controller로 옮긴다. 

먼저 `endpoints`에도 등록해준다.

```swift
routeCollection.get(":id", use: getMoviesByID)
```

이어서 use에 들어갈 함수를 만들어 준다.
아직 return 부분은 만들 수 없기에 가능한 부분을 먼저 해준다.

이때 이전에는 파라미터가 `movieID`였지만 이제는 `id`이다.

```swift
func getMoviesByID(request: Request, context: some RequestContext) async throws -> Movie? {
    guard let id = context.parameters.get("id", as: Int.self) else {
        throw HTTPError(.badRequest)
    }
    
}
```

repository에도 단일 movie를 찾는 함수를 추가한다.

```swift
// MovieRepository
func movie(id: Int) -> Movie? {
    movies.first(where: { $0.id == id })
}
```

이후 함수를 마무리 해준다.

```swift
func getMoviesByID(request: Request, context: some RequestContext) async throws -> Movie? {

    guard let id = context.parameters.get("id", as: Int.self) else {
        throw HTTPError(.badRequest)
    }
    
    return await repository.movie(id: id)
}
```

스샷은 없지만 확인해보니(http://127.0.0.1:8080/api/movies/1) 잘 되는걸 알 수 있다.

---

### POST route 옮기기: movie 생성

POST route도 마찬가지로 옮긴다. `routeCollection.post`에 별도 경로를 안 주면 controller가 등록된 prefix(`/api/movies`) 그대로 POST 요청을 받는다.

먼저 endpoint에 추가를 해준다.

```swift
routeCollection.post(use: createMovie)
```

그리고 함수를 만들어 준다.


```swift
func createMovie(request: Request, context: some RequestContext) async throws -> Movie {
    let movie = try await request.decode(as: Movie.self, context: context)
}
```

그리고 기존에 만들어둔 addMovie에서 createMovie로 바꿔주었다.
이때 배열에 추가를하고 그 배열을 다시 리턴하는 식으로 고쳐주었다.

```swift
// MovieRepository {
func createMovie(_ movie: Movie) -> Movie {
    movies.append(movie)
    return movie
}
```

여기도 함수를 마무리 해준다.

```swift
func createMovie(request: Request, context: some RequestContext) async throws -> Movie {
    let movie = try await request.decode(as: Movie.self, context: context)
    return await repository.createMovie(movie)
}
```

---

### 테스트

Postman으로 전체 movie 목록 조회, 특정 movie 조회, movie 추가(Finding Nemo)까지 다 정상 동작을 확인했다. 다만 여전히 메모리에만 저장되는 구조라, 서버를 재시작하면 추가한 데이터는 사라진다. movie가 여러 review를 가지거나 actor와 many-to-many 관계를 맺는 것처럼 실제 관계형 데이터를 다루려면 결국 database가 필요하다.

사진은 생략.

---

## Postgres 설치하기

이제 Hummingbird API 프로젝트에 Postgres 데이터베이스를 붙여본다. 설치 방법은 여러 가지가 있지만, 제일 간단한 건 Postgres.app을 쓰는 것.

---

### Postgres.app 설치

[postgresapp.com](https://postgresapp.com){:target="_blank"}에서 다운로드하고 설치하면 메뉴 바에 아이콘이 뜬다. 열어보면 기본 데이터베이스가 한두 개 보이고, 필요하면 Initialize 버튼을 눌러줘야 서버가 켜지기도 한다. 정상적으로 실행되면 Postgres 서버가 돌아가고 있는 게 확인된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-19.3736.png){: width="50%" height="50%"}

start를 눌러준다.

그럼 아래와 같이 뜨는데 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-19.3823.png){: width="50%" height="50%"}

더블클릭을 하면 터미널사용에 대해 유져의 권한 허용이 필요하다.
모르고 거절을 했다면

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-19.3910.png){: width="50%" height="50%"}

여기서 다시 허용을 해주면 된다.

---

### 데이터베이스 만들기

내 이름으로 된걸 더블클릭하면 터미널이 실행이 된다. 여기서 movies 애플리케이션용 데이터베이스를 하나 만든다.(Postgres.app에서 아무 database 이름을 더블클릭하면 접속되고, 거기서 SQL 명령어로 새 데이터베이스를 만들 수 있다.)

```sql
CREATE DATABASE moviesdb;
```

세미콜론을 꼭 붙여야 명령어가 완성된다(안 붙이면 계속 다음 줄로 넘어가버린다). 키워드를 대문자로 쓰는 건 습관일 뿐, 필수는 아니다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-19.4110.png){: width="50%" height="50%"}

실행하고 나면 Postgres.app 목록에 `moviesdb`가 생긴 걸 확인할 수 있다. 지금은 빈 데이터베이스고, 테이블은 앞으로 Hummingbird 구현을 통해 만들어나갈 예정이다.

---

## Postgres Client 붙이기

이제 Hummingbird 애플리케이션에 실제로 Postgres client를 연결해본다. Postgres.app으로 서버는 이미 띄워둔 상태다.

---

### PostgresNIO 의존성 추가

`Package.swift`에 [PostgresNIO](https://github.com/vapor/postgres-nio){:target="_blank"} 의존성을 추가한다. 이때 `dependencies`뿐 아니라 executable target의 `dependencies`에도 같이 추가해줘야 한다.

```swift
// Package
dependencies: [
    // 생략
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "App",
        dependencies: [
            // 생략
            .product(name: "PostgresNIO", package: "postgres-nio"),
        ]
    )
]
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-19.5143.png){: width="50%" height="50%"}

---

### PostgresNIO import 문제 해결

강의대로 했으나 import할때 `No Such Module` 에러가 발생했다.

reset, resolve package, swift 파일 재실행을 해보아도 되지 않았다.

마지막으로 한것이 `DerivedData` 삭제였다.

그렇게 하니 해결이 되었다.

---

### MovieRepository를 Postgres client 기반으로 바꾸기

`MovieRepository`가 이제 Postgres client에 의존하게 된다. `actor`가 아니라 `struct`로 바꾸고, 기존에 있던 함수들은 일단 다 지운다(나중에 다시 채울 예정). Controller 쪽 코드는 당장 깨질 수 있는데, 관련 route 등록 부분은 일단 주석 처리해둔다.

```swift
import PostgresNIO

struct MovieRepository {
    let client: PostgresClient
}
```

---

### buildApplication에서 client 설정하기

`buildApplication` 함수 안에서 Postgres client를 생성하고, 그 client를 넣어서 repository를 만든다.

```swift
var movieRepository: MovieRepository?
var router: Router<AppRequestContext>

let client = PostgresClient(
    configuration: .init(
        host: "localhost",
        username: "postgres",
        password: nil,
        database: "movies_db",
        tls: .disable
    )
)

let repository = MovieRepository(client: client)
movieRepository = repository

router = try buildRouter(repository: repository)
```

호스트는 localhost, username은 Postgres.app 설치 시 기본으로 잡히는 `postgres`, password는 없어서 `nil`, database는 앞서 만든 `movies_db`, TLS는 로컬 개발이니 disable로 둔다.

`buildRouter` 함수도 이 repository를 파라미터로 받도록 바꿔서, controller를 초기화할 때 넘겨준다.

```swift
func buildRouter(_ repository: MovieRepository) throws -> Router<AppRequestContext> {
    // 생략
}
```

---

### addServices로 client 생명주기 관리

Postgres client처럼 시작/종료를 관리해야 하는 객체는 `app.addServices`로 등록한다. 이렇게 등록하면 Hummingbird가 해당 객체의 생명주기(시작, 종료)를 대신 관리해준다. Postgres뿐 아니라 MongoDB, Redis 같은 다른 database client에도 똑같이 쓸 수 있는 방식이다.

```swift
var app = Application(
        router: router,
        configuration: ApplicationConfiguration(reader: reader.scoped(to: "http")),
        logger: logger
    )
    
if let movieRepository {
    app.addServices(movieRepository.client)
}
```

이때 기존에 `let app`으로 되어있던것을 `var app`으로 바꿔준다.

---

### 테이블 생성하기

`MovieRepository`에 테이블을 생성하는 함수를 추가한다.

```swift
func createTable() async throws {
    try await client.query("""
            CREATE TABLE IF NOT EXISTS movies (
            
                id UUID PRIMARY KEY,
                title TEXT NOT NULL,
                year INTEGER NOT NULL
            
            )
            
        """)
}
```

`IF NOT EXISTS`를 붙여서 테이블이 이미 있으면 다시 만들지 않도록 한다. 컬럼은 id(UUID, primary key), title(TEXT, not null), year(INTEGER, not null)로 구성.

이 함수는 서비스가 시작되기 전에 호출해서, 서버가 뜰 때 테이블이 항상 준비되어 있도록 한다.

```swift
if let movieRepository {
    app.addServices(movieRepository.client)
    app.beforeServerStarts {
        try await repository.createTable()
    }
}
```

`watchexec`로 서버가 재시작되면서 정상적으로 실행되면 테이블이 생성된다. 다만 지금은 테이블 안에 아무 데이터도 없는 상태이다.

---

## 테이블 생성 확인하기

앞서 `MovieRepository`의 `createTable` 함수로 만든 테이블이 실제로 잘 생성됐는지 확인해본다. 방법은 두 가지, 터미널로 직접 확인하는 방법과 GUI 도구를 쓰는 방법이다.

---

### 터미널(psql)로 확인하기

Postgres.app에서 `movies_db`를 더블클릭하면 psql 터미널로 접속된다.

스키마 목록을 확인하면 `public`, `pg_database_owner`가 보인다.

```bash
moviesdb=# \dn
      List of schemas
  Name  |       Owner       
--------+-------------------
 public | pg_database_owner
(1 row)

moviesdb=# \dt
           List of tables
 Schema |  Name  | Type  |  Owner   
--------+--------+-------+----------
 public | movies | table | postgres
(1 row)
```

현재 스키마의 테이블 목록을 보면 `movies` 테이블이 실제로 생성되어 있는 걸 확인할 수 있다. `createTable` 함수가 정상적으로 동작했다는 증거다.

```bash
moviesdb=# \d movies
               Table "public.movies"
 Column |  Type   | Collation | Nullable | Default 
--------+---------+-----------+----------+---------
 id     | uuid    |           | not null | 
 title  | text    |           | not null | 
 year   | integer |           | not null | 
Indexes:
    "movies_pkey" PRIMARY KEY, btree (id)
```

테이블 구조를 보면 정의한 대로 id, title, year 컬럼이 그대로 잡혀있다. `\d+ movies`로 하면 primary key 등 좀 더 자세한 정보까지 볼 수 있다.

```sql
moviesdb=# select * from movies;
 id | title | year 
----+-------+------
(0 rows)
```

데이터를 조회해보면 아직 아무것도 insert한 적이 없어서 비어있다.

`\q`로 psql 터미널을 빠져나올 수 있다.

---

### Beekeeper Studio로 확인하기

터미널 대신 GUI로 보고 싶다면 [Beekeeper Studio](https://www.beekeeperstudio.io/){:target="_blank"} 같은 무료 도구를 쓸 수 있다(Community 버전 무료, macOS Intel/Apple Silicon 지원). 물론 이런 종류의 도구는 이거 말고도 많으니 편한 걸 쓰면 된다.

연결 설정에서 connection type을 PostgreSQL로 선택하고, user는 `postgres`, password는 비워두고(설치 시 자동 생성된 계정), database는 `movies_db`로 지정한 다음 Test 버튼으로 연결을 확인하고 접속하면 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-21.2903.png){: width="50%" height="50%"}

접속하면 테이블 목록이 보이고, View Data로 데이터를(지금은 비어있음), View Structure로 테이블 구조를 시각적으로 확인할 수 있다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-21.2950.png){: width="50%" height="50%"}

---

## 실제로 movie 저장하기

이제 database에 movie를 실제로 insert하는 `save` 함수를 만들어본다. Repository에 이 함수를 하나 추가하면, 지금까지 만든 controller와 route가 진짜 database랑 연결된다.

---

### save 함수 작성하기

```swift
func save(_ movie: Movie) async throws -> Movie {
    let id = UUID()
    try await self.client.query("""
        
        INSERT INTO movies (id, title, year) VALUES (\(id), \(movie.title), \(movie.year));
        
        """)
    
    return Movie(id: id, title: movie.title, year: movie.year)
}
```

ID는 서버에서 생성해서 넣어주고, INSERT 쿼리를 실행한 뒤 생성된 movie를 그대로 반환한다.

이 과정에서 몇 가지 타입 불일치가 드러났다. Model에서 `name`으로 되어있던 필드를 `title`로 통일해야 했고, 기존에 `id`가 `Int`였던 걸 `UUID`로 바꿔야 했다(테이블 정의 자체가 UUID 기반이었으니까). `id` 타입을 바꾸는 순간 관련 코드 전체가 줄줄이 컴파일 에러로 깨졌는데, 이걸 하나하나 손으로 고치는 대신 AI 에이전트(Codex)한테 "Movie의 id를 UUID로 바꿔줘" 정도로 맡겨서 한 번에 정리했다.

```swift
struct Movie {
    let id: UUID
    let title: String
    let year: Int
}

actor MovieStore {
    
    private(set) var movies: [Movie] = [
        Movie(id: UUID(), title: "The Shawshank Redemption", year: 1994),
        // 생략
    ]

}
```

참고로 이제 database가 실제로 데이터를 영속화해주니 `MovieStore`는 더 쓸 일이 없어져서, 이후에 정리하며 삭제하게 된다.

---

### Controller에 연결하기

`MoviesController`의 `createMovie`에서 이제 `repository.save(_:)`를 실제로 호출하도록 채운다.

```swift
// MoviesController
routeCollection.post(use: createMovie)

func createMovie(request: Request, context: some RequestContext) async throws -> Movie {
    let movie = try await request.decode(as: Movie.self, context: context)
    return try await repository.save(movie)
}
```

---

### Postman으로 테스트하다가 만난 에러

`POST /api/movies`로 title "Finding Nemo", year 2010을 보내봤다(헤더에 `Content-Type: application/json` 포함). 그런데 "coding key id was not found"라는 에러가 났다. 

```json
{
    "error": {
        "message": "Coding key `id` not found."
    }
}
```

클라이언트가 `id`를 안 보내는 게 당연한데(서버가 생성하는 값이니까), Movie 모델의 `id`가 필수 값으로 되어있어서 decode가 실패한 것.

`id`를 optional로 바꿔서 해결했다.

```swift
struct Movie {
    var id: UUID?
    let title: String
    let year: Int
}
```

이젠 send를 하면 이렇게 나오는걸 알 수 있다.

```json
{
    "title": "Finding Nemo",
    "year": 2010,
    "id": "8A882022-2341-4E6B-9320-6C37F1F94071"
}
```

---

### 검증

다시 요청을 보내니 생성된 movie가 JSON으로 잘 반환됐다. Beekeeper Studio에서 View Data 후 새로고침해보니 실제로 Finding Nemo가 id, title, year와 함께 database에 저장되어 있는 걸 확인했다. 요청이 controller → repository → database까지 끝까지 잘 이어졌다는 뜻이다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-22.0956.png){: width="50%" height="50%"}

---

## 전체 movie 목록 조회하기

movie를 몇 개 더 추가해봤다(Lord of the Rings(2002), Batman(2026)). Beekeeper Studio로 확인해보니 다 database에 잘 저장되어 있다. 이제 이 movie들을 전부 목록으로 가져오는 기능을 만들어본다.

---

### getAll 함수 작성하기

Repository에 `getAll` 함수를 추가한다. Postgres client로 쿼리를 실행하면 결과가 async stream 형태로 돌아오는데, 이걸 순회하면서 movie 배열을 채우는 방식이다.

```swift
func getAll() async throws -> [Movie] {
    let stream = try await self.client.query("SELECT id, title, year FROM movies;")

    var movies: [Movie] = []
    
    for try await (id, title, year) in stream.decode((UUID, String, Int).self, context: .default) {
        let movie = Movie(id: id, title: title, year: year)
        movies.append(movie)
    }
    return movies
}
```

`SELECT *` 대신 컬럼 이름을 명시적으로 나열하는 게 좋다고 한다. 그래야 내부적으로 만들어지는 build plan이 캐싱되어서 재사용될 수 있기 때문. `stream.decode`에는 가져올 컬럼들의 타입을 튜플로 지정해주고(`UUID`, `String`, `Int`), context는 기본으로 제공되는 `.default`(Postgres decoding context)를 그대로 쓴다.

---

### Controller에 연결하기

`MoviesController`에서 주석 처리해뒀던 `routeCollection.get(use: getMovies)`를 다시 살리고, 실제로 `repository.getAll()`을 호출하도록 채운다.

```swift
routeCollection.get(use: getMovies)

func getMovies(request: Request, context: some RequestContext) async throws -> [Movie] {
    try await repository.getAll()
}
```

---

### 테스트

Postman으로 `GET /api/movies`를 호출해보니 Finding Nemo, Lord of the Rings, Batman까지 database에 저장했던 movie 세 개가 그대로 반환됐다. database에서 저장하고 다시 꺼내오는 흐름이 끝까지 잘 연결됐다는 뜻이다. 

```json
[
    {
        "year": 2010,
        "id": "8A882022-2341-4E6B-9320-6C37F1F94071",
        "title": "Finding Nemo"
    },
    {
        "year": 2002,
        "id": "7B568498-8CA8-4B45-BC7D-3512E3644393",
        "title": "Lord of the Rings"
    },
    {
        "year": 2026,
        "id": "EA8E0159-8A83-41D3-9582-35FB508353D6",
        "title": "Batman"
    }
]
```

---

## ID로 movie 하나 조회하기

이번엔 movie ID를 받아서 그에 해당하는 movie 하나만 조회하는 기능을 만든다.

---

### getByID 함수 작성하기

`MovieRepository`에 `getByID` 함수를 추가한다. 앞서 `getAll`에서 쓴 것과 같은 async stream 방식을 그대로 활용한다.

```swift
func getById(_ id: UUID) async throws -> Movie? {
    
    let stream = try await self.client.query("""
        
            SELECT id, title, year
            FROM movies
            WHERE id = \(id)
            LIMIT 1;
        
        """)

    for try await (id, title, year) in stream.decode((UUID, String, Int).self, context: .default) {
        return Movie(id: id, title: title, year: year)
    }
    
    return nil
}
```

`WHERE id = ...`로 조건을 걸고 `LIMIT 1`을 붙여서 정확히 한 개만 가져오게 한다. 어차피 한 개만 오니까 stream에서 첫 값을 만나면 바로 그걸 반환하고, 만약 아무것도 안 왔다면(=해당 id가 없다면) `nil`을 반환한다.

---

### Controller에 연결하기

`MoviesController`에는 이미 `:id` dynamic parameter를 받는 route가 있었는데(`/api/movies/:id`), 여기에 연결되는 함수를 채운다.

함수 이름은 원래 `getMoviesByID`였는데, 이건 movie 하나만(primary key 기준) 조회하는 거니까 `getMovieByID`로 단수형으로 바로잡았다.

```swift
routeCollection.get(":id", use: getMovieById)

func getMovieById(request: Request, context: some RequestContext) async throws -> Movie? {

    guard let movieId = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    
    guard let movie = try await repository.getById(movieId) else {
        throw HTTPError(.notFound)
    }
    return movie
}
```

이때 `movieID`가 더 이상 `Int`가 아니라 `UUID`이므로 parameter 타입도 맞춰서 수정해야 한다. movie가 없으면 not found를 던지고, 있으면 그대로 반환한다.

---

### 테스트

Postman으로 실제 movie ID(꽤 긴 UUID 문자열)를 URL에 넣어서 요청해보니, Finding Nemo가 정상적으로 반환됐다. 다른 ID(Batman)로도 확인해보니 마찬가지로 잘 동작한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_07-22.5543.png){: width="50%" height="50%"}

---

## movie 삭제하기

이번엔 movie를 삭제하는 기능을 만든다.

---

### delete 함수 작성하기

`MovieRepository`에 `delete` 함수를 추가한다. ID를 받아서 삭제하고, 삭제된 movie를 그대로 반환하는 구조다.

```swift
func delete(_ id: UUID) async throws -> Movie {
    
    guard let movie = try await getById(id) else {
        throw MovieError.notFound
    }
    
    try await client.query("DELETE FROM movies WHERE id = \(id);")
    return movie
}
```

먼저 앞서 만들어둔 `getById`로 해당 ID의 movie가 실제로 존재하는지부터 확인한다. 이렇게 작은 함수들을 미리 만들어두면 이런 식으로 재사용할 수 있어서 좋다. 존재하지 않으면 에러를 던지고, 존재하면 primary key 기준으로 `DELETE` 쿼리를 실행한 뒤 삭제된 movie를 반환한다.

에러는 별도 타입으로 정의했다.

```swift
enum MovieError: Error {
    case notFound
}
```

지금은 같은 파일에 두지만, 나중에 별도 파일로 분리하는 게 좋다고 한다.

---

### Controller에 연결하기

`MoviesController`에 delete route를 추가한다.

```swift
routeCollection.delete(":id", use: deleteMovie)
```

```swift
func deleteMovie(request: Request, context: some RequestContext) async throws -> Movie {
    
    guard let movieId = context.parameters.get("id", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }

    do {
        return try await repository.delete(movieId)
    } catch MovieError.notFound {
        throw HTTPError(.notFound)
    }
}
```

URL에서 movie ID를 꺼내고, `repository.delete`를 호출한다. `MovieError.notFound`가 던져지면 이걸 잡아서 HTTP not found 에러로 변환해서 응답한다.

---

### 테스트

먼저 전체 movie 목록을 조회해서 Batman의 ID를 확인한다. Postman에서 method를 DELETE로 설정하고 해당 ID로 요청을 보내면, 삭제된 Batman 정보가 응답으로 돌아온다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_08-00.4036.png){: width="50%" height="50%"}

다시 전체 목록을 조회해보면 Batman은 사라지고 Finding Nemo, Lord of the Rings만 남아있다. database에서 직접 확인해도 Batman이 삭제된 걸 볼 수 있다.

```json
[
    {
        "year": 2010,
        "id": "8A882022-2341-4E6B-9320-6C37F1F94071",
        "title": "Finding Nemo"
    },
    {
        "year": 2002,
        "id": "7B568498-8CA8-4B45-BC7D-3512E3644393",
        "title": "Lord of the Rings"
    }
]
```

---

## movie 수정하기

이번엔 movie를 업데이트하는 기능을 만든다. 제목을 잘못 썼거나 연도를 바꿔야 하는 경우처럼, 기존 movie를 수정할 수 있어야 한다.

---

### update 함수 작성하기

`MovieRepository`에 `update` 함수를 추가한다. 업데이트된 값이 담긴 movie 객체를 통째로 받아서, 업데이트된 movie를 그대로 반환하는 구조다.

```swift
func update(_ movie: Movie) async throws -> Movie {
    
    guard let movieId = movie.id,
            let _ = try await getById(movieId)
    else {
        throw MovieError.notFound
    }


    try await client.query("""

            UPDATE movies
            SET title = \(movie.title), year = \(movie.year) 
            WHERE id = \(movieId);

        """)

    return movie
}
```

`movie.id`는 optional이라 `guard let`으로 먼저 풀어준다. 그리고 앞서 만든 `getByID`로 해당 ID의 movie가 실제로 존재하는지 확인하고(없으면 `MovieError.notFound`), 존재하면 `UPDATE` 쿼리를 실행한다. `WHERE` 절로 ID를 지정하는 게 제일 중요한 부분인데, 이걸 빠뜨리면 movies 테이블 전체가 업데이트되어 버린다.

---

### Controller에 연결하기

`MoviesController`에 update route를 추가한다. HTTP method는 PUT과 PATCH 둘 다 쓸 수 있는데, PUT은 객체 전체를 새 값으로 교체한다는 의미고 PATCH는 일부 필드만 부분적으로 수정한다는 의미다. 여기서는 PUT을 쓴다.

```swift
routeCollection.put(use: updateMovie)
```

```swift
func updateMovie(request: Request, context: AppRequestContext) async throws -> Movie {
    let movie = try await request.decode(as: Movie.self, context: context)
    return try await repository.update(movie)
}
```

URL에 별도로 ID를 안 받는 대신, body에 담긴 movie의 `id`를 그대로 사용한다.

---

### 테스트

Finding Nemo의 ID를 확인한 뒤, Postman에서 PUT 요청으로 title을 "Finding Dory", year를 2023으로 바꿔서 보낸다. 응답으로 수정된 movie가 그대로 돌아오고, database를 확인해보면 실제로 Finding Nemo가 Finding Dory로 바뀌어 있다. ID 기준으로 정확히 그 레코드만 업데이트된 것.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_08-00.4613.png){: width="50%" height="50%"}

이렇게 해서 movies controller, movies repository를 거쳐 database까지 이어지는 CRUD(Create, Read, Update, Delete) 전체 흐름을 완성했다.

---

## buildApplication 정리하기

`buildApplication` 함수 안에 `movieRepository`, `repository` 두 개가 같은 스코프에 따로 존재하고 있었다는 걸 발견했다. 둘 다 movie 데이터에 접근하는 용도인데 굳이 나눠져 있을 이유가 없어서, 하나로 정리한다.

```swift
var movieRepository: MovieRepository?
// 생략
let repository = MovieRepository(client: client)
```

---

### 중복 제거하기

기존에 있던 별도의 `repository` 변수는 지우고, `movieRepository`로 통일한다. 이제 `movieRepository`가 더 이상 optional이 아니게 되면서, 이걸 optional unwrap하던 부분도 같이 제거할 수 있었다.

```swift
let movieRepository = MovieRepository(client: client)

router = try buildRouter(repository: movieRepository)

app.addServices(movieRepository.client)
app.beforeServerStarts {
    try await movieRepository.createTable()
}
```

`movieRepository` 인스턴스 하나가 `buildRouter`로 전달되어 router를 만들고, `movieRepository.client`가 service로 등록되고, `createTable()`도 이 인스턴스로 실행된다. `buildApplication` 안에 movie repository 인스턴스가 딱 하나만 존재하게 되어 흐름이 좀 더 깔끔해졌다.

---

## ID 생성을 database로 넘기기

지금까지는 movie를 저장할 때 애플리케이션 코드에서 `UUID()`를 직접 만들어서 넣어줬는데, 이 책임을 database 쪽으로 옮겨본다. 

```swift
func save(_ movie: Movie) async throws -> Movie {
    let id = UUID()
    try await self.client.query("""
        
        INSERT INTO movies (id, title, year) VALUES (\(id), \(movie.title), \(movie.year));
        
        """)
    
    return Movie(id: id, title: movie.title, year: movie.year)
}
```

지금은 이렇게 코드 단위에서 UUID를 생성하여 집어넣는 구조이다.

즉, database가 결국 데이터의 최종 소스니까, ID 생성도 database가 맡는 게 더 자연스럽다는 것.

---

### 테이블에 default 값 설정하기

`createTable`에서 `id` 컬럼에 default 값을 지정한다.

```swift
func createTable() async throws {
    try await client.query("""
            CREATE TABLE IF NOT EXISTS movies (
            
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                title TEXT NOT NULL,
                year INTEGER NOT NULL
            
            )
            
        """)
}
```

`gen_random_uuid()`는 Postgres에 내장된 함수로, 랜덤 UUID를 생성해준다(다른 DBMS라면 함수 이름이 다를 수 있다). 다만 이미 테이블이 존재하는 상태에서는 `CREATE TABLE IF NOT EXISTS`가 무시되니, 기존 `movies` 테이블을 한 번 drop하고 서버를 재시작해서 새 정의로 다시 만들어야 반영된다.

Beekeeper Studio에서 구조를 확인해보면 id 컬럼에 default 값으로 `gen_random_uuid()`가 잡혀있는 걸 볼 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-07-hummingbird-2/CleanShot_08-01.3244.png){: width="50%" height="50%"}

---

### save 함수 수정하기

이제 애플리케이션에서 ID를 직접 만들 필요가 없다. INSERT 쿼리에서 `RETURNING id`를 붙이면, 새로 생성된 ID가 결과 스트림으로 돌아온다.

```swift
enum DatabaseError: Error {
    case insertFailed
}

func save(_ movie: Movie) async throws -> Movie {
    
    let stream = try await self.client.query("""
        
        INSERT INTO movies (title, year) VALUES (\(movie.title), \(movie.year))
        RETURNING id;
        
        """)
    
    for try await id in stream.decode(UUID.self, context: .default) {
        return Movie(id: id, title: movie.title, year: movie.year)
    }
    
    throw DatabaseError.insertFailed
}
```

`getAll`이나 `getByID`에서 튜플로 여러 컬럼을 decode했던 것과 달리, 여기선 `id` 하나만 받아오면 되니까 `stream.decode(UUID.self, ...)`로 단일 값만 꺼낸다. 혹시라도 아무것도 반환되지 않으면 `DatabaseError.insertFailed`를 던진다.

Controller 쪽 코드는 전혀 바뀌지 않는다. `save` 함수를 호출하는 방식은 그대로고, 내부 구현만 달라졌을 뿐이다.

---

### 프로젝트 구조 정리

이 김에 코드 구조도 정리한다.

- `MovieError`, `DatabaseError` 같은 커스텀 에러들은 `CustomErrors/Errors.swift`로 분리
- `Movie` 모델은 `Models/Models.swift`로 분리 (모델이 늘어나면 이 파일에 계속 추가)
- 이제 완전히 안 쓰이는 `MovieStore`는 삭제

이렇게 정리하고 나니, `save` 함수는 이제 ID 생성에 신경 쓸 필요 없이 title과 year만 다루면 되고, ID는 database 레벨에서 자동으로 생성되는 깔끔한 구조가 됐다.