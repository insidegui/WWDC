//
//  ScheduledSession.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

class ScheduledSession: Object {
    
    dynamic var track: Track?
    dynamic var type = ""
    dynamic var year = 0
    dynamic var id = 0
    dynamic var uniqueId = ""
    dynamic var room = ""
    dynamic var startsAt = NSDate()
    dynamic var endsAt = NSDate()
    dynamic var calendarIdentifier = ""
    
    var liveSession: LiveSession? {
        return LiveEventObserver.SharedObserver().liveSessions.filter({ $0.id == self.id }).first
    }
    
    var isLive: Bool {
        return liveSession != nil
    }
    
    var session: Session? {
        guard let realm = realm else { return nil }
        
        return realm.objectForPrimaryKey(Session.self, key: uniqueId)
    }
    
    override static func primaryKey() -> String? {
        return "uniqueId"
    }
    
    override static func indexedProperties() -> [String] {
        return ["title"]
    }
    
    convenience required init(json: JSON) {
        self.init()
        
        let uniqueIdDateFormatter = NSDateFormatter()
        uniqueIdDateFormatter.dateFormat = "YYYY"
        
        self.type = json["type"].stringValue
        self.id = json["id"].intValue
        self.room = json["room"].stringValue
        
        if let year = Int(uniqueIdDateFormatter.stringFromDate(self.startsAt)) {
            self.year = year
            self.uniqueId = "#" + String(year) + "-" + String(id)
        }
        
        if let startTime = json["start_time"].int {
            self.startsAt = NSDate(timeIntervalSince1970: NSTimeInterval(startTime))
        }
        
        if let endTime = json["end_time"].int {
            self.endsAt = NSDate(timeIntervalSince1970: NSTimeInterval(endTime))
        }
    }
    
    func isSemanticallyEqualToScheduledSession(otherSession: ScheduledSession) -> Bool {
        return id == otherSession.id &&
            year == otherSession.year &&
            room == otherSession.room &&
            startsAt.isEqualToDate(otherSession.startsAt) &&
            endsAt.isEqualToDate(otherSession.endsAt)
    }
    
}