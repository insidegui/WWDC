//
//  WWDCTableRowView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCTableRowView: NSTableRowView {

    override var wantsUpdateLayer: Bool {
        return true
    }

    override var layerContentsRedrawPolicy: NSView.LayerContentsRedrawPolicy {
        get { return .onSetNeedsDisplay }
        // swiftlint:disable:next unused_setter_value
        set { }
    }

    override func makeBackingLayer() -> CALayer {
        let layer = super.makeBackingLayer()

        updateBackgroundColorToMatchState(for: layer)

        return layer
    }

    override var isGroupRowStyle: Bool {
        didSet {
            layer.map { updateBackgroundColorToMatchState(for: $0) }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.layer?.backgroundColor = nil
    }

    override var isSelected: Bool {
        didSet {
            layer.map { updateBackgroundColorToMatchState(for: $0) }
        }
    }

    override func updateLayer() {
        // From `wantsUpdateLayer`:
        // >> If you override this property to be true,
        // >> you must also override the updateLayer() method of your view and
        // >> use it to make the changes to your layer.
        // From `updateLayer`:
        // >> Your implementation of this method should not call super.
    }

    private func updateBackgroundColorToMatchState(for layer: CALayer) {
        if isGroupRowStyle {
            layer.backgroundColor = NSColor.sectionHeaderBackground.cgColor
        } else if isSelected {
            layer.backgroundColor = NSColor.selection.cgColor
        } else {
            layer.backgroundColor = nil
        }
    }
}
