---
title: Hummingbird (6)
writer: Harold
date: 2026-09-09 07:06
categories: [Hummingbird]
tags: [railway, docker]

toc: true
toc_sticky: true
---

## Docker로 로컬 배포 준비하기

이제 [Railway](https://railway.com/deploy/hummingbird--hummingbird){:target="_blank"}에 배포하기 위한 준비 작업을 시작한다.

이 강의에선 [Railway Github](https://github.com/dangdennis/railway-hummingbird){:target="_blank"}을 참고하는데, 내용을 보면 Docker로 Postgres와 앱을 함께 띄우는 방식을 쓴다. 로컬에서 먼저 Docker로 정상 동작을 확인한 뒤, 그 이미지를 Railway에 배포하는 순서로 진행한다.

---

### Docker 설치

`docker compose up -d`를 실행하려면 먼저 Docker가 설치되어 있어야 한다. [docker.com](https://www.docker.com/products/docker-desktop/){:target="_blank"}에서 Docker Desktop을 다운로드해서 설치한다(Apple Silicon/Intel용이 따로 있으니 맞는 걸 선택).

설치를 하면 터미널에서 `docker` 명령어가 바로 안 먹히는 문제가 있었다. `docker: command not found`가 뜨는데, 이건 Docker Desktop이 설치되긴 했지만 그 실행 파일 경로가 셸의 `PATH`에 안 잡혀 있어서 생기는 문제다.

이럴 땐 Docker 앱 자체가 제공하는 터미널을 먼저 열어서 설치 경로부터 확인해야 한다. Docker Desktop을 실행하고, 우측 상단 톱니바퀴(Settings) 옆이나 메뉴에서 터미널을 열 수 있는 옵션을 찾아 실행한다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-10.5503.png){: width="50%" height="50%"}

그러면 `/Applications/Docker.app/Contents/Resources/bin/docker` 이 경로에 설치되어 있다는 걸 확인할 수 있다.

이제 이 경로를 셸의 `PATH`에 추가해주면 된다. `~/.zshrc`를 연다.

```bash
open ~/.zshrc
```

그리고 파일 맨 아래에 다음 줄을 추가한다.

```text
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
```

저장한 뒤, 변경사항을 바로 적용하려면 터미널을 재시작하거나 아래 명령어로 현재 세션에 다시 로드한다.

```bash
source ~/.zshrc
```

이제 일반 터미널에서 `docker -v`을 입력해보면 정상적으로 버전 정보가 출력되는 걸 확인할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-10.5815.png){: width="50%" height="50%"}

---

### docker-compose.yml 작성하기

프로젝트 루트에서 `docker compose up -d`를 실행하면 "no configuration found"라는 에러가 난다. `docker-compose.yml` 파일이 없기 때문이다. 파일을 만들고 아래 내용을 채운다.

```yaml
volumes:
  db_data:

services:
  db:
    image: postgres:16-alpine
    volumes:
      - db_data:/var/lib/postgresql/data/pgdata
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: moviesdb
    ports:
      - "5432:5432"

```

주요 부분만 짚으면:

- `volumes.db_data`: named volume을 만든다. 이게 없으면 container를 내렸을 때 database 데이터가 전부 날아간다
- `services.db.image`: `postgres:16-alpine`처럼 가벼운(alpine 기반) Postgres 이미지를 pull해서 쓴다. 버전을 명시해두면 나중에 이미지가 예기치 않게 바뀌는 걸 방지할 수 있다
- `volumes` (service 내부): 위에서 만든 named volume을 container 내부의 실제 데이터 저장 경로에 매핑한다. 이 경로는 `PGDATA` 환경 변수 값과 정확히 일치해야 한다
- `PGDATA`: Postgres가 실제로 데이터 파일을 저장할 위치를 지정한다. 위 volume 매핑 경로와 같은 값을 줘야 데이터가 named volume에 제대로 쌓인다
- 나머지 `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, 포트 등은 이름 그대로다

---

### 로컬에서 서버 실행 확인

`swift build`로 먼저 빌드한다. 이 과정에서 안 쓰는 변수 관련 warning이 뜨면 배포 전에 정리해두는 게 좋다. 빌드가 성공하면 `swift run`으로 서버를 로컬에서 실행해서 정상 동작을 확인한다.

---

### 환경 변수를 실제로 읽어오도록 수정하기

Railway 템플릿의 Docker 실행 커맨드를 보면 database host, port, username, password, name 같은 값들을 전부 환경 변수로 주입하고 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.0711.png){: width="50%" height="50%"}

그런데 지금까지 프로젝트는 `JWT_SECRET` 하나만 env에서 읽어오고, 나머지 database 관련 설정은 여전히 코드에 하드코딩되어 있었다. 

```swift
// App+build
guard let jwtSecret = reader.string(forKey: "JWT_SECRET") else {
        fatalError("keys are missing")
    }
    
let config = SQLPostgresConfiguration(
    hostname: "localhost",
    port: 5432,
    username: "postgres",
    password: "",
    database: "moviesdb",
    tls: .disable
)
```

그래서 이 값들도 환경 변수에서 읽어오도록 고친다.

```swift
// App+build
import Foundation

let env = ProcessInfo.processInfo.environment

let config = SQLPostgresConfiguration(
    hostname: env["DATABASE_HOST"] ?? "localhost",
    port: Int(env["DATABASE_PORT"] ?? "5432") ?? 5432,
    username: env["DATABASE_USERNAME"] ?? "postgres",
    password: env["DATABASE_PASSWORD"] ?? "postgres",
    database: env["DATABASE_NAME"] ?? "moviesdb",
    tls: .disable
)
```

환경 변수가 없으면 기존 로컬 개발용 기본값으로 대체되도록 `??`로 fallback을 걸어둔다.

다시 `swift build`를 통해 문제가 없는지 확인을 해본다.

---

### Docker 이미지 빌드 및 실행

```
docker build -t hummingbird-movies-app .
```

처음 시도했을 때 "fail to connect to the Docker API"라는 에러가 났는데, 원인은 Docker Desktop 앱을 실수로 꺼둔 상태였기 때문이었다. Docker Desktop을 다시 켜고 재시도하니 이미지 빌드가 정상적으로 진행됐다.

이미지가 만들어지면 실행한다. 이때 환경 변수들을 하나씩 `-e` 옵션으로 넘겨준다.

```
docker run -p 8080:8080 \
  -e DATABASE_HOST=localhost \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e DATABASE_NAME=moviesdb \
  hummingbird-movies-app
```

---

### 실행하면서 만난 문제들

몇 가지 시행착오가 있었다.

- **JWT secret key 누락**: 처음 실행했을 때 "fatal error: keys are missing"가 떴는데, `.env` 파일에 있던 `JWT_SECRET` 값을 `-e` 옵션으로 안 넘겼기 때문이었다. `.env` 파일 내용을 확인해서 그대로 넘기니 해결됐다.
- **database 연결 에러**: `DATABASE_HOST`를 `localhost`로 넘겼더니 connection reset 에러가 났다. 원인은 이 애플리케이션이 Docker container 안에서 실행되고 있는데, container 입장에서 `localhost`는 컨테이너 자기 자신을 가리키지, Mac 호스트 머신을 가리키지 않기 때문이었다. Docker가 제공하는 특수 호스트 이름인 `host.docker.internal`로 바꾸니 정상적으로 연결됐다.

```text
docker run -p 8080:8080 \
  -e DATABASE_HOST=host.docker.internal \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e DATABASE_NAME=moviesdb \
  -e JWT_SECRET=a-much-longer-random-secret-key-for-testing-purposes-1234567890 \
  hummingbird-movies-app
```

---

### 결과 확인

이렇게 실행하니 서버가 정상적으로 뜨고 지정한 포트에서 listen하는 게 확인됐다. `/api/movies`로 요청을 보내보면(로그인을 안 한 상태라 인증 에러가 나긴 하지만) 요청 자체는 API까지 정상적으로 도달한다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.2421.png){: width="50%" height="50%"}

즉 Docker container 안에서 애플리케이션과 Postgres가 서로 통신하며 정상 동작하고 있다는 뜻이다.

이제 로컬에서 검증이 끝난 Docker 이미지를 가지고 있으니, 다음 단계는 이 이미지를 Railway에 배포하는 것이다.

---

## Railway에 Docker 이미지 배포하기

로컬에서 검증한 Docker 이미지를 Railway에 배포한다.

---

### GitHub 연동 대신 Docker 이미지 방식을 선택한 이유

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.2625.png){: width="50%" height="50%"}

Railway는 GitHub 저장소를 연결해서 클라우드에서 직접 빌드하는 방식도 지원하는데, 이 경우 빌드 시간이 30~45분 이상 걸리고 종종 실패하기도 한다. 그래서 로컬에서 미리 빌드해둔 Docker 이미지를 그대로 push해서 배포하는 방식을 쓰는 게 더 낫다.

---

### AMD64용 이미지 빌드해서 Docker Hub에 push하기

지금까지 로컬에서 만든 이미지는 Apple Silicon(ARM) 기준으로 빌드된 것이다. Railway 같은 클라우드 환경은 보통 AMD64 아키텍처를 쓰기 때문에, 배포용 이미지는 `linux/amd64` 플랫폼을 명시해서 다시 빌드해야 한다.

```
docker buildx build \
--platform linux/amd64 \
-t dongik/hummingbird-movies-app:latest \
--push .
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.3610.png){: width="50%" height="50%"}

