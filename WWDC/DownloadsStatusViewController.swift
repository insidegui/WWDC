//
//  DownloadsStatusViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 18/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsStatusViewController: NSViewController {

    let downloadManager: DownloadManager

    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var statusButton: DownloadsStatusButton = {
        let v = DownloadsStatusButton(target: self, action: #selector(test))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.sizeToFit()

        return v
    }()

    override func loadView() {
        let view = NSView()

        #if DEBUG
        view.addSubview(statusButton)
        statusButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
        statusButton.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.65, constant: 0).isActive = true
        statusButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        #endif

        self.view = view
    }

    @objc
    func test(sender: NSButton) {
        if presentedViewControllers?.isEmpty == true {
            presentViewController(DownloadsManagementViewController(nibName: nil, bundle: nil), asPopoverRelativeTo: sender.bounds, of: sender, preferredEdge: .maxY, behavior: .semitransient)
        } else {
            presentedViewControllers?.forEach(dismissViewController)
        }
    }
}
