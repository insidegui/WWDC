//
//  ToolbarSetup.swift
//  WWDC
//
//  Created by luca on 29.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit

private extension NSToolbarItem.Identifier {
    static let searchItem = NSToolbarItem.Identifier("wwdc.sidebar.search")
    static let tabSelectionItem = NSToolbarItem.Identifier("wwdc.main.centered.tab")
    static let downloadItem = NSToolbarItem.Identifier("wwdc.main.download")
}

protocol ToolbarItemAccessor {
    var toolbarWindow: NSWindow? { get }
}

extension ToolbarItemAccessor {
    var topSegmentControl: NSSegmentedControl? {
        topTabItem?.view as? NSSegmentedControl
    }

    var topTabItem: NSToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .tabSelectionItem })
    }

    var topSearchItem: NSToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .searchItem })
    }

    var topDownloadItem: NSToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .downloadItem })
    }
}

extension NSViewController: ToolbarItemAccessor {
    var toolbarWindow: NSWindow? { viewIfLoaded?.window }
}

private extension MainWindowController {
    var coordinator: AppCoordinator? {
        (NSApp.delegate as? AppDelegate)?.coordinator
    }
}

extension MainWindowController: NSToolbarDelegate {
    func setupWindowAndToolbar(tab: MainWindowTab = .explore) {
        guard let window else {
            return
        }
        window.styleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        let toolbar = NSToolbar(identifier: "LiquidToolbar-\(tab.rawValue)")

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [.tabSelectionItem]
        window.toolbar = toolbar
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.autovalidates = false
        switch itemIdentifier {
        case .searchItem:
            toolbarItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
            toolbarItem.toolTip = "Search"
            toolbarItem.target = self
            toolbarItem.action = #selector(toggleSearchPanel)
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
            .searchItem,
            .sidebarTrackingSeparator,
            .tabSelectionItem,
            .flexibleSpace,
            .downloadItem
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}

private extension MainWindowController {
    @objc func toggleSearchPanel(_ item: NSToolbarItem) {
        if let searchPopover {
            if searchPopover.isShown {
                searchPopover.close()
                if #available(macOS 15.0, *) {
                    item.toolbar?.items.first(where: { $0.itemIdentifier == .downloadItem })?.isHidden = false
                }
            } else {
                searchPopover.show(relativeTo: item)
                if #available(macOS 15.0, *) {
                    item.toolbar?.items.first(where: { $0.itemIdentifier == .downloadItem })?.isHidden = true
                }
            }
            return
        }
        guard let searchCoordinator = (NSApp.delegate as? AppDelegate)?.coordinator?.searchCoordinator else { return }
        let popover = NSPopover()
        searchCoordinator.videosSearchController.showFilterButton = false
        popover.contentViewController = searchCoordinator.videosSearchController
        popover.behavior = .applicationDefined
        popover.show(relativeTo: item)
        searchPopover = popover

        if #available(macOS 15.0, *) {
            item.toolbar?.items.first(where: { $0.itemIdentifier == .downloadItem })?.isHidden = true
        }
    }

    @objc func toggleDownloadPanel(_ item: NSToolbarItem) {}

    @objc func selectTabControl(_ control: NSSegmentedControl) {
        if let tab = MainWindowTab(rawValue: control.selectedSegment) {
            coordinator?.tabController.setActiveTab(tab)
        }
    }
}
