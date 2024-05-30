//
//  Colors.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
@_exported import ConfUIFoundation

extension NSColor {

    static var timeLabel = NSColor.labelColor

    static let playerBorder = NSColor.quaternaryLabelColor

    static var highlightedPlayerBorder = NSColor.tertiaryLabelColor

    static let bufferProgress = NSColor.tertiaryLabelColor

    static var playerProgress = NSColor.secondaryLabelColor

    static var seekProgress = NSColor.labelColor

    static var playerHighlight: NSColor { .primary }

    static var buttonColor: NSColor {
        return NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
    }

}
