---
title: GitExplorer (5)
writer: Harold
date: 2026-05-25 08:06
categories: [Combine]
tags: [Combine]

toc: true
toc_sticky: true
published: false
---

#### GitExplorer (1) — 검색 시스템의 노이즈 캔슬링 및 기초 세팅
* **핵심 로직 및 흐름:** 사용자가 검색창에 타이핑할 때 발생하는 실시간 입력 스트림의 노이즈를 제어하고 비동기 레이스 컨디션을 방지하는 파이프라인 구축이 핵심임.
* **시행착오와 해결:** 처음에는 `PassthroughSubject`로 수동 `send()` 처리를 시도했으나 불필요한 바인딩 루프가 생겨 `@Published` 속성의 `$` Wrapper를 활용한 방식으로 선회함. 이 과정에서 중복 데이터가 2번씩 출력되는 버그가 발생했으나 `debounce` 오퍼레이터의 특성을 활용하고 `.removeDuplicates()`의 위치를 `debounce` 뒤로 정밀하게 배치하여 해결함. 최소 글자 수 필터링을 위해 `.filter({ $0.count > 1 })`를 적용함.
* **네트워크 레이스 컨디션 해결:** [코드 1] `URLSession.dataTaskPublisher`를 통해 GitHub API 통신 부를 구현할 때, 비동기 데이터 충돌(이전 요청이 뒤늦게 도착해 화면을 덮어쓰는 현상)을 막기 위해 상위 스트림을 최신 네트워크 요청 퍼블리셔로 교체해 주는 `flatMap` 혹은 `switchToLatest` 스트림 스위칭 구조의 기틀을 마련함.
* **참고 사이트:** [GitHub Discussion](https://github.com/pointfreeco/swift-composable-architecture/discussions/1093), [GitHub Docs](https://docs.github.com/en/rest/search/search?apiVersion=2026-03-10#search-users), [Auth Docs](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2026-03-10), [이전글](https://haroldfromk.github.io/posts/10%EC%A3%BC%EC%B0%A8-%EA%B3%BC%EC%A0%9C-(10)/)
* **시각 자료:**
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/5405ccd3-926b-402c-9afd-ec26a808a47a.png" alt="Postman API 테스트 결과" />

#### GitExplorer (2) — 프로필 상세 화면 및 다중 API 통합
* **핵심 로직 및 흐름:** 유저 상세 정보 화면 진입 시, 반응형 화면 상태(Status) 관리와 독립적인 3개의 API 요청을 동시에 출발시켜 하나의 통합 모델로 조립하는 흐름임.
* **화면 상태 분리 (Enum 관리):** 단순 값 유무 추론 방식에서 `idle`, `loading`, `success`, `failure` 구조의 명확한 상태 기반 UI 환경으로 개편함. 파이프라인 중간에 로딩 상태를 주입하기 위해 스트림 흐름을 방해하지 않는 `.handleEvents(receiveOutput:)` 오퍼레이터를 도입함.
* **시행착오와 해결:** 에러 발생 시 `catch` 내부에서 직접 `self.status = .failure`를 유도했다가 메인 스레드 경고(Main thread warning)를 마주함. 이를 우회하기 위해 무분별한 `receive(on:)` 중첩 대신, `catch`에서는 빈 배열(`Just([])`)만 안전하게 흘려보내고 최종 `sink` 단에서 빈 배열 여부로 실패 상태를 안전하게 판정하도록 로직을 개선함.
* **다중 요청 병렬 처리:** [코드 2] 제네릭 기반의 `GitHubNetworkService` 리팩토링 후, 프로필 정보·레포지토리 목록·팔로워 목록을 `Publishers.CombineLatest3`으로 묶어 병렬 호출 처리함. 세 데이터가 모두 유효하게 도착하는 시점에 UI를 원샷으로 업데이트함.
* **StateObject 매개변수 초기화 제약:** 외부에서 주입된 유저 객체로 뷰모델을 초기화할 때 `Property initializers run before self is available` 에러 및 `@StateObject` 미설치 접근 경고가 발생하여, 무리한 `init` 연동 대신 `onAppear` 시점에 바인딩 및 초기 조회를 수행하도록 조율함.
* **참고 사이트:** [참고글1](https://sarunw.com/posts/how-to-initialize-stateobject-with-parameters-in-swiftui/), [참고글2](https://www.swiftwithvincent.com/blog/bad-practice-creating-a-stateobject-wrapper), [StateObject Docs](https://developer.apple.com/documentation/swiftui/stateobject)
* **시각 자료:**
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/ea988caa-f3a0-4aa3-9835-04a6a46a2a29.png" alt="초기 아바타 뷰" />
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/bf3e8d18-5566-4696-814f-198daaa455fc.png" alt=" handleEvents 로딩 상태 흐름" />
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/fcf3426d-ef8a-4237-a0ca-c76c756733b3.png" alt="상태별 UI 분기 결과" />
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/ce590d96-0325-4dde-9ac3-8f90b69f72d4.png" alt="세그먼트 탭 레이아웃" />

#### GitExplorer (3) — 즐겨찾기 스트림 관리 및 영속성 레이어 구축
* **핵심 로직 및 흐름:** 물리적인 터치 버튼 이벤트를 순간적인 신호 스트림(Subject)으로 치환하여 로컬 저장소 데이터와 유기적으로 누적·결합하는 동기화 메커니즘임.
* **UserDefaults와 AppStorage 계층 분리:** 영속성 적용을 고민하며 뷰 계층 구조에 종속적인 `@AppStorage` 대신 뷰모델 및 비즈니스 로직 계층에 적합한 오리지널 `UserDefaults`를 채택함.
* **스트림 생존 보장 (Never의 의의):** 예전 프로젝트에서 `Failure` 타입에 일반 `Error`를 할당했다가 에러 방출과 동시에 스트림이 통째로 파괴되었던 인과관계를 기억해 냄. 단순 액션 신호에는 절대로 끊어지지 않는 파이프라인인 `Never` 타입을 적용하여 연속적인 이벤트 탭을 수용함. `PassthroughSubject<String, Never>`를 통해 데이터 원격 전송 구조를 완성함.
* **시행착오와 해결:** SwiftUI `.onDelete` 가 전달하는 `IndexSet` 구조를 파악함. 다중 삭제 대응이 가능한 특징이 있으나 단일 스와이프 삭제 상황에서는 최적화를 위해 `if let index = indexSet.first` 문맥으로 핸들링함. 뷰모델 인스턴스가 뷰마다 독립적으로 생성되어 즐겨찾기 추가/삭제 시 화면 간 실시간 동기화가 깨지는 현상이 생겼으나, 임시로 `onAppear` 시점에 `UserDefaults` 데이터를 강제 갱신하는 리로드 함수를 붙여 화면 단위의 유실을 방지함.
* **참고 사이트:** [Medium](https://medium.com/@nsuneelkumar98/swiftui-data-persistence-userdefaults-vs-appstorage-a66c41666d15), [이전글1](https://haroldfromk.github.io/posts/Final-(8)/), [이전글2](https://haroldfromk.github.io/posts/Final-(17)/), [이전글3](https://haroldfromk.github.io/posts/Todoey-(2)/)
* **시각 자료:**
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/4940eee5-5304-405d-b638-bd0ffd2b69ce.png" alt="UserDefaults vs AppStorage 요약" />
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/6963a6f5-4b72-40ca-846e-fb4e20d196c4.png" alt="즐겨찾기 토글 별 렌더링" />
  <img src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/ef38a113-feb5-44ba-a2b1-095b8f433818.png" alt="즐겨찾기 목록 뷰" />

#### GitExplorer (4) — 백그라운드 자동 갱신 및 비동기 동시성 브릿지
* **핵심 로직 및 흐름:** 타이머 기반의 백그라운드 스케줄러 스트림을 열어 주기적으로 데이터를 리프레시하고, 고성능 연타 방지 댐을 구축하며, 기존 Combine 코드를 최신 `async/await` 동시성 문법과 상호 호환시키는 가교(Bridge) 작업임.
* **동적 다중 요청 처리:** 저장된 유저 배열 수량에 대응하기 위해 `names.map`으로 각 유저별 단독 퍼블리셔들을 생성한 뒤, 가변적 스트림 결합에 특화된 `Publishers.MergeMany`를 사용하여 병렬 스트림을 전개함. `replaceError` 사용 직후 에러 타입이 `Never`로 즉시 치환되는 특성을 파악하여 타입 불일치 컴파일 에러를 교정하고, 최종 수신부에서 2차원 배열을 1차원 구조로 평탄화하기 위해 `result.flatMap { $0 }` 기법을 적용함.
* **구독 중첩 버그 차단:** 화면 이탈 후 재진입 시 `Timer.publish` 구독선이 중복 개설되어 네트워크 트래픽이 폭증하는 메모리 누수 요인을 발견함. 화면이 닫힐 때 기존 타이머 스트림에 명시적으로 `.cancel()` 신호를 주어 파괴하거나, 뷰모델의 `deinit` 라이프사이클에 맞춰 `AnyCancellable` 집합체가 자동으로 메모리를 해제하게끔 라이프사이클 인과관계를 바로잡음.
* **연타 방지 및 청크 저장:** [코드 3] 수동 새로고침 버튼 폭주를 방지하기 위해 단기간의 입력 스트림을 억제하는 `throttle` 오퍼레이터를 장착함. (첫 신호 우선 방출 속성인 `latest: false` 지정). 자원 절약을 위해 흐르는 데이터를 특정 시간 단위 묶음으로 처리하는 `collect(.byTime)` 아키텍처의 이론적 활용 방안을 도출함.
* **Combine-Async 브릿지 구현:** 구형 Combine 스트림 기반 비동기 코드를 최신 `async/await` 구조로 안전하게 래핑하기 위해 `withCheckedThrowingContinuation` 기술을 도입함. 스트림의 결과 또는 에러 시점을 정확히 포착하여 `continuation.resume`으로 던져주는 안전 브릿지를 설계함.
* **참고 사이트:** [이전글1](https://haroldfromk.github.io/posts/Final-(8)/), [이전글2](https://haroldfromk.github.io/posts/High-order-function/), [이전글3](https://haroldfromk.github.io/posts/Async_await-(6)/)

#### [HotFix] UI 업데이트 지연 및 배열 정렬 불일치에 따른 삭제 버그 해결
* **핵심 로직 및 흐름:** 즐겨찾기 유저 삭제 시 UI가 즉각적으로 동기화되지 않는 결함과, 디스크 저장 배열(`names`)과 화면 렌더링 배열(`users`)의 인덱스 불일치로 인해 엉뚱한 데이터가 삭제되는 레이스 컨디션을 정밀하게 교정함.
* **1. UI 변경 결함 제어:** 즐겨찾기 목록에서 특정 항목을 제거(Swipe Delete 등)했을 때 로컬 DB만 수정되고 화면 렌더링에 즉각 반영되지 않던 문제를 발견함. `removeSubject` 파이프라인 내부의 `sink` 클로저 연쇄 반응 끝단에 갱신 메서드를 강제 수행하도록 결합하여 해결함.
* **시각 자료 1:**
  <img width="302" height="630" alt="UI 업데이트 미반영 결함" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/d1cc8e2d-ea8b-46f0-9082-9d01a4c07b38.png" />

* **2. 비동기 응답 속도에 따른 인덱스 뒤틀림(삭제 꼬임) 규명:** `UserDefaults`의 원본 ID 순서(`names`)와 `Publishers.MergeMany` 기반의 네트워크 응답 도착 순서(`users`)가 비동기 레이스 컨디션에 의해 서로 다르게 배치되는 인과관계를 찾아냄. 이 상태에서 특정 행(Row)의 인덱스로 삭제를 시도하면 샌드박스 내부 배열과 화면 뷰의 매핑 기준이 달라 사용자가 선택하지 않은 다른 유저가 파괴되는 심각한 오작동이 유발됨.
* **시각 자료 2:**
  <img width="302" height="630" alt="배열 순서 뒤틀림 결함" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/936e92d5-850f-4025-a2ba-6f6d3969bd2c.png" />

* **3. 순차적 비동기 처리(`async/await`) 우회 및 동시성 컨텍스트 매핑:** [코드 4] 순서 보장이 불가능한 Combine 스트림 구조 대신, 반복문을 순차적으로 순회하며 호출 순서를 완벽히 제어하는 `for-in` 기반의 `async/await` 메서드로 전환함. 뷰 계층 역시 `.task` 모디파이어를 장착하여 동시성 수명 주기를 제어함.
* **4. 동시성 컨텍스트 스위칭 에러 해결:** `removeSubject` 스트림 수신부 내부에서 비동기 메서드를 직접 호출할 때 `Cannot pass function of type @concurrent (String) async -> Void to parameter expecting synchronous function type` 컴파일 에러가 발생함. 동기식 클로저 영역 내부에서 비동기 작업을 안전하게 격리·수행할 수 있도록 최신 동시성 도구인 `Task { ... }` 블록으로 래핑하여 인과 흐름을 완성함.
* **시각 자료 3:**
  <img width="302" height="630" alt="MergeMany 재호출에 따른 데이터 혼선" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/18c2b794-0067-4909-ad40-6ecfec11fb7a.png" />
* **시각 자료 4:**
  <img width="302" height="630" alt="최종 HotFix 적용 후 정상 작동" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-05-25-GitExplorer요약/d5738a64-21b8-4a5a-baf5-b2a598d3abb7.png" />
