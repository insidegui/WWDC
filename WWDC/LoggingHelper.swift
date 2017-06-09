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

import CommunitySupport

final class LoggingHelper {

    static func install() {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Fabric.with([Crashlytics.self])

        observeCommunityCenterNotifications()
    }

    static func registerCloudKitUserIdentifier(_ identifier: String) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Crashlytics.sharedInstance().setUserIdentifier(identifier)
    }

    static func registerError(_ error: Error, info: [String: Any]? = nil) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Crashlytics.sharedInstance().recordError(error, withAdditionalUserInfo: info)
    }

    static func registerEvent(with name: String, info: [String: Any] = [:]) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }

        Answers.logCustomEvent(withName: name, customAttributes: info)
    }

    static func observeCommunityCenterNotifications() {
        NotificationCenter.default.addObserver(forName: .CMSErrorOccurred, object: nil, queue: OperationQueue.main) { note in
            let error: Error

            if let noteError = note.object as? Error {
                error = noteError
            } else {
                error = NSError(domain: "CMSCommunityCenter", code: -1, userInfo: note.userInfo)
            }

            LoggingHelper.registerError(error, info: note.userInfo as? [String: Any])
        }

        NotificationCenter.default.addObserver(forName: .CMSUserIdentifierDidBecomeAvailable, object: nil, queue: OperationQueue.main) { note in
            guard let identifier = note.object as? String else { return }

            LoggingHelper.registerCloudKitUserIdentifier(identifier)
        }
    }

}
