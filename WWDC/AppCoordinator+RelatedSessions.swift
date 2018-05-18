//
//  AppCoordinator+RelatedSessions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 17/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

extension AppCoordinator: RelatedSessionsViewControllerDelegate {

    func relatedSessionsViewController(_ controller: RelatedSessionsViewController, didSelectSession session: SessionViewModel) {
        currentListController.selectSession(with: session.identifier)
    }

}
