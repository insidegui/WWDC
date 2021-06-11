//
//  TitleBarButtonsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/06/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxSwift
import Combine
import SwiftUI

final class TitleBarButtonsViewController: NSViewController {
    private let downloadManager: DownloadManager
    private let storage: Storage
    private let disposeBag = DisposeBag()
    private weak var managementViewController: DownloadsManagementViewController?
    
    var handleSharePlayClicked: () -> Void = { }
    
    private var _sharePlayStateHolder: Any?
    
    @available(macOS 12.0, *)
    private var sharePlayViewModel: SharePlayStatusViewModel {
        // swiftlint:disable:next force_cast
        _sharePlayStateHolder as! SharePlayStatusViewModel
    }
    
    private lazy var cancellables = Set<AnyCancellable>()

    init(downloadManager: DownloadManager, storage: Storage) {
        self.downloadManager = downloadManager
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        downloadManager
            .downloadsObservable
            .throttle(.milliseconds(200), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.statusButton.isHidden = $0.isEmpty
            }).disposed(by: disposeBag)
        
        bindSharePlayStateIfSupported()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bindSharePlayStateIfSupported() {
        guard #available(macOS 12.0, *) else { return }
        
        _sharePlayStateHolder = SharePlayStatusViewModel()
        
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

    @objc
    func toggleDownloadsManagementPopover(sender: NSButton) {
        if managementViewController == nil {
            let managementViewController = DownloadsManagementViewController(downloadManager: downloadManager, storage: storage)
            self.managementViewController = managementViewController
            present(managementViewController, asPopoverRelativeTo: sender.bounds, of: sender, preferredEdge: .maxY, behavior: .semitransient)
        } else {
            managementViewController?.dismiss(nil)
        }
    }
}

@available(macOS 12.0, *)
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
