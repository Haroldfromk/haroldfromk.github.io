---
title: Combine Weather (1)
writer: Harold
date: 2024-12-26 06:16
categories: [Combine, WeatherKit]
tags: [WeatherKit]

toc: true
toc_sticky: true
---

## Combine을 사용한 날씨 앱 만들기.

SwiftUI & Combine을 사용하여 간단한 날씨앱을 만들어 보려고 한다.

![CleanShot 2024-12-22 at 13 05 13](https://github.com/user-attachments/assets/cc4a6c32-ddc6-4f04-bcfa-d2a69729119c)

지역을 저장하게 하여, 사용자가 저장한 지역의 날씨도 보여주면 좋을 것 같아서 이번엔 SwiftData를 프로젝트를 생성하면서 만들어본다.

## UIDesign

### gif Image를 Background로 사용하기

검색을해보니 좋은 영상이 있어 참고하여 만들어 본다.

[Youtube](https://www.youtube.com/watch?v=9fz8EW-dX-I){:target="_blank"}링크는 여기

물론 [Medium](https://medium.com/@venkateshmandapati/displaying-gifs-in-swiftui-using-gifimageview-04179d926552){:target="_blank"}에도 같은내용이 있으니 참고.

하지만 문제는 Gif 이미지의 자체 크기에 따라 View의 크기가 결정이 된다는 것.

이리저리 검색을하고 시도를 하였으나 gif이미지의 사이즈를 직접 수정하지 않는 이상은 답이 없었다.

#### GPT를 통한 문제 해결

검색을 하였지만 원하는 내용이 없어 gpt를 통해 해결을 한다.

```swift
struct BackgroundImageView: UIViewRepresentable {
    let name: String
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.clipsToBounds = true

        guard let gifView = createGIFView() else {
            return containerView
        }

        containerView.addSubview(gifView)
        gifView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gifView.topAnchor.constraint(equalTo: containerView.topAnchor),
            gifView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            gifView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gifView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
       
    }
    
    private func createGIFView() -> UIImageView? {
        guard let path = Bundle.main.path(forResource: name, ofType: "gif"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let gifView = UIImageView()
        gifView.contentMode = .scaleAspectFill
        
        var images: [UIImage] = []
        var duration: Double = 0

        let frameCount = CGImageSourceGetCount(source)
        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let frameDuration = getFrameDuration(for: source, at: i)
                duration += frameDuration
                images.append(UIImage(cgImage: cgImage))
            }
        }

        gifView.animationImages = images
        gifView.animationDuration = duration
        gifView.startAnimating()
        return gifView
    }
    
    private func getFrameDuration(for source: CGImageSource, at index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
              let frameDuration = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double ??
                                   gifProperties[kCGImagePropertyGIFDelayTime] as? Double else {
            return 0.1 // 기본값
        }
        return frameDuration > 0 ? frameDuration : 0.1
    }
}
```

코드는 위와 같다.

**구조 및 역할**

- 이 코드는 `UIViewRepresentable`을 사용하여 SwiftUI에서 `UIImageView`를 활용하여 GIF 이미지를 표시하는 뷰를 생성한다.
- GIF 이미지를 로드하고 애니메이션으로 표시하며, SwiftUI의 뷰 구조 안에서 작동하도록 UIKit의 `UIView`를 래핑한다.

---

**코드 분석**

1. `makeUIView(context:)`

- **`containerView`**: `UIView` 컨테이너를 생성하며, GIF 이미지를 담는 역할을 한다. 
  - 다른 레이아웃과 충돌하지 않도록 클립 설정(`clipsToBounds = true`)을 추가했다.
- **`createGIFView()`**: GIF 이미지를 생성하여 반환한다.
- **`NSLayoutConstraint`**: `UIImageView`를 `containerView`의 상하좌우에 꽉 맞도록 제약을 설정하여 크기를 조절한다.

---

2. `updateUIView(_:context:)`

- SwiftUI 뷰가 업데이트될 때 호출되지만, 현재는 GIF가 계속 재생되므로 업데이트 처리가 필요 없다.

---

3. `createGIFView()`

- **GIF 데이터를 로드**:
  - 로컬에 있는 GIF 파일의 경로를 가져오고 데이터를 읽어 `CGImageSource`로 변환한다.
  - `CGImageSource`를 통해 GIF 파일의 각 프레임을 처리할 수 있다.
- **GIF를 애니메이션으로 변환**:
  - `UIImageView`를 생성한 뒤, GIF의 프레임을 `UIImage` 배열로 변환하여 `UIImageView`의 `animationImages`에 설정한다.
  - GIF 프레임의 개별 재생 시간을 합산하여 전체 재생 시간을 계산한다.
  - `UIImageView`의 `startAnimating()`을 호출하여 GIF 애니메이션을 시작한다.

---

4. `getFrameDuration(for:at:)`

- **프레임 지속 시간 계산**:
  - `CGImageSource`에서 각 프레임의 속성을 가져와 지속 시간을 계산한다.
  - `kCGImagePropertyGIFUnclampedDelayTime` 또는 `kCGImagePropertyGIFDelayTime`을 통해 지속 시간을 가져오며, 기본값은 0.1초이다.
  - 값이 0이거나 음수일 경우에도 기본값 0.1초를 반환한다.

### Navigation Title color 변경

![CleanShot 2024-12-24 at 11 35 03](https://github.com/user-attachments/assets/3ffef2ac-e6ce-4931-8878-80c299bfe481){: width="50%" height="50%"} 

[Developer Forum](https://discussions.apple.com/thread/255346817?sortBy=rank){:target="_blank"}을 보고 해결

별도의 Extension을 만들었다.

## NetworkManager 구현

### 모델링

우선 모델링을 진행한다

코드로 대체

```swift
import Foundation

struct WeatherModel: Codable {
    let weather: [Weather]
    let main: Main
    let wind: Wind
    let timezone, id: Int
    let name: String
    let cod: Int
}

// MARK: - Main
struct Main: Codable {
    let temp, feelsLike, tempMin, tempMax: Double
    let pressure, humidity: Int

    enum CodingKeys: String, CodingKey {
        case temp
        case feelsLike = "feels_like"
        case tempMin = "temp_min"
        case tempMax = "temp_max"
        case pressure, humidity
    }
}

// MARK: - Weather
struct Weather: Codable {
    let id: Int
    let main, description, icon: String
}

// MARK: - Wind
struct Wind: Codable {
    let speed: Double
    let deg: Int
}
```

이 모델링은 추후 변동 사항이 있을지도 모르겠다.

### NetworkManager 구현

```swift
@Observable
class NetworkManager {
    
    func fetchRequest(url: URL, for city: String) -> AnyPublisher<WeatherModel, NetworkError> {
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap({ data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                return data
            })
            .decode(type: WeatherModel.self, decoder: JSONDecoder())
            .catch({ error -> AnyPublisher<WeatherModel, NetworkError> in
                
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        
        
    }
    
}
```

코드를 작성하다 문제점을 발견

여기서 catch를 사용하게되면 WeatherModel의 초기값이 있어야한다.

왜냐면 Just를 통해 리턴하기 때문.

즉 다른방식으로 에러 핸들링을 해야한다.

이전에는 replaceError를 사용했는데, 지금은 배열로 값을 가져오는게 아니기에 패스.

검색을 해보니 [참고글](https://www.avanderlee.com/swift/combine-error-handling/){:target="_blank"}에 `mapError`가 있다하여 그걸 사용해보려 한다.

```swift
@Observable
class NetworkManager {
    
    func fetchRequest(url: URL, for city: String) -> AnyPublisher<WeatherModel, NetworkError> {
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap({ data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                return data
            })
            .decode(type: WeatherModel.self, decoder: JSONDecoder())
            .mapError({ error in // new
                return NetworkError.invalidURL
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        
    }
}

```

사용방법은 간단하다.

## ViewModel 만들기

```swift
class NetworkViewModel: ObservableObject {
    
    @Published var currentWeather: WeatherModel
    
    let networkManager: NetworkManager
    var cancellables = Set<AnyCancellable>()
    
    init(currentWeather: WeatherModel, networkManager: NetworkManager) {
        self.currentWeather = currentWeather
        self.networkManager = networkManager
    }

    func fetchWeather(city: String) {
        
        guard let currentURL = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=apikey") else { return }
        
        networkManager.fetchRequest(url: currentURL, for: city)
            .sink { completion in
                switch completion {
                case .finished:
                    print("success")
                    return
                case .failure(let error):
                    print(error)
                }
            } receiveValue: { [weak self] current in
                self?.currentWeather = current
                print(current)
            }.store(in: &cancellables)
    }
    
}
```

우선은 이렇게 코드를 작성했다,

크게 언급할 내용은 없어서 패스

제대로 출력이 되는것을 확인하였다.

### 날씨에 따라 배경이미지 다르게 구현하기

```swift
func getCondition() {
    networkViewModel.$currentWeather
        .map(\.weather)
        .sink(receiveCompletion: { _ in
            
        }, receiveValue: { weather in
            if let id = weather.first?.id {
                print(id)
                switch id {
                case 200...232 : imageName = "thunderstrom"
                case 300...321 : imageName = "drizzle"
                case 500...531 : imageName = "rain"
                case 600...622 : imageName = "snow"
                case 700...781 : imageName = "foggy"
                case 800 : imageName = "sunny"
                case 801...804 : imageName = "cloud"
                default : imageName = "sunny"
                }
                print(imageName)
            } else {
                imageName = "sunny"
            }
            
        })
        .store(in: &cancellables)
}
```

위와 같이 코드를 작성했다.

날씨의 id값에 따라서 배경화면의 이미지명을 바꾸려고한다.

하지만 이미지가 변하지 않는다.

backgroundImageView는 gpt를 통해 만들었기에 도움을 받아 해결

```swift
func updateUIView(_ uiView: UIView, context: Context) {
    guard let gifView = createGIFView() else { return }
        uiView.subviews.forEach { $0.removeFromSuperview() }
        uiView.addSubview(gifView)
        gifView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gifView.topAnchor.constraint(equalTo: uiView.topAnchor),
            gifView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor),
            gifView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            gifView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
        ])
}
```

ui를 업데이트 하는 코드가 필요했던것.

## LocationManager 만들기

`CoreLocation`을 사용하여 만든다.


[Docs](https://developer.apple.com/documentation/corelocation/configuring-your-app-to-use-location-services){:target="_blank"}를 참고하여 만들어 보려고 한다.

[지명가져오기](https://developer.apple.com/documentation/corelocation/converting-between-coordinates-and-user-friendly-place-names){:target="_blank"}는 여기

```swift
import CoreLocation

class CoreLocationManager: NSObject, ObservableObject {
    
    private var locationManager: CLLocationManager?
    
    @Published var location: CLLocation?
    @Published var area: String?
    
    init(locationManager: CLLocationManager) {
        super.init()
        self.locationManager = locationManager
        locationManager.delegate = self
    }
    
    func request() {
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }
    
    func convertCoordinateToAddress() {
        if let location {
            let geocoder = CLGeocoder()
            let locale = Locale(identifier: "en_US") // 영어로 출력되도록 설정
            
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?.first
                    self?.area = firstLocation?.administrativeArea // 부산광역시x busan
                } else {
                    print(error?.localizedDescription ?? "Unknown Error")
                }
            }
        }
    }
}

extension CoreLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        locationManager?.startUpdatingLocation()
    }
}
```

이렇게 코드를 작성하였따.

그리고 이전에도 언급했지만, 반드시 info.plist 파일에 위치사용 허용에 대한 내용을 추가하자.

이후 View로 가서

```swift
.onAppear {
    coreLocationManager.request()
}
.onReceive(coreLocationManager.$location) { _ in
    coreLocationManager.convertCoordinateToAddress()
    networkViewModel.fetchWeather(city: coreLocationManager.area ?? "paris")
    getCondition()
}
```

`onReceive` 모디파이어를 사용한다.

location은 publshed에 의해 일종의 `Publisher`의 성격을 갖게 되는데, 이때 location이 값을 방출할때 onReceive가 방출된 값을 받아서 작동하게 된다.

그래서 onAppear에 유저의 위치를 가져오는 request를 실행하고, 그 값을 가져왔을때 좌표를 주소로 변환하고, 날씨 정보를 가져오게 했다.

![Dec-27-2024 14-04-10](https://github.com/user-attachments/assets/4ec97459-a6e8-4f14-9389-eaa1f1640a7e){: width="50%" height="50%"} 

실행하면 위와 같다.