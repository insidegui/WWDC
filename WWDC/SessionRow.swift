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
    
    init(viewModel: SessionViewModel) {
        self.kind = .session
        self.viewModel = viewModel
        
        super.init()
    }
    
    init(title: String) {
        self.kind = .sectionHeader
        self.viewModel = SessionViewModel(title: title)
        
        super.init()
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
