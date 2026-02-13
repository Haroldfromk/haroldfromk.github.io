---
title: Build the unofficial Udemy Home Screen (1)
writer: Harold
date: 2024-10-09 12:13
modified: 2024-10-10 12:13
categories: [Udemy]
tags: []

toc: true
toc_sticky: true
---

## 시작전 기본 세팅

우선 스냅킷을 설치.

Snapkit Dynamic은 여전히 에러가 발생하는듯하니 설치하지 말자.

![CleanShot 2024-10-10 at 02 15 29](https://github.com/user-attachments/assets/33cf7299-a9bd-4442-baa7-0922318fa0df){: width="50%" height="50%"}

Xcode Project 생성시 생기는 파일에서 Info.plist, VC 빼고 나머지 파일들을 모두 Supporting Files에 넣어주었다.

그리고 이번엔 JSON을 사용하여 구성을하기에 JSON 파일을 하나 만들어 준다.

```json
{
    "layout" : {
        "name" : "Hello"
    }
}
```

그리고 내용은 간단하게 이렇게만 한다.

![CleanShot 2024-10-10 at 02 26 24](https://github.com/user-attachments/assets/6d1808a0-3c03-47db-8de2-c478943a6a75){: width="50%" height="50%"} 

그리고 SwiftUIView 디렉토리엔 반드시 위와 같이 SwiftUI 에 해당하는 파일로 선택해서 만들자.

![CleanShot 2024-10-10 at 02 28 40](https://github.com/user-attachments/assets/1491168a-0a9e-4944-bf7e-14a3f79073b3){: width="50%" height="50%"} 

## 컬렉션뷰 세팅

View 디렉토리에 여러 파일들을 미리 만들어준다.

![CleanShot 2024-10-10 at 02 35 44](https://github.com/user-attachments/assets/e0bcd18c-809f-496f-a330-58f13dfd274b){: width="50%" height="50%"} 

현재는 아무것도 없는 빈 깡통.

### HomeCollectionView Setting

```swift
import UIKit

final class HomeCollectionView: UICollectionView {
    
    init() {
        super.init(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        backgroundColor = .green
    }
}
```

우선은 기본적인 세팅만 해두었다.


VC로 가서 제대로 세팅이 되었는지 확인해보자.

```swift
import UIKit
import SnapKit

class HomeViewController: UIViewController {

    private let collectionView = HomeCollectionView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

}
```

우선 collectionView를 만들고 그것을 띄우는데 autolayout을 view전체를 덮어씌우는 느낌으로 간다.

즉 실행했을때 녹색화면이 보인다면 제대로 되었다는 것.

![simulator_screenshot_A3D22DA3-47E8-436D-BC52-9DAED2F752B3](https://github.com/user-attachments/assets/fb17891e-37a0-4af5-9d01-6d1ceb0dc57c){: width="50%" height="50%"} 

정상인것을 확인!

## UIModel 추가

```swift
import Foundation

struct HomeUIModel: Hashable {
    
    let sectionModels: [SectionModel] // added     

    struct SectionModel: Hashable {
        let section: Section
        let body: [Item]
    }
    
    enum Section:Hashable {
        case mainBanner(id: String)
        case textheader(id: String)
        case courseSwimlane(id: String)
        case udemyBusinessBanner(id: String)
        case categories(id: String)
        case featuredCourses(id: String)
    }
    
    enum Item: Hashable {
        case mainBanner(id: String, imageLink: String, title: String, caption: String)
        case course(id: String, imageLink: String, title: String, author: String, rating: Double, reviewCount: Int, price: Decimal, tag: String)
        case textHeader(id: String, text: String, highlightedText: String?)
        case udemyBusinessBanner(id: String, link: String)
        case categoriesScroller(id: String, titles: [String])
        case featuredCourse(id: String, imageLink: String, title: String, author: String, rating: Double, reviewCount: Int, price: Decimal)
    }

}
```

![CleanShot 2024-10-10 at 03 01 16](https://github.com/user-attachments/assets/f6a9dc34-e7a6-4ae2-b3e8-aeecc5720b7e){: width="50%" height="50%"} 

강의에 있는 이부분에 대한 모델링을 미리 해두는 것이다.

`let sectionModels: [SectionModel]` 이부분이 빠져서 새로 추가 해준다 - 24.10.10 modified

## MainBannerView 추가

```swift
struct PlaceholderImageView: View {
    var body: some View {
        Rectangle()
            .foregroundColor(.gray.opacity(0.3))
    }
}

#Preview {
    PlaceholderImageView()
}
```

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
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .padding(.leading, 20)
        }
    }
}

#Preview {
    MainBannerView(imageLink: "https://plus.unsplash.com/premium_photo-1661373704604-7c4d230c8928?q=80&w=1740&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D", title: "Learning that fits", caption: "Skills for your present and future")
}
```

![CleanShot 2024-10-10 at 03 38 30](https://github.com/user-attachments/assets/32c7c39c-5c35-45ea-a6aa-07e918df30ff){: width="50%" height="50%"} 

Preview를 하게 되면 이렇게 나온다.

여기서 새로운건 AsyncImage이다.

[Docs](https://developer.apple.com/documentation/swiftui/asyncimage){:target="_blank"}도 읽어보면 좋을듯.

간단하게 정의하면 url주소를 통해 이미지를 가져온다고 생각하면 된다.

그리고 거기에있는 새로운 Modifier는 바로 `.clipped`

이녀석은 이미지나 뷰의 일부가 부모 뷰의 경계를 벗어날 때, 그 초과 부분을 잘라내는 역할을 한다.

예를 들어, 이미지가 frame의 크기를 초과할 경우 clipped()를 사용하면 지정된 크기 바깥으로 나오는 부분을 잘라낸다. 

이렇게 하면 이미지가 frame의 경계를 벗어나지 않고 깔끔하게 표시된다.
- clipped()가 없는 경우: 이미지가 지정된 frame을 넘어갈 경우, 초과된 부분이 화면에 그대로 표시될 수 있다.
- clipped() 사용 시: 이미지가 frame 밖으로 나가는 부분이 잘려서 보이지 않게 된다.