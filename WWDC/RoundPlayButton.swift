//
//  RoundPlayButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ViewUtils

class RoundPlayButton: NSButton {

    override func drawRect(dirtyRect: NSRect) {
        
        let bezel = NSBezierPath(ovalInRect: NSInsetRect(bounds, 1.0, 1.0))
        bezel.lineWidth = 1.0
        
        if highlighted {
            Theme.WWDCTheme.fillColor.darkerColor.set()
        } else {
            Theme.WWDCTheme.fillColor.set()
        }
        
        bezel.stroke()
        
        let playImage = NSImage(named: "play")!
        let playMask = playImage.CGImage
        let ctx = NSGraphicsContext.currentContext()?.CGContext
        
        let multiplier = CGFloat(0.8)
        let imageWidth = playImage.size.width*multiplier
        let imageHeight = playImage.size.height*multiplier
        let glyphRect = NSMakeRect(floor(bounds.size.width/2-imageWidth/2)+2.0, floor(bounds.size.height/2-imageHeight/2)+1.0, floor(imageWidth), floor(imageHeight))
        CGContextClipToMask(ctx, glyphRect, playMask)
        CGContextFillRect(ctx, bounds)
    }
    
}
