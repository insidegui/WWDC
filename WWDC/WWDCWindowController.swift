//
//  WWDCWindowController.swift
//  WWDC
//
//  Created by Allen Humphreys on 18/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

protocol WWDCWindowControllerObject: NSWindowController {
    var sidebarInitWidth: CGFloat? { get set }
    var titleBarViewController: TitleBarViewController { get }
}

class WWDCWindowController: NSWindowController, WWDCWindowControllerObject {
    public var sidebarInitWidth: CGFloat?
    lazy var titleBarViewController = TitleBarViewController()

    override var windowNibName: NSNib.Name? {
        // Triggers `loadWindow` to be called so we can override it
        return NSNib.Name("")
    }

    init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadWindow() {
        fatalError("loadWindow must be overriden by subclasses")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.addTitlebarAccessoryViewController(titleBarViewController)
    }
}

class NewWWDCWindowController: NSWindowController, WWDCWindowControllerObject {
    public var sidebarInitWidth: CGFloat?
    lazy var titleBarViewController = TitleBarViewController()

    override var windowNibName: NSNib.Name? {
        // Triggers `loadWindow` to be called so we can override it
        return NSNib.Name("")
    }

    init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadWindow() {
        fatalError("loadWindow must be overriden by subclasses")
    }
}
