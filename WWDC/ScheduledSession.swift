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
    dynamic var startsAt = Date()
    dynamic var endsAt = Date()
    dynamic var calendarIdentifier = ""
    
    var liveSession: LiveSession? {
        return LiveEventObserver.SharedObserver().liveSessions.filter({ $0.id == self.id }).first
    }
    
    var isLive: Bool {
        return liveSession != nil
    }
    
    var session: Session? {
        guard let realm = realm else { return nil }
        
        return realm.object(ofType: Session.self, forPrimaryKey: uniqueId as AnyObject)
    }
    
    override static func primaryKey() -> String? {
        return "uniqueId"
    }
    
    override static func indexedProperties() -> [String] {
        return ["title"]
    }
    
    convenience required init(json: JSON) {
        self.init()
        
        let uniqueIdDateFormatter = DateFormatter()
        uniqueIdDateFormatter.dateFormat = "YYYY"
        
        self.type = json["type"].stringValue
        self.id = json["id"].intValue
        self.room = json["room"].stringValue
        
        if let year = Int(uniqueIdDateFormatter.string(from: self.startsAt)) {
            self.year = year
            self.uniqueId = "#" + String(year) + "-" + String(id)
        }
        
        if let startTime = json["start_time"].int {
            self.startsAt = Date(timeIntervalSince1970: TimeInterval(startTime))
        }
        
        if let endTime = json["end_time"].int {
            self.endsAt = Date(timeIntervalSince1970: TimeInterval(endTime))
        }
    }
    
    func isSemanticallyEqualToScheduledSession(_ otherSession: ScheduledSession) -> Bool {
        return id == otherSession.id &&
            year == otherSession.year &&
            room == otherSession.room &&
            (startsAt == otherSession.startsAt) &&
            (endsAt == otherSession.endsAt)
    }
    
}
