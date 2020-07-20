//
//  FilterType.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

protocol FilterType {

    var identifier: FilterIdentifier { get set }
    var isEmpty: Bool { get }
    var predicate: NSPredicate? { get }
    mutating func reset()

}

extension Array where Element == FilterType {

    /// This performs a comparison to ensure the two arrays
    /// have the same elements by comparing their identifiers
    ///
    /// It is very slow. If the size of the arrays or frequency
    /// of use becomes greater in the future, a new approach
    /// may be required
    func isIdentical(to otherArray: [Element]) -> Bool {

        var isIdentical = false

        if self.count == otherArray.count {

            isIdentical = true

            for filter in self {

                if !otherArray.contains(where: {
                    if let mc0 = $0 as? MultipleChoiceFilter, let mc1 = filter as? MultipleChoiceFilter {
                        return mc0.identifier == mc1.identifier && mc0.options == mc1.options
                    } else {
                        return $0.identifier == filter.identifier
                    }

                }) {
                    isIdentical = false
                    break
                }
            }
        }

        return isIdentical
    }
}
