//
//  AppCoordinator+Featured.swift
//  WWDC
//
//  Created by Guilherme Rambo on 29/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

extension AppCoordinator: FeaturedContentViewControllerDelegate {

    func featuredContentViewController(_ controller: FeaturedContentViewController, didSelectContent content: FeaturedContentViewModel) {
        guard let sessionViewModel = content.sessionViewModel else { return }

        selectSessionOnAppropriateTab(with: sessionViewModel)
    }

}
