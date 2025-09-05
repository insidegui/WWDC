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

    static let timeLabel = NSColor.labelColor

    static let playerBorder = NSColor.quaternaryLabelColor

    static let highlightedPlayerBorder = NSColor.tertiaryLabelColor

    static let bufferProgress = NSColor.tertiaryLabelColor

    static let playerProgress = NSColor.secondaryLabelColor

    static let seekProgress = NSColor.labelColor

    static var playerHighlight: NSColor { .primary }

    static var buttonColor: NSColor {
        return NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
    }

}
