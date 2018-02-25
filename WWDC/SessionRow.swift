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

extension SessionRow: Hashable {

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }

    static func ==(lhs: SessionRow, rhs: SessionRow) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

struct IndexedSessionRow: Hashable {

    let sessionRow: SessionRow
    let index: Int

    var hashValue: Int {
        return sessionRow.hashValue
    }

    static func == (lhs: IndexedSessionRow, rhs: IndexedSessionRow) -> Bool {
        return lhs.sessionRow == rhs.sessionRow
    }
}
