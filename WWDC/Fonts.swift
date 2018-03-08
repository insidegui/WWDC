//
//  Fonts.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension NSAttributedString {

    static func attributedBoldTitle(with string: String) -> NSAttributedString {
        let attrs: [NSAttributedStringKey: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.white,
            .kern: -0.5
        ]

        return NSAttributedString(string: string, attributes: attrs)
    }

}
