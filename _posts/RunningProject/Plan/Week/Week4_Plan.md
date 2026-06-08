# RunWay — Week 4 Plan: Analysis & Stability

## 목표
Dynamic Island, 실기기 테스트, 데이터 연동 마무리

---

## Day 16 — Dynamic Island
### 목표
Dynamic Island 5가지 상태 구현
### 체크리스트
- [ ] ActivityKit 설정
- [ ] preflight / takeoff / cruise / approach / touchdown 상태 UI
- [ ] FlightPhase 연동
- [ ] 실기기 테스트

---

## Day 17 — 실기기 전체 테스트
### 목표
전체 흐름 실기기 검증
### 체크리스트
- [ ] Home → ModeA → Takeoff → PFD → Touchdown → Summary 전체 흐름
- [ ] GPWS 실제 페이스 기준 트리거 확인
- [ ] GPS 경로 MapPolyline 확인
- [ ] Watch 연동 확인
- [ ] Dynamic Island 상태 전환 확인

---

## Day 18 — 버그 수정 + UI 보완
### 목표
테스트에서 발견된 버그 수정 및 UI 최종 점검
### 체크리스트
- [ ] 버그 수정
- [ ] SpeedTape 애니메이션 구현 (보류 항목)
- [ ] FlightPhase 5단계 복원 (takeoff, approach)
- [ ] 전반적 UI 보완

---

## Day 19 — LogbookView 실제 데이터 연동
### 목표
LogbookView SwiftData 기반 실제 기록 표시
### 체크리스트
- [ ] Flight SwiftData 저장 로직 완성
- [ ] LogbookView ALL / MISSION / FREE 필터
- [ ] LogbookView → FlightSummaryView 연결

---

## Day 20 — HomeView 실제 데이터 연동
### 목표
HomeView 최근 기록 + 주간 차트 실제 데이터 연결
### 체크리스트
- [ ] 최근 기록 SwiftData 연동
- [ ] 주간 차트 실제 데이터 표시
- [ ] GPS Path 미리보기 연동
