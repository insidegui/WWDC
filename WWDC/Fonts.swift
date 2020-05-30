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
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldTitleFont,
            .foregroundColor: NSColor.primaryText,
            .kern: -0.5
        ]

        return NSAttributedString(string: string, attributes: attrs)
    }

    static func create(with string: String,
                       font: NSFont,
                       color: NSColor,
                       lineHeightMultiple: CGFloat = 1,
                       alignment: NSTextAlignment = .left,
                       lineBreakMode: NSLineBreakMode = .byWordWrapping) -> NSAttributedString {
        let pStyle = NSMutableParagraphStyle()
        pStyle.lineHeightMultiple = lineHeightMultiple
        pStyle.alignment = alignment
        pStyle.lineBreakMode = lineBreakMode

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: pStyle
        ]

        return NSAttributedString(string: string, attributes: attrs)
    }

}

extension NSFont {
    static let boldTitleFont = NSFont.wwdcRoundedSystemFont(ofSize: 24, weight: .semibold)
}
