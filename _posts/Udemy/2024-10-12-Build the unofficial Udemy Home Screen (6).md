---
title: Build the unofficial Udemy Home Screen (6)
writer: Harold
date: 2024-10-12 06:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## 다른 Course Swimlane을 추가

코드는 생략

이미지로 대체한다.

![simulator_screenshot_DD1B28D3-090B-4A58-9ABD-DD6E95CB8DA4](https://github.com/user-attachments/assets/8cc82991-9868-43cc-9fd8-62966da400a9){: width="50%" height="50%"} 

HomeVC에서 내용을 추가, 수정했다.

## FeaturedCourseView 추가

CourseView의 내용을 가져오되, tag만 지워준다.

그리고 높이만 바꿔주었다.

```swift
struct FeaturedCourseView: View {
    let imageLink: String
    let title: String
    let author: String
    let rating: Double
    let reviewCount: Int
    let price: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: URL(string: imageLink)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .border(Color.gray.opacity(0.3))
                    .clipped()
            } placeholder: {
                PlaceholderImageView()
                    .frame(height: 140)
            }.padding(.bottom, 4)
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            Text(author)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(.gray)
            ReviewRatingView(rating: rating, reviewCount: reviewCount)
            Text(price.priceFormat)
                .font(.system(size: 10, weight: .bold))
            Spacer()
        }
    }
}
```

## FeaturedCollectionViewCell 설정

[이전글](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(5)/){:target="_blank"} 과 유사하므로 생략...

한가지 새롭게 추가된거라면

```swift
private func makeFeaturedCourseSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(230))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item])
        
        group.interItemSpacing = NSCollectionLayoutSpacing.fixed(10)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
        
        return section
    }
```

`group.interItemSpacing = NSCollectionLayoutSpacing.fixed(10)`은 NSCollectionLayoutGroup 내의 아이템들 간의 간격을 고정된 간격으로 설정하는 코드이다.

- group은 여러 아이템을 포함하는 그룹이며, 이 그룹 내에서 아이템들이 가로 또는 세로로 배치될 수 있다.
- interItemSpacing은 이 그룹 안에서 각 아이템 간의 간격을 설정하는 속성이다. 여기서는 그룹 안에서의 아이템 간 간격을 지정하고 있다.
- NSCollectionLayoutSpacing.fixed(10)는 고정된 10 포인트(pixels)의 간격을 의미한다. 즉, 그룹 내에서 각 아이템 사이에 10 포인트의 간격이 들어가게 된다.

![simulator_screenshot_41E71D73-90AA-4A4A-B481-EC907D1AF252](https://github.com/user-attachments/assets/da3ac389-bc34-4a6d-82e2-e0612811ed9f){: width="50%" height="50%"} 

완성사진.

## UdemyBusinessView 추가

```swift
struct UdemyBusinessView: View {
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Top companies trust Udemy")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .padding(.top, 16)
            HStack(spacing: 40) {
                UdemyBusinessIconView(systemName: "apple.logo")
                UdemyBusinessIconView(systemName: "shazam.logo.fill")
                UdemyBusinessIconView(systemName: "playstation.logo")
            }
            
            Button {
                self.onTap?()
            } label: {
                Text("Try Udemy Business")
                    .font(.system(size: 12, weight: .bold))
            }
            .tint(.indigo)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .border(Color(uiColor: .systemGray), width: 1)
    }
}

struct UdemyBusinessIconView: View {
    let systemName: String
    
    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 48, height: 48)
            .foregroundStyle(Color(uiColor: .gray))
    }
    
}
```

뭐 크게 언급할 만한 내용은 없어보인다.

![CleanShot 2024-10-12 at 08 08 11](https://github.com/user-attachments/assets/d13b4a91-f95f-44a7-916c-c5d8904c565c){: width="50%" height="50%"} 

## UdemyBusinessCollectionViewCell 설정 및 추가

여기서 하나 언급할만한건

```swift
final class UdemyBusinessCollectionViewCell: UICollectionViewCell {
    private var hostingController: UIHostingController<UdemyBusinessView>!
    
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func layout() {
        hostingController = UIHostingController(rootView: UdemyBusinessView())
        addSubview(hostingController.view)
        hostingController.view.clipsToBounds = true
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        hostingController.rootView.onTap = { [weak self] in
            self?.onTap?()
        }
    }
}

case let .udemyBusinessBanner(_, link):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UdemyBusinessCollectionViewCell.namedIdentifier, for: indexPath) as! UdemyBusinessCollectionViewCell
                cell.onTap = {
                    print(">>>>> tapped on udemy Business \(link)")
                }
                return cell
```

이 코드인데. 셀을 탭했을때의 이벤트를 핸들링 하기위해 클로저를 사용했다.

```swift
var onTap: (() -> Void)?
```
- onTap은 클로저 타입으로 선언된 프로퍼티다. `(() -> Void)?`는 매개변수가 없고 반환값도 없는 클로저를 의미하며, 이 클로저는 선택적으로 설정될 수 있기 때문에 Optional(?)로 선언되었다.
- 이 프로퍼티는 외부에서 해당 셀을 탭했을 때 수행할 동작을 정의하기 위해 사용된다.

```swift
cell.onTap = {
    print(">>>>> tapped on udemy Business \(link)")
}
```
- collectionView에서 셀을 구성할 때, onTap 클로저에 특정 동작을 할당한다. 여기서는 탭을 하면 콘솔에 print문이 실행되도록 설정되었다.
- 이 코드는 셀을 탭했을 때 실행될 행동을 정의하며, 여기서는 해당 링크 정보(link)를 출력하는 기능을 담당한다.

```swift
hostingController.rootView.onTap = { [weak self] in
    self?.onTap?()
}
```
- UdemyBusinessView에서 정의된 onTap이라는 클로저가 실제로 트리거되는 부분이다. 이 클로저가 호출되면, UdemyBusinessCollectionViewCell의 onTap 프로퍼티에 할당된 클로저가 실행된다.
- [weak self]는 메모리 누수를 방지하기 위해 사용된 약한 참조다. 이를 통해 클로저가 self를 강하게 참조하는 것을 방지하며, self가 해제되어도 강한 참조 순환이 일어나지 않도록 한다.

**순서**
1. UICollectionView에서 셀을 설정할 때, UdemyBusinessCollectionViewCell의 onTap 클로저에 원하는 동작을 정의
2. UdemyBusinessCollectionViewCell 내부에서 UdemyBusinessView를 SwiftUI로 렌더링하고, rootView의 onTap 클로저에 셀의 onTap을 연결
3. UdemyBusinessView에서 사용자가 셀을 탭하면, SwiftUI 뷰의 onTap이 호출된다. 이 때, UdemyBusinessCollectionViewCell의 onTap 클로저가 트리거된다.
4. 사용자가 탭했을 때, UdemyBusinessCollectionViewCell에서 설정된 onTap 클로저가 실행되고, 외부에서 설정된 동작(여기서는 print)이 수행된다.

![simulator_screenshot_6FBF352D-7AA2-4A49-AA0E-7307637DDFFE](https://github.com/user-attachments/assets/6a988c13-56de-4b1e-8318-7ca83beba1c2){: width="50%" height="50%"} 

완성된 화면은 위와 같다.

## TapGestures 추가하기

계속 추가를 하는것이기에 매커니즘은 같아서 하나만 예를 든다

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
            .padding(.horizontal, 20)
        }
    }
}
```

이렇게 버튼을 눌렀을때 print를 하던것을 onTap 프로퍼티를 만들어 대체한다.

```swift
var onTap: ((String) -> Void)?

HStack {
                    ForEach(titles[..<midPoint], id: \.self) { title in
                        CatgoryButton(title: title) {
                            onTap?(title)
                        }
                        
                    }
                }
```

여기는 Category의 title을 받기에 String을 파라미터로 밭지만, 이걸 제외하고 나머지는

`var onTap: (() -> Void)?` 이렇게 되어있다.

```swift
final class CategoriesCollectionViewCell: UICollectionViewCell {
    
    private var hostingController: UIHostingController<CategoriesView>!
    
    var onTap: ((String) -> Void)?
    
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
        hostingController.rootView.onTap = { [weak self] title in
            self?.onTap?(title)
        }
    }
}
```

rootView가 categoriesView이기에 ontap에 대하여 실제로 트리거가 되게 설정을 한다.

```swift
private func setupDataSource() {
        diffableDataSource = UICollectionViewDiffableDataSource(collectionView: self, cellProvider: { collectionView, indexPath, item in
            switch item {
            case let .mainBanner(_, imageLink, title, caption):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier, for: indexPath) as! MainBannerCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, caption: caption)
                return cell
            case let .textHeader(id, title, highlightedText):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextHeaderCollectionViewCell.namedIdentifier, for: indexPath) as! TextHeaderCollectionViewCell
                cell.configure(text: title, highlightedText: highlightedText)
                cell.onTap = {
                    print(">>> TextHeader link tapped: \(id) - \(highlightedText)")
                }
                return cell
            case let .course(id, imageLink, title, author, rating, reviewCount, price, tag):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CourseCollectionViewCell.namedIdentifier, for: indexPath) as! CourseCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, author: author, rating: rating, reviewCount: reviewCount, price: price, tag: tag)
                cell.onTap = {
                    print(">>> course tapped: \(id) - \(title)")
                }
                return cell
            case let .categoriesScroller(_, titles):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoriesCollectionViewCell.namedIdentifier, for: indexPath) as! CategoriesCollectionViewCell
                cell.configure(titles: titles)
                cell.onTap = { title in
                    print(">>> category tapped is \(title)")
                }
                return cell
            case let .featuredCourse(_, imageLink, title, author, rating, reviewCount, price):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedCourseCollectionViewCell.namedIdentifier, for: indexPath) as! FeaturedCourseCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, author: author, rating: rating, reviewCount: reviewCount, price: price)
                return cell
            case let .udemyBusinessBanner(_, link):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UdemyBusinessCollectionViewCell.namedIdentifier, for: indexPath) as! UdemyBusinessCollectionViewCell
                cell.onTap = {
                    print(">>>>> tapped on udemy Business \(link)")
                }
                return cell
            default :
                fatalError()
            }
        })
    }
```

그리고 트리거가 되었을때에 대한 액션을 정의한다.

지금은 print로 한다.

```swift
struct FeaturedCourseView: View {
    let imageLink: String
    let title: String
    let author: String
    let rating: Double
    let reviewCount: Int
    let price: Decimal
    
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: URL(string: imageLink)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .border(Color.gray.opacity(0.3))
                    .clipped()
            } placeholder: {
                PlaceholderImageView()
                    .frame(height: 140)
            }.padding(.bottom, 4)
            
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .default))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            Text(author)
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundStyle(.gray)
            ReviewRatingView(rating: rating, reviewCount: reviewCount)
            Text(price.priceFormat)
                .font(.system(size: 10, weight: .bold))
            Spacer()
        }
        .onTapGesture {
            onTap?()
        }
    }
}
```

뷰 자체를 탭하는 경우.

`onTapGesture` Modifier를 사용해준다.

```swift
var onTap: (() -> Void)?

.onTapGesture {
            onTap?()
        }
```

![Oct-12-2024 18-41-02](https://github.com/user-attachments/assets/f77715a7-1d61-4ac1-9bfe-b73e74035ad7)

실행하면 이렇게 print 됨을 알 수 있다.

