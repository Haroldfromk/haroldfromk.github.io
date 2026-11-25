---
title: "[WWDC] 시리즈 안내"
writer: Harold
date: 2021-06-07 11:00:00 +0900
last_modified_at: 2026-11-25 06:30:00 +0900
categories: [WWDC, Guide]
tags: [Swift, WWDC]

toc: true
toc_sticky: true
published: true
---

> 이 글은 WWDC 시리즈가 어떻게 쓰이는지 Claude Code 로 정리한 안내 글이고, 실제로 쓴 날은 2026-11-25 다. 시리즈의 맨 앞에 오도록 날짜를 가장 이른 세션의 하루 전으로 두었다.
{: .prompt-info }

---

## 이 시리즈가 하는 일

WWDC 세션을 세션 하나에 글 하나로 정리한다. 핵심만 추린 요약이 아니라 세션 전체를 빠짐없이 옮긴다. 나중에 영상을 다시 틀지 않고 글만 읽어도 세션 내용을 다시 이해할 수 있는 것이 기준이다.

그래서 글 하나가 길다. 20분짜리 세션도 500줄을 넘는다. 발표자가 slide 한 장에서 한 말, demo 에서 누른 버튼, 화면에 잠깐 지나간 code 까지 순서대로 적기 때문이다. 훑어볼 글이 아니라 필요할 때 찾아와서 그 부분을 읽는 글로 썼다.

---

## 글을 만드는 방법

글은 Claude Code 가 쓰고 내가 읽고 고친다. 재료는 세 가지다.

- transcript: 세션 page 에 실린 문장별 대본이다. 번역해서 붙여 넣지 않고, 내용을 이해한 뒤 설명하는 글로 다시 쓴다
- 영상 화면: slide 와 demo 장면을 영상에서 잘라 넣는다. 그림마다 아래에 무엇을 보여 주는 장면인지 적는다
- code: 세션 page 의 snippet 과 화면에 보인 code 다

code 는 그대로 싣지 않는다. 세션의 snippet 은 조각이라 보조 type 이 빠져 있고, 녹화한 뒤에 API 가 바뀌어 지금의 SDK 와 맞지 않는 경우도 잦다. 그래서 빠진 부분을 채워 실제로 build 하거나 type check 를 통과시킨 것만 글에 싣는다. 세션의 code 와 달라진 곳은 그 code 바로 아래에 무엇을 왜 고쳤는지 적는다.

글 맨 위의 안내문에는 그 글의 code 를 어디까지 돌렸는지가 한 문장으로 적혀 있다. `swift build` 까지인지, type check 까지인지, `swift test` 로 실행했는지가 글마다 다르다.

---

## 다루는 세션과 순서

WWDC26 의 세션은 138개다. 전부 쓰지는 않고, iOS 개발에 얼마나 바로 쓰이는지로 나눠 가까운 것부터 쓴다.

| 순서 | 묶음 | 내용 |
| --- | --- | --- |
| 1 | iOS 개발 전반 | Swift, SwiftUI, UIKit, Xcode, SwiftData, Swift Testing, Instruments, Accessibility, design 원칙 |
| 2 | Concurrency 계보 | WWDC21 부터 WWDC25 까지의 Swift Concurrency 세션 여섯 개 |
| 3 | iOS 앱에서 쓰는 framework | App Intents, Foundation Models, HealthKit, Live Activities, In-App Purchase, Wallet, CarPlay 등 |
| 4 | 관심사와 거리가 먼 것 | Games, Metal, RealityKit 등 |

visionOS 전용, macOS 전용, Safari 와 WebKit, tvOS 세션과 Keynote 는 쓰지 않는다.

---

### Concurrency 계보를 따로 둔 이유

이전 연도의 세션은 통째로 정리하지 않는다. 다만 Swift 6 의 concurrency 는 WWDC26 의 세션만 읽어서는 왜 그렇게 됐는지 알기 어렵다. async/await 가 처음 나온 2021년부터 순서대로 읽어야 actor, `Sendable`, strict concurrency 검사가 어떤 문제를 풀려고 나왔는지 이어진다. 그래서 이 주제만 연도를 거슬러 올라가 여섯 세션을 골랐다.

- [[WWDC21] Meet async/await in Swift](https://haroldfromk.github.io/posts/WWDC21-10132/)
- [[WWDC21] Protect mutable state with Swift actors](https://haroldfromk.github.io/posts/WWDC21-10133/)
- [[WWDC21] Swift concurrency: Behind the scenes](https://haroldfromk.github.io/posts/WWDC21-10254/)
- [[WWDC22] Eliminate data races using Swift Concurrency](https://haroldfromk.github.io/posts/WWDC22-110351/)
- [[WWDC24] Migrate your app to Swift 6](https://haroldfromk.github.io/posts/WWDC24-10169/)
- [[WWDC25] Embracing Swift concurrency](https://haroldfromk.github.io/posts/WWDC25-268/)

이 여섯 편의 code 는 세션이 나온 해의 도구가 아니라 지금의 Xcode 27.0 (Swift 6.4) 으로 확인했다. 당시 화면의 error 문구와 지금 compiler 가 내는 문구가 다른 곳은 지금 것을 적었다.

---

## 글 하나의 구성

모든 글이 같은 틀을 따른다. 처음 보는 글이어도 어디에 무엇이 있는지 알 수 있다.

| 섹션 | 내용 |
| --- | --- |
| 세션 정보 | 세션 link, 길이, 공개일, 발표자, code 의 유무 |
| 한 줄 요약 | 세션이 말하는 것을 두세 문장으로 |
| 세션의 구성 | 세션이 진행되는 순서를 표로 |
| 본문 | 세션의 순서를 따라가는 여러 섹션. 처음 나오는 개념은 `무엇이란?` 소제목으로 먼저 설명한다 |
| 세션의 마무리 | 발표자가 끝에서 정리한 것과 권한 다음 세션 |
| 정리 | 내가 기억해 둘 것과 내 프로젝트에 가져갈 점 |
| 관련 글, 참고자료 | 이 시리즈의 다른 글과 Apple 문서 |

기술 용어는 번역하지 않고 영어 그대로 쓴다. code 에 처음 나온 API 는 그 code 아래에 소제목을 두고 설명하며 Apple 문서로 link 를 건다.

---

## 날짜와 분류

글의 날짜는 쓴 날이 아니라 세션이 공개된 날이다. WWDC26 의 글은 전부 2026-06-08 이고, WWDC21 의 글은 2021년 6월에 있다. 실제로 쓴 날은 글 맨 위의 안내문에 적혀 있다.

분류는 WWDC 아래에 연도별로 나뉜다. WWDC21, WWDC22, WWDC24, WWDC25, WWDC26 이 있다. 제목은 `[WWDC26] 세션의 원래 제목` 꼴이라 세션 이름으로 찾을 수 있다.
