//
//  AppConfig.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

class AppConfig: Object {
    dynamic var sessionsURL = ""
    dynamic var videosURL = ""
    dynamic var isWWDCWeek = false
    dynamic var scheduleEnabled = false
    dynamic var shouldIgnoreCache = false
    dynamic var videosUpdatedAt = ""
    
    override static func primaryKey() -> String? {
        return "sessionsURL"
    }
    
    func isEqualToConfig(config: AppConfig?) -> Bool {
        guard let compareConfig = config else { return false }
        
        return compareConfig.sessionsURL == self.sessionsURL &&
            compareConfig.videosURL == self.videosURL &&
            compareConfig.isWWDCWeek == self.isWWDCWeek &&
            compareConfig.scheduleEnabled == self.scheduleEnabled &&
            compareConfig.shouldIgnoreCache == self.shouldIgnoreCache
    }
}