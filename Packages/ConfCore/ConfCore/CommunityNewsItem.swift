//
//  CommunityNewsItem.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public class CommunityNewsItem: Object, Decodable {

    @objc public dynamic var id = ""
    @objc public dynamic var title = ""
    @objc public dynamic var summary: String?
    @objc public dynamic var date = Date()
    @objc public dynamic var url = ""
    @objc public dynamic var isFeatured = false
    @objc public dynamic var image: String?
    public let tags = List<CommunityTag>()

    public var rawTags: [String] = []

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case summary = "description"
        case date
        case url
        case tags
        case image
        case isFeatured
    }

    public override class func primaryKey() -> String? {
        return "id"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.url = try container.decode(String.self, forKey: .url)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        self.rawTags = try container.decode([String].self, forKey: .tags)
    }

}
