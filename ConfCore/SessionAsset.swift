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
public class SessionAsset: Object, Decodable {

    /// The type of asset:
    ///
    /// - WWDCSessionAssetTypeHDVideo
    /// - WWDCSessionAssetTypeSDVideo
    /// - WWDCSessionAssetTypeShelfImage
    /// - WWDCSessionAssetTypeSlidesPDF
    /// - WWDCSessionAssetTypeStreamingVideo
    /// - WWDCSessionAssetTypeWebpageURL
    @objc internal dynamic var rawAssetType = "" {
        didSet {
            identifier = generateIdentifier()
        }
    }

    @objc public dynamic var identifier = ""

    public var assetType: SessionAssetType {
        get {
            return SessionAssetType(rawValue: rawAssetType) ?? .none
        }
        set {
            rawAssetType = newValue.rawValue
        }
    }

    /// The year of the session this asset belongs to
    @objc public dynamic var year = 0 {
        didSet {
            identifier = generateIdentifier()
        }
    }

    /// The id of the session this asset belongs to
    @objc public dynamic var sessionId = "" {
        didSet {
            identifier = generateIdentifier()
        }
    }

    /// URL for this asset
    @objc public dynamic var remoteURL = ""

    /// Relative local URL to save the asset to when downloading
    @objc public dynamic var relativeLocalURL = ""

    @objc public dynamic var actualEndDate: Date?

    /// The session this asset belongs to
    public let session = LinkingObjects(fromType: Session.self, property: "assets")

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    func merge(with other: SessionAsset, in realm: Realm) {
        assert(other.remoteURL == remoteURL, "Can't merge two objects with different identifiers!")

        year = other.year
        sessionId = other.sessionId
        relativeLocalURL = other.relativeLocalURL
    }

    public func generateIdentifier() -> String {
        return String(year) + "@" + sessionId + "~" + rawAssetType.replacingOccurrences(of: "WWDCSessionAssetType", with: "")
    }

    public convenience required init(from decoder: Decoder) throws {
        let context = DecodingError.Context(codingPath: decoder.codingPath,
                                            debugDescription: "SessionAsset decoding is not currently supported")
        throw DecodingError.dataCorrupted(context)
    }
}

struct LiveAssetWrapper: Decodable {

    let liveSession: SessionAsset

    private enum CodingKeys: String, CodingKey {
        case sessionId, tvosUrl, iosUrl, actualEndDate
    }

    public init(from decoder: Decoder) throws {
        guard let sessionId = decoder.codingPath.last?.stringValue else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Session id is not the last coding path",
                underlyingError: nil)
            throw DecodingError.dataCorrupted(context)
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let remoteURL = try container.decodeIfPresent(String.self, forKey: .tvosUrl) ?? container.decodeIfPresent(String.self, forKey: .iosUrl) else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "no url for the live asset",
                underlyingError: nil)
            throw DecodingError.dataCorrupted(context)
        }

        let asset = SessionAsset()

        // Live assets are always for the current year
        asset.year = Calendar.current.component(.year, from: Date())
        // There are two assumptions being made here
        // 1 - Live assets are always for the current year
        // 2 - Live assets are always for "WWDC" events
        // FIXME: done in a rush to fix live streaming in 2018
        asset.sessionId = "wwdc\(asset.year)-"+sessionId
        asset.rawAssetType = SessionAssetType.liveStreamVideo.rawValue
        asset.remoteURL = remoteURL
        // Not using decodeIfPresent because date can actually be an empty string :/
        asset.actualEndDate = try? container.decode(Date.self, forKey: .actualEndDate)

        self.liveSession = asset
    }
}

struct LiveVideosWrapper: Decodable {

    let liveAssets: [SessionAsset]

    // MARK: - Decodable

    private enum CodingKeys: String, CodingKey {
        case liveSessions = "live_sessions"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let assets = try container.decode([String: LiveAssetWrapper].self, forKey: .liveSessions)

        self.liveAssets = assets.values.map { $0.liveSession }
    }
}
