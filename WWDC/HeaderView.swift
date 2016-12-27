//
//  HeaderView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class HeaderView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.white.set()
        NSRectFill(dirtyRect)
    }
    
}
