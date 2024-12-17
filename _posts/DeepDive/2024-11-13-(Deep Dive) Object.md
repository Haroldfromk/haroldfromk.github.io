---
title: (Deep Dive) @ObservedObject vs @StateObject
writer: Harold
date: 2024-11-13 13:00
#last_modified_at: 2024-03-17 21:11:00
categories: [Deep Dive]
tags: [Myself]

toc: true
toc_sticky: true
---

@ObservedObject vs @StateObject 이부분은 좀 더 자세히 알아봐야할것같아서 이렇게 새롭게 글을 작성한다

코드 예시는 [여기](https://www.avanderlee.com/swiftui/stateobject-observedobject-differences/){:target="_blank"}를 참고하여 작성을 한다.

### @ObservedObject vs @StateObject

우선 둘의 공통점은 `ObservableObject` 프로토콜을 따른다는 것이다.

![CleanShot 2024-11-13 at 20 19 22](https://github.com/user-attachments/assets/091ee2ab-5133-45cf-a7da-048cf6d7050b)

그리고 지금 아래 코드를 보면 viewModel에 대해 Wrapper를 다르게 했는데 이렇게 해도 실행 결과는 같다.

```swift
final class CounterViewModel: ObservableObject {
    @Published var count = 0

    func incrementCounter() {
        count += 1
    }
}

struct CounterView: View {
    @ObservedObject var viewModel = CounterViewModel()
    @StateObject var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("Count is: \(viewModel.count)")
            Button("Increment Counter") {
                viewModel.incrementCounter()
            }
        }
    }

}
```

![Nov-13-2024 20-16-04](https://github.com/user-attachments/assets/ce25c987-0198-4532-b44c-e6088dd24fcb)

![CleanShot 2024-11-13 at 20 16 37](https://github.com/user-attachments/assets/2c761575-33f9-4755-9e52-32ce168d3915)

그러면 차이를 줘보도록 하자

```swift
struct RandomNumberView: View {
    @State var randomNumber = 0

    var body: some View {
        VStack {
            Text("Random number is: \(randomNumber)")
            Button("Randomize number") {
                randomNumber = (0..<1000).randomElement()!
            }
        }.padding(.bottom)

        CounterView()
    }
}
```

RandomNumberView를 만들어 준다.

#### 1. @ObservedObject


```swift
struct CounterView: View {
    @ObservedObject var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("Count is: \(viewModel.count)")
            Button("Increment Counter") {
                viewModel.incrementCounter()
            }
        }
    }

}
```

![Nov-13-2024 20-29-30](https://github.com/user-attachments/assets/36bdb0d2-77f9-4e72-b656-f4d8af6f9c3b)

카운트만 눌렀을때는 숫자가 증가하지만

랜덤을 누르는순간 카운트가 초기화가 되어버린다.

![CleanShot 2024-11-13 at 20 45 12](https://github.com/user-attachments/assets/d136f912-1822-4c30-91fb-acf9edf51a40)

```text
<SwiftUI.CGDrawingView: 0x101390ed0; frame = (160.333 462.333; 81.6667 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtC7SwiftUIP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x600002635b60>>
```

이제 랜덤을 누르면 어떻게 되는지 확인하자

![CleanShot 2024-11-13 at 20 47 13](https://github.com/user-attachments/assets/a3b75e0e-cd60-45ca-88cc-25afb74c49eb)

```text
<SwiftUI.CGDrawingView: 0x101390ed0; frame = (160 462.333; 82 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtC7SwiftUIP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x600002635b60>>
```

CounterViewModel의 메모리가 달라진걸 확인할 수 있다.

즉 랜덤을 누름과 동시에 ViewModel객체가 초기화가 되기에 count도 초기값인 0으로 돌아가는것.

#### 2. @StateObject

```swift
struct CounterView: View {
    @StateObject var viewModel = CounterViewModel()
    
    var body: some View {
        VStack {
            Text("Count is: \(viewModel.count)")
            Button("Increment Counter") {
                viewModel.incrementCounter()
            }
        }
    }

}
```

![Nov-13-2024 20-30-30](https://github.com/user-attachments/assets/d02b9d8c-520a-4a28-bf6a-109dc4f35903)

위와 달리 카운트가 증가한상태에서 랜덤을 눌러도 카운트가 유지가 된다.

![CleanShot 2024-11-13 at 20 41 19](https://github.com/user-attachments/assets/4e2ad343-14aa-47e2-82b0-a64d2b69906d)

```text
<SwiftUI.CGDrawingView: 0x10130f7d0; frame = (160 462.333; 82 20.3333); anchorPoint = (0, 0); opaque = NO; autoresizesSubviews = NO; layer = <_TtC7SwiftUIP33_65A81BD07F0108B0485D2E15DE104A7514CGDrawingLayer: 0x60000262e100>>
```

이건 count is와 관련된 View의 정보

숫자를 늘려도 그대로이다. 즉 ViewModel의 메모리가 그대로 유지된채로 값이 바뀐다는것이다.

#### 차이점

랜덤을 누르는 순간 ViewModel의 객체가 초기화가 되었다.

ObservedObject는 초기화가 된 사례
StateObject는 초기화가 되지 않은 사례 이다.

```swift
struct RandomNumberView: View {
    @State var randomNumber = 0

    var body: some View {
        VStack {
            Text("Random number is: \(randomNumber)")
            Button("Randomize number") {
                randomNumber = (0..<1000).randomElement()!
            }
        }.padding(.bottom)

        CounterView()
    }
}
```

여기서 랜덤 버튼을 클릭하게되면 숫자가 바뀐다. 즉 **View가 업데이트** 된다.

CounterView()는 현재 RandomNumberView의 자식뷰 이므로, 같이 업데이트가 된다.

이때 @ObservedObject를 사용하게 되면 CounterView 자체도 새롭게 렌더링이 되면서 ViewModel을 새롭게 생성하게 된다. 그러면서 메모리가 바뀌게 된것.

하지만 @StateObject를 사용하게 되면 CounterView는 새롭게 렌더링이 될지라도 ViewModel 자체는 그대로 유지를 하기에 값이 변하지 않은것.

