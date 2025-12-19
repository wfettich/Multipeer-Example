//
//  ModeSelectionVC.swift
//  MultipeerVideo-Assignment
//

import UIKit

final class ModeSelectionVC: UIViewController {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose Mode"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let hostButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Host (Controller)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let streamerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Streamer (Camera)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(hostButton)
        view.addSubview(streamerButton)
        
        hostButton.addTarget(self, action: #selector(hostButtonTapped), for: .touchUpInside)
        streamerButton.addTarget(self, action: #selector(streamerButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            
            hostButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            hostButton.widthAnchor.constraint(equalToConstant: 250),
            hostButton.heightAnchor.constraint(equalToConstant: 60),
            
            streamerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            streamerButton.topAnchor.constraint(equalTo: hostButton.bottomAnchor, constant: 30),
            streamerButton.widthAnchor.constraint(equalToConstant: 250),
            streamerButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func hostButtonTapped() {
        let hostVC = HostVC()
        hostVC.modalPresentationStyle = .fullScreen
        present(hostVC, animated: true)
    }
    
    @objc private func streamerButtonTapped() {
        let streamerVC = StreamerVC()
        streamerVC.modalPresentationStyle = .fullScreen
        present(streamerVC, animated: true)
    }
}
