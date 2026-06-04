# Claude 추천: MiniRunner 미니 프로젝트

## 한 줄 요약
RunWay Actor 구조를 실제 센서 없이 축소 버전으로 먼저 체험하고, 나중에 RunWay에 그대로 이식한다.

---

## 핵심 아이디어
실제 GPS/HealthKit 없이 **Timer로 가짜 센서 데이터**를 1초마다 생성해서 Actor에 흘려보낸다.
구조는 RunWay와 완전히 동일하게 가져간다.

---

## 데이터 흐름

```
SensorSimulator (Timer로 가짜 데이터 생성)
        ↓
RunningCenter Actor (pace 계산, distance 누적, FlightPhase 전환)
        ↓
AsyncStream<FlightData>
        ↓
RunningViewModel (@MainActor)
        ↓
SwiftUI (숫자만 보여주는 단순 UI)
```

---

## 구성 요소

### SensorSimulator
- 실제 센서 대신 Timer 사용
- 1초마다 랜덤 pace, heartRate, cadence 생성
- AsyncStream으로 흘려보냄

### RunningCenter Actor
- 모든 계산을 여기서 처리
- pace 계산, distance 누적
- FlightPhase 전환 (cruise → approach → touchdown)
- FlightData를 AsyncStream으로 방출

### RunningViewModel
- @MainActor
- Actor에서 받은 FlightData를 @Published로 UI에 전달
- UI 표시만 담당

### SwiftUI View
- 숫자만 보여주는 단순 화면
- pace, heartRate, distance, FlightPhase 텍스트 표시
- START 버튼 하나

---

## 배우는 것
- Actor 내부 serial 처리 직접 체험
- AsyncStream 생성 및 소비 흐름
- @MainActor ViewModel과 Actor 연결 패턴
- FlightPhase 상태 전환 로직
- RunWay에 그대로 이식 가능한 구조 습득

---

## 예상 소요 시간
2~3시간

---

## RunWay 이식 시 달라지는 것
SensorSimulator → CoreLocation + HealthKit + CoreMotion 으로 교체만 하면 끝