여기서 `-t` 뒤에 오는 값은 `<Docker Hub 계정 아이디>/<이미지 이름>:<태그>` 형식이다. `dongik`이 Docker Hub 계정 아이디이고, 이 값이 있어야 `--push`했을 때 어느 계정의 어느 레포지토리로 올릴지 Docker가 알 수 있다. 계정 아이디 없이 이미지 이름만 쓰면 로컬 태그로만 인식되어 push할 대상을 찾지 못한다.

이 명령어를 처음 실행하면 Docker Hub 로그인이 안 되어 있을 경우 브라우저를 열어서 로그인하라는 안내가 뜬다(Google 계정 등으로). 로그인이 되어 있으면 바로 빌드와 push가 진행된다. 크로스 플랫폼 빌드라 시간이 꽤 걸리는 편이라 어느정도 여유를 두고 기다리는 게 좋다.

빌드와 push가 끝나면 Docker Hub의 Repositories 메뉴에서 해당 이미지가 올라간 걸 확인할 수 있다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.4711.png){: width="50%" height="50%"}

---

### Railway에 새 프로젝트 만들기

Railway 대시보드에서 새 프로젝트를 만들고 "Deploy from Docker Image"를 선택한 뒤, Docker Hub 계정이 연결되어 있으면 방금 push한 이미지를 검색해서 선택할 수 있다.

