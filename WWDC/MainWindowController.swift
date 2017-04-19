//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class MainWindowController: NSWindowController {

    init() {
        let rect: NSRect
        
        if let screen = NSScreen.main() {
            rect = screen.visibleFrame.insetBy(dx: 50, dy: 70)
        } else {
            rect = NSRect(x: 0, y: 0, width: 1200, height: 640)
        }
        
        let mask: NSWindowStyleMask = [.titled, .resizable, .miniaturizable, .closable]
        let window = NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
        
        super.init(window: window)
        
        window.appearance = WWDCAppearance.appearance()
        window.center()
        
        windowDidLoad()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }

}
