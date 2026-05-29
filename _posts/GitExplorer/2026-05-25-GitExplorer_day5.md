---
title: GitExplorer day5
writer: Harold
date: 2026-05-25 08:06
categories: [Combine]
tags: [Combine]

toc: true
toc_sticky: true
published: false
---

## Day 5 아이디어 (추가 개선)

1. `ObservableObject` + `@Published` → `@Observable`로 전체 마이그레이션
   - `FavoriteViewModel` 의존성 주입 방식 변경 (ProfileView, FavoritesView 공유)
   - `FavoritesView`에서 `onAppear reloadData` 제거
2. `ProfileViewModel`에 로딩/성공/실패 상태 관리 추가
3. `FavoriteViewModel` → `scan`으로 리팩토링
4. `FavoritesView` → SwiftData 연결 (UserDefaults 제거)
5. 에러 스트림 `merge`로 통합해서 Alert 띄우는 구조 추가
6. 에러 스트림을 Subject로 외부에 전달하는 구조 개선

이렇게 정리를 했다.

일단은 봉인

---



