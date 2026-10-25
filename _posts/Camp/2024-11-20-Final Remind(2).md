---
title: Final Remind (2) 커뮤니티 채팅은 어떻게 실시간으로 움직였나
writer: Harold
date: 2024-11-20 01:00:00 +0900
last_modified_at: 2026-10-26 08:40:00 +0900
categories: [캠프, Remind]
tags: [Firebase, Firestore, FirebaseStorage, MessageKit, UIKit]

toc: true
toc_sticky: true
published: true
---

> 프로젝트 막바지에는 기능 구현에 쫓겨 블로그 정리를 제대로 하지 못했다. 그래서 이 글은 당시 GitHub 커밋 내역과, 프로젝트 기간에 직접 적어 둔 업무 내역 목록을 AI(Claude Code)에게 보여주고 그걸 바탕으로 내용을 다시 정리했다. 코드는 프로젝트의 마지막 코드(dev branch)에서 가져왔다.
{: .prompt-info }

Final (21) 즈음부터는 정리할 시간이 없어서 화면도 거의 찍지 못했다. 그중에서도 커뮤니티 채팅은 매일 손을 댔는데, 정작 "Firebase 의 listener 를 써서 실시간으로 된다" 정도로만 알고 넘어갔다. 그래서 이 글에서는 채팅 하나가 어디에 저장되고, 어떻게 다른 사람 화면에 나타나는지를 처음부터 따라가 본다. 글자, 사진, 지도 메시지를 모두 다룬다.

채팅의 뼈대(`ChatFirestoreStream`, `FirebaseStorageManager`, 사진 전송)는 진문님이 만들었고, 나는 그 위에 게스트, 지도 첨부, 신고와 차단, 프로필 사진 같은 것을 붙였다. 둘이 만든 코드가 섞여 있지만 흐름을 이해하려면 전부 봐야 해서 같이 정리한다.

---

## 채팅 데이터가 놓이는 곳

채팅 메시지는 Firebase 의 Firestore 에 저장되고, 사진 파일만 Firebase Storage 에 따로 저장된다. 먼저 Firestore 가 데이터를 어떤 모양으로 담는지부터 본다.

---

### Firestore란?

Firestore 는 Firebase 가 제공하는 데이터베이스다. 표(table)에 행을 쌓는 방식이 아니라, 폴더와 파일처럼 생겼다.

- document: 파일 하나다. 안에 `이름: 값` 형태의 필드가 들어 있다. 메시지 한 개가 document 한 개다
- collection: document 를 모아 두는 폴더다
- document 안에 다시 collection 을 둘 수 있다. 이걸 subcollection 이라고 한다

우리 앱의 채팅은 이렇게 생겼다.

![채팅방 목록인 channels collection 안에 채팅방 document 가 있고, 그 아래 thread collection 에 메시지 document 가 쌓인다. 메시지에는 글자, 사진 주소, 위도 경도 중 하나만 들어가고, 사진 파일 자체는 Storage 에 있다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2024-11-20-Final-Remind2/chat-firestore-structure.png)

`channels` collection 에 "서울특별시", "경기도" 같은 채팅방 document 가 있고, 각 채팅방 아래 `thread` collection 에 메시지가 하나씩 쌓인다. 그래서 서울 채팅방의 메시지 주소는 `channels/서울 채팅방 id/thread/메시지 id` 가 된다.

메시지 document 의 필드 중 `content`, `url`, `latitude, longitude` 는 셋 중 하나만 들어간다. 무엇이 들어 있느냐로 글자, 사진, 지도 메시지가 갈린다. 사진은 파일 자체가 아니라 Storage 에 올린 파일의 주소만 들어간다.

