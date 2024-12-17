---
title: (Deep Dive) Compositional Layout
writer: Harold
date: 2024-04-21 13:00
#last_modified_at: 2024-03-17 21:11:00
published: false
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

사실 TableView, CollectionView는 Swift를 다룬다면, 불가분의 관계라고 생각을 한다.

이번에 프로젝트를 앞두고 이부분을 정리를 좀 해두려고 한다.

Compositional Layout이 좀 빡세다고 하니, 미리 좀 다뤄보려고 한다.

## 1. 기본 구성

**iOS 13 이상에서 지원**하며, 다음과 같은 구성을 가진다.

![](https://docs-assets.developer.apple.com/published/1b0de7d0bb/rendered2x-1691073705.png)

1개의 Section 안에 Group이 존재하고, 그 Group안에 한 화면이 들어가는 item들이 있다.

> 즉 Group엔 여러 화면이 담기게된다.
>> 여러 item이 존재한다.

- 그래서 구성할때 section, group, item의 레이아웃을 각각 설정하여 구현하게 된다.

## 2. 핵심 Code

```swift
let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3),
heightDimension: .fractionalHeight(0.75))
let item = NSCollectionLayoutItem(layoutSize: size)
let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
subitem: item, count: 3)
let section = NSCollectionLayoutSection(group: group)
let layout = NSCollectionViewCompositionalLayout(section: section)
```

핵심 코드를 보게되면 사이즈는 item으로, item은 group으로 하나 씩 계속 ➘ 방향으로 이어지는 걸 알 수 있다.

## 3. Size 설정

Item의 사이즈를 설정하는 방법은 3가지가 있다.
1. .absolute : 절대적인 값 즉, 고정크기
2. .estimated : Runtime에 변경, 예상 되는 수치를 적어준다.
3. .fractional : 비율

사이즈는 widthDimension / heightDimension으로 나뉘어진다.


## 참고자료

https://www.youtube.com/watch?v=Y2bz-uft9Zw

https://velog.io/@sopt_official/iOS1

https://velog.io/@j_aion/UIKit-UICollectionView-Compositional-Layout-Sections

https://ios-development.tistory.com/945

글작성은 잠시 보류.