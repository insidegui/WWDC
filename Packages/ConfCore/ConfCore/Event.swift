//
//  Event.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Represents a past, present or future WWDC edition (ex: WWDC-2016)
public class Event: Object, Decodable {

    /// Unique identifier (ex: wwdc2017)
    @objc public dynamic var identifier = ""

    /// Event name
    @objc public dynamic var name = ""

    /// When the event starts
    @objc public dynamic var startDate = Date.distantPast

    @objc public dynamic var year = -1

    /// When the event ends
    @objc public dynamic var endDate = Date.distantPast

    /// Is this the current event?
    @objc public dynamic var isCurrent = false

    /// Sessions held at this event
    public let sessions = List<Session>()

    @objc public dynamic var imagesPath = ""

    /// Session instances for schedule
    public var sessionInstances = List<SessionInstance>()

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    internal static func identifier(from date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)

        return "wwdc\(year)"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case name, current, imagesPath
        case start = "startTime"
        case end = "endTime"
        case identifier = "id"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = try container.decode(key: .identifier)
        name = try container.decode(key: .name)
        startDate = try container.decode(key: .start)
        year = Calendar.current.component(.year, from: startDate)
        endDate = try container.decode(key: .end)
        isCurrent = try container.decode(key: .current)
        imagesPath = try container.decode(key: .imagesPath)
    }

}
