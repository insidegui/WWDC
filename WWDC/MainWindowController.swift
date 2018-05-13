//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI

enum MainWindowTab: Int {
    case schedule
    case videos

    func stringValue() -> String {
        var name = ""

        debugPrint(self, separator: "", terminator: "", to: &name)

        return name
    }
}

extension Notification.Name {
    static let MainWindowWantsToSelectSearchField = Notification.Name("MainWindowWantsToSelectSearchField")
}

final class MainWindowController: NSWindowController {

    weak var activePlayerView: PUIPlayerView? {
        didSet {
            touchBar = nil
        }
    }

    static var defaultRect: NSRect {
        return NSScreen.main?.visibleFrame.insetBy(dx: 50, dy: 120) ??
               NSRect(x: 0, y: 0, width: 1200, height: 600)
    }
    public var sidebarInitWidth: CGFloat?

    init() {
        let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .closable]
        let window = WWDCWindow(contentRect: MainWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)

        super.init(window: window)

        window.title = "WWDC"

        window.appearance = WWDCAppearance.appearance()
        window.center()

        window.titleVisibility = .hidden

        window.toolbar = NSToolbar(identifier: NSToolbar.Identifier(rawValue: "WWDC"))

        window.identifier = NSUserInterfaceItemIdentifier(rawValue: "main")
        window.setFrameAutosaveName(NSWindow.FrameAutosaveName(rawValue: "main"))
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

    override func makeTouchBar() -> NSTouchBar? {
        return activePlayerView?.makeTouchBar()
    }

}
