//
//  FilterType.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

enum FilterIdentifier: String {
    case text
    case event
    case focus
    case track
    case isFavorite
    case isDownloaded
    case isUnwatched
    case hasBookmarks
}

protocol FilterType {

    var identifier: FilterIdentifier { get set }
    var isEmpty: Bool { get }
    var predicate: NSPredicate? { get }
    mutating func reset()

}

extension Array where Element == FilterType {
    func find<T: FilterType>(_ type: T.Type = T.self, byID identifier: FilterIdentifier) -> T? {
        findIndexed(type, byID: identifier)?.element
    }

    func findIndexed<T: FilterType>(_ type: T.Type = T.self, byID identifier: FilterIdentifier) -> (offset: Index, element: T)? {
        let index = self.firstIndex { (filter) -> Bool in
            return filter.identifier == identifier && filter is T
        }
        guard let index, let item = self[index] as? T else { return nil }

        return (index, item)
    }
}
