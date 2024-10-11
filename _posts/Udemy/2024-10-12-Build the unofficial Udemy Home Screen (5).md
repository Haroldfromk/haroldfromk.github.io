---
title: Build the unofficial Udemy Home Screen (5)
writer: Harold
date: 2024-10-12 05:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## CategoryTextHeader 추가

```swift
.init(section: .textheader(id: "1233332"), body: [
                .textHeader(id: "1234fds", text: "Categories", highlightedText: nil)
```

이렇게 적어주면 Categories가 생긴다.

## CategoryView 추가

### 모델링

그전에 먼저 모델링을 해준다.

```swift
enum Category: String, CaseIterable {
    case development
    case business
    case officeProductivity
    case healthAndFitness
    case teachingAndAcademics
    case financeAndAccounting
    case itAndSoftware
    case personalDevelopment
    case marketing
    case photographyAndVideo
    case design
    case lifestyle
    case Music
}
```

이때 처음 보는것이 있다. 바로 `CaseIterable`

CaseIterable은 Swift의 프로토콜로, enum 타입에 적용하여 해당 enum이 가지는 모든 케이스를 컬렉션처럼 순회할 수 있도록 해준다. 

즉, CaseIterable을 채택한 enum은 자동으로 allCases라는 배열 형태의 속성을 제공하며, 이를 통해 열거형의 모든 케이스에 접근할 수 있다.

주요 기능:
- 자동으로 allCases 배열 제공: CaseIterable을 적용한 enum은 모든 케이스를 포함하는 allCases 배열을 자동으로 생성한다.
- 케이스 순회 가능: allCases 배열을 통해 for-in 루프를 사용하여 enum의 모든 케이스를 순회할 수 있다

```swift
enum Category: String, CaseIterable {
    case development
    case business
    case officeProductivity
    case healthAndFitness
    // 다른 케이스들...
}

for category in Category.allCases {
    print(category.rawValue)
}
```

장점:
- enum의 모든 케이스를 쉽게 관리하고 접근할 수 있다.
- enum의 케이스 목록을 사용해 드롭다운 메뉴, 필터링 기능 등을 쉽게 구현할 수 있다.

---

### CategoryButton 만들기

```swift
struct CatgoryButton: View {
    let title: String
    let onTap: (() -> Void)?
    
    var body: some View {
        Button {
            self.onTap?()
        } label: {
            Text(title)
                .padding(.all, 12)
                .font(.system(size: 10,weight: .semibold))
                .foregroundStyle(.black)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.black, lineWidth: 1.0))
        }
    }
}
```

카테고리 버튼을 만들어준다.

### CategoryView 만들기

```swift
struct CategoriesView: View {
    let titles: [String]
    
    var midPoint: Int {
        return Int(titles.count / 2)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack {
                    ForEach(titles[..<midPoint], id: \.self) { title in
                        CatgoryButton(title: title) {
                            print(">>>> tapped: \(title)")
                        }
                        
                    }
                }
                
                HStack {
                    ForEach(titles[midPoint...], id: \.self) { title in
                        CatgoryButton(title: title) {
                            print(">>>> tapped: \(title)")
                        }
                        
                    }
                }
            }
        }
    }
}
```

Lazy가 붙었는데 우리가 알고있는 그 Lazy가 맞다.

필요로 하기전까지는 메모리에 상주시키지 않는다.

