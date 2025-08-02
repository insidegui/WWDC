//
//  ContentFilterOption.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Foundation

struct ContentFilterOption: PickAnyPickerItem, ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    internal init(label: String? = nil, isSelected: Bool = false) {
        self.label = label
        self.isSelected = isSelected
    }
    
    static var divider = ContentFilterOption()
    let id = UUID()
    var label: String?
    var isSelected = false

    init(stringLiteral value: String) {
        self.init(label: value)
    }

    init(stringInterpolation: DefaultStringInterpolation) {
        self.init(label: "\(stringInterpolation)")
    }
}
