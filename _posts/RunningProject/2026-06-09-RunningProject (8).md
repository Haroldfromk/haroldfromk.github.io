---
title: RunWay (8) SwiftData 연동
writer: Harold
date: 2026-06-09 08:33:00 +0900
categories: [RunWay]
tags: [SwiftData, SwiftUI, Actor]

toc: true
toc_sticky: true
published: false
---

## SwiftData 사용하기

러닝 기록을 저장하기 위해 CoreData와 SwiftData를 고민하다가 SwiftData를 선택했다.

가장 큰 이유는 SwiftData가 CoreData를 개선한 방식이기도 하지만, 모델링이 편하다는 장점도 있다. `@Model`만 붙여주면 되기 때문이다.

물론 Xcode에서 CoreData → SwiftData 마이그레이션을 제공하긴 하지만, 신규 프로젝트에서 굳이 마이그레이션을 거칠 이유가 없다고 판단했다.

---

## 모델 설계

러닝 기록을 저장하기 위한 모델을 설계한다.

러닝 전체 데이터를 담는 `Flight`와 GPWS 경고 이력을 담는 `Alert`다. `Alert`를 `Flight` 안에 포함시키는 이유는 간단하다. 어떤 러닝에서 어떤 페이스 경고가 발생했는지를 한 번에 확인하기 위해서다. 러닝 기록을 보면서 그날 경고도 같이 볼 수 있어야 하니까.

다만 SwiftData는 `@Model`을 `class`에만 적용할 수 있어, 기존 `struct` 기반 모델과는 별도로 class 모델을 새로 만들었다.

---

### Flight

러닝 한 세션의 전체 데이터를 담는 모델이다. 거리, 시간, 페이스, 심박수, 케이던스, 칼로리, 날짜와 함께 경고 이력(`alerts`)과 GPS 경로(`coordinates`)를 포함한다.

```swift
@Model
class SwiftDataFlight {
    var id: UUID
    var mode: String       
    var distance: Double    
    var time: Int           
    var pace: Double       
    var heartRate: Int      
    var cadence: Int        
    var fuel: Int           
    var date: Date
    
    @Relationship(deleteRule: .cascade) var alerts: [SwiftDataAlert] = []
    @Relationship(deleteRule: .cascade) var coordinates: [SwiftDataCoordinate] = []
    
    init(mode: String, distance: Double, time: Int, pace: Double, heartRate: Int, cadence: Int, fuel: Int, date: Date) {
        self.id = UUID()
        self.mode = mode
        self.distance = distance
        self.time = time
        self.pace = pace
        self.heartRate = heartRate
        self.cadence = cadence
        self.fuel = fuel
        self.date = date
    }
}
```

---

### Alert

GPWS 경고 발생 시 자동 저장되는 모델이다. 경고 종류, 발생 시각, 당시 페이스, 누적 거리, GPS 좌표를 저장한다. 

`SwiftDataFlight`와 연결되며 Flight 삭제 시 경로 좌표도 함께 삭제된다.

```swift
@Model
class SwiftDataAlert {
    var id: UUID
    var gpwsState: String   // "sinkRate" / "overspeed" / "minimums"
    var pace: Double        // min/km
    var distance: Double    // km
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    
    init(gpwsState: String, pace: Double, distance: Double, timestamp: Date, latitude: Double, longitude: Double) {
        self.id = UUID()
        self.gpwsState = gpwsState
        self.pace = pace
        self.distance = distance
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }
}
```

---

### Coordinates

러닝 경로 전체의 GPS 좌표를 저장하는 모델이다. 러닝 중 위치가 업데이트될 때마다 누적되며 `order`로 순서를 보장한다.

좌표 배열을 `SwiftDataFlight`에 직접 넣지 않고 별도 모델로 분리한 이유는 좌표 수가 러닝 시간에 따라 수백~수천 개까지 늘어날 수 있기 때문이다. 하나의 모델에 담기엔 부담이 크고, `@Relationship`으로 연결하면 필요할 때만 불러올 수 있어 더 효율적이다.

그리고 기존 `RunningCentor`에서 좌표를 튜플 배열 `[(latitude: Double, longitude: Double)]`로 관리하고 있는데, SwiftData는 튜플을 직접 저장할 수 없어 별도 모델로 전환하게 되었다.

`SwiftDataFlight`와 연결되며 MapPolyline 경로 표시에 사용된다.

```swift
@Model
class SwiftDataCoordinate {
    var latitude: Double
    var longitude: Double
    var order: Int
    
    init(latitude: Double, longitude: Double, order: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.order = order
    }
}
```

---

## GPWS 경고 자동 저장

---

## 러닝 종료 시 Flight 저장

---

## TouchdownView 실제 데이터 연결
