# RunWay — Week 3 Plan: Avionics

## 목표
Watch 연동, FlightSummaryView GPS 경로, 온보딩 구현

---

## Day 11 — SwiftData 연동
### 목표
AlertsView SwiftData 저장 + FlightSummaryView GPS 경로 연동
### 체크리스트
- [ ] Alerts 모델 SwiftData 설계
- [ ] GPWS 경고 발생 시 자동 저장 로직
- [ ] AlertsView 실제 데이터 표시
- [ ] coordinateArray SwiftData 저장
- [ ] FlightSummaryView MapPolyline 경로 표시

---

## Day 12 — 온보딩
### 목표
Aircraft 모델 기반 온보딩 뷰 구현
### 체크리스트
- [ ] 온보딩 UI 구현 (슬라이드 방식)
- [ ] Aircraft 모델 SwiftData 저장
- [ ] BMI + 최대심박수 자동 계산
- [ ] 온보딩 완료 후 HomeView 진입

---

## Day 13 — Watch UI
### 목표
Watch 단독 앱 UI 구현
### 체크리스트
- [ ] Watch 타겟 추가
- [ ] Watch용 PFD UI 설계 및 구현
- [ ] 심박 / 케이던스 표시 UI
- [ ] Watch 앱 기본 흐름 구성

---

## Day 14 — WatchConnectivity
### 목표
iPhone ↔ Watch 데이터 연동
### 체크리스트
- [ ] WatchConnectivity 설정
- [ ] Combine Publisher 래핑
- [ ] 심박 / 케이던스 실시간 전송
- [ ] RunningCentor processHeartRate / processCadence 연결

---

## Day 15 — PFD Watch 데이터 연동
### 목표
심박 / 케이던스 PFD 실시간 표시
### 체크리스트
- [ ] HR N1% 게이지 실제 데이터 연결
- [ ] CAD N1% 게이지 실제 데이터 연결
- [ ] ADI 경사도 / 수직속도 CoreMotion 연동
- [ ] 실기기 테스트
