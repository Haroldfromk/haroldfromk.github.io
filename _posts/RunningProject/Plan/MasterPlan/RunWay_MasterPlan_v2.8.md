# [Project] RunWay: The Aviator's Running Tracker (Master Plan v2.8)

## 0. 프로젝트 비전
"Ex-항공정비사의 시각으로 설계한 정밀 운항 기반 러닝 솔루션"
- **슬로건**: Turn Every Run Into A Flight
- **핵심 가치**: 데이터 무결성(Data Integrity), 정밀한 RPM 관리(Cadence), 이륙 시퀀스 경험(Take-off UX)

---

## 1. 핵심 비행 모드 (Flight Operations)

### 🛫 Take-off Sequence (이륙 절차) **[Core UX]**
1. **Pre-flight Check**: GPS/심박수/가속도 센서 수신 확인 (Ready for Take-off 점등)
2. **Thrust Set**: 시작 버튼 클릭 시 Haptic 엔진 가동 (엔진 출력 상승 진동)
3. **Rotation**:
   - 카운트다운 "3... 2... 1..." 숫자마다 햅틱 강도 차별화 (3→약, 2→중, 1→강, ROTATE→최강)
   - **"ROTATE!"** 명령과 함께 UI가 계기판(PFD)으로 전환되며 기록 시작

### ✈️ Mode A: Mission Flight (Target-driven)
- **Target Setting**:
  - 목표 페이스 (min/km) 분/초 개별 설정
  - 허용 오차 `paceDeviation` (±초 단위)
  - 목표 거리 (km) 설정 — 빠른 선택: 3km / 5km / 10km / 하프 / 풀
- **GPWS** — 페이스 기준:
  - **"SINK RATE"**: 목표 페이스 + 허용 오차 초과 → 빨간 배경 점멸 + 햅틱 + 경고음
  - **"OVERSPEED"**: 목표 페이스 - 허용 오차 초과 → 빨간 배경 점멸 + 햅틱 + 경고음
  - **"GLIDE PATH"**: 허용 오차 범위 내 복귀 → 정상 화면 복귀
- **MINIMUMS**: 목표 거리 50m 전 → 노란 배경 점멸 + 햅틱 + 경고음

### ✈️ Mode B: Free Flight (VFR)
- 목표 설정 없는 자유 러닝
- 수동 Touchdown 종료

---

## 2. 화면 구조 (Screens)

| 화면 | 설명 | 연결 |
| :--- | :--- | :--- |
| `HomeView` | Flight Deck — Mode 선택, 최근 기록, 주간 차트, GPS Path 미리보기 | Mission → ModeAView / Free → TakeoffView |
| `ModeAView` | 목표 페이스 + 허용 오차 + 거리 설정 | → TakeoffView |
| `TakeoffView` | Pre-flight Check + ROTATE 카운트다운 | → PFDView |
| `PFDView` | 실시간 계기판, ScrollView + scrollDisabled(true)로 레이아웃 고정 | → TouchdownView |
| `TouchdownView` | 착륙 애니메이션 + 햅틱 | → FlightSummaryView |
| `FlightSummaryView` | 비행 요약 + MapPolyline 경로 | → LogbookView |
| `LogbookView` | 러닝 기록 목록 (ALL / MISSION / FREE 필터) | → FlightSummaryView |
| `AlertsView` | GPWS 경고 이력 조회 (자동 저장) | - |
| `AircraftView` | 유저 프로필 (항공기 = 유저 컨셉) | - |
| `SettingsView` | 앱 설정 | - |

---

## 3. 데이터 모델

### Flight — 러닝 기록
```swift
enum RunMode { case modeA, case modeB }

struct Flight {
    var id = UUID()
    let mode: RunMode
    let distance: Double    // km (HealthKit distanceWalkingRunning → m → km 변환)
    let time: Int           // seconds (HKWorkout 으로 관리 예정)
    let pace: Double        // min/km (HealthKit runningSpeed → m/s → min/km 변환)
    let heartRate: Int      // bpm (HealthKit heartRate 직접 매핑)
    let cadence: Int        // spm (HealthKit stepCount → 분당 걸음 수 변환)
    let fuel: Int           // kcal (HealthKit activeEnergyBurned 직접 매핑)
    let date: Date
    // GPS 좌표 배열 → SwiftData 저장 → MapPolyline 경로 표시
    // 왕복/반복 구간은 겹쳐서 그리는 방식
}
```

