---
title: Build the unofficial Udemy Home Screen (7)
writer: Harold
date: 2024-10-12 06:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## Tap 이벤트를 VC로 전달하기

Combine의 EventPublisher를 사용하여 할것이다.

HomeCollectionView에서 진행한다.

```swift
enum Event {
        case itemTapped(HomeUIModel.Item)
    }

private let eventSubject = PassthroughSubject<Event, Never>()
var eventPublisher: AnyPublisher<Event, Never> {
    return eventSubject.eraseToAnyPublisher()
}
```

그리고 cell에도 내용을 바꿔준다.

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
                cell.onTap = { [weak self] in
                    self?.eventSubject.send(.itemTapped(item))
                    print(">>> TextHeader link tapped: \(id) - \(highlightedText)")
                }
                return cell
            case let .course(id, imageLink, title, author, rating, reviewCount, price, tag):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CourseCollectionViewCell.namedIdentifier, for: indexPath) as! CourseCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, author: author, rating: rating, reviewCount: reviewCount, price: price, tag: tag)
                cell.onTap = {[weak self] in
                    self?.eventSubject.send(.itemTapped(item))
                }
                return cell
            case let .categoriesScroller(_, titles):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoriesCollectionViewCell.namedIdentifier, for: indexPath) as! CategoriesCollectionViewCell
                cell.configure(titles: titles)
                cell.onTap = { [weak self] title in
                    // self?.eventSubject.send(.itemTapped(item))
                    print(">>> category tapped is \(title)")
                }
                return cell
            case let .featuredCourse(_, imageLink, title, author, rating, reviewCount, price):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeaturedCourseCollectionViewCell.namedIdentifier, for: indexPath) as! FeaturedCourseCollectionViewCell
                cell.configure(imageLink: imageLink, title: title, author: author, rating: rating, reviewCount: reviewCount, price: price)
                cell.onTap = { [weak self] in
                    self?.eventSubject.send(.itemTapped(item))
                }
                return cell
            case let .udemyBusinessBanner(_, link):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UdemyBusinessCollectionViewCell.namedIdentifier, for: indexPath) as! UdemyBusinessCollectionViewCell
                cell.onTap = { [weak self] in
                    self?.eventSubject.send(.itemTapped(item))
                }
                return cell
            }
        })
    }
```

`categoriesScroller`경우만 프린트를 해둔 이유는

title에 바로 접근을 지금 할수가 없기에 잠시 보류를 해둔상태라고 보면된다.

지금 할 수 없다는 것은

```swift
enum Item: Hashable {
        case mainBanner(id: String, imageLink: String, title: String, caption: String)
        case course(id: String, imageLink: String, title: String, author: String, rating: Double, reviewCount: Int, price: Decimal, tag: String)
        case textHeader(id: String, text: String, highlightedText: String?)
        case udemyBusinessBanner(id: String, link: String)
        case categoriesScroller(id: String, titles: [String])
        case featuredCourse(id: String, imageLink: String, title: String, author: String, rating: Double, reviewCount: Int, price: Decimal)
    }
```

여기 아이템에서 categoriesScroller로 들어가서 title을 가져올수없기때문.

### HomeVC에서 Event 정의하기

우선 loadView를 override 해준다.

loadView의 경우엔 [이전](https://haroldfromk.github.io/posts/%EB%AA%A8%EC%9D%98%EB%A9%B4%EC%A0%91/){:target="_blank"}에 간략하게 적어둔게 있어서 생략

```swift
override func loadView() {
        super.loadView()
        observe()
    }

private func observe() {
        collectionView.eventPublisher.sink { [weak self] event in
            switch event {
            case let .itemTapped(item):
                self?.handleItemTapped(item: item)
            }
        }.store(in: &cancellables)
    }
    
private func handleItemTapped(item: HomeUIModel.Item) {
        switch item {
        case .mainBanner(let id, let imageLink, let title, let caption):
            print(">>> mainBanner tapped")
        case .course(let id, let imageLink, let title, let author, let rating, let reviewCount, let price, let tag):
            print(">>> course tapped")
        case .textHeader(let id, let text, let highlightedText):
            print(">>> textHeader tapped")
        case .udemyBusinessBanner(let id, let link):
            print(">>> udemyBusinessBanner tapped")
        case .categoriesScroller(let id, let titles):
            print(">>> categoriesScroller tapped")
        case .featuredCourse(let id, let imageLink, let title, let author, let rating, let reviewCount, let price):
            print(">>> featuredCourse tapped")
        }
    }
