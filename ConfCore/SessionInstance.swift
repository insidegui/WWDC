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
    case session, lab, video, getTogether, specialEvent

    init?(rawSessionType: String) {
        switch rawSessionType {
        case "Session":
            self = .session
        case "Lab":
            self = .lab
        case "Video":
            self = .video
        case "Get-Together":
            self = .getTogether
        case "Special Event":
            self = .specialEvent
        default: return nil
        }
    }
}

/// A session instance represents a specific occurence of a session with a location and start/end times
public class SessionInstance: Object {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// Instance number
    @objc public dynamic var number = ""

    public var code: Int {
        guard let n = number.components(separatedBy: "-").last else { return NSNotFound }

        return Int(n) ?? NSNotFound
    }

    /// The event identifier for the event this instance belongs to
    @objc public dynamic var eventIdentifier = ""

    /// The session
    @objc public dynamic var session: Session? = nil

    /// The raw session type as returned by the API
    @objc public dynamic var rawSessionType = "Session"

    /// Type of session (0 = regular session, 1 = lab, 2 = video-only session)
    @objc public dynamic var sessionType = 0

    public var type: SessionInstanceType {
        get {
            return SessionInstanceType(rawValue: sessionType) ?? .session
        }
        set {
            sessionType = newValue.rawValue
        }
    }

    /// The start time
    @objc public dynamic var startTime: Date = .distantPast

    /// The end time
    @objc public dynamic var endTime: Date = .distantPast

    /// Keywords for this session
    public let keywords = List<Keyword>()

    /// Room name
    @objc public dynamic var roomName = ""

    /// Room unique identifier
    @objc public dynamic var roomIdentifier = ""

    // Track name
    @objc public dynamic var trackName = ""

    @objc public dynamic var trackIdentifier = ""

    /// The track associated with the instance
    public let track = LinkingObjects(fromType: Track.self, property: "instances")

    /// Whether this is being live streamed at the moment
    @objc public dynamic var isCurrentlyLive = false

    /// Whether the live flag is being forced by an external source
    @objc public dynamic var isForcedLive = false

    /// The EKEvent's eventIdentifier 
    /// See https://developer.apple.com/reference/eventkit/ekevent/1507437-eventidentifier
    public dynamic var calendarEventIdentifier = ""

    public override static func primaryKey() -> String? {
        return "identifier"
    }

    public override static func ignoredProperties() -> [String] {
        return ["code"]
    }

    public static func standardSort(instanceA: SessionInstance, instanceB: SessionInstance) -> Bool {
        guard let sessionA = instanceA.session, let sessionB = instanceB.session else { return false }

        let nA = instanceA.code
        let nB = instanceB.code

        if instanceA.sessionType == instanceB.sessionType {
            if instanceA.sessionType == SessionInstanceType.session.rawValue {
                if instanceA.startTime == instanceB.startTime {
                    return nA < nB
                } else {
                    return instanceA.startTime < instanceB.startTime
                }
            } else {
                return Session.standardSort(sessionA: sessionA, sessionB: sessionB)
            }
        } else {
            return instanceA.sessionType < instanceB.sessionType
        }
    }

    func merge(with other: SessionInstance, in realm: Realm) {
<<<<<<< HEAD
        assert(other.identifier == identifier, "Can't merge two objects with different identifiers!")

        number = other.number
        rawSessionType = other.rawSessionType
        sessionType = other.sessionType
        startTime = other.startTime
        endTime = other.endTime
        roomIdentifier = other.roomIdentifier
        trackName = other.trackName
        trackIdentifier = other.trackIdentifier
        eventIdentifier = other.eventIdentifier

        if let otherSession = other.session, let session = session {
=======
        assert(other.identifier == self.identifier, "Can't merge two objects with different identifiers!")
        
        self.number = other.number
        self.rawSessionType = other.rawSessionType
        self.sessionType = other.sessionType
        self.startTime = other.startTime
        self.endTime = other.endTime
        self.roomIdentifier = other.roomIdentifier
        self.trackName = other.trackName
        self.trackIdentifier = other.trackIdentifier
        self.eventIdentifier = other.eventIdentifier
        self.calendarEventIdentifier = other.calendarEventIdentifier
        
        if let otherSession = other.session, let session = self.session {
>>>>>>> 7c1e0ac55b9295f507993ee6ff99fe9ccab63cc2
            session.merge(with: otherSession, in: realm)
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
        
        keywords.removeAll()
        keywords.append(objectsIn: otherKeywords)
    }
    
}
