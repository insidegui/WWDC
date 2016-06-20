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
        
        if let videos = json["urls"]["videos"].string {
            config.videosURL = videos
        }
        if let sessions = json["urls"]["sessions"].string {
            config.sessionsURL = sessions
        }
        
        if let streaming = json["features"]["liveStreaming"].bool {
            config.isWWDCWeek = streaming
        }
        
        config.scheduleEnabled = true
        config.shouldIgnoreCache = false
        
        return config
    }
    
}