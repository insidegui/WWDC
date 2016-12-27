//
//  TranscriptLineTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TranscriptLineTableRowView: NSTableRowView {

    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSRectFill(dirtyRect)
    }
    
    override var isSelected: Bool {
        didSet {
            updateSubviewsInterestedInSelectionState()
        }
    }
    
    fileprivate func updateSubviewsInterestedInSelectionState() {
        guard subviews.count > 0 else { return }
        
        if let cell = subviews[0] as? TranscriptLineTableCellView {
            cell.selected = isSelected
        }
    }
    
}
