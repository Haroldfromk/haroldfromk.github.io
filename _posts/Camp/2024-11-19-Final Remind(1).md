---
title: Final Remind (1)
writer: Harold
date: 2024-11-19 01:00
categories: [캠프, Remind]
tags: []
toc: true
toc_sticky: true
---

## 1. 파이널 프로젝트 - 지도 기능 리마인드

이전에 했던 파이널 프로젝트에 대해서 코드 리마인드를 좀 하면서 UIKit감각도 좀 되살릴겸 해보려고한다.
아마도 기능 위주로 챕터를 나눠서 진행을 할 예정
기능은 크게 가입(로그인), 추천, 지도, 가게, 채팅, 마이페이지 이렇게 크게 6개로 나뉘게 된다.
오늘 다뤄볼 주제는 지도이다.
지도는 내가 다룬 파트는 아니지만 이전에 KickBoard 앱을 만들때 지도를 다뤄봤기에 코드에 크게 거부감은 없다.

---

## 2. UI 구성

![simulator_screenshot_9D17A48D-40B8-46DE-9C33-3936E1974EBF](https://github.com/user-attachments/assets/6a59843e-d040-44a8-aa38-1d5bfb009c3e){: width="50%" height="50%"}
![simulator_screenshot_52C45360-10CA-4E02-BF6B-2824E0EEBA80](https://github.com/user-attachments/assets/3c1fcf8e-d624-40da-9d12-2441e1482a0d){: width="50%" height="50%"} 


### 2-1. 지도 화면 UI 구조
지도 화면은 `MapVC`와 이를 구성하는 `MapView`로 나뉜다. 

---

### 2-2. 계층 구조

![CleanShot 2024-11-19 at 13 24 49](https://github.com/user-attachments/assets/e1143d0c-59fd-4d38-a028-3485a65769eb){: width="50%" height="50%"} 

- **MapViewController**
  - `View`
    - `MapView`
      - `MKMapView`
      - `UISearchBar`
      - `UIButton (Find My Location)`
      - `MKCompassButton`
    - `PinStoreView` (별도 서술 예정)
  - **ViewModel**
    - `MapViewModel`
      - `stores`: 네트워크로 로드한 가게 데이터
      - `jsonStores`: JSON 파일에서 로드한 지역별 데이터
      - `state`: ViewModel의 현재 상태
      - 주요 메서드:
        - `loadStores`: 가게 검색
        - `loadJsonStores`: JSON 데이터 로드
        - `scrap`: 스크랩 관리

### 2-3. UI 요소 설명
1. **지도 (`MKMapView`)**
   - 사용자가 지도를 이동하고 줌인/줌아웃하며 주변 정보를 탐색할 수 있다.
   - 핀을 추가하여 특정 장소를 표시하거나, 현재 위치를 표시할 수 있다.
2. **검색 바 (`UISearchBar`)**
   - 장소나 지역명을 검색하여 해당 위치로 이동한다.
3. **현재 위치 버튼**
   - 사용자가 현재 위치로 빠르게 이동할 수 있도록 돕는다.
4. **컴퍼스 버튼 (`MKCompassButton`)**
   - 지도 상에서 북쪽 방향을 표시한다.

### 2-4. 코드

```swift
class MapView: UIView {
    
    let map: MKMapView = {
        let map = MKMapView()
        map.mapType = .standard
        map.isZoomEnabled = true     // 줌 가능 여부
        map.isScrollEnabled = true   // 이동 가능 여부
        map.isPitchEnabled = true    // 각도 조절 가능 여부 (두 손가락으로 위/아래 슬라이드)
        map.showsCompass = false
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return map
    }()

    let searchBar: UISearchBar = {
    }()

    let findMyLocationBtn: UIButton = {
    }()

    lazy var compassBtn: MKCompassButton = {
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setConstraints()
    }

    func setConstraints() {
    }
}
```

코드 상세 내용은 좀 빼둔다.

---

## 3. MapView의 역할

### 3-1. MapView 구성
`MapView`는 `UIView`를 상속받아 지도와 검색 바, 버튼들을 포함하는 뷰이다.

### 3-2. MapKit 사용법
- **Delegate 설정**: 지도에서 이벤트(핀 추가, 클릭 등)를 처리하려면 `MKMapViewDelegate`를 구현해야 한다.
- **주요 설정**: 
  - `mapType`: 지도 스타일 지정 (기본, 위성, 혼합 등)
  - `isZoomEnabled`, `isScrollEnabled`: 지도 인터랙션 허용 여부
  - `showsCompass`: 나침반 표시 여부

### 3-3. 코드

```swift
class MapViewController: UIViewController, PinStoreViewDelegate {
    private func setMapView() {
            mapView.map.delegate = self
            
            // 위치 관리자 설정
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            
            // 위치 업데이트 시작
            findMyLocation()
            locationManager.startUpdatingLocation()
        }
}
```

---

## 4. MapViewController 기능 구현

### 4-1. 지도 초기화 및 설정

#### 4-1-1. 초기화와 Delegate 설정

- **지도 초기화**: `viewDidLoad`와 `setMapView`에서 지도와 관련된 초기 작업을 수행.
- **Delegate 설정**: `MKMapViewDelegate`, `CLLocationManagerDelegate`, `UISearchBarDelegate` 위임.
- **위치 권한 요청**: 위치 관리자 초기화 및 권한 요청.

```swift
override func viewDidLoad() {
    setMapView()
}

private func setMapView() {
    mapView.map.delegate = self
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.requestWhenInUseAuthorization() // 위치 권한 요청
    locationManager.startUpdatingLocation()
}
```

---

### 4-2. 지도 상호작용

#### 4-2-1. 현재 위치 추적

- **`findMyLocation`**: 사용자 위치를 지도 중심으로 설정.
- **`LocationAuthorization`**: 위치 서비스 권한 확인 및 위치 업데이트.

```swift
private func findMyLocation() {
        centerMapOnLocation(location: userLocation)
        mapView.map.showsUserLocation = true
        mapView.map.setUserTrackingMode(.follow, animated: true)
    }
```

---

#### 4-2-2. 핀 추가 및 사용자 지정

- **`addPin`**: 특정 위치에 핀을 추가하고, `annotation.subtitle`로 검색한 장소 또는 상점 여부를 표시.
- **`viewFor annotation`**: 핀의 커스텀 이미지를 설정.

```swift
private func addPin(at location: CLLocation, title: String, isMainLocation: Bool) {
    let annotation = MKPointAnnotation()
    annotation.coordinate = location.coordinate
    annotation.title = title
    annotation.subtitle = isMainLocation ? "검색한 장소" : "분식집"
    mapView.map.addAnnotation(annotation)
}
```

---

#### 4-2-3. 장소 검색

- **`searchBarSearchButtonClicked`**: 사용자가 검색한 키워드를 기반으로 장소 검색.
- **`searchLocation`**: 검색 결과의 첫 번째 장소를 지도 중심으로 설정하고, 핀을 추가.

```swift
func searchLocation(query: String, for stores: [Document]) {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    let search = MKLocalSearch(request: request)
    search.start { response, error in
        guard let response else {
            print("Error searching for location: \(String(describing: error))")
            return
        }
        if let mapItem = response.mapItems.first {
            let coordinate = mapItem.placemark.coordinate
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            centerMapOnLocation(location: location)
            addPin(at: location, title: query, isMainLocation: true)
        }
    }
}
```

---

#### 4-2-4. 길게 눌러 위치 선택

- **`handleLongPress`**: 지도에서 특정 위치를 길게 눌러 핀을 추가.

```swift
@objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
    if gestureRecognizer.state == .began {
        let touchPoint = gestureRecognizer.location(in: mapView.map)
        let coordinate = mapView.map.convert(touchPoint, toCoordinateFrom: mapView.map)
        addPin(at: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), title: "선택된 위치", isMainLocation: true)
    }
}
```

---

### 4-3. 데이터 로드 및 UI 업데이트

#### 4-3-1. JSON 데이터 로드

- **`loadJson`**: 특정 지역의 JSON 데이터를 불러와 지도에 핀 추가.
- **`getFileName`**: 주소 정보를 기반으로 JSON 파일명을 결정.

```swift
private func loadJson(file name: String) {
    let jsonService = JsonService(fileName: name)
    jsonViewModel = JsonViewModel(jsonService: jsonService)
    let nearStores = jsonViewModel.getNearbyStores(currentLocation: userLocation)
    addNearbyStorePins(for: nearStores)
}
```

이부분은 추후 다시 서술할 예정

---

#### 4-3-2. 상점 정보 표시

- **`displayStoreInfoFromJSON`**: 특정 상점의 정보를 JSON 데이터에서 가져와 UI에 표시.
- **`getAverageRating`**: 상점 리뷰 평점 평균 계산.

```swift
private func displayStoreInfoFromJSON(with name: String) {
    let stores = jsonViewModel.getNearbyStores(currentLocation: userLocation)
    if let store = stores.first(where: { $0.storeName == name }) {
        let averageRating = getAverageRating(ratings: store.ratings)
        storeInfoView.bind(title: store.storeName, address: store.address, rating: averageRating)
    }
}
```

이부분은 추후 다시 서술할 예정

---

### 4-4. 추가 기능

#### 4-4-1. 스크랩 기능

- **`scrapButtonTapped`**: 스토어 정보를 스크랩하거나 스크랩을 취소.
- **`customAlertControl`**: 스크랩 여부에 따라 사용자 알림 표시.

```swift
func scrapButtonTapped(_ view: PinStoreView) {
        let name = view.titleLabel.text ?? ""
        viewModel.scrap(name, upon: storeInfoView.isScrapped)
        storeInfoView.isScrapped.toggle()
        customAlertControl()
    }

private func customAlertControl() {
        if storeInfoView.isScrapped {
            showPositiveCustomAlert(image: UIImage(systemName: "flag.fill")!, message: "스크랩되었습니다.")
        } else {
            showNegativeCustomAlert(image: UIImage(systemName: "flag.slash")!, message: "스크랩이 해제되었습니다.")
        }
    }
```

---

#### 4-4-2. UI 이벤트 처리

- **`sendButtonTapped`**: 선택된 위치를 Delegate를 통해 전달.
- **`cancelButtonTapped`**: 위치 선택 취소.

```swift
@objc func sendButtonTapped() {
    if let location = selectedLocation {
        delegate?.didSelectLocation(location)
    }
    dismiss(animated: true, completion: nil)
}

@objc func cancelButtonTapped() {
    dismiss(animated: true, completion: nil)
}
```

이부분은 추후 다시 서술할 예정

---

#### 4-4-3. 상태 변경 처리

- **`bind`**: ViewModel의 상태 변화를 감지하고 UI를 업데이트.

```swift
private func bind() {
    viewModel.didChangeState = { [weak self] viewModel in
        switch viewModel.state {
        case let .didStoresLoaded(keyword, stores):
            self?.searchLocation(query: keyword, for: stores)
        case let .didLoadedStore(store):
            self?.storeInfoView.bind(title: store.title, address: store.address, rating: store.rating)
        default: break
        }
    }
}
```

---


### 4-5. 결론

#### 4-5-1. 분류된 기능의 활용

- 각 함수는 특정 기능에 따라 명확히 분리되어 있으며, 이를 통해 유지보수성과 확장성이 크게 향상.

#### 4-5-2. 추가 개선점

- `ViewModel`의 역할 분리 및 데이터 로딩 최적화.
- 지도와 데이터 상호작용 간 비동기 처리를 더욱 효율적으로 개선.

---

## 5. MapViewModel 구조와 역할

### 5-1. MapViewModel 개요
`MapViewModel`은 지도 화면의 데이터 로직과 상태 관리를 담당한다. 
- ViewController와 분리된 데이터 로직을 통해 뷰와 비즈니스 로직의 결합도를 낮추고, 코드 재사용성을 높인다.
- 비동기 작업(Firebase, 네트워크 요청)과 데이터 상태 관리를 수행하며, ViewController는 ViewModel에서 발생하는 상태 변화에 반응한다.

---

### 5-2. ViewModel의 구성

- **프로퍼티**
  - `stores`: 사용자가 검색한 결과 데이터.
  - `jsonStores`: JSON 파일에서 로드한 지역별 데이터.
  - `state`: ViewModel의 상태를 나타내며, ViewController와의 데이터 전달에 사용.

- **주요 메서드**
  - `loadStores`: 키워드로 검색된 데이터를 가져온다.
  - `loadJsonStores`: JSON 데이터로부터 가게 정보를 불러온다.
  - `loadStore`: 특정 가게를 검색하거나 JSON 데이터에서 로드한다.
  - `getScrap`: 가게가 스크랩되었는지 확인한다.
  - `scrap`: 스크랩 또는 스크랩 취소 작업을 처리한다.

---

### 5-3. State 패턴
ViewModel은 `State`를 사용하여 상태 변화를 관리한다. 

- **`pending`**: 초기 상태.
- **`didStoresLoaded`**: 검색된 가게 데이터가 로드된 상태.
- **`didLoadedStore`**: 특정 가게의 상세 데이터가 로드된 상태.
- **`didLoadedWithError`**: 데이터 로드 중 에러가 발생한 상태.

```swift
enum State {
    case pending
    case didStoresLoaded(forKeyword: String, stores: [Document])
    case didLoadedStore(store: ShopView)
    case didLoadedWithError(error: StoreError)
}
```

---

### 5-4. 주요 메서드 설명

#### 5-4-1. 데이터 검색 및 로드

- **`loadStores`**: 네트워크에서 가게 데이터를 검색.
- **`loadJsonStores`**: 지역별 JSON 데이터를 로드.

```swift
func loadStores(with name: String) {
    NetworkManager.shared.fetchAPI(query: "\(name) 분식") { [weak self] stores in
        self?.stores = stores
        self?.state = .didStoresLoaded(forKeyword: name, stores: stores)
    }
}

func loadJsonStores(_ stores: [JsonModel]) {
    self.jsonStores = stores
}
```

---

#### 5-4-2. 스크랩 상태 관리

- **`getScrap`**: 가게의 스크랩 여부를 확인.
- **`scrap`**: 가게를 스크랩하거나 취소.

```swift
func scrap(_ storeName: String, upon isAlreadyScrapped: Bool) {
    if let store = findStore(with: storeName) {
        isAlreadyScrapped ? undoScrap(store) : scrap(store)
    } else if let store = findJsonStore(with: storeName) {
        isAlreadyScrapped ? undoScrapJsonStore(store) : scrapJsonStore(store)
    }
}
```

---

#### 5-4-3. 상태 업데이트와 데이터 바인딩

- ViewModel은 상태가 변경될 때 `didChangeState` 클로저를 호출하여 ViewController에 알린다.
- ViewController는 `bind` 메서드를 통해 ViewModel의 상태 변화를 구독한다.

```swift
var didChangeState: ((MapViewModel) -> Void)?

private(set) var state: State = .pending {
    didSet { didChangeState?(self) }
}
```

---

### 5-5. ViewModel과 ViewController의 연동

#### ViewController에서 ViewModel의 상태를 구독
- ViewController는 `bind` 메서드에서 ViewModel의 상태 변화를 감지하고, UI를 업데이트한다.

```swift
private func bind() {
    viewModel.didChangeState = { [weak self] viewModel in
        switch viewModel.state {
        case let .didStoresLoaded(keyword, stores):
            self?.searchLocation(query: keyword, for: stores)
        case let .didLoadedStore(store):
            self?.storeInfoView.bind(title: store.title, address: store.address, rating: store.rating)
        default: break
        }
    }
}
```

4-4-3 과 상동

---

### 5-6. ViewModel의 개선 가능성

1. **의존성 주입**: `JsonService`, `NetworkManager` 등을 초기화 시점에 주입하여 테스트 가능성을 높인다.
2. **비동기 작업 최적화**: `async/await`를 적극적으로 활용하여 코드 가독성을 개선.
3. **Error 핸들링 강화**: `State`에서 발생 가능한 에러에 대한 세부 처리를 추가.

---

## 6. 결론 및 앞으로의 방향

- **ViewController와 ViewModel 분리**: 역할을 명확히 분리하여 코드의 유지보수성과 재사용성을 높인다.
- **상태 관리 개선**: ViewModel이 다양한 상태를 효과적으로 관리하도록 설계.
- **추후 확장 가능성**: 지도 외의 다른 기능(가게, 채팅, 마이페이지 등)에서도 유사한 패턴을 적용할 수 있다.

---