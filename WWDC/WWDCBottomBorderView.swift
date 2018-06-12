//
//  WWDCBottomBorderView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCBottomBorderView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let borderRect = NSRect(width: bounds.width, height: 0.5)
        NSColor.tertiaryText.withAlphaComponent(0.7).setFill()
        borderRect.fill()
    }

}
