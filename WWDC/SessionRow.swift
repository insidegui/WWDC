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
    case sectionHeader
    case session
}

final class SessionRow: NSObject {
    
    let kind: SessionRowKind
    let viewModel: SessionViewModel
    
    init(viewModel: SessionViewModel, kind: SessionRowKind) {
        self.kind = kind
        self.viewModel = viewModel
        
        super.init()
    }
    
    convenience init(viewModel: SessionViewModel) {
        self.init(viewModel: viewModel, kind: .session)
    }
    
    convenience init(title: String) {
        self.init(viewModel: SessionViewModel(title: title), kind: .sectionHeader)
    }
    
    var title: String {
        return viewModel.title
    }
    
}

extension SessionRow: IGListDiffable {
    
    func diffIdentifier() -> NSObjectProtocol {
        return viewModel.diffIdentifier()
    }
    
    func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        return viewModel.isEqual(toDiffableObject: object)
    }
    
}
