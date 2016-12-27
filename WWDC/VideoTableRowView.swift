//
//  VideoTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoTableRowView: NSTableRowView {
    
    override var isPreviousRowSelected: Bool {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override var isNextRowSelected: Bool {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override var isSelected: Bool {
        didSet {
            updateSubviewsInterestedInSelectionState()
        }
    }
    
    fileprivate var shouldDrawAsKey = true
    
    fileprivate func updateSubviewsInterestedInSelectionState() {
        guard subviews.count > 0 else { return }
        
        if let videoCell = subviews[0] as? VideoTableCellView {
            videoCell.selected = isSelected
            
            for subview in videoCell.subviews {
                if let p = subview as? SessionProgressView {
                    p.selected = isSelected
                }
            }
        } else if let scheduleCell = subviews[0] as? ScheduledSessionTableCellView {
            scheduleCell.selected = isSelected
        }
    }
    
    override var allowsVibrancy: Bool {
        return true
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        let nc = NotificationCenter.default
        
        nc.removeObserver(self)
        
        super.viewWillMove(toWindow: newWindow)
        
        nc.addObserver(forName: NSNotification.Name.NSWindowDidResignKey, object: newWindow, queue: nil) { _ in
            self.setNeedsDisplay(self.bounds)
        }
        nc.addObserver(forName: NSNotification.Name.NSWindowDidBecomeKey, object: newWindow, queue: nil) { _ in
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    override func addSubview(_ aView: NSView) {
        super.addSubview(aView)
        
        updateSubviewsInterestedInSelectionState()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        isSelected = false
        
        themeBackgroundColor = Theme.WWDCTheme.fillColor
        themeSeparatorColor = Theme.WWDCTheme.separatorColor
    }
    
    var themeBackgroundColor = Theme.WWDCTheme.fillColor {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    var themeSeparatorColor = Theme.WWDCTheme.separatorColor {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override func drawSeparator(in dirtyRect: NSRect) {
        let bottomRect = NSMakeRect(0, NSHeight(bounds)-1.0, NSWidth(bounds), 1.0)
        let topRect = NSMakeRect(0, 0.0, NSWidth(bounds), 1.0)
        
        if isSelected {
            if shouldDrawAsKey {
                themeBackgroundColor.adjustingBrightness(withFactor: -0.2).withAlphaComponent(0.8).setFill()
            } else {
                themeSeparatorColor.adjustingBrightness(withFactor: -0.2).withAlphaComponent(0.8).setFill()
            }
            
            NSRectFillUsingOperation(topRect, .overlay)
        } else {
            Theme.WWDCTheme.separatorColor.setFill()
        }
        
        if !isNextRowSelected {
            NSRectFillUsingOperation(bottomRect, .overlay)
        }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if shouldDrawAsKey {
            themeBackgroundColor.adjustingBrightness(withFactor: -0.1).withAlphaComponent(0.8).setFill()
        } else {
            themeSeparatorColor.withAlphaComponent(0.8).setFill()
        }
        NSRectFillUsingOperation(dirtyRect, .overlay)
    }
    
}
