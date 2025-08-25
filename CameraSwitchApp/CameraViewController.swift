//
//  CameraViewController.swift
//  CameraSwitchApp
//
//  Created by Emirhan Ipek on 23.07.2025.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {
    // MARK: - AVCapture Properties
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session.queue")
    
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    // MARK: - Asset Writer Properties
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isWriting = false
    private var sessionStarted = false
    
    // MARK: - UI Elements
    private let recordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("● REC", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        return btn
    }()
    
    private let switchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("↺ Switch", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16)
        return btn
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureUI()
        checkPermissionsAndStart()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    // MARK: - Permission & Session Setup
    private func checkPermissionsAndStart() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch (videoStatus, audioStatus) {
        case (.authorized, .authorized):
            setupAndStartSession()
        case (.notDetermined, _):
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.checkPermissionsAndStart()
                    } else {
                        self.showPermissionAlert()
                    }
                }
            }
        case (_, .notDetermined):
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.checkPermissionsAndStart()
                    } else {
                        self.showPermissionAlert()
                    }
                }
            }
        default:
            showPermissionAlert()
        }
    }
    
    private func setupAndStartSession() {
        configureSession()
        configurePreviewLayer()
        sessionQueue.async { self.session.startRunning() }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Permissions Needed",
            message: "Please allow camera and microphone access in Settings → Privacy",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Configuration
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Video input
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let videoDeviceInput = try? AVCaptureDeviceInput(device: backCamera),
           session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoInput = videoDeviceInput
        } else {
            print("❌ Unable to add back camera")
        }
        
        // Audio input (only if microphone permission is granted)
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           let mic = AVCaptureDevice.default(for: .audio),
           let audioDeviceInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioDeviceInput) {
            session.addInput(audioDeviceInput)
            self.audioInput = audioDeviceInput
        }
        
        // Video data output
        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            session.addOutput(videoOutput)
        } else {
            print("❌ Could not add video data output")
        }
        
        // Audio data output
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
           session.canAddOutput(audioOutput) {
            audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            session.addOutput(audioOutput)
        } else {
            print("❌ Could not add audio data output")
        }
        
        session.commitConfiguration()
    }
    
    private func configurePreviewLayer() {
        previewLayer?.removeFromSuperlayer()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.bounds
        updateVideoConnection()
    }
    
    // MARK: - UI Setup
    private func configureUI() {
        [recordButton, switchButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            switchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            switchButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
        ])
        recordButton.addTarget(self, action: #selector(toggleRecord), for: .touchUpInside)
        switchButton.addTarget(self, action: #selector(didTapSwitch), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func toggleRecord() {
        if !isWriting {
            startWritingSession()
            recordButton.setTitle("■ STOP", for: .normal)
        } else {
            finishWritingSession()
            recordButton.setTitle("● REC", for: .normal)
        }
    }
    
    @objc private func didTapSwitch() {
        sessionQueue.async { [weak self] in
            guard let self = self, let current = self.videoInput else { return }
            let newPos: AVCaptureDevice.Position = (current.device.position == .back ? .front : .back)
            if let newDev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPos),
               let newInput = try? AVCaptureDeviceInput(device: newDev) {
                self.session.beginConfiguration()
                self.session.removeInput(current)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoInput = newInput
                } else {
                    self.session.addInput(current)
                }
                self.session.commitConfiguration()
                self.updateVideoConnection()
            }
        }
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
    switch UIDevice.current.orientation {
    case .portrait:
        return .portrait
    case .portraitUpsideDown:
        return .portraitUpsideDown
    case .landscapeLeft:
        return .landscapeRight
    case .landscapeRight:
        return .landscapeLeft
    default:
        return .portrait
    }
}

private func updateVideoConnection() {
    let isFront = (videoInput?.device.position == .front)

    if let connection = videoOutput.connection(with: .video) {
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = isFront
        }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        } else {
            connection.videoOrientation = .portrait
        }
    } else {
        print("❌ videoOutput connection is nil")
    }

    DispatchQueue.main.async {
        guard let conn = self.previewLayer?.connection else {
            print("❌ previewLayer connection is nil")
            return
        }
        conn.automaticallyAdjustsVideoMirroring = false
        if conn.isVideoMirroringSupported {
            conn.isVideoMirrored = isFront
        }
        if conn.isVideoOrientationSupported {
            conn.videoOrientation = self.currentVideoOrientation()
        } else {
            conn.videoOrientation = .portrait
        }
    }
}

private func currentVideoTransform() -> CGAffineTransform {
    if videoInput?.device.position == .front {
        return CGAffineTransform(scaleX: -1, y: 1)
    } else {
        return .identity
    }
}

    // MARK: - Writer Control
private func startWritingSession() {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("mov")

    guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
        print("❌ Could not create AVAssetWriter")
        return
    }
    assetWriter = writer

    updateVideoConnection()

    // Video writer input
    guard let vSettings = videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) else {
        print("❌ Could not get video settings")
        return
    }
    let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
    vInput.expectsMediaDataInRealTime = true
    pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: vInput,
        sourcePixelBufferAttributes: nil
    )
    if writer.canAdd(vInput) {
        writer.add(vInput)
        videoWriterInput = vInput
    } else {
        print("❌ Cannot add video writer input")
    }

    // Audio writer input
    let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    aInput.expectsMediaDataInRealTime = true
    if writer.canAdd(aInput) {
        writer.add(aInput)
        audioWriterInput = aInput
    } else {
        print("❌ Cannot add audio writer input")
    }

    writer.startWriting()
    isWriting = true
    sessionStarted = false
}
    
    private func finishWritingSession() {
        isWriting = false
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        assetWriter?.finishWriting {
            if let url = self.assetWriter?.outputURL {
                DispatchQueue.main.async {
                    UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                }
            }
        }
    }
}

// MARK: - AVCapture Output Delegates
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate,
                                 AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isWriting,
              let writer = assetWriter,
              writer.status == .writing else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if !sessionStarted {
            writer.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }
        
        if output is AVCaptureVideoDataOutput,
           let vInput = videoWriterInput,
           vInput.isReadyForMoreMediaData,
           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: timestamp)
        } else if output is AVCaptureAudioDataOutput,
                  let aInput = audioWriterInput,
                  aInput.isReadyForMoreMediaData {
            aInput.append(sampleBuffer)
        }
    }
}