### HealthKit 타입 → Flight 모델 매핑
| HealthKit 타입 | Flight 모델 필드 | 변환 |
|------|------|------|
| `heartRate` | `heartRate` | 직접 매핑 |
| `stepCount` | `cadence` | 분당 걸음 수로 변환 |
| `activeEnergyBurned` | `fuel` | 직접 매핑 |
| `distanceWalkingRunning` | `distance` | m → km 변환 |
| `runningSpeed` | `pace` | m/s → min/km 변환 |
| `runningGroundContactTime` | - | 추후 활용 |
| `runningStrideLength` | - | 추후 활용 |

### ModeA — Mission Flight 설정
```swift
struct ModeA {
    var id = UUID()
    var targetPace: Double      // min/km
    var paceDeviation: Int      // seconds
    var targetDistance: Double  // km
}
```

### Aircraft — 유저 프로필
```swift
// 온보딩 시 구현 예정
// 기종 선택 (A320neo 등)
// 키/몸무게/나이/성별 → BMI, 최대심박수(220-나이) 자동 계산
```

### Alerts — GPWS 경고 이력
```swift
// GPWS 경고 발생 시 자동 SwiftData 저장
// AlertsView는 저장된 기록 조회용
```

---

## 4. 🏗 핵심 아키텍처: RunningCenter Actor

### 왜 Actor인가?
GPS, HealthKit, CoreMotion 데이터가 **동시에 병렬로** 들어오는 구조에서:
- ViewModel에서 처리하면 데이터 레이스 위험 + 비대해짐
- `actor`는 내부적으로 **serial queue를 보장** → 상태 무결성 확보
- 메인 스레드 부하 없음

### 전체 데이터 흐름
```text
CoreLocation (Publisher)      ↘
HealthKit (Publisher)          → RunningCenter (Actor) → AsyncStream → ViewModel (@MainActor) → SwiftUI
WatchConnectivity (Publisher)  ↗
```

- **Combine Publisher** — CoreLocation, HealthKit, WatchConnectivity 센서 데이터 수집
- **RunningCenter Actor** — Combine 스트림을 받아 데이터 가공 및 상태 관리
- **AsyncStream** — 가공된 데이터를 ViewModel로 전달
- **ViewModel** — View에 필요한 값만 노출

### RunningCenter Actor 설계
```swift
actor RunningCenter {
    private(set) var phase: FlightPhase = .preflight
    private var totalDistance: Double = 0
    private var lastLocation: CLLocation?
    var coordinateArray = [(latitude: Double, longitude: Double)]()

    func processLocation(_ location: CLLocation) { ... }
    func processHeartRate(_ bpm: Int) { ... }
    func processCadence(_ spm: Int) { ... }

    func flightDataStream() -> AsyncStream<FlightData> { ... }
}
```

### MVP 전략
- MVP: `RunningCenter` **1개**로 통합
- 내부는 processor로 관심사 분리
- 앱 커지면 Actor 분해 (오버엔지니어링 방지)

### 면접 답변
> "GPS, 심박수, 케이던스가 동시에 들어오므로 상태 무결성을 보장하기 위해 RunningCenter Actor를 두고 모든 러닝 계산을 단일 격리 영역에서 처리했습니다."

---

## 5. ✈️ FlightPhase 상태 머신

### 왜 필요한가?
각 화면이 독립적으로 상태를 판단하는 대신, 항공기 운항 단계에서 착안한 **단일 상태**로 앱 전체를 관리.
Dynamic Island, Watch, PFD가 동일한 상태를 참조.

### FlightPhase
```swift
enum FlightPhase {
    case preflight     // 이륙 준비
    case takeoff       // ROTATE 카운트다운
    case cruise        // 정상 러닝
    case approach      // MINIMUMS 진입 (목표 거리 50m 전)
    case touchdown     // 러닝 종료
}
```

### 상태 전환 흐름
```text
앱 진입 → preflight
ROTATE 시작 → takeoff
러닝 시작 → cruise
목표 거리 50m 전 → approach (MINIMUMS 자동 트리거)
러닝 종료 → touchdown
```

