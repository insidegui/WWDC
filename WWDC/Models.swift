//
//  Schema.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 01/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

class AppConfig: Object {
    dynamic var sessionsURL = ""
    dynamic var videosURL = ""
    dynamic var isWWDCWeek = false
    dynamic var videosUpdatedAt = ""
    
    convenience required init(json: JSON) {
        self.init()
        
        self.sessionsURL = json["sessions"].stringValue
        self.videosURL = json["url"].stringValue
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
    
}

class TranscriptLine: Object {
    dynamic var transcript: Transcript?
    dynamic var text = ""
    dynamic var timecode: Double = 0.0
    
    convenience required init(text: String, timecode: Double) {
        self.init()
        
        self.text = text
        self.timecode = timecode
    }
}

class Transcript: Object {
    dynamic var session: Session?
    dynamic var fullText = ""
    let lines = List<TranscriptLine>()
    
    convenience required init(json: JSON, session: Session) {
        self.init()
        
        self.session = session
        self.fullText = json["transcript"].stringValue
        
        if let annotations = json["annotations"].arrayObject as? [String], timecodes = json["timecodes"].arrayObject as? [Double] {
            for annotation in annotations {
                guard let idx = annotations.indexOf({ $0 == annotation }) else { continue }
                let line = TranscriptLine(text: annotation, timecode: timecodes[idx])
                line.transcript = self
                self.lines.append(line)
            }
        }
    }
}

class LiveSession {
    var id = 0
    var title = ""
    var summary = ""
    var startsAt: NSDate?
    var streamURL = ""
    var alternateStreamURL = ""
    var current = false
}