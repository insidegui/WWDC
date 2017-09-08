//
//  SessionRow.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation
import IGListKit

enum SessionRowKind {
    case sectionHeader(String)
    case session(SessionViewModel)
}

final class SessionRow: NSObject {

    let kind: SessionRowKind

    var _diffIdentifier: NSObjectProtocol

    init(viewModel: SessionViewModel) {
        kind = .session(viewModel)
        _diffIdentifier = viewModel.diffIdentifier()

        super.init()
    }

    init(title: String) {
        kind = .sectionHeader(title)
        _diffIdentifier = title as NSObjectProtocol
    }

    convenience init(date: Date, showTimeZone: Bool = false) {
        let title = SessionViewModel.standardFormatted(date: date, withTimeZoneName: showTimeZone)

        self.init(title: title)
    }

    override var debugDescription: String {
        switch kind {
        case .sectionHeader(let title):
            return "Header: " + title
        case .session(let viewModel):
            return "Session: " + viewModel.identifier + " " + viewModel.title
        }
    }

    // `hashValue` and `isEqual` both need to be provided to
    // work correctly in sequences
    override var hashValue: Int {
        return diffIdentifier().hash
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let diffable = object as? IGListDiffable {
            return diffIdentifier().isEqual(diffable.diffIdentifier())
        } else {
            return false
        }
    }
}

extension SessionRow: IGListDiffable {

    func diffIdentifier() -> NSObjectProtocol {
        return _diffIdentifier
    }

    func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        guard let other = object as? SessionRow else { return false }

        if case .session(let otherViewModel) = other.kind, case .session(let viewModel) = kind {
            return otherViewModel.isEqual(toDiffableObject: viewModel)
        } else if case .sectionHeader(let otherTitle) = other.kind, case .sectionHeader(let title) = kind {
            return otherTitle == title
        } else {
            return false
        }
    }
}

struct IndexedSessionRow: Hashable {

    let sessionRow: SessionRow
    let index: Int

    var hashValue: Int {
        return sessionRow.hashValue
    }

    static func ==(lhs: IndexedSessionRow, rhs: IndexedSessionRow) -> Bool {
        return lhs.sessionRow == rhs.sessionRow
    }
}