---

### 겪었던 문제: 이미지를 못 찾음

이미지를 찾지 못하는 문제가 두 가지 다른 형태로 나타났다.

**케이스 1: "image could not be found"**

처음 시도했을 때 "image could not be found"라는 배포 실패 메시지가 떴다. 이미지 이름을 잘못 입력했다고 생각해서 Docker Hub에서 정확한 이미지 이름을 다시 확인했는데, 눈으로 보기엔 같아 보였다. 연결을 끊었다가 Docker Hub 쪽에서 이미지를 다시 찾아 연결하니 정상적으로 인식됐고, 배포가 진행되어 성공적으로 끝났다.

**케이스 2: `library/` 네임스페이스로 잘못 인식되는 경우**

또 다른 경우엔 이런 에러가 났다.

```text
Deploy > Create container

The image "docker.io/library/hummingbird-movies-app:latest" could not be
pulled from the registry. If the image is private, check that the registry
credentials saved for this service are still valid.
```

에러 메시지를 자세히 보면 `docker.io/library/hummingbird-movies-app:latest`로 되어 있는데, 여기서 `library/`가 문제였다. `library`는 Docker Hub에서 공식(official) 이미지들이 올라가는 예약된 네임스페이스이지, 내 계정(`dongik`) 네임스페이스가 아니다. 즉 Railway에 이미지를 연결할 때 계정 아이디 없이 `hummingbird-movies-app:latest`만 입력해서, Docker가 기본값으로 `library/` 네임스페이스에서 이미지를 찾으려다 실패한 것이었다.

