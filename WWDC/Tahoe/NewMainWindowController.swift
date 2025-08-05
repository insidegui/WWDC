//
//  NewMainWindowController.swift
//  WWDC
//
//  Created by luca on 30.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine

@available(macOS 26.0, *)
final class NewMainWindowController: NewWWDCWindowController {
    weak var touchBarProvider: NSResponder? {
        didSet {
            touchBar = nil
        }
    }

    static var defaultRect: NSRect {
        return NSScreen.main?.visibleFrame.insetBy(dx: 50, dy: 120) ??
            NSRect(x: 0, y: 0, width: 1200, height: 600)
    }

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
        setupWindowAndToolbar()
    }

    @objc func performFindPanelAction(_ sender: Any) {
        guard let searchItem = window?.toolbar?.items.first(where: { $0.itemIdentifier == .searchItem }) as? NSSearchToolbarItem else {
            return
        }
        searchItem.beginSearchInteraction()
    }

    override func makeTouchBar() -> NSTouchBar? {
        return touchBarProvider?.makeTouchBar()
    }
}

@available(macOS 26.0, *)
extension NewMainWindowController: NSToolbarDelegate {
    private func setupWindowAndToolbar(tab: MainWindowTab = .explore) {
        guard let window else {
            return
        }
        window.styleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        window.isMovableByWindowBackground = false
        window.titleVisibility = .hidden
        let toolbar = NSToolbar(identifier: "LiquidToolbar-\(tab.rawValue)")

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsDisplayModeCustomization = false
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [.tabSelectionItem]
        window.toolbar = toolbar
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.autovalidates = false
        switch itemIdentifier {
        case .searchItem:
            let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
            item.resignsFirstResponderWithCancel = true
            return item
        case .filterItem:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "Filter")
            item.showsIndicator = false
            item.menu.addItem(withTitle: "Action 1", action: nil, keyEquivalent: "")
            item.toolTip = "Filter"
            return item
        case .tabSelectionItem:
            let segmentControl = NSSegmentedControl()
            segmentControl.segmentCount = MainWindowTab.allCases.count
            segmentControl.trackingMode = .selectOne
            for (idx, tab) in MainWindowTab.allCases.enumerated() {
                let image = tab.toolbarItemImage
                segmentControl.setImage(image, forSegment: idx)
                segmentControl.setLabel(image?.accessibilityDescription ?? "", forSegment: idx)
            }
            segmentControl.target = self
            segmentControl.action = #selector(selectTabControl)
            segmentControl.selectedSegment = coordinator?.activeTab.rawValue ?? 0
            toolbarItem.view = segmentControl
            toolbarItem.title = "Explore|Schedule|Videos"
        case .downloadItem:
            toolbarItem.image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Dowloads")
            toolbarItem.toolTip = "Downloads"
            toolbarItem.target = self
            toolbarItem.action = #selector(toggleDownloadPanel)
        default:
            break // won't go here since all allowed custom items are handled above
        }
        return toolbarItem
    }

    func toolbar(_ toolbar: NSToolbar, itemIdentifier: NSToolbarItem.Identifier, canBeInsertedAt index: Int) -> Bool {
        return true
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            .filterItem,
            .sidebarTrackingSeparator,
            .tabSelectionItem,
            .downloadItem,
            .flexibleSpace,
            .searchItem
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}

@available(macOS 26.0, *)
private extension NewMainWindowController {
    @objc func toggleDownloadPanel(_ item: NSToolbarItem) {}

    @objc func selectTabControl(_ control: NSSegmentedControl) {
        if let tab = MainWindowTab(rawValue: control.selectedSegment) {
            coordinator?.tabController.setActiveTab(tab)
        }
    }
}

@available(macOS 26.0, *)
private extension NewMainWindowController {
    var coordinator: (any WWDCCoordinator)? {
        (NSApp.delegate as? AppDelegate)?.coordinator
    }
}
