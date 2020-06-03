//
//  Colors.swift
//  ConfUIFoundation
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

@objc public extension NSColor {

    static var listBackground: NSColor { .underPageBackgroundColor }

    static let primaryText = NSColor(calibratedWhite: 0.9, alpha: 1.0)

    static let secondaryText = NSColor(calibratedWhite: 0.75, alpha: 1.0)

    static var tertiaryText = NSColor(calibratedWhite: 0.55, alpha: 1.0)

    private static var isAccentColorGraphite: Bool { NSColorGetUserAccentColor() == kGraphiteAccentColor }

    /// Color used as a fallback when the system accent color is graphite,
    /// to prevent issues with lack of color contrast.
    private static let fallbackAccentColor = NSColor(named: "fallbackAccentColor", bundle: .confUIFoundation)!

    private static var wwdcAccentColor: NSColor {
        guard !isAccentColorGraphite else { return fallbackAccentColor }

        return .controlAccentColor
    }

    static var primary: NSColor { .wwdcAccentColor }

    static var toolbarTintActive: NSColor { .wwdcAccentColor }

    static var toolbarTint = NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.40, alpha: 1.00)

    static var sectionHeaderBackground: NSColor {
        return NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.40, alpha: 0.97)
    }

    static var darkText: NSColor {
        return NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.04, alpha: 1.00)
    }

    static var selection: NSColor {
        guard !isAccentColorGraphite else { return fallbackAccentColor }

        return .selectedControlColor
    }

    static let darkWindowBackground = NSColor.black

    static let contentBackground = NSColor(named: "contentBackgroundColor", bundle: .confUIFoundation)!

    static let roundedCellBackground = NSColor(named: "roundedCellBackgroundColor", bundle: .confUIFoundation)!

    static let darkTitlebarBackground = NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)

    static let prefsPrimaryText = NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.90, alpha: 1.00)

    static let prefsSecondaryText = NSColor(calibratedRed: 0.75, green: 0.75, blue: 0.75, alpha: 1.00)

    static let prefsTertiaryText = NSColor(calibratedRed: 0.49, green: 0.49, blue: 0.49, alpha: 1.00)

    static let auxWindowBackground = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.07, alpha: 1.00)

    static let darkGridColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.00)

}
