---
title: Create Model (2)
writer: Harold
date: 2024-04-20 15:13
#last_modified_at: 2024-04-15 09:11
categories: [Udemy, CoreML]
tags: []

toc: true
toc_sticky: true
---

## playground를 통한 자연어 처리 Model 생성

우선 Dataset을 하나 가져온다.

![CleanShot 2024-04-20 at 18 49 32@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/d2b7a619-a35d-4de0-80ef-c17e1980ce1a)

내용은 다음과 같다.

![CleanShot 2024-04-20 at 18 55 56@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/dd972078-304e-4d94-b933-a653214b157f)

여기서 playground로 만들어 주자.

```swift
import Cocoa
import CreateML

let data = try MLDataTable(contentsOf: URL(fileURLWithPath: ""))

```

Dataset을 가져오는 작업을 한다.

위의 path에 경로를 넣어주자.

![CleanShot 2024-04-20 at 19 00 16@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8b5a2319-3d8b-4250-aa44-4883d6cfafbc)

실행해보니 path도 잘 연결된것으로 나온다.

이젠 Train / Test Data를 만들어볼것이다.

```swift
let(traningData, testingData) = data.randomSplit(by: 0.8, seed: 5)

let sentimentClassifier = try MLTextClassifier(trainingData: traningData, textColumn: "text", labelColumn: "class")
```

전에 언급했던 8:2의 비율로 나누고, seed는 일종의 난수로 시드에 따라 랜덤으로 8:2로 맞춰준다.

여기 textColumn과 labelColumn은 

![CleanShot 2024-04-20 at 19 04 17@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/03cf87d3-0cf5-4c65-85b4-53d204bf0189)

이렇게 된다.

```swift
// before
import Cocoa
import CreateML

let data = try MLDataTable(contentsOf: URL(fileURLWithPath: "/Users/dongik/Documents/Workspace/twitter-sanders-apple3.csv"))


let(traningData, testingData) = data.randomSplit(by: 0.8, seed: 5)
//
let sentimentClassifier = try MLTextClassifier(trainingData: traningData, textColumn: "text", labelColumn: "class")

let evaluationMetrics = sentimentClassifier.evaluation(on: testingData, textColumn: "text", labelColumn: "class")

let evatuationAccuracy = (1.0 - evaluationMetrics.classificationError) * 100
```

![CleanShot 2024-04-20 at 19 16 55@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e0b971f7-30da-4c1c-9884-f4edd4cd03f5)

실행하니 다음과 같다.

이제 모델을 저장해보자.

``` swift
let metadata = MLModelMetadata(author: "Harold Song", shortDescription: "A model trained to classify sentiment on Tweets", version: "1.0")

try sentimentClassifier.write(to: URL(fileURLWithPath: "/Users/dongik/Documents/Workspace/TweetSentimentClassifer.mlmodel"), metadata: metadata)
```

model에 대한 정보를 적고. 실행하면 모델이 생긴다.

## Test Model

predict를 통해 테스트를 해보자

![CleanShot 2024-04-20 at 19 23 15@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c3d58cc7-783b-4894-b264-c588b2ba0e32)

부정적인 글을 썼더니 결과로 Neg가 나온다.

```swift
import Cocoa
import CreateML


let data = try MLDataTable(contentsOf: URL(fileURLWithPath: "/Users/dongik/Documents/Workspace/twitter-sanders-apple3.csv"))


let(traningData, testingData) = data.randomSplit(by: 0.8, seed: 5)

let sentimentClassifier = try MLTextClassifier(trainingData: traningData, textColumn: "text", labelColumn: "class")

let evaluationMetrics = sentimentClassifier.evaluation(on: testingData, textColumn: "text", labelColumn: "class")

let evatuationAccuracy = (1.0 - evaluationMetrics.classificationError) * 100

let metadata = MLModelMetadata(author: "Harold Song", shortDescription: "A model trained to classify sentiment on Tweets", version: "1.0")

try sentimentClassifier.write(to: URL(fileURLWithPath: "/Users/dongik/Documents/Workspace/TweetSentimentClassifer.mlmodel"), metadata: metadata)


try sentimentClassifier.prediction(from: "@Apple is a terrible company!") // Neg

try sentimentClassifier.prediction(from: "I just found the best restaurant ever, and it's @DuckandWaffle") // Pos

try sentimentClassifier.prediction(from: "I think @CocaCola ads are just ok.") // Neutral

```

## Xcode에 Framework 추가하기.

![CleanShot 2024-04-20 at 20 42 42@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c819f0cc-90f1-456d-99e1-3301dd5910b4)

Drag & Drop으로 만든 모델을 가져와서 클릭해보니, 내가 Metadata로 입력한 값들이 그대로 들어가 있는걸 알 수 있다.

