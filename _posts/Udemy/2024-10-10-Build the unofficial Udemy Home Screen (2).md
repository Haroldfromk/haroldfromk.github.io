---
title: Build the unofficial Udemy Home Screen (2)
writer: Harold
date: 2024-10-10 12:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## MainBannerCollectionViewCell 추가하기

이 파일은 View에 있지만, SwiftUI를 import 해주었다.

> `import SwiftUI`를 하게되면 UIkit 을 별도로 import를 해야하나?
>> ![CleanShot 2024-10-10 at 15 17 54](https://github.com/user-attachments/assets/7acd140a-bd2a-45a2-af05-8cc0ce1aaa35){: width="50%" height="50%"} 
>>> 이렇게 Definition을 보게되면 SwiftUI안에 UIKit을 이미 import한게 내장이 되어있다는걸 알 수 있다. 즉 import를 할 필요가 없다.

[Swift Style Guide](https://google.github.io/swift/){:target="_blank"}에 코드 컨벤션 관련한 내용이 있으니 한번 확인해보자.

```swift
import SwiftUI

final class MainBannerCollectionViewCell: UICollectionViewCell {
    
    private var hostingController: UIHostingController<MainBannerView>!
    
    func configure(
        imageLink: String,
        title: String,
        caption: String)
    {
        guard hostingController == nil else { return }
        let mainBannerView = MainBannerView(imageLink: imageLink, title: title, caption: caption)
        hostingController = UIHostingController(rootView: mainBannerView)
        guard let hostingController = hostingController else { return }
        addSubview(hostingController.view)
        hostingController.view.clipsToBounds = true
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
```

여기서 새로운건 바로 Hosting Controller라는 녀석이다.

[참고글](https://ios-development.tistory.com/1157){:target="_blank"}도 읽어보면 좋을듯.

![CleanShot 2024-10-10 at 15 39 31](https://github.com/user-attachments/assets/37defc65-cb00-464a-b9ed-af19806e1e3c)

간단하게 정의를 하면 UIKit에서 SwiftUI View를 사요하고 싶을때 쓴다고 보면 될듯.

이부분은 생소할수 있으니 조금 더 살펴보기로 하면,

- configure 함수에서의 `guard hostingController == nil else { return }`
	- hostingController가 이미 초기화되었으면(즉, 해당 셀이 재사용될 때) 다시 초기화하지 않도록 guard 문을 통해 보호한다.

- `hostingController = UIHostingController(rootView: mainBannerView)`
    - MainBannerView(imageLink:title:caption:)를 통해 새로운 SwiftUI 뷰를 생성하고, 이를 UIHostingController의 rootView로 설정한다.

- `addSubview(hostingController.view)`
    - UIHostingController의 뷰를 UICollectionViewCell의 서브뷰로 추가한다. 이때, SwiftUI 뷰가 UIView 계층 구조에 들어간다.

## MainBannerCollectionViewCell을 CollectionView에 추가하기

### DiffableDataSource 세팅
여기선 DiffableDataSource를 사용했다.

```swift

private var diffableDataSource: UICollectionViewDiffableDataSource<HomeUIModel.Section, HomeUIModel.Item>!

func setupUIModel(uiModel: HomeUIModel) {
        self.uiModel = uiModel
        self.applySnapshot()
    }
```

먼저 diffableDataSource 객체를 생성해준다.
이때 디퍼블에 들어가는 속성은 반드시 Hashable Protocol을 따라야 한다.

그 다음 안에 들어가는건 섹션과, 아이템이다.
`UICollectionViewDiffableDataSource<HomeUIModel.Section, HomeUIModel.Item>`

---

이렇게 객체 생성을 하고난 뒤에는 Datasource를 관리하는 함수를 만든다.
CellforRowAt과 유사하다고 생각하면 될듯.

```swift
private func setupDataSource() {
        diffableDataSource = UICollectionViewDiffableDataSource(collectionView: self, cellProvider: { collectionView, indexPath, item in
            switch item {
            case let .mainBanner(_, imageLink, title, caption):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MainBannerCollectionViewCell.namedIdentifier, for: indexPath) as! MainBannerCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, caption: caption)
                return cell
                default :
                fatalError()
            }
        })
    }
```

1.	UICollectionViewDiffableDataSource 생성:
- diffableDataSource는 컬렉션 뷰에 데이터를 제공하는 데이터 소스다.
- 셀을 생성하는 역할을 담당하는 클로저(cellProvider)가 전달된다.
2.	cellProvider 클로저:
- collectionView, indexPath, item을 매개변수로 받아, 적절한 셀을 반환하는 역할을 한다.
- switch문에서 item의 타입을 검사하고, MainBannerCollectionViewCell이 필요할 때 이를 생성하고 구성한다.
3.	MainBannerCollectionViewCell 설정:
- dequeueReusableCell 메서드를 사용해 셀을 재사용 큐에서 가져온 후, configure(imageLink:title:caption:) 메서드를 호출해 셀의 내용을 구성한다.

---

그다음은 스냅샷을 적용.

```swift
private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HomeUIModel.Section, HomeUIModel.Item>()
        uiModel?.sectionModels.forEach({ sectionModel in
            snapshot.appendSections([sectionModel.section])
            snapshot.appendItems(sectionModel.body, toSection: sectionModel.section)
        })
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }
```

1.	스냅샷 생성:
- NSDiffableDataSourceSnapshot<HomeUIModel.Section, HomeUIModel.Item>()로 새로운 스냅샷을 생성한다. 스냅샷은 컬렉션 뷰의 섹션과 아이템을 나타내는 데이터 구조이다.
2.	섹션 및 아이템 추가:
- sectionModels 배열을 반복하며, 각 섹션을 스냅샷에 추가한다.
- snapshot.appendSections([sectionModel.section])로 각 섹션을 추가하고, snapshot.appendItems(sectionModel.body, toSection: sectionModel.section)로 해당 섹션에 속하는 아이템들을 추가한다.
3.	스냅샷 적용:
- diffableDataSource.apply(snapshot, animatingDifferences: false)를 통해 스냅샷을 데이터 소스에 적용한다. animatingDifferences: false는 애니메이션 없이 스냅샷이 적용되도록 설정한 것이다.


### Compositional Layout 세팅

```swift
private func makeCompositionalLayout() -> UICollectionViewCompositionalLayout {
        
        let provider: UICollectionViewCompositionalLayoutSectionProvider = { [weak self] index, env in
            
            guard let sectionModel = self?.uiModel?.sectionModels[index] else { return nil }
            
            switch sectionModel.section {
            case .mainBanner:
                return self?.makeBannerSection()
                
            default :
                fatalError()
            }
        }
        return UICollectionViewCompositionalLayout(sectionProvider: provider)
    }
```

>UICollectionViewCompositionalLayoutSectionProvider를 사용해 각각의 섹션에 맞는 레이아웃을 동적으로 반환하게 한다.

1.	UICollectionViewCompositionalLayout 생성:
- makeCompositionalLayout() 함수는 UICollectionViewCompositionalLayout을 반환한다. 이는 컬렉션 뷰의 레이아웃을 정의하는 역할을 한다.
- UICollectionViewCompositionalLayoutSectionProvider는 컬렉션 뷰의 각 섹션에 맞는 레이아웃을 제공하는 클로저 형태의 제공자다.
2.	SectionProvider 클로저:
- sectionProvider 클로저는 index와 env (환경 설정)를 매개변수로 받는다.
- uiModel의 sectionModels 배열에서 해당 섹션을 가져와, 그 섹션에 맞는 레이아웃을 반환한다.
- 섹션이 mainBanner일 경우, makeBannerSection() 함수를 호출해 배너 레이아웃을 반환한다.
- 이외의 섹션이 들어오면 fatalError()를 호출해 프로그램이 중단되도록 한다. 이는 예상치 못한 섹션이 포함될 때 디버깅을 쉽게 하기 위함이다.
3.	Weak Self 사용:
- [weak self]는 클로저에서 순환 참조를 방지하기 위해 사용되며, self가 해제될 수 있도록 약한 참조를 사용한다. 이로써 메모리 누수를 방지한다.

```swift
private func makeBannerSection() -> NSCollectionLayoutSection {
        
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
        
        return NSCollectionLayoutSection(group: group)
    }
```

>컬렉션 뷰의 섹션을 가로로 스크롤되는 배너 형식으로 레이아웃을 설정한다.

1.	아이템 크기 정의 (itemSize):
- NSCollectionLayoutSize를 사용하여 아이템의 크기를 설정한다.
- widthDimension: .fractionalWidth(1.0)는 아이템이 그룹 너비의 100%를 차지하게 하고, heightDimension: .fractionalHeight(1.0)는 그룹 높이의 100%를 차지하게 한다.
- 이 크기를 바탕으로 NSCollectionLayoutItem을 생성한다.
2.	그룹 크기 정의 (layoutSize):
- NSCollectionLayoutSize로 그룹의 크기를 설정한다.
- widthDimension: .fractionalWidth(1.0)는 그룹이 섹션 너비의 100%를 차지하게 하고, heightDimension: .absolute(220)는 그룹의 높이를 고정된 220 포인트로 설정한다.
- NSCollectionLayoutGroup.horizontal을 사용하여 가로 방향으로 아이템을 배치하는 그룹을 생성한다. 여기서는 하나의 아이템이 그룹에 포함된다.
3.	섹션 생성 (NSCollectionLayoutSection):
- NSCollectionLayoutSection에 그룹을 추가하여 섹션을 생성하고, 이 섹션을 반환한다.

## HomeVC에 CollectionView 추가하기

```swift
override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        let uiModel = HomeUIModel(sectionModels: [
            .init(section: .mainBanner(id: "123"),
                  body: [.mainBanner(id: "123", imageLink: "https://images.unsplash.com/photo-1627634777217-c864268db30c?q=80&w=1740&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D", title: "Some Title", caption: "some caption")])
        ])
        collectionView.setupUIModel(uiModel: uiModel)
    }
```

완성하고 나니 강의와 달랐다.

caption에 대한 내용이 없다.

![simulator_screenshot_0A1B9930-0CD0-4D9C-8659-C797004B4D52](https://github.com/user-attachments/assets/f060db93-12ac-410c-96d9-41b233f17a8b){: width="50%" height="50%"} 

역산을 하며 올라가던중 MainBannerView에 caption이 없음을 인지했다.

```swift
struct MainBannerView: View {
    let imageLink: String
    let title: String
    let caption: String
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(string: imageLink)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
            } placeholder: {
                PlaceholderImageView()
                    .frame(height: 160)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold)) // modified
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Text(caption) // 빠져있었다.
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .padding(.leading, 20)
        }
    }
}
```

MainBannerView의 Vstack에서 caption에 대한 부분이 아예 없었다. 빼먹었나보다.

[이전 글](https://haroldfromk.github.io/posts/Build-the-unofficial-Udemy-Home-Screen-(1)/){:target="_blank"} 에 해당 내용이 빠져있으니 참고...

수정을 하고나니 제대로 나온다.

![simulator_screenshot_08B39584-6A5B-4AEE-86C8-4B154794FCC9](https://github.com/user-attachments/assets/e227cda5-4144-45d7-a307-f96464b97733){: width="50%" height="50%"} 

그러면 제일 상단의 메인 배너 쪽이 완성이 된다!