//
//  HostVC.swift
//  MultipeerVideo-Assignment
//
//  Created by cleanmac on 16/01/23.
//

import UIKit
import Combine

final class HostVC: UIViewController {
    
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private weak var connectionStatusLabel: UILabel!
    @IBOutlet private weak var seeVideoButton: UIButton!
    @IBOutlet private weak var previewCameraView: UIView!
    @IBOutlet private weak var recordButton: UIButton!
    @IBOutlet private weak var streamImageView: UIImageView!
    
    private var viewModel: HostVM!
    private var disposables = Set<AnyCancellable>()
    
    init() {
        super.init(nibName: "HostVC", bundle: nil)
        viewModel = HostVM(viewController: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Doesn't support Storyboard initializations")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()

        // Verify streamImageView is properly configured
        streamImageView.backgroundColor = .darkGray
        streamImageView.contentMode = .scaleAspectFit
        print("[HostVC] viewDidLoad - streamImageView frame: \(streamImageView.frame), hidden: \(streamImageView.isHidden)")

        // Test with a placeholder image
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            // Create a simple test image to verify the imageView works
            let size = CGSize(width: 100, height: 100)
            let renderer = UIGraphicsImageRenderer(size: size)
            let testImage = renderer.image { context in
                UIColor.systemBlue.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            self.streamImageView.image = testImage
            print("[HostVC] Test image set - imageView should now show blue square")
        }
    }

    func updateStreamImage(_ image: UIImage) {
        print("[HostVC] updateStreamImage called - image size: \(image.size.width)x\(image.size.height)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.streamImageView.image = image
            print("[HostVC] Image updated on main thread - imageView frame: \(self.streamImageView.frame), hidden: \(self.streamImageView.isHidden)")
        }
    }
    
    private func setupBindings() {
        viewModel
            .$connectedPeers
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard !value.isEmpty else {
                    self?.connectionStatusLabel.text = "Not connected"
                    self?.recordButton.isHidden = true
                    return
                }
                
                let peers = String(describing: value.map{ $0.displayName })
                self?.connectionStatusLabel.text = "Connected to: \(peers)"
                self?.recordButton.isHidden = false
            }.store(in: &disposables)
        
        viewModel
            .$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.recordButton.setTitle(value == .isRecording ? "Stop Recording" : "Start Recording", for: .normal)
            }.store(in: &disposables)
    }
    
    @IBAction private func buttonActions(_ sender: UIButton) {
        if sender == connectButton {
            viewModel.showPeerBrowserModal()
        } else if sender == recordButton {
            if viewModel.recordingState != .finishedRecording {
                viewModel.changeRecordingState()
            }
        } else if sender == seeVideoButton {
            viewModel.showVideoResolutionAlert()
        }
    }
    
}
