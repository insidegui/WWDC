//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

enum MainWindowTab: Int {
    case schedule
    case videos
}

extension Notification.Name {
    static let MainWindowWantsToSelectSearchField = Notification.Name("MainWindowWantsToSelectSearchField")
}

final class MainWindowController: NSWindowController {
    
    static var defaultRect: NSRect {
        if let screen = NSScreen.main() {
            return screen.visibleFrame.insetBy(dx: 50, dy: 70)
        } else {
            return NSRect(x: 0, y: 0, width: 1200, height: 640)
        }
    }
    
    init() {        
        let mask: NSWindowStyleMask = [.titled, .resizable, .miniaturizable, .closable]
        let window = WWDCWindow(contentRect: MainWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)
        
        super.init(window: window)
        
        window.title = "WWDC"
        
        window.appearance = WWDCAppearance.appearance()
        window.center()
        
        window.titleVisibility = .hidden
        
        window.toolbar = NSToolbar(identifier: "WWDC")
        
        window.identifier = "main"
        window.minSize = NSSize(width: 1060, height: 700)
        
        windowDidLoad()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    @IBAction func performFindPanelAction(_ sender: Any) {
        NotificationCenter.default.post(name: .MainWindowWantsToSelectSearchField, object: nil)
    }

}
