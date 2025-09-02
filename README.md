# CameraSwitchApp

A minimal iOS sample that records video with audio while letting you switch between the front and back cameras during capture. It uses `AVCaptureSession` for live preview and `AVAssetWriter` to write H.264/AAC `.mov` files, automatically saving the result to the Photos library when recording stops.

## Features
- Live camera preview with correct orientation and mirroring
- Toggle recording (start/stop) to capture video + audio
- Switch cameras (front/back) on the fly
- Saves recordings to the Photos library
- Pure UIKit, programmatic UI (no storyboards for the main UI)

## Requirements
- iOS 15.0+ (project settings indicate iOS 15+, Swift 5)
- Xcode 15+ recommended
- A physical iOS device for full functionality (camera/mic)

## Getting Started
1. Open `CameraSwitchApp.xcodeproj` in Xcode.
2. Select a signing team under: Target → Signing & Capabilities.
3. Choose a physical device as the run destination.
4. Build and run.

On first launch, grant camera and microphone permissions. The app will also request permission to add videos to your Photo Library when saving.

## Usage
- Tap "● REC" to start recording.
- Tap "■ STOP" to finish and save the video to Photos.
- Tap "↺ Switch" anytime to toggle between front and back cameras. Preview orientation and mirroring are adjusted accordingly.

## How It Works
- `AVCaptureSession` drives live capture; `AVCaptureVideoPreviewLayer` renders the preview.
- `AVCaptureVideoDataOutput` and `AVCaptureAudioDataOutput` provide sample buffers on a dedicated session queue.
- `AVAssetWriter` with video and audio inputs writes frames in realtime:
  - Starts a writing session at the first sample buffer timestamp.
  - Appends video pixel buffers and audio CMSampleBuffers while recording.
  - Finishes the writing session on stop, then saves the resulting `.mov` to Photos.
- Camera switching is handled by reconfiguring the session inputs and updating the video connection. Mirroring is enabled for the front camera; orientation follows the device orientation.

Key classes/files:
- `CameraViewController.swift`: Core capture, preview, recording, and camera switching logic.
- `SceneDelegate.swift`: Sets `CameraViewController` as the root view controller.
- `Info.plist`: Usage descriptions for Camera, Microphone, and Photo Library Add permissions.

## Permissions
The app requires:
- `NSCameraUsageDescription` (camera access)
- `NSMicrophoneUsageDescription` (audio recording)
- `NSPhotoLibraryAddUsageDescription` (save recordings to Photos)

These are already included in `CameraSwitchApp/Info.plist`.

## Notes & Limitations
- The Simulator does not provide real camera/microphone input; use a device.
- Basic error handling and UI are intentionally minimal for clarity.
- Files are saved to the Photos library; there is no in-app file management UI.

## Possible Improvements
- In-app gallery and share/export options
- Better error handling and user feedback (toasts, states)
- Configurable quality/presets, frame rate, stabilization
- Background recording support and interruption handling
- Optional HEVC (H.265) output and metadata
- Unit/UI tests and CI configuration

