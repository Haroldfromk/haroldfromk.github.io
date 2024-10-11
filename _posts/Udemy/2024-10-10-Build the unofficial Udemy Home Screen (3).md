---
title: Build the unofficial Udemy Home Screen (3)
writer: Harold
date: 2024-10-10 12:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

이전에 Background Color를 Green으로 했던걸 지워준다.

```swift
private func setup() {
        register(MainBannerCollectionViewCell.self, forCellWithReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier)
    }
```

## TextHeaderCollectionViewCell 세팅

```swift
final class TextHeaderCollectionViewCell: UICollectionViewCell {
    
    private let label = AttributedTappableLabel()
    
    override init (frame: CGRect) {
        super.init(frame: frame)
        layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String, highlightedText: String?) {
        label.setAttributedText(text: text,
                                highlightedText: highlightedText,
                                color: .systemIndigo,
                                font: .systemFont(ofSize: 18, weight: .bold)
        )
    }
    
    private func layout() {
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        label.onTap = {
            print(">>>>> tapped")
        }
    }
    
}
```

뭐 딱히 서술할게 없어 보인다.

## HomeCollectionView에 통합하기

```swift
private func setup() {
        register(MainBannerCollectionViewCell.self, forCellWithReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier)
        register(TextHeaderCollectionViewCell.self, forCellWithReuseIdentifier: TextHeaderCollectionViewCell.namedIdentifier) // new
    }
```

우선 위에 만들어둔 셀을 등록을 해준다.

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
                default :
                fatalError()
            }
        })
    }
```

TextHeader인 경우를 추가하여 셀을 새로 구성해주자.

그리고 HeaderSection을 만들어주는 함수도 만든다.

```swift
private func makeTextHeaderSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(120))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20)

        return section
    }
```

관련 내용은 [이전글](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(2)/){:target="_blank"} 에 서술했으니 참고할 것.

새롭게 추가된 부분이라면 Insets을 주었다.
> Padding이라고 생각하면 될듯.

## HomeVC 세팅

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
                    highlightedText: "Mobile Development") // added
            ])
        ])
        collectionView.setupUIModel(uiModel: uiModel)
    }
```

