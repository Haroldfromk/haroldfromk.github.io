---
title: RunWay 1.3.2 GPWS 경고가 지도에 스무 개씩 찍히던 이유
writer: Harold
date: 2026-09-05 09:00:00 +0900
categories: [RunWay]
tags: [GPS, AI]

toc: true
toc_sticky: true
published: true
---

1.3.1을 배포하고 나서 지인에게 피드백을 받았다. 마커가 너무 많이 나왔다는 부분이다. 그리고 SINK RATE가 뜬 뒤에 속도를 다시 올려도 경고가 풀리기까지 한참 걸렸다고 한다. (실제로 이건 IIR 필터 계수 값을 조정하면서 나도 느꼈던 부분이었다)

이번 글은 이 두 가지를 AI와 대화하면서 좁혀나간 과정을 그대로 옮긴 것이다. 결론부터 말하면 **처음에 세운 가설은 거의 다 틀렸고, 진짜 원인은 마지막에 나왔다.** 틀린 과정을 지우면 남는 게 별로 없어서 순서대로 적는다.

---

## 처음 나온 진단

증상을 설명하니 원인을 세 층위로 나눠서 정리해줬다.

1. **경고가 켜지는 기준과 꺼지는 기준이 똑같다.** `calculateGPWSStatus()`는 목표 페이스에서 얼마나 벗어났는지만 보고 판정한다. 그 선 하나를 두고 페이스가 왔다갔다 하면 경고도 같이 켜졌다 꺼졌다 한다.
2. **페이스를 부드럽게 만드는 계수가 너무 낮다.** 화면에 보이는 페이스는 GPS 속도를 그대로 쓰지 않는다. 이전 값에 새 값을 조금씩만 섞어서 숫자가 튀지 않게 만드는데, 지금은 그 섞는 비율(α)이 0.15다. 게다가 이 과정을 두 번 겹쳐서 쓴다. 그래서 실제로 속도를 올려도 **화면 숫자가 그 변화를 대부분 따라잡는 데 25초쯤 걸린다.**
3. **기록을 거르는 조건이 없다.** 경고가 뜨는 순간 바로 저장한다.

그리고 근본 조건 하나를 짚어줬는데 이게 제일 뼈아팠다. 목표 페이스 5분 45초에 허용 오차를 10초로 뒀으니 허용 범위가 5분 35초에서 5분 55초다. 이걸 속도로 바꾸면 2.817에서 2.985m/s, **폭이 0.168m/s밖에 안 된다.** GPS가 알려주는 속도값 자체가 그 정도는 흔들린다.

게다가 그날 평균 페이스가 5분 36초였다. **허용 범위의 빠른 쪽 끝에 딱 붙어서 뛴 셈이다.** 경고가 자주 뜰 수밖에 없는 조건이었다.

---

## 시뮬레이터를 먼저 만들었다

계수를 바꾸려면 실기기에서 여러 번 뛰어야 한다. 한 번 뛰는 데 40분씩 걸리는데 계수 하나 확인하자고 그걸 반복하는 건 무리였다.

그래서 `RunningCenter`의 알고리즘을 그대로 옮긴 시뮬레이터를 먼저 만들었다. 실제 km별 페이스(6분 30초, 5분 26초, 5분 31초)를 뼈대로 삼고, 거기에 GPS 속도가 흔들리는 정도를 얹어 1초 간격으로 재현하는 방식이다.

그때 돌려본 걸 여기에 다시 옮겨왔다. 위에서 안을 하나씩 켜보면 세 숫자가 어떻게 같이 움직이는지 볼 수 있다.

<iframe
  src="/assets/demo/gpws_proposal_tuner.html"
  width="100%"
  height="730px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

그래프에서 먼저 보이는 게 있다. **허용 범위(초록 띠)가 저렇게 얇다.** 화면에 보이는 페이스가 그 위아래를 계속 넘나들고, 그래서 경고가 켜진 구간(붉은 음영)이 러닝 대부분을 덮는다. 계수를 어떻게 손보든 이 조건 자체가 안 바뀌면 경고는 계속 뜬다는 게 여기서 이미 보인다.

(아래 숫자들은 흔들림을 얼마로 잡느냐에 따라 같이 움직인다. 이 글 뒤쪽 "시뮬레이터 숫자에 대해"에 그 얘기를 따로 적어뒀다.)

**여기서 첫 번째 제안이 바로 깨졌다.**

