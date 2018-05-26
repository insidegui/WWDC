//
//  AppCoordinator+RelatedSessions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 17/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension AppCoordinator: RelatedSessionsViewControllerDelegate {

    func selectSessionOnAppropriateTab(with viewModel: SessionViewModel) {
        if ![.video, .session].contains(viewModel.sessionInstance.type) {
            // If the related session selected is not a video or regular session, we must be
            // on the schedule tab to show it, since the videos tab only shows videos
            tabController.activeTab = .schedule
        }

        currentListController?.selectSession(with: viewModel.identifier)
    }

    func relatedSessionsViewController(_ controller: RelatedSessionsViewController, didSelectSession viewModel: SessionViewModel) {
        selectSessionOnAppropriateTab(with: viewModel)
    }

}
