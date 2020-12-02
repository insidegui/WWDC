//
//  UserDataSyncProtocols.swift
//  ConfCore
//
//  Created by Guilherme Rambo on 24/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation
import RealmSwift
import CloudKit
import CloudKitCodable

typealias SynchronizableObject = Object & SyncObjectConvertible & SoftDeletable
typealias SoftDeletableSynchronizableObject = Object & HasCloudKitFields & SoftDeletable

public protocol HasCloudKitFields {
    var ckFields: Data { get set }

    var ckRecordID: CKRecord.ID? { get }

    static func resolveConflict(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord?

    static var syncThrottlingInterval: TimeInterval { get }
}

public protocol SyncObjectConvertible: HasCloudKitFields {
    associatedtype SyncObject: CustomCloudKitCodable & BelongsToSession

    static func from(syncObject: SyncObject) -> Self
    var syncObject: SyncObject? { get }
}

public protocol BelongsToSession {
    var sessionId: String? { get }
}

public protocol SoftDeletable {
    var isDeleted: Bool { get set }
}

extension HasCloudKitFields {

    public var ckRecordID: CKRecord.ID? {
        guard !ckFields.isEmpty else { return nil }

        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: ckFields) else { return nil }
        coder.requiresSecureCoding = true

        let metaRecord = CKRecord(coder: coder)
        coder.finishDecoding()

        return metaRecord?.recordID
    }

}
