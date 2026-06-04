# [Project] RunWay: The Aviator's Running Tracker (Master Plan v2.5)

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
- **GPWS (Ground Proximity Warning System)** — 페이스 기준:
  - **"SINK RATE"**: 목표 페이스 + 허용 오차 초과 시 → 빨간 배경 점멸 + 햅틱 + 경고음
  - **"OVERSPEED"**: 목표 페이스 - 허용 오차 초과 시 → 빨간 배경 점멸 + 햅틱 + 경고음
  - **"GLIDE PATH"**: 허용 오차 범위 내 복귀 시 → 정상 화면 복귀
  - 심박수는 GPWS 기준 아님, N1% 게이지 모니터링용
- **MINIMUMS**: 목표 거리 50m 전 → 노란 배경 점멸 + 햅틱 + 경고음

### ✈️ Mode B: Free Flight (VFR)
- 목표 설정 없는 자유 러닝
- HUD 미니멀 UI
- 수동 Touchdown 종료

---

## 2. 화면 구조 (Screens)

| 화면 | 설명 | 연결 |
| :--- | :--- | :--- |
| `HomeView` | Flight Deck — Mode 선택, 최근 기록, 주간 차트, GPS Path 미리보기 | Mission → ModeAView / Free → TakeoffView |
| `ModeAView` | 목표 페이스 + 허용 오차 + 거리 설정 | → TakeoffView |
| `TakeoffView` | Pre-flight Check + ROTATE 카운트다운 | → PFDView |
| `PFDView` | 실시간 계기판 (속도 테이프 + ADI + N1% 게이지), ScrollView + scrollDisabled(true)로 레이아웃 고정 | → TouchdownView |
| `TouchdownView` | 착륙 애니메이션 (비행기 + 런웨이) + 햅틱 | → FlightSummaryView |
| `FlightSummaryView` | 비행 요약 + MapPolyline 경로 지도 | → LogbookView |
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
    let distance: Double    // km
    let time: Int           // seconds
    let pace: Double        // min/km (average)
    let heartRate: Int      // bpm (average)
    let cadence: Int        // spm (average)
    let fuel: Int           // kcal
    let date: Date
    // GPS 좌표 배열 → SwiftData 저장 → MapPolyline 경로 표시
    // 왕복/반복 구간은 겹쳐서 그리는 방식으로 처리
}
```

### ModeA — Mission Flight 설정
```swift
struct ModeA {
    var id = UUID()
    var targetPace: Double      // min/km
    var paceDeviation: Int      // seconds (허용 오차)
    var targetDistance: Double  // km (MINIMUMS 기준)
}
```

### Aircraft — 유저 프로필 (유저 = 항공기 한 대 컨셉)
```swift
// 온보딩 시 구현 예정
// 기종 선택 (A320neo 등) → 나중에 기종 추가 가능
// 키/몸무게/나이/성별 → BMI, 최대심박수(220-나이) 자동 계산
```

### Alerts — GPWS 경고 이력
```swift
// 러닝 중 GPWS 경고 발생 시 자동으로 SwiftData 저장
// AlertsView는 저장된 기록 조회용
```

---

## 4. 🏗 핵심 아키텍처: RunningCenter Actor

### 왜 Actor인가?
RunWay는 GPS, HealthKit, CoreMotion 센서 데이터가 **동시에 병렬로** 들어오는 구조다.
이를 ViewModel에서 처리하면:
- ViewModel이 비대해짐 (위치 계산 + 페이스 계산 + 심박 처리 + GPWS 판단 + 저장)
- 데이터 레이스 가능성 (병렬 센서 데이터가 동시에 상태 변경)

`actor`는 내부적으로 **serial queue를 보장**하므로:
- "GPS 계산 끝나고 나서 심박 처리" 가 자동 보장
- 데이터 무결성 확보
- 메인 스레드 부하 없음

### 구조
```text
CoreLocation
HealthKit      →  RunningCenter (Actor)  →  AsyncStream  →  ViewModel (@MainActor)  →  SwiftUI
CoreMotion
```

### RunningCenter Actor 설계
```swift
actor RunningCenter {
    // 내부 Processor로 관심사 분리
    private var gpsProcessor: GPSProcessor
    private var heartRateProcessor: HeartRateProcessor
    private var cadenceProcessor: CadenceProcessor
    private var gpwsProcessor: GPWSProcessor

    // 센서 데이터 진입점
    func processLocation(_ location: CLLocation) async { ... }
    func processHeartRate(_ bpm: Int) async { ... }
    func processCadence(_ spm: Int) async { ... }

    // ViewModel로 전달
    func flightDataStream() -> AsyncStream<FlightData> { ... }
}
```

### ViewModel은 계기판만
```swift
@MainActor
final class RunningViewModel: ObservableObject {
    @Published var flightData: FlightData = .empty

