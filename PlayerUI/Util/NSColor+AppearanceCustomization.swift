//
//  NSColor+AppearanceCustomization.swift
//  WWDC
//
//  Created by luca on 12.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit

public extension NSColor {
    func preferred(in appearanceName: NSAppearance.Name) -> NSColor {
        return NSColor(cgColor: preferredCGColor(in: appearanceName)) ?? self
    }

    func preferredCGColor(in appearanceName: NSAppearance.Name) -> CGColor {
        guard let appearance = NSAppearance(named: appearanceName) else {
            return cgColor
        }
        var result = cgColor
        appearance.performAsCurrentDrawingAppearance { // accessing cgcolor will get the correct color under specific appearance
            result = cgColor
        }
        return result
    }
}
