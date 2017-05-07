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
    
    // Track name (for JSON adapting only)
    public dynamic var trackName = ""
    
    /// The room where this session will be held
    public let room = LinkingObjects(fromType: Room.self, property: "instances")
    
    /// The track associated with the instance
    public let track = LinkingObjects(fromType: Track.self, property: "instances")
    
    public override static func primaryKey() -> String? {
        return "identifier"
    }
    
    public override static func ignoredProperties() -> [String] {
        return ["roomName"]
    }
    
    public static func standardSort(instanceA: SessionInstance, instanceB: SessionInstance) -> Bool {
        guard let nA = Int(instanceA.number), let nB = Int(instanceB.number) else { return false }
        
        if instanceA.startTime == instanceB.startTime {
            return nA < nB
        } else {
            return instanceA.startTime < instanceB.startTime
        }
    }
    
    func merge(with other: SessionInstance, in realm: Realm) {
        assert(other.identifier == self.identifier, "Can't merge two objects with different identifiers!")
        
        self.number = other.number
        self.sessionType = other.sessionType
        self.startTime = other.startTime
        self.endTime = other.endTime
        self.roomName = other.roomName
        self.trackName = other.trackName
        
        if let otherSession = other.session {
            self.session = realm.object(ofType: Session.self, forPrimaryKey: otherSession.identifier)
        }
        
        let otherKeywords = other.keywords.map { newKeyword -> (Keyword) in
            if newKeyword.realm == nil,
                let existingKeyword = realm.object(ofType: Keyword.self, forPrimaryKey: newKeyword.name)
            {
                return existingKeyword
            } else {
                return newKeyword
            }
        }
        
        self.keywords.removeAll()
        self.keywords.append(objectsIn: otherKeywords)
    }
    
}
