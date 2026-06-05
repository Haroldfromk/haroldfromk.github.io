# RunWay — Week 2 Plan: Cockpit & Take-off

## 목표
RunningCenter Actor 구현 및 MockUI → 실제 데이터 연결

---

## Day 6 — RunningCenter Actor
### 목표
RunningCenter Actor 구현 및 FlightPhase 상태 머신 연동
### 체크리스트
- [ ] `RunningCenter` Actor 기본 구조 구현
- [ ] `FlightPhase` 상태 머신 연동
- [ ] `processLocation`, `processHeartRate`, `processCadence` 구현
- [ ] `flightDataStream()` AsyncStream 구현

---

## Day 7 — ViewModel 연결
### 목표
AsyncStream → ViewModel → SwiftUI 데이터 흐름 완성
### 체크리스트
- [ ] `RunViewModel`에서 AsyncStream 수신
- [ ] PFD 실시간 데이터 표시
- [ ] MockUI → 실제 데이터 연결
- [ ] UI 보완 사항 체크

---

## Day 8 — GPWS 로직
### 목표
GPWS 경고 시스템 실제 데이터 연동
### 체크리스트
- [ ] SINK RATE / OVERSPEED / GLIDE PATH 로직 구현
- [ ] MINIMUMS 자동 트리거
- [ ] 햅틱 + 경고음 연동
- [ ] AlertsView SwiftData 자동 저장 연동

---

## Day 9 — 온보딩
### 목표
Aircraft 모델 기반 온보딩 뷰 구현
### 체크리스트
- [ ] 온보딩 UI 구현
- [ ] Aircraft 모델 SwiftData 저장
- [ ] BMI + 최대심박수 자동 계산
- [ ] 온보딩 완료 후 HomeView 진입

---

## Day 10 — Week 2 마무리
### 목표
실기기 테스트 + 안정화
### 체크리스트
- [ ] 실기기 테스트
- [ ] 버그 수정
- [ ] Week 2 UI 보완 최종 점검
