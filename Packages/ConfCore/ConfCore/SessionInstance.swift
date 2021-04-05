//
//  SessionInstance.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public enum SessionInstanceType: Int, Decodable {
    case session, lab, video, getTogether, specialEvent, labByAppointment

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
        case "Lab by Appointment":
            self = .labByAppointment
        default: return nil
        }
    }
}

/// A session instance represents a specific occurence of a session with a location and start/end times
public class SessionInstance: Object, ConditionallyDecodable {

    static let defaultTrackId = 4

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
    @objc public dynamic var session: Session?

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
    @objc public dynamic var calendarEventIdentifier = ""

    // Action link
    @objc public dynamic var actionLinkPrompt: String?
    @objc public dynamic var actionLinkURL: String?

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
        calendarEventIdentifier = other.calendarEventIdentifier

        if let otherSession = other.session, let session = session {
            session.merge(with: otherSession, in: realm)
        }

        let otherKeywords = other.keywords.map { newKeyword -> (Keyword) in
            if newKeyword.realm == nil,
                let existingKeyword = realm.object(ofType: Keyword.self, forPrimaryKey: newKeyword.name) {
                return existingKeyword
            } else {
                return newKeyword
            }
        }

        keywords.removeAll()
        keywords.append(objectsIn: otherKeywords)
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case id, keywords, startTime, endTime, type
        case eventId, actionLinkPrompt, actionLinkURL
        case room = "roomId"
        case track = "trackId"
    }

    public convenience required init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            let session = try Session(from: decoder)

            self.number = try container.decode(key: .id)
            self.session = session
            self.identifier = session.identifier
            self.eventIdentifier = try container.decode(key: .eventId)

            let rawType = try container.decode(String.self, forKey: .type)
            self.rawSessionType = rawType
            self.sessionType = SessionInstanceType(rawSessionType: rawType)?.rawValue ?? 0

            self.startTime = try container.decode(Date.self, forKey: .startTime)
            self.endTime = try container.decode(Date.self, forKey: .endTime)

            let roomNumber = try container.decodeIfPresent(Int.self, forKey: .room)
            self.roomIdentifier = roomNumber.flatMap { String($0) } ?? ""

            let trackNumber = try container.decodeIfPresent(Int.self, forKey: .track)
            self.trackIdentifier = trackNumber.flatMap { String($0) } ?? String(Self.defaultTrackId)
        } catch let error as DecodingError where error.isKeyNotFound {
            throw ConditionallyDecodableError.missingKey(error)
        }

        actionLinkPrompt = try container.decodeIfPresent(key: .actionLinkPrompt)
        actionLinkURL = try container.decodeIfPresent(key: .actionLinkURL)

        try container.decodeIfPresent([Keyword].self, forKey: .keywords).map { keywords.append(objectsIn: $0) }
    }

}

fileprivate extension DecodingError {

    var isKeyNotFound: Bool {
        switch self {
        case .keyNotFound:
            return true
        default:
            return false
        }
    }
}
