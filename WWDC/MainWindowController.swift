//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI

enum MainWindowTab: Int, CaseIterable, Sendable, WWDCTab {
    case explore
    case schedule
    case videos

    func stringValue() -> String {
        var name = ""

        debugPrint(self, separator: "", terminator: "", to: &name)

        return name
    }

    var hidesWindowTitleBar: Bool { self == .explore }

    var toolbarItemImage: NSImage? {
        switch self {
        case .explore:
            return NSImage(systemSymbolName: "star.square.fill", accessibilityDescription: "Explore")
        case .schedule:
            return NSImage(systemSymbolName: "calendar", accessibilityDescription: "Schedule")
        case .videos:
            return NSImage(systemSymbolName: "play.square.fill", accessibilityDescription: "Videos")
        }
    }
}

extension Notification.Name {
    static let MainWindowWantsToSelectSearchField = Notification.Name("MainWindowWantsToSelectSearchField")
}

final class MainWindowController: NewWWDCWindowController {

    weak var touchBarProvider: NSResponder? {
        didSet {
            touchBar = nil
        }
    }

    static var defaultRect: NSRect {
        return NSScreen.main?.visibleFrame.insetBy(dx: 50, dy: 120) ??
               NSRect(x: 0, y: 0, width: 1200, height: 600)
    }
    public var sidebarInitWidth: CGFloat?
    var searchPopover: NSPopover?

    override func loadWindow() {
        let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        let window = NSWindow(contentRect: MainWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)

        window.title = "WWDC"

        window.center()

        window.identifier = .mainWindow
        window.setFrameAutosaveName("main")
        window.minSize = NSSize(width: 1060, height: 700)

        self.window = window
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        if TahoeFeatureFlag.isLiquidGlassEnabled {
            setupWindowAndToolbar()
        }
    }

    @IBAction func performFindPanelAction(_ sender: Any) {
        NotificationCenter.default.post(name: .MainWindowWantsToSelectSearchField, object: nil)
    }

    override func makeTouchBar() -> NSTouchBar? {
        return touchBarProvider?.makeTouchBar()
    }

}

extension NSUserInterfaceItemIdentifier {

    static let mainWindow = NSUserInterfaceItemIdentifier(rawValue: "main")
}
