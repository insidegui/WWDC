//
//  SessionProgressSyncObject.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKitCodable
import os.log

public struct SessionProgressSyncObject: CustomCloudKitCodable, BelongsToSession {
    public var cloudKitSystemFields: Data?
    public var cloudKitIdentifier: String
    public let sessionId: String?
    let createdAt: Date
    let updatedAt: Date
    var currentPosition: Double
    var relativePosition: Double
    var isDeleted: Bool
}

extension SessionProgress: SyncObjectConvertible, BelongsToSession {

    public static var syncThrottlingInterval: TimeInterval {
        return 20.0
    }

    public var sessionId: String? {
        return session.first?.identifier
    }

    public typealias SyncObject = SessionProgressSyncObject

    public static func from(syncObject: SyncObject) -> SessionProgress {
        let progress = SessionProgress()

        progress.ckFields = syncObject.cloudKitSystemFields ?? Data()
        progress.identifier = syncObject.cloudKitIdentifier
        progress.createdAt = syncObject.createdAt
        progress.updatedAt = syncObject.updatedAt
        progress.currentPosition = syncObject.currentPosition
        progress.relativePosition = syncObject.relativePosition
        progress.isDeleted = syncObject.isDeleted

        return progress
    }

    public var syncObject: SessionProgressSyncObject? {
        guard let sessionId = session.first?.identifier else {
            os_log("SessionProgress %@ is not associated to a session. That's illegal!",
                   log: .default,
                   type: .fault,
                   identifier)

            return nil
        }

        return SessionProgressSyncObject(cloudKitSystemFields: ckFields.isEmpty ? nil : ckFields,
                                         cloudKitIdentifier: identifier,
                                         sessionId: sessionId,
                                         createdAt: createdAt,
                                         updatedAt: updatedAt,
                                         currentPosition: currentPosition,
                                         relativePosition: relativePosition,
                                         isDeleted: isDeleted)
    }

}
