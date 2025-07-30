//
//  PreferencesWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PreferencesWindowController: WWDCWindowController {

    static var defaultRect: NSRect {
        return NSRect(x: 0, y: 0, width: 650, height: 500)
    }

    override func loadWindow() {
        let mask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let window = WWDCWindow(contentRect: PreferencesWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)

        window.title = "Preferences"

        window.center()

        window.identifier = NSUserInterfaceItemIdentifier(rawValue: "preferences")
        window.minSize = PreferencesWindowController.defaultRect.size

        window.animationBehavior = .alertPanel

        window.backgroundColor = .auxWindowBackground

        self.window = window
    }

}
