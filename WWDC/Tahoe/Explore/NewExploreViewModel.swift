//
//  NewExploreViewModel.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
@Observable
class NewExploreViewModel {
    let provider: ExploreTabProvider

    var selectedCategory: String?
    var scrollPosition = ScrollPosition(idType: String.self)

    init(provider: ExploreTabProvider) {
        self.provider = provider
    }
}