화면에 보여줄 페이스와 경고를 판정할 페이스를 따로 두고, 판정용은 더 빠르게 반응하게 만들자는 안이었다. 돌려보니 경고가 풀리는 시간은 41초에서 20초로 줄었는데 **경고가 켜졌다 꺼졌다 한 횟수가 97번에서 183번으로 두 배가 됐다.** 빠르게 반응한다는 건 GPS가 흔들리는 것까지 그대로 따라간다는 뜻이니 당연한 결과였다. 실기기에서 이걸 알았으면 몇 번을 더 뛰어야 했을 거다.

켜지는 기준과 꺼지는 기준을 다르게 두는 방법도 마찬가지였다. 경고가 8초 이상 유지돼야 기록하는 조건과 같이 쓰니 기록이 17건에서 26건으로 **오히려 늘었다.** 꺼지는 기준을 까다롭게 하면 경고가 더 오래 켜져 있게 되고, 그러면 8초를 채우는 경고가 늘어난다. 두 장치가 노리는 게 겹쳐서 서로를 깎고 있었다.

---

## 500미터는 러닝에서 너무 크다

다음으로 나온 안은 같은 종류의 경고를 500m 안에서는 한 번만 기록하자는 거였다. 29건이 13건으로 줄어든다는 숫자까지 나왔다.

그런데 5분 36초 페이스면 500m는 **2분 48초다.** 그 안에 일어난 다른 이탈이 통째로 묻힌다는 뜻이다. 이건 좀 아닌 것 같아서 되물었더니, 다시 재보고 이렇게 나왔다.

| 8초 이상 유지 + 몇 m 안에서 묶기 | 기록 |
|---|---|
| 안 묶음 | 24건 |
| 50~150m | 24건 |
| 200m | 23건 |
| 300m | 19건 |
| 500m | 13건 |

150m 이하는 **아무 효과가 없었다.** 8초 이상 유지된 것만 남기다 보니 기록끼리 이미 그만큼 떨어져 있었기 때문이다. 그리고 200m를 넘어가면서 줄어드는 건, 8초 넘게 이어진 **진짜 이탈을 지우기 시작한다는 뜻**이었다. 500m로 13건을 만든 건 실제 사건 11건을 없앤 것이다.

거리 병합은 여기서 버렸다.

---

## 그런데 20초면 이미 막았어야 하는 거 아닌가

기존 코드에는 이미 쿨다운이 있었다. 같은 경고가 20초 안에 다시 뜨면 기록하지 않는 조건이다. 그래서 물었다. **20초라고 해뒀는데 왜 스무 개나 찍힌 거지?**

이 질문에서 진짜 원인이 나왔다.

```swift
// RunViewModel.swift (기존)
var lastGPWSClearedAt: [String: Date] = [:]
```

**쿨다운이 경고 종류별로 나뉘어 있었다.** SINK RATE가 꺼진 시각과 OVERSPEED가 꺼진 시각을 각각 따로 기억하고, 새 경고가 뜨면 자기 종류의 시각만 본다.

```swift
// PFDView.swift (기존)
func saveAlert() {
    let type = runViewModel.flightData.gpwsStatus?.rawValue ?? "normal"
    if let clearedAt = runViewModel.lastGPWSClearedAt[type],   // 자기 종류만 확인
       Date.now.timeIntervalSince(clearedAt) < RunViewModel.alertRecordCooldown {
        return
    }
    // 생략
}
```

그러면 이렇게 된다.

| 시각 | 일어난 일 | 확인하는 값 | 결과 |
|---|---|---|---|
| 0초 | SINK RATE 발생 | SINK 기록 없음 | 저장 |
| 5초 | 정상 복귀 | SINK 해제 시각 = 5초 | |
| 6초 | OVERSPEED 발생 | OVER 기록 없음 | **저장** |
| 12초 | 정상 복귀 | OVER 해제 시각 = 12초 | |
| 30초 | SINK RATE 발생 | SINK 해제 시각 5초 → 25초 경과 | **저장** |
| 40초 | OVERSPEED 발생 | OVER 해제 시각 12초 → 28초 경과 | **저장** |

40초 동안 네 건이 저장됐는데 20초 조건에 **한 번도 걸리지 않았다.** 두 경고가 번갈아 뜨면 각자 자기 시계만 보기 때문에 둘 다 20초를 쉽게 넘긴다.

실제 기록을 확인해보니 SINK 14건, OVER 15건으로 거의 반반이었다. 번갈아 떴다는 증거다.

