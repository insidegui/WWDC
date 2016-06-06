//
//  LiveSession.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

class LiveSession {
    var id = 0
    var title = ""
    var summary = ""
    var startsAt: NSDate?
    var endsAt: NSDate?
    var streamURL: NSURL?
    var alternateStreamURL = ""
    var isLiveRightNow = false
    
    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let description = "description"
        static let stream = "stream"
        static let stream2 = "stream_elcapitan"
        static let startsAt = "starts_at"
        static let isLiveRightNow = "isLiveRightNow"
    }
    
    private let _dateTimezone = "GMT"
    private let _dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'ZZZZ"
    
    init(jsonObject: JSON) {
        id = jsonObject[Keys.id].intValue
        
        if let title = jsonObject[Keys.title].string {
            self.title = title
        } else {
            self.title = ""
        }
        
        if let description = jsonObject[Keys.description].string {
            self.summary = description
        } else {
            self.summary = ""
        }
        
        if let streamURL = jsonObject[Keys.stream].string {
            self.streamURL = NSURL(string: streamURL)
        }
        
        isLiveRightNow = jsonObject[Keys.isLiveRightNow].boolValue
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = _dateFormat
        if let startsAtString = jsonObject[Keys.startsAt].string {
            let startsAtWithZone = startsAtString+_dateTimezone
            startsAt = formatter.dateFromString(startsAtWithZone)
        }
    }
    
    init(liveSessionJSON: JSON) {
        id = liveSessionJSON[Keys.id].intValue
        
        if let title = liveSessionJSON[Keys.title].string {
            self.title = title
        } else {
            self.title = ""
        }
        
        if let description = liveSessionJSON[Keys.description].string {
            self.summary = description
        } else {
            self.summary = ""
        }
        
        if let streamURL = liveSessionJSON["url"].string {
            self.streamURL = NSURL(string: streamURL)
        }
        
        isLiveRightNow = liveSessionJSON[Keys.isLiveRightNow].boolValue
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        
        if let startsAtString = liveSessionJSON["start_date"].string {
            startsAt = formatter.dateFromString(startsAtString)
        }
        if let endsAtString = liveSessionJSON["end_date"].string {
            endsAt = formatter.dateFromString(endsAtString)
        }
    }
}