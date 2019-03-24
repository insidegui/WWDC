//
//  Bookmark.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

/// Bookmarks are notes the user can create while watching session videos to reference later, bookmarks can be private or shared with other users
public final class Bookmark: Object, HasCloudKitFields, SoftDeletable, Decodable {

    @objc public dynamic var ckFields = Data()

    /// Unique identifier
    @objc public dynamic var identifier = UUID().uuidString

    /// Date/time the bookmark was created
    @objc public dynamic var createdAt = Date.distantPast

    /// Date/time the bookmark was last modified
    @objc public dynamic var modifiedAt = Date.distantPast

    /// Whether other users can see this bookmark or only the user who created it can
    @objc public dynamic var isShared = false

    /// Plain text body
    @objc public dynamic var body = ""

    /// Formatted text body
    @objc public dynamic var attributedBody = Data()

    /// Time in the video this bookmark was created
    @objc public dynamic var timecode = 0.0

    /// Time in the video where the bookmark ends
    @objc public dynamic var duration: Double = 0.0

    /// Snapshot from the video at the time the bookmark was created
    @objc public dynamic var snapshot = Data()

    /// What the presenter was saying close to where the bookmark was created
    @objc public dynamic var annotation: TranscriptAnnotation?

    /// Soft delete (for syncing)
    @objc public dynamic var isDeleted: Bool = false

    /// When was this item soft deleted (for syncing)
    @objc public dynamic var deletedAt: Date = .distantFuture

    /// The session this bookmark is associated with
    public let session = LinkingObjects(fromType: Session.self, property: "bookmarks")

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case body, attributedBody, timecode, duration
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        body = try container.decode(key: .body)
        timecode = try container.decode(key: .timecode)
        duration = try container.decode(key: .duration)
        isShared = true

        if let attributedBody = try container.decodeIfPresent(String.self, forKey: .attributedBody),
            let attributedBodyData = Data(base64Encoded: attributedBody) {
            self.attributedBody = attributedBodyData
        }
    }

}
