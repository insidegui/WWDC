//
//  AppConfig.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

class AppConfig: Object {
    dynamic var sessionsURL = ""
    dynamic var videosURL = ""
    dynamic var isWWDCWeek = false
    dynamic var videosUpdatedAt = ""
    
    convenience required init(json: JSON) {
        self.init()
        
        self.sessionsURL = json["sessions"].stringValue
        self.videosURL = json["videos"].stringValue
        self.isWWDCWeek = json["wwdc_week"].intValue == 1;
    }
    
    override static func primaryKey() -> String? {
        return "sessionsURL"
    }
    
    func isEqualToConfig(config: AppConfig?) -> Bool {
        guard let compareConfig = config else { return false }
        
        return compareConfig.sessionsURL == self.sessionsURL && compareConfig.videosURL == self.videosURL && compareConfig.isWWDCWeek == self.isWWDCWeek
    }
}