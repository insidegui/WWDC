//
//  SeparatorView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SeparatorView: NSView {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        Theme.WWDCTheme.separatorColor.set()
        NSRectFill(dirtyRect)
    }
    
}
