//
//  TextualFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct TextualFilter: FilterType {
    
    var identifier: String
    var value: String?
    var modelKeys: [String]
    
    var isEmpty: Bool {
        return predicate == nil
    }
    
    var predicate: NSPredicate? {
        guard let value = value else { return nil }
        guard value.characters.count > 2 else { return nil }
        
        let subpredicates = modelKeys.map { key in
            return NSPredicate(format: "\(key) CONTAINS[cd] %@", value)
        }
        
        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }
    
}
