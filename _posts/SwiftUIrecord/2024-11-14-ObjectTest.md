---
title: SwiftUI 상태 관리 및 데이터 저장 비교 - @StateObject, @ObservedObject, CoreData, SwiftData
writer: Harold
date: 2024-11-14 7:33:00 +0800
last_modified_at: 2024-11-17 1:32:00 +0800
categories: [Study, TourApp]
tags: []

toc: true
toc_sticky: true
---

어제 `@ObservableObject, @StateObject`와 관련된 글을 작성하면서 뭔가 테스트를 해보고싶어서 간단한 앱을 하나 만들어보려한다.

장바구니 앱이며, https://dummyjson.com/products/1 사이트를 사용해서 DummyData가 있는 api를 호출하여 맘에드는 것을 담고,

장바구니를 초기화할때 `@ObservableObject, @StateObject`의 차이를 통해 보여지는 화면이 다를것으로 판단이 들어서 그걸 확인해보려한다.

![CleanShot 2024-11-14 at 13 50 51](https://github.com/user-attachments/assets/22335a71-35b8-4133-a917-a79cd0d38b2a)

우선 파일구조는 다음과 같다.

---

## 1. 모델링

```swift
struct WishModel: Codable {
    let id: Int
    let title, description, category: String
    let price, discountPercentage, rating: Double
    let stock: Int
    let tags: [String]
    let brand: String
    let reviews: [Review]
    let thumbnail: String
}

// MARK: - Review
struct Review: Codable {
    let rating: Int
    let comment, date, reviewerName, reviewerEmail: String
}
```

우선은 이렇게 해두었다.

사실 간단한 테스트용이라 빼도 되는게 몇개 있긴한데 이정도만 살려두었다.

---

## 2. 화면구성

화면구성은 좀 심플하게 하려고한다.

탭바를 통해 2개의 화면을 구성한다.

### 2-1. TabView 구성

파일명은 MainView로 하였고 여기에 TabView를 사용 하여 Tabbar를 만든다.

```swift
struct MainView: View {
    var body: some View {
        TabView {
            Tab("Display", systemImage: "eye") {
                DisplayView()
            }
            Tab("cart", systemImage: "cart") {
                CartView()
            }
        }
    }
}
```

![CleanShot 2024-11-14 at 14 57 24](https://github.com/user-attachments/assets/81369ca6-6d1f-48dc-8e1e-aee9c8741395){: width="50%" height="50%"}

이전에는 

```swift
DisplayView()
        .tabItem {
                Text("Display")
                Image(systemName: "eye")
                }
CartView()
        .tabItem {
                Text("cart")
                Image(systemName: "cart")
                }
```

이런식으로 했지만 사용하려고하면 Deprecated 되었기에 써도 무관하지만 새롭게 사용하는 방식으로 하였다.

다만 2개를 혼용하여 사용하지는 못한다.

### 2-2. 첫번째 화면

파일명은 DisplayView로 하였다.

#### 2-2-1. ToolBar
상단에 장바구니 버튼을 누르면 menu를 띄워 추가, 전체삭제 이렇게 두개를 구성

```swift
var body: some View {
        NavigationStack {
            NavigationView {
                
            }
            .navigationBarItems(trailing: Button(action: {
                
            }, label: {
                Image(systemName: "cart")
            }))
        }
        
    }
```

하지만 `navigationBarItems` 역시 Deprecated 되었다.

```swift
struct DisplayView: View {
    var body: some View {
        NavigationStack {
            Text("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            print("test")
                        } label: {
                            Image(systemName: "cart")
                        }

                    }
            }
            
            NavigationView {
                
                
            }
        }
        
    }
}
```

다만 toolBar를 사용하려면 Modifier개념으로 들어가기에 Text를 넣어주었다.

#### 2-2-2. ItemView

가운데 화면에 제품설명

제품설명은 센터에 이미지, 하단에 제품명, 제품설명, 가격 이정도로 심플하게

이후에 위에 모델링한것들을 할지는 생각

ItemView라는 새로운 파일을 만들어 주었다.

```swift
struct ItemView: View {
    
    @State var imageUrl: String = ""
    @State var title: String = ""
    @State var description: String = ""
    @State var price: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "photo")
                    .resizable()
            }
            .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.4)
            Text(title)
            Text(description)
                .padding(.horizontal, 20)
            HStack {
                Spacer()
                Text(price.dollarAdd())
            }
            .padding(.horizontal, 25)
        }
    }
}
```

![CleanShot 2024-11-14 at 15 52 36](https://github.com/user-attachments/assets/5136e4ac-15ec-418d-b8e8-96adfac191b6){: width="50%" height="50%"} 

이렇게 세팅을 완료

이때 가격이 타입이 Double이라서 앞에 $표시를 간단하게 붙이게 하기위해 Extension을 사용하여 Function을 하나 만들어 준다.

```swift
extension Double {
    func dollarAdd() -> String {
        return ("$\(self)")
    }
}
```

이렇게 만들면 굳이 `"$\(price)"` 이런식으로 번거롭게 할 필요가 없어진다.

![CleanShot 2024-11-14 at 15 54 53](https://github.com/user-attachments/assets/000360c9-77b6-4b98-88f7-a1d46340f79d){: width="50%" height="50%"} 

현재는 이렇게 나온다.

Navigation Toolbar를 처음에 버튼으로 했다가. 생각해보니 메뉴로 보이게 하는게 좋을듯 해서 바꾼다.

```swift
 ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                print("added")
                            } label: {
                                Text("추가하기")
                                Image(systemName: "cart.badge.plus")
                            }
                            Button {
                                print("deleted")
                            } label: {
                                Text("장바구니 비우기")
                                Image(systemName: "cart.badge.minus")
                            }
                        } label: {
                            Image(systemName: "cart")
                        }

                    }
```


![Simulator Screenshot - iPhone 16 Pro - 2024-11-14 at 16 06 38](https://github.com/user-attachments/assets/62af07b0-99e0-44a3-bacd-66562c2e8182){: width="50%" height="50%"} 

그리고 아래에도 버튼을 만들어 주었다.

```swift
 HStack {
                Button {
                    print("next")
                } label: {
                    Text("다음")
                        .fontWeight(.bold)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.05)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .foregroundStyle(.blue)
                            .opacity(0.5))
                }
                Button {
                    print("add")
                } label: {
                    Text("추가")
                        .fontWeight(.bold)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.05)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .foregroundStyle(.green)
                            .opacity(0.5))
                }
            }
            .padding(.horizontal, 15)
```

![CleanShot 2024-11-14 at 17 15 57](https://github.com/user-attachments/assets/10b08a29-dff7-4ce3-aa3b-fc5029c73de2){: width="50%" height="50%"} 

완료

**Menu에서는 장바구니 비우기 하나만 두기로 결정**

```swift
Menu {
        Button {
            cartViewModel.deleteAllData()
        } label: {
            Text("장바구니 비우기")
            Image(systemName: "cart.badge.minus")
        }
    } label: {
        Image(systemName: "cart")
    }
```

현재는 이렇게 두었다.

### 2-3. 두번째 화면

리스트를 사용해서 어떤 물건이 등록되었는지 보여주기

SwipeAction을 사용하여 개별 제거 가능.

파일명은 CartView로 하였다.

아직 데이터가 정확하게 들어오지 않았으므로 우선은 심플하게 뼈대만

```swift
var body: some View {
        VStack {
            List() { cart in
                HStack {
                    Text("상품명")
                    Spacer()
                    Text("가격자리")
                }
            }
        }
    }
```

---

## 3. Api 관련 코드작성

이전에 했던것처럼 Generic을 사용해서 해볼것이다.

```swift
enum NetworkError: Error {
    case badUrl
    case invalidRequest
    case badResponse
    case badStatus
    case failedToDecodeResponse
}

class WishService {
    func downLoadData<T: Codable>(url: String) async -> T? {
        do {
            guard let url = URL(string: url) else { throw NetworkError.badUrl }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse else { throw NetworkError.badResponse }
            guard response.statusCode >= 200 && response.statusCode < 300 else { throw NetworkError.badStatus }
            guard let decodedData = try? JSONDecoder().decode(T.self, from: data) else { throw NetworkError.failedToDecodeResponse }
            
            return decodedData
            
        } catch NetworkError.badUrl {
            print("There was an error creating the URL")
        } catch NetworkError.badResponse {
            print("Did not get a valid response")
        } catch NetworkError.badStatus {
            print("Did not get a 2xx status code from the response")
        } catch NetworkError.failedToDecodeResponse {
            print("Failed to decode response into the given type")
        } catch {
            print("An error occured downloading the data")
        }
        
        return nil
    }
}
```

이렇게 만들어 준다.

이번엔 이전과 달리 decode에도 T를 사용함으로써 Generic을 유지한다.

```swift
class WishViewModel: ObservableObject {
    @Published var wishList: [WishModel] = []
    
    init() {
            Task {
                await fetchWishList()
            }
        }

    func fetchWishList() async {
        let randomNumber: Int = Int.random(in: 1...100)
        let url: String = "https://dummyjson.com/products/\(randomNumber)"
        guard let list: WishModel = await WishService().downLoadData(url: url) else { return }
        
        wishList = [list]
    }
}
```

---

## 4. Api 호출하기

여기서 선택지가 주어진다

ViewModel에 대해 `@ObservedObject` 또는 `@StateObject` 를 사용하는건데

지금은 크게 상관이 없어서 둘중 아무거나쓰고 나중에 비교할때 다시 관련 헤더를 만들어서 작성해보는걸로

ItemView에서 호출을 해보도록하자.

```swift
@ObservedObject var wishViewModel = WishViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            AsyncImage(url: URL(string: wishViewModel.wishList!.thumbnail))
```

이런식으로 해주었다.

데이터가 있어서 강제 언래핑을 하긴했지만 에러가 발생

아무래도 제대로 호출이 안된듯하다.

![CleanShot 2024-11-14 at 19 20 57](https://github.com/user-attachments/assets/e78847aa-0e67-4fba-9af1-0e81f660ad03)

문제는 여기를 찍고 다음을 넘기게되면 바로 에러가뜨는곳으로 넘어가게 된다.

우선 뭐가 잘못되었는지 다시 코드를 봐야할듯하다.

우선 빼먹은건 ViewModel에서 `@MainActor`를 빼먹었다.

하지만 이게 문제는 아니었다.

관련된 뷰를 전부 주석으로 잡고 

```swift
guard let url = URL(string: url) else { throw NetworkError.badUrl }
let (data, response) = try await URLSession.shared.data(from: url)
print(data)
print(response)
guard let response = response as? HTTPURLResponse else { throw NetworkError.badResponse }
guard response.statusCode >= 200 && response.statusCode < 300 else { throw NetworkError.badStatus }
guard let decodedData = try? JSONDecoder().decode(T.self, from: data) else { throw NetworkError.failedToDecodeResponse }

return decodedData
```

이렇게 해본결과

```text
1757 bytes
<NSHTTPURLResponse: 0x6000002e9280> { URL: https://dummyjson.com/products/89 } { Status Code: 200, Headers {
생략
}
Failed to decode response into the given type
```

1757bytes이기때문에 데이터도 제대로 받아왔다.

왜냐면 코드가 200이기 때문이다.

즉 호출은 제대로 되었고, 문제는 type이었다.

Generic을 사용했는데 어디서 문제인지 확인이 필요해보인다.

```swift
guard let decodedData = try? JSONDecoder().decode(WishModel.self, from: data) else { throw NetworkError.failedToDecodeResponse }
```

우선 여기를 그냥 모델로했을때는 출력이 된다.

즉 Generic사용에서 문제가 생겼다는것을 알 수 있다.

하지만 이건 문제 해결과정에서 내가 고치다가 잘못된것이었고 처음에는

```swift
 func fetchWishList() async {
        let randomNumber: Int = Int.random(in: 1...194)
        let url: String = "https://dummyjson.com/products/\(randomNumber)"
        guard let list: WishModel = await WishService().downLoadData(url: url) else { return }
        
        wishList = [list]
    }
```

이렇게 되어있었기에 크게 문제가 안된다.

다시 주석을 풀고 실행을 해보니 역시나 문제가 발생

뭔가 ViewModel을 가져와서 init을 했음에도 불구하고 data, response 부분에서 바로 계속 AsyncImage로 넘어가는게 이상하다.

**아무래도 api를 호출하면서 View가 먼저 렌더링 되기에 발생하는 문제로 보인다.**

아무래도 초기에 데이터값을 주어야하나보다.

그래서

```swift
VStack(spacing: 20) {
            AsyncImage(url: URL(string: wishViewModel.wishList.first?.thumbnail ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Image(systemName: "photo")
                    .resizable()
            }
            .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height * 0.4)
            Text(wishViewModel.wishList.first?.title ?? "")
            Text(wishViewModel.wishList.first?.description ?? "")
                .padding(.horizontal, 20)
            HStack {
                Spacer()
                Text(wishViewModel.wishList.first?.price.dollarAdd() ?? "$")
            }
            .padding(.horizontal, 25)
            HStack {
                Button {
                    print("next")
                } label: {
                    Text("다음")
                        .fontWeight(.bold)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.05)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .foregroundStyle(.blue)
                            .opacity(0.5))
                }
                Button {
                    print("add")
                } label: {
                    Text("추가")
                        .fontWeight(.bold)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.05)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .foregroundStyle(.green)
                            .opacity(0.5))
                }
            }
            .padding(.horizontal, 15)
        }
        .onAppear {
            if wishViewModel.wishList.isEmpty {
                Task {
                    await wishViewModel.fetchWishList()
                }
            }
        }
    }
```

옵셔널 체이닝을 통해 값을 주었다.

그제서야 해결....

그러면서 어떤 애들은 또 디코딩 에러가 나길래

```swift
struct WishModel: Codable {
    let id: Int
    let title, description: String
    let price: Double
    let thumbnail: String
}

```

모델을 대폭 축소화한다.

이미지도 약간 사이즈마다 다른듯해서 

`.scaledToFill()` 이걸로 바꿔준다.

![Nov-14-2024 20-09-45](https://github.com/user-attachments/assets/3557cbcd-42e0-4615-b20f-33831a3ef220){: width="50%" height="50%"} 

지금 다음을 눌렀을때 새롭게 가져오는건

```swift
Button {
                    Task {
                        await wishViewModel.fetchWishList()
                    }
                } label: {
                    Text("다음")
```

버튼에 이렇게 다시 fetch를 하도록 해두었기 때문.

---

## 5. Cart 기능 구현

SwiftData와 CoreData 둘중 뭘해볼까 고민을 하다 구글링을 했는데

[질문](https://www.inflearn.com/community/questions/1035841/swiftdata%EA%B0%80-core-data%EB%A5%BC-%EB%8C%80%EC%B2%B4%ED%95%98%EB%8A%94%EC%A7%80%EC%9A%94){:target="_blank"}글이 있어서 읽어보니 뭐 그렇다고 한다.

그래서 CoreData를 간만에 다시 써보는걸로,

물론 UIKit에서는 AppDelegate에서 Container설정을 했는데 그부분은 좀 달라서 알아두면 좋긴 할듯하다.

이후 내가 작성한 글을 다시 읽어보다가 SwiftData도 조금 더 사용해볼겸 한프로젝트에 다시 사용해보는것도 좋을듯해서 만들어 보기로 결정. [11.16 추가]

### 5-1. Model 만들기

여기는 좀 심플하게 List에만 보여주고 클릭시 새롭게 정보를 보여주는 용도는 아니라 가볍게 만든다.

```swift
struct CartModel: Identifiable {
    let id: Int
    let title: String
    let price: Double
}
```

간단하게 이름과 가격만으로 설정을 해둔다.

이때 list에 들어갈것이라 `Identifiable` 프로토콜을 채택해준다.

그래서 id도 같이 해준다.

SwiftUI에서 List를 사용할때는 데이터의 무결성을 중요시하므로 채택을 해주도록 하자.

### 5-2. CoreData 사용

UIKit을 사용할때는 AppDelegate에서 Container를 사용했는데 

[Youtube](https://www.youtube.com/watch?v=BPQkpxtgalY)를 참고하여 구현해보았다.

#### 5-2-1. 모델링

![CleanShot 2024-11-14 at 23 49 15](https://github.com/user-attachments/assets/9cc01577-1b43-4ea5-95f0-ab26d605eda9)

여기서 생성을 해주자.

![CleanShot 2024-11-14 at 23 51 44](https://github.com/user-attachments/assets/89f022c3-caec-455f-ad25-f991177e1efa)

이때 파일명을 정하고 생성을 누르니 이런 창이 뜬다.

이전에 없었던것같은데, GPT에게 차이를 물어보았다.

##### 5-2-1-1. `.xcdatamodel` vs `.xcdatamodeld` 확장자 차이

Core Data에서 **데이터 모델 파일**을 생성할 때, 다음 두 가지 확장자를 사용할 수 있다:

1. **`.xcdatamodel`**
2. **`.xcdatamodeld`**

Xcode에서는 **올바른 확장자** 사용을 권장하며, 아래는 두 확장자의 차이점이다.

###### 5-2-1-1-1. 📝 차이점 요약

| 확장자             | 설명                                                                                        | 사용 시기                       |
| ------------------ | ------------------------------------------------------------------------------------------- | ------------------------------- |
| **`.xcdatamodel`**  | **단일 데이터 모델 파일**이다. 하나의 데이터 모델만 포함한다.                               | **이전 버전의 Core Data** 프로젝트 |
| **`.xcdatamodeld`** | **데이터 모델 파일의 패키지**이다. 여러 개의 `.xcdatamodel` 파일을 포함할 수 있다.         | **현재 버전의 Core Data** 프로젝트 |

###### 5-2-1-1-2. 📌 `.xcdatamodel`

- **단일 모델 파일**로, Core Data의 초기 버전에서 사용되었다.
- **버전 관리 기능이 없다.**
- 이 확장자를 사용하면, 데이터 모델 변경 시 **버전 관리가 불가능**해 문제가 발생할 수 있다.

###### 5-2-1-1-3. 📌 `.xcdatamodeld`

- **패키지 디렉토리**로, 여러 개의 `.xcdatamodel` 파일을 포함할 수 있다.
- Core Data의 **버전 관리 기능**을 지원한다.
  - 예를 들어, `V1.xcdatamodel`, `V2.xcdatamodel`처럼 여러 버전의 모델을 저장할 수 있다.
- 현재 Xcode에서는 표준 확장자로 **`.xcdatamodeld`**를 사용하며, 데이터 모델의 **버전 관리**를 위해 권장된다.

###### 5-2-1-1-4. ⚠️ Xcode 알림 설명

Xcode에서 **`.xcdatamodel`** 확장자를 사용해 파일을 생성하려고 하면, **`.xcdatamodeld`** 확장자를 권장하는 알림이 나타난다.

- **"Use .xcdatamodel"**: 단일 모델 파일을 사용하겠다는 의미로, **버전 관리가 불가능**하다.
- **"Use .xcdatamodeld"**: 패키지 확장자를 사용하며, **버전 관리 기능**을 사용할 수 있다.
- **"Cancel"**: 파일 생성을 취소한다.

###### 5-2-1-1-5. ✅ 권장 사항

- 현재 프로젝트에서는 **`.xcdatamodeld`** 확장자를 사용하는 것이 권장된다.
- 이를 통해 Core Data의 **버전 관리 기능**을 활용할 수 있으며, 데이터 모델 변경 시 문제가 줄어든다.

따라서, 창에서 **"Use .xcdatamodeld"** 옵션을 선택하는 것이 올바른 선택이다.

![CleanShot 2024-11-15 at 00 07 18](https://github.com/user-attachments/assets/cde56b90-e84a-4936-9f80-4031b44642c2)

이렇게 모델링 그대로 설정을 해준다.

이때 Entity 명은 `Cart`로 해준다

#### 5-2-2. Container 생성 및 함수 구현

ViewModel에 Container를 생성하고 이때 init을 통해 ViewModel 객체가 만들어질때 자연스럽게 Container를 생성하는 방식으로 이루어 진다.

##### 5-2-2-1. Container 만들기

```swift
let container: NSPersistentContainer
    
    @Published var cart: [Cart] = []
    
    init() {
        container = NSPersistentContainer(name: "Cart")
        container.loadPersistentStores { (description, error) in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }
    }
```

이렇게 만들어 준다.

Container를 만들면서 init에 집어넣음으로써,

ViewModel이 만들어지면서 Container가 만들어지게 된다.

##### 5-2-2-2. Fetch 함수 구현

```swift
func fetchRequest() {
    let request = NSFetchRequest<Cart>(entityName: "Cart")
    
    do {
        cart = try container.viewContext.fetch(request)
    } catch {
        print("Fetch failed: \(error)")
    }
}
```

뭐 사실 크게 이질적인 부분은 없는듯 하다.

가끔 CoreData의 Entity가 만들어지지 않아 `Cart`를 적어도 없다고 뜨는경우엔 Xcode를 재실행하면 만들어진다.

##### 5-2-2-3. 장바구니 담기 구현

```swift
func addCart(model: WishModel) {
    let item = Cart(context: container.viewContext)
    item.id = Int64(model.id)
    item.title = model.title
    item.price = model.price
    
    saveData()
}
    
func saveData() {
    do {
        try container.viewContext.save()
        fetchRequest() // added
    } catch {
        print("Save failed: \(error)")
    }
}
```

이건 저장하는것도 같이 첨부를 하는데, 이전에도 작성을 해둔적이 있지만, CoreData의 Data가 변할때는 Save를 반드시 해주어야 한다.

(11.16 추가) 그리고 이전에 깜빡하고 적지 않았는데 fetch함수를 추가하여 배열이 업데이트 되도록 하였다.

##### 5-2-2-4. 삭제기능 구현

```swift
func deleteData(object: Cart) {
    container.viewContext.delete(object)
    saveData()
}

func deleteAllData() {
    let request: NSFetchRequest<NSFetchRequestResult> = Cart.fetchRequest()
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
    
    do {
        try container.viewContext.execute(deleteRequest)
        try container.viewContext.save()
    } catch {
        print("Delete failed: \(error)")
    }
}
```

이것도 부분삭제, 전체삭제를 한꺼번에 한다.

전체삭제가 기억나지가 않아서, [참고](https://www.hackingwithswift.com/forums/swiftui/delete-all-item-from-core-data-with-button/16512){:target="_blank"} 글을 보고 적용했다.

이전에도 이부분을 아마 해외사이트 보고 참고해서 적었던 기억이있다.

### 5-3. SwiftData 사용 (11.16 추가)

SwiftData도 사용하면 좋을듯해서 이미 프로젝트파일 자체는 다 만들어졌기에 새롭게 버튼을 하나 추가해서 Coredata저장, SwiftData저장 이렇게 버튼을 나눠본다.

이전에 [글](https://haroldfromk.github.io/posts/SwiftData/){:target="_blank"}을 작성을 해봤기에 그걸 좀 참고하면서 작성하면 더 각인이 되지 않을까 싶다.

#### 5-3-1. 모델링

이전에 만들었던 `CartModel`을 사용하는것보다, 새롭게 만들어서 비교를 하는게 좋을듯해서 새롭게 만들어본다.

![CleanShot 2024-11-16 at 07 34 45](https://github.com/user-attachments/assets/02edfbb9-37c0-4bda-8d86-fa611c9271be)

우선 SwiftData를 사용할때는 `@Model` Wrapper를 사용해준다.

이때 보통 우리가 모델링을 할때는 `struct`를 사용했지만 이녀석은 **`class`를 사용**해줘야한다.

![CleanShot 2024-11-16 at 07 33 42](https://github.com/user-attachments/assets/5c3c801f-c487-4afd-afea-80301084dc7c)

그렇게 바꾸고 나니 이런에러가 난다.

첫번째는 init을 해주지 않아서 발생.

두번째는 Swift6 부터는 에러가 발생할거라고 경고를 준다.

let을 사용하지말라는것이다.

```swift
import SwiftData

@Model
class SDCartModel {
    var id: Int
    var title: String
    var price: Double
    
    init(id: Int, title: String, price: Double) {
        self.id = id
        self.title = title
        self.price = price
    }
}
```

이렇게 작성을 해주면 아주 기본적인 모델링이 완성되고, 모든 에러와 경고가 깔끔하게 사라진다.

이후에 무결성이 필요하다면

`#Unique`나 `@Attribute`를 추가로 사용하겠다.

`@Model`을 사용해준 이유는 해당 클래스가 SwiftData의 데이터 모델로 인식되도록 지정한다. 이를 통해 이 클래스의 인스턴스는 SwiftData에서 관리되는 데이터베이스 엔티티가 된다. (이전 글에서도 서술)

#### 5-3-2. SwiftData용 Button과 View새롭게 추가.

##### 5-3-2-1. SDCartView

```swift
var body: some View {
        VStack {
            List {
                ForEach(cartViewModel.cart, id: \.self) { cart in
                    HStack {
                        Text(cart.title ?? "")
                        Spacer()
                        Text(cart.price.dollarAdd())
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            currentCartItem = cart
                            isDelete.toggle()
                        } label: {
                            Image(systemName: "trash")
                        }
                        
                    }
                }
            }
            .alert("항목 삭제", isPresented: $isDelete) {
                Button("삭제", role: .destructive) {
                    if let item = currentCartItem {
                        cartViewModel.deleteData(object: item)
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 항목을 삭제하시겠습니까?")
            }
        }
        .onAppear {
            cartViewModel.fetchRequest()
        }
    }
```

일단은 기존에 만든 CartView의 내용을 그대로 가져왔다.

아래 서술할 작업들을 해두고 나서 하나씩 수정을 이에 맞게 할생각이다.

##### 5-3-2-2. MainView

```swift
Button {
        cartViewModel.deleteAllData()
    } label: {
        Text("SD장바구니 비우기")
        Image(systemName: "cart.badge.minus")
    }

Tab("SDCart", systemImage: "cart.circle") {
                        SDCartView(cartViewModel: cartViewModel)
                    }
```

이렇게 메뉴와 탭을 하나 더 추가를 해준다.

##### 5-3-2-3. ItemView

여기서는 SwiftData에 추가를 해줄 버튼만 하나 만들어 주면 된다.

```swift
Button {
            
        } label: {
            Text("SD추가")
                .fontWeight(.bold)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(width: UIScreen.main.bounds.width * 0.3, height: UIScreen.main.bounds.height * 0.05)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .foregroundStyle(.red)
                    .opacity(0.5))
        }
//                .alert(isPresented: $isDuplicated) {
//                    Alert(title: Text("중복 확인"),
//                          message: Text("이미 장바구니에 있습니다."))
//                }
```

우선은 이렇게만 뼈대를 해준다.

Frame을 이전에는 버튼이 2개라 90%정도 있으면 좋을듯해서 가로길이의 0.45 였으나, 버튼이 3개므로 0.3을 적용해주었다.

![simulator_screenshot_9CA1BFA6-DC3A-4405-B443-94E204593626](https://github.com/user-attachments/assets/aec08390-0b5c-4e05-a73b-9dbd03b10aa8){: width="50%" height="50%"} 

적용된사진은 다음과 같다.

#### 5-3-3. Container 생성 및 함수 구현

여기서 부터는 [참고글](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-use-mvvm-to-separate-swiftdata-from-your-views){:target="_blank"}을 바탕으로 좀 만들어 보려고한다.

##### 5-3-3-1. Container 만들기

보통은 앱과 똑같은 명의 swift파일에 하는듯하다.

UIKit에서의 AppDelegate와 같은 위치랄까

```swift
@main
struct ApiCartApp: App {
    let container: ModelContainer
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
    
    init() {
        do {
            container = try ModelContainer(for: SDCartModel.self)
        } catch {
            fatalError()
        }
    }
}
```

우선은 이렇게 만들었다.

Container에 들어가는 for는 우리가 만들어둔 모델을 적용하면된다.

~~이때 원래는 `MainView(modelContext: container.mainContext)` 이런식으로 context를 전달해야하는데 아직 완성되지않아서 함수를 구현다 하고 다시 세팅할 예정~~

[Medium](https://medium.com/@dikidwid0/implement-swiftdata-in-swiftui-using-mvvm-architecture-pattern-aa3a9973c87c){:target="_blank"}글을 읽어보는데, Coredata처럼 ViewModel에서도 container init이 가능하다.

그래서 좀 수정을 해본다. 

```swift
@MainActor
class SDCartViewModel: ObservableObject {
    
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    @Published var cart: [SDCartModel] = []
    
    init() {
        self.modelContainer = try! ModelContainer(for: SDCartModel.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.modelContext = modelContainer.mainContext
    }
    
    func fetchRequest() -> [SDCartModel] {
        do {
            return try modelContext.fetch(FetchDescriptor<SDCartModel>())
        } catch {
            fatalError()
        }
    }
}
```

이렇게 적용하게되면 처음에 App.swift에서는 만들 필요가 없어진다.

그래서 지웠다.

`isStoredInMemoryOnly: true`?

| 속성                   | 설명                                           | `true`일 때                              | `false`일 때                        |
| ---------------------- | ---------------------------------------------- | ---------------------------------------- | ---------------------------------- |
| `isStoredInMemoryOnly` | 메모리에만 데이터를 저장할지 여부 설정           | 메모리에만 저장하고, 디스크에 저장하지 않음 | 디스크에 영구적으로 데이터를 저장함 |
| **장점**               | 빠른 데이터 접근 속도                          | 테스트 용도 또는 임시 데이터 처리에 적합  | 영구적인 데이터 저장 가능           |
| **단점**               | 데이터 영구성                                   | 앱 종료 시 데이터 손실                   | 디스크 I/O로 인해 성능 저하 가능    |
| **사용 예시**          | 용도                                           | 테스트 및 임시 데이터                    | 실제 사용자 데이터, 영구적 저장 필요 |

##### 5-3-3-2. Fetch 함수 구현

~~크게 Fetch 함수에 대해선 없는게 그냥 우리가 만든 배열에 저장이되고 그걸 그냥 가져다 쓰면 된다.~~

```swift
func fetchRequest() {
        do {
            cart = try modelContext.fetch(FetchDescriptor<SDCartModel>())
        } catch {
            fatalError()
        }
    }
```

특이한 점이라면 request가 아닌 [FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor){:target="_blank"}를 사용했다는 점.

Docs를 보게 되면 애초에 Fetch를 하면서 원하는 조건을 설정하여 가져올 수 있게 되어있다.

두개 차이는 아래에서 추후 서술.

##### 5-3-3-3. 장바구니 담기 구현

```swift
func addCart(model: WishModel) {
        let item = SDCartModel(id: model.id, title: model.title, price: model.price)
        modelContext.insert(item)
        saveCart()
    }

func saveCart() {
        do {
            try modelContext.save()
            fetchRequest()
        } catch {
            fatalError()
        }
    }
```

CoreData와 거의 유사 딱히 서술할점은 없어보인다.

##### 5-3-3-4. 삭제기능 구현

```swift
func deleteCart(object: SDCartModel) {
        modelContext.delete(object)
        saveCart()
    }
```

전체삭제는 [참고글](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-delete-all-instances-of-a-particular-model){:target="_blank"}을 보고 작성한다.

```swift
func deleteAllCart() {
        do {
            try modelContext.delete(model: SDCartModel.self)
            saveCart()
        } catch {
            fatalError()
        }
    }
```

---

## 6. 담기 기능 적용하기.

### 6-1. CoreData

생각을 해보니 ViewModel을 가져다 적용을하는데

Navigation Toolbar는 DisplayView에 담기버튼은 ItemView에 있다.

일단은 진행을 해보자, 어차피 CoreData에 있는걸 배열로 가져오는것이기에 크게 문제는 없어보인다. (1차생각)

우선은 직관적으로 보이기 쉬운 ItemView에서 먼저 기능을 구현해보기로 한다.

```swift
@StateObject var cartViewModel = CartViewModel()

Button {
        cartViewModel.addCart(model: wishViewModel.wishList.first!)
    }
```

이렇게 해주었다.

#### 6-1-1. 저장경로 확인하기

이전에는 `print(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask))`

이걸통해서 확인했는데, 그대로 한번 적용해서 되는지 확인해보자.

경로 바로 이동하는건 **Command + Shift + G**

sqlViewer에서는 안보여서 그냥 바로 다음스텝으로 간다.

#### 6-1-2. 두번째 화면에서 List를 통해 가져오기

```swift
struct CartView: View {
    @StateObject var cartViewModel = CartViewModel()
    
    var body: some View {
        VStack {
            List(cartViewModel.cart) { cart in
                HStack {
                    Text(cart.title ?? "")
                    Spacer()
                    Text(cart.price.dollarAdd())
                }
            }
        }
    }
}
```

기존 두번째 화면에서 viewModel 쪽만 추가.

![Simulator Screenshot - iPhone 16 Pro - 2024-11-15 at 04 00 51](https://github.com/user-attachments/assets/262bc131-93c3-4cfe-a557-ee28a0f35b14){: width="50%" height="50%"} 

추가했던게 잘 나오고 있었다.

안되는줄알고 무지성으로 눌렀더니 중복 문제가 발생.

```text
ForEach<Array<Cart>, Int64, HStack<TupleView<(Text, Spacer, Text)>>>: the ID 116 occurs multiple times within the collection, this will give undefined results!
```

예외처리는 추후에 다시 하는걸로.

![CleanShot 2024-11-16 at 12 40 10](https://github.com/user-attachments/assets/edd97ef4-a449-4e19-9d6e-0e0e569248df)
(11.16 사진 추가)

### 6-2. SwiftData

(11.16 추가)
이제 추가를 해보는 단계이다.

#### 6-2-1. ItemView에 Viewmodel 추가

```swift
@StateObject var sdCartViewModel: SDCartViewModel

Button {
        sdCartViewModel.addCart(model: wishViewModel.wishList.first!)
    } label: {
        Text("SD추가")
            .fontWeight(.bold)
            .font(.headline)
            .foregroundStyle(.black)
            .frame(width: UIScreen.main.bounds.width * 0.3, height: UIScreen.main.bounds.height * 0.05)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .foregroundStyle(.red)
                .opacity(0.5))
    }
```

이렇게 해주었다. 당연히 의존성 주입을 위해 MainView에는

```swift
@StateObject var sdCartViewModel = SDCartViewModel()

Button {
        sdCartViewModel.deleteAllCart()
    } label: {
        Text("SD장바구니 비우기")
        Image(systemName: "cart.badge.minus")
    }

Tab("Display", systemImage: "eye") {
                        ItemView(wishViewModel: wishViewModel,
                                 cartViewModel: cartViewModel,
                                 sdCartViewModel: sdCartViewModel)
                    }
```

이렇게 적용을 해주었다.

#### 6-2-2. SDCartView 적용

```swift
@StateObject var sdCartViewModel: SDCartViewModel
```
viewmodel을 전달해주니 바로 적용이된다.

![simulator_screenshot_F2CC8B96-8A72-4509-9032-5D4327FF01B2](https://github.com/user-attachments/assets/3976cecb-610d-4307-97c1-9b4b0a7eccea){: width="50%" height="50%"}![simulator_screenshot_67511425-DFD8-4CD7-8412-56DBC65BE7E0](https://github.com/user-attachments/assets/6185da6e-f315-4351-a951-3ab6abe1add3){: width="50%" height="50%"} 

움짤 귀찮아서 패스

이제 기능을 적용해보자.

```swift
struct SDCartView: View {
    @StateObject var sdCartViewModel: SDCartViewModel
    
    @State private var isDelete = false
    @State private var currentCartItem: SDCartModel?
    
    var body: some View {
        VStack {
            List {
                ForEach(sdCartViewModel.cart, id: \.self) { cart in
                    HStack {
                        Text(cart.title)
                        Spacer()
                        Text(cart.price.dollarAdd())
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            currentCartItem = cart
                            isDelete.toggle()
                        } label: {
                            Image(systemName: "trash")
                        }
                        
                    }
                }
            }
            .alert("항목 삭제", isPresented: $isDelete) {
                Button("삭제", role: .destructive) {
                    if let currentCartItem {
                        sdCartViewModel.deleteCart(object: currentCartItem)
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 항목을 삭제하시겠습니까?")
            }
        }
        .onAppear {
            sdCartViewModel.fetchRequest()
        }
    }
}
```

완료.

이전에 Coredata할때 처럼 중복추가에 대해서도 적용을 해본다.

```swift
 f let checkTitle = wishViewModel.wishList.first?.title {
                        isDuplicated = sdCartViewModel.checkDuplicate(title: checkTitle)
                        if isDuplicated == false {
                            sdCartViewModel.addCart(model: wishViewModel.wishList.first!)
                        }
                    } else {
                        print("Title does not exist")
                    }
```

코드는 동일

![simulator_screenshot_88963A3B-BF04-4F94-8217-3B168BE88FD7](https://github.com/user-attachments/assets/d0532950-7e94-4bb7-b24e-b5924343e304){: width="50%" height="50%"} 

작동 확인 완료.

![CleanShot 2024-11-16 at 12 38 58](https://github.com/user-attachments/assets/b8a405e0-15be-4ce7-a3ec-13feba5a9e58)

이렇게 확인도 된다.

---

## 7. SwipeAction을 통한 삭제기능 구현

로드되는것도 확인이 되었으니 이제 swipeaction을 통해 삭제를 해보자.

```swift
var body: some View {
        VStack {
            List {
                ForEach(cartViewModel.cart, id: \.self) { cart in
                    HStack {
                        Text(cart.title ?? "")
                        Spacer()
                        Text(cart.price.dollarAdd())
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            cartViewModel.deleteData(object: cart)
                        } label: {
                            Image(systemName: "trash")
                        }

                    }
                }
            }
        }
    }
```

이렇게 swipeaction을 추가해주었다.

삭제는 되는데 문제는 바로 업데이트가 되지않고, 재실행을 해야 지워진게 확인됨을 알았다.

그리고 추가를하고 탭뷰를 눌러서 카트를 가보면 UIUpdate가 되지않기에 onappear를 사용했다.

```swift
struct CartView: View {
    @StateObject var cartViewModel = CartViewModel()
    
    var body: some View {
        VStack {
            List {
                ForEach(cartViewModel.cart, id: \.self) { cart in
                    HStack {
                        Text(cart.title ?? "")
                        Spacer()
                        Text(cart.price.dollarAdd())
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            cartViewModel.deleteData(object: cart)
                            cartViewModel.fetchRequest()
                        } label: {
                            Image(systemName: "trash")
                        }

                    }
                }
            }
        }
        .onAppear {
            cartViewModel.fetchRequest()
        }
    }
}
```

![Nov-15-2024 04-14-00](https://github.com/user-attachments/assets/e33f7074-ff79-4f0e-b3a4-6860edbf38aa){: width="50%" height="50%"} 

우선 작동은 완료.

사진을 다시보니 CartView 쪽에선 navigation tab bar가 보이지 않아서 지우고 MainView에 통합시킨다.

```swift
struct MainView: View {
    var body: some View {
        NavigationStack {
            Text("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                print("added")
                            } label: {
                                Text("추가하기")
                                Image(systemName: "cart.badge.plus")
                            }
                            Button {
                                print("deleted")
                            } label: {
                                Text("장바구니 비우기")
                                Image(systemName: "cart.badge.minus")
                            }
                        } label: {
                            Image(systemName: "cart")
                        }

                    }
            }
            NavigationView {
                TabView {
                    Tab("Display", systemImage: "eye") {
                        ItemView()
                    }
                    Tab("cart", systemImage: "cart") {
                        CartView()
                    }
                }
            }
        }
        
    }
}
```

사진은 패스.

NavigationView가 의미없이 사용이되어 개선을 한다 (11.16)

```swift
struct MainView: View {
    @StateObject var wishViewModel = WishViewModel()
    @StateObject var cartViewModel = CartViewModel()
    @StateObject var sdCartViewModel = SDCartViewModel()

    var body: some View {
        NavigationStack {
            TabView {
                Tab("Display", systemImage: "eye") {
                    ItemView(wishViewModel: wishViewModel,
                             cartViewModel: cartViewModel,
                             sdCartViewModel: sdCartViewModel)
                }
                Tab("CoreCart", systemImage: "cart") {
                    CoreCartView(cartViewModel: cartViewModel)
                }
                Tab("SDCart", systemImage: "cart.circle") {
                    SDCartView(sdCartViewModel: sdCartViewModel)
                }
                Tab("Test", systemImage: "star") {
                    TestView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            cartViewModel.deleteAllData()
                        } label: {
                            Text("Core 장바구니 비우기")
                            Image(systemName: "cart.badge.minus")
                        }
                        Button {
                            sdCartViewModel.deleteAllCart()
                        } label: {
                            Text("SD 장바구니 비우기")
                            Image(systemName: "cart.badge.minus")
                        }
                    } label: {
                        Image(systemName: "cart")
                    }
                }
            }
        }
    }
}
```

개선 이유중 하나는 TestView에는 필요가 없는것도 있다.

---

## 8. 전체 삭제 적용

```swift
toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    print("added")
                } label: {
                    Text("추가하기")
                    Image(systemName: "cart.badge.plus")
                }
                Button {
                    cartViewModel.deleteAllData()
                } label: {
                    Text("장바구니 비우기")
                    Image(systemName: "cart.badge.minus")
                }
            } label: {
                Image(systemName: "cart")
            }

        }
}
```

우선 전체 삭제는 되지만, View가 서로 달라서 CartView가 활성화 된상태에서 비우면 바로 적용이 안되는 문제가 있다.

---

## 9. CoreData vs SwiftData

비교는 내가 작성한 코드와 간단하게 정리한것을 바탕으로 GPT를 통해 정리해달라고 했다.

** CoreData와 SwiftData 비교 표 **

| 항목                    | CoreData (`NSPersistentContainer`)             | SwiftData (`ModelContainer`)              |
| ----------------------- | ---------------------------------------------- | ----------------------------------------- |
| **데이터 컨테이너**     | `NSPersistentContainer` 사용                    | `ModelContainer` 사용                      |
| **데이터 컨텍스트**     | `viewContext` 사용                              | `mainContext` 사용                         |
| **컨테이너 초기화**     | `loadPersistentStores()`로 로드                  | `try! ModelContainer()`로 간단히 초기화   |
| **메모리 저장 옵션**    | 메모리 전용 옵션 없음                           | `isStoredInMemoryOnly` 옵션 지원           |
| **Fetch 요청**          | `NSFetchRequest` 사용                           | `FetchDescriptor` 사용                     |
| **데이터 삽입**         | `NSManagedObject` 인스턴스 생성 후 삽입         | Swift 구조체 인스턴스를 생성 후 삽입       |
| **데이터 삭제**         | `NSBatchDeleteRequest` 등을 사용하여 삭제       | `modelContext.delete()` 메서드 사용        |
| **저장 방식**           | SQLite 데이터베이스 (`.sqlite`) 파일로 저장      | SQLite 데이터베이스 (`.store`) 파일로 저장  |
| **모델 정의 방식**      | `.xcdatamodeld` 파일에서 엔티티 정의             | Swift 구조체 및 `@Model` 어노테이션 사용   |
| **SwiftUI 통합**        | ObservableObject로 사용 가능하지만 별도 설정 필요 | SwiftData는 SwiftUI와 원활하게 통합됨      |

위의 표는 GPT에게 viewmodel로 만든 코드를 비교하여 정리를 해달라고 한것이다.

### 9-1. 모델링

CoreData는 CoreData를 사용하기위한 별도의 `.xcdatamodeld`파일 생성이 필요하다.

![CleanShot 2024-11-15 at 00 07 18](https://github.com/user-attachments/assets/cde56b90-e84a-4936-9f80-4031b44642c2)

그리고 그에따른 Model를 만들어줘야한다.

```swift
struct CartModel: Identifiable {
    let id: Int
    let title: String
    let price: Double
}
```

하지만 SwiftData는 파일을 만들 필요가 없고,

```swift
import SwiftData

@Model
class SDCartModel {
    var id: Int
    var title: String
    var price: Double
    
    init(id: Int, title: String, price: Double) {
        self.id = id
        self.title = title
        self.price = price
    }
}
```

이렇게 모델링을 해주는것만으로도 해결이 된다.

#### 9-1-1. 정리

CoreData와 SwiftData의 모델 정의 방식의 차이를 아래 표로 정리함. CoreData는 `.xcdatamodeld` 파일이 필요하지만, SwiftData는 Swift 코드 내에서 직접 모델을 정의할 수 있다.

| 항목                    | CoreData                                      | SwiftData                                      |
| ----------------------- | --------------------------------------------- | ---------------------------------------------- |
| **모델 파일 필요 여부** | 별도의 `.xcdatamodeld` 파일 필요                | Swift 코드에서 직접 정의, 추가 파일 필요 없음   |
| **모델 정의 방식**      | `.xcdatamodeld`에서 엔티티와 속성 정의         | Swift 클래스/구조체에 `@Model` 어노테이션 사용  |
| **초기화 방식**         | `NSManagedObject` 클래스 상속, `context` 필요   | 일반 Swift 클래스, Swift 초기화 방식 사용       |
| **코드 간결성**         | `.xcdatamodeld` 파일과 코드로 분리됨            | Swift 코드만으로 정의 가능, 간결하고 직관적임   |
| **Swift 언어 특징 사용**| Swift의 타입 안전성 및 구조체 사용 어려움       | Swift의 기본 타입과 초기화 메서드 사용 가능     |

##### 9-1-1-1. 부연 설명

1. **모델 파일 생성 필요 여부**:
   - **CoreData**는 `.xcdatamodeld` 파일을 통해 모델 구조를 시각적으로 정의함. 이 파일에서 모든 엔티티와 속성을 정의하고, 자동 생성된 `NSManagedObject` 서브클래스를 사용해야 함.
   - **SwiftData**는 별도의 모델 파일 없이, Swift 코드에서 직접 모델 정의가 가능함. 이를 통해 Swift 언어의 타입 안전성과 구조체 사용이 가능함.

2. **코드의 간결성**:
   - CoreData는 모델 정의가 `.xcdatamodeld` 파일과 코드로 분리되어 있어, 코드 간결성이 떨어지고, 변경 시 파일과 코드 모두 수정해야 함.
   - SwiftData는 코드 내에서 모든 모델 정의가 가능해, 코드가 더 직관적이고 간결함.

3. **초기화 방식**:
   - CoreData는 `context`를 필요로 하는 `NSManagedObject` 초기화 방식을 사용함.
   - SwiftData는 일반 Swift 클래스의 초기화 방식을 따르며, `context`를 명시할 필요가 없음.

##### 9-1-1-2. 결론

- **CoreData**는 전통적인 방식으로, 시각적인 모델링과 복잡한 설정이 필요할 때 유리함.
- **SwiftData**는 최신 Swift 언어의 특징을 잘 반영하고 있으며, 더 간단하고 간결한 코드로 정의 가능함.

이건 GPT를 통해 정리를 한 내용.

### 9-2. Container

우선 Container 생성을 할때 CoreData는 xcdatamodeld 파일을 만들고 거기 안에 있는 Entity의 명을 제대로 적어 줘야한다.

![CleanShot 2024-11-16 at 12 57 07](https://github.com/user-attachments/assets/bfed402e-5449-4b02-9fe5-82a8ca56f1c5)

하지만 SwiftData는 우리가 만든 데이터 모델을이 들어간다.

그리고 메모리 저장을 할지 말지(`isStoredInMemoryOnly`)에 대한 차이가 가장 크다.

저장되는 파일이 조금 다르다.

![CleanShot 2024-11-16 at 12 59 07](https://github.com/user-attachments/assets/3cd42179-3460-4f50-929b-d5b6cf3badad)

CoreData는 `.sqlite`이고 SwiftData는 `.store`파일이다.

물론 두개다 Viewer 프로그램을 통해 확인이 가능하다.

#### 9-2-1. 정리

| 항목                    | CoreData                                      | SwiftData                                      |
| ----------------------- | --------------------------------------------- | ---------------------------------------------- |
| **모델 정의 방식**      | `.xcdatamodeld` 파일 필요, 엔티티 이름을 지정  | Swift 클래스/구조체를 직접 지정 (`@Model`)       |
| **초기화 방식**         | `NSPersistentContainer`와 `loadPersistentStores()` 사용 | `try! ModelContainer()`로 간단하게 초기화       |
| **메모리 저장 옵션**    | 메모리 전용 저장 옵션 없음                     | `isStoredInMemoryOnly` 옵션 지원                |
| **저장 파일 확장자**    | `.sqlite` (`Model.sqlite`)                    | `.store` (`default.store`)                      |
| **파일 뷰어 프로그램**  | `.sqlite` 파일은 SQLite Viewer로 확인 가능     | `.store` 파일도 SQLite Viewer로 확인 가능        |

##### 9-2-1-1. 부연 설명

1. **모델 정의 방식**:
   - **CoreData**는 `.xcdatamodeld` 파일을 생성하고, 그 안에 엔티티(Entity)와 속성을 정의함. 컨테이너 초기화 시 `.xcdatamodeld` 파일 이름을 정확히 지정해야 함.
   - **SwiftData**는 Swift 코드 내에서 직접 데이터 모델을 정의하며, `@Model` 어노테이션을 사용해 Swift 구조체나 클래스를 모델로 지정함.

2. **메모리 저장 옵션**:
   - **CoreData**는 메모리 전용 저장소 옵션이 없고, 기본적으로 디스크에 데이터를 저장함.
   - **SwiftData**는 `isStoredInMemoryOnly: true` 옵션을 통해 데이터를 메모리에만 저장할 수 있음. 이는 테스트나 임시 데이터 처리 시 유리함.

3. **저장 파일 확장자**:
   - **CoreData**는 SQLite 형식의 데이터베이스를 사용하며, 저장 파일의 확장자는 `.sqlite`임 (`Model.sqlite`).
   - **SwiftData**는 `.store` 확장자를 사용하며 (`default.store`), 더 간단한 파일 형식을 사용함.

4. **파일 뷰어 프로그램**:
   - 두 파일 모두 SQLite 형식이기 때문에, **DB Browser for SQLite**나 **SQLiteStudio** 같은 뷰어 프로그램에서 확인 가능함.

##### 9-2-1-2. 결론

- **CoreData**는 전통적인 방식으로, `.xcdatamodeld` 파일과 SQLite 데이터베이스(`.sqlite`)를 사용함. 더 많은 설정이 필요하지만, 복잡한 데이터 모델링에 유리함.
- **SwiftData**는 간단하고 현대적인 방식으로, Swift 코드에서 직접 모델을 정의하며, 메모리 전용 옵션과 간단한 초기화 방식이 특징임. 더 간결하고 Swift 언어의 특성을 잘 살리고 있음.

위에 Total로 정리한것이랑 중복은 있을것이다. GPT를 통해 정리를 해달라고 했기때문

---

### 9-3. Context

CoreData나 SwiftData 모두 Context를 통해 CRUD를 적용하게된다.

CoreData는 `NSManagedObjectContext`이다.

SwiftData는 `ModelContext`이다.

#### 9-3-1. 정리

CoreData와 SwiftData 모두 **Context**를 사용해 **CRUD (Create, Read, Update, Delete)** 작업을 수행함. CoreData는 `NSManagedObjectContext`를 사용하고, SwiftData는 `ModelContext`를 사용함. 전체 데이터를 삭제할 때 CoreData는 `NSBatchDeleteRequest`와 `execute()` 메서드를 사용하며, SwiftData는 `delete(model:)` 메서드를 사용함.

| 항목                    | CoreData (`NSManagedObjectContext`)           | SwiftData (`ModelContext`)                  |
| ----------------------- | --------------------------------------------- | ------------------------------------------- |
| **Context 타입**       | `NSManagedObjectContext`                      | `ModelContext`                              |
| **데이터 삽입 방식**    | `insert(_:)` 메서드로 `NSManagedObject` 삽입   | `insert(_:)` 메서드로 Swift 구조체 삽입      |
| **데이터 저장 방식**    | `save()` 메서드 호출                           | `save()` 메서드 호출                         |
| **데이터 삭제 방식**    | `delete(_:)` 메서드 호출                       | `delete(_:)` 메서드 호출                     |
| **Fetch 요청**          | `NSFetchRequest` 사용                          | `FetchDescriptor` 사용                       |
| **전체 삭제 방식**      | `NSBatchDeleteRequest`와 `execute()` 메서드 사용 | `delete(model:)` 메서드 사용                |

##### 9-3-1-1. 부연 설명

1. **Context 역할**:
   - **Context**는 데이터의 **일시적인 작업 공간**으로, 메모리에 로드된 데이터를 관리하고, 변경 사항을 추적함. 변경된 데이터를 저장(`save()`)하면 영구 저장소에 반영됨.

2. **CRUD 작업의 일관성**:
   - CoreData와 SwiftData 모두 `Context`를 통해 데이터 삽입(`insert`), 삭제(`delete`), 저장(`save`) 작업을 수행함.
   - CoreData의 `NSManagedObjectContext`는 `NSManagedObject`를 사용해 데이터를 관리함.
   - SwiftData의 `ModelContext`는 Swift 구조체나 클래스를 직접 관리하므로, 타입 안전성이 높고 더 간결함.

3. **전체 데이터 삭제 방식**:
   - **CoreData**는 `NSBatchDeleteRequest`를 사용해 전체 데이터를 삭제함. `NSFetchRequest`로 엔티티를 지정하고, 이를 기반으로 `NSBatchDeleteRequest` 객체를 생성함. 이후 `execute()` 메서드를 호출해 요청을 실행함.
   - **SwiftData**는 `delete(model:)` 메서드를 사용해 간단하게 전체 데이터를 삭제할 수 있음. 모델(`SDCartModel.self`)만 지정하면 되므로 코드가 더 간결함.

4. **SwiftUI와의 통합**:
   - SwiftData의 `ModelContext`는 SwiftUI의 `@Environment`에서 직접 접근할 수 있어, SwiftUI와의 통합이 더 쉬움 (`@Environment(\.modelContext)`).
   - CoreData의 `NSManagedObjectContext`도 SwiftUI와 통합할 수 있지만, `@Environment(\.managedObjectContext)`를 통해 접근해야 하며, 추가적인 설정이 필요할 수 있음.

##### 9-3-1-2. 결론

- **CoreData**는 전통적인 데이터 관리 프레임워크로, `NSManagedObjectContext`를 사용하여 다양한 고급 기능을 제공함. 특히, **`NSBatchDeleteRequest`**와 같은 기능을 통해 대규모 데이터 삭제 시 성능 최적화를 할 수 있음. 그러나 초기 설정이 복잡하고, `.xcdatamodeld` 파일 관리 및 복잡한 API 사용으로 인해 코드가 길어질 수 있음.
- **SwiftData**는 현대적인 Swift 기반의 데이터 관리 프레임워크로, `ModelContext`를 사용하여 더 간결하고 타입 안전한 코드 작성을 가능하게 함. 간단한 **`delete(model:)`** 메서드를 통해 전체 데이터를 삭제할 수 있으며, SwiftUI와의 자연스러운 통합으로 인해 최신 SwiftUI 프로젝트에서 사용하기 적합함.
- SwiftData는 Swift의 기본 타입과 구조체를 직접 사용할 수 있어, 코드의 간결성 및 유지보수성이 높음. 특히, 메모리 전용 옵션(`isStoredInMemoryOnly`)은 테스트 환경에서 유리하며, SwiftUI 환경에서의 개발 생산성을 크게 향상시킴.

따라서:
- 복잡한 데이터 모델과 고급 기능이 필요한 경우에는 **CoreData**가 적합함.
- 간결한 코드, SwiftUI와의 높은 호환성, 그리고 타입 안전성을 중시하는 경우에는 **SwiftData**가 더 적합함.

---

## 10. 문제 해결

크게 3가지 문제가 파악이 되었다.

### 10-1. 중복 문제

```swift
func checkDuplicate(title: String) -> Bool {
        if cart.contains(where: { $0.title == title }) {
            return true
        } else {
            return false
        }
    }
```

다음과 같이 중복확인을 하는 함수를 만들어 주었다.


이걸 통해 true / false 체크하여 Alert를 띄우도록 한다.

그리고 Alert를 띄우기 위해 Button을 약간 수정한다.

```swift
@State var isDuplicated = false

Button {
        isDuplicated = cartViewModel.checkDuplicate(title: wishViewModel.wishList.first?.title ?? "")
        print(wishViewModel.wishList.first?.title)
        print(isDuplicated)
        if !isDuplicated {
            cartViewModel.addCart(model: wishViewModel.wishList.first!)
        }
        
    } label: {
        Text("추가")
            .fontWeight(.bold)
            .font(.headline)
            .foregroundStyle(.black)
            .frame(width: UIScreen.main.bounds.width * 0.45, height: UIScreen.main.bounds.height * 0.05)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .foregroundStyle(.green)
                .opacity(0.5))
    }
    .alert(isPresented: $isDuplicated) {
        Alert(title: Text("중복 확인"),
                message: Text("이미 장바구니에 있습니다."))
    }
```

하지만 계속 false가 뜨는 문제가 발생.

print를 해보니 

`Optional("Knoll Saarinen Executive Conference Chair")` 옵셔널이어서 타입이 달라서 그런건가? 라는 생각이 들어서 옵셔널 바인딩을 해보았으나 실패.

```swift
if let checkTitle = wishViewModel.wishList.first?.title {
                        isDuplicated = cartViewModel.checkDuplicate(title: checkTitle)
                        print(isDuplicated)
                        if !isDuplicated {
                            cartViewModel.addCart(model: wishViewModel.wishList.first!)
                        }
                    } else {
                        print("Title does not exist")
                    }
```

일단 이건 그대로 두는걸로.

`print(cart.map { $0.title ?? "" })`를 해본결과

담기를 했지만 CartViewModel의 cart가 업데이트가 되지 않아서 생긴 문제였다.

```swift
func addCart(model: WishModel) {
        let item = Cart(context: container.viewContext)
        item.id = Int64(model.id)
        item.title = model.title
        item.price = model.price
        
        saveData()
}

func saveData() {
        do {
            try container.viewContext.save()
            fetchRequest()
        } catch {
            print("Save failed: \(error)")
        }
    }
```

추가할때마다 fetchRequest()를 실행하게 해주었다.

아무래도 데이터가 변화가 있을때마다 save와 fetch를 둘다 해야하는듯 하다.

생각해보니 이전에는 배열에 직접 넣어줬기에 관리가 되었는데 지금은 그렇지 않다.

계속 fetchRequest를 하는건 그렇게 좋아보이지는 않는듯하다.

근본적인 방법을 좀 바꿔야할 필요가 있어보인다.

일단은 fetchRequest()를 호출하는 식으로 변경

---

### 10-2. CoreData Warning

```text
CoreData: error: +[Cart entity] Failed to find a unique match for an NSEntityDescription to a managed object subclass
```

아마 이것도 init과 연관이 좀 있어보이는듯 하다.

ViewModel이 메모리가 다른데 CoreData를 공유하기에 발생했던 문제, 즉 init이 여러번 이루어 졌다.

3-2의 문제를 해결하면서 해소. (역시 맞았다.)

---

### 10-3. 전체 삭제 문제 (CartView)

현재 2가지 문제가 있다.

#### 10-3-1. 전체 삭제 후 UI Update 안됨

CartView에서 전체 삭제를 하게되면 view가 업데이트 되지 않는 문제가 있다.

![Nov-15-2024 06-19-26](https://github.com/user-attachments/assets/3f8268f9-4e6b-4778-aa9f-24dde66be119){: width="50%" height="50%"} 

2번 문제를 해결 하면서 자연스럽게 해결.

#### 10-3-2. 카트에 담고 전체삭제후 다시 담을경우 중복 에러 발생

장바구니를 비웠으나 아무래도 배열에 대해 초기화가 되지않아서 생기는 문제로 보인다.

![Nov-15-2024 06-20-17](https://github.com/user-attachments/assets/71725553-7b13-4b08-a50e-9bfddb948ef0){: width="50%" height="50%"} 
 
삭제하는 함수에 `print(cart.map { $0.title ?? "" })`이걸 다시 넣어서 배열을 확인해봐야할듯하다.

배열은 [] 이렇게 빈걸로 나온다.

아무래도 한번 추가를 하고나면 true로 바뀌어서 그런걸로 보인다.

```swift
if let checkTitle = wishViewModel.wishList.first?.title {
                        isDuplicated = cartViewModel.checkDuplicate(title: checkTitle)
                        if !isDuplicated {
                            cartViewModel.addCart(model: wishViewModel.wishList.first!)
                            isDuplicated = false
                        }
                    } else {
                        print("Title does not exist")
                    }
```

추가하고 난뒤 false로 바꿔주기로 결정.

그래도 안된다.

onAppear에 print로 찍어봤지만 false가 뜬다.

문득 각 View 마다 cartViewModel을 인스턴스화 하는데, 그것도 혹시 영향이 있지 않을까라는 생각이 들어서 바꿔본다.

해결이 되었다.

원래는 모든 문제를 해결하고 이후에 하나로 바꿔줄 생각이었는데 이게 문제였다....

그러면서 자연스럽게 전체삭제후 UI가 바뀌지않던 부분도 해결

ViewModel에 대해 각각 CoreData를 공유하더라도 ViewModel이 서로 달랐기에 충돌이 일어나지 않았을까 싶다.

```swift
// MainView
@StateObject var cartViewModel = CartViewModel() 
@ObservedObject var wishViewModel = WishViewModel()

Tab("Display", systemImage: "eye") {
                        ItemView(wishViewModel: wishViewModel,
                                cartViewModel: cartViewModel)
                    }
                    Tab("cart", systemImage: "cart") {
                        CartView(cartViewModel: cartViewModel)
                    }

// ItemView
@StateObject var cartViewModel: CartViewModel
@ObservedObject var wishViewModel: WishViewModel

// CartView
@StateObject var cartViewModel: CartViewModel
```

지금은 MainView에서 ViewModel을 인스턴스화 해서 필요한 Item, CartView에 전달하는 식으로 바꾸었다.

---

### 10-4. SwipeAction시 발생하는 Warning

```text
Attempted to invalidate swipe actions layout for invalid decoration index path: <NSIndexPath: 0x8a8d70bf3cd24cb2> {length = 2, path = 0 - 0}
```

이런 경고가 뜬다.

확인해보니 List의 마지막을 지울때 발생하게 된다.

유효하지 않은 indexpath 에서 유효하지않은 swipeaction이 시도가 되었다는데,

뭔가 삭제하고나서도 swipeaction이 활성화가 되어있는지는 모르겠다.

그래서 삭제할때 Alert를 띄우면 어떨까 싶어서 해보려고한다.

```swift
@State private var isDelete = false
@State private var currentCartItem: Cart?
    
var body: some View {
    VStack {
        List {
            ForEach(cartViewModel.cart, id: \.self) { cart in
                HStack {
                    Text(cart.title ?? "")
                    Spacer()
                    Text(cart.price.dollarAdd())
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        currentCartItem = cart
                        isDelete.toggle()
                    } label: {
                        Image(systemName: "trash")
                    }
                    
                }
            }
        }
        .alert("항목 삭제", isPresented: $isDelete) {
            Button("삭제", role: .destructive) {
                if let item = currentCartItem {
                    cartViewModel.deleteData(object: item)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 항목을 삭제하시겠습니까?")
        }
    }
    .onAppear {
        cartViewModel.fetchRequest()
    }
}
```

![Nov-15-2024 09-41-51](https://github.com/user-attachments/assets/32c8ef86-bef2-4aaf-b137-cd5f75c93448){: width="50%" height="50%"} 

Warning이 더이상 뜨지 않는다.

끝.

검색해도 내용이 없어서 GPT에게 물어봤다.

#### 10-4-1. Alert를 사용했을 때 문제가 해결되는 이유

SwiftUI에서 Alert를 사용하면 스와이프 액션 관련 문제가 해결되는 이유는 **상태 관리와 이벤트 흐름**에 있다. Alert는 SwiftUI에서 **비동기적인 UI 업데이트 문제를 해결**하고, **스와이프 액션이 남아 있는 상태**를 정상적으로 종료시킨다.

##### 10-4-1-1. 문제의 원인

1. **스와이프 액션이 활성화된 상태에서 데이터 삭제**
   - 사용자가 셀을 스와이프한 후, 삭제 버튼을 누르기 전까지 **스와이프 액션이 활성화된 상태로 남아 있다**.
   - 이 상태에서 데이터를 삭제하면, SwiftUI는 **스와이프 액션이 완료되지 않은 상태에서 셀을 제거하려고 시도**하게 된다.
   - 결과적으로 **비정상적인 인덱스 참조 문제**가 발생할 수 있다.

2. **SwiftUI의 비동기 UI 업데이트 문제**
   - Core Data에서 데이터를 삭제하면, 데이터 소스는 **즉시 업데이트**된다.
   - 그러나 SwiftUI의 `List` 뷰는 **UI 업데이트와 스와이프 액션 종료 사이에 시간 차이**가 있을 수 있다.
   - 특히 **마지막 셀을 삭제할 때** 문제가 더 자주 발생한다.

##### 10-4-1-2. Alert가 문제를 해결하는 이유

1. **스와이프 액션 종료**
   - Alert가 표시되면 SwiftUI는 **현재 활성화된 스와이프 액션을 종료**한다.
   - SwiftUI는 Alert가 표시되는 동안 **사용자 인터랙션을 차단**하고, 스와이프 액션이 비활성화된다.
   - 이를 통해, **스와이프 액션이 남아 있는 문제**가 방지된다.

2. **UI 업데이트 타이밍 안정화**
   - Alert가 표시되면서 SwiftUI는 **UI 업데이트 흐름을 차단**하고, 데이터가 안전하게 변경될 시간을 제공한다.
   - 사용자가 Alert에서 "삭제"를 선택하면, 이 시점에서 SwiftUI는 **안정된 상태에서 데이터를 업데이트**할 수 있다.
   - 이로 인해 `List` 뷰와 데이터 소스 간의 불일치 문제가 해결된다.

#### 10-4-2. 결론

- Alert는 **스와이프 액션을 종료하고**, SwiftUI가 안정적인 상태에서 **UI 업데이트를 수행**할 수 있도록 돕는다.
- Alert가 표시되면서 **사용자 인터랙션이 차단**되고, 스와이프 액션도 정상적으로 종료된다.
- 이를 통해 **비동기 UI 업데이트 문제**와 **데이터 간 불일치 문제**가 해결된다.

---

## 11. 테스트

여기서 말하는 테스트는 글을 작성하면서 제일 처음에 적었던

`@ObservableObject, @StateObject` 이것에 대해서 해보려고한다.

이 앱을 하려고한건 

처음 생각은 이랬다. 

>화면하나에 api를 호출하는게 있고 위에 장바구니 초기화 버튼이 있다.
>> api조회를 한 결과가 화면에 있고 장바구니 초기화를 눌렀을때 api결과가 그대로인상태에서 장바구니가 초기화되면 stateobject
>> api조회를 한 결과가 화면에 있고 장바구니 초기화를 눌렀을때 api결과가 초기화되고 장바구니가 초기화되면 observedobject

이런 개념으로 좀 테스트를 해보려고 한것이었다.

근데 만들다보니 장바구니 초기화를 하면서 view의 변화가 없다.

원래 의도는 장바구니를 초기화하게되었을때 api도 초기화 되면서 새롭게 리로드를 하는걸 상상했는데

구현하다보니 의도와 다르게 코드가 작성이 되어버렸다.

새롭게 뷰를 만들어서 진행한다.

그동안 긴글 작성하느라 지쳐서 GPT한테 기본적인 틀을 만들어 달라고 한뒤, 세부적인 것을 계속 손봤다.

```swift
struct TestView: View {
    @ObservedObject var cartViewModel = CartViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("TestView - API 조회 및 장바구니 테스트")
                .font(.headline)

            // 독립적인 API 조회 뷰
            ApiDataSubview(cartViewModel: cartViewModel)
            // 독립적인 장바구니 조작 뷰
            Text("장바구니 내용")
                .font(.headline)

            List(cartViewModel.cart, id: \.self) { item in
                Text(item.title ?? "No Title")
            }

            Button("장바구니 초기화") {
                cartViewModel.deleteAllData()
            }
            .padding()
        }
    }
}

struct ApiDataSubview: View {
    //@ObservedObject var testWishViewModel = TestWishViewModel()
    @StateObject var testWishViewModel = TestWishViewModel()
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack {
            Text("API 조회 결과")
                .font(.headline)

            // API 데이터 리스트
            List(testWishViewModel.wishList, id: \.id) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // API 조회 버튼
            Button("API 조회") {
                Task {
                    await testWishViewModel.fetchWishList()
                }
            }
            .padding()
        }
        .border(Color.blue, width: 2)
    }
}
```

이게 최종적으로 만들어진 코드.

여러 시행착오가 있었다.

---

### 11-1. 시행착오

#### 11-1-1. MainView → TestView 로 ViewModel 전달

```swift
// MainView
Tab("Test", systemImage: "star") {
                    TestView(wishViewModel: wishViewModel,
                             cartViewModel: cartViewModel)
                }

struct TestView: View {
    @ObservedObject var wishViewModel: WishViewModel
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("TestView - API 조회 및 장바구니 테스트")
                .font(.headline)

            // API 데이터 표시 및 추가 버튼
            List(wishViewModel.wishList, id: \.id) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // API 조회 버튼
            Button("API 조회") {
                Task {
                    await wishViewModel.fetchWishList()
                }
            }
            .padding()

            // 장바구니 초기화 버튼
            Button("장바구니 초기화") {
                cartViewModel.deleteAllData()
            }
            .padding()

            // 장바구니 데이터 표시
            Text("장바구니 내용")
                .font(.headline)
            List(cartViewModel.cart, id: \.self) { item in
                Text(item.title ?? "No Title")
            }
        }
        .onAppear {
            Task {
                await wishViewModel.fetchWishList()
            }
        }
    }
}
```

실패.

![Nov-15-2024 11-23-37](https://github.com/user-attachments/assets/910afdf8-25ab-4924-a2e6-ff13a7fe446b){: width="50%" height="50%"} 

변화가 없음.

#### 11-1-2. TestView에서 자체 Instance 생성

```swift
struct TestView: View {
    @StateObject var wishViewModel = WishViewModel() // 독립적인 인스턴스 생성
    @StateObject var cartViewModel = CartViewModel() // 독립적인 인스턴스 생성

    var body: some View {
        VStack(spacing: 20) {
            Text("TestView - 독립적인 뷰 모델 사용")
                .font(.headline)

            // API 데이터 표시 및 장바구니 담기 버튼
            List(wishViewModel.wishList, id: \.id) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                }
            }

            // API 조회 버튼
            Button("API 조회") {
                Task {
                    await wishViewModel.fetchWishList()
                }
            }
            .padding()

            // 장바구니 초기화 버튼
            Button("장바구니 초기화") {
                cartViewModel.deleteAllData()
            }
            .padding()

            // 장바구니 데이터 표시
            Text("장바구니 내용")
                .font(.headline)
            List(cartViewModel.cart, id: \.self) { item in
                Text(item.title ?? "No Title")
            }
        }
        .onAppear {
            Task {
                await wishViewModel.fetchWishList()
            }
        }
    }
}
```

![Nov-15-2024 11-26-23](https://github.com/user-attachments/assets/d77d2488-42f7-4cf9-981f-75c254f8a034){: width="50%" height="50%"} 

결과는 상동.

#### 11-1-3. TestView 강제 렌더링

```swift
@State private var forceRefreshId = UUID() // 뷰의 강제 재생성을 위한 ID

var body: some View {
    VStack {
        Button("TestView 강제 초기화") {
            forceRefreshId = UUID() // 새로운 UUID로 업데이트하여 뷰를 강제 초기화
        }
        TestView()
            .id(forceRefreshId) // ID가 변경되면 뷰가 강제로 재생성됨
    }
}
```

이건 뷰를 새롭게 렌더링하면서 인스턴스를 새로 생성하는것.

이건 새롭게 렌더링 하면서 onAppear를 통해 새롭게 렌더링을 하므로

wrapper와 상관없이 API결과가 계속 달라진다.

![Nov-15-2024 11-34-07](https://github.com/user-attachments/assets/d7425f9f-3e48-4e87-8653-832d660c6128){: width="50%" height="50%"} 

그래서 onAppear를 빼보았다.

![Nov-15-2024 11-35-36](https://github.com/user-attachments/assets/3cc54700-62b7-4257-b849-d880f59ea96e){: width="50%" height="50%"} 

조회 결과가 사라진다.

왜냐 새롭게 뷰가 렌더링 되었지만 fetch를 하지 않았기 때문.

#### 11-1-4. 이전에 참고했던 글과 유사한 방식으로 재시도

RandomNumberView의 자식뷰로 CounterView가 있었던걸 생각해서 그렇게 구현을 해보았다.

```swift
struct TestView: View {
    //@StateObject var wishViewModel = WishViewModel() // 테스트 1: 유지되는 경우
    @ObservedObject var wishViewModel = WishViewModel() // 테스트 2: 초기화되는 경우
    @ObservedObject var cartViewModel = CartViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("TestView - API 조회 및 장바구니 테스트")
                .font(.headline)

            // 독립적인 API 조회 뷰
            ApiDataSubview(wishViewModel: wishViewModel)

            // 독립적인 장바구니 조작 뷰
            CartDataSubview(cartViewModel: cartViewModel)
        }
    }
}

struct ApiDataSubview: View {
    @ObservedObject var wishViewModel: WishViewModel
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack {
            Text("API 조회 결과")
                .font(.headline)

            // API 데이터 리스트
            List(wishViewModel.wishList, id: \.id) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // API 조회 버튼
            Button("API 조회") {
                Task {
                    await wishViewModel.fetchWishList()
                }
            }
            .padding()
        }
        .border(Color.blue, width: 2)
    }
}

struct CartDataSubview: View {
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack {
            Text("장바구니 내용")
                .font(.headline)

            List(cartViewModel.cart, id: \.self) { item in
                Text(item.title ?? "No Title")
            }

            Button("장바구니 초기화") {
                cartViewModel.deleteAllData()
            }
            .padding()
        }
        .border(Color.green, width: 2)
    }
}
```

![Nov-15-2024 12-00-35](https://github.com/user-attachments/assets/7761daff-739d-4016-8f96-a9689f906610){: width="50%" height="50%"} 

영향이 없다.

#### 11-1-5. CartDataSubView를 제거 (최종)

##### 11-1-5-1. **`TestView`**

- `@ObservedObject var cartViewModel = CartViewModel()`으로 선언하여 **CartViewModel** 인스턴스는 `TestView`에서 직접 생성.
- `ApiDataSubview`와 독립적인 **장바구니 데이터를 표시**하는 UI로 구성.
- "장바구니 초기화" 버튼을 통해 장바구니 데이터를 삭제.

```swift
struct TestView: View {
    @ObservedObject var cartViewModel = CartViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("TestView - API 조회 및 장바구니 테스트")
                .font(.headline)

            // 독립적인 API 조회 뷰
            ApiDataSubview(cartViewModel: cartViewModel)
            // 독립적인 장바구니 조작 뷰
            Text("장바구니 내용")
                .font(.headline)

            List(cartViewModel.cart, id: \.self) { item in
                Text(item.title ?? "No Title")
            }

            Button("장바구니 초기화") {
                cartViewModel.deleteAllData()
            }
            .padding()
        }
    }
}
```

##### 11-1-5-2. **`ApiDataSubview`**

- `@StateObject var testWishViewModel = TestWishViewModel()`으로 선언하여 **TestWishViewModel** 인스턴스는 `ApiDataSubview`에서 직접 생성.
- **API 조회 결과**를 표시하고, "담기" 버튼을 통해 장바구니에 아이템을 추가.
- `@StateObject`를 사용함으로써, **`testWishViewModel` 인스턴스가 유지**됨.

```swift
struct ApiDataSubview: View {
    //@ObservedObject var testWishViewModel = TestWishViewModel()
    @StateObject var testWishViewModel = TestWishViewModel()
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack {
            Text("API 조회 결과")
                .font(.headline)

            // API 데이터 리스트
            List(testWishViewModel.wishList, id: \.id) { item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // API 조회 버튼
            Button("API 조회") {
                Task {
                    await testWishViewModel.fetchWishList()
                }
            }
            .padding()
        }
        .border(Color.blue, width: 2)
    }
}
```

#### 11-1-6. 🏆 성공 요인

| 요인                       | 설명                                                                                      |
| -------------------------- | ----------------------------------------------------------------------------------------- |
| 1. **`@StateObject` 사용** | `ApiDataSubview`에서 **`@StateObject`**로 선언한 `testWishViewModel`은 인스턴스가 유지됨.  |
| 2. **독립적인 서브 뷰 구조** | `ApiDataSubview`와 장바구니 표시 뷰를 **독립적인 서브 뷰로 분리**하여 각각의 상태를 독립적으로 관리. |
| 3. **`@ObservedObject`로 전달된 인스턴스** | `CartViewModel`은 `TestView`에서 생성되어 **재렌더링 시 초기화되지 않음**.                          |
| 4. **뷰의 생명주기 차이 확인 가능** | `@StateObject`는 **뷰의 처음 생성 시 한 번만 초기화**, `@ObservedObject`는 **뷰가 재렌더링 시마다 초기화**됨. |

##### 11-1-6-1. 🎯 테스트 결과 비교

| 선언 방식         | `testWishViewModel` 초기화 여부 | API 조회 결과 유지 여부 | 장바구니 데이터 유지 여부 |
| ----------------- | ------------------------------ | ----------------------- | ------------------------ |
| `@StateObject`    | ❌ (한 번만 초기화됨)          | ✅ (유지됨)              | ✅ (유지됨)               |
| `@ObservedObject` | ✅ (재렌더링 시 초기화됨)      | ❌ (초기화됨)            | ✅ (유지됨)               |

##### 11-1-6-2. 결론

1. `@StateObject`는 **뷰의 생명주기 동안 인스턴스를 유지**하므로, API 조회 결과가 유지.
2. `@ObservedObject`는 **뷰가 재렌더링될 때마다 인스턴스를 새로 생성**하므로, API 조회 결과가 초기화.

---

## 12. 결과

### 12-1. ObservedObject

![Nov-15-2024 11-55-47](https://github.com/user-attachments/assets/830126b9-5924-48ca-9842-dbe30c097f7e){: width="50%" height="50%"} 


```swift
struct ApiDataSubview: View {
    @ObservedObject var testWishViewModel = TestWishViewModel()
```

장바구니 UI가 변하면서 api를 재호출함.

재호출 하는 이유는 새롭게 만든 ViewModel에 

```swift
@MainActor
class TestWishViewModel: ObservableObject {
    @Published var wishList = [WishModel]()

    init() {
        Task {
            await fetchWishList()
        }
    }

    func fetchWishList() async {
        let randomNumber: Int = Int.random(in: 1...194)
        let url: String = "https://dummyjson.com/products/\(randomNumber)"
        guard let list: WishModel = await WishService().downLoadData(url: url) else { return }

        wishList = [list]
    }
}
```

이렇게 init을 해주었기 때문.

init을 하지않고 기존에 만들어둔 WishViewModel을 사용하면 wishList가 빈배열이므로 아무 결과도 나오지 않는다.

### 12-2. @StateObject

```swift
struct ApiDataSubview: View {
    @StateObject var testWishViewModel = TestWishViewModel()
```

![Nov-15-2024 11-54-13](https://github.com/user-attachments/assets/090fd539-765b-4981-8727-65ef68964574){: width="50%" height="50%"} 

장바구니 UI가 변해도 API 조회 결과가 그대로 유지된다.

### 12-3. 한화면에 보여지게 수정

```swift
struct TestView: View {
    @ObservedObject var cartViewModel = CartViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                // ObservedObject 섹션
                VStack {
                    Text("ObservedObject - API 조회")
                        .font(.headline)
                    ApiDataSubview(cartViewModel: cartViewModel)
                        .frame(height: 180)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

                // StateObject 섹션
                VStack {
                    Text("StateObject - API 조회")
                        .font(.headline)
                    ApiStateSubview(cartViewModel: cartViewModel)
                        .frame(height: 180)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)

                // 장바구니 내용 섹션
                VStack {
                    Text("장바구니 내용")
                        .font(.headline)

                    List(cartViewModel.cart, id: \.self) { item in
                        Text(item.title ?? "No Title")
                    }
                    .frame(height: 80)

                    Button("장바구니 초기화") {
                        cartViewModel.deleteAllData()
                    }
                    .padding(.vertical, 5)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationBarHidden(true) // NavigationBar 완전히 숨기기
    }
}
```

그리고 view하나더 만들었다.

```swift
struct ApiStateSubview: View {
    @StateObject var testWishViewModel = TestWishViewModel()
    @ObservedObject var cartViewModel: CartViewModel

    var body: some View {
        VStack {
            Text("API 조회 결과 - StateObject")
                .font(.headline)

            if let item = testWishViewModel.wishList.first {
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
            } 

            Button("API 조회") {
                Task {
                    await testWishViewModel.fetchWishList()
                }
            }
            .padding()
        }
    }
}
```
ApiDataSubview, ApiStateSubview 이렇게 만들었고 ApiDataSubview의 코드도 위의 코드와 동일하게 하되 `@observedobject` 이걸로만 바꿨다.

![simulator_screenshot_BBEB06E1-85A2-4F39-A73A-C4AB6222A6E7](https://github.com/user-attachments/assets/11728d51-68f3-4a1e-8e4e-eb825c51f7ee){: width="50%" height="50%"} 

그러면 이렇게 한화면에서 비교가 가능해진다.

![Nov-16-2024 15-04-28](https://github.com/user-attachments/assets/6aee8f53-6251-4912-82e1-962b83a4ac81){: width="50%" height="50%"} 

내가 생각한대로 결과가 나온다. 하지만 이걸하면서 느낀건 부모뷰와 자식관계에 따라 @StateObject, @ObservableObject의 결과가 같을수도 다를수도 있다는것.

### 12-4. `@StateObject` vs `@ObservedObject` 가설과 결과 분석

이건 GPT를 통해 정리를 해달라고했다.

#### 12-4-1. 초기 가설

처음에 내가 생각한 가설은 위에 언급이 되어있지만 정리하면 아래와 같다.

- **화면 구성**: 
  - API 호출 결과를 표시하는 뷰와, 장바구니 초기화 버튼이 있는 화면을 가정.
- **가설**:
  - API 조회 결과가 화면에 표시된 상태에서, **장바구니 초기화 버튼을 눌렀을 때**의 동작을 통해 차이를 확인할 수 있음:
    - **`@StateObject` 사용 시**: API 조회 결과는 **초기화되지 않고 그대로 유지**되며, **장바구니 데이터만 초기화**됨.
    - **`@ObservedObject` 사용 시**: API 조회 결과가 **뷰모델의 초기 값으로 리셋**되며, **장바구니 데이터와 함께 초기화**됨.

#### 12-4-2. 시행착오 과정

##### 12-4-2-1. MainView에서 TestView로 ViewModel 전달

- **문제**: 부모 뷰(MainView)에서 생성된 `WishViewModel`과 `CartViewModel`을 `@ObservedObject`로 TestView에 전달하여 사용했음.
- **결과**: `@ObservedObject`와 `@StateObject` 모두 **동일한 동작**을 보였음.
- **원인 분석**: 부모 뷰에서 생성된 ViewModel 인스턴스가 전달되었기 때문에, `@ObservedObject`와 `@StateObject`의 차이가 나타나지 않았음. 객체는 부모 뷰에서 생성된 인스턴스를 재사용했기 때문에 상태가 유지되었음.

##### 12-4-2-2. TestView에서 독립적인 인스턴스 생성

- **변경 사항**: `@StateObject`를 사용하여 TestView에서 독립적인 `WishViewModel`과 `CartViewModel` 인스턴스를 생성함.
- **결과**: `@StateObject` 사용 시, API 조회 결과가 유지되며 장바구니 초기화 버튼을 눌러도 조회된 데이터가 초기화되지 않음.
- **문제 분석**: 단일 뷰에서 ViewModel을 직접 생성하면, `@ObservedObject`와 `@StateObject`의 차이가 나타나지 않음. 부모-자식 뷰 관계가 아닌 경우, 객체의 생명 주기는 동일하게 작동하기 때문임.

##### 12-4-2-3. TestView 강제 렌더링 시도

- **시도**: `UUID`를 사용해 `TestView`를 강제 렌더링하여, 뷰가 다시 생성되도록 함.
- **결과**: 뷰가 새로 생성되면서, `onAppear`가 호출되고 API 조회 결과가 초기화됨.
- **문제**: 강제 렌더링으로 인해 `@StateObject`의 생명 주기 관리 기능이 무력화됨. 이 방식은 `@StateObject`와 `@ObservedObject`의 차이를 테스트하는 데 적합하지 않음.

##### 12-4-2-4. 부모-자식 관계로 구조 변경

- **변경 사항**: `TestView`를 부모 뷰로, `ApiDataSubview`를 자식 뷰로 분리함. `@ObservedObject`와 `@StateObject`의 차이를 비교하기 위해, `ApiDataSubview`에서 `WishViewModel`을 `@ObservedObject`로 선언함.
- **결과**:
  - `@StateObject`는 API 조회 결과를 유지하며, 부모 뷰의 재렌더링에도 영향을 받지 않음.
  - `@ObservedObject`는 부모 뷰의 생명 주기에 따라 객체가 재생성되어, API 조회 결과가 초기화됨.
- **결론**: 부모-자식 관계에서만 `@ObservedObject`와 `@StateObject`의 차이가 명확히 드러남. 부모 뷰에서 객체를 주입받는 `@ObservedObject`는 부모 뷰의 상태 변화에 따라 초기화될 수 있음.

### 12-5. 시행착오 요약

- 단일 뷰에서 `@ObservedObject`와 `@StateObject`를 비교했을 때, **차이가 드러나지 않아 잘못된 결론에 도달할 뻔함**.
- 강제 렌더링 시도는 `@StateObject`의 생명 주기 관리 기능을 무력화시켜, 올바른 테스트 방법이 아님.
- 부모-자식 관계를 고려한 테스트에서, **객체의 생명 주기와 상태 관리 차이**를 명확하게 이해할 수 있었음.
- 이 실험을 통해, **부모 뷰와 자식 뷰 간의 관계**에 따라 `@ObservedObject`와 `@StateObject`의 동작이 달라질 수 있음을 확인함.

#### 12-5-1. 시행착오 후 수정된 결론

- **부모 뷰와 자식 뷰의 관계**에 따라 **`@StateObject`**와 **`@ObservedObject`**의 결과가 **같을 수도 있고, 다를 수도 있음**을 발견함.
- **결과 차이의 원인**:
  - **`@StateObject`**는 자식 뷰에서 직접 객체를 생성하고 관리하므로, **독립적인 생명 주기**를 가짐. 이 경우, 부모 뷰의 상태 변화와 무관하게 **API 조회 결과가 유지**됨.
  - **`@ObservedObject`**는 부모 뷰에서 객체를 전달받아 사용하므로, **부모 뷰의 생명 주기에 따라 객체가 재생성**될 수 있음. 이 경우, 부모 뷰의 상태 변화가 있을 때 **API 조회 결과가 초기화**될 가능성이 있음.

#### 12-5-2. 결론

| 항목                          | `@StateObject` 사용 시                    | `@ObservedObject` 사용 시                  |
| ----------------------------- | ---------------------------------------- | ----------------------------------------- |
| **API 결과 유지 여부**        | API 결과는 그대로 유지됨                  | API 결과가 초기 값으로 리셋될 수 있음      |
| **객체의 생명 주기**          | 자식 뷰에서 독립적으로 관리됨             | 부모 뷰의 생명 주기에 따라 변경될 수 있음 |
| **장바구니 초기화 후 동작**   | API 결과는 유지되고, 장바구니만 초기화됨   | API 결과와 장바구니 모두 초기화됨         |
| **상황 설명**                 | 부모 뷰의 상태 변화에 영향을 받지 않음    | 부모 뷰의 상태 변화에 영향을 받음        |

#### 12-5-3. 결론 요약

- `@StateObject`와 `@ObservedObject`의 차이는 **객체의 생성과 생명 주기 관리**에서 비롯되며, 부모 뷰와 자식 뷰 간의 관계에 따라 **결과가 달라질 수 있음**.
- **독립적인 상태 유지**가 필요하면 `@StateObject`를 사용하고, **부모 뷰의 상태와 동기화**가 필요하면 `@ObservedObject`를 사용하는 것이 적합함.
- 이 차이를 이해하면 SwiftUI에서 더 예측 가능하고 안정적인 상태 관리를 할 수 있음.

---

## 13. 모의면접

GPT에게 이걸 면접으로 물어보는 상황을 만들어보게 해봤다.

### 13-1. `@StateObject`와 `@ObservedObject`

질문: `@StateObject`와 `@ObservedObject`의 **"객체의 생명 주기와 상태 관리 차이"**에 대해 설명해 주세요.

---

답변:

wiftUI에서 **`@StateObject`**와 **`@ObservedObject`**는 모두 `ObservableObject` 프로토콜을 따르는 객체의 상태 변화를 감지하고 뷰를 업데이트하는 데 사용됩니다. 하지만 **객체의 생성과 생명 주기 관리 방식**에서 중요한 차이점이 있습니다:

#### 13-1-1. 객체의 생명 주기 (`Lifecycle`)

- **`@StateObject`**:
  - `@StateObject`는 **뷰에서 직접 객체를 생성하고 관리**합니다. 이 객체는 **뷰가 처음 생성될 때만 초기화**되며, 이후 뷰가 재렌더링되더라도 **동일한 인스턴스**를 유지합니다.
  - 따라서, `@StateObject`는 **뷰가 제거될 때까지 동일한 인스턴스**를 유지하며, 객체의 생명 주기는 **뷰 자체**에 의해 관리됩니다.
  - **예시**:
    - API 조회 결과를 `@StateObject`로 관리할 경우, 부모 뷰가 재생성되더라도 조회 결과는 초기화되지 않고 그대로 유지됩니다. 이는 객체의 생명 주기가 **뷰와 독립적**이기 때문입니다.

- **`@ObservedObject`**:
  - `@ObservedObject`는 **부모 뷰에서 객체를 전달받아 사용**합니다. 이 경우, 객체의 생명 주기는 **부모 뷰의 생명 주기**에 종속됩니다.
  - 부모 뷰가 재생성되면, 부모 뷰에서 전달된 객체도 **새로 초기화**될 가능성이 있습니다.
  - **예시**:
    - API 조회 결과를 `@ObservedObject`로 관리할 경우, 부모 뷰가 재생성되면 조회된 데이터가 초기화될 수 있습니다. 이는 객체의 생명 주기가 **부모 뷰의 생명 주기**에 따라 결정되기 때문입니다.

#### 13-1-2. 상태 관리 (`State Management`)

- **`@StateObject`**:
  - `@StateObject`는 **독립적인 상태 유지**가 가능합니다. 뷰가 재렌더링되더라도, 객체의 상태는 초기화되지 않습니다.
  - 이는 객체의 인스턴스가 뷰 내부에서 **독립적으로 관리**되기 때문입니다.
  - **예시**:
    - API 조회 결과를 `@StateObject`로 선언하면, 조회된 데이터는 부모 뷰가 재생성되더라도 유지되며, 초기화되지 않습니다.

- **`@ObservedObject`**:
  - `@ObservedObject`는 **부모 뷰에서 전달된 객체의 상태**를 동기화합니다. 부모 뷰의 생명 주기에 따라 객체가 새로 생성되면, 상태도 초기 값으로 리셋됩니다.
  - 따라서, `@ObservedObject`는 부모 뷰의 상태 변화에 따라 **상태가 초기화될 위험**이 있습니다.
  - **예시**:
    - API 조회 결과를 `@ObservedObject`로 선언하면, 부모 뷰가 재생성될 때 조회된 데이터가 초기화될 수 있습니다.

#### 13-1-3-3. 요약

| 항목                          | `@StateObject` 사용 시                    | `@ObservedObject` 사용 시                  |
| ----------------------------- | ---------------------------------------- | ----------------------------------------- |
| **객체의 생명 주기**          | 뷰에서 독립적으로 관리됨                  | 부모 뷰의 생명 주기에 종속됨              |
| **상태 유지 여부**            | 상태가 유지됨                            | 상태가 초기화될 가능성이 있음             |
| **사용 시점**                 | 독립적인 상태 유지가 필요할 때            | 부모 뷰와 상태 동기화가 필요할 때         |

### 13-2. CoreData, SwiftData

질문: iOS 개발에서 **SwiftData**와 **CoreData**의 차이점은 무엇인가요? 어떤 상황에서 각각을 사용해야 할까요?

---

답변: 

SwiftData와 CoreData는 모두 Apple의 데이터 영속성 프레임워크로, 로컬 데이터베이스를 관리하는 데 사용됩니다. 하지만 이 두 가지는 설계 철학과 사용 방식에서 중요한 차이점이 있습니다.

#### 13-2-1. 데이터 모델링 방식

- **CoreData**:
  - CoreData는 **`.xcdatamodeld` 파일**을 사용하여 데이터 모델을 정의합니다. 여기에는 엔티티(Entity), 속성(Attribute), 관계(Relationship)을 시각적으로 설계할 수 있습니다.
  - 데이터 모델을 수정하려면 **`.xcdatamodeld` 파일**에서 직접 수정해야 하며, 코드와 모델 파일 간의 일치가 중요합니다.
  - **예시**: CoreData에서 데이터 모델을 정의할 때는 `NSManagedObject` 클래스를 사용하며, 데이터베이스의 구조를 미리 정의해야 합니다.

- **SwiftData**:
  - SwiftData는 **Swift 코드 기반의 데이터 모델링**을 사용합니다. `@Model` 애노테이션을 사용하여 데이터 모델을 직접 Swift 코드에서 정의할 수 있습니다.
  - 코드만으로 데이터 모델을 정의할 수 있으므로, 더 직관적이고 Swift 언어의 기능을 활용할 수 있습니다.
  - **예시**: SwiftData에서는 `@Model`로 선언된 Swift 구조체나 클래스를 데이터베이스 모델로 사용합니다. 모델 정의가 간단하며 코드와 데이터 모델이 일관성을 가집니다.

#### 13-2-2. 데이터 저장 및 파일 구조

- **CoreData**:
  - CoreData는 데이터를 **`.sqlite` 파일**로 저장합니다. 이 파일은 앱의 **Documents 디렉토리**에 위치하며, 외부에서 쉽게 접근할 수 있습니다.
  - 디스크 기반의 저장 방식으로, 데이터를 영구적으로 저장하며 **대용량 데이터 처리**에도 적합합니다.

- **SwiftData**:
  - SwiftData는 데이터를 **`.store` 파일**로 저장합니다. 이 파일은 SwiftData의 새로운 저장 포맷으로, CoreData의 `.sqlite` 파일과는 다릅니다.
  - 기본적으로 메모리에 데이터를 저장할 수도 있으며(`isStoredInMemoryOnly: true`), 디스크 저장 옵션도 제공하지만 간단한 설정으로 관리할 수 있습니다.

#### 13-2-3. Context와 CRUD 작업

- **CoreData**:
  - CoreData는 **`NSManagedObjectContext`**를 사용하여 데이터를 관리합니다. 이 Context는 데이터의 일시적인 작업 공간으로, 데이터를 삽입, 삭제, 저장할 때 사용됩니다.
  - **예시**: 데이터를 삭제할 때는 `NSBatchDeleteRequest`와 `execute()` 메서드를 사용하여 대량의 데이터를 효율적으로 삭제할 수 있습니다.

- **SwiftData**:
  - SwiftData는 **`ModelContext`**를 사용하여 데이터를 관리합니다. `ModelContext`는 SwiftUI와의 통합이 더 쉽고, Swift 구조체를 직접 관리할 수 있습니다.
  - **예시**: 데이터를 삭제할 때는 `delete(model:)` 메서드를 사용하여 간단하게 모델 전체를 삭제할 수 있습니다.

#### 13-2-4. 요약

| 항목                    | **CoreData**                             | **SwiftData**                           |
| ----------------------- | ---------------------------------------- | --------------------------------------- |
| **데이터 모델링 방식**   | `.xcdatamodeld` 파일 사용                | Swift 코드에서 `@Model`로 정의           |
| **저장 파일 형식**      | `.sqlite` 파일                           | `.store` 파일                           |
| **Context 타입**        | `NSManagedObjectContext` 사용            | `ModelContext` 사용                     |
| **대량 데이터 삭제**    | `NSBatchDeleteRequest` 사용              | `delete(model:)` 메서드 사용            |
| **SwiftUI 통합**        | 추가 설정 필요 (`@Environment` 사용)     | `@Environment(\.modelContext)`로 간편 접근 |

---

## 14. 마지막 개선

(11.17 추가)

ApiStateSubview / ApiDataSubview가 

`ObservedObject` / `StateObject` 말고는 코드가 같기에 하나로 통일한다.

```swift
struct TestView: View {
    @ObservedObject var cartViewModel = CartViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                // ObservedObject 섹션
                VStack {
                    ApiToggleSubview(useStateObject: false, cartViewModel: cartViewModel)
                        .frame(height: 180)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

                // StateObject 섹션
                VStack {
                    ApiToggleSubview(useStateObject: true, cartViewModel: cartViewModel)
                        .frame(height: 180)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)

                // 장바구니 내용 섹션
                VStack {
                    Text("장바구니 내용")
                        .font(.headline)

                    List(cartViewModel.cart, id: \.self) { item in
                        Text(item.title ?? "No Title")
                    }
                    .frame(height: 150)

                    Button("장바구니 초기화") {
                        cartViewModel.deleteAllData()
                    }
                    .padding(.vertical, 5)
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
}


struct ApiToggleSubview: View {
    let useStateObject: Bool
    @ObservedObject var cartViewModel: CartViewModel

    @StateObject private var stateViewModel: TestWishViewModel
    @ObservedObject private var observedViewModel: TestWishViewModel

    init(useStateObject: Bool, cartViewModel: CartViewModel) {
        self.useStateObject = useStateObject
        self.cartViewModel = cartViewModel

        // 초기화 시점에서 선택적으로 인스턴스를 생성
        if useStateObject {
            _stateViewModel = StateObject(wrappedValue: TestWishViewModel())
            _observedViewModel = ObservedObject(wrappedValue: TestWishViewModel()) // 더미 인스턴스
        } else {
            _stateViewModel = StateObject(wrappedValue: TestWishViewModel()) // 더미 인스턴스
            _observedViewModel = ObservedObject(wrappedValue: TestWishViewModel())
        }
    }

    var body: some View {
        VStack {
            Text(useStateObject ? "StateObject - API 조회" : "ObservedObject - API 조회")
                .font(.headline)

            let viewModel = useStateObject ? stateViewModel : observedViewModel

            if let item = viewModel.wishList.first {
                HStack {
                    Text(item.title)
                    Spacer()
                    Button("담기") {
                        cartViewModel.addCart(model: item)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
            }

            Button("API 조회") {
                Task {
                    await viewModel.fetchWishList()
                }
            }
            .padding()
        }
    }
}
```

이렇게 true / false로 넘겨서 가능하게 했다.

이때 특이점은 init에서 `_`이게 변수앞에 붙는것.

해당 내용은 Docs에 설명이 있다.

[StateObject](https://developer.apple.com/documentation/swiftui/stateobject){:target="_blank"} [ObservedObject](https://developer.apple.com/documentation/swiftui/observedobject){:target="_blank"}를 참고하자.

### 14-1. 왜 언더스코어(`_`)가 필요한가?

Swift에서 `@StateObject`, `@ObservedObject`와 같은 **Property Wrapper**를 사용할 때, **내부 프로퍼티**인 **래퍼 객체**에 접근할 때는 언더스코어(`_`)를 사용해야 함.

#### 14-1-1. Property Wrapper의 구조

Property Wrapper는 다음과 같은 두 가지 요소로 구성됨:

- **래핑된 값 (wrapped value)**: 실제 값
- **래퍼 객체 (wrapper object)**: Property Wrapper 자체

### 14-2. 초기화 시 언더스코어 사용

- 언더스코어(`_`)를 사용하는 이유는 **래퍼 객체**에 직접 접근해 초기화하기 위함임.
- Property Wrapper는 일반 변수처럼 직접 초기화할 수 없으며, **래퍼 객체**에 접근해야만 올바른 초기화가 가능함.

### 14-3. 왜 언더스코어가 필요한지 요약

| 접근 방식         | 설명                                      |
| ----------------- | ----------------------------------------- |
| `stateViewModel`  | **래핑된 값** (`TestWishViewModel` 인스턴스) |
| `_stateViewModel` | **래퍼 객체** (`StateObject<TestWishViewModel>`) |

### 14-4. 결론

- `@StateObject`, `@ObservedObject`는 Property Wrapper이므로, 직접 초기화할 때는 언더스코어(`_`)를 사용해 **래퍼 객체**에 접근해야 함.
- 그렇지 않으면 Swift의 **Property Wrapper 규칙**을 위반하게 됨.

진짜 끝.

확실히 정리할때는 내가 먼저 정리한걸 기반으로 GPT를 사용하면 훨씬 도움이 많이 되는듯하다.

[GitHub](https://github.com/Haroldfromk/ForSwiftUI/tree/main/ApiCart){:target="_blank"}
