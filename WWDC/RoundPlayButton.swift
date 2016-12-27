//
//  RoundPlayButton.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCAppKit

class RoundPlayButton: NSButton {

    override func draw(_ dirtyRect: NSRect) {
        
        let bezel = NSBezierPath(ovalIn: NSInsetRect(bounds, 1.0, 1.0))
        bezel.lineWidth = 1.0
        
        if isHighlighted {
            Theme.WWDCTheme.fillColor.darker.set()
        } else {
            Theme.WWDCTheme.fillColor.set()
        }
        
        bezel.stroke()
        
        let playImage = NSImage(named: "play")!
        let playMask = playImage.CGImage
        let ctx = NSGraphicsContext.current()?.cgContext
        
        let multiplier = CGFloat(0.8)
        let imageWidth = playImage.size.width*multiplier
        let imageHeight = playImage.size.height*multiplier
        let glyphRect = NSMakeRect(floor(bounds.size.width/2-imageWidth/2)+2.0, floor(bounds.size.height/2-imageHeight/2)+1.0, floor(imageWidth), floor(imageHeight))
        ctx.clip(to: glyphRect, mask: playMask)
        ctx?.fill(bounds)
    }
    
}
