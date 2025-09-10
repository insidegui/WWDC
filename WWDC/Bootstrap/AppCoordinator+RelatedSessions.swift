//
//  AppCoordinator+RelatedSessions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 17/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

extension AppCoordinator: RelatedSessionsDelegate {

    func relatedSessions(_ relatedSessions: RelatedSessionsViewModel, didSelectSession viewModel: SessionViewModel) {
        selectSessionOnAppropriateTab(with: viewModel)
    }

}
