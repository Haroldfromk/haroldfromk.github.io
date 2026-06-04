# RunWay — Week 1: Engine Installation

## Overview

| Day | 주제 | 세부 작업 |
| :--- | :--- | :--- |
| Day 1 ✅ | 프로젝트 세팅 | Xcode 프로젝트 생성, Swift 6 설정, 폴더 구조, Git 초기화 |
| Day 2 | SwiftData 모델 | Flight, Gear, User 모델 설계 및 ModelContainer 설정 |
| Day 3 | CoreLocation | LocationService 프로토콜 + 구현체, 위치 권한 처리 |
| Day 4 | HealthKit | HealthKitService 프로토콜 + 심박수/케이던스 수집 |
| Day 5 | DI + 데이터 흐름 | ServiceContainer, MVVM 연결, AsyncStream 연결 |
| Day 6-7 | 버퍼 + 운동 | 못 채운 부분 보완, 실기기 테스트, 걷기/러닝 |

---

## Day 1 ✅ — 프로젝트 세팅

- [x] Xcode 프로젝트 생성 (iOS + watchOS)
- [x] Swift 6 언어 버전 설정
- [x] `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 설정
- [x] 폴더 구조 생성 (Models / Services / ViewModels / Views / Utilities)
- [x] Git 초기화

---

## Day 2 — SwiftData 모델

### 목표
러닝 기록을 저장할 SwiftData 모델 3개 설계

### 체크리스트
- [ ] `Flight` 모델 — 러닝 기록 (거리, 시간, 페이스, 심박수, 케이던스)
- [ ] `ModeA` 모델 — 사용자 설정 (목표 페이스, 허용 오차)
- [ ] `ModelContainer` 설정 (`RunWayApp.swift`에 연결)
- [ ] SwiftData `@Model` 매크로 적용 확인

### 예상 파일
```
Models/
  Flight.swift
  Gear.swift
  User.swift
```

---

## Day 3 — CoreLocation

### 목표
GPS 위치 데이터를 안전하게 수집하는 서비스 레이어 구현

### 체크리스트
- [ ] `LocationServiceProtocol` 프로토콜 정의
- [ ] `LocationService` 구현체 작성 (`CLLocationManager` 래핑)
- [ ] `nonisolated` 적용 (백그라운드 위치 수집)
- [ ] `Info.plist` 위치 권한 추가
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
- [ ] `AsyncStream<CLLocation>` 으로 위치 스트림 구성

### 예상 파일
```
Services/
  LocationServiceProtocol.swift
  LocationService.swift
```

---

## Day 4 — HealthKit

### 목표
심박수 + 케이던스 데이터를 HealthKit에서 실시간 수집

### 체크리스트
- [ ] `HealthKitServiceProtocol` 프로토콜 정의
- [ ] `HealthKitService` 구현체 작성
- [ ] HealthKit 권한 요청 처리
  - 심박수 (`HKQuantityTypeIdentifier.heartRate`)
  - 보폭수 (`HKQuantityTypeIdentifier.stepCount`)
- [ ] `Info.plist` 및 Capabilities에 HealthKit 추가
- [ ] `AsyncStream<Int>` 으로 심박수 스트림 구성
- [ ] `AsyncStream<Double>` 으로 케이던스 스트림 구성

### 예상 파일
```
Services/
  HealthKitServiceProtocol.swift
  HealthKitService.swift
```

---

## Day 5 — DI + 데이터 흐름

### 목표
서비스들을 하나로 묶어 ViewModel에 주입, AsyncStream으로 데이터 흐름 연결

### 체크리스트
- [ ] `ServiceContainer` 구현 (LocationService + HealthKitService 보유)
- [ ] `RunViewModel` 생성 (`@Observable @MainActor`)
- [ ] `RunViewModel`에서 두 서비스 주입받아 사용
- [ ] `Task` + `AsyncStream`으로 실시간 데이터 수신 구현
- [ ] `RunWayApp.swift`에서 `ServiceContainer` 생성 후 environment 주입
- [ ] 시뮬레이터에서 기본 데이터 흐름 확인

### 예상 파일
```
Services/
  ServiceContainer.swift
ViewModels/
  RunViewModel.swift
```

---

## Day 6-7 — 버퍼 + 운동

- 못 채운 Day 보완
- 실기기에 빌드해서 GPS/HealthKit 권한 동작 확인
- 걷기 또는 러닝으로 실제 데이터 수집 테스트
