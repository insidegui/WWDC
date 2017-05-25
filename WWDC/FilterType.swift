//
//  FilterType.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct FilterOption: Equatable {
    let title: String
    let value: String
    
    static func ==(lhs: FilterOption, rhs: FilterOption) -> Bool {
        return lhs.value == rhs.value
    }
}

struct FilterType {
    
    var identifier: String {
        return collectionKey + "." + modelKey
    }
    
    var isSubquery = false
    var collectionKey = ""
    var modelKey = ""
    var options: [FilterOption]
    var selectedOptions: [FilterOption]
    
    var isEmpty: Bool {
        return selectedOptions.isEmpty
    }
    
    var emptyTitle: String
    
    var title: String {
        if isEmpty || selectedOptions.count == options.count {
            return emptyTitle
        } else {
            let t = selectedOptions.reduce("", { $0 + ", " + $1.title })
            
            return t.substring(from: t.index(t.startIndex, offsetBy: 2))
        }
    }
    
    var predicate: NSPredicate? {
        guard !isEmpty else { return nil }
        
        let subpredicates = selectedOptions.map { option -> NSPredicate in
            let format: String
            
            if isSubquery {
                format = "SUBQUERY(\(collectionKey), $\(collectionKey), $\(collectionKey).\(modelKey) == %@).@count > 0"
            } else {
                format = "\(modelKey) == %@"
            }
            
            return NSPredicate(format: format, option.value)
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }
    
}
