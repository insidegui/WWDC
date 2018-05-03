//
//  NewsItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public enum NewsType: Int {
    case news
    case unsupportedUnknown
    case gallery
    case unsupportedPassbook
}

/// NewsItem can be a simple news text or a photo gallery
public class NewsItem: Object, Decodable {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// The type of news (0 = regular news, 2 = photo gallery)
    @objc public dynamic var newsType = 0

    /// The condition that must be true so the user can see this item (used to limit some items to only attendees)
    @objc public dynamic var visibility = ""

    /// When this news item got published
    @objc public dynamic var date = Date.distantPast

    /// Title
    @objc public dynamic var title = ""

    /// Text
    @objc public dynamic var body = ""

    /// Photos for this news item, only present when `newsType == 2`
    public let photos = List<Photo>()

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case id, title, body, timestamp, visibility, photos, type
    }

    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let type = try container.decodeIfPresent(String.self, forKey: .type) {
            guard type != "pass" else {
                let context = DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "'Pass' is not a supported NewsItem type",
                    underlyingError: nil)
                throw DecodingError.dataCorrupted(context)
            }
        }

        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let timestamp = try container.decode(Double.self, forKey: .timestamp)
        let visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? ""
        let body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""

        self.init()

        if let photos = try container.decodeIfPresent([Photo].self, forKey: .photos) {
            self.photos.append(objectsIn: photos)
        }

        self.identifier = id
        self.title = title
        self.body = body
        self.visibility = visibility
        self.date = Date(timeIntervalSince1970: timestamp)
        self.newsType = self.photos.count > 0 ? NewsType.gallery.rawValue : NewsType.news.rawValue
    }

}
