//
//  LiveSessionsBannerView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class LiveSessionsBannerView: NSView {

    var title: String? {
        didSet {
            _storedAttributedTitle = nil
            setNeedsDisplayInRect(bounds)
        }
    }
    
    private var _storedAttributedTitle: NSAttributedString?
    private var attributedTitle: NSAttributedString {
        if _storedAttributedTitle == nil {
            let attrs = [
                NSFontAttributeName: NSFont.systemFontOfSize(13.0),
                NSForegroundColorAttributeName: NSColor.whiteColor()
            ]
            _storedAttributedTitle = NSAttributedString(string: title!, attributes: attrs)
        }
        
        return _storedAttributedTitle!
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        Theme.WWDCTheme.liveColor.setFill()
        NSRectFill(dirtyRect)
        
        NSColor(calibratedWhite: 0.0, alpha: 0.8).setFill()
        NSRectFillUsingOperation(NSRect(x: 0.0, y: bounds.height - 1.0, width: bounds.width, height: 1.0), .CompositeOverlay)
        
        guard title != nil else { return }
        
        attributedTitle.drawAtPoint(NSPoint(x: 8.0, y: round(bounds.height / 2.0 - attributedTitle.size().height / 2.0)))
    }
    
}