**허용 범위 끝에 붙어 달린 게 이 구멍을 연 조건이었다.** 확실히 느리게 뛰면 SINK RATE만 계속 뜨고 꺼지니까 자기 시각이 계속 갱신되어 20초가 제대로 걸린다. 그동안 문제가 없었던 게 이 때문이다.

토글로 켜고 꺼보면서 어떻게 갈리는지 확인할 수 있게 만들어봤다.

<iframe
  src="/assets/demo/gpws_cooldown_scope_simulator.html"
  width="100%"
  height="580px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

종류별로 두면 29건이 기록되고 쿨다운이 실제로 막은 건 20번뿐이다. 통합하면 5건으로 줄고 쿨다운이 44번 동작한다. 같은 20초인데 재는 방식만 다르다.

---

## 원래 의도가 통합이었다

여기서 확실해진 게 있다. **이건 설계를 바꾸는 게 아니라 버그를 고치는 것이다.**

내가 이 쿨다운을 넣을 때 의도한 건 "경고 하나가 끝나고 20초 안에 또 뜨면 같은 사건으로 본다"였다. 종류를 나눌 생각은 없었다. 그런데 구현이 `[String: Date]` 딕셔너리가 되면서 의도와 코드가 조용히 갈라졌다.

그래서 상수를 60초로 키우자는 얘기도 나왔었는데 그것도 접었다. **20초는 통합 동작을 전제로 고른 값이다.** 지금까지 그렇게 동작한 적이 한 번도 없었을 뿐이지, 그 값이 나쁘다는 근거는 없다. 버그를 고치면 처음으로 의도대로 돌아가게 되니 그 상태로 먼저 뛰어보는 게 맞다.

---

## 고친 코드

```swift
// RunViewModel.swift / WatchViewModel.swift
- var lastGPWSClearedAt: [String: Date] = [:]
+ var lastGPWSClearedAt: Date?
```

```swift
// PFDView.swift / WatchPFDView.swift
- runViewModel.lastGPWSClearedAt[previous.rawValue] = .now
+ runViewModel.lastGPWSClearedAt = .now

- if let clearedAt = runViewModel.lastGPWSClearedAt[type],
+ if let clearedAt = runViewModel.lastGPWSClearedAt,
       Date.now.timeIntervalSince(clearedAt) < RunViewModel.alertRecordCooldown {
      return
  }
```

`resetState()`에서 `[:]`로 비우던 것도 `nil`로 바꿨다.

페이스를 부드럽게 만드는 비율은 0.15에서 0.18로 올렸다. 새 값을 조금 더 많이 반영한다는 뜻이고, 속도 변화를 따라잡는 시간이 25초쯤에서 21초쯤으로 줄어든다. 0.20을 넘기면 이번엔 화면 숫자가 눈에 띄게 흔들려서 그 앞에서 멈췄다.

```swift
// RunningCenter.swift
- smoothingSpeedFirst  = 0.85 * smoothingSpeedFirst  + 0.15 * compensatedSpeed
- smoothingSpeedSecond = 0.85 * smoothingSpeedSecond + 0.15 * smoothingSpeedFirst
+ smoothingSpeedFirst  = 0.82 * smoothingSpeedFirst  + 0.18 * compensatedSpeed
+ smoothingSpeedSecond = 0.82 * smoothingSpeedSecond + 0.18 * smoothingSpeedFirst
```

8초 유지 조건도, 거리로 묶는 것도, 켜지고 꺼지는 기준을 다르게 두는 것도 넣지 않았다. 전부 검토했다가 뺐다. **타입 하나와 숫자 하나가 이번 변경의 전부다.**

---

## 화면 경고는 그대로 뜬다

한 가지 짚어둘 것이 있다. 이 수정은 **저장만 막는다.**

`triggerGPWS()`는 `switch` 바깥에 있어서 상태가 바뀔 때마다 항상 실행된다. Watch의 경고 오버레이도 `gpwsStatus`를 직접 읽기 때문에 저장 로직과 무관하다.

| | 쿨다운 영향 |
|---|---|
| 화면 플래시, 경고음 | 없음 |
| Watch 경고 오버레이, 반복 햅틱 | 없음 |
| Dynamic Island 갱신 | 없음 |
| Alerts 저장, 지도 마커 | 여기만 막힘 |

의도한 대로다. 실시간 코칭은 매번 알려주고, 기록만 요약하는 것이다. 페이스가 벗어났으면 그 순간 알려주는 게 맞고, 나중에 지도에서 볼 때 같은 사건이 스무 번 찍힐 필요는 없다.

