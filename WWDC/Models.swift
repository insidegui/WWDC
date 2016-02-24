//
//  Schema.swift
//  WWDC Data Layer Rewrite
//
//  Created by Guilherme Rambo on 01/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

// TODO: share model layer between OS X and tvOS, not just copy the files around

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
    dynamic var downloaded = false
    
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
    
}

enum SearchFilter {
    case Arbitrary(NSPredicate)
    case Year([Int])
    case Track([String])
    case Focus([String])
    case Favorited(Bool)
    case Downloaded([String])
    
    var isEmpty: Bool {
        switch self {
        case .Arbitrary:
            return false
        case .Year(let years):
            return years.count == 0
        case .Track(let tracks):
            return tracks.count == 0
        case .Focus(let focuses):
            return focuses.count == 0
        // for boolean properties, setting them to "false" means empty because we only want to filter when true
        case .Favorited(let favorited):
            return !favorited;
        case .Downloaded(let states):
            return states.count == 0;
        }
    }
    
    var predicate: NSPredicate {
        switch self {
        case .Arbitrary(let predicate):
            return predicate
        case .Year(let years):
            return NSPredicate(format: "year IN %@", years)
        case .Track(let tracks):
            return NSPredicate(format: "track IN %@", tracks)
        case .Focus(let focuses):
            return NSPredicate(format: "focus IN %@", focuses)
        case .Favorited(let favorited):
            return NSPredicate(format: "favorite = %@", favorited)
        case .Downloaded(let downloaded):
            return NSPredicate(format: "downloaded = %@", downloaded[0].boolValue)
        }
    }
    
    var selectedInts: [Int]? {
        switch self {
        case .Year(let years):
            return years
        default:
            return nil
        }
    }
    
    var selectedStrings: [String]? {
        switch self {
        case .Track(let strings):
            return strings
        case .Focus(let strings):
            return strings
        case .Downloaded(let strings):
            return strings
        default:
            return nil
        }
    }
    
    static func predicatesWithFilters(filters: SearchFilters) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        for filter in filters {
            predicates.append(filter.predicate)
        }
        return predicates
    }
}
typealias SearchFilters = [SearchFilter]

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
}