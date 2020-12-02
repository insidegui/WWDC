//
//  FeaturedAuthor.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Specifies an author for a curated playlist
public class FeaturedAuthor: Object, Decodable {

    @objc public dynamic var name: String = ""
    @objc public dynamic var bio: String = ""
    @objc public dynamic var avatar: String = ""
    @objc public dynamic var url: String = ""

    public override static func primaryKey() -> String? {
        return "name"
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, bio, avatar, url
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(key: .name)
        bio = try container.decode(key: .bio)
        avatar = try container.decode(key: .avatar)
        url = try container.decode(key: .url)
    }
}
