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
            if self.lowercaseString == "yes" || self.lowercaseString == "true" || Int(self) > 0 {
                return true
            } else {
                return false
            }
        }
    }
    
    func words() -> [String] {
        
        var words = [String]()
        let range = Range<String.Index>(start: self.startIndex, end: self.endIndex)
        self.enumerateSubstringsInRange(range, options: NSStringEnumerationOptions.ByWords) { (substring, _, _, _) -> () in
            words.append(substring!)
        }
        return words
    }
    
}