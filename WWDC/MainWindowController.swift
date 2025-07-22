//
//  MainWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI

enum MainWindowTab: Int, WWDCTab {
    case explore
    case schedule
    case videos

    func stringValue() -> String {
        var name = ""

        debugPrint(self, separator: "", terminator: "", to: &name)

        return name
    }

    var hidesWindowTitleBar: Bool { self == .explore }
}

extension Notification.Name {
    static let MainWindowWantsToSelectSearchField = Notification.Name("MainWindowWantsToSelectSearchField")
}

final class MainWindowController: WWDCWindowController {

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

    override func loadWindow() {
        let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        let window = WWDCWindow(contentRect: MainWindowController.defaultRect, styleMask: mask, backing: .buffered, defer: false)

        window.title = "WWDC"

        window.center()

        window.identifier = .mainWindow
        window.setFrameAutosaveName("main")
        window.minSize = NSSize(width: 1060, height: 700)

        self.window = window
    }

    @IBAction func performFindPanelAction(_ sender: Any) {
        NotificationCenter.default.post(name: .MainWindowWantsToSelectSearchField, object: nil)
    }

    /// Outlet that attempt to extract the current text selection from the firstResponder (naively only supports NSTextView).
    /// Puts the contents in the find pasteboard and triggers the search field to become first responder.
    ///
    /// This handles the targeted UX which is selecting text in a session description and then hitting `⌘ + E`
    ///
    /// This is attached via Main.storyboard
    @IBAction func useSelectionForFind(_ sender: Any?) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }

        let selectedNSRange = textView.selectedRange()
        let completeString = textView.string

        guard selectedNSRange.length > 0, let selectedRange = Range(selectedNSRange, in: completeString) else { return }

        let selectedString = String(completeString[selectedRange])

        let findPasteboard = NSPasteboard(name: .find)
        findPasteboard.clearContents()
        findPasteboard.setString(selectedString, forType: .string)

        NotificationCenter.default.post(name: .MainWindowWantsToSelectSearchField, object: selectedString)
    }

    override func makeTouchBar() -> NSTouchBar? {
        return touchBarProvider?.makeTouchBar()
    }

}

extension NSUserInterfaceItemIdentifier {

    static let mainWindow = NSUserInterfaceItemIdentifier(rawValue: "main")
}
