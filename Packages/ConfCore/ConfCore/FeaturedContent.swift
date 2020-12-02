//
//  FeaturedContent.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

/// Specifies an author for a curated playlist
public class FeaturedContent: Object, Decodable {

    /// The session id for the relevant session
    @objc public dynamic var sessionId: String = ""

    /// The session this content represents
    @objc public dynamic var session: Session?

    /// RTF data for the essay associated with the content
    @objc public dynamic var essay: Data?

    /// A list of bookmarks
    public let bookmarks = List<Bookmark>()

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case sessionId = "identifier"
        case essay
        case bookmarks
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId = try container.decode(key: .sessionId)
        essay = try container.decodeIfPresent(String.self, forKey: .essay).flatMap { Data(base64Encoded: $0) }
        try container.decodeIfPresent([Bookmark].self, forKey: .bookmarks).map { bookmarks.append(objectsIn: $0) }
    }

}
