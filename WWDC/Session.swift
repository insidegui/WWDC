//
//  Session.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

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
        guard let schedule = schedule else { return false }
        
        return schedule.endsAt.isGreaterThanOrEqualTo(NSDate())
    }
    
    var schedule: ScheduledSession? {
        guard let realm = realm else { return nil }
        
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
    
    convenience required init(json: JSON) {
        self.init()
        
        self.id = json["id"].intValue
        self.year = json["year"].intValue
        self.uniqueId = "#\(self.year)-\(self.id)"
        self.title = json["title"].stringValue
        self.summary = json["description"].stringValue
        self.date = json["date"].stringValue
        self.track = json["track"].stringValue
        self.videoURL = json["url"].stringValue
        self.hdVideoURL = json["download_hd"].stringValue
        self.slidesURL = json["slides"].stringValue
        self.track = json["track"].stringValue
        if let focus = json["focus"].arrayObject as? [String] {
            self.focus = focus.joinWithSeparator(", ")
        }
        if let images = json["images"].dictionaryObject as? [String: String] {
            self.shelfImageURL = images["shelf"] ?? ""
        }
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