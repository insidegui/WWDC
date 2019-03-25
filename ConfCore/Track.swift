//
//  Track.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Tracks represent a specific are of interest (ex: "System Frameworks", "Graphics and Games")
public class Track: Object, Decodable {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// The name of the track
    @objc public dynamic var name = ""

    /// The order in which the track should be listed
    @objc public dynamic var order = 0

    /// Dark theme color
    @objc public dynamic var darkColor = ""

    /// Color for light backgrounds
    @objc public dynamic var lightBackgroundColor = ""

    /// Color for light contexts
    @objc public dynamic var lightColor = ""

    /// Theme title color
    @objc public dynamic var titleColor = ""

    /// Sessions related to this track
    public let sessions = List<Session>()

    /// Instances related to this track
    public let instances = List<SessionInstance>()

    public override class func primaryKey() -> String? {
        return "name"
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case name, color, darkColor, titleColor, lightBGColor, ordinal
        case identifier = "id"
    }

    public convenience required init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        identifier = String(try container.decode(Int.self, forKey: .identifier))
        name = try container.decode(key: .name)
        darkColor = try container.decode(key: .darkColor)
        lightBackgroundColor = try container.decode(key: .lightBGColor)
        lightColor = try container.decode(key: .color)
        titleColor = try container.decode(key: .titleColor)
        order = try container.decodeIfPresent(key: .ordinal) ?? 0
    }
}
