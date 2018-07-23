//
//  DownloadsManagementViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 3/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsManagementViewController: NSViewController {

    private lazy var summaryLabel: VibrantTextField = {
        let l = VibrantTextField(labelWithString: "Downloads")
        l.font = .systemFont(ofSize: 50)
        l.textColor = .secondaryLabelColor
        l.isSelectable = true
        l.translatesAutoresizingMaskIntoConstraints = false

        return l
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        view.addSubview(summaryLabel)

        view.topAnchor.constraint(equalTo: summaryLabel.topAnchor, constant: -20).isActive = true
        view.centerXAnchor.constraint(equalTo: summaryLabel.centerXAnchor).isActive = true
    }
}

extension DownloadsManagementViewController: NSPopoverDelegate {

    func popoverShouldDetach(_ popover: NSPopover) -> Bool {

        return true
    }
}
