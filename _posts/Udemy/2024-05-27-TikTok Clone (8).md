---
title: TikTok Clone (8)
writer: Harold
date: 2024-05-27 10:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

## ProgressView 추가

```swift
func timerTick() {
        total_RecordedTime_In_Secs += 1
        videoDurationOfLastClip += 1
        
        let time_limit = currentMaxRecordingDuration * 10
        if total_RecordedTime_In_Secs == time_limit {
            handleDidTapRecord()
        }
        // added
        let startTime = 0
        let trimmedTime: Int = Int(currentMaxRecordingDuration) - startTime
        let positiveOrZero = max(total_RecordedTime_In_Secs, 0)
        let progress = Float(positiveOrZero) / Float(trimmedTime) / 10
        segmentedProgressView.setProgress(CGFloat(progress))
        let countDownSec: Int = Int(currentMaxRecordingDuration) - total_RecordedTime_In_Secs / 10
        timerCounterLabel.text = "\(countDownSec)"
    }

func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
            handleAnimateRecordButton()
            stopTimer()
            segmentedProgressView.pauseProgress() // added
            print("Stop Count")
        }
    }
```

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/37514f37-0ef7-4291-9f49-45209c18d30a" controls="">대체텍스트</video>

그리고 stopRecording에 새로 추가를 했는데

저건 멈추면

![CleanShot 2024-05-27 at 22 36 34@2x](https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6de47b61-3c4d-47f0-9f29-d2b6aa79f6df){: width="50%" height="50%"}

이렇게 보인다.

## discard 기능 추가

우선 discard 버튼을 눌렀을때 Alert를 띄우게 구현

```swift
 @IBAction func discardButtonDidTapped(_ sender: Any) {
        let alertVC = UIAlertController(title: "Discard the last Clip?", message: nil, preferredStyle: .alert)
        let discardAction = UIAlertAction(title: "Discard", style: .default) { [weak self] (_) in
            self?.handleDiscardLastRecordedClip()
        }
        let keepAction = UIAlertAction(title: "Keep", style: .cancel) { (_) in
            
        }
        alertVC.addAction(discardAction)
        alertVC.addAction(keepAction)
        present(alertVC, animated: true)
    }
```

그리고 메서드는 다음과 같이 구현

```swift
func handleDiscardLastRecordedClip() {
        print("discard")
        outputURL = nil
        thumbnailImage = nil
        recordedClips.removeLast()
        handleResetAllVisibilityToIdentity()
        handleSetNewOutputURLAndThumbnailImage()
        segmentedProgressView.handleRemoveLastSegment()
        
        if recordedClips.isEmpty == true {
            self.handleResetTimerAndProgressViewToZero()
        } else if recordedClips.isEmpty == false {
            self.handleCalculateDurationLeft()
        }
    }
```

지금 여기는 그냥 기존에 있었던 값들을 nil로 바꾸고 마지막에 있던 클립을 지워준다.

```swift
func handleSetNewOutputURLAndThumbnailImage() {
        outputURL = recordedClips.last?.videoUrl
        let currentUrl: URL? = outputURL
        guard let currentUrlUnwrapped = currentUrl else { return }
        guard let generatedThumbnailImage = generateVideoThumbnail(withfile: currentUrlUnwrapped) else { return }
        if currentCameraDevice?.position == .front {
            thumbnailImage = didTakePicture(generatedThumbnailImage, to: .upMirrored)
        } else {
            thumbnailImage = generatedThumbnailImage
        }   
    }
```

최근 녹화된 url을 가져온다. 그걸 unwrapping을 해주었다.

그 뒤 썸네일 이미지를 생성.

```swift
  func handleResetTimerAndProgressViewToZero() {
        total_RecordedTime_In_Secs = 0
        total_RecordedTime_In_Minutes = 0
        videoDurationOfLastClip = 0
        stopTimer()
        segmentedProgressView.setProgress(0)
        timerCounterLabel.text = "\(currentMaxRecordingDuration)"
        
    }
```

설명 생략.

```swift
func handleCalculateDurationLeft() {
        let timeToDiscard = videoDurationOfLastClip
        let currentCombineTime = total_RecordedTime_In_Secs
        let newVideoDuration = currentCombineTime - timeToDiscard
        total_RecordedTime_In_Secs = newVideoDuration
        let countDownSec: Int = Int(currentMaxRecordingDuration) - total_RecordedTime_In_Secs / 10
        timerCounterLabel.text = "\(countDownSec)"
    }
    
```

timeToDiscard 에 마지막 클립의 길이를 저장하고, currentCombineTime에는 현재까지 녹화된 시간을 저장한다.

newVideoDuration를 통해 현재까지 녹화된 전체 시간을 담는다.

countDownSec 에는 남는 시간을 계산 한다.

<video height="400" width="288" src="https://github.com/Haroldfromk/haroldfromk.github.io/assets/97341336/6c76c8dc-7a37-4c62-9411-655ed47ee0f6" controls="">대체텍스트</video>

discard를 하게되면 다시 리셋이 되는걸 볼 수 있다.

오늘은 컨디션 관리를 위해 여기까지.



