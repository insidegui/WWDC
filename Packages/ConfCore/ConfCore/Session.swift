//
//  Session.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Specifies a session in an event, with its related keywords, assets, instances, user favorites and user bookmarks
public class Session: Object, Decodable {

    /// Unique identifier
    @objc public dynamic var identifier = ""

    /// Session number
    @objc public dynamic var number = ""

    /// Title
    @objc public dynamic var title = ""

    @objc public dynamic var staticContentId = ""

    /// Description
    @objc public dynamic var summary = ""

    /// The event identifier for the event this session belongs to
    @objc public dynamic var eventIdentifier = ""
    @objc public dynamic var eventStartDate = Date.distantPast

    /// Track name
    @objc public dynamic var trackName = ""
    @objc public dynamic var trackOrder = 0

    /// Track identifier
    @objc public dynamic var trackIdentifier = ""

    /// The session's focuses
    public let focuses = List<Focus>()

    /// The session's assets (videos, slides, links)
    public let assets = List<SessionAsset>()

    // The session's "related" resources -- other sessions, documentation, guides and sample code
    public var related = List<RelatedResource>()

    /// Whether this session is downloaded
    @objc public dynamic var isDownloaded = false

    /// Session favorite
    public let favorites = List<Favorite>()

    /// Session progress
    public let progresses = List<SessionProgress>()

    /// Session bookmarks
    public let bookmarks = List<Bookmark>()

    /// Transcript identifier for the session
    @objc public dynamic var transcriptIdentifier: String = ""

    /// Shortcut to get the full transcript text (used during search)
    @objc public dynamic var transcriptText: String = ""

    /// Media duration (in seconds)
    @objc public dynamic var mediaDuration: Double = 0

    /// Fetches and returns the transcript object associated with the session
    public func transcript() -> Transcript? {
        guard let transcripts = transcripts() else { return nil }

        return transcripts.first
    }

    /// Fetches and returns the transcripts associated with the session. There should only ever be one.
    public func transcripts() -> Results<Transcript>? {
        guard let realm = realm else { return nil }
        guard !transcriptIdentifier.isEmpty else { return nil }

        return realm.objects(Transcript.self).filter("identifier == %@ AND annotations.@count > 0", transcriptIdentifier)
    }

    /// The session's track
    public let track = LinkingObjects(fromType: Track.self, property: "sessions")

    /// The event this session belongs to
    public let event = LinkingObjects(fromType: Event.self, property: "sessions")

    /// Instances of this session
    public let instances = LinkingObjects(fromType: SessionInstance.self, property: "session")

    public override static func primaryKey() -> String? {
        return "identifier"
    }

    //    public func transcript() -> Transcript? {
    //        guard let realm = self.realm else { return nil }
    //        guard !transcriptIdentifier.isEmpty else { return nil }
    //
    //        return realm.objects(Transcript.self).filter("identifier == %@", self.transcriptIdentifier).first
    //    }

    @MainActor
    public static let videoPredicate: NSPredicate = NSPredicate(format: "ANY assets.rawAssetType == %@", SessionAssetType.streamingVideo.rawValue)

    public static func sameTrackSortDescriptors() -> [RealmSwift.SortDescriptor] {
        return [
            RealmSwift.SortDescriptor(keyPath: "eventStartDate"),
            RealmSwift.SortDescriptor(keyPath: "title")
        ]
    }