다만 페이스 반영 비율을 올리면 경고가 켜졌다 꺼졌다 하는 횟수 자체는 늘어난다. 모델상 97번에서 117번이다. 기록에는 안 남지만 손목의 진동은 그만큼 더 울린다는 뜻이라, 실제로 뛰어보고 거슬리면 **경고가 몇 초는 유지돼야 화면과 진동이 따라가게** 만드는 장치를 따로 넣을 생각이다.

---

## 시뮬레이터 숫자에 대해

이 글에 나오는 숫자는 대부분 **앱을 측정한 값이 아니라 모델의 출력이다.**

km별 페이스는 실제 값이지만, **초당 속도가 얼마나 흔들리는지는 내가 정한 값이다.** `SwiftDataCoordinate`에 시각을 저장하지 않아서 실제 초당 속도를 되살릴 수 없었기 때문이다. 그래서 29건이 5건이 되는지, 15건이 11건이 되는지는 그 값을 얼마로 잡느냐에 따라 달라진다. 흔들림을 0.35에서 0.20으로 낮춰 보면 29건과 5건이 15건과 11건으로 좁혀진다.

반면 다음은 시뮬레이션과 무관하게 코드에서 확인한 사실이다.

- 쿨다운이 경고 종류별로 나뉘어 있다는 것
- 그래서 경고가 번갈아 뜨면 구조적으로 발동하지 않는다는 것
- 허용 범위의 폭이 0.168m/s라는 것
- 비율을 바꿨을 때 반응 속도가 얼마나 달라지는지

**모델이 답을 준 게 아니라 가설이 틀렸다는 걸 싸게 알려줬다.** 방향을 좁히는 데 썼고, 확정은 실기기에서 해야 한다.

---

## 건강 앱에 같은 러닝이 두 번 저장되고 있었다

1.3.2를 실기기에서 확인하러 나가면서, 겸사겸사 다른 것도 하나 보기로 했다. 워치 전원을 끄고 아이폰만 들고 뛰어보는 것이다. 앱 코드에는 아이폰이 Apple Health에 워크아웃을 저장하는 호출이 없어서, 워치가 없으면 건강 앱에 아무것도 안 남을 거라고 생각했다.

**남았다.** 그것도 강제 종료한 것까지 남았다.

거기서 의심이 하나 생겼다. 아이폰이 저장한다면, 워치를 같이 차고 뛴 날은 두 번 저장된 것 아닌가.

---

### 같은 시각에 시작한 러닝이 두 개

건강 앱에서 예전 기록을 열어보니 그대로였다.

| | 기록 A | 기록 B |
|---|---|---|
| 시작 | 20:30:36 | 20:30:36 |
| 종료 | 21:42:48 | 21:42:44 |
| 소요 | 1h 12m 12.09s | 1h 12m 7.92s |
| Source | RunWay | RunWay |
| Device | iPhone | Apple Watch |

시작 시각이 초 단위까지 같고, 종료만 4초 차이다. 한 번 뛴 러닝이 두 건으로 들어가 있다. 이런 쌍이 여러 날에 걸쳐 있었다.

그림으로 보면 이렇다. 저장하는 쪽이 둘이라 기록도 둘이 된다.

