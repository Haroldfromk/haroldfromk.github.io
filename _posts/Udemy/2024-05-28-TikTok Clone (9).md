---
title: TikTok Clone (9)
writer: Harold
date: 2024-05-28 10:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## Save 버튼 구현

새로운 VC를 만들고 코드는 다음과 같다

```swift
class PreviewCapturedViewController: UIViewController {
    
    var currentlyPlayingVideoClip: VideoClips
    var recordedClips: [VideoClips]
    var viewWillDenitRestartVideoSession: (() -> Void)?
    
    deinit {
        print("PreviewCaptureVideoVC was deinited")
        (viewWillDenitRestartVideoSession)?()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    init?(coder: NSCoder, recordedClips: [VideoClips]) {
        self.currentlyPlayingVideoClip = recordedClips.first!
        self.recordedClips = recordedClips
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
```

`init?(coder: NSCoder, recordedClips: [VideoClips])`

녹화된 클립 배열을 인수로 받아 현재 재생 중인 클립을 배열의 첫 번째 요소로 설정하고, recordedClips 속성에 할당한다.

deinit을 통해 메모리에서 해제할때 `viewWillDenitRestartVideoSession`클로저를 호출

다시 CreatePostVC로 가서 

```swift
@IBAction func saveButtonDidTapped(_ sender: Any) {
        let previewVC = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: "PreviewCapturedViewController", creator: { coder -> PreviewCapturedViewController? in
            PreviewCapturedViewController(coder: coder, recordedClips: self.recordedClips)
        })
        previewVC.viewWillDenitRestartVideoSession = { [weak self ] in
            guard let self = self else { return }
            if self.setupCaptureSession() {
                DispatchQueue.global(qos: .background).async {
                    self.captureSession.startRunning()
                }
            }
        }
        navigationController?.pushViewController(previewVC, animated: true)
    }
```

버튼과 관련된 기능을 구현

여기서 조금 색다른 점이라면 기본적으로 인스턴스 화를 하는방식과는 다르다.

creator를 사용 했는데, creator 클로저를 통해 PreviewCapturedViewController의 초기화 메서드인 init(coder:recordedClips:)를 호출하면서 인스턴스화 하게 된다.

이후 인스턴스화를 한 상태에서 viewWillDenitRestartVideoSession 의 클로저를 정의

PreviewCapturedViewController가 deinit될 때 호출되는 녀석이다.

captureSession.startRunning()을 호출하여 캡처 세션을 시작한다.

## 비디오 미리보기 구현

우선 previewVC에 uiview, uiimageview를 추가해 주었고,

3개의 변수가 추가되었다.

```swift
var player: AVPlayer = AVPlayer()
var playerLayer: AVPlayerLayer = AVPlayerLayer()
var urlsForVids: [URL] = [] {
        didSet {
            print("outputURLunwrapped:", urlsForVids)
        }
    }
```




```swift
     override func viewDidLoad() {
        super.viewDidLoad()
        
        handleStartPlayingFirstClip()
        hideStatusBar = true
        
        print("\(recordedClips.count)")
        recordedClips.forEach { clip in
            urlsForVids.append(clip.videoUrl)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: animated)
        player.play()
        hideStatusBar = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        navigationController?.setNavigationBarHidden(false, animated: animated)
        player.pause()
    }
```

VC 생명주기를 고려하여 작성이 되었고 뭐 딱히 없다.

```swift
    func handleStartPlayingFirstClip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let firstClip = self.recordedClips.first else { return }
            self.currentlyPlayingVideoClip = firstClip
            self.setupPlayerView(with: firstClip)
        }
    }
```

첫번째 클립에 대해 재생하는 메서드


```swift
    func setupPlayerView(with videoClip: VideoClips) {
        let player = AVPlayer(url: videoClip.videoUrl)
        let playerLayer = AVPlayerLayer(player: player)
        self.player = player
        self.playerLayer = playerLayer
        playerLayer.frame = thumbnailImageView.frame
        self.player = player
        self.playerLayer = playerLayer
        thumbnailImageView.layer.insertSublayer(playerLayer, at: 3)
        player.play()
        NotificationCenter.default.addObserver(self, selector: #selector(avPlayerItemDidPlayToEndTime(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        handleMirrorPlayer(cameraPosition: videoClip.cameraPosition)
    }
```

뭐 여기부분도 크게 언급할건 없을것같고

플레이어와 플레이어레이어를 설정하고, 레이어 프레임에 썸네일 이미지 프레임을 넣어준다.

`thumbnailImageView.layer.insertSublayer(playerLayer, at: 3)`는 4번째 레이어에 추가를 한다는 것.

```swift    
    func removePeriodicTimeobserver() {
        player.replaceCurrentItem(with: nil)
        playerLayer.removeFromSuperlayer()
    }
```

재생중인 플레이어를 초기화.

그리고 레이어를 제거함으로써 비디오 제거


```swift    
    @objc func avPlayerItemDidPlayToEndTime(notification: Notification) {
        if let currentIndex = recordedClips.firstIndex(of: currentlyPlayingVideoClip) {
            let nextIndex = currentIndex + 1
            if nextIndex > recordedClips.count - 1 {
                removePeriodicTimeobserver()
                guard let firstClip = recordedClips.first else { return }
                setupPlayerView(with: firstClip)
                currentlyPlayingVideoClip = firstClip
            } else {
                for (index, clip) in recordedClips.enumerated() {
                    if index == nextIndex {
                        removePeriodicTimeobserver()
                        setupPlayerView(with: clip)
                        currentlyPlayingVideoClip = clip
                    }
                }
            }
        }
            
    }
```

현재 비디오가 재생이 끝났을때 다음 비디오를 재생하게 하는 로직이다.

마지막 비디오 클립 재생이 끝나면 다시 첫번째 영상을 재생하도록 한다.

removePeriodicTimeobserver를 호출하여 이전 클립의 플레이어 설정을 제거하고, setupPlayerView(with:)를 호출하여 새로운 클립을 설정한다.

```swift    
    func handleMirrorPlayer(cameraPosition: AVCaptureDevice.Position) {
        if cameraPosition == .front {
            thumbnailImageView.transform = CGAffineTransform(scaleX: -1, y: -1)
        } else {
            thumbnailImageView.transform = .identity
        }
    }
```

카메라의 전후에 따라 이미지 뷰를 반전시킨다.

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/672828bf-a729-45cd-a026-4815f351bcb2" controls="">대체텍스트</video>

확인 완료.