//
//  CocoaHubEdition.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

public class CocoaHubEdition: Object, Decodable {

    @objc public dynamic var index = 0
    @objc public dynamic var id = ""
    @objc public dynamic var title = ""
    @objc public dynamic var summary = ""
    @objc public dynamic var date = Date()

    public let articles = List<CommunityNewsItem>()

    enum CodingKeys: String, CodingKey {
        case index = "id"
        case id = "_id"
        case title
        case summary = "description"
        case date
    }

    public override class func primaryKey() -> String? {
        return "id"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.index = try container.decode(Int.self, forKey: .index)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.date = try container.decode(Date.self, forKey: .date)
    }

    func merge(with other: CocoaHubEdition) {
        assert(other.id == id, "Can't merge two objects with different identifiers!")

        self.index = other.index
        self.title = other.title
        self.summary = other.summary
        self.date = other.date
    }

}
