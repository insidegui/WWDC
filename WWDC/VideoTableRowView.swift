//
//  VideoTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/09/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideoTableRowView: NSTableRowView {
    
    override var previousRowSelected: Bool {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    override var nextRowSelected: Bool {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    override var selected: Bool {
        didSet {
            updateSubviewsInterestedInSelectionState()
        }
    }
    
    private var shouldDrawAsKey = true
    
    private func updateSubviewsInterestedInSelectionState() {
        guard subviews.count > 0 else { return }
        
        if let videoCell = subviews[0] as? VideoTableCellView {
            videoCell.selected = selected
            
            for subview in videoCell.subviews {
                if let p = subview as? SessionProgressView {
                    p.selected = selected
                }
            }
        } else if let scheduleCell = subviews[0] as? ScheduledSessionTableCellView {
            scheduleCell.selected = selected
        }
    }
    
    override var allowsVibrancy: Bool {
        return true
    }
    
    override func viewWillMoveToWindow(newWindow: NSWindow?) {
        let nc = NSNotificationCenter.defaultCenter()
        
        nc.removeObserver(self)
        
        super.viewWillMoveToWindow(newWindow)
        
        nc.addObserverForName(NSWindowDidResignKeyNotification, object: newWindow, queue: nil) { _ in
            self.setNeedsDisplayInRect(self.bounds)
        }
        nc.addObserverForName(NSWindowDidBecomeKeyNotification, object: newWindow, queue: nil) { _ in
            self.setNeedsDisplayInRect(self.bounds)
        }
    }
    
    override func addSubview(aView: NSView) {
        super.addSubview(aView)
        
        updateSubviewsInterestedInSelectionState()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        selected = false
        
        themeBackgroundColor = Theme.WWDCTheme.fillColor
        themeSeparatorColor = Theme.WWDCTheme.separatorColor
    }
    
    var themeBackgroundColor = Theme.WWDCTheme.fillColor {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    var themeSeparatorColor = Theme.WWDCTheme.separatorColor {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    override func drawSeparatorInRect(dirtyRect: NSRect) {
        let bottomRect = NSMakeRect(0, NSHeight(bounds)-1.0, NSWidth(bounds), 1.0)
        let topRect = NSMakeRect(0, 0.0, NSWidth(bounds), 1.0)
        
        if selected {
            if shouldDrawAsKey {
                themeBackgroundColor.colorByAdjustingBrightnessWithFactor(-0.2).colorWithAlphaComponent(0.8).setFill()
            } else {
                themeSeparatorColor.colorByAdjustingBrightnessWithFactor(-0.2).colorWithAlphaComponent(0.8).setFill()
            }
            
            NSRectFillUsingOperation(topRect, .CompositeOverlay)
        } else {
            Theme.WWDCTheme.separatorColor.setFill()
        }
        
        if !nextRowSelected {
            NSRectFillUsingOperation(bottomRect, .CompositeOverlay)
        }
    }
    
    override func drawSelectionInRect(dirtyRect: NSRect) {
        if shouldDrawAsKey {
            themeBackgroundColor.colorByAdjustingBrightnessWithFactor(-0.1).colorWithAlphaComponent(0.8).setFill()
        } else {
            themeSeparatorColor.colorWithAlphaComponent(0.8).setFill()
        }
        NSRectFillUsingOperation(dirtyRect, .CompositeOverlay)
    }
    
}
