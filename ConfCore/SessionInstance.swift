//
//  SessionInstance.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public enum SessionInstanceType: Int {
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
public class SessionInstance: Object {
    
    /// Unique identifier
    public dynamic var identifier = ""
    
    /// Instance number
    public dynamic var number = ""
    
    /// The session
    public dynamic var session: Session? = nil
    
    /// Type of session (0 = regular session, 1 = lab, 2 = video-only session)
    public dynamic var sessionType = 0
    
    /// The start time
    public dynamic var startTime: Date = .distantPast
    
    /// The end time
    public dynamic var endTime: Date = .distantPast
    
    /// Keywords for this session
    public let keywords = List<Keyword>()
    
    /// Room name (for JSON adapting only)
    public dynamic var roomName = ""
    
    /// The room where this session will be held
    public let room = LinkingObjects(fromType: Room.self, property: "instances")
    
    public override static func primaryKey() -> String? {
        return "identifier"
    }
    
    public override static func ignoredProperties() -> [String] {
        return ["roomName"]
    }
    
}
