//
//  SessionRow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

enum SessionRowKind {
    case sectionHeader(_ title: String, _ symbolName: String?)
    case session(SessionViewModel)

    var isHeader: Bool {
        switch self {
        case .sectionHeader:
            return true
        default:
            return false
        }
    }

    var isSession: Bool {
        switch self {
        case .session:
            return true
        default:
            return false
        }
    }

    var sessionViewModel: SessionViewModel? {
        switch self {
        case .session(let viewModel):
            return viewModel
        default:
            return nil
        }
    }
}

final class SessionRow: CustomDebugStringConvertible {

    let kind: SessionRowKind

    init(viewModel: SessionViewModel) {
        kind = .session(viewModel)
    }

    init(title: String, symbolName: String? = nil) {
        kind = .sectionHeader(title, symbolName)
    }

    convenience init(date: Date, showTimeZone: Bool = false) {
        let title = SessionViewModel.standardFormatted(date: date, withTimeZoneName: showTimeZone)

        self.init(title: title)
    }

    var isHeader: Bool { kind.isHeader }
    var isSession: Bool { kind.isSession }
    var sessionViewModel: SessionViewModel? { kind.sessionViewModel }
    func represents(session: SessionIdentifiable) -> Bool {
        sessionViewModel?.identifier == session.sessionIdentifier
    }

    var debugDescription: String {
        switch kind {
        case .sectionHeader(let title, _):
            return "Header: " + title
        case .session(let viewModel):
            return "Session: " + viewModel.identifier + " " + viewModel.title
        }
    }
}

extension SessionRow: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(reflecting: kind))
        switch kind {
        case let .sectionHeader(title, symbol):
            hasher.combine(title)
            hasher.combine(symbol)
        case let .session(viewModel):
            hasher.combine(viewModel.identifier)
            hasher.combine(viewModel.trackName)
        }
    }

    /// This definition of equality of 2 rows depends largely on the fact that
    /// each view is bound to a realm object so there is no need to create a new row
    static func == (lhs: SessionRow, rhs: SessionRow) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case let (.sectionHeader(lhsTitle, lhsSymbol), .sectionHeader(rhsTitle, rhsSymbol)) where lhsTitle == rhsTitle && lhsSymbol == rhsSymbol:
            return true
        case let (.session(lhsViewModel), .session(rhsViewModel))
            where lhsViewModel.identifier == rhsViewModel.identifier && lhsViewModel.trackName == rhsViewModel.trackName:
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
