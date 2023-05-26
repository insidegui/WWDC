//
//  WWDCTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableRowView: NSTableRowView {

    override var isGroupRowStyle: Bool {
        didSet {
            guard isGroupRowStyle != oldValue else { return }
            setupGroupRowStyleIfNeeded()
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard !isGroupRowStyle else { return }

        if window?.isKeyWindow == false || NSApp.isActive == false {
            super.drawSelection(in: dirtyRect)
        } else {
            NSColor.selection.set()
            dirtyRect.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        guard !isGroupRowStyle else { return }

        super.drawBackground(in: dirtyRect)
    }

    private var groupBackground: NSVisualEffectView?

    private func setupGroupRowStyleIfNeeded() {
        guard isGroupRowStyle else {
            groupBackground?.removeFromSuperview()
            return
        }

        guard groupBackground == nil else { return }

        let bg = NSVisualEffectView(frame: bounds)
        bg.appearance = NSAppearance(named: .darkAqua)
        bg.material = .headerView
        bg.blendingMode = .withinWindow
        bg.state = .followsWindowActiveState
        bg.autoresizingMask = [.width, .height]
        addSubview(bg)

        groupBackground = bg
    }

}
