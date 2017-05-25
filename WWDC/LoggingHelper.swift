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
    
    static func registerCloudKitUserIdentifier(_ identifier: String) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }
        
        Crashlytics.sharedInstance().setUserIdentifier(identifier)
    }
    
    static func registerError(_ error: Error) {
        guard !Preferences.shared.userOptedOutOfCrashReporting else { return }
        
        Crashlytics.sharedInstance().recordError(error)
    }
    
}
