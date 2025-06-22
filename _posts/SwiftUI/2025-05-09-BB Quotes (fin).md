---
title: BB Quotes (fin)
writer: Harold
date: 2025-5-9 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Version 2로 업그레이드

이어서 계속 작성해보도록 한다

### 4. Extenstion을 사용하여 코드 간소화

현재 `Image(show.lowercased().replacingOccurrences(of: " ", with: ""))` 이런식으로

코드가 약간 길어지는것을 Extension을 활용하여 조금 간소화를 해보도록 한다.

이렇게 Extension으로 관리를하면 View 쪽은 코드가 간략하여 유지 보수 하기에 용이해진다.

```swift
extension String {
    func removeSpaces() -> String {
        self.replacingOccurrences(of: " ", with: "")
    }
    
    func removeCaseAndSpace() -> String {
        self.removeSpaces().lowercased()
    }
}
```

이렇게 만들어 주었다.

그리고 필요한부분에 맞춰 적용을 해주자

```swift
// before
Image(show.lowercased().replacingOccurrences(of: " ", with: ""))

// after
Image(show.removeCaseAndSpace())
```

이런식으로 간소화 된걸 알 수 있다.

### 5. constant를 사용한 코드 관리

ContentView 만봐도

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Breaking Bad", systemImage: "tortoise") {
                QuoteView(show: "Breaking Bad")
                    .toolbarBackgroundVisibility(.visible, for: .tabBar)
            }
            
            Tab("Better Call Saul", systemImage: "briefcase") {
                QuoteView(show: "Better Call Saul")
                    .toolbarBackgroundVisibility(.visible, for: .tabBar)
            }
            
            Tab("El Camino", systemImage: "car") {
                QuoteView(show: "El Camino")
                    .toolbarBackgroundVisibility(.visible, for: .tabBar)
            }
        }
        .preferredColorScheme(.dark)
    }
}
```

지금 "Breaking Bad" 같이 문자열을 그대로 사용하여 값을 전달하는데, 이렇게 직접적으로 입력하게 될 경우 오타가 발생할 경우도 있다.

그렇기에 이런것들은 상수(Constants)로 관리를 해주면 오타방지도 되면서 이후에 사용하기도 편리하다.

```swift
enum Constants {
    static let bbName = "Breaking Bad"
    static let bcsName = "Better Call Saul"
    static let ecName = "El Camino"
}
```

그리고 이렇게 바꿔주면 된다.

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            Tab(Constants.bbName, systemImage: "tortoise") {
                QuoteView(show: Constants.bbName)
            }
            
            Tab(Constants.bcsName, systemImage: "briefcase") {
                QuoteView(show: Constants.bcsName)
            }
            
            Tab(Constants.ecName, systemImage: "car") {
                QuoteView(show: Constants.ecName)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct QuoteView: View {
    let vm = ViewModel()
    let show: String
    
    @State var showCharacterInfo = false
    
    var body: some View {
        GeometryReader { geo in
            // 생략
        }
        .ignoresSafeArea()
        .toolbarBackgroundVisibility(.visible, for: .tabBar) // moved
        .sheet(isPresented: $showCharacterInfo) {
            CharacterView(character: vm.character, show: show)
        }
    }
}
```

이렇게 constansts를 사용하면서 각 Tab에 달려있던 `toolbarBackgroundVisibility` Modifier를 QuoteView에 달아준다.

### 6. Episode 가져오기

