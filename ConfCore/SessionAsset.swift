//
//  SessionAsset.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

public enum SessionAssetType: String {
    case none
    case hdVideo = "WWDCSessionAssetTypeHDVideo"
    case sdVideo = "WWDCSessionAssetTypeSDVideo"
    case image = "WWDCSessionAssetTypeShelfImage"
    case slides = "WWDCSessionAssetTypeSlidesPDF"
    case streamingVideo = "WWDCSessionAssetTypeStreamingVideo"
    case liveStreamVideo = "WWDCSessionAssetTypeLiveStreamVideo"
    case webpage = "WWDCSessionAssetTypeWebpageURL"
}

/// Session assets are resources associated with sessions, like videos, PDFs and useful links
public class SessionAsset: Object {

    /// The type of asset:
    ///
    /// - WWDCSessionAssetTypeHDVideo
    /// - WWDCSessionAssetTypeSDVideo
    /// - WWDCSessionAssetTypeShelfImage
    /// - WWDCSessionAssetTypeSlidesPDF
    /// - WWDCSessionAssetTypeStreamingVideo
    /// - WWDCSessionAssetTypeWebpageURL
    internal dynamic var rawAssetType = "" {
        didSet {
            self.identifier = generateIdentifier()
        }
    }

    public dynamic var identifier = ""

    public var assetType: SessionAssetType {
        get {
            return SessionAssetType(rawValue: rawAssetType) ?? .none
        }
        set {
            rawAssetType = newValue.rawValue
        }
    }

    /// The year of the session this asset belongs to
    public dynamic var year = 0 {
        didSet {
            self.identifier = generateIdentifier()
        }
    }

    /// The id of the session this asset belongs to
    public dynamic var sessionId = "" {
        didSet {
            self.identifier = generateIdentifier()
        }
    }

    /// URL for this asset
    public dynamic var remoteURL = ""

    /// Relative local URL to save the asset to when downloading
    public dynamic var relativeLocalURL = ""

    /// The session this asset belongs to
    public let session = LinkingObjects(fromType: Session.self, property: "assets")

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    public override static func indexedProperties() -> [String] {
        return [
            "identifier",
            "rawAssetType",
            "sessionId",
            "year",
            "remoteURL",
            "relativeLocalURL"
        ]
    }

    func merge(with other: SessionAsset, in realm: Realm) {
        assert(other.remoteURL == self.remoteURL, "Can't merge two objects with different identifiers!")

        self.year = other.year
        self.sessionId = other.sessionId
        self.relativeLocalURL = other.relativeLocalURL
    }

    public func generateIdentifier() -> String {
        return String(self.year) + "@" + self.sessionId + "~" + self.rawAssetType.replacingOccurrences(of: "WWDCSessionAssetType", with: "")
    }

}
