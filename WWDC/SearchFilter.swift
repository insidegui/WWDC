//
//  SearchFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

enum SearchFilter {
    case Arbitrary(NSPredicate)
    case Year([Int])
    case Track([String])
    case Focus([String])
    case Favorited(Bool)
    case Downloaded([String])
    case SearchIn([String])
    
    var isEmpty: Bool {
        switch self {
        case .Arbitrary:
            return false
        case .Year(let years):
            return years.count == 0
        case .Track(let tracks):
            return tracks.count == 0
        case .Focus(let focuses):
            return focuses.count == 0
        // for boolean properties, setting them to "false" means empty because we only want to filter when true
        case .Favorited(let favorited):
            return !favorited;
        case .Downloaded(let states):
          return states.count == 0;
        case .SearchIn(let searchKeys):
          return searchKeys.count == 0;
          
      }
      
    }
    private static let searchTermKey = "SEARCHTERM"
    
    var predicate: NSPredicate {
        switch self {
        case .Arbitrary(let predicate):
            return predicate
        case .Year(let years):
            return NSPredicate(format: "year IN %@", years)
        case .Track(let tracks):
            return NSPredicate(format: "track IN %@", tracks)
        case .Focus(let focuses):
            return NSPredicate(format: "focus IN %@", focuses)
        case .Favorited(let favorited):
            return NSPredicate(format: "favorite = %@", favorited)
        case .Downloaded(let downloaded):
            return NSPredicate(format: "downloaded = %@", downloaded[0].boolValue)
        case .SearchIn(let searchKeys):
            let keys = searchKeys.count > 0 ? searchKeys : Session.searchableTextKeys;
            let predicates = keys.map { searchKey in
                 NSPredicate(format: "\(searchKey) CONTAINS[c] $\(SearchFilter.searchTermKey)")
            }
            return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }
    }
    
    func predicateWithSearchTerm(term: String) -> NSPredicate  {
        switch self {
        case .SearchIn(_):
            return self.predicate.predicateWithSubstitutionVariables([SearchFilter.searchTermKey: term])
        default:
            return self.predicate
        }
    }
    
    var selectedInts: [Int]? {
        switch self {
        case .Year(let years):
            return years
        default:
            return nil
        }
    }
    
    var selectedStrings: [String]? {
        switch self {
        case .Track(let strings):
            return strings
        case .Focus(let strings):
            return strings
        case .Downloaded(let strings):
            return strings
        case .SearchIn(let strings):
            return strings
        default:
            return nil
        }
    }
    
    static func predicatesWithFilters(filters: SearchFilters) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        for filter in filters {
            predicates.append(filter.predicate)
        }
        return predicates
    }
}
typealias SearchFilters = [SearchFilter]

