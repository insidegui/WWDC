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

    init(viewModel: SessionViewModel) {
        self.kind = .session(viewModel)

        super.init()
    }

    init(title: String) {
        self.kind = .sectionHeader(title)
    }

    convenience init(date: Date, showTimeZone: Bool = false) {
        let title = SessionViewModel.standardFormatted(date: date, withTimeZoneName: showTimeZone)

        self.init(title: title)
    }

}

extension SessionRow: IGListDiffable {

    func diffIdentifier() -> NSObjectProtocol {
        switch self.kind {
        case .sectionHeader(let title):
            return title as NSObjectProtocol
        case .session(let viewModel):
            return viewModel.diffIdentifier()
        }
    }

    func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        guard let other = object as? SessionRow else { return false }

        if case .session(let otherViewModel) = other.kind, case .session(let viewModel) = self.kind {
            return otherViewModel.isEqual(toDiffableObject: viewModel)
        } else if case .sectionHeader(let otherTitle) = other.kind, case .sectionHeader(let title) = self.kind {
            return otherTitle == title
        } else {
            return false
        }
    }
}
