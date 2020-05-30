//
//  NSFont+Rounded.swift
//  WWDC
//
//  Created by Guilherme Rambo on 24/04/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

public extension NSFont {

    static func wwdcRoundedSystemFont(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        guard let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) else {
            assertionFailure("Failed to get font descriptor")
            return NSFont.systemFont(ofSize: size, weight: weight)
        }

        return NSFont(descriptor: desc, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

}
