---
title: (Deep Dive) Diffable DataSource
writer: Harold
date: 2024-05-02 13:00
#last_modified_at: 2024-03-17 21:11:00
published: false
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

기존 Datasource를 사용하지 않아도 된다.

SnapShot 개념을 사용하여 SnapShot이 변경되면 테이블뷰를 업데이트 해준다.

SnapShot을 Apply 해주면 된다.

1. enum을 사용하여 섹션 분리

2. enum을 하나더 사용하여 각 섹션에 들어갈 아이템 분리

이때 둘다 Hashable 채택 -> Model에도 채택 해줘야한다.

3. datasource 만들기

`var dataSource: UITablieViewDiffableDataSource<Section, SectionItem>?`