    func merge(with other: Session, in realm: Realm) {
        assert(other.identifier == identifier, "Can't merge two objects with different identifiers!")

        title = other.title
        number = other.number
        summary = other.summary
        eventIdentifier = other.eventIdentifier
        trackIdentifier = other.trackIdentifier
        staticContentId = other.staticContentId
        trackName = other.trackName
        mediaDuration = other.mediaDuration

        // merge assets
        // Pulling the identifiers into Swift Set is an optimization for realm,
        // You can't see it but `map` on `List` is lazy and each call to `.contains(element)`
        // is O(n) but with a higher constant time because it accesses the realm property
        // every time. Pulling strings into a Set gets the `.contains` call down to O(1)
        // and ensures the Realm object accesses are only done once
        let currentAssetIds = Set(self.assets.map { $0.identifier })
        other.assets.forEach { otherAsset in
            guard !currentAssetIds.contains(otherAsset.identifier) else { return }
            self.assets.append(otherAsset)
        }

        let currentRelatedIds = Set(related.map { $0.identifier })
        other.related.forEach { newRelated in
            guard !currentRelatedIds.contains(newRelated.identifier) else { return }

            related.append(realm.object(ofType: RelatedResource.self, forPrimaryKey: newRelated.identifier) ?? newRelated)
        }

        let currentFocusIds = Set(focuses.map { $0.name })
        other.focuses.forEach { newFocus in
            guard !currentFocusIds.contains(newFocus.name) else { return }

            focuses.append(realm.object(ofType: Focus.self, forPrimaryKey: newFocus.name) ?? newFocus)
        }
    }

    // MARK: - Decodable

    private enum AssetCodingKeys: String, CodingKey {
        case id, year, title, downloadHD, downloadSD, downloadHLS, slides, hls, images, shelf, duration
    }

    private enum SessionCodingKeys: String, CodingKey {
        case id, year, title, platforms, description, startTime, eventContentId, eventId, media, webPermalink, staticContentId, related
        case track = "trackId"
    }

    private enum RelatedCodingKeys: String, CodingKey {
        case activities, resources
    }

