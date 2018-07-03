//
//  VibrantTextField.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/23/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

// TODO: Should subclass something? Such as WWDCTextField?
class VibrantTextField: NSTextField {

    override var allowsVibrancy: Bool {
        return true
    }
}
