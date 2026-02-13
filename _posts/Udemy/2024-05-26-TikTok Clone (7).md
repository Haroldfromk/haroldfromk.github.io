---
title: TikTok Clone (7)
writer: Harold
date: 2024-05-26 21:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## 멀티 채널 영상 녹화

우선 VideoClip에 대한 모델링을 하나 해준다.

```swift
import UIKit
import AVKit

struct VideoClips: Equatable {
    
    let videoUrl: URL
    let cameraPosition: AVCaptureDevice.Position
    
    init(videoUrl: URL, cameraPosition: AVCaptureDevice.Position?) {
        self.videoUrl = videoUrl
        self.cameraPosition = cameraPosition ?? .back
    }
    
    static func ==(lhs: VideoClips, rhs:VideoClips) -> Bool {
        return lhs.videoUrl == rhs.videoUrl && lhs.cameraPosition == rhs.cameraPosition
    }
    
}
```

`Equatable`은 비교를 할 수 있는 프로토콜이다.

Equatable 프로토콜을 구현하여 두 VideoClips 객체를 비교할 수 있게 한다.

두 객체의 videoUrl과 cameraPosition이 모두 같을 때만 두 객체가 동일한 것으로 간주!

우선 녹화를 시작하는 메서드를 구현

```swift
func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        let newRecordedClip = VideoClips(videoUrl: fileURL, cameraPosition: currentCameraDevice?.position)
        recordedClips.append(newRecordedClip)
        print("recordedClips", recordedClips.count)
        
    }
```

`AVCaptureFileOutputRecordingDelegate`의 메서드 중 하나이며, 녹화가 시작되면 호출 된다.

새로운 비디오 클립을 생성하고

지금까지 녹화된 모든 비디오 클립을 저장하는 배열인 recordedClips 배열에 추가해준다.

녹화 시작, 중단 함수 구현

```swift
func startRecording() {
        if movieOutput.isRecording == false {
            guard let connection = movieOutput.connection(with: .video) else { return }
            if connection.isVideoOrientationSupported {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
                let device = activeInput.device
                if device.isSmoothAutoFocusSupported {
                    do {
                        try device.lockForConfiguration()
                        device.isSmoothAutoFocusEnabled = false
                        device.unlockForConfiguration()
                    } catch {
                        print("Error setting configuration: \(error.localizedDescription)")
                    }
                }
                outputURL = tempUrl()
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            }
        }
    }
    
    func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
            print("Stop Count")
        }
    }
```

우선 movieOutput을 통해 녹화상태인지를 먼저 확인한다.

그리고 비디오 연결 설정을 해준다.

연결 설정을 통하여 비디오 안정화 및 자동 초점을 설정을 하게 된다.

비디오 안정화 설정: 비디오 연결이 비디오 방향을 지원하는 경우, `preferredVideoStabilizationMode`를 auto로 설정하여 자동 비디오 안정화를 활성화

자동 초점 설정: 현재 활성화된 입력 장치(`activeInput.device`)가 부드러운 자동 초점을 지원하는지 확인

장치가 부드러운 자동 초점을 지원하는 경우, 장치 설정을 잠그고(lockForConfiguration), 부드러운 자동 초점을 비활성화(isSmoothAutoFocusEnabled = false)한 후 설정을 해제(unlockForConfiguration)

이후 tempUrl을 통해 파일을 저장할 임시 url을 생성한다. 

```swift
func tempUrl() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }
        return nil
    }
```

## 영상 녹화 시 버튼 애니메이션 추가

`var isRecording = false`를 하나 만들어준다.

그리고 함수를 하나 만들건데 함수의 위치는 다음과 같다

```swift
func startRecording() {
        if movieOutput.isRecording == false {
            guard let connection = movieOutput.connection(with: .video) else { return }
            if connection.isVideoOrientationSupported {
                connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
                let device = activeInput.device
                if device.isSmoothAutoFocusSupported {
                    do {
                        try device.lockForConfiguration()
                        device.isSmoothAutoFocusEnabled = false
                        device.unlockForConfiguration()
                    } catch {
                        print("Error setting configuration: \(error.localizedDescription)")
                    }
                }
                outputURL = tempUrl()
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                handleAnimateRecordButton() // here
            }
        }
    }

func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
            handleAnimateRecordButton() // added
            print("Stop Count")
        }
    }
```

바로 영상 녹화가 시작될때 트리거된다.

그리고 해당 함수의 코드를 작성한다.

