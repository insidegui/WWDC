//
//  LoggingHelper.swift
//  WWDC
//
//  Created by Guilherme Rambo on 24/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

import Fabric
import Crashlytics

final class LoggingHelper {

    static func install() {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Fabric.with([Crashlytics.self])
    }

    static func registerError(_ error: Error, info: [String: Any]? = nil) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: info)
    }
}
