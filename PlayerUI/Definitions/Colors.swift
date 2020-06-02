//
//  Colors.swift
//  PlayerProto
//
//  Created by Guilherme Rambo on 28/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSColor {

    static var timeLabel: NSColor {
        return NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
    }

    static var playerBorder: NSColor {
        return NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.40, alpha: 1.00)
    }

    static var highlightedPlayerBorder: NSColor {
        return NSColor(calibratedRed: 0.56, green: 0.55, blue: 0.55, alpha: 1.00)
    }

    static var bufferProgress: NSColor {
        return NSColor(calibratedRed: 0.52, green: 0.52, blue: 0.52, alpha: 1.00)
    }

    static var playerProgress: NSColor {
        return NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.90, alpha: 1.00)
    }

    static var seekProgress: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor
        } else {
            return NSColor(calibratedRed: 0.00, green: 0.80, blue: 0.92, alpha: 1.00)
        }
    }

    static var playerHighlight: NSColor {
        if #available(macOS 10.14, *) {
            return .controlAccentColor
        } else {
            return NSColor(calibratedRed: 0.00, green: 0.80, blue: 0.92, alpha: 1.00)
        }
    }

    static var buttonColor: NSColor {
        return NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
    }

    static var externalPlaybackText: NSColor {
        return #colorLiteral(red: 0.8980392156862745, green: 0.8980392156862745, blue: 0.8980392156862745, alpha: 1)
    }

    static var scrimColor: NSColor {
        return NSColor.black
    }
}
