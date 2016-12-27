//
//  SeparatorView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SeparatorView: NSView {

    var backgroundColor = Theme.WWDCTheme.separatorColor {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        backgroundColor.set()
        NSRectFill(dirtyRect)
    }
    
}
