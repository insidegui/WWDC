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
            setNeedsDisplayInRect(bounds)
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        backgroundColor.set()
        NSRectFill(dirtyRect)
    }
    
}