```swift
func handleAnimateRecordButton() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseIn, animations: {
            [weak self] in
            guard let self = self else { return }
            
            if self.isRecording == false {
                self.captureButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                self.cancelButton.layer.cornerRadius = 5
                self.captureButtonRingView.transform = CGAffineTransform(scaleX: 1.7, y: 1.7)
                
                self.saveButton.alpha = 0
                self.discardButton.alpha = 0
                
                [self.flipCameraButton, self.flipCameraLabel, self.speedLabel, self.speedButton, self.beatyLabel, self.beautyButton, self.filtersLabel, self.filtersButton, self.timerLabel, self.timerButton, self.galleryButton, self.effectsButton, self.soundsView, self.timerCounterLabel].forEach { subView in
                    subView?.isHidden = true
                }
            } else {
                self.captureButton.transform = CGAffineTransform.identity
                self.captureButton.layer.cornerRadius = 68/2
                self.captureButtonRingView.transform = CGAffineTransform.identity
                
                self.handleResetAllVisibilityToIdentity()
            }
        }) { [weak self] onComplete in
            guard let self = self else { return }
            self.isRecording = !self.isRecording
        }
    }

func handleResetAllVisibilityToIdentity() {
        
        if recordedClips.isEmpty == true {
            [self.flipCameraButton, self.flipCameraLabel, self.speedLabel, self.speedButton, self.beatyLabel, self.beautyButton, self.filtersLabel, self.filtersButton, self.timerLabel, self.timerButton, self.galleryButton, self.effectsButton, self.soundsView, self.timerCounterLabel].forEach { subView in
                subView?.isHidden = false
            }
            saveButton.alpha = 0
            discardButton.alpha = 0
            print("recordedClips:", "is empty")
        } else {
            [self.flipCameraButton, self.flipCameraLabel, self.speedLabel, self.speedButton, self.beatyLabel, self.beautyButton, self.filtersLabel, self.filtersButton, self.timerLabel, self.timerButton, self.galleryButton, self.effectsButton, self.soundsView, self.timerCounterLabel].forEach { subView in
                subView?.isHidden = true
            }
            saveButton.alpha = 1
            discardButton.alpha = 1
            print("recordedClips:", "is not empty")
        }
        
    }
```

사실 버튼에 관한 애니메이션이다.

`CGAffineTransform` 이건 사이즈를 조절할때 사용한다. 

`self.captureButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)`

이건 캡처버튼을 절반으로 줄이겠다는 의미.

작동 영상.

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6f2c2c73-3fbb-426d-86ce-3c28164c7484" controls="">대체텍스트</video>

## 타이머 생성


```swift
var videoDurationOfLastClip = 0
var recordingTimer: Timer?
var currentMaxRecordingDuration: Int = 15 {
    didSet {
        timerCounterLabel.text = "\(currentMaxRecordingDuration)s"
    }    }    
var total_RecordedTime_In_Secs = 0
var total_RecordedTime_In_Minutes = 0

extension CreatePostViewController {
    
func startTimer() {
        videoDurationOfLastClip = 0
        stopTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
            self?.timerTick()
        })
    }
```


videoDurationOfLastClip: 마지막 클립의 비디오 녹화 시간을 초 단위로 저장

currentMaxRecordingDuration: 최대 녹화 시간을 저장 하고, 이 값이 변경될 때마다 timerCounterLabel에 업데이트된 시간을 표시한다.

StartTimer 함수는

타이머가 실행되고 있다면 중지를 먼저 하고, 새로운 타이머를 0.1초 간격으로 반복적으로 `timerTick` 메서드를 호출한다.

``` swift
func timerTick() {
        total_RecordedTime_In_Secs += 1
        videoDurationOfLastClip += 1
        
        let time_limit = currentMaxRecordingDuration * 10
        if total_RecordedTime_In_Secs == time_limit {
            handleDidTapRecord()
        }
        let countDownSec: Int = Int(currentMaxRecordingDuration) - total_RecordedTime_In_Secs / 10
        timerCounterLabel.text = "\(countDownSec)"
    }
func stopTimer() {
        recordingTimer?.invalidate()
    }
}
```


TimerTick 함수는

total_RecordedTime_In_Secs와 videoDurationOfLastClip을 0.1초 간격으로 1씩 증가시킨다.

이유는 위에있는 타이머가 반복실행 되므로

time_limit을 계산하여 최대 녹화 시간(초 단위로 10배)을 설정

전체 녹화 시간이 time_limit에 도달하면 handleDidTapRecord()를 호출하여 녹화를 중지

남은 시간을 계산하여 timerCounterLabel에 표시한다.


``` swift
func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
            handleAnimateRecordButton()
            stopTimer() // added
            print("Stop Count")
        }
    }

func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        let newRecordedClip = VideoClips(videoUrl: fileURL, cameraPosition: currentCameraDevice?.position)
        recordedClips.append(newRecordedClip)
        print("recordedClips", recordedClips.count)
        startTimer() // added   
    }

```

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/c362c52e-9953-4df0-b8d3-63d3ce6d27c5" controls="">대체텍스트</video>

15초 카운트가 끝나면 자동으로 레코딩이 멈추게 된다.