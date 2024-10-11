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