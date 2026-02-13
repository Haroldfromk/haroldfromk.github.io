---
title: TikTok Clone (6)
writer: Harold
date: 2024-05-26 09:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## 게시글 등록 VC 만들기

![CleanShot 2024-05-26 at 16 43 14@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e5de9dfa-86a4-4242-a2ff-3f8b449c5b0a){: width="50%" height="50%"}

스토리보드 디자인은 다음과 같다.

해당 VC의 배경을 검게한이유는 카메라의 화면이 나올 예정이기 때문

```swift
class CreatePostViewController: UIViewController {

    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var captureButtonRingView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func setupView() {
        captureButton.backgroundColor = UIColor(red: 254/255, green: 44/255, blue: 85/255, alpha: 1.0)
        captureButton.layer.cornerRadius = 68/2
        captureButtonRingView.layer.borderColor = UIColor(red: 254/255, green: 44/255, blue: 85/255, alpha: 1.0).cgColor
        captureButtonRingView.layer.borderWidth = 6
        captureButtonRingView.layer.cornerRadius = 85/2
    }
    

}
```

그래서 설정을 다음과 같이한다.

VC LifeCycle을 활용하여, 탭바를 사라지게했다가, 다시 보여지게 한다.

왜냐 다른화면에서는 탭바가 다시 보여야하기 때문.

![simulator_screenshot_212190E8-7B01-43BD-9936-FF646188D698](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/990a0e9d-88d7-4108-adab-57514520731f){: width="50%" height="50%"}

제법 카메라 화면다워보인다.

## 카메라 세션 설정

먼저 `AVFoundation`이걸 임포트 해주고

```swift
let photoFileOutput = AVCapturePhotoOutput()
let captureSession = AVCaptureSession()
```

다음과 같이 인스턴스화 해준다.

1. AVCapturePhotoOutput
    - 스틸 사진촬영과 관련이 있는 캡처 작업흐름을 위한 인터페이스를 제공
2. AVCaptureSession
    - Capture 관련 행동들을 다루며, input device에서 output을 캡쳐할수 있도록 데이터의 흐름을 관리하는 오브젝트
        - Capture의 중심이며, input(카메라, 마이크 등), output(사진, 동영상 파일 등)을 관리함.


```swift
func setupCaptureSession() -> Bool {
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        
        // 1. setup inputs
        if let captureVideoDevice = AVCaptureDevice.default(for: AVMediaType.video),
           let captureAudioDevice = AVCaptureDevice.default(for: AVMediaType.audio) {
            do {
                let inputVideo = try AVCaptureDeviceInput(device: captureVideoDevice)
                let inputAudio = try AVCaptureDeviceInput(device: captureAudioDevice)
                
                if captureSession.canAddInput(inputVideo) {
                    captureSession.addInput(inputVideo)
                }
                
                if captureSession.canAddInput(inputAudio) {
                    captureSession.addInput(inputAudio)
                }
                
            } catch let error {
                print("Could not setup camera input:", error)
                return false
            }
        }
        
        // 2. setup outputs
        if captureSession.canAddOutput(photoFileOutput) {
            captureSession.addOutput(photoFileOutput)
        }
        
        // 3. setup output previwes.
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return true
    }
```

우선 코드는 다음과 같다.

주석에 있듯이 크게 3개의 과정을 포인트로 한다

### 1. 인풋 설정

이건 영상과 오디오를 사용하기 위해 설정을 하는 것이다.

처음에 캡쳐 세션의 프리셋을 high로 하면서 고화질 비디오를 캡쳐하도록 한다.

이후 비디오 및 오디오 입력 장치를 설정하고, `AVCaptureDevice.default(for: AVMediaType.video)`와 `AVCaptureDevice.default(for: AVMediaType.audio)`를 사용하여 기본 비디오 및 오디오 장치를 가져 오도록 한다.

각각의 장치로 AVCaptureDeviceInput을 생성하고 이를 캡처 세션에 추가한다.

`canAddInput` 메서드를 사용하여 입력을 추가할 수 있는지 확인한 후, 가능한 경우 세션에 추가
`canAddOutput` 메서드를 사용하여 출력(movieOutput)을 추가할 수 있는지 확인한 후, 가능한 경우 세션에 추가

물론 이때 여러가지를 인풋으로 받아올 수 있다.

![CleanShot 2024-05-26 at 17 02 57@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e4899bb8-f5cb-44af-9705-c43b462aa277)

그리고 이렇게 다양한 카메라 설정이 가능!

![CleanShot 2024-05-26 at 17 03 25@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/5700cefd-a34c-45b6-9ccb-30783d9d8ff2){: width="50%" height="50%"}

그리고 어떤 형태를 내가 input으로 따올건지 설정도 가능. 여기선 비디오와 오디오를 했다.
![CleanShot 2024-05-26 at 17 04 31@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c1ec4155-e34d-4ab1-8826-27b36dc5cffe){: width="50%" height="50%"}

또한 position을 통해 전, 후면 설정도 가능.

![CleanShot 2024-05-26 at 17 05 42@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/1a5ff9e1-9375-4291-9d6f-eb00b3f6b5dd){: width="50%" height="50%"}

### 2. 아웃풋 설정

`AVCapturePhotoOutput`을 캡처 세션에 추가한다.

지금은 이렇게 심플하게 아웃풋을 인풋과 비슷하게 add로 했지만

여기서도 좀 더 디테일하게 들어갈 수 있다.

![CleanShot 2024-05-26 at 17 08 23@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/e2f65cf0-2918-44fe-b2ba-ab3765cd69c3){: width="50%" height="50%"}

이렇게 코덱 타입이라던가.. 무수히 많으니 나중에 좀 더 알아보기로 하자.