그리고 Twitter Api를 사용하기위해 [Site](https://developer.twitter.com/en)를 접속해보자.

그리고 개발자 계정을 만들어 두자.

swift에 관한 내용은 [여기](https://github.com/mattdonnelly/Swifter)를 참고.

그리고 해당 내용 깃클론으로 가져온다.

그리고 우리가 만든 프로젝트에 드래그를 해준다.

![CleanShot 2024-04-20 at 21 15 10@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8cf17300-53f4-4ff7-9cd1-87d54f310758){: width="50%" height="50%"}

그리고 프로젝트 바로 하위로 드래그 해준다.

xcodeproj 파일을 드래그 해준 이유는 아래 사진으로 모두 설명이 된다.

![CleanShot 2024-04-20 at 21 16 40@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/a74fc059-1be3-49f9-9bba-071e7eb3abe6){: width="50%" height="50%"}

이렇게 프로젝트의 하위 내용도 그대로 사용이 가능해진다.

이젠 해당 프레임워크를 사용해야하니 추가를 해보자.

![CleanShot 2024-04-20 at 21 17 46@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/4f00b487-807c-46ee-842a-ef1bd3cc91cd)

위의 사진처럼 추가를 해주면 된다.

![CleanShot 2024-04-20 at 21 19 11@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/32168d1c-bb54-4cf6-986c-47f008e085bf)

확인은 위와 같이 해준다.

그리고 빌드테스트로 확인을 해주면 프레임워크 추가 끝.

혹시나 빌드 테스트를 하면서 버전에 관한 에러가 뜬다면?

![CleanShot 2024-04-20 at 21 21 25@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/470240b2-4438-4563-9417-651c265501b2)

이렇게 Minimum Deployments Version을 수정해주면된다.

## Twitter Framework 사용

`swifter = Swifter(consumerKey: TWITTER_CONSUMER_KEY, consumerSecret: TWITTER_CONSUMER_SECRET)` 이걸 복사해서

입력하고 consumer key, consumer secret을 입력해주자.

## API Key 관리.

API키는 민감한 정보이므로, 이런 내용들이 Github에 올라가는 일을 방지해야한다. 물론 Git Guardian으로 메일이 와서 경고를 해주기도하지만, 애초에 해당 내용을 방지하는게 좋다.

![CleanShot 2024-04-20 at 21 31 10@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/421d1cd3-b434-40bb-81ac-e616a0d4f7cf)

이렇게 새로운 PropertyList파일을 하나 만들어준다.

![CleanShot 2024-04-20 at 21 33 05@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/30214af7-db9f-4a0d-ad02-9db2422c9067)

그리고 여기에 담아주는데, 이때 .plist 파일을 .gitignore에 적어서 해당 파일을 업로드 하지 못하게 하면 된다.

[글](https://stackoverflow.com/questions/14778429/secure-keys-in-ios-app-scenario-is-it-safe)한번 읽어보는 것도 추천.

## 검색하는 기능을 구현.

swifter의 searchTweet Method를 사용하는데, parameter가 많다.

parameter에 대한 정보는.

[Docs](https://developer.twitter.com/en/docs/twitter-api/v1/tweets/search/api-reference/get-search-tweets)를 참고.

```swift
 swifter.searchTweet(using: "@Apple") { (result, metadata) in
            print(result)
        } failure: { error in
            print(error)
        }
```

검색에 관련된 메서드를 다음과 같이 적어주었다.

우선 실행해서 어떻게 나오는지를 확인해\보자.

```
SwifterError(message: "HTTP Status 401: Unauthorized, Response: {\"errors\":[{\"code\":32,\"message\":\"Could not authenticate you.\"}]}"
```

우선 Auth Error가 발생했기에, api key를 다시한번 확인해본다.

Key를 Regenerate하여 입력하니 

```
SwifterError(message: "HTTP Status 403: Forbidden, Response: {\"errors\":[{\"message\":\"You currently have access to a subset of Twitter API v2 endpoints and limited v1.1 endpoints (e.g. media post, oauth) only. If you need access to this endpoint, you may need a different access level. You can learn more here:
```

다른 에러가 발생한다.

아무래도 api 유료화에 대한 정책이라 더이상 진행이 불가능 해보인다...

그냥 추가로 흐름에 대해서만 적도록 한다.

## 모델 적용.

`let sentimentClassifier = TweetSentimentClassifer()` model을 instance화 하고,

predict 메서드를 사용한다.

```swift
let prediction = try! sentimentClassifier.prediction(text: "@Apple is a terribe company")
        
print(prediction.label)
```

이렇게 예측 값을 출력을 할 수 있다.

그리고 여러값을 배열에 저장해서 예측을 할때는

```swift
var tweets = [TweetSentimentClassiferInput]()
            
            for i in 0 ..< 100 {
                if let tweet = result[i]["full_text"].string {
                    let tweetForClassfication = TweetSentimentClassiferInput(text: tweet)
                    tweets.append(tweetForClassfication)
                }
            }
            
            do {
                let predictions = try self.sentimentClassifier.predictions(inputs: tweets)
                for pred in predictions {
                    print(pred.label)
                }
            } catch {
                print(error)
            }

```

이런식으로 여러 값을 저장할때 type이 중요한데, 우리가 만든 모델에 input 메서드를 통해 string값을 저장을 한다.

이때 tweetForClassfication의 datatype은 `TweetSentimentClassiferInput` 이다.

그러므로 `var tweets = [TweetSentimentClassiferInput]()` 배열도 이렇게 만드는 것이다.

그리고 predict를 사용할때 어러 배열값이 들어갈때는 

![CleanShot 2024-04-21 at 00 13 44@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/0054be05-122c-4ff1-8efc-36f99f1fc7e2)

이렇게 한번씩 option으로 확인을 해주는게 중요하다.

이번 챕터는 여기까지..

