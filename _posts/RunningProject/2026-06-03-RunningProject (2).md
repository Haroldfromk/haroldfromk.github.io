---
title: RunWay (2) CoreLocation
writer: Harold
date: 2026-06-03 07:33:00 +0800
categories: [RunWay]
tags: [CoreLocation]

toc: true
toc_sticky: true
published: true
---

## LocationService 만들기

러닝앱에서 빠지면 안되는 가장 중요한 요소이다.

오늘은 이걸 만들고 mockui하나 만들어서 시뮬레이터와, 실기기 테스트를 할 예정

다만 Swift6로 만들기때문에 초기에 잘 해놔야할 것 같다.

이미 알고 있는 부분이 많긴하지만, 그래도 디테일하게 하나 하나 작성을 하면서 가보려 한다.

이유는 그냥 나중에 내글 보고서 리마인드하기 위함.

---

### 1. CLLocationManagerDelegate 프로토콜 사용

일단 CLLocationManager 관련 클래스를 만들 때, `CLLocationManagerDelegate`를 채택해야 한다.

근데 여기서 바로 채택이 안된다. 먼저 `import CoreLocation`를 해서 임포트를 해줘야 사용이 가능하다. [CoreLocation Docs](https://developer.apple.com/documentation/corelocation){:target="_blank"} 참고.

그리고 바로 Delegate를 쓰면 에러가 발생한다.
`CLLocationManagerDelegate`는 내부적으로 `NSObjectProtocol`을 요구하기 때문이다.

```
Cannot declare conformance to 'NSObjectProtocol' in Swift; 'LocationService' should inherit 'NSObject' instead
```

에러는 위와 같다. 이것에 대한 해결 방법은 간단한데, `NSObject`를 상속받으면 된다. `NSObject`가 `NSObjectProtocol`을 이미 구현하고 있어서 자동으로 요구사항이 충족된다.

이후 `private let locationManager = CLLocationManager()`를 통해 Manager 객체를 만들어 준다.

```swift
import CoreLocation
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
}
```

### 2. delegate 설정 및 초기화

이제 정말 중요한 과정중하나인 delegate를 설정해야한다.

Delegate를 설정하는 이유는 내가 이 프로토콜이 가지고있는 기능을 대리 수행한다는, 일종에 권한 대리 임명이라고 보면 된다.

여기선 그걸 `LocationService`라는 우리가 만든 클래스에게 위임을 해주는것.

```swift
final class LocationService: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
}
```
---

### 3. 기본 기능 구현

이제 LocationService가 행할 기본적인 기능을 구현해본다.

기본적인것들은 사실 [CLLocationManager Docs](https://developer.apple.com/documentation/corelocation/cllocationmanager){:target="_blank"}를 보면 나와있다.

여기서 우리가 러닝앱에 필요한 메서드를 사용하면 될 것같다.

우선 기능을 추려본다. (Docs하단부 Topic을 보면 다 있다.)

1. `requestWhenInUseAuthorization()` - 앱 사용 중 위치 권한 요청. 러닝 시작 전 반드시 필요하다.
2. `startUpdatingLocation()` / `stopUpdatingLocation()` - 러닝 시작/종료 시점에 맞춰 GPS 수집을 켜고 끈다.
3. `desiredAccuracy = kCLLocationAccuracyBest` - GPS 정확도를 최고로 설정. 러닝 경로 추적이 핵심이라 필수다.
4. `distanceFilter` - 몇 미터마다 위치 업데이트를 받을지 설정. 너무 잦으면 배터리 소모가 크고, 너무 드물면 경로가 뭉개진다.
5. `accuracyAuthorization` - 사용자가 정확한 위치를 허용했는지 대략적 위치만 허용했는지 확인. 대략적 위치면 경로 추적이 의미없으니 안내가 필요하다.
6. `allowsBackgroundLocationUpdates = true` - 러닝 중 화면이 꺼지거나 다른 앱으로 전환돼도 GPS 수집을 유지한다.
7. `pausesLocationUpdatesAutomatically = false` - iOS가 자동으로 위치 업데이트를 멈추는 걸 방지한다. 러닝 중 갑자기 끊기면 안 되니까.

---

#### 기본 뼈대

```swift
import Foundation
import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    // MARK: - Basic method
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocations = locations.last{
            print(lastLocations)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        
            // 아직 권한 요청 전 - 권한 요청
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            
            // 자녀 보호 등 시스템 제한 - 앱에서 처리 불가
        case .restricted:
            print("Location access restricted")
            
            // 사용자가 거부 - 설정 앱으로 안내 필요
        case .denied:
            print("Location access denied")
            
            // 항상 허용 - 백그라운드 포함 수집 가능
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
        
            // 앱 사용 중 허용 - 정상 동작
        case .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
            
        default:
            break
        }
    }
    
    // MARK: - Addtional Methods
    
}
```

아주 기본적인 뼈대는 위와 같다.

각각 기능을 적어보면

---

`didUpdateLocations` - GPS 위치 업데이트가 올 때마다 호출된다. `locations.last`로 가장 최신 좌표를 꺼내 쓴다.

`didFailWithError` - 위치 수집에 실패했을 때 호출된다. 권한 문제나 GPS 신호 없음 등이 원인이 될 수 있다.

`locationManagerDidChangeAuthorization` - 권한 상태가 바뀔 때마다 호출된다. 앱 최초 실행 시에도 호출되기 때문에 여기서 권한 요청과 위치 수집 시작을 함께 처리한다.

---

#### 추가 설정

이제 추가로 설정을 해준다.

위에서 나열한 기능들을 역할에 따라 나눌 수 있다.

그래서 아래와 같이 헤더로 분류한것에 맞게 구현을 해본다.

---

##### 권한 / 상태 확인

1. `requestWhenInUseAuthorization()` - 앱 사용 중 위치 권한 요청
    - `locationManagerDidChangeAuthorization` 메서드에서 권한요청 전인 `case .notDetermined:` 일때, `locationManager.requestWhenInUseAuthorization()`를 통해 권한 요청을 하게 된다.

2. `accuracyAuthorization` - 정확한 위치 허용 여부 확인
    - 사용자가 위치 권한을 허용할 때 "정확한 위치"와 "대략적인 위치" 중 선택할 수 있다.
    - 러닝 경로 추적이 핵심인 앱이라 대략적인 위치로는 의미가 없다.
    - 디폴트는 `fullAccuracy`라 init에서 별도 설정은 불필요하다.
    - 다만 사용자가 "대략적인 위치"를 선택한 경우를 대비해, 러닝 시작 시점에 `accuracyAuthorization`이 `.reducedAccuracy`인지 체크하고 `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)`으로 정확한 위치를 요청하는 방식을 사용한다.
    - `withPurposeKey`에 해당하는 키는 Info.plist의 `NSLocationTemporaryUsageDescriptionDictionary`에 미리 등록해야 한다. 그리고 purposeKey에 해당하는 설명 문구를 등록해야 한다.

---

**참고**

accuracyAuthorization의 공식 상수는 다음과 같다

• kCLLocationAccuracyBestForNavigation - 내비게이션용 최고 정확도 (배터리 소모 큼)
• kCLLocationAccuracyBest - 최고 정확도
• kCLLocationAccuracyNearestTenMeters - 10m 단위
• kCLLocationAccuracyHundredMeters - 100m 단위
• kCLLocationAccuracyKilometer - 1km 단위
• kCLLocationAccuracyThreeKilometers - 3km 단위

---

##### 동작 설정

- `desiredAccuracy = kCLLocationAccuracyBest` - GPS 정확도 최고로 설정
- `distanceFilter` - 몇 미터마다 업데이트할지
- `allowsBackgroundLocationUpdates = true` - 백그라운드에서도 GPS 수집
- `pausesLocationUpdatesAutomatically = false` - 자동 중지 방지
- `startUpdatingLocation()` - 러닝 시작 시 수집 시작
- `stopUpdatingLocation()` - 러닝 종료 시 수집 중단

위의 `accuracyAuthorization`와 더불어 동작 설정에 해당하는 부분은 사실 init에서 쓰기에는 앱을 켜자마자 배터리 소모가 심해지기 때문에 러닝을 할때 작동을 해주는것이 바람직 하다고 생각 했다.

```swift
func startTracking() {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.startUpdatingLocation()
}

func stopTracking() {
    locationManager.stopUpdatingLocation()
    locationManager.allowsBackgroundLocationUpdates = false
}
```

그래서 이렇게 해주었다.

`stopTracking()`에서는 위치 수집을 멈추고 백그라운드 허용도 함께 꺼준다. 러닝이 끝난 시점에는 더 이상 GPS가 필요 없고, 결과 화면을 보는 동안 백그라운드에서 불필요하게 배터리를 소모할 이유가 없기 때문이다.

---

### 4. Info.plist 권한 추가

- LocationWhenInUseUsageDescription
- LocationTemporaryUsageDescriptionDictionary

이 두개에 대해 추가를 해준다.

Target -> Info에서 추가를 하면되는데, `LocationTemporaryUsageDescriptionDictionary` 추가를 하려하니 Xcode 자체 AppCrash가 발생.

그리고 빌드를 하면 갑자기 중복에러가 발생해서 보니 Info.plist 파일이 자동으로 생성이 되어 있었다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/f501b095-d163-4c62-9572-c6d0a440913d.png" />

그래서 이렇게 info.plist 목록을 제거해주어 에러를 해결했다.

---

하지만 재시도를 해도 자꾸 저기서 팅겨서 그냥 새롭게 생성된 info.plist에 custom을 하기로 결정.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/501040b7-be28-40b1-85ce-b3f9f9d7f2d1.png" />

이렇게 설정을하고 info.plist에 `Privacy - Location Temporary Usage Description Dictionary`를 추가해준다.

그리고 이건 source code로 변환하여 key와 value를 추가해주었다.
(Source Code로 변환시 `NSLocationTemporaryUsageDescriptionDictionary` 이렇게 NS가 앞에 붙어야함)

```XML
Before
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSLocationTemporaryUsageDescriptionDictionary</key>
	<dict/>
</dict>
</plist>

After
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocationTemporaryUsageDescriptionDictionary</key>
    <dict>
        <key>RunningTracking</key>
        <string>정확한 러닝 경로 기록을 위해 일시적으로 정확한 위치가 필요합니다.</string>
    </dict>
</dict>
</plist>
```

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/c92eb159-7d69-4e1d-8de0-ab636fd52848.png" />

그럼 이렇게 추가된걸 알 수 있다.

---

### 5. Swift 6 반영하기

사실 Swift 6을 반영할지 말지에 대한 고민이 컸다. 하지만 어차피 시간이 지나면 6으로 올라갈건데 해볼거면 지금 하자라는 생각이 강해서 사용하게 되었다.

```swift
final class LocationService: NSObject, CLLocationManagerDelegate {}
```

지금까진 이렇게 사용하면 되었다.

하지만 6부터는 class에 대해서 별도의 언급이 없는이상 `MainActor`가 암묵적으로 사용되어서 이런 위치관련기능또한 MainThread에서 실행된다.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/45b6d0c6-fc4e-4046-97a6-89bd7bd1f7d3.png" />

물론. `@preconcurrency`쓰면 되긴하지만, 어차피 위에서도 바꿔서 해보기로 결정했기에 해당 attribute는 그냥 언급만하고 쓰지는 않는다.

```swift
nonisolated final class LocationService: NSObject, CLLocationManagerDelegate {}
```

이렇게 `nonisolated`를 사용해주면된다.

---

### 6. 테스트 하기

이제 기본 셋업은 끝났다. 테스트를 하기위해 ui를 세팅하고

locationService에 필요한 변수와 didUpdateLocations에 수정을 해준다.

```swift
var latitude: Double = 0
var longitude: Double = 0
var accuracy: Double = 0

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocations = locations.last{
        latitude = lastLocations.coordinate.latitude
        longitude = lastLocations.coordinate.longitude
        accuracy = lastLocations.horizontalAccuracy
    }
}    

```

#### Info.plist 수동설정

실행을하니 info.plist 관련 에러가 발생 그래서 기본적인 세팅을 직접 해준다

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/4b05e327-a62f-4e6e-8a62-4415a93f7299.png" />

이렇게하고 빌드시 아래와 에러가 발생하면

```swift
Multiple commands produce '/Users/dongik/Library/Developer/Xcode/DerivedData/RunWay-azhalxdtuxxrwxfpqdrunkbuxqob/Build/Products/Debug-iphoneos/RunWay.app/Info.plist'
```

타겟을 지워주자.

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/66d51583-d450-4daa-a52e-b2add42c0945.png" />

그리고 아래와 같이 작성

```XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>NSLocationTemporaryUsageDescriptionDictionary</key>
	<dict>
		<key>RunningTracking</key>
		<string>정확한 러닝 경로 기록을 위해 일시적으로 정확한 위치가 필요합니다.</string>
	</dict>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>러닝 중 GPS 경로 추적을 위해 위치 정보가 필요합니다.</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<true/>
		<key>UISceneConfigurations</key>
		<dict/>
	</dict>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>UILaunchScreen</key>
	<dict>
		<key>UILaunchScreen</key>
		<dict/>
	</dict>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
</dict>
</plist>
```

그리고 반드시

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/0d5fffe3-27b4-47b9-8c21-9503cecf267f.png" />

Generate를 No로 해준다. 위에서도 하긴 했는데 다시한번 강조...

---

시뮬레이터에서 info.plist 설정이 제대로 된것을 확인

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/b25f0768-90a8-4b0d-8899-17ace3f5e7f6.png" />

그래서 실기기 테스트 결과 이렇게 잘 되는걸 알 수 있다.
(위치와 좌표는 일부러 블러처리)

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/d0a9aacf-4ddf-4767-ae2a-0c671bf80f44.png" />

---

#### nonisolated와 Thread의 관계

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocations = locations.last {
        latitude = lastLocations.coordinate.latitude
        longitude = lastLocations.coordinate.longitude
        accuracy = lastLocations.horizontalAccuracy
        print("Thread: \(Thread.current)")
    }
}
```

실기기에서 확인해보니 Delegate Callback이 Main Thread에서 실행되는 걸 확인했다.

처음엔 `nonisolated`로 선언했으니 백그라운드에서 호출될 거라 생각했는데 예상과 달랐다.

이유는 간단하다. `nonisolated`는 Actor Isolation을 제거할 뿐, 실행 스레드를 바꾸는 키워드가 아니다.

[Core Location Docs](https://developer.apple.com/documentation/corelocation/cllocationmanager){:target="_blank"}를 보면 Delegate Callback은 `CLLocationManager`가 생성된 스레드의 RunLoop에서 호출된다고 명시되어 있다.

현재 구조에서는 SwiftUI View에서 `LocationService`를 생성하고, 그 안에서 `CLLocationManager`도 함께 초기화된다.

```
SwiftUI View (Main Thread)
→ LocationService 초기화
→ CLLocationManager 초기화
→ Delegate Callback (Main Thread)
```

결국 `nonisolated ≠ Background Thread`다. Actor는 "어느 스레드에서 실행할지"가 아니라 "어느 컨텍스트에서 상태에 접근할 수 있는지"를 정의하는 개념이고, 실제 실행 스레드는 해당 API의 구현 방식에 따라 결정된다.

---

### 7. Background Mode 추가

현재 startTracking이 실행되면 AppCrash가 발생한다.

```swift
func startTracking() {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.startUpdatingLocation()
}
```

여기서 `locationManager.allowsBackgroundLocationUpdates = true` 이부분에서 에러가 발생하는것.

Target으로 가서

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/fbca788b-001e-45a2-bbcc-09d19ef4355d.png" />

이렇게 추가를 해주고

<img width="50%" height="50%" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/5b4c7217-9246-47ec-b324-2cd828002f61.png" />

location에 체크를 해준다.

---

### 8. 실기기 `startTracking` Test

```swift
func startTracking() {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.startUpdatingLocation()
}

func stopTracking() {
    locationManager.stopUpdatingLocation()
    locationManager.allowsBackgroundLocationUpdates = false
}
```

지금은 이렇게 되어있어서 제대로 Tracking이 되는지 확인이 어렵다

그래서

```swift
var logs: [String] = []

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocations = locations.last{
        latitude = lastLocations.coordinate.latitude
        longitude = lastLocations.coordinate.longitude
        accuracy = lastLocations.horizontalAccuracy
        addLog("위치 업데이트 → lat: \(String(format: "%.5f", latitude)), lon: \(String(format: "%.5f", longitude))")
    }
}

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    // 생략
        
        // 항상 허용 - 백그라운드 포함 수집 가능
    case .authorizedAlways:
        //locationManager.startUpdatingLocation()
        break
        // 앱 사용 중 허용 - 정상 동작
    case .authorizedWhenInUse:
        //locationManager.startUpdatingLocation()
        break
    default:
        break
    }
}

func startTracking() {
    addLog("러닝을 시작합니다")
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 5
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.startUpdatingLocation()
}

func stopTracking() {
    addLog("러닝을 중단합니다")
    locationManager.stopUpdatingLocation()
    locationManager.allowsBackgroundLocationUpdates = false
}

// MARK: - For Test

private func addLog(_ message: String) {
    let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    logs.insert("[\(time)] \(message)", at: 0)
    if logs.count > 20 { logs.removeLast() }
}
```

이렇게 해주었다.

그리고 테스트용 UI에도 적용해주었다.

지금은 5미터 이동하면 출력을 하게 되어있다.

일단은 시뮬레이터에서는 작동이 된다.

<img width="472" height="986" alt="Image" src="https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2026-06-03-RunningProject-2/0921446d-ee77-4f6b-9694-6e3bbe8ed3f2.png" />{: width="50%" height="50%"}

---

실기기테스트도 확인완료.