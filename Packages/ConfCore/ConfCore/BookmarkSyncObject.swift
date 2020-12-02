//
//  BookmarkSyncObject.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 24/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import CloudKitCodable
import os.log

public struct BookmarkSyncObject: CustomCloudKitCodable, BelongsToSession {
    public var cloudKitSystemFields: Data?
    public var cloudKitIdentifier: String
    public let sessionId: String?
    let createdAt: Date
    var modifiedAt: Date
    var body: String
    var timecode: Double
    var attributedBody: Data
    var snapshot: URL?
    var isDeleted: Bool
}

extension Bookmark: SyncObjectConvertible, BelongsToSession {

    public static var syncThrottlingInterval: TimeInterval {
        return 0
    }

    public typealias SyncObject = BookmarkSyncObject

    public var sessionId: String? {
        return session.first?.identifier
    }

    public static func from(syncObject: BookmarkSyncObject) -> Bookmark {
        let bookmark = Bookmark()

        bookmark.ckFields = syncObject.cloudKitSystemFields ?? Data()
        bookmark.identifier = syncObject.cloudKitIdentifier
        bookmark.createdAt = syncObject.createdAt
        bookmark.modifiedAt = syncObject.modifiedAt
        bookmark.body = syncObject.body
        bookmark.timecode = syncObject.timecode
        bookmark.attributedBody = syncObject.attributedBody
        bookmark.isDeleted = syncObject.isDeleted

        if let snapshotURL = syncObject.snapshot {
            do {
                bookmark.snapshot = try Data(contentsOf: snapshotURL)
            } catch {
                os_log("Failed to load bookmark snapshot from CloudKit: %{public}@",
                       log: .default,
                       type: .fault,
                       String(describing: error))
                bookmark.snapshot = Data()
            }
        } else {
            bookmark.snapshot = Data()
        }

        return bookmark
    }

    public var syncObject: BookmarkSyncObject? {
        guard let sessionId = session.first?.identifier else {
            os_log("Bookmark %@ is not associated to a session. That's illegal!",
                   log: .default,
                   type: .fault,
                   identifier)

            return nil
        }

        let snapshotURL = try? snapshot.writeToTempLocationForCloudKitUpload()

        return BookmarkSyncObject(cloudKitSystemFields: ckFields.isEmpty ? nil : ckFields,
                                  cloudKitIdentifier: identifier,
                                  sessionId: sessionId,
                                  createdAt: createdAt,
                                  modifiedAt: modifiedAt,
                                  body: body,
                                  timecode: timecode,
                                  attributedBody: attributedBody,
                                  snapshot: snapshotURL,
                                  isDeleted: isDeleted)
    }

}