![CleanShot 2024-10-12 at 05 04 08](https://github.com/user-attachments/assets/3dd9fb9e-6cab-4878-9dc5-737a46e1509a){: width="50%" height="50%"} 

이렇게 나온다.

**`\.self`?** 

`\.self`는 Swift에서 ForEach와 같은 반복 구조에서 사용되는 키 경로(key path) 구문이다. 이는 Swift의 Identifiable 프로토콜을 따르지 않는 타입에서 고유한 값을 참조하기 위해 사용된다. 여기서는 String 배열의 각 요소가 반복문 내에서 고유하게 식별될 수 있도록, 해당 요소 자체를 식별자로 사용하겠다는 의미이다.


- ForEach는 각 항목을 식별할 수 있는 값이 필요하다. titles 배열은 String 타입이므로, 문자열 자체로 각 항목을 고유하게 식별할 수 있다.
- \.self는 각 String 값 그 자체를 고유 식별자로 사용한다는 의미이다. 즉, 각 String이 해당 반복 항목의 ID로 사용된다.

```swift
ForEach(titles[..<midPoint], id: \.self) { title in
    CatgoryButton(title: title) {
        print(">>>> tapped: \(title)")
    }
}
```

여기서 id: \.self는 ForEach가 각 title을 고유하게 식별할 수 있도록, title 그 자체를 ID로 사용하겠다는 의미이다. 각 title은 배열 내에서 고유하기 때문에 ForEach는 이를 사용해 아이템을 구분할 수 있다.

정리:
- \.self는 그 값 자체를 고유 식별자로 사용한다는 의미이다.
- 이 구문은 값 타입이 Identifiable 프로토콜을 따르지 않는 경우에 주로 사용된다.
- 위 코드에서는 String 타입의 값 자체를 식별자로 사용하고 있다.

---

## CategoriesCollectionViewCell 추가

이전에 했던것과 같은 방식이다.

```swift
private var hostingController: UIHostingController<CategoriesView>!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(titles: [String]) {
        guard hostingController == nil else { return }
        let categoriesView = CategoriesView(titles: titles)
        hostingController = UIHostingController(rootView: categoriesView)
        addSubview(hostingController.view)
        hostingController.view.clipsToBounds = true
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
```

패스.

## HomeCollectionView에 추가하기

### 1. Cell 등록

```swift
private func setup() {
        register(MainBannerCollectionViewCell.self, forCellWithReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier)
        register(TextHeaderCollectionViewCell.self, forCellWithReuseIdentifier: TextHeaderCollectionViewCell.namedIdentifier)
        register(CourseCollectionViewCell.self, forCellWithReuseIdentifier: CourseCollectionViewCell.namedIdentifier)
        register(CategoriesCollectionViewCell.self, forCellWithReuseIdentifier: CategoriesCollectionViewCell.namedIdentifier)
    }
```

### 2. Datasource 추가

```swift
private func setupDataSource() {
        diffableDataSource = UICollectionViewDiffableDataSource(collectionView: self, cellProvider: { collectionView, indexPath, item in
            switch item {
            case let .mainBanner(_, imageLink, title, caption):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier, for: indexPath) as! MainBannerCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, caption: caption)
                return cell
            case let .textHeader(_, title, highlightedText):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextHeaderCollectionViewCell.namedIdentifier, for: indexPath) as! TextHeaderCollectionViewCell
                cell.configure(text: title, highlightedText: highlightedText)
                return cell
            case let .course(_, imageLink, title, author, rating, reviewCount, price, tag):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CourseCollectionViewCell.namedIdentifier, for: indexPath) as! CourseCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, author: author, rating: rating, reviewCount: reviewCount, price: price, tag: tag)
                return cell
            case let .categoriesScroller(_, titles):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoriesCollectionViewCell.namedIdentifier, for: indexPath) as! CategoriesCollectionViewCell
                cell.configure(titles: titles)
                return cell
            default :
                fatalError()
            }
        })
    }
```

### 3. Compositional Layout 설정

```swift
private func makeCompositionalLayout() -> UICollectionViewCompositionalLayout {
        
        let provider: UICollectionViewCompositionalLayoutSectionProvider = { [weak self] index, env in
            
            guard let sectionModel = self?.uiModel?.sectionModels[index] else { return nil }
            
            switch sectionModel.section {
            case .mainBanner:
                return self?.makeMainBannerSection()
            case .textheader:
                guard case let .textHeader(_, text, _) = sectionModel.body.first else { return nil }
                return self?.makeTextHeaderSection(text: text)
            case .courseSwimlane:
                return self?.makeCourseSwimlaneSection()
            case .categories:
                return self?.makeCategoriesSection()
            default :
                fatalError()
            }
        }
        return UICollectionViewCompositionalLayout(sectionProvider: provider)
    }
```

### 4. makeCategoriesSection 함수 설정

```swift
private func makeCategoriesSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(88))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
        
        return section
    }
```

## HomeVC에 데이터 추가

```swift
override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        let uiModel = HomeUIModel(sectionModels: [
            .init(section:.mainBanner(id: "123"), body: [
                .mainBanner(
                    id: "123",
                    imageLink: "https://images.unsplash.com/photo-1627634777217-c864268db30c?q=80&w=1740&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D", title: "Some Title",
                    caption: "some caption")
            ]),
            .init(section: .textheader(id: "2321"), body: [
                .textHeader(
                    id: "879",
                    text: "Newest courses in Mobile Development",
                    highlightedText: "Mobile Development")
            ]),
            .init(section: .courseSwimlane(id: "4432"), body: [
                .course(
                    id: "313123",
                    imageLink: "https://picsum.photos/300/200",
                    title: "iOs & Swift: Server Driven UI Compositional Layout & SwiftUI",
                    author: "Kelvin Fok",
                    rating: 4.5,
                    reviewCount: 224,
                    price: 19.99,
                    tag: "BestSeller"),
                .course(
                    id: "313124",
                    imageLink: "https://picsum.photos/300/200",
                    title: "iOs &z Swift: SwiftUI Mastery",
                    author: "Kelvin Fok",
                    rating: 4.2,
                    reviewCount: 224,
                    price: 19.99,
                    tag: "BestSeller"),
                .course(
                    id: "313125",
                    imageLink: "https://picsum.photos/300/200",
                    title: "iOs & Swift: AutoLayout",
                    author: "Kelvin Fok",
                    rating: 3.5,
                    reviewCount: 224,
                    price: 19.99,
                    tag: "BestSeller")
            ]),
            .init(section: .textheader(id: "1233332"), body: [
                .textHeader(id: "1234fds", text: "Categories", highlightedText: nil)
            ]),
            .init(section: .categories(id: "sdf1"), body: [
                .categoriesScroller(id: "123444", titles: Category.allCases.map({
                    $0.rawValue.camelCaseToEnglish.useShortAndFormat.capitalized }))
            ])
        ])
        collectionView.setupDataSource(uiModel: uiModel)
    }
```

![simulator_screenshot_91A56CE3-7A6D-49FC-991D-12DD529A4F38](https://github.com/user-attachments/assets/4f238658-1641-47e7-84fa-c8ce3814d0ff){: width="50%" height="50%"} 

카테고리 뷰가 너무 붙어있어서 패딩을 준다.

```swift
struct CategoriesView: View {
    let titles: [String]
    
    var midPoint: Int {
        return Int(titles.count / 2)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack {
                    ForEach(titles[..<midPoint], id: \.self) { title in
                        CatgoryButton(title: title) {
                            print(">>>> tapped: \(title)")
                        }
                        
                    }
                }
                
                HStack {
                    ForEach(titles[midPoint...], id: \.self) { title in
                        CatgoryButton(title: title) {
                            print(">>>> tapped: \(title)")
                        }
                        
                    }
                }
            }
            .padding(.horizontal, 20) // added
        }
    }
}
```

![simulator_screenshot_EE06826D-5B66-4F4D-84AB-A89BAD8BA994](https://github.com/user-attachments/assets/98b2fc11-5565-4ccb-82b0-791dbcf470ec){: width="50%" height="50%"} 

완성.

대부분 반복이라 크게 서술할건 없다.


