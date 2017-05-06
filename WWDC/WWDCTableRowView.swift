//
//  WWDCTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableRowView: NSTableRowView {
    
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.selection.set()
        NSRectFill(dirtyRect)
    }
    
}
