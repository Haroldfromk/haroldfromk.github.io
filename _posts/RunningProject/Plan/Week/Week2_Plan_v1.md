# RunWay — Week 2 Plan: Cockpit & Take-off

## 목표
RunningCenter Actor 완성 + PFD 실시간 데이터 연동 + GPWS 구현

---

## Day 6 — RunningCenter Actor ✅
### 목표
RunningCenter Actor 구현 및 FlightPhase 상태 머신 연동
### 체크리스트
- [x] RunningCenter Actor 기본 구조 구현
- [x] processLocation 구현 (거리 누적, 경로 좌표 저장)
- [x] Combine Publisher로 LocationService 리팩토링
- [x] FlightPhase 상태 머신 연동 (3단계 구현)
- [x] streamFlightData() AsyncStream 구현

---

## Day 7 — ViewModel 연결 ✅
### 목표
AsyncStream → ViewModel → SwiftUI 데이터 흐름 완성
### 체크리스트
- [x] RunViewModel에서 AsyncStream 수신
- [x] FlightData 모델 확장 (pace, altitude, heading)
- [x] PFD 실시간 데이터 표시 (SpeedTapeView, ADIView, DIST, FLIGHT TIME)
- [x] elapsedTime ViewModel 타이머 관리 (Timer.publish)
- [x] AVG 페이스 계산
- [x] Environment 기반 ViewModel 주입

---

## Day 8 — GPWS 로직 ✅
### 목표
GPWS 경고 시스템 실제 데이터 연동
### 체크리스트
- [x] ModeAView 목표 페이스 / paceDeviation / 목표 거리 설정 연결
- [x] GPWSState enum 신규 생성 (RunningCentor)
- [x] FlightData gpwsStatus 추가
- [x] SINK RATE / OVERSPEED 로직 구현 (calculateGPWSStatus)
- [x] MINIMUMS 자동 트리거 (목표 거리 50m 전)
- [x] isReachedPace 플래그 (GPWS 활성화 조건)
- [x] 햅틱 + 경고음 연동
- [x] TakeoffView → PFDView → TouchdownView 화면 흐름 연결
- [ ] AlertsView SwiftData 자동 저장 연동 → Day 11로 이동

---

## Day 9 — SwiftData 연동
### 목표
AlertsView SwiftData 저장 + Flight 기초 저장 작업
### 체크리스트
- [ ] Alerts 모델 SwiftData 설계
- [ ] GPWS 경고 발생 시 자동 저장 로직
- [ ] AlertsView 실제 데이터 표시
- [ ] Flight SwiftData 저장 기초 작업

---

## Day 10 — Week 2 마무리
### 목표
실기기 테스트 + 안정화
### 체크리스트
- [ ] 실기기 테스트
- [ ] 버그 수정
- [ ] Week 2 UI 보완 최종 점검
- [ ] FlightPhase 5단계 복원 준비 (takeoff, approach)
