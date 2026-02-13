---
title: Build the unofficial Udemy Home Screen (4)
writer: Harold
date: 2024-10-11 12:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

![CleanShot 2024-10-11 at 16 06 11](https://github.com/user-attachments/assets/d18b3da6-e8b7-48d1-8b1c-8869fcc852ab){: width="50%" height="50%"} 

지금까지 빨간색 테두리로 된 부분을 만들었다.

주황색 테두리가 이제 만들 CourseView이다.

그전에 조금 수정을 한다.

## Textheader 간격주기

```swift
private func makeMainBannerSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(220))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
        
        return section
    }
```

return 으로 섹션을 바로 하던걸 인스턴스화 하였고, Insets를 주었다.

![simulator_screenshot_37D87EA5-24B0-4ABF-89FC-8DE3DA83C814](https://github.com/user-attachments/assets/d238be82-223c-4126-9433-35278d50c73c){: width="50%" height="50%"} 

그리고 노란색 배경도 지웠다. (이건 서술할 필요가 없을듯해서 생략)


## CourseView 추가

우선 필요한 변수들을 만들어 준다.

```swift
struct CourseView: View {
    let imageLink: String
    let title: String
    let author: String
    let rating: Double
    let reviewCount: Int
    let price: Decimal
    let tag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: URL(string: imageLink)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .border(Color.gray.opacity(0.3))
                    .clipped()
            } placeholder: {
                PlaceholderImageView()
                    .frame(height: 64)
            }.padding(.bottom, 4)
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .fixedSize(horizontal: false, vertical: true)
            Text(author)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(.gray)
        }
    }
}
```

크게 언급할만한건 없는듯 하다.

![CleanShot 2024-10-11 at 16 37 25](https://github.com/user-attachments/assets/5e4f385e-edbe-46e6-a673-0b68d7e83f31){: width="50%" height="50%"} 

이렇게 나온다.

## ReviewRaingView 만들기

```swift
struct ReviewRatingView: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 4, content: {
            Text(rating.description)
                .foregroundStyle(.orange)
                .font(.system(size: 10, weight: .semibold))
            Image(systemName: "star.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 10)
                .foregroundStyle(.yellow)
            Text(reviewCount.formatted())
                .foregroundStyle(.gray)
                .font(.system(size: 10))
        })
    }
}
```

이때 rating은 Dount, reviewCount는 Int인데 Text는 String을 받는다.

그래서 Rating은 Description을 통해 String으로 전환 해주었다.

그리고 count의 경우는 formatted를 사용하여 String으로 형변환을 함과 동시에 default 숫자 설정을 따르게 했다. 

그리고 extension을 사용했는데

```swift
extension String {
    var withBrackets: String {
        String(format: "(%@)", self)
    }
}
```

숫자 뒤에 괄호로 감싸주기 위함이다.

이렇게 리뷰쪽에 관한 부분도 만들었다.

![CleanShot 2024-10-11 at 17 02 10](https://github.com/user-attachments/assets/83b775fb-97c1-4944-a03a-b5b7d585e2cb){: width="50%" height="50%"} 


## CourseView 마무리

```swift
VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: URL(string: imageLink)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .border(Color.gray.opacity(0.3))
                    .clipped()
            } placeholder: {
                PlaceholderImageView()
                    .frame(height: 64)
            }.padding(.bottom, 4)
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .fixedSize(horizontal: false, vertical: true)
            Text(author)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(.gray)
            ReviewRatingView(rating: rating, reviewCount: reviewCount)
            Text(price.priceFormat)
                .font(.system(size: 10, weight: .bold))
            Text(tag)
                .font(.system(size: 10, weight: .semibold))
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .background(content: {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow.opacity(0.4))
                })
            Spacer()
```

이때 Price가 Decimal인데, Decimal에 대한 extension을 또 하나 만들어 준다.

```swift
extension Decimal {
    var priceFormat: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: self as NSDecimalNumber) ?? String(describing: self)
    }
}
```
이건 금액앞에 통화 단위를 붙여주게 된다. 현재는 locale을 `en_US`로 했기에 달러로 나올것이다.

이렇게 CourseView가 완성이 되었다.

![CleanShot 2024-10-11 at 17 11 45](https://github.com/user-attachments/assets/b7fb86a4-dcf6-4417-86f9-963ed7256b6f){: width="50%" height="50%"} 

## CourseCollectionViewCell 추가하기

```swift
final class CourseCollectionViewCell: UICollectionViewCell {
    private var hostingController: UIHostingController<CourseView>!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .gray
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(
        imageLink: String,
        title: String,
        author: String,
        rating: Double,
        reviewCount: Int,
        price: Decimal,
        tag: String
    ) {
        guard hostingController == nil else { return }
        let courseView = CourseView(
            imageLink: imageLink,
            title: title,
            author: author,
            rating: rating,
            reviewCount: reviewCount,
            price: price,
            tag: tag
        )
        hostingController = UIHostingController(rootView: courseView)
        addSubview(hostingController.view)
        hostingController.view.clipsToBounds = true
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
}
```

## CourseSwimLane 추가하기

우선 HomeCollectionView에 셀을 등록해준다.

```swift
private func setup() {
        register(MainBannerCollectionViewCell.self, forCellWithReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier)
        register(TextHeaderCollectionViewCell.self, forCellWithReuseIdentifier: TextHeaderCollectionViewCell.namedIdentifier)
        register(CourseCollectionViewCell.self, forCellWithReuseIdentifier: CourseCollectionViewCell.namedIdentifier)
    }
```

그리고 셀에 대한 데이터 소스를 추가

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
            default :
                fatalError()
            }
        })
    }
```

이후 컴포지셔널 레이아웃을 관리하는 함수에도 추가를 해준다

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
            default :
                fatalError()
            }
        }
        return UICollectionViewCompositionalLayout(sectionProvider: provider)
    }   
```

## makeCourseSwimlaneSection 함수 만들기

```swift
private func makeCourseSwimlaneSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(160),
            heightDimension: .fractionalHeight(200))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
        section.orthogonalScrollingBehavior = .continuous
        
        return section
    }
```

## HomeVC에 내용 추가

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
            .init(section: .courseSwimlane(id: "321"), body: [
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
                        title: "iOs & Swift: Server Driven UI Compositional Layout & SwiftUI",
                        author: "Kelvin Fok",
                        rating: 4.5,
                        reviewCount: 224,
                        price: 19.99,
                        tag: "BestSeller"),
                .course(
                    id: "313125",
                    imageLink: "https://picsum.photos/300/200",
                        title: "iOs & Swift: Server Driven UI Compositional Layout & SwiftUI",
                        author: "Kelvin Fok",
                        rating: 4.5,
                        reviewCount: 224,
                        price: 19.99,
                        tag: "BestSeller")
        ])
            ])
        collectionView.setupDataSource(uiModel: uiModel)
    }
