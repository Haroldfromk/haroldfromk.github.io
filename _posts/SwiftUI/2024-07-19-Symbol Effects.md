---
title: Symbol Effects
writer: Harold
date: 2024-7-19 06:33:00 +0800
categories: [Udemy, SwiftUI]
tags: [SwiftUI]

toc: true
toc_sticky: true
---

SwiftUI의 구성

![CleanShot 2024-09-06 at 13 21 07@2x](https://github.com/user-attachments/assets/337f1c58-33ab-4eac-a024-eb5e3dcf4134)

파일을 SwiftUI로 설정하여 만들게 되면

위와같이 2개의 파일이 생성이 된다.

이전과는 다른 양식이다.

```swift
import SwiftUI

@main
struct VacationInVegasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

WindowGroup에 ContentView가 있는데,

이것을 통해 화면에 보여준다라고 생각을 하면 된다.

ContentView는 바로 ContentView.swift 이다.

SwiftUI는 UIKit과는 달리 Preview가 제공이 되는데. 이것을 통해 내가 현재 어떤 작업을 하는지 가시적으로 확인이 가능해지는 장점이 있다.


```swift
import SwiftUI

struct Symbols: View {
    @State private var shouldIBounce = false
    @State private var shouldIRotate = false
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)
            
            Image(systemName: "airplane")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.teal)
                .symbolEffect(.wiggle)
            
            Image(systemName: "wifi")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.purple)
                .symbolEffect(.variableColor.reversing)
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.tint)
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.bounce, value: shouldIBounce)
                .onTapGesture {
                    shouldIBounce.toggle()
                }
            
            Image(systemName: "cloud.sun.rain.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.gray, .yellow, .mint)
                .symbolEffect(.bounce, value: shouldIBounce)
                .onTapGesture {
                    shouldIBounce.toggle()
                }
            
            Image(systemName: "arrow.clockwise.square")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.blue.mix(with: .red, by: 0.75))
                .symbolEffect(.rotate, value: shouldIRotate)
                .onTapGesture {
                    shouldIRotate.toggle()
                }
            
            Image(systemName: "sun.max.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.yellow)
                .symbolEffect(.breathe)
        }
        .padding()
    }
}

#Preview {
    Symbols()
}

```

**foregroundStyle**은 색을 지정하는데 사용.

**symbolEffect**는 말그대로 효과를 줄때 사용한다.
이때 wiggle은 ios18이후에서 사용 가능하니 주의.

**ontapGesture**도 역시 말그대로 탭을 했을때의 이벤트가 어떻게 될지를 정한다.

결과는 다음과 같다.

![Sep-06-2024 13-39-29](https://github.com/user-attachments/assets/7303ef72-1d4c-4272-a376-75baf33d2105)

---

## @state 란?

상태 프로퍼티이며, 상태에 관한 가장 기본적인 형태이다.

`@state`로 선언하며, 해당 뷰의 값이 변경될 때마다, 뷰를 다시 렌더링 하도록 한다.

단, 뷰 내부에서만 사용가능하며, 외부에서는 직접적으로 접근을 할 수 없다.

혹시나 해서 true로 바꾸고 하면 평상시에 계속 작동하지 않을까 했지만 작동하지 않았다.

애니메이션 효과의 경우 동일한 값이 유지된 상태 즉 false, true로 유지된 상태에서는 작동하지 않고, 값이 변할때 작동을 하기에 ,toggle을 통해 값이 변경 됨에 따라 애니메이션이 작동하는 것이다.
