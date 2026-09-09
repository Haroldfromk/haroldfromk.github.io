---
title: Hummingbird (3)
writer: Harold
date: 2026-09-08 03:06
categories: [Hummingbird]
tags: []

toc: true
toc_sticky: true
---

## One-to-Many 관계 설정하기

이번엔 movie와 review의 관계를 다룬다. 하나의 movie가 여러 개의 review를 가질 수 있으니, 이건 one-to-many 관계다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/movie_review_relationship_v2.png){: width="50%" height="50%"}

---

### Review 모델 만들기

`Models.swift`에 `Review`를 추가한다.

```swift
struct Review {
    var id: UUID?
    let comment: String
    let rating: Int
    var movieId: UUID
    var createdAt: Date?
}

extension Review: ResponseEncodable, Decodable, Equatable { }
```

movie와의 관계를 나타내기 위해 `movieId`를 갖고, 언제 작성됐는지 알기 위해 `createdAt`도 추가한다. `Movie`와 마찬가지로 `ResponseEncodable`, `Decodable`, `Equatable`을 채택해야 route에서 바로 반환할 수 있다.

---

### ReviewsController 기본 골격 만들기

review 관련 기능(저장, 삭제, 전체 조회 등)을 movies controller에 몰아넣기보다는, 전용 controller를 따로 만드는 게 낫다. 일단은 아직 review repository가 없으니, 빈 골격만 만들어둔다.

```swift
import Hummingbird

struct ReviewsController {
    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
    }
}
```

---

### buildRouter에 등록하기

`buildRouter`가 나중엔 movie repository뿐 아니라 review repository도 파라미터로 받게 될 예정이지만, 지금은 review repository가 없으니 `ReviewsController`를 의존성 없이 그대로 등록한다.

```swift
router.addRoutes(ReviewsController().endpoints, atPath: "/api/movies/:movieId/reviews")
```

review는 특정 movie에 종속된 리소스이므로, URL 경로에 `movieID`를 포함시켜서 `/api/movies/:movieId/reviews` 형태로 설계한다. 지금은 route가 하나도 등록되어 있지 않아서 실제로 동작하는 건 없지만, 나중에 review repository가 만들어지면 이 부분을 채워나갈 골격이다.

---

## ReviewRepository와 reviews 테이블 만들기

이제 review를 실제로 저장할 수 있도록 `ReviewRepository`를 만들고, `reviews` 테이블을 생성한다.

---

### createTable 함수 작성하기

`ReviewRepository`도 `MovieRepository`처럼 Postgres client에 의존한다.

```swift
import PostgresNIO

struct ReviewRepository {
    
    let client: PostgresClient

    func createTable() async throws {
        
        try await self.client.query("""
            
            CREATE TABLE IF NOT EXISTS reviews(
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                movie_id UUID NOT NULL,
                rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
                comment TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            
                CONSTRAINT fk_movie 
                    FOREIGN KEY (movie_id)
                    REFERENCES movies(id)
                    ON DELETE CASCADE
            )
        
        """)
    }
}
```

컬럼 구성은 이렇다.

- `id`: UUID, primary key, `gen_random_uuid()`로 자동 생성
- `movie_id`: not null, foreign key로 `movies(id)`를 참조. movie가 삭제되면 관련 review도 같이 삭제되도록 `ON DELETE CASCADE`를 걸었다
- `rating`: not null이면서 `CHECK` 제약으로 1~5 사이 값만 허용
- `comment`: review 본문
- `created_at`: 기본값으로 `CURRENT_TIMESTAMP`를 넣어서, 값을 안 넘겨도 생성 시각이 자동으로 기록되게 한다

foreign key 제약이 중요한데, 이게 없으면 review에 아무 movie ID나 넣어도 통과되어 버린다. movies 테이블에 실제로 존재하는 ID만 허용하도록 강제하는 게 목적이다.

---

### AppDependencies로 repository 묶기

`buildRouter`가 movie repository 하나만 받도록 되어 있었는데, review repository까지 늘어나면 파라미터를 계속 추가해야 하는 문제가 생긴다. 대신 여러 repository를 묶는 struct를 하나 만든다.

```swift
struct AppDependencies {
    let movieRepository: MovieRepository
    let reviewRepository: ReviewRepository
}
```

`buildApplication`에서 두 repository를 만들고 `AppDependencies`로 묶어서 `buildRouter`에 전달한다.

