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
        return NSAppearance(named: NSAppearance.Name.vibrantDark)!
    }
}
