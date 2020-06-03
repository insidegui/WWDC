//
//  PUISlider.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 30/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PUISlider: NSSlider {

    override class var cellClass: AnyClass? {
        // swiftlint:disable:next unused_setter_value
        set {
            super.cellClass = PUISliderCell.self
        }

        get {
            return PUISliderCell.self
        }

    }

}

class PUISliderCell: NSSliderCell {

    override func drawKnob(_ knobRect: NSRect) {
        if isHighlighted {
            NSColor.playerProgress.setFill()
        } else {
            NSColor.highlightedPlayerBorder.setFill()
        }

        let path = NSBezierPath(ovalIn: knobRect.insetBy(dx: 4, dy: 4))

        NSColor(calibratedWhite: 0, alpha: 0.4).setStroke()

        path.stroke()
        path.fill()
    }

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let finalRect = rect.insetBy(dx: 2, dy: 0.5)

        NSColor.bufferProgress.withAlphaComponent(0.8).setFill()

        let barPath = NSBezierPath(roundedRect: finalRect, xRadius: 2, yRadius: 2)
        barPath.fill()

        let progressRect = NSRect(x: finalRect.origin.x, y: finalRect.origin.y, width: finalRect.width * CGFloat(doubleValue / maxValue), height: finalRect.height)
        let progressPath = NSBezierPath(roundedRect: progressRect, xRadius: 2, yRadius: 2)

        NSColor.primary.setFill()
        progressPath.fill()
    }

}
