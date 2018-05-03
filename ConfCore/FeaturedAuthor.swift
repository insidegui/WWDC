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
        case name
        case bio
        case avatar
        case url
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let bio = try container.decode(String.self, forKey: .bio)
        let avatar = try container.decode(String.self, forKey: .avatar)
        let url = try container.decode(String.self, forKey: .url)

        self.init()

        self.name = name
        self.bio = bio
        self.avatar = avatar
        self.url = url
    }
}
