---
title: JPApexPredators (1)
writer: Harold
date: 2025-3-21 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

새로운 프로젝트를 시작해본다.

기본적인 부분과 이미 알고있던 부분은 패스하거나 간략하게 서술할 예정

## Json파일과 동일하게 구조체 만들기

이건 워낙 api나 json 파일을 사용하면서 많이 해보았기에 내용은 패스

```swift
struct ApexPredator: Decodable {
    let id: Int
    let name: String
    let type: String
    let latitude: Double
    let longitude: Double
    let movies: [String]
    let movieScenes: [MovieScene]
    let link: String
    
    struct MovieScene: Decodable {
        let id: Int
        let movie: String
        let sceneDescription: String
    }
}
```

결과는 위와 같다.

## Decoding을 할 class 생성

```swift
class Predators {
    var apexPredators: [ApexPredator] = []
    
    init() {
        decodeApexPredators()
    }
    
    func decodeApexPredators() {
        if let url = Bundle.main.url(forResource: "jpapexpredators", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                apexPredators = try decoder.decode([ApexPredator].self, from: data)
            } catch {
                print("Error deconding Json data: \(error)")
            }
        }
    }
}
```

[이전에](https://haroldfromk.github.io/posts/TourApp_4/){:target="_blank"} youtube를 보고 한 기억이 있긴하다.

[다른 방법](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(8)/){:target="_blank"} 으로 file의 path를 설정한적이 있는데, 오래간만에 리마인드할겸 참고해보는것도 나쁘지 않을듯

그리고 keyDecodingStrategy 의 경우엔 [여기서](https://haroldfromk.github.io/posts/Widget-(3)/){:target="_blank"} 다룬적이 있으므로 참고!

`init()`을 통해 클래스 인스턴스가 초기화될 때 JSON 파일을 디코딩해 apexPredators에 데이터를 채우도록 한다.

## UI Design

![Image](https://github.com/user-attachments/assets/2c55ceb7-6574-4c76-822d-44c1a7608772){: width="50%" height="50%"} 

위와 같이 만들것이다.

사진처럼 만들기위해서 list를 사용해야하는데

```swift
struct ContentView: View {
    let predators = Predators()
    
    var body: some View {
        List(predators.apexPredators) { predator in
                
        }
    }
}
```

이렇게 그대로 사용하게 되면 에러가 발생 `ApexPredator가 Identifiable 프로토콜을 채택해야한다`고 뜬다.

`struct ApexPredator: Decodable, Identifiable {` 이렇게 Identifiable 프로토콜도 채택해주자.

Image가 필요한데 우리가 추가한 image 파일명이 json의 name과 거의 같지만 이미지는 소문자로 이름이 되어있고 띄어쓰기가 없다.

하지만 json의 경우엔 대문자와 띄어쓰기가 존재.

예를들어 

1. Quetzalcoatlus
 - json: Quetzalcoatlus
 - image: quetzalcoatlus
2. Indominus Rex
 - json: Indominus Rex
 - image: indominusrex

이런식으로 각각 다르기에 computed property를 통해 json의 name을 image에 사용하도록 변화를 주어야한다.

```swift
struct ApexPredator: Decodable, Identifiable {
    // 생략
    
    var image: String {
        name.lowercased().replacingOccurrences(of: " ", with: "")
    }
    
    struct MovieScene: Decodable {
        // 생략
    }
}
```

이렇게 코드를 작성하면 기본틀은 완성이 된다.

```swift
struct ContentView: View {
    let predators = Predators()
    
    var body: some View {
        List(predators.apexPredators) { predator in
            HStack {
                // Dinosaur Image
                Image(predator.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .shadow(color:.white, radius: 1)
                
                VStack(alignment: .leading) {
                    // Name
                    Text(predator.name)
                        .fontWeight(.bold)
                    
                    // Type
                    Text(predator.type.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
```


이제는 type에 따라 배경색을 다르게 하기위해 코드를 조금 수정한다.

```swift
struct ApexPredator: Decodable, Identifiable {
    // 생략

    enum APType {
        case land
        case air
        case sea
        
        var background: Color {
            switch self {
            case .land: .brown
            case .air: .teal
            case .sea: .blue
            }
        }
    }
}
```

이렇게 추가해준다.

그리고 Text에 사용할 background modifier를 사용하여 코드를 작성한다.

```swift
Text(predator.type.capitalized)
    // 생략
    .background(predator.type.background)
```

사실 predator.type.background는 존재하지 않는다. (미리적어두는 것)

왜냐면 위에 type은 그냥 String이기 때문.

우리가 만든 enum을 사용하기 위해서 type을 고쳐주자.

```swift
struct ApexPredator: Decodable, Identifiable {
    // 생략
    let type: APType // changed
    // 생략
    
    enum APType: String, Decodable { // changed
        case land
        case air
        case sea
        
        var background: Color {
            switch self {
            case .land: .brown
            case .air: .teal
            case .sea: .blue
            }
        }
    }
}
```

그래도 여전히 에러는 같은 위치에서 발생 하지만 지금의 에러의 이유는 바로 `Text(predator.type.capitalized)` 여기서 발생.

이전에는 type이 string이었기에, type.capitalized가 사용이 가능했으나, 지금은 하나의 열거형이 되었기에 바꿔주어야 한다. 

type이 가지고 있는 그 자체의 값(rawValue)를 사용해주면 된다.

`Text(predator.type.rawValue.capitalized)` 이렇게.

그러면 아래와 같이 제대로 나오게 된다.

![Image](https://github.com/user-attachments/assets/f32a6f5f-43ce-4002-9a1e-02c366af965b){: width="50%" height="50%"} 

물론 마지막에 `.clipShape(.capsule)` 을통해 배경의 shape를 둥글게 깎았으나 그건 패스...