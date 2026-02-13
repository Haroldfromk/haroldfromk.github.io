---
title: TikTok Clone (10)
writer: Harold
date: 2024-05-29 10:13
categories: [Udemy, TikTok]
tags: []

toc: true
toc_sticky: true
---

여기부분은 강의에서도 그냥 타이핑만 하고 파일을 제공해주므로 각 function에 대해서 적어본다.

## VideoComposition Writer 만들기

```swift
func mergeMultipleVideo(urls: [URL], onComplete: @escaping (Bool, URL?) -> Void) {
        var totalDuration = CMTime.zero
        var assets: [AVAsset] = []
        
        for url in urls {
            let asset = AVAsset(url: url)
            assets.append(asset)
            totalDuration = CMTimeAdd(totalDuration, asset.duration)
        }
        
        let outputURL = createOutputUrl(with: urls.first!)
        let mixComposition = merge(arrayVideos: assets)
        handleCreateExportSession(outputURL: outputURL, mixComposition: mixComposition, onComplete: onComplete)
    }
```

1. 에셋 준비
- 각 비디오 URL로부터 AVAsset 객체를 생성하여 assets 배열에 추가한다.
- CMTimeAdd 함수를 사용하여 각 비디오의 지속 시간을 totalDuration에 더한다.
- CMTimeAdd 함수는 두 개의 CMTime 값을 더하는데 사용한다, CMTime은 시간 값을 나타내는 구조체로, 비디오 및 오디오 처리에서 시간 계산에 사용된다.
2. 출력 URL 생성
- createOutputUrl(with:) 함수를 호출하여 첫 번째 비디오 URL을 기반으로 출력 파일의 경로를 생성
3. 비디오 병합
- merge(arrayVideos:) 함수를 호출하여 여러 비디오 에셋을 하나의 AVMutableComposition 객체로 병합
- 이 함수는 비디오와 오디오 트랙을 추가하고, 각 비디오의 시간 범위를 삽입하여 하나의 구성으로 만든다.
4. 내보내기 세션 처리
- handleCreateExportSession(outputURL:mixComposition:onComplete:) 함수를 호출하여 내보내기 세션을 설정하고 비동기로 내보내기 작업을 수행

```swift
 func handleCreateExportSession(outputURL: URL, mixComposition: AVMutableComposition, onComplete: @escaping (Bool, URL?) -> Void) {
        exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = outputURL
        exportSession?.shouldOptimizeForNetworkUse = true
        exportSession?.outputFileType = AVFileType.mp4
        
        var exportProgressBarTimer = Timer()
        guard let exportSessionUnwrapped = exportSession else { 
            exportProgressBarTimer.invalidate()
            return
        }
        
        exportProgressBarTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { timer in
            let progress = Float((exportSessionUnwrapped.progress))
            let dict: [String: Float] = ["progress": progress]
            // NotificationCenter.default.post(name: .updateProgress, object: nil, userInfo: dict)
        })
        
        exportSession.exportAsynchronously {
            exportProgressBarTimer.invalidate()
            switch exportSession.status {
            case .completed:
                DispatchQueue.main.async {
                    let dict: [String: Float] = ["progress": 1.0]
                    // NotificationCenter.default.post(name: .updateProgress, object: nil, userInfo: dict)
                    onComplete(true, exportSession.outputURL)
                }
            case .failed:
                print("Failed \(exportSession.error.debugDescription)")
                onComplete(false, nil)
            case .cancelled:
                print("Cancelled \(exportSession.error.debugDescription)")
                onComplete(false, nil)
            default:
                break
            }
        }
    }
```

1. 내보내기 세션 초기화 및 설정
- AVAssetExportSession 객체를 AVAssetExportPresetHighestQuality 프리셋으로 초기화
- outputURL을 내보내기 세션의 출력 URL로 설정
- shouldOptimizeForNetworkUse를 true로 설정하여 네트워크 사용을 최적화
- outputFileType을 AVFileType.mp4로 설정
2. 진행 상황 모니터링
- Timer 객체를 사용하여 0.1초마다 내보내기 진행 상황을 체크
- 진행 상황을 progress 변수로 저장하고, 필요 시 알림(NotificationCenter)을 통해 업데이트를 전송할 수 있다.
- 타이머는 exportProgressBarTimer에 저장되며, 내보내기 세션이 종료되면 타이머를 무효화
3. 비동기 내보내기
- exportAsynchronously 메서드를 호출하여 비동기로 내보내기 작업을 시작
- 내보내기 작업이 완료되면 exportSession.status를 확인하여 완료, 실패, 취소 등의 상태에 따라 처리
- 내보내기 작업이 성공적으로 완료되면, 완료 핸들러(onComplete)를 호출하여 true와 출력 URL을 전달
- 실패하거나 취소된 경우, 오류 메시지를 출력하고 완료 핸들러를 호출하여 false와 nil을 전달

```swift
func createOutputUrl(with videoUrl: URL) -> URL {
        let fileManager = FileManager.default
        let documentDirectory = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
        
        var outputUrl = documentDirectory.appendingPathComponent("output")
        do {
            try fileManager.createDirectory(at: outputUrl, withIntermediateDirectories: true)
            outputUrl = outputUrl.appendingPathComponent("\(videoUrl.lastPathComponent)")
        } catch let error {
            print(error)
        }
        
        return outputUrl
    }
```

