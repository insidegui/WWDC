//
//  WWDCTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableRowView: NSTableRowView {

    override var isGroupRowStyle: Bool {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if window?.isKeyWindow == false || NSApp.isActive == false {
            super.drawSelection(in: dirtyRect)
        } else {
            NSColor.selection.set()
            dirtyRect.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if isGroupRowStyle {
            NSColor.sectionHeaderBackground.set()
            dirtyRect.fill()
        } else {
            super.drawBackground(in: dirtyRect)
        }
    }

}
