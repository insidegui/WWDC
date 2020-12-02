//
//  Photo.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Photos are pictures associated with news items
public class Photo: Object, Decodable {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// The photo's aspect ratio
    @objc public dynamic var aspectRatio = 0.0

    /// The news item this photo is associated with
    public let newsItem = LinkingObjects(fromType: NewsItem.self, property: "photos")

    /// The representations this photo has
    public let representations = List<PhotoRepresentation>()

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case id, ratio
    }

    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let ratio = try container.decode(Double.self, forKey: .ratio)

        let representations = PhotoRepresentationSize.all.map { size -> PhotoRepresentation in
            let rep = PhotoRepresentation()

            rep.remotePath = "\(id)/\(size.rawValue).jpeg"
            rep.width = size.rawValue

            return rep
        }

        self.init()

        self.identifier = id
        self.aspectRatio = ratio
        self.representations.append(objectsIn: representations)
    }
}
