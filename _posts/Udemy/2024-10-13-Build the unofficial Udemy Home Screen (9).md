---
title: Build the unofficial Udemy Home Screen (9)
writer: Harold
date: 2024-10-13 01:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## APIResponse를 UIModel에 파싱하기

이전에는 Json으로 데이터를 가져오지 않았기에

```swift
let uiModel = HomeUIModel(sectionModels: [
            .init(section:.mainBanner(id: "123"), body: [
```

이렇게 ViewDidLoad에 값을 넣어 주었는데, 이젠 JSON에 값이 있기에 JSON을 사용하여 바로 로드를 해보기로 한다.

ViewDidLoad에 있던 uiModel에 관한 내용은 모두 날리자.

## Helper 설정

```swift
struct HomeUIModelHelper {
    typealias SectionModel = HomeUIModel.SectionModel
    
    static func makeUIModel(response: APIResponse) -> HomeUIModel {
        var sectionModels = [SectionModel]()
        for layout in response.layouts {
            switch layout {
            case let .mainBanner(id, mainBanner):
                let sectionModel = SectionModel(
                    section: .mainBanner(id: id),
                    body: [.mainBanner(
                        id: mainBanner.id,
                        imageLink: mainBanner.imageLink,
                        title: mainBanner.title,
                        caption: mainBanner.caption)
                    ])
                sectionModels.append(sectionModel)
            case let .textHeader(id, textHeader):
                let sectionModel = SectionModel(
                    section: .textHeader(id: id),
                    body: [.textHeader(
                        id: textHeader.id,
                        text: textHeader.text,
                        highlightedText: textHeader.highlightedText)
                    ])
                sectionModels.append(sectionModel)
            case let .courseSwimlane(id, courses):
                let items: [HomeUIModel.Item] = courses.map { course in
                    return .course(id: course.id, imageLink: course.imageLink, title: course.title, author: course.author, rating: course.rating, reviewCount: course.reviewCount, price: course.price, tag: course.tag)
                }
```

일부만 적는다.

---

## 문제해결

갑자기 

`guard let sectionModel = self?.uiModel?.sectionModels[index] else { return nil }` 여기부분에서 에러가 발생했다.

에러내용은 다음과 같다.

```
'nil' is not compatible with closure result type 'NSCollectionLayoutSection'
```

HomeUIModelHelper를 적으면서 생긴문제이니 거기서부터 확인을 해봐야겠다.

그부분은 문제가 없었다.

init에서 차이가있음을 발견

실행했을때는 차이가 없어서 이부분은 GPT를 통해 내용을 좀 더 적는다.

```swift
//wrong
init() {
        super.init(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionViewLayout = makeCompositionalLayout()
        registerCells()
        setupDataSource()
    }

//correct
init() {
    super.init(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout()) // different
    collectionViewLayout = makeCompositionalLayout()
    registerCells()
    setupDataSource()
  }
```

1. UICollectionViewLayout
- 추상 클래스로, UICollectionView의 모든 레이아웃의 기본 클래스.
- 직접 사용하지 않고, 레이아웃을 커스터마이징하려면 이 클래스를 서브클래싱하여 구현함.
- 개발자가 컬렉션 뷰의 레이아웃을 완전히 제어하고 싶을 때 사용하는 클래스.

```swift
class CustomLayout: UICollectionViewLayout {
    
    override func prepare() {
        super.prepare()
        // 커스텀 레이아웃 준비 작업
    }
    
    override var collectionViewContentSize: CGSize {
        // 컬렉션 뷰의 전체 콘텐츠 크기 정의
        return CGSize(width: 1000, height: 1000)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributes = [UICollectionViewLayoutAttributes]()
        // 주어진 rect에 표시할 아이템의 레이아웃 속성 계산
        return attributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        // 특정 아이템의 레이아웃 속성 정의
        attributes.frame = CGRect(x: indexPath.row * 50, y: 0, width: 50, height: 50)
        return attributes
    }
}
```

2. UICollectionViewFlowLayout
- UICollectionViewLayout의 서브클래스.
- 미리 정의된 표준 레이아웃을 제공함.
- 아이템을 그리드 형식으로 행(row)이나 열(column)에 자동으로 배치하는 레이아웃을 제공.
- 일반적인 수평 및 수직 스크롤을 처리하는 레이아웃으로 많이 사용됨.
- 간단한 설정으로 섹션 간 간격, 아이템 크기, 스크롤 방향 등을 제어 가능.

```swift
let flowLayout = UICollectionViewFlowLayout()
flowLayout.itemSize = CGSize(width: 100, height: 100)
flowLayout.minimumLineSpacing = 10
flowLayout.minimumInteritemSpacing = 10
flowLayout.scrollDirection = .vertical

let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
```

차이점
- UICollectionViewLayout은 추상적인 기본 클래스로, 완전한 커스텀 레이아웃을 만들 때 사용.
- UICollectionViewFlowLayout은 그리드 레이아웃을 제공하는 구현된 클래스로, 커스텀이 필요 없는 경우 쉽게 사용할 수 있음.

