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
    func sessionTableViewContextMenuActionRemoveDownload(viewModels: [SessionViewModel])
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
