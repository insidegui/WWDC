//
//  SessionStatusView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import QuartzCore

@IBDesignable
class SessionProgressView: NSView {

    @IBInspectable var favorite: Bool = false {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }
    
    @IBInspectable var progress: Double = 0 {
        didSet {
            setNeedsDisplayInRect(bounds)
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        if progress >= 1 {
            drawStarOutlineIfNeeded()
            return
        }
        
        if favorite {
            drawStarBezel()
        } else {
            drawCircularBezel()
        }
        
        NSGraphicsContext.currentContext()?.saveGraphicsState()
        Theme.WWDCTheme.fillColor.set()
        if progress == 0 {
            NSRectFill(bounds)
        } else if progress < 1 {
            NSBezierPath(rect: NSMakeRect(0, 0, round(NSWidth(bounds)/2), NSHeight(bounds))).addClip()
            NSRectFill(bounds)
        }
        NSGraphicsContext.currentContext()?.restoreGraphicsState()
        
        drawStarOutlineIfNeeded()
    }
    
    // MARK: Shape drawing
    
    private var insetBounds: NSRect {
        get {
            return NSInsetRect(bounds, 5.5, 5.5)
        }
    }
    private var insetBoundsForStar: NSRect {
        get {
            return NSInsetRect(bounds, 5, 5)
        }
    }
    
    private func drawCircularBezel() {
        let circle = NSBezierPath(ovalInRect: insetBounds)
        
        Theme.WWDCTheme.backgroundColor.set()
        circle.fill()
        Theme.WWDCTheme.fillColor.set()
        circle.stroke()
        
        circle.addClip()
    }
    
    private func drawStarBezel() {
        let ctx = NSGraphicsContext.currentContext()?.CGContext
        
        // mask the context to the star shape
        let mask = Theme.WWDCTheme.starImage
        CGContextClipToMask(ctx, insetBoundsForStar, mask)
        CGContextSetFillColorWithColor(ctx, Theme.WWDCTheme.backgroundColor.CGColor)
        CGContextFillRect(ctx, insetBoundsForStar)
    }
    
    private func drawStarOutlineIfNeeded() {
        if !favorite {
            return
        }
        
        let ctx = NSGraphicsContext.currentContext()?.CGContext
        
        // get star outline shape
        let outline = Theme.WWDCTheme.starOutlineImage
        
        // draw star outline
        CGContextClipToMask(ctx, insetBoundsForStar, outline)
        CGContextSetFillColorWithColor(ctx, Theme.WWDCTheme.fillColor.CGColor)
        CGContextFillRect(ctx, insetBoundsForStar)
    }
    
}