---
title: JPApexPredators (4)
writer: Harold
date: 2025-4-10 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## Detail View 만들기

지금은 Navigation Link 안에 그냥 Image만 띄워놓은 상태인데 이것 역시도 별도로 관리하는 View 만들어 본다.

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/68ec5a42-b912-44bb-a56d-3c8137b7e6ed.png){: width="50%" height="50%"} 

이렇게 디자인을 해보려고 한다.

이번엔 ScrollView를 사용한다

```swift
struct PredatorDetail: View {
    var body: some View {
        ScrollView {
            ZStack {
                // Background Image
                
                // Dino Image
            }
            
            // Dino Name
            
            // Current Location
            
            // Appears In
            
            // Movie Moments
            
            // Link to Webpage
        }
    }
}
```

대강 구도는 이렇게 잡아놓고 시작!

```swift
struct PredatorDetail: View {
    let predator: ApexPredator
    
    var body: some View {
        ScrollView {
            ZStack {
                // Background Image
                Image(predator.type.rawValue)
                    .resizable()
                    .scaledToFit()
                
                // Dino Image
                Image(predator.image)
                    .resizable()
                    .scaledToFit()
            }
            
            // Dino Name
            
            // Current Location
            
            // Appears In
            
            // Movie Moments
            
            // Link to Webpage
        }
        .ignoresSafeArea()
    }
}
```

이렇게 디자인을 하다보면

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/9d17321e-c567-4cdf-8c78-77cd49a4fbf0.png){: width="50%" height="50%"} 

위와 같이나오는데, 현재는 16pro를 기준으로 하고있는데, 사람마다 아이폰 기종이 다르다.

모두에게 똑같은 화면이 보이지 않기때문에 이걸 해결하기위해 `GeometryReader`를 사용한다.

[이전에](https://haroldfromk.github.io/posts/HealthKit-(5)/){:target="_blank"} 사용해본 적이 있으니 참고.

```swift
struct PredatorDetail: View {
    let predator: ApexPredator
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                ZStack {
                    // 생략
                }
            }
            .ignoresSafeArea()
        }
    }
}
```

이렇게 Scroll view 상위로 GeometryReader를 넣어준다.

### Tip

이때 Tip이 있다면

각 기기별 사이즈를 직접 확이하고 싶을때

```swift
Text("Width: \(geo.size.width)")
Text("Height: \(geo.size.height)")
```

를 사용하게되면

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/080d09c6-5bc1-4551-a29a-09459fb3eef1.png){: width="50%" height="50%"} 

이렇게 사이즈를 확인 가능 하다.

이건 지금 그냥 UI디자인 하면서 적어본것.

그리고 내가 어떤 이미지를 적용할때 현재 적용이 어느 범위로 되는지 확인을 해보고 싶다면

```swift
Image(predator.image)
    .resizable()
    .scaledToFit()
    .frame(
        width: geo.size.width,
        height: geo.size.height
    )
    .border(.blue, width: 7)
```

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/e5228881-a619-417b-85bf-d295fad89805.png){: width="50%" height="50%"} 

이렇게 border를 통해 확인을 해보면 된다.

---

다시 돌아와서 이미지 부분은 다음과 같이 여러 Modifier를 통해 꾸며주었다.

```swift
Image(predator.image)
    .resizable()
    .scaledToFit()
    .frame(
        width: geo.size.width/1.5,
        height: geo.size.height/3.7
    )
    .scaleEffect(x: -1)
    .shadow(color:.black, radius: 7)
    .offset(y: 20)
```

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/e2380090-a3c8-4c94-85dd-bd1712330ca8.png){: width="50%" height="50%"} 

이렇게 나온다.

딱히 언급할만한건 없지만

- `.scaleEffect(x: , y: )`는 뷰의 **크기와 방향**을 조절하는 Modifier  
- 부호(+, –): **방향 반전 여부**  
- 절대값: **크기 변화 정도**

---

### 📐 x축 (가로 방향)
- **x = 1**: 기본 크기  
- **x > 1**: 오른쪽으로 **가로 확대**  
- **0 < x < 1**: 오른쪽 방향은 유지되며 **가로 축소**  
- **x < 0**: **좌우 반전됨** (거울처럼 뒤집힘)  
  - 예: `x = -1` → 크기는 동일하지만 **좌우 반전**
  - 예: `x = -2` → **좌우 반전 + 2배 확대**

---