<svg viewBox="0 0 420 436" xmlns="http://www.w3.org/2000/svg" role="img"
     aria-label="건강 앱 중복 저장 수정 전후 비교" style="width:100%;height:auto;color:inherit">
  <defs>
    <marker id="ar" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="currentColor" opacity=".4"/>
    </marker>
    <marker id="arR" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="#e05c4f"/>
    </marker>
    <marker id="arG" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="5" markerHeight="5" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="#2fa37c"/>
    </marker>
  </defs>

  <text x="0" y="12" font-size="11.5" fill="currentColor" opacity=".55" font-family="monospace">수정 전</text>

  <rect x="0" y="22" width="198" height="56" rx="8" fill="none" stroke="#e05c4f" stroke-width="1.2"/>
  <text x="14" y="42" font-size="11" fill="currentColor" opacity=".55" font-family="monospace">iPhone</text>
  <text x="14" y="62" font-size="13" fill="#e05c4f" font-weight="600">시스템이 builder 마감</text>

  <rect x="222" y="22" width="198" height="56" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".3"/>
  <text x="236" y="42" font-size="11" fill="currentColor" opacity=".55" font-family="monospace">Apple Watch</text>
  <text x="236" y="62" font-size="13" fill="currentColor" font-weight="600">finishWorkout()</text>

  <line x1="99" y1="78" x2="99" y2="104" stroke="#e05c4f" stroke-width="1.2" marker-end="url(#arR)"/>
  <line x1="321" y1="78" x2="321" y2="104" stroke="currentColor" stroke-width="1.2" opacity=".4" marker-end="url(#ar)"/>

  <rect x="0" y="110" width="420" height="84" rx="8" fill="none" stroke="currentColor" stroke-width="1" opacity=".25" stroke-dasharray="4 3"/>
  <text x="14" y="128" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">Apple Health · 운동 목록</text>
  <rect x="14" y="136" width="392" height="22" rx="5" fill="none" stroke="#e05c4f" stroke-width="1"/>
  <text x="26" y="151" font-size="11.5" fill="#e05c4f" font-family="monospace">Running · Device iPhone · 심박 없음</text>
  <rect x="14" y="164" width="392" height="22" rx="5" fill="none" stroke="#e05c4f" stroke-width="1"/>
  <text x="26" y="179" font-size="11.5" fill="#e05c4f" font-family="monospace">Running · Device Apple Watch · 심박 있음</text>

  <line x1="0" y1="216" x2="420" y2="216" stroke="currentColor" stroke-width="1" opacity=".18"/>

  <text x="0" y="242" font-size="11.5" fill="currentColor" opacity=".55" font-family="monospace">수정 후</text>

  <rect x="0" y="252" width="198" height="56" rx="8" fill="none" stroke="currentColor" stroke-width="1.2" opacity=".22" stroke-dasharray="4 3"/>
  <text x="14" y="272" font-size="11" fill="currentColor" opacity=".4" font-family="monospace">iPhone</text>
  <text x="14" y="292" font-size="13" fill="currentColor" opacity=".45" font-weight="600">discardWorkout()</text>
  <line x1="168" y1="266" x2="182" y2="280" stroke="currentColor" stroke-width="1.6" opacity=".4"/>
  <line x1="182" y1="266" x2="168" y2="280" stroke="currentColor" stroke-width="1.6" opacity=".4"/>

  <rect x="222" y="252" width="198" height="56" rx="8" fill="none" stroke="#2fa37c" stroke-width="1.4"/>
  <text x="236" y="272" font-size="11" fill="currentColor" opacity=".55" font-family="monospace">Apple Watch</text>
  <text x="236" y="292" font-size="13" fill="#2fa37c" font-weight="600">finishWorkout()</text>

  <line x1="321" y1="308" x2="321" y2="334" stroke="#2fa37c" stroke-width="1.4" marker-end="url(#arG)"/>

  <rect x="0" y="340" width="420" height="62" rx="8" fill="none" stroke="currentColor" stroke-width="1" opacity=".25" stroke-dasharray="4 3"/>
  <text x="14" y="358" font-size="10.5" fill="currentColor" opacity=".5" font-family="monospace">Apple Health · 운동 목록</text>
  <rect x="14" y="366" width="392" height="22" rx="5" fill="none" stroke="#2fa37c" stroke-width="1"/>
  <text x="26" y="381" font-size="11.5" fill="#2fa37c" font-family="monospace">Running · Device Apple Watch · 심박 있음</text>

  <text x="0" y="424" font-size="11.5" fill="currentColor" opacity=".6">저장하는 쪽을 센서 가진 기기 하나로 고정한다</text>
</svg>


주간 합계에는 두 배로 반영되지 않았다. 겹치는 시간대의 운동을 건강 앱이 합산에서 걸러주는 것으로 보인다.(추정) 그래서 여태 몰랐다. **건강 앱의 운동 목록을 직접 열어보기 전까지는 드러나지 않는 종류의 문제였다.**

---

### 아이폰은 저장하지 않는다고 적어뒀었다

코드에는 이렇게 적혀 있었다.

```swift
// HealthKitService+iOS.swift
// 앱은 항상 러닝의 origin이라 iPhone이 이 세션을 받을 일이 없다. 등록하면 오히려
// iPhone의 startOrigin이 .remote로 덮어써져서(saveRunningData()가 막힘), 심박수/케이던스는
// 이미 sendMessage로 따로 오고 있고 Apple Health 저장도 Watch의 builder로만 이뤄지는 걸
// 확인해서 호출을 끊었다.
```

"Apple Health 저장도 Watch의 builder로만 이뤄지는 걸 확인해서"라고 써놨다. 이 전제가 틀렸다.