![Image](https://github.com/user-attachments/assets/d1474a2d-8099-4a59-b006-1dc656c8e540){: width="50%" height="50%"} 

이렇게 정보를 제공하는걸 만들어 본다.


#### 1. 모델링

Episode 역시 Modeling이 필요하니 그걸 먼저 해주자.

```swift
struct Episode: Decodable {
    let episode: Int // 101, 512
    let title: String
    let image: URL
    let synopsis: String
    let writtenBy: String
    let directedBy: String
    let airDate: String

    var seasonEpisode: String {
        "Season \(episode / 100) Episode \(episode % 100)"
    }
}
```

이때 seasonEpisode의 경우

sample을 보게되면 `"episode": 101` 이런식으로 적혀있다.

그렇기에 100을 나누어서 몫은 시즌을, 나머지는 그 시즌의 회차로 정의 한다.

#### 2. fetch 코드 작성

```swift
func fetchEpisode(from show: String) async throws -> Episode? {
    let episodeURL = baseURL.appending(path: "episodes")
    let fetchURL = episodeURL.appending(queryItems: [URLQueryItem(name: "production", value: show)])
    
    let (data, response) = try await URLSession.shared.data(from: fetchURL)
    
    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
        throw FetchError.badResponse
    }
    
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    let episodes = try decoder.decode([Episode].self, from: data)
    
    return episodes.randomElement()
}
```

뭐 딱히 언급할만한 건 없다.

에피소드가 존재하지않을때를 대비해 Optional로 해준것 말곤 없다.

ViewModel로 가서도 sample 데이터를 가져오기위해 코드를 작성

```swift
var episode: Episode
    // 생략
    init() {
        // 생략
        
        let episodeData = try! Data(contentsOf: Bundle.main.url(forResource: "sampleepisode", withExtension: "json")!)
        episode = try! decoder.decode(Episode.self, from: episodeData)
    }

    func getEpisode(for show: String) async {
        status = .fetching
        
        do {
            if let unwrappedEpisode = try await fetcher.fetchEpisode(from: show) {
                episode = unwrappedEpisode
            }
            
            status = .success
        } catch {
            status = .failed(error: error)
        }
    }
```

ViewModel에 있던 getData함수는 getQuoteData로 명칭 변경

이유는 QuoteData와 Episode 가져오는걸 분리하기 위해서.

#### 3. EpsodeView 만들기

QuoteView를 FetchView로 이름을 바꿔준다.

하나의 뷰를 재활용할 예정

```swift
 HStack {
    Button {
        // 생략
    }
    
    Spacer()
    
    Button {
       // 생략
    }
}
.padding(.horizontal, 30)
```

![Image](https://github.com/user-attachments/assets/52dce88f-6a7a-4dc4-8d07-1dd562dd8167){: width="50%" height="50%"} 

이렇게 나누어 준다.

하지만

![Image](https://github.com/user-attachments/assets/58d78bcb-ea89-48b0-86a3-95c1a94af4a1){: width="50%" height="50%"} 

작동하지 않는다.

그 이유는

`case .success:` 일때 우리가 quote에 대한 조건만 처리 해뒀기 때문

그렇기에 viewmodel에서 별도의 case를 하나 더 만들어줄 필요가 있다.

```swift
enum FetchStatus {
    case notStarted
    case fetching
    case successQuote
    case successEpisode
    case failed(error: Error)
}

    func getQuoteData(for show: String) async {
        status = .fetching
        
        do {
            // 생략
            
            status = .successQuote
        } catch {
            status = .failed(error: error)
        }
    }
    
    func getEpisode(for show: String) async {
        status = .fetching
        
        do {
            // 생략
            
            status = .successEpisode
        } catch {
            status = .failed(error: error)
        }
    }
```

이렇게 다시 추가하고 수정했다면

```swift
case .successQuote:
    // 생략
case .successEpisode:
    VStack(alignment: .leading) {
        EpisodeView()
    }
```

이런식으로 case도 바꿔준다.

이제 새롭게 만든 EpisodeView UI를 디자인 해주자

```swift
struct EpisodeView: View {
    let episode: Episode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(episode.title)
                .font(.largeTitle)
            
            Text(episode.title)
                .font(.title2)
            
            AsyncImage(url: episode.image) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 15))
            } placeholder: {
                ProgressView()
            }
            
            Text(episode.synopsis)
                .font(.title3)
                .minimumScaleFactor(0.5)
                .padding(.bottom)
            
            Text("Written By: \(episode.writtenBy)")
            
            Text("Directed By: \(episode.directedBy)")
            
            Text("Aired: \(episode.airDate)")
        }
        .padding()
        .foregroundStyle(.white)
        .background(.black.opacity(0.6))
        .clipShape(.rect(cornerRadius: 25))
        .padding(.horizontal)
    }
}
```

![Image](https://github.com/user-attachments/assets/bb481727-91e0-4a8f-94e0-545204f14ade){: width="50%" height="50%"} 

그럼 이렇게 나오게 된다.

이제 실행해보면

![Image](https://github.com/user-attachments/assets/d230b4ce-6558-46d5-bfb7-d044ceba639e){: width="50%" height="50%"} 

잘된다.


## 💡 BB Quotes Coding Challenge 요약

---

### ✅ Challenge 1: 앱 시작 시 자동으로 Quote 가져오기
- 현재는 앱을 켜면 화면이 비어 있음
- 앱이 실행되자마자 자동으로 Quote를 fetch해서 보여주도록 설정
- 이후 버튼 탭 시에는 기존처럼 작동

---

### 🖼️ Challenge 2: 캐릭터 이미지 랜덤 선택
- 현재는 항상 이미지 배열의 첫 번째 이미지를 사용 중
- `character.images` 배열에서 랜덤한 이미지 선택해서 보여주기

---

### 🎭 Challenge 3: 랜덤 캐릭터 Fetch
- 랜덤 quote 또는 episode와 비슷하게 랜덤 캐릭터도 fetch
- URL: `https://.../characters/random`
- 다만 show 구분이 없기 때문에 `productions` 속성을 활용해 현재 탭(show)에 맞는 캐릭터인지 확인
- show가 맞지 않다면 무시하거나 다시 fetch하도록 처리

---

### 💬 Challenge 4: CharacterView에 캐릭터 Quote 추가
- 기존 CharacterView에 해당 캐릭터의 랜덤 Quote 하나 추가
- 버튼을 눌러 해당 캐릭터의 다른 Quote를 가져올 수 있도록 설정
- 사용 API:  
  `https://.../quote/random?author={characterName}`

---

### 🟡 Challenge 5: 가끔 Simpsons Quote 가져오기
- 일정 확률 또는 주기로 Simpsons Quote를 가져오도록 설정
  - 예: 5번 중 1번, 혹은 20% 확률
- Simpsons API:  
  `https://thesimpsonsquoteapi.glitch.me/quotes`
- 응답은 하나의 quote만 담긴 배열 형태  
  - quote, character, image 정보 포함

---

Challenge 나중에 해보는걸로...