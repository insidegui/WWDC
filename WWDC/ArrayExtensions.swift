//
//  ArrayExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 19/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

extension Array {
    mutating func remove<U: Equatable>(object: U) {
        var index: Int?
        for (idx, itemToRemove) in self.enumerate() {
            if let to = itemToRemove as? U {
                if object == to {
                    index = idx
                }
            }
        }
        
        if(index != nil) {
            self.removeAtIndex(index!)
        }
    }
    
    func contains<U: Equatable>(object: U) -> Bool {
        for itemToCompare in self {
            if let to = itemToCompare as? U {
                if object == to {
                    return true
                }
            }
        }
        
        return false
    }
}