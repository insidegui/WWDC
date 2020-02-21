//
//  DownloadsStatusViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 18/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RxSwift

class DownloadsStatusViewController: NSViewController {

    private let downloadManager: DownloadManager
    private let storage: Storage
    private let disposeBag = DisposeBag()
    private weak var managementViewController: DownloadsManagementViewController?

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var statusButton: DownloadsStatusButton = {
        let v = DownloadsStatusButton(target: self, action: #selector(toggleDownloadsManagementPopover))
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    override func loadView() {
        let view = NSView()

        view.addSubview(statusButton)
        statusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
        statusButton.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: 1, constant: 0).isActive = true
        statusButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        self.view = view
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
