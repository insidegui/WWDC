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
    #if FEATURED_TAB_ENABLED
    case featured
    #endif
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

final class MainWindowController: WWDCWindowController {

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

    override func loadWindow() {
        let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        let window = WWDCWindow(contentRect: MainWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)

        window.title = "WWDC"

        window.center()

        window.identifier = NSUserInterfaceItemIdentifier(rawValue: "main")
        window.setFrameAutosaveName(NSWindow.FrameAutosaveName(rawValue: "main"))
        window.minSize = NSSize(width: 1060, height: 700)

        self.window = window
    }

    @IBAction func performFindPanelAction(_ sender: Any) {
        NotificationCenter.default.post(name: .MainWindowWantsToSelectSearchField, object: nil)
    }

    override func makeTouchBar() -> NSTouchBar? {
        return activePlayerView?.makeTouchBar()
    }

}