```

**observe() 함수**:
- 컬렉션 뷰에서 발생하는 이벤트를 감지하는 역할을 한다.
- collectionView.eventPublisher를 통해 이벤트 스트림을 구독하고, 아이템이 탭 되었을 때 itemTapped 이벤트가 발생하면 handleItemTapped 함수로 해당 아이템을 전달하여 처리한다.
- 메모리 누수를 방지하기 위해 [weak self]로 약한 참조를 사용하며, 구독은 cancellables에 저장된다.

**handleItemTapped(item:) 함수**:
- 사용자가 탭한 항목에 대한 세부 처리를 담당한다.
- HomeUIModel.Item 타입의 아이템에 대해 switch를 사용하여 어떤 타입의 아이템이 탭되었는지 확인하고, 그에 맞는 동작(여기서는 print)을 수행한다.
- 탭된 아이템의 타입에 따라 (예: mainBanner, course, textHeader 등) 적절한 로그를 출력한다.

## Category Tap 수정

```swift
cell.onTap = { [weak self] title in
                    // self?.eventSubject.send(.itemTapped(item))
                    print(">>> category tapped is \(title)")
                }
```

여기만 프린트로 별도로 해둔부분을 수정하려고 한다.

프린트를 지우고 주석단부분을 활성화 했을때 어떻게 나오는지 먼저 확인해보자.

**[before]**
![Oct-12-2024 22-14-07](https://github.com/user-attachments/assets/5fd0cb0f-bda6-43c0-a7f1-3472074360ae){: width="50%" height="50%"} 

**[after]**
![Oct-12-2024 22-13-30](https://github.com/user-attachments/assets/4e813db3-ec0d-4f74-b624-5820e67086f8){: width="50%" height="50%"} 

아이템을 지칭하는 전체적인것이 탭이 되었다고 뜬다.

> 그러면 HomeVC에서 titles를 가져오면?

```swift
case .categoriesScroller(let id, let titles):
            print(">>> categoriesScroller tapped \(titles)")
```
이렇게 했을때 어떻게 출력이 되는지 확인해보자.

![Oct-12-2024 22-30-16](https://github.com/user-attachments/assets/e5c1ef99-247d-4e0b-af0e-afa4c896fa96){: width="50%" height="50%"} 

하나를 클릭하더라도 전체 category안에 있는 전체 Item들이 다 보이는걸 알 수 있다.

그래서 잠시 홀딩을 해두었던것.

HomeCollectionView로 가서 

선택된 항목에 대한 변수를 하나 만들어 준다.

```swift
cell.onTap = { [weak self] title in
                    let selected = HomeUIModel.Item.categoriesScroller(id: id, titles: [title])
                    self?.eventSubject.send(.itemTapped(selected))
                }
```
그리고 item대신 selected로 파라미터를 바꿔주자.

selected는 사용자가 카테고리를 탭했을 때, 선택된 카테고리 정보를 담은 객체이다.

이 객체는 HomeUIModel.Item.categoriesScroller 타입의 새로운 인스턴스로 생성되며, 탭된 title 정보를 가지고 있다.

- **selected**는 탭된 카테고리 정보를 바탕으로 새로운 categoriesScroller 아이템을 만든다.
- id: 기존의 categoriesScroller 아이템의 고유 ID를 유지한다.
- titles: [title]: 사용자가 선택한 하나의 title만을 포함하는 배열로 생성된다.
- 기존의 titles 배열이 아니라, 탭된 특정 카테고리(title)만을 포함하는 배열로 만들어진다.

```swift
case .categoriesScroller(let id, let titles):
            guard let title = titles.first else { return }
            print(">>> categoriesScroller tapped \(title)")
```

그리고 선택된 항목의 값만 출력하기위해 first를 한다.

first를 하지않으면 

`>>> categoriesScroller tapped ["Development"]` 

이런식으로 배열로 값이 보일것이다.

이제 탭을 해보면

![Oct-12-2024 22-37-03](https://github.com/user-attachments/assets/f89241d4-ca56-4d93-a45a-db750102e9d3){: width="50%" height="50%"} 

잘 된다.

## Course 상세 설명 보여주기.

우선 새로운 디렉토리(CourseDetail)를 만들어 준다.

상세페이지를 담당할 `CourseDetailViewController`파일을 만들어 준다.

```swift
class CourseDetailViewController: UIViewController {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .bold)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(32)
            make.trailing.equalToSuperview().offset(-32)
        }
        
    }
    
    func setText(title: String) {
        titleLabel.text = title
        
    }
}
```

아직까진 크게 서술할만한건 없다.

HomeVC에서 CourseDetailVC를 호출하도록 만든다.

```swift
case .course(let id, let imageLink, let title, let author, let rating, let reviewCount, let price, let tag):
            showCourseDetailsViewcontroller(title: title)
            print(">>> course tapped \(id) - \(title)")


