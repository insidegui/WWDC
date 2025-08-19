//
//  ToolbarSetup.swift
//  WWDC
//
//  Created by luca on 29.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit

extension NSToolbarItem.Identifier {
    static let searchItem = NSToolbarItem.Identifier("wwdc.sidebar.search")
    static let filterItem = NSToolbarItem.Identifier("wwdc.sidebar.search.filter")
    static let tabSelectionItem = NSToolbarItem.Identifier("wwdc.main.centered.tab")
    static let downloadItem = NSToolbarItem.Identifier("wwdc.main.download")
}

protocol ToolbarItemAccessor {
}

extension ToolbarItemAccessor {
    var toolbarWindow: NSWindow? {
        NSApp.keyWindow
    }
}

extension ToolbarItemAccessor {
    var topSegmentControl: NSSegmentedControl? {
        topTabItem?.view as? NSSegmentedControl
    }

    var topTabItem: NSToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .tabSelectionItem })
    }

    var filterItem: NSMenuToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .filterItem }) as? NSMenuToolbarItem
    }

    var searchItem: NSSearchToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .searchItem }) as? NSSearchToolbarItem
    }

    var downloadItem: NSToolbarItem? {
        toolbarWindow?.toolbar?.items.first(where: { $0.itemIdentifier == .downloadItem }) as? NSToolbarItem
    }
}

extension NSViewController: ToolbarItemAccessor {
}

extension NSWindowController: ToolbarItemAccessor {
}