    func startListening(to center: RunningCenter) {
        Task {
            for await data in await center.flightDataStream() {
                flightData = data
            }
        }
    }
}
```

### MVP 전략
- MVP: `RunningCenter` **1개**로 통합 시작
- 내부는 processor로 관심사 분리
- 앱 커지면 Actor 분해 (LocationActor, HealthActor 등)
- 처음부터 Actor 5개 = 오버엔지니어링

### 면접 답변
> "GPS, 심박수, 케이던스가 동시에 들어오므로 상태 무결성을 보장하기 위해 RunningCenter Actor를 두고 모든 러닝 계산을 단일 격리 영역에서 처리했습니다."

---

## 5. GPWS 경고 시스템 상세

| 상태 | 트리거 | 시각 효과 | 햅틱 | 사운드 |
| :--- | :--- | :--- | :--- | :--- |
| SINK RATE | 현재 페이스 > 목표 + paceDeviation | 빨간 배경 점멸 | Heavy | 경고음 |
| OVERSPEED | 현재 페이스 < 목표 - paceDeviation | 빨간 배경 점멸 | Heavy | 경고음 |
| GLIDE PATH | 허용 오차 범위 내 복귀 | 정상 | - | Chime |
| MINIMUMS | 목표 거리 50m 전 | 노란 배경 점멸 | Medium | 경고음 |

---

## 6. Touchdown 애니메이션 시퀀스

1. 비행기가 아래쪽(크게)에서 위쪽(작게) 소실점으로 올라가며 사라짐
   - modifier 순서: `rotationEffect` → `scaleEffect` → `offset` (회전 후 이동해야 방향 유지)
2. 착륙 햅틱: Heavy → 0.15초 후 Medium
3. "TOUCHDOWN" 텍스트 스프링 애니메이션으로 등장
4. 하단 콘텐츠 즉시 표시
- 활주로 라이트: 앰버색, 원근감
- 중앙 점선: 아래쪽 크고 위쪽 작아지는 원근감

---

## 7. 핵심 기술 스택

| 구분 | 기술 | 목적 |
| :--- | :--- | :--- |
| UI | SwiftUI | 전체 화면 구성 |
| 상태관리 | @Observable + @MainActor | Swift 6 Concurrency |
| 동시성 | Actor (RunningCenter) + AsyncStream | 센서 데이터 직렬 처리 + 상태 무결성 |
| 저장 | SwiftData | 러닝 기록 + GPWS 이력 로컬 저장 |
| 센서 | HealthKit + CoreLocation | 심박수, GPS, 케이던스 |
| 모션 | CoreMotion | Attitude Indicator 연동 |
| 지도 | MapKit + MapPolyline | 러닝 경로 시각화 |
| 차트 | Swift Charts | 페이스/심박수/케이던스 시각화 |
| 워치 | WatchConnectivity | iPhone ↔ Watch 연동 |
| 사운드 | AudioToolbox | GPWS 경고음 |

---

## 8. MVP 개발 로드맵 (5-Week Sprint)

### [Week 1] Engine Installation
- SwiftData 모델 설계 (Flight, ModeA) ✅
- UI Mock 전체 화면 구현 ✅
- RunningCenter Actor 미니 프로젝트 연습 → 실제 적용

### [Week 2] Cockpit & Take-off
- RunningCenter Actor 구현
- CoreLocation 서비스 연동
- HealthKit 서비스 연동
- AsyncStream → ViewModel 연결
- PFD 실시간 데이터 표시
- GPWS 로직 실제 연동
- Dynamic Island 5가지 상태
- 온보딩 뷰 (Aircraft 모델 연동)

### [Week 3] Avionics
- MINIMUMS 로직 (목표 거리 50m 전)
- Watch 단독 앱 + WatchConnectivity
- FlightSummaryView 실제 GPS 경로 MapPolyline 연동

### [Week 4] Analysis & Stability
- 케이던스/페이스/심박수 오버레이 차트
- 실기기 안정화 테스트

### [Week 5] Release
- App Store 심사 제출
- 포트폴리오 포스팅

---

## 9. 차후 확장 계획 (Post-MVP)

- **Phase 2**: 비동기 랭킹 시스템 (Firebase)
- **Phase 3**: AI 기반 맞춤형 페이스 가이드
- **Phase 4**: 기종 추가 (A320neo 등 다양한 항공기 선택)
- **Phase 5**: RunningCenter Actor 분해 (LocationActor, HealthActor 등)

---

## 10. 결론: "Cleared for Take-off"
전직 항공정비사의 철학이 담긴 정밀 러닝 솔루션. **"Rotate"**와 함께 비행을 시작하세요.
