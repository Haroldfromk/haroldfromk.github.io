---
title: Math Function Charts
writer: Harold
date: 2024-7-21 09:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

차트를 구현해보려한다.

TripsChart라는 새로운 파일을 만들어주고

`import Charts`를 해주자.

### 1. 샘플 데이터 모델링

```swift
struct SampleTripRating {
    let trip: Int
    let rating: Int
    
    static let ratings: [SampleTripRating] = [
        SampleTripRating(trip: 1, rating: 55),
        SampleTripRating(trip: 2, rating: 27),
        SampleTripRating(trip: 3, rating: 67),
        SampleTripRating(trip: 4, rating: 72),
        SampleTripRating(trip: 5, rating: 81)
    ]
}
```

### 2. 구현하기

```swift
struct TripsChart: View {
    var body: some View {
        Chart(SampleTripRating.ratings, id: \.trip) { rating in
            LinePlot(x: "Years", y: "Ratings") { x in
                return x * 6 + 50
            }
            .foregroundStyle(.purple)
        }
        .chartXScale(domain: 1...5)
        .chartYScale(domain: 1...100)
        .padding()
    }
}
```

Graph를 보면

SampleTripRating.ratings를 통해 어떤 데이터를 가져올지를 지정하고, id는 각항목의 고유 식별자로 이해하면된다.

LinePlot 는 바로 직선이다.
x축, y축에 대해 설정을 해주고.

- .chartXScale(domain: 1...5)
    - x축 범위
- .chartYScale(domain: 1...100)
    - y축 범위

그리고 리턴을 해주었다. 즉 저 그래프는

y = 6x + 50의 그래프이다.

![CleanShot 2024-09-10 at 02 20 18@2x](https://github.com/user-attachments/assets/48cfdddd-a9f7-42bd-9274-54636a1b70c5)

이렇게 그래프가 나온다.

### 3. 그래프를 여러개 구현하기

```swift
struct TripsChart: View {
    var body: some View {
        Chart(SampleTripRating.ratings, id: \.trip) { rating in
            PointMark(x: .value("Year", rating.trip), y: .value("Rating", rating.rating))
            
            LinePlot(x: "Years", y: "Ratings") { x in
                return x * 6 + 50
            }
            .foregroundStyle(.purple)
        }
        .chartXScale(domain: 1...5)
        .chartYScale(domain: 1...100)
        .padding()
    }
}
```

그래프를 여러개라고 적었지만 실제로는 우리가 샘플로 만든 값을 표시했다.

![CleanShot 2024-09-10 at 02 25 07@2x](https://github.com/user-attachments/assets/a7cb000f-b227-4c27-bc0c-f489bace1e22){: width="50%" height="50%"}

물론 bar type도 가능하다.

![CleanShot 2024-09-10 at 02 25 45@2x](https://github.com/user-attachments/assets/d4b45b94-e7af-48cd-beb2-dff44c42bf17){: width="50%" height="50%"}

Point를 Bar로만 바꿔 주면 된다.

