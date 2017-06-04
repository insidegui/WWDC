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
        let attrs: [String: Any] = [
            NSFontAttributeName: NSFont.boldSystemFont(ofSize: 24),
            NSForegroundColorAttributeName: NSColor.white,
            NSKernAttributeName: -0.5
        ]
        
        return NSAttributedString(string: string, attributes: attrs)
    }
    
}
