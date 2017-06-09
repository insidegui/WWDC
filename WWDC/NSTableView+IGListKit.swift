//
//  NSTableView+IGListKit.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import IGListKit

extension NSTableView {

    func reload(withOldValue oldValue: [IGListDiffable], newValue: [IGListDiffable]) {
        guard oldValue.count > 0 else {
            reloadData()
            return
        }

        let diff = IGListDiff(oldValue, newValue, .equality)

        beginUpdates()
        insertRows(at: diff.inserts, withAnimation: .effectGap)
        removeRows(at: diff.deletes, withAnimation: .effectGap)
        reloadData(forRowIndexes: diff.updates, columnIndexes: IndexSet([0]))
        endUpdates()
    }

}
