//
//  SearchFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation

enum SearchFilter {
    case arbitrary(NSPredicate)
    case year([Int])
    case track([String])
    case focus([String])
    case favorited(Bool)
    case downloaded([String])
    
    var isEmpty: Bool {
        switch self {
        case .arbitrary:
            return false
        case .year(let years):
            return years.count == 0
        case .track(let tracks):
            return tracks.count == 0
        case .focus(let focuses):
            return focuses.count == 0
        // for boolean properties, setting them to "false" means empty because we only want to filter when true
        case .favorited(let favorited):
            return !favorited;
        case .downloaded(let states):
            return states.count == 0;
        }
    }
    
    var predicate: NSPredicate {
        switch self {
        case .arbitrary(let predicate):
            return predicate
        case .year(let years):
            return NSPredicate(format: "year IN %@", years)
        case .track(let tracks):
            return NSPredicate(format: "track IN %@", tracks)
        case .focus(let focuses):
            return NSPredicate(format: "focus IN %@", focuses)
        case .favorited(let favorited):
            return NSPredicate(format: "favorite = %@", favorited as CVarArg)
        case .downloaded(let downloaded):
            return NSPredicate(format: "downloaded = %@", downloaded[0].boolValue as CVarArg)
        }
    }
    
    var selectedInts: [Int]? {
        switch self {
        case .year(let years):
            return years
        default:
            return nil
        }
    }
    
    var selectedStrings: [String]? {
        switch self {
        case .track(let strings):
            return strings
        case .focus(let strings):
            return strings
        case .downloaded(let strings):
            return strings
        default:
            return nil
        }
    }
    
    static func predicatesWithFilters(_ filters: SearchFilters) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        for filter in filters {
            predicates.append(filter.predicate)
        }
        return predicates
    }
}
typealias SearchFilters = [SearchFilter]

