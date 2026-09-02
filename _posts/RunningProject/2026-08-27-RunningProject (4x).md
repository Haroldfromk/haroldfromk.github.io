---
title: RunWay 1.4 (1) 분석은 모르지만 AI랑 만들어본 Debrief
writer: Harold
date: 2026-08-27 21:00:00 +0900
categories: [RunWay]
tags: [SwiftData, Charts]

toc: true
toc_sticky: true
published: false
---

RunWay는 러닝 앱인데, 정작 나는 러닝 분석에 대한 지식이 거의 없다. 스플릿이 어떻게 흘러야 좋은 페이싱인지, 심박이 어떤 식으로 움직이면 문제인지 하나도 모르는 상태에서 시작했다. 그래서 이번 기능은 처음부터 끝까지 AI한테 물어가면서 아이디어를 받고, 그걸 코드로 옮기고, 실기기로 확인하면서 고쳐나간 과정을 그대로 정리했다.

목표는 러닝 앱 이름을 그대로 딴 "Debrief"(비행 후 브리핑) 탭 하나. 지금까지 쌓인 러닝 기록을 바탕으로 페이스 패턴, 심박 반응, GPWS 경고 패턴을 분석해서 보여준다. v1.4 준비 작업이라 아직 배포된 건 아니다.

---

## CoreML이 아니라 그냥 통계로 시작하기

원래는 iPhone 14 Pro Max의 Neural Engine을 살려서 CoreML로 뭔가 만들어볼까 했다. 근데 얘기를 나눠보니 온디바이스 학습은 결국 유저 한 명의 러닝 기록 수가 곧 학습 데이터 양이라서, 기록이 적은 초반엔 아예 학습이 안 되는 콜드스타트 문제가 있었다. 반대로 지금 하려는 분석들(스플릿이 일정한지, 심박이 오르는지, 경고가 언제 뜨는지)은 평균, 표준편차, 전후반 비교 같은 기본적인 통계만으로도 충분히 답이 나오는 문제였다.

그래서 방향을 바꿔서, CoreML은 나중에 "예상 완주 페이스 예측"처럼 진짜 예측이 필요한 기능이 생겼을 때, 그리고 기록이 충분히 쌓였을 때 다시 검토하기로 하고 이번엔 순수 통계로만 갔다.

RunWay는 이미 러닝 하나당 이런 데이터를 갖고 있었다.

```swift
// SwiftDataSplit.swift (기존 코드)
class SwiftDataSplit {
    var order: Int        // 몇 번째 km 구간인지
    var pace: Double       // 구간 평균 페이스
    var heartRate: Int     // 구간 평균 심박수
    var elevationGain: Double  // 이 구간에서 오른 고도
    // 생략
}
```

이 정도만 있어도 한 러닝 안에서 페이스/심박이 어떻게 흘렀는지는 충분히 볼 수 있었다.

---

## 스플릿 페이스 패턴: 일정함, 네거티브, 포지티브, 불규칙

