---
title: Final (Fin)
writer: Harold
date: 2024-07-03 01:00
categories: [캠프, TheLast]
tags: []
toc: true
toc_sticky: true
published: false
---

## 성능 개선

fetchData를 할때 한꺼번에 데이터를 불러들인다음에 UI에 반영하면서 로딩시간이 상당히 오래걸리는 문제가 있었다.
-> 실제로 유저피드백에서 나왔던 내용이다.

이전코드


