---
title: Async/Await (1)
writer: Harold
date: 2024-11-27 01:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## 1. Concurrency ?

Swift를 하다보면 중간에 배우게 되는게 Concurrency 이다.

그렇다면 Concurrency란 도대체 무엇일까?
> 사전적 의미로는 동시성이다.
> Swift에서는 간단하게 정의하면 여러가지 일을 같은 시간에 수행한다.

[Docs](https://developer.apple.com/documentation/swift/concurrency/){:target="_blank"}에도 있으니 한번 읽어 보는것을 추천.

[WWDC](https://developer.apple.com/videos/play/wwdc2021/10254/){:target="_blank"}도 같이 봐두면 좋을듯하다.

![image](https://miro.medium.com/v2/resize:fit:1400/format:webp/1*Tn3YSVqG_96cywHdyS3HHQ.jpeg)

이미지출처: [Medium](https://mattsaedi.medium.com/concurrency-in-swift-0f8f0ab10ee9){:target="_blank"} 

### 1.1 왜 필요한가?

우리가 어떤 이미지를 다운로드를 한다고 하면, 만약 Main Thread에서 이미지를 다운로드 하게 되면

![Untitled Diagram drawio](https://github.com/user-attachments/assets/de667592-29d4-489f-ba67-c89093a4f48f)

이런식으로의 작업이 이루어지게 된다.

즉, Main Thread에서 전부 순차적으로 시행이 되기때문에, UI작동이 잠시 렉이 걸리듯 멈추었다가 Network작업이 끝난후 다시 UI가 작동이 된다.

### 1.2 그렇다면 해결할 수 있는 방법은?

![Untitled Diagram drawio1](https://github.com/user-attachments/assets/7208cad0-0787-4cd4-921d-9e6601526c89)

이런식으로 Network같은 오래걸리는 작업을 Background Thread에서 작업을 실행하게 하는것이다.

![image](https://docs-assets.developer.apple.com/published/9d00c17c463bfa2e328a09d311800006/improving-app-responsiveness-4@2x.png)

즉, UI적인 요소는 Main Thread에서 이외 다운로드 같은 Network 관련된 작업은 Background Thread에서 작업을 하게하는 즉 작업을 분산시키는걸로 보면 된다.

이게바로 Concurrency, 즉 동시성이다.

## 2. GCD ?

GCD는 Grand Central Dispatch의 약자이다.

### 2.1. GCD의 종류와 우선순위 


GCD에서는 **글로벌 큐(global queue)**도 생성할 수 있으며, 이는 **병렬(concurrent)**로 실행된다.  
글로벌 큐에는 다양한 **품질 서비스(QoS, Quality of Service)** 우선순위 설정이 있다:

1. **User Interactive**  
   - 애니메이션, 이벤트 처리, 앱 UI 업데이트와 같은 작업에 적합하다.
   - 즉시 사용자의 인터페이스에 영향을 주는 작업을 처리한다.

2. **User Initiated**  
   - 사용자가 앱을 적극적으로 사용하는 동안 완료되어야 하는 작업에 적합하다.

3. **Default**  
   - 기본 품질 서비스로 설정되며, 시스템이 적절한 우선순위를 자동으로 선택한다.

4. **Utility**  
   - 사용자가 적극적으로 추적하지 않는 작업(예: 다운로드, 데이터 처리)에 적합하다.

5. **Background**  
   - 백그라운드에서 수행하는 유지보수 작업(예: 데이터 정리, 업데이트)에 적합하다.

6. **Unspecified**  
   - 품질 서비스나 우선순위가 지정되지 않은 상태이다.

### 2.2 Serial Queue / ConcurrentQueue

**Serial(직렬) Queue**  
Swift에서는 Serial Queue를 `DispatchQueue`를 사용하여 간단히 생성할 수 있다.  
그리고 label은 Customizing이 가능하며, `async` 메서드를 사용해 작업을 실행한다.  
첫 번째 작업이 완료되면 다음 작업이 실행된다. (즉 순서대로 작업이 진행이 된다.)

```swift
let queue = DispatchQueue(label: "SerialQueue")\
queue.async {
    // This Task is executed first
}
queue.async {
    // and then This Task is executed second
}
```

**Concurrent(병렬) Queue**  
Concurrent Queue를 생성하려면 `DispatchQueue`의 속성(attribute)에서 Concurrent Queue를 설정해야 한다.  
Concurrent Queue에서 작업은 추가된 순서대로 시작되지만, 완료되는 순서는 보장되지 않는다.  
즉, 첫 번째 작업이 먼저 끝날 수도, 두 번째나 세 번째 작업이 먼저 끝날 수도 있다.

```swift
let queue = DispatchQueue(label: "ConcurrentQueue", attributes: .concurrent)
queue.async {

}
queue.async {
    
}
// Tasks will start in the order they ar added but they can finish in any order
```

## 3. Background Thread / Main Thread


- **Background Thread 사용**  
  리소스나 이미지를 다운로드하는 작업은 **Global Background Queue**에서 수행하는 것이 적합하다.  
  이러한 작업을 Main Thread에서 실행하면 UI가 멈추거나 반응하지 않게 된다.

```swift
// Bad Idea
DispatchQueue.global().async {
    // download the image

    // refresh the UI
}
```

- **Main Thread로 전환**  
  UI를 업데이트하거나 사용자 인터페이스와 관련된 작업을 수행하려면 반드시 **Main Thread**로 전환해야 한다.  
  이를 위해 `DispatchQueue.main.async`를 사용한다.  
  이렇게 하면 UI 업데이트가 Main Thread에서 실행되어 원활한 사용자 경험을 제공할 수 있다.

```swift
// Good Idea
DispatchQueue.global().async {
    // download the image
    DispatchQueue.main.async {
        // refresh the UI
    }
}
```

## 참고하면 좋은 글

1. [viget](https://www.viget.com/articles/concurrency-multithreading-in-ios/){:target="_blank"} 
2. [medium](https://ali-akhtar.medium.com/concurrency-in-swift-grand-central-dispatch-part-1-945ff05e8863){:target="_blank"} 
3. [swiftbysundell](https://www.swiftbysundell.com/articles/task-based-concurrency-in-swift/){:target="_blank"} 
4. [cocoacasts](https://cocoacasts.com/swift-and-cocoa-fundamentals-threads-queues-and-concurrency){:target="_blank"} 