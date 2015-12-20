//
//  TranscriptLineTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptLineTableRowView: NSTableRowView {

    override func drawSelectionInRect(dirtyRect: NSRect) {
        NSColor.whiteColor().setFill()
        NSRectFill(dirtyRect)
    }
    
    override var selected: Bool {
        didSet {
            updateSubviewsInterestedInSelectionState()
        }
    }
    
    private func updateSubviewsInterestedInSelectionState() {
        guard subviews.count > 0 else { return }
        
        if let cell = subviews[0] as? TranscriptLineTableCellView {
            cell.selected = selected
        }
    }
    
}