    public convenience required init(from decoder: Decoder) throws {
        let sessionContainer = try decoder.container(keyedBy: SessionCodingKeys.self)

        let id = try sessionContainer.decode(String.self, forKey: .id)
        let eventIdentifier = try sessionContainer.decode(String.self, forKey: .eventId)
        let eventYear = eventIdentifier.replacingOccurrences(of: "wwdc", with: "")
        let title = try sessionContainer.decode(String.self, forKey: .title)
        let summary = try sessionContainer.decode(String.self, forKey: .description)
        let trackIdentifier = try sessionContainer.decodeIfPresent(Int.self, forKey: .track) ?? SessionInstance.defaultTrackId
        let eventContentId = try sessionContainer.decode(Int.self, forKey: .eventContentId)

        self.init()

        var mediaDuration: Double?

        func decodeAssetIfPresent() throws {

            let assetContainer: KeyedDecodingContainer<Session.AssetCodingKeys>
            do {
                assetContainer = try sessionContainer.nestedContainer(keyedBy: AssetCodingKeys.self, forKey: .media)
            } catch DecodingError.keyNotFound {
                return
            }

            mediaDuration = try assetContainer.decodeIfPresent(Double.self, forKey: .duration) ?? 0.0

            if let url = try assetContainer.decodeIfPresent(String.self, forKey: .hls) {
                let streaming = SessionAsset()

                streaming.rawAssetType = SessionAssetType.streamingVideo.rawValue
                streaming.remoteURL = url
                streaming.year = Int(eventYear) ?? -1
                streaming.sessionId = id

                self.assets.append(streaming)
            }

            if let hd = try assetContainer.decodeIfPresent(String.self, forKey: .downloadHD) {
                let hdVideo = SessionAsset()
                hdVideo.rawAssetType = SessionAssetType.hdVideo.rawValue
                hdVideo.remoteURL = hd
                hdVideo.year = Int(eventYear) ?? -1
                hdVideo.sessionId = id

                let filename = URL(string: hd)?.lastPathComponent ?? "\(title).mp4"
                hdVideo.relativeLocalURL = "\(eventYear)/\(filename)"

                self.assets.append(hdVideo)
            }

            if let sd = try assetContainer.decodeIfPresent(String.self, forKey: .downloadSD) {
                let sdVideo = SessionAsset()
                sdVideo.rawAssetType = SessionAssetType.sdVideo.rawValue
                sdVideo.remoteURL = sd
                sdVideo.year = Int(eventYear) ?? -1
                sdVideo.sessionId = id

                let filename = URL(string: sd)?.lastPathComponent ?? "\(title).mp4"
                sdVideo.relativeLocalURL = "\(eventYear)/\(filename)"

                self.assets.append(sdVideo)
            }

            if let slides = try assetContainer.decodeIfPresent(String.self, forKey: .slides) {
                let slidesAsset = SessionAsset()
                slidesAsset.rawAssetType = SessionAssetType.slides.rawValue
                slidesAsset.remoteURL = slides
                slidesAsset.year = Int(eventYear) ?? -1
                slidesAsset.sessionId = id

                self.assets.append(slidesAsset)
            }

            if let downloadHLS = try assetContainer.decodeIfPresent(String.self, forKey: .downloadHLS) {
                let downloadHLSVideo = SessionAsset()
                downloadHLSVideo.rawAssetType = SessionAssetType.downloadHLSVideo.rawValue
                downloadHLSVideo.remoteURL = downloadHLS
                downloadHLSVideo.year = Int(eventYear) ?? -1
                downloadHLSVideo.sessionId = downloadHLS

                let filename = "\(title).movpkg"
                downloadHLSVideo.relativeLocalURL = "\(eventYear)/\(filename)"

                self.assets.append(downloadHLSVideo)
            }
        }

        func decodeRelatedIfPresent() throws {

            let relatedContainer: KeyedDecodingContainer<Session.RelatedCodingKeys>
            do {
                relatedContainer = try sessionContainer.nestedContainer(keyedBy: RelatedCodingKeys.self, forKey: .related)
            } catch DecodingError.keyNotFound {
                return
            }

            if let resources = try relatedContainer.decodeIfPresent([UnknownRelatedResource].self, forKey: .resources)?.map({ $0.resource }) {
                self.related.append(objectsIn: resources)
            }

            if let resources = try relatedContainer.decodeIfPresent([ActivityRelatedResource].self, forKey: .activities)?.map({ $0.resource }) {
                self.related.append(objectsIn: resources)
            }
        }

        try decodeAssetIfPresent()
        try decodeRelatedIfPresent()

        if let permalink = try sessionContainer.decodeIfPresent(String.self, forKey: .webPermalink) {
            let webPageAsset = SessionAsset()
            webPageAsset.rawAssetType = SessionAssetType.webpage.rawValue
            webPageAsset.remoteURL = permalink
            webPageAsset.year = Int(eventYear) ?? -1
            webPageAsset.sessionId = id

            self.assets.append(webPageAsset)
        }

        if let focuses = try sessionContainer.decodeIfPresent([Focus].self, forKey: .platforms) {
            self.focuses.append(objectsIn: focuses)
        }

        self.staticContentId = String(try sessionContainer.decodeIfPresent(Int.self, forKey: .staticContentId) ?? 0)
        self.identifier = id
        self.number = String(eventContentId)
        self.title = title
        self.summary = summary
        self.trackIdentifier = String(trackIdentifier)
        self.mediaDuration = mediaDuration ?? 0
        self.eventIdentifier = eventIdentifier
    }
}

extension Session {

    /// Returns the first asset matching the requested type
    public func asset(ofType type: SessionAssetType) -> SessionAsset? {
        if type == .image {
            return imageAsset()
        } else {
            return assets(matching: [type]).first
        }
    }

    private func imageAsset() -> SessionAsset? {
        guard let baseURL = event.first.flatMap({ URL(string: $0.imagesPath) }) else { return nil }

        let filename = "\(staticContentId)_wide_900x506_1x.jpg"

        let url = baseURL.appendingPathComponent("\(staticContentId)/\(filename)")

        let asset = SessionAsset()

        asset.assetType = .image
        asset.remoteURL = url.absoluteString

        return asset
    }

    public func assets(matching types: [SessionAssetType]) -> Results<SessionAsset> {
        assert(!types.contains(.image), "This method does not support finding image assets")

        let predicate = NSPredicate(format: "rawAssetType IN %@", types.map { $0.rawValue })
        return assets.filter(predicate)
    }
}

public extension Session {
    var isFavorite: Bool { !favorites.filter("isDeleted == false").isEmpty }
}
