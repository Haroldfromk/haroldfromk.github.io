# [Project] RunWay: The Aviator's Running Tracker (Master Plan v2.2)

## 0. 프로젝트 비전
"Ex-항공정비사의 시각으로 설계한 정밀 운항 기반 러닝 솔루션"
- **핵심 가치**: 데이터 무결성(Data Integrity), 정밀한 RPM 관리(Cadence), 이륙 시퀀스 경험(Take-off UX)

---

## 1. 핵심 비행 모드 (Flight Operations)

### 🛫 Take-off Sequence (이륙 절차) **[Core UX]**
1. **Pre-flight Check**: GPS/심박수/가속도 센서 수신 확인 (Ready for Take-off 점등)
2. **Thrust Set**: 시작 버튼 클릭 시 Haptic 엔진 가동 (엔진 출력 상승 진동)
3. **Rotation**: 
   - 카운트다운 "Three... Two... One..." (음성)
   - 카운트다운 숫자마다 햅틱 강도 차별화 (3 → 약, 2 → 중, 1 → 강, ROTATE → 최강)
   - **"ROTATE!"** 명령과 함께 UI가 계기판(PFD)으로 전환되며 기록 시작

### ✈️ Mode A: Mission Flight (Target-driven)
*목표 페이스를 설정하고 오차 범위를 허용하지 않는 정밀 비행*
- **Target Setting**: 목표 페이스(예: 5'30"/km) 및 허용 오차(예: ±10초) 입력
- **GPWS (Ground Proximity Warning System) Monitoring**:
    - **"SINK RATE"**: 목표 페이스보다 느려질 때 (Stall Warning 느낌의 진동)
    - **"OVERSPEED"**: 목표보다 너무 빠르거나 심박수 임계치 초과 시 (긴박한 경고음)
    - **"GLIDE PATH"**: 목표 페이스 안으로 복귀 시 짧은 안도음(Chime)
- **Decision Height**: 목표 거리 도달 500m 전 "MINIMUMS" 안내

### ✈️ Mode B: Free Flight (VFR - 시계비행)
- **목적**: 기록에 연연하지 않는 자유 러닝
- **특징**: 군더더기 없는 HUD 스타일 UI 제공 및 수동 'Touchdown' 종료

---

## 2. 주요 기능 및 아키텍처 (Core Systems)

### [System 1] Glass Cockpit UI (SwiftUI & Canvas)
- **PFD Style UI**: 
    - **Airspeed**: 실시간 페이스
    - **Altitude**: 고도
    - **N1% (Engine RPM)**: **심박수**와 **케이던스(SPM)**를 듀얼 게이지로 시각화
    - **Attitude Indicator**: CoreMotion 연동으로 기기 기울기에 따라 실시간 반응하는 인공 수평선
- **Dynamic Island HUD**: Live Activities를 활용해 백그라운드 운항 상태 모니터링 (5가지 상태)
- [코드 1] SwiftUI Canvas를 활용한 항공 계기판 UI 드로잉 로직

### [System 2] Standalone watchOS & Connectivity
- **독립 운항**: iPhone 없이 Watch 단독으로 "Rotate" 및 데이터 기록
- **Sensor Fusion**: 가속도계(Accelerometer)를 활용한 정밀 케이던스 측정
- [코드 2] WCSession 프로토콜 기반의 실시간 텔레메트리

### [System 3] Flight Logbook (SwiftData & Concurrency)
- **Black Box**: **async/await**를 활용해 고주파 데이터(위치/심박/케이던스)를 안전하게 저장
- **Maintenance Log**: 러닝화(Landing Gear) 마모도 및 신체 컨디션 기록
- [코드 3] SwiftData 모델 설계 및 `@ModelActor` 비동기 처리

---

## 3. 핵심 기술 및 설계 원칙

### 🧱 Dependency Injection (DI) - 부품 규격화
- **내용**: `LocationService`, `CadenceService` 등을 프로토콜로 추상화
- **목적**: 유지보수 시 엔진(로직) 교체를 용이하게 하고 테스트 무결성 확보

### ⚡ Swift Concurrency - 실시간 관제
- **내용**: `Task`, `AsyncStream`을 사용하여 센서 데이터 흐름 제어
- **목적**: 메인 스레드 간섭 없이 위치 업데이트와 데이터 저장을 안전하게 처리

---

## 4. 핵심 기술 스택 (The Tech Stack)

| 구분 | 기술 프레임워크 | 도입 목적 |
| :--- | :--- | :--- |
| **Platform** | **iOS & watchOS** | **[iOS]**: FMC 역할 (설정, 분석) / **[watchOS]**: Avionics (센서, 햅틱) |
| **Storage** | **SwiftData** | 정밀 비행 일지(Logbook) 및 로컬 영속성 관리 |
| **Analysis** | **Swift Charts** | 페이스, 심박수, **케이던스(SPM)** 추이 시각화 |
| **Biometrics** | **HealthKit** | 심박수, 칼로리, **케이던스(Steps/Min)** 정밀 연동 |
| **Reactive** | **Combine / Async** | 센서 데이터 스트림 처리 및 GPWS 이벤트 핸들링 |
| **Motion** | **CoreMotion** | Attitude Indicator 실시간 기기 기울기 연동 |

---

## 5. MVP 개발 로드맵 (5-Week Sprint)

### [Week 1] Engine Installation (데이터 및 구조)
- **Engine**: HealthKit(심박/케이던스) + CoreLocation 수집 로직 구현
- **Model**: SwiftData 로그북 설계 (Flight, Gear, User)
- **Architecture**: MVVM + DI 구조 확립

### [Week 2] Cockpit & Take-off (UI/UX)
- **Mockup**: HTML/CSS로 제작한 UI 목업 기반으로 SwiftUI 화면 구현
  - Home, PFD, Take-off, Landing, Watch 화면
  - Dynamic Island 5가지 상태 (Compact, Expanded, GPWS, MINIMUMS, Touchdown)
- **Visual**: PFD 계기판 구현 (케이던스 게이지 포함)
- **Attitude Indicator**: CoreMotion 연동 인공 수평선 구현
- **UX**: 햅틱/오디오가 결합된 "Rotate" 이륙 시퀀스 구현
  - 카운트다운 단계별 햅틱 강도 차별화
  - Home 화면 최근 7일 페이스 미니 차트 (Swift Charts)

### [Week 3] Avionics (워치 및 경고 시스템)
- **Warning**: 목표 페이스 이탈 시 작동하는 **GPWS 로직(Mode A)** 구현
- **Watch**: 워치 단독 앱 및 Connectivity 연동

### [Week 4] Analysis & Stability (분석 및 안정화)
- **Charts**: 운동 종료 후 **케이던스/페이스/심박수 오버레이 차트** 구현
- **Test**: 장시간 러닝 시 데이터 유실 점검 (Black-box Test)

### [Week 5] Release (출시)
- **Deploy**: App Store 심사 제출 및 런칭
- **Portfolio**: 깃블로그에 기술적 성과(DI, Concurrency) 포스팅

---

## 6. 차후 확장 계획 (Post-MVP)

- **Phase 2 (Global Air Race)**: 비동기 랭킹 시스템 (Firebase)
- **Phase 3 (Auto-Pilot)**: AI 기반 사용자 맞춤형 페이스 가이드
- **Phase 4 (Fleet Management)**: 러닝화별 마모도 및 교체 주기 관리

---

## 7. 결론: "Cleared for Take-off"
이 프로젝트는 단순한 러닝 앱이 아닙니다. 엔진 RPM(케이던스)까지 정밀하게 관리하는 Ex-항공정비사의 철학이 담긴 전문 운항 솔루션입니다. **"Rotate"**와 함께 비행을 시작하세요.