```swift
let movieRepository = MovieRepository(client: client)
let reviewRepository = ReviewRepository(client: client)

let dependencies = AppDependencies(
    movieRepository: movieRepository,
    reviewRepository: reviewRepository
)

router = try buildRouter(dependencies)

func buildRouter(_ dependencies: AppDependencies) throws -> Router<AppRequestContext> {
    // 생략
    router.addRoutes(MoviesController(repository: dependencies.movieRepository).endpoints, atPath: "/api/movies")
    // 생략
}

```

`buildRouter` 안에서는 `dependencies.movieRepository`, `dependencies.reviewRepository`로 각 controller에 필요한 repository를 꺼내 쓰면 된다.

그리고 ReviewsController에 repository도 추가해준다.

```swift
// ReviewsController
let repository: ReviewRepository

// App+build
router.addRoutes(ReviewsController(repository: dependencies.reviewRepository).endpoints, atPath: "/api/movies/:movieId/reviews")
```

테이블 생성도 movie repository와 마찬가지로 서비스가 시작되기 전에 호출해준다.

```swift
try await dependencies.reviewRepository.createTable()
```

---

### 주의해야 할 점

SQL에서 컬럼 정의 사이에 콤마(`,`) 하나만 빠져도 전체 쿼리가 syntax error로 실패한다. 특히 `CREATE TABLE`처럼 컬럼이 여러 줄에 걸쳐 나열되는 쿼리에서는, 줄 끝마다 콤마가 제대로 붙어있는지 하나씩 확인하는 습관을 들이는 게 좋다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-03.2252.png){: width="50%" height="50%"}

강의에선 여기에서 `,`를 붙이지 않아 에러가 발생했었다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-03.2349.png){: width="50%" height="50%"}

이렇게 잘 만들어진걸 확인할 수 있다.

또한 Relationships도 잘 형성 되어있는걸 알 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-03.2425.png){: width="50%" height="50%"}

---

## review 저장하기

이번엔 특정 movie에 review를 저장하는 기능을 만든다.

---

### DTO로 요청 body 분리하기

`POST /api/movies/:movieID/reviews`로 요청이 들어올 때, 클라이언트가 실제로 보내는 값은 `comment`와 `rating` 뿐이다. `movieID`는 URL에 이미 있고, `id`나 `createdAt`은 database가 자동으로 채워주는 값이라 클라이언트가 보낼 이유가 없다. 그래서 `Review` 모델을 그대로 decode하는 대신, 요청 body 전용 DTO를 따로 만든다.

```swift
struct CreateReviewRequest {
    let comment: String
    let rating: Int
}

extension CreateReviewRequest: ResponseEncodable, Decodable, Equatable { }
```

`Review`와 마찬가지로 `ResponseEncodable`, `Decodable`, `Equatable`을 채택한다.

---

### createReview 함수 작성하기

`ReviewsController`에 POST route를 추가한다.

```swift
routeCollection.post(use: createReview)
```

```swift
func createReview(request: Request, context: some RequestContext) async throws -> Review {
    
    guard let movieId = context.parameters.get("movieId", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }

    let createReviewRequest = try await request.decode(as: CreateReviewRequest.self, context: context)

    let review = Review(
        comment: createReviewRequest.comment,
        rating: createReviewRequest.rating,
        movieId: movieId
    )

    return try await repository.save(review)
}
```

`movieID`는 URL parameter에서 꺼내고, body는 `CreateReviewRequest`로 decode한다. 이 둘을 조합해서 `Review`를 만들고 repository에 저장을 위임한다.

---

### Repository에 save 함수 추가하기

`ReviewRepository`에도 `MovieRepository.save`와 같은 패턴으로 `save` 함수를 추가한다. INSERT 후 `RETURNING id`로 생성된 ID를 받아온다.

```swift
func save(_ review: Review) async throws -> Review {
    let stream = try await client.query("""
        
            INSERT INTO reviews (movie_id, rating, comment) VALUES (\(review.movieId), \(review.rating), \(review.comment))
            RETURNING id
        
        """)

    for try await id in stream.decode(UUID.self, context: .default) {
        return Review(id: id, comment: review.comment, rating: review.rating, movieId: review.movieId)
    }

    throw DatabaseError.insertFailed
}
```

---

### route 충돌 문제 다시 만나기

서버가 정상적으로 안 뜨는 문제가 있었는데, 원인은 이전에 movies route에서 봤던 것과 같은 route 충돌이었다. `MoviesController`에서 movie 단건 조회에 쓰던 dynamic parameter 이름이 `id`였는데, `ReviewsController`가 등록한 경로에서는 같은 위치의 parameter가 `movieId`였다. 

