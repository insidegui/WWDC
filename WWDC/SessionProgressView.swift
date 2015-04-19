//
//  SessionStatusView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

@IBDesignable
class SessionProgressView: NSView {

    @IBInspectable var progress: Double = 0 {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        if progress >= 1 {
            return
        }
        
        let circle = NSBezierPath(ovalInRect: NSInsetRect(bounds, 5.0, 5.0))
        circle.addClip()
        
        Theme.WWDCTheme.backgroundColor.set()
        NSRectFill(bounds)
        Theme.WWDCTheme.fillColor.set()
        circle.stroke()
        
        if progress == 0 {
            NSRectFill(bounds)
        } else if progress < 1 {
            NSBezierPath(rect: NSMakeRect(0, 0, round(NSWidth(bounds)/2), NSHeight(bounds))).addClip()
            NSRectFill(bounds)
        }
    }
    
}
