//
//  GlobalSearchTabState.swift
//  WWDC
//
//  Created by luca on 01.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import Combine
import ConfCore
import OSLog
import RealmSwift

struct GlobalSearchTabState {
    let additionalPredicates: [NSPredicate]
    private(set) var filterPredicate: FilterPredicate {
        willSet {
            GlobalSearchCoordinator.log.debug("New predicate: \(newValue.predicate?.description ?? "nil", privacy: .public)")
        }
    }

    var effectiveFilters: [FilterType] = []
    private var currentPredicate: NSPredicate? {
        let filters = effectiveFilters
        guard filters.contains(where: { !$0.isEmpty }) || !additionalPredicates.isEmpty else {
            return nil
        }
        let subpredicates = filters.compactMap { $0.predicate } + additionalPredicates
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        return predicate
    }

    mutating func updatePredicate(_ reason: FilterChangeReason) {
        filterPredicate = .init(predicate: currentPredicate, changeReason: reason)
    }
}
