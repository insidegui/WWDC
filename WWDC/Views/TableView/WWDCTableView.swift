//
//  WWDCTableView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableView: NSTableView {

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

extension NSTableView {

    func scrollRowToCenter(_ row: Int) {

        guard let clipView = superview as? NSClipView,
              let scrollView = clipView.superview as? NSScrollView else {

                assertionFailure("Unexpected NSTableView view hiearchy")
                return
        }

        let rowRect = rect(ofRow: row)
        var scrollOrigin = rowRect.origin

        let tableHalfHeight = clipView.frame.height * 0.5
        let rowRectHalfHeight = rowRect.height * 0.5

        scrollOrigin.y = (scrollOrigin.y - tableHalfHeight) + rowRectHalfHeight

        scrollView.flashScrollers()

        clipView.setBoundsOrigin(scrollOrigin)
    }
}
