---
title: Async/Await (8)
writer: Harold
date: 2024-11-29 00:13
categories: [Udemy, Concurrency]
tags: []

toc: true
toc_sticky: true
---

## Concurrent Tasks

이번엔 동시에 작업을 생성하는 방법에 대해 다뤄본다.

1. **Async let**
	- 이 작업은 여러 하위 작업(Child Tasks)을 가질 수 있다.
	- 하위 작업은 async let 구문을 사용하여 생성되며, 결국 async let은 변수와 같은 역할을 한다.
	- 이를 통해 이러한 작업이 동시에 실행될 수 있다.
    ![Untitled Diagram1 drawio](https://github.com/user-attachments/assets/8a1ff092-b7a5-4b9a-a9ea-2cc4e2282250)
2. **Task Group**
	- 반면, 동적 데이터가 있고 몇 개의 동시 작업을 실행해야 할지 알 수 없는 상황에서는 Task Group이 더 적합할 수 있다.
	- Task Group을 사용하면 작업 내에서 여러 그룹을 실행할 수 있으며, 각 그룹은 자체적으로 여러 하위 작업을 실행할 수 있다.
	- Task Group의 장점 중 하나는 그룹이 Task Group 구문을 사용하면서도 하위 작업은 async 구문을 자유롭게 사용할 수 있다는 것이다.
	- 이 경우, 여러 그룹을 생성할 수 있고, 각 그룹은 동시에 여러 하위 작업을 실행할 수 있다.
    ![Untitled Diagram2 drawio](https://github.com/user-attachments/assets/de48de24-96f3-4cf1-bcb2-cccdaee6275c)

### 1. 시나리오: 랜덤 이미지 앱 (Async let)

다른건 패스한다.

#### Webservice

```swift
private func getRandomImage(id: Int) async throws -> RandomImage {
    
    guard let url = Constants.Urls.getRandomImageUrl() else {
                throw NetworkError.badUrl
    }
    
    guard let randomQuoteUrl = Constants.Urls.randomQuoteUrl else {
                throw NetworkError.badUrl
    }
    
    async let (imageData, _) = URLSession.shared.data(from: url)
    async let (randomQuoteData, _) = URLSession.shared.data(from: randomQuoteUrl)
    
    guard let quote = try? JSONDecoder().decode(Quote.self, from: try await randomQuoteData) else {
        throw NetworkError.decodingError
    }
    
    return RandomImage(image: try await imageData, quote: quote)
}
```

비동기 작업을 순서대로 하지않고 같이 시작하기 위해 `async let`을 사용해준다.

그리고 그 변수를 사용하는 쪽에 반드시 `await`를 작성한다.

#### ViewModel

```swift
@MainActor
class RandomImageListViewModel: ObservableObject {
    
    @Published var randomImages: [RandomImageViewModel] = []
    
    func getRandomImages(ids: [Int]) async {
        
        do {
            let randomImages = try await Webservice().getRandomImages(ids: ids)
            self.randomImages = randomImages.map(RandomImageViewModel.init)
        } catch {
            print(error)
        }
    }
}

struct RandomImageViewModel: Identifiable {
    
    let id = UUID()
    fileprivate let randomImage: RandomImage
    
    var image: UIImage? {
        UIImage(data: randomImage.image)
    }
    
    var quote: String {
        randomImage.quote.content
    }
    
}
```

여기서는 `self.randomImages = randomImages.map(RandomImageViewModel.init)` 이것만 보면 될것같은데

randomImages의 타입을 [RandomImage] 에서 [RandomImageViewModel]로 타입을 변환해주는 작업을 map을 통해서 했다고 보면 된다.

![CleanShot 2024-11-29 at 14 57 52](https://github.com/user-attachments/assets/aef2abf7-7649-4623-a4ee-64717d3928bb)![CleanShot 2024-11-29 at 14 58 10](https://github.com/user-attachments/assets/5fe67578-87ab-4c5d-80ac-1b08d0d363dd)

그리고 **Main Thread에서 실행**하기 위해 `@MainActor`를 사용해준다.

#### 문제 발견

현재 강의에 있는 random quote api가 작동이 되지 않기에 다른 api가 필요.

https://quoteslate.vercel.app/api/quotes/random

이걸로 변경.

![simulator_screenshot_5B031220-7AC4-4AB2-B666-226FF115481E](https://github.com/user-attachments/assets/2c8750e0-9dec-47df-8edc-01f86d5514e0){: width="50%" height="50%"} 

완료.

### 2. 시나리오: 랜덤 이미지 앱 (Task Group)

현재 함수들을 보면 `Webservice`의 `getRandomImage`는 `async let`을 사용하여 작업을 동시에 시작하게 하고있다.

하지만 그 함수를 사용하는 `getRandomImages`는

```swift
func getRandomImages(ids: [Int]) async throws -> [RandomImage] {
    
    var randomImages: [RandomImage] = []
    
    for id in ids {
        
        let randomImage = try await getRandomImage(id: id)
        randomImages.append(randomImage)
    }
    return randomImages
}
```

위와 같이 배열에 하나씩 순서대로 넣으면서 작업이 진행되는 `Serial Queue`의 형태를 지니고 있다.

[이전글](https://haroldfromk.github.io/posts/Async_await-(7)/){:target="_blank"}에서 적용했던 `withThrowingTaskGroup`을 사용하여 코드를 보완해본다.

![CleanShot 2024-11-29 at 15 21 54](https://github.com/user-attachments/assets/5a24cee1-2ad0-45ce-9167-60e230cde168)

async가 deprecated 되었으니 강의와 다르게 addTask를 사용하여 구현한다.

```swift
func getRandomImages(ids: [Int]) async throws -> [RandomImage] {
    
    var randomImages: [RandomImage] = []
    
    try await withThrowingTaskGroup(of: (Int, RandomImage).self) { group in
        for id in ids {
            group.addTask { [self] in
                return (id, try await getRandomImage(id: id))
            }
        }
        
        for try await (_, randomImage) in group {
            randomImages.append(randomImage)
        }
    }
    
    return randomImages
}
```

이전글을 바탕으로 혼자서 해보려고했는데 리턴 타입에서 조금 잘못생각을 했던것 같아서 여기에 더 보완해서 적어본다.

아무렇지않게 `getRandomImages`함수의 리턴타입이 [RandomImage] 이거라서 of에다가도 [RandomImage]를 적용했었다.

그러다보니 타입 에러가 발생. 

이번에 정확하게 깨달은 건 `withThrowingTaskGroup`여기에서 of 를 정하기전에

먼저 For문에서 작업이 끝난이후의 타입 (다른함수에서 호출된 타입)이 뭔지를 먼저 파악하고 그것을 of에 적고 리턴을 하는게 좋아보인다.

즉 처음에는 of에러가 거슬린다면 `Void.self`로 에러를 없앤후 이후에 수정을 해도 좋을듯.

강의에서는 위의 방식을 적용하면서 리턴을 (Int, RandomImage)라는 Tuple의 타입으로 리턴을 했는데,

그러면서 작업이 끝난후의 아래 For문에서는 id가 필요없어서 _를 치면서 생략을 해주었다.

```swift
func getRandomImages(ids: [Int]) async throws -> [RandomImage] {
    
    var randomImages: [RandomImage] = []
    
    try await withThrowingTaskGroup(of: RandomImage.self) { group in
        for id in ids {
            group.addTask { [self] in
                return try await getRandomImage(id: id)
            }
        }
        
        for try await randomImage in group {
            randomImages.append(randomImage)
        }
    }
    
    return randomImages
}
```

그래서 수정을 좀 해봤는데 이렇게 해도 문제는 없다.

```swift
for try await randomImage in group {
    randomImages.append(randomImage)
}
```

여기서 포인트는 **이전에 리턴된 이미지들이 그룹내에 들어있는것이고 물론 순서는 우리는 모른다.**

그렇게 무작위로 들어온 이미지에 대해서 추가된 순서대로 배열에 담아주는 작업을 진행한다.

#### 이미지를 다운로드된 순서대로 보여주기

지금 어떻게 보면 위의 Task Group을 통해 이미지다운로드를 동시에 진행하게끔 하였다.

그렇다면 이런생각도 해볼수가 있는데,

> 다운로드가 먼저 끝난 이미지에 대해선 화면에 먼저 로딩을 해주는게 더 좋지않나?

이런 생각을 가질수있다.

왜냐하면 앞으로 뭔가 어떤 프로젝트를 진행함에 있어서 이미지가 무조건 용량이 작은것만은 있다고 보장할수는 없기 때문이다.

용량이 큰이미지가 있다면 이렇게 한번에 모두 담아서 보여준다면 로딩시간이 꽤나 길것이다.

물론 파이널 프로젝트때는 이미지 업로드를 할때 이미지의 Quality를 낮추면서 올리는 작업을 하기도 했었다.

```swift
static func uploadImage(image: UIImage, channel: Channel, progress: ((Double) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) -> StorageUploadTask? {
        guard let channelId = channel.id,
              let data = image.jpegData(compressionQuality: 0.4) else { // 여기 0.4로 퀄리티를 낮춘다.
            completion(.failure(NSError(domain: "ImageUploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image for upload"])))
            return nil
        }
        
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpg" 
        let imageName = UUID().uuidString + String(Date().timeIntervalSince1970)
        let imageReference = Storage.storage().reference().child("\(channelId)/\(imageName)")
        
        let uploadTask = imageReference.putData(data, metadata: metaData) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            imageReference.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url))
                } else {
                    completion(.failure(NSError(domain: "ImageUploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
        
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            progress?(percentComplete)
        }
        
        return uploadTask
    }
```

다시 현재 현재 코드로 돌아오면

```swift
class RandomImageListViewModel: ObservableObject {
    
    @Published var randomImages: [RandomImageViewModel] = []
    
    func getRandomImages(ids: [Int]) async {
        
        do {
            let randomImages = try await Webservice().getRandomImages(ids: ids)
            self.randomImages = randomImages.map(RandomImageViewModel.init)
        } catch {
            print(error)
        }
    }
}
```

여기서 randomImages가 어떻게 보면 배열인데, 모든 이미지가 다 담겨졌을때 작업이 끝나게 된다.

즉 

![example4 drawio1](https://github.com/user-attachments/assets/5b71e9ff-9cf0-4286-977f-2a79039300a5)

해당 이미지를 재사용 했는데, 하위 작업이 모두 끝나야 제일 상위의 부모 Task가 끝나는 구조가 바로 현재의 구조이다.

즉 위에서도 언급했지만

> 요청한 이미지 다운로드 작업이 모두 끝나고 배열에 담겨야만 작업이 끝난다.

이게 중요한 포인트인 것이다.

그러다보니 앱을 실행하면 모든 이미지가 같이 뜬다.

이제 위의 코드를 다시 수정해본다.

```swift
@MainActor
class RandomImageListViewModel: ObservableObject {
    
    @Published var randomImages: [RandomImageViewModel] = []
    
    func getRandomImages(ids: [Int]) async {
        
        let webService = Webservice()
        
        do {
            try await withThrowingTaskGroup(of: RandomImage.self) { group in
                for id in ids {
                    group.addTask {
                        return try await webService.getRandomImage(id: id)
                    }
                }
                
                for try await randomImage in group {
                    randomImages.append(RandomImageViewModel(randomImage: randomImage))
                }
            }
        } catch {
            print(error)
        }
    }
}
```

실행해보면 실행시간이 빨라졌다.

**[Before]**

![Nov-29-2024 16-49-21](https://github.com/user-attachments/assets/fb4cbfa5-11e0-43ab-b788-145f6854dc86){: width="50%" height="50%"} 

**[After]**

![Nov-29-2024 16-50-49](https://github.com/user-attachments/assets/6238a7fd-2c97-4e14-b902-439d4fb29ea0){: width="50%" height="50%"} 

일단은 강의와 달리 난 id를 사용하지 않기에 이번에도 배제를 했으나

이후 id를 사용할일이 생길수도 있기에 Tuple로 리턴해서 id도 같이 넘기는것이 더 좋아보이긴 한다.

### 3. 시나리오: 랜덤 이미지 앱 (Unstructured Task)

![CleanShot 2024-11-29 at 16 38 25](https://github.com/user-attachments/assets/fea906e2-c011-4871-a094-fac3d3e9899b){: width="50%" height="50%"} 

현재 이렇게 ui가 구성되어있다.

Refresh 버튼을 누른다고 가정해보자.

```swift
.navigationBarItems(trailing: Button(action: {
    Task {
        await randomImageListVM.getRandomImages(ids: Array(100...120))
    }
}, label: {
    Image(systemName: "arrow.clockwise.circle")
}))
```

그러면 배열에 계속 추가되면서 스크롤이 길어지게 된다.

![Nov-29-2024 16-42-24](https://github.com/user-attachments/assets/03f80c36-eae3-490d-990a-8a9dd139c25c){: width="50%" height="50%"} 

이건 Refresh라고 볼수 없다.

왜냐면 지금 배열 초기화를 해주는 부분이 없기때문

```swift
@Published var randomImages: [RandomImageViewModel] = []

func getRandomImages(ids: [Int]) async {
    
    let webService = Webservice()
    randomImages = []
    
    do {
        try await withThrowingTaskGroup(of: RandomImage.self) { group in
            for id in ids {
                group.addTask {
                    return try await webService.getRandomImage(id: id)
                }
            }
            
            for try await randomImage in group {
                randomImages.append(RandomImageViewModel(randomImage: randomImage))
            }
        }
    } catch {
        print(error)
    }
}
```

함수가 호출될때마다 배열을 초기화 해주는 작업을 해주면 된다.

![Nov-29-2024 16-47-55](https://github.com/user-attachments/assets/97e30e16-e99c-4261-9200-4ad1625f1918){: width="50%" height="50%"} 

끝.