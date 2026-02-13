---
title: 1주차 (6)
writer: Harold
date: 2024-03-05 05:11:00 +0800
categories: [캠프, 1주차]
tags: [스택&큐]

toc: true
toc_sticky: true
---
# Stack & Queue
- Stack과 Queue는 데이터에 대한 개념이다
- Swift에서는 따로 큐와 스택을 지원하지 않으며, Array등을 사용하여 별도로 직접 구현 할 수 있다.

## 1. Queue
![](https://static.javatpoint.com/ds/images/ds-stack-vs-queue2.png)
![](https://www.masaischool.com/blog/content/images/wordpress/2022/04/Enqueue-and-Dequeue-operations.png)
- First In First Out (F.I.F.O. / 선입선출)
- 말그대로 먼저 들어온 값을 먼저 내보내는 구조이다.

```swift
/*
<T> 에 대해서는 추후 배울 예정
제네릭이라는 것인데, 하나의 타입으로 국한되지 않고
타입에 유연하게 코드를 작성할 수 있는 기능이다.
*/

struct Queue<T> {
    private var queue: [T] = []
    
    public var count: Int {
        return queue.count
    }
    
    public var isEmpty: Bool {
        return queue.isEmpty
    }
    
    public mutating func enqueue(_ element: T) {
        queue.append(element)
    }
    
    public mutating func dequeue() -> T? {
        return isEmpty ? nil : queue.removeFirst()
    }
}

var queue = Queue<Int>()
queue.enqueue(10)
queue.enqueue(20)
queue.dequeue() // 10
```

## 2. Stack
![](https://static.javatpoint.com/ds/images/ds-stack-vs-queue.png)
- Last In Fisrt Out (L.I.F.O. / 후입선출)
- 먼저 들어온 값을 가장 마지막에 내보내는 구조
- 즉 가장 마지막에 들어온 값이 먼저 내보내는 구조

```swift
/*
<T> 에 대해서는 추후 배울 예정
제네릭이라는 것인데, 하나의 타입으로 국한되지 않고
타입에 유연하게 코드를 작성할 수 있는 기능이다.
*/
struct Stack<T> {
    private var stack: [T] = []
    
    public var count: Int {
        return stack.count
    }
    
    public var isEmpty: Bool {
        return stack.isEmpty
    }
    
    public mutating func push(_ element: T) {
        stack.append(element)
    }
    
    public mutating func pop() -> T? {
        return isEmpty ? nil : stack.popLast()
    }
}

var stack = Stack<Int>()
stack.push(10)
stack.push(20)
stack.pop() // 20
```