아이폰 쪽에는 `finishWorkout()`도 `store.save()`도 없다. 그건 맞다. 그런데 저장은 된다. 아이폰은 러닝을 시작할 때 자기 세션을 만들고 거기에 빌더를 붙여 수집을 시작한다.

```swift
// HealthKitService.swift
session = try HKWorkoutSession(healthStore: store, configuration: workoutConfiguration)
builder = session?.associatedWorkoutBuilder()
// 생략
builder?.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: workoutConfiguration)
try await builder?.beginCollection(at: startDate)
```

그리고 종료할 때는 세션만 끝내고 빌더는 손대지 않는다. **마무리를 안 해도 시스템이 그때까지 모인 데이터로 워크아웃을 마감해 저장한다.** 그래서 앱이 저장을 지시한 적이 없는데도 Source가 RunWay로 찍힌다.

워치는 워치대로 `finishWatchWorkout()`에서 `endCollection()`과 `finishWorkout()`을 부른다. 저장하는 쪽이 둘이니 기록도 둘이다.

---

### 미러링일 때는 아이폰 것을 버린다

`HKWorkoutBuilder`에는 모은 데이터를 저장하지 않고 마감하는 `discardWorkout()`이 있다. 미러링일 때만 이걸 부르면 된다.

```swift
// before (HealthKitService+iOS.swift)
if toState == .stopped {
    session?.end()
    let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin, startOrigin: nil)
    updateAndSendState(event)
}
```

```swift
// after
if toState == .stopped {
    // 미러링 중이면 Apple Health 저장은 Watch의 builder가 한다. iPhone의 builder를
    // 그대로 두면 시스템이 이것까지 마감해 저장해서, 같은 러닝이 건강 앱에 두 번 남는다.
    if runningMode == .mirrored {
        builder?.discardWorkout()
    }
    session?.end()
    let event = SessionStateEvent(state: state, runningMode: runningMode, stopOrigin: stopOrigin, startOrigin: nil)
    updateAndSendState(event)
}
```

무조건 버리지 않고 `runningMode == .mirrored`를 붙인 이유가 있다. **워치를 안 차고 아이폰만으로 뛰면 아이폰이 유일한 저장 주체다.** 조건 없이 버리면 그 경우 건강 앱에 아무것도 남지 않는다. 오늘 워치를 끄고 뛴 기록이 남은 게 바로 그 경우였다.

세션이 정상 흐름을 타지 않고 정리되는 경로에도 같은 처리를 넣었다.

```swift
// before (resetWorkout)
if let session, session.state != .ended {
    session.end()
}
```

```swift
// after
if let session, session.state != .ended {
    if runningMode == .mirrored {
        builder?.discardWorkout()
    }
    session.end()
}
```

`session.state != .ended` 조건 안에 넣었기 때문에 정상 종료 흐름에서는 여기까지 오지 않는다. 앞에서 이미 세션이 끝나 있어서 `discardWorkout()`이 두 번 불릴 일은 없다.

조건을 왜 붙였는지는 눌러보는 쪽이 빠르다. 구성과 정리 방식을 바꿔가며 건강 앱에 무엇이 남는지 보면 된다.

<iframe
  src="/assets/demo/health_duplicate_save_simulator.html"
  width="100%"
  height="710px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

"워치 꺼둠"에 "조건 없이 버린다"를 걸어보면 기록이 아예 사라진다. **중복을 없애는 것과 기록을 없애는 건 다른 얘기**라는 게 여기서 보인다.

---

### 왜 이걸 몰랐나

세 가지가 겹쳤다.

첫째, **저장 코드를 안 썼으니 저장이 안 될 거라고 생각했다.** 시스템이 대신 마감해준다는 걸 몰랐다.

둘째, **주간 합계가 정상이었다.** 숫자가 두 배로 튀었으면 진작 알았을 텐데 겹치는 운동이 걸러지면서 조용히 넘어갔다.

셋째, **워치를 늘 같이 들고 테스트했다.** 워치를 끄고 한 번만 뛰어봤어도 아이폰이 저장한다는 걸 알았을 것이다. 오늘 그걸 처음 해봤다.

원래 확인하려던 건 강제 종료된 세션이 남는 문제였다. 그것 때문에 워치를 끄고 나갔는데, 나온 건 전혀 다른 문제였다.

---

## 고쳤다고 생각했는데 종료 주체에 따라 갈렸다

