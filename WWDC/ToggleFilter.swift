//
//  ToggleFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct ToggleFilter: FilterType {
    
    var identifier: String
    var isOn: Bool
    
    var customPredicate: NSPredicate?
    
    var isEmpty: Bool {
        return !isOn
    }
    
    var predicate: NSPredicate? {
        guard isOn else { return nil }
        
        return customPredicate
    }
    
}
