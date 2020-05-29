//
//  WWDCWindowController.swift
//  WWDC
//
//  Created by Allen Humphreys on 18/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class WWDCWindowController: NSWindowController {

    var titleBarViewController = TitleBarViewController()

    override var windowNibName: NSNib.Name? {
        // Triggers `loadWindow` to be called so we can override it
        return NSNib.Name("")
    }

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadWindow() {
        fatalError("loadWindow must be overriden by subclasses")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.titleVisibility = .hidden
        window?.addTitlebarAccessoryViewController(titleBarViewController)
        window?.toolbar = NSToolbar(identifier: "DummyToolbar")
    }
}
