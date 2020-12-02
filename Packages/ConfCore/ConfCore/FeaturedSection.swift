//
//  FeaturedSection.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift

public enum FeaturedSectionFormat: String {
    // Standard formats from Apple
    case largeGrid = "large_grid"
    case smallGrid = "small_grid"

    // Custom format for curated playlists
    case curated = "curated_wwdc.io"

    // Special dynamic sections
    case history = "_history"
    case favorites = "_favorites"
    case live = "_live"
    case upNext = "_next"
}

/// Specifies a playlist that's shown in the Featured tab
public class FeaturedSection: Object, Decodable {

    /// The order in which to display the featured section
    @objc public dynamic var order = 0

    /// Whether this section is published and should be displayed
    @objc public dynamic var isPublished = true

    @objc dynamic var rawFormat: String = ""

    /// The format for the section layout
    public var format: FeaturedSectionFormat? {
        get {
            return FeaturedSectionFormat(rawValue: rawFormat)
        }
        set {
            rawFormat = newValue?.rawValue ?? ""
        }
    }

    @objc public dynamic var title: String = ""
    @objc public dynamic var summary: String = ""

    @objc public dynamic var colorA: String?
    @objc public dynamic var colorB: String?
    @objc public dynamic var colorC: String?

    /// Contains a list of contents which are sessions that can have an associated essay and bookmarks
    public let content = List<FeaturedContent>()

    /// When the section is a curated one, contains information for the author
    @objc public dynamic var author: FeaturedAuthor?

    public override static func ignoredProperties() -> [String] {
        return ["format"]
    }

    public override static func primaryKey() -> String? {
        return "title"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case ordinal, format, title, description, content, author, published
        case colorA = "ios_color"
        case colorB = "tvos_light_style_color"
        case colorC = "tvos_dark_style_color"
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        content.append(objectsIn: try container.decode([FeaturedContent].self, forKey: .content))
        author = try container.decodeIfPresent(key: .author)
        order = try container.decode(key: .ordinal)
        isPublished = try container.decodeIfPresent(key: .published) ?? true
        rawFormat = try container.decodeIfPresent(key: .format) ?? FeaturedSectionFormat.largeGrid.rawValue
        title = try container.decode(key: .title)
        summary = try container.decode(key: .description)
        colorA = try container.decodeIfPresent(key: .colorA)
        colorB = try container.decodeIfPresent(key: .colorB)
        colorC = try container.decodeIfPresent(key: .colorC)
    }
}
