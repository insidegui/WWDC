//
//  AppCoordinator+UserActivity.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import ConfCore
import PlayerUI

extension AppCoordinator {

    func updateCurrentActivity(with item: UserActivityRepresentable?) {
        guard let item = item else {
            currentActivity?.invalidate()
            currentActivity = nil
            return
        }

        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)

        activity.title = item.title
        activity.webpageURL = item.webUrl?.replacingAppleDeveloperHostWithNativeHost

        activity.becomeCurrent()

        currentActivity = activity
    }

}
