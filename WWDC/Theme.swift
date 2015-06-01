//
//  Theme.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

private let _SharedThemeInstance = Theme()

class Theme: NSObject {

    class var WWDCTheme: Theme {
        return _SharedThemeInstance
    }
    
    let separatorColor = NSColor.grayColor().colorWithAlphaComponent(0.3)
    let backgroundColor = NSColor.whiteColor()
    let fillColor = NSColor(calibratedRed: 0, green: 0.49, blue: 1, alpha: 1)
    
    private var cachedImages: [String:CGImage] = [:]
    
    private let starImageName = "star"
    private let starOutlineImageName = "star-outline"
    
    var starImage: CGImage {
        get {
            return getImage(starImageName)
        }
    }
    var starOutlineImage: CGImage {
        get {
            return getImage(starOutlineImageName)
        }
    }
    
    private func getImage(name: String) -> CGImage {
        if let image = cachedImages[name] {
            return image
        } else {
            cachedImages[name] = NSImage(named: name)?.CGImage
            return cachedImages[name]!
        }
    }
    
}

private extension NSImage {
    var CGImage: CGImageRef {
        get {
            var rect = NSMakeRect(0, 0, self.size.width, self.size.height)
            
            var iref = self.CGImageForProposedRect(&rect, context: nil, hints: nil)
            
            return iref!.takeRetainedValue()
        }
    }
}