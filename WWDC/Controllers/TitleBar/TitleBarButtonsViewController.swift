//
//  TitleBarButtonsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/06/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine
import SwiftUI

final class TitleBarButtonsViewController: NSViewController {
    private let downloadManager: MediaDownloadManager
    private let storage: Storage
    private weak var managementViewController: DownloadsManagementViewController?
    
    var handleSharePlayClicked: () -> Void = { }

    private lazy var sharePlayViewModel = SharePlayStatusViewModel()

    private lazy var cancellables = Set<AnyCancellable>()

    init(downloadManager: MediaDownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        downloadManager
            .$downloads
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.statusButton.isHidden = $0.isEmpty
            }.store(in: &cancellables)
        
        bindSharePlayState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bindSharePlayState() {
        SharePlayManager.shared.$canStartSharePlay.sink { [weak self] available in
            guard let self = self else { return }
            
            DispatchQueue.main.async { self.sharePlayViewModel.state = (available) ? SharePlayManager.shared.state.buttonState : .unavailable }
        }.store(in: &cancellables)
        
        SharePlayManager.shared.$state.sink { [weak self] state in
            guard let self = self else { return }
            
            let available = SharePlayManager.shared.canStartSharePlay
            
            DispatchQueue.main.async { self.sharePlayViewModel.state = (available) ? state.buttonState : .unavailable }
        }.store(in: &cancellables)
    }

    private lazy var statusButton: DownloadsStatusButton = {
        let v = DownloadsStatusButton(target: self, action: #selector(toggleDownloadsManagementPopover))
       
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [statusButton])
        
        v.translatesAutoresizingMaskIntoConstraints = false
        v.orientation = .horizontal
        v.spacing = 8
        
        return v
    }()

    override func loadView() {
        let view = NSView()

        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            statusButton.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1, constant: 0),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        self.view = view
        
        installSharePlayViewIfSupported()
    }
    
    private func installSharePlayViewIfSupported() {
        guard #available(macOS 12.0, *) else { return }
        
        let statusView = SharePlayStatusView { [weak self] in
            self?.handleSharePlayClicked()
        }.environmentObject(sharePlayViewModel)
        
        let hostingView = NSHostingView(rootView: statusView)
        
        stackView.insertArrangedSubview(hostingView, at: 0)
    }

    private var isPresentingDownloadManagementPopover: Bool {
        guard let presentedViewControllers, let managementViewController else { return false }
        return presentedViewControllers.contains(managementViewController)
    }

    @objc
    func toggleDownloadsManagementPopover(sender: NSButton) {
        guard !isPresentingDownloadManagementPopover else {
            managementViewController?.dismiss(nil)
            return
        }

        let controller: DownloadsManagementViewController

        if let managementViewController {
            controller = managementViewController
        } else {
            controller = DownloadsManagementViewController(downloadManager: downloadManager, storage: storage)
            self.managementViewController = controller
        }

        present(controller, asPopoverRelativeTo: sender.bounds, of: sender, preferredEdge: .maxY, behavior: .semitransient)
    }
}

private extension SharePlayManager.State {
    var buttonState: SharePlayState {
        switch self {
        case .idle:
            return .inactive
        case .joining, .starting:
            return .loading
        case .session:
            return .active
        }
    }
}
