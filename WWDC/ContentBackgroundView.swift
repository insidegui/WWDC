//
//  ContentBackgroundView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ContentBackgroundView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        Theme.WWDCTheme.backgroundColor.set()
        NSRectFill(dirtyRect)
    }
    
}
