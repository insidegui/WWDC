//
//  DownloadsStatusButton.swift
//  WWDC
//
//  Created by Allen Humphreys on 17/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsStatusButton: NSButton {

    init(target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        setButtonType(.momentaryLight)

        bezelStyle = .texturedRounded
        imageScaling = .scaleProportionallyDown
        image = NSImage(named: "NSTransferDownload")
        self.target = target
        self.action = action
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
