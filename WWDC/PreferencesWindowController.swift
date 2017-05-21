//
//  PreferencesWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PreferencesWindowController: NSWindowController {

    static var defaultRect: NSRect {
        return NSRect(x: 0, y: 0, width: 460, height: 500)
    }
    
    init() {
        let mask: NSWindowStyleMask = [.titled, .closable]
        let window = WWDCWindow(contentRect: PreferencesWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)
        
        super.init(window: window)
        
        window.title = "Preferences"
        
        window.appearance = WWDCAppearance.appearance()
        window.center()
        
        window.titleVisibility = .hidden
        
        window.toolbar = NSToolbar(identifier: "WWDCPreferences")
        
        window.identifier = "preferences"
        window.minSize = PreferencesWindowController.defaultRect.size
        
        window.animationBehavior = .alertPanel
        
        window.backgroundColor = .auxWindowBackground
        
        windowDidLoad()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }

}
