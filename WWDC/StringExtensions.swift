//
//  StringExtensions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 23/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


extension String {
    
    var boolValue: Bool {
        get {
            if self.lowercased() == "yes" || self.lowercased() == "true" || Int(self) > 0 {
                return true
            } else {
                return false
            }
        }
    }
    
    func words() -> [String] {
        
        var words = [String]()
        let range = self.characters.indices
        self.enumerateSubstrings(in: range, options: NSString.EnumerationOptions.byWords) { (substring, _, _, _) -> () in
            words.append(substring!)
        }
        return words
    }
    
}
