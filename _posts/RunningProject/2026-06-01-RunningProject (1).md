---
title: Running Project (1)
writer: Harold
date: 2026-06-01 07:33:00 +0800
categories: [RunningProject]
tags: [Project]

toc: true
toc_sticky: true
published: false
---

운동을 시작해야겠다는 생각이 들었다. 이왕 하는 거 내가 직접 만든 앱으로 하자 싶었고, 어떤 앱을 만들지 고민하다 보니 자연스럽게 전직 항공정비사 시절 생각이 났다.

항공기 계기판(PFD)처럼 데이터를 한눈에 보여주는 러닝 앱. 그게 RunWay의 시작이다.

---

## 앱 소개

| 항목 | 내용 |
| :--- | :--- |
| 앱 이름 | RunWay |
| 컨셉 | 항공 계기판(PFD) 스타일의 러닝 트래커 |
| 플랫폼 | iOS 18.5+ / watchOS 11.5+ |
| Swift 버전 | Swift 6 |
| Xcode | Xcode 26.5 |

## 기술 스택

| 구분 | 기술 | 목적 |
| :--- | :--- | :--- |
| UI | SwiftUI | 전체 화면 구성 |
| 상태관리 | @Observable + @MainActor | Swift 6 Concurrency |
| 저장 | SwiftData | 러닝 기록 로컬 저장 |
| 센서 | HealthKit + CoreLocation | 심박수, GPS, 케이던스 |
| 모션 | CoreMotion | Attitude Indicator 연동 |
| 차트 | Swift Charts | 페이스/심박수 시각화 |
| 워치 | WatchConnectivity | iPhone ↔ Watch 연동 |

## 5주 로드맵

| Week | 주제 | 내용 |
| :--- | :--- | :--- |
| 1 | Engine Installation | HealthKit + CoreLocation + SwiftData 구조 |
| 2 | Cockpit & Take-off | PFD UI + 이륙 시퀀스 |
| 3 | Avionics | Watch 연동 + GPWS 경고 시스템 |
| 4 | Analysis | 차트 + 안정화 |
| 5 | Release | App Store 심사 |

---

우선은 이렇게 큰 계획을 세웠다.

기술 스택만 봐도 엄청 많지만, 하나하나 보면 한 번씩은 다뤄봤던 것들이다. 여태 공부했던 것들을 이 앱 하나에 응축시켜 보려고 한다.

---

## 1. 프로젝트 만들기

위의 표처럼 기본적인 세팅을 하고 들어간다.

사실 개인적으로 여기서 가장 큰 핵심은 `Swift6`을 사용했다는 점이다.

확실히 Swift5를 쓰다가 최근에 Swift6을 접하니 `Concurrency`부분이 상당히 빡셌다. 즉 그만큼 철저한 Thread 관리가 필요하다는걸 느꼈는데, 이참에 시작을 6으로 해서 개발을 한다면 나중에 리팩토링 할때보다는 훨씬 괜찮을 것이라고 생각했다.

