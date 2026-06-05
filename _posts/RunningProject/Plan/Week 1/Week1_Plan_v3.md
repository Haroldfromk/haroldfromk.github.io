# RunWay — Week 1: Engine Installation

## Overview

| Day | 주제 | 세부 작업 |
| :--- | :--- | :--- |
| Day 1 ✅ | 프로젝트 세팅 | Xcode 프로젝트 생성, Swift 6 설정, 폴더 구조, Git 초기화 |
| Day 2 ✅ | 모델 설계 | Flight, ModeA, Aircraft 순수 모델 설계 + MockUI 전체 화면 구현 |
| Day 3 ✅ | CoreLocation | LocationService 구현체, 위치 권한 처리, 실기기 테스트 |
| Day 4 ✅ | HealthKit | HealthKitService 구현체, MockData 생성 및 fetch 확인 |
| Day 5 | DI + 데이터 흐름 | RunViewModel, 서비스 주입 구조, 데이터 흐름 연결 (주말 포함 진행) |

---

## Day 1 ✅ — 프로젝트 세팅

- [x] Xcode 프로젝트 생성 (iOS + watchOS)
- [x] Swift 6 언어 버전 설정
- [x] `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 설정
- [x] 폴더 구조 생성 (Models / Services / ViewModels / Views / Utilities)
- [x] Git 초기화
- [x] .gitignore 추가
- [x] GitHub 레포 생성 (private)
- [x] dev 브랜치 생성
- [x] GitHub Projects - RunWay Board 생성
- [x] 커밋 컨벤션 및 브랜치 전략 수립

---

## Day 2 ✅ — 모델 설계 + MockUI

### 목표
러닝 기록과 Mode A 설정을 담을 순수 Swift 모델 설계 + MockUI 전체 화면 구현

### 체크리스트
- [x] `RunMode` enum 정의 (`.modeA` / `.modeB`)
- [x] `Flight` 모델 — 러닝 기록 (거리, 시간, 페이스, 심박수, 케이던스, 칼로리, 모드)
- [x] `ModeA` 모델 — 목표 페이스, 허용 오차(paceDeviation)
- [x] `Aircraft` 모델 — 유저 프로필 (항공기 컨셉)
- [x] MockUI 전체 화면 구현

---

## Day 3 ✅ — CoreLocation

### 목표
GPS 위치 데이터를 안전하게 수집하는 서비스 레이어 구현

### 체크리스트
- [x] `LocationService` 구현체 작성 (`CLLocationManager` 래핑)
- [x] `nonisolated` 적용 (Swift 6 Concurrency 대응)
- [x] `Info.plist` 위치 권한 추가
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationTemporaryUsageDescriptionDictionary`
- [x] `UIBackgroundModes` location 추가
- [x] `startTracking` / `stopTracking` 구현
- [x] MapTestView로 시뮬레이터 + 실기기 테스트 완료

### 비고
- `Generate Info.plist File = No` + 수동 Info.plist 방식으로 관리
- Xcode 26 Capabilities 탭 크래시 버그로 인해 Info.plist 직접 편집으로 대응

---

## Day 4 ✅ — HealthKit

### 목표
HealthKit 세팅 및 MockData를 통한 데이터 수집 확인

### 체크리스트
- [x] `HealthKitService` 구현체 작성
- [x] HealthKit 권한 요청 처리
- [x] Capabilities에 HealthKit + Background Delivery 추가
- [x] 데이터 타입 선언 (heartRate, stepCount, activeEnergyBurned, distanceWalkingRunning, runningSpeed, runningGroundContactTime, runningStrideLength)
- [x] MockData 생성 및 store 저장
- [x] fetch 함수 작성 (HKAnchoredObjectQueryDescriptor, HKStatisticsCollectionQueryDescriptor)
- [x] 시뮬레이터 콘솔 확인
- [ ] 실기기 테스트 (추후 예정)

### 비고
- `pace`는 별도 계산 없이 `runningSpeed` (m/s → min/km 변환)로 직접 받아오는 방식으로 변경
- `toShare` 타입은 `healthTypes as! Set<HKSampleType>` 캐스팅 필요

---

## Day 5 — DI + 데이터 흐름

### 목표
LocationService + HealthKitService를 ViewModel에 연결하여 데이터 흐름 구성

### 비고
주말을 활용하여 진행. 하루 안에 끝내기보다 충분히 시간을 들여 구조를 잡는 데 집중한다.
`ServiceContainer`, `AsyncStream`은 구현하면서 필요하다고 판단되면 추가한다.
단, 주말에 체크리스트를 해결했을 경우 완료 날짜를 함께 표시한다.

### 체크리스트
- [ ] `RunViewModel` 생성 (`@Observable @MainActor`)
- [ ] `LocationService`, `HealthKitService` 주입 구조 결정
- [ ] `RunViewModel`에서 실시간 데이터 수신 구현
- [ ] `RunWayApp.swift`에서 서비스 생성 후 environment 주입
- [ ] 시뮬레이터에서 기본 데이터 흐름 확인