실제로 push한 이미지는 `dongik/hummingbird-movies-app:latest`였으므로, Railway의 이미지 경로 입력란에도 계정 아이디를 포함해서 `dongik/hummingbird-movies-app`로 정확히 다시 입력해야 했다. 이렇게 고치니 정상적으로 이미지를 pull해와서 배포가 진행됐다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.5857.png){: width="50%" height="50%"}

---

### Postgres 서비스 추가하기

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-11.5925.png){: width="50%" height="50%"}

Railway 프로젝트 안에서 "Database" → "Postgres"를 선택하면 별도의 Postgres 서비스가 새로 생성된다. 이 프로젝트 안에는 이제 애플리케이션 서비스와 Postgres 서비스, 두 개가 함께 존재하게 된다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.0239.png){: width="50%" height="50%"}

---

### 겪었던 문제: keys are missing

Postgres를 추가하고 나서 애플리케이션 로그를 확인해보니 "keys are missing"이라는 에러로 죽어있었다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.0120.png){: width="50%" height="50%"}

원인은 명확했다. 로컬 Docker 실행 때는 `-e` 옵션으로 환경 변수를 직접 넘겨줬지만, Railway에는 아직 그 값들(database 관련 정보, `JWT_SECRET` 등)을 설정해두지 않았기 때문이다. Railway는 각 서비스마다 Variables 탭에서 환경 변수를 key-value 형태로 등록할 수 있는데, 애플리케이션 서비스뿐 아니라 Postgres 서비스 쪽에도 필요한 값을 설정해야 한다.

---

## 환경 변수 설정하고 최종 배포하기

Railway에 Postgres와 애플리케이션, 두 서비스 모두 환경 변수를 설정해야 crash 없이 정상적으로 뜬다. 하나씩 채워나간다.

---

### Postgres 서비스에 변수 설정하기

Postgres 서비스의 Variables 탭에서 Raw Editor를 열면, key-value 여러 개를 한 번에 붙여넣을 수 있다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.0708.png){: width="50%" height="50%"}

username은 `postgres`인데, password는 처음엔 어디 있는지 헷갈렸다. Railway가 Postgres 서비스에 자동으로 생성해둔 값들 중에서 connection password에 해당하는 값을 찾아서 복사해 넣었다.

`JWT_SECRET`은 사실 Postgres 서비스에는 필요 없는 값이지만(애플리케이션 쪽에서만 쓰는 값이니까), 굳이 문제될 건 없어서 그냥 같이 넣어뒀다.

```swift
DATABASE_HOST="${{RAILWAY_PRIVATE_DOMAIN}}"
DATABASE_PORT="5432"
DATABASE_USERNAME="postgres"
DATABASE_PASSWORD="CLuImkozBhaoQwNUfVfbemQJUcYHocjK"
DATABASE_NAME="railway"
JWT_SECRET="a-much-longer-random-secret-key-for-testing-purposes-1234567890"
PGDATA="/var/lib/postgresql/data/pgdata"
```

변수를 저장하면 Railway가 자동으로 재배포를 시작한다. 

deployment 자체는 성공으로 뜨더라도 post-deploy 단계가 별도로 실패할 수 있어서, 로그를 계속 지켜보면서 완전히 안정적으로 뜨는지 확인해야 한다.

---

### 애플리케이션 서비스에도 변수 설정하기

같은 방식으로 애플리케이션 서비스의 Variables에도 Raw Editor로 필요한 값들(database 관련 값들과 `JWT_SECRET`)을 채운다. 이 값들이 들어가야 애플리케이션과 database 사이에 연결이 생긴다.

