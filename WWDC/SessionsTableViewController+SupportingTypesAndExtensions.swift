//
//  SessionsTableViewController+SupportingTypesAndExtensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/6/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RealmSwift
import os.log

/// Conforming to this protocol means the type is capable
/// of uniquely identifying a `Session`
///
/// TODO: Move to ConfCore and make it "official"?
protocol SessionIdentifiable {
    var sessionIdentifier: String { get }
}

struct SessionIdentifier: SessionIdentifiable {
    let sessionIdentifier: String

    init(_ string: String) {
        sessionIdentifier = string
    }
}

extension SessionViewModel: SessionIdentifiable {
    var sessionIdentifier: String {
        return identifier
    }
}

protocol SessionsTableViewControllerDelegate: class {

    func sessionTableViewContextMenuActionWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionUnWatch(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRemoveFavorite(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionCancelDownload(viewModels: [SessionViewModel])
    func sessionTableViewContextMenuActionRevealInFinder(viewModels: [SessionViewModel])
}

extension Session {

    var isWatched: Bool {
        if let progress = progresses.first {
            return progress.relativePosition > PlayerConstants.watchedVideoRelativePosition
        }

        return false
    }
}

extension Array where Element == SessionRow {

    func index(of session: SessionIdentifiable) -> Int? {
        return index { row in
            guard case .session(let viewModel) = row.kind else { return false }

            return viewModel.identifier == session.sessionIdentifier
        }
    }

    func firstSessionRowIndex() -> Int? {
        return index { row in
            if case .session = row.kind {
                return true
            }
            return false
        }
    }

    func forEachSessionViewModel(_ body: (SessionViewModel) throws -> Void) rethrows {
        try forEach {
            if case .session(let viewModel) = $0.kind {
                try body(viewModel)
            }
        }
    }
}

struct FilterResults {

    static var empty: FilterResults {
        return FilterResults(storage: nil, query: nil)
    }

    /// This becomes an OperationQueue for aborting, tada
    private static let searchQueue = DispatchQueue(label: "Search", qos: .userInteractive)

    var query: NSPredicate? {
        didSet {
            searchResults = nil
        }
    }

    let storage: Storage?

    private var searchResults: Results<Session>?

    init(storage: Storage?, query: NSPredicate?) {
        self.storage = storage
        self.query = query
    }

    func results(with closure: @escaping (Results<Session>?) -> Void) {

        if let searchResults = searchResults {
            closure(searchResults)
            return
        }

        guard let query = query, let storage = storage else {
            closure(nil)
            return
        }

        // I'm pretty sure doing this on the background isn't saving any time
        FilterResults.searchQueue.async {
            do {
                let realm = try Realm(configuration: storage.realmConfig)

                let objects = realm.objects(Session.self).filter(query)
                let reference = ThreadSafeReference(to: objects)
                DispatchQueue.main.async {
                    closure(storage.realm.resolve(reference))
                }
            } catch {
                os_log("Failed to initialize Realm for searching: %{public}@",
                       log: .default,
                       type: .error,
                       String(describing: error))
                LoggingHelper.registerError(error, info: ["when": "Searching"])
            }
        }
    }
}
