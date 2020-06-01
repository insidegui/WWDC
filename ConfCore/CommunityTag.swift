//
//  CommunityTag.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public class CommunityTag: Object, Decodable {

    @objc public dynamic var name = ""
    @objc public dynamic var title = ""
    @objc public dynamic var order = 0
    @objc public dynamic var color = ""

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case order
        case color
    }

    public override class func primaryKey() -> String? {
        return "name"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.title = try container.decode(String.self, forKey: .title)
        self.order = try container.decode(Int.self, forKey: .order)
        self.color = try container.decode(String.self, forKey: .color)
    }

}
