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
public class FeaturedSection: Object {

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

}