가장 먼저 만든 건 "이번 러닝의 페이스가 어떤 모양이었는지"를 분류하는 거였다. 마라톤 코칭에서 실제로 쓰는 개념인 [네거티브 스플릿(negative split)](https://en.wikipedia.org/wiki/Negative_split){:target="_blank"}을 기준으로 잡았다. 후반부가 전반부보다 빠르면 네거티브(페이싱을 잘한 것), 느려지면 포지티브(후반에 무너진 것), 이도 저도 아니면 일정함이나 불규칙으로 나눴다.

```swift
// RunAnalysis.swift
static func classify(flight: SwiftDataFlight) -> SplitPatternClassification? {
    // 생략
    let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
    let cv = variance.squareRoot() / mean
    if cv >= erraticCVThreshold { return .erratic }  // 편차가 너무 크면 무조건 불규칙

    let mid = values.count / 2
    let delta = (secondAvg - firstAvg) / firstAvg
    if delta <= -halfCompareThreshold { return .negative }
    if delta >= halfCompareThreshold { return .positive }
    return .consistent
}
```

여기서 놓칠 뻔한 게 하나 있었다. RunWay의 Mission Flight는 목표를 페이스로도, 심박수로도 잡을 수 있는데, 처음엔 무조건 페이스로만 판단하게 만들었다. 근데 심박을 목표로 뛴 러닝은 심박대를 유지하려고 일부러 페이스를 조절하는 거라, 페이스가 들쭉날쭉한 게 오히려 정상이다. 그걸 "불규칙"이라고 판정하면 완전히 반대로 해석하는 셈이었다.

그래서 러닝이 어떤 목표로 뛰어졌는지를 보고 기준 자체를 바꾸게 했다.

```swift
// RunAnalysis.swift
var splitPatternBasis: ModeATarget {
    mode == "modeA" && missionTarget == ModeATarget.heartRate.rawValue ? .heartRate : .pace
}
```

심박 목표 러닝은 페이스 대신 심박 값으로 같은 계산을 돌린다. 대신 "네거티브 스플릿"이라는 표현 자체가 페이스 용어라 심박에는 안 맞아서, 라벨은 "후반에 심박 안정" / "후반에 심박 상승"처럼 따로 썼다.

이렇게 목표별로 기준이 갈리다 보니, 여러 러닝을 한 번에 모아 보는 화면에서 페이스 목표 러닝이랑 심박 목표 러닝을 같은 집계에 섞으면 숫자가 뒤죽박죽이 됐다. 결국 화면에 PACE / HEART RATE 토글을 두고 기준별로 따로 보게 만들었다.

---

## 페이스는 그대로인데 심박만 오른다면

두 번째로 만든 건 카디악 드리프트다. 같은 페이스를 유지하는데 심박만 계속 오르는 걸 보는 지표인데, 나는 이 개념 자체를 몰라서 AI한테 물어보고서야 알았다. 코칭 쪽에서 실제로 쓰는 [Joe Friel의 5%/10% 기준](https://www.trainingpeaks.com/coach-blog/aerobic-endurance-and-decoupling/){:target="_blank"}을 그대로 가져다 썼다. 드리프트가 5% 미만이면 안정적, 10% 이상이면 뚜렷한 저하로 본다.

```swift
// RunAnalysis.swift
static func classify(splits: [SwiftDataSplit]) -> CardiacDriftClassification? {
    // 생략
    let ratios = validSplits.map { Double($0.heartRate) / $0.pace }
    let drift = (secondAvg - firstAvg) / firstAvg
    if drift >= highThreshold { return .high }      // 10% 이상
    if drift >= lowThreshold { return .moderate }    // 5~10%
    return .low
}
```

여기도 실기기로 확인하다가 걸린 게 있었다. 워치 없이(또는 워치 미착용으로) 뛴 러닝만 있으면 심박 데이터 자체가 없어서 계산이 하나도 안 되는데, 화면에는 그냥 통계 타일이 전부 0으로 뜨기만 했다. 왜 비어있는지 이유를 알 수가 없는 상태였다. 그래서 "분석 대상 러닝은 있는데 심박 기록만 없는" 경우를 따로 구분해서, "워치로 심박을 기록한 러닝이 아직 없어요"라는 안내 문구가 뜨도록 고쳤다.

---

## 장기 추세와 페이스가 느려지기 시작하는 지점

한 러닝 안이 아니라 여러 러닝에 걸친 경향도 두 개 더 만들었다.

장기 추세는 분석 대상 러닝을 날짜순으로 줄 세워서 전반부/후반부 평균 페이스를 비교하는 것뿐이다. 최소 4개는 쌓여야 의미가 있다고 보고 그 미만이면 카드 자체를 안 띄운다.

페이스 저하 시작점은 좀 더 재밌는 아이디어였다. "보통 몇 km 지점부터 페이스가 느려지는 경향이 있다"는 걸 실제로 계산해보자는 이야기가 나와서, 각 러닝에서 페이스가 전체 평균보다 5% 이상 느려지고 그 이후로도 계속 느린(한 번 튄 게 아니라 진짜 저하가 시작된) 첫 지점을 찾고, 그 위치를 여러 러닝에 걸쳐 평균 내는 방식으로 만들었다.

```swift
// RunAnalysis.swift
static func onsetOrder(splits: [SwiftDataSplit]) -> Int? {
    // 생략
    for i in 1..<paces.count {
        guard paces[i] > mean * (1 + onsetThreshold) else { continue }
        let remainingAvg = remaining.reduce(0, +) / Double(remaining.count)
        if remainingAvg > mean * (1 + onsetThreshold / 2) {
            return sorted[i].order  // 이 지점부터 진짜 저하 시작
        }
    }
    return nil
}
```

이걸 저하 시작점을 찾은 러닝들의 평균 위치(전체 거리 대비 비율)로 집계해서, "보통 6km 지점부터 페이스가 느려지는 경향이 있어요" 같은 문장으로 보여준다.

---

## GPWS 경고가 뜨는 타이밍을 한눈에

GPWS(SINK RATE/OVERSPEED) 경고 기록도 쌓여있길래, 이 경고들이 러닝의 어느 지점에서 자주 뜨는지 히스토그램으로 만들었다. 각 경고가 발생한 시점을 그 러닝 전체 거리 대비 몇 % 지점이었는지로 정규화해서 10% 단위로 묶었다.

이건 RunWay 전체에서 처음으로 [Swift Charts](https://developer.apple.com/documentation/charts){:target="_blank"}를 쓴 화면이다. 지금까지 있던 다른 차트들(홈 화면의 주간 막대, 캘린더 히트맵)은 전부 `LazyVGrid`나 `HStack`으로 직접 그린 건데, 두 종류(SINK RATE/OVERSPEED)를 겹쳐서 10개 구간에 막대로 보여주는 건 직접 그리는 것보다 Swift Charts로 만드는 게 훨씬 간단했다.

```swift
// DebriefView.swift
Chart(bars) { bar in
    BarMark(
        x: .value("Progress", bar.bucketLabel),
        y: .value("Count", bar.count)
    )
    .foregroundStyle(by: .value("Type", bar.state))
}
.chartForegroundStyleScale([
    "SINK RATE": Color.rwRed,
    "OVERSPEED": Color.rwAmber
])
```

실제로 확인해보니 SINK RATE가 러닝 후반부(70~90% 지점)에 몰려있는 게 한눈에 보였다. 처음부터 오버페이스했다가 후반에 못 버티는 패턴이라는 걸 숫자로만 볼 때보다 훨씬 빨리 알아챌 수 있었다.

---

## `?` 버튼으로 실제 화면처럼 설명하기

카드를 다 만들고 나니, 정작 각 숫자가 뭘 뜻하는지 설명이 하나도 없다는 문제가 남았다. 처음엔 그냥 텍스트로 "이 카드는 이런 뜻입니다"를 나열했는데, 다시 보니 실감이 안 났다. 그래서 방향을 바꿔서, 헤더에 `?` 버튼을 두고 누르면 실제 화면과 똑같이 생긴 예시 카드(가짜 데이터)를 그대로 보여주면서, 각 카드에 번호를 매기고 아래에 번호별 설명을 붙이는 식으로 만들었다.

```swift
// DebriefView.swift
private func numberedMock<Content: View>(_ number: Int, @ViewBuilder content: () -> Content) -> some View {
    content()
        .overlay(alignment: .topLeading) {
            numberBadge(number)
                .offset(x: -8, y: -8)
        }
}
```

만들면서 실수도 하나 발견했다. 예시 카드에 박아넣은 문장 몇 개가 그냥 한글 리터럴이었다. 실제 카드는 `String(localized:)`로 미리 번역된 값을 만들어서 쓰는데, 예시 카드는 그 단계를 빼먹고 완성된 한국어 문장을 그대로 박아넣은 거라, 영어/일본어 기기에서 봐도 그 부분만 한글로 나오는 상태였다. 통계 타일 라벨도 같은 이유로 걸려있었다. `String(localized:)`로 한 번씩 감싸서 실제 카드와 같은 방식으로 맞췄다.

온보딩에도 Debrief 소개 페이지를 하나 추가해서, 처음 앱을 켠 사람도 "3km 이상 러닝이 몇 번 쌓이면 분석이 나온다"는 걸 미리 알 수 있게 했다.

---

## 정리

| 항목 | 기준 | 최소 조건 |
|---|---|---|
| 스플릿 페이스 패턴 | 변동계수 + 전후반 비교, 목표(페이스/심박)에 따라 기준 전환 | 3km 이상, 유효 스플릿 3개 |
| 카디악 드리프트 | (심박/페이스) 비율의 전후반 변화율 | 심박 기록된 3km 이상 러닝 |
| 장기 추세 | 날짜순 전후반 평균 페이스 비교 | 분석 대상 러닝 4개 이상 |
| 페이스 저하 시작점 | 평균보다 5% 이상, 지속적으로 느려지는 첫 지점 | 저하 시작점 발견 3개 이상 |
| GPWS 경고 타이밍 | 발생 시점을 거리 대비 %로 정규화, 10% 단위 집계 | 없음 (0이면 빈 그래프) |

전부 CoreML 없이 통계만으로 만들었고, 실기기로 확인하면서 목표별 기준 전환, 심박 데이터 없음 안내, 예시 카드 로컬라이즈 버그까지 하나씩 잡아나갔다. CoreML은 예상 완주 페이스 예측처럼 통계로는 안 되는 진짜 예측 기능이 필요해지고, 기록도 충분히 쌓였을 때 다시 검토하기로 했다.
