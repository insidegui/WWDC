//
//  FeaturedSectionViewModel.swift
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

final class FeaturedSectionViewModel {

    let section: FeaturedSection

    init(section: FeaturedSection) {
        self.section = section
    }

    lazy var rxTitle: Observable<String> = {
        return Observable.from(object: section).map({ $0.title })
    }()

    lazy var rxSubtitle: Observable<String> = {
        return Observable.from(object: section).map({ $0.summary })
    }()

    lazy var contents: [FeaturedContentViewModel] = {
        return section.content.map { FeaturedContentViewModel(content: $0) }
    }()

}