### 3. 미리보기 설정

캡쳐하는 세션으로 부터 받아오고 그걸 띄워주는 레이어를 하나 만들고.

그것의 프레임을 설정한 뒤, 어떻게 채워지게 보일지 설정을 하고, 그걸 view의 서브 뷰 개념식으로 추가를 해준다.

### 4. info.plist 설정

![CleanShot 2024-05-26 at 17 22 23@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/8de83873-beb8-4afb-8351-06e82f7c48f4)

사진으로 퉁.

실행하면 다음과 같다.

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/9098ffa8-9535-4c96-aa0a-235e6afe6ed1" controls="">대체텍스트</video>

이렇게 잘되는걸 확인.

다만 이것 역시도 시뮬레이터에서는 안된다.

시뮬레이터는 카메라가 없기때문

## 카메라 전, 후 변경 설정

```swift
@IBAction func flipButtonDidTapped(_ sender: Any) {
        captureSession.beginConfiguration()
        
        let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput
        let newCameraDevice = currentInput?.device.position == .back ? getDeviceFront(position: .front) : getDeviceBack(position: .back)
        
        let newVideoInput = try? AVCaptureDeviceInput(device: newCameraDevice!)
        
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
        
        if captureSession.inputs.isEmpty {
            captureSession.addInput(newVideoInput!)
        }
        
        captureSession.commitConfiguration()
    }
    
    func getDeviceFront(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    
    func getDeviceBack(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    @IBAction func handleDismiss(_ sender: Any) {
        tabBarController?.selectedIndex = 0
    }
```

세션에 설정 시작을 알리는 `beginConfiguration`을 사용.

현재 카메라의 인풋이 뭔지를 알려주는 currentInput과 flip을 시킬 카메라 newCameraDevice 변수를 만들어준다

newCameraDevice의 경우 삼항연산자를 통해 뒷면이라면 앞면을, 아니라면 뒷면을 보이게한다.

카메라가 바뀌게 되면 새롭게 input값이 바뀌어야 한다.

그리고 기존에 input값을 지워주고, 세션에 새롭게 인풋값을 담아주게 된다.

그리고 나서 세션에는 현재 설정에 대해 적용하는 `commitConfiguration`를 사용한다.

아래 2개의 함수는 카매라 전, 후를 변경하는 함수이다

이걸 통해 위에있는 newCameraDevice에 설정하게 한다.

## 동영상 캡쳐 기능 추가

`let movieOutput = AVCaptureMovieFileOutput()` 이걸 추가해주고 똑같이 

```swift
if captureSession.canAddOutput(movieOutput) {
                    captureSession.addOutput(movieOutput)
                }
```

이것도 포함시킨다

그리고

```swift
if captureSession.canAddInput(inputVideo) {
                    captureSession.addInput(inputVideo)
                    activeInput = inputVideo // added
                }

if captureSession.inputs.isEmpty {
            captureSession.addInput(newVideoInput!)
            activeInput = newVideoInput
        }
```

```swift
var activeInput: AVCaptureDeviceInput!
var outputURL: URL!
var currentCameraDevice: AVCaptureDevice?
var thumbnailImage: UIImage?

extension CreatePostViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) {
        if error != nil {
            print("Error recording moview: \(error?.localizedDescription ?? "")")
        } else {
            let urlOfVideoRecorded = outputURL! as URL
            
            guard let generatedThumbnailImage = generateVideoThumbnail(withfile: urlOfVideoRecorded) else { return }
            
            if currentCameraDevice?.position == .front {
                thumbnailImage = didTakePicture(generatedThumbnailImage, to: .upMirrored)
            } else {
                thumbnailImage = generatedThumbnailImage
            }
            
        }
    }
    
    func didTakePicture(_ picture: UIImage, to orientation: UIImage.Orientation) -> UIImage {
        let flippedImage = UIImage(cgImage: picture.cgImage!, scale: picture.scale, orientation: orientation)
        return flippedImage
    }
    
    func generateVideoThumbnail(withfile videoUrl: URL) -> UIImage? {
        let asset = AVAsset(url: videoUrl)
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cmTime = CMTimeMake(value: 1, timescale: 60)
            let thumbnailCGImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
            return UIImage(cgImage: thumbnailCGImage)
        } catch let error {
            print (error)
        }
        return nil
    }
    
}

```

첫번쨰 함수는 protocol을 채택하면 자동으로 생성되는 메서드인데 녹화 완료를 처리한다.

우선 녹화된 비디오의 url을 가져오고, `generateVideoThumbnail` 함수를 사용해 비디오 썸네일 이미지를 생성한다.

그리고 카메라가 전면일 경우, 이미지를 뒤집는다 즉 좌우 반전처리

orientation을 통해 이미지의 방향을 처리한다.

`generateVideoThumbnail` 은 위에 언급했다시피 비디오 썸네일을 만드는데

우선 녹화된 비디오의 파일주소(url)을 가져온다.

`AVAssetImageGenerator`를 생성하여 비디오에서 썸네일 이미지를 생성할 준비를 하고

`appliesPreferredTrackTransform`을 `true`로 설정하여 비디오의 기본 변환(회전, 비율 등)을 적용한다.

이후 do-catch 블럭을 통해 썸네일을 리턴하게 되는데

`CMTimeMake(value:timescale:)`를 사용하여 비디오의 특정 시간(여기서는 1/60초)을 지정.

`copyCGImage(at:actualTime:)` 메서드를 사용하여 지정된 시간에서 썸네일 이미지를 생성하고,

생성된 썸네일 이미지를 UIImage로 변환하여 리턴시키게 된다.


