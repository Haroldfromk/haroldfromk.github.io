---
title: Build the unofficial Udemy Home Screen (8)
writer: Harold
date: 2024-10-12 06:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## FileManager Extension 구성하기

```swift
extension FileManager {
    static func modelFromJSON<T: Decodable>(fileName: String) -> T? {
        
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json") else {
            print(">>> Path not found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let stringValue = String(data: data, encoding: .utf8)
            print(">>> StringValue: \(stringValue)")
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print(">>> Error reading JSON File: \(error.localizedDescription)")
            return nil
        }
    }
}
```

1.	<T: Decodable>:
- **T**는 제네릭 타입 매개변수로, 이 함수가 반환할 타입을 의미한다.
- **T: Decodable**은 제약 조건으로, T는 반드시 Decodable 프로토콜을 준수해야 한다는 것을 의미한다. 즉, T는 JSON 데이터를 디코딩할 수 있는 타입이어야 한다. Decodable 프로토콜은 구조체, 클래스, 열거형이 JSON 등의 외부 데이터 포맷에서 변환 가능한 모델이어야 함을 의미한다.
- 이 제네릭을 통해, JSON 파일에서 특정 타입의 데이터 모델을 동적으로 디코딩할 수 있다. 즉, T는 실행 시점에 결정되며 다양한 타입으로 사용할 수 있다.

---

1. 파일 경로 찾기
- 주어진 fileName과 확장자가 .json인 파일을 앱 번들 내에서 찾는다. 파일 경로가 없을 경우 nil을 반환한다.
2. 파일 데이터를 Data로 변환
- 찾은 파일의 경로를 사용해 파일을 읽어들여 Data 객체로 변환한다. 이 데이터는 JSON 형식의 파일 내용을 바이트로 읽어들인 것이다.
- options: .mappedIfSafe는 파일 내용을 메모리 맵 방식으로 로드하는 옵션으로, 파일을 안전하게 메모리에 로드하도록 한다.
3. JSON 디코딩
- JSONDecoder()를 사용하여 JSON 데이터를 제네릭 타입 T로 디코딩한다. 여기서 T.self는 타입을 나타내며, 해당 타입으로 JSON 데이터를 변환한다.
- option의 `mappedIfSafe`
    - **.mappedIfSafe**는 파일을 메모리에 매핑할 때 안전한 방식으로 매핑하겠다는 의미이다. 이 옵션은 큰 파일을 다룰 때 메모리를 효율적으로 관리하기 위해 사용된다.
    - 파일을 메모리에 매핑하는 방식인데, 이 방식은 시스템이 해당 파일을 안전하다고 판단하는 경우에만 매핑을 사용한다. 시스템에 의해 안전하지 않다고 판단되면 일반적인 방식으로 파일을 읽어온다.
- 이 과정에서 JSON 데이터가 제네릭 타입 T로 변환되며, 성공하면 변환된 객체를 반환하고, 실패하면 에러를 발생시킨다.

## HomeVC에 JSON Load 함수 구성

```swift
private func loadJSON() {
        let response: APIResponse? = FileManager.modelFromJSON(fileName: "payload")
    }
    
```

그리고 ViewDidLoad에서 해당 함수를 호출한다.

