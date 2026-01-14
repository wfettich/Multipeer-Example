//
//  StreamerVC.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import UIKit
import Combine
import MultipeerConnectivity
import AVFoundation

final class StreamerVC: UIViewController {
    
    @IBOutlet private weak var connectionStatusLabel: UILabel!
    @IBOutlet private weak var previewLayerView: UIView!
    @IBOutlet private weak var recordStateLabel: UILabel!
    
    private(set) var captureSession: AVCaptureSession!
    private(set) var previewLayer: AVCaptureVideoPreviewLayer!
    private(set) var movieOutput: AVCaptureMovieFileOutput!
    private(set) var movieFileOutputConnection: AVCaptureConnection?
    private(set) var videoDataOutput: AVCaptureVideoDataOutput!

    private var captureQueue = DispatchQueue(label: "capture-queue")
    private var viewModel: StreamerVM!
    private var disposables = Set<AnyCancellable>()

    // Frame rate limiting
    private var frameCounter = 0
    private let frameSkipCount = 5 // Send every 5th frame (~6 fps if capturing at ~30 fps)
    
    init() {
        super.init(nibName: "StreamerVC", bundle: nil)
        viewModel = StreamerVM(viewController: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Doesn't support Storyboard initializations")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        setupPreviewLayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupBindings() {
        viewModel
            .$connectedPeer
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] value in
                guard let value else {
                    self?.connectionStatusLabel.text = "Not connected"
                    return
                }
                
                self?.connectionStatusLabel.text = "Connected to: \(value.displayName)"
            }).store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordHandler(value)
            }.store(in: &disposables)
        
        viewModel
            .$videoOrientation
            .sink { [weak self] value in
                self?.setVideoOrientation(value)
            }.store(in: &disposables)
    }
    
    private func setupPreviewLayer() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let audioCaptureDevice = AVCaptureDevice.default(for: .audio) else { return }
        let videoInput: AVCaptureDeviceInput
        let audioInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            audioInput = try AVCaptureDeviceInput(device: audioCaptureDevice)
        } catch {
            return
        }

        if captureSession.canAddInput(videoInput),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        } else {
            return
        }

        let mode = viewModel.streamingMode
        print("[StreamerVC] Setting up capture outputs for mode: \(mode.displayName)")

        // Conditionally add movie output based on streaming mode
        if mode == .fileRecording || mode == .hybrid {
            movieOutput = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(movieOutput) {
                captureSession.addOutput(movieOutput)
                movieFileOutputConnection = movieOutput.connection(with: .video)
                print("[StreamerVC] Movie output added for file recording")
            } else {
                print("[StreamerVC] Cannot add movie output")
                return
            }
        } else {
            print("[StreamerVC] Skipping movie output (live streaming mode only)")
        }

        // Conditionally add video data output based on streaming mode
        if mode == .liveStreaming || mode == .hybrid {
            setupDataOutput()
        } else {
            print("[StreamerVC] Skipping video data output (file recording mode only)")
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async { [unowned self] in
            self.previewLayer.frame = self.previewLayerView.bounds
            self.previewLayerView.layer.addSublayer(self.previewLayer)
        }

        previewLayerView.layer.cornerRadius = 10
    }
    
    private func setupDataOutput() {
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            print("[StreamerVC] Video data output added for live streaming")
        } else {
            print("[StreamerVC] Cannot add video data output")
        }

        captureSession.commitConfiguration()
    }
    
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        movieFileOutputConnection?.videoOrientation = orientation
    }
    
    private func recordHandler(_ state: RecordingState) {
        let mode = viewModel.streamingMode

        // Only handle recording states if in file recording or hybrid mode
        guard mode == .fileRecording || mode == .hybrid else {
            recordStateLabel.text = "Live streaming mode - no recording"
            print("[StreamerVC] Ignoring recording state change in live streaming mode")
            return
        }

        if state == .isRecording {
            try? FileManager.default.removeItem(at: viewModel.fileUrl)
            movieOutput.startRecording(to: viewModel.fileUrl,
                                       recordingDelegate: self)
            recordStateLabel.text = "Recording..."
            print("[StreamerVC] Started recording to file")
        } else if state == .finishedRecording {
            movieOutput.stopRecording()
            recordStateLabel.text = "Recording finished!"
            print("[StreamerVC] Stopped recording")
        } else {
            recordStateLabel.text = ""
        }
    }
    
}

extension StreamerVC: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if error == nil {
            viewModel.sendMovieFileToHost()
        }
    }
    
}

extension StreamerVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Only process frames if in live streaming or hybrid mode
        let mode = viewModel.streamingMode
        guard mode == .liveStreaming || mode == .hybrid else {
            return
        }

        // Frame rate limiting - only process every Nth frame
        frameCounter += 1
        guard frameCounter >= frameSkipCount else {
            return
        }
        frameCounter = 0

        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)

        if let imageBuffer {
            CVPixelBufferLockBaseAddress(imageBuffer, [])
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            let bytesPerRow: size_t? = CVPixelBufferGetBytesPerRow(imageBuffer)
            let width: size_t? = CVPixelBufferGetWidth(imageBuffer)
            let height: size_t? = CVPixelBufferGetHeight(imageBuffer)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let newContext = CGContext(data: baseAddress,
                                       width: width ?? 0,
                                       height: height ?? 0,
                                       bitsPerComponent: 8,
                                       bytesPerRow: bytesPerRow ?? 0,
                                       space: colorSpace,
                                       bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

            if let newImage = newContext?.makeImage() {
                // Convert AVCaptureVideoOrientation to UIImage.Orientation
                let imageOrientation = uiImageOrientation(from: viewModel.videoOrientation)

                let image = UIImage(cgImage: newImage,
                                    scale: 1,
                                    orientation: imageOrientation)

                CVPixelBufferUnlockBaseAddress(imageBuffer, [])

                if let data = image.jpegData(compressionQuality: 0.7) {
                    print("[StreamerVC] Frame captured - size: \(data.count) bytes, dimensions: \(width ?? 0)x\(height ?? 0), orientation: \(viewModel.videoOrientation.rawValue)")
                    viewModel.sendVideoStreamImage(using: data)
                } else {
                    print("[StreamerVC] Failed to convert frame to JPEG")
                }
            } else {
                print("[StreamerVC] Failed to create CGImage from pixel buffer")
            }
        } else {
            print("[StreamerVC] Failed to get image buffer from sample buffer")
        }
    }

    // Helper function to convert AVCaptureVideoOrientation to UIImage.Orientation
    private func uiImageOrientation(from videoOrientation: AVCaptureVideoOrientation) -> UIImage.Orientation {
        switch videoOrientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeRight:
            return .up
        case .landscapeLeft:
            return .down
        @unknown default:
            return .right
        }
    }
}
