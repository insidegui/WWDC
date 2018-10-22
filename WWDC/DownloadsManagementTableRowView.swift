//
//  DownloadsManagementTableRowView.swift
//  WWDC
//
//  Created by Allen Humphreys on 10/22/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class DownloadsManagementTableRowView: NSTableRowView {

    var isLastRow: Bool = false {
        didSet {
            guard isLastRow != oldValue else { return }
            setNeedsDisplay(bounds)
        }
    }

    override func drawSeparator(in dirtyRect: NSRect) {
        if isLastRow {
            NSColor.clear.setFill()
            dirtyRect.fill()
        } else {
            super.drawSeparator(in: dirtyRect)
        }
    }
}
