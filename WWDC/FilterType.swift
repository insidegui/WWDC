//
//  FilterType.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

typealias WWDCFiltersStateDictionary = [ String : [ FilterIdentifier.RawValue : WWDCFilterTypeDictionary ] ]
typealias WWDCFilterTypeDictionary = [ String : Any ]

protocol FilterType {

    var identifier: String { get set }
    var isEmpty: Bool { get }
    var predicate: NSPredicate? { get }
    func dictionaryRepresentation() -> WWDCFilterTypeDictionary

}

// Can't use WWDCFilterTypeDictionary as Value's type, likely a bug in Swift
extension Dictionary where Key == String, Value == [ String : Any ] {

    init?(filters: [FilterType]) {

        self = [String : WWDCFilterTypeDictionary]()

        for filter in filters {

            guard let filterID = FilterIdentifier(rawValue: filter.identifier) else {
                continue
            }

            switch filterID {
            case .text:
                //TextualFilter
                self[filterID.rawValue] = filter.dictionaryRepresentation()

            case .event, .focus, .track:
                //MultipleChoiceFilter
                self[filterID.rawValue] = filter.dictionaryRepresentation()

            case .isFavorite, .isDownloaded, .isUnwatched:
                //ToggleFilters
                self[filterID.rawValue] = filter.dictionaryRepresentation()
            }
        }
    }
}

extension Array where Element == FilterType {

    func isIdentical(to otherArray: [Element]) -> Bool {

        var isIdentical = false

        if self.count == otherArray.count {

            isIdentical = true

            for filter in self {

                if !otherArray.contains(where: { $0.identifier == filter.identifier }) {
                    isIdentical = false
                    break
                }
            }
        }

        return isIdentical
    }
}
