//
//  TextualFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore

struct TextualFilter: FilterType {

    var identifier: FilterIdentifier
    var value: String?

    init(identifier: FilterIdentifier, value: String?) {
        self.identifier = identifier
        self.value = value
    }

    private var modelKeys: [String] = ["title"]
    private var subqueryKeys: [String: String] = [:]

    var isEmpty: Bool {
        return predicate == nil
    }

    var predicate: NSPredicate? {
        guard let value = value else { return nil }
        guard value.count > 2 else { return nil }

        if Int(value) != nil {
            return NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(Session.number), value)
        }

        var subpredicates = modelKeys.map { key -> NSPredicate in
            return NSPredicate(format: "\(key) CONTAINS[cd] %@", value)
        }

        let keywords = NSPredicate(format: "SUBQUERY(instances, $instances, ANY $instances.keywords.name CONTAINS[cd] %@).@count > 0", value)
        subpredicates.append(keywords)

        if Preferences.shared.searchInBookmarks {
            let bookmarks = NSPredicate(format: "ANY bookmarks.body CONTAINS[cd] %@", value)
            subpredicates.append(bookmarks)
        }

        if Preferences.shared.searchInTranscripts {
            let transcripts = NSPredicate(format: "transcriptText CONTAINS[cd] %@", value)
            subpredicates.append(transcripts)
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    mutating func reset() {
        value = nil
    }

    var state: State {
        State(value: value)
    }

    struct State: Codable {
        let value: String?
    }
}