### 📏 y축 (세로 방향)
- **y = 1**: 기본 크기  
- **y > 1**: 아래 방향으로 **세로 확대**  
- **0 < y < 1**: 아래 방향 유지하며 **세로 축소**  
- **y < 0**: **상하 반전됨** (뒤집힘)
  - 예: `y = -1` → 크기는 같지만 **상하 반전**
  - 예: `y = -0.5` → **상하 반전 + 축소**

---

> ✅ 요약:
> - **부호**: +는 그대로, –는 반전  
> - **절대값** ↑: 커질수록 확대, ↓: 축소

---

- `.offset(x: , y: )`는 뷰의 **화면 상 위치를 이동**시키는 Modifier  
- 부호(+, –): **이동 방향**  
- 절대값: **이동 거리**

---

### ↔️ x축 (좌우 이동)
- **x = 0**: 이동 없음  
- **x > 0**: **오른쪽으로 이동**  
- **x < 0**: **왼쪽으로 이동**  
  - 예: `x = 20` → 오른쪽으로 20pt 이동  
  - 예: `x = -10` → 왼쪽으로 10pt 이동

---

### ↕️ y축 (상하 이동)
- **y = 0**: 이동 없음  
- **y > 0**: **아래로 이동**  
- **y < 0**: **위로 이동**  
  - 예: `y = 30` → 아래로 30pt 이동  
  - 예: `y = -15` → 위로 15pt 이동

---

> ✅ 요약:
> - **부호**: +는 오른쪽/아래, –는 왼쪽/위  
> - **절대값** ↑: 이동 거리 증가

---

다시 DetailView를 디자인하면서

```swift
Text("Appears In:")
    .font(.title3)

ForEach(predator.movies) { movie in
    Text(movie)
}
```

바로 ForEach에서 문제가 생긴다.

보통 ForEach에 들어가는 Contents들은 Identifiable이어야 한다.

하지만 movies의 경우는 `let movies: [String]` 단지 String을 가지고 있는 배열일 뿐이다.
여기에 Identifiable 프로토콜을 채택할수는 없지만 방법이 있다. 배열안의 element들이 각각 id 역할을 하게 해주면 되는데 바로

```swift
ForEach(predator.movies, id: \.self) { movie in
    Text(movie)
}
```

이렇게 안의 요소 자기자신이 id역할을 하게한다는 `id: \.self`를 사용해주면 된다.

이건 사용하면서 언급해본적이 없어서 이번에 한번 언급을 해보고 간다.

Movie Moments 역시도 

```swift
struct MovieScene: Decodable, Identifiable { // changed
        // 생략
```

Foreach를 사용하기 위해 Identifiable 를 채택해준다.

이건 Struct이니 Identifiable 프로토콜을 바로 채택하면 된다.

이렇게 코드를 완성하고 실행하면

![Image](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2025-04-10-JPApexPredators-4/56c1383a-6c46-4b39-bb7d-36237aa818e8.png){: width="50%" height="50%"} 

이런식으로 되는걸 알 수 있다.

```swift
struct PredatorDetail: View {
    let predator: ApexPredator
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                ZStack(alignment: .bottomTrailing) {
                    // Background Image
                    Image(predator.type.rawValue)
                        .resizable()
                        .scaledToFit()
                    
                    // Dino Image
                    Image(predator.image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: geo.size.width/1.5,
                            height: geo.size.height/3.7
                        )
                        .scaleEffect(x: -1)
                        .shadow(color:.black, radius: 7)
                        .offset(y: 20)
                }
                VStack(alignment: .leading) {
                    // Dino Name
                    Text(predator.name)
                        .font(.largeTitle)
                    
                    // Current Location
                    
                    // Appears In
                    Text("Appears In:")
                        .font(.title3)
                    
                    ForEach(predator.movies, id: \.self) { movie in
                        Text("•" + movie)
                            .font(.subheadline)
                    }
                    
                    // Movie Moments
                    Text("Movie Moments")
                        .font(.title)
                        .padding(.top, 15)
                    
                    ForEach(predator.movieScenes) { scene in
                        Text(scene.movie)
                            .font(.title2)
                            .padding(.bottom, 1)
                        
                        Text(scene.sceneDescription)
                            .padding(.bottom, 15)
                            
                    }
                    // Link to Webpage
                    Text("Read More:")
                        .font(.caption)
                    
                    Link(predator.link, destination: URL(string: predator.link)!)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding()
                .padding(.bottom)
                .frame(width: geo.size.width, alignment: .leading)
                
            }
            .ignoresSafeArea()
        }
    }
}
```

현재까지 작성한 코드.

Current Location은 MapKit을 사용하는데 이건 다음글에서 계속...