>실행해도 문제가 없는 이유.

1.	초기 기본 레이아웃 설정:
- UICollectionViewFlowLayout은 컬렉션 뷰의 기본적인 그리드형 레이아웃(아이템 크기, 간격, 스크롤 방향 등)을 자동으로 처리해 줍니다. 만약 초기화 시 UICollectionViewFlowLayout을 사용하면 기본적인 레이아웃이 설정됨.
- 반면에, UICollectionViewLayout은 추상적인 기본 클래스이므로, 레이아웃 관련 동작을 모두 직접 구현해야 힌디. 만약 이후에 makeCompositionalLayout()으로 레이아웃을 변경할 예정이라면, 초기화 시 UICollectionViewLayout을 사용해도 문제가 발생하지 않을 수 있다.
2.	의미적인 차이:
- UICollectionViewFlowLayout은 명시적으로 기본 그리드 레이아웃을 사용할 의도를 나타낸다. 즉, 기본적으로 표준적인 흐름(flow) 레이아웃을 사용하고 있음을 명확히 알 수 있다.
- UICollectionViewLayout은 그 자체로 아무런 레이아웃을 설정하지 않으므로, 이후에 별도로 레이아웃을 설정할 의도임을 나타낸다.

>왜 문제가 없을까?

현재 코드에서 collectionViewLayout = makeCompositionalLayout()으로 나중에 레이아웃을 덮어씌우기 때문에 초기화 시 사용한 UICollectionViewFlowLayout이나 UICollectionViewLayout이 최종적으로 반영되지 않는다.
makeCompositionalLayout()에서 설정한 레이아웃이 최종적으로 사용되기 때문에 문제가 발생하지 않는 것.
하지만 명확하게 의도를 표현하고 싶다면 UICollectionViewFlowLayout을 사용하는 것이 더 좋다.

---

그리고 `makeCompositionalLayout` 힘수에서도 발견

```swift
//wrong
case .textheader:
                guard case let .textHeader(_, text, _) = sectionModel.body.first
                else { return nil }
                return self?.makeTextHeaderSection(text: text)
//correct
case .textHeader:
                guard case let .textHeader(_, text, _) = sectionModel.body.first
                else { return nil }
                return self?.makeTextHeaderSection(text: text)
```

해당에러는 이런 대소문자나 기타 에러에 의해서 파생된 에러로 확인되었다.

---

이후 HomeVC로가서

```swift
private func loadJSON() {
        let apiResponse: APIResponse? = FileManager.modelFromJSON(fileName: "payload")
        
        if let response = apiResponse {
            let uiModel = HomeUIModelHelper.makeUIModel(response: response)
            collectionView.setDataSource(uiModel: uiModel)
        }
            
    }
```

uiModel을 적용시켜준다.

## 서버를 통한 JSON 로드하기

[Mocky](https://designer.mocky.io/){:target="_blank"} 를 사용하여, JSON의 내용을 모두 복사한뒤 업로드한다.

![CleanShot 2024-10-13 at 04 23 38](https://github.com/user-attachments/assets/1cdfc8cb-c920-4d01-b716-6d9f00de48da)

New Mock을 클릭하면 위와같이 나오는데 Response에 내용을 복사하자.

이후 Generate를 하면

![CleanShot 2024-10-13 at 04 24 57](https://github.com/user-attachments/assets/6da53647-42bc-454a-aae2-4433da503ba7)

이렇게 링크가 생성이 된다.

링크를 타고들어가면 우리가 복사한 내용이 그대로 보인다.


```swift
struct APIClient {
    
    private let urlString =
    "https://run.mocky.io/v3/7efcd0a5-21fd-4f12-9e73-7aaa6701d722"
    
    func fetchLayout() -> AnyPublisher<APIResponse, Error> {
        return URLSession.shared.dataTaskPublisher(for: URL(string: urlString)!)
            .map({$0.data})
            .decode(type: APIResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
```

API호출 관련 Struct를 만들어 주었다.

```swift
private let apiClient = APIClient()

private func fetchLayout() {
        apiClient.fetchLayout()
            .receive(on: DispatchQueue.main)
            .sink { completion in
            if case let .failure(error) = completion {
                print("Error: \(error)")
            }
        } receiveValue: { [weak self] apiResponse in
            let uiModel = HomeUIModelHelper.makeUIModel(response: apiResponse)
            self?.collectionView.setupDataSource(uiModel: uiModel)
        }.store(in: &cancellables)
        
        
        //        let apiResponse: APIResponse? = FileManager.modelFromJSON(fileName: "payload")
        //
        //        if let response = apiResponse {
        //            let uiModel = HomeUIModelHelper.makeUIModel(response: response)
        //            collectionView.setupDataSource(uiModel: uiModel)
        //        }
        
    }
```

loadJSON에서 fetchLayout으로 함수명을 바꿔주었다.

이젠 JSON에 아무런 내용이 없어도 서버에서 가져오기에 로드가 된다.

작동화면은 달라진게 없어서 패스