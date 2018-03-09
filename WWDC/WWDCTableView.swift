//
//  WWDCTableView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableView: NSTableView {

    private var selectedRowIndexesBeforeReload: IndexSet = IndexSet([])

    func reloadPreservingSelection() {
        selectedRowIndexesBeforeReload = selectedRowIndexes
        reloadData()
        selectRowIndexes(selectedRowIndexesBeforeReload, byExtendingSelection: false)
    }

    override var effectiveAppearance: NSAppearance {
        return NSAppearance(named: .vibrantDark)!
    }

    override func menu(for event: NSEvent) -> NSMenu? {

        let windowLocation = event.locationInWindow
        let tableLocation = convert(windowLocation, from: nil)
        let clickedRow = row(at: tableLocation)

        if clickedRow >= 0,
            let rowView = rowView(atRow: clickedRow, makeIfNecessary: false),
            rowView.isGroupRowStyle {

            return nil
        }

        return super.menu(for: event)
    }
}
