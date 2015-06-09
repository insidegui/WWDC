//
//  LiveEvent.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

private let _dateTimezone = "GMT"
private let _dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'ZZZZ"

struct LiveEvent {
    var id: Int
    var title: String
    var startsAt: NSDate?
    var description: String
    var stream: NSURL?
    var isLiveRightNow: Bool
    
    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let description = "description"
        static let stream = "stream"
        static let startsAt = "starts_at"
        static let isLiveRightNow = "isLiveRightNow"
    }
    
    init(jsonObject: JSON) {
        id = jsonObject[Keys.id].intValue
        
        if let title = jsonObject[Keys.title].string {
            self.title = title
        } else {
            self.title = ""
        }
        
        if let description = jsonObject[Keys.description].string {
            self.description = description
        } else {
            self.description = ""
        }
        
        if let streamURL = jsonObject[Keys.stream].string {
            self.stream = NSURL(string: streamURL)
        }
        
        isLiveRightNow = jsonObject[Keys.isLiveRightNow].boolValue
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = _dateFormat
        if let startsAtString = jsonObject[Keys.startsAt].string {
            let startsAtWithZone = startsAtString+_dateTimezone
            startsAt = formatter.dateFromString(startsAtWithZone)
        }
    }
}