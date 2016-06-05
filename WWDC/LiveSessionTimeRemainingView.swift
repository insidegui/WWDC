//
//  LiveSessionTimeRemainingView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class LiveSessionTimeRemainingView: NSView {

    var title: String = "" {
        didSet {
            _storedAttributedTitle = nil
            sizeToFit()
            setNeedsDisplayInRect(bounds)
        }
    }
    
    private var _storedAttributedTitle: NSAttributedString?
    private var attributedTitle: NSAttributedString {
        if _storedAttributedTitle == nil {
            let attrs = [
                NSFontAttributeName: NSFont.systemFontOfSize(11.0),
                NSForegroundColorAttributeName: NSColor.whiteColor()
            ]
            _storedAttributedTitle = NSAttributedString(string: title, attributes: attrs)
        }
        
        return _storedAttributedTitle!
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        Theme.WWDCTheme.fillColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4.0, yRadius: 4.0).addClip()
        NSRectFill(dirtyRect)
        
        let titleOrigin = NSPoint(
            x: round(bounds.width / 2.0 - attributedTitle.size().width / 2.0),
            y: round(bounds.height / 2.0 - attributedTitle.size().height / 2.0)
        )
        
        attributedTitle.drawAtPoint(titleOrigin)
    }
    
    override var intrinsicContentSize: NSSize {
        let titleSize = attributedTitle.size()
        return NSSize(width: titleSize.width + 10.0, height: titleSize.height + 4.0)
    }
    
    func sizeToFit() {
        setFrameSize(intrinsicContentSize)
    }
    
}
