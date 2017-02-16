//
//  SessionInstance.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

enum SessionInstanceType: Int {
    case session
    case lab
    case video
    
    init?(rawSessionType: String) {
        switch rawSessionType {
        case "Session":
            self = .session
        case "Lab":
            self = .lab
        case "Video":
            self = .video
        default: return nil
        }
    }
}

/// A session instance represents a specific occurence of a session with a location and start/end times
class SessionInstance: Object {
    
    /// Unique identifier
    dynamic var identifier = ""
    
    /// Instance number
    dynamic var number = ""
    
    /// The session
    dynamic var session: Session? = nil
    
    /// Type of session (0 = regular session, 1 = lab, 2 = video-only session)
    dynamic var sessionType = 0
    
    /// The start time
    dynamic var startTime: Date = .distantPast
    
    /// The end time
    dynamic var endTime: Date = .distantPast
    
    /// Keywords for this session
    let keywords = List<Keyword>()
    
    /// Room name (for JSON adapting only)
    dynamic var roomName = ""
    
    /// The room where this session will be held
    let room = LinkingObjects(fromType: Room.self, property: "instances")
    
    override static func primaryKey() -> String? {
        return "identifier"
    }
    
    override static func ignoredProperties() -> [String] {
        return ["roomName"]
    }
    
}
