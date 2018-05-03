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
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let identifier = try container.decode(Int.self, forKey: .identifier)
        let name = try container.decode(String.self, forKey: .name)
        let color = try container.decode(String.self, forKey: .color)
        let darkColor = try container.decode(String.self, forKey: .darkColor)
        let titleColor = try container.decode(String.self, forKey: .titleColor)
        let lightBGColor = try container.decode(String.self, forKey: .lightBGColor)
        let ordinal = try container.decodeIfPresent(Int.self, forKey: .ordinal) ?? 0

        self.init()

        self.identifier = "\(identifier)"
        self.name = name
        self.darkColor = darkColor
        self.lightBackgroundColor = lightBGColor
        self.lightColor = color
        self.titleColor = titleColor
        self.order = ordinal
    }
}
