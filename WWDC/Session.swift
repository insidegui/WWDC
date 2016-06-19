//
//  Session.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

class Session: Object {
    
    dynamic var uniqueId = ""
    dynamic var id = 0
    dynamic var year = 0
    dynamic var date = ""
    dynamic var track = ""
    dynamic var focus = ""
    dynamic var title = ""
    dynamic var summary = ""
    dynamic var videoURL = ""
    dynamic var hdVideoURL = ""
    dynamic var slidesURL = ""
    dynamic var shelfImageURL = ""
    dynamic var progress = 0.0
    dynamic var currentPosition: Double = 0.0
    dynamic var favorite = false
    dynamic var transcript: Transcript?
    dynamic var slidesPDFData = NSData()
    dynamic var downloaded = false
    
    var isScheduled: Bool {
        guard let schedule = schedule where !schedule.invalidated else { return false }
        
        guard !schedule.isLive else { return true }
        
        return schedule.endsAt.isGreaterThanOrEqualTo(NSDate().dateByAddingTimeInterval(WWDCEnvironment.liveTolerance))
    }
    
    var schedule: ScheduledSession? {
        guard let realm = realm where !invalidated else { return nil }
        
        return realm.objectForPrimaryKey(ScheduledSession.self, key: uniqueId)
    }
    
    var event: String {
        if id > 10000 {
            return "Apple TV Tech Talks"
        } else {
            return "WWDC"
        }
    }
    
    var isExtra: Bool {
        return event != "WWDC"
    }
    
    override static func primaryKey() -> String? {
        return "uniqueId"
    }
    
    override static func indexedProperties() -> [String] {
        return ["title"]
    }
    
    var shareURL: String {
        get {
            return "wwdc://\(year)/\(id)"
        }
    }
    
    var hd_url: String? {
        if hdVideoURL == "" {
            return nil
        } else {
            return hdVideoURL
        }
    }
    
    var subtitle: String {
        return "\(year) | \(track) | \(focus)"
    }
    
    func isSemanticallyEqualToSession(otherSession: Session) -> Bool {
        return id == otherSession.id &&
            year == otherSession.year &&
            date == otherSession.date &&
            track == otherSession.track &&
            focus == otherSession.focus &&
            title == otherSession.title &&
            summary == otherSession.summary &&
            videoURL == otherSession.videoURL &&
            hdVideoURL == otherSession.hdVideoURL &&
            slidesURL == otherSession.slidesURL
    }
    
}