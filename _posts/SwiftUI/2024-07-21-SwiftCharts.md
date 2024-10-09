---
title: SwiftCharts
writer: Harold
date: 2024-7-21 08:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

차트를 구현해보려한다.

VegasChart라는 새로운 파일을 만들어주고

`import Charts`를 해주자.

### 1. 샘플 데이터 모델링

```swift
struct SampleRating {
    let place: String
    let rating: Int
    
    static let ratings: [SampleRating] = [
        SampleRating(place: "Bellagio", rating: 88),
        SampleRating(place: "Paris", rating: 75),
        SampleRating(place: "Treasure Island", rating: 33),
        SampleRating(place: "Excalibur", rating: 99)
    ]
}
```

### 2. 구현하기

```swift
struct VegasChart: View {
    var body: some View {
        Chart(SampleRating.ratings, id: \.place) { rating in
            SectorMark(angle: .value("Ratings", rating.rating)
                       , innerRadius: .ratio(0.25)
                       , angularInset: 1)
                .cornerRadius(7)
                .foregroundStyle(by: .value("Place", rating.place))
        }
        .padding()
        .frame(height: 500)
    }
}
```

Chart를 보면

SampleRating.ratings를 통해 어떤 데이터를 가져올지를 지정하고, id는 각항목의 고유 식별자로 이해하면된다.(Legend)

SectorMark는 Pie Chart / Donut Chart이다.
- innerRadius: .ratio(0.25)는 섹터의 안쪽 반지름을 설정하여 도넛 형태를 만든다.
- angularInset: 1은 각 섹터 사이의 간격을 조절한다.

![CleanShot 2024-09-10 at 02 08 01@2x](https://github.com/user-attachments/assets/8503b71a-8199-4f0a-8d35-f82dc744f68c){: width="50%" height="50%"}

이렇게 차트가 나온다.