![CleanShot 2024-10-13 at 01 27 27](https://github.com/user-attachments/assets/b8a84258-a743-4c8f-a7c7-d160e95a3d3e){: width="50%" height="50%"} 

이렇게 실행하니 json파일이 잘 콘솔에 출력이됨을 알 수 있다.

## API Response 구성하기

Response를 구성할때는 Top to Bottom으로 진행하는데

JSON의 제일 상위부터 시작한다.

![CleanShot 2024-10-13 at 01 31 43](https://github.com/user-attachments/assets/0a9f1501-75e5-4788-82b4-607197f42dba)

즉 status, layouts부터 구성.

```swift
struct APIResponse: Decodable {
    
    let status: Int
    let layouts: [Layout]
    
}
```

### 1. Layout 구성

Layout은 type에 따라 다르므로.

![CleanShot 2024-10-13 at 01 35 47](https://github.com/user-attachments/assets/f6b9bf51-306a-4192-a51d-bd62fb2c3d4e){: width="50%" height="50%"} 

enum을 사용해서 구성한다.

```swift
enum Layout {
        case mainBanner(String, MainBanner)
    }
    
    struct MainBanner {
        let id: String
        let imageLink: String
        let title: String
        let caption: String
    }
```

이렇게 앞에 String, MainBanner로 나눈 이유는

![CleanShot 2024-10-13 at 01 39 28](https://github.com/user-attachments/assets/6053b529-550f-48c5-8ba2-2fe840a23d47)

id는 String이고 Value는 MainBanner Struct를 사용해서 구성을 하기 때문에 이렇게 했다.

이렇게 JSON의 값을 확인해서 구성을 해주자.

Course의 경우 

`case swimLane(String, [Course])`

이렇게 배열로 감싼건

![CleanShot 2024-10-13 at 02 06 34](https://github.com/user-attachments/assets/1a6db809-b327-4362-a3cb-60dd6ec85a78)

사진을 전부 표현하기엔 길어서 상단만 했는데 이렇게 배열로 값이 감싸지기 때문.

배열로 감싸지 않은건

![CleanShot 2024-10-13 at 02 07 29](https://github.com/user-attachments/assets/a7279f28-bd53-410c-8ba5-0b991835489c)

이렇게 `[`로 시작하지 않는다.

![CleanShot 2024-10-13 at 02 49 34](https://github.com/user-attachments/assets/a71b4cb8-d4ba-47a4-b7b9-f683b53cf6c1)

이렇게 에러가 나기에 에러를 수정하기위해 initializing을 해줘야한다.

```swift
init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            let id = try container.decode(String.self, forKey: .id)
            switch type {
            case "mainBanner":
                let model = try container.decode(MainBanner.self, forKey: .value)
                self = .mainBanner(id, model)
            case "textHeader":
                let model = try container.decode(TextHeader.self, forKey: .value)
                self = .textHeader(id, model)
            case "courseSwimlane":
                let models = try container.decode([Course].self, forKey: .value)
                self = .courseSwimlane(id, models)
            case "categories":
                let model = try container.decode(Categories.self, forKey: .value)
                self = .categories(id, model)
            case "featuredCourse":
                let model = try container.decode(Course.self, forKey: .value)
                self = .featuredCourse(id, model)
            case "udemyBusinessBanner":
                let model = try container.decode(UdemyBusinessBanner.self, forKey: .value)
                self = .udemyBusinessBanner(id, model)
            default:
                self = .unknown(type)
            }
        }
```
---

>APIResponse.Layout 구조체의 init(from decoder: any Decoder) 부분은 디코딩 로직을 정의하는 커스텀 초기화 메서드이다.
이 부분은 JSON 데이터를 파싱하여 해당 Layout 케이스로 변환하는 역할을 한다.
이 초기화 메서드에서는 특정 키(type, id, value)에 따라 적절한 케이스를 선택하고 그에 맞는 데이터를 디코딩하여 해당 케이스로 초기화한다.

1. Decoder 객체로부터 데이터를 읽어오는 과정
- `let container = try decoder.container(keyedBy: CodingKeys.self)`
- decoder로부터 컨테이너를 가져옴. 이 컨테이너는 JSON의 키-값 쌍을 읽는 역할을 함.
- CodingKeys는 JSON의 키를 정의한 열거형이고, 이를 통해 데이터를 읽음.
2. type과 id 필드 읽기
- JSON의 type과 id 필드를 읽음.
- type은 JSON에서 어떤 레이아웃인지 나타내고, id는 그 레이아웃의 고유 식별자임.
3. switch문으로 type에 따른 분기 처리
- type 값에 따라 어떤 케이스로 디코딩할지 결정함.
- type에 따라 mainBanner, textHeader, courseSwimlane 등 여러 케이스로 분기함.
4.  케이스별 디코딩 처리
- 각 케이스에 맞는 데이터를 디코딩하고, self에 해당 케이스로 할당함.
    - a. mainBanner 케이스
        - type이 "mainBanner"인 경우, JSON에서 MainBanner 타입으로 데이터를 디코딩함.
	    - self는 .mainBanner(id, model)로 할당됨.
    - b. 다른 케이스 (textHeader, courseSwimlane 등)
        - 각 케이스마다 비슷한 방식으로 해당 모델을 디코딩하고, self에 적절한 케이스로 할당함.
        - 예를 들어, textHeader는 TextHeader 타입으로, courseSwimlane은 Course 배열로 디코딩됨.
5. 기본 케이스
- type이 정의되지 않은 값인 경우, unknown 케이스로 처리함.

---

그래도 에러가 발생하는걸 보니 struct로 한것들도 모두 Decodable 뿐만 아니라 Hashable을 적용시켜줘야 한다는걸 알았다.

```swift
    struct MainBanner: Decodable, Hashable {
        let id: String
        let imageLink: String
        let title: String
        let caption: String
    }
    
    struct TextHeader: Decodable, Hashable {
        let id: String
        let title: String
        let highlightedText: String?
    }
    
    struct Course: Decodable, Hashable {
        let id: String
        let imageLink: String
        let title: String
        let author: String
        let rating: Double
        let reviewCount: Int
        let price: Decimal
        let tags: String
    }
    
    struct Categories: Decodable, Hashable {
        let id: String
        let title: [String]
    }
    
    struct UdemyBusinessBanner: Decodable, Hashable {
        let id: String
        let link: String
    }
```

여기서 

![CleanShot 2024-10-13 at 03 11 10](https://github.com/user-attachments/assets/60432319-24ab-4b0e-8df5-e84da4494081)

type, id, value만 key로 사용하므로 

나머지는 지우자.

```swift
private enum CodingKeys: String, CodingKey {
            case type, value, id
        }
```

그리고 Hashable도 필요없으므로, 해당 프로토콜을 모두 지워준다.

혹시나 실행을 했는데

```
>>> Error reading JSON File: keyNotFound(CodingKeys(stringValue: "title", intValue: nil), Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "layouts", intValue: nil), _CodingKey(stringValue: "Index 4", intValue: 4), CodingKeys(stringValue: "value", intValue: nil)], debugDescription: "No value associated with key CodingKeys(stringValue: \"title\", intValue: nil) (\"title\").", underlyingError: nil))
>>> response: nil
```

이런 에러가 발생한다면

4번째 레이아웃에서 발생한 에러인데 title이 없다라는것이므로

그부분에 오타가 있는지 봐야한다.

```swift
struct Categories: Decodable {
        let id: String
        let title: [String]
    }
```

title로 해두었는데 json을 가서 확인하면

![CleanShot 2024-10-13 at 03 08 39](https://github.com/user-attachments/assets/1d5e8646-32dc-415e-a3ab-49a745cc0b72)

title이 아닌 titles이다.

이렇게 json과 다르면 에러가 나므로 오타를 잘 확인하자.

Json의 변수를 그대로 잘 맞춰주었다면 실행했을때

```
>>> response: Optional(ios_udemy_home.APIResponse(status: 200, layouts: [ios_udemy_home.APIResponse.Layout.mainBanner("79c7e84a-d29b-11ee-8a80-325096b39f47",
```

이런 결과를 얻게된다.