앞의 수정을 실기기에서 확인했다. **결과가 종료 버튼을 어디서 눌렀느냐에 따라 달랐다.** 앱에서 끝냈을 때와 워치에서 끝냈을 때가 다르게 나왔다.

원인이 둘이었고, 둘 다 처음 수정할 때 못 본 것이다.

---

### 첫째, 순서가 뒤바뀌어 있었다

`resetWorkout()`에도 같은 처리를 넣어뒀는데, 그게 도는 시점에는 이미 조건이 깨져 있었다.

```swift
// RunViewModel.swift - resetState()
HealthKitService.shared.runningMode = .standalone   // 먼저 초기화하고
await runningCenter.reset()
await runningCenter.clearModeAData()
HealthKitService.shared.resetWorkout()              // 그 다음에 부른다
```

`resetWorkout()` 안의 판단이 `runningMode == .mirrored`인데, **그 값을 바로 위에서 `.standalone`으로 되돌려버린 뒤였다.** 그래서 버리는 분기를 한 번도 못 탔다.

```swift
// after
await runningCenter.reset()
await runningCenter.clearModeAData()
// resetWorkout()이 미러링 여부를 보고 iPhone builder를 버릴지 정하므로,
// runningMode 초기화는 그 뒤여야 한다.
HealthKitService.shared.resetWorkout()
HealthKitService.shared.runningMode = .standalone
```

한 줄을 아래로 내린 게 전부인데, **조건을 보는 코드와 그 조건을 지우는 코드가 세 줄 떨어져 있었다.** 워치에서 종료하는 경로가 이쪽을 타기 때문에 그때만 결과가 달랐다.

---

### 둘째, 워치가 마무리를 안 하고 있었다

더 큰 건 이쪽이다. **앱에서 종료하면 워치는 자기 워크아웃을 끝내지 않는다.**

```swift
// WatchViewModel.swift - iPhone 이 끝냈다는 신호를 받는 자리
if result.stopOrigin == .remote {
    guard !self.isHandlingRemoteStop else { return }
    self.isHandlingRemoteStop = true
    Task {
        await self.saveRunningData()
        await self.resetState()
        self.isHandlingRemoteStop = false
    }
}
```

`saveRunningData()`는 앱 Logbook용이고 미러링일 때는 가드에 걸려 바로 빠져나온다. `resetState()`는 워치의 `resetWorkout()`을 부르는데 **그건 참조만 비우고 `session.end()`를 부르지 않는다.**

그래서 워치의 세션은 `.stopped`가 되지 않고, `finishWatchWorkout()`도 불리지 않는다. **Apple Health에 워치 기록이 안 남고, 끝나지 않은 세션이 그대로 남는다.** 강제 종료 얘기를 하면서 봤던 것과 같은 모양인데, 이건 정상 종료에서도 매번 생기고 있었다.

---

## 그래서 규칙을 먼저 정했다

코드를 더 고치기 전에 물음이 하나 남아 있었다. **애초에 누가 저장해야 하는가.**

후보가 둘이었다. 하나는 **종료한 기기가 저장한다.** 대칭적이고 예외가 없다. 앱에서 끝내면 아이폰이, 워치에서 끝내면 워치가 쓴다. 지금 코드에서 가장 적게 바꿔도 되는 길이기도 하다.

다른 하나는 **센서를 가진 기기가 저장한다.** 앱 주도 미러링에서 손목에 있는 건 워치다.

<iframe
  src="/assets/demo/health_save_owner_simulator.html"
  width="100%"
  height="620px"
  style="border: 1px solid rgba(120, 113, 108, 0.2); border-radius: 16px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);"
  scrolling="no"
  loading="lazy"
></iframe>

첫 번째 규칙으로 두 종료 경로를 돌려보면 문제가 보인다. **개수가 아니라 내용이 다르다.**

미러링 중에 심박을 재는 건 워치다. 워치가 심박을 아이폰으로 보내주긴 하지만 그건 앱 화면에서 쓰는 값이고, **아이폰의 워크아웃 빌더로는 들어가지 않는다.** 아이폰 빌더에는 심박 센서에서 온 데이터가 없다.

| 종료한 곳 | 남는 기록 | 심박 |
|---|---|---|
| 워치 | Apple Watch | 있음 |
| 앱 | iPhone | 없음 |

**같은 러닝인데 종료 버튼을 어디서 눌렀느냐로 기록의 내용이 달라진다.** 사용자는 그 둘을 다른 선택이라고 생각하지 않는다. 건강 앱에서 운동을 열면 심박 그래프가 나오는 게 기본인데, 앱에서 끝낸 날만 비어 있으면 이상하게 보인다.

