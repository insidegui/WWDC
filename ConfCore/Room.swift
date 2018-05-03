//
//  Room.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Represents a room or venue where sessions are held
public class Room: Object, Decodable {

    @objc public dynamic var identifier = ""

    /// Name of the map file (maps are not present in the macOS app because they are embedded in the iOS app's binary, not given by the API)
    @objc public dynamic var mapName = ""

    /// Name of the room
    @objc public dynamic var name = ""

    /// Room floor name
    @objc public dynamic var floor = ""

    /// Session instances held at this room
    public let instances = List<SessionInstance>()

    public override class func primaryKey() -> String? {
        return "name"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case name, mapName, floor
        case identifier = "id"
    }

    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let identifier = try container.decode(Int.self, forKey: .identifier)
        let name = try container.decode(String.self, forKey: .name)

        self.init()

        self.identifier = "\(identifier)"
        self.name = name
    }
}