```swift
// MoviesController
var endpoints: RouteCollection<AppRequestContext> {
    let routeCollection = RouteCollection(context: AppRequestContext.self)
    routeCollection.get(use: getMovies)
    // /api/movies/2
    routeCollection.get(":id", use: getMovieById)
    routeCollection.post(use: createMovie)
    routeCollection.delete(":id", use: deleteMovie)
    routeCollection.put(use: updateMovie)
    return routeCollection
}

func deleteMovie(request: Request, context: some RequestContext) async throws -> Movie {
    
    guard let movieId = context.parameters.get("movieId", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    // 생략
}

func getMovieById(request: Request, context: some RequestContext) async throws -> Movie? {

    guard let movieId = context.parameters.get("movieId", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    // 생략
}

// App+build
router.addRoutes(ReviewsController(repository: dependencies.reviewRepository).endpoints, atPath: "/api/movies/:movieId/reviews")
```

이름이 다른 parameter가 같은 depth에서 겹치면서 라우팅이 꼬여버린 것. `MoviesController` 쪽 parameter 이름도 `movieId`로 통일해서 해결했다.

```swift
routeCollection.get(":movieId", use: getMovieById)
routeCollection.post(use: createMovie)
routeCollection.delete(":movieId", use: deleteMovie)
```


---

### 테스트

먼저 movie 목록을 조회해서 movie ID를 확인한다(현재는 Batman 하나).

만약 하나도 없을 경우 추가를 해준다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-03.5859.png){: width="50%" height="50%"}

그 ID를 이용해 `POST /api/movies/:movieID/reviews`로 comment와 rating을 담아 요청을 보내면, 생성된 review가 그대로 응답으로 돌아온다. 

하지만 지금 내상황은 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-04.0624.png){: width="50%" height="50%"}

이렇게 에러가 발생한다.

이건 스스로 해결을 해보려 한다.

알고보니 

```swift
routeCollection.put(use: createReview) // ❌
routeCollection.post(use: createReview) // ✅
```

블로그 글을 제대로 적었으나 실제 코드에는 `put`으로 자동완성을 해버린것....

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-04.1018.png){: width="50%" height="50%"}

이제는 잘 들어간걸 알 수 있다.

database를 확인해보면 movie ID, rating, comment가 잘 저장되어 있고, `created_at`도 자동으로 채워져 있다. 같은 movie에 review를 여러 개 추가하는 것도 문제없이 동작한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-04.1106.png){: width="50%" height="50%"}![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-04.1138.png){: width="50%" height="50%"}

---

## movie 조회 시 review도 같이 가져오기

이번엔 movie를 ID로 조회할 때, 그 movie에 달린 review들도 같이 반환하도록 만든다.

---

### MovieDetail DTO 만들기

`Movie` 모델 자체에는 review를 담을 자리가 없다. 그렇다고 기존 데이터 매핑을 바꾸는 건 좋은 방법이 아니라서, movie와 review를 함께 담는 별도의 DTO를 만든다.

```swift
struct MovieDetail {
    let id: UUID
    let title: String
    let year: Int
    let reviews: [Review]
}

extension MovieDetail: ResponseEncodable, Decodable, Equatable { }
```

`Movie`, `Review`와 마찬가지로 `ResponseEncodable`, `Decodable`, `Equatable`을 채택한다.

---

### getById가 MovieDetail을 반환하도록 바꾸기

`MovieRepository.getByID`가 이제 `Movie`가 아니라 `MovieDetail`을 반환하도록 바꾼다. movie 정보를 가져온 뒤, 같은 movie ID로 review들도 조회해서 합쳐서 반환하는 구조다.

```swift
func getById(_ id: UUID) async throws -> MovieDetail? {
    
    let stream = try await self.client.query("""
        
            SELECT id, title, year
            FROM movies
            WHERE id = \(id)
            LIMIT 1;
        
        """)
    
    for try await (id, title, year) in stream.decode((UUID, String, Int).self, context: .default) {
        
        let reviewStream = try await self.client.query("""
                SELECT id, movie_id, comment, rating, created_at FROM reviews
                WHERE movie_id = \(id)
                
            """)
        
        var reviews: [Review] = []
        
        for try await (reviewId, movieId, comment, rating, createdAt) in reviewStream.decode((UUID, UUID, String, Int, Date).self, context: .default) {
                reviews.append(Review(id: reviewId, comment: comment, rating: rating, movieId: movieId, createdAt: createdAt))
            }
        
        return MovieDetail(id: id, title: title, year: year, reviews: reviews)
    }
    
    return nil
}
```

---

### findMovieByID로 기존 로직 재사용하기

