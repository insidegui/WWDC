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
    
}