private func showCourseDetailsViewcontroller(title: String) {
        let viewController = CourseDetailViewController()
        viewController.setText(title: title)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
```

하지만 이렇게해도 실행했을때 화면이 나오지 않는다.

왜냐면 `showCourseDetailsViewcontroller`에서 NavigationController를 사용하는데, 현재 NavigationController는 없기 때문이다.

StoryBoard로 가서 NavigationController를 Embeded 해주자.

![CleanShot 2024-10-12 at 23 06 52](https://github.com/user-attachments/assets/794fc2ad-0b3e-4f46-831e-6338e109ca80)

여기서 해도되고 

![CleanShot 2024-10-12 at 23 08 18](https://github.com/user-attachments/assets/42256960-1c51-4d75-8592-d6a898c6706b)


편한걸로 하자.

![simulator_screenshot_40369EEE-613F-453F-861D-C0AFFC295507](https://github.com/user-attachments/assets/73381f43-5f79-4ac7-98ff-080692812598){: width="50%" height="50%"} 

상단에 NavigationBar Area가 생긴걸 알 수 있다.

![Oct-12-2024 23-11-12](https://github.com/user-attachments/assets/fbb48c2a-583a-4629-8103-62f3ead7bcc5){: width="50%" height="50%"} 

이걸 숨기기 위해서

```swift
override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
    }
    
override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
```

이렇게 해주었다.

HomeVC가 보일때는 NavigationBar를 숨기고, 사라질때 NavigationBar를 보이게 한다.

그래야 CourseDetailVC에서 NavigationBar 가 보여서 back을 할 수 있기 때문

## UdemyBusiness 탭 이벤트 적용하기

여기는 html링크가 있으므로 해당부분을 탭했을때 safari를 통해 홈페이지가 보여지게 하면 된다.

먼저 함수를 하나 만들어준다.

그리고 사파리를 사용하기 위해서

`import SafariServices` 임포트 해주자.

```swift
private func showSafariWebView(link: String) {
        guard let url = URL(string: link) else { return }
        navigationController?.pushViewController(SFSafariViewController(url: url), animated: true)
    }
```

![CleanShot 2024-10-12 at 23 37 26](https://github.com/user-attachments/assets/66adfe9b-53a6-48ee-be74-9d7f958339cb){: width="50%" height="50%"} 

```swift
case .udemyBusinessBanner(let id, let link):
            showSafariWebView(link: link)
```

print 대신 바꿔준다.

![Oct-12-2024 23-39-06](https://github.com/user-attachments/assets/e041406f-0507-428f-abe4-54fc1678c1ee){: width="50%" height="50%"} 

현재 링크를 Udemy로 해두었는데 이렇게 바로 사이트로 연결되는걸 확인할 수 있다.

## Tab Event 정리

![CleanShot 2024-10-12 at 23 41 42](https://github.com/user-attachments/assets/b31a78af-3f23-4bcf-ac9d-62651cd4c678){: width="50%" height="50%"} 

현재 이렇게 Warning이 많기에 사용하지 않는 파라미터, 그리고 item들을 좀 정리한다.

```swift
private func handleItemTapped(item: HomeUIModel.Item) {
        switch item {
        case .mainBanner:
            break
        case let .course(_, _, title, _, _, _, _, _):
            showCourseDetailsViewcontroller(title: title)
        case .textHeader:
            break
        case let .udemyBusinessBanner(_, link):
            showSafariWebView(link: link)
        case let .categoriesScroller(_, titles):
            guard let title = titles.first else { return }
            print(">>> categoriesScroller tapped \(title)")
        case .featuredCourse:
            break
        }
    }
```

![CleanShot 2024-10-12 at 23 50 12](https://github.com/user-attachments/assets/5e421c8c-14f4-42ce-a743-6508e05fa10c){: width="50%" height="50%"} 

warning들이 전부 사라졌다.

case 바로 뒤에 let을 사용함으로써 파라미터안애서 변수를 만들지 않게 했다.

---

case 뒤에 let을 붙이는 것과 파라미터에서 let을 붙이는 것은 패턴 매칭을 통해 값을 바인딩하는 위치와 방식에서 차이를 나타낸다.

1. case let을 사용하는 경우:
- case 뒤에 let을 붙이면 한 번에 모든 값을 바인딩한다
- 각 변수에 let을 따로 붙이지 않고 더 간결하게 작성할 수 있다
- 패턴 매칭을 통해 케이스의 모든 값을 한꺼번에 처리한다
- `case let .udemyBusinessBanner(id, link): // 한 번에 모든 값을 바인딩`

2. 각 변수에 let을 붙이는 경우:
- 각 변수마다 let을 붙여서 개별적으로 바인딩한다
- 명시적으로 값을 바인딩하므로 어떤 값을 바인딩하는지 더 명확하게 표현한다
- `case let .udemyBusinessBanner(id, link): // 한 번에 모든 값을 바인딩`
