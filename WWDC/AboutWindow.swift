//
//  AboutWindow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 21/12/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class AboutWindow: NSWindow {

    override var canBecomeMainWindow: Bool {
        return false
    }
    
    override var canBecomeKeyWindow: Bool {
        return false
    }
    
}
