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
        return (self as NSString).boolValue
    }
    
}