![simulator_screenshot_4B9C6779-047E-46B7-A7D4-4E492092CF65](https://github.com/user-attachments/assets/0441a316-f534-4333-8661-30535d5d4fcd){: width="50%" height="50%"} 

이렇게 추가가 된걸 알 수 있다.

## Tap 부분 문제해결

원래는 `layout` 함수에서 레입르을 탭했을때 콘솔에 출력이 되어야하는데 되지 않았다.

그부분을 해결하려고 한다.

먼저 정확하게 label의 영역이 어디인지를 식별 하기 위해 배경화면을 임의로 정해줄 것이다.

```swift
func configure(text: String, highlightedText: String?) {
        label.setAttributedText(text: text,
                                highlightedText: highlightedText,
                                color: .systemIndigo,
                                font: .systemFont(ofSize: 18, weight: .bold))
        label.backgroundColor = .yellow // added
    }
```

![simulator_screenshot_EA60613C-8A46-4513-9445-0FFD72D59623](https://github.com/user-attachments/assets/59bd9f04-74d8-458d-bbff-65b91328b5a5){: width="50%" height="50%"} 

확인 완료.

![Oct-10-2024 20-42-49](https://github.com/user-attachments/assets/25286ca8-08fd-4496-aed6-2a3f67a913ea){: width="50%" height="50%"}

실제로 영역 안에서 클릭을 해보면 되는부분이 있고 안되는 부분이 있다.

`AttributedTappableLabel` 로 가서 문제를 확인하면 된다.

```swift
func setAttributedText(text: String, highlightedText: String?, color: UIColor = .black, font: UIFont = .systemFont(ofSize: 18, weight: .bold)) {
    let attributedString = NSMutableAttributedString(string: text)
    
    // Check if highlighted string is provided
    if let highlighted = highlightedText {
      // Find the range of the highlighted part
      let range = (text as NSString).range(of: highlighted)
      
      // Apply the color to the range
      attributedString.addAttribute(.foregroundColor, value: color, range: range)
    }
    
    attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
    
    self.attributedText = attributedString
    self.tapRange = (text as NSString?)?.range(of: highlightedText ?? "") // modified
    self.labelFont = font
  }
```

tapRange에서 highlightedText를 text로 바꿔준다.

1.	highlightedText의 범위 찾기:
- (text as NSString).range(of: highlightedText ?? "") 코드를 통해 text 내에서 highlightedText가 위치한 범위를 찾는다. 이 범위는 NSRange 타입으로 저장된다.
- 이 범위는 tapRange에 할당되어 나중에 어떤 특정한 텍스트 부분이 터치되었는지 확인할 수 있게 한다.

## TextHeader의 높이를 동적으로 조절하게 세팅

```swift
private func makeTextHeaderSection(
        text: String,
        highlightedText: String?
    ) -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let label = AttributedTappableLabel()
        label.setAttributedText(text: text, highlightedText: highlightedText)
        let height = label.heightForWidth(frame.size.width)
        
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20)
        
        return section
    }
```

label을 추가해 주었고, setAttributedText에는 text, highlightedText를 파라미터로 받기에

함수에서 그걸 파라미터로 받아서 label에 전달하도록 바꿔주었다.

그리고 height를 설정해주는데

함수는 다음과 같다

```swift
func heightForWidth(_ width: CGFloat) -> CGFloat {
    guard let font = labelFont, let text = text else { return 0 }
    
    let size = CGSize(width: width, height: .greatestFiniteMagnitude)
    let boundingRect = NSString(string: text).boundingRect(
      with: size,
      options: .usesLineFragmentOrigin,
      attributes: [NSAttributedString.Key.font: font],
      context: nil
    )
    let safePadding: CGFloat = 4
    return boundingRect.height + safePadding
  }
```

1.	labelFont와 text 확인:
- labelFont와 text가 모두 존재하는지 확인한다. 둘 중 하나라도 없으면 0을 반환한다.
2.	CGSize 설정:
- 계산할 크기를 나타내는 CGSize를 설정한다. 여기서 너비는 함수로 전달된 값이고, 높이는 .greatestFiniteMagnitude를 사용)하여 매우 큰 값으로 설정된다. 이는 텍스트가 높이 제한 없이 얼마만큼의 공간을 차지하는지 계산하기 위함이다.
3.	boundingRect를 사용한 높이 계산:
- NSString의 boundingRect(with:options:attributes:context: 메서드를 사용하여 텍스트가 주어진 너비에서 차지하는 실제 크기를 계산한다. 이 메서드는 텍스트가 주어진 CGSize 내에서 어느 정도의 공간을 차지하는지 CGRect로 반환한다.
- attributes에는 폰트 정보가 포함되어 있으며, 이를 바탕으로 텍스트의 높이를 정확히 계산한다.
4.	safePadding 추가:
- safePadding은 기본적으로 4포인트의 여유 공간을 추가하여, 텍스트가 너무 꽉 차 보이지 않도록 한다.
5.	최종 높이 반환:
- 계산된 boundingRect.height에 safePadding을 더한 값을 반환하여, 레이블이 주어진 너비에 맞는 높이를 계산한다.

그리고 CompositionalLayout 함수도 바꿔준다.

```swift
private func makeCompositionalLayout() -> UICollectionViewCompositionalLayout {
        
        let provider: UICollectionViewCompositionalLayoutSectionProvider = { [weak self] index, env in
            
            guard let sectionModel = self?.uiModel?.sectionModels[index] else { return nil }
            
            switch sectionModel.section {
            case .mainBanner:
                return self?.makeBannerSection()
            case .textheader:
                guard case let .textHeader(_, text, highlightedText) = sectionModel.body.first else { return nil }
                return self?.makeTextHeaderSection(text: text, highlightedText: highlightedText)
            default :
                fatalError()
            }
        }
        return UICollectionViewCompositionalLayout(sectionProvider: provider)
    }
```

![simulator_screenshot_71891A42-3AF7-46AA-8169-722D1CBCF5A6](https://github.com/user-attachments/assets/d3b583b9-7610-44ee-87ee-611736b906bc){: width="50%" height="50%"} 

레이블의 범위가 줄어들었음을 알 수 있다.

그리고 case 뒤에 .이 붙는 이유는 case 뒤에 .mainBanner, .textHeader와 같은 구문에서 enum 타입이 생략된 것이다. 
Swift는 패턴 매칭 시, enum의 타입이 명시적으로 확인 가능한 경우 case .value로 작성할 수 있다. 여기서 생략된 것은 enum 타입의 이름이다.

1.	enum 타입:
- HomeUIModel.Item 또는 HomeUIModel.Section과 같은 enum 타입에서 정의된 케이스들(예: .mainBanner, .textHeader)이다. Swift에서는 타입이 명확하게 추론될 수 있는 경우 enum 타입을 생략할 수 있다.
2.	생략된 부분:
- 생략된 부분은 HomeUIModel.Item이다.
- 예를 들어, HomeUIModel.Item.mainBanner와 같이 타입 이름을 포함할 수 있지만, Swift의 문맥에서 타입이 명확하기 때문에 case .mainBanner로 작성 가능하다.
3.	Swift의 타입 추론:
- diffableDataSource는 UICollectionViewDiffableDataSource<HomeUIModel.Section, HomeUIModel.Item>로 정의되어 있으므로, Swift는 item이 HomeUIModel.Item 타입이라는 것을 알고 있다. 따라서 case 구문에서 enum 타입을 생략하고 .mainBanner, .textHeader와 같이 간결하게 작성할 수 있다.

## 리팩토링

`heightForWidth` 함수를 좀 더 다른데서도 사용하기 위해 static을 붙여준다.

```swift
static func heightForWidth(
    _ width: CGFloat,
    font: UIFont = .systemFont(ofSize: 18, weight: .bold),
    text: String) -> CGFloat {
    
    let size = CGSize(width: width, height: .greatestFiniteMagnitude)
    let boundingRect = NSString(string: text).boundingRect(
      with: size,
      options: .usesLineFragmentOrigin,
      attributes: [NSAttributedString.Key.font: font],
      context: nil
    )
    let safePadding: CGFloat = 4
    return boundingRect.height + safePadding
  }
```

그리고 makeTextHeaderSection함수도 바꿔준다.

```swift
private func makeTextHeaderSection(
        text: String
    ) -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let layoutSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(AttributedTappableLabel.heightForWidth(frame.size.width, text: text)))
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: layoutSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20)
        
        return section
    }
```

height와 label 변수가 사라졌다.

그리고 파라미터로 받던 highlightedText도 지워주었다.

대신 높이를 조절하는 heightDimension에 absolute안에 있던 파라미터값이 120이었던가 그랬는데 그것을 높이를 동적으로 조절하기위해 바꿔준다.

label객체를 만든것도 그런의미 였는데 이젠 static으로 선언했기에 그냥 사용이 가능.

작동사진은 어차피 그대로기에 패스!