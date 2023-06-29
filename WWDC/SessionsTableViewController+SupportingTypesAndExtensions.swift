//
//  SessionsTableViewController+SupportingTypesAndExtensions.swift
//  WWDC
//
//  Created by Allen Humphreys on 6/6/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import ConfCore
import RealmSwift
import Combine
import OSLog

/// Conforming to this protocol means the type is capable
/// of uniquely identifying a `Session`
///
/// TODO: Move to ConfCore and make it "official"?
protocol SessionIdentifiable {
    var sessionIdentifier: String { get }
}

struct SessionIdentifier: SessionIdentifiable, Hashable {
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

protocol SessionsTableViewControllerDelegate: AnyObject {

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
            return progress.relativePosition > Constants.watchedVideoRelativePosition
        }

        return false
    }
}

extension Array where Element == SessionRow {

    func index(of session: SessionIdentifiable) -> Int? {
        return firstIndex { row in
            guard case .session(let viewModel) = row.kind else { return false }

            return viewModel.identifier == session.sessionIdentifier
        }
    }

    func firstSessionRowIndex() -> Int? {
        return firstIndex { row in
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
