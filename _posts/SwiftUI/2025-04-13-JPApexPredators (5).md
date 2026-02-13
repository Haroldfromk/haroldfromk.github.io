---
title: JPApexPredators (5)
writer: Harold
date: 2025-4-13 7:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

## ui 보완

mapkit을 사용하기전에 먼저 아래 사진을 보면

![Image](https://github.com/user-attachments/assets/9162a649-53b4-4ac4-a490-6d43b168a395){: width="50%" height="50%"} 

배경이 파란색인 경우 Navigation button이 잘 보이지 않는다.

이부분을 먼저 보완을 하고 넘어가려고한다.

![Image](https://github.com/user-attachments/assets/e6de38c2-b10c-46fc-b970-6d3ce5ed1ffe)

이렇게 먼저 Accent Color를 보완한다.

우리는 현재 ` .preferredColorScheme(.dark)`를 통해 애초에 다크모드로 해둔 상태이긴 하다.

![Image](https://github.com/user-attachments/assets/8ec8d318-8060-48e0-97fe-490edf8f3407){: width="50%" height="50%"} 

둘다 labelColor로 해준다.

이후 ConentView로 돌아와서 Preview에서 Light, Dark 모드 테스트를 할 수 있는데.

![Image](https://github.com/user-attachments/assets/581ed310-1fee-4e0d-8a6c-b67b9d4eb3c1){: width="50%" height="50%"} ![Image](https://github.com/user-attachments/assets/4f866652-0dbf-46d2-9e09-50bc7bebdacb){: width="50%" height="50%"} 

이렇게 확인이 가능

그리고 체크를 풀게되면 애초에 우리가 설정해둔 `preferredColorScheme`를 통해 다시 검게 된다.

![Image](https://github.com/user-attachments/assets/1f707ab4-01a9-4561-bca5-0672c1f782b9){: width="50%" height="50%"} 

이제는 이렇게 하얗게 변한걸 알 수 있다.

그리고 PredatorDetailView에서

이미지에 그라데이션 효과를 좀 줘본다.

```swift
Image(predator.type.rawValue)
    .resizable()
    .scaledToFit()
    .overlay {
        LinearGradient(stops: [
            Gradient.Stop(color: .clear, location: 0.8),
            Gradient.Stop(color: .black, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }
```

Overlay를 통해 겹치게 하고 LinearGradient를 통해 그라데이션 효과를 주는데 location을 통해 하단부에만 효과를 주도록 한다.

- `color: .clear, location: 0.8`  
  → 화면의 **80% 지점까지는 완전히 투명**

- `color: .black, location: 1`  
  → 아래 **20% 구간에서 점점 검정색으로 어두워짐**

- `.top → .bottom` 방향으로 그라디언트 적용됨

👉 이렇게 하면 **위쪽은 투명하고, 아래쪽만 서서히 어두워지는 효과**를 만들 수 있다.  
보통 **이미지 위에 텍스트를 얹을 때 가독성을 높이기 위한 용도**로 자주 사용된다.

아무생각없이 Gradient를 사용하게되면...

![Image](https://github.com/user-attachments/assets/b34d6169-dfb4-40f8-9ae4-9a372783c345){: width="50%" height="50%"} 

이렇게 개판날수도 있으니까 조심


- before
![Image](https://github.com/user-attachments/assets/f1cc2f9b-7394-4387-afd4-52374a30bae7){: width="50%" height="50%"} 
- after
![Image](https://github.com/user-attachments/assets/7578dab8-6dbf-4c0d-95e6-339edced1c2c){: width="50%" height="50%"} 

확실히 하단부분이 다른걸 알 수 있다.

## Mapkit을 사용하여 위치 표시하기

이건 이전에도 종종 사용을 해보았는데 swiftui에서는 [여기서](https://haroldfromk.github.io/posts/MapKit/){:target="_blank"} 사용을 했다.

물론 mapkit에 대해 다른글을 쓰고 있긴하지만 잠시 그건 보류한 상태였고 조만간 다시 작성예정...

다시 본론으로 돌아가서 현재 json파일을 보면

```text
"latitude": 32.7848,
"longitude": -96.8025,
```

이렇게 latitude, longitude가 있다.

그래서 우리는 ApexPredator 라는 구조체에 json과 동일하게 변수이름을 만들고 type을 설정 했었다.

ApexPredator에 가서

```swift
import MapKit

struct ApexPredator: Decodable, Identifiable {
    // 생략
    var location: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    // 생략
}
```

이렇게 우리가 detailview에서 별도로 변수를 만들지않고 관련 코드에서 자체적으로 처리하도록 만들어 준다.

다시 detailview로 돌아와서

![Image](https://github.com/user-attachments/assets/739fd861-68a1-459c-8f81-993b6dc11fe6)

여기서 우리는 3가지를 포인트로 둔다.

겹치는 건 Zstack을 사용해도 되고, 위에서 사용한 overlay를 사용해도 된다.

```swift
@State var position: MapCameraPosition

// Current Location
Map(position: $position) {
    Annotation(predator.name, coordinate: predator.location) {
        Image(systemName: "mappin.and.ellipse")
            .font(.largeTitle)
            .imageScale(.large)
            .symbolEffect(.pulse)
    }
    .annotationTitles(.hidden)
}
.frame(height: 125)
.clipShape(.rect(cornerRadius: 15))
```

이렇게 코드를 작성하면

![Image](https://github.com/user-attachments/assets/c1074187-401a-4e70-9633-744fbf5f6b54){: width="50%" height="50%"} 

symboleffect에 의해 핀이 깜빡 깜빡 거린다.

사실 여기는 크게 언급할 부분은 없어보이긴한다.

현재 미리보기에서 이렇게 나오는건 

```swift
#Preview {
    let predator = Predators().apexPredators[2]
    
    PredatorDetail(
        predator: predator,
        position: .camera(
            MapCamera(
                centerCoordinate: predator.location,
                distance: 30000
            )
        )
    )
    .preferredColorScheme(.dark)
}

```

preview의 distance를 30000으로 해두었기 때문

그리고 annotation pin에 굳이 또 predator.name이 들어갈 필요는 없어서 `.annotationTitles(.hidden)`를 통해 숨겼다.

### 화면 전환 하기

이전에 사용한 Navigation Link를 사용하여 전환을 해주도록 한다.

```swift
 // Current Location
NavigationLink {
    Image(predator.image)
        .resizable()
        .scaledToFit()
} label: {
    Map(position: $position) {
        Annotation(predator.name, coordinate: predator.location) {
            Image(systemName: "mappin.and.ellipse")
                .font(.largeTitle)
                .imageScale(.large)
                .symbolEffect(.pulse)
        }
        .annotationTitles(.hidden)
    }
    .frame(height: 125)
    .clipShape(.rect(cornerRadius: 15))
    .overlay(alignment: .trailing) {
        Image(systemName: "greaterthan")
            .imageScale(.large)
            .font(.title3)
            .padding(.trailing, 5)
    }
    .overlay(alignment: .topLeading) {
        Text("Current Location")
            .padding([.leading, .bottom], 5)
            .padding(.trailing, 8)
            .background(.black.opacity(0.33))
            .clipShape(.rect(bottomTrailingRadius: 15))
    }
    .clipShape(.rect(cornerRadius: 15))
}
```

이렇게 코드를 작성해 주었다.

뭐 딱히 크게 언급할만한건 없어보이긴 한다.

![Image](https://github.com/user-attachments/assets/7e5500db-39fa-4738-87af-221ea5a6a585){: width="50%" height="50%"} 

실행하면 이렇게 된다.

그리고 만약 코드에서 navigation link를 이렇게 사용했는데 preview에서 되지 않는다면 어떻게 해야할까?

ContentView에 이미 NavigationStack이 있는데, DetailView에 또 NavigationStack을 쌓는건 바람직 하지 않다.

하지만 작동 확인을 하기 위해서는 NavigationStack이 필요한데 이때 preview에 NavigationStack을 넣어주면 된다.

```swift
#Preview {
    let predator = Predators().apexPredators[2]
    NavigationStack{
        PredatorDetail(
            predator: predator,
            position: .camera(
                MapCamera(
                    centerCoordinate: predator.location,
                    distance: 30000
                )
            )
        )
        .preferredColorScheme(.dark)
    }
}
```

그러면 preview에서도 확인이 된다.