`getByID`가 `Movie`를 반환하던 시절엔 `delete` 함수가 이걸 그대로 가져다 썼는데, 반환 타입이 `MovieDetail`로 바뀌면서 `delete`가 깨져버린다. 그래서 원래 `getByID`가 하던 일(순수하게 movie 하나만 조회)을 `findMovieByID`라는 이름으로 따로 빼서, `delete`는 이쪽을 쓰도록 한다.

```swift
func findMovieById(_ id: UUID) async throws -> Movie? {
    let stream = try await self.client.query("""
            SELECT id, title, year
            FROM movies
            WHERE id = \(id)
            LIMIT 1;
        
        """)

    for try await (movieId, title, year) in stream.decode((UUID, String, Int).self, context: .default) {
        return Movie(id: movieId, title: title, year: year)
    }
    return nil
}
```

---

### Controller 반환 타입 맞추기

`MoviesController.getMovieById`도 이제 `Movie`가 아니라 `MovieDetail`을 반환하도록 타입을 맞춰준다.

```swift
func getMovieById(request: Request, context: some RequestContext) async throws -> MovieDetail? {

    guard let movieId = context.parameters.get("movieId", as: UUID.self) else {
        throw HTTPError(.badRequest)
    }
    
    guard let movieDetail = try await repository.getById(movieId) else {
        throw HTTPError(.notFound)
    }
    return movieDetail
}
```

---

### 테스트

`GET /api/movies/:movieId`로 조회해보면, movie의 id/title/year와 함께 그 movie에 달린 review들이 배열로 깔끔하게 같이 반환된다. 이 응답 하나만으로 클라이언트가 movie 상세 화면에 review까지 바로 표시할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-06.2019.png){: width="50%" height="50%"}

---

## 전체 review 조회하기 (movie 정보 포함)

이번엔 데이터베이스에 있는 모든 review를, 각 review가 어떤 movie에 달린 건지와 함께 반환하는 기능을 만든다. 고객용 화면보다는 admin이 전체 review를 관리할 때 쓸 법한 endpoint다.

---

### ReviewDetail DTO 만들기

`Review`에는 `movieId`만 있고 movie의 title이나 year 같은 정보는 없다. 그래서 `MovieDetail`과 비슷하게, review와 movie를 함께 담는 DTO를 만든다.

```swift
struct ReviewDetail {
    let id: UUID
    let comment: String
    let rating: Int
    let movie: Movie
}

extension ReviewDetail: ResponseEncodable, Decodable, Equatable { }
```

---

### getAll 함수 작성하기 (JOIN 사용)

`ReviewRepository`에 `getAll` 함수를 추가한다. review와 movie를 같이 가져와야 하니 SQL `JOIN`을 사용한다.

```swift
func getAll() async throws -> [ReviewDetail] {
    
    let stream = try await self.client.query("""
        
        SELECT r.id, r.comment, r.rating, m.id, m.title, m.year
        FROM reviews r INNER JOIN movies m ON r.movie_id = m.id;
        
        """)

    var reviews: [ReviewDetail] = []
    
    for try await (reviewId, comment, rating, movieId, title, year) in stream.decode((UUID, String, Int, UUID, String, Int).self, context: .default) {
        let movie = Movie(id: movieId, title: title, year: year)
        let review = ReviewDetail(id: reviewId, comment: comment, rating: rating, movie: movie)
        reviews.append(review)
    }
    
    return reviews
}
```

`r`, `m`을 각각 reviews, movies 테이블의 alias로 쓰고, `r.movie_id = m.id` 조건으로 두 테이블을 이어붙인다. 결과로 나오는 튜플을 movie와 review로 각각 재구성해서 `ReviewDetail` 배열로 만든다.

---

### Controller에 연결하기

`ReviewsController`에 route를 추가한다.

```swift
routeCollection.get(use: getAll)
```

```swift
func getAll(request: Request, context: some RequestContext) async throws -> [ReviewDetail] {
    try await repository.getAll()
}
```

---

### 별도 경로로 등록하기

기존에 `ReviewsController`가 등록된 경로는 `/api/movies/:movieId/reviews`였는데, 이번 기능은 특정 movie에 종속된 게 아니라 전체 review를 대상으로 하니까 movie ID가 필요 없다. 그래서 같은 `ReviewsController`를 별도 경로로 한 번 더 등록한다.

```swift
router.addRoutes(ReviewsController(repository: dependencies.reviewRepository).endpoints, atPath: "/api/reviews")
```

이제 `/api/reviews`로 요청하면 전체 review 목록을, 각 review에 딸린 movie 정보(id, title, year)까지 함께 받아올 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-08-hummingbird-3/CleanShot_08-06.2909.png){: width="50%" height="50%"}