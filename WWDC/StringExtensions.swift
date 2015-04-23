//
//  StringExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

extension String {
    
    var boolValue: Bool {
        get {
            if self.lowercaseString == "yes" || self.lowercaseString == "true" || self.toInt() > 0 {
                return true
            } else {
                return false
            }
        }
    }
    
}