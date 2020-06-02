//
//  SessionRow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

enum SessionRowKind {
    case sectionHeader(String)
    case session(SessionViewModel)
}

final class SessionRow: CustomDebugStringConvertible {

    let kind: SessionRowKind

    init(viewModel: SessionViewModel) {
        kind = .session(viewModel)
    }

    init(title: String) {
        kind = .sectionHeader(title)
    }

    convenience init(date: Date, showTimeZone: Bool = false) {
        let title = SessionViewModel.standardFormatted(date: date, withTimeZoneName: showTimeZone)

        self.init(title: title)
    }

    var debugDescription: String {
        switch kind {
        case .sectionHeader(let title):
            return "Header: " + title
        case .session(let viewModel):
            return "Session: " + viewModel.identifier + " " + viewModel.title
        }
    }
}

extension SessionRow {

    func represents(session: SessionIdentifiable) -> Bool {
        if case .session(let viewModel) = kind {
            return viewModel.identifier.contains(session.sessionIdentifier)
        }
        return false
    }
}

extension SessionRow: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(reflecting: kind))
        switch kind {
        case let .sectionHeader(title):
            hasher.combine(title)
        case let .session(viewModel):
            hasher.combine(viewModel.identifier)
        }
    }

    /// This definition of equality of 2 rows depends largely on the fact that
    /// each view is bound to a realm object so there is no need to create a new row
    static func == (lhs: SessionRow, rhs: SessionRow) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case let (.sectionHeader(lhsTitle), .sectionHeader(rhsTitle)) where lhsTitle == rhsTitle:
            return true
        case let (.session(lhsViewModel), .session(rhsViewModel)) where lhsViewModel.identifier == rhsViewModel.identifier:
            return true
        default:
            return false
        }
    }
}

struct IndexedSessionRow: Hashable {

    let sessionRow: SessionRow
    let index: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(sessionRow)
    }

    static func == (lhs: IndexedSessionRow, rhs: IndexedSessionRow) -> Bool {
        return lhs.sessionRow == rhs.sessionRow
    }
}
