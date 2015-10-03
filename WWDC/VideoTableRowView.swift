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
    
    private var shouldDrawAsKey: Bool {
        get {
            if let window = window {
                return window.keyWindow && NSApp.active && window.firstResponder.isEqualTo(self.superview)
            } else {
                return false
            }
        }
    }
    
    private func updateSubviewsInterestedInSelectionState() {
        guard subviews.count > 0 else { return }
        
        if let videoCell = subviews[0] as? VideoTableCellView {
            for subview in videoCell.subviews {
                if let p = subview as? SessionProgressView {
                    p.selected = selected
                }
            }
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
    }
    
    override func drawSeparatorInRect(dirtyRect: NSRect) {
        let bottomRect = NSMakeRect(0, NSHeight(bounds)-1.0, NSWidth(bounds), 1.0)
        let topRect = NSMakeRect(0, 0.0, NSWidth(bounds), 1.0)
        
        if selected {
            if shouldDrawAsKey {
                Theme.WWDCTheme.fillColor.colorByAdjustingBrightnessWithFactor(-0.2).colorWithAlphaComponent(0.8).setFill()
            } else {
                Theme.WWDCTheme.separatorColor.colorByAdjustingBrightnessWithFactor(-0.2).colorWithAlphaComponent(0.8).setFill()
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
            Theme.WWDCTheme.fillColor.colorByAdjustingBrightnessWithFactor(-0.1).colorWithAlphaComponent(0.8).setFill()
        } else {
            Theme.WWDCTheme.separatorColor.colorWithAlphaComponent(0.8).setFill()
        }
        NSRectFillUsingOperation(dirtyRect, .CompositeOverlay)
    }
    
}
