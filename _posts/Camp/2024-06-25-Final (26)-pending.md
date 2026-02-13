---
title: Final (26)
writer: Harold
date: 2024-06-25 01:00
categories: [캠프, TheLast]
tags: []
published: false
toc: true
toc_sticky: true
---

## 신고기능 예외처리


---

### 2. 게스트 유저 메시지 전송 차단

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if let user = Auth.auth().currentUser {
        self.user = user
        self.customUser = nil
    } else {
        self.customUser = CustomUser.shared
        self.user = nil
    }
}
```


viewWillAppear 시점에서 인증 유저와 게스트 유저를 구분해 저장함.  
이후 메시지 전송 등에서 접근 제어에 활용됨.

```swift
func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    if customUser != nil {
        showMessage(title: "알림", message: "게스트는 메시지를 보낼 수 없습니다.")
        return
    }

    // 메시지 전송 처리
}
```


게스트 유저가 메시지를 보내려고 하면 차단됨.  
커뮤니티 내 인증되지 않은 사용자 접근을 막기 위한 처리이다.

---

### 3. 메시지 신고 기능 구현

```swift
override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    if action == #selector(report(_:)) {
        report(indexPath)
    }
}

override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
    return true
}

override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
    return action == #selector(report(_:))
}

@objc func report(_ indexPath: IndexPath) {
    let message = messages[indexPath.section]
    let reportData = ReportUserData(senderId: message.sender.senderId, messageId: message.messageId)
    let vc = ChatReportViewController(reportData: reportData)
    present(vc, animated: true)
}
```


메시지를 길게 누르면 ‘신고’ 메뉴가 노출되며, 해당 메시지 정보를 기반으로 신고 뷰를 띄움.  
사용자 자정 기능을 위한 기본적인 UX 구조다.

---

### 4. 위치 기반 메시지 전송 제한

```swift
func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    if !isLocation {
        showMessage(title: "알림", message: "이 지역에서는 메시지를 보낼 수 없습니다.")
        return
    }

    // 메시지 전송 처리
}
```


현재 위치가 허용되지 않은 경우 메시지 전송을 차단한다.  
물리적인 지역 기반 커뮤니티 기능 구현에 적합하다.

```swift
func presentInputActionSheet() {
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    alert.addAction(UIAlertAction(title: "사진 선택", style: .default, handler: { _ in
        if !self.isLocation {
            self.showMessage(title: "알림", message: "이 지역에서는 사진을 보낼 수 없습니다.")
            return
        }
        self.presentImagePicker()
    }))

    present(alert, animated: true)
}
```


이미지 전송에도 동일한 지역 제한을 적용해 사용자 혼란을 줄인다.  
기능 제한의 일관성을 유지하는 좋은 방식이다.

---

### 5. ChannelVC → ChatVC로 지역 정보 전달 방식

```swift
private var isLocation = false

func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let channel = channels[indexPath.row]
    
    isLocation = (currentAddress == channel.name)

    if let user = currentUser {
        let vc = ChatVC(user: user, channel: channel)
        vc.isLocation = isLocation
        navigationController?.pushViewController(vc, animated: true)
    } else if let guest = customUser {
        let vc = ChatVC(guest: guest, channel: channel)
        vc.isLocation = isLocation
        navigationController?.pushViewController(vc, animated: true)
    }
}
```

기존에는 지역이 일치하지 않으면 입장을 막았지만,  
변경 후에는 `ChatVC`로 `isLocation` 플래그를 넘겨 내부에서 처리하도록 함.  
입장은 자유롭게 허용하고, 이후 기능에서 제어하는 구조다.

---

### 6. 셀 내부에서 신고 호출 연결

```swift
extension MessageCollectionViewCell {
    @objc func report(_ sender: Any?) {
        guard let collectionView = superview as? UICollectionView,
              let indexPath = collectionView.indexPath(for: self) else { return }

        if let vc = collectionView.delegate as? ChatVC {
            vc.report(indexPath)
        }
    }
}
```


셀 내부에서 바로 신고를 호출할 수 있도록 구성.  
셀의 상위 collectionView로부터 indexPath를 가져와서  
적절한 ViewController로 위임 처리함.

---

### 기능 요약표

| 기능 항목 | 설명 | 처리 목적 |
|-----------|------|------------|
| 신고 조건 강화 | '기타' 선택 없으면 텍스트 신고 차단 | UX 실수 방지 |
| 게스트 유저 제한 | customUser 존재 시 전송 차단 | 비인가 사용자 제어 |
| 메시지 신고 기능 | 메시지 롱탭 → 신고 메뉴 노출 | 커뮤니티 자정 기능 강화 |
| 위치 기반 제한 | isLocation에 따라 메시지 및 사진 제한 | 오프라인 기반 UX |
| 입장 구조 개선 | ChannelVC에서 위치 판단, ChatVC 전달 | 테스트 및 접근 유연화 |
| 셀 내 액션 연결 | 셀 확장에서 신고 처리 | 사용자 인터랙션 다양화 |

---

### 결론

인증 여부, 위치 조건, 커뮤니티 관리 기능 등을  
기능별로 분리하고 필요한 곳에서만 제어하도록 설계되었다.  
구조적으로는 자유롭게 접근하면서,  
기능적으로는 정교하게 제한하는 **유연한 커뮤니티 구조**를 완성한 변경이다.

## 리젝으로 인하여 테스트 채널 오픈

```swift
if let user = currentUser {Add commentMore actions
    if channel.name == "테스트" {
        isLocation = true
        viewController = ChatVC(user: user, channel: channel)
        viewController.isLocation = isLocation
    } else {
        viewController = ChatVC(user: user, channel: channel)
        viewController.isLocation = isLocation
    }
}
```

이건 언급안해도 될듯..