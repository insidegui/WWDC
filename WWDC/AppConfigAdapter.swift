//
//  AppConfigAdapter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 07/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import SwiftyJSON

class AppConfigAdapter: JSONAdapter {
    
    typealias ModelType = AppConfig
    
    static func adapt(json: JSON) -> ModelType {
        let config = AppConfig()
        
        if let baseURL = json["baseURL"].string {
            config.sessionsURL = baseURL + json["sessions"].stringValue
            config.videosURL = baseURL + json["videos"].stringValue
        } else {
            config.sessionsURL = json["sessions"].stringValue
            config.videosURL = json["videos"].stringValue
        }
        
        config.isWWDCWeek = json["wwdc_week"].intValue == 1
        config.scheduleEnabled = json["schedule"].intValue == 1
        config.shouldIgnoreCache = json["ignore_cache"].intValue == 1
        
        return config
    }
    
}