```swift
DATABASE_HOST="${{Postgres.RAILWAY_PRIVATE_DOMAIN}}"
DATABASE_PORT="5432"
DATABASE_USERNAME="postgres"
DATABASE_PASSWORD="CLuImkozBhaoQwNUfVfbemQJUcYHocjK"
DATABASE_NAME="railway"
JWT_SECRET="a-much-longer-random-secret-key-for-testing-purposes-1234567890"
```

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.1443.png){: width="50%" height="50%"}

두 서비스 모두 Deploy를 눌러서 재배포를 진행하고, 각각의 배포와 post-deploy가 다 안정적으로 완료됐는지 로그로 확인한다.

---

### 도메인 생성하기

배포된 서비스에 접근할 URL이 필요하다. 애플리케이션 서비스의 Settings → Networking에서 Generate Domain을 선택하면 Railway가 자동으로 도메인을 만들어준다(포트는 8080 그대로 사용).

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.1923.png){: width="50%" height="50%"}

---

### 겪었던 문제: 404 Not Found

생성된 URL로 Postman에서 회원가입 요청(`POST /api/users/register`)을 보냈는데 계속 404가 났다. 경로도, Content-Type 헤더도 다 맞아 보였는데, 원인은 URL을 `http`로 보내고 있었기 때문이었다. `https`로 바꾸니 정상적으로 "user has been created" 응답이 돌아왔다.

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.2152.png){: width="50%" height="50%"}

---

### 최종 확인

회원가입에 이어 로그인까지 시도해보니 access token과 refresh token이 정상적으로 발급됐다. 

![](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-09-09-hummingbird-6/CleanShot_09-12.2235.png){: width="50%" height="50%"}

---

## 부록: Railway 배포 가이드 정리

강의 자료로 제공된 배포 가이드를 정리한다. 지금까지 직접 겪으면서 하나씩 풀어온 내용이 여기 순서대로 요약되어 있어서, 전체 흐름을 다시 훑어보기 좋다.

---

### Step 1: Docker 이미지 빌드 및 push

Apple Silicon 환경이라면 `linux/amd64`를 명시해서 빌드해야 한다.

```
docker buildx build \
  --platform linux/amd64 \
  -t <계정>/hellobirdfluent:latest \
  --push .
```

이 명령어가 하는 일은 세 가지다. 앱을 Docker 이미지로 빌드하고, Linux를 타겟으로 지정하고(클라우드 배포에 필요), Docker Hub에 push한다.

---

### Step 2: Railway에 애플리케이션 서비스 만들기

Railway에서 New Project → New Service → Docker Image를 선택하고, push해둔 이미지 이름을 정확히 입력한다.

```
<계정>/hellobirdfluent:latest
```

이때 계정 아이디를 빠뜨리면 Docker가 기본값인 `library/` 네임스페이스에서 이미지를 찾으려다 실패한다는 걸 이미 겪어봤다.

---

### Step 3: PostgreSQL 추가하기

같은 프로젝트 안에서 New → Database → PostgreSQL을 선택한다. 이제 프로젝트 안에는 Postgres 서비스와 애플리케이션 서비스, 두 개가 나란히 존재하게 된다.

---

### Step 4: 애플리케이션을 database에 연결하기

가장 중요한 단계다. Railway 환경에서는 `localhost`를 database host로 쓸 수 없다. 애플리케이션 서비스의 Variables에 아래 값들을 추가한다.

```
DATABASE_HOST=${{Postgres.RAILWAY_PRIVATE_DOMAIN}}
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=YOUR_REAL_POSTGRES_PASSWORD
DATABASE_NAME=railway
JWT_SECRET=super-long-random-secret
```

`${{Postgres.RAILWAY_PRIVATE_DOMAIN}}`처럼 다른 서비스의 값을 실시간으로 참조하는 문법을 쓰면, Postgres 서비스가 나중에 재배포되어도 이 값이 자동으로 따라간다. 앞서 Postgres 값을 그대로 복붙했다가 애플리케이션이 자기 자신에게 연결을 시도해서 crash가 났던 문제가 바로 이 참조 문법을 안 쓰고 값을 직접 복사해서 생긴 일이었다.