### 면접 포인트
> "단순히 러닝 중인지 아닌지를 Bool로 관리하지 않고, 항공기 운항 단계에서 착안한 FlightPhase 상태 머신을 도입하여 앱 전체가 동일한 상태를 참조하도록 설계했습니다."

---

## 6. GPWS 경고 시스템

| 상태 | 트리거 | 시각 효과 | 햅틱 | 사운드 |
| :--- | :--- | :--- | :--- | :--- |
| SINK RATE | 현재 페이스 > 목표 + paceDeviation | 빨간 배경 점멸 | Heavy | 경고음 |
| OVERSPEED | 현재 페이스 < 목표 - paceDeviation | 빨간 배경 점멸 | Heavy | 경고음 |
| GLIDE PATH | 허용 오차 범위 내 복귀 | 정상 | - | Chime |
| MINIMUMS | approach 페이즈 진입 시 자동 | 노란 배경 점멸 | Medium | 경고음 |

---

## 7. Touchdown 애니메이션

- `rotationEffect` → `scaleEffect` → `offset` 순서 (회전 후 이동)
- 비행기 아래(크게) → 위(작게) 소실점으로
- Heavy → Medium 햅틱
- "TOUCHDOWN" 스프링 애니메이션

---

## 8. 핵심 기술 스택

| 구분 | 기술 | 목적 |
| :--- | :--- | :--- |
| UI | SwiftUI | 전체 화면 구성 |
| 상태관리 | @MainActor + @Observable | UI 상태 |
| 동시성 | Actor (RunningCenter) + AsyncStream | 센서 데이터 직렬 처리 |
| 반응형 스트림 | Combine | 센서 데이터 Publisher 래핑 (CoreLocation, HealthKit, WatchConnectivity) |
| 상태 머신 | FlightPhase enum | 앱 전체 단일 상태 참조 |
| 저장 | SwiftData | 러닝 기록 + GPWS 이력 |
| 센서 | HealthKit + CoreLocation | 심박수, GPS, 케이던스 |
| 모션 | CoreMotion | Attitude Indicator |
| 지도 | MapKit + MapPolyline | 러닝 경로 시각화 |
| 사운드 | AudioToolbox | GPWS 경고음 |
| 워치 | WatchConnectivity | iPhone ↔ Watch |

---

## 9. MVP 개발 로드맵

### [Week 1] Engine Installation
- SwiftData 모델 설계 (Flight, ModeA) ✅
- UI Mock 전체 화면 구현 ✅
- CoreLocation 서비스 구현 ✅
- HealthKit 서비스 구현 ✅ (MockData 포함)
- DI + 데이터 흐름 (RunViewModel) ✅

### [Week 2] Cockpit & Take-off
- RunningCenter Actor 구현 (진행 중)
  - 위치 데이터 처리 (거리 누적, 경로 좌표 저장)
  - Combine Publisher로 LocationService 리팩토링
  - FlightPhase 상태 머신 연동
- AsyncStream → ViewModel 연결
- PFD 실시간 데이터 표시
- GPWS 로직 실제 연동
- MockUI → 실제 데이터 연결 + UI 보완
- 온보딩 뷰 (Aircraft 모델 연동)

### [Week 3] Avionics
- Watch 단독 앱 + WatchConnectivity (Combine Publisher 래핑)
- Dynamic Island 5가지 상태
- FlightSummaryView 실제 GPS 경로 연동

### [Week 4] Analysis & Stability
- 실기기 안정화 테스트

### [Week 5] Release
- App Store 심사 제출
- 포트폴리오 포스팅

---

## 10. 차후 확장

- **Phase 2**: 비동기 랭킹 (Firebase)
- **Phase 3**: AI 맞춤형 페이스 가이드
- **Phase 4**: 기종 추가 (A320neo 등)
- **Phase 5**: RunningCenter Actor 분해 (LocationActor, HealthActor 등)

---

## 11. 결론: "Cleared for Take-off"
전직 항공정비사의 철학이 담긴 정밀 러닝 솔루션. **"Rotate"**와 함께 비행을 시작하세요.