그래서 **센서를 가진 기기가 저장한다**로 정했다. 어디서 끝내든 남는 기록이 같다.

---

### 워치가 원격 종료에서도 마무리하게

규칙을 정하고 나니 고칠 곳이 분명해졌다. 아이폰에서 끝냈을 때 워치가 자기 워크아웃을 마감하게 만들면 된다.

```swift
// after (WatchViewModel.swift)
Task {
    // iPhone 이 끝냈어도 Watch 세션은 자기가 만든 것이라 저절로 끝나지 않는다.
    // 여기서 마무리하지 않으면 두 가지가 같이 어긋난다.
    // 1. Apple Health 에 아무 기록도 안 남는다. 미러링 중에는 iPhone 이
    //    자기 builder 를 버리기 때문에 Watch 마저 마무리를 안 하면 저장하는 쪽이 없다.
    // 2. resetWorkout() 은 session 을 nil 로만 비우고 end() 는 부르지 않아서,
    //    끝나지 않은 세션이 healthd 에 그대로 남는다.
    await HealthKitService.shared.finishWatchWorkout(at: Date())
    await self.saveRunningData()
    await self.resetState()
    self.isHandlingRemoteStop = false
}
```

`finishWatchWorkout(at:)`이 `endCollection`, `finishWorkout`, `session.end()`를 순서대로 처리한다. 이미 있던 함수인데 **정상 종료 경로 한쪽에서만 불리고 있었다.**

워치의 `resetWorkout()`에도 주의 문구를 달았다. 이 함수가 `session.end()`를 부르지 않는다는 걸 모르면, 다음에 종료 경로를 추가할 때 같은 일이 반복된다.

---

### 정리하면 이렇게 된다

| 시작 | 종료 | 저장하는 쪽 | 건강 앱 |
|---|---|---|---|
| 앱 주도 | 앱 | 워치 | 1건 (Apple Watch) |
| 앱 주도 | 워치 | 워치 | 1건 (Apple Watch) |
| 앱 주도, 워치 꺼둠 | 앱 | 아이폰 | 1건 (iPhone) |
| 워치 주도 | 워치 | 워치 | 1건 (Apple Watch) |

마지막 줄은 이번 수정과 무관하다. **워치 주도는 미러링을 아예 시도하지 않아서** 아이폰에 세션이 생기지 않는다. 저장 주체가 처음부터 하나뿐이라 구조적으로 중복이 불가능하다.

세 번째 줄 때문에 조건을 붙였다. 워치를 꺼두고 뛰면 아이폰이 유일한 저장 주체다. 조건 없이 버리면 그 경우 기록이 통째로 사라진다.

---

### 배운 것

처음 고쳤을 때 나는 **저장하는 쪽을 하나로 줄이는 문제**라고 봤다. 그래서 아이폰 것을 버리는 코드만 넣고 끝냈다.

실제로는 **누가 저장할 것인지 정하는 문제**였다. 그걸 안 정하고 한쪽을 막으니, 막힌 경로에서는 아무도 저장하지 않고 안 막힌 경로에서는 둘 다 저장했다. 규칙을 먼저 세우고 나니 고칠 곳이 두 군데로 분명해졌다.

**중복을 없애는 것과 주체를 정하는 것은 다른 일이었다.**

---

## 남은 것

`SwiftDataCoordinate`에 시각을 같이 저장할까 고민 중이다. 지금은 저장 직전에 지도에 그릴 만큼만 좌표를 솎아내기 때문에 남은 좌표들 사이의 시간 간격도 제각각이다. 좌표마다 시각이 있으면 실제 러닝 데이터를 시뮬레이터에 그대로 넣을 수 있어서 이런 조정이 훨씬 정확해진다.

그리고 경고를 지금처럼 하나하나 따로 기록할지, **시작과 끝을 가진 한 덩어리로 묶을지**도 생각해볼 문제다. 페이스가 허용 범위를 벗어나 있는 건 한동안 이어지는 상태인데, 지금은 경고가 켜지는 순간마다 별개로 세고 있다. 덩어리로 묶으면 7.87km에 서너 건이 될 것이다. 다만 저장 구조를 바꾸는 거라 기존 사용자의 데이터를 옮기는 작업이 필요하고, 1.1에서 겪은 문제를 다시 밟지 않도록 조심해야 한다.

실기기 테스트를 마치는 대로 1.3.2로 올릴 예정이다.