```

하지만 문제가 발생했다.

![simulator_screenshot_90152B8A-AD9E-4DB5-BAFF-28DB32DA8BF6](https://github.com/user-attachments/assets/4f74ea95-20f6-45cc-bee3-48899d768b0f){: width="50%" height="50%"} 

이미지쪽에서 문제가 발생했다.

주소가 틀리지 않았음에도 로드가 안되는 문제가 발생

CourseView의 Preview에서는 제대로 나오기에 다른부분이 문제가 생긴듯하다.

문제를 찾았다

```swift
private func makeCourseSwimlaneSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(160), // cause 
            heightDimension: .fractionalHeight(200)) // cause
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
        section.orthogonalScrollingBehavior = .continuous
        
        return section
    }
```

바로 저기가 문제였던것....

[이전글](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(2)/){:target="_blank"} 

에 너무 간단하게 적은것 같아 여기에 조금더 설명을 덧붙인다.

---

## Fractional Width & Height

fractionalWidth와 fractionalHeight는 UICollectionViewCompositionalLayout에서 레이아웃 아이템의 크기를 설정할 때 사용하는 NSCollectionLayoutDimension 클래스의 메서드이다.

이들은 각각 부모 뷰의 크기에 대한 비율로 아이템의 너비와 높이를 설정하는 방식이다.

### fractionalWidth
fractionalWidth는 부모 요소(상위 그룹이나 섹션)의 너비에 대한 비율로 아이템의 너비를 결정한다.

### fractionalHeight
fractionalHeight는 부모 요소의 높이에 대한 비율로 아이템의 높이를 설정한다.

```swift
let itemSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1.0), // 부모의 100% 너비
    heightDimension: .fractionalHeight(0.3) // 부모의 30% 높이
)
```

**부모 요소가 무엇인지?**

fractionalWidth와 fractionalHeight에서 말하는 부모 요소는 레이아웃에 따라 다르다.
- 아이템의 부모 요소는 그룹이다.
- 그룹의 부모 요소는 섹션이다.
- 섹션의 부모 요소는 컬렉션 뷰 전체이다.

따라서, fractionalWidth(0.5)를 설정하면 해당 아이템이 속한 그룹의 너비에 대해 50% 크기를 가진다는 의미이다.

장점

이 방식의 장점은 부모의 크기에 상대적인 비율로 아이템 크기를 정의할 수 있어, 다양한 화면 크기에서도 유연하게 레이아웃을 맞출 수 있다는 점이다. 아이폰, 아이패드처럼 화면 크기가 다른 기기에서도 레이아웃이 자동으로 조정된다.

```swift
let itemSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(0.5), // 그룹의 50% 너비
    heightDimension: .fractionalHeight(1.0) // 그룹의 100% 높이
)
let item = NSCollectionLayoutItem(layoutSize: itemSize)

let groupSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1.0), // 섹션의 100% 너비
    heightDimension: .absolute(200) // 절대 높이 200
)
let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
```

---

다시 돌아와서 실행을 하면

![Simulator Screenshot - iPhone 16 Pro - 2024-10-12 at 04 35 31](https://github.com/user-attachments/assets/32883010-de3c-4408-bc88-4db361c5c7c0){: width="50%" height="50%"} 

잘 된다.

Xcode가 새롭게 업데이트되면서 자동완성을 나도모르게 남발해서 생긴 문제였다.