//
//  FeaturedContentViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import ConfCore
import RxRealm
import RxSwift
import RxCocoa
import RealmSwift

final class FeaturedContentViewModel {

    let content: FeaturedContent

    init(content: FeaturedContent) {
        self.content = content
    }

    var sessionViewModel: SessionViewModel? {
        guard let session = content.session else { return nil }

        return SessionViewModel(session: session)
    }

}