1. 임시 디렉토리 경로 가져오기
- NSTemporaryDirectory() 함수를 사용하여 임시 디렉토리 경로를 가져온다.
- NSURL.fileURL(withPath:isDirectory:) 함수를 사용하여 임시 디렉토리의 URL 객체를 생성
2. 출력 디렉토리 생성
- documentDirectory URL에 “output” 디렉토리를 추가하여 outputUrl을 생성
- FileManager를 사용하여 해당 디렉토리를 생성, 이미 디렉토리가 있는 경우에도 에러 없이 중첩된 디렉토리를 생성
3. 출력 파일 URL 생성
- videoUrl.lastPathComponent를 사용하여 원본 비디오 파일의 이름을 가져온다
- outputUrl에 파일 이름을 추가하여 최종 출력 파일의 URL을 생성한다.
4. 에러 처리
- 디렉토리 생성 중 에러가 발생하면 에러 메시지를 출력
5. 출력 URL 반환
- 최종 생성된 출력 파일의 URL을 리턴


```swift
func merge(arrayVideos: [AVAsset]) -> AVMutableComposition {
        let mainComposition = AVMutableComposition()
        
        let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAudioTrack = mainComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let frontCameraTransform: CGAffineTransform = CGAffineTransform(scaleX: -1.0, y: 1.0).rotated(by: CGFloat(Double.pi/2))
        let backCameraTransform: CGAffineTransform = CGAffineTransform(rotationAngle: .pi/2)
        
        compositionVideoTrack?.preferredTransform = backCameraTransform
        
        var insertTime = CMTime.zero
        
        for videoAsset in arrayVideos {
            try! compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of:
                                                            videoAsset.tracks(withMediaType: .video)[0], at: insertTime)
            
            if videoAsset.tracks(withMediaType: .audio).count > 0 {
                try! compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .audio)[0], at: insertTime)
            }
            insertTime = CMTimeAdd(insertTime, videoAsset.duration)
        }
        return mainComposition
        
    }
```

1. AVMutableComposition 객체 생성
- AVMutableComposition 객체를 생성하여 비디오 및 오디오 트랙을 추가할 수 있는 구성 객체를 생성
2. 비디오 및 오디오 트랙 추가
- mainComposition에 비디오 및 오디오 트랙을 추가
- compositionVideoTrack과 compositionAudioTrack을 생성
3. 비디오 트랙의 변환 설정
- frontCameraTransform과 backCameraTransform을 정의
- 여기에선 후면 카메라 변환(backCameraTransform)을 비디오 트랙의 기본 변환으로 설정한다.
4. 비디오 및 오디오 트랙 삽입
- insertTime을 초기화
- 각 비디오 에셋을 순회하며 해당 비디오와 오디오 트랙을 구성 객체에 삽입
- CMTimeRangeMake를 사용하여 각 비디오의 전체 시간을 삽입
- 삽입된 각 비디오의 지속 시간을 insertTime에 더하여 다음 비디오의 삽입 시간을 갱신한다.

```swift
func saveVideoTobeUploadedToServerToTempDirectory(sourceURL: URL, completion: ((_ outputUrl: URL) -> Void)? = nil) {

    let fileManager = FileManager.default
    //        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    //
    let documentDirectory = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
    
    let asset = AVAsset(url: sourceURL)
    let length = Float(asset.duration.value) / Float(asset.duration.timescale)
    print("video length: \(length) seconds")
    
    var outputURL = documentDirectory.appendingPathComponent("output")
    do {
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        outputURL = outputURL.appendingPathComponent("\(sourceURL.lastPathComponent).mp4")
    }catch let error {
        print(error)
    }
    
    //Remove existing file
    try? fileManager.removeItem(at: outputURL)
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return }
    exportSession.outputURL = outputURL
    exportSession.outputFileType = AVFileType.mp4
    
    
    exportSession.exportAsynchronously {
        switch exportSession.status {
        case .completed:
            print("exported at \(outputURL)")
            completion?(outputURL)
        case .failed:
            print("failed \(exportSession.error.debugDescription)")
        case .cancelled:
            print("cancelled \(exportSession.error.debugDescription)")
        default: break
        }
    }
}
```

1. 파일 관리자 설정
- FileManager.default를 사용하여 파일 관리자 객체를 가져온다.
2. 임시 디렉토리 경로 설정
- NSTemporaryDirectory() 함수를 사용하여 임시 디렉토리 경로를 가져오고, 이를 기반으로 documentDirectory URL 객체를 생성
3.	AVAsset 객체 생성
- AVAsset(url: sourceURL)을 사용하여 주어진 비디오 URL로부터 AVAsset 객체를 생성
- 비디오의 길이를 계산하여 출력. 비디오 길이는 asset.duration.value와 asset.duration.timescale을 사용하여 계산
4. 출력 디렉토리 및 파일 경로 설정
- outputURL을 생성하여 임시 디렉토리의 “output” 디렉토리에 비디오 파일 이름을 추가
- FileManager를 사용하여 출력 디렉토리를 생성. 중첩된 디렉토리 생성을 허용한다.
- 기존 파일이 존재하면 삭제
5. AVAssetExportSession 설정
- AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)를 사용하여 내보내기 세션을 생성
- 내보내기 세션의 출력 URL과 파일 형식을 설정
6. 비동기 내보내기
- exportAsynchronously 메서드를 호출하여 비동기로 내보내기 작업을 시작
- 내보내기 작업이 완료되면 상태에 따라 결과를 처리
- 내보내기 성공 시 완료 핸들러를 호출하여 출력 URL을 반환
- 실패하거나 취소된 경우, 오류 메시지를 출력하고 완료 핸들러를 호출하여 nil을 반환