Firestore 에 대한 더 자세한 설명은 [데이터 모델 Docs](https://firebase.google.com/docs/firestore/data-model){:target="_blank"}에 있다.

---

### 메시지를 document 로 바꾸기

앱 안에서 메시지는 `Message` 구조체다. MessageKit 이 화면에 그릴 수 있도록 `MessageType` 프로토콜을 따른다. Firestore 에 저장할 때는 이걸 dictionary 로 바꾼다.

```swift
protocol DatabaseRepresentation {
    var representation: [String: Any] { get }
}

extension Message: DatabaseRepresentation {
    var representation: [String : Any] {
        var representation: [String: Any] = [
            "created": sentDate,
            "senderId": sender.senderId,
            "senderName": sender.displayName,
            "chatReportCount": chatReportCount,
            "isActive": isActive
        ]

        if let url = downloadURL {
            representation["url"] = url.absoluteString
        } else if let location = location {
            representation["latitude"] = location.coordinate.latitude
            representation["longitude"] = location.coordinate.longitude
        } else {
            representation["content"] = content
        }

        return representation
    }
}
```

#### DatabaseRepresentation으로 메시지를 dictionary로 만들기

`DatabaseRepresentation` 은 Firebase 가 아니라 프로젝트에서 직접 만든 프로토콜이다. "Firestore 에 넣을 수 있는 dictionary 를 돌려줄 수 있다" 는 약속 하나만 있다. 채팅방(`Channel`)도 같은 프로토콜을 따른다.

Firestore 는 `[String: Any]` dictionary 를 받아서 그대로 document 의 필드로 저장한다. 값으로는 문자열, 숫자, Bool, 날짜, 배열 같은 기본 타입만 넣을 수 있어서, `URL` 은 `absoluteString` 으로 문자열로 바꾸고, [`CLLocation`](https://developer.apple.com/documentation/corelocation/cllocation){:target="_blank"} 은 `coordinate` 의 위도(`latitude`)와 경도(`longitude`) 두 숫자로 나눠서 넣는다. `sentDate` 같은 `Date` 는 Firestore 가 자기 날짜 타입인 `Timestamp` 로 바꿔서 저장한다.

읽어올 때는 반대로 document 를 `Message` 로 되살린다.

```swift
init?(document: QueryDocumentSnapshot) {
    let data = document.data()
    guard let sentDate = data["created"] as? Timestamp,
          let senderId = data["senderId"] as? String,
          let senderName = data["senderName"] as? String else { return nil }
    id = document.documentID
    self.sentDate = sentDate.dateValue()
    sender = Sender(senderId: senderId, displayName: senderName)

    if let content = data["content"] as? String {
        self.content = content
        downloadURL = nil
        location = nil
    } else if let urlString = data["url"] as? String, let url = URL(string: urlString) {
        downloadURL = url
        content = ""
        location = nil
    } else if let latitude = data["latitude"] as? CLLocationDegrees, let longitude = data["longitude"] as? CLLocationDegrees {
        location = CLLocation(latitude: latitude, longitude: longitude)
        content = ""
        downloadURL = nil
    } else {
        return nil
    }
}
```

#### QueryDocumentSnapshot으로 메시지 되살리기

[`QueryDocumentSnapshot`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/QueryDocumentSnapshot){:target="_blank"} 은 query 로 읽어 온 document 하나다. `data()` 는 필드를 `[String: Any]` 로 돌려주고, `documentID` 는 Firestore 가 document 를 만들 때 붙여 준 고유 id 다. 이 id 를 메시지 id 로 써서, 같은 메시지가 두 번 들어오지 않게 막는다.

저장할 때 넣은 `Date` 는 읽을 때 `Timestamp` 로 돌아오기 때문에 `dateValue()` 로 다시 `Date` 로 바꾼다. 필수 필드가 없거나 세 종류 중 아무것도 없으면 `init?` 이 `nil` 을 돌려줘서, 모양이 이상한 document 는 화면에 나오지 않는다.

---

## 한 번 읽기와 계속 듣기

여기까지는 저장과 읽기의 모양이다. 이제 이 글의 핵심인 "다른 사람이 보낸 메시지가 내 화면에 어떻게 바로 나타나는가" 를 본다.

---

### Listener란?

Firestore 에서 데이터를 가져오는 방법은 두 가지다.

- 한 번 읽기(`getDocuments`): 지금 있는 데이터를 한 번 가져오고 끝난다. 택배 조회 화면을 직접 새로고침하는 것과 같다
- 계속 듣기(`addSnapshotListener`): 한 번 등록해 두면, 그 데이터가 바뀔 때마다 Firestore 가 새 결과를 보내준다. 택배 상태가 바뀌면 문자로 알려주는 알림을 신청해 두는 것과 같다

이 등록해 둔 알림을 listener 라고 부른다. 채팅방에 들어가면 그 채팅방의 `thread` collection 에 listener 를 붙인다. 그 뒤로는 누가 메시지를 하나 저장할 때마다, 그 채팅방에 listener 를 붙여 둔 모든 폰에 "document 가 하나 추가됐다" 는 알림이 간다.

![보내는 폰이 Firestore 에 메시지를 저장하면, 그 채팅방을 구독 중인 다른 폰들과 보낸 폰 자신의 listener 가 모두 추가 이벤트를 받는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2024-11-20-Final-Remind2/chat-listener-flow.png)

그래서 채팅을 보낼 때 "상대방 폰에 보내기" 같은 코드는 따로 없다. 보내는 쪽은 Firestore 에 document 를 하나 저장할 뿐이고, 받는 쪽은 listener 가 알려주는 것을 화면에 그릴 뿐이다. 둘은 서로를 모른다.

---

### listener 를 처음 붙였을 때 오는 것

listener 를 붙이면 Firestore 는 변경을 기다리기 전에, 지금 조건에 맞는 document 전부를 먼저 한 번 보내준다. 이때 모든 document 가 "추가됨" 으로 온다.

그래서 채팅방에 들어가서 listener 를 붙이는 순간, 그동안 쌓인 메시지가 전부 "추가됨" 으로 들어와서 화면이 채워진다. 그 다음부터는 바뀐 것만 온다. 기존 메시지를 불러오는 코드와 새 메시지를 받는 코드를 따로 만들 필요가 없는 이유가 이것이다.

---

### 내가 보낸 메시지가 바로 보이는 이유

내가 보낸 메시지도 내 listener 로 들어온다. 그런데 서버에 저장되고 다시 돌아올 때까지 기다리면 보낼 때마다 잠깐씩 멈칫하게 된다.

Firestore 는 이걸 기기 안의 캐시로 해결한다. `addDocument` 를 부르면 서버에 보내는 것과 동시에 기기 안의 캐시에 먼저 써 두고, 그 순간 내 listener 를 바로 부른다. 서버 응답은 그 뒤에 따로 온다. [실시간 업데이트 Docs](https://firebase.google.com/docs/firestore/query-data/listen){:target="_blank"}에서는 이걸 latency compensation(지연 보정)이라고 부른다.

그래서 우리 코드에서도 메시지를 저장한 뒤에 화면에 직접 추가하지 않는다. 지도 메시지를 보내는 코드에 남겨 둔 주석이 바로 이 얘기다.

```swift
chatFirestoreStream.save(locationMessage) { error in
    // ...
    // 메시지를 추가하지 않음. Firestore의 스냅샷 리스너가 이를 처리함.
}
```

---

## 채팅방 구독 코드

채팅방 하나의 listener 는 `ChatFirestoreStream` 이 관리한다. 채팅 화면(`ChatVC`)은 이 객체에 "이 채팅방을 구독해 줘" 라고 부탁하고, 결과로 메시지 배열을 받는다.

```swift
class ChatFirestoreStream {
    let firestoreDataBase = Firestore.firestore()
    var listener: ListenerRegistration?
    var collectionListener: CollectionReference?
    var blockListener: ListenerRegistration?

    var messages = [Message]()
    var blockSenderSet = Set<String>()

    func subscribe(id: String, myUid: String?, completion: @escaping (Result<[Message], StreamError>) -> Void) {
        let streamPath = "channels/\(id)/thread"

        removeListener()
        collectionListener = firestoreDataBase.collection(streamPath)

        guard let myUid = myUid else {
            // 게스트 사용자의 경우 차단된 사용자 목록을 확인하지 않고 메시지를 구독
            listener = collectionListener?.whereField(db_isActive, isEqualTo: true)
                .addSnapshotListener { snapshot, error in
                    guard let snapshot = snapshot else {
                        completion(.failure(StreamError.firestoreError(error)))
                        return
                    }

                    self.handleDocumentChanges(snapshot.documentChanges) { messages in
                        completion(.success(messages))
                    }
                }
            return
        }

        // ... 로그인 유저는 차단 목록 listener 도 붙인다 (아래에서 설명)
    }
}
```

#### addSnapshotListener로 채팅방 thread 구독하기

1. [`Firestore.firestore()`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/Firestore){:target="_blank"} 로 앱의 Firestore 를 가져오고, `collection(_:)` 에 `"channels/\(id)/thread"` 처럼 경로를 넘겨서 그 채팅방의 메시지 collection 을 가리키는 [`CollectionReference`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/CollectionReference){:target="_blank"} 를 만든다. 이건 주소를 들고 있을 뿐이고, 아직 아무것도 읽지 않는다
2. [`Query`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/Query){:target="_blank"} 의 `whereField(_:isEqualTo:)` 로 `isActive` 가 `true` 인 메시지만 고른다. 신고가 3번 쌓여 `isActive` 가 `false` 가 된 메시지는 처음부터 오지 않는다
3. 같은 `Query` 의 `addSnapshotListener` 로 listener 를 붙인다. 클로저는 처음 한 번, 그리고 조건에 맞는 document 가 바뀔 때마다 계속 불린다. 넘어오는 [`QuerySnapshot`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/QuerySnapshot){:target="_blank"} 은 그 순간의 결과 전체이고, 실패하면 `snapshot` 이 `nil` 이고 `error` 가 온다
4. `addSnapshotListener` 는 [`ListenerRegistration`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Protocols/ListenerRegistration){:target="_blank"} 을 돌려준다. listener 를 끊을 때 쓰는 영수증 같은 것이라 `listener` property 에 보관해 둔다

`subscribe` 를 시작할 때 `removeListener()` 를 먼저 부르는 것은, 혹시 이전 listener 가 남아 있으면 끊고 새로 붙이기 위해서다. listener 두 개가 동시에 살아 있으면 같은 메시지가 두 번씩 들어온다.

---

### 바뀐 것만 골라 처리하기

`QuerySnapshot` 은 결과 전체(`documents`)와 함께, 지난번 결과와 비교해 무엇이 바뀌었는지(`documentChanges`)도 준다. 채팅은 바뀐 것만 보면 되니까 `documentChanges` 를 쓴다.

```swift
private func handleDocumentChanges(_ documentChanges: [DocumentChange], completion: @escaping ([Message]) -> Void) {
    var newMessages = [Message]()

    documentChanges.forEach { change in
        if var message = Message(document: change.document) {
            switch change.type {
            case .added:
                if !blockSenderSet.contains(message.sender.displayName), !messages.contains(where: { $0.id == message.id }) {
                    newMessages.append(message)
                }
            case .modified:
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    if blockSenderSet.contains(message.sender.displayName) {
                        messages.remove(at: index)
                    } else {
                        messages[index] = message
                    }
                } else if !blockSenderSet.contains(message.sender.displayName) {
                    newMessages.append(message)
                }
            case .removed:
                messages.removeAll { $0.id == message.id }
            }
        }
    }

    self.messages += newMessages
    self.messages.sort()

    // ... 사진 메시지는 사진을 받은 뒤에 completion (아래 사진 메시지에서 설명)
}
```

#### DocumentChange로 추가, 수정, 제거 나누기

[`DocumentChange`](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/DocumentChange){:target="_blank"} 는 바뀐 document 하나(`document`)와 어떻게 바뀌었는지(`type`)를 담고 있다. `type` 은 세 가지다.

| type | 언제 오는가 | 이 코드에서 하는 일 |
|------|-------------|---------------------|
| `.added` | 새 document 가 생겼거나, 조건에 새로 맞게 됐을 때. listener 를 처음 붙였을 때의 기존 document 도 전부 이걸로 온다 | 차단한 사람이 아니고 이미 가진 메시지가 아니면 추가 |
| `.modified` | 조건에 맞는 document 의 필드가 바뀌었을 때. 예를 들어 신고 횟수가 1 올랐을 때 | 가진 메시지를 새 내용으로 교체 |
| `.removed` | document 가 지워졌거나, 조건에서 빠지게 됐을 때 | 가진 메시지에서 제거 |

`.removed` 는 document 가 실제로 지워질 때만 오는 게 아니다. 신고가 3번 쌓여 `isActive` 가 `false` 로 바뀌면, 그 메시지는 `whereField(db_isActive, isEqualTo: true)` 조건에서 빠지기 때문에 listener 입장에서는 "결과에서 사라졌다" 로 보여서 `.removed` 가 온다. 그래서 신고로 가려진 메시지가 모든 사람 화면에서 바로 사라진다.

`.added` 에서 `messages.contains` 로 한 번 더 확인하는 것은, 아래의 차단 목록 처리 때문에 같은 메시지가 다른 길로 먼저 들어와 있을 수 있어서다. `Message` 는 `Comparable` 을 따르고 `<` 를 보낸 시각으로 비교하게 해 두어서, `sort()` 를 하면 시간순으로 정렬된다.

---

### 차단 목록도 listener 로 듣기

로그인한 유저는 listener 를 하나 더 붙인다. 내가 차단한 사람 목록(`UserBlock` collection 의 내 document)이 바뀌는지 듣는 listener 다.

```swift
// 차단된 사용자 목록의 변화를 감지
blockListener = blockCollection.document(myUid).addSnapshotListener { [weak self] (snapshot, error) in
    guard let self = self else { return }
    guard let document = snapshot, document.exists, let blockData = document.data(), let blockSenderArray = blockData[db_blockSenderNames] as? [String] else {
        self.blockSenderSet = Set<String>()
        self.reloadMessages(completion: completion)
        return
    }

    self.blockSenderSet = Set(blockSenderArray)
    self.reloadMessages(completion: completion)
}

// 메시지 변화를 감지
listener = collectionListener?.whereField(db_isActive, isEqualTo: true)
    .addSnapshotListener { snapshot, error in
        // ... 게스트와 같음
    }
```

listener 는 collection 뿐 아니라 document 하나에도 붙일 수 있다. 이때는 `QuerySnapshot` 이 아니라 document 하나의 snapshot 이 온다. 차단을 추가하거나 해제해서 배열이 바뀌면, `reloadMessages` 가 메시지를 한 번 읽기(`getDocuments`)로 처음부터 다시 가져와서 차단한 사람 것을 뺀다. 그래서 차단 버튼을 누르면 그 사람의 메시지가 바로 사라지고, 해제하면 바로 다시 보인다. 차단 기능 자체는 [Final (30)](https://haroldfromk.github.io/posts/Final-(30)/)에 정리했다.

---

### 채팅 화면에서 결과 받기

`ChatVC` 는 화면이 로드될 때 구독을 시작하고, 받은 배열로 화면을 갱신한다.

```swift
private func listenToMessages() {
    guard let id = channel.id else {
        navigationController?.popViewController(animated: true)
        return
    }

    let myUid = user?.uid  // 현재 사용자가 있는 경우에만 uid를 전달

    chatFirestoreStream.subscribe(id: id, myUid: myUid) { [weak self] result in
        guard let self = self else { return }
        switch result {
        case .success(let messages):
            self.updateMessages(messages) // Ensure updating messages array
            self.loadImageAndUpdateCells(messages)
            self.preloadProfileImages(for: messages)
        case .failure(let error):
            print(error)
        }
    }
}
```

`updateMessages` 는 받은 배열로 화면의 `messages` 를 바꾸고, 날짜별로 묶은 뒤 다시 그린다. 이 과정은 [Final (31)](https://haroldfromk.github.io/posts/Final-(31)/)에 정리했다. 이 클로저는 메시지가 바뀔 때마다 계속 불린다는 점이 중요하다. 한 번 부르고 끝나는 함수가 아니라, 채팅방에 있는 동안 계속 살아 있는 연결이다.

---

### listener 끊기

listener 는 끊지 않으면 화면을 나가도 계속 살아서 데이터를 받는다. 쓸데없이 읽기 비용이 나가고, 이미 사라진 화면을 갱신하려다 문제가 생길 수도 있다. 그래서 채팅 화면이 메모리에서 사라질 때(`deinit`) 끊는다.

```swift
// ChatVC
deinit {
    chatFirestoreStream.removeListener()
    // ...
}

// ChatFirestoreStream
func removeListener() {
    listener?.remove()
    blockListener?.remove()
}
```

`ListenerRegistration` 의 `remove()` 를 부르면 그 listener 는 더 이상 불리지 않는다. 메시지 listener 와 차단 목록 listener 를 둘 다 끊어야 한다.

---

## 글자 메시지 보내기

보내는 쪽은 훨씬 간단하다. 메시지를 만들어서 `thread` collection 에 document 로 추가하면 끝이다.

```swift
func save(_ message: Message, completion: ((Error?) -> Void)? = nil) {
    collectionListener?.addDocument(data: message.representation) { error in
        completion?(error)
    }
}
```

#### addDocument로 메시지 저장하기

`CollectionReference` 의 `addDocument(data:completion:)` 은 collection 에 새 document 를 만들고 dictionary 를 필드로 저장한다. document id 는 Firestore 가 겹치지 않게 자동으로 만들어 준다. completion 은 서버에 저장이 끝났을 때 불리고, 실패하면 `error` 가 온다. 앞에서 말했듯이 내 listener 는 이 completion 보다 먼저, 기기 캐시에 쓰는 순간 불린다.

전송 버튼을 누르면 닉네임을 확인하고, 지역 제한을 확인한 뒤 저장한다.

```swift
func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    Message.fetchDisplayName(userManager: UserManager()) { [weak self] displayName in
        guard let displayName = displayName, let self = self else {
            // 게스트는 로그인 안내
            return
        }

        if isLocation == false {
            showMessage(title: "안내", message: "타 지역에서는 불가합니다.")
        } else {
            var message: Message
            if let user = self.user {
                message = Message(user: user, content: text, displayName: displayName)
            } else if let customUser = self.customUser {
                message = Message(customUser: customUser, content: text, displayName: displayName)
            } else {
                print("No valid user found")
                return
            }

            self.chatFirestoreStream.save(message) { error in
                if let error = error {
                    print(error)
                    return
                }
                self.messagesCollectionView.scrollToLastItem()
            }
            inputBar.inputTextView.text.removeAll()
        }
    }
}
```

`inputBar(_:didPressSendButtonWith:)` 는 MessageKit 이 쓰는 입력창 라이브러리(InputBarAccessoryView)의 delegate 메서드로, 전송 버튼을 누르면 입력된 글자와 함께 불린다. 이 함수 어디에도 화면에 메시지를 추가하는 코드가 없다는 점을 보면 된다. 저장하면 listener 가 알아서 가져온다.

---

## 사진 메시지 보내기

사진은 글자와 달리 바로 Firestore 에 넣지 않는다. 사진 파일은 Storage 에 올리고, Firestore 에는 그 사진의 주소만 넣는다.

---

### Storage는 왜 따로 쓰는가

Firestore 의 document 하나는 최대 1 MiB 까지만 담을 수 있다([용량 제한 Docs](https://firebase.google.com/docs/firestore/quotas){:target="_blank"}). 폰 사진은 압축해도 그보다 큰 경우가 많고, 무엇보다 Firestore 는 작은 값을 빠르게 찾고 듣는 용도라 큰 파일을 넣기에 맞지 않다.

Firebase Storage 는 반대로 사진, 동영상 같은 큰 파일을 보관하는 창고다. 그래서 파일은 창고에 두고, 메시지에는 "창고 몇 번 선반에 있다" 는 주소만 적는다. 받는 사람은 메시지에서 주소를 보고 창고에 가서 파일을 가져온다.

![보내는 폰이 사진을 Storage 에 올리고 주소를 받아 Firestore 에 주소만 저장하면, 받는 폰은 listener 로 주소를 받아 Storage 에서 사진을 내려받는다](https://pub-1fd8ca6711bd4f3f8b74d88a697b50f9.r2.dev/2024-11-20-Final-Remind2/chat-photo-flow.png)

---

### 사진 고르기

클립 버튼에서 "카메라" 나 "사진" 을 고르면 `UIImagePickerController` 를 띄운다.

```swift
private func didTapLibraryButton() {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = .photoLibrary
    present(picker, animated: true)
}

private func didTapCameraButton() {
    if UIImagePickerController.isSourceTypeAvailable(.camera) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        present(picker, animated: true)
    } else {
        showMessage(title: "권한 설정 오류", message: "카메라를 사용하기 위해 권한을 설정해주세요!", completion: didTapLibraryButton)
    }
}
```

#### UIImagePickerController로 카메라와 앨범 띄우기

[`UIImagePickerController`](https://developer.apple.com/documentation/uikit/uiimagepickercontroller){:target="_blank"} 는 iOS 가 제공하는 사진 선택 화면이다. [`sourceType`](https://developer.apple.com/documentation/uikit/uiimagepickercontroller/sourcetype-swift.property){:target="_blank"} 으로 `.photoLibrary`(앨범)나 `.camera`(카메라 촬영)를 고른다. 시뮬레이터처럼 카메라가 없는 기기도 있어서, `isSourceTypeAvailable(.camera)` 로 쓸 수 있는지 먼저 확인하고 안 되면 앨범으로 보낸다. 사진을 고르거나 취소한 결과는 `delegate` 로 받는다.

```swift
func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    if let image = info[.originalImage] as? UIImage {
        showImageConfirmationAlert(image, picker: picker)
    } else if let asset = info[.phAsset] as? PHAsset {
        let imageSize = CGSize(width: 500, height: 500)
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: imageSize,
                                              contentMode: .aspectFit,
                                              options: nil) { [weak self] image, _ in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                self.showImageConfirmationAlert(image, picker: picker)
            }
        }
    }
}
```

#### didFinishPickingMediaWithInfo로 고른 사진 받기

[`UIImagePickerControllerDelegate`](https://developer.apple.com/documentation/uikit/uiimagepickercontrollerdelegate){:target="_blank"} 의 이 메서드는 사진을 고르면 불리고, `info` dictionary 에 결과가 담겨 온다. [`.originalImage`](https://developer.apple.com/documentation/uikit/uiimagepickercontroller/infokey/originalimage){:target="_blank"} key 에는 고른 사진이 `UIImage` 로 들어 있다.

그게 없으면 `.phAsset` 으로 사진 앨범의 원본 항목(`PHAsset`)을 받아서, [`PHImageManager`](https://developer.apple.com/documentation/photos/phimagemanager){:target="_blank"} 의 [`requestImage(for:targetSize:contentMode:options:resultHandler:)`](https://developer.apple.com/documentation/photos/phimagemanager/requestimage%28for:targetsize:contentmode:options:resulthandler:%29){:target="_blank"} 로 500x500 안에 맞춘 크기의 이미지를 요청한다. 결과 클로저는 메인 스레드가 아닐 수 있어서 Alert 는 `DispatchQueue.main.async` 안에서 띄운다.

어느 쪽이든 바로 보내지 않고 "이 이미지를 업로드하시겠습니까?" Alert 를 한 번 띄운 뒤, 확인을 누르면 `sendPhoto` 를 부른다.

---

### Storage에 올리고 주소 받기

`sendPhoto` 는 먼저 사진을 Storage 에 올린다. 업로드는 `FirebaseStorageManager` 가 한다.

```swift
static func uploadImage(image: UIImage, channel: Channel, progress: ((Double) -> Void)? = nil, completion: @escaping (Result<URL, Error>) -> Void) -> StorageUploadTask? {
    guard let channelId = channel.id,
          let data = image.jpegData(compressionQuality: 0.4) else { // jpg 포맷 사용
        completion(.failure(NSError(domain: "ImageUploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image for upload"])))
        return nil
    }

    let metaData = StorageMetadata()
    metaData.contentType = "image/jpg" // jpg 포맷 사용

    let imageName = UUID().uuidString + String(Date().timeIntervalSince1970)
    let imageReference = Storage.storage().reference().child("\(channelId)/\(imageName)")

    let uploadTask = imageReference.putData(data, metadata: metaData) { metadata, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        imageReference.downloadURL { url, error in
            if let error = error {
                completion(.failure(error))
            } else if let url = url {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: "ImageUploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
            }
        }
    }

    uploadTask.observe(.progress) { snapshot in
        let percentComplete = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
        progress?(percentComplete)
    }

    return uploadTask
}
```

#### putData로 사진을 Storage에 올리기

1. [`jpegData(compressionQuality:)`](https://developer.apple.com/documentation/uikit/uiimage/jpegdata%28compressionquality:%29){:target="_blank"} 로 `UIImage` 를 JPEG 파일 데이터(`Data`)로 바꾼다. 인자는 0 에서 1 사이 화질이고, 0.4 면 원본보다 훨씬 작아진다. 채팅 사진은 작게 보이니까 화질을 많이 낮췄다
2. [`StorageMetadata`](https://firebase.google.com/docs/reference/swift/firebasestorage/api/reference/Classes/StorageMetadata){:target="_blank"} 의 `contentType` 에 파일 종류를 적는다. 브라우저 등에서 이 주소를 열었을 때 이미지로 보이게 하는 정보다
3. 파일 이름은 [`UUID`](https://developer.apple.com/documentation/foundation/uuid){:target="_blank"} 로 만든 고유 문자열에 현재 시각을 붙여서 겹치지 않게 했다. [`Storage`](https://firebase.google.com/docs/reference/swift/firebasestorage/api/reference/Classes/Storage){:target="_blank"} 의 `reference()` 는 창고의 맨 위를 가리키고, `child(_:)` 로 `채널id/파일이름` 경로를 가리키는 [`StorageReference`](https://firebase.google.com/docs/reference/swift/firebasestorage/api/reference/Classes/StorageReference){:target="_blank"} 를 만든다. 채팅방마다 폴더가 나뉜다
4. `putData(_:metadata:completion:)` 로 데이터를 그 경로에 올린다. 올리기가 끝나면 completion 이 불린다
5. 올린 뒤 `downloadURL(completion:)` 로 이 파일을 내려받을 수 있는 `https://` 주소를 받는다. 이 주소가 메시지에 들어간다
6. `putData` 는 [`StorageUploadTask`](https://firebase.google.com/docs/reference/swift/firebasestorage/api/reference/Classes/StorageUploadTask){:target="_blank"} 를 돌려준다. `observe(.progress)` 로 업로드가 몇 % 진행됐는지 받을 수 있다. 진행 막대에 쓰려고 열어 두었는데, 실제로는 print 만 하고 ProgressHUD 로 로딩만 보여줬다

업로드가 끝나면 그 주소를 넣은 메시지를 만들어서, 글자 메시지와 똑같이 `save` 로 저장한다.

```swift
_ = FirebaseStorageManager.uploadImage(image: image, channel: channel, progress: { progress in
    print("Upload progress: \(progress * 100)%")
}, completion: { [weak self] result in
    self?.isSendingPhoto = false
    guard let self = self else { return }

    ProgressHUD.dismiss()

    switch result {
    case .success(let url):
        Message.fetchDisplayName(userManager: UserManager()) { displayName in
            // ... message = Message(user: user, image: image, displayName: displayName)
            message.downloadURL = url
            self.chatFirestoreStream.save(message) { error in
                // ...
            }
        }
    case .failure(let error):
        print("Failed to upload image: \(error)")
        ProgressHUD.dismiss()
    }
})
```

`representation` 은 `downloadURL` 이 있으면 `url` 필드를 넣으니까, Firestore 에는 사진 주소 문자열만 저장된다. `isSendingPhoto` 는 업로드 중에 클립 버튼을 꺼서 두 번 보내지 않게 막는다.

---

### 받는 쪽에서 사진 내려받기

받는 폰의 listener 에는 `url` 만 들어 있는 메시지가 온다. `Message(document:)` 는 이걸 `downloadURL` 에 담고, 아직 `image` 는 비어 있다. 그래서 `handleDocumentChanges` 는 새 메시지 중 `downloadURL` 이 있는 것들의 사진을 먼저 받은 다음에 화면으로 넘긴다.

```swift
let messagesWithImages = newMessages.filter { $0.downloadURL != nil }
let dispatchGroup = DispatchGroup()

messagesWithImages.forEach { message in
    if let url = message.downloadURL {
        dispatchGroup.enter()
        FirebaseStorageManager.downloadImage(url: url) { result in
            switch result {
            case .success(let image):
                if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                    self.messages[index].image = image
                }
            case .failure(let error):
                print("Failed to download image: \(error)")
            }
            dispatchGroup.leave()
        }
    }
}

dispatchGroup.notify(queue: .main) {
    completion(self.messages)
}
```

#### DispatchGroup으로 사진을 다 받은 뒤 넘기기

[`DispatchGroup`](https://developer.apple.com/documentation/dispatch/dispatchgroup){:target="_blank"} 은 여러 비동기 작업을 묶어서 "전부 끝났을 때" 를 알려준다. 사진마다 받기 시작할 때 `enter()`, 끝날 때 성공이든 실패든 `leave()` 를 부르고, `enter` 와 `leave` 의 수가 같아지면 `notify(queue:)` 의 클로저가 그 queue 에서 실행된다. 여기서는 메인 queue 에서 completion 을 불러 화면을 갱신한다. 사진이 하나도 없으면 바로 `notify` 가 실행된다.

실제 다운로드는 캐시를 먼저 확인한다.

```swift
static let cache = ImageCache.default

static func downloadImage(url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
    // 먼저 캐시에서 이미지를 확인
    if let cachedImage = cache.retrieveImageInMemoryCache(forKey: url.absoluteString) {
        completion(.success(cachedImage))
        return
    }

    cache.retrieveImage(forKey: url.absoluteString) { result in
        switch result {
        case .success(let value):
            if let image = value.image {
                completion(.success(image))
                return
            }
        case .failure:
            break
        }

        let reference = Storage.storage().reference(forURL: url.absoluteString)
        let fiftyMegabytes = Int64(2 * 1024 * 1024)

        reference.getData(maxSize: fiftyMegabytes) { data, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let imageData = data, let image = UIImage(data: imageData) else {
                completion(.failure(NSError(domain: "ImageDownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])))
                return
            }

            // 이미지를 캐시에 저장
            cache.store(image, forKey: url.absoluteString)

            completion(.success(image))
        }
    }
}
```

#### ImageCache와 getData로 사진 내려받기

1. Kingfisher 의 [`ImageCache`](https://github.com/onevcat/Kingfisher/blob/master/Sources/Cache/ImageCache.swift){:target="_blank"} 는 받은 이미지를 메모리와 디스크에 보관하는 캐시다. `default` 는 앱 전체가 같이 쓰는 기본 캐시이고, 사진 주소를 key 로 쓴다
2. `retrieveImageInMemoryCache(forKey:)` 는 메모리에서만 찾는다. 바로 결과가 나와서 가장 빠르다
3. 없으면 `retrieveImage(forKey:)` 로 디스크까지 찾는다. 앱을 껐다 켜도 디스크 캐시는 남아 있어서, 전에 본 사진은 다시 받지 않는다
4. 그래도 없으면 `Storage.storage().reference(forURL:)` 로 주소에서 `StorageReference` 를 만들고, `getData(maxSize:completion:)` 로 파일을 `Data` 로 받는다. `maxSize` 보다 큰 파일은 받지 않고 에러를 낸다. 업로드 때 0.4 로 압축하니까 2MB 로 잡았다
5. 받은 `Data` 를 `UIImage(data:)` 로 이미지로 만들고, `store(_:forKey:)` 로 캐시에 넣은 뒤 돌려준다

이렇게 사진을 받아 `image` 가 채워지면, `Message` 의 `kind` 가 사진 메시지로 바뀐다.

```swift
var kind: MessageKind {
    if let image = image {
        let mediaItem = ImageMediaItem(image: image)
        return .photo(mediaItem)
    } else if let location = location {
        let locationItem = Location(location: location)
        return .location(locationItem)
    } else {
        return .text(content)
    }
}
```

#### MessageKind로 말풍선 종류 정하기

MessageKit 은 메시지마다 [`MessageKind`](https://github.com/MessageKit/MessageKit/blob/main/Sources/Models/MessageKind.swift){:target="_blank"} 를 물어보고, 그 값에 따라 다른 말풍선 cell 을 쓴다. `.text` 면 글자 말풍선, `.photo` 면 사진 말풍선, `.location` 이면 지도 말풍선이다. `.photo` 에는 [`MediaItem`](https://github.com/MessageKit/MessageKit/blob/main/Sources/Protocols/MediaItem.swift){:target="_blank"} 을 따르는 값을 넣어야 해서, 이미지와 말풍선 크기(240x240)를 담는 `ImageMediaItem` 을 만들어 두었다.

---

## 지도 메시지 보내기

지도 메시지는 사진보다 간단하다. 위치는 숫자 두 개(위도, 경도)라서 Storage 없이 Firestore 에 바로 들어간다. 지도에서 위치를 고르는 화면은 [Final (24)](https://haroldfromk.github.io/posts/Final-(24)/)에 정리했고, 여기서는 고른 위치가 메시지가 되는 과정만 본다.

```swift
func didSelectLocation(_ location: CLLocationCoordinate2D) {
    guard let user = self.user else {
        print("No valid user found")
        return
    }

    let displayName = currentDisplayName

    let locationMessage = Message(user: user, location: CLLocation(latitude: location.latitude, longitude: location.longitude), displayName: displayName)

    chatFirestoreStream.save(locationMessage) { error in
        if let error = error {
            print(error)
            return
        }
        // 메시지를 추가하지 않음. Firestore의 스냅샷 리스너가 이를 처리함.
    }
}
```

#### CLLocationCoordinate2D를 CLLocation으로 바꿔 저장하기

지도에서 넘어오는 값은 [`CLLocationCoordinate2D`](https://developer.apple.com/documentation/corelocation/cllocationcoordinate2d){:target="_blank"} 로, 위도와 경도만 담은 가벼운 구조체다. `Message` 는 `CLLocation` 으로 들고 있어서 `CLLocation(latitude:longitude:)` 로 바꿔 넣는다. 저장할 때는 `representation` 이 다시 위도, 경도 숫자로 풀어서 `latitude`, `longitude` 필드에 넣는다.

받는 쪽은 `Message(document:)` 가 두 숫자로 `CLLocation` 을 만들고, `kind` 가 `.location` 을 돌려준다. 여기에 넣는 `Location` 은 MessageKit 의 [`LocationItem`](https://github.com/MessageKit/MessageKit/blob/main/Sources/Protocols/LocationItem.swift){:target="_blank"} 을 따르는 구조체로, 위치와 말풍선 크기를 담는다.

```swift
struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize

    init(location: CLLocation) {
        self.location = location
        self.size = CGSize(width: 240, height: 240) // 원하는 지도 크기
    }
}
```

MessageKit 은 `.location` 메시지를 받으면 그 위치를 중심으로 지도 이미지를 만들어서 말풍선에 넣고, 가운데에 핀을 꽂아 준다. 지도를 직접 그리는 코드는 우리 쪽에 없다. 대신 말풍선은 그림일 뿐이라, 눌러서 지도를 움직이거나 확대할 수는 없었다.

---

## 세 가지 메시지 정리

| | 글자 | 사진 | 지도 |
|------|------|------|------|
| Firestore 에 들어가는 것 | `content` | `url` (Storage 주소) | `latitude`, `longitude` |
| 따로 쓰는 곳 | 없음 | Storage 에 jpg 파일 | 없음 |
| 보낼 때 단계 | 저장 | 업로드, 주소 받기, 저장 | 저장 |
| 받을 때 단계 | listener | listener, 다운로드 | listener |
| `MessageKind` | `.text` | `.photo` | `.location` |

결국 세 메시지 모두 마지막 단계는 같다. Firestore 의 `thread` 에 document 를 하나 추가하는 것이고, 그걸 받는 길은 listener 하나뿐이다. 사진만 무거운 파일을 창고에 따로 두고 주소를 주고받는 단계가 앞뒤로 붙는다.

---

## 지금 보면 아쉬운 점

정리하면서 다시 보니 고칠 만한 곳이 보였다.

첫째, 채팅방의 메시지를 전부 구독한다. listener 를 처음 붙이면 조건에 맞는 document 를 전부 보내주기 때문에, 메시지가 수천 개 쌓인 방에 들어가면 그걸 다 받는다. `order(by:)` 와 `limit(toLast:)` 로 최근 50개만 듣고, 위로 스크롤할 때 이전 메시지를 한 번 읽기로 더 가져오는 방식이 맞다.

둘째, 사진을 두 번 받는다. `ChatFirestoreStream.handleDocumentChanges` 가 새 메시지의 사진을 받고, `ChatVC.loadImageAndUpdateCells` 도 받은 메시지 전체의 사진을 다시 받는다. 캐시 덕분에 실제 네트워크는 한 번이지만, 같은 일을 두 곳에서 하고 있다.

셋째, 차단 목록이 바뀌면 `reloadMessages` 가 메시지를 처음부터 다시 읽는다. 이미 가진 메시지에서 차단한 사람 것을 빼기만 해도 되는데, 그러지 않고 서버에서 전체를 다시 가져온다.

넷째, 메시지 목록이 `ChatFirestoreStream.messages` 와 `ChatVC.messages` 두 곳에 있다. 둘 다 고치고 정렬하다 보니, 하나만 바뀌고 하나는 안 바뀌는 순간이 생길 수 있다. 한쪽만 원본으로 두는 게 맞다.

그래도 이번에 정리하면서 "listener 는 한 번 붙여 두면 처음에 전부, 그 뒤로 바뀐 것만 계속 보내준다" 와 "내가 저장한 것도 내 listener 로 바로 돌아온다" 두 가지를 확실히 이해했다. 채팅 코드에 메시지를 화면에 넣는 곳이 listener 하나뿐인 이유가 여기에 있었다.

---

## 참고자료

- [Upload files with Cloud Storage on Apple platforms (Firebase)](https://firebase.google.com/docs/storage/ios/upload-files){:target="_blank"}
- [Download files with Cloud Storage on Apple platforms (Firebase)](https://firebase.google.com/docs/storage/ios/download-files){:target="_blank"}
- [MessageKit (GitHub)](https://github.com/MessageKit/MessageKit){:target="_blank"}
