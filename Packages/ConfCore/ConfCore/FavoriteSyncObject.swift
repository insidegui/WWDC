//
//  FavoriteSyncObject.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 20/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import CloudKitCodable
import os.log

public struct FavoriteSyncObject: CustomCloudKitCodable, BelongsToSession {
    public var cloudKitSystemFields: Data?
    public var cloudKitIdentifier: String
    public let sessionId: String?
    let createdAt: Date
    var isDeleted: Bool
}

extension Favorite: SyncObjectConvertible, BelongsToSession {

    public static var syncThrottlingInterval: TimeInterval {
        return 0
    }

    public var sessionId: String? {
        return session.first?.identifier
    }

    public typealias SyncObject = FavoriteSyncObject

    public static func from(syncObject: SyncObject) -> Favorite {
        let favorite = Favorite()

        favorite.ckFields = syncObject.cloudKitSystemFields ?? Data()
        favorite.identifier = syncObject.cloudKitIdentifier
        favorite.createdAt = syncObject.createdAt
        favorite.isDeleted = syncObject.isDeleted

        return favorite
    }

    public var syncObject: FavoriteSyncObject? {
        guard let sessionId = session.first?.identifier else {
            os_log("Favorite %@ is not associated to a session. That's illegal!",
                   log: .default,
                   type: .fault,
                   identifier)

            return nil
        }

        return FavoriteSyncObject(cloudKitSystemFields: ckFields.isEmpty ? nil : ckFields,
                                  cloudKitIdentifier: identifier,
                                  sessionId: sessionId,
                                  createdAt: createdAt,
                                  isDeleted: isDeleted)
    }

}