실제 password는 Postgres 서비스의 Variables에서 `POSTGRES_PASSWORD` 값을 그대로 복사해서 `DATABASE_PASSWORD`에 붙여넣으면 된다.

---

### Step 5: Swift 코드에서 환경 변수 읽어오기

```swift
let env = ProcessInfo.processInfo.environment

let config = SQLPostgresConfiguration(
    hostname: env["DATABASE_HOST"] ?? "localhost",
    port: Int(env["DATABASE_PORT"] ?? "5432") ?? 5432,
    username: env["DATABASE_USERNAME"] ?? "postgres",
    password: env["DATABASE_PASSWORD"] ?? "postgres",
    database: env["DATABASE_NAME"] ?? "moviesdb",
    tls: .disable
)
```

여기서 코드가 실제로 읽는 키 이름(`DATABASE_USERNAME` 등)과 Railway Variables에 등록한 키 이름이 정확히 일치해야 한다. 하나라도 다르면 fallback 기본값이 대신 쓰이면서 엉뚱한 곳에 연결을 시도하게 된다.

---

### Step 6: Railway가 할당하는 포트 사용하기

Railway는 컨테이너에 동적으로 포트를 할당하고, 이 값을 `PORT` 환경 변수로 전달한다.

```swift
let port = Int(env["PORT"] ?? "8080") ?? 8080
```

또한 서버가 바인딩하는 주소도 `0.0.0.0`이어야 한다. 로컬 개발에서는 `127.0.0.1`/`localhost`로도 충분하지만, 컨테이너 환경에서는 `0.0.0.0`으로 바인딩해야 컨테이너 바깥에서 오는 요청을 받을 수 있다.

---

### Step 7: 공개 URL 생성하기

애플리케이션 서비스의 Networking에서 Generate Domain을 선택하고, 포트는 8080으로 지정한다.

---

### Step 8: API 테스트

```
POST https://your-app.up.railway.app/api/users/register
POST https://your-app.up.railway.app/api/users/login
```

만약 `401 Unauthorized`가 뜬다면, 이건 오히려 배포 자체는 정상적으로 되어 있다는 뜻이다. 인증 요청이 서버까지 도달해서 처리됐고, 다만 credential이나 데이터가 맞지 않았을 뿐이라는 걸 의미하기 때문이다.

---

### 로컬 Docker 테스트

```
docker run -p 8080:8080 \
  -e DATABASE_HOST=host.docker.internal \
  -e DATABASE_PORT=5432 \
  -e DATABASE_USERNAME=postgres \
  -e DATABASE_PASSWORD=postgres \
  -e DATABASE_NAME=moviesdb \
  -e JWT_SECRET=my-secret-key \
  <계정>/hellobirdfluent:latest
```

`host.docker.internal`을 쓰는 이유는, database는 Mac(호스트 머신)에서 돌고 있는데 컨테이너 입장에서는 호스트 머신에 접근할 방법이 필요하기 때문이다. `host.docker.internal`이 그 다리 역할을 해준다.

---

### 흔한 실수 체크리스트

- database host로 `localhost`를 쓰는 것 ❌ (컨테이너 환경에서는 통하지 않는다)
- 환경 변수 설정을 빼먹는 것 ❌
- 변수를 추가하고도 재배포를 안 하는 것 ❌
- `linux/amd64`로 빌드하지 않는 것 ❌ (Apple Silicon에서 그냥 빌드하면 ARM용 이미지가 만들어진다)

---

### 최종 멘탈 모델

애플리케이션과 database는 서로 별개의 container에서 각자 돌아간다. 이 둘은 오직 환경 변수를 통해서만 서로의 위치를 알고 통신한다. Railway가 두 서비스를 자동으로 연결해주지는 않으며, 그 연결을 명시적으로 설정하는 건 개발자의 몫이다.