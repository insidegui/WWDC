//
//  LiveEvent.swift
//  WWDC
//
//  Created by Guilherme Rambo on 16/05/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Foundation

private let _dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'ZZZZ"

struct LiveEvent {
    var id: Int
    var title: String
    var startsAt: NSDate
    var description: String
    var stream: NSURL

    var willBeLiveSoon: Bool {
        get {
            // TODO: return whether the live event will start "soon" (half an hour? fifteen minutes?)
            return false
        }
    }
    
    var waitTime: Int {
        // TODO: return how many seconds It will take for the live event to start
        return 0
    }
    
    var isLiveRightNow: Bool {
        get {
            // TODO: return true if the event is currently live
            return false
        }
    }
    
    private struct Keys {
        static let id = "id"
        static let title = "title"
        static let description = "description"
        static let stream = "stream"
        static let startsAt = "starts_at"
    }
    
    init(jsonObject: JSON) {
        id = jsonObject[Keys.id].intValue
        title = jsonObject[Keys.title].string!
        description = jsonObject[Keys.description].string!
        stream = NSURL(string: jsonObject[Keys.stream].string!)!
        
        let formatter = NSDateFormatter()
        formatter.dateFormat = _dateFormat
        startsAt = formatter.dateFromString(jsonObject[Keys.startsAt].string!)!
    }
}