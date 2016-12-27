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
    
    let separatorColor = NSColor.gray.withAlphaComponent(0.3)
    let backgroundColor = NSColor.white
    let fillColor = NSColor(calibratedRed: 0, green: 0.49, blue: 1, alpha: 1)
    let liveColor = NSColor(calibratedRed:0.823, green:0.114, blue:0.053, alpha:1)
    
    fileprivate var cachedImages: [String:CGImage] = [:]
    
    fileprivate let starImageName = "star"
    fileprivate let starOutlineImageName = "star-outline"
    
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
    
    fileprivate func getImage(_ name: String) -> CGImage {
        if let image = cachedImages[name] {
            return image
        } else {
            cachedImages[name] = NSImage(named: name)?.CGImage
            return cachedImages[name]!
        }
    }
    
}
